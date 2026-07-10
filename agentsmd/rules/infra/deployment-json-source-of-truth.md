---
name: deployment-json-source-of-truth
description: deployment.json is the single source of truth for Terraform config; it is a single-writer S3 object and terraform.tfvars must never exist
type: feedback
---

# deployment.json is the Single Source of Truth

`deployment.json` is the **single source of truth** for Terraform resource
definitions (containers, VMs, pools, sizing) in this repo. The full ACID
contract — fetch, schema validation, single-writer locking, and container
authoring rules — is documented once at
[docs.jacobpevans.com → Deployment state contract](https://docs.jacobpevans.com/infrastructure/deployment-state-contract).
**Read it before changing any infrastructure config.** This rule keeps only the
hard prohibitions and the repo-specific layer split that the public page leaves out.

**Where it lives:** the live file is **NOT committed** — it is the single
versioned object in the on-prem `s3` object store, fetched by terragrunt at
plan/apply with the Doppler `S3_*` creds, and it **FAILS LOUD** if missing (a
blank input can never plan a destroy). Location is parameterized in
`terragrunt.hcl` (`S3_INVENTORY_BUCKET` / `S3_INVENTORY_KEY`);
`DEPLOYMENT_JSON_PATH` overrides with a local file for offline/bootstrap work
only. The repo keeps only `deployment.json.example`. Read/edit recipe:
`docs/SOPS_SETUP.md` → "Setting Up Layer 1".

**Hard prohibitions (the tripwires):**

- Make ALL infrastructure changes in the live S3 object (fetch → edit → validate
  → upload, per `docs/SOPS_SETUP.md` Layer 1) — never `git add deployment.json`.
- Never create or commit `terraform.tfvars`. It silently overrides
  `deployment.json` via variable precedence (tfvars = level 3, `TF_VAR_*` from
  Terragrunt = level 2) and is gitignored, so it drifts between worktrees —
  changes appear to apply but don't. If one exists in your worktree, delete it
  immediately: `rm terraform.tfvars`.
- One writer at a time: the OpenTofu state lock serializes applies and
  `-lock-timeout` makes concurrent runs wait. Don't bypass it.
- Container and VM keys MUST match the Terraform state keys exactly — a mismatch
  triggers destroy + recreate. Verify against `terragrunt state list` first.
  (Authoring details: see the contract page above.)

**Two environments (git-flow):** there are two independent inputs — the prod
object (`deployment.json`, `environment: homelab`) and the develop object
(`deployment.develop.json`, `environment: develop`). Select which one a run uses
by **explicitly** exporting `S3_INVENTORY_KEY` (`deployment.json` is the default;
`deployment.develop.json` for develop) — there is no git-branch inference. The
`environment` field inside the fetched object then drives three derived keys:

| Key | `homelab` (prod, UNCHANGED) | `develop` |
| --- | --- | --- |
| tfstate | `terraform-proxmox/terraform.tfstate` | `terraform-proxmox/develop/terraform.tfstate` |
| input mirror | `terraform-proxmox/input/deployment.json` | `terraform-proxmox/input/develop/deployment.json` |
| published inventory | `terraform-proxmox/inventory/ansible_inventory.json` | `terraform-proxmox/inventory/develop/ansible_inventory.json` |

Invariants: **prod paths never change** (the `homelab` branch pins today's exact
literals — drift makes a prod apply init an empty state and plan a full destroy);
**never point the develop input at prod state**; separate tfstate keys mean
separate locks, but both envs share one physical cluster, so the global flow
lease still serializes applies across them. Keep the develop object **minimal**
(only guests under test) on the `nonprod` VLAN with the env digit `1` in the last
VMID position. An unknown `environment` fails loud (allowlist `["homelab","develop"]`).
The repo keeps only `deployment.develop.json.example`.

**Repo-specific layer split (not on the public page — installation-specific):**

- SOPS (`terraform.sops.json`) holds installation-specific values (not
  necessarily secret, but they'd reveal private infra details if committed
  plaintext): `network_prefix`, `domain`, the `vm_ssh_*` key paths,
  `proxmox_ssh_username`, and `rack_servers` (BMC IPs/MACs, chassis, service tags).
- Doppler holds only runtime credentials: `PROXMOX_VE_*`, `SPLUNK_*`,
  `PROXMOX_SSH_PRIVATE_KEY`.
