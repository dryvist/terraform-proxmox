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
secret/infra/      proxmox/  aws/  network/        # IaC kernel — Terraform writes
secret/platform/   dns/ traefik/ object-storage/ splunk/ cribl/ infisical/
secret/apps/       media/ monitoring/ home-automation/
secret/ai/         hermes/ agents/                 # LLM stack + AI-agent creds
secret/ci/         github/ doppler-sync/
```

Each path is `secret/<category>/<service>/<key>`. New static secrets are written
greenfield-first into this tree; Doppler/SOPS remain authoritative until a
consumer is proven against OpenBao.

## RBAC groups

| Identity | Auth method | Read | Write | Notes |
| --- | --- | --- | --- | --- |
| `terraform` | AppRole | `secret/infra/*`, `secret/platform/*` | same + manage engines | The IaC identity; creds in Doppler tier-0 |
| `ansible` | AppRole | `secret/platform/*`, `secret/apps/*` | — | Config-management pulls |
| `ai-readonly` | AppRole | `secret/ai/*`, `secret/apps/*` | — | **No `secret/infra/*`.** Default AI-agent group; creds in the `ai-secrets` keychain |
| `ai-elevated` | AppRole | `ai-readonly` + `secret/platform/*` | — | Trusted infra-touching agents; still no write, no kernel |
| `ci` | JWT/OIDC | scoped CI paths | — | Keyless from GitHub Actions |
| operator | root / OIDC | break-glass | all | Root token on paper; OIDC/userpass later |

AI agents are deliberately **read-only** and walled off from the infra kernel
(`secret/infra/*` — Proxmox API token, AWS state creds, network CIDRs). Two broad
groups for now: `ai-readonly` (default) and `ai-elevated` (broader read).

## Secret-zero — stays OUT of OpenBao (in Doppler T3)

To avoid a cold-cluster brick (OpenBao can't hold the secrets needed to bring
OpenBao up) or a locked-out actor (can't reach the lease authority), these live
in the Doppler strict tier (T3), never in OpenBao:

- The **static seal key** (`OPENBAO_STATIC_SEAL_KEY` + `OPENBAO_STATIC_SEAL_KEY_ID`).
- The **flow-lock AppRole `secret_id`** — the credential to acquire the global
  flow-lock lease that OpenBao arbitrates.
- The OpenBao AppRole `role_id`/`secret_id` (`VAULT_ROLE_ID`/`VAULT_SECRET_ID`).
- Proxmox API token (`PROXMOX_VE_*`).
- AWS state-backend credentials (S3 + DynamoDB lock).

## Resilience (never lost, near-zero unavailability)

- **3-node Raft HA** (quorum 2) — survives one node loss with no downtime.
- **On-prem static-key auto-unseal** — each node self-unseals on reboot from the
  seal key in its 0600 EnvironmentFile (sourced from Doppler tier-0). No cloud.
  The 0600 EnvironmentFile is the at-rest exposure of the seal key: a node-disk
  or backup compromise yields the key and thus the vault. Encrypt the underlying
  VM/LXC disks at the Proxmox host (LUKS or ZFS native encryption) so the key —
  and the Raft data it unseals — is protected at rest on disk and in snapshots.
- **Automated encrypted snapshots** → on-prem `s3` bucket `openbao-snapshots` +
  NAS + offsite-encrypted. Snapshots are encrypted at rest; restore needs the
  seal key (Doppler) OR the recovery shares (paper).
- **Paper break-glass** — recovery shares (5, threshold 3) + initial root token,
  transcribed to paper and split across custodians.

## Migration order (greenfield-first)

1. Stand up the 3-node HA cluster + KV hierarchy + RBAC (Phase 1).
2. New generated secrets go into OpenBao; consumers read via AppRole.
3. Leave Doppler/SOPS authoritative for existing secrets until each consumer is
   proven against OpenBao, then migrate per-secret.
4. Tier-0 kernel never migrates into OpenBao.

See also `docs/SECRETS_ROADMAP.md`.
