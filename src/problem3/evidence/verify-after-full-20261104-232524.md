# verify.sh results, profile after

| Field | Value |
|---|---|
| Run | 20261104-232524 |
| Stack | `src/problem3` at commit `c031a5f`, clean working tree |
| Docker | 29.4.0 on linux/arm64, Compose 5.1.2 |

| ID | Scenario | Result | Measured |
|---|---|---|---|
| S1 | GET /api/users through nginx | PASS | HTTP 200 |
| S2 | 200 requests/s for 60 s, dependencies healthy | PASS | 12001 requests, 0 failed, 0 dropped, p99 5.2 ms |
| S3 | Postgres restart under load, 5 times | PASS | replicas running 2 of 2, restarts 0. c1: outage 456 ms, 0 errors outside the window. c2: outage 565 ms, 0 errors outside the window. c3: outage 758 ms, 0 errors outside the window. c4: outage 608 ms, 0 errors outside the window. c5: outage 735 ms, 0 errors outside the window. |
| S4 | Postgres paused for 15 s under load | PASS | slowest response while paused 1906 ms, statuses while paused 503=2476 , errors from 5 s after unpause 0 |
| S5 | Redis stopped, paused and blackholed | PASS |  stop: p99 3.3 ms, 0 non-200. pause: p99 3.8 ms, 0 non-200. hole: p99 3.7 ms, 0 non-200. |
| S6 | Every API replica recreated while placeholders hold the old IPs | PASS | old IPs 192.168.207.2 192.168.207.3 , new IPs 192.168.207.5 192.168.207.6 , first 200 after 32 ms |
| S7 | 4 replicas, 120 concurrent clients for 60 s | PASS | 588920 requests, 0 failed, 0 too-many-clients log lines, app connections max 20, admin psql yes |
| S8 | kill -9 on one of two replicas under load | PASS | error rate in the 10 s after the kill 0.00 % (0 of 2000), restarts 1, rejoined after 6131 ms, errors after rejoin 0 |
| S9 | docker stop on one replica, healthy and with Postgres paused | PASS | healthy: stop took 422 ms, exit 0, 0 non-200 during the stop. Postgres paused: stop took 392 ms, exit 0 |
| S10 | Pool health across the 5 faults of S3 | PASS |  c1: fresh 200, pool total max 4, waiting 0, in use 0, Postgres sockets per replica max 5, Redis sockets max 1, RSS 154504 kB, fds 85. c2: fresh 200, pool total max 2, waiting 0, in use 0, Postgres sockets per replica max 3, Redis sockets max 1, RSS 106844 kB, fds 81. c3: fresh 200, pool total max 2, waiting 0, in use 0, Postgres sockets per replica max 3, Redis sockets max 1, RSS 107300 kB, fds 79. c4: fresh 200, pool total max 4, waiting 0, in use 0, Postgres sockets per replica max 5, Redis sockets max 1, RSS 97940 kB, fds 128. c5: fresh 200, pool total max 2, waiting 0, in use 0, Postgres sockets per replica max 3, Redis sockets max 1, RSS 99348 kB, fds 76. |
| S11 | Cold start, fresh volume and existing volume | PASS | first request after start: fresh volume HTTP 200, existing volume HTTP 200 |
| S12 | Cold start with Redis scaled to 0 | PASS | HTTP 200 after 39 ms, Redis containers 0 |
