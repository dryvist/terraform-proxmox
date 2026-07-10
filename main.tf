terraform {
  required_version = ">= 1.10"
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111"
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
      # NIC onto the VM's service VLAN; DHCP-first VMs get a deterministic MAC
      # (local.vm_mac) for a stable reservation, same pattern as containers.
      network_interfaces = [
        for ni in v.network_interfaces : merge(ni, {
          vlan_id     = lookup(var.vlan_ids, v.vlan, null)
          mac_address = try(v.dhcp, false) ? local.vm_mac[k] : null
        })
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

# Firewall module - rules for Splunk and containers
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

  # Object storage (object-storage tag) — RustFS.
  s3_container_ids = local.s3_container_ids

  # OpenBao secrets-management containers (openbao tag)
  openbao_container_ids = local.openbao_container_ids

  # Postgres + Nautobot + Vikunja containers — 5432 / 8080 / 3456 from internal
  postgres_container_ids = local.postgres_container_ids
  nautobot_container_ids = local.nautobot_container_ids
  vikunja_container_ids  = local.vikunja_container_ids

  # Ingress (Traefik HA) containers (ingress tag) — define-disabled guest firewall
  # that pre-allows keepalived VRRP + 80/443 so a later enforcement flip is safe.
  ingress_container_ids = local.ingress_container_ids

  # iDRAC KVM LXC: tagged "idrac" (domistyle/idrac6-based viewers, Docker-in-LXC)
  idrac_kvm_container_ids = local.idrac_kvm_container_ids

  # Network-quality monitoring LXC: tagged "monitoring" (SmokePing + speedtest-exporter)
  monitoring_container_ids = local.monitoring_container_ids

  # LAN-only media LXCs: media tag minus the VPN-locked downloader (its in-guest
  # killswitch is the boundary; see locals-media.tf)
  media_container_ids = local.media_container_ids

  # Hermes Agent LXC: tagged "hermes-agent" (autonomous agent, broad HTTPS egress)
  hermes_agent_container_ids = local.hermes_agent_container_ids

  # AI orchestration LXCs: tagged "ai-orchestration" (n8n, Dify, LangFlow, LangGraph, agent-exec)
  ai_orchestration_container_ids = local.ai_orchestration_container_ids

  # Langfuse LLM-observability LXC: tagged "langfuse"
  langfuse_container_ids = local.langfuse_container_ids

  # LLM fabric LXCs: llm-router (LiteLLM proxy) + llm-fast (GPU llama-swap server)
  llm_router_container_ids = local.llm_router_container_ids
  llm_fast_container_ids   = local.llm_fast_container_ids

  # agentgateway MCP/LLM/A2A data-plane proxy (agentgateway tag).
  agentgateway_container_ids = local.agentgateway_container_ids

  # Honeypots (honeypot/notify/tpot tags); filters in locals-honeypot.tf.
  honeypot_container_ids        = local.honeypot_container_ids
  honeypot_notify_container_ids = local.honeypot_notify_container_ids
  tpot_vm_ids                   = local.tpot_vm_ids


  # Pipeline constants: single source of truth for service ports (DRY)
  pipeline_constants = local.pipeline_constants

  management_network = local.management_network
  splunk_network     = join(",", local.splunk_network_ips)
  # Derived from the Doppler-sourced VLAN CIDR map (locals.tf) — no committed ranges.
  internal_networks = local.internal_networks
  # AI VLAN CIDR — least-privilege source scope for the Cribl Edge OTLP ingest.
  ai_network = local.ai_network
  # Per-VLAN CIDR map for zero-trust rule source scoping (staged disabled).
  network_cidrs = nonsensitive(var.network_cidrs)

  depends_on = [module.vms, module.containers, module.splunk_vm]
}

# ACME Certificate module - Let's Encrypt via Route53
module "acme_certificates" {
  count  = length(var.acme_accounts) > 0 ? 1 : 0
  source = "./modules/acme-certificate"

  acme_accounts     = var.acme_accounts
  dns_plugins       = var.dns_plugins
  acme_certificates = var.acme_certificates
  environment       = var.environment

  # SSH credentials for cert-delivery provisioner.
  proxmox_ssh_host        = var.proxmox_ssh_host
  proxmox_ssh_username    = var.proxmox_ssh_username
  proxmox_ssh_private_key = var.proxmox_ssh_private_key

  # Ensure the LXCs/VMs we deliver to exist before the cert lands.
  depends_on = [module.pools, module.containers, module.vms, module.splunk_vm]
}

# Rack-server cluster inventory (SOPS-encrypted values).
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
