# Secrets Roadmap

Unified secrets strategy across the Proxmox homelab ecosystem.

## Current State

### ACTIVE: Doppler (Primary Runtime Secrets)

Doppler is the primary secrets manager for all runtime credentials.

**How it works:**

- Secrets stored in Doppler projects, organized by config (dev/stg/prd)
- Injected at runtime via `doppler run --` command wrapper
- BPG Proxmox provider reads `PROXMOX_VE_*` env vars directly
- Configured once at bare repo root; all worktrees inherit automatically

**Repositories using Doppler:**

| Repository | Secrets Managed |
| --- | --- |
| terraform-proxmox | `PROXMOX_VE_*`, `SPLUNK_*` |
| ansible-proxmox-apps | `PROXMOX_*`, `SPLUNK_HEC_TOKEN` |
| ansible-splunk | `SPLUNK_*`, `PROXMOX_*` |
| ansible-proxmox | `PROXMOX_*` |

**Strengths:**

- Zero secrets in git or environment files
- Automatic worktree inheritance via bare repo config
- Audit logging and access controls
- Easy rotation without code changes

### ACTIVE: aws-vault (AWS Credential Management)

Secures AWS credentials for Terraform S3 backend access.

**How it works:**

- Credentials stored in macOS Keychain
- Temporary STS sessions via `aws-vault exec <profile> --`
- Never written to `~/.aws/credentials`

**Repositories using aws-vault:**

- terraform-proxmox (S3 state backend)
- terraform-aws (AWS infrastructure)
- terraform-aws-bedrock (Bedrock AI)

### ACTIVE: secrets-sync (Doppler to GitHub Actions)

Synchronizes Doppler secrets to GitHub Actions repository secrets.

**How it works:**

- Doppler secrets-sync integration configured per repository
- Automatically pushes secret updates to GitHub Actions secrets
- CI/CD workflows reference secrets via `${{ secrets.SECRET_NAME }}`

### ACTIVE: macOS Keychain (AI Agent Keys)

API keys for Claude Code and AI agents stored in a dedicated keychain.

**How it works:**

- Dedicated `ai-secrets` keychain in macOS Keychain Access
- Retrieved at runtime by Claude Code plugins
- Never stored in files or environment variables

## Planned

### ACTIVE: SOPS + Age (Git-Committed Encrypted Deployment Config)

Replaces `.env/terraform.tfvars` with an age-encrypted JSON file committed to git.
**SOPS is the encrypted equivalent of tfvars — deployment config, not credentials.**
Doppler continues to manage all credentials. They work together, not as alternatives.

**Division of responsibility:**

| What | Where | Examples |
| --- | --- | --- |
| API tokens, passwords, SSH keys | Doppler | `PROXMOX_VE_API_TOKEN`, `SPLUNK_PASSWORD` |
| Node name, IPs, topology, container/VM definitions | SOPS | `proxmox_node`, `management_network`, `containers` |

**Integration pattern:**

```hcl
# In terragrunt.hcl:
sops_config = fileexists("${get_terragrunt_dir()}/terraform.sops.json") ?
  jsondecode(sops_decrypt_file("${get_terragrunt_dir()}/terraform.sops.json")) : {}
inputs = merge(local.env_var_defaults, local.sops_inputs)
```

**Run command (always both together):**

```bash
aws-vault exec tf-proxmox -- doppler run -- terragrunt plan
```

**Files:**

| File | Status | Purpose |
| --- | --- | --- |
| `.sops.yaml` | Committed | Age public key config |
| `terraform.sops.json` | Committed (encrypted) | Deployment config for Terragrunt |
| `terraform.sops.json.example` | Committed | Template with placeholder values |

**Repositories using SOPS:**

| Repository | Status |
| --- | --- |
| terraform-proxmox | ACTIVE |
| ansible-proxmox-apps | Planned |
| ansible-splunk | Planned |

See [docs/SOPS_SETUP.md](./SOPS_SETUP.md) for full setup and usage instructions.

### PLANNED-FOR-DEPLOY: Self-Hosted OpenBao (Machine / IaC Secrets Engine)

<!-- DO NOT DELETE - Active planning item -->

OpenBao is the machine/IaC/dynamic-secrets engine — the counterpart to Infisical
(the human UI + developer integration hub). The two are domain-split with **no
sync between them**. The IaC and Ansible roles exist; the cluster stands up in
Phase 1.

**Architecture:**

- **3-node Raft HA** — `openbao1`/`openbao2`/`openbao3` spread across
  `proxmox-1`/`proxmox-2`/`proxmox-3` on the apps VLAN. Quorum 2 survives one
  node loss with no downtime.
- **On-prem static-key auto-unseal (no cloud)** — each node self-unseals on
  reboot from a 32-byte AES-256 seal key in its `0600` EnvironmentFile, sourced
  from Doppler tier-0. This replaces the earlier AWS-KMS unseal design; the seal
  carries no cloud dependency.
- **Automated encrypted Raft snapshots** → on-prem `s3` bucket
  `openbao-snapshots` + NAS + offsite-encrypted.
- **Paper break-glass** — recovery shares (5, threshold 3) + initial root token
  transcribed to paper and split across custodians.

**Tier-0 kernel (stays OUT of OpenBao):**

These bootstrap OpenBao itself, so they live in Doppler tier-0 and never migrate
in — otherwise a cold cluster could not unseal itself:

| Doppler tier-0 secret | Purpose |
| --- | --- |
| `OPENBAO_STATIC_SEAL_KEY` | 32-byte AES-256 auto-unseal key (base64) |
| `OPENBAO_STATIC_SEAL_KEY_ID` | Seal-key rotation id (e.g. `YYYYMMDD-1`) |
| `VAULT_ADDR` | OpenBao API address |
| `VAULT_ROLE_ID` / `VAULT_SECRET_ID` | Terraform AppRole credentials |

See [docs/SECRETS_HIERARCHY.md](./SECRETS_HIERARCHY.md) for the KV v2
categorization and RBAC groups (including least-privilege AI-agent groups).

### PLANNED: Self-Hosted Infisical

<!-- DO NOT DELETE - Active planning item -->

Self-hosted secrets manager running on Proxmox infrastructure.

**Motivation:**

- Reduce dependency on Doppler SaaS
- Full control over secrets infrastructure
- Native Terraform and Ansible integrations
- Web UI for team management

See [INFISICAL_PLANNING.md](./INFISICAL_PLANNING.md) for detailed planning.

## Under Consideration

### CONSIDERATION: Google Secrets Manager

Evaluating as potential alternative or complement to Doppler for
cloud-native workloads.

**Pros:**

- Native GCP integration
- Pay-per-use pricing
- Strong IAM integration

**Cons:**

- Adds GCP dependency to primarily AWS/on-prem stack
- No clear advantage over Doppler for current use cases
- Would require additional credential management

**Decision:** On hold. Revisit if GCP workloads are added to the ecosystem.

## Secrets Flow Summary

```text
Doppler (SaaS) — credentials
├── PROXMOX_VE_* ──────→ BPG provider (API auth)
├── PROXMOX_SSH_* ─────→ Terragrunt → provider SSH block
├── SPLUNK_* ──────────→ Terragrunt → Terraform variables
├── secrets-sync ──────→ GitHub Actions
└── Runtime injection ──→ Ansible

aws-vault (local) — AWS auth
└── STS sessions ──────→ Terraform S3 backend

macOS Keychain (local) — AI keys
└── ai-secrets ────────→ Claude Code / AI agents

SOPS + Age (ACTIVE) — deployment config (not credentials)
└── terraform.sops.json (encrypted, committed to git)
    └── sops_decrypt_file() ──→ Terragrunt inputs
        (proxmox_node, IPs, networks, container/VM definitions)

OpenBao (planned-for-deploy) — machine/IaC secrets engine
└── 3-node Raft HA, on-prem static-key auto-unseal (no cloud)
    └── AppRole (VAULT_ROLE_ID/SECRET_ID) ──→ Terraform/Ansible reads
        (tier-0 kernel stays in Doppler; see SECRETS_HIERARCHY.md)

Infisical (planned) — human UI + developer integration hub
└── Self-hosted ───────→ domain-split from OpenBao (no sync)
```

## Migration Path

```text
Current:  Doppler → credentials (API tokens, passwords, SSH keys)
          SOPS    → deployment config (IPs, node, container defs) — replaces .env/terraform.tfvars
          Both always used together: aws-vault exec tf-proxmox -- doppler run -- terragrunt plan

Near-term: + Extend SOPS pattern to ansible-proxmox-apps and ansible-splunk
           + Pre-commit guards against committing unencrypted secrets
           + Stand up OpenBao 3-node Raft HA (Phase 1); new generated secrets
             land greenfield-first in OpenBao, consumers read via AppRole

Future:    OpenBao (self-hosted) as the machine/IaC/dynamic-secrets engine
           Infisical (self-hosted) as the human UI + developer integration hub
           Doppler retains the tier-0 kernel (incl. OpenBao seal key) + fallback
           SOPS/Age continues for git-committed deployment config
```
