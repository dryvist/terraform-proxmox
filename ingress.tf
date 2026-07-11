# Traefik HTTPS ingress route table — the SINGLE source for every service the
# reverse proxy fronts. The ansible-proxmox-apps `traefik` and `technitium_dns`
# roles consume `ansible_inventory.ingress` instead of each hand-listing hosts
# (the previous DRY violation). Add/remove a fronted service in ONE place here.
#
# Extracted from locals.tf into its own file so locals.tf stays under the shared
# _file-size workflow's 12 KB limit; both files declare locals in the same module.
locals {
  # name = the hostname label -> https://<name>.<domain>.
  # backend = the container key whose IP is resolved from the inventory.
  # port = a pipeline_constants reference (never a literal, so ports stay DRY).
  ingress_services = {
    plex             = { backend = "plex", port = local.pipeline_constants.media_ports.plex_web }
    seerr            = { backend = "seerr", port = local.pipeline_constants.media_ports.seerr_web }
    sonarr           = { backend = "sonarr", port = local.pipeline_constants.media_ports.sonarr_web }
    radarr           = { backend = "radarr", port = local.pipeline_constants.media_ports.radarr_web }
    sortarr          = { backend = "sortarr", port = local.pipeline_constants.media_ports.sortarr_web }
    qbittorrent      = { backend = "download-vpn", port = local.pipeline_constants.media_ports.qbittorrent_web }
    prowlarr         = { backend = "download-vpn", port = local.pipeline_constants.media_ports.prowlarr_web }
    technitium       = { backend = "technitium-dns", port = local.pipeline_constants.service_ports.technitium_web }
    phpipam          = { backend = "phpipam", port = local.pipeline_constants.service_ports.phpipam_web }
    nautobot         = { backend = "nautobot", port = local.pipeline_constants.service_ports.nautobot_web } # native IPAM/DCIM UI; Postgres has NO ingress row (in-cluster 5432 only)
    vikunja          = { backend = "vikunja", port = local.pipeline_constants.service_ports.vikunja_web }
    zammad           = { backend = "zammad", port = local.pipeline_constants.service_ports.zammad_web } # native ITSM/ticketing + KB UI; nginx on 8080
    "object-storage" = { backend = "s3", port = local.pipeline_constants.service_ports.object_storage_console }
    # RustFS S3 API fronted by a valid-TLS hostname. Path-style S3 format.
    s3 = { backend = "s3", port = local.pipeline_constants.service_ports.object_storage_s3 }
    # openbao is fronted as a load-balanced pool (openbao_backends below).
    mailpit           = { backend = "mailpit", port = local.pipeline_constants.notification_ports.mailpit_web }
    ntfy              = { backend = "ntfy", port = local.pipeline_constants.notification_ports.ntfy_http }
    "honeypot-notify" = { backend = "honeypot-notify", port = local.pipeline_constants.honeypot_ports.apprise_api }
    homeassistant     = { backend = "homeassistant", port = local.pipeline_constants.service_ports.homeassistant_web }
    openproject       = { backend = "openproject", port = local.pipeline_constants.service_ports.openproject_web }
    prometheus        = { backend = "prometheus", port = local.pipeline_constants.service_ports.prometheus_web }
    # llm is fronted as a load-balanced router pool (llm_router_backends below).
    chat   = { backend = "open-webui", port = local.pipeline_constants.service_ports.open_webui_web }
    qdrant = { backend = "qdrant", port = local.pipeline_constants.vector_db_ports.qdrant_http }
    # AI orchestration stack UIs (ai VLAN) + Langfuse LLM observability (siem VLAN).
    n8n          = { backend = "n8n", port = local.pipeline_constants.service_ports.n8n_web }
    dify         = { backend = "dify", port = local.pipeline_constants.service_ports.dify_web }
    langflow     = { backend = "langflow", port = local.pipeline_constants.service_ports.langflow_web }
    langfuse     = { backend = "langfuse", port = local.pipeline_constants.service_ports.langfuse_web }
    agentgateway = { backend = "agentgateway", port = local.pipeline_constants.service_ports.agentgateway_admin }
    # MCP tool-plane front door (the `llm`-alias pattern, for tools): clients
    # dial https://mcp.<domain>/<target>/mcp; `agentgateway` stays the admin UI.
    mcp = { backend = "agentgateway", port = local.pipeline_constants.service_ports.agentgateway_proxy }
    # LangGraph (self-hosted): the `langgraph dev` server API + its Agent Chat UI,
    # both backed by the one `langgraph` guest. Chat UI is the primary play surface;
    # the API host also lets browser Studio point its ?baseUrl at it.
    langgraph        = { backend = "langgraph", port = local.pipeline_constants.service_ports.langgraph_api }
    "langgraph-chat" = { backend = "langgraph", port = local.pipeline_constants.service_ports.agent_chat_ui_web }
    # Hermes agent inbound webhook front door: https://hermes.<domain>/webhooks/<name>
    # -> hermes-agent container : hermes_webhook (HMAC-signed, event-driven trigger
    # for the one non-A2A agent). Guest firewall opens the port from internal.
    hermes          = { backend = "hermes-agent", port = local.pipeline_constants.service_ports.hermes_webhook }
    smokeping       = { backend = "smokeping", port = local.pipeline_constants.service_ports.smokeping_web }
    "haproxy-stats" = { backend = "haproxy", port = local.pipeline_constants.service_ports.haproxy_stats }
  }
}
