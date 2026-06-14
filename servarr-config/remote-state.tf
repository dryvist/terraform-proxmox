# Partial S3 backend — the bucket (which embeds the AWS account id) is supplied
# at init time via -backend-config, so it is never committed:
#   tofu init -backend-config="bucket=terraform-proxmox-state-useast2-$(aws sts get-caller-identity --query Account --output text)"
# (named remote-state.tf because the repo gitignores backend.tf — terragrunt-generated)
terraform {
  backend "s3" {
    key            = "terraform-proxmox/servarr-config/terraform.tfstate"
    region         = "us-east-2"
    dynamodb_table = "terraform-proxmox-locks-useast2"
    encrypt        = true
  }
}
