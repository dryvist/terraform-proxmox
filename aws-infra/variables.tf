# AWS Provider Configuration

variable "aws_region" {
  description = "AWS region for all AWS resources"
  type        = string
  default     = "us-east-1"

  validation {
    condition     = can(regex("^[a-z]{2}-[a-z]+-[0-9]{1}$", var.aws_region))
    error_message = "AWS region must be a valid region identifier (e.g., us-east-1)."
  }
}

variable "aws_access_key" {
  description = "AWS IAM access key for API access"
  type        = string
  sensitive   = true
}

variable "aws_secret_key" {
  description = "AWS IAM secret key for API access"
  type        = string
  sensitive   = true
}

# Route53 Configuration

variable "enable_route53_dns" {
  description = "Enable Route53 DNS record management"
  type        = bool
  default     = true
}

variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS record management"
  type        = string

  validation {
    condition     = can(regex("^Z[A-Z0-9]+$", var.route53_zone_id))
    error_message = "Route53 zone ID must start with 'Z' followed by alphanumeric characters."
  }
}

# Proxmox Integration (values passed from Proxmox config or Doppler)

variable "proxmox_domain" {
  description = "Fully qualified domain name for Proxmox VE UI (e.g., pve.example.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*$", var.proxmox_domain))
    error_message = "Proxmox domain must be a valid fully qualified domain name."
  }
}

variable "proxmox_ip_address" {
  description = "IP address of Proxmox VE host"
  type        = string

  validation {
    condition     = can(cidrnetmask("${var.proxmox_ip_address}/32"))
    error_message = "Proxmox IP address must be a valid IPv4 address."
  }
}

variable "dns_ttl" {
  description = "DNS TTL in seconds for the A record"
  type        = number
  default     = 300

  validation {
    condition     = var.dns_ttl >= 60 && var.dns_ttl <= 86400
    error_message = "DNS TTL must be between 60 seconds (1 minute) and 86400 seconds (24 hours)."
  }
}

# General

variable "environment" {
  description = "Environment name for tagging and organization"
  type        = string
  default     = "homelab"
}
