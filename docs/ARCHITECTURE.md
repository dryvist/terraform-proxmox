# Infrastructure Architecture

Canonical architecture reference for the Proxmox homelab ecosystem.
All other repositories link here; this is the single source of truth.

## Repository Dependency Graph

```mermaid
graph TD
    subgraph "Infrastructure Layer"
        TP[terraform-proxmox]
        TA[terraform-aws]
        TAB[terraform-aws-bedrock]
        TAS[terraform-aws-static-website]
    end

    subgraph "Configuration Layer"
        AP[ansible-proxmox]
        APA[ansible-proxmox-apps]
        AS[ansible-splunk]
    end

    subgraph "Development & Applications"
        CR[cribl]
        SP[splunk]
    end

    subgraph "Secrets & Credentials"
        DOP[Doppler]
        AV[aws-vault]
        SOPS_AGE[SOPS + Age]
    end

    TP -->|ansible_inventory| APA
    TP -->|ansible_inventory| AS
    TP -->|VM/container IDs, IPs| AP
    TA -->|Route53 DNS| TP
    DOP -->|PROXMOX_VE_* env vars| TP
    DOP -->|SPLUNK_* env vars| AS
    DOP -->|env vars| APA
    AV -->|AWS creds for S3 backend| TP
    AV -->|AWS creds| TA
    CR -->|packs & configs| APA
    SP -->|add-ons| AS
    SOPS_AGE -->|terraform.sops.json| TP
```

## Data Pipeline Flow

```mermaid
flowchart LR
    subgraph Sources["Syslog Sources"]
        U[UniFi :1514]
        PA[Palo Alto :1515]
        CA[Cisco ASA :1516]
        LN[Linux :1517]
        WN[Windows :1518]
    end

    subgraph NetFlow["NetFlow Sources"]
        NF[UniFi IPFIX :2055 UDP]
    end

    subgraph LB["Load Balancer (LXC)"]
        HAP[HAProxy<br/>:1514-1518 UDP/TCP<br/>:2055 UDP<br/>Stats :8404]
    end

    subgraph Collectors["Cribl Edge (LXC, 2 replicas)"]
        CE1[cribl-edge-01<br/>:9420 API]
        CE2[cribl-edge-02<br/>:9420 API]
        PQ1[(per-node PQ<br/>~100GB)]
        PQ2[(per-node PQ<br/>~100GB)]
    end

    subgraph Processors["Cribl Stream (LXC, 2 replicas)"]
        CS1[cribl-stream-01<br/>:9000 API]
        CS2[cribl-stream-02<br/>:9000 API]
    end

    subgraph Destination["Splunk Enterprise VM"]
        HEC[HEC :8088]
        WEB[Web UI :8000]
        MGMT[Mgmt :8089]
    end

    Sources --> HAP
    NetFlow --> HAP
    HAP -->|round-robin syslog| CE1
    HAP -->|round-robin syslog| CE2
    HAP -->|netflow UDP| CS1
    HAP -->|netflow UDP| CS2
    CE1 --> PQ1
    CE2 --> PQ2
    PQ1 --> CS1
    PQ2 --> CS2
    CS1 -->|HEC HTTPS| HEC
    CS2 -->|HEC HTTPS| HEC
```

**Cribl two-tier rationale**: Edge nodes own ingestion + persistent queueing
(absorbs upstream bursts, survives Splunk outages). Stream nodes own routing
and central pipeline logic (sourcetype enrichment, HEC output). Both run as
LXC containers in the `logging` resource pool — no Docker Swarm in this path.

## Secrets Chain

```mermaid
flowchart TD
    subgraph Runtime["Runtime Secrets (Active)"]
        DOP[Doppler<br/>Project: iac-conf-mgmt]
        AV[aws-vault<br/>Profile: terraform]
        KC[macOS Keychain<br/>ai-secrets keychain]
    end

    subgraph Sync["Secrets Sync (Active)"]
        DS[doppler secrets-sync]
    end

    subgraph GitCommitted["Git-Committed Secrets (Active)"]
        SOPS[SOPS + Age<br/>terraform.sops.json]
    end

    subgraph Consumers["Consumers"]
        TF[Terraform/Terragrunt]
        ANS[Ansible Playbooks]
        GHA[GitHub Actions]
        AI[Claude Code / AI Agents]
    end

    DOP -->|PROXMOX_VE_*| TF
    DOP -->|SPLUNK_*, env vars| ANS
    DOP -->|secrets-sync| DS
    DS -->|repository secrets| GHA
    AV -->|AWS_* creds| TF
    KC -->|API keys| AI
    SOPS -->|terraform.sops.json| TF
```

## Infrastructure Components

### Proxmox VE Host

Single-node hypervisor running VMs and LXC containers.
Managed by `ansible-proxmox` (kernel, ZFS, monitoring, firewall, Samba NAS).

**Host services declared in `deployment.json`** (`host_services.nas`):

- ZFS dataset `rpool/data/nas` mounted at `/mnt/nas` (1 TB quota)
- Samba shares: `nas` (general), `ha-media`, `ha-backups`
- Directories under `/mnt/nas`: `media`, `backups`, `huggingface/hub`,
  `ollama/models`
- SMB user `homeassistant` for HA integration writes to `ha-media` /
  `ha-backups`

### VMs (terraform-proxmox)

Provisioned via BPG Proxmox Terraform provider. IPs derived from VM ID:
`network_prefix.vm_id` (e.g., VM 200 = `192.168.0.200`).

| Resource      | VM ID | Purpose                                                                     |
| ------------- | ----- | --------------------------------------------------------------------------- |
| `splunk-aio`  | 200   | Splunk Enterprise (Docker) — see `modules/splunk-vm/`                       |
| `docker-host` | 250   | Docker host for ephemeral GitHub Actions runners and other Docker workloads |

Cribl Edge and Cribl Stream were previously planned for Docker Swarm on
`docker-host` but now run as dedicated LXC containers (see below).

### LXC Containers (terraform-proxmox)

Authoritative list lives in `deployment.json` `containers.*`. Summary by pool:

- **`infrastructure`** — `ansible`, `pve-scripts-local`, `technitium-dns`,
  `pi-hole`, `phpipam`, `apt-cacher-ng`, `minio`, `mailpit`, `ntfy`,
  `homeassistant`, `mssql`, `nginx-proxy-manager`, `prometheus`
- **`logging`** — `haproxy`, `cribl-edge-01/02`, `cribl-stream-01/02`,
  `splunk-mgmt` (SH + DS + LM + MC + CM)
- **`ai`** — `claude-code-01/02`, `gemini-01/02`, `qdrant`, `llamaindex`
- **`media`** (v1 pinned to the primary media node — `node_name`,
  `node_storage`, and ansible inventory label all aligned on that node;
  v2 lives on the secondary media node) — `download-vpn` (qBittorrent +
  Prowlarr behind Proton WireGuard with an nftables killswitch), `sonarr`,
  `radarr`, `plex`, `seerr`, `traefik` (HTTPS/TLS ingress)

Notable per-container facts:

- `haproxy` LXC fronts syslog 1514-1518 (UDP/TCP) and NetFlow 2055 (UDP) — see
  [LOGGING_PIPELINE.md](./LOGGING_PIPELINE.md).
- `cribl-edge-01/02` (port 9420 API) and `cribl-stream-01/02` (port 9000 API)
  form the two-tier processing pipeline.
- `splunk-mgmt` is the LXC search head + deployment server + license manager +
  monitoring console + cluster manager. The `splunk-aio` VM 200 is the
  dedicated indexing node.
- `mailpit` and `ntfy` run Docker-in-LXC (`nesting: true`, `keyctl: true`) for
  internal notifications.
- `download-vpn` is an unprivileged LXC with `/dev/net/tun` passed through
  (`device_passthrough`) so WireGuard can create `wg0` inside the container.
  `rpool/data/downloads` and `rpool/data/media` are bind-mounted from the media-node host
  (size-less `mount_points`); the `ansible-proxmox` `zfs_pools` role provisions
  these datasets ahead of LXC creation. Egress is locked to the VPN by an in-LXC
  nftables killswitch (config + continuous validation owned by
  `ansible-proxmox-apps` `download_vpn` role); Proxmox-level firewall is
  intentionally not applied to the media pool — the killswitch is the security
  boundary.
- `sonarr`, `radarr`, `plex` are LAN-only (no VPN); they reach Prowlarr +
  qBittorrent on `download-vpn` over the LAN and read/write the same
  bind-mounted `rpool/data/*` datasets.
- `traefik` (VMID 215) is the HTTPS reverse-proxy / TLS ingress, on the media
  VLAN so it reaches the media UIs at layer 2 (other VLANs' UIs route in). It
  fronts every service web UI at `https://<name>.pve.<domain>` (no ports) and
  fetches + auto-renews a wildcard `*.pve.<domain>` Let's Encrypt certificate
  itself via the Route53 DNS-01 challenge (lego) — no inbound internet required.
  Install, dynamic routers (generated from this inventory), and the cert
  lifecycle are owned by the `ansible-proxmox-apps` `traefik` role; it
  supersedes the legacy `nginx-proxy-manager` LXC.

#### Notification Services

Mailpit (VM ID 110) and ntfy (VM ID 111) provide internal notification delivery:

- **Mailpit** (`192.168.x.110`): SMTP relay on port 1025, web UI on port 8025. Captures outbound emails from internal services for inspection and relaying.
- **ntfy** (`192.168.x.111`): HTTP push notification server on port 8080. Provides topic-based pub/sub notifications for internal alerting.

Both containers run Docker-in-LXC (`nesting: true`, `keyctl: true`) and are tagged `notifications` for firewall group membership.

### Terraform Modules

| Module | Purpose |
| --- | --- |
| `proxmox-vm` | Generic VM provisioning |
| `proxmox-container` | LXC container provisioning |
| `proxmox-pool` | Resource pool management |
| `splunk-vm` | Splunk-specific VM with Docker |
| `firewall` | Proxmox firewall rules |
| `storage` | Datastore configuration |
| `acme-certificate` | Let's Encrypt via Route53 |
| `security` | Security policies |

### State Management

- **Backend**: S3 + DynamoDB (us-east-2)
- **Encryption**: Enabled at rest
- **Locking**: DynamoDB table per repo
- **Credential**: aws-vault (never stored in files)

## Downstream Inventory Flow

terraform-proxmox produces `ansible_inventory` output consumed by Ansible repos:

```bash
# Regenerate, validate, and distribute (writes tofu_inventory.json to each
# downstream repo + a versioned commit to int_homelab; rejects a partial output)
./scripts/sync-inventory.sh
```

The inventory includes:

- `containers` - LXC containers with `proxmox_pct_remote` connection
- `vms` - VMs with SSH connection
- `docker_vms` - VMs tagged "docker" (subset of vms)
- `splunk_vm` - Dedicated Splunk VM
- `constants` - Pipeline port definitions from `locals.tf`

## Tool Chain

All Terraform commands require the full toolchain wrapper:

```text
nix develop → aws-vault exec → doppler run → terragrunt <command>
```

- **Nix**: Consistent tool versions (Terraform, Terragrunt, Ansible)
- **aws-vault**: AWS credentials for S3 backend
- **Doppler**: Proxmox API credentials (`PROXMOX_VE_*` env vars)
- **Terragrunt**: Wrapper with remote state and provider generation

## Related Documentation

- [LOGGING_PIPELINE.md](./LOGGING_PIPELINE.md) - Detailed syslog pipeline
- [SECRETS_ROADMAP.md](./SECRETS_ROADMAP.md) - Unified secrets strategy
- [INFISICAL_PLANNING.md](./INFISICAL_PLANNING.md) - Self-hosted secrets manager planning
