output "node_names" {
  description = "Sorted list of PowerEdge node names declared in the cluster inventory."
  value       = sort(keys(var.poweredge_nodes))
}

output "idrac_ips" {
  description = "Map of node name to iDRAC management IP."
  value       = { for k, v in var.poweredge_nodes : k => v.idrac_ip }
}

output "idrac_macs" {
  description = "Map of node name to iDRAC NIC MAC address."
  value       = { for k, v in var.poweredge_nodes : k => v.idrac_mac }
}

output "mgmt_ips" {
  description = "Map of node name to host OS management IP."
  value       = { for k, v in var.poweredge_nodes : k => v.mgmt_ip }
}

output "service_tags" {
  description = "Map of node name to Dell service tag."
  value       = { for k, v in var.poweredge_nodes : k => v.service_tag }
}

output "by_chassis" {
  description = "Nodes grouped by chassis model (e.g. r410, r710) — useful for ansible group_vars selection."
  value       = local.by_chassis
}

output "ansible_inventory" {
  description = "Ansible-friendly inventory shape: list of hosts with iDRAC/mgmt addresses, MAC, and chassis tag. Consume from ansible-proxmox via terraform_remote_state."
  value = [
    for name, node in var.poweredge_nodes : {
      name        = name
      mgmt_ip     = node.mgmt_ip
      idrac_ip    = node.idrac_ip
      idrac_mac   = node.idrac_mac
      chassis     = node.chassis
      service_tag = node.service_tag
    }
  ]
}
