# AI / LLM log-ingest security group.
#
# One dedicated Cribl TCP-JSON receiver per AI-log source family (MacBook AI
# tools, Mac Studio LLM stack, homelab LLM fabric, OpenBao audit). All are
# HAProxy-fronted TCP frontends the sources dial; HAProxy load-balances each
# frontend PORT-TO-PORT onto the Cribl Stream pair's matching in_ai_* listener
# (backend ai_backend_<port>, NOT the shared 10300 S2S backend — Stream keys
# index/sourcetype stamping off the port). The group is therefore attached
# twice: the HAProxy containers get the frontends (pipeline_container_rules.tf)
# and the Stream containers get the same accepts for their backend listeners
# (container_rules.tf).
#
# Rule data lives here (not in locals.tf) so that file stays under the shared
# _file-size 12 KB error threshold. local.svc_ports / local.internal_src are
# defined in locals.tf — cross-file local refs resolve within the module.
#
# DRY: every port is sourced from var.pipeline_constants.ai_log_ports; the rule
# set expands automatically when a new source family is added to that map. All
# ports are TCP (Cribl TCP-JSON), inbound from internal RFC1918 networks.
locals {
  ai_log_ingest_rules = [
    for name, port in local.ai_log_ports : {
      proto   = "tcp"
      dport   = tostring(port)
      source  = local.internal_src
      comment = "AI log ingest ${name} (TCP ${port}) from internal"
    }
  ]
}

resource "proxmox_virtual_environment_cluster_firewall_security_group" "ai_log_ingest" {
  name    = "ai-log-ingest"
  comment = "AI/LLM log-ingest TCP-JSON frontends (MacBook tools, Mac Studio LLM, homelab LLM, OpenBao audit) from internal networks"

  dynamic "rule" {
    for_each = local.ai_log_ingest_rules
    content {
      type    = "in"
      action  = "ACCEPT"
      proto   = rule.value.proto
      dport   = rule.value.dport
      source  = rule.value.source
      comment = rule.value.comment
    }
  }
}
