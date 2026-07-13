# OpenBao and Terrakube Secret Contract

OpenBao is the only machine secret manager for these OpenTofu workspaces.
Terrakube is the execution, state, locking, and audit plane. Both services run
inside the homelab and routine operation requires no public internet.

## Authentication

Terrakube signs a per-job workload token. OpenBao validates its issuer,
audience, workspace, organization, and project claims, then returns a
short-lived token bound to the exact workspace policy. Long-lived AppRole
secrets and provider credentials are not stored in Terrakube.

## Native paths

| Path | Consumer | Contents |
| --- | --- | --- |
| `secret/infrastructure/proxmox` | `tofu-proxmox` | Proxmox API, PVE SSH, and VM SSH credentials |
| `secret/platform/object-storage` | infrastructure workspaces | RustFS endpoint and credentials |
| `aws/creds/tf-proxmox` | `tofu-proxmox-aws-infra` | Dynamic Route53 STS credentials |
| `secret/apps/media` | `tofu-proxmox-servarr-config` | Sonarr/Radarr endpoints and API keys |
| `secret/infrastructure/proxmox-packer` | approved Packer operator | Packer-only Proxmox and Splunk fields |

Use provider-native ephemeral resources whenever the destination accepts an
ephemeral value. If a provider persists a secret-bearing resource argument and
offers no write-only field, transfer that feature to Ansible or restrict and
encrypt Terrakube state until the provider adds native support.

The private RustFS `deployment.json` holds desired state only. It may contain
network topology and public keys, but never tokens, passwords, or private keys.

## Locking

Terrakube workspace locking serializes OpenTofu runs. OpenBao does not provide
a second global flow lock for these workspaces.
