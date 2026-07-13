# Architecture

## Control plane

Terrakube runs OpenTofu inside the homelab. It owns state, workspace locking,
job ordering, and audit history. Its per-job identity is exchanged directly
with OpenBao for a short-lived workspace token. Executors install providers
and modules from the homelab mirror, so routine plan/apply does not require
public internet.

```text
Terrakube workspace lock
  -> per-job workload identity
  -> OpenBao workspace policy
  -> ephemeral provider credentials
  -> OpenTofu plan/apply
```

## Inputs

The private, versioned RustFS `deployment.json` is desired state: guests,
pools, storage declarations, topology, domain, and the public SSH key. OpenBao
stores all credentials and private keys. The root configuration reads both
natively and passes typed values to `modules/proxmox-stack`.

OpenBao cluster peers are expanded deterministically from the shared cluster
shape in the deployment object. The root contract fails closed when load-
bearing collections or topology values are absent.

## State and locking

Terrakube state replaces the former object-store backend and lock table.
Workspace locking is sufficient; the general OpenBao flow-lock authority is
not used for OpenTofu. `migrations.tf` moves existing resource addresses under
the wrapper module without recreating infrastructure. The actual state import
requires an approved production migration window.

## Networking and firewall

Every static address is derived with `cidrhost(network_cidrs[vlan], vm_id)`.
DHCP-first guests use deterministic MACs and reserved host numbers. Guest
firewalls remain default-deny with service flows derived from
`pipeline_constants`; the UniFi layer consumes the same model in `tofu-unifi`.

## Downstream inventory

A full apply publishes the versioned Ansible inventory to RustFS as a native
resource. `ansible-proxmox`, `ansible-proxmox-apps`, and `ansible-splunk` fetch
that object on the homelab network. The producer graph validates required
connection and ingress fields before publication.

## Secret-bearing feature transfers

- Route53 uses OpenBao's native AWS secrets engine for ephemeral STS sessions.
- Servarr API keys are ephemeral; qBittorrent wiring stays in the Ansible
  `servarr_wiring` role because the provider cannot accept ephemeral secrets.
- Provider arguments that cannot be write-only require encrypted, tightly
  scoped Terrakube state until ownership can move to a native Ansible path.
