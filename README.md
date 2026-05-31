# Terraform Proxmox Infrastructure

This project contains Terraform/Terragrunt configurations for managing Proxmox VE infrastructure with virtual machines
for automation, development, logging, and service management.

## Overview

This repository provides Terraform configurations to provision and manage:

- Virtual machines and containers on Proxmox VE
- Automation infrastructure to manage all VMs and containers
- Logging infrastructure and centralized syslog
- Container orchestration with Kubernetes k3s and Docker
- Resource pools and networking
- SSH keys and authentication

## Architecture

The project uses a modular structure for better maintainability and reusability:

```text
terraform-proxmox/
├── main.tf                    # Root module orchestrating all components
├── variables.tf               # Root-level variable definitions
├── outputs.tf                 # Root-level outputs
├── locals.tf                  # Local value definitions
├── container.tf               # Container resource definitions
├── deployment.json.example    # Example deployment config (copy to deployment.json)
├── terraform.sops.json        # Encrypted network topology (3 values)
├── terraform.sops.json.example # SOPS template
├── terragrunt.hcl             # Terragrunt configuration (generates provider.tf)
├── packer/                    # Packer templates for VM images
│   ├── splunk.pkr.hcl         # Splunk Enterprise template build
│   └── variables.pkr.hcl      # Packer variables (Doppler integration)
└── modules/
    ├── proxmox-pool/          # Resource pool management
    ├── proxmox-vm/            # Virtual machine creation
    ├── proxmox-container/     # Container management
    ├── splunk-vm/             # Splunk Enterprise all-in-one VM
    ├── security/              # Security resources (SSH keys, passwords)
    ├── firewall/              # Proxmox firewall rules for clusters
    └── storage/               # Storage and cloud-init configs
```

## Features

### Implemented

- **Modular Design**: Separate modules for different resource types
- **Security**: Static SSH key management via cloud-init
- **Resource Pools**: Organized resource management
- **Virtual Machines**: Configurable VM deployments with virtio disk interface
- **Containers**: LXC container support (configurable)
- **Storage**: Cloud-init configuration management
- **Splunk Infrastructure**: Packer-built Splunk Enterprise template with dedicated splunk-vm module
- **Firewall Management**: Integrated Proxmox firewall module for network isolation and security
- **Terragrunt Integration**: Backend configuration and state management
- **Latest Versions**: See `terragrunt.hcl` for current provider version constraints

### Benefits of the Modular Structure

1. **Eliminated Duplication**: All VMs use the same module
2. **Improved Reusability**: Modules can be used across different environments
3. **Enhanced Maintainability**: Clear separation of concerns
4. **Better Security**: Static SSH key management with cloud-init
5. **Consistent Configuration**: Standardized VM settings with virtio interfaces
6. **Performance Optimized**: Virtio disk interfaces eliminate Proxmox warnings

## Requirements

### Option A: Using Nix Shell (Recommended)

All tools are provided via the shared [nix-devenv terraform shell](https://github.com/JacobPEvans/nix-devenv/tree/main/shells/terraform).
The repository ships a committed `.envrc` file that auto-activates
the shell via direnv when you enter the directory.

**Requirements:**

- [Nix](https://nixos.org/download/) with flakes enabled
- [direnv](https://direnv.net/docs/installation.html) with [nix-direnv](https://github.com/nix-community/nix-direnv)

```bash
# Automatic activation (requires direnv + nix-direnv)
direnv allow    # one-time per worktree, then automatic on cd

# Manual activation
nix develop "github:JacobPEvans/nix-devenv?dir=shells/terraform"
```

**Tools provided:**

- `terragrunt`, `opentofu`, `terraform-docs`, `tflint` -- IaC tooling
- `tfsec`, `trivy` -- security scanning
- `sops`, `age` -- secrets management
- `awscli2`, `git`, `python3` -- cloud and development
- `jq`, `yq` -- utilities
- `pre-commit` -- git hook management

See **[nix-devenv shells/terraform](https://github.com/JacobPEvans/nix-devenv/tree/main/shells/terraform)** for the complete dev environment definition.

### Option B: Manual Installation

Install the following tools manually:

- Terraform >= 1.12.2
- Terragrunt >= 0.81.10
- AWS CLI configured
- Proxmox API token
- SSH key pair
- Security scanners (tfsec, trivy)
- Ansible and molecule (for configuration management)

## Usage

### Essential Commands

```bash
# Plan changes
terragrunt plan

# Deploy infrastructure
terragrunt apply -auto-approve

# Destroy infrastructure
terragrunt destroy --terragrunt-parallelism=1

# Check state
terragrunt state list

# View infrastructure
terragrunt show
```

### Configuration

Configuration is split into three layers:

```text
deployment.json          (local only, gitignored) — containers, VMs, pools, proxmox_node
terraform.sops.json      (committed, encrypted)   — network_prefix, SSH key paths
Doppler env vars         (runtime only)           — PROXMOX_VE_*, SPLUNK_*, credentials
```

1. **Edit non-secret config** by copying the example and editing locally:

   ```bash
   cp deployment.json.example deployment.json
   $EDITOR deployment.json
   ```

2. **Set up SOPS** for the 3 encrypted values (network prefix + SSH key paths):

   ```bash
   cp terraform.sops.json.example terraform.sops.json
   $EDITOR terraform.sops.json        # fill in real values
   sops --encrypt --in-place terraform.sops.json
   git add terraform.sops.json
   ```

3. **See the complete guide**: [docs/SOPS_SETUP.md](./docs/SOPS_SETUP.md)

   This document explains the full 3-layer architecture, SOPS key setup,
   Doppler credential management, and derived network values.

## Repository Structure

| File | Purpose |
| ---- | ------- |
| `main.tf` | Core resource definitions and VM orchestration |
| `variables.tf` | Input variable definitions with validation |
| `locals.tf` | Local value computations and transformations |
| `container.tf` | Container resources and configurations |
| `outputs.tf` | Output value definitions |
| `terragrunt.hcl` | Remote state management (generates provider.tf) |
| `deployment.json.example` | Example deployment config (copy to `deployment.json`, gitignored) |
| `terraform.sops.json` | Encrypted network topology (3 values) |
| `terraform.sops.json.example` | SOPS template |

## Configuration

### Required Variables

- `proxmox_api_endpoint` - Proxmox API URL
- `proxmox_api_token` - API authentication token
- `proxmox_ssh_private_key` - SSH key for Proxmox host access

### State Management

- **Backend**: AWS S3 + DynamoDB
- **Encryption**: Enabled
- **Locking**: DynamoDB table for state locking

## Storage Configuration

**Note**: Proxmox datastore creation is typically done manually or via Proxmox API.
The bpg/proxmox provider doesn't support datastore creation through Terraform.
This follows Proxmox best practices to manage storage at the hypervisor level.

Default datastores used:

- `local`: For ISO images, snippets, backups
- `local-zfs`: For VM disks (recommended for better performance)
- `local-lvm`: Alternative storage option

Additional datastores should be configured directly in Proxmox VE before running Terraform.

## VM Configuration

All VMs are configured with:

- Hardware-constrained resource allocation
- Virtio disk interfaces for optimal performance
- Debian 13.2.0 (Trixie)
- Cloud-init integration with static SSH keys
- SSH key authentication from configured SSH key

**Infrastructure Summary**:

- 1 VM (Splunk Enterprise all-in-one): ID 100
- 5 LXC Containers: IDs 200, 205, 210-211, 220
- See [INFRASTRUCTURE_NUMBERING.md](./docs/INFRASTRUCTURE_NUMBERING.md) for complete details

## Testing

### Splunk Protection Tests

Verify Splunk VM protection guarantees (plan safety, output structure, live health):

```bash
# Plan-level tests (safe, no infrastructure changes):
aws-vault exec tf-proxmox -- doppler run -- ./scripts/test-splunk-protection.sh

# With live VM health checks:
aws-vault exec tf-proxmox -- doppler run -- ./scripts/test-splunk-protection.sh --live
```

### Terraform Test Suite

Run the `.tftest.hcl` mock test suite directly:

```bash
terraform test
# or: tofu test
```

## Documentation

### Setup & Configuration

- **[DEPLOYMENT_GUIDE.md](./docs/DEPLOYMENT_GUIDE.md)** - **START HERE**: Complete deployment walkthrough
- **[Managing Real Infrastructure Values](./docs/MANAGING_REAL_VALUES.md)** -
  **CRITICAL**: How to safely maintain real IPs/hostnames separate from committed code
- **[Nix Shell Setup Guide](./docs/nix-shell-setup.md)** - Comprehensive guide to using Nix shells for development

### Infrastructure Reference

- **[INFRASTRUCTURE_NUMBERING.md](./docs/INFRASTRUCTURE_NUMBERING.md)** - Complete infrastructure map and numbering scheme
- **[Splunk Cluster Specification](./docs/splunk-cluster-spec.md)** - Detailed Splunk configuration

### Troubleshooting

- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** - Operational guidance and common issues

## Current Status

**Infrastructure Ready**: Terraform state synchronization issues completely resolved. All state operations (plan, refresh, apply) work reliably
with proper S3 + DynamoDB backend connectivity. Ready for controlled infrastructure deployment and k3s/Docker container setup.

## Security

- Passwords configured per VM via cloud-init user accounts
- All sensitive outputs are marked as sensitive
- State files are encrypted in S3
- Least-privilege access principles applied
- Virtio interfaces provide secure disk access

## Best Practices Implemented

1. **Resource Tagging**: All resources tagged with environment and purpose
2. **Module Versioning**: Provider versions pinned for stability
3. **State Management**: Remote state with S3 backend and DynamoDB locking
4. **Variable Validation**: Input validation where appropriate
5. **Lifecycle Management**: Proper resource lifecycle configuration
6. **Error Handling**: Robust error handling and validation

## Contributing

1. Plan changes with `terragrunt plan`
2. Review infrastructure changes carefully
3. Test in isolated environments
4. Follow conventional commit messages

## Future Enhancements

- Add support for additional VM types
- Implement backup automation
- Add monitoring and alerting configurations
- Integrate with configuration management tools

## License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.

<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
