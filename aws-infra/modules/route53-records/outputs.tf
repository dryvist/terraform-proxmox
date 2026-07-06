output "proxmox_record_fqdn" {
  description = "Fully qualified domain name of the Proxmox A record (null when not published)"
  value       = one(aws_route53_record.proxmox[*].fqdn)
}

output "proxmox_record_name" {
  description = "Name of the Proxmox A record (null when not published)"
  value       = one(aws_route53_record.proxmox[*].name)
}

output "proxmox_record_ttl" {
  description = "TTL of the Proxmox A record (null when not published)"
  value       = one(aws_route53_record.proxmox[*].ttl)
}

output "proxmox_ip_address" {
  description = "First IP address the Proxmox domain resolves to"
  value       = local.proxmox_ip_addresses[0]
}

output "proxmox_ip_addresses" {
  description = "IP addresses the Proxmox domain resolves to"
  value       = local.proxmox_ip_addresses
}

output "route53_zone_id" {
  description = "Route53 hosted zone ID used for DNS records"
  value       = var.route53_zone_id
}
