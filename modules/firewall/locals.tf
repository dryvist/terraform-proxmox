# =============================================================================
# Rule Data & Firewall Defaults
# =============================================================================

# Firewall defaults shared across all VM/container options resources
locals {
  firewall_defaults = {
    enabled       = true
    input_policy  = "DROP"
    output_policy = "DROP"
    log_level_in  = "warning"
    log_level_out = "warning"
  }
}

# Zero-trust source-VLAN CIDRs (staged disabled). Keys mirror var.vlan_ids /
# terragrunt.hcl's network_cidrs map. A missing key -> "" so a rule referencing
# an undeployed VLAN is inert rather than a plan error.
locals {
  zt_src = { for k in [
    "dns", "mgmt", "bmc", "compute", "pipeline", "data",
    "siem", "ai", "apps", "media_svc", "homeauto", "nonprod",
  ] : k => lookup(var.network_cidrs, k, "") }

  # Zero-trust flows are staged disabled. Flip per-rule in a later PR once
  # each is observed against the allow+log baseline.
  zt_enabled = false

  # Ingress (Traefik HA) guest firewall is DEFINE-DISABLED, same staged pattern
  # as zero-trust above. Today the ingress containers run un-firewalled so
  # keepalived VRRP flows freely; ingress_rules.tf declares the eventual DROP
  # policy + its 80/443 and VRRP pre-allows so a future flip to `true` (in its
  # own observed PR) cannot black-hole the floating VIP. Follow-up: enable after
  # an allow+log baseline confirms no legitimate ingress flow is missed.
  ingress_fw_enabled = false
}
