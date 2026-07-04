# Secrets Hierarchy & RBAC

The categorization of secrets in OpenBao and the broad RBAC groups that govern
access — including least-privilege groups for AI agents. In the four-tier secrets
model OpenBao (T2) is the **single** machine/IaC/dynamic-secrets engine and the
primary runtime interface for AI agents and automation. There is no second,
domain-split engine: the earlier OpenBao/Infisical split is dead, Infisical's
contents migrate into OpenBao, and Infisical is decommissioned. See
[SECRETS_ROADMAP.md](./SECRETS_ROADMAP.md) for the full four-tier design.

## KV v2 hierarchy (mount `secret/`)

```text
secret/infra/      proxmox/  aws/  network/        # IaC kernel — terraform-apply writes
secret/platform/   dns/ traefik/ object-storage/ compute/ splunk/ cribl/ terrakube/
secret/apps/       media/ monitoring/ home-automation/
secret/ai/         router/ llm-large/ qdrant/ open-webui/ hermes/ agents/
secret/ci/         github/ doppler-sync/
secret/public/     domain/                         # non-exploitable facts (see below)
```

Each path is `secret/<category>/<service>/<key>`. New static secrets are written
greenfield-first into this tree; Doppler/SOPS remain authoritative until a
consumer is proven against OpenBao.

## RBAC groups

RBAC is split by **resource domain** — one least-privilege AppRole per consumer,
so a compromise of any one credential is scoped to that domain's secrets:

| Identity | Read | Write | Notes |
| --- | --- | --- | --- |
| `terraform-apply` | `secret/infra/*`, `secret/platform/{dns,traefik}` | same | Human-triggered IaC apply; isolated from Terrakube's untrusted-plan surface |
| `terrakube-plan` | `secret/platform/terrakube` only | — | VCS-driven plan runs treated as hostile; **never** `secret/infra/*` |
| `ansible-converge` | `secret/platform/*`, `secret/apps/*` | — | Config-management pulls; no infra kernel |
| `observability` | `secret/platform/{splunk,cribl}` | — | Splunk + Cribl |
| `local-cloud` | `secret/platform/{object-storage,compute}` | — | S3/object-storage + compute |
| `monitoring` | `secret/apps/monitoring` | — | Metrics/exporters |
| `media` | `secret/apps/media` | — | Media stack |
| `local-llm` | `secret/ai/*` | — | LLM serving stack (router, models, vector DB) |
| `ai-readonly` | `secret/ai/*`, `secret/apps/*` | — | **No `secret/infra/*`.** Default AI **agent** identity |
| `ai-elevated` | `ai-readonly` + `secret/platform/*` | — | Trusted infra-touching agents; still no write, no kernel |
| `snapshot` | `sys/storage/raft/snapshot` | — | Least-privilege backup identity (the snapshot daemon) |
| `public` | `secret/public/*` | — | Non-exploitable facts; creds ship ambiently, never keychain-gated (see below) |
| `ci` | scoped CI paths (JWT/OIDC) | — | Keyless from GitHub Actions |
| operator | break-glass (root / OIDC) | all | Root token on paper; OIDC/userpass later |

Each AppRole is bound to a `secret_id_bound_cidrs` scoped to its consumer's
subnet (cheap hardening). `terraform-apply` is deliberately walled off from
`terrakube-plan`: Terrakube executes VCS-driven (potentially untrusted) plans,
so it gets a read-only, `secret/platform/terrakube`-only identity that can never
rewrite `secret/infra/*` that Ansible later trusts. AI **agents** (`ai-readonly`
/ `ai-elevated`) are read-only and walled off from the infra kernel; the LLM
**serving** stack is a separate `local-llm` identity, not an agent identity.

## Secret-zero — stays OUT of OpenBao (in Doppler T3)

To avoid a cold-cluster brick (OpenBao can't hold the secrets needed to bring
OpenBao up) or a locked-out actor (can't reach the lease authority), these live
in the Doppler strict tier (T3), never in OpenBao:

- The **static seal key** (`OPENBAO_STATIC_SEAL_KEY` + `OPENBAO_STATIC_SEAL_KEY_ID`).
- The **flow-lock AppRole `secret_id`** — the credential to acquire the global
  flow-lock lease that OpenBao arbitrates.
- The OpenBao AppRole `role_id`/`secret_id` per domain.
- Proxmox API token (`PROXMOX_VE_*`).
- AWS state-backend credentials (S3 + DynamoDB lock).

## Secret-zero delivery — the keychain lock IS the access boundary

Each domain's AppRole `role_id`/`secret_id` is delivered to a consuming machine
as its own item in a **dedicated, auto-locking secret store** (on macOS, a
dedicated keychain with a 72-hour auto-lock; on Linux guests, a root-only `0600`
EnvironmentFile / systemd credential). **The store's lock state is the entire
access boundary — not the AppRole SecretID's own TTL.** While locked, no process
can read the credential at all; once unlocked (one human prompt every ~3 days on
macOS), a **user-domain agent** reads each domain's credential and publishes it
into the session environment, so any subsequently spawned consumer inherits it
ambiently with no store access of its own. A non-expiring SecretID is therefore
the correct design here, not a flaw: the boundary is read-access to the store,
scoped one domain per credential, with bound CIDRs and recorded SecretID
accessors for clean single-credential revocation if one is ever suspected
compromised.

### The `public` domain — no unlock at all

`secret/public/*` holds **sensitive-but-not-exploitable facts** that don't belong
in a public repo yet aren't secrets in the security sense — the canonical example
being the internal domain/subdomain. Nothing is compromised by any internal
process reading them, so they must not sit behind the same gate as real secrets.
OpenBao (like Vault) has no truly-unauthenticated KV read path, so this is a
single fixed low-privilege `public` AppRole whose creds are **not** keychain-gated
— they ship ambiently the same way other non-secret internal config already does,
bound to internal RFC1918 CIDRs so they are useless if ever exfiltrated off-LAN.

## Resilience (never lost, near-zero unavailability)

- **3-node Raft HA** (quorum 2) — survives one node loss with no downtime.
- **On-prem static-key auto-unseal** — each node self-unseals on reboot from the
  seal key in its 0600 EnvironmentFile (sourced from Doppler tier-0). No cloud.
  The 0600 EnvironmentFile is the at-rest exposure of the seal key: a node-disk
  or backup compromise yields the key and thus the vault. Encrypt the underlying
  VM/LXC disks at the Proxmox host (LUKS or ZFS native encryption) so the key —
  and the Raft data it unseals — is protected at rest on disk and in snapshots.
- **Automated raft snapshots** — an on-box systemd timer takes a snapshot on the
  active node only (leader-gated at runtime), authenticated with the
  least-privilege `snapshot` AppRole, integrity-checked (`gzip -t`), and kept
  under the ZFS/PBS-backed data volume that already replicates **off-box**;
  failures page via the deadman/ntfy stack. A second off-box copy into the
  on-prem `s3` bucket `openbao-snapshots` (with a `HeadObject`/size/sha256
  verify — never trusting the S3 ETag) and a full restore-to-scratch drill are
  tracked follow-ups; restore needs the seal key (Doppler) OR the recovery
  shares (paper).
- **Paper break-glass** — recovery shares (5, threshold 3) + initial root token,
  transcribed to paper and split across custodians.

## Migration order (greenfield-first)

1. Stand up the 3-node HA cluster + KV hierarchy + RBAC (Phase 1).
2. New generated secrets go into OpenBao; consumers read via AppRole.
3. Leave Doppler/SOPS authoritative for existing secrets until each consumer is
   proven against OpenBao, then migrate per-secret.
4. Tier-0 kernel never migrates into OpenBao.

See also `docs/SECRETS_ROADMAP.md`.
