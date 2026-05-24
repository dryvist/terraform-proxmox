# Infisical Module (Reserved — Phase 2)

<!-- DO NOT DELETE - Placeholder reserved for the Infisical Terraform provider integration in Phase 2 -->

This directory is **reserved** for a future Terraform module that uses the
[Infisical Terraform provider](https://registry.terraform.io/providers/Infisical/infisical/latest)
to manage Infisical projects, environments, secrets, and access policies as
code — once the self-hosted instance is up and stable.

**Status:** RESERVED — no Terraform resources yet. Do not delete the directory;
the placeholder keeps the Phase 2 location stable across renames.

## Scope split

| Concern | Where it lives |
| --- | --- |
| Provisioning the **Infisical LXC itself** (vm_id 108, firewall, mount points) | `deployment.json` + `modules/firewall/` + `locals.tf` (Phase 1, already on `main`) |
| Deploying the **Infisical Docker Compose stack** (app + Postgres + Redis) | `ansible-proxmox-apps/roles/infisical_docker/` (Phase 1) |
| Fronting it with **HAProxy + TLS** | `ansible-proxmox-apps/roles/haproxy/` + `group_vars/haproxy_group.yml` (Phase 1) |
| **This module** — managing Infisical projects/secrets/policies via the Infisical Terraform provider | Phase 2 (see [issue #136](https://github.com/JacobPEvans/terraform-proxmox/issues/136)) |

## Requirements

This module does not declare any Terraform resources today, so it has no
provider or version requirements of its own. Phase 2 will add a dependency
on the Infisical Terraform provider once the self-hosted instance is stable.

Prerequisites that must be in place before Phase 2 work begins:

- Phase 1 deploy complete and stable (LXC up, HAProxy serving valid TLS, web UI reachable)
- Initial admin user + first project created manually via the web UI
- Service token issued for Terraform with project-scoped least privilege
- Infisical Terraform provider at a stable release

## Usage

Reserved — there is nothing to instantiate yet. Do not add a
`module "infisical" { source = "./modules/infisical" }` block to the root
`main.tf`; doing so will currently no-op and will conflict with the Phase 2
implementation once it lands. When Phase 2 ships, this section will document
the real provider + module usage.

## References

- [Infisical Planning Document](../../docs/INFISICAL_PLANNING.md)
- [Secrets Roadmap](../../docs/SECRETS_ROADMAP.md)
- [Infisical Terraform Provider](https://registry.terraform.io/providers/Infisical/infisical/latest)
