# Tests for splunk VM protection guarantees
#
# Verifies that the splunk VM module:
#   1. Plans successfully without splunk credentials (moved to Ansible/Doppler)
#   2. Produces the expected outputs used by downstream Ansible repos
#   3. Handles non-default splunk_vm_id correctly in derived IPs (siem VLAN)

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
  network_cidrs = {
    lan_main  = "192.0.2.0/22"
    lan_mgmt  = "192.0.2.0/24"
    dns       = "192.0.3.0/24"
    bmc       = "192.0.4.0/24"
    compute   = "192.0.5.0/24"
    siem      = "198.51.100.0/24"
    pipeline  = "198.51.101.0/24"
    data      = "198.51.102.0/24"
    ai        = "198.51.103.0/24"
    apps      = "203.0.113.0/24"
    media_svc = "203.0.114.0/24"
    homeauto  = "203.0.115.0/24"
    nonprod   = "203.0.116.0/24"
  }
  vlan_ids = {
    lan_main  = 1
    dns       = 2
    lan_mgmt  = 5
    bmc       = 8
    compute   = 10
    siem      = 20
    pipeline  = 25
    data      = 30
    ai        = 40
    apps      = 50
    media_svc = 55
    homeauto  = 60
    nonprod   = 90
  }
}

# --- Test: no Splunk credentials required at Terraform level ---
# splunk_password and splunk_hec_token are consumed by Ansible directly from
# Doppler. Terraform no longer needs them. This run verifies the plan succeeds
# without any credential variables.

run "plan_succeeds_without_splunk_credentials" {
  command = plan
}

# --- Test: ansible_inventory output contains splunk_vm at root level ---
# Downstream Ansible repos load this output and access terraform_data.splunk_vm.
# Any nesting change here breaks ansible-splunk inventory loading.

run "ansible_inventory_splunk_vm_at_root" {
  command = plan

  assert {
    condition     = output.ansible_inventory.splunk_vm != null
    error_message = "ansible_inventory must contain splunk_vm at root level (not nested under another key)"
  }
}

# --- Test: splunk IP is derived from vm_id on the siem VLAN, not hardcoded ---
# Changing splunk_vm_id must produce a different IP and be reflected in
# ansible_inventory. This prevents silent misconfiguration if the VM is
# renumbered.

run "splunk_ip_derived_from_vm_id" {
  command = plan

  variables {
    splunk_vm_id = 205
  }

  assert {
    condition     = local.splunk_derived_ip == "198.51.100.205/24"
    error_message = "splunk_derived_ip must track splunk_vm_id (205) on the siem VLAN, got ${local.splunk_derived_ip}"
  }
}
