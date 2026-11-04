# Requirements

Every requirement of the challenge has an ID here, and every decision record cites the IDs it serves. IDs ending in `A` are derived by this submission from an assumption, and the problem's `SOLUTION.md` states the basis. `tools/trace_check.py` fails when a requirement has no decision record or no traceability row.

| ID | Requirement | Source | Answered in |
|---|---|---|---|
| REQ-G1 | Solutions are attached or linked and can be viewed without pain. Unzipping counts as pain | Instructions |  |
| REQ-G2 | Uncertainties are noted and assumptions are declared | Instructions |  |
| REQ-G3 | Every problem is at least attempted | Instructions |  |
| REQ-G4 | Work starts from the template repo, which must not be forked | Instructions, template README |  |
| REQ-P1-1 | A highly available trading system with features similar to Binance, using a chosen subset of features | Task | `src/problem1` |
| REQ-P1-2 | Resilient to failures | Task | `src/problem1` |
| REQ-P1-3 | Scalable | Task | `src/problem1` |
| REQ-P1-4 | Cost-effective | Task | `src/problem1` |
| REQ-P1-5 | The approach to high availability and scalability is explained | Task | `src/problem1` |
| REQ-P1-6 | AWS is the cloud provider | Specification | `src/problem1` |
| REQ-P1-7 | 500 requests per second | Specification | `src/problem1` |
| REQ-P1-8 | p99 response time under 100 ms | Specification | `src/problem1` |
| REQ-P1-9 | Overview diagram of the services and the role each plays | Deliverable | `src/problem1` |
| REQ-P1-10 | Why each cloud service is used and which alternatives were considered | Deliverable | `src/problem1` |
| REQ-P1-11 | Plans for scaling once the product outgrows the current setup | Deliverable | `src/problem1` |
| REQ-P1-12A | 99.95 % availability objective for the trading API | Assumption, `src/problem1/SOLUTION.md` | `src/problem1` |
| REQ-P1-13A | AZ loss: no acknowledged data lost, trading back within 1 min. Region loss: objectives set after the first DR exercise, trading halted until a person decides | Assumption, `src/problem1/SOLUTION.md` | `src/problem1` |
| REQ-P1-14A | Spendable balances never go negative, no trade settles twice, matching is deterministic per symbol | Assumption, `src/problem1/SOLUTION.md` | `src/problem1` |
| REQ-P1-15A | REQ-P1-8 applies per request class, measured from a load generator inside the region through the public hostname, with CloudFront and WAF in the path. It holds at a fixed 500 rps and at a 3x plateau (1500 rps) reached by a 5 min ramp, once autoscaling has converged. During convergence up to 1 % of requests may be shed with 429, for at most 5 min | Assumption, `src/problem1/SOLUTION.md` | `src/problem1` |
| REQ-P1-16A | Order-to-match p99 under 20 ms from durable acceptance to the committed match, and trade-to-settlement p99 under 1 s from the committed match to the ledger commit | Assumption, `src/problem1/SOLUTION.md` | `src/problem1` |
| REQ-P2-1 | Steps to troubleshoot the production issues on the VM | Task | `src/problem2` |
| REQ-P2-2 | The causes and scenarios expected | Challenge | `src/problem2` |
| REQ-P2-3 | The impact of each possible root cause | Challenge | `src/problem2` |
| REQ-P2-4 | Recovery steps for each possible root cause | Challenge | `src/problem2` |
| REQ-P2-5 | Context: Ubuntu 24.04, 64 GB of storage, 99 % usage, NGINX load balancer as the only service | Scenario | `src/problem2` |
| REQ-P3-1 | Identify the issues | README | `src/problem3` |
| REQ-P3-2 | Fix them | README | `src/problem3` |
| REQ-P3-3 | Explain the root causes | README | `src/problem3` |
| REQ-P3-4 | Report the problems found, how they were diagnosed, the fixes, the monitoring and alerts to add, and how to prevent this in production | README | `src/problem3` |
| REQ-P3-5 | The stack runs with `docker compose up --build` and serves on port 8080 | README | `src/problem3` |
| REQ-P4-1 | CI/CD for the backend HTTP API deployed to EC2 | Context | `src/problem4` |
| REQ-P4-2 | CI/CD for the frontend SPA deployed to S3 | Context | `src/problem4` |
| REQ-P4-3 | The pipelines use GitHub Actions | Context | `src/problem4` |
| REQ-P4-4 | Decide what production ready means and make the pipelines meet it | Task | `src/problem4` |
| REQ-P4-5 | No real AWS account is needed. Whatever cannot run is implemented faithfully with an explanation of what it would do | Task | `src/problem4` |
| REQ-P4-6 | Workflows, supporting files, and `SOLUTION.md` with the assumptions and why, how the pipelines work, and what was left out | Submission | `src/problem4` |
| REQ-P5-1 | The Problem 1 architecture is made secure, with security integrated into the design | Task | `src/problem5` |
| REQ-P5-2 | Show where the design changed, where something was added and where the risk was accepted as it stood | Task | `src/problem5` |
| REQ-P5-3 | State what is secured first, what is deferred and what would block shipping | Task | `src/problem5` |
| REQ-P5-4 | For each missing fact: what is needed, how to get it and what was assumed meanwhile | Task | `src/problem5` |
| REQ-P5-5 | `SOLUTION.md` with the updated architecture and the changes marked, why each change exists and what it protects against, and what was left out with the trade-offs | Submission | `src/problem5` |
| REQ-P5-6 | Every Problem 1 requirement still holds after the security changes | Derived from REQ-P5-1, which starts from the Problem 1 design | `src/problem5` |
