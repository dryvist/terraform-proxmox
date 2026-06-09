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

The published object reflects the **last apply**. Editing `deployment.json`
without applying changes nothing downstream — `apply` is the only publish point.
This makes `apply` the single, auditable way to change what every consumer sees.

## Relationship to `scripts/sync-inventory.sh`

The S3 publish is **native Terraform**. The existing after-hook
(`scripts/sync-inventory.sh`) is unchanged and still handles the two
distribution targets Terraform cannot: the schema-validated versioned commit
into the private `int_homelab` repo, and the local gitignored copies for
development.

## IAM

The credentials used for `apply` need `s3:PutObject` (and `s3:GetObject` for
plan refresh) on `…/terraform-proxmox/inventory/*`; each consumer needs
`s3:GetObject` on the same key. If the state bucket policy scopes access to the
`terraform.tfstate` key only, widen it to the `terraform-proxmox/` prefix (or
the `inventory/` sub-prefix) for these objects.

## Consuming the inventory

Consumers fetch the raw object and adapt it. Example
(`ansible-proxmox`'s `playbooks/load_tofu.yml` resolver):

1. `TOFU_INVENTORY_PATH` — explicit local file.
2. S3 artifact — fetched with the `aws` CLI (URI from `TOFU_INVENTORY_S3_URI`
   or derived from the account).
3. `inventory/tofu_inventory.json` — local cache.

A consumer needs only AWS read creds for option 2 — no repo checkout and no
terraform/terragrunt toolchain.
