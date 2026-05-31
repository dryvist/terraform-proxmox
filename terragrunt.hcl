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
    lan_main  = get_env("NETWORK_CIDR_LAN_MAIN")
    lan_mgmt  = get_env("NETWORK_CIDR_LAN_MGMT")
    dns       = get_env("NETWORK_CIDR_DNS")
    bmc       = get_env("NETWORK_CIDR_BMC")
    compute   = get_env("NETWORK_CIDR_COMPUTE")
    siem      = get_env("NETWORK_CIDR_SIEM")
    pipeline  = get_env("NETWORK_CIDR_PIPELINE")
    data      = get_env("NETWORK_CIDR_DATA")
    ai        = get_env("NETWORK_CIDR_AI")
    apps      = get_env("NETWORK_CIDR_APPS")
    media_svc = get_env("NETWORK_CIDR_MEDIA_SVC")
    homeauto  = get_env("NETWORK_CIDR_HOMEAUTO")
    nonprod   = get_env("NETWORK_CIDR_NONPROD")
  }

  # Layer 3: Doppler env vars — credentials only (API tokens, SSH keys, passwords).
  # SSH credentials for BPG provider file operations.
  # proxmox_ssh_username comes from SOPS (env-specific, not a secret — value is "root").
  proxmox_ssh_user        = try(local.sops_config["proxmox_ssh_username"], get_env("PROXMOX_SSH_USERNAME", "root"))
  proxmox_ssh_private_key = get_env("PROXMOX_SSH_PRIVATE_KEY", "")

  # Fallback defaults from Doppler for values that may vary per environment.
  # These override deployment.json and SOPS via merge() order.
  env_var_defaults = {
    proxmox_node            = get_env("PROXMOX_VE_NODE", "pve")
    proxmox_ssh_private_key = get_env("PROXMOX_SSH_PRIVATE_KEY", "")
    proxmox_ssh_host        = get_env("PROXMOX_VE_HOSTNAME", "")
    # Keep in sync with local.proxmox_ssh_user (SOPS-first, env fallback)
    proxmox_ssh_username    = local.proxmox_ssh_user
  }
}

terraform {
  source = "."

  # Automatically sync ansible_inventory to downstream Ansible repos after every apply.
  # Writes terraform_inventory.json to ansible-proxmox, ansible-proxmox-apps, and ansible-splunk.
  after_hook "sync_inventory" {
    commands     = ["apply"]
    execute      = ["bash", "-c", "INV=$(tofu output -json ansible_inventory) && for repo in ansible-proxmox ansible-proxmox-apps ansible-splunk; do TARGET=\"$HOME/git/$repo/main/inventory/terraform_inventory.json\"; if [ -d \"$(dirname \"$TARGET\")\" ]; then printf \"%s\\n\" \"$INV\" > \"$TARGET\" && echo \"Synced inventory -> $repo\" >&2; else echo \"Skipped $repo (not cloned at ~/git/$repo/main)\" >&2; fi; done"]
    run_on_error = false
  }
}

# Remote state backend configuration using S3 + DynamoDB
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
