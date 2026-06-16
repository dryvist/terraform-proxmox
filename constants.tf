# Pipeline constants - single source of truth for service, syslog, NetFlow, notification, and vector DB ports
# Referenced by ansible_inventory output for downstream consumption
locals {
  # Syslog source-family routing map — the single source of truth for the
  # syslog pipeline. standard = app-facing HAProxy frontend port; high =
  # backend port HAProxy forwards to (the Cribl Edge listener); index/
  # sourcetype = Splunk routing stamped by the Cribl Edge syslog pipeline.
  # Consumed by modules/firewall and exported through
  # ansible_inventory.constants for the HAProxy/Cribl roles, the
  # validate-pipeline playbook, and the pytest E2E fixtures in
  # ansible-proxmox-apps.
  syslog_port_map = {
    unifi     = { standard = 514, high = 1514, index = "unifi", sourcetype = "ubiquiti:unifi" }
    palo_alto = { standard = 515, high = 1515, index = "firewall", sourcetype = "pan:firewall" }
    cisco_asa = { standard = 516, high = 1516, index = "firewall", sourcetype = "cisco:asa" }
    linux     = { standard = 517, high = 1517, index = "os", sourcetype = "syslog" }
    windows   = { standard = 518, high = 1518, index = "os", sourcetype = "syslog" }
  }

  pipeline_constants = {
    service_ports = {
      haproxy_stats     = 8404
      splunk_web        = 8000
      splunk_hec        = 8088
      splunk_mgmt       = 8089
      splunk_forwarding = 9997
      cribl_edge_api    = 9420
      cribl_stream_api  = 9000
      # Cribl-to-Cribl (S2S/TCP-JSON) ingestion: remote Edge nodes -> HAProxy -> Stream
      cribl_s2s     = 10300
      apt_cacher_ng = 3142
      minio_api     = 9000
      minio_console = 9001
      # Object storage (RustFS) — replaces MinIO. Both kept during the migration
      # soak; remove the minio_* pair once object-storage cutover is stable.
      object_storage_s3      = 9000
      object_storage_console = 9001
      infisical_api          = 8080
      openbao_api            = 8200
      openbao_cluster        = 8201
      postgres_default       = 5432
      redis_default          = 6379
      ntp                    = 123
      idrac_kvm_r410         = 5410
      idrac_kvm_r710         = 5710
      # Web UIs fronted by Traefik that have no other constant home. Kept here so
      # every port lives in one place and the ingress table (below) references
      # constants, never literals.
      technitium_web    = 5380
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
    syslog_port_map = local.syslog_port_map
    # Legacy flat map: high/backend ports keyed by family, plus the standard
    # default frontend (514, which unifi rides). Derived from syslog_port_map;
    # kept until every downstream consumer reads syslog_port_map directly.
    syslog_ports = merge(
      { default = local.syslog_port_map.unifi.standard },
      { for k, v in local.syslog_port_map : k => v.high }
    )
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
