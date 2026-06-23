# Inventory Publishing

The Ansible inventory is published to the terragrunt S3 backend **natively** —
an `aws_s3_object` resource (`inventory_publish.tf`), not a script. `terragrunt
apply` is the publish boundary: when the inventory content changes, Terraform
uploads the object as part of the apply.

```hcl
resource "aws_s3_object" "ansible_inventory" {
  bucket       = "terraform-proxmox-state-useast2-${data.aws_caller_identity.current.account_id}"
  key          = "terraform-proxmox/inventory/ansible_inventory.json"
  content      = jsonencode(local.ansible_inventory)
  content_type = "application/json"
}
```

- The AWS provider uses the **same ambient credential chain as the S3 state
  backend** (aws-vault locally, OIDC in CI) — no static keys, no `aws` CLI.
- The object content is `jsonencode(local.ansible_inventory)` — the same value
  as the `ansible_inventory` output. Consumers adapt the shape to their needs.
- The resource updates only when the content changes, and only when it is in
  scope: a `-target` apply that excludes it does **not** republish a partial
  inventory.

## Why S3

The inventory contains real node names, IPs, and pool names, so it cannot be
committed to a public repo. The terragrunt **state backend bucket already
exists** and is access-controlled, so it is the natural cloud-reachable source:
GitHub Actions assume a read role via OIDC, cloud agents use a scoped read role,
and `aws-vault` covers local use — all fetch the same object with no checkout
and no terraform toolchain.

## Freshness contract

The published object reflects the **last apply**. Updating `deployment.json` (the
private desired-state INPUT, which lives in the on-prem `s3` store at
`s3://iac-inventory/deployment.json`, not in this repo) without applying changes
nothing downstream — `apply` is the only publish point. This makes `apply` the
single, auditable way to change what every consumer sees.

## Relationship to `scripts/sync-inventory.sh`

The S3 publish is **native Terraform**. The after-hook
(`scripts/sync-inventory.sh`) handles only what Terraform cannot: the
versioned-mirror PR into the private data repo (gated on the
`INVENTORY_DATA_REPO` env var) and cache-warming — the local gitignored
`tofu_inventory.json` each consumer's resolver uses as its offline fallback.

## IAM

The credentials used for `apply` need `s3:PutObject` (and `s3:GetObject` +
`s3:GetObjectTagging` for plan refresh) on `…/terraform-proxmox/inventory/*`
(the `tf-proxmox` role carries these via the `s3-inventory-publish` inline
policy); each consumer needs `s3:GetObject` on the same key.

## Consuming the inventory

Every consumer resolves the same way (each repo's `load_tofu.yml`):

1. `TOFU_INVENTORY_PATH` — explicit local file (pin / tests / overrides).
2. S3 artifact — fetched natively with `amazon.aws.s3_object` (URI from
   `TOFU_INVENTORY_S3_URI` or derived from the account via
   `amazon.aws.aws_caller_info`; region `TOFU_INVENTORY_S3_REGION`,
   default `us-east-2`); no `aws` CLI needed.
3. `inventory/tofu_inventory.json` — local cache (written by the after-hook).

A consumer needs only AWS read creds for option 2 — no repo checkout and no
terraform/terragrunt toolchain.

| Consumer | Resolver | Notes |
| --- | --- | --- |
| `ansible-proxmox` | `playbooks/load_tofu.yml` | host_services, node_storage, nodes |
| `ansible-proxmox-apps` | `inventory/load_tofu.yml` | containers, docker_vms, constants, ingress |
| `ansible-splunk` | `inventory/load_tofu.yml` | splunk_vm; static fallback `SPLUNK_VM_HOST` else DNS-first `splunk-aio.{PROXMOX_DOMAIN}` |

## Addressing: the inventory carries identity, DNS carries reachability

The artifact stays authoritative for **identity and topology** — VMIDs, tags,
ports, node placement, storage — which DNS cannot carry. Addresses, however,
trend DNS-first: `dhcp: true` guests publish `{hostname}.{domain}` as their
inventory `ip` (see `container_address` in `locals.tf`), and Technitium serves
A-records derived from this same inventory. Invariants:

- **Bootstrap-pinned hosts stay static-IP forever**: the DNS containers
  (technitium-dns, pi-hole), the Proxmox nodes, and the Splunk VM — everything
  that must be reachable before DNS works.
- Everything else migrates to `dhcp: true` under the VMID/tier convention;
  its address self-heals via DHCP+DNS even if a consumer's inventory copy lags.
- A consumer that only needs to *reach a service* (not configure hosts) should
  use the FQDN and skip the inventory fetch entirely.
