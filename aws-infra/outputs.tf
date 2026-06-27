# Route53 DNS outputs
# These can be consumed by the Proxmox configuration via remote state or data files

output "proxmox_domain_fqdn" {
  description = "Fully qualified domain name for Proxmox VE UI"
  value       = try(module.route53_records[0].proxmox_record_fqdn, "")
}

output "proxmox_dns_record_name" {
  description = "DNS record name for Proxmox VE UI"
  value       = try(module.route53_records[0].proxmox_record_name, "")
}

output "proxmox_dns_ttl" {
  description = "DNS TTL for Proxmox VE UI"
  value       = try(module.route53_records[0].proxmox_record_ttl, 0)
}

output "proxmox_ip_address" {
  description = "IP address the Proxmox domain resolves to"
  value       = try(module.route53_records[0].proxmox_ip_address, "")
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID used for DNS records"
  value       = try(module.route53_records[0].route53_zone_id, "")
}

# Cross-reference output for Proxmox ACME configuration
# This provides the domain that should be used for certificate requests
output "acme_domain" {
  description = "Domain to use for ACME certificate requests"
  value       = var.proxmox_domain
}
