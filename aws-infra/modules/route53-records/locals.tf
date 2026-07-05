locals {
  proxmox_ip_addresses = sort(distinct(
    length(var.proxmox_ip_addresses) > 0 ? var.proxmox_ip_addresses : [var.proxmox_ip_address]
  ))
}
