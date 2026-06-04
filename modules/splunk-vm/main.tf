terraform {
  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "~> 0.106"
    }
  }
}

# =============================================================================
# CRITICAL — SPLUNK INDEXER DATA IS NOT BACKED UP
# =============================================================================
# The Splunk indexer data on this VM's data disks (virtio0 = 25G, virtio1 =
# 200G) is NOT backed up anywhere. Treat EVERY operation on this VM as
# potentially data-destructive:
#   - NEVER destroy/recreate the VM. `prevent_destroy = true` is set below for
#     exactly this reason — do not remove it.
#   - NEVER touch the data disks (virtio0/virtio1). Only the 4MB cloud-init
#     drive is safe to modify.
#   - AVOID `cloud-init clean` + reboot here. It re-runs cloud-init; it is only
#     data-safe because the cloud-init user-data has no disk_setup/fs_setup/
#     growpart today — re-verify that before ever relying on it.
#   - The guest network/OS config is Ansible-owned post-boot (cloud-init is
#     first-boot only); tofu manages the NIC VLAN tag, not the guest IP, which
#     is why initialization[0].ip_config is in ignore_changes below.
# ACTION NEEDED: stand up a real backup job (PBS / zfs-send) for virtio0+virtio1
# BEFORE the next risky change. The disks carry backup=1 but no backup runs yet.
# =============================================================================

# Render cloud-init configuration with secrets and config files
# Firewall is managed by Proxmox firewall module, not guest-level iptables
locals {
  cloud_init_config = templatefile("${path.module}/templates/cloud-init.yml.tpl", {
    hostname = var.name
    domain   = var.domain
  })
}

resource "proxmox_virtual_environment_vm" "splunk_vm" {
  vm_id       = var.vm_id
  node_name   = var.node_name
  name        = var.name
  description = "Splunk Enterprise Docker - ${var.name}"

  tags = [
    "terraform",
    "splunk",
    "docker",
    "enterprise"
  ]

  pool_id    = var.pool_id
  protection = false

  # Startup configuration
  on_boot = true

  agent {
    enabled = true
    timeout = "15m"
    trim    = true
    type    = "virtio"
  }

  # CPU configuration: "host" exposes all host CPU features directly
  # to the VM with zero emulation overhead
  cpu {
    cores      = var.cpu_cores
    type       = "host"
    hotplugged = 0
  }

  memory {
    dedicated = var.memory
    floating  = var.memory
  }

  # Boot disk: virtio0 interface uses VirtIO SCSI controller
  disk {
    datastore_id = var.datastore_id
    interface    = "virtio0"
    size         = var.boot_disk_size
    file_format  = "raw"
    iothread     = true
    ssd          = false
    discard      = "ignore"
  }

  # Data disk for Splunk index storage (mounted at /opt/splunk)
  dynamic "disk" {
    for_each = var.data_disk_size > 0 ? [1] : []
    content {
      datastore_id = var.datastore_id
      interface    = "virtio1"
      size         = var.data_disk_size
      file_format  = "raw"
      iothread     = true
      ssd          = false
      discard      = "ignore"
    }
  }

  network_device {
    bridge   = var.bridge
    model    = "virtio"
    firewall = true
  }

  clone {
    vm_id = var.template_id
  }

  initialization {
    datastore_id = var.datastore_id

    ip_config {
      ipv4 {
        address = var.ip_address
        gateway = var.gateway
      }
    }

    user_account {
      username = "debian"
      keys     = var.ssh_public_key != "" ? [var.ssh_public_key] : []
    }

    # Cloud-init user data with Splunk Docker configuration
    user_data_file_id = proxmox_virtual_environment_file.cloud_init.id
  }

  operating_system {
    type = "l26"
  }

  # Timeout configurations - 30 min for clone/create, 15 min standard for others
  timeout_clone       = 1800 # 30 min - disk copy can be slow
  timeout_create      = 1800 # 30 min - cloud-init execution
  timeout_migrate     = 900  # 15 min - standard
  timeout_reboot      = 900  # 15 min - standard
  timeout_shutdown_vm = 900  # 15 min - standard
  timeout_start_vm    = 900  # 15 min - standard
  timeout_stop_vm     = 900  # 15 min - standard

  lifecycle {
    prevent_destroy       = true
    create_before_destroy = false
    ignore_changes = [
      # Ignore changes to the source template after initial clone.
      # The VM is managed by Ansible post-creation; Packer rebuilds of the base
      # template should not trigger VM replacement.
      clone,
      # Cloud-init runs only at first boot; Ansible handles all post-boot config.
      # Ignore changes to user_data_file_id so cloud-init template updates
      # don't force VM replacement on an already-running VM.
      initialization[0].user_data_file_id,
      # Same reason: a VLAN change alters cloud-init ip_config, which would make
      # bpg rebuild the cloud-init drive — and that fails on the non-removable
      # ide2 disk. Ansible owns post-boot networking, so ignore the drift.
      initialization[0].ip_config,
    ]
  }
}

# Cloud-init configuration file stored in Proxmox
resource "proxmox_virtual_environment_file" "cloud_init" {
  content_type = "snippets"
  datastore_id = var.snippets_datastore_id
  node_name    = var.node_name

  source_raw {
    data      = local.cloud_init_config
    file_name = "${var.name}-cloud-init.yml"
  }
}
