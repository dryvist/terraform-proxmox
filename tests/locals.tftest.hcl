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
# aws is only used by the S3 inventory publish (inventory_publish.tf);
# mock it so tests need no AWS credentials in CI or locally.
mock_provider "aws" {}
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
      # Rebuilt pipeline-tier guest: siem VLAN (40), DHCP-first with a positional
      # VMID (candidate id — final allocation confirmed against the private
      # allocation table before the rebuild apply).
      "haproxy" = { vm_id = 421040, hostname = "haproxy", vlan = "siem", dhcp = true, reserved_host = 21 }
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

  # DHCP-first guest short-circuits cidrhost — the positional VMID must never
  # be interpreted as a /24 host number.
  assert {
    condition     = local.container_ipv4["haproxy"] == "dhcp"
    error_message = "dhcp-first siem-VLAN guest must pass through as 'dhcp', got ${local.container_ipv4["haproxy"]}"
  }

  assert {
    condition     = local.container_reserved_ip["haproxy"] == "192.168.40.21"
    error_message = "siem-VLAN reserved_host 21 must yield 192.168.40.21, got ${local.container_reserved_ip["haproxy"]}"
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
    condition     = local.vm_ipv4["idrac-kvm"] == "192.168.60.251/24"
    error_message = "apps-VLAN VM 251 should be 192.168.60.251/24, got ${local.vm_ipv4["idrac-kvm"]}"
  }
}

# --- splunk derivation tests (siem VLAN) ---

run "splunk_derived_ip_uses_siem_vlan" {
  command = plan

  assert {
    condition     = local.splunk_derived_ip == "192.168.40.99/24"
    error_message = "splunk_derived_ip should be siem-VLAN 192.168.40.99/24 (placeholder default splunk_vm_id), got ${local.splunk_derived_ip}"
  }

  assert {
    condition     = local.splunk_network_gateway == "192.168.40.1"
    error_message = "splunk_network_gateway should be siem-VLAN .1 (192.168.40.1), got ${local.splunk_network_gateway}"
  }
}

run "splunk_derived_ip_different_id" {
  command = plan

  variables {
    splunk_vm_id = 205
  }

  assert {
    condition     = local.splunk_derived_ip == "192.168.40.205/24"
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
    condition     = contains(local.splunk_network_ips, "192.168.40.99")
    error_message = "splunk_network_ips should contain splunk VM IP 192.168.40.99 (placeholder default)"
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
    condition     = contains(local.splunk_network_ips, "192.168.40.99")
    error_message = "splunk_network_ips must include splunk VM IP"
  }

  assert {
    condition     = contains(local.splunk_network_ips, "192.168.40.199")
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

  # Legacy flat map is derived from syslog_port_map (high ports + default 514)
  assert {
    condition     = local.pipeline_constants.syslog_ports.unifi == 1514
    error_message = "unifi syslog port should be 1514"
  }

  assert {
    condition     = local.pipeline_constants.syslog_ports.palo_alto == 1515
    error_message = "palo_alto syslog port should be 1515"
  }

  assert {
    condition     = local.pipeline_constants.syslog_ports.default == 514
    error_message = "default syslog port should be 514"
  }
}

run "pipeline_constants_syslog_port_map" {
  command = plan

  assert {
    condition     = local.pipeline_constants.syslog_port_map.unifi.standard == 514
    error_message = "unifi standard frontend should be 514"
  }

  assert {
    condition     = local.pipeline_constants.syslog_port_map.unifi.high == 1514
    error_message = "unifi high backend should be 1514"
  }

  assert {
    condition     = local.pipeline_constants.syslog_port_map.palo_alto.index == "firewall"
    error_message = "palo_alto must route to the firewall index"
  }

  assert {
    condition     = local.pipeline_constants.syslog_port_map.windows.sourcetype == "syslog"
    error_message = "windows sourcetype should be syslog"
  }

  # Every family keeps the high = standard + 1000 convention
  assert {
    condition = alltrue([
      for k, v in local.pipeline_constants.syslog_port_map : v.high == v.standard + 1000
    ])
    error_message = "every syslog_port_map family must keep high == standard + 1000"
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

run "pipeline_constants_db_ports" {
  command = plan

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
        vm_id         = 990001
        dhcp          = true
        reserved_host = 30
        hostname      = "smokeping"
        vlan          = "mgmt"
        tags          = ["terraform", "container", "monitoring", "docker"]
      }
    }
  }

  assert {
    condition     = local.monitoring_container_ids["smokeping"] == 990001
    error_message = "monitoring_container_ids should map 'smokeping' to its 6-digit VMID 990001"
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
        vm_id         = 990002
        dhcp          = true
        reserved_host = 31
        hostname      = "speedtest"
        vlan          = "mgmt"
        tags          = ["terraform", "container", "monitoring", "docker"]
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

# Static-IP exception host (a DNS server, reachable before DNS is up) carrying a
# 7-digit positional VMID. cidrhost(<dns cidr>, 9900001) would overflow the /24,
# so this run only passes because the static ip_config short-circuits the derive
# branch — the regression guard for the coalesce -> if/else change in locals.tf.
run "container_static_ip_with_positional_vmid_skips_cidrhost" {
  command = plan

  variables {
    containers = {
      "technitium-dns-2" = {
        vm_id     = 9900001
        hostname  = "technitium-dns-2"
        vlan      = "dns"
        ip_config = { ipv4_address = "192.168.2.3/24" }
        tags      = ["terraform", "container", "dns"]
      }
    }
  }

  assert {
    condition     = local.container_ipv4["technitium-dns-2"] == "192.168.2.3/24"
    error_message = "static ip_config must win without evaluating cidrhost for the 7-digit vm_id, got ${local.container_ipv4["technitium-dns-2"]}"
  }

  assert {
    condition     = local.container_gateway["technitium-dns-2"] == "192.168.2.1"
    error_message = "static positional-VMID guest gateway should be the .1 of its VLAN, got ${local.container_gateway["technitium-dns-2"]}"
  }
}

run "cribl_stream_ids_picks_up_stream_tagged" {
  command = plan

  variables {
    containers = {
      "cribl-stream" = {
        vm_id         = 425040
        dhcp          = true
        reserved_host = 25
        hostname      = "cribl-stream"
        vlan          = "siem"
        tags          = ["terraform", "cribl", "stream", "container"]
      }
    }
  }

  assert {
    condition     = length(local.cribl_stream_container_ids) == 1
    error_message = "cribl_stream_container_ids should have 1 entry for cribl+stream tagged container"
  }

  assert {
    condition     = local.cribl_stream_container_ids["cribl-stream"] == 425040
    error_message = "cribl_stream_container_ids should map 'cribl-stream' to vm_id 425040"
  }
}

run "dns_servers_derived_from_dns_containers" {
  command = plan

  variables {
    containers = {
      "technitium-dns" = { vm_id = 103, hostname = "technitium-dns", vlan = "dns", ip_config = { ipv4_address = "192.168.2.2/24" } }
      "pi-hole"        = { vm_id = 104, hostname = "pi-hole", vlan = "dns" }
    }
  }

  # Static pin honored for Technitium; Pi-hole derived from vm_id; order fixed
  assert {
    condition     = jsonencode(local.dns_servers) == jsonencode(["192.168.2.2", "192.168.2.104"])
    error_message = "dns_servers must be [technitium (pinned), pi-hole (derived)], got ${jsonencode(local.dns_servers)}"
  }
}

run "dns_servers_empty_without_dns_containers" {
  command = plan

  variables {
    containers = {}
  }

  assert {
    condition     = length(local.dns_servers) == 0
    error_message = "dns_servers must be empty with no DNS containers, got ${jsonencode(local.dns_servers)}"
  }
}

# --- deterministic MAC + reserved IP contract (DHCP-first guests) ---
#
# DHCP-first LXCs carry a stable, locally-administered MAC (02:-prefixed digest of
# the hostname) and a reserved IP derived from reserved_host (NOT the 6-digit
# positional vm_id). tofu-unifi pins MAC -> reserved_ip; technitium_dns points the
# A record at reserved_ip. Static guests get a null reserved_ip.

run "container_mac_is_deterministic_locally_administered" {
  command = plan

  variables {
    containers = {
      "smokeping" = {
        vm_id         = 990001
        dhcp          = true
        reserved_host = 30
        hostname      = "smokeping"
        vlan          = "mgmt"
        tags          = ["terraform", "container", "monitoring", "docker"]
      }
    }
  }

  # 02: prefix => locally-administered + unicast (RFC 7042).
  assert {
    condition     = startswith(local.container_mac["smokeping"], "02:")
    error_message = "container_mac must be locally-administered (02:-prefixed), got ${local.container_mac["smokeping"]}"
  }

  # Canonical 6-octet colon-separated form (17 chars: 02 + 5*':'+2 hex).
  assert {
    condition     = length(local.container_mac["smokeping"]) == 17
    error_message = "container_mac must be a 17-char MAC (02:xx:xx:xx:xx:xx), got ${local.container_mac["smokeping"]}"
  }

  # Deterministic: equals the md5-digest format() recomputed from the same hostname.
  assert {
    condition = local.container_mac["smokeping"] == format("02:%s:%s:%s:%s:%s",
      substr(md5("smokeping"), 0, 2), substr(md5("smokeping"), 2, 2),
    substr(md5("smokeping"), 4, 2), substr(md5("smokeping"), 6, 2), substr(md5("smokeping"), 8, 2))
    error_message = "container_mac must be the deterministic md5(hostname) digest, got ${local.container_mac["smokeping"]}"
  }
}

run "container_reserved_ip_from_reserved_host" {
  command = plan

  variables {
    containers = {
      # DHCP-first media-VLAN guest: reserved_host 210 -> 192.168.70.210, decoupled
      # from the 6-digit positional vm_id (which the /24 cidrhost math can't express).
      "netq-probe-media" = {
        vm_id         = 990003
        dhcp          = true
        reserved_host = 210
        hostname      = "netq-probe-media"
        vlan          = "media_svc"
        tags          = ["terraform", "container", "monitoring", "docker"]
      }
      # Static guest: no reserved_ip (advertises its derived IP instead).
      "apt-cacher-ng" = {
        vm_id    = 108
        hostname = "apt-cacher-ng"
        vlan     = "compute"
      }
    }
  }

  # media_svc id 70 -> 192.168.70.0/24; reserved_host 210 -> 192.168.70.210.
  assert {
    condition     = local.container_reserved_ip["netq-probe-media"] == "192.168.70.210"
    error_message = "dhcp guest reserved_host 210 on media_svc must yield 192.168.70.210, got ${local.container_reserved_ip["netq-probe-media"]}"
  }

  # Static guest has no reservation.
  assert {
    condition     = local.container_reserved_ip["apt-cacher-ng"] == null
    error_message = "static guest must have reserved_ip = null"
  }

  # Static guest also carries no DHCP MAC in the inventory export.
  assert {
    condition     = output.ansible_inventory.containers["apt-cacher-ng"].mac == null
    error_message = "static guest inventory mac must be null"
  }

  # DHCP guest surfaces both mac and reserved_ip in the inventory export.
  assert {
    condition     = output.ansible_inventory.containers["netq-probe-media"].reserved_ip == "192.168.70.210"
    error_message = "dhcp guest inventory reserved_ip must be 192.168.70.210, got ${output.ansible_inventory.containers["netq-probe-media"].reserved_ip}"
  }

  assert {
    condition     = startswith(output.ansible_inventory.containers["netq-probe-media"].mac, "02:")
    error_message = "dhcp guest inventory mac must be the 02:-prefixed deterministic MAC"
  }
}

# --- ai_log_routing tests (routing truth derives from ai_log_ports) ---

run "ai_log_routing_ports_track_ai_log_ports" {
  command = plan

  # Same key set, and every routing port equals its ai_log_ports twin — the
  # routing map is derived, so a drifted port is impossible by construction;
  # this asserts the derivation itself stays wired.
  assert {
    condition     = keys(local.ai_log_routing) == keys(local.ai_log_ports)
    error_message = "ai_log_routing must have exactly the ai_log_ports key set"
  }

  assert {
    condition     = alltrue([for name, r in local.ai_log_routing : r.port == local.ai_log_ports[name]])
    error_message = "every ai_log_routing port must equal its ai_log_ports twin"
  }

  assert {
    condition     = alltrue([for name, r in local.ai_log_routing : length(r.index) > 0 && length(r.sourcetype) > 0])
    error_message = "every ai_log_routing entry needs a non-empty index and sourcetype"
  }
}

run "ai_log_routing_exported_in_pipeline_constants" {
  command = plan

  assert {
    condition     = local.pipeline_constants.ai_log_routing == local.ai_log_routing
    error_message = "pipeline_constants must surface ai_log_routing for the ansible_inventory consumers"
  }

  assert {
    condition     = local.pipeline_constants.ai_log_routing.claude_code.index == "claude"
    error_message = "claude_code must route to index=claude"
  }

  assert {
    condition     = local.pipeline_constants.ai_log_routing.openbao_audit.sourcetype == "openbao:audit"
    error_message = "openbao_audit must carry sourcetype openbao:audit"
  }
}

# --- media_container_ids tag-filter tests ---
# The vpn-tag exclusion is security-critical: the VPN-locked downloader must
# NOT get a stacked hypervisor DROP/DROP under its in-guest killswitch (and it
# has no media_web_rules entry, so a stacked firewall would also drop all
# inbound web traffic). Guard the filter, not just the static port map.

run "media_container_ids_excludes_vpn_tagged_downloader" {
  command = plan

  variables {
    containers = {
      "download-vpn" = {
        vm_id    = 210
        hostname = "download-vpn"
        vlan     = "media_svc"
        tags     = ["terraform", "container", "media", "vpn"]
      }
      "sonarr" = {
        vm_id    = 211
        hostname = "sonarr"
        vlan     = "media_svc"
        tags     = ["terraform", "container", "media", "sonarr"]
      }
      "no-media-tag" = {
        vm_id    = 212
        hostname = "no-media-tag"
        vlan     = "apps"
        tags     = ["terraform", "container"]
      }
    }
  }

  assert {
    condition     = !contains(keys(local.media_container_ids), "download-vpn")
    error_message = "media_container_ids must exclude vpn-tagged guests — the killswitch is their boundary, never a stacked guest firewall"
  }

  assert {
    condition     = contains(keys(local.media_container_ids), "sonarr")
    error_message = "media_container_ids must include media-tagged LAN-only guests"
  }

  assert {
    condition     = length(local.media_container_ids) == 1
    error_message = "media_container_ids must contain exactly the media-minus-vpn set"
  }
}
