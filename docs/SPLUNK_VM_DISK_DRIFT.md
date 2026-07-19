# Splunk VM disk drift (blocking prerequisite for tiered storage)

The Splunk VM's on-disk layout diverged from `modules/splunk-vm` out-of-band.
This drift is currently masked by `lifecycle.ignore_changes = [disk]` and must be
reconciled — under human supervision — before the new `fast-splunk`/`bulk-splunk`
tiered disks can actually attach on a real apply.

## What is declared vs. what is live

| Disk | Module declares | Live (drifted) |
| --- | --- | --- |
| Boot | `virtio0`, 25G | `scsi0`, 50G |
| Data | `virtio1`, 200G | `virtio1`, 200G (tracked in state) |
| Leftover disk-1 | (none) | reaped directly on the host |

`tofu` state tracks only the `virtio1` data disk. Because `bpg/proxmox` keys
disk blocks and reconciliation on the live VM has no record of the `scsi0` boot
disk, any un-ignored disk plan tries to unplug the live boot disk (Proxmox HTTP
400) and would reinterpret the 200G data disk. `ignore_changes = [disk]` is set
in `modules/splunk-vm/main.tf` for exactly this reason and must not be removed
casually — the VM has `prevent_destroy = true` and no working backup today.

## Why this cannot be reconciled mechanically here

- **The live values are not verifiable from this repo.** Confirming the exact
  current disk set (interfaces, datastore ids, sizes, `ssd`/`discard`/`backup`
  flags) requires querying the live Proxmox API / node, which is out of scope
  for static validation and CI.
- **Issue #247 (referenced in the code comment) does not exist** in
  `dryvist/tofu-proxmox`, so there is no additional recorded detail to reconcile
  against beyond "boot is `scsi0`/50G".
- Editing the declared disk blocks while `ignore_changes = [disk]` is active
  produces **no plan diff**, so it would be an unverifiable change that could
  mislead a future operator into thinking the config is truthful.

For these reasons this repo does **not** guess at live disk values. The declared
blocks are left as-is and the drift is documented here as a flagged prerequisite.

## `ignore_changes` narrowing finding (tiered disks)

Narrowing `ignore_changes` to a positional index (e.g. `disk[0]`, `disk[1]`) to
un-ignore only the new `virtio2`/`virtio3` tiers is **not viable** on
`bpg/proxmox`: the provider keys disk blocks by their `interface`, not
positionally, so a numeric `ignore_changes` index does not stably map to a given
disk across refreshes (Terraform's `ignore_changes` indexing is undefined for
set-like nested blocks). Keeping the whole `disk` attribute ignored is the only
safe state today. **Consequence:** while `disk` stays ignored, the
`var.tiered_disks` blocks are declared but produce no plan diff and will not
attach.

## What a real reconciliation requires (human-supervised, out of scope here)

1. Capture the live layout from the node (`qm config <vmid>` / Proxmox API):
   exact interface, `datastore_id`, `size`, `ssd`, `discard`, `backup` for the
   boot disk, `virtio1`, and anything else attached.
2. Update the declared disk blocks in `modules/splunk-vm/main.tf` to match
   reality (boot `scsi0`/50G, etc.).
3. Align `tofu` state with the live disks (import / `tofu state` ops); confirm a
   no-op plan with `disk` still ignored.
4. Remove the `disk` entry from `ignore_changes` under a reviewed plan and
   confirm the plan creates **only** the new `virtio2`/`virtio3` tiered disks and
   touches nothing else.
5. Apply in a supervised window, respecting `prevent_destroy = true` and the
   absence of a backup.

Until step 4 completes, `fast-splunk`/`bulk-splunk` remain declared-but-inert.
