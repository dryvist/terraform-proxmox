---
name: deployment-json-source-of-truth
description: deployment.json is the private RustFS desired-state object and terraform.tfvars must never exist
type: feedback
---

# deployment.json is the Single Source of Truth

The live `deployment.json` is a private, versioned RustFS object read by the
`tofu-proxmox` Terrakube workspace. It contains desired state, topology,
domain, and the public SSH key. It must never contain credentials or private
keys; those live in native OpenBao paths.

- Validate changes against `deployment.schema.json` before updating RustFS.
- Never commit the live object or create `terraform.tfvars`.
- Never bypass Terrakube workspace locking.
- Container and VM keys must match state addresses exactly; verify with a
  Terrakube state operation before renaming.
- A missing, empty, or structurally incomplete object must fail before plan.
