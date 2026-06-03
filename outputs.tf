# SSH key outputs
output "vm_ssh_public_key" {
  description = "SSH public key used for VMs and containers"
  value       = trimspace(data.local_file.vm_ssh_public_key.content)
}

output "vm_ssh_key_file" {
  description = "Path to the SSH public key file"
  value       = data.local_file.vm_ssh_public_key.filename
}

# Pool outputs
output "pools" {
  description = "Created resource pools"
  value       = module.pools.pools
}

# Storage outputs
output "cloud_init_file_id" {
  description = "Cloud-init configuration file ID"
  value       = module.storage.cloud_init_file_id
}

output "storage_validated" {
  description = "Confirms storage data sources are loaded"
  value       = module.storage.storage_validated
}

# VM outputs
output "vms" {
  description = "Created VMs information"
  value       = module.vms.vm_details
}

output "vm_network_info" {
  description = "VM network interface information"
  value       = module.vms.vm_network_interfaces
}

# Container outputs (when enabled)
output "containers" {
  description = "Created containers information"
  value       = length(var.containers) > 0 ? module.containers[0].container_details : {}
}

output "container_network_info" {
  description = "Container network interface information"
  value       = length(var.containers) > 0 ? module.containers[0].container_network_interfaces : {}
}

# NOTE: Route53 DNS outputs are now in aws-infra/outputs.tf

# ACME Certificate outputs
output "acme_certificates" {
  description = "ACME certificates information"
  value       = try(module.acme_certificates[0].certificates, {})
}

output "acme_accounts" {
  description = "ACME accounts information"
  value       = try(module.acme_certificates[0].acme_accounts, {})
}

output "acme_dns_plugins" {
  description = "DNS plugins for ACME validation"
  value       = try(module.acme_certificates[0].dns_plugins, {})
  sensitive   = true
}

# Ansible Inventory Output - Single Source of Truth
# This output structures all infrastructure data for dynamic Ansible inventory
# generation, eliminating hardcoded VM IDs and IPs from Ansible configuration.
output "ansible_inventory" {
  description = "Structured inventory for Ansible consumption - includes all VMs, containers, and Splunk infrastructure"
  value = {
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

# Rack-server cluster inventory - consumed by ansible-proxmox via terraform_remote_state.
# Sensitive: BMC IPs/MACs and host mgmt IPs are operational secrets. ansible-proxmox
# must use nonsensitive() when constructing inventory strings from these.
output "rack_servers" {
  description = "Rack-server identity (names, BMC IPs/MACs, mgmt IPs, service tags, by-chassis grouping, ansible inventory shape). Real values come from terraform.sops.json; when var.rack_servers defaults to an empty map, this output is an object whose collections are all empty."
  value = {
    names             = module.rack_server_cluster.node_names
    bmc_ips           = module.rack_server_cluster.bmc_ips
    bmc_macs          = module.rack_server_cluster.bmc_macs
    mgmt_ips          = module.rack_server_cluster.mgmt_ips
    service_tags      = module.rack_server_cluster.service_tags
    by_chassis        = module.rack_server_cluster.by_chassis
    ansible_inventory = module.rack_server_cluster.ansible_inventory
  }
  sensitive = true
}
