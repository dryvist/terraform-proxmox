# OpenBao Workspace Policy Layout

Each Terrakube workspace receives a distinct OpenBao role and least-privilege
policy. Roles bind the exact workload identity claims; policies grant only the
native paths listed in [SECRETS_ROADMAP.md](./SECRETS_ROADMAP.md).

## Terrakube workspace roles (remote executor)

| Workspace | OpenBao role | Allowed paths |
| --- | --- | --- |
| `tofu-proxmox` | `terrakube-tofu-proxmox` | `secret/infrastructure/proxmox`, `secret/platform/object-storage` |
| `tofu-proxmox-aws-infra` | `terrakube-tofu-proxmox-aws-infra` | `aws/creds/tf-proxmox` |
| `tofu-proxmox-servarr-config` | `terrakube-tofu-proxmox-servarr-config` | `secret/apps/media` |
| Platform bootstrap roles | various | Cannot read application values |

## Operator / AI-agent AppRole (local envrc pull)

The `terraform-apply` AppRole (keys in Doppler T3 / operator keychain) grants
read access to `secret/platform/terrakube/main` only — the non-secret
coordination path (`TF_CLOUD_HOSTNAME`, `TF_CLOUD_ORGANIZATION`). It cannot
read infrastructure provider credentials or Terrakube server secrets.

## Rules
- Human recovery credentials stay outside routine machine execution.
- Never copy an OpenBao token, unseal material, or provider credential into a
  Terrakube workspace variable.
- The workspace executor roles and the operator AppRole are separate identities
  with non-overlapping policies.
