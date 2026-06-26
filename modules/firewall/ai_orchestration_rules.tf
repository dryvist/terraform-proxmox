# AI orchestration tier firewall resources. The orchestration UIs (n8n, Dify,
# LangFlow) and the agent-exec runtime live on the ai VLAN; Langfuse lives on the
# siem VLAN. All are DHCP-first guests behind DROP in/out policies, so each gets
# `dhcp = true` (same reason as object_storage_rules.tf). The Cribl Edge OTLP
# ingest rule (from the ai VLAN) is attached to the pipeline containers in
# container_rules.tf; this file owns the app-side guests.

# AI orchestration containers (n8n, Dify, LangFlow, agent-exec)

resource "proxmox_virtual_environment_firewall_options" "ai_orchestration_container" {
  for_each = var.ai_orchestration_container_ids

  node_name     = var.node_name
  container_id  = each.value
  enabled       = local.firewall_defaults.enabled
  input_policy  = local.firewall_defaults.input_policy
  output_policy = local.firewall_defaults.output_policy
  log_level_in  = local.firewall_defaults.log_level_in
  log_level_out = local.firewall_defaults.log_level_out

  # DHCP-first guests behind DROP policies need their own DHCPDISCOVER/OFFER
  # allowed or they never lease their reserved ai-VLAN address.
  dhcp = true

  depends_on = [proxmox_virtual_environment_cluster_firewall.main]
}

resource "proxmox_virtual_environment_firewall_rules" "ai_orchestration_container" {
  for_each = var.ai_orchestration_container_ids

  node_name    = var.node_name
  container_id = each.value

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.internal_access.name
    comment        = "Internal access (SSH, ICMP)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.ai_orchestration_services.name
    comment        = "AI orchestration UIs (n8n, LangFlow, Dify)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.outbound_internal.name
    comment        = "Outbound to internal (model endpoints, Cribl OTLP, DNS)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.outbound_https.name
    comment        = "Outbound HTTPS (external model APIs, package installs)"
  }

  depends_on = [proxmox_virtual_environment_firewall_options.ai_orchestration_container]
}

# Langfuse container (LLM observability — web + OTLP ingest on 3000)

resource "proxmox_virtual_environment_firewall_options" "langfuse_container" {
  for_each = var.langfuse_container_ids

  node_name     = var.node_name
  container_id  = each.value
  enabled       = local.firewall_defaults.enabled
  input_policy  = local.firewall_defaults.input_policy
  output_policy = local.firewall_defaults.output_policy
  log_level_in  = local.firewall_defaults.log_level_in
  log_level_out = local.firewall_defaults.log_level_out

  dhcp = true

  depends_on = [proxmox_virtual_environment_cluster_firewall.main]
}

resource "proxmox_virtual_environment_firewall_rules" "langfuse_container" {
  for_each = var.langfuse_container_ids

  node_name    = var.node_name
  container_id = each.value

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.internal_access.name
    comment        = "Internal access (SSH, ICMP)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.langfuse_services.name
    comment        = "Langfuse web + OTLP ingest (3000)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.outbound_internal.name
    comment        = "Outbound to internal (object store, DNS)"
  }

  rule {
    security_group = proxmox_virtual_environment_cluster_firewall_security_group.outbound_https.name
    comment        = "Outbound HTTPS (updates/telemetry)"
  }

  depends_on = [proxmox_virtual_environment_firewall_options.langfuse_container]
}
