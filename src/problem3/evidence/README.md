# Evidence

| File | What it holds |
|---|---|
| `probes/` | Diagnosis overrides and the commands behind findings F0 to F12 |
| `verify-before-20261104-215042.md` | First matched baseline run of S1 to S12 on `upstream/main` |
| `verify-before-20261104-221004.md` | Second baseline run of S3, S7, S11 and S12 after three harness corrections, listed below |
| `verify-after-*.md` | Runs on the fixed stack, one per fix commit and one full run |

The first baseline run exposed three weaknesses in the harness itself, and the second run repeats only the affected scenarios.

| Scenario | Weakness in the first run | Correction |
|---|---|---|
| S3 | The outage was printed in whole seconds and read 0 s | The outage is printed in milliseconds |
| S7 | 400 requests/s at a constant arrival rate needs about one connection per replica, because each query takes about 2 ms, so it passed on the template and could not reproduce F8 | 120 concurrent clients in a closed loop, which fills every pool |
| S11, S12 | Without the port fix every request returns 502 (F1), which hides the cold-start and missing-Redis behaviour | The port fix applies to every scenario except S1 |

In the second run S7 reports "app connections max 0" because the admin query that counts connections was itself refused with `too many clients`. That refusal is the finding, and the admin column records it.

## Runs on the fixed stack

Each file below is the unedited output of `verify.sh` for one fix commit. The reading column explains every failure that the commit under test does not target.

| File | Commit under test | Reading |
|---|---|---|
| `verify-after-c2-20261104-222603.md` | `3464284` | S6 passes, and nginx reaches the recreated replicas 55 ms after the recreate. S1 and S2 fail on their first 27 requests only, which reach the API while Postgres still refuses connections. The stack has no readiness gate until commit 5. The "uncommitted changes" flag came from untracked ADR files, which `f8d8fe0` stopped counting |
| `verify-after-c3-20261104-222828.md` | `e056ab3` | S4 passes. While Postgres was paused, the slowest response took 1906 ms and every response was a 503. S3 keeps both replicas running with no restart, and cycles 2 to 5 have no error outside the outage window. The 27 errors of cycle 1 fall in the first 126 ms of load and are the same cold-start race as in S1 and S2. A repeat of that start returned 503 `dependency_unavailable` with `ECONNREFUSED` for every request. S10 reads -1 for the pool because `/internal/pool` only exists from commit 5 |
| `verify-after-c4-20261104-224624.md` | `d2b8f61` | S5 passes. With Redis stopped, paused or blackholed, p99 stayed at or below 11.2 ms with no failed request. S12 fails on its first request only, a 503 `dependency_unavailable` caused by `ECONNREFUSED` from Postgres. A repeat of that start answered 200 once Postgres accepted connections, with Redis still at zero containers |
| `verify-after-c5-20261104-225026.md` | `df245d7` | S1, S2, S3, S8, S9, S11 and S12 pass, so the cold-start race of the earlier runs is gone. S10 failed on its own criterion, which required the idle count summed over both replicas to stay within 2 of the first cycle. Sampling starts 30 s after each fault, which is also the pool's idle timeout, so the idle count moved between 4 and 8 while no request waited. Commit `3081eca` replaced that criterion with clients in use, and the next run measures S10 again |
| `verify-after-c6-20261104-230403.md` | `044aa1e` | S1, S3, S5, S6, S7, S11 and S12 pass. S7 kept the app at 20 connections with four replicas, and admin `psql` still worked. S5 ran through the split-network override. S10 passed the clients-in-use criterion in every cycle, with 0 in use and 0 waiting, and failed on the descriptor count, which moved between 84 and 162 with no trend. That count includes the keepalive connections nginx opens and closes. Commit `f81bb10` replaced it with established connections to Postgres and Redis per replica |
| `verify-after-full-20261104-232524.md` | `c031a5f` | All twelve scenarios pass. The code is the same as `9f523dc`, and `c031a5f` only adds evidence files. This is the after column of `SOLUTION.md` |
| `verify-after-b1-20261104-235007.md` | `230c3af` | S1, S2 and S8 pass with the metrics middleware in place, p99 3.9 ms at 200 requests/s |

## Other checks

| File | What it holds |
|---|---|
| `image-gate-20261104-234508.md` | trivy and hadolint on the template and on `c031a5f`, from `scripts/image-gate.sh` |
| `monitoring-check-20261104-234826.md` | The probe alert measured end to end on `230c3af`, from `scripts/monitoring-check.sh` |
