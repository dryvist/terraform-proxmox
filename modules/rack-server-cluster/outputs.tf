output "node_names" {
  description = "Sorted list of rack-server node names declared in the cluster inventory."
  value       = sort(keys(var.rack_servers))
  # Names are operator-chosen labels (node-a, node-b); not sensitive by themselves.
  sensitive = false
}

output "bmc_ips" {
  description = "Map of node name to BMC management IP (iDRAC/iLO/IMM/etc.). Sensitive — BMC is the privileged out-of-band interface."
  value       = { for k, v in var.rack_servers : k => v.bmc_ip }
  sensitive   = true
}

output "bmc_macs" {
  description = "Map of node name to BMC NIC MAC address. Sensitive — pairs with bmc_ip for DHCP/switch-port attacks."
  value       = { for k, v in var.rack_servers : k => v.bmc_mac }
  sensitive   = true
}

output "mgmt_ips" {
  description = "Map of node name to host OS management IP. Sensitive — direct SSH target."
  value       = { for k, v in var.rack_servers : k => v.mgmt_ip }
  sensitive   = true
}

output "service_tags" {
  description = "Map of node name to vendor service tag. Sensitive — usable in social-engineering against vendor support."
  value       = { for k, v in var.rack_servers : k => v.service_tag }
  sensitive   = true
}

output "by_chassis" {
  description = "Nodes grouped by chassis model (e.g. r410, dl360-g6) — useful for ansible group_vars selection. Whole map is sensitive because the values include bmc_ip/mac."
  value       = local.by_chassis
  sensitive   = true
}

output "ansible_inventory" {
  description = "Ansible-friendly inventory shape: map of hosts keyed by node name, each with BMC/mgmt addresses, MAC, and chassis tag. Same shape as the root vms/containers outputs. Sensitive — same fields as the source rack_servers map."
  value = {
    for name, node in var.rack_servers : name => {
      mgmt_ip     = node.mgmt_ip
      bmc_ip      = node.bmc_ip
      bmc_mac     = node.bmc_mac
      chassis     = node.chassis
      service_tag = node.service_tag
    }
  }
  sensitive = true
}
