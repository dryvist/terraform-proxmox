# Startup dependency tiers -> Proxmox `startup.order` (bpg/proxmox provider;
# LOWER order value starts first — matches this repo's pre-existing
# `order = 256 - vm_id` convention in modules/proxmox-container and
# modules/proxmox-vm, where higher VMIDs got a lower order and started first).
#
# Before this map, every 6-digit-VMID guest (the current fleet) computed
# `max(0, 256 - vm_id)` and got clamped to the SAME order (0), so Proxmox's
# tiebreak among them was undefined — the 2026-07-20 pve1 reboot (INC-17124,
# INC-17125) brought consumers up before their dependencies (Hindsight before
# postgres-ai; agents before DNS) purely by accident of that tiebreak, and the
# Splunk VM (no startup block at all) landed ~11.5 min after boot.
#
# Each guest sets `startup_tier` (1-5) in its definition; unset guests default
# to tier 3 (platform). Tiers are a dependency order, not the VLAN trust tier:
#   1 = core infra : DNS, secrets — everything else needs these reachable first
#   2 = data       : databases, vector stores, the log/SIEM platform (Splunk)
#   3 = platform   : ingress, pipeline, metrics (DEFAULT for unset guests)
#   4 = apps       : user-facing services that read the data/platform tiers
#   5 = agents     : callers into the rest of the stack — must be last up
locals {
  startup_tier_order = {
    1 = 100
    2 = 200
    3 = 300
    4 = 400
    5 = 500
  }
  default_startup_tier = 3
}
