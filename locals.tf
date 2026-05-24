# Local values for common computed expressions
locals {
  # DRY Network Configuration - Single Source of Truth
  # IPs are derived from VM IDs: network_prefix.vm_id (e.g., 192.168.0.200 for VM ID 200)
  network_gateway = "${var.network_prefix}.1"

  # Helper function to derive IP from VM ID
  # Usage: local.derive_ip[100] => "192.168.0.100/24"
  derive_ip = { for id in range(1, 1000) : id => "${var.network_prefix}.${id}${var.network_cidr_mask}" }

  # Derived Splunk IP from VM ID (eliminates redundant splunk_vm_ip_address variable)
  splunk_derived_ip = "${var.network_prefix}.${var.splunk_vm_id}${var.network_cidr_mask}"

  # Splunk network gateway - derived from network_prefix (DRY)
  splunk_network_gateway = local.network_gateway

  # VGA type validation helper
  valid_vga_types = ["std", "cirrus", "vmware", "qxl"]

  # DRY: Derive management_network from network_prefix (eliminates redundant variable)
  management_network = "${var.network_prefix}.0${var.network_cidr_mask}"

  # DRY: Derive splunk_network_ips from VM IDs (eliminates redundant variable)
  # Combines splunk VM IP + any containers tagged "splunk"
  splunk_network_ips = concat(
    ["${var.network_prefix}.${var.splunk_vm_id}"],
    [for k, v in var.containers : "${var.network_prefix}.${v.vm_id}" if contains(coalesce(v.tags, []), "splunk")]
  )

  # Pipeline containers: HAProxy (haproxy tag) and Cribl Edge (cribl + edge tags)
  # These receive syslog and NetFlow data from network devices
  pipeline_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "haproxy") || (
      contains(coalesce(try(v.tags, null), []), "cribl") && contains(coalesce(try(v.tags, null), []), "edge")
    )
  }

  # Notification containers: Mailpit and ntfy (notifications tag)
  notification_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "notifications")
  }

  # Vector database containers: Qdrant (vectordb tag)
  vectordb_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "vectordb")
  }

  # RAG engine containers: LlamaIndex (rag tag)
  rag_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "rag")
  }

  # APT caching proxy containers: apt-cacher-ng (apt-cache tag)
  apt_cacher_ng_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "apt-cache")
  }

  # MinIO object storage containers (minio tag)
  minio_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "minio")
  }

  # Infisical secrets-management containers (infisical tag)
  infisical_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "infisical")
  }

  # Cribl Stream containers: tagged cribl + stream (receives from Edge, routes to Splunk)
  # Distinct from pipeline_container_ids (HAProxy + Cribl Edge) as it doesn't receive external traffic
  cribl_stream_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "cribl") && contains(coalesce(try(v.tags, null), []), "stream")
  }

  # iDRAC KVM VMs: tagged "idrac" (domistyle/idrac6 containers on dedicated Docker VM)
  idrac_kvm_vm_ids = {
    for k, v in var.vms : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "idrac")
  }
}

# Pipeline constants - single source of truth for service, syslog, NetFlow, notification, and vector DB ports
# Referenced by ansible_inventory output for downstream consumption
locals {
  pipeline_constants = {
    service_ports = {
      haproxy_stats    = 8404
      splunk_web       = 8000
      splunk_hec       = 8088
      splunk_mgmt      = 8089
      cribl_edge_api   = 9420
      cribl_stream_api = 9000
      apt_cacher_ng    = 3142
      minio_api        = 9000
      minio_console    = 9001
      infisical_api    = 8080
      postgres_default = 5432
      redis_default    = 6379
    }
    syslog_ports = {
      unifi     = 1514
      palo_alto = 1515
      cisco_asa = 1516
      linux     = 1517
      windows   = 1518
    }
    netflow_ports = {
      unifi = 2055
    }
    notification_ports = {
      mailpit_smtp = 1025
      mailpit_web  = 8025
      ntfy_http    = 8080
    }
    vector_db_ports = {
      qdrant_http = 6333
      qdrant_grpc = 6334
    }
  }
}
