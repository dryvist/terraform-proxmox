# Network-Quality Monitoring (SmokePing & beyond)

This homelab tracks **latency, packet loss, jitter, reachability, DNS/HTTP response
time, throughput, and latency-under-load (bufferbloat)** across internal segments,
the WAN link, and from the outside in.

> **Design verdict (adversarial review).** Classic SmokePing renders pretty RRD
> "smoke" graphs but traps the data in a Perl/RRD/CGI island that this homelab's
> **Prometheus + Grafana + Splunk + Cribl** stack cannot query, alert on, SLO, or
> correlate. So the **system of record is Prometheus-native** — `smokeping_prober`
> for the latency distribution + `blackbox_exporter` for DNS/HTTP/TLS/TCP. The
> classic SmokePing CGI is **optional/cosmetic**. This reverses the original
> single-LXC RRD design after the four findings below.

## What measures what

| Metric | Tool (system of record) | Why not "just SmokePing" |
| --- | --- | --- |
| Latency distribution / loss / jitter-spread | **`smokeping_prober`** (ICMP/UDP) → Prometheus histograms → Grafana heatmaps | RRD can't be PromQL'd, dashboarded, or alerted by Alertmanager |
| DNS RTT, HTTP(S)/TLS response, TCP reachability, SLO | **`blackbox_exporter`** | `smokeping_prober` is ICMP/UDP only |
| **Real** jitter / MOS (RFC 3393/3550 IPDV) | **`irtt`** (isochronous 20 ms UDP) | SmokePing "SD" is RTT *distribution*, not IPDV — do not call it jitter |
| Throughput (Mbps up/down) | **speedtest-exporter** (decoupled host) | SmokePing measures no bandwidth |
| **Bufferbloat** (latency-under-load) | **flent RRUL** / Waveform, scheduled | every idle probe is blind to the spike users actually feel |
| Outside-in reachability / ISP-from-the-world | **RIPE Atlas + `atlas_exporter`**, external Uptime Kuma | a LAN box can't see "is my inbound/ISP down from outside" |

## The four findings that shaped this design

1. **RRD silo** → make `smokeping_prober`/`blackbox_exporter` the source of truth in
   Prometheus; keep the SmokePing CGI only as a familiar secondary view.
2. **Bufferbloat invisible** → all idle probes miss latency-under-load; add a
   scheduled flent/Waveform test (and it justifies SQM/CAKE on the router).
3. **"Jitter" ≠ jitter** → SmokePing/ICMP-batch SD is distribution spread, not IPDV;
   use `irtt` for VoIP-grade jitter + MOS and **relabel** the SD panel "RTT variability".
4. **Single vantage point** → mgmt-only probing can't see each segment's real path
   and is polluted by inter-VLAN routing; probe from **per-segment vantages + a
   WAN-edge vantage**, plus the outside-in vantage above.

See [`SMOKEPING_PROBES.md`](./SMOKEPING_PROBES.md) for the full measurement matrix
(ICMP caveats, `pings` count, DNS/curl correctness, config references) and sources.

## Architecture

```text
            ┌── per-segment vantages (netq-probe-*) ── smokeping_prober + blackbox + irtt
 segments ──┤                                                     │  (one per VLAN you care about)
            └── WAN-edge vantage ── true ISP-link quality          ▼
 mgmt ───── smokeping (central): smokeping_prober + blackbox + atlas_exporter + irtt (+ optional CGI UI)
 decoupled  speedtest (own host, pinned off prober node): speedtest-exporter   ──┐
 outside ── RIPE Atlas probe + atlas_exporter ; external Uptime Kuma (off-site)  │
                                                                                 ▼
                       Prometheus (scrape 15s; speedtest hourly) ── Grafana heatmaps
                                                                 └─ (deferred) Alertmanager SLOs / long-term store / Splunk
```

Throughput is **decoupled** onto its own `speedtest` host so a saturating test
never corrupts the latency/loss probes (the speedtest *causes* the bufferbloat
spike — never co-locate it with the prober).

## Infra contract (this repo → `ansible-proxmox-apps`)

No IPs/ports are hardcoded downstream — they come from `terraform output
ansible_inventory`. All guests carry the `monitoring` tag (firewall + locals
pick them up) and `docker` (Docker-in-LXC: `nesting`+`keyctl`).

| Concern | Source of truth (this repo) | Inventory key |
| --- | --- | --- |
| Central collector | `deployment.json` → `containers.smokeping` (mgmt) | `containers.smokeping.{ip,vmid}` |
| Decoupled throughput host | `containers.speedtest` (own node) | `containers.speedtest.ip` |
| Per-segment vantage(s) | `containers.netq-probe-*` (per VLAN) | `containers["netq-probe-*"].ip` |
| `smokeping_prober` :9374 | `pipeline_constants.service_ports.smokeping_prober` | `constants.service_ports.smokeping_prober` |
| `blackbox_exporter` :9115 | `…service_ports.blackbox_exporter` | `constants.service_ports.blackbox_exporter` |
| `atlas_exporter` :9400 | `…service_ports.atlas_exporter` | `constants.service_ports.atlas_exporter` |
| `irtt` :2112/udp | `…service_ports.irtt` | `constants.service_ports.irtt` |
| speedtest-exporter :9798 | `…service_ports.speedtest_exporter` | `constants.service_ports.speedtest_exporter` |
| SmokePing CGI :80 (optional) | `…service_ports.smokeping_web` + `ingress_services.smokeping` | `ingress[] name == "smokeping"` |
| Firewall (scrape-inbound + irtt UDP; open egress) | `modules/firewall/` `monitoring_services` SG + `monitoring_rules.tf` | enforced on host |

Egress stays open (`output_policy = ACCEPT`) so probes reach across VLANs and the
WAN; inter-VLAN reachability is enforced at UniFi. **Least-privilege egress
(default-deny allowlist to just the probe targets/DNS/NTP) is the recommended
hardening** — a monitoring box on mgmt with open egress is a pivot risk; the
exporters themselves only need scrape-inbound.

## Cadence

- `smokeping_prober`: continuous ~1 packet/s stream; Prometheus **scrape 15 s**
  (≈20 samples / 5 min, matching SmokePing resolution).
- `blackbox`: scrape 15–30 s for SLO probes.
- `irtt`: continuous or 60 s windows (isochronous 20 ms UDP).
- **speedtest: hourly, off-peak** — a real test saturates the WAN; 5-minute cadence
  would distort the result and ISP usage, and (if co-located) corrupt latency.
- bufferbloat (flent/Waveform): hourly/daily scheduled, recording the loaded−idle
  delta; align with or replace a speedtest slot.

## Component references (downstream Compose)

Central `smokeping` collector (grant `cap_net_raw` to the binaries rather than
privileged; under unprivileged LXC verify `cap_net_raw+ep` survives and set
`net.ipv4.ping_group_range`):

```yaml
services:
  smokeping_prober:
    image: ghcr.io/superq/smokeping_prober:latest   # pin a digest in the role
    command: ["--config.file=/config/smokeping.yml"]
    cap_add: [NET_RAW]
    ports: ["9374:9374"]                            # constants.service_ports.smokeping_prober
  blackbox_exporter:
    image: quay.io/prometheus/blackbox-exporter:latest
    command: ["--config.file=/config/blackbox.yml"]
    cap_add: [NET_RAW]                               # icmp module
    ports: ["9115:9115"]                            # constants.service_ports.blackbox_exporter
  irtt:
    image: ghcr.io/heistp/irtt:latest               # irtt server -i0 (isochronous)
    command: ["server"]
    ports: ["2112:2112/udp"]                        # constants.service_ports.irtt
  # atlas_exporter (RIPE Atlas streaming → :9400) on the central host only
  # classic SmokePing CGI (:80) optional — see ingress_services.smokeping
```

Decoupled `speedtest` host (own node):

```yaml
services:
  speedtest-exporter:
    image: ghcr.io/miguelndecarvalho/speedtest-exporter:latest
    ports: ["9798:9798"]                            # constants.service_ports.speedtest_exporter
    # - SPEEDTEST_SERVER=<id>  # pin an Ookla server for stable trends
```

Prometheus scrape (downstream): one job per exporter using `constants.service_ports.*`
and the guest IPs; `smokeping_prober`/`blackbox` at 15 s, **`speedtest` hourly**
(`scrape_interval: 1h`, `scrape_timeout: 60s`). Multi-vantage = one scrape target
per `netq-probe-*` guest, labelled by segment.

## Dashboards & alerting

- **Grafana**: import [SmokePing for smokeping_prober #22471](https://grafana.com/grafana/dashboards/22471-smokeping/)
  (heatmap + jitter + loss) and the percentile-band "smoke" technique from
  [#17335](https://grafana.com/grafana/dashboards/17335-smokeping/); blackbox SLO
  views [#7587](https://grafana.com/grafana/dashboards/7587-prometheus-blackbox-exporter/);
  RIPE Atlas [#23794](https://grafana.com/grafana/dashboards/23794-ripe-atlas/).
- **Alerting (deferred track — not built here):** prefer Alertmanager
  **multi-window multi-burn-rate SLOs** ([Google SRE Workbook](https://sre.google/workbook/alerting-on-slos/))
  routed to the existing ntfy/Mailpit over SmokePing's single-spike patterns.
  Long-term retention (VictoriaMetrics/Thanos) and Splunk-via-Cribl correlation
  are likewise recorded as future work, not implemented in this PR.

## Downstream implementation checklist (`ansible-proxmox-apps`)

1. `network_quality` role: deploy the Compose stacks above on `smokeping`,
   `speedtest`, and each `netq-probe-*` from `ansible_inventory` (IPs/ports DRY).
2. Template `smokeping_prober`/`blackbox` target lists from inventory (gateways
   from `network_cidrs`, hosts from `nodes`/`containers`/`splunk_vm`) — never
   hardcode IPs; include WAN-edge + per-segment vantages.
3. Add Prometheus scrape jobs (15 s; speedtest hourly) + import the Grafana
   dashboards; keep the optional SmokePing CGI router from `ingress[]`.
4. Schedule the bufferbloat (flent/Waveform) test and the `irtt` jitter/MOS run.
5. Stand up a RIPE Atlas probe + `atlas_exporter`, and one external Uptime Kuma
   off-site, for outside-in visibility.

## Resilience notes

- One container = SPOF; add a Prometheus **deadman** alert (stale metric = alert)
  and an **external watcher** so a node/monitor death still pages you.
- `cap_net_raw` in unprivileged Docker-in-LXC is fragile and the host clock skews
  sub-ms RTT — keep the prober NTP-synced and CPU-uncontended (another reason the
  speedtest is decoupled). A bare LXC or small VM for the prober is most reliable.
- Back up the RRD/data volumes (PBS) like any stateful app.
