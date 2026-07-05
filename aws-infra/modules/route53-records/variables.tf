variable "route53_zone_id" {
  description = "Route53 hosted zone ID for DNS record management"
  type        = string

  validation {
    condition     = can(regex("^Z[A-Z0-9]+$", var.route53_zone_id))
    error_message = "Route53 zone ID must start with 'Z' followed by alphanumeric characters."
  }
}

variable "proxmox_domain" {
  description = "Fully qualified domain name for Proxmox VE UI (e.g., pve.example.com)"
  type        = string

  validation {
    condition     = can(regex("^[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?(\\.[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?)*$", var.proxmox_domain))
    error_message = "Proxmox domain must be a valid fully qualified domain name."
  }
}

variable "proxmox_ip_address" {
  description = "Legacy single IP address of a Proxmox VE host. Used only when proxmox_ip_addresses is empty."
  type        = string
  default     = ""

  validation {
    condition     = var.proxmox_ip_address == "" || can(cidrnetmask("${var.proxmox_ip_address}/32"))
    error_message = "Proxmox IP address must be a valid IPv4 address."
  }
}

variable "proxmox_ip_addresses" {
  description = "IP addresses of active Proxmox VE API endpoints for the shared Proxmox UI/API DNS record."
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for ip in var.proxmox_ip_addresses : can(cidrnetmask("${ip}/32"))])
    error_message = "Every Proxmox IP address must be a valid IPv4 address."
  }
}

variable "dns_ttl" {
  description = "DNS TTL in seconds for the A record"
  type        = number
  default     = 300 # 5 minutes

  validation {
    condition     = var.dns_ttl >= 60 && var.dns_ttl <= 86400
    error_message = "DNS TTL must be between 60 seconds (1 minute) and 86400 seconds (24 hours)."
  }
}

variable "route53_cnames" {
  description = "Map of service-alias CNAME records: record label (relative to the zone) -> target FQDN"
  type        = map(string)
  default     = {}
}

variable "environment" {
  description = "Environment name for tagging and organization"
  type        = string
  default     = "homelab"
}
