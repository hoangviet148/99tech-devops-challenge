HOURS = 730
SECONDS = HOURS * 3600

SOURCES = {
    "EC2": ("AmazonEC2", "20261103235716", "2026-11-03"),
    "CSP": ("AWSComputeSavingsPlan", "20261104004726", "2026-11-04"),
    "EKS": ("AmazonEKS", "20261027191639", "2026-10-27"),
    "MSK": ("AmazonMSK", "20261103003605", "2026-11-03"),
    "RDS": ("AmazonRDS", "20261029070635", "2026-10-29"),
    "ECA": ("AmazonElastiCache", "20261028192450", "2026-10-28"),
    "DDB": ("AmazonDynamoDB", "20261104000705", "2026-11-04"),
    "VPC": ("AmazonVPC", "20261103000947", "2026-11-03"),
    "ELB": ("AWSELB", "20261102102527", "2026-11-02"),
    "CFR": ("AmazonCloudFront", "20261019150500", "2026-10-19"),
    "WAF": ("awswaf", "20260914163921", "2026-09-14"),
    "SHD": ("AWSShield", "20260916132208", "2026-09-16"),
    "NFW": ("AWSNetworkFirewall", "20260911124604", "2026-09-11"),
    "DTR": ("AWSDataTransfer", "20261103133147", "2026-11-03"),
    "S3": ("AmazonS3", "20261015173540", "2026-10-15"),
    "CWL": ("AmazonCloudWatch", "20261007115540", "2026-10-07"),
    "AMP": ("AmazonPrometheus", "20261014165444", "2026-10-14"),
    "AMG": ("AmazonGrafana", "20260911124432", "2026-09-11"),
    "ECR": ("AmazonECR", "20260911124425", "2026-09-11"),
    "KMS": ("awskms", "20261026201814", "2026-10-26"),
    "GDY": ("AmazonGuardDuty", "20261030005614", "2026-10-30"),
    "SHB": ("AWSSecurityHub", "20261029222727", "2026-10-29"),
    "CFG": ("AWSConfig", "20260911124534", "2026-09-11"),
    "CTR": ("AWSCloudTrail", "20261102172009", "2026-11-02"),
    "COG": ("AmazonCognito", "20261020233814", "2026-10-20"),
}

PRICES = {
    "m8g.xlarge": (0.2244, "per hour", "EC2", "APS1-BoxUsage:m8g.xlarge, Linux, shared tenancy"),
    "c8g.2xlarge": (0.36656, "per hour", "EC2", "APS1-BoxUsage:c8g.2xlarge, Linux, shared tenancy"),
    "m7g.large": (0.102, "per hour", "EC2", "APS1-BoxUsage:m7g.large, Linux, shared tenancy"),
    "csp.m8g.xlarge": (0.1671, "per hour", "CSP", "Compute Savings Plan, 1 year, no upfront, m8g.xlarge"),
    "csp.c8g.2xlarge": (0.27824, "per hour", "CSP", "Compute Savings Plan, 1 year, no upfront, c8g.2xlarge"),
    "csp.m7g.large": (0.076, "per hour", "CSP", "Compute Savings Plan, 1 year, no upfront, m7g.large"),
    "gp3": (0.096, "per GB-month", "EC2", "APS1-EBS:VolumeUsage.gp3"),
    "nat.hour": (0.059, "per hour", "EC2", "APS1-NatGateway-Hours"),
    "nat.gb": (0.059, "per GB", "EC2", "APS1-NatGateway-Bytes"),
    "eks.cluster": (0.10, "per hour", "EKS", "APS1-AmazonEKS-Hours:perCluster"),
    "msk.m7g.large": (0.255, "per broker-hour", "MSK", "APS1-Kafka.m7g.large"),
    "msk.storage": (0.12, "per GB-month", "MSK", "APS1-Kafka.Storage.GP2"),
    "msk.tiered": (0.0652, "per GB-month", "MSK", "APS1-Kafka.Storage.Tiered"),
    "aurora.r8g.large": (0.333, "per hour", "RDS", "APS1-InstanceUsage:db.r8g.large, Aurora PostgreSQL"),
    "ri.aurora.r8g.large": (0.2231, "per hour", "RDS", "Reserved, 1 year, no upfront, db.r8g.large, Aurora PostgreSQL"),
    "aurora.io.r8g.large": (0.433, "per hour", "RDS", "APS1-InstanceUsageIOOptimized:db.r8g.large"),
    "aurora.storage": (0.11, "per GB-month", "RDS", "APS1-Aurora:StorageUsage"),
    "aurora.io.storage": (0.248, "per GB-month", "RDS", "APS1-Aurora:IO-OptimizedStorageUsage"),
    "aurora.io": (0.22, "per million I/O", "RDS", "APS1-Aurora:StorageIOUsage"),
    "aurora.backup": (0.023, "per GB-month", "RDS", "APS1-Aurora:BackupUsage"),
    "valkey.m7g.large": (0.1576, "per node-hour", "ECA", "APS1-NodeUsage:cache.m7g.large, Valkey"),
    "ri.valkey.m7g.large": (0.1072, "per node-hour", "ECA", "Reserved, 1 year, no upfront, cache.m7g.large, Valkey"),
    "ddb.wru": (0.71, "per million write units", "DDB", "APS1-WriteRequestUnits"),
    "ddb.rru": (0.1425, "per million read units", "DDB", "APS1-ReadRequestUnits"),
    "vpce.hour": (0.013, "per endpoint-hour", "VPC", "APS1-VpcEndpoint-Hours"),
    "vpce.gb": (0.01, "per GB", "VPC", "APS1-VpcEndpoint-Bytes, first 1 PB"),
    "alb.hour": (0.0252, "per hour", "ELB", "APS1-LoadBalancerUsage, Application"),
    "alb.lcu": (0.008, "per LCU-hour", "ELB", "APS1-LCUUsage, Application"),
    "cf.dto.10tb": (0.12, "per GB", "CFR", "AP-DataTransfer-Out-Bytes, first 10 TB"),
    "cf.dto.50tb": (0.10, "per GB", "CFR", "AP-DataTransfer-Out-Bytes, next 40 TB"),
    "cf.https": (0.012, "per 10,000 requests", "CFR", "AP-Requests-Tier2-HTTPS"),
    "cf.origin": (0.06, "per GB", "CFR", "AP-DataTransfer-Out-OBytes, to origin"),
    "waf.acl": (5.0, "per web ACL-month", "WAF", "Global-WebACLV2"),
    "waf.rule": (1.0, "per rule-month", "WAF", "Global-RuleV2"),
    "waf.request": (0.60, "per million requests", "WAF", "Global-RequestV2-Tier0"),
    "waf.shield.request": (0.0, "per million requests", "WAF", "Global-ShieldProtected-RequestV2-Tier0"),
    "waf.bot": (10.0, "per rule group-month", "WAF", "Global-AMR-BotControl"),
    "waf.bot.request": (1.0, "per million requests above 10 million", "WAF", "Global-AMR-BotControl-Request"),
    "shield.fee": (3000.0, "per month", "SHD", "Shield-Monthly-Fee, first subscription"),
    "shield.cf.gb": (0.025, "per GB", "SHD", "Global-DataTransfer-Shield-Bytes, out of CloudFront, first 100 TB"),
    "nfw.hour": (0.395, "per endpoint-hour", "NFW", "APS1-Endpoint-Hour"),
    "nfw.gb": (0.065, "per GB", "NFW", "APS1-Traffic-GB-Processed"),
    "xaz.gb": (0.01, "per GB in each direction", "DTR", "APS1-DataTransfer-Regional-Bytes"),
    "s3.gb": (0.025, "per GB-month", "S3", "APS1-TimedStorage-ByteHrs, first 50 TB"),
    "logs.ingest": (0.70, "per GB", "CWL", "APS1-DataProcessing-Bytes, Standard class"),
    "logs.store": (0.03, "per GB-month", "CWL", "APS1-TimedStorage-ByteHrs"),
    "logs.s3": (0.35, "per GB, first 10 TB", "CWL", "APS1-S3-Egress-Bytes, logs from AWS services delivered to S3"),
    "amp.tier1": (0.90, "per 10 million samples, 40 million to 2 billion", "AMP", "APS1-AMP:MetricSampleCount"),
    "amp.tier2": (0.35, "per 10 million samples, next 250 billion", "AMP", "APS1-AMP:MetricSampleCount"),
    "amp.query": (0.10, "per billion query samples", "AMP", "APS1-AMP:QuerySamplesProcessed"),
    "amg.editor": (9.0, "per editor-month", "AMG", "APS1-Grafana:EditorUser"),
    "amg.viewer": (5.0, "per viewer-month", "AMG", "APS1-Grafana:ViewerUser"),
    "ecr.gb": (0.10, "per GB-month", "ECR", "APS1-TimedStorage-ByteHrs"),
    "kms.key": (1.0, "per key-month", "KMS", "ap-southeast-1-KMS-Keys"),
    "kms.request": (0.03, "per 10,000 requests", "KMS", "ap-southeast-1-KMS-Requests"),
    "kms.asym": (0.15, "per 10,000 requests", "KMS", "ap-southeast-1-KMS-Requests-Asymmetric"),
    "gd.events": (4.60, "per million CloudTrail events", "GDY", "APS1-PaidEventsAnalyzed"),
    "gd.logs": (1.15, "per GB, first 500 GB", "GDY", "APS1-PaidEventsAnalyzed-Bytes"),
    "gd.eks": (1.85, "per vCPU-month, first 500 vCPU", "GDY", "APS1-PaidEKSvCPUMonitored"),
    "sh.check": (0.001, "per check, first 100,000 per account", "SHB", "APS1-PaidComplianceCheck"),
    "cfg.item": (0.003, "per configuration item", "CFG", "APS1-ConfigurationItemRecorded"),
    "ct.first": (0.0, "per event, first copy of management events", "CTR", "APS1-FreeEventsRecorded"),
    "va.app": (0.35, "per application-hour", "VPC", "APS1-VerifiedAccess-App-Hours"),
    "va.gb": (0.02, "per GB", "VPC", "APS1-VerifiedAccess-DataProcess-Bytes"),
    "cognito.essentials": (0.015, "per monthly active user", "COG", "APS1-CognitoEssentialsMAU"),
    "cognito.plus": (0.02, "per monthly active user", "COG", "APS1-CognitoPlusMAU"),
}

REQUESTS = 500 * SECONDS
CACHED_SHARE = 0.60 * 0.50
ORIGIN_REQUESTS = REQUESTS * (1 - CACHED_SHARE)
REST_GB = REQUESTS * 2 / 1e6
WS_GB = 10_000 * 1 * SECONDS / 1e6
ORIGIN_GB = ORIGIN_REQUESTS * 1 / 1e6
ALB_GB = REST_GB * (1 - CACHED_SHARE) + WS_GB + ORIGIN_GB
KAFKA_GB_DAY = 1 * 86_400 / 1e3
NAT_GB = 200 + 300
BOT_REQUESTS = REQUESTS * 0.05
LEASE_OPS = 20 * SECONDS
AMP_SAMPLES = 100_000 * 2 * 60 * HOURS

ACCOUNTS = 7
MGMT_EVENTS = 5e6
TRAIL_GB = 5
FLOW_GB = 200
EKS_VCPU = 6 * 4 + 4 * 8
CHECKS_PER_ACCOUNT = 20_000
CONFIG_ITEMS = 30_000
CMK_KEYS = 6
CMK_REQUESTS = 3e6
SIGNATURES = 100_000
VA_APPS = 1
VA_GB = 10
AUDIT_GB = 400
WALLET_AZS = 2


def p(key):
    return PRICES[key][0]


def cf_dto(gb):
    first = min(gb, 10_240)
    return first * p("cf.dto.10tb") + max(gb - 10_240, 0) * p("cf.dto.50tb")


def amp(samples):
    tier1 = max(min(samples, 2e9) - 40e6, 0)
    tier2 = max(samples - 2e9, 0)
    return tier1 / 1e7 * p("amp.tier1") + tier2 / 1e7 * p("amp.tier2")


def base(area, item, qty, keys, od, disc=None, small=None):
    return {"kind": "base", "area": area, "item": item, "qty": qty, "keys": keys, "od": od,
            "disc": od if disc is None else disc, "small": od if small is None else small, "sec": 0.0}


def security(area, item, qty, keys, sec):
    return {"kind": "security", "area": area, "item": item, "qty": qty, "keys": keys, "od": 0.0, "disc": 0.0, "small": 0.0, "sec": sec}


WAF_WITH_SHIELD = p("waf.bot") + max(BOT_REQUESTS - 10e6, 0) / 1e6 * p("waf.bot.request")
WAF_WITHOUT_SHIELD = p("waf.acl") + 8 * p("waf.rule") + REQUESTS / 1e6 * p("waf.request") + WAF_WITH_SHIELD

ROWS = [
    base("Compute", "EKS control plane", "1 cluster", ["eks.cluster"], p("eks.cluster") * HOURS, small=0.0),
    base("Compute", "Stateless pool", "6 x m8g.xlarge (4 vCPU, 16 GiB), 2 per AZ", ["m8g.xlarge", "csp.m8g.xlarge"],
         6 * HOURS * p("m8g.xlarge"), 6 * HOURS * p("csp.m8g.xlarge")),
    base("Compute", "Matching and risk pool", "4 x c8g.2xlarge (8 vCPU, 16 GiB), CPU pinning, spread 2, 1, 1",
         ["c8g.2xlarge", "csp.c8g.2xlarge"], 4 * HOURS * p("c8g.2xlarge"), 4 * HOURS * p("csp.c8g.2xlarge")),
    base("Compute", "Node root volumes", "10 x 50 GB gp3", ["gp3"], 10 * 50 * p("gp3")),
    base("Compute", "Image registry", "50 GB in ECR", ["ecr.gb"], 50 * p("ecr.gb")),
    base("Event log", "MSK brokers", "3 x kafka.m7g.large, one per AZ", ["msk.m7g.large"], 3 * HOURS * p("msk.m7g.large")),
    base("Event log", "MSK broker storage", "3 x 1,000 GB for 7 days of 1 MB/s at replication factor 3", ["msk.storage"],
         3 * 1_000 * p("msk.storage")),
    base("Event log", "MSK tiered storage", f"35 days of 1 MB/s, {35 * KAFKA_GB_DAY:,.0f} GB", ["msk.tiered"],
         35 * KAFKA_GB_DAY * p("msk.tiered")),
    base("Ledger", "Aurora PostgreSQL instances", "1 writer and 2 readers, db.r8g.large, Aurora Standard",
         ["aurora.r8g.large", "ri.aurora.r8g.large"], 3 * HOURS * p("aurora.r8g.large"), 3 * HOURS * p("ri.aurora.r8g.large")),
    base("Ledger", "Aurora storage and I/O", "200 GB, 300 million I/O per month", ["aurora.storage", "aurora.io"],
         200 * p("aurora.storage") + 300 * p("aurora.io")),
    base("Ledger", "Aurora backup above the free allocation", "350 GB for 35 days of point-in-time recovery",
         ["aurora.backup"], 350 * p("aurora.backup")),
    base("Cache", "ElastiCache for Valkey", "1 primary and 2 replicas, cache.m7g.large", ["valkey.m7g.large", "ri.valkey.m7g.large"],
         3 * HOURS * p("valkey.m7g.large"), 3 * HOURS * p("ri.valkey.m7g.large"), 2 * HOURS * p("valkey.m7g.large")),
    base("Leases", "DynamoDB on demand", "20 lease writes and 20 reads per second", ["ddb.wru", "ddb.rru"],
         LEASE_OPS / 1e6 * (p("ddb.wru") + p("ddb.rru"))),
    base("Identity", "Cognito user pools, Essentials plan", "`<MAU>` monthly active users", ["cognito.essentials"],
         "`<MAU>` x 0.015"),
    base("Edge", "CloudFront requests", f"{REQUESTS / 1e9:.3f} billion HTTPS requests", ["cf.https"], REQUESTS / 1e4 * p("cf.https")),
    base("Edge", "CloudFront data transfer out", f"{REST_GB:,.0f} GB REST and {WS_GB:,.0f} GB WebSocket",
         ["cf.dto.10tb", "cf.dto.50tb"], cf_dto(REST_GB + WS_GB)),
    base("Edge", "CloudFront to origin", f"{ORIGIN_GB:,.0f} GB of forwarded requests", ["cf.origin"], ORIGIN_GB * p("cf.origin")),
    base("Edge", "AWS WAF with Shield Advanced",
         "web ACL, rules and requests at the Shield-protected rates, Bot Control on 5 % of requests",
         ["waf.shield.request", "waf.bot", "waf.bot.request", "waf.acl", "waf.rule", "waf.request"],
         WAF_WITH_SHIELD + REQUESTS / 1e6 * p("waf.shield.request"), small=WAF_WITHOUT_SHIELD),
    base("Edge", "Shield Advanced", "subscription and data transfer out of CloudFront", ["shield.fee", "shield.cf.gb"],
         p("shield.fee") + (REST_GB + WS_GB) * p("shield.cf.gb"), small=0.0),
    base("Edge", "Application Load Balancer", f"1 ALB, {ALB_GB / HOURS:.1f} LCU from processed bytes", ["alb.hour", "alb.lcu"],
         HOURS * (p("alb.hour") + ALB_GB / HOURS * p("alb.lcu"))),
    base("Network", "NAT gateways", f"3, one per AZ, {NAT_GB} GB processed", ["nat.hour", "nat.gb"],
         3 * HOURS * p("nat.hour") + NAT_GB * p("nat.gb")),
    base("Network", "Network Firewall", f"3 endpoints, {NAT_GB} GB inspected", ["nfw.hour", "nfw.gb"],
         3 * HOURS * p("nfw.hour") + NAT_GB * p("nfw.gb")),
    base("Network", "Interface endpoints", "ECR API, ECR Docker, STS, KMS, Secrets Manager in 3 AZs, 100 GB",
         ["vpce.hour", "vpce.gb"], 5 * 3 * HOURS * p("vpce.hour") + 100 * p("vpce.gb")),
    base("Network", "Cross-AZ traffic", "6,000 GB in each direction", ["xaz.gb"], 6_000 * 2 * p("xaz.gb")),
    base("Observability", "CloudWatch Logs", "5 GB per day ingested, 30 days kept", ["logs.ingest", "logs.store"],
         5 * HOURS / 24 * (p("logs.ingest") + p("logs.store"))),
    base("Observability", "Managed Prometheus",
         f"100,000 active series every 30 s, {AMP_SAMPLES / 1e9:.2f} billion samples, 50 billion query samples",
         ["amp.tier1", "amp.tier2", "amp.query"], amp(AMP_SAMPLES) + 50 * p("amp.query")),
    base("Observability", "Managed Grafana", "5 editors, 20 viewers", ["amg.editor", "amg.viewer"],
         5 * p("amg.editor") + 20 * p("amg.viewer")),
    base("Backup", "Vault locked in compliance mode in the backup account", "540 GB of Aurora copies over 35 days",
         ["aurora.backup"], 540 * p("aurora.backup")),
    base("Backup", "Engine snapshots in S3 with Object Lock", "200 GB for 7 days of 60 s snapshots", ["s3.gb"], 200 * p("s3.gb")),
    base("Wallet", "Signer and watcher hosts", "2 x m7g.large in the wallet account", ["m7g.large", "csp.m7g.large"],
         2 * HOURS * p("m7g.large"), 2 * HOURS * p("csp.m7g.large")),
    base("Wallet", "KMS keys", "4 hot wallet keys", ["kms.key"], 4 * p("kms.key")),
    security("SC-01 custody", "KMS endpoint in the wallet account", f"1 interface endpoint in {WALLET_AZS} AZs",
             ["vpce.hour"], WALLET_AZS * HOURS * p("vpce.hour")),
    security("SC-01 custody", "KMS signing requests", f"{SIGNATURES:,} withdrawal signatures", ["kms.asym"],
             SIGNATURES / 1e4 * p("kms.asym")),
    security("SC-05 admin plane", "Verified Access", f"{VA_APPS} application, {VA_GB} GB", ["va.app", "va.gb"],
             VA_APPS * HOURS * p("va.app") + VA_GB * p("va.gb")),
    security("SC-09 encryption", "Customer managed KMS keys", f"{CMK_KEYS} keys, one per data class", ["kms.key"],
             CMK_KEYS * p("kms.key")),
    security("SC-09 encryption", "KMS requests on customer managed keys", f"{CMK_REQUESTS / 1e6:.0f} million requests",
             ["kms.request"], CMK_REQUESTS / 1e4 * p("kms.request")),
    security("SC-11 detection", "Organization CloudTrail", "first copy of management events in every account",
             ["ct.first"], MGMT_EVENTS * p("ct.first")),
    security("SC-11 detection", "GuardDuty CloudTrail analysis", f"{MGMT_EVENTS / 1e6:.0f} million management events",
             ["gd.events"], MGMT_EVENTS / 1e6 * p("gd.events")),
    security("SC-11 detection", "GuardDuty flow and DNS log analysis", f"{FLOW_GB} GB", ["gd.logs"], FLOW_GB * p("gd.logs")),
    security("SC-11 detection", "GuardDuty Runtime Monitoring for EKS", f"{EKS_VCPU} vCPUs of production EKS nodes",
             ["gd.eks"], EKS_VCPU * p("gd.eks")),
    security("SC-11 detection", "Security Hub CSPM", f"{CHECKS_PER_ACCOUNT:,} checks in each of {ACCOUNTS} accounts",
             ["sh.check"], ACCOUNTS * CHECKS_PER_ACCOUNT * p("sh.check")),
    security("SC-11 detection", "AWS Config", f"{CONFIG_ITEMS:,} configuration items", ["cfg.item"], CONFIG_ITEMS * p("cfg.item")),
    security("SC-11 detection", "VPC Flow Logs delivered to S3", f"{FLOW_GB} GB", ["logs.s3"], FLOW_GB * p("logs.s3")),
    security("SC-11 detection", "Log storage in S3 with Object Lock",
             f"{TRAIL_GB + FLOW_GB + AUDIT_GB} GB added per month: trail files, flow logs, audit log", ["s3.gb"],
             (TRAIL_GB + FLOW_GB + AUDIT_GB) * p("s3.gb")),
    security("SC-22 identity", "Cognito Plus over Essentials", "`<MAU>` monthly active users", ["cognito.plus", "cognito.essentials"],
             "`<MAU>` x 0.005"),
]


def money(x):
    return f"{x:,.2f}" if isinstance(x, float) or isinstance(x, int) else x


def units(row):
    parts = []
    for key in row["keys"]:
        usd, unit, src, _ = PRICES[key]
        parts.append(f"{usd:g} {unit} ({SOURCES[src][2]})")
    return ", ".join(parts)


def total(column):
    return sum(r[column] for r in ROWS if isinstance(r[column], (int, float)))


def main():
    print("# Monthly cost estimate for ap-southeast-1")
    print()
    print("Generated by `python3 -I cost_estimate.py`. Quantities are the assumptions of section 2.3 of `SOLUTION.md`. Prices come from the AWS price list files named in the second table, read on 2026-11-04 for the base design and on 2026-11-05 for the security column. A month is 730 hours. Cells written as `<MAU>` times a price are placeholders, and the totals leave them out.")
    print()
    print("| Area | Item | Quantity (assumption) | Unit prices, USD (price list date) | On demand USD per month | With eligible discounts | Smaller baseline | Security column |")
    print("|---|---|---|---|---|---|---|---|")
    for r in ROWS:
        print(f"| {r['area']} | {r['item']} | {r['qty']} | {units(r)} | {money(r['od'])} | {money(r['disc'])} | {money(r['small'])} | {money(r['sec'])} |")
    od, disc, small, sec = total("od"), total("disc"), total("small"), total("sec")
    print(f"| Total | | | | {money(od)} | {money(disc)} | {money(small)} | {money(sec)} |")
    print(f"| Total with the security column | | | | {money(od + sec)} | {money(disc + sec)} | {money(small + sec)} | |")
    print()
    print("| Price key | USD | Unit | Usage type or term | Offer file version | Published |")
    print("|---|---|---|---|---|---|")
    for key, (usd, unit, src, usage) in PRICES.items():
        offer, version, date = SOURCES[src]
        print(f"| {key} | {usd:g} | {unit} | {usage} | {offer} {version} | {date} |")
    print()
    io_extra = 3 * HOURS * (p("aurora.io.r8g.large") - p("aurora.r8g.large")) + 200 * (p("aurora.io.storage") - p("aurora.storage"))
    endpoint_month = 3 * HOURS * p("vpce.hour")
    print("| Derived figure | Value |")
    print("|---|---|")
    print(f"| Requests per month at 500 requests/s | {REQUESTS:,.0f} |")
    print(f"| GB through the ALB per month | {ALB_GB:,.0f} |")
    print(f"| Aurora I/O per month above which I/O-Optimized costs less, in millions | {io_extra / p('aurora.io'):,.0f} |")
    print(f"| One interface endpoint in 3 AZs, USD per month | {endpoint_month:.2f} |")
    print(f"| Traffic per month above which that endpoint costs less than NAT, GB | {endpoint_month / (p('nat.gb') - p('vpce.gb')):,.0f} |")
    print(f"| CloudFront and Shield data transfer change per 0.1 KB/s of WebSocket traffic per connection, USD per month | {WS_GB / 10 * (p('cf.dto.50tb') + p('shield.cf.gb')):,.2f} |")
    by_area = {}
    for r in ROWS:
        if r["kind"] == "base" and isinstance(r["od"], float):
            by_area[r["area"]] = by_area.get(r["area"], 0.0) + r["od"]
    for area, value in by_area.items():
        print(f"| Share of the on-demand total, {area} | {value / od * 100:.1f} % |")
    print(f"| Saving from eligible discounts, USD per month | {od - disc:,.2f} ({(od - disc) / od * 100:.1f} %) |")
    waf = next(r for r in ROWS if r["item"] == "AWS WAF with Shield Advanced")
    shield = next(r for r in ROWS if r["item"] == "Shield Advanced")
    print(f"| Shield Advanced net of the WAF fees it removes, USD per month | {shield['od'] + waf['od'] - waf['small']:,.2f} |")
    print(f"| Smaller baseline below the design, USD per month | {od - small:,.2f} |")
    telemetry = sum(r["od"] for r in ROWS if r["area"] == "Observability")
    print(f"| Observability lines, USD per month | {telemetry:,.2f} ({telemetry / od * 100:.1f} %) |")
    print(f"| Security column against the on-demand total | {sec / od * 100:.1f} % |")
    detection = sum(r["sec"] for r in ROWS if r["area"] == "SC-11 detection" and isinstance(r["sec"], float))
    print(f"| SC-11 detection lines, USD per month | {detection:,.2f} |")


if __name__ == "__main__":
    main()
