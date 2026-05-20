output "node_names" {
  description = "Sorted list of rack-server node names declared in the cluster inventory."
  value       = sort(keys(var.rack_servers))
}

output "bmc_ips" {
  description = "Map of node name to BMC management IP (iDRAC/iLO/IMM/etc.)."
  value       = { for k, v in var.rack_servers : k => v.bmc_ip }
}

output "bmc_macs" {
  description = "Map of node name to BMC NIC MAC address."
  value       = { for k, v in var.rack_servers : k => v.bmc_mac }
}

output "mgmt_ips" {
  description = "Map of node name to host OS management IP."
  value       = { for k, v in var.rack_servers : k => v.mgmt_ip }
}

output "service_tags" {
  description = "Map of node name to vendor service tag."
  value       = { for k, v in var.rack_servers : k => v.service_tag }
}

output "by_chassis" {
  description = "Nodes grouped by chassis model (e.g. r410, dl360-g6) — useful for ansible group_vars selection."
  value       = local.by_chassis
}

output "ansible_inventory" {
  description = "Ansible-friendly inventory shape: list of hosts with BMC/mgmt addresses, MAC, and chassis tag. Consume from ansible-proxmox via terraform_remote_state."
  value = [
    for name, node in var.rack_servers : {
      name        = name
      mgmt_ip     = node.mgmt_ip
      bmc_ip      = node.bmc_ip
      bmc_mac     = node.bmc_mac
      chassis     = node.chassis
      service_tag = node.service_tag
    }
  ]
}
