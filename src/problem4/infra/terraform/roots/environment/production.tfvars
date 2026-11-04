environment        = "production"
vpc_cidr           = "10.30.0.0/16"
availability_zones = ["ap-southeast-1a", "ap-southeast-1b"]

fleet = {
  instance_type = "t3.small"
  min_size      = 2
  max_size      = 6
}

frontend_bucket            = "example-frontend-production"
frontend_domain            = "www.example.com"
alb_certificate_arn        = "arn:aws:acm:ap-southeast-1:777788889999:certificate/00000000-0000-0000-0000-000000000001"
cloudfront_certificate_arn = "arn:aws:acm:us-east-1:777788889999:certificate/00000000-0000-0000-0000-000000000002"
