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
    "object-storage" = { backend = "object-storage", port = local.pipeline_constants.service_ports.object_storage_console }
    # RustFS S3 API fronted by a valid-TLS hostname. Path-style S3 format.
    s3        = { backend = "object-storage", port = local.pipeline_constants.service_ports.object_storage_s3 }
    infisical = { backend = "infisical", port = local.pipeline_constants.service_ports.infisical_api }
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
    dify            = { backend = "dify", port = local.pipeline_constants.service_ports.dify_web }
    langflow        = { backend = "langflow", port = local.pipeline_constants.service_ports.langflow_web }
    langfuse        = { backend = "langfuse", port = local.pipeline_constants.service_ports.langfuse_web }
    agentgateway    = { backend = "agentgateway", port = local.pipeline_constants.service_ports.agentgateway_admin }
    smokeping       = { backend = "smokeping", port = local.pipeline_constants.service_ports.smokeping_web }
    "haproxy-stats" = { backend = "haproxy", port = local.pipeline_constants.service_ports.haproxy_stats }
  }

  # Ingress HA (keepalived VRRP VIP) locals — ingress_vip / ingress_hosts /
  # ingress_container_keys — live in locals-ingress-ha.tf so this file stays under
  # the shared _file-size workflow's 12 KB error threshold (locals merge across
  # files in the module, same split as locals-honeypot.tf / locals-vm-network.tf).

  # Proxmox cluster UI apex backend pool. Load-balanced across commissioned
  # nodes by role FQDN. Traefik skips backend cert verification.
  proxmox_ui_backends = [
    for name, n in var.nodes : "${n.role}.${var.domain}"
    if n.commissioned
  ]

  # OpenBao Raft HA backend pool. Every LXC tagged "openbao" is load-balanced
  # behind a single openbao.<domain> route with health checks, so a node loss
  # drops only that node from the pool and the ingress stays up. Standby peers
  # transparently forward API requests to the active node, so the client sees
  # one logical endpoint. The key sort keeps route rendering deterministic.
  openbao_backend_keys = sort([
    for k, v in var.containers : k
    if contains(coalesce(try(v.tags, null), []), "openbao")
  ])
  openbao_backends = [
    for k in local.openbao_backend_keys : local.container_address[k]
  ]

  # LiteLLM router pool: THE fabric endpoint (https://llm.<domain>/v1) for every
  # consumer, load-balanced across the stateless router guests. Same
  # skip-missing-peers shape as openbao_backends.
  llm_router_backends = [
    for k in ["llm-router-1", "llm-router-2", "llm-router-3"] : local.container_address[k]
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
      },
      {
        # Splunk HEC (8088) fronted at splunk-hec.<domain> on the standard
        # TLS entrypoint. HEC senders (the Cribl edges) must use this name:
        # splunk.<domain> resolves to Traefik, which serves nothing on a raw
        # 8088, so a sender dialing <name>:8088 black-holes. Same HTTPS
        # self-signed backend treatment as the other Splunk routes above.
        name         = "splunk-hec"
        ip           = split("/", local.splunk_derived_ip)[0]
        port         = local.pipeline_constants.service_ports.splunk_hec
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
    # OpenBao HA: one openbao.<domain> route load-balancing the Raft peers.
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
    ] : [],
    # LiteLLM router pool: llm.<domain> load-balancing the stateless routers.
    # No sticky — every router serves every model from the same config.
    length(local.llm_router_backends) > 0 ? [
      {
        name              = "llm"
        backends          = local.llm_router_backends
        port              = local.pipeline_constants.service_ports.llm_router_api
        health_check      = true
        health_check_path = "/health/liveliness"
      }
    ] : [],
    # IaC automation platform (Terrakube + Semaphore UI) on the iac-platform VM
    # (DHCP/DNS-first, mgmt VLAN, pve3). Appended like the Splunk VM (VMs are not
    # in var.containers, so no ingress_services row), but conditionally — a
    # deployment.json without the VM never emits dangling routes. The backend is
    # local.vm_address: the VM's FQDN, never an IP (DNS-first doctrine). Four
    # Terrakube hostnames are required upstream (UI/API/registry/dex each get
    # their own vhost); the executor is deliberately not fronted. pve3 powers
    # off nightly — consumers must treat these routes as daytime-available.
    contains(keys(var.vms), "iac-platform") ? [
      for svc in [
        { name = "terrakube", port = local.pipeline_constants.iac_platform_ports.terrakube_ui },
        { name = "terrakube-api", port = local.pipeline_constants.iac_platform_ports.terrakube_api },
        { name = "terrakube-registry", port = local.pipeline_constants.iac_platform_ports.terrakube_registry },
        { name = "terrakube-dex", port = local.pipeline_constants.iac_platform_ports.terrakube_dex },
        { name = "semaphore", port = local.pipeline_constants.iac_platform_ports.semaphore_web },
        ] : {
        name = svc.name
        ip   = local.vm_address["iac-platform"]
        port = svc.port
      }
    ] : []
  )
}
