# Terragrunt configuration for Proxmox infrastructure

locals {
  # Layer 1: Non-secret deployment config (committed plaintext — edit directly, no SOPS).
  # Contains container/VM definitions, pool names, Splunk VM sizing, template IDs, etc.
  deployment_config = try(jsondecode(file("${get_terragrunt_dir()}/deployment.json")), {})

  # Strip any "_"-prefixed key: deployment.json uses "_comment" / "_*_comment"
  # keys for inline documentation (JSON has no comment syntax). These are not
  # Terraform variables and must not be passed as inputs.
  deployment_inputs = {
    for k, v in local.deployment_config : k => v
    if !startswith(k, "_")
  }

  # Layer 2: Network topology + SSH paths (committed, SOPS-encrypted — edit with `sops terraform.sops.json`).
  # Values: domain, vm_ssh_public_key_path, vm_ssh_private_key_path, proxmox_ssh_username.
  # Per-VLAN CIDRs come from Doppler (local.network_cidrs below), not SOPS.
  # management_network and splunk_network are DERIVED in locals.tf — never stored here.
  sops_config = fileexists("${get_terragrunt_dir()}/terraform.sops.json") ? jsondecode(sops_decrypt_file("${get_terragrunt_dir()}/terraform.sops.json")) : {}

  sops_inputs = {
    for k, v in local.sops_config : k => v
    if k != "_comment"
  }

  # Per-VLAN network CIDRs are SENSITIVE and live only in Doppler
  # (NETWORK_CIDR_<KEY>, network-form like 192.168.20.0/24 — a fake RFC2544 doc
  # example; real subnets live ONLY in Doppler). No default: a missing
  # key fails loudly instead of silently selecting a wrong subnet. Canonical and
  # shared one-way with terraform-unifi — single source, no magic numbers.
  network_cidrs = {
    lan_main = get_env("NETWORK_CIDR_LAN_MAIN")
    mgmt     = get_env("NETWORK_CIDR_MGMT")
    # Native/untagged Management subnet (gateway + DNS servers). No vlan_ids entry
    # => NICs on this key are untagged (native VLAN), matching haproxy/Technitium.
    mgmt_native = get_env("NETWORK_CIDR_LAN_MGMT")
    dns         = get_env("NETWORK_CIDR_DNS")
    bmc         = get_env("NETWORK_CIDR_BMC")
    compute     = get_env("NETWORK_CIDR_COMPUTE")
    siem        = get_env("NETWORK_CIDR_SIEM")
    pipeline    = get_env("NETWORK_CIDR_PIPELINE")
    data        = get_env("NETWORK_CIDR_DATA")
    ai          = get_env("NETWORK_CIDR_AI")
    apps        = get_env("NETWORK_CIDR_APPS")
    media_svc   = get_env("NETWORK_CIDR_MEDIA_SVC")
    homeauto    = get_env("NETWORK_CIDR_HOMEAUTO")
    nonprod     = get_env("NETWORK_CIDR_NONPROD")
  }

  # Layer 3: Doppler env vars — credentials only (API tokens, SSH keys, passwords).
  # SSH credentials for BPG provider file operations.
  # proxmox_ssh_username comes from SOPS (env-specific, not a secret — value is "root").
  proxmox_ssh_user        = try(local.sops_config["proxmox_ssh_username"], get_env("PROXMOX_SSH_USERNAME", "root"))
  proxmox_ssh_private_key = get_env("PROXMOX_SSH_PRIVATE_KEY", "")

  # Fallback defaults from Doppler for values that may vary per environment.
  # These override deployment.json and SOPS via merge() order.
  env_var_defaults = {
    proxmox_node            = get_env("PROXMOX_VE_NODE", "proxmox-1")
    proxmox_ssh_private_key = get_env("PROXMOX_SSH_PRIVATE_KEY", "")
    proxmox_ssh_host        = get_env("PROXMOX_VE_HOSTNAME", "")
    # Keep in sync with local.proxmox_ssh_user (SOPS-first, env fallback)
    proxmox_ssh_username = local.proxmox_ssh_user
  }
}

terraform {
  source = "."

  # Contention: automated runs (agents, hooks, parallel sessions) collide on the
  # state lock and fail instantly with "Error acquiring the state lock". Make
  # every locking command WAIT for the holder instead — 10m comfortably covers
  # a full apply + after-hook. get_terraform_commands_that_need_locking() is the
  # terragrunt-canonical command list for exactly this.
  extra_arguments "state_lock_timeout" {
    commands  = get_terraform_commands_that_need_locking()
    arguments = ["-lock-timeout=10m"]
  }

  # Render, VALIDATE, then distribute ansible_inventory to its consumers after
  # every apply (see scripts/sync-inventory.sh), including the transitional
  # gitignored copy each Ansible repo reads today. A partial/invalid output (e.g.
  # from a `-target` apply, where replace-pending media containers drop whole
  # sections) is REJECTED and nothing is written — the guard the previous inline
  # one-liner lacked. Logic lives in scripts/sync-inventory.sh (no-scripts rule).
  after_hook "sync_inventory" {
    commands     = ["apply"]
    execute      = ["bash", "${get_terragrunt_dir()}/scripts/sync-inventory.sh"]
    run_on_error = false
  }
}

# Remote state backend configuration using S3 + DynamoDB.
# Locking is belt-and-suspenders: use_lockfile (S3-native, tofu >= 1.10) AND the
# legacy DynamoDB table — both are acquired. Dropping the DynamoDB leg would
# force a backend re-init for no contention benefit; revisit when terragrunt is
# removed (#353). Lock WAITING (the contention fix) is the -lock-timeout
# extra_arguments above, not the backend config.
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "terraform-proxmox-state-useast2-${get_aws_account_id()}"
    key            = "terraform-proxmox/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    use_lockfile   = true
    dynamodb_table = "terraform-proxmox-locks-useast2"

    # Retry configuration for transient S3/DynamoDB failures
    max_retries = 5
  }
}

# Merge order: deployment.json < SOPS < Doppler-derived (network_cidrs + env defaults).
# Later entries win for the same key.
inputs = merge(
  local.deployment_inputs,
  local.sops_inputs,
  { network_cidrs = local.network_cidrs },
  local.env_var_defaults,
)

# Generate provider.tf — SSH credentials from Doppler env vars.
# Provider version constraints live solely in main.tf (single source of truth);
# this block intentionally declares no required_providers to avoid drift.
# BPG provider reads API auth (endpoint, token) from PROXMOX_VE_* env vars set by Doppler.
generate "provider" {
  path      = "provider_override.tf"
  if_exists = "overwrite"
  contents  = <<EOF
# BPG provider reads API auth from PROXMOX_VE_* env vars (set by Doppler).
# See: https://registry.terraform.io/providers/bpg/proxmox/latest/docs
provider "proxmox" {
  ssh {
    agent       = false
    username    = "${local.proxmox_ssh_user}"
    private_key = <<-SSHKEY
${local.proxmox_ssh_private_key}
SSHKEY
  }
}
EOF
}
