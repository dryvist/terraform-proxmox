# OpenTofu Proxmox Infrastructure

OpenTofu infrastructure for the Proxmox VE homelab: VMs, LXC containers,
resource pools, firewall rules, certificates, and the published Ansible
inventory.

Terrakube owns state, native workspace locking, execution, and audit history.
It exchanges workload identity for a short-lived OpenBao token. Providers then
read Proxmox, SSH, Route53, and RustFS credentials with native ephemeral
resources; no credential is stored in repository configuration or Terrakube
workspace variables.

## Configuration

| Source | Contents |
| --- | --- |
| Private RustFS `deployment.json` | Desired state, topology, domain, and public SSH key |
| OpenBao `secret/infrastructure/proxmox` | Proxmox API and SSH credentials |
| OpenBao `secret/platform/object-storage` | RustFS endpoint and credentials |

Every apply publishes `ansible_inventory.json` back to RustFS through the
OpenTofu resource graph. Terrakube workspace locking replaces the former
backend-specific lock; no second global OpenBao lock is used.

## Local validation

The Nix dev shell activates through direnv. Local checks never require live
credentials:

```bash
direnv allow
tofu fmt -check -recursive
tofu init -backend=false
tofu validate
tofu test
tofu -chdir=modules/proxmox-stack init -backend=false
tofu -chdir=modules/proxmox-stack test
```

Credentialed plans, applies, imports, and state operations run only in the
private `tofu-proxmox` Terrakube workspace.

## Documentation

| Doc | Purpose |
| --- | --- |
| [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) | Pipeline architecture and IP derivation |
| [docs/INVENTORY_PUBLISHING.md](./docs/INVENTORY_PUBLISHING.md) | Native RustFS inventory contract |
| [docs/SECRETS_ROADMAP.md](./docs/SECRETS_ROADMAP.md) | OpenBao and Terrakube secret contract |
| [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) | Operational recovery guidance |

## License

Apache License 2.0 — see [LICENSE](LICENSE).
