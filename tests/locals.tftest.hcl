# Tests for locals.tf - per-VLAN IP derivation and pipeline constants
#
# All runs use mock providers (no real infrastructure needed).
# command = plan is sufficient since locals are evaluated at plan time.
#
# network_cidrs fixture uses the homelab VLAN layout from
# int_homelab network/architecture.md (test data, not committed secrets).
# Every guest IP is cidrhost(network_cidrs[vlan], vm_id); gateway is the .1.

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

# Override data sources and modules that require real provider connections
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
    name        = "splunk-vm"
    ip_address  = null
    mac_address = null
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
    lan_main  = "198.18.0.0/22"
    lan_mgmt  = "198.18.1.0/24"
    dns       = "198.18.2.0/24"
    bmc       = "198.18.8.0/24"
    compute   = "198.18.10.0/24"
    siem      = "198.18.20.0/24"
    pipeline  = "198.18.25.0/24"
    data      = "198.18.30.0/24"
    ai        = "198.18.40.0/24"
    apps      = "198.18.50.0/24"
    media_svc = "198.18.55.0/24"
    homeauto  = "198.18.60.0/24"
    nonprod   = "198.18.90.0/24"
  }
  splunk_vm_id = 200
}

# --- per-guest IP derivation tests ---

run "container_ipv4_uses_vlan_cidr" {
  command = plan

  variables {
    containers = {
      "technitium-dns" = { vm_id = 103, hostname = "technitium-dns", vlan = "dns" }
      "haproxy"        = { vm_id = 175, hostname = "haproxy", vlan = "pipeline" }
    }
  }

  assert {
    condition     = local.container_ipv4["technitium-dns"] == "198.18.2.103/24"
    error_message = "dns-VLAN container 103 should be 198.18.2.103/24, got ${local.container_ipv4["technitium-dns"]}"
  }

  assert {
    condition     = local.container_gateway["technitium-dns"] == "198.18.2.1"
    error_message = "dns-VLAN gateway should be 198.18.2.1, got ${local.container_gateway["technitium-dns"]}"
  }

  assert {
    condition     = local.container_ipv4["haproxy"] == "198.18.25.175/24"
    error_message = "pipeline-VLAN container 175 should be 198.18.25.175/24, got ${local.container_ipv4["haproxy"]}"
  }
}

run "vm_ipv4_uses_vlan_cidr" {
  command = plan

  variables {
    vms = {
      "docker-host" = { vm_id = 250, name = "docker", vlan = "nonprod" }
      "idrac-kvm"   = { vm_id = 251, name = "idrac-kvm", vlan = "apps" }
    }
  }

  assert {
    condition     = local.vm_ipv4["docker-host"] == "198.18.90.250/24"
    error_message = "nonprod-VLAN VM 250 should be 198.18.90.250/24, got ${local.vm_ipv4["docker-host"]}"
  }

  assert {
    condition     = local.vm_gateway["docker-host"] == "198.18.90.1"
    error_message = "nonprod-VLAN gateway should be 198.18.90.1, got ${local.vm_gateway["docker-host"]}"
  }

  assert {
    condition     = local.vm_ipv4["idrac-kvm"] == "198.18.50.251/24"
    error_message = "apps-VLAN VM 251 should be 198.18.50.251/24, got ${local.vm_ipv4["idrac-kvm"]}"
  }
}

# --- splunk derivation tests (siem VLAN) ---

run "splunk_derived_ip_uses_siem_vlan" {
  command = plan

  assert {
    condition     = local.splunk_derived_ip == "198.18.20.200/24"
    error_message = "splunk_derived_ip should be siem-VLAN 198.18.20.200/24, got ${local.splunk_derived_ip}"
  }

  assert {
    condition     = local.splunk_network_gateway == "198.18.20.1"
    error_message = "splunk_network_gateway should be siem-VLAN .1 (198.18.20.1), got ${local.splunk_network_gateway}"
  }
}

run "splunk_derived_ip_different_id" {
  command = plan

  variables {
    splunk_vm_id = 205
  }

  assert {
    condition     = local.splunk_derived_ip == "198.18.20.205/24"
    error_message = "splunk_derived_ip should track splunk_vm_id (205), got ${local.splunk_derived_ip}"
  }
}

# --- management_network test (compute VLAN CIDR) ---

run "management_network_is_compute_cidr" {
  command = plan

  assert {
    condition     = local.management_network == "198.18.10.0/24"
    error_message = "management_network should be the compute VLAN CIDR 198.18.10.0/24, got ${local.management_network}"
  }
}

# --- splunk_network_ips tests (siem VLAN, host-form) ---

run "splunk_network_ips_default_no_containers" {
  command = plan

  variables {
    containers = {}
  }

  assert {
    condition     = length(local.splunk_network_ips) == 1
    error_message = "splunk_network_ips with no splunk containers should have exactly 1 entry, got ${length(local.splunk_network_ips)}"
  }

  assert {
    condition     = contains(local.splunk_network_ips, "198.18.20.200")
    error_message = "splunk_network_ips should contain splunk VM IP 198.18.20.200"
  }
}

run "splunk_network_ips_includes_splunk_tagged_container" {
  command = plan

  variables {
    containers = {
      "splunk-mgmt" = {
        vm_id    = 199
        hostname = "splunk-mgmt"
        vlan     = "siem"
        tags     = ["terraform", "splunk", "container"]
      }
    }
  }

  assert {
    condition     = contains(local.splunk_network_ips, "198.18.20.200")
    error_message = "splunk_network_ips must include splunk VM IP"
  }

  assert {
    condition     = contains(local.splunk_network_ips, "198.18.20.199")
    error_message = "splunk_network_ips must include splunk-tagged container IP on siem VLAN"
  }

  assert {
    condition     = length(local.splunk_network_ips) == 2
    error_message = "splunk_network_ips should have exactly 2 entries"
  }
}

# --- pipeline_constants tests ---

run "pipeline_constants_service_ports" {
  command = plan

  assert {
    condition     = local.pipeline_constants.service_ports.splunk_hec == 8088
    error_message = "splunk_hec port should be 8088"
  }

  assert {
    condition     = local.pipeline_constants.service_ports.splunk_web == 8000
    error_message = "splunk_web port should be 8000"
  }

  assert {
    condition     = local.pipeline_constants.service_ports.haproxy_stats == 8404
    error_message = "haproxy_stats port should be 8404"
  }
}

run "pipeline_constants_syslog_ports" {
  command = plan

  assert {
    condition     = local.pipeline_constants.syslog_ports.unifi == 1514
    error_message = "unifi syslog port should be 1514"
  }

  assert {
    condition     = local.pipeline_constants.syslog_ports.palo_alto == 1515
    error_message = "palo_alto syslog port should be 1515"
  }
}

run "pipeline_constants_netflow_ports" {
  command = plan

  assert {
    condition     = local.pipeline_constants.netflow_ports.unifi == 2055
    error_message = "unifi netflow port should be 2055"
  }
}

run "pipeline_constants_notification_ports" {
  command = plan

  assert {
    condition     = local.pipeline_constants.notification_ports.mailpit_smtp == 1025
    error_message = "mailpit_smtp port should be 1025"
  }

  assert {
    condition     = local.pipeline_constants.notification_ports.mailpit_web == 8025
    error_message = "mailpit_web port should be 8025"
  }

  assert {
    condition     = local.pipeline_constants.notification_ports.ntfy_http == 8080
    error_message = "ntfy_http port should be 8080"
  }
}

run "pipeline_constants_cribl_ports" {
  command = plan

  assert {
    condition     = local.pipeline_constants.service_ports.cribl_edge_api == 9420
    error_message = "cribl_edge_api port should be 9420"
  }

  assert {
    condition     = local.pipeline_constants.service_ports.cribl_stream_api == 9000
    error_message = "cribl_stream_api port should be 9000"
  }
}

run "pipeline_constants_vector_db_ports" {
  command = plan

  assert {
    condition     = local.pipeline_constants.vector_db_ports.qdrant_http == 6333
    error_message = "qdrant_http port should be 6333"
  }

  assert {
    condition     = local.pipeline_constants.vector_db_ports.qdrant_grpc == 6334
    error_message = "qdrant_grpc port should be 6334"
  }
}

run "pipeline_constants_infisical_ports" {
  command = plan

  assert {
    condition     = local.pipeline_constants.service_ports.infisical_api == 8080
    error_message = "infisical_api port should be 8080"
  }

  assert {
    condition     = local.pipeline_constants.service_ports.postgres_default == 5432
    error_message = "postgres_default port should be 5432"
  }

  assert {
    condition     = local.pipeline_constants.service_ports.redis_default == 6379
    error_message = "redis_default port should be 6379"
  }
}

# --- tag-filtering locals isolation ---

run "infisical_ids_empty_by_default" {
  command = plan

  variables {
    containers = {}
  }

  assert {
    condition     = length(local.infisical_container_ids) == 0
    error_message = "infisical_container_ids should be empty when containers is empty"
  }
}

run "cribl_stream_ids_empty_by_default" {
  command = plan

  variables {
    containers = {}
  }

  assert {
    condition     = length(local.cribl_stream_container_ids) == 0
    error_message = "cribl_stream_container_ids should be empty when containers is empty"
  }
}

run "cribl_stream_ids_picks_up_stream_tagged" {
  command = plan

  variables {
    containers = {
      "cribl-stream" = {
        vm_id    = 182
        hostname = "cribl-stream"
        vlan     = "pipeline"
        tags     = ["terraform", "cribl", "stream", "container"]
      }
    }
  }

  assert {
    condition     = length(local.cribl_stream_container_ids) == 1
    error_message = "cribl_stream_container_ids should have 1 entry for cribl+stream tagged container"
  }

  assert {
    condition     = local.cribl_stream_container_ids["cribl-stream"] == 182
    error_message = "cribl_stream_container_ids should map 'cribl-stream' to vm_id 182"
  }
}
