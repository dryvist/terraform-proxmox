# Infisical Planning

<!-- DO NOT DELETE - Active planning document -->

Self-hosted Infisical deployment on Proxmox infrastructure.

**Status:** IN PROGRESS — Phase 1 deploy (LXC + firewall landing via
`terraform-proxmox`; Ansible role + HAProxy frontend land via
`ansible-proxmox-apps` PR 3).

## Phase 1 — concrete values

| Field | Value | Source |
| --- | --- | --- |
| LXC vm_id | `108` | `deployment.json` (groups with platform services 105/106/107) |
| CPU / RAM / disk | 2 cores / 4 GB dedicated + 8 GB swap / 16 GB root + 30 GB at `/opt/infisical` | `deployment.json` |
| FQDN | `infisical.<domain>` (resolved via Technitium A record on the haproxy LXC) | runtime, populated from `terraform.sops.json` `domain` |
| Container internal API port | `8080` | `locals.pipeline_constants.service_ports.infisical_api` |
| Bundled Postgres port | `5432` | `locals.pipeline_constants.service_ports.postgres_default` (container-internal Docker network only) |
| Bundled Redis port | `6379` | `locals.pipeline_constants.service_ports.redis_default` (container-internal Docker network only) |
| Firewall security group | `infisical-svc` | `modules/firewall/security_groups.tf` |
| Ingress | HAProxy on vm_id 175 with ACME cert at `/etc/ssl/private/infisical.pem` | PR 3 |

ACME cert for `infisical.<domain>` is **out of scope for Phase 1's
terraform-proxmox PR**: the existing `modules/acme-certificate` module today
issues node-level Proxmox certs (delivered to `/etc/pve/local/`), not certs
delivered to LXCs. Cert delivery to the haproxy LXC is handled in
`ansible-proxmox-apps` (PR 3) — either by an Ansible-driven Let's Encrypt
flow on the haproxy LXC itself or by extending the ACME module separately.
Tracked as a follow-up in issue #136 Phase 1.

## Overview

Infisical is an open-source secrets management platform that provides
centralized secret storage, rotation, and injection with native
integrations for Terraform, Ansible, and CI/CD platforms.

## Why Self-Hosted Infisical

- **Data sovereignty**: All secrets remain on-premises
- **No SaaS dependency**: Eliminates Doppler subscription cost
- **Native integrations**: Terraform provider, Ansible lookup plugin, CLI
- **Web UI**: Browser-based secret management and audit trails
- **RBAC**: Fine-grained access control per project and environment

## Proposed Architecture

### Deployment Target

| Component | Resource | Notes |
| --- | --- | --- |
| Infisical Server | LXC container or VM | Docker Compose deployment |
| PostgreSQL | Same container or dedicated | Infisical backend database |
| Redis | Same container | Caching and queue |

### Network Integration

- Internal access only (no public exposure)
- DNS entry via Technitium: `infisical.example.local`
- TLS via ACME certificate module (existing)
- Firewall rules via existing firewall module

### Resource Estimates

| Resource | Minimum | Recommended |
| --- | --- | --- |
| CPU | 2 cores | 4 cores |
| RAM | 2 GB | 4 GB |
| Disk | 10 GB | 20 GB |

## Migration Plan

### Phase 1: Deploy and Validate

1. Provision LXC container via terraform-proxmox
2. Deploy Infisical via Docker Compose (Ansible role)
3. Configure initial projects and environments
4. Validate API access and CLI connectivity

### Phase 2: Mirror Doppler Secrets

1. Export Doppler secrets (excluding rotation-sensitive ones)
2. Import into Infisical projects matching Doppler structure
3. Run both systems in parallel for validation
4. Verify terraform and ansible can read from Infisical

### Phase 3: Migrate Consumers

1. Update terraform-proxmox to use Infisical provider
2. Update ansible repos to use Infisical lookup plugin
3. Configure Infisical GitHub Actions integration (replace secrets-sync)
4. Update CI/CD workflows

### Phase 4: Decommission Doppler

1. Verify all consumers use Infisical
2. Remove Doppler CLI references from toolchain docs
3. Cancel Doppler subscription
4. Keep Doppler CLI installed as emergency fallback (30 days)

## Terraform Integration

```hcl
# Example: Infisical provider configuration
provider "infisical" {
  host          = "https://infisical.example.local"
  client_id     = var.infisical_client_id
  client_secret = var.infisical_client_secret
}

data "infisical_secrets" "proxmox" {
  env_slug     = "prd"
  project_id   = var.infisical_project_id
  folder_path  = "/proxmox"
}
```

## Ansible Integration

```yaml
# Example: Infisical lookup plugin
- name: Get Splunk HEC token
  ansible.builtin.set_fact:
    splunk_hec_token: "{{ lookup('infisical', 'SPLUNK_HEC_TOKEN',
      project_id=infisical_project_id,
      environment='prd') }}"
```

## Risks and Mitigations

| Risk | Mitigation |
| --- | --- |
| Single point of failure | Daily PostgreSQL backups to S3 |
| Infisical upgrades break API | Pin version, test upgrades in staging |
| Lost admin credentials | Recovery keys stored in SOPS-encrypted file |
| Container failure | Proxmox HA restart policy |

## Decision Criteria

Proceed with implementation when:

- [ ] SOPS + Age integration is stable across repos
- [ ] Proxmox cluster has available capacity
- [ ] Infisical Terraform provider reaches stable release
- [ ] Current Doppler costs justify migration effort

## References

- [Infisical Documentation](https://infisical.com/docs)
- [Infisical Terraform Provider](https://registry.terraform.io/providers/Infisical/infisical/latest)
- [Infisical Self-Hosting Guide](https://infisical.com/docs/self-hosting/overview)
