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
