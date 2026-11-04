environment        = "staging"
vpc_cidr           = "10.20.0.0/16"
availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]

fleet = {
  instance_type = "t3.small"
  min_size      = 2
  max_size      = 4
}

frontend_bucket            = "example-frontend-staging"
frontend_domain            = "staging.example.com"
alb_certificate_arn        = "arn:aws:acm:ap-southeast-1:444455556666:certificate/00000000-0000-0000-0000-000000000001"
cloudfront_certificate_arn = "arn:aws:acm:us-east-1:444455556666:certificate/00000000-0000-0000-0000-000000000002"
