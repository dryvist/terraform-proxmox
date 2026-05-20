# PowerEdge cluster module.
#
# Scope today: declarative inventory of PowerEdge nodes that will join the
# Proxmox cluster. Emits outputs that other repos (ansible-proxmox) consume
# via terraform_remote_state so the IP/MAC/service-tag values stay DRY across
# the org and out of public files.
#
# Future scope (commented enable below): when nodes are physically online and
# joined to the cluster, swap the locals-only mode for data sources against the
# bpg/proxmox provider's proxmox_virtual_environment_nodes to verify the live
# node list matches the declared inventory.

locals {
  # Group by chassis model — handy for ansible-proxmox group_vars selection.
  by_chassis = {
    for chassis in distinct([for k, v in var.poweredge_nodes : v.chassis]) :
    chassis => {
      for k, v in var.poweredge_nodes : k => v if v.chassis == chassis
    }
  }
}

# Future cluster-membership verification (uncomment when nodes are joined):
#
# data "proxmox_virtual_environment_nodes" "live" {}
#
# check "all_declared_nodes_in_cluster" {
#   assert {
#     condition = alltrue([
#       for name, _ in var.poweredge_nodes :
#       contains(data.proxmox_virtual_environment_nodes.live.names, name)
#     ])
#     error_message = "One or more declared PowerEdge nodes are not present in the live Proxmox cluster."
#   }
# }
