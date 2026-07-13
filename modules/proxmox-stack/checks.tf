# Storage-safety policy-as-code (advisory).
#
# Surfaces, at plan/apply time, any guest that holds persistent data
# (additional_disks on VMs, mount_points on LXCs) yet is not protection-flagged.
#
# "Deny accidental destroy" is enforced by two non-deadlocking mechanisms:
#   1. Proxmox `protection = true` on the guest — the Proxmox API refuses to
#      delete a protected guest or its disks until protection is removed.
#   2. CODEOWNERS review on deployment.json / storage paths — weakening a
#      protection flag requires a reviewed PR.
#
# This is intentionally a `check` (warning) rather than a variable validation
# (hard error): a hard rule would deadlock intentional teardown, because you
# could never set protection = false to begin the removal. The warning keeps the
# policy visible without blocking deliberate, reviewed changes.
check "storage_guest_protection" {
  assert {
    condition = alltrue(concat(
      [for k, v in var.vms : v.protection if length(coalesce(v.additional_disks, [])) > 0],
      [for k, v in var.containers : v.protection if length(coalesce(v.mount_points, [])) > 0],
    ))
    error_message = "Storage-safety: guests with persistent data volumes (additional_disks / mount_points) should set protection = true so Proxmox refuses accidental deletion."
  }
}
