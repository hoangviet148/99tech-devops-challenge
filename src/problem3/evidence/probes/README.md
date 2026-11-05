# Diagnosis probes

These files reproduce the findings F0 to F12 of `SOLUTION.md` on the untouched template. Every command runs from a checkout of the template at `src/problem3`, with the project name `p3`. A probe changes one thing at a time and lives outside the template files, so the template itself stays unmodified.

| File | Used by | What it changes |
|---|---|---|
| `before-port-fix.yml` with `nginx-port-fix/` | F0, F5, matched baseline runs except S1 | nginx proxies to port 3000 instead of 3001 |
| `before-pool-listener.yml` with `api-pool-listener/index.js` | F3 | Adds only `pool.on("error")` to the template API |
| `before-init-sql.yml` | F8, matched baseline of S7 | Mounts the template `postgres/init.sql` into the init directory |

The compose overrides read `P3_PROBE_DIR`, so set it to this folder before using them:

```bash
export P3_PROBE_DIR="$PWD/evidence/probes"
```

## Commands per finding

| Finding | Command | Observed on 2026-11-04 |
|---|---|---|
| F1 | `docker compose -p p3 up -d --build`, then `curl -s -o /dev/null -w '%{http_code}' http://localhost:8080/api/users` and `docker compose -p p3 logs nginx` | 502, `connect() failed (111: Connection refused)` to port 3001. Inside the API container, `wget -qO- http://localhost:3000/api/users` returns `{"ok":true,...}` |
| F2, F4 | One request to `/api/users`, then `docker restart p3-postgres-1` and `docker ps -a --filter name=p3-api-1` | The API exits with code 1 and `Unhandled 'error' event`. `docker inspect -f '{{.HostConfig.RestartPolicy.Name}}' p3-api-1` prints `no` |
| F3 | Add `-f evidence/probes/before-pool-listener.yml`, load with `ab -c 50 -n 200000`, restart Postgres after 3 s | Query errors at `index.js:21`, then `read ECONNRESET` with `Emitted 'error' event on Client instance`, and the API exits |
| F0, F5 | Add `-f evidence/probes/before-port-fix.yml`. F0: `ab -c 50 -n 5000 http://localhost:8080/api/users`. F5: remove the API container, start a placeholder container on the network so it takes the freed IP, start the API again | F0: 0 failed, p99 44 ms. F5: the API moves to a new IP, nginx keeps the old one and answers 502 until `docker compose restart nginx` |
| F6 | `docker pause p3-postgres-1`, then `wget -T 15` inside the API container | No response before the 15 s client timeout |
| F7 | `docker stop p3-redis-1`, then `time wget` inside the API container | HTTP 500 after 20.66 s |
| F8 | `docker compose down -v`, then up with `-f evidence/probes/before-port-fix.yml -f evidence/probes/before-init-sql.yml --scale api=3`, then `ab -c 100 -n 20000` | `max_connections` is 20, 39 non-2xx with `sorry, too many clients already`, admin `psql` refused |
| F9 | `time docker stop p3-api-1` | 11 s, exit code 137 |
| F10 | `docker inspect` on every container, `curl http://localhost:8080/status` | No healthcheck anywhere, `/status` through nginx returns 404 |
| F11 | `docker run --rm <image> node -v`, `nginx -v`, and `trivy image --severity HIGH,CRITICAL` per image | Node v20.20.2, nginx 1.25.5. HIGH/CRITICAL: nginx 179/21, api 25/1, postgres 87/2, redis 32/1 |
| F12 | Read `api/src/index.js`, `docker-compose.yml`, `nginx/nginx.conf`, `.env` and `docker inspect p3-postgres-1` | Credentials in code and compose, empty files, `err.message` in responses, an anonymous data volume |

The matched before and after runs use `scripts/verify-before.sh` and `scripts/verify.sh`, which apply the same overrides automatically.
