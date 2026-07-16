# Apps-tier Proxmox HA (PVE 9 "HA rules" model).
#
# SHIPS DISABLED. var.apps_ha_enabled defaults false, so nothing here is created
# until it is deliberately turned on. It must stay off until two things are true:
#
#   1. STORAGE. These guests sit on node-local `local-zfs` with NO cross-node
#      replication — there is no Proxmox pvesr, and syncoid only ships DR copies
#      into `bulk/replica/<node>/...` backup slots, not the live
#      `rpool/data/subvol-<vmid>-disk-0` path HA needs to start a guest elsewhere.
#      Relocating onto a node that lacks the rootfs is an outage. Live per-guest
#      replication (pvesr or equivalent) is the real prerequisite.
#   2. OWNERSHIP. ansible-proxmox `roles/pve_ha` already manages `/etc/pve/ha`
#      via ha-manager. Enabling this makes tofu a second writer of the same
#      files. Pick ONE owner before flipping apps_ha_enabled on.
#
# PVE 9 note: HA *groups* (proxmox_hagroup) are superseded by HA *rules*, so node
# pinning is a node-affinity `proxmox_harule` and guest enrollment is
# `proxmox_haresource` — not the deprecated `proxmox_hagroup`.
#
# Membership is tag-driven, mirroring the `ingress` tag (locals-ingress-ha.tf):
# any container tagged `ha` is enrolled. The affinity nodes are the distinct
# node_names of the tagged guests, so a sleeping node (proxmox-3) is excluded
# automatically because no ha-tagged guest lives there.
# ponytail: affinity node set = union of tagged guests' home nodes; if a pure
# failover-only target node is ever needed, tag a guest onto it or widen this local.
locals {
  ha_container_keys = [
    for k, v in var.containers : k
    if contains(coalesce(try(v.tags, null), []), "ha")
  ]
  ha_enabled = var.apps_ha_enabled && length(local.ha_container_keys) > 0
  ha_nodes = toset([
    for k in local.ha_container_keys :
    coalesce(try(var.containers[k].node_name, null), var.proxmox_node)
  ])
}

# Enroll each tagged LXC as an HA resource. max_relocate is deliberately low:
# with no cross-node storage replication the payload is restart-in-place, not
# relocation (see roles/pve_ha for the same reasoning).
resource "proxmox_haresource" "apps" {
  for_each = local.ha_enabled ? toset(local.ha_container_keys) : toset([])

  resource_id  = "ct:${var.containers[each.value].vm_id}"
  state        = "started"
  max_restart  = 1
  max_relocate = 1
  comment      = "tofu-proxmox apps-tier HA"
}

# Confine the apps-tier guests to the always-on apps nodes (the PVE 9 replacement
# for a `restricted` HA group). Equal priority: no preferred node among them.
resource "proxmox_harule" "apps_node_affinity" {
  count = local.ha_enabled ? 1 : 0

  rule      = "apps-node-affinity"
  type      = "node-affinity"
  comment   = "Apps-tier guests are confined to the always-on apps nodes"
  resources = [for k in local.ha_container_keys : "ct:${var.containers[k].vm_id}"]
  nodes     = { for n in local.ha_nodes : n => 1 }
  strict    = true

  depends_on = [proxmox_haresource.apps]
}
