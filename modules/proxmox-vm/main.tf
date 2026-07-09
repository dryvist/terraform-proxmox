terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.111"
    }
  }
}

resource "proxmox_virtual_environment_vm" "vms" {
  for_each = var.vms

  vm_id       = each.value.vm_id
  node_name   = each.value.node_name
  name        = each.value.name
  description = each.value.description != null ? each.value.description : "TF VM ${each.value.name} - ${var.environment}"

  tags = concat(
    each.value.tags,
    [var.environment]
  )

  pool_id    = each.value.pool_id
  protection = each.value.protection

  # Startup configuration
  on_boot = try(each.value.on_boot, true)

  # Startup order: 256 - vm_id (higher IDs start first)
  # Delay: global startup_delay between each start
  startup {
    order    = 256 - each.value.vm_id
    up_delay = var.startup_delay
  }

  agent {
    enabled = each.value.agent_enabled
    timeout = "15m"
    trim    = true
    type    = "virtio"
  }

  # CPU configuration: "host" by default for single-node homelab stability
  # Exposes all host CPU features with zero emulation overhead
  cpu {
    cores      = each.value.cpu_cores
    type       = each.value.cpu_type
    hotplugged = 0
  }

  vga {
    type = each.value.vga_type
  }

  memory {
    dedicated = each.value.memory_dedicated
    floating  = each.value.memory_floating != null ? each.value.memory_floating : each.value.memory_dedicated
  }

  disk {
    datastore_id = coalesce(
      each.value.boot_disk.datastore_id,
      var.default_datastore
    )
    interface   = coalesce(each.value.boot_disk.interface, "scsi0")
    size        = coalesce(each.value.boot_disk.size, 32)
    file_format = coalesce(each.value.boot_disk.file_format, "raw")
    iothread    = coalesce(each.value.boot_disk.iothread, true)
    ssd         = coalesce(each.value.boot_disk.ssd, false)
    discard     = coalesce(each.value.boot_disk.discard, "ignore")
  }

  dynamic "disk" {
    for_each = each.value.additional_disks
    content {
      datastore_id = disk.value.datastore_id
      interface    = disk.value.interface
      size         = disk.value.size
      file_format  = coalesce(disk.value.file_format, "raw")
      iothread     = disk.value.iothread != null ? disk.value.iothread : true
      ssd          = disk.value.ssd != null ? disk.value.ssd : false
      discard      = coalesce(disk.value.discard, "ignore")
    }
  }

  dynamic "network_device" {
    for_each = each.value.network_interfaces
    content {
      bridge      = network_device.value.bridge
      model       = coalesce(network_device.value.model, "virtio")
      vlan_id     = network_device.value.vlan_id
      firewall    = network_device.value.firewall != null ? network_device.value.firewall : false
      mac_address = network_device.value.mac_address
    }
  }

  dynamic "cdrom" {
    for_each = each.value.cdrom_file_id != null ? [each.value.cdrom_file_id] : []
    content {
      file_id = cdrom.value
    }
  }

  dynamic "clone" {
    for_each = each.value.clone_template != null ? [each.value.clone_template] : []
    content {
      vm_id = clone.value.template_id
    }
  }

  initialization {
    datastore_id = var.default_datastore

    # DNS search domain + explicit resolvers for FQDN resolution. Without
    # servers, guests inherit the node's resolvers at provision time and
    # silently keep them forever — stale-resolver drift broke docker-host
    # DNS entirely (2026-06-10). Takes effect on cloud-init re-run/reboot.
    dynamic "dns" {
      for_each = var.domain != "" || length(var.dns_servers) > 0 ? [1] : []
      content {
        domain  = var.domain != "" ? var.domain : null
        servers = length(var.dns_servers) > 0 ? var.dns_servers : null
      }
    }

    dynamic "ip_config" {
      for_each = each.value.ip_config.ipv4_address != null || each.value.ip_config.ipv6_address != null ? [1] : []
      content {
        ipv4 {
          address = each.value.ip_config.ipv4_address
          gateway = each.value.ip_config.ipv4_gateway
        }

        dynamic "ipv6" {
          for_each = each.value.ip_config.ipv6_address != null ? [1] : []
          content {
            address = each.value.ip_config.ipv6_address
            gateway = each.value.ip_config.ipv6_gateway
          }
        }
      }
    }

    user_account {
      username = each.value.user_account.username
      password = each.value.user_account.password
      keys     = each.value.user_account.keys
    }
  }

  operating_system {
    type = each.value.os_type
  }

  # Timeout configurations - operation-level timeouts
  timeout_clone       = 1800 # 30 min - disk copy can be slow
  timeout_create      = 1800 # 30 min - cloud-init execution
  timeout_migrate     = 900  # 15 min - standard
  timeout_reboot      = 900  # 15 min - standard
  timeout_shutdown_vm = 900  # 15 min - standard
  timeout_start_vm    = 900  # 15 min - standard
  timeout_stop_vm     = 900  # 15 min - standard

  lifecycle {
    create_before_destroy = false
    ignore_changes = [
      initialization[0].user_account[0].password,
      # Cloud-init runs only at first boot; Ansible owns post-boot networking.
      # A VLAN change updates the qemu NIC live but also changes cloud-init
      # ip_config — ignore it so bpg does not rebuild the cloud-init drive
      # (which fails: the ide2 cloud-init disk is not removable on a running VM).
      initialization[0].ip_config,
      # Same failure mode for resolvers: a dns diff (e.g. changing the explicit
      # DNS-server derivation) makes bpg rebuild the non-removable ide2 drive on
      # every running VM — that is what broke the 2026-06-11 full apply. New VMs
      # pick up the dns block at first boot; existing VMs get resolvers via
      # Ansible post-boot.
      initialization[0].dns,
      # A cloned VM re-imported (e.g. after a manual VMID move) reports its
      # `clone` block as a new addition, which is ForceNew — terraform would
      # destroy+recreate a healthy VM. The clone source only matters at first
      # creation, so ignore it: imports and template changes never rebuild a VM.
      clone,
    ]
  }

}
