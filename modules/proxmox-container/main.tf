terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.106"
    }
  }
}

resource "proxmox_virtual_environment_container" "containers" {
  for_each = var.containers

  vm_id       = each.value.vm_id
  node_name   = each.value.node_name
  description = each.value.description != null ? each.value.description : "TF CT ${each.value.hostname} - ${var.environment}"

  # Tags with environment
  tags = concat(
    each.value.tags,
    [var.environment]
  )

  # Pool assignment
  pool_id = each.value.pool_id

  # Unprivileged containers can set features without root@pam
  unprivileged = each.value.unprivileged

  # Protection
  protection = each.value.protection

  # Startup configuration
  start_on_boot = each.value.start_on_boot

  # Startup order: 256 - vm_id (higher IDs start first)
  # Delay: global startup_delay between each start
  startup {
    order    = 256 - each.value.vm_id
    up_delay = var.startup_delay
  }

  # Container initialization
  initialization {
    hostname = each.value.hostname

    # IP configuration
    dynamic "ip_config" {
      for_each = each.value.ip_config.ipv4_address != null ? [1] : []
      content {
        ipv4 {
          address = each.value.ip_config.ipv4_address
          gateway = each.value.ip_config.ipv4_gateway
        }
      }
    }

    # DNS search domain for FQDN resolution
    dynamic "dns" {
      for_each = var.domain != "" ? [1] : []
      content {
        domain = var.domain
      }
    }

    # User account configuration (only if keys are provided)
    dynamic "user_account" {
      for_each = length(lookup(each.value.user_account, "keys", [])) > 0 || lookup(each.value.user_account, "password", "") != "" ? [1] : []
      content {
        password = lookup(each.value.user_account, "password", "")
        keys     = lookup(each.value.user_account, "keys", [])
      }
    }
  }

  # CPU configuration
  cpu {
    cores = each.value.cpu_cores
  }

  # Memory configuration
  memory {
    dedicated = each.value.memory_dedicated
    swap      = each.value.memory_swap
  }

  # Root disk
  disk {
    datastore_id = coalesce(each.value.root_disk.datastore_id, var.default_datastore)
    size         = coalesce(each.value.root_disk.size, 8)
  }

  # Additional mount points
  # `size` is only set for managed-volume mounts. Host-directory bind-mounts
  # (volume = "/example-pool/media") must omit size — passing a size to a bind-mount
  # is rejected by the Proxmox API.
  dynamic "mount_point" {
    for_each = each.value.mount_points
    content {
      volume = mount_point.value.volume
      size   = mount_point.value.size
      path   = mount_point.value.path
    }
  }

  # Device passthrough (e.g. /dev/net/tun for WireGuard inside the LXC).
  dynamic "device_passthrough" {
    for_each = each.value.device_passthrough
    content {
      path       = device_passthrough.value.path
      mode       = device_passthrough.value.mode
      uid        = device_passthrough.value.uid
      gid        = device_passthrough.value.gid
      deny_write = device_passthrough.value.deny_write
    }
  }

  # Network interfaces
  dynamic "network_interface" {
    for_each = each.value.network_interfaces
    content {
      name     = network_interface.value.name
      bridge   = network_interface.value.bridge
      firewall = network_interface.value.firewall
      vlan_id  = network_interface.value.vlan_id
    }
  }

  # Operating system
  operating_system {
    template_file_id = each.value.template_file_id
    type             = each.value.os_type
  }

  # Container features (nesting for Docker, keyctl for overlay fs)
  # Only emit features block when any non-default value is set.
  # Creating privileged containers with a features block requires root@pam.
  dynamic "features" {
    for_each = (each.value.features.nesting || each.value.features.keyctl || each.value.features.fuse || length(each.value.features.mount) > 0) ? [1] : []
    content {
      nesting = each.value.features.nesting
      keyctl  = each.value.features.keyctl
      fuse    = each.value.features.fuse
      mount   = each.value.features.mount
    }
  }

  lifecycle {
    create_before_destroy = false
    ignore_changes = [
      # Ignore changes to immutable attributes after import
      # These can only be changed by replacing the container
      initialization[0].user_account[0].password,
      initialization[0].user_account[0].keys,
      operating_system[0].template_file_id,
      pool_id,
      # Ignore the runtime started status - this is a computed field that reflects
      # whether the container is currently running. We manage boot behavior via
      # start_on_boot, not runtime state.
      started,
      # Ignore features drift on existing containers — Proxmox returns HTTP 500
      # "no options specified" when an update sends no meaningful feature changes.
      # Features are only set at creation time (privileged containers require root@pam).
      features,
    ]
  }
}
