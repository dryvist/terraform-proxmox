# AI Instructions for Terraform Proxmox Repository

## Critical: Version Management

**NEVER hardcode dependency versions unless explicitly requested.**

- Always use latest stable versions (no pinning)
- Let package managers resolve compatible versions
- If version conflicts occur, investigate current ecosystem state
- When unsure about compatibility, ask the user or research current docs

**If you find yourself suggesting old versions or deprecated features, STOP and research the current state first.**

## Technology Stack

This repo uses:

- **Terraform/Terragrunt** - Infrastructure provisioning
- **Ansible** - Configuration management (tested via Molecule)
- **Python 3.12+** - Required for Ansible tooling
- **GitHub Actions** - CI/CD
- **Nix Shell** - Provides Terraform/Terragrunt/Ansible tooling
- **aws-vault** - Securely manages AWS credentials for S3 backend
- **Doppler** - Manages credentials (API tokens, passwords, SSH keys) at runtime
- **SOPS/age** - Git-committed encrypted deployment config (replaces `.env/terraform.tfvars`)

## Running Terraform Commands

**CRITICAL**: All Terraform/Terragrunt commands require the complete toolchain wrapper.

### The Command (always this, always both)

```bash
aws-vault exec tf-proxmox -- doppler run -- terragrunt <COMMAND>
```

The Nix shell (providing Terraform/Terragrunt/Ansible) is activated automatically via direnv when you enter the repository directory.

### AI agents: when to use `aws-vault` vs ask for pre-injected credentials

> **Autonomy rule**: every `aws-vault exec` call prompts for a Touch ID / keychain
> password. A session that hits `aws-vault` repeatedly cannot run autonomously and
> violates the "always run autonomously" rule.

- **One-off command** (a single `validate`, single `plan`, single `apply` in the
  whole session): an AI agent MAY run
  `aws-vault exec tf-proxmox -- doppler run -- terragrunt …` directly. One
  password prompt is acceptable.
- **Two or more terragrunt commands in the same session**: the AI MUST stop and
  ask the user to inject reusable AWS credentials before continuing. The user
  can either launch the session inside `aws-vault exec tf-proxmox -- claude …`,
  or export `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` / `AWS_SESSION_TOKEN`
  into the parent shell before the session starts. Once injected, drop the
  `aws-vault exec tf-proxmox --` prefix entirely and run
  `doppler run -- terragrunt …` directly.
- **Never** loop `aws-vault exec` across worktrees, parallel invocations, or
  per-resource checks. Always batch behind one credential injection.

If you're unsure whether credentials are already injected, run
`aws sts get-caller-identity` once — if it returns an ARN without prompting,
credentials are live and you should NOT call `aws-vault` again this session.

**Doppler and SOPS serve different purposes — they are always used together:**

- **`deployment.json`** contains resource definitions (containers, VMs, pools, sizing) — committed plaintext, edit directly
- **`terraform.sops.json`** contains 5 env-specific values (not necessarily secret, but installation-specific):
  `network_prefix`, `domain`, `vm_ssh_public_key_path`, `vm_ssh_private_key_path`, `proxmox_ssh_username`
- **Doppler** injects credentials: `PROXMOX_VE_*` (provider auth), `PROXMOX_SSH_*`, `SPLUNK_*`
- Terragrunt reads `deployment.json` and decrypts SOPS automatically. No extra flags needed.
- `management_network` and `splunk_network` are **derived** in `locals.tf` — never set manually

### Command Breakdown

1. **`aws-vault exec tf-proxmox`** - AWS credentials for S3 backend (profile: `tf-proxmox`, assumes role via `terraform` source profile)
2. **`doppler run --`** - Injects credentials as env vars (`PROXMOX_VE_*`, `SPLUNK_*`, etc.)
3. **`terragrunt <COMMAND>`** - Runs Terraform; also auto-decrypts `terraform.sops.json` if present

**Note**: The BPG Proxmox provider reads directly from `PROXMOX_VE_*` environment variables.
No `--name-transformer` is needed. See [BPG provider docs](https://registry.terraform.io/providers/bpg/proxmox/latest/docs).

### Common Commands

```bash
aws-vault exec tf-proxmox -- doppler run -- terragrunt validate
aws-vault exec tf-proxmox -- doppler run -- terragrunt plan
aws-vault exec tf-proxmox -- doppler run -- terragrunt apply
aws-vault exec tf-proxmox -- doppler run -- terragrunt show
```

### Doppler Configuration

Doppler is configured once at the repository root and automatically inherited by all
worktrees. See your local environment documentation for project and config details.

### Doppler Secret Naming (BPG Standard)

Doppler secrets use `PROXMOX_VE_*` naming to match the BPG Terraform provider:

| Secret | Purpose |
| --- | --- |
| `PROXMOX_VE_ENDPOINT` | API URL (without /api2/json) |
| `PROXMOX_VE_API_TOKEN` | API token (user@realm!tokenid=secret) |
| `PROXMOX_VE_USERNAME` | Username for token |
| `PROXMOX_VE_INSECURE` | Skip TLS verification |
| `PROXMOX_VE_NODE` | Proxmox node name |

### Why All Four Tools?

- **Nix + direnv**: Provides consistent tool versions (Terraform, Terragrunt, Ansible) via `.envrc` auto-activation
- **aws-vault**: Secures AWS credentials for S3 backend (never stored in files)
- **Doppler**: Credentials at runtime — API tokens, passwords, SSH keys (`PROXMOX_VE_*`, `SPLUNK_*`, etc.)
- **`deployment.json`**: Committed plaintext — containers, VMs, pools, Splunk sizing (replaces `.env/terraform.tfvars`)
- **SOPS/age**: 5 encrypted values in `terraform.sops.json` — `network_prefix`, `domain`, SSH key paths, `proxmox_ssh_username`

### Config File Architecture

```text
deployment.json          (committed, plaintext) — containers, VMs, pools, proxmox_node
terraform.sops.json      (committed, encrypted) — network_prefix, domain, vm_ssh_*_key_path, proxmox_ssh_username
Doppler env vars         (runtime only)         — PROXMOX_VE_*, SPLUNK_*, SSH key content
locals.tf derivations    (computed)             — management_network, splunk_network_ips
```

> **WARNING**: `terraform.tfvars` is intentionally gitignored and must NOT exist. It silently overrides
> `deployment.json` due to Terraform variable precedence (tfvars = level 3, TF_VAR_* = level 2).
> If it exists in your worktree, delete it: `rm terraform.tfvars`

See [docs/SOPS_SETUP.md](./docs/SOPS_SETUP.md) for full setup and usage.

- `.sops.yaml` - Age public key configuration (safe to commit)
- `deployment.json` - Non-secret config (edit and commit directly)
- `terraform.sops.json.example` - SOPS template with 5 values (copy, fill in, encrypt)

## Dev Environment

Uses [Nix flakes](https://wiki.nixos.org/wiki/Flakes) + [direnv](https://direnv.net/) for reproducible dev environment.

```sh
direnv allow    # one-time per worktree, then automatic on cd
nix develop     # manual activation
```

**Tools**: terragrunt, opentofu, terraform-docs, tflint, tfsec, trivy, sops, age, awscli2, git, python3, jq, yq, pre-commit

## Repository Context

- Infrastructure-as-code for Proxmox VE homelab
- Real infrastructure details in separate private repository
- This repo contains placeholder/example values only

## Pipeline Architecture (This Repo's Role)

This repo is the **single source of truth** for infrastructure: VMs, containers, IPs, ports, and firewall rules.

### IP Derivation

All IPs are derived from VM/container ID: `network_prefix.vm_id` (e.g., VM 250 = `192.168.0.250`).
Never hardcode IPs in any repo - they come from terraform output.

### Pipeline Constants

`locals.tf` defines `pipeline_constants` with service and syslog port mappings.
These are exposed via `ansible_inventory.constants` in `outputs.tf` for downstream Ansible repos.

### Downstream Repos

| Repo | Consumes | Purpose |
| --- | --- | --- |
| ansible-proxmox | `ansible_inventory.host_services` | Proxmox host config (kernel, ZFS, monitoring, NAS/Samba) |
| ansible-proxmox-apps | `ansible_inventory` (containers, docker_vms, constants) | Cribl, HAProxy, DNS |
| ansible-splunk | `ansible_inventory` (splunk_vm) | Splunk Enterprise (Docker) |

### Inventory Sync (Automatic)

Inventory sync to downstream repos is **automatic** via a Terragrunt `after_hook` in `terragrunt.hcl`.
After every `terragrunt apply`, `terraform_inventory.json` is written to
`ansible-proxmox`, `ansible-proxmox-apps`, and `ansible-splunk` if they are cloned
at `~/git/<repo>/main/`.
Repos not present are skipped with a stderr warning.

To sync manually (e.g., after importing state without apply):

```bash
aws-vault exec tf-proxmox -- doppler run -- bash -c '
  INV=$(terragrunt output -json ansible_inventory)
  for repo in ansible-proxmox ansible-proxmox-apps ansible-splunk; do
    TARGET="$HOME/git/$repo/main/inventory/terraform_inventory.json"
    if [ -d "$(dirname "$TARGET")" ]; then
      printf "%s\n" "$INV" > "$TARGET"
    else
      printf "Skipped %s (not cloned at ~/git/%s/main)\n" "$repo" "$repo" >&2
    fi
  done
'
```

## Development Workflow

### Terraform/Terragrunt

**Before ANY commits**, run validation and planning:

```bash
# 1. Validate syntax
aws-vault exec tf-proxmox -- doppler run -- terragrunt validate

# 2. Plan changes to review what will be modified
aws-vault exec tf-proxmox -- doppler run -- terragrunt plan
```

**Best Practices**:

- Test in isolated resource pools, never production-first
- Use feature branches for all changes
- Follow conventional commit messages
- Never commit without running validate + plan first

### Timeout and Debug Logging

When experiencing "context deadline exceeded" or slow Terraform operations:

#### Pre-Operation Health Check

```bash
# Test API connectivity before running Terraform
doppler run -- ./scripts/check-proxmox-api.sh
```

#### Debug Logging

```bash
# Full debug logging with file output
TF_LOG=DEBUG TF_LOG_PATH=/tmp/terraform-debug.log \
  terragrunt plan 2>&1 | tee /tmp/terraform-output.log

# Monitor in second terminal
tail -f /tmp/terraform-debug.log | grep -E "GET|POST|Refreshing|timeout|deadline"
```

#### Real-Time Monitoring (Multi-Terminal)

```bash
# Terminal 1: Run with logging
TF_LOG=DEBUG terragrunt apply -auto-approve 2>&1 | tee /tmp/tf.log

# Terminal 2: Monitor progress
./scripts/monitor-terraform.sh /tmp/tf.log

# Terminal 3 (optional): Watch Proxmox host
ssh root@proxmox-host 'while true; do clear; date; free -h; qm list; pct list; sleep 10; done'
```

#### Timeout Configuration

Resource-level timeouts are configured in modules (15 min standard, 30 min for clone/create):

- `modules/proxmox-vm/main.tf`
- `modules/splunk-vm/main.tf`

For slow operations, reduce parallelism:

```bash
terragrunt apply -parallelism=1 -auto-approve
```

See [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) for detailed timeout analysis.

### Ansible

- Lint with `ansible-lint` before commits
- Test roles with `molecule test`
- Ensure idempotency (running twice produces no changes)
- Use FQCN for modules (e.g., `ansible.builtin.apt`)

## Best Practices

### Terraform

- Modular resource definitions
- Document variables with descriptions and validation
- Mark secrets with `sensitive = true`
- Remote state with encryption (S3 + DynamoDB)
- Never update VMs directly; use Terragrunt or Ansible

### Ansible

- Roles in `ansible/roles/` with Molecule tests
- Collections in `ansible/requirements.yml`
- Config in `ansible/.ansible-lint` (profile: production)
- Docker-based testing with geerlingguy images

### Security

- Never commit secrets, API tokens, or passwords
- Reference private context for real infrastructure details
- Separate SSH keys per environment
- Enable state file encryption

## File References

| Need | Location |
| ---- | -------- |
| Architecture (canonical) | docs/ARCHITECTURE.md |
| Secrets roadmap | docs/SECRETS_ROADMAP.md |
| General docs | README.md |
| Troubleshooting | TROUBLESHOOTING.md |
| Planning | GitHub Issues |
| Change history | PR descriptions and commits |
| Ansible config | ansible/.ansible-lint |
| Molecule tests | ansible/roles/*/molecule/ |
| CI workflows | .github/workflows/ |

## When to Ask for Clarification

Ask the user before proceeding if:

- Current tool versions are unclear
- Multiple valid implementation approaches exist
- Changes affect production infrastructure
- Security implications are uncertain
- Breaking changes may be introduced

## PR Review Checklist

- [ ] No exposed secrets or credentials
- [ ] Variables documented with `sensitive = true` where needed
- [ ] Terraform: `terragrunt validate` passes
- [ ] Ansible: `ansible-lint` passes
- [ ] Ansible roles: `molecule test` passes
- [ ] Conventional commit message
- [ ] Documentation updated if needed
