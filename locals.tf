# Local values for common computed expressions
locals {
  # DRY per-VLAN Network Configuration - Single Source of Truth.
  # Every guest IP is derived from its VLAN's CIDR (network-form, from Doppler)
  # and its VM ID: cidrhost(network_cidrs[vlan], vm_id). The gateway is the .1
  # host of that same subnet. Masks come from the CIDR itself, so this repo
  # holds zero literal IP octets.
  #
  # var.network_cidrs is `sensitive` so the full subnet map never leaks via a
  # stray `tofu output`/log. Individual resolved values below are wrapped in
  # nonsensitive(): a single host address (<vlan subnet>.<vmid>) or a guest's
  # own gateway is not independently secret, and these must flow into the
  # ansible_inventory output and module inputs (which are non-sensitive),
  # exactly as the terraform-unifi reference resolves its Doppler CIDRs.

  # Splunk lives on the siem VLAN (per network/architecture.md). The siem CIDR
  # is the only VLAN referenced by name here; all other guests resolve via their
  # own `vlan` field below.
  splunk_derived_ip      = nonsensitive("${cidrhost(var.network_cidrs["siem"], var.splunk_vm_id)}/${split("/", var.network_cidrs["siem"])[1]}")
  splunk_network_gateway = nonsensitive(cidrhost(var.network_cidrs["siem"], 1))

  # Per-guest IPv4 (CIDR notation) and gateway, keyed by resource name. IP is
  # cidrhost(<guest VLAN CIDR>, vm_id); gateway is the .1 of that subnet.
  # A container MAY pin a static ipv4_address (CIDR form, e.g. "192.168.5.10/24") to
  # override the vm_id-derived address — for fixed low-number hosts (e.g. a DNS server
  # at .10) whose address must not follow the vm_id. Otherwise derived as usual.
  container_ipv4 = {
    for k, v in var.containers : k => nonsensitive(coalesce(
      try(v.ip_config.ipv4_address, null),
      "${cidrhost(var.network_cidrs[v.vlan], v.vm_id)}/${split("/", var.network_cidrs[v.vlan])[1]}"
    ))
  }
  container_gateway = {
    for k, v in var.containers : k => nonsensitive(cidrhost(var.network_cidrs[v.vlan], 1))
  }
  vm_ipv4 = {
    for k, v in var.vms : k =>
    nonsensitive("${cidrhost(var.network_cidrs[v.vlan], v.vm_id)}/${split("/", var.network_cidrs[v.vlan])[1]}")
  }
  vm_gateway = {
    for k, v in var.vms : k => nonsensitive(cidrhost(var.network_cidrs[v.vlan], 1))
  }

  # VGA type validation helper
  valid_vga_types = ["std", "cirrus", "vmware", "qxl"]

  # Management network for the host firewall module: the compute VLAN CIDR
  # (Proxmox hosts live on compute). Inter-VLAN policy is enforced at UniFi;
  # the Proxmox host firewall keeps host-local protection only.
  management_network = nonsensitive(var.network_cidrs["compute"])

  # Splunk cluster IPs (host-form, no mask) for the firewall splunk-cluster
  # rules: the Splunk VM on siem + any containers tagged "splunk" (e.g.
  # splunk-mgmt), each at its own VLAN address.
  splunk_network_ips = nonsensitive(concat(
    [cidrhost(var.network_cidrs["siem"], var.splunk_vm_id)],
    [for k, v in var.containers : cidrhost(var.network_cidrs[v.vlan], v.vm_id) if contains(coalesce(v.tags, []), "splunk")]
  ))

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

  # HAProxy LXCs (haproxy tag) — receive delivered ACME certs for HTTPS frontends.
  # Distinct from pipeline_container_ids (which also includes Cribl Edge); this
  # local is dedicated to cert-delivery targeting.
  haproxy_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "haproxy")
  }

  # Cribl Stream containers: tagged cribl + stream (receives from Edge, routes to Splunk)
  # Distinct from pipeline_container_ids (HAProxy + Cribl Edge) as it doesn't receive external traffic
  cribl_stream_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "cribl") && contains(coalesce(try(v.tags, null), []), "stream")
  }

  # iDRAC KVM LXC: tagged "idrac" (domistyle/idrac6-based viewers, Docker-in-LXC)
  idrac_kvm_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "idrac")
  }
}

# Pipeline constants - single source of truth for service, syslog, NetFlow, notification, and vector DB ports
# Referenced by ansible_inventory output for downstream consumption
locals {
  pipeline_constants = {
    service_ports = {
      haproxy_stats     = 8404
      splunk_web        = 8000
      splunk_hec        = 8088
      splunk_mgmt       = 8089
      splunk_forwarding = 9997
      cribl_edge_api    = 9420
      cribl_stream_api  = 9000
      apt_cacher_ng     = 3142
      minio_api         = 9000
      minio_console     = 9001
      infisical_api     = 8080
      postgres_default  = 5432
      redis_default     = 6379
      ntp               = 123
      idrac_kvm_r410    = 5410
      idrac_kvm_r710    = 5710
      # Web UIs fronted by Traefik that have no other constant home. Kept here so
      # every port lives in one place and the ingress table (below) references
      # constants, never literals.
      technitium_web    = 5380
      pihole_web        = 80
      phpipam_web       = 80
      homeassistant_web = 8123
      openproject_web   = 80
      prometheus_web    = 9090
      # Local LLM: Ollama API (CT 167 hermes-infer) + Open WebUI (CT 168 hermes-chat)
      ollama_api     = 11434
      open_webui_web = 8080
    }
    syslog_ports = {
      default   = 514
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
    # Media stack web UIs. qBittorrent + Prowlarr run inside the download-vpn
    # LXC bound to wg0; their UIs are reachable on the LAN. Sonarr/Radarr/Plex
    # are LAN-only guests. Consumed by ansible-proxmox-apps media roles so no
    # port is hardcoded downstream.
    media_ports = {
      qbittorrent_web = 8080
      prowlarr_web    = 9696
      sonarr_web      = 8989
      radarr_web      = 7878
      plex_web        = 32400
      seerr_web       = 5055
    }
  }
}

# Traefik HTTPS ingress route table — the SINGLE source for every service the
# reverse proxy fronts. The ansible-proxmox-apps `traefik` and `technitium_dns`
# roles consume `ansible_inventory.ingress` instead of each hand-listing hosts
# (the previous DRY violation). Add/remove a fronted service in ONE place here.
locals {
  # name = the hostname label -> https://<name>.<domain>.
  # backend = the container key whose IP is resolved from the inventory.
  # port = a pipeline_constants reference (never a literal, so ports stay DRY).
  ingress_services = {
    plex            = { backend = "plex", port = local.pipeline_constants.media_ports.plex_web }
    seerr           = { backend = "seerr", port = local.pipeline_constants.media_ports.seerr_web }
    sonarr          = { backend = "sonarr", port = local.pipeline_constants.media_ports.sonarr_web }
    radarr          = { backend = "radarr", port = local.pipeline_constants.media_ports.radarr_web }
    qbittorrent     = { backend = "download-vpn", port = local.pipeline_constants.media_ports.qbittorrent_web }
    prowlarr        = { backend = "download-vpn", port = local.pipeline_constants.media_ports.prowlarr_web }
    technitium      = { backend = "technitium-dns", port = local.pipeline_constants.service_ports.technitium_web }
    pihole          = { backend = "pi-hole", port = local.pipeline_constants.service_ports.pihole_web }
    phpipam         = { backend = "phpipam", port = local.pipeline_constants.service_ports.phpipam_web }
    minio           = { backend = "minio", port = local.pipeline_constants.service_ports.minio_console }
    infisical       = { backend = "infisical", port = local.pipeline_constants.service_ports.infisical_api }
    mailpit         = { backend = "mailpit", port = local.pipeline_constants.notification_ports.mailpit_web }
    ntfy            = { backend = "ntfy", port = local.pipeline_constants.notification_ports.ntfy_http }
    homeassistant   = { backend = "homeassistant", port = local.pipeline_constants.service_ports.homeassistant_web }
    openproject     = { backend = "openproject", port = local.pipeline_constants.service_ports.openproject_web }
    prometheus      = { backend = "prometheus", port = local.pipeline_constants.service_ports.prometheus_web }
    llm             = { backend = "hermes-chat", port = local.pipeline_constants.service_ports.open_webui_web }
    qdrant          = { backend = "qdrant", port = local.pipeline_constants.vector_db_ports.qdrant_http }
    "haproxy-stats" = { backend = "haproxy", port = local.pipeline_constants.service_ports.haproxy_stats }
  }

  # Assembled routes: one {name, ip, port} per fronted service whose backend
  # container is actually defined (others are skipped, so a partial deployment
  # never emits a dangling route). IP resolves via container_ipv4 (cidrhost),
  # already nonsensitive; strip the CIDR mask for the proxy backend URL.
  ingress = [
    for name, svc in local.ingress_services : {
      name = name
      ip   = split("/", local.container_ipv4[svc.backend])[0]
      port = svc.port
    }
    if contains(keys(var.containers), svc.backend)
  ]
}
