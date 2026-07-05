terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
  }
}

# NOTE: AWS Provider is configured in parent module (aws-infra/main.tf)
# This module inherits the provider from its parent

# A Record for Proxmox VE UI
# Points the Proxmox domain to all active Proxmox API endpoints.
resource "aws_route53_record" "proxmox" {
  #checkov:skip=CKV2_AWS_23: Proxmox is on-premises infrastructure with a static IP; AWS alias resource is architecturally inapplicable
  zone_id = var.route53_zone_id
  name    = var.proxmox_domain
  type    = "A"
  ttl     = var.dns_ttl
  records = local.proxmox_ip_addresses

  lifecycle {
    # Prevent accidental deletion of critical DNS record
    prevent_destroy = false # Set to true in production
  }
}
