# 99Tech DevOps challenge

This repository answers the five problems of the 99Tech DevOps Challenge. It started from a clone of the template repository and is not a fork (ADR-0001). Every document is Markdown with Mermaid diagrams, so the GitHub web view renders all of it (ADR-0005).

## Reading order

Problem 5 secures the Problem 1 design, so Problem 1 comes first. Problems 2, 3 and 4 stand alone.

1. [Problem 1](src/problem1/SOLUTION.md): a trading platform on AWS, with a priced estimate.
2. [Problem 2](src/problem2/SOLUTION.md): a full disk on the NGINX load balancer VM, reproduced in a lab.
3. [Problem 3](src/problem3/SOLUTION.md): an unreliable API on Docker Compose, fixed and tested by fault scenarios.
4. [Problem 4](src/problem4/SOLUTION.md): CI/CD for a backend on EC2 and a frontend on S3, tested offline.
5. [Problem 5](src/problem5/SOLUTION.md): security built into the Problem 1 design.

Each problem keeps its decision records in `docs/adr/` and, for Problems 1 to 4, its run outputs in `evidence/`.

## Shared documents

- [`docs/requirements.md`](docs/requirements.md) gives every requirement of the challenge an ID. IDs ending in `A` come from an assumption the answer states.
- [`docs/principles.md`](docs/principles.md) lists the AWS Well-Architected design principles that the decision records cite.
- [`docs/adr/`](docs/adr/README.md) holds the decisions that span all five problems: one repository never forked (ADR-0001), one register traced by a script (ADR-0002), numbers only from recorded runs or cited pages (ADR-0003), independent review before each merge (ADR-0004), Markdown with Mermaid only (ADR-0005), and base answers before extensions (ADR-0006).
- [`docs/review-log.md`](docs/review-log.md) records each review round and what it found.
- [`tools/trace_check.py`](tools/trace_check.py) fails when an ID is undefined or a requirement has no decision record or traceability row. [`tools/test_trace_check.py`](tools/test_trace_check.py) tests it.

## Running it locally

You need Docker with Compose, Node.js 24, Python 3, `jq`, `curl`, `perl`, `shellcheck`, network access and a full git clone (Problem 3 checks out the template commit `d514e60`). The Problem 2 lab needs privileged containers and two free loop devices. Commands that take `--yes` change state on the machine and refuse to run without it.

```bash
# Repository root
python3 -I tools/trace_check.py
python3 -I tools/test_trace_check.py
python3 -I src/problem1/evidence/cost_estimate.py
bash src/problem2/lab/run.sh --yes
bash src/problem2/alerts/test.sh

# From src/problem3
docker compose up --build
bash scripts/verify.sh --yes
P3_BEFORE_REF=d514e60 bash scripts/verify-before.sh --yes
P3_BEFORE_REF=d514e60 bash scripts/image-gate.sh --yes
bash scripts/test-alerts.sh
bash scripts/monitoring-check.sh --yes

# From src/problem4
bash scripts/tests/run-all.sh
(cd backend && npm ci && npm test) && (cd frontend && npm ci && npm test)
python3 -I infra/policies/test_policies.py
bash scripts/terraform-check.sh
bash scripts/lint-workflows.sh
bash scripts/scan.sh
bash scripts/tests/browser/run.sh
```

The Problem 3 scripts with `--yes` all bind 127.0.0.1:18080, so run one at a time.

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs the trace check, the linters, the Problem 2 tests and lab, five Problem 3 scenarios and the Problem 4 offline suites, and fails on a fork. S6 runs only locally: on two of three runs on a GitHub-hosted runner, nginx kept the old API addresses for more than 15 s after every replica was recreated.

## Limits

There is no AWS account. Problems 1 and 5 are checked by review only, and the AWS steps of Problem 4 run in dry-run mode or against a fake AWS CLI. No workflow has run on GitHub yet, since that needs the published repository. All runs used a Docker VM on an arm64 laptop, so timings on production hardware will differ. The Problem 2 lab is a container, so its LVM and journald steps rest on vendor documentation.

## Notes on the challenge text

The README inside `src/problem3` is titled "Problem 4", and the Notion text of Problem 3 points to it. Here the folder name is the identifier. Problem 2 asks about two production issues but describes one, a VM at 99 % storage, and its answer covers that one.

## Traceability of the instructions

| Requirement | Decision | Verification |
|---|---|---|
| REQ-G1 Viewable without pain | This README links every answer, all in Markdown (ADR-0005) | Each `SOLUTION.md` opened in the GitHub web view |
| REQ-G2 Assumptions declared | An assumptions section in every `SOLUTION.md`, derived IDs marked `A` | `tools/trace_check.py` fails without that section |
| REQ-G3 Every problem attempted | Base answers first (ADR-0006) | `tools/trace_check.py` fails when a `SOLUTION.md` is missing |
| REQ-G4 From the template, not forked | A new repository from a clone (ADR-0001) | The root workflow fails on a fork, and `gh repo view --json isFork` prints `false` |
