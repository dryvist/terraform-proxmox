# AWS Infrastructure

AWS resources for the Proxmox VE homelab, managed **separately** from Proxmox
infrastructure.

## Architecture

```text
terraform-proxmox/
├── aws-infra/                    # THIS DIRECTORY - AWS resources only
│   ├── main.tf                   # AWS provider, module instantiations
│   ├── variables.tf              # AWS-specific variables
│   ├── outputs.tf                # AWS-specific outputs
│   ├── terragrunt.hcl            # Separate state (aws-infra/terraform.tfstate)
│   └── modules/
│       └── route53-records/      # Route53 A record management
│
└── (root)                        # Proxmox resources only
    ├── main.tf                   # Proxmox provider, VMs, containers
    ├── terragrunt.hcl            # Separate state (terraform.tfstate)
    └── modules/
        ├── acme-certificate/     # Proxmox ACME (uses Route53 for DNS-01)
        ├── proxmox-vm/
        └── ...
```

## Why Separate?

1. **Different providers** - AWS and Proxmox have different auth, APIs, and life cycles
2. **Independent state** - AWS changes don't require Proxmox state lock
3. **Clear boundaries** - AWS resources in one place, Proxmox in another
4. **Different credentials** - AWS uses IAM, Proxmox uses API tokens

## Requirements

- [Nix](https://nixos.org/download/) with flakes enabled (provides Terraform/Terragrunt via nix-devenv)
- [aws-vault](https://github.com/99designs/aws-vault) with `tf-proxmox` profile configured
- [Doppler CLI](https://docs.doppler.com/docs/install-cli) configured for `infra-project/prd`
- Route53 hosted zone for the Proxmox domain

## Usage

### Prerequisites

1. Add AWS credentials to Doppler:

   ```bash
   doppler secrets set AWS_ROUTE53_ACCESS_KEY=<your-access-key>
   doppler secrets set AWS_ROUTE53_SECRET_KEY=...
   doppler secrets set ROUTE53_ZONE_ID=Z0123456789ABCDEFGHIJ
   doppler secrets set PROXMOX_DOMAIN=pve.example.com
   doppler secrets set PROXMOX_IP_ADDRESSES=192.168.10.10,192.168.10.11,192.168.10.12
   ```

2. Run from this directory:

   ```bash
   cd aws-infra/
   nix develop "github:JacobPEvans/nix-devenv?dir=shells/terraform" --command bash -c \
     "aws-vault exec tf-proxmox -- doppler run -- terragrunt init"
   ```

   The Nix shell provides Terraform, Terragrunt, aws-vault, and other tools automatically.

### Commands

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

## Modules

| Module          | Purpose                                               |
| --------------- | ----------------------------------------------------- |
| route53-records | Manages A record set for the Proxmox VE UI/API domain |

## Cross-Reference with Proxmox

The Proxmox ACME module uses Route53 for DNS-01 validation. The workflow:

1. **Deploy aws-infra first** - Creates the A record for pve.example.com
2. **Deploy Proxmox** - ACME module validates domain ownership via Route53

The ACME module in Proxmox needs AWS credentials for DNS-01 challenges. These
are passed via `dns_plugins` variable from Doppler.

## State Management

| Root Module | State Key                                         |
| ----------- | ------------------------------------------------- |
| aws-infra   | `terraform-proxmox/aws-infra/terraform.tfstate`   |
| Proxmox     | `terraform-proxmox/terraform.tfstate`             |

Both use the same S3 bucket and DynamoDB table for state locking.
