# ADR-P3-0010: Local-only default credentials so the stack starts with one command

| Field | Value |
|---|---|
| Status | accepted |
| Date | 2026-11-04 |
| Deciders | Submission author |
| Requirements | REQ-P3-5, REQ-P3-2 |
| Principles | SEC-DP1, SEC-DP6 |
| Supersedes | none |

## Context

The template hardcodes `postgres` as both user and password in the code and in the compose file (F12). The README promises that `docker compose up --build` starts the stack (REQ-P3-5), so any credential scheme that needs a manual step first breaks the requirement. Postgres is not published to the host and, after ADR-P3-0009, sits on an internal network.

## Decision

The code holds no credentials and reads the standard `PG*` variables. `docker-compose.yml` passes credentials from the environment with defaults named `local-dev-only-*`, `.env.example` documents the override, `.env` is git-ignored, and the API uses the least-privilege `app` role from ADR-P3-0007.

## Alternatives considered

| Option | Gains | Costs | Why it lost |
|---|---|---|---|
| A committed `.env` file | One command still works | A secrets file in git, the pattern scanners flag | Teaches the wrong habit |
| Compose `secrets` from files | Closest to production | The files must exist before the first start | Breaks REQ-P3-5 unless the files are committed |
| A script that generates `.env` first | Strong random passwords | A step before `docker compose up` | Breaks REQ-P3-5 |

## Trade-offs

Default passwords exist in the compose file. They are reachable only from inside the internal network and are named so nobody mistakes them for real ones. Production takes them from a secret manager, as the prevention section states.

## Consequences

### Positive

- The stack starts with the README command, and the code carries no secret.

### Negative

- A reviewer who copies the compose file to a shared host must override the defaults.

### Risks

- The defaults reach a real environment. The names, `.env.example` and the prevention section make the override explicit.

## Verification

`gitleaks` on the history finds no secret, and `docker port` shows no published Postgres or Redis port (local run).

## Reopen when

The stack runs anywhere other than a developer machine.
