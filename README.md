# Terraform Proxmox Infrastructure

Terraform/Terragrunt IaC for the Proxmox VE homelab. Provisions VMs, LXC
containers, resource pools, firewall rules, and ACME certificates. State is
stored in S3 with DynamoDB locking.

## Installation

All tooling ships via the Nix devshell — activate once per worktree with
`direnv allow` (requires direnv + nix-direnv); after that it's automatic on
every `cd`.

```bash
direnv allow        # one-time
```

Tooling provided: `terragrunt`, `opentofu`, `terraform-docs`, `tflint`,
`tfsec`, `trivy`, `sops`, `age`, `awscli2`, `jq`, `yq`, `pre-commit`.

## Usage

Every credentialed command requires AWS credentials (state backend) and
Doppler (provider secrets). Run all commands through the wrapper:

```bash
aws-vault exec tf-proxmox -- doppler run -- terragrunt <COMMAND>
```

Exploratory (not implemented): a Proton Pass bootstrap path is being explored to
materialize the SOPS age key on fresh hosts (incl. Linux cloud agents), so the
wrapper can decrypt `terraform.sops.json` anywhere:

```bash
./scripts/secrets-bootstrap.sh   # idempotent; writes ~/.config/sops/age/keys.txt if absent
```

Today the age key is set up per host via `age-keygen` (see
[docs/SOPS_SETUP.md](./docs/SOPS_SETUP.md)); the Proton Pass proposal is in
[docs/PROTON_PASS_STRATEGY.md](./docs/PROTON_PASS_STRATEGY.md).

Common operations:

```bash
doppler run -- terragrunt validate
doppler run -- terragrunt plan
doppler run -- terragrunt apply
doppler run -- terragrunt show
```

Note: `aws-vault exec` triggers a keychain prompt on each invocation. Batch
all credentialed work in a single `aws-vault exec tf-proxmox -- claude`
session rather than re-invoking repeatedly.

## Configuration

Config is split across three layers:

| Source | Contents | How to edit |
| ------ | -------- | ----------- |
| `deployment.json` | Container/VM definitions, pools, node placement | Private, in the on-prem `s3` store (see [AGENTS.md](AGENTS.md)) |
| `terraform.sops.json` | Per-VLAN network CIDRs, domain, SSH key paths | Decrypt with SOPS, edit, re-encrypt |
| Doppler | `PROXMOX_VE_*`, SSH key content, credentials | Doppler web UI or CLI |

`terraform.tfvars` is gitignored and must not exist — it silently overrides
`deployment.json` via Terraform variable precedence.

See [docs/SOPS_SETUP.md](./docs/SOPS_SETUP.md) for the full three-layer setup.

## IP derivation

Every guest IP is `cidrhost(<vlan CIDR>, vm_id)`. No literal IPs are
committed anywhere in this repo — they are derived at plan-time from
Doppler-supplied `NETWORK_CIDR_*` values.

## Testing

```bash
tofu test           # mock-provider contract tests (no credentials needed)
```

The full suite runs automatically in CI on every PR.

## Documentation

| Doc | Purpose |
| --- | ------- |
| [docs/ARCHITECTURE.md](./docs/ARCHITECTURE.md) | Pipeline architecture and IP derivation |
| [docs/SOPS_SETUP.md](./docs/SOPS_SETUP.md) | SOPS + age setup, Doppler integration |
| [docs/PROTON_PASS_STRATEGY.md](./docs/PROTON_PASS_STRATEGY.md) | Exploratory: Proton Pass as a future root-of-trust + AI-agent keychain |
| [TROUBLESHOOTING.md](./TROUBLESHOOTING.md) | Operational guidance, timeout/debug logging |

## License

Apache License 2.0 — see [LICENSE](LICENSE).

---

> Part of a [larger ecosystem of ~40 repos](https://docs.jacobpevans.com) — see how it all fits together.
