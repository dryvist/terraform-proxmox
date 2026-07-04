# Splunk containers

resource "proxmox_virtual_environment_firewall_options" "splunk_container" {
  for_each = var.splunk_container_ids

  node_name     = var.node_name
  container_id  = each.value
  enabled       = local.firewall_defaults.enabled
  input_policy  = local.firewall_defaults.input_policy
  output_policy = local.firewall_defaults.output_policy
  log_level_in  = local.firewall_defaults.log_level_in
  log_level_out = local.firewall_defaults.log_level_out

  depends_on = [proxmox_virtual_environment_cluster_firewall.main]
}

resource "proxmox_virtual_environment_firewall_rules" "splunk_container" {
  for_each = var.splunk_container_ids

  node_name    = var.node_name
  container_id = each.value

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.internal_access.name
    comment        = "Internal access (SSH, ICMP)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.splunk_services.name
    comment        = "Splunk services (Web, HEC, Forwarding)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.syslog.name
    comment        = "Syslog ingestion"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.splunk_cluster.name
    comment        = "Splunk cluster communication"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.outbound_internal.name
    comment        = "Outbound to internal only"
  }

  depends_on = [proxmox_virtual_environment_firewall_options.splunk_container]
}

# Pipeline containers (HAProxy, Cribl Edge — syslog/NetFlow receivers)

resource "proxmox_virtual_environment_firewall_options" "pipeline_container" {
  for_each = var.pipeline_container_ids

  node_name     = var.node_name
  container_id  = each.value
  enabled       = local.firewall_defaults.enabled
  input_policy  = local.firewall_defaults.input_policy
  output_policy = local.firewall_defaults.output_policy
  log_level_in  = local.firewall_defaults.log_level_in
  log_level_out = local.firewall_defaults.log_level_out

  depends_on = [proxmox_virtual_environment_cluster_firewall.main]
}

resource "proxmox_virtual_environment_firewall_rules" "pipeline_container" {
  for_each = var.pipeline_container_ids

  node_name    = var.node_name
  container_id = each.value

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.internal_access.name
    comment        = "Internal access (SSH, ICMP)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.pipeline_services.name
    comment        = "Pipeline management (HAProxy stats, Cribl Edge API)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.syslog.name
    comment        = "Syslog ingestion"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.netflow.name
    comment        = "NetFlow/IPFIX ingestion"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.outbound_internal.name
    comment        = "Outbound to internal only"
  }

  # Cribl Edge only: license-telemetry HTTPS egress. HAProxy shares this
  # rule set but gets no internet egress.
  dynamic "rule" {
    for_each = contains(keys(var.cribl_edge_container_ids), each.key) ? [1] : []
    content {
      security_group = proxmox_virtual_environment_cluster_firewall_security_group.outbound_https.name
      comment        = "Outbound HTTPS (Cribl license telemetry)"
    }
  }

  # Cribl Edge only: native OTLP ingest (traces/metrics/logs) from the AI
  # orchestration apps on the ai VLAN. HAProxy in the same group gets no OTLP.
  dynamic "rule" {
    for_each = contains(keys(var.cribl_edge_container_ids), each.key) ? [1] : []
    content {
      security_group = proxmox_virtual_environment_cluster_firewall_security_group.otel_ingest.name
      comment        = "OTLP ingest (traces/metrics/logs) from the AI VLAN"
    }
  }

  depends_on = [proxmox_virtual_environment_firewall_options.pipeline_container]
}

# Cribl Stream containers (receives from Edge, routes to Splunk HEC)

resource "proxmox_virtual_environment_firewall_options" "cribl_stream_container" {
  for_each = var.cribl_stream_container_ids

  node_name     = var.node_name
  container_id  = each.value
  enabled       = local.firewall_defaults.enabled
  input_policy  = local.firewall_defaults.input_policy
  output_policy = local.firewall_defaults.output_policy
  log_level_in  = local.firewall_defaults.log_level_in
  log_level_out = local.firewall_defaults.log_level_out

  depends_on = [proxmox_virtual_environment_cluster_firewall.main]
}

resource "proxmox_virtual_environment_firewall_rules" "cribl_stream_container" {
  for_each = var.cribl_stream_container_ids

  node_name    = var.node_name
  container_id = each.value

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.internal_access.name
    comment        = "Internal access (SSH, ICMP)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.cribl_stream_services.name
    comment        = "Cribl Stream API (9000)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.syslog.name
    comment        = "Syslog ingestion (TCP/UDP 514, 1514-1518)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.netflow.name
    comment        = "NetFlow/IPFIX ingestion (UDP 2055)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.outbound_internal.name
    comment        = "Outbound to internal only (reaches Splunk HEC 8088)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.outbound_https.name
    comment        = "Outbound HTTPS (Cribl license telemetry)"
  }

  depends_on = [proxmox_virtual_environment_firewall_options.cribl_stream_container]
}

# Notification containers (Mailpit, ntfy)

resource "proxmox_virtual_environment_firewall_options" "notification_container" {
  for_each = var.notification_container_ids

  node_name     = var.node_name
  container_id  = each.value
  enabled       = local.firewall_defaults.enabled
  input_policy  = local.firewall_defaults.input_policy
  output_policy = "ACCEPT"
  log_level_in  = local.firewall_defaults.log_level_in
  log_level_out = local.firewall_defaults.log_level_out

  depends_on = [proxmox_virtual_environment_cluster_firewall.main]
}

resource "proxmox_virtual_environment_firewall_rules" "notification_container" {
  for_each = var.notification_container_ids

  node_name    = var.node_name
  container_id = each.value

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.internal_access.name
    comment        = "Internal access (SSH, ICMP)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.notification_services.name
    comment        = "Notification services (Mailpit SMTP/Web, ntfy HTTP)"
  }

  depends_on = [proxmox_virtual_environment_firewall_options.notification_container]
}

# APT caching proxy (apt-cacher-ng — outbound ACCEPT for upstream mirrors)

resource "proxmox_virtual_environment_firewall_options" "apt_cacher_ng_container" {
  for_each = var.apt_cacher_ng_container_ids

  node_name     = var.node_name
  container_id  = each.value
  enabled       = local.firewall_defaults.enabled
  input_policy  = local.firewall_defaults.input_policy
  output_policy = "ACCEPT"
  log_level_in  = local.firewall_defaults.log_level_in
  log_level_out = local.firewall_defaults.log_level_out

  depends_on = [proxmox_virtual_environment_cluster_firewall.main]
}

resource "proxmox_virtual_environment_firewall_rules" "apt_cacher_ng_container" {
  for_each = var.apt_cacher_ng_container_ids

  node_name    = var.node_name
  container_id = each.value

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.internal_access.name
    comment        = "Internal access (SSH, ICMP)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.apt_cacher_ng_services.name
    comment        = "APT caching proxy (port 3142)"
  }

  depends_on = [proxmox_virtual_environment_firewall_options.apt_cacher_ng_container]
}

# Vector database containers (Qdrant — HTTP 6333, gRPC 6334)

resource "proxmox_virtual_environment_firewall_options" "vectordb_container" {
  for_each = var.vectordb_container_ids

  node_name     = var.node_name
  container_id  = each.value
  enabled       = local.firewall_defaults.enabled
  input_policy  = local.firewall_defaults.input_policy
  output_policy = local.firewall_defaults.output_policy
  log_level_in  = local.firewall_defaults.log_level_in
  log_level_out = local.firewall_defaults.log_level_out

  # DHCP-first guest behind DROP policies (same reason as llm_fabric_rules.tf).
  dhcp = true

  depends_on = [proxmox_virtual_environment_cluster_firewall.main]
}

resource "proxmox_virtual_environment_firewall_rules" "vectordb_container" {
  for_each = var.vectordb_container_ids

  node_name    = var.node_name
  container_id = each.value

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.internal_access.name
    comment        = "Internal access (SSH, ICMP)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.vectordb_services.name
    comment        = "Vector database (Qdrant HTTP, gRPC)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.outbound_internal.name
    comment        = "Outbound to internal only"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.outbound_https.name
    comment        = "Outbound HTTPS (Docker install/images)"
  }

  depends_on = [proxmox_virtual_environment_firewall_options.vectordb_container]
}

# RAG engine containers (LlamaIndex — no service ports, outbound-internal only)

resource "proxmox_virtual_environment_firewall_options" "rag_container" {
  for_each = var.rag_container_ids

  node_name     = var.node_name
  container_id  = each.value
  enabled       = local.firewall_defaults.enabled
  input_policy  = local.firewall_defaults.input_policy
  output_policy = local.firewall_defaults.output_policy
  log_level_in  = local.firewall_defaults.log_level_in
  log_level_out = local.firewall_defaults.log_level_out

  # DHCP-first guest behind DROP policies (same reason as llm_fabric_rules.tf).
  dhcp = true

  depends_on = [proxmox_virtual_environment_cluster_firewall.main]
}

resource "proxmox_virtual_environment_firewall_rules" "rag_container" {
  for_each = var.rag_container_ids

  node_name    = var.node_name
  container_id = each.value

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.internal_access.name
    comment        = "Internal access (SSH, ICMP)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.outbound_internal.name
    comment        = "Outbound to internal only"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.outbound_https.name
    comment        = "Outbound HTTPS (pip/PyPI installs)"
  }

  depends_on = [proxmox_virtual_environment_firewall_options.rag_container]
}

# Object storage container firewall resources: modules/firewall/object_storage_rules.tf

# Infisical container firewall resources live in modules/firewall/infisical_rules.tf
# (extracted so container_rules.tf stays under the shared _file-size workflow's 12 KB error
# threshold).
