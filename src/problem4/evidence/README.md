# Evidence

Each file is the unedited output of one command, run on 2026-11-04 on macOS with Docker 29.4.0 (linux/arm64, with `linux/amd64` emulation for the Amazon Linux 2023 containers). The first line of each file names the commit and the command.

| File | Command | Result |
|---|---|---|
| `test-suites.txt` | `bash scripts/tests/run-all.sh` | 9 suites, 113 assertions, all pass |
| `unit-and-policy-tests.txt` | `npm test` in `backend/` and `frontend/`, `python3 -I infra/policies/test_policies.py` | 9, 14 and 13 tests pass |
| `lint-workflows.txt` | `bash scripts/lint-workflows.sh` | actionlint, zizmor and shellcheck report nothing at medium or above |
| `scan.txt` | `bash scripts/scan.sh` | gitleaks finds no leak, trivy finds no HIGH or CRITICAL vulnerability |
| `build-determinism.txt` | `build-backend.sh` and `build-frontend.sh` twice each for one commit | Identical digests per app, and the backend bundle layout |
| `browser-tests.txt` | `bash scripts/tests/browser/run.sh` | 5 of 5 Playwright tests pass |
| `terraform-check.txt` | `bash scripts/terraform-check.sh` | 18 of 18 steps pass, with the three offline plans, the policy and link checks, tflint and trivy |

Collecting this evidence changed three scripts, each recorded in its own commit. actionlint now receives the workflow files by name, because this folder has no `.git` of its own inside the repository. trivy now includes dev dependencies, because the build and CI run them. The build scripts log the artifact name instead of its local path, so the build and browser outputs hold no path of the machine that ran them.
