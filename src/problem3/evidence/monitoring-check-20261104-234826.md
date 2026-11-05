# Monitoring check

| Field | Value |
|---|---|
| Stack | `src/problem3` at commit `230c3af` |
| Scrape targets up | 3 (two API replicas and the probe) after 2128 ms |
| Histogram bucket series on one replica | 33 |
| Alert rules loaded | 5 |
| ApiProbeFailing firing after nginx stopped | 43105 ms |
| ApiProbeFailing cleared after nginx started | 27984 ms |
