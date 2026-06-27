terraform {
  required_version = ">= 1.10"

  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# AWS Provider - credentials from Doppler environment variables
# Static credentials are used here because this infrastructure runs on a local Proxmox host
# rather than on AWS infrastructure. For production AWS environments, consider using
# IAM roles, instance profiles, or the AWS CLI credential chain instead.
provider "aws" {
  region     = var.aws_region
  access_key = var.aws_access_key
  secret_key = var.aws_secret_key
}

# Route53 DNS Records module - manages A record for Proxmox VE UI
module "route53_records" {
  count  = var.enable_route53_dns ? 1 : 0
  source = "./modules/route53-records"

  route53_zone_id    = var.route53_zone_id
  proxmox_domain     = var.proxmox_domain
  proxmox_ip_address = var.proxmox_ip_address
  dns_ttl            = var.dns_ttl
  environment        = var.environment
}

# Future AWS resources go here:
# - IAM users/roles for Terraform
# - S3 buckets for backups
# - CloudWatch alarms
# - etc.
