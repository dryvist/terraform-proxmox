# Network-Quality Measurement Matrix & Rationale

Companion to [`SMOKEPING.md`](./SMOKEPING.md). This is the *how* — the probe
settings, the correctness pitfalls behind each, and the sources. It exists because
an adversarial review found that a naive "SmokePing pinging 8.8.8.8 every 5 min"
mislabels idle ICMP reachability as "latency, loss, jitter, and speed."

## Revised best-practice probe matrix

| Metric | Probe / tool | Cadence | Key settings | Notes |
| --- | --- | --- | --- | --- |
| Idle latency (median/p95) | `smokeping_prober` (FPing) **+** TCP/HTTP via blackbox | scrape 15 s (critical: faster) | `pings = 60–100`, packetsize 64 | ICMP = liveness; trust the TCP line for "real" latency. Report median **and** p95. |
| Packet loss | FPing **+** TCP/HTTPS corroboration | 15 s | `pings ≥ 60` (≤1.6% quantization) | Never alert on ICMP loss alone. 20 pings = 5% quantization (unfit). |
| Jitter / VoIP MOS | **irtt** (or TWAMP/OWAMP) — *not* SmokePing SD | continuous / 60 s | isochronous **20 ms UDP**; MOS via G.107 E-model | Relabel SmokePing SD "RTT variability," not jitter. |
| Bufferbloat (latency-under-load) | **flent RRUL** / Waveform; or fping/irtt *during* speedtest | hourly | measure loaded−idle delta, up+down saturation | The biggest gap in idle-only designs. Grade A–F; justifies SQM/CAKE. |
| DNS | blackbox `dns` / SmokePing DNS | 15–30 s | query an **authoritative** name / `+norecurse` / random label | Don't time the resolver cache. |
| HTTP/HTTPS/TLS | blackbox `http` / Curl with phase split | 15–30 s | graph `namelookup/connect/appconnect/starttransfer/total`; pin handshake | network = `connect` + TLS RTT, not the blended total. |
| Reachability / SLO | blackbox `icmp`+`tcp`+`http` (`probe_success`) | 15 s | per-target modules | feeds burn-rate SLOs. |
| Throughput | speedtest-exporter (decoupled) **+** concurrent latency probe | hourly | record loaded latency beside Mbps | throughput alone hides the bufferbloat it causes. |
| PMTU/MTU (optional) | FPing large-payload, DF set | daily | 1400–1472 B, DF; ensure ICMPv6 PtB permitted (RFC 4890) | only if MTU/QoS matters. |

## Why each setting (the pitfalls)

- **ICMP is a distorting proxy.** Routers rate-limit/deprioritize ICMP at the
  control plane (CoPP); studies find 65–98% of targets rate-limit ICMP, so ICMP
  RTT/loss can reflect *policer policy, not path quality*. Corroborate with
  TCP/HTTPS probes; gate "outage" alerts on the TCP/HTTPS probe agreeing.
  ([ISI/USC ICMP rate-limiting](https://ant.isi.edu/datasets/icmp/),
  ["Your Router is My Prober"](https://arxiv.org/pdf/2210.13088),
  [Obkio ICMP caveats](https://obkio.com/blog/what-is-icmp-monitoring/))
- **20 pings/300 s is too sparse.** n=20 quantizes loss to 5% (one drop = 5% spike)
  and gives a noisy p95/p99. Raise `pings` to 60–100; add a 60 s probe for critical
  anchors. To *validate* 0.1% loss you need thousands of packets.
  ([Silver Peak — measuring loss](https://www.silver-peak.com/sites/default/files/infoctr/silver-peak_wp_measuringloss.pdf),
  [NetBeez](https://netbeez.net/blog/testing-packet-loss/))
- **"Jitter" ≠ jitter.** SmokePing plots the median and the spread ("smoke"); its SD
  is the *standard deviation of the averages*, not RFC 3393 IPDV / RFC 3550 jitter,
  and a 20-echo burst is not a 20 ms VoIP stream. Use `irtt` for per-packet delay
  variation + loss on a real isochronous stream; derive MOS from the G.107 E-model.
  ([SmokePing reading the graphs](https://oss.oetiker.ch/smokeping/doc/reading.en.html),
  [smokeping-users: SD of averages](https://lists.oetiker.ch/pipermail/smokeping-users/2009-January/003530.html),
  [RFC 3393](https://www.rfc-editor.org/rfc/rfc3393), [RFC 3550 §6.4.1](https://www.rfc-editor.org/rfc/rfc3550),
  [irtt](https://github.com/heistp/irtt), [RFC 5357 TWAMP](https://www.rfc-editor.org/rfc/rfc5357))
- **Bufferbloat is invisible to idle probes.** Latency-under-load only appears while
  the link is saturated; the methodology is idle → saturate → measure delta. The
  hourly speedtest *is* a saturation event — graph latency during it, or run flent
  RRUL / Waveform on a schedule, and grade A–F. Enable SQM/CAKE (fq_codel) to fix it.
  ([Bufferbloat tests](https://www.bufferbloat.net/projects/bloat/wiki/Tests_for_Bufferbloat/),
  [RRUL chart](https://www.bufferbloat.net/projects/bloat/wiki/RRUL_Chart_Explanation/),
  [Flent](https://flent.org/), [LibreQoS test](https://test.libreqos.com/))
- **DNS probe must not time the cache.** Querying a cached name on a recursive
  resolver times a memcpy and under-counts loss. Query a name the resolver is
  authoritative for (or `+norecurse`/random label); track recursion health on a
  separate graph. ([SmokePing DNS probe](https://oss.oetiker.ch/smokeping/probe/DNS.en.html))
- **Curl blends DNS+TCP+TLS+server; TLS resumption skews it.** A single "HTTPS time"
  hides where a regression is, and resumed vs full TLS handshakes aren't comparable.
  Graph `curl -w` phases separately and pin handshake behavior (`--no-sessionid` or
  controlled resumption). ([curl TLS sessions](https://everything.curl.dev/usingcurl/tls/session.html),
  [TLS resumption perf](https://arxiv.org/pdf/1902.02531))
- **Packet size / IPv6.** 64 B is fine for latency/loss (avoids fragmentation) but
  can't reveal PMTU/MTU black holes; add an occasional large-payload DF probe if MTU
  matters. For IPv6, overzealous ICMPv6 filtering breaks PMTU discovery, so FPing6
  loss may reflect a firewall, not the path. ([RFC 4890](https://www.rfc-editor.org/rfc/rfc4890),
  [FPing probe](https://oss.oetiker.ch/smokeping/probe/FPing.en.html))

## Why Prometheus-native over classic SmokePing

`smokeping_prober` (by a Prometheus maintainer) records latency into **histograms**,
so `histogram_quantile()` gives any percentile and Grafana renders a heatmap = the
"smoke," now queryable, alertable, and retainable alongside the rest of the stack.
Classic SmokePing is in maintenance mode (v2.7.2, 2024), single-vantage, RRD-siloed,
and the linuxserver image has recurring SUID/`NET_RAW` fping breakage that is worst
inside unprivileged LXC. `smokeping_prober` is ICMP/UDP only, which is exactly why
`blackbox_exporter` covers DNS/HTTP/TLS/TCP, and `irtt` covers real jitter.

Alternatives considered: `blackbox_exporter` alone (one sample/scrape — no
distribution), Telegraf `ping` (good if the sink is Splunk/Influx, not Prometheus),
Cloudprober (one binary, ICMP+DNS+HTTP+distribution, easy multi-vantage fan-out — a
viable substitute), LibreNMS/Zabbix (heavier), Uptime Kuma (reachability only, no
jitter/loss graphs — use it for the *external* vantage). Sources:
[smokeping_prober](https://github.com/SuperQ/smokeping_prober),
[anarcat — replacing Smokeping with Prometheus](https://anarc.at/blog/2020-06-04-replacing-smokeping-prometheus/),
[Wikimedia T169860](https://phabricator.wikimedia.org/T169860),
[blackbox #370 (smokeping-like)](https://github.com/prometheus/blackbox_exporter/issues/370),
[APNIC — distributed latency monitoring](https://blog.apnic.net/2023/09/29/distributed-latency-monitoring/),
[Cloudprober](https://cloudprober.org/docs/overview/cloudprober/),
[linuxserver smokeping #169 (fping SUID)](https://github.com/linuxserver/docker-smokeping/issues/169).

## Multi-vantage & outside-in

- **Per-segment vantages** (`netq-probe-*`): one small prober per VLAN you care about
  (media, compute/storage, IoT) + **one on the WAN edge** — mgmt-only probing only
  sees mgmt's path and is polluted by inter-VLAN routing. Tier targets for
  attribution: LAN gateway → WAN/modem IP → ISP first hop → external anchors, so a
  spike is attributable to a layer (CGNAT blends this — document if present).
  ([SmokePing master/slave](https://oss.oetiker.ch/smokeping/doc/smokeping_master_slave.en.html))
- **Outside-in:** host a **RIPE Atlas** probe and pull results via
  [`atlas_exporter`](https://github.com/czerwonk/atlas_exporter) into Prometheus
  ([RIPE Labs guide](https://labs.ripe.net/author/daniel_czerwonk/using-ripe-atlas-measurement-results-in-prometheus/)),
  plus one **[Uptime Kuma](https://github.com/louislam/uptime-kuma)** off-site (VPS)
  for inbound reachability + a public status page — a LAN box shares your failure
  domain and can't tell you the ISP is down from the world's perspective.
