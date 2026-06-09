# Native publish of the Ansible inventory to the terragrunt S3 backend.
#
# `terragrunt apply` is the publish boundary: the aws_s3_object below uploads the
# inventory whenever its content changes — no shell script, no `aws` CLI. Any
# consumer (CI via OIDC, cloud agents, ansible) fetches this object with scoped
# read creds, with no checkout and no terraform toolchain.
#
# The AWS provider uses the same ambient credential chain as the S3 *state*
# backend (terragrunt.hcl) — no static keys here.

locals {
  # The inventory value, shared by output.ansible_inventory and the publish
  # resource below (a resource cannot reference an output, so this lives here).
  ansible_inventory = {
    # LXC Containers - using proxmox_pct_remote connection
    containers = {
      for k, v in(length(var.containers) > 0 ? module.containers[0].container_details : {}) : k => {
        vmid     = v.id
        hostname = var.containers[k].hostname
        ip       = split("/", local.container_ipv4[k])[0] # per-VLAN IP cidrhost(network_cidrs[vlan], vm_id); strip CIDR for Ansible
        node     = v.node_name
        # Connection settings for proxmox_pct_remote (community.proxmox)
        ansible_connection = "community.proxmox.proxmox_pct_remote"
        ansible_pct_vmid   = v.id
        tags               = v.tags
        pool_id            = v.pool_id
      }
    }
    # Regular VMs - using SSH connection
    # DRY: IP derived from vm_id (consistent with containers and cloud-init config)
    vms = {
      for k, v in module.vms.vm_details : k => {
        vmid               = v.id
        hostname           = v.name
        ip                 = split("/", local.vm_ipv4[k])[0]
        node               = v.node_name
        ansible_connection = "ssh"
        tags               = v.tags
        pool_id            = v.pool_id
      }
    }
    # Docker VMs - filtered subset of VMs with "docker" tag
    docker_vms = {
      for k, v in module.vms.vm_details : k => {
        vmid               = v.id
        hostname           = v.name
        ip                 = split("/", local.vm_ipv4[k])[0]
        node               = v.node_name
        ansible_connection = "ssh"
        tags               = v.tags
        pool_id            = v.pool_id
      } if contains(try(v.tags, []), "docker")
    }
    # Splunk VM - dedicated Docker host with SSH connection
    splunk_vm = {
      splunk = {
        vmid               = module.splunk_vm.vm_id
        hostname           = module.splunk_vm.name
        ip                 = module.splunk_vm.ip_address # CIDR already stripped in module output
        node               = var.proxmox_node
        ansible_connection = "ssh"
      }
    }
    # Pipeline constants - service and syslog port definitions
    constants = local.pipeline_constants
    # Traefik ingress route table - one {name, ip, port} per fronted service UI.
    # The ansible-proxmox-apps traefik + technitium_dns roles derive their routers
    # and DNS aliases from this single source instead of hand-listing hosts.
    ingress = local.ingress
    # Host-level NAS service config - consumed by ansible-proxmox to provision ZFS dataset + Samba
    host_services = var.host_services
    # Cluster node inventory (non-secret identity) - ansible-proxmox targets hosts and
    # skips nodes where commissioned = false.
    nodes = var.nodes
    # Per-node ZFS storage to provision (pools/datasets/quotas) - ansible-proxmox creates
    # and registers these; Terraform only references the datastore by id on disks.
    node_storage = var.node_storage
    # Domain for FQDN resolution (e.g., example.com)
    domain = var.domain
  }
}

# Same ambient credential chain as the S3 state backend (aws-vault locally, OIDC
# in CI). Region matches the state bucket in terragrunt.hcl.
provider "aws" {
  region = "us-east-2"
}

data "aws_caller_identity" "current" {}

# Publish point. The object updates only when the inventory content changes, and
# only when this resource is in scope — a `-target` apply that excludes it does
# not republish a partial inventory.
resource "aws_s3_object" "ansible_inventory" {
  bucket       = "terraform-proxmox-state-useast2-${data.aws_caller_identity.current.account_id}"
  key          = "terraform-proxmox/inventory/ansible_inventory.json"
  content      = jsonencode(local.ansible_inventory)
  content_type = "application/json"
}
