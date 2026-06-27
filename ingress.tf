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
    qbittorrent      = { backend = "download-vpn", port = local.pipeline_constants.media_ports.qbittorrent_web }
    prowlarr         = { backend = "download-vpn", port = local.pipeline_constants.media_ports.prowlarr_web }
    technitium       = { backend = "technitium-dns", port = local.pipeline_constants.service_ports.technitium_web }
    phpipam          = { backend = "phpipam", port = local.pipeline_constants.service_ports.phpipam_web }
    minio            = { backend = "minio", port = local.pipeline_constants.service_ports.minio_console }
    "object-storage" = { backend = "object-storage", port = local.pipeline_constants.service_ports.object_storage_console }
    infisical        = { backend = "infisical", port = local.pipeline_constants.service_ports.infisical_api }
    # openbao is intentionally NOT here: it is a 3-node Raft HA cluster, fronted
    # as a load-balanced multi-backend pool (openbao_backends below) so the
    # ingress survives a single node loss — not a single-backend route.
    mailpit       = { backend = "mailpit", port = local.pipeline_constants.notification_ports.mailpit_web }
    ntfy          = { backend = "ntfy", port = local.pipeline_constants.notification_ports.ntfy_http }
    homeassistant = { backend = "homeassistant", port = local.pipeline_constants.service_ports.homeassistant_web }
    openproject   = { backend = "openproject", port = local.pipeline_constants.service_ports.openproject_web }
    prometheus    = { backend = "prometheus", port = local.pipeline_constants.service_ports.prometheus_web }
    llm           = { backend = "hermes-chat", port = local.pipeline_constants.service_ports.open_webui_web }
    ollama        = { backend = "hermes-infer", port = local.pipeline_constants.service_ports.ollama_api }
    qdrant        = { backend = "qdrant", port = local.pipeline_constants.vector_db_ports.qdrant_http }
    # AI orchestration stack UIs (ai VLAN) + Langfuse LLM observability (siem VLAN).
    n8n             = { backend = "n8n", port = local.pipeline_constants.service_ports.n8n_web }
    dify            = { backend = "dify", port = local.pipeline_constants.service_ports.dify_web }
    langflow        = { backend = "langflow", port = local.pipeline_constants.service_ports.langflow_web }
    langfuse        = { backend = "langfuse", port = local.pipeline_constants.service_ports.langfuse_web }
    smokeping       = { backend = "smokeping", port = local.pipeline_constants.service_ports.smokeping_web }
    "haproxy-stats" = { backend = "haproxy", port = local.pipeline_constants.service_ports.haproxy_stats }
  }

  # Proxmox cluster UI apex backend pool. Every commissioned node's web UI is
  # reachable at https://<role>.<domain>:8006, using each node's role FQDN —
  # these already resolve internally, while the bare Proxmox cluster-member name
  # deliberately does NOT, so it never collides with the subdomain ingress apex.
  # These are HOSTNAMES, not IPs: no node management IP is exported, so the
  # sensitive rack_servers data stays out of the inventory. Traefik load-balances
  # the pool and skips backend cert verification (nodes serve self-signed certs).
  proxmox_ui_backends = [
    for name, n in var.nodes : "${n.role}.${var.domain}"
    if n.commissioned
  ]

  # OpenBao 3-node Raft HA backend pool. The three peers (openbao1/2/3) are
  # load-balanced behind a single openbao.<domain> route with health checks, so
  # a node loss drops only that node from the pool and the ingress stays up.
  # Standby peers transparently forward API requests to the active node, so the
  # client sees one logical endpoint. Skips any peer not yet in var.containers
  # (partial deployment never emits a dangling backend).
  openbao_backends = [
    for k in ["openbao1", "openbao2", "openbao3"] : local.container_address[k]
    if contains(keys(var.containers), k)
  ]

  # Assembled routes: one {name, ip, port} per fronted service whose backend
  # container is actually defined (others are skipped, so a partial deployment
  # never emits a dangling route). The backend address comes from
  # local.container_address: a static guest's cidrhost IP, or a DNS-first
  # (dhcp = true) guest's FQDN — same hostname-not-IP shape as proxmox_ui_backends.
  # The Splunk VM is appended separately: it is a VM (not in var.containers), so
  # its IP comes from splunk_derived_ip (siem VLAN) rather than container_address.
  ingress = concat(
    [
      for name, svc in local.ingress_services : {
        name = name
        ip   = local.container_address[svc.backend]
        port = svc.port
      }
      if contains(keys(var.containers), svc.backend)
    ],
    [
      {
        name = "splunk"
        ip   = split("/", local.splunk_derived_ip)[0]
        port = local.pipeline_constants.service_ports.splunk_web
        # Splunk Web serves HTTPS with a self-signed cert, unlike the HTTP
        # container backends. Traefik must speak https to it and skip verify.
        # Consumers default scheme=http / insecure_tls=false when absent.
        scheme       = "https"
        insecure_tls = true
      },
      {
        # Splunk management / REST API (splunkd, 8089) fronted at
        # splunk-mgmt.<domain>. Single label deliberately: the *.<domain>
        # wildcard cert covers splunk-mgmt.<domain> but NOT a nested
        # mgmt.splunk.<domain>. splunkd's mgmt port is HTTPS self-signed, so
        # same https + skip-verify backend as the web route above.
        name         = "splunk-mgmt"
        ip           = split("/", local.splunk_derived_ip)[0]
        port         = local.pipeline_constants.service_ports.splunk_mgmt
        scheme       = "https"
        insecure_tls = true
      }
    ],
    # Proxmox cluster UI apex (the ingress subdomain apex), load-balanced.
    # apex=true -> the Traefik Host rule is the base domain itself (no <name>.
    # prefix). backends (plural) -> a multi-server loadBalancer; sticky + health
    # checks give a stable per-browser session + drop a down node from the pool.
    # Omitted entirely if no node is commissioned (empty pool -> no route).
    length(local.proxmox_ui_backends) > 0 ? [
      {
        name         = "proxmox"
        apex         = true
        backends     = local.proxmox_ui_backends
        port         = local.pipeline_constants.service_ports.proxmox_web
        scheme       = "https"
        insecure_tls = true
        sticky       = true
        health_check = true
      }
    ] : [],
    # OpenBao HA: one openbao.<domain> route load-balancing the 3 Raft peers.
    # backends (plural) -> multi-server loadBalancer; health_check drops a down
    # node; sticky keeps a browser UI session pinned. Omitted if no peer exists.
    #
    # health_check_path forces ?standbyok=true: only the active OpenBao peer
    # returns 200 on /v1/sys/health — standby peers return 429, which Traefik
    # would otherwise read as unhealthy and evict from the pool, killing the
    # standby-forwarding the HA design depends on. ?standbyok=true makes standbys
    # return 200 so they stay in the pool. The `traefik` role renders this path
    # for the route's health check (defaulting to "/" when unset).
    length(local.openbao_backends) > 0 ? [
      {
        name              = "openbao"
        backends          = local.openbao_backends
        port              = local.pipeline_constants.service_ports.openbao_api
        sticky            = true
        health_check      = true
        health_check_path = "/v1/sys/health?standbyok=true"
      }
    ] : []
  )
}
