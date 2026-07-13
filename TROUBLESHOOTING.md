# Terrakube and OpenTofu Troubleshooting

## A run is waiting

Terrakube serializes runs per workspace. Inspect the private Terrakube job
queue and cancel only a confirmed abandoned job. Do not create or bypass a
second OpenBao lock. A lost executor does not leave a separate backend lock.

## OpenBao authentication fails

Verify the Terrakube workload issuer and JWKS endpoints from the homelab, then
confirm the workspace role binds the exact audience, organization, project,
and workspace claims. Do not fall back to a stored AppRole secret or root
token.

## RustFS desired state cannot be read

Check the native OpenBao path
`secret/infrastructure/terrakube/object-storage`, RustFS DNS/TLS reachability,
and the `iac-inventory/deployment.json` object. The configuration fails closed;
never substitute an empty object.

## Proxmox is slow or unreachable

Run `scripts/check-proxmox-api.sh` only from an approved OpenBao-authenticated
operator session. Check the Proxmox endpoint stored at
`secret/infrastructure/proxmox`, cluster health, and internal DNS. Keep all
writes inside the Terrakube workspace.

## State recovery or import

Use a private Terrakube state operation so the workspace lock and audit trail
remain authoritative. Never edit state locally, target an apply, or upload a
state file without the documented production migration approval.

## Provider installation without internet

Terrakube executors use the homelab provider/module mirror configured by the
platform. If initialization attempts public registry access, stop the run and
repair the mirror configuration; do not grant temporary egress.
