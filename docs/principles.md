# AWS Well-Architected design principles

The IDs are local to this submission. Each name quotes a design principle of the AWS Well-Architected Framework or of its Financial Services Industry Lens, as published on docs.aws.amazon.com and read on 2026-11-04. An AWS best practice ID such as `SEC02-BP02` appears only where a `SOLUTION.md` cites one specific best practice.

| Problem | Sets cited by its decision records or its traceability table | Focus |
|---|---|---|
| 1 | All sets | Every pillar gets a row in the Well-Architected review of `src/problem1/SOLUTION.md` |
| 2 | OPS, REL, SEC, COST and GEN | The runbook and prevention |
| 3 | REL, OPS, SEC and GEN | The stack and its operation |
| 4 | OPS, SEC, REL, FSI and GEN | The delivery pipeline |
| 5 | SEC, FSI, OPS, REL, PERF, COST and GEN | SEC and FSI lead, and REL, PERF and COST check that the changes keep REQ-P5-6 |

Problem 1's Well-Architected review names the principles its decisions trade off or leave to Problem 5. The other problems cite a principle only where a decision applies it or works against it, in the Principles field or the text of a decision record or in a row of the traceability table. `tools/trace_check.py` fails when this table and those citations disagree.

| ID | Principle | Set |
|---|---|---|
| GEN-DP1 | "Stop guessing your capacity needs" | General |
| GEN-DP2 | "Test systems at production scale" | General |
| GEN-DP3 | "Automate with architectural experimentation in mind" | General |
| GEN-DP4 | "Consider evolutionary architectures" | General |
| GEN-DP5 | "Drive architectures using data" | General |
| GEN-DP6 | "Improve through game days" | General |
| OPS-DP1 | "Organize teams around business outcomes" | Operational excellence |
| OPS-DP2 | "Implement observability for actionable insights" | Operational excellence |
| OPS-DP3 | "Safely automate where possible" | Operational excellence |
| OPS-DP4 | "Make frequent, small, reversible changes" | Operational excellence |
| OPS-DP5 | "Refine operations procedures frequently" | Operational excellence |
| OPS-DP6 | "Anticipate failure" | Operational excellence |
| OPS-DP7 | "Learn from all operational events and metrics" | Operational excellence |
| OPS-DP8 | "Use managed services" | Operational excellence |
| SEC-DP1 | "Implement a strong identity foundation" | Security |
| SEC-DP2 | "Maintain traceability" | Security |
| SEC-DP3 | "Apply security at all layers" | Security |
| SEC-DP4 | "Automate security best practices" | Security |
| SEC-DP5 | "Protect data in transit and at rest" | Security |
| SEC-DP6 | "Keep people away from data" | Security |
| SEC-DP7 | "Prepare for security events" | Security |
| REL-DP1 | "Automatically recover from failure" | Reliability |
| REL-DP2 | "Test recovery procedures" | Reliability |
| REL-DP3 | "Scale horizontally to increase aggregate workload availability" | Reliability |
| REL-DP4 | "Stop guessing capacity" | Reliability |
| REL-DP5 | "Manage change through automation" | Reliability |
| PERF-DP1 | "Democratize advanced technologies" | Performance efficiency |
| PERF-DP2 | "Go global in minutes" | Performance efficiency |
| PERF-DP3 | "Use serverless architectures" | Performance efficiency |
| PERF-DP4 | "Experiment more often" | Performance efficiency |
| PERF-DP5 | "Consider mechanical sympathy" | Performance efficiency |
| COST-DP1 | "Implement Cloud Financial Management" | Cost optimization |
| COST-DP2 | "Adopt a consumption model" | Cost optimization |
| COST-DP3 | "Measure overall efficiency" | Cost optimization |
| COST-DP4 | "Stop spending money on undifferentiated heavy lifting" | Cost optimization |
| COST-DP5 | "Analyze and attribute expenditure" | Cost optimization |
| SUS-DP1 | "Understand your impact" | Sustainability |
| SUS-DP2 | "Establish sustainability goals" | Sustainability |
| SUS-DP3 | "Maximize utilization" | Sustainability |
| SUS-DP4 | "Anticipate and adopt new, more efficient hardware and software offerings" | Sustainability |
| SUS-DP5 | "Use managed services" | Sustainability |
| SUS-DP6 | "Reduce the downstream impact of your cloud workloads" | Sustainability |
| FSI-DP1 | "Documented operational planning" | Financial Services Industry Lens |
| FSI-DP2 | "Automated infrastructure and application deployment" | Financial Services Industry Lens |
| FSI-DP3 | "Security by design" | Financial Services Industry Lens |
| FSI-DP4 | "Automated governance" | Financial Services Industry Lens |
