import json
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parent
OIDC = "token.actions.githubusercontent.com"
APPS = ("backend", "frontend")
ENVS = ("staging", "production")
OIDC_ROLES = {f"{a}-build" for a in APPS} | {f"{a}-{e}-deploy" for a in APPS for e in ENVS}
SERVICE_ROLES = {"backend-instance": "ec2.amazonaws.com", "backend-codedeploy": "codedeploy.amazonaws.com"}
RECORD_READS = {
    "backend-staging-deploy": {"staging/backend/", "staging/frontend/"},
    "backend-production-deploy": {"production/backend/", "production/frontend/", "staging/backend/", "builds/backend/"},
    "frontend-staging-deploy": {"staging/frontend/"},
    "frontend-production-deploy": {"production/frontend/", "staging/frontend/", "builds/frontend/"},
}
S3_ENDPOINT_RESOURCES = {
    "arn:aws:s3:::<ARTIFACT_BUCKET>/backend/*",
    "arn:aws:s3:::al2023-repos-<REGION>-de612dc2",
    "arn:aws:s3:::al2023-repos-<REGION>-de612dc2/*",
    "arn:aws:s3:::aws-codedeploy-<REGION>/*",
}


def load(path):
    return json.loads(path.read_text())


def load_dir(name):
    return {p.stem: load(p) for p in sorted((ROOT / name).glob("*.json"))}


def statements(doc):
    return doc["Statement"]


def allowed(doc):
    return [s for s in statements(doc) if s["Effect"] == "Allow"]


def actions(stmt):
    value = stmt.get("Action", [])
    return [value] if isinstance(value, str) else value


def resources(stmt):
    value = stmt.get("Resource", [])
    return [value] if isinstance(value, str) else value


class TrustPolicies(unittest.TestCase):
    def setUp(self):
        self.trust = load_dir("trust")
        self.oidc = {name: doc for name, doc in self.trust.items() if name in OIDC_ROLES}

    def test_every_role_has_a_trust_policy(self):
        self.assertEqual(set(self.trust), OIDC_ROLES | set(SERVICE_ROLES))

    def test_trust_is_exact_and_audience_bound(self):
        for name, doc in self.oidc.items():
            with self.subTest(role=name):
                (stmt,) = statements(doc)
                self.assertEqual(stmt["Action"], "sts:AssumeRoleWithWebIdentity")
                self.assertTrue(stmt["Principal"]["Federated"].endswith(f":oidc-provider/{OIDC}"))
                self.assertEqual(set(stmt["Condition"]), {"StringEquals"})
                cond = stmt["Condition"]["StringEquals"]
                self.assertEqual(cond[f"{OIDC}:aud"], "sts.amazonaws.com")
                self.assertNotIn("*", cond[f"{OIDC}:sub"])
                self.assertNotIn("?", cond[f"{OIDC}:sub"])

    def test_no_two_roles_share_a_subject(self):
        subjects = [statements(d)[0]["Condition"]["StringEquals"][f"{OIDC}:sub"] for d in self.oidc.values()]
        self.assertEqual(len(subjects), len(set(subjects)))

    def test_subjects_pin_environment_and_workflow(self):
        for app in APPS:
            build = statements(self.trust[f"{app}-build"])[0]["Condition"]["StringEquals"][f"{OIDC}:sub"]
            self.assertIn(":ref:refs/heads/main:", build)
            self.assertTrue(build.endswith(f"/.github/workflows/{app}-cd.yml@refs/heads/main"))
            for env in ENVS:
                sub = statements(self.trust[f"{app}-{env}-deploy"])[0]["Condition"]["StringEquals"][f"{OIDC}:sub"]
                self.assertIn(f":environment:{app}-{env}:", sub)
                self.assertTrue(sub.endswith(f"/.github/workflows/_deploy-{app}.yml@refs/heads/main"))

    def test_service_roles_trust_one_service(self):
        for name, service in SERVICE_ROLES.items():
            with self.subTest(role=name):
                (stmt,) = statements(self.trust[name])
                self.assertEqual(stmt["Action"], "sts:AssumeRole")
                self.assertEqual(stmt["Principal"], {"Service": service})

    def test_codedeploy_is_trusted_for_its_own_account_only(self):
        (stmt,) = statements(self.trust["backend-codedeploy"])
        self.assertEqual(stmt["Condition"], {"StringEquals": {"aws:SourceAccount": "<ACCOUNT_ID>"}})


class PermissionPolicies(unittest.TestCase):
    def setUp(self):
        self.perms = load_dir("permissions")

    def test_every_role_has_permissions(self):
        self.assertEqual(set(self.perms), OIDC_ROLES | set(SERVICE_ROLES))

    def test_no_wildcard_actions(self):
        for name, doc in self.perms.items():
            for stmt in statements(doc):
                for action in actions(stmt):
                    with self.subTest(role=name, action=action):
                        self.assertFalse(action.endswith(":*") or action == "*")

    def test_no_role_can_delete_objects(self):
        for name, doc in self.perms.items():
            for stmt in allowed(doc):
                for action in actions(stmt):
                    with self.subTest(role=name, action=action):
                        self.assertFalse(action.lower().startswith("s3:delete"))

    def test_deploy_roles_cannot_write_artifacts(self):
        for app in APPS:
            for env in ENVS:
                for stmt in statements(self.perms[f"{app}-{env}-deploy"]):
                    if "s3:PutObject" in actions(stmt):
                        for res in resources(stmt):
                            with self.subTest(role=f"{app}-{env}-deploy", resource=res):
                                self.assertNotIn("<ARTIFACT_BUCKET>", res)

    def test_frontend_deploy_roles_never_name_the_artifact_bucket(self):
        for env in ENVS:
            self.assertNotIn("<ARTIFACT_BUCKET>", json.dumps(self.perms[f"frontend-{env}-deploy"]))

    def test_record_writes_stay_in_own_prefix(self):
        for app in APPS:
            for env in ENVS:
                for stmt in statements(self.perms[f"{app}-{env}-deploy"]):
                    if "s3:PutObject" not in actions(stmt):
                        continue
                    for res in resources(stmt):
                        if "<MANIFEST_BUCKET>" in res:
                            self.assertTrue(res.endswith(f"/{env}/{app}/*"), res)

    def test_record_reads_are_the_prefixes_the_scripts_read(self):
        for role, prefixes in RECORD_READS.items():
            reads, lists = set(), set()
            for stmt in allowed(self.perms[role]):
                for res in resources(stmt):
                    if not res.startswith("arn:aws:s3:::<MANIFEST_BUCKET>"):
                        continue
                    if "s3:GetObject" in actions(stmt):
                        reads.add(res.split("<MANIFEST_BUCKET>/", 1)[1].removesuffix("*"))
                    if "s3:ListBucket" in actions(stmt):
                        self.assertEqual(res, "arn:aws:s3:::<MANIFEST_BUCKET>", role)
                        lists.update(stmt["Condition"]["StringEquals"]["s3:prefix"])
            with self.subTest(role=role):
                self.assertEqual(reads, prefixes)
                self.assertEqual(lists, {p for p in prefixes if not p.startswith("builds/")})

    def test_build_roles_write_only_their_app(self):
        for app in APPS:
            other = "frontend" if app == "backend" else "backend"
            for stmt in statements(self.perms[f"{app}-build"]):
                for res in resources(stmt):
                    self.assertNotIn(f"/{other}/", res)

    def test_build_roles_read_back_their_own_records(self):
        for app in APPS:
            reads = {r for s in allowed(self.perms[f"{app}-build"]) if "s3:GetObject" in actions(s) for r in resources(s)}
            self.assertIn(f"arn:aws:s3:::<MANIFEST_BUCKET>/builds/{app}/*", reads)

    def test_backend_deploy_roles_read_only_their_own_alarms(self):
        for env in ENVS:
            prefix = f"arn:aws:cloudwatch:<REGION>:<{env.upper()}_ACCOUNT_ID>:alarm:backend-{env}-"
            for stmt in allowed(self.perms[f"backend-{env}-deploy"]):
                if "cloudwatch:DescribeAlarms" in actions(stmt):
                    for res in resources(stmt):
                        self.assertTrue(res.startswith(prefix), res)

    def test_instance_reads_only_backend_releases(self):
        for stmt in allowed(self.perms["backend-instance"]):
            for res in resources(stmt):
                if res.startswith("arn:aws:s3:::"):
                    self.assertEqual(res, "arn:aws:s3:::<ARTIFACT_BUCKET>/backend/*")

    def test_codedeploy_cannot_create_or_destroy_capacity(self):
        forbidden = {
            "ec2:TerminateInstances",
            "autoscaling:CreateAutoScalingGroup",
            "autoscaling:UpdateAutoScalingGroup",
            "autoscaling:DeleteAutoScalingGroup",
            "sns:Publish",
            "cloudwatch:PutMetricAlarm",
        }
        for stmt in allowed(self.perms["backend-codedeploy"]):
            self.assertFalse(forbidden & set(actions(stmt)), stmt["Sid"])

    def test_codedeploy_changes_only_named_resources(self):
        for stmt in allowed(self.perms["backend-codedeploy"]):
            readonly = all(a.split(":", 1)[1].startswith(("Describe", "Get")) for a in actions(stmt))
            if resources(stmt) == ["*"] and not readonly:
                self.assertIn("Condition", stmt, stmt["Sid"])

    def test_codedeploy_passes_only_the_instance_role_to_ec2(self):
        passes = [s for s in allowed(self.perms["backend-codedeploy"]) if "iam:PassRole" in actions(s)]
        self.assertEqual(len(passes), 1)
        self.assertEqual(resources(passes[0]), ["arn:aws:iam::<ACCOUNT_ID>:role/backend-instance"])
        self.assertEqual(passes[0]["Condition"], {"StringEquals": {"iam:PassedToService": "ec2.amazonaws.com"}})


class BucketPolicies(unittest.TestCase):
    def setUp(self):
        self.buckets = load_dir("buckets")

    def sid(self, name, sid):
        matches = [s for s in statements(self.buckets[name]) if s.get("Sid") == sid]
        self.assertEqual(len(matches), 1, f"{name} has no single {sid}")
        return matches[0]

    def test_every_bucket_requires_tls(self):
        for name in self.buckets:
            stmt = self.sid(name, "DenyInsecureTransport")
            self.assertEqual(stmt["Condition"], {"Bool": {"aws:SecureTransport": "false"}})

    def test_unconditional_writes_are_denied(self):
        for name in self.buckets:
            stmt = self.sid(name, "DenyUnconditionalWrites")
            self.assertEqual(stmt["Effect"], "Deny")
            self.assertEqual(stmt["Condition"]["Null"], {"s3:if-none-match": "true"})

    def test_frontend_activation_is_the_only_overwrite(self):
        for env in ENVS:
            stmt = self.sid(f"frontend-{env}-bucket", "DenyUnconditionalWrites")
            self.assertEqual(stmt["NotResource"], [f"arn:aws:s3:::<FRONTEND_BUCKET_{env.upper()}>/index.html"])

    def test_release_records_and_artifacts_cannot_be_deleted(self):
        for name in ("artifact-bucket", "manifest-bucket"):
            stmt = self.sid(name, "DenyDeletes")
            self.assertTrue({"s3:DeleteObject", "s3:DeleteObjectVersion"} <= set(actions(stmt)))

    def test_each_manifest_prefix_has_one_writer(self):
        prefixes = {f"builds/{a}" for a in APPS} | {f"{e}/{a}" for a in APPS for e in ENVS}
        writers = {}
        for stmt in statements(self.buckets["manifest-bucket"]):
            if stmt.get("Sid", "").startswith("OnlyWriter"):
                prefix = resources(stmt)[0].split(":::<MANIFEST_BUCKET>/")[1].removesuffix("/*")
                writers[prefix] = stmt["Condition"]["StringNotEquals"]["aws:PrincipalArn"]
        self.assertEqual(set(writers), prefixes)
        for prefix, writer in writers.items():
            app = prefix.split("/")[1]
            expected = f"role/{app}-build" if prefix.startswith("builds/") else f"role/{app}-{prefix.split('/')[0]}-deploy"
            self.assertTrue(writer.endswith(expected), f"{prefix} written by {writer}")

    def test_only_backend_principals_read_backend_artifacts(self):
        stmt = self.sid("artifact-bucket", "CrossAccountRead")
        for principal in stmt["Principal"]["AWS"]:
            self.assertTrue(principal.split(":role/", 1)[1].startswith("backend-"), principal)
        self.assertEqual(resources(stmt), ["arn:aws:s3:::<ARTIFACT_BUCKET>/backend/*"])


class ContentSecurityPolicy(unittest.TestCase):
    def setUp(self):
        text = (ROOT / "content-security-policy.txt").read_text().strip()
        self.directives = {d.split()[0]: d.split()[1:] for d in (part.strip() for part in text.split(";")) if d}

    def test_csp_allows_only_own_origin_and_the_api(self):
        self.assertEqual(self.directives["default-src"], ["'self'"])
        self.assertEqual(self.directives["connect-src"], ["'self'", "<API_ORIGIN>"])
        self.assertEqual(set(self.directives) - {"default-src", "connect-src", "object-src", "frame-ancestors", "base-uri"}, set())

    def test_csp_blocks_plugins_framing_and_base_rewrites(self):
        self.assertEqual(self.directives["object-src"], ["'none'"])
        self.assertEqual(self.directives["frame-ancestors"], ["'none'"])
        self.assertEqual(self.directives["base-uri"], ["'self'"])


class EndpointPolicies(unittest.TestCase):
    def setUp(self):
        self.endpoints = load_dir("endpoints")

    def test_endpoint_policies_name_their_actions(self):
        for name, doc in self.endpoints.items():
            for stmt in statements(doc):
                for action in actions(stmt):
                    with self.subTest(endpoint=name, action=action):
                        self.assertFalse(action.endswith(":*") or action == "*")

    def test_s3_endpoint_reaches_only_releases_packages_and_the_agent(self):
        for stmt in allowed(self.endpoints["s3"]):
            self.assertLessEqual(set(resources(stmt)), S3_ENDPOINT_RESOURCES, stmt["Sid"])
            self.assertLessEqual(set(actions(stmt)), {"s3:GetObject", "s3:GetObjectVersion", "s3:ListBucket"}, stmt["Sid"])

    def test_interface_endpoints_serve_only_their_own_account(self):
        for name, doc in self.endpoints.items():
            if name == "s3":
                continue
            for stmt in allowed(doc):
                with self.subTest(endpoint=name):
                    self.assertEqual(stmt["Condition"]["StringEquals"]["aws:PrincipalAccount"], "<ACCOUNT_ID>")


if __name__ == "__main__":
    result = unittest.main(exit=False, verbosity=2).result
    sys.exit(0 if result.wasSuccessful() else 1)
