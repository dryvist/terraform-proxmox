# Terragrunt configuration for AWS infrastructure
# COMPLETELY SEPARATE from Proxmox infrastructure

terraform {
  source = "."
}

# Remote state backend configuration using S3 + DynamoDB
# Uses a DIFFERENT state key than Proxmox to keep states isolated
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "terraform-proxmox-state-useast2-${get_aws_account_id()}"
    key            = "terraform-proxmox/aws-infra/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "terraform-proxmox-locks-useast2"

    max_retries = 5
  }
}

# AWS credentials from Doppler environment variables
# These should be set for the Route53/IAM user, NOT the terraform S3 backend user
# Supports both AWS_ROUTE53_* and ROUTE53_* naming conventions for backwards compatibility
inputs = {
  aws_access_key       = get_env("AWS_ROUTE53_ACCESS_KEY", get_env("ROUTE53_ACCESS_KEY", ""))
  aws_secret_key       = get_env("AWS_ROUTE53_SECRET_KEY", get_env("ROUTE53_SECRET_KEY", ""))
  route53_zone_id      = get_env("ROUTE53_ZONE_ID", "")
  proxmox_domain       = get_env("PROXMOX_DOMAIN", "")
  proxmox_ip_address   = get_env("PROXMOX_IP_ADDRESS", "")
  proxmox_ip_addresses = compact(split(",", get_env("PROXMOX_IP_ADDRESSES", get_env("PROXMOX_IP_ADDRESS", ""))))
  aws_region           = get_env("AWS_REGION", "us-east-1")
  environment          = get_env("ENVIRONMENT", "homelab")
  # Service-alias CNAMEs: comma-separated "label=target.fqdn" pairs, e.g.
  # ROUTE53_CNAMES="llm-large=host.example.com". Values live in Doppler so no
  # hostname literal is committed.
  route53_cnames = {
    for pair in compact(split(",", get_env("ROUTE53_CNAMES", ""))) :
    trimspace(split("=", pair)[0]) => trimspace(split("=", pair)[1])
  }
}

# Terragrunt will generate provider.tf with AWS provider settings
generate "provider" {
  path      = "provider_override.tf"
  if_exists = "overwrite"
  contents  = <<EOF
terraform {
  required_version = ">= 1.10"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 5.0"
    }
  }
}
EOF
}
