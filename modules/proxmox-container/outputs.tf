output "container_ids" {
  description = "Map of container names to their IDs"
  value       = { for k, v in proxmox_virtual_environment_container.containers : k => v.vm_id }
}

output "container_details" {
  description = "Complete container information"
  value = { for k, v in proxmox_virtual_environment_container.containers : k => {
    id          = v.vm_id
    node_name   = v.node_name
    description = v.description
    tags        = v.tags
    pool_id     = v.pool_id
  } }
}

output "container_network_interfaces" {
  description = "Container network interface configuration (computed attributes not available in bpg/proxmox v0.90+)"
  value = { for k, v in proxmox_virtual_environment_container.containers : k => {
    # Note: In bpg/proxmox v0.90+, network attributes (ipv4_addresses, mac_addresses, etc.)
    # are not exposed as computed attributes. Use 'tofu show' to view runtime network details.
    configured_interfaces = length(v.network_interface)
  } }
}
