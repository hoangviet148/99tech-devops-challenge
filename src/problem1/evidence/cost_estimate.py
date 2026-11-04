HOURS = 730
SECONDS = HOURS * 3600
FIRST_READ = "2026-11-04"
SECOND_READ = "2026-11-05"

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
    "GDA": ("AmazonS3GlacierDeepArchive", "20260911124507", "2026-09-11"),
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
    "m8g.xlarge": (0.2244, "per hour", "EC2", "APS1-BoxUsage:m8g.xlarge, Linux, shared tenancy", FIRST_READ),
    "c8g.2xlarge": (0.36656, "per hour", "EC2", "APS1-BoxUsage:c8g.2xlarge, Linux, shared tenancy", FIRST_READ),
    "m7g.large": (0.102, "per hour", "EC2", "APS1-BoxUsage:m7g.large, Linux, shared tenancy", FIRST_READ),
    "csp.m8g.xlarge": (0.1671, "per hour", "CSP", "Compute Savings Plan, 1 year, no upfront, m8g.xlarge", FIRST_READ),
    "csp.c8g.2xlarge": (0.27824, "per hour", "CSP", "Compute Savings Plan, 1 year, no upfront, c8g.2xlarge", FIRST_READ),
    "csp.m7g.large": (0.076, "per hour", "CSP", "Compute Savings Plan, 1 year, no upfront, m7g.large", FIRST_READ),
    "gp3": (0.096, "per GB-month", "EC2", "APS1-EBS:VolumeUsage.gp3", FIRST_READ),
    "nat.hour": (0.059, "per hour", "EC2", "APS1-NatGateway-Hours", FIRST_READ),
    "nat.gb": (0.059, "per GB", "EC2", "APS1-NatGateway-Bytes", FIRST_READ),
    "eks.cluster": (0.10, "per hour", "EKS", "APS1-AmazonEKS-Hours:perCluster", FIRST_READ),
    "msk.m7g.large": (0.255, "per broker-hour", "MSK", "APS1-Kafka.m7g.large", FIRST_READ),
    "msk.storage": (0.12, "per GB-month", "MSK", "APS1-Kafka.Storage.GP2", FIRST_READ),
    "msk.tiered": (0.0652, "per GB-month", "MSK", "APS1-Kafka.Storage.Tiered", FIRST_READ),
    "msk.replicator": (0.36, "per Replicator-hour", "MSK", "APS1-KafkaReplication-ReplicatorHours", SECOND_READ),
    "msk.replicator.gb": (0.10, "per GB processed", "MSK", "APS1-KafkaReplication-Processed-Bytes, cross-Region source", SECOND_READ),
    "msk.private.hour": (0.0252, "per hour per authentication scheme", "MSK", "APS1-Kafka.PrivateConnectivityHours", SECOND_READ),
    "msk.private.gb": (0.006, "per GB", "MSK", "APS1-Kafka.PrivateConnectivity.BytesProcessed", SECOND_READ),
    "aurora.r8g.large": (0.333, "per hour", "RDS", "APS1-InstanceUsage:db.r8g.large, Aurora PostgreSQL", FIRST_READ),
    "ri.aurora.r8g.large": (0.2231, "per hour", "RDS", "Reserved, 1 year, no upfront, db.r8g.large, Aurora PostgreSQL", FIRST_READ),
    "aurora.io.r8g.large": (0.433, "per hour", "RDS", "APS1-InstanceUsageIOOptimized:db.r8g.large", FIRST_READ),
    "aurora.storage": (0.11, "per GB-month", "RDS", "APS1-Aurora:StorageUsage", FIRST_READ),
    "aurora.io.storage": (0.248, "per GB-month", "RDS", "APS1-Aurora:IO-OptimizedStorageUsage", FIRST_READ),
    "aurora.io": (0.22, "per million I/O", "RDS", "APS1-Aurora:StorageIOUsage", FIRST_READ),
    "aurora.backup": (0.023, "per GB-month", "RDS", "APS1-Aurora:BackupUsage, also the AWS Backup price of Aurora snapshots", FIRST_READ),
    "aurora.replicated": (0.22, "per million replicated write I/O", "RDS", "APS1-Aurora:ReplicatedWriteIO, Aurora PostgreSQL", SECOND_READ),
    "valkey.m7g.large": (0.1576, "per node-hour", "ECA", "APS1-NodeUsage:cache.m7g.large, Valkey", FIRST_READ),
    "ri.valkey.m7g.large": (0.1072, "per node-hour", "ECA", "Reserved, 1 year, no upfront, cache.m7g.large, Valkey", FIRST_READ),
    "ddb.wru": (0.71, "per million write units", "DDB", "APS1-WriteRequestUnits", FIRST_READ),
    "ddb.rru": (0.1425, "per million read units", "DDB", "APS1-ReadRequestUnits", FIRST_READ),
    "vpce.hour": (0.013, "per endpoint-hour", "VPC", "APS1-VpcEndpoint-Hours", FIRST_READ),
    "vpce.gb": (0.01, "per GB", "VPC", "APS1-VpcEndpoint-Bytes, first 1 PB", FIRST_READ),
    "alb.hour": (0.0252, "per hour", "ELB", "APS1-LoadBalancerUsage, Application", FIRST_READ),
    "alb.lcu": (0.008, "per LCU-hour", "ELB", "APS1-LCUUsage, Application", FIRST_READ),
    "nlb.hour": (0.0252, "per hour", "ELB", "APS1-LoadBalancerUsage, Network", SECOND_READ),
    "nlb.lcu": (0.006, "per NLCU-hour", "ELB", "APS1-LCUUsage, Network", SECOND_READ),
    "cf.dto.10tb": (0.12, "per GB", "CFR", "AP-DataTransfer-Out-Bytes, first 10 TB", FIRST_READ),
    "cf.dto.50tb": (0.10, "per GB", "CFR", "AP-DataTransfer-Out-Bytes, next 40 TB", FIRST_READ),
    "cf.https": (0.012, "per 10,000 requests", "CFR", "AP-Requests-Tier2-HTTPS", FIRST_READ),
    "cf.origin": (0.06, "per GB", "CFR", "AP-DataTransfer-Out-OBytes, to origin", FIRST_READ),
    "waf.acl": (5.0, "per web ACL-month", "WAF", "Global-WebACLV2", FIRST_READ),
    "waf.rule": (1.0, "per rule-month", "WAF", "Global-RuleV2", FIRST_READ),
    "waf.request": (0.60, "per million requests", "WAF", "Global-RequestV2-Tier0", FIRST_READ),
    "waf.shield.request": (0.0, "per million requests", "WAF", "Global-ShieldProtected-RequestV2-Tier0", FIRST_READ),
    "waf.bot": (10.0, "per rule group-month", "WAF", "Global-AMR-BotControl", FIRST_READ),
    "waf.bot.request": (1.0, "per million requests above 10 million", "WAF", "Global-AMR-BotControl-Request", FIRST_READ),
    "shield.fee": (3000.0, "per month", "SHD", "Shield-Monthly-Fee, first subscription", FIRST_READ),
    "shield.cf.gb": (0.025, "per GB", "SHD", "Global-DataTransfer-Shield-Bytes, out of CloudFront, first 100 TB", FIRST_READ),
    "nfw.hour": (0.395, "per endpoint-hour", "NFW", "APS1-Endpoint-Hour", FIRST_READ),
    "nfw.gb": (0.065, "per GB", "NFW", "APS1-Traffic-GB-Processed", FIRST_READ),
    "xaz.gb": (0.01, "per GB in each direction", "DTR", "APS1-DataTransfer-Regional-Bytes", FIRST_READ),
    "dto.internet": (0.12, "per GB, first 10 TB", "DTR", "APS1-DataTransfer-Out-Bytes", SECOND_READ),
    "dtr.region": (0.09, "per GB", "DTR", "APS1-APN1-AWS-Out-Bytes, the same rate to every Asia Pacific Region except APS7 and APS9 at 0.08", SECOND_READ),
    "s3.gb": (0.025, "per GB-month", "S3", "APS1-TimedStorage-ByteHrs, first 50 TB", FIRST_READ),
    "s3da.gb": (0.002, "per GB-month", "GDA", "APS1-TimedStorage-GDA-ByteHrs", SECOND_READ),
    "s3da.transition": (0.06, "per 1,000 lifecycle transitions", "GDA", "APS1-Requests-Tier3, S3-GDATransition", SECOND_READ),
    "logs.ingest": (0.70, "per GB", "CWL", "APS1-DataProcessing-Bytes, Standard class", FIRST_READ),
    "logs.store": (0.03, "per GB-month", "CWL", "APS1-TimedStorage-ByteHrs", FIRST_READ),
    "logs.s3": (0.35, "per GB, first 10 TB", "CWL", "APS1-S3-Egress-Bytes, logs from AWS services delivered to S3", FIRST_READ),
    "amp.tier1": (0.90, "per 10 million samples, 40 million to 2 billion", "AMP", "APS1-AMP:MetricSampleCount", FIRST_READ),
    "amp.tier2": (0.35, "per 10 million samples, next 250 billion", "AMP", "APS1-AMP:MetricSampleCount", FIRST_READ),
    "amp.query": (0.10, "per billion query samples", "AMP", "APS1-AMP:QuerySamplesProcessed", FIRST_READ),
    "amg.editor": (9.0, "per editor-month", "AMG", "APS1-Grafana:EditorUser", FIRST_READ),
    "amg.viewer": (5.0, "per viewer-month", "AMG", "APS1-Grafana:ViewerUser", FIRST_READ),
    "ecr.gb": (0.10, "per GB-month", "ECR", "APS1-TimedStorage-ByteHrs", FIRST_READ),
    "kms.key": (1.0, "per key-month", "KMS", "ap-southeast-1-KMS-Keys, each multi-Region primary and replica", FIRST_READ),
    "kms.request": (0.03, "per 10,000 requests", "KMS", "ap-southeast-1-KMS-Requests", FIRST_READ),
    "kms.asym": (0.15, "per 10,000 requests", "KMS", "ap-southeast-1-KMS-Requests-Asymmetric", FIRST_READ),
    "gd.events": (4.60, "per million CloudTrail events", "GDY", "APS1-PaidEventsAnalyzed", SECOND_READ),
    "gd.logs": (1.15, "per GB, first 500 GB", "GDY", "APS1-PaidEventsAnalyzed-Bytes", SECOND_READ),
    "gd.eks": (1.85, "per vCPU-month, first 500 vCPU", "GDY", "APS1-PaidEKSvCPUMonitored", SECOND_READ),
    "sh.check": (0.001, "per check, first 100,000 per account", "SHB", "APS1-PaidComplianceCheck", SECOND_READ),
    "cfg.item": (0.003, "per configuration item", "CFG", "APS1-ConfigurationItemRecorded", SECOND_READ),
    "ct.first": (0.0, "per event, first copy of management events", "CTR", "APS1-FreeEventsRecorded", SECOND_READ),
    "va.app": (0.35, "per application-hour", "VPC", "APS1-VerifiedAccess-App-Hours", SECOND_READ),
    "va.gb": (0.02, "per GB", "VPC", "APS1-VerifiedAccess-DataProcess-Bytes", SECOND_READ),
    "cognito.essentials": (0.015, "per monthly active user", "COG", "APS1-CognitoEssentialsMAU", SECOND_READ),
    "cognito.plus": (0.02, "per monthly active user", "COG", "APS1-CognitoPlusMAU", SECOND_READ),
    "cognito.mrr": (0.006, "per monthly active user", "COG", "APS1-CognitoPlusMRRMAU", SECOND_READ),
}

SUPPORT_SOURCE = "https://aws.amazon.com/premiumsupport/pricing/"
SUPPORT_MINIMUM = 29.0
SUPPORT_TIERS = [(10_000, 0.09), (80_000, 0.07), (250_000, 0.05), (None, 0.03)]

VENDOR_VALUES = [
    ("Business Support+ fee per account", "The greater of 29 USD or 9 % of monthly charges up to 10,000 USD, 7 % from 10,000 to 80,000 USD, 5 % from 80,000 to 250,000 USD and 3 % above, on gross charges with Savings Plan and reservation charges included and AWS Support charges left out", "Support row", SUPPORT_SOURCE),
    ("NAT gateway waiver", "NAT gateway hour and GB charges are waived one for one against Network Firewall endpoint hours and GB when the NAT gateway sits on the same path in the same Region", "NAT rows", "https://aws.amazon.com/network-firewall/pricing/"),
    ("ALB capacity unit", "25 new connections per second averaged over the hour, 3,000 active connections per minute, 1 GB per hour for EC2 and IP targets, 1,000 rule evaluations per second", "ALB rows and the reconnect wave", "https://aws.amazon.com/elasticloadbalancing/pricing/"),
    ("NLB capacity unit for TCP", "800 new connections per second, 100,000 active connections, 1 GB per hour", "PrivateLink rows", "https://aws.amazon.com/elasticloadbalancing/pricing/"),
    ("Glacier Deep Archive object overhead", "40 KB of metadata per archived object, 32 KB at the Deep Archive rate and 8 KB at the S3 Standard rate, and a 180-day minimum storage duration", "Log storage rows", "https://docs.aws.amazon.com/AmazonS3/latest/userguide/storage-class-intro.html"),
    ("Aurora Global Database transfer", "2.75 KB per replicated write I/O, the size the pricing page uses in its Global Database example", "Inter-region transfer row", "https://aws.amazon.com/rds/aurora/pricing/"),
]

WS_CONNECTIONS = 10_000
REQUESTS = 500 * SECONDS
CACHED_SHARE = 0.60 * 0.50
ORIGIN_REQUESTS = REQUESTS * (1 - CACHED_SHARE)
REST_GB = REQUESTS * 2 / 1e6
ORIGIN_GB = ORIGIN_REQUESTS * 1 / 1e6
KAFKA_GB_DAY = 1 * 86_400 / 1e3
KAFKA_GB_MONTH = 1 * SECONDS / 1e3
BOT_REQUESTS = REQUESTS * 0.05
WAF_RULES = 8
LEASE_OPS = 20 * SECONDS
AMP_SAMPLES = 100_000 * 2 * 60 * HOURS
AMP_QUERY_BILLIONS = 50

STATELESS_NODES = 9
STATELESS_VCPU_PER_NODE = 4
STATELESS_PEAK_VCPU = 10.7
CPU_CEILING = 0.70
PINNED_NODES = 6
PINNED_VCPU_PER_NODE = 8
PINNABLE_VCPU = 6
CORES_PER_PROCESS = 2
SHARDS = 4 + 4
PROCESSES = SHARDS * 2
AZS = 3
ROOT_GB = 50
ECR_GB = 50
ORDERS_PER_SECOND = 75
RISK_SHARDS = 4
COMMIT_BUDGET_MS = 15
BUSY_SHARE_LIMIT = 0.5
WS_PODS = 6
WS_POD_CONNECTIONS = 2_500
WS_POD_NEW_PER_SECOND = 100
WS_WAVE_SECONDS = 30

INTERNET_GB = 200
TELEMETRY_GB = 300
LOGS_GB = 5 * HOURS / 24
NAT_GB = INTERNET_GB + TELEMETRY_GB
NFW_GB = NAT_GB
NAT_GATEWAYS = 3
NFW_ENDPOINTS = 3
ENDPOINT_GB = 100
CROSS_AZ_GB = 6_000
WALLET_AZS = 2
WALLET_GB = 1

LEDGER_GB = 200
PITR_GB = 350
VAULT_COPIES = 35 + 12
SNAPSHOT_GB = 200
REPLICATED_WRITES = 150e6
REPLICATED_WRITE_KB = 2.75

WITNESS_WRITES_PER_SECOND = 4
DR_EPOCH_READS_PER_SECOND = 8 / 10
SIGNER_LEASE_PER_SECOND = 1 / 10
ITEM_KB = 1

ACCOUNTS = 7
MGMT_EVENTS = 5e6
TRAIL_GB = 5
FLOW_GB = 200
AUDIT_GB = 400
EKS_VCPU = STATELESS_NODES * STATELESS_VCPU_PER_NODE + PINNED_NODES * PINNED_VCPU_PER_NODE
CHECKS_PER_ACCOUNT = 20_000
CONFIG_ITEMS = 30_000
CMK_KEYS = 7
CMK_REQUESTS = 3e6
SIGNATURES = 100_000
VA_APPS = 1
VA_GB = 10
HOT_KEYS = 4
TRAIL_MONTHS = 60
FLOW_MONTHS = 12
AUDIT_MONTHS = 60
STANDARD_MONTHS = 3
LOG_OBJECT_MB = 10
ARCHIVE_KB = 32
ARCHIVE_STANDARD_KB = 8

DR_STATELESS_NODES = 3
DR_PINNED_NODES = 3
DR_CMK_KEYS = 6 + 1


def p(key):
    return PRICES[key][0]


def cf_dto(gb):
    first = min(gb, 10_240)
    return first * p("cf.dto.10tb") + max(gb - 10_240, 0) * p("cf.dto.50tb")


def amp(samples):
    tier1 = max(min(samples, 2e9) - 40e6, 0)
    tier2 = max(samples - 2e9, 0)
    return tier1 / 1e7 * p("amp.tier1") + tier2 / 1e7 * p("amp.tier2")


def support_fee(charges):
    fee, lower = 0.0, 0.0
    for upper, rate in SUPPORT_TIERS:
        top = charges if upper is None else min(charges, upper)
        if top > lower:
            fee += (top - lower) * rate
        if upper is None or charges <= upper:
            break
        lower = upper
    return max(SUPPORT_MINIMUM, fee)


def row(kind, area, item, account, qty, keys, od=0.0, disc=None, small=None, sec=0.0, dr=0.0, control="", units=""):
    return {"kind": kind, "area": area, "item": item, "account": account, "qty": qty, "keys": keys, "od": od,
            "disc": od if disc is None else disc, "small": od if small is None else small, "sec": sec, "dr": dr,
            "control": control, "units": units}


def base(area, item, account, qty, keys, od, disc=None, small=None):
    return row("base", area, item, account, qty, keys, od, disc, small)


def security(control, item, account, qty, keys, value):
    return row("security", "Security", f"{item} (Problem 5 {control})", account, qty, keys, 0.0, 0.0, 0.0, sec=value, control=control)


def standby(item, account, qty, keys, value):
    return row("dr", "DR region", f"{item} in `<DR_REGION>`", account, qty, keys, 0.0, 0.0, 0.0, dr=value)


def is_number(x):
    return isinstance(x, (int, float))


def production(rows, column):
    return sum(r[column] for r in rows if r["account"] == "Production" and is_number(r[column]))


def stocks():
    flow_standard = FLOW_GB * STANDARD_MONTHS
    flow_archive = FLOW_GB * (FLOW_MONTHS - STANDARD_MONTHS)
    audit_standard = AUDIT_GB * STANDARD_MONTHS
    audit_archive = AUDIT_GB * (AUDIT_MONTHS - STANDARD_MONTHS)
    archived_objects = (flow_archive + audit_archive) * 1e3 / LOG_OBJECT_MB
    transitions = (FLOW_GB + AUDIT_GB) * 1e3 / LOG_OBJECT_MB
    standard = TRAIL_GB * TRAIL_MONTHS + flow_standard + audit_standard + archived_objects * ARCHIVE_STANDARD_KB / 1e6
    archive = flow_archive + audit_archive + archived_objects * ARCHIVE_KB / 1e6
    return standard, archive, archived_objects, transitions


def build(ws_kbps):
    ws_gb = WS_CONNECTIONS * ws_kbps * SECONDS / 1e6
    alb_gb = REST_GB * (1 - CACHED_SHARE) + ws_gb + ORIGIN_GB
    waf_with_shield = p("waf.bot") + max(BOT_REQUESTS - 10e6, 0) / 1e6 * p("waf.bot.request")
    waf_without_shield = p("waf.acl") + WAF_RULES * p("waf.rule") + REQUESTS / 1e6 * p("waf.request") + waf_with_shield
    witness_gb = WITNESS_WRITES_PER_SECOND * SECONDS * ITEM_KB / 1e6
    lease_gb = SIGNER_LEASE_PER_SECOND * SECONDS * ITEM_KB / 1e6
    aurora_dr_gb = REPLICATED_WRITES * REPLICATED_WRITE_KB / 1e6
    standard, archive, archived_objects, transitions = stocks()
    rows = [
        base("Compute", "EKS control plane", "Production", "1 cluster (AS-07)", ["eks.cluster"], p("eks.cluster") * HOURS, small=0.0),
        base("Compute", "Stateless pool", "Production",
             f"{STATELESS_NODES} x m8g.xlarge (4 vCPU, 16 GiB), 3 per AZ (AS-07, AS-20)", ["m8g.xlarge", "csp.m8g.xlarge"],
             STATELESS_NODES * HOURS * p("m8g.xlarge"), STATELESS_NODES * HOURS * p("csp.m8g.xlarge")),
        base("Compute", "Matching and risk pool", "Production",
             f"{PINNED_NODES} x c8g.2xlarge (8 vCPU, 16 GiB), CPU pinning, 2 per AZ (AS-07, AS-21)",
             ["c8g.2xlarge", "csp.c8g.2xlarge"], PINNED_NODES * HOURS * p("c8g.2xlarge"), PINNED_NODES * HOURS * p("csp.c8g.2xlarge")),
        base("Compute", "Node root volumes", "Production", f"{STATELESS_NODES + PINNED_NODES} x {ROOT_GB} GB gp3 (AS-22)", ["gp3"],
             (STATELESS_NODES + PINNED_NODES) * ROOT_GB * p("gp3")),
        base("Compute", "Image registry", "Production", f"{ECR_GB} GB in ECR (AS-22)", ["ecr.gb"], ECR_GB * p("ecr.gb")),
        base("Event log", "MSK brokers", "Production", "3 x kafka.m7g.large, one per AZ (AS-07)", ["msk.m7g.large"],
             3 * HOURS * p("msk.m7g.large")),
        base("Event log", "MSK broker storage", "Production", "3 x 1,000 GB for 7 days of 1 MB/s at replication factor 3 (AS-06)",
             ["msk.storage"], 3 * 1_000 * p("msk.storage")),
        base("Event log", "MSK tiered storage", "Production", f"35 days of 1 MB/s, {35 * KAFKA_GB_DAY:,.0f} GB (AS-06)", ["msk.tiered"],
             35 * KAFKA_GB_DAY * p("msk.tiered")),
        base("Ledger", "Aurora PostgreSQL instances", "Production", "1 writer and 2 readers, db.r8g.large, Aurora Standard (AS-07)",
             ["aurora.r8g.large", "ri.aurora.r8g.large"], 3 * HOURS * p("aurora.r8g.large"), 3 * HOURS * p("ri.aurora.r8g.large")),
        base("Ledger", "Aurora storage and I/O", "Production", f"{LEDGER_GB} GB, 300 million I/O per month (AS-08)",
             ["aurora.storage", "aurora.io"], LEDGER_GB * p("aurora.storage") + 300 * p("aurora.io")),
        base("Ledger", "Aurora backup above the free allocation", "Production",
             f"{PITR_GB} GB for 35 days of point-in-time recovery (AS-24)", ["aurora.backup"], PITR_GB * p("aurora.backup")),
        base("Cache", "ElastiCache for Valkey", "Production", "1 primary and 2 replicas, cache.m7g.large (AS-07)",
             ["valkey.m7g.large", "ri.valkey.m7g.large"], 3 * HOURS * p("valkey.m7g.large"), 3 * HOURS * p("ri.valkey.m7g.large"),
             2 * HOURS * p("valkey.m7g.large")),
        base("Leases", "DynamoDB on demand", "Production", "20 lease writes and 20 reads per second (AS-26)", ["ddb.wru", "ddb.rru"],
             LEASE_OPS / 1e6 * (p("ddb.wru") + p("ddb.rru"))),
        base("Identity", "Cognito user pools, Essentials plan", "Production", "`<MAU>` monthly active users (AS-35)",
             ["cognito.essentials"], "`<MAU>` x 0.015"),
        base("Edge", "CloudFront requests", "Production", f"{REQUESTS / 1e9:.3f} billion HTTPS requests (AS-04)", ["cf.https"],
             REQUESTS / 1e4 * p("cf.https")),
        base("Edge", "CloudFront data transfer out", "Production", f"{REST_GB:,.0f} GB REST and {ws_gb:,.0f} GB WebSocket (AS-02, AS-05)",
             ["cf.dto.10tb", "cf.dto.50tb"], cf_dto(REST_GB + ws_gb)),
        base("Edge", "CloudFront to origin", "Production", f"{ORIGIN_GB:,.0f} GB of forwarded requests (AS-01, AS-05)", ["cf.origin"],
             ORIGIN_GB * p("cf.origin")),
        base("Edge", "AWS WAF with Shield Advanced", "Production",
             f"web ACL, {WAF_RULES} rules and requests at the Shield-protected rates, Bot Control on 5 % of requests (AS-27)",
             ["waf.shield.request", "waf.bot", "waf.bot.request", "waf.acl", "waf.rule", "waf.request"],
             waf_with_shield + REQUESTS / 1e6 * p("waf.shield.request"), small=waf_without_shield),
        base("Edge", "Shield Advanced", "Production", "subscription and data transfer out of CloudFront (AS-05)", ["shield.fee", "shield.cf.gb"],
             p("shield.fee") + (REST_GB + ws_gb) * p("shield.cf.gb"), small=0.0),
        base("Edge", "Application Load Balancer", "Production", f"1 ALB, {alb_gb / HOURS:.1f} LCU from processed bytes (AS-05)",
             ["alb.hour", "alb.lcu"], HOURS * (p("alb.hour") + alb_gb / HOURS * p("alb.lcu"))),
        base("Network", "NAT gateways", "Production",
             f"{NAT_GATEWAYS}, one per AZ, {NAT_GB} GB (AS-28), hour and GB charges waived one for one by Network Firewall on the same path",
             ["nat.hour", "nat.gb"],
             max(NAT_GATEWAYS - NFW_ENDPOINTS, 0) * HOURS * p("nat.hour") + max(NAT_GB - NFW_GB, 0) * p("nat.gb")),
        base("Network", "Network Firewall", "Production", f"{NFW_ENDPOINTS} endpoints, {NFW_GB} GB inspected (AS-28)", ["nfw.hour", "nfw.gb"],
             NFW_ENDPOINTS * HOURS * p("nfw.hour") + NFW_GB * p("nfw.gb")),
        base("Network", "Internet data transfer out", "Production",
             f"{INTERNET_GB - witness_gb:,.1f} GB, the internet egress without the witness writes (AS-28)", ["dto.internet"],
             (INTERNET_GB - witness_gb) * p("dto.internet")),
        base("Network", "Interface endpoints", "Production",
             f"ECR API, ECR Docker, STS, KMS, Secrets Manager in 3 AZs, {ENDPOINT_GB} GB (AS-28), gateway endpoints for S3 and DynamoDB at no charge",
             ["vpce.hour", "vpce.gb"], 5 * 3 * HOURS * p("vpce.hour") + ENDPOINT_GB * p("vpce.gb")),
        base("Network", "Cross-AZ traffic", "Production", f"{CROSS_AZ_GB:,} GB in each direction (AS-28)", ["xaz.gb"],
             CROSS_AZ_GB * 2 * p("xaz.gb")),
        base("Observability", "CloudWatch Logs", "Production", "5 GB per day ingested, 30 days kept (AS-08)", ["logs.ingest", "logs.store"],
             LOGS_GB * (p("logs.ingest") + p("logs.store"))),
        base("Observability", "Managed Prometheus", "Production",
             f"100,000 active series every 30 s, {AMP_SAMPLES / 1e9:.2f} billion samples, {AMP_QUERY_BILLIONS} billion query samples (AS-08, AS-29)",
             ["amp.tier1", "amp.tier2", "amp.query"], amp(AMP_SAMPLES) + AMP_QUERY_BILLIONS * p("amp.query")),
        base("Observability", "Managed Grafana", "Production", "5 editors, 20 viewers (AS-29)", ["amg.editor", "amg.viewer"],
             5 * p("amg.editor") + 20 * p("amg.viewer")),
        base("Backup", "Vault locked in compliance mode", "Backup",
             f"{VAULT_COPIES} full copies of the {LEDGER_GB} GB ledger, 35 daily and 12 monthly (AS-25)", ["aurora.backup"],
             VAULT_COPIES * LEDGER_GB * p("aurora.backup")),
        base("Backup", "Engine snapshots in S3 with Object Lock", "Production", f"{SNAPSHOT_GB} GB for 7 days of 60 s snapshots (AS-25)",
             ["s3.gb"], SNAPSHOT_GB * p("s3.gb")),
        base("Wallet", "Signer and watcher hosts", "Wallet", f"2 x m7g.large in {WALLET_AZS} AZs (AS-07)", ["m7g.large", "csp.m7g.large"],
             2 * HOURS * p("m7g.large"), 2 * HOURS * p("csp.m7g.large")),
        base("Wallet", "KMS keys", "Wallet", f"{HOT_KEYS} hot wallet keys (AS-30)", ["kms.key"], HOT_KEYS * p("kms.key")),
        base("Wallet", "PrivateLink endpoint service", "Wallet",
             f"1 NLB over {WALLET_AZS} AZs, {WALLET_GB} GB per month, about {WALLET_GB} NLCU-hour (AS-28)", ["nlb.hour", "nlb.lcu"],
             HOURS * p("nlb.hour") + WALLET_GB * p("nlb.lcu")),
        base("Wallet", "Interface endpoint to the wallet service", "Production",
             f"1 endpoint in the {WALLET_AZS} AZs of the NLB, {WALLET_GB} GB (AS-28)", ["vpce.hour", "vpce.gb"],
             WALLET_AZS * HOURS * p("vpce.hour") + WALLET_GB * p("vpce.gb")),
        security("SC-01", "KMS endpoint in the wallet account", "Wallet", f"1 interface endpoint in {WALLET_AZS} AZs (AS-07)",
                 ["vpce.hour"], WALLET_AZS * HOURS * p("vpce.hour")),
        security("SC-01", "KMS signing requests", "Wallet", f"{SIGNATURES:,} withdrawal signatures (AS-16)", ["kms.asym"],
                 SIGNATURES / 1e4 * p("kms.asym")),
        security("SC-05", "Verified Access for the admin plane", "Production", f"{VA_APPS} application, {VA_GB} GB (AS-17)", ["va.app", "va.gb"],
                 VA_APPS * HOURS * p("va.app") + VA_GB * p("va.gb")),
        security("SC-09", "Customer managed KMS keys", "Production",
                 f"{CMK_KEYS} keys: one per data class and the multi-Region Cognito key (AS-16)", ["kms.key"], CMK_KEYS * p("kms.key")),
        security("SC-09", "KMS requests on customer managed keys", "Production", f"{CMK_REQUESTS / 1e6:.0f} million requests (AS-16)",
                 ["kms.request"], CMK_REQUESTS / 1e4 * p("kms.request")),
        security("SC-11", "Organization CloudTrail", "Management", "first copy of management events in every account (AS-11)", ["ct.first"],
                 MGMT_EVENTS * p("ct.first")),
        security("SC-11", "GuardDuty CloudTrail analysis", "Production", f"{MGMT_EVENTS / 1e6:.0f} million management events (AS-11, AS-33)",
                 ["gd.events"], MGMT_EVENTS / 1e6 * p("gd.events")),
        security("SC-11", "GuardDuty flow and DNS log analysis", "Production", f"{FLOW_GB} GB (AS-12)", ["gd.logs"], FLOW_GB * p("gd.logs")),
        security("SC-11", "GuardDuty Runtime Monitoring for EKS", "Production", f"{EKS_VCPU} vCPUs of production EKS nodes (AS-13)",
                 ["gd.eks"], EKS_VCPU * p("gd.eks")),
        security("SC-11", "Security Hub CSPM", "Production", f"{CHECKS_PER_ACCOUNT:,} checks (AS-14)", ["sh.check"],
                 CHECKS_PER_ACCOUNT * p("sh.check")),
        security("SC-11", "Security Hub CSPM", "Other 6 accounts", f"{CHECKS_PER_ACCOUNT:,} checks in each of {ACCOUNTS - 1} accounts (AS-10, AS-14)",
                 ["sh.check"], (ACCOUNTS - 1) * CHECKS_PER_ACCOUNT * p("sh.check")),
        security("SC-11", "AWS Config", "Production", f"{CONFIG_ITEMS:,} configuration items (AS-15)", ["cfg.item"], CONFIG_ITEMS * p("cfg.item")),
        security("SC-11", "VPC Flow Logs delivered to S3", "Production", f"{FLOW_GB} GB (AS-12)", ["logs.s3"], FLOW_GB * p("logs.s3")),
        security("SC-11", "Log storage in S3 Standard with Object Lock", "Log archive",
                 f"{standard:,.0f} GB: 5 years of trail files, 3 months of flow logs and audit log, 8 KB per archived object (AS-11, AS-12, AS-18, AS-34)",
                 ["s3.gb"], standard * p("s3.gb")),
        security("SC-11", "Log storage in Glacier Deep Archive with Object Lock", "Log archive",
                 f"{archive:,.0f} GB: the rest of 1 year of flow logs and 5 years of audit log, 32 KB per archived object (AS-12, AS-18, AS-34)",
                 ["s3da.gb"], archive * p("s3da.gb")),
        security("SC-11", "Lifecycle transitions to Glacier Deep Archive", "Log archive",
                 f"{transitions:,.0f} objects per month of {LOG_OBJECT_MB} MB (AS-34)", ["s3da.transition"],
                 transitions / 1e3 * p("s3da.transition")),
        security("SC-22", "Cognito Plus over Essentials", "Production", "`<MAU>` monthly active users (AS-35)",
                 ["cognito.plus", "cognito.essentials"], "`<MAU>` x 0.005"),
        standby("EKS control plane", "Production", "1 cluster (AS-31)", ["eks.cluster"], p("eks.cluster") * HOURS),
        standby("Stateless nodes", "Production", f"{DR_STATELESS_NODES} x m8g.xlarge, one per AZ (AS-31)", ["m8g.xlarge"],
                DR_STATELESS_NODES * HOURS * p("m8g.xlarge")),
        standby("Pinned nodes", "Production", f"{DR_PINNED_NODES} x c8g.2xlarge, one quiescent process per shard (AS-21, AS-31)",
                ["c8g.2xlarge"], DR_PINNED_NODES * HOURS * p("c8g.2xlarge")),
        standby("Node root volumes", "Production", f"{DR_STATELESS_NODES + DR_PINNED_NODES} x {ROOT_GB} GB gp3 (AS-22)", ["gp3"],
                (DR_STATELESS_NODES + DR_PINNED_NODES) * ROOT_GB * p("gp3")),
        standby("MSK target cluster", "Production", "3 x kafka.m7g.large with 3 x 1,000 GB (AS-07, AS-31)", ["msk.m7g.large", "msk.storage"],
                3 * HOURS * p("msk.m7g.large") + 3 * 1_000 * p("msk.storage")),
        standby("MSK Replicator", "Production", f"1 Replicator, {KAFKA_GB_MONTH:,.0f} GB processed (AS-06, AS-31)",
                ["msk.replicator", "msk.replicator.gb"], HOURS * p("msk.replicator") + KAFKA_GB_MONTH * p("msk.replicator.gb")),
        row("dr", "DR region", "Multi-VPC private connectivity on the source cluster", "Production",
            f"1 authentication scheme, {KAFKA_GB_MONTH:,.0f} GB read by the Replicator (AS-06)", ["msk.private.hour", "msk.private.gb"],
            dr=HOURS * p("msk.private.hour") + KAFKA_GB_MONTH * p("msk.private.gb")),
        standby("Aurora Global Database secondary", "Production",
                f"1 x db.r8g.large, {LEDGER_GB} GB, {REPLICATED_WRITES / 1e6:.0f} million replicated write I/O (AS-08, AS-24)",
                ["aurora.r8g.large", "aurora.storage", "aurora.replicated"],
                HOURS * p("aurora.r8g.large") + LEDGER_GB * p("aurora.storage") + REPLICATED_WRITES / 1e6 * p("aurora.replicated")),
        standby("ElastiCache for Valkey", "Production", "1 primary and 1 replica, cache.m7g.large (AS-07)", ["valkey.m7g.large"],
                2 * HOURS * p("valkey.m7g.large")),
        standby("Internal ALB", "Production", "1 ALB, no capacity units outside a failover (AS-31)", ["alb.hour"], HOURS * p("alb.hour")),
        standby("Network Firewall and NAT gateways", "Production",
                f"{NFW_ENDPOINTS} firewall endpoints, {NAT_GATEWAYS} NAT gateways whose hours the firewall waives (AS-31)", ["nfw.hour", "nat.hour"],
                NFW_ENDPOINTS * HOURS * p("nfw.hour") + max(NAT_GATEWAYS - NFW_ENDPOINTS, 0) * HOURS * p("nat.hour")),
        standby("Interface endpoints", "Production", "5 endpoints in 3 AZs (AS-31)", ["vpce.hour"], 5 * 3 * HOURS * p("vpce.hour")),
        standby("Lease and control tables", "Production",
                f"{WITNESS_WRITES_PER_SECOND} witness writes per second, epoch reads by 8 quiescent writers every 10 s (AS-26)",
                ["ddb.wru", "ddb.rru"],
                WITNESS_WRITES_PER_SECOND * SECONDS / 1e6 * p("ddb.wru") + DR_EPOCH_READS_PER_SECOND * SECONDS / 1e6 * p("ddb.rru")),
        standby("Signer lease", "Wallet", "renewed every 10 s from ap-southeast-1 and read every 10 s (AS-26, AS-31)",
                ["ddb.wru", "ddb.rru", "dtr.region"],
                SIGNER_LEASE_PER_SECOND * SECONDS / 1e6 * (p("ddb.wru") + p("ddb.rru")) + lease_gb * p("dtr.region")),
        standby("KMS keys", "Production", f"{DR_CMK_KEYS}: DR keys for 6 data classes and the Cognito key replica (AS-16, AS-31)",
                ["kms.key"], DR_CMK_KEYS * p("kms.key")),
        standby("KMS hot key replicas", "Wallet", f"{HOT_KEYS} replicas (AS-30)", ["kms.key"], HOT_KEYS * p("kms.key")),
        standby("Signer and watcher hosts", "Wallet", f"2 x m7g.large in {WALLET_AZS} AZs, quiescent signer (AS-07)", ["m7g.large"],
                2 * HOURS * p("m7g.large")),
        standby("PrivateLink endpoint service", "Wallet", f"1 NLB over {WALLET_AZS} AZs, no capacity units while quiescent (AS-31)",
                ["nlb.hour"], HOURS * p("nlb.hour")),
        standby("Interface endpoint to the wallet service", "Production", f"1 endpoint in {WALLET_AZS} AZs (AS-31)", ["vpce.hour"],
                WALLET_AZS * HOURS * p("vpce.hour")),
        row("dr", "DR region", "Cognito multi-Region replication", "Production", "`<MAU>` monthly active users (AS-35)", ["cognito.mrr"],
            dr="`<MAU>` x 0.006"),
        row("dr", "DR region", "Inter-region transfer from ap-southeast-1", "Production",
            f"{KAFKA_GB_MONTH:,.0f} GB of Replicator traffic, {aurora_dr_gb:,.1f} GB of Aurora replication, {witness_gb:,.1f} GB of witness writes (AS-06, AS-24, AS-26, AS-31)",
            ["dtr.region"], dr=(KAFKA_GB_MONTH + aurora_dr_gb + witness_gb) * p("dtr.region")),
    ]
    rows.append(support_row(rows))
    return rows


def support_row(rows):
    sec_prod, dr_prod = production(rows, "sec"), production(rows, "dr")
    fees, sec_fees, dr_fees = {}, [], []
    for column in ("od", "disc", "small"):
        prod = production(rows, column)
        fees[column] = support_fee(prod)
        sec_fees.append(support_fee(prod + sec_prod) - support_fee(prod))
        dr_fees.append(support_fee(prod + sec_prod + dr_prod) - support_fee(prod + sec_prod))
    if max(sec_fees) - min(sec_fees) > 0.005 or max(dr_fees) - min(dr_fees) > 0.005:
        raise SystemExit("the marginal support fee differs between the base columns, so one security and DR value is wrong")
    return row("support", "Support", "Business Support+", "Production", "the production charges of each column (AS-32, AS-33)", [],
               fees["od"], fees["disc"], fees["small"], sec=sec_fees[0], dr=dr_fees[0],
               units=f"9 % to 10,000 USD, 7 % from 10,000 to 80,000 USD of production charges ({SECOND_READ})")


def money(x):
    return f"{x:,.2f}" if is_number(x) else x


def units(r):
    if r["units"]:
        return r["units"]
    parts = []
    for key in r["keys"]:
        usd, unit, src, _, _ = PRICES[key]
        parts.append(f"{usd:g} {unit} ({SOURCES[src][2]})")
    return ", ".join(parts)


def total(rows, column):
    return sum(r[column] for r in rows if is_number(r[column]))


def find(rows, item, account="Production"):
    return next(r for r in rows if r["item"] == item and r["account"] == account)


def main():
    rows = build(1.0)
    od, disc, small, sec, dr = (total(rows, c) for c in ("od", "disc", "small", "sec", "dr"))
    print("# Monthly cost estimate for ap-southeast-1")
    print()
    print("Generated by `python3 -I cost_estimate.py`. Each quantity names the assumption of section 2.3 of `SOLUTION.md` that it rests on, "
          "and the Account cell names the account it is charged to. Prices come from the AWS price list files named in the second table, "
          f"read on {FIRST_READ}, and on {SECOND_READ} for the GuardDuty, Security Hub, AWS Config, CloudTrail and Cognito offer files, "
          "the Verified Access prices and every price the second table dates "
          f"{SECOND_READ}. The third table lists the rates and rules taken from AWS pages. A month is 730 hours. "
          "Cells written as `<MAU>` times a price are placeholders, and the totals leave them out.")
    print()
    print("| Area | Item | Account | Quantity (assumption) | Unit prices, USD (price list date) | On demand USD per month | With eligible discounts | Smaller baseline | Security column | DR column |")
    print("|---|---|---|---|---|---|---|---|---|---|")
    for r in rows:
        print(f"| {r['area']} | {r['item']} | {r['account']} | {r['qty']} | {units(r)} | {money(r['od'])} | {money(r['disc'])} | "
              f"{money(r['small'])} | {money(r['sec'])} | {money(r['dr'])} |")
    print(f"| Total | | | | | {money(od)} | {money(disc)} | {money(small)} | {money(sec)} | {money(dr)} |")
    print(f"| Total with the security column | | | | | {money(od + sec)} | {money(disc + sec)} | {money(small + sec)} | | |")
    print(f"| Total with the security and DR columns | | | | | {money(od + sec + dr)} | {money(disc + sec + dr)} | {money(small + sec + dr)} | | |")
    print()
    print("| Price key | USD | Unit | Usage type or term | Offer file version | Published | Read on |")
    print("|---|---|---|---|---|---|---|")
    for key, (usd, unit, src, usage, read_on) in PRICES.items():
        offer, version, date = SOURCES[src]
        print(f"| {key} | {usd:g} | {unit} | {usage} | {offer} {version} | {date} | {read_on} |")
    print()
    print("| Rate or rule | Value | Used in | Source | Read on |")
    print("|---|---|---|---|---|")
    for name, value, used, source in VENDOR_VALUES:
        print(f"| {name} | {value} | {used} | {source} | {SECOND_READ} |")
    print()
    figures(rows, od, disc, small, sec, dr)


def figures(rows, od, disc, small, sec, dr):
    ws_gb = WS_CONNECTIONS * 1.0 * SECONDS / 1e6
    alb_gb = REST_GB * (1 - CACHED_SHARE) + ws_gb + ORIGIN_GB
    io_extra = 3 * HOURS * (p("aurora.io.r8g.large") - p("aurora.r8g.large")) + LEDGER_GB * (p("aurora.io.storage") - p("aurora.storage"))
    endpoint_month = 3 * HOURS * p("vpce.hour")
    waf, shield = find(rows, "AWS WAF with Shield Advanced"), find(rows, "Shield Advanced")
    eks, valkey, support = find(rows, "EKS control plane"), find(rows, "ElastiCache for Valkey"), find(rows, "Business Support+")
    dto = find(rows, "CloudFront data transfer out")
    prod_od = production(rows, "od") - support["od"]
    shield_net = shield["od"] + waf["od"] - shield["small"] - waf["small"]
    shield_support = support_fee(prod_od) - support_fee(prod_od - shield_net)
    gap_parts = [eks["od"] - eks["small"], valkey["od"] - valkey["small"], shield_net, support["od"] - support["small"]]
    if abs(sum(gap_parts) - (od - small)) > 0.005:
        raise SystemExit("the smaller baseline gap does not equal the sum of its parts")
    sensitivity = total(build(1.1), "od") - od
    largest = max((r for r in rows if is_number(r["od"])), key=lambda r: r["od"])
    telemetry = sum(r["od"] for r in rows if r["area"] == "Observability")
    detection = sum(r["sec"] for r in rows if r["control"] == "SC-11" and is_number(r["sec"]))
    witness_gb = WITNESS_WRITES_PER_SECOND * SECONDS * ITEM_KB / 1e6
    stateless_vcpu = STATELESS_NODES * STATELESS_VCPU_PER_NODE
    two_az_vcpu = stateless_vcpu * (AZS - 1) / AZS
    slots = PINNED_NODES * (PINNABLE_VCPU // CORES_PER_PROCESS)
    wave_per_second = WS_CONNECTIONS / WS_WAVE_SECONDS
    surviving_pods = WS_PODS * (AZS - 1) // AZS
    print("| Derived figure | Value |")
    print("|---|---|")
    print(f"| Requests per month at 500 requests/s | {REQUESTS:,.0f} |")
    print(f"| GB through the ALB per month | {alb_gb:,.0f} |")
    print(f"| Stateless CPU at normal peak on {STATELESS_NODES} nodes | {STATELESS_PEAK_VCPU / stateless_vcpu * 100:.1f} % of {stateless_vcpu} vCPU |")
    print(f"| Stateless CPU at 1.5x on the nodes of two AZs | {1.5 * STATELESS_PEAK_VCPU / two_az_vcpu * 100:.1f} % of {two_az_vcpu:.0f} vCPU |")
    print(f"| Burst that three AZs carry under the {CPU_CEILING * 100:.0f} % ceiling | {CPU_CEILING * stateless_vcpu / STATELESS_PEAK_VCPU:.1f}x the normal peak |")
    print(f"| Pinned slots of {CORES_PER_PROCESS} cores, in total and after the loss of one AZ | {slots} and {slots * (AZS - 1) // AZS}, for {PROCESSES} processes of {SHARDS} shards |")
    print(f"| Orders and cancels per risk shard per second, at normal peak and at 3x | {ORDERS_PER_SECOND / RISK_SHARDS:.0f} and {3 * ORDERS_PER_SECOND / RISK_SHARDS:.0f} |")
    peak_shard = 3 * ORDERS_PER_SECOND / RISK_SHARDS
    print(f"| Busy share of a risk shard at 3x with one transaction per order and a mean commit time equal to the {COMMIT_BUDGET_MS} ms budget | {peak_shard * COMMIT_BUDGET_MS / 1e3:.2f} |")
    print(f"| Mean commit time under which a risk shard at 3x stays below a busy share of {BUSY_SHARE_LIMIT}, ms | {BUSY_SHARE_LIMIT / peak_shard * 1e3:.1f} |")
    print(f"| WebSocket reconnect wave of {WS_CONNECTIONS:,} connections in {WS_WAVE_SECONDS} s | {wave_per_second:.0f} new connections per second against {surviving_pods * WS_POD_NEW_PER_SECOND} on the {surviving_pods} pods left after the loss of one AZ, which hold {surviving_pods * WS_POD_CONNECTIONS:,} connections |")
    print(f"| ALB capacity units of that wave, new connections averaged over the hour and open connections | {WS_CONNECTIONS / 3600 / 25:.2f} and {WS_CONNECTIONS / 3000:.2f}, against {alb_gb / HOURS:.1f} from processed bytes |")
    print(f"| Aurora I/O per month above which I/O-Optimized costs less, in millions | {io_extra / p('aurora.io'):,.0f} |")
    print(f"| One interface endpoint in 3 AZs, USD per month | {endpoint_month:.2f} |")
    print(f"| Traffic per month above which that endpoint costs less than the NAT and Network Firewall path, GB | {endpoint_month / (p('nfw.gb') - p('vpce.gb')):,.0f} |")
    print(f"| Telemetry through NAT and Network Firewall, logs and metrics, GB per month | {LOGS_GB:,.0f} and {TELEMETRY_GB - LOGS_GB:,.0f} |")
    print(f"| Witness writes to `<DR_REGION>`, GB per month | {witness_gb:,.1f} |")
    print(f"| Largest line of the on-demand column, USD per month | {largest['item']}, {largest['od']:,.2f} |")
    print(f"| Data transfer out of CloudFront, billed by CloudFront and by Shield, USD per month | {dto['od'] + (REST_GB + ws_gb) * p('shield.cf.gb'):,.2f} |")
    print(f"| On-demand total change from 1.0 to 1.1 KB/s of WebSocket traffic per connection, USD per month | {sensitivity:,.2f} |")
    by_area = {}
    for r in rows:
        if r["kind"] in ("base", "support") and is_number(r["od"]):
            by_area[r["area"]] = by_area.get(r["area"], 0.0) + r["od"]
    for area, value in by_area.items():
        print(f"| Share of the on-demand total, {area} | {value / od * 100:.1f} % |")
    print(f"| Saving from eligible discounts, USD per month | {od - disc:,.2f} ({(od - disc) / od * 100:.1f} %) |")
    print(f"| Business Support+, USD per month | {support['od']:,.2f} on demand, {support['disc']:,.2f} with discounts, {support['small']:,.2f} in the smaller baseline, {support['sec']:,.2f} on the security column, {support['dr']:,.2f} on the DR column |")
    print(f"| Shield Advanced net of the WAF fees it removes, with the support fee on that amount, USD per month | {shield_net + shield_support:,.2f} ({shield_net:,.2f} and {shield_support:,.2f} of support) |")
    print(f"| Smaller baseline below the design, USD per month | {od - small:,.2f}: Shield Advanced net of WAF {gap_parts[2]:,.2f}, EKS control plane {gap_parts[0]:,.2f}, third Valkey node {gap_parts[1]:,.2f}, support {gap_parts[3]:,.2f} |")
    print(f"| Observability lines, USD per month | {telemetry:,.2f} ({telemetry / od * 100:.1f} %) |")
    print(f"| Security column against the on-demand total | {sec / od * 100:.1f} % |")
    print(f"| Detection lines, USD per month | {detection:,.2f}, the Problem 5 SC-11 rows |")
    print(f"| DR column against the on-demand total | {dr / od * 100:.1f} % |")


if __name__ == "__main__":
    main()
