# PowerEdge node variables: cluster identity for Dell PowerEdge servers
# joining the Proxmox cluster.
#
# DRY: real values supplied via SOPS-encrypted terraform.sops.json — see
# terraform.sops.json.example for the placeholder shape. Public repo never
# contains real IPs, MACs, service tags, or hostnames.

variable "poweredge_nodes" {
  description = <<-EOT
    Map of PowerEdge nodes joining the Proxmox cluster. Keyed by node name
    (chosen by the operator — e.g. "node-a", "node-b"). Real values supplied
    via SOPS-encrypted terraform.sops.json; default is an empty map so plans
    succeed cleanly before any nodes are populated.

    Fields:
      chassis     - PowerEdge model identifier ("r410", "r710", etc.).
      idrac_ip    - iDRAC management IP on the management VLAN.
      idrac_mac   - iDRAC NIC MAC address (dedicated NIC when Enterprise
                    daughter card is installed).
      service_tag - Dell service tag, used for inventory + warranty lookup.
      mgmt_ip     - Host OS management IP (PVE web UI, SSH).
  EOT
  type = map(object({
    chassis     = string
    idrac_ip    = string
    idrac_mac   = string
    service_tag = string
    mgmt_ip     = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.poweredge_nodes :
      contains(["r410", "r710", "r720", "r730", "r740"], lower(v.chassis))
    ])
    error_message = "Each poweredge_nodes entry must set chassis to a supported PowerEdge model (r410, r710, r720, r730, r740)."
  }
}
