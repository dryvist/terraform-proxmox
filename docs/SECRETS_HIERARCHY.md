# OpenBao Workspace Policy Layout

Each Terrakube workspace receives a distinct OpenBao role and least-privilege
policy. Roles bind the exact workload identity claims; policies grant only the
native paths listed in [SECRETS_ROADMAP.md](./SECRETS_ROADMAP.md).

- `tofu-proxmox` reads Proxmox and RustFS credentials.
- `tofu-proxmox-aws-infra` requests its Route53 STS role.
- `tofu-proxmox-servarr-config` reads only media application fields.
- Platform bootstrap roles cannot read application values.

Human recovery credentials stay outside routine machine execution. Never copy
an OpenBao token, unseal material, or provider credential into a Terrakube
workspace variable.
