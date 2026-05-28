# =============================================================================
# iDRAC KVM LXC Firewall Configuration
#
# One unprivileged LXC per physical iDRAC (R410 → LXC 252, R710 → LXC 253),
# each running a domistyle/idrac6 Docker container that exposes the HTML5
# noVNC viewer on TCP 5800. Was a dedicated docker VM (idrac-kvm, VMID 251)
# that has been retired in favor of one LXC per target.
# Extracted from container_rules.tf to keep that file under the shared
# _file-size workflow's 12 KB error threshold (same pattern as infisical).
# =============================================================================

resource "proxmox_virtual_environment_firewall_options" "idrac_kvm_container" {
  for_each = var.idrac_kvm_container_ids

  node_name     = var.node_name
  container_id  = each.value
  enabled       = local.firewall_defaults.enabled
  input_policy  = local.firewall_defaults.input_policy
  output_policy = local.firewall_defaults.output_policy
  log_level_in  = local.firewall_defaults.log_level_in
  log_level_out = local.firewall_defaults.log_level_out

  depends_on = [proxmox_virtual_environment_cluster_firewall.main]
}

resource "proxmox_virtual_environment_firewall_rules" "idrac_kvm_container" {
  for_each = var.idrac_kvm_container_ids

  node_name    = var.node_name
  container_id = each.value

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.internal_access.name
    comment        = "Internal access (SSH, ICMP)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.idrac_kvm_svc.name
    comment        = "iDRAC HTML5 noVNC viewer (TCP 5800)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.outbound_internal.name
    comment        = "Outbound to internal only (reaches iDRAC BMC subnet)"
  }

  depends_on = [proxmox_virtual_environment_firewall_options.idrac_kvm_container]
}
