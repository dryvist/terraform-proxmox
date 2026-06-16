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
    openbao          = { backend = "openbao1", port = local.pipeline_constants.service_ports.openbao_api }
    mailpit          = { backend = "mailpit", port = local.pipeline_constants.notification_ports.mailpit_web }
    ntfy             = { backend = "ntfy", port = local.pipeline_constants.notification_ports.ntfy_http }
    homeassistant    = { backend = "homeassistant", port = local.pipeline_constants.service_ports.homeassistant_web }
    openproject      = { backend = "openproject", port = local.pipeline_constants.service_ports.openproject_web }
    prometheus       = { backend = "prometheus", port = local.pipeline_constants.service_ports.prometheus_web }
    llm              = { backend = "hermes-chat", port = local.pipeline_constants.service_ports.open_webui_web }
    ollama           = { backend = "hermes-infer", port = local.pipeline_constants.service_ports.ollama_api }
    qdrant           = { backend = "qdrant", port = local.pipeline_constants.vector_db_ports.qdrant_http }
    smokeping        = { backend = "smokeping", port = local.pipeline_constants.service_ports.smokeping_web }
    "haproxy-stats"  = { backend = "haproxy", port = local.pipeline_constants.service_ports.haproxy_stats }
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
    ] : []
  )
}
