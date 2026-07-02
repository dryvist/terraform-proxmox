# Secrets Roadmap

Unified secrets strategy across the Proxmox homelab ecosystem.

The end-state is a **four-tier hierarchy**. Every credential has exactly one
authoritative home, chosen by what the secret is for — git-committed config,
machine/AI runtime, cloud secret-zero, or a human-only vault:

| Tier | System | Role | AI / machine access |
| --- | --- | --- | --- |
| **T1** | SOPS + age | Git-committed, encrypted deployment config (not credentials) | Read at plan/apply via the age key |
| **T2** | OpenBao (self-hosted LXC) | **Primary machine + AI runtime secrets engine**, dynamic secrets, rotation, and the global flow-lock lease authority | Yes — the default runtime interface, via least-privilege AppRoles |
| **T3** | Doppler (SaaS) | Strict cloud tier: OpenBao secret-zero + rare user-approved keys-to-kingdom | Only for rare, explicitly user-approved operations |
| **T4** | Bitwarden | Human-only vault | **Never** — no AI or automation identity ever reads T4 |

This supersedes the earlier design in two specific ways, called out in full
under [Superseded designs](#superseded-designs):

- The **OpenBao / Infisical domain-split is dead.** OpenBao is the single
  machine/IaC/runtime engine. Infisical's contents migrate into OpenBao and
  Infisical is decommissioned.
- **Proton Pass is out of the machine architecture.** It stays a personal,
  human tool only; it holds no machine or AI secret-zero. Bitwarden (T4) is the
  human-only tier of record.

## Current State

### ACTIVE: Doppler (Runtime Secrets, migrating to strict tier)

Doppler is today the primary secrets manager for runtime credentials. In the
four-tier end-state it narrows to the **strict cloud tier (T3)**: OpenBao's
secret-zero plus a small set of rare, user-approved keys-to-kingdom values.
Routine machine and AI runtime secrets migrate out of Doppler into OpenBao
(T2) over time — see [Migration sequence](#migration-sequence).

**How it works today:**

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

Secures AWS credentials for Terraform S3 backend access. Orthogonal to the
four-tier storage hierarchy — it is a local credential broker, not a secrets
store. Its bootstrap creds are secret-zero (T3) and are a candidate for OpenBao
dynamic AWS credentials (T2) later.

**How it works:**

- Credentials stored in macOS Keychain
- Temporary STS sessions via `aws-vault exec <profile> --`
- Never written to `~/.aws/credentials`

**Repositories using aws-vault:**

- terraform-proxmox (S3 state backend)
- terraform-aws (AWS infrastructure)
- terraform-aws-bedrock (Bedrock AI)

### ACTIVE: secrets-sync (Doppler to GitHub Actions)

Synchronizes Doppler secrets to GitHub Actions repository secrets. Retired once
CI reads from OpenBao (T2) via JWT/OIDC — see [Migration sequence](#migration-sequence).

**How it works:**

- Doppler secrets-sync integration configured per repository
- Automatically pushes secret updates to GitHub Actions secrets
- CI/CD workflows reference secrets via `${{ secrets.SECRET_NAME }}`

### ACTIVE: macOS Keychain (AI Agent AppRole Bootstrap)

Holds the local bootstrap for the AI-agent OpenBao AppRole `secret_id`. This
feeds **T2**: once an agent has its AppRole credential it reads everything else
from OpenBao. It is a local materialization point, not a tier of its own; it is
macOS-only, so Linux cloud agents materialize the same bootstrap by their own
means.

**How it works:**

- Dedicated `ai-secrets` keychain in macOS Keychain Access
- Retrieved at runtime by Claude Code plugins to obtain the OpenBao AppRole
- Never stored in files or environment variables

## The four tiers (end-state)

### T1 — SOPS + Age (git-committed encrypted deployment config)

**Unchanged.** SOPS replaces `.env/terraform.tfvars` with an age-encrypted JSON
file committed to git. **SOPS is the encrypted equivalent of tfvars —
deployment config, not credentials.** OpenBao and Doppler manage credentials;
SOPS carries the committed config alongside them.

**Division of responsibility:**

| What | Where | Examples |
| --- | --- | --- |
| API tokens, passwords, SSH keys | OpenBao (T2) / Doppler (T3) | `PROXMOX_VE_API_TOKEN`, `SPLUNK_PASSWORD` |
| Node name, IPs, topology, container/VM definitions | SOPS (T1) | `proxmox_node`, `management_network`, `containers` |

**Integration pattern:**

```hcl
# In terragrunt.hcl:
sops_config = fileexists("${get_terragrunt_dir()}/terraform.sops.json") ?
  jsondecode(sops_decrypt_file("${get_terragrunt_dir()}/terraform.sops.json")) : {}
inputs = merge(local.env_var_defaults, local.sops_inputs)
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

The age **private** key is set up per host today (`age-keygen`). A per-host
age-key improvement (a portable, backed-up home so SOPS decryption works on
Linux/cloud agents too) is a future refinement; it does not change T1's role.
See [docs/SOPS_SETUP.md](./SOPS_SETUP.md) for full setup and usage.

### T2 — Self-Hosted OpenBao (primary machine + AI runtime engine)

OpenBao is the **single** machine/IaC/dynamic-secrets engine and the **primary
runtime interface for AI agents and automation**. The earlier OpenBao/Infisical
domain-split is dead — there is no second engine and no sync. OpenBao owns
AppRole RBAC, dynamic secrets, rotation, and Raft-snapshot DR, and it is also
the **global flow-lock lease authority** (below).

**Architecture:**

- **Self-hosted on a Proxmox LXC** on the apps VLAN, backed by Raft storage with
  automated snapshots. (HA quorum can be added later; the LXC is the initial
  target.)
- **On-prem static-key auto-unseal (no cloud)** — nodes self-unseal on reboot
  from a 32-byte AES-256 seal key in a `0600` EnvironmentFile, sourced from the
  Doppler strict tier (T3). This is the chosen seal model; there is no AWS-KMS
  dependency.
- **Automated encrypted Raft snapshots** → on-prem `s3` bucket
  `openbao-snapshots` + NAS + offsite-encrypted.
- **Paper break-glass** — recovery shares + initial root token transcribed to
  paper and split across custodians.

**Flow-lock lease authority.** OpenBao also holds the **global flow-lock** — a
single mutual-exclusion lease that serializes infrastructure-mutating flows
across repos and agents, so only one actor mutates shared state at a time. The
flow-lock AppRole `secret_id` that lets an actor acquire the lease is
secret-zero and stays in Doppler (T3) — see below.

**AI-agent access.** AI agents reach OpenBao through least-privilege AppRoles
and are read-only and walled off from the infra kernel. See
[docs/SECRETS_HIERARCHY.md](./SECRETS_HIERARCHY.md) for the KV v2 layout and the
RBAC groups.

**Secret-zero stays out of OpenBao (in Doppler T3):**

These bootstrap OpenBao itself or the lease that gates it, so they never migrate
in — otherwise a cold cluster could not unseal or a locked-out actor could not
acquire the lease:

| Doppler secret-zero | Purpose |
| --- | --- |
| `OPENBAO_STATIC_SEAL_KEY` | 32-byte AES-256 auto-unseal key (base64) |
| `OPENBAO_STATIC_SEAL_KEY_ID` | Seal-key rotation id (e.g. `YYYYMMDD-1`) |
| flow-lock AppRole `secret_id` | Credential to acquire the global flow-lock lease |
| `VAULT_ADDR` | OpenBao API address |
| `VAULT_ROLE_ID` / `VAULT_SECRET_ID` | Terraform AppRole credentials |

### T3 — Doppler (strict cloud tier: secret-zero + keys-to-kingdom)

Doppler narrows from primary runtime store to the **strict cloud tier**. It
holds two things and nothing routine:

1. **OpenBao secret-zero** — the seal key + id and the flow-lock AppRole
   `secret_id` listed above. These must live outside OpenBao so a cold cluster
   can always unseal and a locked-out actor can always reach the lease
   authority.
2. **Rare keys-to-kingdom** — a small set of high-blast-radius credentials that
   an AI agent may touch **only** for a specific, explicitly user-approved
   operation. Normal AI/machine runtime never reads T3.

Routine machine and AI runtime secrets migrate **out** of Doppler into OpenBao
(T2). As that completes, the runtime keys that remain are renamed `BREAKGLASS_*`
to make their strict, exceptional status explicit in tooling and audit logs.

### T4 — Bitwarden (human-only vault)

Bitwarden is the **human tier of record** — the personal/interactive vault for
credentials a human uses directly. **No AI agent, service account, or automation
identity ever reads T4.** It is deliberately outside every machine code path;
there is no CLI hook, lookup plugin, or bootstrap script that resolves a
Bitwarden item. This tier replaces Proton Pass in the human role (Proton Pass is
out of the machine architecture entirely — see below).

## Hybrid SSH certificate authority

SSH access moves to a **hybrid CA** model backed by OpenBao's SSH secrets
engine:

- **Automation identities** (`ai-agent`, `ansible`, `ci`) get **short-TTL SSH
  certificates** signed on demand by the OpenBao SSH engine. No long-lived
  automation private keys sit on disk; a leaked cert expires on its own.
- **Humans keep static SSH keys.** The CA is additive for automation, not a
  forced migration for interactive human access.

This is a T2 capability (the signing authority is OpenBao) and lands after the
core engine is up — see [Migration sequence](#migration-sequence).

## Superseded designs

Two earlier directions are **superseded** and must not be reintroduced:

- **OpenBao / Infisical domain-split — DEAD.** The plan to run OpenBao (machine
  engine) and Infisical (human UI + developer hub) as two domain-split systems
  with no sync between them **does not ship**. OpenBao is the single engine.
  Infisical's contents migrate into OpenBao and Infisical is decommissioned.
  See [INFISICAL_PLANNING.md](./INFISICAL_PLANNING.md) (superseded banner).
- **Proton Pass as tier-0 root-of-trust / AI keychain — SUPERSEDED.** Proton
  Pass is **out of the machine architecture**. It is a personal, human-only tool
  and holds no machine or AI secret-zero. The human tier of record is Bitwarden
  (T4); machine secret-zero lives in Doppler (T3). See
  [PROTON_PASS_STRATEGY.md](./PROTON_PASS_STRATEGY.md) (superseded banner).

## What stays in Doppler permanently

Even after the runtime migration completes, Doppler (T3) permanently retains the
secret-zero that OpenBao cannot hold for itself:

- `OPENBAO_STATIC_SEAL_KEY` + `OPENBAO_STATIC_SEAL_KEY_ID` — the auto-unseal key.
- The **flow-lock AppRole `secret_id`** — the credential to acquire the global
  lease authority.
- A small strict set of user-approved keys-to-kingdom (`BREAKGLASS_*`).

Everything else that is machine/AI runtime leaves Doppler for OpenBao.

## Migration sequence

```text
1. OpenBao bring-up      Stand up OpenBao on the Proxmox LXC (Raft + snapshots).
                         Seal key sourced from Doppler T3 (static-key auto-unseal).

2. Seed infra creds      Write the IaC kernel (secret/infra/*) into OpenBao;
                         consumers begin reading via the terraform AppRole.

3. Flow-lock adoption    OpenBao becomes the global flow-lock lease authority;
                         infra-mutating flows acquire the lease before mutating
                         shared state. Lease AppRole secret_id is secret-zero (T3).

4. Doppler slim-down     Migrate routine machine/AI runtime secrets Doppler → OpenBao.
                         Remaining strict runtime keys renamed BREAKGLASS_*.
                         Retire secrets-sync once CI reads OpenBao via JWT/OIDC.

5. Infisical migration    Migrate any Infisical contents into OpenBao, then
   + decommission         DECOMMISSION Infisical. The domain-split never ships.

6. SSH-CA                Enable the OpenBao SSH engine; automation identities
                         (ai-agent/ansible/ci) get short-TTL signed certs.
                         Humans keep static keys.
```

## Secrets Flow Summary

```text
T1  SOPS + Age — git-committed deployment config (not credentials)
└── terraform.sops.json (encrypted, committed)
    └── sops_decrypt_file() ──→ Terragrunt inputs
        (proxmox_node, IPs, networks, container/VM definitions)

T2  OpenBao — PRIMARY machine + AI runtime engine + flow-lock authority
├── AppRole (VAULT_ROLE_ID/SECRET_ID) ──→ Terraform / Ansible reads
├── least-privilege AI AppRoles ────────→ Claude Code / cloud agents (read-only)
├── SSH engine ───────────────────────→ short-TTL automation certs (ai/ansible/ci)
└── flow-lock lease ──────────────────→ serializes infra-mutating flows
    (secret-zero stays in Doppler T3 — see below)

T3  Doppler — strict cloud tier (secret-zero + keys-to-kingdom)
├── OPENBAO_STATIC_SEAL_KEY (+ _ID) ───→ OpenBao auto-unseal
├── flow-lock AppRole secret_id ───────→ acquire the global lease
└── BREAKGLASS_* ──────────────────────→ rare, user-approved keys-to-kingdom only

T4  Bitwarden — human-only vault
└── NEVER read by any AI or automation identity

Operational (orthogonal to the tier hierarchy):
  aws-vault (local) ──→ STS sessions ──→ Terraform S3 backend
  macOS ai-secrets keychain ──→ AI-agent OpenBao AppRole bootstrap ──→ T2
```

## Migration Path

```text
Current:  Doppler → runtime credentials (API tokens, passwords, SSH keys)
          SOPS    → deployment config (IPs, node, container defs)
          Both used together: aws-vault exec tf-proxmox -- doppler run -- terragrunt plan
          OpenBao IaC/Ansible roles exist; Infisical Phase 1 LXC in flight (being superseded)

End-state (four tiers):
  T1 SOPS+age  → git-committed encrypted deploy config (unchanged)
  T2 OpenBao   → PRIMARY machine+AI runtime engine, rotation, DR, flow-lock authority, SSH-CA
  T3 Doppler   → strict: OpenBao secret-zero + flow-lock secret_id + rare BREAKGLASS_*
  T4 Bitwarden → human-only; never AI

Superseded: OpenBao/Infisical domain-split (dead — one engine, Infisical decommissioned)
            Proton Pass tier-0 root-of-trust / AI keychain (out of machine architecture)
```
