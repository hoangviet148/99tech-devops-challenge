import argparse
import json
import pathlib
import re
import sys

PLACEHOLDER = re.compile(r"<([A-Z_]+)>")
APPLY_TIME = re.compile(r"^DISTRIBUTION_ID_[A-Z]+$")
SENTINEL = "E0APPLYTIME0"
IAM_TYPES = {"aws_iam_role", "aws_iam_role_policy", "aws_iam_instance_profile", "aws_iam_openid_connect_provider"}
SKIPPED_ACTIONS = (["delete"], ["no-op"], ["read"])


class Report:
    def __init__(self):
        self.problems = []

    def problem(self, text):
        self.problems.append(text)
        print(f"problem   {text}")


def plan_values(plan):
    v = {name: var["value"] for name, var in plan["variables"].items()}
    accounts, github = v["accounts"], v["github"]
    values = {
        "REGION": v["region"],
        "DELIVERY_ACCOUNT_ID": accounts["delivery"],
        "STAGING_ACCOUNT_ID": accounts["staging"],
        "PRODUCTION_ACCOUNT_ID": accounts["production"],
        "ARTIFACT_BUCKET": v["artifact_bucket"],
        "MANIFEST_BUCKET": v["manifest_bucket"],
        "OWNER": github["owner"],
        "OWNER_ID": github["owner_id"],
        "REPO": github["repo"],
        "REPO_ID": github["repo_id"],
    }
    env = v.get("environment")
    if env:
        values.update({"ACCOUNT_ID": accounts[env], "ENVIRONMENT": env, f"FRONTEND_BUCKET_{env.upper()}": v["frontend_bucket"]})
    return env or "delivery", accounts[env or "delivery"], values


def changes(plan):
    for rc in plan.get("resource_changes", []):
        if rc["change"]["actions"] in SKIPPED_ACTIONS:
            continue
        yield rc, rc["change"]["after"] or {}, rc["change"].get("after_unknown") or {}


def policy_documents(plan, env, values):
    buckets = {values["ARTIFACT_BUCKET"]: "artifact-bucket", values["MANIFEST_BUCKET"]: "manifest-bucket"}
    if env != "delivery":
        buckets[values[f"FRONTEND_BUCKET_{env.upper()}"]] = f"frontend-{env}-bucket"
    prefix = f"com.amazonaws.{values['REGION']}."
    for rc, after, unknown in changes(plan):
        kind = rc["type"]
        if kind == "aws_iam_role":
            yield rc["address"], None, f"trust/{after.get('name')}", after.get("assume_role_policy"), unknown.get("assume_role_policy")
        elif kind == "aws_iam_role_policy":
            yield rc["address"], None, f"permissions/{after.get('role')}", after.get("policy"), unknown.get("policy")
        elif kind == "aws_s3_bucket_policy":
            yield rc["address"], None, f"buckets/{buckets.get(after.get('bucket'), after.get('bucket'))}", after.get("policy"), unknown.get("policy")
        elif kind == "aws_vpc_endpoint":
            service = (after.get("service_name") or "").removeprefix(prefix)
            yield rc["address"], service, f"endpoints/{service}", after.get("policy"), unknown.get("policy")


def render(text, values):
    return PLACEHOLDER.sub(lambda m: values[m.group(1)], text)


def first_difference(expected, actual, path="$"):
    if isinstance(expected, dict) and isinstance(actual, dict):
        for key in sorted(set(expected) | set(actual)):
            if expected.get(key) != actual.get(key):
                return first_difference(expected.get(key), actual.get(key), f"{path}.{key}")
    if isinstance(expected, list) and isinstance(actual, list) and len(expected) == len(actual):
        for i, (e, a) in enumerate(zip(expected, actual)):
            if e != a:
                return first_difference(e, a, f"{path}[{i}]")
    return f"{path} is {json.dumps(actual)[:120]}, the document says {json.dumps(expected)[:120]}"


def identity_grants(doc):
    for stmt in doc.get("Statement", []):
        if stmt.get("Effect") != "Allow":
            continue
        listed = stmt.get("Action", [])
        yield from [listed] if isinstance(listed, str) else listed


def check_plan(label, plan, policies, default_endpoints, report):
    env, account, values = plan_values(plan)
    equal = deferred = accepted = 0
    rendered = []
    for address, service, template, doc, unknown in policy_documents(plan, env, values):
        path = policies / f"{template}.json"
        if service is not None and service in default_endpoints:
            if path.exists() or doc is not None:
                report.problem(f"{label}: {address} keeps the default policy by exception but has a document")
            else:
                accepted += 1
                print(f"accepted  {label}: {address} keeps the default endpoint policy")
            continue
        if not path.exists():
            report.problem(f"{label}: {address} has no source document infra/policies/{template}.json")
            continue
        text = path.read_text()
        names = set(PLACEHOLDER.findall(text))
        later = {n for n in names if APPLY_TIME.match(n)}
        missing = sorted(names - set(values) - later)
        if missing:
            report.problem(f"{label}: {template}.json uses {', '.join(missing)}, which the plan does not provide")
            continue
        if later:
            try:
                document = json.loads(render(text, {**values, **{n: SENTINEL for n in later}}))
            except json.JSONDecodeError as err:
                report.problem(f"{label}: {template}.json is not JSON after rendering: {err}")
                continue
            if doc is not None or unknown is not True:
                report.problem(f"{label}: {address} is known at plan, but {template}.json waits for {', '.join(sorted(later))}")
                continue
            deferred += 1
            rendered.append((template, document))
            print(f"deferred  {label}: {address} waits for {', '.join(sorted(later))} ({template}.json)")
            continue
        expected = json.loads(render(text, values))
        if doc is None:
            report.problem(f"{label}: {address} has no policy at plan, but {template}.json needs only plan-time values")
            continue
        actual = json.loads(doc)
        if actual != expected:
            report.problem(f"{label}: {address} differs from {template}.json: {first_difference(expected, actual)}")
            continue
        equal += 1
        rendered.append((template, expected))
        print(f"equal     {label}: {address} = {template}.json")
        if template.startswith("permissions/"):
            for action in identity_grants(expected):
                if action == "*" or action.endswith(":*") or action.lower().startswith("s3:delete"):
                    report.problem(f"{label}: {address} allows {action}")
    for rc, after, _ in changes(plan):
        if rc["type"].startswith("aws_iam_") and rc["type"] not in IAM_TYPES:
            report.problem(f"{label}: {rc['address']} is an {rc['type']}, which grants permissions outside infra/policies")
        if rc["type"] == "aws_iam_role" and (after.get("managed_policy_arns") or after.get("inline_policy")):
            report.problem(f"{label}: {rc['address']} attaches policies outside infra/policies")
    print(f"summary   {label}: {equal} equal their document, {deferred} deferred to apply, {accepted} default endpoint policies accepted")
    return {"label": label, "env": env, "account": account, "values": values, "rendered": rendered}


def inventory(plan):
    found = {"role": set(), "oidc": set(), "app": set(), "group": set(), "config": set(), "alarm": set(),
             "log-group": set(), "targetgroup": set(), "asg": set(), "launch-template": set(), "bucket": set(), "image": set()}
    fields = {
        "aws_iam_role": ("role", "name"),
        "aws_codedeploy_app": ("app", "name"),
        "aws_cloudwatch_metric_alarm": ("alarm", "alarm_name"),
        "aws_cloudwatch_log_group": ("log-group", "name"),
        "aws_lb_target_group": ("targetgroup", "name"),
        "aws_autoscaling_group": ("asg", "name"),
        "aws_launch_template": ("launch-template", "name"),
        "aws_s3_bucket": ("bucket", "bucket"),
    }
    for rc, after, _ in changes(plan):
        if rc["type"] in fields:
            kind, field = fields[rc["type"]]
            found[kind].add(after.get(field))
        if rc["type"] == "aws_iam_openid_connect_provider":
            found["oidc"].add((after.get("url") or "").removeprefix("https://"))
        if rc["type"] == "aws_codedeploy_deployment_group":
            found["group"].add(f"{after.get('app_name')}/{after.get('deployment_group_name')}")
            found["config"].add(after.get("deployment_config_name"))
        if rc["type"] == "aws_launch_template":
            found["image"].add(after.get("image_id"))
    return found


def arns(node):
    if isinstance(node, dict):
        for value in node.values():
            yield from arns(value)
    elif isinstance(node, list):
        for value in node:
            yield from arns(value)
    elif isinstance(node, str) and node.startswith("arn:aws:"):
        yield node


def link_problem(arn, region, accounts, owned, external_roles):
    _, _, service, arn_region, account, resource = arn.split(":", 5)
    global_service = service in ("iam", "s3", "cloudfront")
    if global_service and arn_region:
        return "a global service ARN with a region"
    if not global_service and arn_region != region:
        return f"region {arn_region or 'none'}, the plan region is {region}"
    if service in ("s3", "ssm"):
        if account:
            return "an account ID where AWS ARNs have none"
    elif account not in accounts:
        return f"account {account}, which is none of the three accounts"
    have = owned.get(account, {})
    if service == "iam":
        kind, _, name = resource.partition("/")
        if kind == "role":
            return None if name in have.get("role", set()) or name in external_roles else f"role {name}, which no plan of account {account} creates"
        if kind == "oidc-provider":
            return None if name in have.get("oidc", set()) else f"OIDC provider {name}, which account {account} does not create"
    if service == "s3":
        bucket = resource.split("/", 1)[0]
        aws_owned = {f"al2023-repos-{region}-de612dc2", f"aws-codedeploy-{region}"}
        planned = set().union(*(o.get("bucket", set()) for o in owned.values()))
        return None if bucket in planned | aws_owned else f"bucket {bucket}, which no plan creates"
    if service == "codedeploy":
        kind, _, name = resource.partition(":")
        key = {"application": "app", "deploymentgroup": "group", "deploymentconfig": "config"}.get(kind)
        return None if key and name in have.get(key, set()) else f"CodeDeploy {kind} {name}, which account {account} does not create"
    if service == "cloudwatch" and resource.startswith("alarm:"):
        name = resource.removeprefix("alarm:")
        return None if name in have.get("alarm", set()) else f"alarm {name}, which account {account} does not create"
    if service == "logs" and resource.startswith("log-group:"):
        name = resource.removeprefix("log-group:").removesuffix(":*")
        return None if name in have.get("log-group", set()) else f"log group {name}, which account {account} does not create"
    if service == "elasticloadbalancing" and resource.startswith("targetgroup/"):
        name = resource.split("/")[1]
        return None if name in have.get("targetgroup", set()) else f"target group {name}, which account {account} does not create"
    if service == "autoscaling" and "autoScalingGroupName/" in resource:
        name = resource.split("autoScalingGroupName/", 1)[1]
        return None if name in have.get("asg", set()) else f"Auto Scaling group {name}, which account {account} does not create"
    if service == "ec2" and resource == "launch-template/*":
        return None if have.get("launch-template") else f"launch templates of account {account}, which creates none"
    if service == "ssm" and resource.startswith("parameter/"):
        image = "resolve:ssm:" + resource.removeprefix("parameter")
        planned = set().union(*(o.get("image", set()) for o in owned.values()))
        return None if image in planned else f"parameter {resource}, which no launch template resolves"
    if service == "cloudfront" and resource.startswith("distribution/"):
        return None
    return "an ARN type without a link rule in scripts/plan-policies.py"


def check_links(checked, plans, external_roles, report):
    owned = {c["account"]: inventory(plans[c["label"]]) for c in checked}
    accounts = set(owned)
    count = 0
    for c in checked:
        for template, document in c["rendered"]:
            for arn in arns(document):
                count += 1
                reason = link_problem(arn, c["values"]["REGION"], accounts, owned, external_roles)
                if reason:
                    report.problem(f"links: {template}.json in {c['label']} names {arn}: {reason}")
    print(f"summary   links: {count} ARNs in {sum(len(c['rendered']) for c in checked)} documents name planned resources")


def main():
    parser = argparse.ArgumentParser(description="Compare the policy documents of Terraform plans with infra/policies")
    parser.add_argument("--policies", required=True, type=pathlib.Path)
    parser.add_argument("--plan", action="append", required=True, metavar="LABEL=PATH")
    parser.add_argument("--default-endpoint", action="append", default=[], metavar="SERVICE")
    parser.add_argument("--external-role", action="append", default=[], metavar="NAME")
    parser.add_argument("--links", action="store_true", help="also check that every ARN names a resource of the plans")
    args = parser.parse_args()
    report = Report()
    plans = {}
    for item in args.plan:
        label, _, path = item.partition("=")
        plans[label] = json.loads(pathlib.Path(path).read_text())
    checked = [check_plan(label, plan, args.policies, set(args.default_endpoint), report) for label, plan in plans.items()]
    if args.links:
        envs = sorted(c["env"] for c in checked)
        if envs != ["delivery", "production", "staging"]:
            report.problem(f"links: need the delivery, staging and production plans, got {', '.join(envs)}")
        else:
            check_links(checked, plans, set(args.external_role), report)
    if report.problems:
        print(f"summary   {len(report.problems)} problems")
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
