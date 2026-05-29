# Terraform Proxmox — AI Agent Documentation

Infrastructure-as-code for the Proxmox VE homelab using Terraform/Terragrunt.
This is the **infrastructure layer**; downstream Ansible repos handle
configuration management.

## Version management

**Never hardcode dependency versions unless explicitly requested.** Use latest
stable versions, let package managers resolve compatible versions, and
investigate the current ecosystem state when conflicts surface. If you find
yourself suggesting deprecated features, stop and research first.

## Technology stack

| Tool | Role |
| --- | --- |
| Terraform / Terragrunt | Infrastructure provisioning, state in S3 + DynamoDB locking |
| Ansible | Configuration management (downstream repos), tested via Molecule |
| Python 3.12+ | Required by Ansible tooling |
| GitHub Actions | CI/CD (`.github/workflows/`) |
| Nix shell + direnv | Reproducible toolchain (terragrunt, opentofu, terraform-docs, tflint, tfsec, trivy, sops, age, awscli2, jq, yq, pre-commit) — auto-activates on `cd` |
| aws-vault | AWS credentials for the S3 state backend |
| Doppler | Runtime credentials (`PROXMOX_VE_*`, `PROXMOX_SSH_*`, `SPLUNK_*`) |
| SOPS + age | Git-committed encrypted env-specific config (`terraform.sops.json`) |

## Running Terraform / Terragrunt

All commands run through the toolchain wrapper:

```bash
aws-vault exec tf-proxmox -- doppler run -- terragrunt <COMMAND>
```

### When to use `aws-vault` vs ask for pre-injected credentials

> Autonomy rule: every `aws-vault exec` — and every keychain `security` read —
> forces the user to type their full keychain password TWICE (there is no Touch
> ID on this machine). A session that hits `aws-vault`/keychain repeatedly
> cannot run autonomously — minimise these calls hard.

- **Single one-off command** in the session: prefix with
  `aws-vault exec tf-proxmox --`. One credential prompt is acceptable.
- **Two or more commands**: STOP and ask the user to re-launch Claude with
  credentials already injected: `aws-vault exec tf-proxmox -- claude`. This is
  the ONLY supported injection method — never ask the user to export raw AWS
  keys. After re-launch, AWS creds are live for the whole session: drop the
  prefix and call `doppler run -- terragrunt …` directly.
- **Never** loop `aws-vault exec` across worktrees, parallel invocations, or
  per-resource checks. Always batch behind one credential injection.
- If unsure whether credentials are already live: `aws sts get-caller-identity`
  once. If it returns an ARN without prompting, do not call `aws-vault` again.

### Common commands

```bash
doppler run -- terragrunt validate
doppler run -- terragrunt plan
doppler run -- terragrunt apply
doppler run -- terragrunt show
```

The BPG Proxmox provider reads `PROXMOX_VE_*` env vars directly — no
`--name-transformer` needed. The Nix shell activates via direnv (`.envrc`).

## Config-file architecture (single source of truth)

```text
deployment.json          (committed, plaintext) — containers, VMs, pools, proxmox_node
terraform.sops.json      (committed, encrypted) — network_prefix, domain, vm_ssh_*_key_path, proxmox_ssh_username
Doppler env vars         (runtime only)         — PROXMOX_VE_*, SPLUNK_*, SSH key content
locals.tf derivations    (computed)             — management_network, splunk_network_ips
```

- `deployment.json` — resource definitions (containers, VMs, pools, sizing).
  Committed plaintext, edit directly.
- `terraform.sops.json` — five env-specific values: `network_prefix`,
  `domain`, `vm_ssh_public_key_path`, `vm_ssh_private_key_path`,
  `proxmox_ssh_username`. Decrypted automatically by Terragrunt.
- Doppler — credentials at runtime (provider auth + SSH key content).
- `management_network` and `splunk_network` are derived in `locals.tf` and
  must never be set manually.

> **Warning**: `terraform.tfvars` is intentionally gitignored and must NOT
> exist. It silently overrides `deployment.json` due to Terraform variable
> precedence. If it exists in your worktree, delete it: `rm terraform.tfvars`.

See [`docs/SOPS_SETUP.md`](./docs/SOPS_SETUP.md) for full setup and usage.

### Doppler secret naming (BPG standard)

| Secret | Purpose |
| --- | --- |
| `PROXMOX_VE_ENDPOINT` | API URL (without `/api2/json`) |
| `PROXMOX_VE_API_TOKEN` | API token (`user@realm!tokenid=secret`) |
| `PROXMOX_VE_USERNAME` | Username for the token |
| `PROXMOX_VE_INSECURE` | Skip TLS verification |
| `PROXMOX_VE_NODE` | Proxmox node name |

## Pipeline architecture (this repo's role)

This repo is the **single source of truth** for infrastructure: VMs,
containers, IPs, ports, and firewall rules.

- **IP derivation**: every IP is `network_prefix.vm_id` (e.g. VM 250 →
  `192.168.0.250`). Never hardcode IPs in any repo — they come from
  terraform output.
- **Pipeline constants**: `locals.tf` defines `pipeline_constants` with
  service / syslog / netflow / notification / vector-db port mappings,
  surfaced via `ansible_inventory.constants` in `outputs.tf`.

### Downstream repos

| Repo | Consumes | Purpose |
| --- | --- | --- |
| `ansible-proxmox` | `ansible_inventory.host_services` | Host config (kernel, ZFS, monitoring, NAS/Samba) |
| `ansible-proxmox-apps` | `ansible_inventory` (containers, docker_vms, constants) | Cribl, HAProxy, DNS, etc. |
| `ansible-splunk` | `ansible_inventory` (splunk_vm) | Splunk Enterprise (Docker) |

### Inventory sync (automatic)

`terragrunt.hcl` runs an `after_hook` post-apply that writes
`terraform_inventory.json` to each downstream repo's `inventory/`
directory under `~/git/<repo>/main/`. Repos not cloned locally are
skipped with a stderr warning.

To sync manually after importing state without applying, see
`docs/ARCHITECTURE.md`.

## Development workflow

Static checks (`tofu fmt -check`, `tofu validate`, `tofu test`) run
automatically in pre-commit and CI — no manual invocation needed.

Credentialed operations (`terragrunt plan` against the live state
backend, `terragrunt apply`) only run in CI under OIDC, or interactively
when explicitly preparing to apply. Do not gate commits on them.

Test in isolated resource pools, never production-first. Use feature
branches. Conventional-commit subjects only.

For slow operations and "context deadline exceeded" debugging:
[`TROUBLESHOOTING.md`](./TROUBLESHOOTING.md).

### Ansible

- Lint with `ansible-lint` before committing.
- `molecule test` for roles.
- Ensure idempotency (running twice produces no changes).
- Use FQCN (`ansible.builtin.apt`).

## Best practices

- Modular resource definitions; document variables with descriptions +
  validation; mark secrets `sensitive = true`.
- Remote state encrypted (S3 + DynamoDB).
- Never update VMs directly; use Terragrunt or Ansible.
- Ansible: roles under `ansible/roles/` with Molecule tests; collections
  pinned in `ansible/requirements.yml`; config in `ansible/.ansible-lint`
  (profile: production).
- Security: never commit secrets, API tokens, or passwords. Real
  infrastructure values live in a separate private repo; this repo
  contains placeholders only.

## File references

| Need | Location |
| --- | --- |
| Architecture (canonical) | [`docs/ARCHITECTURE.md`](./docs/ARCHITECTURE.md) |
| Secrets roadmap | [`docs/SECRETS_ROADMAP.md`](./docs/SECRETS_ROADMAP.md) |
| SOPS / age setup | [`docs/SOPS_SETUP.md`](./docs/SOPS_SETUP.md) |
| Troubleshooting + timeout/debug logging | [`TROUBLESHOOTING.md`](./TROUBLESHOOTING.md) |
| General docs | [`README.md`](./README.md) |
| Planning | GitHub Issues |
| Change history | PR descriptions + commits |
| Ansible config | `ansible/.ansible-lint` |
| Molecule tests | `ansible/roles/*/molecule/` |
| CI workflows | `.github/workflows/` |

## Ansible inventory output

The `ansible_inventory` output provides structured data for downstream
Ansible (full schema in `outputs.tf`):

```hcl
output "ansible_inventory" {
  value = {
    containers = { ... }
    vms        = { ... }
    docker_vms = { ... }
    splunk_vm  = { splunk = { vmid = 200, hostname = "splunk", ip = "<derived>" } }
    constants  = local.pipeline_constants
    host_services = var.host_services
    domain        = var.domain
  }
}
```

## When to ask for clarification

Stop and ask before proceeding if any of the following are true:

- Current tool versions are unclear.
- Multiple valid implementation approaches exist.
- Changes affect production infrastructure.
- Security implications are uncertain.
- Breaking changes may be introduced.

## PR review checklist

- [ ] No exposed secrets or credentials.
- [ ] Variables documented; `sensitive = true` where appropriate.
- [ ] `terragrunt validate` passes.
- [ ] `ansible-lint` passes (if Ansible touched).
- [ ] `molecule test` passes (if Ansible roles touched).
- [ ] Conventional commit message.
- [ ] Documentation updated where needed.
