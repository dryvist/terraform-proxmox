terraform {
  required_version = ">= 1.10"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.106"
    }
    # Publishes the ansible_inventory output to S3 (inventory_publish.tf), using
    # the same ambient credential chain as the S3 state backend.
    aws = {
      source  = "hashicorp/aws"
      version = ">= 5.0"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    local = {
      source  = "hashicorp/local"
      version = "~> 2.5"
    }
    null = {
      source  = "hashicorp/null"
      version = "~> 3.2"
    }
  }
}

# Read VM SSH public key for cloud-init
data "local_file" "vm_ssh_public_key" {
  filename = pathexpand(var.vm_ssh_public_key_path)
}

# Local variables for cloud-init files
locals {
  ansible_cloud_init = file(var.ansible_cloud_init_file)
}

# Storage module - manages datastores and storage configuration
module "storage" {
  source = "./modules/storage"

  node_name   = var.proxmox_node
  datastores  = var.datastores
  environment = var.environment
}

# Pool module - manages resource pools
module "pools" {
  source = "./modules/proxmox-pool"

  pools       = var.pools
  environment = var.environment
}

# VM module - creates and manages virtual machines
module "vms" {
  source = "./modules/proxmox-vm"

  vms = {
    for k, v in var.vms : k => merge(v, {
      # Per-VM node placement; falls back to the primary node when unset.
      node_name      = coalesce(try(v.node_name, null), var.proxmox_node)
      cdrom_file_id  = v.cdrom_file_id != null ? "${var.datastore_iso}:iso/${var.proxmox_iso_debian}" : null
      clone_template = v.clone_template
      # DRY: IP/gateway derived from the VM's VLAN CIDR + vm_id (see locals.tf).
      ip_config = {
        ipv4_address = local.vm_ipv4[k]
        ipv4_gateway = local.vm_gateway[k]
      }
      # Tag every NIC onto the VM's service VLAN (802.1Q id from var.vlan_ids).
      network_interfaces = [
        for ni in v.network_interfaces : merge(ni, { vlan_id = lookup(var.vlan_ids, v.vlan, null) })
      ]
      user_account = {
        username = v.user_account.username
        password = v.user_account.password
        keys     = [trimspace(data.local_file.vm_ssh_public_key.content)]
      }
      # Override cloud-init for ansible VM to use external file
      cloud_init_user_data = k == "ansible" ? local.ansible_cloud_init : v.cloud_init_user_data
    })
  }

  environment       = var.environment
  default_datastore = var.datastore_default
  domain            = var.domain
  dns_servers       = local.dns_servers

  # SSH credentials for provisioners (BPG provider reads auth from PROXMOX_VE_* env vars)
  proxmox_ssh_username    = var.proxmox_ssh_username
  proxmox_ssh_private_key = var.proxmox_ssh_private_key

  depends_on = [module.pools]
}

# Container module - creates and manages containers (optional)
# DRY: IPs are derived from vm_id unless explicitly specified
module "containers" {
  count  = length(var.containers) > 0 ? 1 : 0
  source = "./modules/proxmox-container"

  containers = {
    for k, v in var.containers : k => merge(v, {
      # Per-LXC node placement; falls back to the primary node when unset.
      node_name        = coalesce(try(v.node_name, null), var.proxmox_node)
      template_file_id = "${var.datastore_iso}:vztmpl/${var.proxmox_ct_template_debian}"
      # DRY: IP/gateway derived from the LXC's VLAN CIDR + vm_id (see locals.tf).
      # local.container_ipv4 already honors a per-container static ipv4_address override.
      ip_config = {
        ipv4_address = local.container_ipv4[k]
        ipv4_gateway = local.container_gateway[k]
      }
      # Tag every NIC onto the LXC's service VLAN (802.1Q id from var.vlan_ids).
      # DHCP-first guests also get a deterministic MAC (local.container_mac) so
      # tofu-unifi can pin a stable DHCP reservation; static guests keep a null MAC
      # (provider auto-generates) so they are not replaced.
      network_interfaces = [
        for ni in v.network_interfaces : merge(ni, {
          vlan_id     = lookup(var.vlan_ids, v.vlan, null)
          mac_address = try(v.dhcp, false) ? local.container_mac[k] : null
        })
      ]
      # DRY: Always inject SSH key for Ansible access
      # Uses container's password/keys if specified, otherwise empty password with SSH key only
      user_account = {
        password = try(v.user_account.password, "")
        keys = concat(
          try(v.user_account.keys, []),
          [trimspace(data.local_file.vm_ssh_public_key.content)]
        )
      }
    })
  }

  environment       = var.environment
  default_datastore = var.datastore_default
  domain            = var.domain

  depends_on = [module.pools, module.storage]
}

# Splunk VM module - Docker-based Splunk Enterprise
# DRY: IP is derived from vm_id using local.splunk_derived_ip
# SECURITY: VM is network-isolated (no internet access, RFC1918 only)
module "splunk_vm" {
  source = "./modules/splunk-vm"

  vm_id          = var.splunk_vm_id
  name           = var.splunk_vm_name
  ip_address     = local.splunk_derived_ip # DRY: derived from splunk_vm_id
  gateway        = local.splunk_network_gateway
  node_name      = var.proxmox_node
  pool_id        = var.splunk_vm_pool_id
  template_id    = var.template_id
  datastore_id   = var.datastore_id
  bridge         = var.bridge
  vlan_id        = lookup(var.vlan_ids, "siem", null) # tag the NIC onto siem; DRY with container pattern
  ssh_public_key = var.ssh_public_key != "" ? var.ssh_public_key : trimspace(data.local_file.vm_ssh_public_key.content)
  boot_disk_size = var.splunk_boot_disk_size
  data_disk_size = var.splunk_data_disk_size
  cpu_cores      = var.splunk_cpu_cores
  memory         = var.splunk_memory
  domain         = var.domain
  dns_servers    = local.dns_servers

  depends_on = [module.pools]
}

# Firewall module - manages Proxmox firewall rules for Splunk and pipeline containers
# Configured to enforce network policies on Splunk resources and log pipeline
module "firewall" {
  source = "./modules/firewall"

  node_name = var.proxmox_node

  splunk_vm_ids = merge(
    {
      for k, v in var.vms : k => v.vm_id
      if contains(try(v.tags, []), "splunk")
    },
    {
      "splunk-vm" = module.splunk_vm.vm_id
    }
  )

  splunk_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(try(v.tags, []), "splunk")
  }

  # Pipeline containers: HAProxy (haproxy tag) and Cribl Edge (cribl + edge tags)
  # These receive syslog and NetFlow data from network devices
  pipeline_container_ids = local.pipeline_container_ids

  # Notification containers: Mailpit and ntfy (notifications tag)
  notification_container_ids = local.notification_container_ids

  # Vector database containers: Qdrant (vectordb tag)
  vectordb_container_ids = local.vectordb_container_ids

  # RAG engine containers: LlamaIndex (rag tag)
  rag_container_ids = local.rag_container_ids

  # APT caching proxy containers: apt-cacher-ng (apt-cache tag)
  apt_cacher_ng_container_ids = local.apt_cacher_ng_container_ids

  # Cribl Stream containers: cribl + stream tags (receives from Edge, routes to Splunk)
  cribl_stream_container_ids = local.cribl_stream_container_ids

  # Cribl Edge containers: cribl + edge tags — subset of pipeline_container_ids
  # that gets license-telemetry HTTPS egress
  cribl_edge_container_ids = local.cribl_edge_container_ids

  # MinIO object storage (minio tag) — DEPRECATED, kept for the migration soak.
  minio_container_ids = local.minio_container_ids

  # Object storage (object-storage tag) — RustFS, MinIO replacement.
  object_storage_container_ids = local.object_storage_container_ids

  # Infisical secrets-management containers (infisical tag)
  infisical_container_ids = local.infisical_container_ids

  # OpenBao secrets-management containers (openbao tag)
  openbao_container_ids = local.openbao_container_ids

  # iDRAC KVM LXC: tagged "idrac" (domistyle/idrac6-based viewers, Docker-in-LXC)
  idrac_kvm_container_ids = local.idrac_kvm_container_ids

  # Network-quality monitoring LXC: tagged "monitoring" (SmokePing + speedtest-exporter)
  monitoring_container_ids = local.monitoring_container_ids

  # Hermes Agent LXC: tagged "hermes-agent" (autonomous agent, broad HTTPS egress)
  hermes_agent_container_ids = local.hermes_agent_container_ids

  # Pipeline constants: single source of truth for service ports (DRY)
  pipeline_constants = local.pipeline_constants

  management_network = local.management_network
  splunk_network     = join(",", local.splunk_network_ips)
  # Derived from the Doppler-sourced VLAN CIDR map (locals.tf) — no committed ranges.
  internal_networks = local.internal_networks

  depends_on = [module.vms, module.containers, module.splunk_vm]
}

# ACME Certificate module - manages Let's Encrypt certificates via Route53
# NOTE: Route53 DNS records are managed separately in aws-infra/
# Ensure Route53 A record exists before running ACME certificate provisioning
module "acme_certificates" {
  count  = length(var.acme_accounts) > 0 ? 1 : 0
  source = "./modules/acme-certificate"

  acme_accounts     = var.acme_accounts
  dns_plugins       = var.dns_plugins
  acme_certificates = var.acme_certificates
  environment       = var.environment

  # SSH credentials for the null_resource cert-delivery provisioner.
  # The provisioner SSHes to the Proxmox node and uses `pct push` (LXC) or
  # `scp` (VM) to deliver the issued cert to each destination configured
  # in acme_certificates[*].destinations.
  proxmox_ssh_host        = var.proxmox_ssh_host
  proxmox_ssh_username    = var.proxmox_ssh_username
  proxmox_ssh_private_key = var.proxmox_ssh_private_key

  # Ensure the LXCs/VMs we deliver to exist before the cert lands.
  depends_on = [module.pools, module.containers, module.vms, module.splunk_vm]
}

# Rack-server cluster inventory. Declarative-only today (no resources
# created); real values come from SOPS-encrypted terraform.sops.json.
# Outputs are consumed by ansible-proxmox via terraform_remote_state to
# keep IP/MAC/service-tag identity DRY across repos.
module "rack_server_cluster" {
  source       = "./modules/rack-server-cluster"
  rack_servers = var.rack_servers
}

# Secure SSH key provisioning for Ansible VM
resource "null_resource" "ansible_ssh_key_setup" {
  count = contains(keys(var.vms), "ansible") ? 1 : 0

  depends_on = [module.vms]

  connection {
    type        = "ssh"
    user        = var.vms["ansible"].user_account.username
    private_key = file(pathexpand(var.vm_ssh_private_key_path))
    host        = cidrhost(var.vms["ansible"].ip_config.ipv4_address, 0)
    timeout     = "2m"
  }

  provisioner "file" {
    source      = pathexpand(var.vm_ssh_private_key_path)
    destination = "/home/${var.vms["ansible"].user_account.username}/.ssh/id_ed25519"
  }

  provisioner "remote-exec" {
    inline = [
      "chmod 600 /home/${var.vms["ansible"].user_account.username}/.ssh/id_ed25519",
      "chown ${var.vms["ansible"].user_account.username}:${var.vms["ansible"].user_account.username} /home/${var.vms["ansible"].user_account.username}/.ssh/id_ed25519"
    ]
  }

  triggers = {
    vm_id = module.vms.vm_ids["ansible"]
  }
}
