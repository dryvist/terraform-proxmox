# poweredge-cluster module

Declarative inventory of Dell PowerEdge nodes joining the Proxmox cluster.

## Usage

Set `poweredge_nodes` via the SOPS-encrypted `terraform.sops.json` at the
repo root (real values supplied this way; the example file shows the shape
with `192.168.0.x` placeholders):

```json
{
  "poweredge_nodes": {
    "node-a": {
      "chassis": "r410",
      "idrac_ip": "192.168.0.10",
      "idrac_mac": "00:00:00:00:00:00",
      "service_tag": "EXAMPLE1",
      "mgmt_ip": "192.168.0.11"
    }
  }
}
```

The module emits outputs that `ansible-proxmox` reads via
`terraform_remote_state` so IP / MAC / service-tag values stay in one
SOPS-encrypted source.

## Requirements

- OpenTofu >= 1.10 (Terraform >= 1.10 also compatible — repo standardizes on OpenTofu)
- bpg/proxmox provider ~> 0.106 (only needed once cluster-membership
  verification is enabled — see "Current scope" below)
- SOPS for editing `terraform.sops.json`

## Outputs

| Output | Shape | Use |
| ------ | ----- | --- |
| `node_names` | sorted list of node names | iteration |
| `idrac_ips` | map(name → ip) | racadm / ipmitool targeting |
| `idrac_macs` | map(name → mac) | DHCP reservations, switch port mapping |
| `mgmt_ips` | map(name → ip) | PVE web UI, SSH, ansible inventory |
| `service_tags` | map(name → tag) | Dell warranty / support lookup |
| `by_chassis` | map(chassis → map of nodes) | ansible group_vars selection |
| `ansible_inventory` | list of objects | drop-in ansible inventory shape |

## Current scope

Inventory-only. No resources are created — this module exists so that nodes
can be declared once (in SOPS) and consumed everywhere without duplication.

When nodes are physically online and joined to the cluster, uncomment the
`proxmox_virtual_environment_nodes` data source + `check` block in `main.tf`
to verify the declared inventory matches the live cluster.

## Why nothing is hard-coded

`terraform-proxmox` is the org's source of truth for cluster identity, but
this repo is public. Real values (IPs, MACs, service tags, hostnames) must
be supplied via SOPS or environment, never committed. The
`terraform.sops.json.example` at the repo root shows the placeholder shape
using the `192.168.0.x` sample prefix.
