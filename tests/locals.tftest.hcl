# Tests for locals.tf - per-VLAN IP derivation and pipeline constants
#
# All runs use mock providers (no real infrastructure needed).
# command = plan is sufficient since locals are evaluated at plan time.
#
# network_cidrs fixture is DERIVED from vlan_ids as 192.168.<vlan_id>.0/24, so the
# third octet always equals the VLAN id (RFC1918 192.168/16, never the real range).
# Real subnets come from Doppler NETWORK_CIDR_* at runtime; these fakes exercise the
# cidrhost() math identically. Every guest IP is cidrhost(network_cidrs[vlan], vm_id);
# gateway is the .1.

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
  # vlan_ids uses its variable default (single source of truth); network_cidrs is
  # derived from it as 192.168.<vlan_id>.0/24 — no duplicated VLAN/CIDR list.
  network_cidrs = { for name, id in var.vlan_ids : name => "192.168.${id}.0/24" }
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
    condition     = local.container_ipv4["technitium-dns"] == "192.168.2.103/24"
    error_message = "dns-VLAN container 103 should be 192.168.2.103/24, got ${local.container_ipv4["technitium-dns"]}"
  }

  assert {
    condition     = local.container_gateway["technitium-dns"] == "192.168.2.1"
    error_message = "dns-VLAN gateway should be 192.168.2.1, got ${local.container_gateway["technitium-dns"]}"
  }

  assert {
    condition     = local.container_ipv4["haproxy"] == "192.168.25.175/24"
    error_message = "pipeline-VLAN container 175 should be 192.168.25.175/24, got ${local.container_ipv4["haproxy"]}"
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
    condition     = local.vm_ipv4["docker-host"] == "192.168.90.250/24"
    error_message = "nonprod-VLAN VM 250 should be 192.168.90.250/24, got ${local.vm_ipv4["docker-host"]}"
  }

  assert {
    condition     = local.vm_gateway["docker-host"] == "192.168.90.1"
    error_message = "nonprod-VLAN gateway should be 192.168.90.1, got ${local.vm_gateway["docker-host"]}"
  }

  assert {
    condition     = local.vm_ipv4["idrac-kvm"] == "192.168.50.251/24"
    error_message = "apps-VLAN VM 251 should be 192.168.50.251/24, got ${local.vm_ipv4["idrac-kvm"]}"
  }
}

# --- splunk derivation tests (siem VLAN) ---

run "splunk_derived_ip_uses_siem_vlan" {
  command = plan

  assert {
    condition     = local.splunk_derived_ip == "192.168.20.200/24"
    error_message = "splunk_derived_ip should be siem-VLAN 192.168.20.200/24, got ${local.splunk_derived_ip}"
  }

  assert {
    condition     = local.splunk_network_gateway == "192.168.20.1"
    error_message = "splunk_network_gateway should be siem-VLAN .1 (192.168.20.1), got ${local.splunk_network_gateway}"
  }
}

run "splunk_derived_ip_different_id" {
  command = plan

  variables {
    splunk_vm_id = 205
  }

  assert {
    condition     = local.splunk_derived_ip == "192.168.20.205/24"
    error_message = "splunk_derived_ip should track splunk_vm_id (205), got ${local.splunk_derived_ip}"
  }
}

# --- management_network test (compute VLAN CIDR) ---

run "management_network_is_compute_cidr" {
  command = plan

  assert {
    condition     = local.management_network == "192.168.10.0/24"
    error_message = "management_network should be the compute VLAN CIDR 192.168.10.0/24, got ${local.management_network}"
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
    condition     = contains(local.splunk_network_ips, "192.168.20.200")
    error_message = "splunk_network_ips should contain splunk VM IP 192.168.20.200"
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
    condition     = contains(local.splunk_network_ips, "192.168.20.200")
    error_message = "splunk_network_ips must include splunk VM IP"
  }

  assert {
    condition     = contains(local.splunk_network_ips, "192.168.20.199")
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

run "pipeline_constants_monitoring_ports" {
  command = plan

  assert {
    condition     = local.pipeline_constants.service_ports.smokeping_web == 80
    error_message = "smokeping_web port should be 80"
  }

  assert {
    condition     = local.pipeline_constants.service_ports.speedtest_exporter == 9798
    error_message = "speedtest_exporter port should be 9798"
  }

  # Hardened Prometheus-native stack exporters (see docs/SMOKEPING.md)
  assert {
    condition     = local.pipeline_constants.service_ports.smokeping_prober == 9374
    error_message = "smokeping_prober port should be 9374"
  }

  assert {
    condition     = local.pipeline_constants.service_ports.blackbox_exporter == 9115
    error_message = "blackbox_exporter port should be 9115"
  }

  assert {
    condition     = local.pipeline_constants.service_ports.atlas_exporter == 9400
    error_message = "atlas_exporter port should be 9400"
  }

  assert {
    condition     = local.pipeline_constants.service_ports.irtt == 2112
    error_message = "irtt port should be 2112"
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

run "monitoring_ids_empty_by_default" {
  command = plan

  variables {
    containers = {}
  }

  assert {
    condition     = length(local.monitoring_container_ids) == 0
    error_message = "monitoring_container_ids should be empty when containers is empty"
  }
}

run "monitoring_ids_picks_up_monitoring_tagged" {
  command = plan

  variables {
    containers = {
      "smokeping" = {
        vm_id    = 412000
        dhcp     = true
        hostname = "smokeping"
        vlan     = "mgmt"
        tags     = ["terraform", "container", "monitoring", "docker"]
      }
    }
  }

  assert {
    condition     = local.monitoring_container_ids["smokeping"] == 412000
    error_message = "monitoring_container_ids should map 'smokeping' to its 6-digit VMID 412000"
  }

  # DNS-first guest: no vm_id-derived IP. cidrhost is skipped (a 6-digit id would
  # overflow the /24 host space), so container_ipv4 is the literal "dhcp".
  assert {
    condition     = local.container_ipv4["smokeping"] == "dhcp"
    error_message = "dhcp smokeping container_ipv4 should be \"dhcp\" (cidrhost skipped), got ${local.container_ipv4["smokeping"]}"
  }
}

# DNS-first (dhcp) addressing: a 6-digit positional VMID skips IP derivation, the
# guest advertises its FQDN ({hostname}.{domain}) to downstream consumers, and no
# gateway is derived (the DHCP lease provides one).
run "container_dhcp_resolves_fqdn_and_null_gateway" {
  command = plan

  variables {
    domain = "example.com"
    containers = {
      "speedtest" = {
        vm_id    = 416000
        dhcp     = true
        hostname = "speedtest"
        vlan     = "mgmt"
        tags     = ["terraform", "container", "monitoring", "docker"]
      }
    }
  }

  assert {
    condition     = local.container_address["speedtest"] == "speedtest.example.com"
    error_message = "dhcp speedtest should advertise FQDN speedtest.example.com, got ${local.container_address["speedtest"]}"
  }

  assert {
    condition     = local.container_gateway["speedtest"] == null
    error_message = "dhcp speedtest container_gateway should be null (lease-provided)"
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
