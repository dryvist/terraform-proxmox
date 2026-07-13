# Native Inventory Publishing

Every full `tofu-proxmox` apply publishes `local.ansible_inventory` to
`s3://iac-inventory/ansible_inventory.json` on homelab RustFS through the
`aws_s3_object` resource. The RustFS provider credentials come from the native
OpenBao object-storage path and remain ephemeral.

The publish is part of the OpenTofu graph, not an after-hook. Preconditions
reject incomplete container and ingress records before the object is written.
Downstream Ansible repositories read the versioned object with scoped native
OpenBao credentials and retain their local cache only as an offline fallback.

Never use a targeted apply: excluding the publisher could leave consumers on
an older contract. A full Terrakube workspace run is the only publish boundary.

During migration, the former AWS inventory object is intentionally forgotten
without destruction. Retire that orphan only after every consumer proves the
RustFS path through its end-to-end validation.
