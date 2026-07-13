# AI orchestration tier root locals — the AI VLAN CIDR and tag-driven container-id
# maps fed to modules/firewall. Extracted from locals.tf (sibling of ingress.tf)
# to keep that file under the shared _file-size 12 KB error threshold.
locals {
  # AI VLAN CIDR — least-privilege source for the Cribl Edge OTLP ingest path.
  # nonsensitive(): a single VLAN CIDR must flow into the firewall module input;
  # the full network_cidrs map stays sensitive.
  ai_network = nonsensitive(var.network_cidrs["ai"])

  # AI orchestration LXCs (ai-orchestration tag): n8n, Dify, LangFlow, LangGraph, agent-exec.
  # Inbound UI ports from internal + outbound internal/HTTPS (model endpoints,
  # external APIs). agent-exec carries the tag too (egress-only; no UI rule fires).
  ai_orchestration_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "ai-orchestration")
  }

  # Langfuse LLM-observability LXC (langfuse tag): web + OTLP ingest on 3000.
  langfuse_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "langfuse")
  }

  # agentgateway MCP/LLM/A2A data-plane proxy (agentgateway tag). Inbound proxy
  # (8080) from internal AI agents/tools + admin UI (15000) from internal;
  # outbound internal (local LLM fabric) + HTTPS (external MCP servers, LLM APIs).
  agentgateway_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "agentgateway")
  }
}
