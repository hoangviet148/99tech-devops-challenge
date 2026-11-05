provider "aws" {
  region                      = var.region
  access_key                  = var.offline ? "mock_access_key" : null
  secret_key                  = var.offline ? "mock_secret_key" : null
  skip_credentials_validation = var.offline
  skip_requesting_account_id  = var.offline
  skip_metadata_api_check     = var.offline
  allowed_account_ids         = var.offline ? null : [var.accounts.delivery]

  default_tags {
    tags = {
      environment  = "delivery"
      "managed-by" = "terraform"
    }
  }
}
