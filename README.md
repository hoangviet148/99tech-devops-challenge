# 99Tech DevOps Challenge

This repository answers the five problems of the 99Tech DevOps Challenge. It was created from a clone of the template repository with its history and folder layout, and it is not a fork (ADR-0001).

| Notion title | Folder | Answer | What runs here |
|---|---|---|---|
| Problem 1: Building Castle In The Cloud | [`src/problem1`](src/problem1) | [A trading platform on AWS](src/problem1/SOLUTION.md) | The cost estimate script in `evidence/` |
| Problem 2: Diagnose Me Doctor | [`src/problem2`](src/problem2) | [A full disk on the NGINX load balancer](src/problem2/SOLUTION.md) | A full-disk lab and the alert rule tests |
| Problem 3: Debugging issues within system | [`src/problem3`](src/problem3) | [An unreliable API on Docker Compose](src/problem3/SOLUTION.md) | The fixed stack, the fault scenarios, an image gate and the monitoring profile |
| Problem 4: Ship It Twice | [`src/problem4`](src/problem4) | [CI/CD for a backend on EC2 and a frontend on S3](src/problem4/SOLUTION.md) | Two small apps, their workflows and the offline tests of every deploy step |
| Problem 5: Fortify The Castle | [`src/problem5`](src/problem5) | [Security for the Problem 1 platform](src/problem5/SOLUTION.md) | Design only |

The Notion titles and the folders do not line up one to one: the README inside `src/problem3` is titled "Problem 4", and the Notion text of Problem 3 points to it. The folder is the identifier everywhere in this repository.

Problem 2 asks for steps to troubleshoot two production issues but describes one, a VM at 99 % storage usage. Its answer covers that scenario and states this reading in its assumptions.

## Reading order

1. [`docs/requirements.md`](docs/requirements.md) gives every requirement of the challenge an ID, and the answers and decision records cite those IDs.
2. The five `SOLUTION.md` files are linked in the table above. Problem 5 secures the Problem 1 design, so Problem 1 comes first. Problems 2, 3 and 4 stand alone.
3. The decision records are listed in [`docs/adr/README.md`](docs/adr/README.md) for the whole submission and in the index of each problem: [1](src/problem1/docs/adr/README.md), [2](src/problem2/docs/adr/README.md), [3](src/problem3/docs/adr/README.md), [4](src/problem4/docs/adr/README.md) and [5](src/problem5/docs/adr/README.md).
4. The `evidence/` folders of Problems 1 to 4 hold the run outputs behind the measured and priced numbers.

## How the answers are organized

| Part | Where |
|---|---|
| Requirement register, 42 IDs | [`docs/requirements.md`](docs/requirements.md) |
| AWS Well-Architected design principles, 46 IDs | [`docs/principles.md`](docs/principles.md) |
| Decision records for the whole submission | [`docs/adr/`](docs/adr) |
| Decision records per problem | `src/problemN/docs/adr/` |
| Run outputs of Problems 1 to 4, each named with its command in the run table below or in the README of its folder | `src/problemN/evidence/` |
| Review rounds and their findings | [`docs/review-log.md`](docs/review-log.md) |
| Consistency check of the IDs, and its tests | [`tools/trace_check.py`](tools/trace_check.py), [`tools/test_trace_check.py`](tools/test_trace_check.py) |
| Workflow that runs the checks on GitHub | [`.github/workflows/ci.yml`](.github/workflows/ci.yml) |

Every decision record cites the requirements it serves and the principles it applies, lists the alternatives it beat with their costs, and names the trigger that would reopen it. Measured or priced numbers come from an evidence file produced by a script in this repository, from a command that an evidence README records with its observed output and date, such as the diagnosis probes in `src/problem3/evidence/probes/README.md`, or from a vendor page cited with the date it was read. Targets, thresholds, allocations and sizing quantities are design values, and each `SOLUTION.md` names the assumption behind them where one exists (ADR-0003).

## Running the checks

### Prerequisites

- Docker with Compose. The Problem 2 lab needs privileged containers and two free loop devices, and on an ARM machine the Problem 4 hook tests need amd64 emulation.
- Node.js 24 with npm, Python 3, `jq`, `curl`, `perl`, `git` and `shellcheck`. The Problem 3 scripts take their millisecond timestamps with `perl`.
- A full git clone, not a ZIP download or a `--depth 1` clone. The Problem 3 before runs check out the template commit `d514e60`, and the Problem 4 scan reads the whole history.
- Network access for the pinned images, the Ubuntu archive, the npm registry, Playwright's Chromium download, the trivy database and the Node.js download of the backend build.

### Commands

The commands of each table run from the folder named above it. The Runs for column gives a class (seconds, minutes, tens of minutes or until stopped), not a measured time, and the first run of a command also downloads the container images and npm packages it uses. The commands that take `--yes` change state on the machine and stop without it.

The root checks, from the repository root:

| Command | What it shows | Runs for | Side effects |
|---|---|---|---|
| `python3 -I tools/trace_check.py` | Every requirement, principle and decision record ID is defined, and so is every local ID that is hyphenated or belongs to a family of its own problem. Every requirement has a decision record and a traceability row, and every decision record has the metadata fields, sections and consequence subsections of the template and two alternatives. The `not checked` lines list the tokens it skipped, such as an unhyphenated ID of another problem or a standard name like SHA-256. The first line prints the register counts | seconds | None |
| `python3 -I tools/test_trace_check.py` | A valid fixture tree passes, and each rule of the trace check fails on a tree that breaks it | seconds | Fixture trees in a temporary directory, removed at the end |

Problem 1, from the repository root:

| Command | What it shows | Runs for | Side effects |
|---|---|---|---|
| `python3 -I src/problem1/evidence/cost_estimate.py` | The cost tables of `src/problem1/evidence/cost-estimate-2026-11-04.md`, computed from the dated unit prices in the script | seconds | None, the tables go to the terminal |

Problem 2, from the repository root:

| Command | What it shows | Runs for | Side effects |
|---|---|---|---|
| `bash src/problem2/lab/run.sh --yes` | The claims of the answer about NGINX on a full disk, checked on a small ext4 filesystem | minutes | A privileged `ubuntu` container attaches two loop devices of the Docker VM and installs packages from the Ubuntu archive. Writes `src/problem2/evidence/lab-<UTC time>.md` or the `--out` file. A failed run leaves its partial report in a `.partial` file instead |
| `bash src/problem2/alerts/test.sh` | The disk alert rules load and pass their promtool unit tests | seconds | Pulls the pinned Prometheus image |

Problem 3, from `src/problem3`:

| Command | What it shows | Runs for | Side effects |
|---|---|---|---|
| `docker compose up --build` | The fixed stack builds and answers `curl -s http://localhost:8080/api/users` | until stopped | Binds port 8080 on every interface until Ctrl-C. `docker compose down -v` then removes the containers and the database volume |
| `bash scripts/verify.sh --yes` | Each fault scenario passes on the fixed stack, and the run exits 1 when one fails | tens of minutes | Recreates the project `p3verify` for every scenario on 127.0.0.1:18080, plus 127.0.0.1:18474 for S5, with k6 and placeholder containers. The report goes to `evidence/verify-after-<time>.md` or the `--out` file |
| `P3_BEFORE_REF=d514e60 bash scripts/verify-before.sh --yes` | The same scenarios on the template stack, where the faults show before the fixes | tens of minutes | The same as `verify.sh`, plus a temporary git worktree of `d514e60`. The report goes to `evidence/verify-before-<time>.md` or the `--out` file |
| `P3_BEFORE_REF=d514e60 bash scripts/image-gate.sh --yes` | HIGH and CRITICAL vulnerabilities and hadolint findings for the images before and after the fixes | minutes | Builds two API images, one in a temporary git worktree of `d514e60`, pulls trivy and hadolint, mounts the Docker socket into the trivy container and keeps the volume `p3gate-trivy-cache`. The report goes to `evidence/image-gate-<time>.md` or the `--out` file |
| `bash scripts/test-alerts.sh` | The Prometheus configuration and alert rules load, and the rules pass their promtool unit tests | seconds | Pulls the pinned Prometheus image |
| `bash scripts/monitoring-check.sh --yes` | The probe alert fires after nginx stops and clears after it starts again | minutes | Runs the project `p3mon` with the monitoring profile on 127.0.0.1:18080 and 127.0.0.1:9090, stops and restarts its nginx, and removes the project at the end. The report goes to `evidence/monitoring-check-<time>.md` or the `--out` file |

`verify.sh`, `verify-before.sh` and `monitoring-check.sh` all bind 127.0.0.1:18080, so only one of them can run at a time.

Problem 4, from `src/problem4`:

| Command | What it shows | Runs for | Side effects |
|---|---|---|---|
| `bash scripts/tests/run-all.sh` | The deploy, rollback, publish, provenance and gate scripts pass their suites against a recording fake of the AWS CLI, and the EC2 deploy hooks pass on Amazon Linux 2023 | minutes | An `amazonlinux:2023` container for `linux/amd64`, and temporary git repositories |
| `(cd backend && npm ci && npm test) && (cd frontend && npm ci && npm test)` | The unit tests of the backend and the frontend pass | seconds | `node_modules/` in both app folders, and the TypeScript output in `backend/dist/` |
| `python3 -I infra/policies/test_policies.py` | The IAM trust, permission and bucket policies pass their unit tests | seconds | None |
| `bash scripts/lint-workflows.sh` | actionlint, zizmor and shellcheck report nothing on the workflows and scripts of Problem 4 | seconds | Pulls actionlint and zizmor. With `GH_TOKEN` set, zizmor also runs its online audits |
| `bash scripts/scan.sh` | gitleaks finds no leak in the git history, and trivy finds no fixable HIGH or CRITICAL issue in `src/problem4` | minutes | Reads the full history of the repository and downloads the trivy database on each run |
| `bash scripts/tests/browser/run.sh` | In Chromium, an open tab follows a release switch and a rollback, and a missing chunk reloads the page once | minutes | `npm ci` in `frontend/` and in `scripts/tests/browser/`, two builds in `frontend/dist/`, a Chromium download into the Playwright cache of the user, a server on 127.0.0.1:4173, and the Playwright `test-results/` folder in `scripts/tests/browser/` |

`evidence/build-determinism.txt` comes from `scripts/build-backend.sh` and `scripts/build-frontend.sh`, each run twice for one commit with `--sha <SHA> --out <DIR>`.

### Root workflow

[`.github/workflows/ci.yml`](.github/workflows/ci.yml) runs on pushes to `main`, on pull requests and on demand, on GitHub's amd64 `ubuntu-24.04` runners, and its token can only read the repository contents. It runs the trace check and its tests, and it fails when the event payload marks the repository as a fork. It lints every tracked shell script with shellcheck, every tracked YAML file with yamllint, and the root and Problem 4 workflows with actionlint and zizmor. For Problem 2 it runs the alert tests and the full-disk lab. For Problem 3 it runs the compose and `nginx -t` checks, the alert tests and the scenarios S1, S5, S6, S8, S11 and S12, and the other scenarios run only in the full `verify.sh` run. For Problem 4 it runs the offline suites and the policy tests. The lab and scenario reports go to the step summary of the run, never into `evidence/`. The workflow runs once the repository is published, and it has not run yet.

## Decisions that span the problems

| ADR | Decision |
|---|---|
| [ADR-0001](docs/adr/0001-one-repository-never-forked.md) | One repository with a folder per problem, created from the template and never forked |
| [ADR-0002](docs/adr/0002-one-register-traced-by-script.md) | One requirement register and one principle list, traced by a script |
| [ADR-0003](docs/adr/0003-numbers-from-runs-or-cited-pages.md) | Every measured or priced number comes from a recorded run or a cited page |
| [ADR-0004](docs/adr/0004-independent-review-before-each-merge.md) | Independent technical review before each merge |
| [ADR-0005](docs/adr/0005-markdown-and-mermaid-only.md) | Markdown with Mermaid as the only document format |
| [ADR-0006](docs/adr/0006-base-answers-before-extensions.md) | Base answers for all five problems before the remaining extensions |

## Assumptions and what was not verified

Each `SOLUTION.md` has its own assumptions section, and requirements derived from an assumption end in `A`. These limits apply to the whole submission:

| Limit | Effect |
|---|---|
| No AWS account | Problems 1 and 5 are verified by review only. The AWS steps of Problem 4 run in dry-run mode or against a recording fake of the AWS CLI, and its `SOLUTION.md` lists the acceptance runs an account would need |
| No GitHub demonstration yet | The Problem 4 workflows have passed actionlint and zizmor but have not run on GitHub, which needs the folder published as its own repository |
| No run of the root workflow yet | The workflow needs the published repository, so none of its jobs has run on GitHub |
| A Docker VM on an arm64 laptop | The Problem 2 lab, the Problem 3 runs and the Problem 4 evidence ran on an arm64 laptop, with their containers in a Docker VM. The lab report records the kernel `7.0.14-orbstack-00380-ga7e0a2dc9535` on aarch64. Each Problem 3 `verify-*.md` records Docker 29.4.0 on linux/arm64 with Compose 5.1.2, and the Problem 4 evidence README records the same Docker version. Absolute timings on production hardware will differ |
| A container, not a VM, for Problem 2 | The lab runs on the kernel of the Docker VM, so LVM growth and journald rest on vendor documentation |

## Traceability of the instructions

| Requirement | Decision | Verification |
|---|---|---|
| REQ-G1 Solutions can be viewed without pain | This README links every answer, and every document is Markdown with Mermaid (ADR-0005) | Each `SOLUTION.md` opened in the GitHub web view before the link is shared (review) |
| REQ-G2 Uncertainties and assumptions are declared | An assumptions section in every `SOLUTION.md`, derived requirements marked with `A`, the limits above | `tools/trace_check.py` fails when a `SOLUTION.md` has no assumptions section (offline test) |
| REQ-G3 Every problem is attempted | Five base answers before the remaining extensions (ADR-0006) | `tools/trace_check.py` fails when a `SOLUTION.md` is missing (offline test) |
| REQ-G4 Work starts from the template and is not forked | A new repository from a clone (ADR-0001) | The root workflow fails on a fork (CI), and `url="$(git remote get-url origin)" && gh repo view "$url" --json isFork --jq .isFork` prints `false` before the link is shared (local run) |
