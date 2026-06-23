---
name: deployment-json-source-of-truth
description: deployment.json is the single source of truth for all Terraform infrastructure config; terraform.tfvars must never exist
type: feedback
---

# deployment.json is the Single Source of Truth

`deployment.json` is the **single source of truth** for Terraform resource definitions (containers, VMs, pools, sizing) in this repo.

It is **private and NOT committed**: the live file lives only in the on-prem `s3`
object store at `s3://iac-inventory/deployment.json` (a versioned bucket), fetched
by terragrunt at plan/apply via the Doppler `S3_*` creds (`DEPLOYMENT_JSON_PATH`
overrides with a local file for offline/bootstrap work). The repo keeps only
`deployment.json.example` as a shape reference.

**Why:** `terraform.tfvars` was deleted because it silently overrides `deployment.json` via Terraform variable
precedence (tfvars = level 3, TF_VAR_* env vars from Terragrunt = level 2). It was gitignored, so it didn't
transfer to new worktrees, causing silent drift where changes appeared to apply but didn't.

**How to apply:**

- Make ALL infrastructure changes (containers, VMs, pools, Splunk sizing) in
  `deployment.json`, then upload it back to `s3://iac-inventory/deployment.json`
  in the on-prem `s3` store — never `git add deployment.json`
- Never create or commit `terraform.tfvars` — it is gitignored and forbidden
- If `terraform.tfvars` exists in your worktree, delete it immediately: `rm terraform.tfvars`
- SOPS (`terraform.sops.json`) holds 5 env-specific values (not necessarily secret, but
  installation-specific — they'd reveal private infra details if committed plaintext):
  `network_prefix`, `domain`, `vm_ssh_public_key_path`, `vm_ssh_private_key_path`,
  `proxmox_ssh_username`
- Doppler holds only runtime credentials: `PROXMOX_VE_*`, `SPLUNK_*`, `PROXMOX_SSH_PRIVATE_KEY`

## Compact DRY Format for Containers

When adding containers to `deployment.json`:

- **Omit** `root_disk.datastore_id` — defaults to `local-zfs` via module
- **Omit** `network_interfaces` when you want `firewall: true` (the default)
- **Include** `network_interfaces` only when `firewall: false` is needed

```json
"my-container": {
  "vm_id": 123,
  "hostname": "my-container",
  "description": "Description of the container",
  "cpu_cores": 2,
  "memory_dedicated": 2048,
  "tags": ["terraform", "container", "some-tag"],
  "pool_id": "infrastructure",
  "root_disk": { "size": 16 }
}
```

For containers that must bypass the Proxmox firewall (e.g., DNS servers, management tools):

```json
"network_interfaces": [{ "name": "eth0", "bridge": "vmbr0", "firewall": false }]
```

## Key Name Alignment

Container key names in `deployment.json` MUST match the Terraform state keys exactly. A key mismatch
triggers destroy + recreate. Always verify against `terragrunt state list` before adding entries for
containers that already exist in state.
