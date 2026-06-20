# Splunk Index Configuration

## Overview

This document defines the Splunk indexes used in the logging pipeline, their purpose, and retention policies.

## Index Definitions

| Index          | Purpose                   | Sources                        | Retention |
| -------------- | ------------------------- | ------------------------------ | --------- |
| unifi          | UniFi network device logs | Network devices, switches, APs | 365 days  |
| os             | Operating system logs     | Linux, macOS, Windows hosts    | 365 days  |
| firewall       | Firewall logs             | Palo Alto, Cisco ASA           | 365 days  |
| network        | General network logs      | Switches, routers, other       | 365 days  |
| netmon_metrics | Per-WAN network diagnosis | Probes, DOCSIS SNMP, satellite | 90 days   |
| netflow        | UniFi NetFlow/IPFIX flows | UniFi gateway (IPFIX 2055)     | 90 days   |

## Index Configuration

### unifi

```ini
[unifi]
homePath = $SPLUNK_DB/unifi/db
coldPath = $SPLUNK_DB/unifi/colddb
thawedPath = $SPLUNK_DB/unifi/thaweddb
maxTotalDataSizeMB = 102400
frozenTimePeriodInSecs = 31536000
```

**Data types**:

- Connection events (client connects/disconnects)
- Threat detection (IDS/IPS alerts)
- Traffic flows
- System events

### os

```ini
[os]
homePath = $SPLUNK_DB/os/db
coldPath = $SPLUNK_DB/os/colddb
thawedPath = $SPLUNK_DB/os/thaweddb
maxTotalDataSizeMB = 102400
frozenTimePeriodInSecs = 31536000
```

**Data types**:

- Authentication events (login/logout)
- Process execution
- File system events
- System errors

### firewall

```ini
[firewall]
homePath = $SPLUNK_DB/firewall/db
coldPath = $SPLUNK_DB/firewall/colddb
thawedPath = $SPLUNK_DB/firewall/thaweddb
maxTotalDataSizeMB = 102400
frozenTimePeriodInSecs = 31536000
```

**Data types**:

- Traffic permits/denies
- NAT translations
- VPN events
- Threat detection

### network

```ini
[network]
homePath = $SPLUNK_DB/network/db
coldPath = $SPLUNK_DB/network/colddb
thawedPath = $SPLUNK_DB/network/thaweddb
maxTotalDataSizeMB = 102400
frozenTimePeriodInSecs = 31536000
```

**Data types**:

- SNMP traps
- Spanning tree events
- Port status changes
- General network telemetry

### netmon_metrics

```ini
[netmon_metrics]
homePath = $SPLUNK_DB/netmon_metrics/db
coldPath = $SPLUNK_DB/netmon_metrics/colddb
thawedPath = $SPLUNK_DB/netmon_metrics/thaweddb
maxTotalDataSizeMB = 51200
frozenTimePeriodInSecs = 7776000
```

**Data types**:

- Per-WAN ICMP/DNS/HTTPS latency, loss, and jitter (Telegraf active probes)
- DOCSIS modem counters (power, MER/SNR, correctable + uncorrectable codewords, T3/T4 timeouts)
- Satellite obstruction %, outages, pop-ping latency
- Hourly per-WAN throughput (speedtest-exporter)

### netflow

```ini
[netflow]
homePath = $SPLUNK_DB/netflow/db
coldPath = $SPLUNK_DB/netflow/colddb
thawedPath = $SPLUNK_DB/netflow/thaweddb
maxTotalDataSizeMB = 51200
frozenTimePeriodInSecs = 7776000
```

**Data types**:

- UniFi NetFlow / IPFIX flow records (UDP 2055 → HAProxy → Cribl Edge → Cribl Stream)
- High-volume traffic-flow telemetry, split from `network` so its volume has its own
  size and retention envelope

## Retention Policy

Security-log indexes use a **365-day retention** period (`frozenTimePeriodInSecs = 31536000`).
The `netmon_metrics` diagnostics and `netflow` flow-record indexes are the exceptions at **90 days**
(`7776000`) — a troubleshooting / volume horizon, not a compliance window.

**Rationale**:

- Security investigations may require historical data
- Compliance requirements typically need 1 year retention
- Storage capacity supports this duration

## Size Limits

Security-log indexes are limited to **100GB** each (`maxTotalDataSizeMB = 102400`); the `netmon_metrics`
diagnostics and `netflow` flow indexes are each capped at **50GB** (`51200`).

**Capacity planning**:

- Total: 500GB across 6 indexes (4 × 100GB security + netmon_metrics 50GB + netflow 50GB)
- Splunk VM disk: 500GB allocated
- Caps now equal the 500GB VM disk — grow the VM disk (leaving ~50GB for Splunk internal
  indexes) before onboarding the broader host/container/firewall log sources

## Source Type Mapping

| Source Type    | Index          | Description            |
| -------------- | -------------- | ---------------------- |
| unifi:usg      | unifi          | UniFi Security Gateway |
| unifi:switch   | unifi          | UniFi switches         |
| unifi:ap       | unifi          | UniFi access points    |
| syslog:linux   | os             | Linux syslog           |
| syslog:macos   | os             | macOS syslog           |
| syslog:windows | os             | Windows Event Log      |
| pan:traffic    | firewall       | Palo Alto traffic      |
| pan:threat     | firewall       | Palo Alto threats      |
| cisco:asa      | firewall       | Cisco ASA              |
| syslog:network | network        | Generic network        |
| netmon:probe   | netmon_metrics | Telegraf active probes |
| netmon:docsis  | netmon_metrics | Cable modem SNMP       |
| netmon:sat     | netmon_metrics | satellite uplink probe |
| ipfix          | netflow        | UniFi NetFlow/IPFIX    |

## HEC Token Configuration

The Splunk HEC token is stored in Doppler as `SPLUNK_HEC_TOKEN`.

**HEC settings**:

- Port: 8088
- TLS: Enabled
- Default index: Based on source type routing in Cribl

## Ansible Configuration

Indexes are configured via the `splunk_docker` role in ansible-proxmox-apps:

```yaml
# roles/splunk_docker/defaults/main.yml
splunk_indexes:
  - name: unifi
    maxTotalDataSizeMB: 102400
    frozenTimePeriodInSecs: 31536000
  - name: os
    maxTotalDataSizeMB: 102400
    frozenTimePeriodInSecs: 31536000
  - name: firewall
    maxTotalDataSizeMB: 102400
    frozenTimePeriodInSecs: 31536000
  - name: network
    maxTotalDataSizeMB: 102400
    frozenTimePeriodInSecs: 31536000
  - name: netmon_metrics
    maxTotalDataSizeMB: 51200
    frozenTimePeriodInSecs: 7776000
  - name: netflow
    maxTotalDataSizeMB: 51200
    frozenTimePeriodInSecs: 7776000
```

## Related Documentation

- [LOGGING_PIPELINE.md](./LOGGING_PIPELINE.md) - Pipeline architecture
- [Splunk Indexes Configuration](https://docs.splunk.com/Documentation/Splunk/latest/Admin/Indexesconf)
