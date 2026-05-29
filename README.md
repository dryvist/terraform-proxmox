# Terraform Proxmox Infrastructure

This project contains Terraform/Terragrunt configurations for managing Proxmox VE infrastructure with virtual machines
for automation, development, logging, and service management.

## 🏗️ Overview

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
├── deployment.json            # Non-secret deployment config (committed plaintext)
├── terraform.sops.json       # Encrypted network topology (3 values)
├── terraform.sops.json.example # SOPS template
├── terragrunt.hcl            # Terragrunt configuration (generates provider.tf)
├── packer/                    # Packer templates for VM images
│   ├── splunk.pkr.hcl        # Splunk Enterprise template build
│   └── variables.pkr.hcl     # Packer variables (Doppler integration)
└── modules/
    ├── proxmox-pool/          # Resource pool management
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── proxmox-vm/            # Virtual machine creation
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── proxmox-container/     # Container management
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── splunk-vm/             # Splunk Enterprise all-in-one VM
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── security/              # Security resources (SSH keys, passwords)
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    ├── firewall/              # Proxmox firewall rules for clusters
    │   ├── main.tf
    │   ├── variables.tf
    │   └── outputs.tf
    └── storage/               # Storage and cloud-init configs
        ├── main.tf
        ├── variables.tf
        └── outputs.tf
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
deployment.json          (committed, plaintext) — containers, VMs, pools, proxmox_node
terraform.sops.json      (committed, encrypted) — network_prefix, SSH key paths
Doppler env vars         (runtime only)         — PROXMOX_VE_*, SPLUNK_*, credentials
```

1. **Edit non-secret config** directly in `deployment.json`:

   ```bash
   # deployment.json is committed plaintext — edit and commit normally
   $EDITOR deployment.json
   git add deployment.json && git commit -m "chore: update containers"
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

## 📁 Repository Structure

| File | Purpose |
| ---- | ------- |
| `main.tf` | Core resource definitions and VM orchestration |
| `variables.tf` | Input variable definitions with validation |
| `locals.tf` | Local value computations and transformations |
| `container.tf` | Container resources and configurations |
| `outputs.tf` | Output value definitions |
| `terragrunt.hcl` | Remote state management (generates provider.tf) |
| `deployment.json` | Non-secret deployment config (containers, VMs, pools) |
| `terraform.sops.json` | Encrypted network topology (3 values) |
| `terraform.sops.json.example` | SOPS template |

## 🔧 Configuration

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

## 📖 Documentation

### Setup & Configuration

- **[DEPLOYMENT_GUIDE.md](./docs/DEPLOYMENT_GUIDE.md)** - **START HERE**: Complete deployment walkthrough
- **[Managing Real Infrastructure Values](./docs/MANAGING_REAL_VALUES.md)** -
  **CRITICAL**: How to safely maintain real IPs/hostnames separate from committed code
- **[Nix Shell Setup Guide](./docs/nix-shell-setup.md)** - Comprehensive guide to using Nix shells for development
- **[OpenHands Integration](./docs/openhands-integration.md)** -
  Guide for integrating OpenHands AI software engineer with Nix, OrbStack, Terraform, and Kubernetes

### Infrastructure Reference

- **[INFRASTRUCTURE_NUMBERING.md](./docs/INFRASTRUCTURE_NUMBERING.md)** - Complete infrastructure map and numbering scheme
- **[Splunk Cluster Specification](./docs/splunk-cluster-spec.md)** - Detailed Splunk configuration

### Troubleshooting

- **[TROUBLESHOOTING.md](./TROUBLESHOOTING.md)** - Operational guidance and common issues
- **[TERRAGRUNT_STATE_TROUBLESHOOTING.md](./TERRAGRUNT_STATE_TROUBLESHOOTING.md)** - Historical state management issues (resolved)

## ✅ Current Status

**Infrastructure Ready**: Terraform state synchronization issues completely resolved. All state operations (plan, refresh, apply) work reliably
with proper S3 + DynamoDB backend connectivity. Ready for controlled infrastructure deployment and k3s/Docker container setup.

## 🛡️ Security

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

## 🤝 Contributing

1. Plan changes with `terragrunt plan`
2. Review infrastructure changes carefully
3. Test in isolated environments
4. Follow conventional commit messages

## Future Enhancements

- Add support for additional VM types
- Implement backup automation
- Add monitoring and alerting configurations
- Integrate with configuration management tools

## 📄 License

This project is licensed under the Apache License 2.0 - see the [LICENSE](LICENSE) file for details.
<!-- BEGINNING OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.10 |
| <a name="requirement_local"></a> [local](#requirement\_local) | ~> 2.5 |
| <a name="requirement_null"></a> [null](#requirement\_null) | ~> 3.2 |
| <a name="requirement_proxmox"></a> [proxmox](#requirement\_proxmox) | ~> 0.106 |
| <a name="requirement_random"></a> [random](#requirement\_random) | ~> 3.7 |
| <a name="requirement_tls"></a> [tls](#requirement\_tls) | ~> 4.1 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_local"></a> [local](#provider\_local) | 2.9.0 |
| <a name="provider_null"></a> [null](#provider\_null) | 3.3.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| <a name="module_acme_certificates"></a> [acme\_certificates](#module\_acme\_certificates) | ./modules/acme-certificate | n/a |
| <a name="module_containers"></a> [containers](#module\_containers) | ./modules/proxmox-container | n/a |
| <a name="module_firewall"></a> [firewall](#module\_firewall) | ./modules/firewall | n/a |
| <a name="module_pools"></a> [pools](#module\_pools) | ./modules/proxmox-pool | n/a |
| <a name="module_rack_server_cluster"></a> [rack\_server\_cluster](#module\_rack\_server\_cluster) | ./modules/rack-server-cluster | n/a |
| <a name="module_splunk_vm"></a> [splunk\_vm](#module\_splunk\_vm) | ./modules/splunk-vm | n/a |
| <a name="module_storage"></a> [storage](#module\_storage) | ./modules/storage | n/a |
| <a name="module_vms"></a> [vms](#module\_vms) | ./modules/proxmox-vm | n/a |

## Resources

| Name | Type |
|------|------|
| [null_resource.ansible_ssh_key_setup](https://registry.terraform.io/providers/hashicorp/null/latest/docs/resources/resource) | resource |
| [local_file.vm_ssh_public_key](https://registry.terraform.io/providers/hashicorp/local/latest/docs/data-sources/file) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_acme_accounts"></a> [acme\_accounts](#input\_acme\_accounts) | ACME account configurations for Let's Encrypt certificate management | <pre>map(object({<br/>    email     = string<br/>    directory = string<br/>    tos       = string<br/>  }))</pre> | `{}` | no |
| <a name="input_acme_certificates"></a> [acme\_certificates](#input\_acme\_certificates) | ACME certificates to provision and manage. Each entry maps to a single<br/>proxmox\_acme\_certificate resource per node, which can cover one primary<br/>domain plus a list of SANs. After issuance, the cert (combined PEM<br/>bundle and/or split cert+key files) can be delivered to LXCs or VMs<br/>via the module's null\_resource provisioner. | <pre>map(object({<br/>    node_name     = string<br/>    domain        = string                     # primary CN (e.g., "pve.example.com")<br/>    account_id    = string                     # ACME account name (key in var.acme_accounts)<br/>    dns_plugin_id = string                     # DNS plugin name (key in var.dns_plugins)<br/>    sans          = optional(list(string), []) # Additional SANs (each uses dns_plugin_id)<br/>    destinations = optional(list(object({<br/>      kind        = string                   # "lxc" or "vm"<br/>      target_id   = number                   # vm_id of the LXC or VM<br/>      target_ip   = optional(string)         # required when kind = "vm" (SSH host for scp)<br/>      bundle_path = optional(string)         # combined cert+key PEM (e.g., "/etc/ssl/private/infisical.pem")<br/>      cert_path   = optional(string)         # separate cert+chain PEM (e.g., "/opt/splunk/etc/auth/server.pem")<br/>      key_path    = optional(string)         # separate private key (e.g., "/opt/splunk/etc/auth/server.key")<br/>      mode        = optional(string, "0600") # file mode for delivered files<br/>      owner       = optional(string, "root") # file owner<br/>      group       = optional(string, "root") # file group<br/>      reload_cmd  = optional(string, "")     # command to run on the target after delivery<br/>    })), [])<br/>  }))</pre> | `{}` | no |
| <a name="input_ansible_cloud_init_file"></a> [ansible\_cloud\_init\_file](#input\_ansible\_cloud\_init\_file) | Path to the cloud-init configuration file for Ansible server | `string` | `"cloud-init/ansible-server-example.yml"` | no |
| <a name="input_bridge"></a> [bridge](#input\_bridge) | Network bridge for Splunk VM network interface | `string` | `"vmbr0"` | no |
| <a name="input_containers"></a> [containers](#input\_containers) | Map of containers to create | <pre>map(object({<br/>    vm_id       = number<br/>    hostname    = string<br/>    description = optional(string)<br/>    tags        = optional(list(string), ["terraform", "container"])<br/>    pool_id     = optional(string)<br/><br/>    # Node placement (optional). When unset, main.tf defaults to var.proxmox_node<br/>    # (the primary node). Set to "pve2"/"pve3" to place an LXC on another cluster node.<br/>    node_name = optional(string)<br/><br/>    # Resource configuration<br/>    cpu_cores        = optional(number, 2)<br/>    memory_dedicated = optional(number, 512)<br/>    memory_swap      = optional(number, 512)<br/><br/>    # Storage<br/>    root_disk = optional(object({<br/>      datastore_id = optional(string)<br/>      size         = optional(number, 16)<br/>    }), {})<br/><br/>    # Mount points (additional volumes mounted into the container)<br/>    mount_points = optional(list(object({<br/>      volume = string<br/>      size   = string<br/>      path   = string<br/>    })), [])<br/><br/>    # Network<br/>    network_interfaces = optional(list(object({<br/>      name     = optional(string, "eth0")<br/>      bridge   = optional(string, "vmbr0")<br/>      firewall = optional(bool, true)<br/>    })), [{ name = "eth0", bridge = "vmbr0", firewall = true }])<br/><br/>    # Initialization<br/>    ip_config = optional(object({<br/>      ipv4_address = optional(string)<br/>      ipv4_gateway = optional(string)<br/>    }), {})<br/><br/>    # User account configuration<br/>    user_account = optional(object({<br/>      username = string<br/>      password = string<br/>      keys     = list(string)<br/>    }))<br/><br/>    unprivileged  = optional(bool, false)<br/>    protection    = optional(bool, false)<br/>    os_type       = optional(string, "debian")<br/>    start_on_boot = optional(bool, true)<br/><br/>    # LXC features (set nesting=true for Docker-in-LXC on unprivileged containers;<br/>    # privileged containers run Docker without features — requires root@pam to set any flag)<br/>    features = optional(object({<br/>      nesting = optional(bool, false)<br/>      keyctl  = optional(bool, false)<br/>      fuse    = optional(bool, false)<br/>      mount   = optional(list(string), [])<br/>    }), { nesting = false, keyctl = false, fuse = false, mount = [] })<br/>  }))</pre> | `{}` | no |
| <a name="input_datastore_default"></a> [datastore\_default](#input\_datastore\_default) | Default datastore for VM disks and container volumes | `string` | `"local-zfs"` | no |
| <a name="input_datastore_id"></a> [datastore\_id](#input\_datastore\_id) | Datastore ID for Splunk VM disk storage | `string` | `"local-zfs"` | no |
| <a name="input_datastore_iso"></a> [datastore\_iso](#input\_datastore\_iso) | Datastore for ISO images and container templates | `string` | `"local"` | no |
| <a name="input_datastores"></a> [datastores](#input\_datastores) | Map of additional datastores to create beyond default local storage | <pre>map(object({<br/>    type    = string # "dir", "nfs", etc.<br/>    path    = optional(string)<br/>    content = optional(list(string), ["images", "vztmpl", "iso", "backup"])<br/>    shared  = optional(bool, false)<br/>    nodes   = optional(list(string))<br/>    # NFS specific<br/>    server  = optional(string)<br/>    export  = optional(string)<br/>    options = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_dns_plugins"></a> [dns\_plugins](#input\_dns\_plugins) | DNS challenge plugins for ACME validation (e.g., AWS Route53) | <pre>map(object({<br/>    plugin_type = string      # API plugin name (e.g., "route53")<br/>    data        = map(string) # DNS plugin data as key=value pairs (e.g., AWS credentials)<br/>  }))</pre> | `{}` | no |
| <a name="input_domain"></a> [domain](#input\_domain) | Internal domain for FQDN resolution (e.g., example.com) | `string` | `""` | no |
| <a name="input_environment"></a> [environment](#input\_environment) | Environment name for resource tagging and organization | `string` | `"homelab"` | no |
| <a name="input_host_services"></a> [host\_services](#input\_host\_services) | Host-level services config (ZFS datasets, Samba shares) for ansible-proxmox consumption | <pre>object({<br/>    nas = optional(object({<br/>      zfs_dataset    = string<br/>      zfs_quota      = string<br/>      mount_point    = string<br/>      smb_share_name = string<br/>      directories    = list(string)<br/>      group_name     = optional(string)<br/>      managed_users = optional(list(object({<br/>        name                = string<br/>        unix_groups         = optional(list(string))<br/>        shell               = optional(string)<br/>        create_home         = optional(bool)<br/>        password_secret_env = string<br/>      })))<br/>      shares = optional(list(object({<br/>        name           = string<br/>        path           = string<br/>        valid_users    = string<br/>        browsable      = optional(bool)<br/>        read_only      = optional(bool)<br/>        force_group    = optional(string)<br/>        create_mask    = optional(string)<br/>        directory_mask = optional(string)<br/>        comment        = optional(string)<br/>      })))<br/>      description = optional(string)<br/>    }))<br/>  })</pre> | `{}` | no |
| <a name="input_internal_networks"></a> [internal\_networks](#input\_internal\_networks) | RFC1918 networks allowed to access Splunk (SSH, Web UI, forwarding port 9997). Configure in terraform.tfvars for your actual networks. | `list(string)` | <pre>[<br/>  "10.0.0.0/8",<br/>  "172.16.0.0/12",<br/>  "192.168.0.0/16"<br/>]</pre> | no |
| <a name="input_network_cidr_mask"></a> [network\_cidr\_mask](#input\_network\_cidr\_mask) | CIDR mask for network IPs (use /24 for standard LAN, /32 only for point-to-point) | `string` | `"/24"` | no |
| <a name="input_network_prefix"></a> [network\_prefix](#input\_network\_prefix) | Network prefix for IP address derivation (e.g., '192.168.0' - IPs derived as prefix.vm\_id) | `string` | `"192.168.0"` | no |
| <a name="input_node_storage"></a> [node\_storage](#input\_node\_storage) | Per-node ZFS pools/datasets/quotas for ansible-proxmox to provision; Terraform consumes the datastore by id. | <pre>map(object({<br/>    pools = map(object({<br/>      type = optional(string, "zfspool")<br/>      raid = optional(string) # raidz1, raidz2, mirror (informational)<br/>      # protected pools must never be auto-destroyed; ansible-proxmox enforces<br/>      # zfs hold / readonly / snapshot retention (storage-safety, design pending).<br/>      protected = optional(bool, true)<br/>      register  = optional(bool, true) # register as PVE storage via pvesm<br/>      content   = optional(list(string), ["images", "rootdir"])<br/>      datasets = optional(map(object({<br/>        quota      = optional(string)<br/>        mountpoint = optional(string)<br/>        nfs_export = optional(string)<br/>      })), {})<br/>    }))<br/>  }))</pre> | `{}` | no |
| <a name="input_nodes"></a> [nodes](#input\_nodes) | Proxmox cluster node inventory (non-secret identity), surfaced to ansible-proxmox via ansible\_inventory. | <pre>map(object({<br/>    role         = string               # role label: pve1 | pve2 | pve3<br/>    hardware     = optional(string)     # e.g. amd-desktop, dell-r410, dell-r710<br/>    commissioned = optional(bool, true) # false = declared but not yet installed<br/>  }))</pre> | <pre>{<br/>  "pve": {<br/>    "hardware": "amd-desktop",<br/>    "role": "pve1"<br/>  }<br/>}</pre> | no |
| <a name="input_pools"></a> [pools](#input\_pools) | Map of resource pools to create | <pre>map(object({<br/>    comment = optional(string)<br/>  }))</pre> | `{}` | no |
| <a name="input_proxmox_ct_template_debian"></a> [proxmox\_ct\_template\_debian](#input\_proxmox\_ct\_template\_debian) | The name of the Debian container template to use for containers | `string` | `"debian-13-standard_13.1-2_amd64.tar.zst"` | no |
| <a name="input_proxmox_iso_debian"></a> [proxmox\_iso\_debian](#input\_proxmox\_iso\_debian) | The name of the Debian ISO file to use for VMs | `string` | `"debian-13.2.0-amd64-netinst.iso"` | no |
| <a name="input_proxmox_node"></a> [proxmox\_node](#input\_proxmox\_node) | The name of the Proxmox node to deploy resources on | `string` | `"pve"` | no |
| <a name="input_proxmox_ssh_host"></a> [proxmox\_ssh\_host](#input\_proxmox\_ssh\_host) | Hostname or IP for SSH access to the Proxmox node. Used by the acme-certificate module's null\_resource provisioner to deliver issued certs to LXCs/VMs. Sourced from PROXMOX\_VE\_HOSTNAME via Doppler/terragrunt. | `string` | `""` | no |
| <a name="input_proxmox_ssh_private_key"></a> [proxmox\_ssh\_private\_key](#input\_proxmox\_ssh\_private\_key) | The SSH private key content for connecting to the Proxmox node (use secure parameter store or environment variable) | `string` | `"~/.ssh/id_rsa"` | no |
| <a name="input_proxmox_ssh_username"></a> [proxmox\_ssh\_username](#input\_proxmox\_ssh\_username) | The SSH username for connecting to the Proxmox node (for cloud-init, etc.) | `string` | `"root@pam"` | no |
| <a name="input_rack_servers"></a> [rack\_servers](#input\_rack\_servers) | Map of rack servers joining the Proxmox cluster. Keyed by node name<br/>(chosen by the operator — e.g. "node-a", "node-b"). Real values supplied<br/>via SOPS-encrypted terraform.sops.json; default is an empty map so plans<br/>succeed cleanly before any nodes are populated.<br/><br/>Fields:<br/>  chassis     - Free-form model identifier ("r410", "r710", "dl360-g6",<br/>                "x10sdv", etc.). Not validated against a vendor list so<br/>                HPE/Supermicro/etc. fit alongside Dell.<br/>  bmc\_ip      - Out-of-band management IP (iDRAC on Dell, iLO on HPE,<br/>                IMM on Lenovo, etc.).<br/>  bmc\_mac     - BMC NIC MAC address (dedicated NIC where available).<br/>  service\_tag - Vendor service tag, used for inventory + warranty lookup.<br/>  mgmt\_ip     - Host OS management IP (PVE web UI, SSH). | <pre>map(object({<br/>    chassis     = string<br/>    bmc_ip      = string<br/>    bmc_mac     = string<br/>    service_tag = string<br/>    mgmt_ip     = string<br/>  }))</pre> | `{}` | no |
| <a name="input_splunk_boot_disk_size"></a> [splunk\_boot\_disk\_size](#input\_splunk\_boot\_disk\_size) | Size of Splunk VM boot disk in GB | `number` | `25` | no |
| <a name="input_splunk_cpu_cores"></a> [splunk\_cpu\_cores](#input\_splunk\_cpu\_cores) | Number of CPU cores for the Splunk VM | `number` | `8` | no |
| <a name="input_splunk_data_disk_size"></a> [splunk\_data\_disk\_size](#input\_splunk\_data\_disk\_size) | Size of Splunk VM additional data disk in GB (0 = no additional disk) | `number` | `200` | no |
| <a name="input_splunk_memory"></a> [splunk\_memory](#input\_splunk\_memory) | Memory in MB for the Splunk VM | `number` | `12288` | no |
| <a name="input_splunk_vm_id"></a> [splunk\_vm\_id](#input\_splunk\_vm\_id) | VM ID for the Splunk VM | `number` | `100` | no |
| <a name="input_splunk_vm_name"></a> [splunk\_vm\_name](#input\_splunk\_vm\_name) | Name of the Splunk VM | `string` | `"splunk-vm"` | no |
| <a name="input_splunk_vm_pool_id"></a> [splunk\_vm\_pool\_id](#input\_splunk\_vm\_pool\_id) | Resource pool ID for the Splunk VM (optional) | `string` | `""` | no |
| <a name="input_ssh_public_key"></a> [ssh\_public\_key](#input\_ssh\_public\_key) | SSH public key content for Splunk VM access (optional) | `string` | `""` | no |
| <a name="input_template_id"></a> [template\_id](#input\_template\_id) | VM ID of the Packer-built Splunk Docker template to clone from (default: splunk-docker-template ID 9201) | `number` | `9201` | no |
| <a name="input_vm_ssh_private_key_path"></a> [vm\_ssh\_private\_key\_path](#input\_vm\_ssh\_private\_key\_path) | Path to the SSH private key for VM authentication (e.g., ~/.ssh/id\_rsa\_vm) | `string` | `"~/.ssh/id_rsa_vm"` | no |
| <a name="input_vm_ssh_public_key_path"></a> [vm\_ssh\_public\_key\_path](#input\_vm\_ssh\_public\_key\_path) | Path to the SSH public key for VM authentication (e.g., ~/.ssh/id\_rsa\_vm.pub) | `string` | `"~/.ssh/id_rsa_vm.pub"` | no |
| <a name="input_vms"></a> [vms](#input\_vms) | Map of VMs to create | <pre>map(object({<br/>    vm_id       = number<br/>    name        = string<br/>    description = optional(string)<br/>    tags        = optional(list(string), ["terraform"])<br/>    pool_id     = optional(string)<br/><br/>    # Node placement (optional). When unset, main.tf defaults to var.proxmox_node<br/>    # (the primary node). Set to "pve2"/"pve3" to place a VM on another cluster node.<br/>    node_name = optional(string)<br/><br/>    # Resource configuration<br/>    cpu_cores        = optional(number, 4)<br/>    cpu_type         = optional(string, "x86-64-v2-AES")<br/>    memory_dedicated = optional(number, 2048)<br/>    memory_floating  = optional(number)<br/><br/>    # Storage configuration<br/>    boot_disk = optional(object({<br/>      datastore_id = optional(string, "local-lvm")<br/>      interface    = optional(string, "scsi0")<br/>      size         = optional(number, 64)<br/>      file_format  = optional(string, "raw")<br/>      iothread     = optional(bool, true)<br/>      ssd          = optional(bool, false)<br/>      discard      = optional(string, "ignore")<br/>    }), {})<br/><br/>    additional_disks = optional(list(object({<br/>      datastore_id = optional(string, "local-zfs")<br/>      interface    = string<br/>      size         = number<br/>      file_format  = optional(string, "raw")<br/>      iothread     = optional(bool, true)<br/>      ssd          = optional(bool, false)<br/>      discard      = optional(string, "ignore")<br/>    })), [])<br/><br/>    # Network configuration<br/>    network_interfaces = optional(list(object({<br/>      bridge   = optional(string, "vmbr0")<br/>      model    = optional(string, "virtio")<br/>      vlan_id  = optional(number)<br/>      firewall = optional(bool, false)<br/>    })), [{ bridge = "vmbr0" }])<br/><br/>    # Initialization<br/>    ip_config = optional(object({<br/>      ipv4_address = optional(string)<br/>      ipv4_gateway = optional(string)<br/>    }), {})<br/><br/>    # Template cloning<br/>    cdrom_file_id = optional(string)<br/>    clone_template = optional(object({<br/>      template_id = number<br/>    }))<br/><br/>    # User account configuration<br/>    user_account = optional(object({<br/>      username = string<br/>      password = string<br/>      keys     = list(string)<br/>      }), {<br/>      username = "debian"<br/>      password = "" # Must be set in terraform.tfvars - do not use default passwords<br/>      keys     = []<br/>    })<br/><br/>    # Display<br/>    vga_type = optional(string, "std")<br/><br/>    # Features<br/>    agent_enabled = optional(bool, true)<br/>    protection    = optional(bool, false)<br/>    os_type       = optional(string, "l26")<br/><br/>    # Cloud-init configuration<br/>    cloud_init_user_data = optional(string)<br/>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_acme_accounts"></a> [acme\_accounts](#output\_acme\_accounts) | ACME accounts information |
| <a name="output_acme_certificates"></a> [acme\_certificates](#output\_acme\_certificates) | ACME certificates information |
| <a name="output_acme_dns_plugins"></a> [acme\_dns\_plugins](#output\_acme\_dns\_plugins) | DNS plugins for ACME validation |
| <a name="output_ansible_inventory"></a> [ansible\_inventory](#output\_ansible\_inventory) | Structured inventory for Ansible consumption - includes all VMs, containers, and Splunk infrastructure |
| <a name="output_cloud_init_file_id"></a> [cloud\_init\_file\_id](#output\_cloud\_init\_file\_id) | Cloud-init configuration file ID |
| <a name="output_container_network_info"></a> [container\_network\_info](#output\_container\_network\_info) | Container network interface information |
| <a name="output_containers"></a> [containers](#output\_containers) | Created containers information |
| <a name="output_pools"></a> [pools](#output\_pools) | Created resource pools |
| <a name="output_rack_servers"></a> [rack\_servers](#output\_rack\_servers) | Rack-server identity (names, BMC IPs/MACs, mgmt IPs, service tags, by-chassis grouping, ansible inventory shape). Real values come from terraform.sops.json; when var.rack\_servers defaults to an empty map, this output is an object whose collections are all empty. |
| <a name="output_storage_validated"></a> [storage\_validated](#output\_storage\_validated) | Confirms storage data sources are loaded |
| <a name="output_vm_network_info"></a> [vm\_network\_info](#output\_vm\_network\_info) | VM network interface information |
| <a name="output_vm_ssh_key_file"></a> [vm\_ssh\_key\_file](#output\_vm\_ssh\_key\_file) | Path to the SSH public key file |
| <a name="output_vm_ssh_public_key"></a> [vm\_ssh\_public\_key](#output\_vm\_ssh\_public\_key) | SSH public key used for VMs and containers |
| <a name="output_vms"></a> [vms](#output\_vms) | Created VMs information |
<!-- END OF PRE-COMMIT-TERRAFORM DOCS HOOK -->
