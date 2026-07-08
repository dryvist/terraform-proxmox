# Infrastructure Numbering Scheme

**Status**: Active. The homelab has moved to a **6-7-digit tier-positional VMID** scheme.
The legacy flat 3-digit IDs (100-251) still exist and are renumbered incrementally as
maintenance windows allow — they are **not** the target.

> The authoritative, digit-by-digit allocation is **not** duplicated here (it drifts).
> Canonical design + tier tables: **[docs.jacobpevans.com/infrastructure/vmid-network-tiers](https://docs.jacobpevans.com/infrastructure/vmid-network-tiers)**
> (the public page is the framework; the exhaustive per-guest allocation is in the private
> infrastructure docs). The **live** per-guest assignment is the gitignored
> `deployment.json` and the `ansible_inventory` Terraform output — this file describes the
> *convention*, not the inventory.

---

## The VMID positional scheme (current)

A VMID is six digits, each position carrying meaning (read coarsest → finest):

```text
[Tier][Sub-tier][Crit][OS][Instance][Env]
   │      │        │    │      │       │
   │      │        │    │      │       └─ environment (prod / stg / test / dev / sbx)
   │      │        │    │      └───────── instance number within the group
   │      │        │    └──────────────── OS family (0 = LXC, the common case)
   │      │        └───────────────────── criticality 0-9 (lower = more critical; 5 = default)
   │      └────────────────────────────── sub-tier (0 user-facing, 1 mgmt, 2 download)
   └───────────────────────────────────── trust tier 1-9 (= VLAN tag ÷ 10)
```

A plain numeric sort groups guests by tier → sub-tier → criticality, for free. Example:
Plex (`702000`) = tier 7 (media) · sub 0 (user-facing) · crit 2 · OS 0 (LXC) · instance 0 ·
env 0 (prod), and lives on VLAN 70 — identity and network are one number. (As-built
exception: the media tier still runs on VLAN 55 — see the accepted deviation below.)

### Trust tiers → VLANs (tier × 10)

| Tier | VLAN | Name | What lives here |
| --- | --- | --- | --- |
| 1 | 10 | Core services | Foundational infra everything depends on |
| 2 | 20 | Storage | NAS, block/object storage, backup targets |
| 3 | 30 | Data / pipeline / compute | Data movement, batch, general compute |
| 4 | 40 | Observability & security | Monitoring, logging, security tooling |
| 5 | 50 | AI / ML | Inference, training, model-serving |
| 6 | 60 | Applications | General self-hosted apps |
| 7 | 70 | Media | Media library + supporting services |
| 8 | 80 | Home & IoT | Home automation, IoT |
| 9 | 90 | Untrusted / guest | Cameras, guest access, least-trusted |

Special-purpose VLANs sit **outside** the tier numbering: `1` Default, `5` Management,
`53` DNS (named for port 53).

**Accepted deviation — media tier (tier 7):** the media guests carry tier-7 VMIDs
(`7xxxxx`) but run on the pre-tier `media_svc` VLAN **55**, not 70. The VMIDs already
encode the target end-state; the VLAN renumber is a supervised maintenance event
(cross-system: network controller VLAN, DHCP reservations, DNS, firewall sources —
every media guest changes address mid-transition) tracked in issue #526, and is
deliberately not folded into routine changes. Until it lands, tier 7 is the one
tier where "identity and network are one number" does not hold.

---

## Addressing: DHCP / DNS-first, with a static exception

Guests do not carry hardcoded IPs. The default is **DHCP + DNS-first**: a guest is referenced
everywhere by `{hostname}.{subdomain}` and DNS owns the actual lease. In `deployment.json` a
DHCP-first guest sets `dhcp: true` (+ optional `reserved_host` octet for a deterministic
DHCP reservation pinned by tofu-unifi). IaC carries hostnames, not octets.

The **exception** is core gear that must be reachable *before* DNS is up — most importantly
**DNS servers**. These pin a static `ip_config.ipv4_address` instead.

How `locals.tf` resolves a guest's address (`container_ipv4`):

- `dhcp = true` → `"dhcp"` (no IP derived; gateway null, lease-provided).
- static `ip_config` set → that address.
- otherwise → `cidrhost(network_cidrs[vlan], vm_id)` (legacy derive; only valid while the ID
  fits the /24).

`cidrhost` is evaluated **only** on the derive branch (an if/else, not `coalesce`, so it
short-circuits — see PR #444). That is what lets a static-IP exception host carry a 6-7-digit
positional VMID: a `cidrhost(cidr, 5310090)` would overflow the /24, but it is never
evaluated when a static `ip_config` is present.

### DNS servers (special VLAN 53, static exception) — worked example

DNS = VLAN 53, outside the tier÷10 rule, so DNS guests use a **7-digit `53`-prefixed** ID and
a **static** IP. An illustrative DNS secondary (the real IDs live only in `deployment.json`):

- VMID **5310090** = `53` (DNS VLAN) · sub 1 (mgmt) · crit 0 (most critical) · OS 0 (LXC) ·
  instance 9 · env 0 (prod).
- static `ip_config` `<dns-subnet>.3` (gateway `.1`, primary `.2`, secondary `.3`).

> IP examples on this page use the `192.168.<vlan>.x` placeholder shape (committed-file rule);
> real subnets come from Doppler `NETWORK_CIDR_*` at runtime and live only in the gitignored
> `deployment.json`. See [AGENTS.md](../AGENTS.md) for the config-file architecture.

---

## Legacy 3-digit ranges (being retired)

The original flat scheme assigned IDs by function in 100-299. These guests still run on these
IDs until renumbered onto their tier-positional IDs; treat the table as historical, not as the
allocation to extend.

| Range | Legacy purpose |
| --- | --- |
| 100-110 | Infrastructure containers |
| 150-169 | AI development containers |
| 171-189 | Cribl Stream / Edge containers |
| 190-199 | Load balancer / HAProxy / Splunk mgmt |
| 200 | Splunk Enterprise VM |
| 201-299 | Reserved for future VMs |

New guests adopt the positional scheme immediately; do not assign new flat 3-digit IDs.

---

## Resource pools

Guests are grouped into Proxmox resource pools by function (`pool_id` in `deployment.json`),
e.g. `infrastructure`, `ai`, `logging`, independent of the VMID. Pools are organizational;
placement on a node's VLAN is driven by the tier, not the pool.

---

## Splunk configuration

### Architecture

Single all-in-one Splunk Enterprise VM plus a management container:

- **Splunk VM**: Splunk Enterprise with all data roles, on the `siem` VLAN.
- **splunk-mgmt container**: management roles (SH, DS, LM, MC, CM).

### Port matrix

| Port | Protocol | Purpose             | Allowed From            |
| ---- | -------- | ------------------- | ----------------------- |
| 22   | TCP      | SSH                 | management_network      |
| 8000 | TCP      | Splunk Web UI       | management_network      |
| 8088 | TCP      | Splunk HEC          | Splunk network + Cribl  |
| 8089 | TCP      | Splunk Management   | Splunk network          |
| 9997 | TCP      | Splunk Forwarding   | Splunk network + Cribl  |
| 8080 | TCP      | Replication         | Splunk network          |
| 9887 | TCP      | Clustering          | Splunk network          |

---

## Storage configuration

### Cribl persistent-queue disks

Cribl Stream and Cribl Edge containers carry a separate data disk for the on-disk persistent
queue (mounted at `/opt/cribl/data`): a small root disk for OS + application, plus a larger
data disk so a HAProxy/Cribl outage buffers instead of dropping. Ansible formats and mounts
the data disk; see the Cribl roles in the downstream apps repo.

### Splunk VM disk layout

The Splunk VM uses separate boot and data disks:

- **Boot disk (virtio0)**: OS, Splunk application, configuration.
- **Data disk (virtio1)**: Splunk index storage and event data, mounted at `/opt/splunk/var`.

Disk sizes are set in `deployment.json` (`splunk_boot_disk_size`, `splunk_data_disk_size`).

---

## Terraform management

All guests, pools, and firewall rules are 100% Terraform-managed; the live set of resources is
defined in `deployment.json` and surfaced to downstream Ansible via the `ansible_inventory`
output. Deploy from scratch with `terragrunt apply`.
