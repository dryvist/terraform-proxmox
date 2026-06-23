# =============================================================================
# Honeypot container firewall (per-VLAN OpenCanary tripwires + apprise gateway)
# =============================================================================
#
# Two roles share the `honeypot` tag and this resource set:
#
#   * tripwires (honeypot, NOT notify) — emulate decoy services on every VLAN.
#     input DROP + honeypot_services (ACCEPT+log the decoy ports) so any touch
#     alerts; egress restricted to internal (outbound_internal) so a poked
#     sensor can reach the notify gateway (Path A) and HAProxy syslog 519
#     (Path B) but can NEVER beacon to the internet.
#
#   * notify gateway (honeypot + notify) — the apprise-api alert sink. input
#     DROP + honeypot_notify_services (just :8000); output ACCEPT so it can
#     fan out to Slack / Pushover / ntfy.sh (same open-egress posture as the
#     Mailpit/ntfy notification containers).
#
# A guest is the notify gateway iff its key is in honeypot_notify_container_ids
# (a subset of honeypot_container_ids). Membership drives both the per-guest
# output_policy and which rule set applies — mirroring how pipeline_container
# grants Cribl-Edge-only HTTPS egress within one shared resource.

resource "proxmox_virtual_environment_firewall_options" "honeypot_container" {
  for_each = var.honeypot_container_ids

  node_name    = var.node_name
  container_id = each.value
  enabled      = local.firewall_defaults.enabled
  input_policy = local.firewall_defaults.input_policy
  # Notify gateway needs the internet (external notifiers); tripwires must not
  # have it (a compromised decoy must not exfiltrate).
  output_policy = contains(keys(var.honeypot_notify_container_ids), each.key) ? "ACCEPT" : local.firewall_defaults.output_policy
  # Decoy interactions are the signal — log inbound at info, not warning.
  log_level_in  = "info"
  log_level_out = local.firewall_defaults.log_level_out

  depends_on = [proxmox_virtual_environment_cluster_firewall.main]
}

resource "proxmox_virtual_environment_firewall_rules" "honeypot_container" {
  for_each = var.honeypot_container_ids

  node_name    = var.node_name
  container_id = each.value

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.internal_access.name
    comment        = "Internal access (SSH, ICMP)"
  }

  # Notify gateway: apprise-api inbound only.
  dynamic "rule" {
    for_each = contains(keys(var.honeypot_notify_container_ids), each.key) ? [1] : []
    content {
      security_group = proxmox_virtual_environment_cluster_firewall_security_group.honeypot_notify_services.name
      comment        = "Honeypot alert gateway (apprise-api)"
    }
  }

  # Tripwires: decoy service surface + internal-only egress (reach notify
  # gateway + HAProxy syslog 519; no internet).
  dynamic "rule" {
    for_each = contains(keys(var.honeypot_notify_container_ids), each.key) ? [] : [1]
    content {
      security_group = proxmox_virtual_environment_cluster_firewall_security_group.honeypot_services.name
      comment        = "Honeypot decoy services (FTP/HTTP/SMB/DB/RDP/SNMP/...)"
    }
  }

  dynamic "rule" {
    for_each = contains(keys(var.honeypot_notify_container_ids), each.key) ? [] : [1]
    content {
      security_group = proxmox_virtual_environment_cluster_firewall_security_group.outbound_internal.name
      comment        = "Outbound to internal only (notify gateway + syslog 519)"
    }
  }

  depends_on = [proxmox_virtual_environment_firewall_options.honeypot_container]
}
