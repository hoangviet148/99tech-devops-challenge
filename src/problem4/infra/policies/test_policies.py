import json
import pathlib
import sys
import unittest

ROOT = pathlib.Path(__file__).resolve().parent
OIDC = "token.actions.githubusercontent.com"
APPS = ("backend", "frontend")
ENVS = ("staging", "production")


def load(path):
    return json.loads(path.read_text())


def statements(doc):
    return doc["Statement"]


def actions(stmt):
    value = stmt.get("Action", [])
    return [value] if isinstance(value, str) else value


def resources(stmt):
    value = stmt.get("Resource", [])
    return [value] if isinstance(value, str) else value


class TrustPolicies(unittest.TestCase):
    def setUp(self):
        self.trust = {p.stem: load(p) for p in sorted((ROOT / "trust").glob("*.json"))}

    def test_every_role_has_a_trust_policy(self):
        expected = {f"{a}-build" for a in APPS} | {f"{a}-{e}-deploy" for a in APPS for e in ENVS}
        self.assertEqual(set(self.trust), expected)

    def test_trust_is_exact_and_audience_bound(self):
        for name, doc in self.trust.items():
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
        subjects = [statements(d)[0]["Condition"]["StringEquals"][f"{OIDC}:sub"] for d in self.trust.values()]
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


class PermissionPolicies(unittest.TestCase):
    def setUp(self):
        self.perms = {p.stem: load(p) for p in sorted((ROOT / "permissions").glob("*.json"))}

    def test_no_wildcard_actions(self):
        for name, doc in self.perms.items():
            for stmt in statements(doc):
                for action in actions(stmt):
                    with self.subTest(role=name, action=action):
                        self.assertFalse(action.endswith(":*") or action == "*")

    def test_deploy_roles_cannot_write_artifacts(self):
        for app in APPS:
            for env in ENVS:
                for stmt in statements(self.perms[f"{app}-{env}-deploy"]):
                    if "s3:PutObject" in actions(stmt):
                        for res in resources(stmt):
                            with self.subTest(role=f"{app}-{env}-deploy", resource=res):
                                self.assertNotIn("<ARTIFACT_BUCKET>", res)

    def test_record_writes_stay_in_own_prefix(self):
        for app in APPS:
            for env in ENVS:
                for stmt in statements(self.perms[f"{app}-{env}-deploy"]):
                    if "s3:PutObject" not in actions(stmt):
                        continue
                    for res in resources(stmt):
                        if "<MANIFEST_BUCKET>" in res:
                            self.assertTrue(res.endswith(f"/{env}/{app}/*"), res)

    def test_build_roles_write_only_their_app(self):
        for app in APPS:
            other = "frontend" if app == "backend" else "backend"
            for stmt in statements(self.perms[f"{app}-build"]):
                for res in resources(stmt):
                    self.assertNotIn(f"/{other}/", res)


class BucketPolicies(unittest.TestCase):
    def setUp(self):
        self.buckets = {p.stem: load(p) for p in sorted((ROOT / "buckets").glob("*.json"))}

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


if __name__ == "__main__":
    result = unittest.main(exit=False, verbosity=2).result
    sys.exit(0 if result.wasSuccessful() else 1)
