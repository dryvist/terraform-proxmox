# Configuration Management Setup

This repository uses a 3-layer architecture for deployment configuration.

## The 3 Layers

```text
LAYER 1: deployment.json (private on-prem `s3` store, NOT committed)
  containers, VMs, pools, template IDs, disk sizes, CPU/memory/tags, proxmox_node

LAYER 2: terraform.sops.json (committed, SOPS-encrypted, 3 values)
  network_prefix, vm_ssh_public_key_path, vm_ssh_private_key_path

LAYER 3: Doppler (runtime env vars, never committed)
  PROXMOX_VE_*, PROXMOX_SSH_*, passwords, API tokens

DERIVED (locals.tf — no input needed):
  management_network = "${network_prefix}.0/24"
  splunk_network     = IPs from splunk_vm_id + containers tagged "splunk"
```

## What Goes Where

| Value | File | Why |
| --- | --- | --- |
| Container/VM definitions | `deployment.json` | Not secret |
| Pool definitions | `deployment.json` | Not secret |
| Template/ISO names | `deployment.json` | Not secret |
| Disk sizes, CPU, memory | `deployment.json` | Not secret |
| `proxmox_node`, `environment` | `deployment.json` | Not secret |
| `network_prefix` | `terraform.sops.json` | Reveals internal network range |
| `vm_ssh_public_key_path` | `terraform.sops.json` | SSH key filesystem path |
| `vm_ssh_private_key_path` | `terraform.sops.json` | SSH key filesystem path |
| `management_network` | **Derived** in `locals.tf` | `= "${network_prefix}.0/24"` |
| `splunk_network` | **Derived** in `locals.tf` | From `splunk_vm_id` + splunk-tagged containers |
| API tokens, SSH key content | Doppler | Actual credentials |
| Passwords | Doppler | Actual credentials |

## The Run Command

One command — always this, always both:

```bash
aws-vault exec tf-proxmox -- doppler run -- terragrunt plan
```

Terragrunt fetches `deployment.json` automatically from the on-prem `s3` store
(via the Doppler `S3_*` creds). Terragrunt decrypts `terraform.sops.json`
automatically. Doppler injects credentials. No extra flags needed.

## Setting Up Layer 1: deployment.json

Private desired-state input — see
[the source-of-truth rule](../agentsmd/rules/infra/deployment-json-source-of-truth.md)
for where it lives and why. Bucket and key default to `S3_INVENTORY_BUCKET` /
`S3_INVENTORY_KEY` in `terragrunt.hcl`; export those (or substitute the values) to
read/edit it. Never `git add deployment.json` (it is gitignored).

```bash
obj="s3://$S3_INVENTORY_BUCKET/$S3_INVENTORY_KEY"
aws --endpoint-url "$S3_ENDPOINT" s3 cp "$obj" deployment.json   # fetch
$EDITOR deployment.json
nix run nixpkgs#check-jsonschema -- --schemafile deployment.schema.json deployment.json  # validate
aws --endpoint-url "$S3_ENDPOINT" s3 cp deployment.json "$obj"   # upload (versioned)
```

The committed `deployment.json.example` is the shape reference only.

## Setting Up Layer 2: terraform.sops.json

`terraform.sops.json` is committed but SOPS-encrypted. It holds only 3 values:
`network_prefix`, `vm_ssh_public_key_path`, `vm_ssh_private_key_path`.

### One-Time Key Setup

SOPS and age are provided by the Nix terraform shell. No manual installation needed.

Generate an age keypair (once per machine):

```bash
mkdir -p ~/.config/sops/age
age-keygen -o ~/.config/sops/age/keys.txt
```

> **Exploratory (not implemented):** a proposal would give the age **private**
> key a portable, backed-up home in **Proton Pass**
> (`pass://infra/sops-age/keys.txt`) so SOPS decryption works on Linux/cloud
> agents (not just macOS), materialized by `./scripts/secrets-bootstrap.sh`. See
> [PROTON_PASS_STRATEGY.md](./PROTON_PASS_STRATEGY.md). Until adopted, set the key
> up per host with `age-keygen` as above.

Note the public key printed to stdout (starts with `age1...`).

Update `.sops.yaml` with your public key:

```yaml
creation_rules:
  - path_regex: \.sops\.json$
    age: "age1your-actual-public-key"
```

### Creating Your SOPS File

```bash
# Start from the example
cp terraform.sops.json.example terraform.sops.json

# Fill in your network prefix and SSH key paths
$EDITOR terraform.sops.json

# Encrypt in-place — safe to commit after this
sops --encrypt --in-place terraform.sops.json

# Add to git
git add terraform.sops.json
```

### Editing Encrypted Values

```bash
# Opens in $EDITOR, decrypts for editing, re-encrypts on save
sops terraform.sops.json
```

## Layer 3: Doppler (no setup needed here)

Doppler provides all credentials via environment variables. See your local environment
documentation for Doppler project/config details.

| Secret | Purpose |
| --- | --- |
| `PROXMOX_VE_ENDPOINT` | API URL |
| `PROXMOX_VE_API_TOKEN` | API token |
| `PROXMOX_VE_INSECURE` | Skip TLS verification |
| `PROXMOX_SSH_PRIVATE_KEY` | SSH private key content for BPG provider |
| `SPLUNK_PASSWORD` | Splunk admin password |
| `SPLUNK_HEC_TOKEN` | Splunk HEC token |

## Key Rotation

To re-encrypt the SOPS file with a new age key:

1. Generate the new keypair (`age-keygen -o ~/.config/sops/age/keys.txt`).
2. Update `.sops.yaml` with the new public key.
3. Run `sops updatekeys terraform.sops.json` to re-encrypt with the new key.
4. Commit both the re-encrypted `terraform.sops.json` and updated `.sops.yaml`.
5. Distribute the new private key to other hosts by your usual secure means.

> **Exploratory (not implemented):** if the Proton Pass proposal is adopted,
> steps 1 and 5 would instead store the private key at
> `pass://infra/sops-age/keys.txt` and other hosts would pick it up via
> `./scripts/secrets-bootstrap.sh` (removing any stale local `keys.txt` first).
> See [PROTON_PASS_STRATEGY.md](./PROTON_PASS_STRATEGY.md).

## Security Notes

- The age private key (`keys.txt`) must **never** be committed to git (an
  exploratory proposal would give it a portable home in Proton Pass —
  `pass://infra/sops-age/keys.txt`, materialized by
  `./scripts/secrets-bootstrap.sh`; not yet implemented)
- The `.sops.yaml` file contains only the **public** key (safe to commit)
- `terraform.sops.json` is safe to commit once encrypted (values are ciphertext)
- `deployment.json` is **not committed** — it is the private input in the on-prem
  `s3` store (see "Setting Up Layer 1" above)
- `management_network` and `splunk_network` are derived from other values — never set manually
