output "vm_id" {
  description = "The VM ID of the Splunk VM"
  value       = proxmox_virtual_environment_vm.splunk_vm.vm_id
}

output "name" {
  description = "The name of the Splunk VM"
  value       = proxmox_virtual_environment_vm.splunk_vm.name
}

output "ip_address" {
  description = "The IPv4 address of the Splunk VM (first non-loopback interface)"
  value = length(proxmox_virtual_environment_vm.splunk_vm.ipv4_addresses) > 1 ? (
    length(proxmox_virtual_environment_vm.splunk_vm.ipv4_addresses[1]) > 0 ?
    split("/", proxmox_virtual_environment_vm.splunk_vm.ipv4_addresses[1][0])[0] : null
  ) : null
}

output "mac_address" {
  description = "The MAC address of the Splunk VM network interface"
  value       = length(proxmox_virtual_environment_vm.splunk_vm.mac_addresses) > 0 ? proxmox_virtual_environment_vm.splunk_vm.mac_addresses[0] : null
}

output "tiered_disks" {
  description = "Tiered Splunk data disks (fast-splunk/bulk-splunk) as declared, keyed by tier."
  value       = var.tiered_disks
}
