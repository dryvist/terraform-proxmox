# rack-server-cluster module

Declarative inventory of rack servers (Dell PowerEdge, HPE ProLiant,
Supermicro, etc.) joining the Proxmox cluster.

## Usage

Set `rack_servers` via the private RustFS `private deployment object` at the repo
root (real values supplied this way; the example file shows the shape with
`192.168.0.x` placeholders):

```json
{
  "rack_servers": {
    "node-a": {
      "chassis": "r410",
      "bmc_ip": "192.168.0.10",
      "bmc_mac": "00:00:00:00:00:00",
      "service_tag": "EXAMPLE1",
      "mgmt_ip": "192.168.0.11"
    }
  }
}
```

`bmc_ip` / `bmc_mac` refer to the out-of-band management interface — iDRAC
on Dell, iLO on HPE, IMM on Lenovo, etc. `chassis` is a free-form model
string (no vendor whitelist).

The module emits outputs that `ansible-proxmox` reads via
`terraform_remote_state` so IP / MAC / service-tag values stay in one
private RustFS source.

## Requirements

- OpenTofu >= 1.10 (Terraform >= 1.10 also compatible — repo standardizes on OpenTofu)
- bpg/proxmox provider ~> 0.106 (only needed once cluster-membership
  verification is enabled — see "Current scope" below)
- private RustFS for editing `private deployment object`

## Outputs

| Output | Shape | Use |
| ------ | ----- | --- |
| `node_names` | sorted list of node names | iteration |
| `bmc_ips` | map(name → ip) | racadm / ipmitool / ilorest targeting |
| `bmc_macs` | map(name → mac) | DHCP reservations, switch port mapping |
| `mgmt_ips` | map(name → ip) | PVE web UI, SSH, ansible inventory |
| `service_tags` | map(name → tag) | vendor warranty / support lookup |
| `by_chassis` | map(chassis → map of nodes) | ansible group_vars selection |
| `ansible_inventory` | list of objects | drop-in ansible inventory shape |

## Current scope

Inventory-only. No resources are created — this module exists so that nodes
can be declared once (in private RustFS) and consumed everywhere without duplication.

When nodes are physically online and joined to the cluster, uncomment the
`proxmox_virtual_environment_nodes` data source + `check` block in `main.tf`
to verify the declared inventory matches the live cluster.

## Why nothing is hard-coded

`tofu-proxmox` is the org's source of truth for cluster identity, but
this repo is public. Real values (IPs, MACs, service tags, hostnames) must
be supplied via private RustFS or environment, never committed. The
`private deployment object.example` at the repo root shows the placeholder shape
using the `192.168.0.x` sample prefix.
