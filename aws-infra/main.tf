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

# =============================================================================
# OpenBao auto-unseal — KMS key + scoped IAM user
# =============================================================================
# WARNING: ELEVATED AWS PERMISSIONS REQUIRED TO APPLY THIS MODULE.
#
# Provisioning a KMS key + IAM user requires an AWS principal that holds:
#   kms:CreateKey, kms:CreateAlias, iam:CreateUser, iam:PutUserPolicy,
#   iam:CreateAccessKey
#
# The aws-infra provider's current Route53-scoped credentials (AWS_ROUTE53_*)
# most likely LACK these permissions. Do NOT assume the existing creds work.
# Apply this unit with an admin-capable principal — e.g. the tf-proxmox profile
# if it carries IAM/KMS permissions, or a dedicated bootstrap user.
#
# After apply, load the outputs into Doppler for the OpenBao nodes:
#   unseal_access_key_id     -> OPENBAO_UNSEAL_AWS_ACCESS_KEY_ID
#   unseal_secret_access_key -> OPENBAO_UNSEAL_AWS_SECRET_ACCESS_KEY
#   kms_key_id               -> OPENBAO_KMS_KEY_ID
#   aws_region               -> OPENBAO_KMS_REGION
#
# See aws-infra/README.md ("OpenBao Auto-Unseal") for the full procedure.
# =============================================================================
module "openbao_unseal" {
  count  = var.enable_openbao_unseal ? 1 : 0
  source = "./modules/openbao-unseal"

  environment = var.environment
}

# Future AWS resources go here:
# - IAM users/roles for Terraform
# - S3 buckets for backups
# - CloudWatch alarms
# - etc.
