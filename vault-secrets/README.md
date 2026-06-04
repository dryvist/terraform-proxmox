# Vault Secrets

Terraform unit that proves the read+write loop against a live OpenBao
instance. It is managed **separately** from Proxmox and `aws-infra/`, with its
own state.

## When to Apply

Apply this unit **AFTER**:

1. The `openbao` Ansible role brings OpenBao live and enables the KV v2 secrets
   engine at `mount = "secret"`.
2. `VAULT_ADDR`, `VAULT_ROLE_ID`, and `VAULT_SECRET_ID` are present in Doppler
   (the AppRole the openbao role provisions for Terraform).

If the `secret` mount is not yet enabled, or the AppRole credentials are
missing, `terragrunt apply` will fail.

## What It Does

1. Reuses the shared `../modules/security` module to generate a demo password
   and SSH key pair (`random_password` + `tls_private_key`).
2. Writes those values into OpenBao at `secret/homelab/demo/vm`
   (`vault_kv_secret_v2.demo`) — proves the **write** path.
3. Reads the same path back (`data.vault_kv_secret_v2.demo_read`) — proves the
   **read** path.

Outputs expose only non-sensitive proof (`demo_secret_path`,
`demo_secret_version`); the secret value itself is never output.

## Requirements

- [Nix](https://nixos.org/download/) with flakes enabled (provides Terraform/Terragrunt via nix-devenv)
- [aws-vault](https://github.com/99designs/aws-vault) with `tf-proxmox` profile configured (for the S3 state backend)
- [Doppler CLI](https://docs.doppler.com/docs/install-cli) configured for `iac-conf-mgmt` project
- A live OpenBao instance with the KV v2 engine enabled at `mount = "secret"`
- `VAULT_ADDR`, `VAULT_ROLE_ID`, and `VAULT_SECRET_ID` present in Doppler

## Usage

```bash
# Validate
nix develop "github:JacobPEvans/nix-devenv?dir=shells/terraform" --command bash -c \
  "aws-vault exec tf-proxmox -- doppler run -- terragrunt validate"

# Plan
nix develop "github:JacobPEvans/nix-devenv?dir=shells/terraform" --command bash -c \
  "aws-vault exec tf-proxmox -- doppler run -- terragrunt plan"

# Apply
nix develop "github:JacobPEvans/nix-devenv?dir=shells/terraform" --command bash -c \
  "aws-vault exec tf-proxmox -- doppler run -- terragrunt apply"
```

`aws-vault` is still required because the state backend lives in S3 + DynamoDB;
the Vault provider itself authenticates via AppRole, not AWS.

## Inputs

| Name            | Description                      | Type   | Sensitive |
| --------------- | -------------------------------- | ------ | --------- |
| vault_addr      | OpenBao API address              | string | no        |
| vault_role_id   | AppRole role ID for Terraform    | string | yes       |
| vault_secret_id | AppRole secret ID for Terraform  | string | yes       |

## Outputs

| Name                | Description                                  |
| ------------------- | -------------------------------------------- |
| demo_secret_path    | KV v2 path the demo secret was written to    |
| demo_secret_version | Version number of the demo secret in OpenBao |

## State Management

| Root Module   | State Key                                           |
| ------------- | --------------------------------------------------- |
| vault-secrets | `terraform-proxmox/vault-secrets/terraform.tfstate` |
| aws-infra     | `terraform-proxmox/aws-infra/terraform.tfstate`     |
| Proxmox       | `terraform-proxmox/terraform.tfstate`               |

All three use the same S3 bucket and DynamoDB table for state locking.

## Notes

- This unit has its own state and does **NOT** trigger the root module's
  `after_hook` inventory sync — applying it never touches downstream Ansible
  repos.
- The `secret` KV v2 mount must already be enabled (the openbao Ansible role
  enables it). This unit does not enable the mount.
