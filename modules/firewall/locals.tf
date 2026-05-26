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
  syslog_ports       = var.pipeline_constants.syslog_ports
  notification_ports = var.pipeline_constants.notification_ports
  vector_db_ports    = var.pipeline_constants.vector_db_ports
  netflow_ports      = var.pipeline_constants.netflow_ports

  # Pipeline syslog ports — derived from syslog_ports values so that adding
  # a new typed-source port auto-expands the firewall rule. Excludes the
  # default (514) which has its own rule.
  #
  # Emitted as a comma-separated list rather than a min:max range to avoid
  # accidentally over-permitting if a non-contiguous port (e.g. 9999) is
  # ever added to syslog_ports — see Gemini security review on #323.
  # Proxmox firewall dport accepts comma-separated port lists.
  pipeline_syslog_ports = [for k, v in local.syslog_ports : v if k != "default"]
  pipeline_syslog_range = join(",", [for v in sort(local.pipeline_syslog_ports) : tostring(v)])

  internal_access_rules = [
    { proto = "tcp", dport = "22", source = local.internal_src, comment = "SSH from internal networks" },
    { proto = "icmp", dport = null, source = local.internal_src, comment = "ICMP from internal networks" },
  ]

  splunk_services_rules = [
    { proto = "tcp", dport = tostring(local.svc_ports.splunk_web), source = local.internal_src, comment = "Splunk Web UI from internal" },
    { proto = "tcp", dport = tostring(local.svc_ports.splunk_hec), source = local.internal_src, comment = "Splunk HEC from internal" },
    { proto = "tcp", dport = tostring(local.svc_ports.splunk_forwarding), source = local.internal_src, comment = "Splunk Forwarding (TCP ${local.svc_ports.splunk_forwarding}) from internal" },
  ]

  syslog_rules = [
    { proto = "udp", dport = tostring(local.syslog_ports.default), source = local.internal_src, comment = "Syslog UDP (UDP ${local.syslog_ports.default}) from internal" },
    { proto = "tcp", dport = tostring(local.syslog_ports.default), source = local.internal_src, comment = "Syslog TCP (TCP ${local.syslog_ports.default}) from internal" },
    { proto = "udp", dport = local.pipeline_syslog_range, source = local.internal_src, comment = "Pipeline syslog UDP (UDP ${local.pipeline_syslog_range}) from internal" },
    { proto = "tcp", dport = local.pipeline_syslog_range, source = local.internal_src, comment = "Pipeline syslog TCP (TCP ${local.pipeline_syslog_range}) from internal" },
  ]

  pipeline_services_rules = [
    { proto = "tcp", dport = tostring(local.svc_ports.haproxy_stats), source = local.internal_src, comment = "HAProxy stats from internal" },
    { proto = "tcp", dport = tostring(local.svc_ports.cribl_edge_api), source = local.internal_src, comment = "Cribl Edge API from internal" },
  ]

  netflow_rules = [
    { proto = "udp", dport = tostring(local.netflow_ports.unifi), source = local.internal_src, comment = "NetFlow/IPFIX UDP from internal" },
  ]

  ntp_server_rules = [
    { proto = "udp", dport = tostring(local.svc_ports.ntp), source = local.internal_src, comment = "NTP chrony server (UDP ${local.svc_ports.ntp}) from internal" },
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
    { proto = "tcp", dport = tostring(local.svc_ports.idrac_kvm_r410), source = local.internal_src, comment = "iDRAC HTML5 KVM R410 (TCP ${local.svc_ports.idrac_kvm_r410}) from internal" },
    { proto = "tcp", dport = tostring(local.svc_ports.idrac_kvm_r710), source = local.internal_src, comment = "iDRAC HTML5 KVM R710 (TCP ${local.svc_ports.idrac_kvm_r710}) from internal" },
  ]
}
