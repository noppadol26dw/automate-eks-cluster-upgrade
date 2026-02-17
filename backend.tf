# # S3 backend. Locking via S3 lockfile (use_lockfile); no DynamoDB.
# # See: https://developer.hashicorp.com/terraform/language/settings/backends/s3
# # Enable bucket versioning on the state bucket for state recovery.
# # Replace the bucket name with your state bucket before first init.
# terraform {
#   backend "s3" {
#     bucket       = "your-terraform-state-bucket"
#     key          = "eks-upgrade-automation/terraform.tfstate"
#     region       = "us-east-1"
#     encrypt      = true
#     use_lockfile = true
#   }
# }
