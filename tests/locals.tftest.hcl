# Tests for locals.tf - IP derivation and pipeline constants
#
# All runs use mock providers (no real infrastructure needed).
# command = plan is sufficient since locals are evaluated at plan time.

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
  network_prefix    = "192.168.0"
  network_cidr_mask = "/24"
  splunk_vm_id      = 200
}

# --- derive_ip tests ---

run "derive_ip_200" {
  command = plan

  assert {
    condition     = local.derive_ip[200] == "192.168.0.200/24"
    error_message = "derive_ip[200] should be 192.168.0.200/24, got ${local.derive_ip[200]}"
  }
}

run "derive_ip_boundary_low" {
  command = plan

  assert {
    condition     = local.derive_ip[1] == "192.168.0.1/24"
    error_message = "derive_ip[1] should be 192.168.0.1/24, got ${local.derive_ip[1]}"
  }
}

run "derive_ip_boundary_high" {
  command = plan

  assert {
    condition     = local.derive_ip[999] == "192.168.0.999/24"
    error_message = "derive_ip[999] should be 192.168.0.999/24, got ${local.derive_ip[999]}"
  }
}

# --- network_gateway test ---

run "network_gateway_derivation" {
  command = plan

  assert {
    condition     = local.network_gateway == "192.168.0.1"
    error_message = "network_gateway should be 192.168.0.1, got ${local.network_gateway}"
  }
}

# --- splunk_derived_ip test ---

run "splunk_derived_ip_uses_vm_id" {
  command = plan

  assert {
    condition     = local.splunk_derived_ip == "192.168.0.200/24"
    error_message = "splunk_derived_ip should use splunk_vm_id (200), got ${local.splunk_derived_ip}"
  }
}

run "splunk_derived_ip_different_id" {
  command = plan

  variables {
    splunk_vm_id = 100
  }

  assert {
    condition     = local.splunk_derived_ip == "192.168.0.100/24"
    error_message = "splunk_derived_ip should be 192.168.0.100/24, got ${local.splunk_derived_ip}"
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

# --- management_network tests ---

run "management_network_default" {
  command = plan

  assert {
    condition     = local.management_network == "192.168.0.0/24"
    error_message = "management_network should be 192.168.0.0/24, got ${local.management_network}"
  }
}


run "management_network_custom_mask" {
  command = plan

  variables {
    network_cidr_mask = "/16"
  }

  assert {
    condition     = local.management_network == "192.168.0.0/16"
    error_message = "management_network with /16 mask should be 192.168.0.0/16, got ${local.management_network}"
  }
}

# --- splunk_network_ips tests ---

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
    condition     = contains(local.splunk_network_ips, "192.168.0.200")
    error_message = "splunk_network_ips should contain splunk VM IP 192.168.0.200"
  }
}

run "splunk_network_ips_includes_splunk_tagged_container" {
  command = plan

  variables {
    containers = {
      "splunk-mgmt" = {
        vm_id    = 199
        hostname = "splunk-mgmt"
        tags     = ["terraform", "splunk", "container"]
      }
    }
  }

  assert {
    condition     = contains(local.splunk_network_ips, "192.168.0.200")
    error_message = "splunk_network_ips must include splunk VM IP"
  }

  assert {
    condition     = contains(local.splunk_network_ips, "192.168.0.199")
    error_message = "splunk_network_ips must include splunk-tagged container IP"
  }

  assert {
    condition     = length(local.splunk_network_ips) == 2
    error_message = "splunk_network_ips should have exactly 2 entries"
  }
}

# --- pipeline_constants netflow_ports tests ---

run "pipeline_constants_netflow_ports" {
  command = plan

  assert {
    condition     = local.pipeline_constants.netflow_ports.unifi == 2055
    error_message = "unifi netflow port should be 2055"
  }
}

# --- pipeline_constants notification_ports tests ---

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

# --- pipeline_constants cribl ports tests ---

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

# --- pipeline_constants vector_db_ports tests ---

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

# --- pipeline_constants infisical-related ports tests ---

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

# --- infisical_container_ids isolation from other groups ---

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

# --- cribl_stream_container_ids tests ---

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
        vm_id    = 171
        hostname = "cribl-stream"
        tags     = ["terraform", "cribl", "stream", "container"]
      }
    }
  }

  assert {
    condition     = length(local.cribl_stream_container_ids) == 1
    error_message = "cribl_stream_container_ids should have 1 entry for cribl+stream tagged container"
  }

  assert {
    condition     = local.cribl_stream_container_ids["cribl-stream"] == 171
    error_message = "cribl_stream_container_ids should map 'cribl-stream' to vm_id 171"
  }
}

# --- derive_ip with different prefix ---

run "derive_ip_custom_prefix" {
  command = plan

  variables {
    network_prefix = "192.168.1"
  }

  assert {
    condition     = local.derive_ip[100] == "192.168.1.100/24"
    error_message = "derive_ip with custom prefix should work, got ${local.derive_ip[100]}"
  }

  assert {
    condition     = local.network_gateway == "192.168.1.1"
    error_message = "network_gateway should use custom prefix, got ${local.network_gateway}"
  }
}
