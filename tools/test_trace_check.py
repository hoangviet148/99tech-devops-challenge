import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

CHECKER = Path(__file__).resolve().with_name("trace_check.py")

README = """# Challenge answers

One repository holds the five answers (ADR-0001).

## Traceability of the instructions

| Requirement | Decision | Verification |
|---|---|---|
| REQ-G1 Solutions can be viewed without pain | Markdown only | Review |
"""

REQUIREMENTS = """# Requirements

| ID | Requirement | Source | Answered in |
|---|---|---|---|
| REQ-G1 | Solutions can be viewed without pain | Instructions |  |
| REQ-P1-1 | A highly available trading system | Task | `src/problem1` |
| REQ-P2-1 | Steps to troubleshoot the VM | Task | `src/problem2` |
| REQ-P3-1 | Identify the issues | README | `src/problem3` |
| REQ-P4-1 | CI/CD for the backend | Context | `src/problem4` |
| REQ-P5-1 | The platform is made secure | Task | `src/problem5` |
"""

SETS_TABLE = """| Problem | Sets cited by its decision records | Focus |
|---|---|---|
| 1 | GEN, OPS | Capacity and operations |
| 2 | OPS | The runbook |
| 3 | GEN | The stack |
| 4 | GEN, OPS | The pipeline |
| 5 | OPS | The controls |
"""

PRINCIPLES_TABLE = """| ID | Principle | Set |
|---|---|---|
| GEN-DP1 | Stop guessing your capacity needs | General |
| OPS-DP1 | Organize teams around business outcomes | Operational excellence |
"""

PROBLEM1 = """# Problem 1

## 1. Requirements

| ID | Requirement | Source |
|---|---|---|
| REQ-P1-1 | A highly available trading system | Task |

## 2. Assumptions

Problem 5 adds the control SC-02. Files sit in S3, services run on EC2, and digests use SHA-256.

## 8. Cost

| Area | Item | USD per month |
|---|---|---|
| SC-01 custody | Key endpoint | 10 |

## 15. Traceability

### 15.1 Decisions

| ID | Decision | Requirements | ADR |
|---|---|---|---|
| AD-P1-01 | Spot trading only | REQ-P1-1 | ADR-P1-0001 |
"""

PROBLEM2 = """# Problem 2

## Assumptions

The runbook answers REQ-P2-1 and follows ADR-P2-0001.

## Traceability

| Decision | Requirements | ADR |
|---|---|---|
| Evidence first | REQ-P2-1 | ADR-P2-0001 |
"""

PROBLEM3 = """# Problem 3

## 3. Diagnosis

| ID | Scenario |
|---|---|
| S1 | The API answers |

## 8. Assumptions and what was left out

The scenarios run on one machine.

## 9. Traceability

| Decision | Requirements | Verified by | ADR |
|---|---|---|---|
| Fault injection | REQ-P3-1 | S1 | ADR-P3-0001 |
"""

PROBLEM4 = """# Problem 4

## 2. Assumptions

No cloud account is used.

## 11. Traceability

| Decision | Requirements | ADR |
|---|---|---|
| One required gate | REQ-P4-1 | ADR-P4-0001 |
"""

PROBLEM5 = """# Problem 5

## 3. Assumptions

The design starts from AD-P1-01 of Problem 1.

## 6. Security changes

| ID | Change |
|---|---|
| SC-01 | Custody boundary |
| SC-02 | Signed requests |

## 13. Traceability

### 13.1 Changes

| Change | Requirements | Record |
|---|---|---|
| SC-01 | REQ-P5-1 | ADR-P5-0001 |
"""

RECORDS = {
    "docs/adr": ("ADR-0001", "0001-one-repository.md", "One repository", "REQ-G1", "OPS-DP1"),
    "src/problem1/docs/adr": ("ADR-P1-0001", "0001-spot-scope.md", "Spot trading only", "REQ-P1-1", "GEN-DP1, OPS-DP1"),
    "src/problem2/docs/adr": ("ADR-P2-0001", "0001-evidence-first.md", "Evidence first", "REQ-P2-1", "OPS-DP1"),
    "src/problem3/docs/adr": ("ADR-P3-0001", "0001-fault-injection.md", "Fault injection", "REQ-P3-1", "GEN-DP1"),
    "src/problem4/docs/adr": ("ADR-P4-0001", "0001-one-gate.md", "One required gate", "REQ-P4-1", "GEN-DP1, OPS-DP1"),
    "src/problem5/docs/adr": ("ADR-P5-0001", "0001-custody.md", "Custody boundary", "REQ-P5-1", "OPS-DP1"),
}

P2_RECORD = "src/problem2/docs/adr/0001-evidence-first.md"
P2_INDEX = "src/problem2/docs/adr/README.md"
P1 = "src/problem1/SOLUTION.md"
P2 = "src/problem2/SOLUTION.md"
P3 = "src/problem3/SOLUTION.md"
P4 = "src/problem4/SOLUTION.md"
P5 = "src/problem5/SOLUTION.md"
PRINCIPLES = "docs/principles.md"


def record(adr_id, title, requirements, principles):
    return f"""# {adr_id}: {title}

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | {requirements} |
| Principles | {principles} |
| Supersedes | none |

## Context

The task needs an answer.

## Decision

The answer is written down.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| Nothing | No work | No answer | Fails the task |
| Something else | Novelty | Risk | Untested |

## Trade-offs

Speed, traded against depth.

## Consequences

### Positive

- An answer exists.

### Negative

- It takes time.

### Risks

- It can be wrong. A review checks it.

## Verification

A review reads it.

## Reopen when

A reviewer finds a gap.
"""


def tree():
    files = {
        "README.md": README,
        "docs/requirements.md": REQUIREMENTS,
        PRINCIPLES: "# Principles\n\n" + SETS_TABLE + "\n" + PRINCIPLES_TABLE,
        P1: PROBLEM1,
        P2: PROBLEM2,
        P3: PROBLEM3,
        P4: PROBLEM4,
        P5: PROBLEM5,
    }
    for folder, (adr_id, name, title, requirements, principles) in RECORDS.items():
        files[f"{folder}/{name}"] = record(adr_id, title, requirements, principles)
        files[f"{folder}/README.md"] = f"# Decision records\n\n| ADR | Decision |\n|---|---|\n| [{adr_id}]({name}) | {title} |\n"
    return files


def run(files, folder="repo"):
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / folder
        for name, text in files.items():
            path = root / name
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(text if isinstance(text, bytes) else text.encode("utf-8"))
        script = root / "tools" / "trace_check.py"
        script.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(CHECKER, script)
        result = subprocess.run(
            [sys.executable, "-I", str(script)],
            cwd=root,
            capture_output=True,
            encoding="utf-8",
            check=False,
        )
        return result.returncode, result.stdout, result.stderr


class TraceCheckTest(unittest.TestCase):
    def edit(self, files, name, old, new):
        self.assertIn(old, files[name])
        files[name] = files[name].replace(old, new, 1)

    def append(self, files, name, text):
        files[name] += f"\n{text}\n"

    def add_row(self, files, name, after, row):
        self.edit(files, name, f"{after}\n", f"{after}\n{row}\n")

    def passes(self, files, folder="repo"):
        code, out, err = run(files, folder)
        self.assertNotIn("Traceback", err)
        self.assertEqual(code, 0, out)
        self.assertIn("\n0 failures\n", out)
        return out

    def fails(self, files, expected, failures=None):
        code, out, err = run(files)
        self.assertNotIn("Traceback", err)
        self.assertEqual(code, 1, out)
        lines = [line for line in out.splitlines() if line.startswith("FAIL ")]
        self.assertTrue(any(expected in line for line in lines), f"{expected!r} not in:\n{out}")
        if failures is not None:
            self.assertEqual(len(lines), failures, out)
        return out

    def line(self, out, prefix):
        return next(line for line in out.splitlines() if line.startswith(prefix))

    def test_valid_tree_passes(self):
        out = self.passes(tree())
        self.assertTrue(out.startswith("requirements 6, principles 2, decision records 6\n"), out)
        unchecked = self.line(out, "problem1 not checked:")
        for token in ("EC2", "S3", "SHA-256"):
            self.assertIn(token, unchecked)
        self.assertIn("problem1: AD-P1-* (1)", out)
        self.assertNotIn("SC-*", self.line(out, "problem1:"))
        self.assertIn("problem5: SC-* (2)", out)
        self.assertIn("problem4 principle sets: GEN, OPS", out)

    def test_checkout_folder_named_like_a_problem(self):
        self.passes(tree(), folder="problem1")

    def test_register_missing(self):
        for name in ("docs/requirements.md", PRINCIPLES):
            with self.subTest(name=name):
                files = tree()
                del files[name]
                self.fails(files, f"{name} is missing")

    def test_register_without_ids(self):
        for name, table in (("docs/requirements.md", REQUIREMENTS), (PRINCIPLES, PRINCIPLES_TABLE)):
            with self.subTest(name=name):
                files = tree()
                self.edit(files, name, table, "No IDs yet.\n")
                self.fails(files, f"{name} defines no ID")

    def test_adr_folder_missing(self):
        files = tree()
        for name in [name for name in files if name.startswith("src/problem2/docs/adr/")]:
            del files[name]
        self.fails(files, "src/problem2/docs/adr is missing")

    def test_adr_index_missing(self):
        files = tree()
        del files[P2_INDEX]
        self.fails(files, f"{P2_INDEX} is missing", failures=1)

    def test_unlinked_record(self):
        files = tree()
        self.edit(files, P2_INDEX, "[ADR-P2-0001](0001-evidence-first.md)", "ADR-P2-0001")
        self.fails(files, f"{P2_INDEX} does not link 0001-evidence-first.md", failures=1)

    def test_dead_index_link(self):
        files = tree()
        self.append(files, P2_INDEX, "| [ADR-P2-0002](0002-gone.md) | Gone |")
        self.fails(files, f"{P2_INDEX} links 0002-gone.md, which does not exist", failures=1)

    def test_wrong_title(self):
        files = tree()
        self.edit(files, P2_RECORD, "# ADR-P2-0001: Evidence first", "# Evidence first")
        self.fails(files, "the title must start with '# ADR-P2-0001: '", failures=1)

    def test_empty_deciders(self):
        files = tree()
        self.edit(files, P2_RECORD, "| Deciders | Submission author |", "| Deciders |  |")
        self.fails(files, "metadata field Deciders is missing or empty", failures=1)

    def test_record_without_requirement(self):
        files = tree()
        self.edit(files, P2_RECORD, "| Requirements | REQ-P2-1 |", "| Requirements | none |")
        self.fails(files, f"{P2_RECORD}: cites no requirement")

    def test_record_without_principle(self):
        files = tree()
        self.edit(files, P2_RECORD, "| Principles | OPS-DP1 |", "| Principles | none |")
        self.fails(files, f"{P2_RECORD}: cites no principle")

    def test_unknown_requirement_in_metadata(self):
        files = tree()
        self.edit(files, P2_RECORD, "| Requirements | REQ-P2-1 |", "| Requirements | REQ-P2-1, REQ-P2-9 |")
        self.fails(files, f"{P2_RECORD}: requirement REQ-P2-9 is not in docs/requirements.md", failures=1)

    def test_unknown_principle_in_metadata(self):
        files = tree()
        self.edit(files, P2_RECORD, "| Principles | OPS-DP1 |", "| Principles | OPS-DP1, OPS-DP9 |")
        self.fails(files, f"{P2_RECORD}: principle OPS-DP9 is not in docs/principles.md", failures=1)

    def test_missing_reopen_section(self):
        files = tree()
        self.edit(files, P2_RECORD, "## Reopen when\n\nA reviewer finds a gap.\n", "")
        self.fails(files, "section 'Reopen when' is missing or empty", failures=1)

    def test_missing_consequence_subsection(self):
        cases = {
            "Positive": "### Positive\n\n- An answer exists.\n\n",
            "Negative": "### Negative\n\n- It takes time.\n\n",
            "Risks": "### Risks\n\n- It can be wrong. A review checks it.\n\n",
        }
        for name, text in cases.items():
            with self.subTest(name=name):
                files = tree()
                self.edit(files, P2_RECORD, text, "")
                self.fails(files, f"{P2_RECORD}: subsection '{name}' of Consequences is missing or empty", failures=1)

    def test_empty_consequence_subsection(self):
        files = tree()
        self.edit(files, P2_RECORD, "### Negative\n\n- It takes time.\n", "### Negative\n")
        self.fails(files, f"{P2_RECORD}: subsection 'Negative' of Consequences is missing or empty", failures=1)

    def test_one_alternative(self):
        files = tree()
        self.edit(files, P2_RECORD, "| Something else | Novelty | Risk | Untested |\n", "")
        self.fails(files, "needs at least two alternatives, found 1", failures=1)

    def test_missing_solution(self):
        files = tree()
        del files[P4]
        self.fails(files, f"{P4} is missing", failures=1)

    def test_no_assumptions_heading(self):
        files = tree()
        self.edit(files, P4, "## 2. Assumptions", "## 2. Givens")
        self.fails(files, f"{P4} has no assumptions section", failures=1)

    def test_undefined_ids_in_solution(self):
        cases = {
            "REQ-P4-7": "requirement REQ-P4-7 is not in docs/requirements.md",
            "OPS-DP9": "principle OPS-DP9 is not in docs/principles.md",
            "ADR-P4-0002": "ADR-P4-0002 has no decision record",
        }
        for token, expected in cases.items():
            with self.subTest(token=token):
                files = tree()
                self.append(files, P4, f"See {token}.")
                self.fails(files, f"{P4}: {expected}", failures=1)

    def test_malformed_ids(self):
        cases = {
            (P1, "REQ-P1-1B"): "REQ-P1-1B is not a well-formed requirement ID",
            (P1, "REQ-P10-1"): "REQ-P10-1 is not a well-formed requirement ID",
            (P2, "ADR-P2-01"): "ADR-P2-01 is not a well-formed decision record ID",
            (P2, "OPS-DP1B"): "OPS-DP1B is not a well-formed principle ID",
        }
        for (name, token), expected in cases.items():
            with self.subTest(token=token):
                files = tree()
                self.append(files, name, f"See {token}.")
                self.fails(files, f"{name}: {expected}", failures=1)

    def test_family_name_in_prose_passes(self):
        files = tree()
        self.append(files, P5, "All the REQ-P1 rows are present.")
        self.passes(files)

    def test_requirement_cited_by_no_record(self):
        files = tree()
        self.add_row(files, "docs/requirements.md", "| REQ-P3-1 | Identify the issues | README | `src/problem3` |", "| REQ-P3-2 | Fix the issues | README | `src/problem3` |")
        self.add_row(files, P3, "| Fault injection | REQ-P3-1 | S1 | ADR-P3-0001 |", "| Fixes | REQ-P3-2 | S1 | ADR-P3-0001 |")
        self.fails(files, "REQ-P3-2 is cited by no decision record", failures=1)

    def test_traceability_row_deleted(self):
        files = tree()
        self.edit(files, P2, "| Evidence first | REQ-P2-1 | ADR-P2-0001 |\n", "")
        self.assertIn("REQ-P2-1", files[P2])
        self.fails(files, f"REQ-P2-1 has no row in the traceability table of {P2}", failures=1)

    def test_traceability_heading_renamed(self):
        cases = {
            P2: ("## Traceability\n", "## Tracing\n"),
            P1: ("## 15. Traceability\n", "## 15. Tracing\n"),
            "README.md": ("## Traceability of the instructions\n", "## Traceability\n"),
        }
        for name, (old, new) in cases.items():
            with self.subTest(name=name):
                files = tree()
                self.edit(files, name, old, new)
                self.fails(files, f"{name} has no traceability section", failures=1)

    def test_id_only_in_register(self):
        files = tree()
        self.add_row(files, "docs/requirements.md", "| REQ-P4-1 | CI/CD for the backend | Context | `src/problem4` |", "| REQ-P4-2 | CI/CD for the frontend | Context | `src/problem4` |")
        self.fails(files, f"REQ-P4-2 has no row in the traceability table of {P4}")

    def test_problem_record_cited_only_by_another_problem(self):
        files = tree()
        self.edit(files, P4, "| One required gate | REQ-P4-1 | ADR-P4-0001 |", "| One required gate | REQ-P4-1 | none |")
        self.append(files, P5, "Problem 4 decided ADR-P4-0001.")
        self.fails(files, f"ADR-P4-0001 is not cited by {P4}", failures=1)

    def test_root_record_cited_only_by_a_solution(self):
        files = tree()
        self.edit(files, "README.md", " (ADR-0001)", "")
        self.append(files, P1, "The layout follows ADR-0001.")
        self.fails(files, "ADR-0001 is not cited by README.md", failures=1)

    def test_undefined_number_in_own_family(self):
        cases = {
            P5: ("SC-03", f"{P5}: SC-03 is not defined in an ID table of {P5} or its decision records"),
            P3: ("S2", f"{P3}: S2 is not defined in an ID table of {P3} or its decision records"),
        }
        for name, (token, expected) in cases.items():
            with self.subTest(token=token):
                files = tree()
                self.append(files, name, f"Then {token} follows.")
                self.fails(files, expected, failures=1)

    def test_cross_problem_number_undefined(self):
        files = tree()
        self.append(files, P1, "Problem 5 also adds SC-03.")
        self.fails(files, f"{P1}: SC-03 is not defined in an ID table of {P5} or its decision records", failures=1)

    def test_area_table_defines_nothing(self):
        files = tree()
        self.add_row(files, P1, "| SC-01 custody | Key endpoint | 10 |", "| SC-07 detection | Threat findings | 20 |")
        self.append(files, P1, "Problem 5 watches the accounts with SC-07.")
        self.fails(files, f"{P1}: SC-07 is not defined in an ID table of {P5} or its decision records", failures=1)

    def test_pinned_family(self):
        cases = {
            "AD-P1-02": f"{P5}: AD-P1-02 is not defined in an ID table of {P1} or its decision records",
            "AD-P2-01": f"{P5}: AD-P2-01 belongs to a family that no problem defines in an ID table",
        }
        for token, expected in cases.items():
            with self.subTest(token=token):
                files = tree()
                self.append(files, P5, f"The design also starts from {token}.")
                self.fails(files, expected, failures=1)

    def test_pinned_family_ignores_other_problems(self):
        files = tree()
        self.append(files, P3, "| ID | Borrowed decision |\n|---|---|\n| AD-P1-02 | Copied row |")
        self.append(files, P5, "The design also starts from AD-P1-02.")
        out = self.fails(files, f"{P5}: AD-P1-02 is not defined in an ID table of {P1} or its decision records", failures=2)
        self.assertIn(f"FAIL {P3}: AD-P1-02 is not defined in an ID table of {P1} or its decision records", out)

    def test_local_row_does_not_override_pinned_family(self):
        files = tree()
        self.append(files, P5, "| ID | Borrowed decision |\n|---|---|\n| AD-P1-99 | Copied row |")
        self.fails(files, f"{P5}: AD-P1-99 is not defined in an ID table of {P1} or its decision records", failures=1)

    def test_shared_family_defined_by_citing_problem(self):
        files = tree()
        self.append(files, P1, "| ID | Local control |\n|---|---|\n| SC-99 | Office network |")
        out = self.passes(files)
        self.assertIn("SC-* (1)", self.line(out, "problem1:"))
        self.append(files, P1, "Problem 5 also adds SC-98.")
        self.fails(files, f"{P1}: SC-98 is not defined in an ID table of {P1}, {P5} or their decision records", failures=1)

    def test_family_defined_by_two_problems(self):
        files = tree()
        self.append(files, P3, "| ID | Threat |\n|---|---|\n| TH-02 | Tampering |")
        self.append(files, P5, "| ID | Threat |\n|---|---|\n| TH-01 | Spoofing |")
        self.append(files, P2, "The runbook covers TH-01 and TH-02.")
        self.passes(files)
        self.append(files, P2, "It leaves out TH-03.")
        self.fails(files, f"{P2}: TH-03 is not defined in an ID table of {P3}, {P5} or their decision records", failures=1)

    def test_family_without_owner(self):
        files = tree()
        self.append(files, P2, "RB-1 restarts the service.")
        self.fails(files, f"{P2}: RB-1 belongs to a family that no problem defines in an ID table", failures=1)

    def test_external_name_passes(self):
        files = tree()
        self.append(files, P2, "Archives are checked with SHA-256.")
        out = self.passes(files)
        self.assertIn("SHA-256", self.line(out, "problem2 not checked:"))

    def test_standard_names_pass(self):
        files = tree()
        self.append(files, P5, "Keys use AES-256 and P-256, text is UTF-8, tokens follow ERC-20, transport is TLS-1.3, weaknesses map to CWE-79, the audit is SOC-2 and mail follows RFC-822.")
        out = self.passes(files)
        unchecked = self.line(out, "problem5 not checked:")
        for token in ("AES-256", "P-256", "UTF-8", "ERC-20", "TLS-1", "CWE-79", "SOC-2", "RFC-822"):
            self.assertIn(token, unchecked)

    def test_standard_name_defined_by_a_problem_is_checked(self):
        files = tree()
        self.append(files, P5, "| ID | Cipher rule |\n|---|---|\n| AES-1 | Keys rotate yearly |")
        self.append(files, P2, "Archives follow AES-2.")
        self.fails(files, f"{P2}: AES-2 is not defined in an ID table of {P5} or its decision records", failures=1)

    def test_restated_requirement_changed(self):
        files = tree()
        self.edit(files, P1, "| REQ-P1-1 | A highly available trading system | Task |", "| REQ-P1-1 | A trading system | Task |")
        self.fails(files, f"{P1}: REQ-P1-1 restates the requirement in other words than docs/requirements.md", failures=1)

    def test_restated_requirement_whitespace_passes(self):
        files = tree()
        self.edit(files, P1, "| REQ-P1-1 | A highly available trading system | Task |", "| REQ-P1-1 |  A highly   available trading system | Task |")
        self.passes(files)

    def test_set_applied_but_not_listed(self):
        files = tree()
        self.edit(files, P2_RECORD, "| Principles | OPS-DP1 |", "| Principles | OPS-DP1, GEN-DP1 |")
        self.fails(files, "docs/principles.md does not list GEN for problem 2, which ADR-P2-0001 cites", failures=1)

    def test_set_cited_in_record_body(self):
        files = tree()
        self.edit(files, P2_RECORD, "Speed, traded against depth.", "Speed, traded against depth (GEN-DP1).")
        self.fails(files, "docs/principles.md does not list GEN for problem 2, which ADR-P2-0001 cites", failures=1)

    def test_set_cited_in_traceability_table(self):
        files = tree()
        self.edit(files, P2, "| Evidence first | REQ-P2-1 | ADR-P2-0001 |", "| Evidence first | REQ-P2-1, GEN-DP1 | ADR-P2-0001 |")
        self.fails(files, f"docs/principles.md does not list GEN for problem 2, which the traceability table of {P2} cites", failures=1)

    def test_set_named_outside_records_and_traceability_passes(self):
        files = tree()
        self.edit(files, P2, "The runbook answers REQ-P2-1", "The runbook answers REQ-P2-1 without GEN-DP1")
        out = self.passes(files)
        self.assertIn("problem2 principle sets: OPS\n", out)

    def test_set_listed_but_not_applied(self):
        files = tree()
        self.edit(files, PRINCIPLES, "| 2 | OPS | The runbook |", "| 2 | OPS, GEN | The runbook |")
        self.fails(files, "docs/principles.md: GEN listed for problem 2, which neither its decision records nor its traceability table cites", failures=1)

    def test_all_sets_means_every_set(self):
        files = tree()
        self.edit(files, PRINCIPLES, "| 1 | GEN, OPS |", "| 1 | All sets |")
        self.fails(files, "docs/principles.md: FSI listed for problem 1, which neither its decision records nor its traceability table cites", failures=6)

    def test_sets_row_missing(self):
        files = tree()
        self.edit(files, PRINCIPLES, "| 3 | GEN | The stack |\n", "")
        self.fails(files, "docs/principles.md has no row for problem 3", failures=1)

    def test_sets_table_missing(self):
        files = tree()
        self.edit(files, PRINCIPLES, SETS_TABLE, "")
        self.fails(files, "docs/principles.md has no table headed Problem", failures=1)

    def test_unreadable_file(self):
        files = tree()
        files[P4] = b"## 2. Assumptions\n\xff\xfe\n"
        self.fails(files, f"{P4} cannot be read: UnicodeDecodeError")

    def test_readme_missing(self):
        files = tree()
        del files["README.md"]
        code, out, err = run(files)
        self.assertEqual(code, 1, out)
        self.assertIn("FAIL README.md is missing\n", out)
        self.assertNotIn("Traceback", err)
        self.assertIn("\n1 failures\n", out)


if __name__ == "__main__":
    unittest.main()
