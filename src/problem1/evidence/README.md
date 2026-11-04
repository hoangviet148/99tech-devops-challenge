# Evidence

| File | What it holds |
|---|---|
| `cost_estimate.py` | The cost model: quantities, unit prices with their price list versions, and the arithmetic behind section 8 of `SOLUTION.md` |
| `cost-estimate-2026-11-04.md` | The output of `python3 -I cost_estimate.py`, copied into section 8 |

## How the prices were read

Every unit price comes from the public AWS price list for ap-southeast-1, read on 2026-11-04 without credentials. For each service the region index gives the current offer file, and the offer file gives the price per usage type.

```bash
curl -s https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonMSK/current/region_index.json
curl -s -o AmazonMSK.json https://pricing.us-east-1.amazonaws.com/offers/v1.0/aws/AmazonMSK/20261103003605/ap-southeast-1/index.json
```

The prices of the security column were read the same way on 2026-11-05 from the offer files of GuardDuty, Security Hub, AWS Config, CloudTrail and Cognito, and the Verified Access prices from the AmazonVPC offer file. CloudFront, AWS WAF and Shield Advanced publish one global file under the region key `aws-other`. Compute Savings Plans rates come from `https://pricing.us-east-1.amazonaws.com/savingsPlan/v1.0/aws/AWSComputeSavingsPlan/20261104004726/ap-southeast-1/index.json`. Reserved rates for Aurora and ElastiCache come from the `Reserved` terms of their offer files, 1 year with no upfront payment. The MSK offer file has on-demand terms only, so MSK has no discounted rate.

## Vendor behaviour cited in `SOLUTION.md`

| Claim | Source, read on 2026-11-04 |
|---|---|
| Kinesis Data Streams consumers with dedicated throughput see a typical average propagation delay of 70 ms, and shared-throughput consumers about 200 ms with one consumer | https://docs.aws.amazon.com/streams/latest/dev/enhanced-consumers.html |
| An API Gateway WebSocket connection lasts at most 2 hours, with a 10 minute idle timeout | https://docs.aws.amazon.com/apigateway/latest/developerguide/apigateway-execution-service-websocket-limits-table.html |
| A DynamoDB `TransactWriteItems` call groups at most 100 actions on at most 100 distinct items, with 4 MB in total | https://docs.aws.amazon.com/amazondynamodb/latest/developerguide/transaction-apis.html |
| MSK tiered storage needs `cleanup.policy=delete` topics, keeps data in the low-cost tier for at least 3 days, does not run on `t3.small` brokers, and warns against `read_committed` reads from the remote tier unless the client uses transactions | https://docs.aws.amazon.com/msk/latest/developerguide/msk-tiered-storage.html |
| Compute Savings Plans apply to EC2, Fargate and Lambda only | https://docs.aws.amazon.com/savingsplans/latest/userguide/sp-services.html |
| Amazon ECS has no charge for orchestration, so ECS on EC2 pays only for instances | https://aws.amazon.com/ecs/pricing/ |
| The CloudFront flat-rate Premium plan costs 1,000 USD per month per distribution and includes 500 million requests and 50 TB, with larger allowances priced on request | https://aws.amazon.com/cloudfront/pricing/ |
| For resources protected by Shield Advanced, AWS WAF bills web ACLs, rules and tier 0 requests at 0 USD | Price list usage types `Global-ShieldProtected-WebACLV2`, `Global-ShieldProtected-RuleV2` and `Global-ShieldProtected-RequestV2-Tier0` in `awswaf` version 20260914163921 |

## Vendor behaviour behind the security column

| Claim | Source, read on 2026-11-05 |
|---|---|
| AWS Organizations has no charge, so the accounts and SCPs of SC-06 add no line | https://aws.amazon.com/organizations/faqs/ |
| CloudTrail delivers the first copy of management events at 0 USD | Price list usage type `APS1-FreeEventsRecorded` in `AWSCloudTrail` version 20261102172009 |
| KMS bills the first and second rotation of a key's material, and later rotations are free | https://docs.aws.amazon.com/kms/latest/developerguide/rotate-keys.html |
| The CloudFront price list has no usage type for VPC origins, and the VPC origin page puts no cost on the private IP addresses it uses, so SC-10 adds no line | `AmazonCloudFront` version 20261019150500, https://docs.aws.amazon.com/AmazonCloudFront/latest/DeveloperGuide/private-content-vpc-origins.html |
| Security Hub CSPM runs most of its controls as AWS Config rules | https://docs.aws.amazon.com/securityhub/latest/userguide/securityhub-setup-prereqs.html |
| VPC Flow Logs delivered to S3 are billed as logs from AWS services delivered to a destination other than CloudWatch | https://docs.aws.amazon.com/vpc/latest/userguide/flow-logs.html, price list usage type `APS1-S3-Egress-Bytes` |
| Cognito user pools have a multi-Region replication add-on, 0.006 USD per monthly active user on the Plus plan | Price list usage type `APS1-CognitoPlusMRRMAU` in `AmazonCognito` version 20261020233814 |
