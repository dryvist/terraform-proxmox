# =============================================================================
# Rule Data & Firewall Defaults
# =============================================================================

# Firewall defaults shared across all VM/container options resources
locals {
  firewall_defaults = {
    enabled       = true
    input_policy  = "DROP"
    output_policy = "DROP"
    log_level_in  = "warning"
    log_level_out = "warning"
  }
}

# Security group rule definitions - use comma-joined source/dest for multi-network rules
# Proxmox natively supports comma-separated CIDRs in source/dest fields,
# so we generate one rule per protocol/port rather than one per network.
#
# DRY: every port literal here either references var.pipeline_constants
# (single source of truth from root locals.tf) or is a port not yet promoted
# to the constants map. Numeric ports are tostring()-converted because the
# proxmox provider's dport attribute expects string values.
locals {
  # Comma-separated internal networks for use in source/dest fields
  internal_src = join(",", var.internal_networks)

  # Local aliases to keep rule definitions readable
  svc_ports          = var.pipeline_constants.service_ports
  notification_ports = var.pipeline_constants.notification_ports
  vector_db_ports    = var.pipeline_constants.vector_db_ports
  netflow_ports      = var.pipeline_constants.netflow_ports

  internal_access_rules = [
    { proto = "tcp", dport = "22", source = local.internal_src, comment = "SSH from internal networks" },
    { proto = "icmp", dport = null, source = local.internal_src, comment = "ICMP from internal networks" },
  ]

  splunk_services_rules = [
    { proto = "tcp", dport = tostring(local.svc_ports.splunk_web), source = local.internal_src, comment = "Splunk Web UI from internal" },
    { proto = "tcp", dport = tostring(local.svc_ports.splunk_hec), source = local.internal_src, comment = "Splunk HEC from internal" },
    { proto = "tcp", dport = "9997", source = local.internal_src, comment = "Splunk Forwarding from internal" },
  ]

  syslog_rules = [
    { proto = "udp", dport = "514", source = local.internal_src, comment = "Syslog UDP from internal" },
    { proto = "tcp", dport = "514", source = local.internal_src, comment = "Syslog TCP from internal" },
    { proto = "udp", dport = "1514:1518", source = local.internal_src, comment = "Pipeline syslog UDP from internal" },
    { proto = "tcp", dport = "1514:1518", source = local.internal_src, comment = "Pipeline syslog TCP from internal" },
  ]

  pipeline_services_rules = [
    { proto = "tcp", dport = tostring(local.svc_ports.haproxy_stats), source = local.internal_src, comment = "HAProxy stats from internal" },
    { proto = "tcp", dport = tostring(local.svc_ports.cribl_edge_api), source = local.internal_src, comment = "Cribl Edge API from internal" },
  ]

  netflow_rules = [
    { proto = "udp", dport = tostring(local.netflow_ports.unifi), source = local.internal_src, comment = "NetFlow/IPFIX UDP from internal" },
  ]

  ntp_server_rules = [
    { proto = "udp", dport = "123", source = local.internal_src, comment = "NTP (chrony server) from internal" },
  ]

  notification_services_rules = [
    { proto = "tcp", dport = tostring(local.notification_ports.mailpit_smtp), source = local.internal_src, comment = "Mailpit SMTP from internal" },
    { proto = "tcp", dport = tostring(local.notification_ports.mailpit_web), source = local.internal_src, comment = "Mailpit Web UI from internal" },
    { proto = "tcp", dport = tostring(local.notification_ports.ntfy_http), source = local.internal_src, comment = "ntfy HTTP from internal" },
  ]

  vectordb_services_rules = [
    { proto = "tcp", dport = tostring(local.vector_db_ports.qdrant_http), source = local.internal_src, comment = "Qdrant HTTP API from internal" },
    { proto = "tcp", dport = tostring(local.vector_db_ports.qdrant_grpc), source = local.internal_src, comment = "Qdrant gRPC from internal" },
  ]

  apt_cacher_ng_services_rules = [
    { proto = "tcp", dport = tostring(local.svc_ports.apt_cacher_ng), source = local.internal_src, comment = "apt-cacher-ng from internal" },
  ]

  cribl_stream_services_rules = [
    { proto = "tcp", dport = tostring(local.svc_ports.cribl_stream_api), source = local.internal_src, comment = "Cribl Stream API from internal" },
  ]

  minio_services_rules = [
    { proto = "tcp", dport = tostring(local.svc_ports.minio_api), source = local.internal_src, comment = "MinIO API from internal" },
    { proto = "tcp", dport = tostring(local.svc_ports.minio_console), source = local.internal_src, comment = "MinIO Console from internal" },
  ]

  infisical_services_rules = [
    { proto = "tcp", dport = tostring(local.svc_ports.infisical_api), source = local.internal_src, comment = "Infisical API/Web from internal" },
  ]

  # Outbound to internal RFC1918 only (blocks internet egress)
  outbound_internal_rules = [
    { proto = "tcp", dest = local.internal_src, comment = "Outbound TCP to internal" },
    { proto = "udp", dest = local.internal_src, comment = "Outbound UDP to internal" },
    { proto = "icmp", dest = local.internal_src, comment = "Outbound ICMP to internal" },
  ]

  # iDRAC KVM: inbound noVNC HTTP ports from internal; egress reuses outbound_internal
  idrac_kvm_services_rules = [
    { proto = "tcp", dport = "5410", source = local.internal_src, comment = "iDRAC HTML5 KVM R410 (TCP 5410) from internal" },
    { proto = "tcp", dport = "5710", source = local.internal_src, comment = "iDRAC HTML5 KVM R710 (TCP 5710) from internal" },
  ]
}
