# 99Tech DevOps Challenge

This repository answers the five problems of the 99Tech DevOps Challenge. It was created from a clone of the template repository with its history and folder layout, and it is not a fork (ADR-0001).

| Notion title | Folder | Answer | What runs here |
|---|---|---|---|
| Problem 1: Building Castle In The Cloud | [`src/problem1`](src/problem1) | [A trading platform on AWS](src/problem1/SOLUTION.md) | The cost estimate script in `evidence/` |
| Problem 2: Diagnose Me Doctor | [`src/problem2`](src/problem2) | [A full disk on the NGINX load balancer](src/problem2/SOLUTION.md) | A full-disk lab and the alert rule tests |
| Problem 3: Debugging issues within system | [`src/problem3`](src/problem3) | [An unreliable API on Docker Compose](src/problem3/SOLUTION.md) | The fixed stack, twelve fault scenarios, an image gate and the monitoring profile |
| Problem 4: Ship It Twice | [`src/problem4`](src/problem4) | [CI/CD for a backend on EC2 and a frontend on S3](src/problem4/SOLUTION.md) | Two small apps, six workflows and the offline tests of every deploy step |
| Problem 5: Fortify The Castle | [`src/problem5`](src/problem5) | [Security for the Problem 1 platform](src/problem5/SOLUTION.md) | Design only |

The Notion titles and the folders do not line up one to one: the README inside `src/problem3` is titled "Problem 4", and the Notion text of Problem 3 points to it. The folder is the identifier everywhere in this repository.

## How the answers are organized

| Part | Where |
|---|---|
| Requirement register, 42 IDs | [`docs/requirements.md`](docs/requirements.md) |
| AWS Well-Architected design principles, 46 IDs | [`docs/principles.md`](docs/principles.md) |
| Decision records for the whole submission | [`docs/adr/`](docs/adr) |
| Decision records per problem, 60 in all | `src/problemN/docs/adr/` |
| Measured evidence behind every number | `src/problemN/evidence/` |
| Review rounds and their findings | [`docs/review-log.md`](docs/review-log.md) |
| Consistency check of the IDs | [`tools/trace_check.py`](tools/trace_check.py) |

Every decision record cites the requirements it serves and the principles it applies, lists the alternatives it beat with their costs, and names the trigger that would reopen it. Every number in an answer comes from an evidence file produced by a script in this repository or from a vendor page cited with the date it was read (ADR-0003).

## Running the checks

The checks need Docker, Node.js 24, Python 3, `jq`, `curl` and `shellcheck`. The Problem 4 hook tests run an `amazonlinux:2023` container for `linux/amd64`, so an ARM machine needs Docker's amd64 emulation.

```bash
python3 -I tools/trace_check.py
```

Problem 3, from `src/problem3`:

```bash
docker compose up --build
```

```bash
bash scripts/verify.sh --yes
```

```bash
bash scripts/verify-before.sh --yes
```

```bash
bash scripts/image-gate.sh --yes
```

```bash
bash scripts/test-alerts.sh
```

```bash
bash scripts/monitoring-check.sh --yes
```

Problem 4, from `src/problem4`:

```bash
bash scripts/tests/run-all.sh
```

```bash
python3 -I infra/policies/test_policies.py
```

```bash
bash scripts/lint-workflows.sh
```

```bash
bash scripts/scan.sh
```

```bash
bash scripts/tests/browser/run.sh
```

Problem 2, from the repository root:

```bash
bash src/problem2/lab/run.sh --yes
```

```bash
bash src/problem2/alerts/test.sh
```

## Decisions that span the problems

| ADR | Decision |
|---|---|
| [ADR-0001](docs/adr/0001-one-repository-never-forked.md) | One repository with a folder per problem, created from the template and never forked |
| [ADR-0002](docs/adr/0002-one-register-traced-by-script.md) | One requirement register and one principle list, traced by a script |
| [ADR-0003](docs/adr/0003-numbers-from-runs-or-cited-pages.md) | Every number comes from a recorded run or a cited vendor page |
| [ADR-0004](docs/adr/0004-independent-review-before-execution-and-merge.md) | Independent technical review before execution and before each merge |
| [ADR-0005](docs/adr/0005-markdown-and-mermaid-only.md) | Markdown with Mermaid as the only document format |
| [ADR-0006](docs/adr/0006-base-answers-before-extensions.md) | Base answers for all five problems before any extension |

## Assumptions and what was not verified

Each `SOLUTION.md` has its own assumptions section, and requirements derived from an assumption end in `A`. These limits apply to the whole submission:

| Limit | Effect |
|---|---|
| No AWS account | Problems 1 and 5 are verified by review only. The AWS steps of Problem 4 run in dry-run mode or against a recording fake of the AWS CLI, and its `SOLUTION.md` lists the acceptance runs an account would need |
| No GitHub demonstration yet | The Problem 4 workflows have passed actionlint and zizmor but have not run on GitHub, which needs the folder published as its own repository |
| A laptop Docker VM | The Problem 3 runs and the Problem 2 lab ran on Docker for macOS (linux/arm64). Each evidence file records the runtime, and absolute timings on production hardware will differ |
| A container, not a VM, for Problem 2 | The lab runs on the kernel of the Docker VM, so LVM growth and journald rest on vendor documentation |

## Traceability of the instructions

| Requirement | Decision | Verification |
|---|---|---|
| REQ-G1 Solutions can be viewed without pain | This README links every answer, and every document is Markdown with Mermaid (ADR-0005) | Each `SOLUTION.md` opened in the GitHub web view before the link is shared (review) |
| REQ-G2 Uncertainties and assumptions are declared | An assumptions section in every `SOLUTION.md`, derived requirements marked with `A`, the limits above | `tools/trace_check.py` fails when a `SOLUTION.md` has no assumptions section (offline test) |
| REQ-G3 Every problem is attempted | Five base answers before any extension (ADR-0006) | `tools/trace_check.py` fails when a `SOLUTION.md` is missing (offline test) |
| REQ-G4 Work starts from the template and is not forked | A new repository from a clone (ADR-0001) | `gh repo view --json isFork` returns `false` (local run) |
