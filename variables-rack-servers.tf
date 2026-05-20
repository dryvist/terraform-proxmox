# Rack-server variables: cluster identity for 1U/2U servers joining the
# Proxmox cluster (Dell PowerEdge, HPE ProLiant, Supermicro, etc.).
#
# DRY: real values supplied via SOPS-encrypted terraform.sops.json — see
# terraform.sops.json.example for the placeholder shape. Public repo never
# contains real IPs, MACs, service tags, or hostnames.

variable "rack_servers" {
  description = <<-EOT
    Map of rack servers joining the Proxmox cluster. Keyed by node name
    (chosen by the operator — e.g. "node-a", "node-b"). Real values supplied
    via SOPS-encrypted terraform.sops.json; default is an empty map so plans
    succeed cleanly before any nodes are populated.

    Fields:
      chassis     - Free-form model identifier ("r410", "r710", "dl360-g6",
                    "x10sdv", etc.). Not validated against a vendor list so
                    HPE/Supermicro/etc. fit alongside Dell.
      bmc_ip      - Out-of-band management IP (iDRAC on Dell, iLO on HPE,
                    IMM on Lenovo, etc.).
      bmc_mac     - BMC NIC MAC address (dedicated NIC where available).
      service_tag - Vendor service tag, used for inventory + warranty lookup.
      mgmt_ip     - Host OS management IP (PVE web UI, SSH).
  EOT
  type = map(object({
    chassis     = string
    bmc_ip      = string
    bmc_mac     = string
    service_tag = string
    mgmt_ip     = string
  }))
  default = {}
}
