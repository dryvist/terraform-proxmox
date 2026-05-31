packer {
  required_plugins {
    proxmox = {
      version = ">= 1.1.0"
      source  = "github.com/hashicorp/proxmox"
    }
  }
}

source "proxmox-clone" "splunk" {
  proxmox_url              = local.proxmox_url
  username                 = var.PKR_PVE_USERNAME
  token                    = var.PROXMOX_TOKEN
  node                     = var.PROXMOX_VE_NODE
  insecure_skip_tls_verify = var.PROXMOX_VE_INSECURE == "true"

  # DEPRECATED: Use splunk-docker.pkr.hcl instead (Docker-based at ID 9200)
  # This native installation template is kept for reference but not actively used
  clone_vm      = "debian-12-base"
  vm_id         = 9199
  vm_name       = "splunk-native-template-deprecated"
  template_name = "splunk-native-template-deprecated"
  full_clone    = true

  # CRITICAL: CPU and hardware configuration to prevent system freezes
  # These settings override Packer's defaults which can cause system instability:
  # - cpu_type: "host" exposes all host CPU features with native performance
  #   instead of kvm64 generic emulation which causes TSC clock instability
  # - scsi_controller: virtio-scsi-pci is modern/fast vs. LSI Logic (default)
  #   which is ancient (~2003) and adds high CPU overhead during disk I/O
  # - os: "l26" optimizes for Linux 2.6+ kernel instead of "other"
  # See: https://github.com/hashicorp/packer-plugin-proxmox/issues/307
  cpu_type        = "host"
  scsi_controller = "virtio-scsi-pci"
  os              = "l26"

  # SSH configuration: Use the VM-specific SSH key (id_ed25519) that matches
  # the public key configured in the base template's cloud-init.
  # Packer automatically detects the VM's IP address from Proxmox API.
  ssh_username         = "debian"
  ssh_timeout          = "300s"
  ssh_agent_auth       = false
  ssh_private_key_file = pathexpand("~/.ssh/id_ed25519")

  cloud_init              = true
  cloud_init_storage_pool = "local-zfs"

  network_adapters {
    bridge = "vmbr0"
    model  = "virtio"
  }
  ipconfig {
    ip = "dhcp"
  }

  cores  = 4
  memory = 4096
}

build {
  sources = ["source.proxmox-clone.splunk"]

  # Splunk installation provisioner
  provisioner "shell" {
    script = "${path.root}/scripts/install-splunk.sh"
    environment_vars = [
      "SPLUNK_VERSION=${var.SPLUNK_VERSION}",
      "SPLUNK_BUILD=${var.SPLUNK_BUILD}",
      "SPLUNK_ARCHITECTURE=${var.SPLUNK_ARCHITECTURE}",
      "SPLUNK_DOWNLOAD_SHA512=${var.SPLUNK_DOWNLOAD_SHA512}",
      "SPLUNK_HOME=${var.SPLUNK_HOME}",
      "SPLUNK_USER=${var.SPLUNK_USER}",
      "SPLUNK_GROUP=${var.SPLUNK_GROUP}",
      "SPLUNK_PASSWORD=${var.SPLUNK_PASSWORD}"
    ]
  }

  # System tuning: Configure systemd service limits and restart policy
  # Consolidates ulimits and restart configuration per review feedback
  provisioner "shell" {
    script = "${path.root}/scripts/configure-systemd.sh"
    environment_vars = [
      "SPLUNK_USER=${var.SPLUNK_USER}",
      "SPLUNK_GROUP=${var.SPLUNK_GROUP}"
    ]
  }

  # Validation: Ensure all files in SPLUNK_HOME are owned by splunk:splunk
  provisioner "shell" {
    script = "${path.root}/scripts/validate-ownership.sh"
    environment_vars = [
      "SPLUNK_HOME=${var.SPLUNK_HOME}",
      "SPLUNK_USER=${var.SPLUNK_USER}",
      "SPLUNK_GROUP=${var.SPLUNK_GROUP}"
    ]
  }
}
