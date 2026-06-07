# SmokePing — Network-Quality Monitoring

SmokePing continuously measures **latency, packet loss, jitter, and reachability**
to many internal and external endpoints and rends them as smoke-trail RRD graphs.
This homelab runs it as a **Docker-in-LXC guest on the mgmt VLAN**, alongside a
**speedtest-exporter** that supplies the one thing SmokePing does *not* measure —
**throughput (Mbps up/down)** — to the existing Prometheus.

> **What measures what.** SmokePing = latency / loss / jitter / DNS RTT / HTTP(S)
> response time. speedtest-exporter = bandwidth (download/upload Mbps + idle ping/
> jitter). "Network quality" needs both; neither tool does the other's job.

---

## Where the infra lives (this repo)

The infra layer is fully wired in `terraform-proxmox`; the table below is the
contract the downstream `ansible-proxmox-apps` role consumes. No IPs or ports are
hardcoded downstream — they come from `terraform output ansible_inventory`.

| Concern | Source of truth (this repo) | Inventory key the role reads |
| --- | --- | --- |
| Guest (LXC, mgmt VLAN, Docker-in-LXC) | `deployment.json` → `containers.smokeping` (tags include `monitoring`, `docker`; `nesting`+`keyctl` on) | `containers.smokeping.{ip,vmid,hostname}` |
| SmokePing web port (80) | `locals.tf` `pipeline_constants.service_ports.smokeping_web` | `constants.service_ports.smokeping_web` |
| speedtest-exporter port (9798) | `locals.tf` `pipeline_constants.service_ports.speedtest_exporter` | `constants.service_ports.speedtest_exporter` |
| HTTPS front-door (`smokeping.<domain>`) | `locals.tf` `ingress_services.smokeping` | `ingress[] where name == "smokeping"` |
| Firewall (inbound 80/9798, **open egress** for probes) | `modules/firewall/` `monitoring_services` SG + `monitoring_rules.tf` | n/a (enforced on the host) |

Egress is intentionally open (`output_policy = ACCEPT` on the container) because
fping/DNS/HTTPS probes must reach across VLANs **and** out to the internet.
Inter-VLAN reachability itself is enforced at UniFi — ensure the mgmt VLAN is
permitted to ICMP/DNS/HTTPS the VLANs and WAN you want to probe.

To deploy the guest: add the same `smokeping` block to your live `deployment.json`
(confirm the `vm_id` is free on the mgmt /24 — `150` in the example is
illustrative), then `terragrunt apply`. The `after_hook` sync writes the updated
inventory into `ansible-proxmox-apps`, which then builds the config below.

---

## Cadence

`step = 300` (5 minutes) with `pings = 20` per cycle — these are SmokePing's
defaults and exactly match the requirement. 300 s is the recommended **floor**:
going lower oversamples, distorts the RRD jitter/CDEF math, and bloats the database
for no analytical gain. The 20 ICMP echoes inside each 5-minute step are what
produce the latency *distribution* (the "smoke") and the median/loss figures.

The **speedtest** job is deliberately *not* on a 5-minute cadence — a real speedtest
saturates the WAN link, so running it every 5 minutes would distort both the result
and your ISP usage. Scrape it **hourly** (see Prometheus section).

---

## Docker Compose (reference for the downstream role)

Two services in one Compose stack on the `smokeping` LXC:

```yaml
services:
  smokeping:
    image: lscr.io/linuxserver/smokeping:latest   # pin a digest/tag in the role
    container_name: smokeping
    cap_add: [NET_RAW]                              # fping raw ICMP sockets
    environment:
      - PUID=1000
      - PGID=1000
      - TZ=${TZ}
    volumes:
      - /opt/smokeping/config:/config              # Targets/Probes/General/Alerts
      - /opt/smokeping/data:/data                   # RRD database (persist!)
    ports:
      - "80:80"                                     # constants.service_ports.smokeping_web
    restart: unless-stopped

  speedtest-exporter:
    image: ghcr.io/miguelndecarvalho/speedtest-exporter:latest
    container_name: speedtest-exporter
    environment:
      - TZ=${TZ}
      # - SPEEDTEST_SERVER=<id>   # optional: pin an Ookla server for stable trends
    ports:
      - "9798:9798"                                 # constants.service_ports.speedtest_exporter
    restart: unless-stopped
```

The RRD `/data` volume **must** be persisted — it is the entire history.

---

## SmokePing config

### General

```text
*** General ***
owner    = Homelab
contact  = ops@<domain>
mailhost = <mailpit_ip>            # from constants.notification_ports.mailpit_smtp
cgiurl   = https://smokeping.<domain>/smokeping/smokeping.cgi
datadir  = /data
piddir   = /data
imgcache = /data/cache
imgurl   = cache
pagedir  = /data/htdocs
smokemail = /config/smokemail
tmail    = /config/tmail
syslogfacility = local0

*** Presentation ***
template = /config/basepage.html
+ charts
menu = Charts
title = Network Quality Overview
++ stddev
sorter = StdDev(entries=>4)
menu = Std Deviation
title = Most variable targets (jitter)
++ max
sorter = Max(entries=>5)
menu = by Max RTT
title = Worst latency
++ loss
sorter = Loss(entries=>5)
menu = by Loss
title = Worst packet loss

*** Database ***
step     = 300        # 5-minute cycle (default; the requested cadence)
pings    = 20         # echoes per cycle -> the latency distribution
# RRA retention (default-style): 10 days @5min, 90 days @30min, 1y @2h, ~4y @1d
AID = 1   0.5  144000
AID = 5   0.5  28800
AID = 7   0.5  8760
AID = 1   0.5  1440
```

### Probes

```text
*** Probes ***
+ FPing
binary = /usr/sbin/fping
packetsize = 64
pings = 20
offset = 50%
# step inherited from General (300)

+ FPing6
binary = /usr/sbin/fping
protocol = 6
packetsize = 64
pings = 20
# enable only if the mgmt VLAN actually carries IPv6

+ DNS
binary = /usr/bin/dig
pings = 5
# per-target: server, lookup, recordtype (set in Targets)

+ Curl
binary = /usr/bin/curl
pings = 5
# HTTPS application-layer response time; per-target urlformat below
```

### Targets (DRY — internal IPs come from the inventory)

Internal targets **must not** be hardcoded. The downstream role templates the
`Targets` file from `ansible_inventory`, so a gateway/host change in Terraform
flows through automatically. External targets are stable public anchors.

```text
*** Targets ***
probe = FPing
menu = Top
title = Homelab Network Quality

+ Internal
menu = Internal
title = Internal latency / loss

++ Gateways
# one entry per VLAN gateway (.1) — looped from network_cidrs in the role
+++ mgmt
menu = mgmt-gw
host = {{ mgmt_gateway_ip }}
+++ compute
host = {{ compute_gateway_ip }}
# ... siem, apps, media_svc, homeauto, etc.

++ Hosts
+++ proxmox1
host = {{ inventory.nodes['proxmox-1'].ip }}
+++ proxmox2
host = {{ inventory.nodes['proxmox-2'].ip }}
+++ splunk
host = {{ inventory.splunk_vm.splunk.ip }}

++ DNS-resolvers
probe = DNS
+++ technitium
host = {{ inventory.containers['technitium-dns'].ip }}
lookup = {{ domain }}
+++ pihole
host = {{ inventory.containers['pi-hole'].ip }}
lookup = {{ domain }}

+ External
menu = External
title = WAN / Internet quality

++ ICMP
probe = FPing
+++ cloudflare
host = 1.1.1.1
+++ google
host = 8.8.8.8
+++ quad9
host = 9.9.9.9
+++ isp-gw
host = {{ isp_gateway_ip }}        # first WAN hop, from the role's vars

++ DNS
probe = DNS
+++ cloudflare-dns
host = 1.1.1.1
lookup = www.google.com
+++ google-dns
host = 8.8.8.8
lookup = www.google.com

++ HTTPS
probe = Curl
+++ google
host = www.google.com
urlformat = https://%host%/
+++ github
host = github.com
urlformat = https://%host%/
+++ cloudflare
host = www.cloudflare.com
urlformat = https://%host%/
```

### Alerts → ntfy / Mailpit

Route SmokePing alerts to the notification stack already defined in
`pipeline_constants.notification_ports` (Mailpit for email, ntfy for push). Wire
the alert command in `General` (`to = |/config/notify.sh`) or via `mailhost`.

```text
*** Alerts ***
to = |/config/notify-ntfy.sh        # POSTs to ntfy; or use mailhost for Mailpit
from = smokeping@<domain>

+ someloss
type = loss
pattern = >0%,*2*,>0%,*2*,>0%
comment = some loss 3 of last 5 cycles

+ bigloss
type = loss
pattern = ==0%,==0%,==0%,==0%,>30%,>30%,>30%
comment = sustained heavy loss

+ hostdown
type = loss
pattern = ==0%,==U%,==U%,==U%
comment = target became unreachable

+ rttdetect
type = rtt
pattern = <10,<10,<10,>50,>50,>50
comment = latency jumped (possible congestion)
```

---

## Prometheus scrape (speedtest-exporter)

Add to the downstream Prometheus config. Note the **hourly** interval and generous
timeout — a speedtest takes 20–40 s.

```yaml
- job_name: speedtest
  scrape_interval: 1h
  scrape_timeout: 60s
  metrics_path: /metrics
  static_configs:
    - targets: ["{{ inventory.containers['smokeping'].ip }}:{{ inventory.constants.service_ports.speedtest_exporter }}"]
```

Useful series: `speedtest_download_bits_per_second`,
`speedtest_upload_bits_per_second`, `speedtest_ping_latency_milliseconds`,
`speedtest_jitter_latency_milliseconds`. Graph in Grafana next to the SmokePing
latency panels for a complete network-quality view.

---

## Downstream implementation checklist (`ansible-proxmox-apps`)

1. New `smokeping` role: install Docker (LXC already has nesting/keyctl), render the
   Compose file above, template `General` / `Probes` / `Targets` / `Alerts` into
   `/opt/smokeping/config`.
2. Build the `Targets` file from `ansible_inventory` (gateways from `network_cidrs`,
   hosts from `nodes` / `containers` / `splunk_vm`) — never hardcode IPs.
3. Add the Traefik router from `ingress[] name == "smokeping"` (the `traefik` role
   already consumes `ansible_inventory.ingress`).
4. Add the `speedtest` Prometheus scrape job (hourly).
5. Point alerts at the existing ntfy/Mailpit endpoints.

## Tuning notes

- Keep `step = 300`; lower only a specific high-value target if you truly need finer
  resolution, and give it its own probe instance with a smaller `step`.
- Enable `FPing6` only if the mgmt VLAN carries IPv6.
- Pin a `SPEEDTEST_SERVER` if your nearest Ookla server flaps between runs and
  muddies the throughput trend.
- The RRD `/data` volume is the whole history — back it up (PBS) like any stateful app.
