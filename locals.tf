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

  # OpenBao secrets-management containers (openbao tag)
  openbao_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "openbao")
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

  # Network-quality monitoring LXC (smokeping tag "monitoring"): SmokePing web UI
  # (80) + speedtest-exporter metrics (9798). Egress is open (output ACCEPT) so
  # fping/DNS/HTTPS probes can reach internal and external targets freely.
  monitoring_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "monitoring")
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
      openbao_api       = 8200
      openbao_cluster   = 8201
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
      # Proxmox cluster web UI (:8006) — fronted by Traefik at the ingress
      # subdomain apex, load-balanced across every commissioned node's UI.
      proxmox_web = 8006
      # Local LLM: Ollama API (CT 167 hermes-infer) + Open WebUI (CT 168 hermes-chat)
      ollama_api     = 11434
      open_webui_web = 8080
      # Network-quality monitoring (Prometheus-native stack — see docs/SMOKEPING.md):
      #   smokeping_web      — SmokePing RRD/CGI UI (optional, fronted by Traefik)
      #   speedtest_exporter — throughput (Mbps) exporter, scraped by Prometheus
      #   smokeping_prober   — SuperQ ICMP/UDP latency-distribution histograms (system of record)
      #   blackbox_exporter  — DNS / HTTP(S) / TLS / TCP probes + reachability SLO
      #   atlas_exporter     — RIPE Atlas outside-in results (external vantage)
      #   irtt               — isochronous UDP RTT/jitter server (real RFC-3393 jitter / MOS)
      smokeping_web      = 80
      speedtest_exporter = 9798
      smokeping_prober   = 9374
      blackbox_exporter  = 9115
      atlas_exporter     = 9400
      irtt               = 2112
      # Per-uplink network diagnosis (CT netmon-*, mgmt VLAN, Docker-in-LXC): the
      # satellite gRPC exporter scraped by each prober's Telegraf, alongside DOCSIS
      # modem SNMP and native active probes. Pushes to Cribl -> Splunk netmon
      # index. See docs/NETWORK_DIAGNOSIS.md.
      satellite_exporter = 9817
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
