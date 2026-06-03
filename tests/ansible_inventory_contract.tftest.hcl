# Tests for ansible_inventory output contract
#
# Validates the structure of the ansible_inventory output that downstream
# Ansible repos (ansible-proxmox-apps, ansible-splunk) depend on.
# Any breaking change to this output structure will break downstream inventory loading.
#
# All runs use mock providers (no real infrastructure needed).

mock_provider "proxmox" {
  mock_data "proxmox_virtual_environment_datastores" {
    defaults = {
      datastores = [
        { id = "local", type = "dir", content_types = ["iso", "vztmpl", "backup"] },
        { id = "local-zfs", type = "zfspool", content_types = ["images", "rootdir"] },
      ]
    }
  }
}
mock_provider "tls" {}
mock_provider "random" {}
mock_provider "local" {}
mock_provider "null" {}

override_data {
  target = data.local_file.vm_ssh_public_key
  values = {
    content = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAITestKeyData test@test"
  }
}

override_module {
  target = module.storage
  outputs = {
    cloud_init_file_id   = null
    datastores_available = {}
    storage_validated    = true
  }
}

override_module {
  target = module.splunk_vm
  outputs = {
    vm_id       = 200
    name        = "splunk-aio"
    ip_address  = "192.168.20.200"
    mac_address = "BC:24:11:00:00:C8"
  }
}

override_module {
  target = module.firewall
  outputs = {
    cluster_firewall_enabled            = true
    vm_firewall_enabled                 = true
    container_firewall_enabled          = true
    pipeline_container_firewall_enabled = true
  }
}

override_module {
  target = module.acme_certificates
  outputs = {
    acme_accounts = {}
    dns_plugins   = {}
    certificates  = {}
  }
}

variables {
  # vlan_ids uses its variable default (single source of truth); network_cidrs is
  # derived from it as 192.168.<vlan_id>.0/24 — no duplicated VLAN/CIDR list.
  network_cidrs = { for name, id in var.vlan_ids : name => "192.168.${id}.0/24" }
}

# --- constants structure tests ---

run "ansible_inventory_constants_exists" {
  command = plan

  assert {
    condition     = can(output.ansible_inventory.constants)
    error_message = "ansible_inventory must contain 'constants' key"
  }
}

run "ansible_inventory_constants_service_ports_exists" {
  command = plan

  assert {
    condition     = can(output.ansible_inventory.constants.service_ports)
    error_message = "ansible_inventory.constants must contain 'service_ports' key"
  }
}

run "ansible_inventory_constants_syslog_ports_exists" {
  command = plan

  assert {
    condition     = can(output.ansible_inventory.constants.syslog_ports)
    error_message = "ansible_inventory.constants must contain 'syslog_ports' key"
  }
}

run "ansible_inventory_constants_netflow_ports_exists" {
  command = plan

  assert {
    condition     = can(output.ansible_inventory.constants.netflow_ports)
    error_message = "ansible_inventory.constants must contain 'netflow_ports' key"
  }
}

run "ansible_inventory_constants_notification_ports_exists" {
  command = plan

  assert {
    condition     = can(output.ansible_inventory.constants.notification_ports)
    error_message = "ansible_inventory.constants must contain 'notification_ports' key"
  }
}

run "ansible_inventory_constants_vector_db_ports_exists" {
  command = plan

  assert {
    condition     = can(output.ansible_inventory.constants.vector_db_ports)
    error_message = "ansible_inventory.constants must contain 'vector_db_ports' key"
  }
}

run "ansible_inventory_constants_media_ports_exists" {
  command = plan

  assert {
    condition     = can(output.ansible_inventory.constants.media_ports)
    error_message = "ansible_inventory.constants must contain 'media_ports' key for the media stack roles"
  }

  assert {
    condition     = output.ansible_inventory.constants.media_ports.qbittorrent_web == 8080
    error_message = "media_ports.qbittorrent_web must be 8080"
  }

  assert {
    condition     = output.ansible_inventory.constants.media_ports.prowlarr_web == 9696
    error_message = "media_ports.prowlarr_web must be 9696"
  }

  assert {
    condition     = output.ansible_inventory.constants.media_ports.jellyseerr_web == 5055
    error_message = "media_ports.jellyseerr_web must be 5055"
  }
}

# --- key port value tests ---

run "ansible_inventory_splunk_hec_port_value" {
  command = plan

  assert {
    condition     = output.ansible_inventory.constants.service_ports.splunk_hec == 8088
    error_message = "splunk_hec port must be 8088, got ${output.ansible_inventory.constants.service_ports.splunk_hec}"
  }
}

run "ansible_inventory_unifi_syslog_port_value" {
  command = plan

  assert {
    condition     = output.ansible_inventory.constants.syslog_ports.unifi == 1514
    error_message = "unifi syslog port must be 1514, got ${output.ansible_inventory.constants.syslog_ports.unifi}"
  }
}

run "ansible_inventory_unifi_netflow_port_value" {
  command = plan

  assert {
    condition     = output.ansible_inventory.constants.netflow_ports.unifi == 2055
    error_message = "unifi netflow port must be 2055, got ${output.ansible_inventory.constants.netflow_ports.unifi}"
  }
}

# --- top-level structure tests ---

run "ansible_inventory_splunk_vm_exists" {
  command = plan

  assert {
    condition     = can(output.ansible_inventory.splunk_vm)
    error_message = "ansible_inventory must contain 'splunk_vm' key at root level"
  }
}

run "ansible_inventory_containers_exists" {
  command = plan

  assert {
    condition     = can(output.ansible_inventory.containers)
    error_message = "ansible_inventory must contain 'containers' key at root level"
  }
}

run "ansible_inventory_docker_vms_exists" {
  command = plan

  assert {
    condition     = can(output.ansible_inventory.docker_vms)
    error_message = "ansible_inventory must contain 'docker_vms' key at root level"
  }
}

# --- per-container node placement (example pins a container to proxmox-2) ---

run "ansible_inventory_container_node_override_propagated" {
  command = plan

  variables {
    containers = {
      "download-vpn" = {
        vm_id      = 210
        hostname   = "download-vpn"
        vlan       = "media_svc"
        node_name  = "proxmox-2"
        pool_id    = "media"
        protection = true # has mount_points -> satisfies storage_guest_protection check
        tags       = ["terraform", "container", "media", "vpn"]
        device_passthrough = [
          { path = "/dev/net/tun", mode = "0666" }
        ]
        mount_points = [
          { volume = "/example-pool/downloads", path = "/mnt/downloads" }
        ]
      }
      "lan-default-node" = {
        vm_id    = 211
        hostname = "lan-default-node"
        vlan     = "apps"
      }
    }
  }

  # node_name set on the container is honored end-to-end in the inventory output.
  assert {
    condition     = output.ansible_inventory.containers["download-vpn"].node == "proxmox-2"
    error_message = "container node_name override must propagate to ansible_inventory.containers[*].node"
  }

  # Containers without node_name fall back to the cluster-wide proxmox_node.
  assert {
    condition     = output.ansible_inventory.containers["lan-default-node"].node == var.proxmox_node
    error_message = "container without node_name must default to var.proxmox_node"
  }
}

# --- ingress: traefik reverse-proxy container contract ---
#
# The ansible-proxmox-apps `traefik` role auto-generates its routers/services
# from this inventory: it needs the ingress LXC to surface with a derived IP,
# its node, and the "ingress" tag so the role can find it. Pin that contract.

run "ansible_inventory_traefik_ingress_container" {
  command = plan

  variables {
    containers = {
      "traefik" = {
        vm_id     = 215
        hostname  = "traefik"
        vlan      = "media_svc"
        node_name = "proxmox-2"
        pool_id   = "media"
        tags      = ["terraform", "container", "ingress", "traefik"]
      }
    }
  }

  # IP derives from the media_svc CIDR (192.168.55.0/24) + vm_id last octet.
  assert {
    condition     = output.ansible_inventory.containers["traefik"].ip == "192.168.55.215"
    error_message = "traefik ingress IP must derive to 192.168.55.215 (cidrhost(media_svc, 215))"
  }

  assert {
    condition     = output.ansible_inventory.containers["traefik"].node == "proxmox-2"
    error_message = "traefik must land on its declared media node"
  }

  assert {
    condition     = contains(output.ansible_inventory.containers["traefik"].tags, "ingress")
    error_message = "traefik must carry the 'ingress' tag the traefik role selects on"
  }
}

# --- host_services structure tests ---

run "ansible_inventory_host_services_exists" {
  command = plan

  assert {
    condition     = can(output.ansible_inventory.host_services)
    error_message = "ansible_inventory must contain 'host_services' key at root level"
  }
}

run "ansible_inventory_host_services_default_no_nas" {
  command = plan

  assert {
    condition     = output.ansible_inventory.host_services.nas == null
    error_message = "ansible_inventory.host_services.nas must be null when no host_services var is set"
  }
}

# --- domain propagation tests ---

run "ansible_inventory_domain_field_exists" {
  command = plan

  assert {
    condition     = can(output.ansible_inventory.domain)
    error_message = "ansible_inventory must contain 'domain' key for downstream FQDN configuration"
  }
}

run "ansible_inventory_domain_default_empty" {
  command = plan

  assert {
    condition     = output.ansible_inventory.domain == ""
    error_message = "ansible_inventory.domain should be empty string when var.domain is not set"
  }
}

run "ansible_inventory_domain_propagated" {
  command = plan

  variables {
    domain = "example.com"
  }

  assert {
    condition     = output.ansible_inventory.domain == "example.com"
    error_message = "ansible_inventory.domain must propagate var.domain, got '${output.ansible_inventory.domain}'"
  }
}

run "ansible_inventory_host_services_nas_propagated" {
  command = plan

  variables {
    host_services = {
      nas = {
        zfs_dataset    = "rpool/data/nas"
        zfs_quota      = "1T"
        mount_point    = "/mnt/nas"
        smb_share_name = "nas"
        directories    = ["huggingface/hub", "ollama/models", "media", "backups"]
        group_name     = "nas"
        managed_users = [
          {
            name                = "homeassistant"
            unix_groups         = ["nas"]
            shell               = "/usr/sbin/nologin"
            create_home         = false
            password_secret_env = "NAS_HOMEASSISTANT_SMB_PASSWORD"
          }
        ]
        shares = [
          {
            name           = "nas"
            path           = "/mnt/nas"
            valid_users    = "@nas"
            browsable      = true
            read_only      = false
            force_group    = "nas"
            create_mask    = "0664"
            directory_mask = "0775"
            comment        = "Primary NAS root share"
          },
          {
            name           = "ha-backups"
            path           = "/mnt/nas/backups"
            valid_users    = "homeassistant"
            browsable      = true
            read_only      = false
            force_group    = "nas"
            create_mask    = "0664"
            directory_mask = "0775"
            comment        = "Home Assistant backup storage"
          }
        ]
      }
    }
  }

  assert {
    condition     = output.ansible_inventory.host_services.nas.zfs_dataset == "rpool/data/nas"
    error_message = "host_services.nas.zfs_dataset must propagate to ansible_inventory output"
  }

  assert {
    condition     = output.ansible_inventory.host_services.nas.mount_point == "/mnt/nas"
    error_message = "host_services.nas.mount_point must propagate to ansible_inventory output"
  }

  assert {
    condition     = output.ansible_inventory.host_services.nas.group_name == "nas"
    error_message = "host_services.nas.group_name must propagate to ansible_inventory output"
  }

  assert {
    condition     = output.ansible_inventory.host_services.nas.managed_users[0].password_secret_env == "NAS_HOMEASSISTANT_SMB_PASSWORD"
    error_message = "host_services.nas.managed_users must propagate to ansible_inventory output"
  }

  assert {
    condition     = output.ansible_inventory.host_services.nas.shares[1].name == "ha-backups"
    error_message = "host_services.nas.shares must propagate to ansible_inventory output"
  }
}

# --- multi-node: nodes + node_storage contract ---

run "ansible_inventory_nodes_exists" {
  command = plan

  assert {
    condition     = can(output.ansible_inventory.nodes)
    error_message = "ansible_inventory must contain 'nodes' key for downstream host targeting"
  }
}

run "ansible_inventory_node_storage_exists" {
  command = plan

  assert {
    condition     = can(output.ansible_inventory.node_storage)
    error_message = "ansible_inventory must contain 'node_storage' key for ansible-proxmox ZFS provisioning"
  }
}

run "ansible_inventory_nodes_commissioned_propagated" {
  command = plan

  variables {
    nodes = {
      proxmox-1 = { role = "node-1" }
      proxmox-3 = { role = "node-3", commissioned = false }
    }
  }

  assert {
    condition     = output.ansible_inventory.nodes["proxmox-1"].commissioned == true
    error_message = "nodes commissioned must default to true"
  }

  assert {
    condition     = output.ansible_inventory.nodes["proxmox-3"].commissioned == false
    error_message = "nodes commissioned=false must propagate (gates apply on un-commissioned nodes)"
  }
}

run "ansible_inventory_node_storage_propagated" {
  command = plan

  variables {
    node_storage = {
      proxmox-2 = {
        pools = {
          example-pool = {
            raid     = "raidz1"
            datasets = { backups = { quota = "1T" } }
          }
        }
      }
    }
  }

  assert {
    condition     = output.ansible_inventory.node_storage["proxmox-2"].pools["example-pool"].datasets["backups"].quota == "1T"
    error_message = "node_storage pool/dataset/quota must propagate to ansible_inventory for ansible-proxmox"
  }

  assert {
    condition     = output.ansible_inventory.node_storage["proxmox-2"].pools["example-pool"].register == true
    error_message = "node_storage pool register must default to true"
  }

  assert {
    condition     = output.ansible_inventory.node_storage["proxmox-2"].pools["example-pool"].protected == true
    error_message = "node_storage pool protected must default to true (storage-safety)"
  }
}

# --- multi-node: per-resource node placement ---

run "vm_node_placement_defaults_to_primary" {
  command = plan

  variables {
    vms = {
      placement = {
        vm_id = 210
        name  = "placement-default"
        vlan  = "apps"
      }
    }
  }

  assert {
    condition     = output.ansible_inventory.vms["placement"].node == "proxmox-1"
    error_message = "a VM without node_name must default to the primary node (var.proxmox_node)"
  }
}

run "vm_node_placement_override" {
  command = plan

  variables {
    vms = {
      placement = {
        vm_id     = 211
        name      = "placement-proxmox-2"
        vlan      = "apps"
        node_name = "proxmox-2"
      }
    }
  }

  assert {
    condition     = output.ansible_inventory.vms["placement"].node == "proxmox-2"
    error_message = "a VM with node_name set must be placed on that node"
  }
}
