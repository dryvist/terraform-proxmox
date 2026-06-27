# MinIO container firewall resources (S3-compatible — API 9000, Console 9001).
# Extracted from container_rules.tf to keep that file under the shared _file-size
# 12 KB error threshold (same pattern as object_storage_rules.tf / infisical_rules.tf).
# DEPRECATED: minio is replaced by RustFS (object_storage); this block is removed
# once the migration soak is stable.

resource "proxmox_virtual_environment_firewall_options" "minio_container" {
  for_each = var.minio_container_ids

  node_name     = var.node_name
  container_id  = each.value
  enabled       = local.firewall_defaults.enabled
  input_policy  = local.firewall_defaults.input_policy
  output_policy = local.firewall_defaults.output_policy
  log_level_in  = local.firewall_defaults.log_level_in
  log_level_out = local.firewall_defaults.log_level_out

  depends_on = [proxmox_virtual_environment_cluster_firewall.main]
}

resource "proxmox_virtual_environment_firewall_rules" "minio_container" {
  for_each = var.minio_container_ids

  node_name    = var.node_name
  container_id = each.value

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.internal_access.name
    comment        = "Internal access (SSH, ICMP)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.minio_services.name
    comment        = "MinIO services (TCP/9000 API, TCP/9001 Console)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.outbound_internal.name
    comment        = "Outbound to internal only"
  }

  depends_on = [proxmox_virtual_environment_firewall_options.minio_container]
}
