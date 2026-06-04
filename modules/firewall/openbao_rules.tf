# OpenBao secrets-management containers (native single-binary LXC: Raft node 1 of a future 3-node HA cluster)
# Raft storage is local to each node (8201 cluster port) — Phase 1 runs a single node, so 8201 has no
# external peers yet but the rule is in place for the HA scale-out.
#
# Lives in its own file (rather than container_rules.tf) to keep container_rules.tf under the
# shared `_file-size` workflow's 12 KB error threshold. As more container types accrete, prefer
# adding new per-domain files like this one over growing container_rules.tf further.

resource "proxmox_virtual_environment_firewall_options" "openbao_container" {
  for_each = var.openbao_container_ids

  node_name     = var.node_name
  container_id  = each.value
  enabled       = local.firewall_defaults.enabled
  input_policy  = local.firewall_defaults.input_policy
  output_policy = local.firewall_defaults.output_policy
  log_level_in  = local.firewall_defaults.log_level_in
  log_level_out = local.firewall_defaults.log_level_out

  depends_on = [proxmox_virtual_environment_cluster_firewall.main]
}

resource "proxmox_virtual_environment_firewall_rules" "openbao_container" {
  for_each = var.openbao_container_ids

  node_name    = var.node_name
  container_id = each.value

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.internal_access.name
    comment        = "Internal access (SSH, ICMP)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.openbao_services.name
    comment        = "OpenBao API/UI + Raft cluster from internal"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.outbound_internal.name
    comment        = "Outbound to internal only"
  }

  depends_on = [proxmox_virtual_environment_firewall_options.openbao_container]
}
