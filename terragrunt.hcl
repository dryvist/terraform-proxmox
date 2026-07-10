# Terragrunt configuration for Proxmox infrastructure

locals {
  # Layer 1: private desired-state INPUT, fetched from the on-prem S3-compatible
  # object store (endpoint + creds come from Doppler S3_*). NOT committed and NOT
  # git-versioned by design — the single shared home is the versioned object, so
  # every session/agent reads the same authoritative copy with no local drift.
  # Bucket / key / region are parameterized: the preferred value is the default
  # here, overridable per environment via env without editing this file (and the
  # endpoint/creds never appear in-repo — they live in Doppler S3_*). NOTE: this
  # store is NOT the AWS S3 tfstate backend (remote_state below); they never share
  # a credential (AWS_* from aws-vault for state vs S3_* for this fetch).
  # DEPLOYMENT_JSON_PATH overrides with a local file for offline / bootstrap work.
  # FAIL-LOUD: a missing object makes the fetch exit non-zero so run_cmd raises — a
  # blank input can never silently become {} and plan a full destroy (no try()).
  s3_inventory_bucket = get_env("S3_INVENTORY_BUCKET", "iac-inventory")
  s3_inventory_key    = get_env("S3_INVENTORY_KEY", "deployment.json")
  s3_inventory_region = get_env("S3_INVENTORY_REGION", "us-east-1")

  # HA fetch failover: the desired-state INPUT is no longer a single-store SPOF.
  # PRIMARY  = the on-prem RustFS object store (S3_* creds, private endpoint).
  # FALLBACK = an AWS-S3 mirror in the same versioned state bucket that holds the
  #            published inventory (ambient AWS creds — aws-vault locally / OIDC in
  #            CI — the SAME chain as remote_state, NOT the S3_* creds). Refreshed
  #            after every apply by scripts/mirror-deployment-json.sh (the
  #            mirror_deployment_json after_hook below). If on-prem is unreachable,
  #            the fetch transparently reads the AWS mirror, so a RustFS outage no
  #            longer blocks plan/apply. FAIL-LOUD preserved: only if BOTH stores
  #            fail (or return empty) does the command exit non-zero and run_cmd
  #            raise — never a silent {} that would plan a full destroy.
  s3_mirror_bucket = "terraform-proxmox-state-useast2-${get_aws_account_id()}"
  # The AWS mirror path tracks the EXPLICITLY-selected input (S3_INVENTORY_KEY), not the
  # object's `environment` field: the fallback runs mid-fetch, before the object (and its
  # environment) can be read, so deriving from the decoded env would be a dependency cycle.
  # ONLY the develop object nests under input/develop/; every other key (prod default, or a
  # staging candidate) keeps the current prod literal so its mirror never moves.
  # ponytail: two-env branch; generalize to a stem-map when a third input appears.
  s3_mirror_key = local.s3_inventory_key == "deployment.develop.json" ? "terraform-proxmox/input/develop/deployment.json" : "terraform-proxmox/input/deployment.json"
  deployment_json = (
    get_env("DEPLOYMENT_JSON_PATH", "") != ""
    ? file(get_env("DEPLOYMENT_JSON_PATH"))
    : run_cmd(
      "--terragrunt-quiet", "bash", "-c",
      <<-FETCH
        set -o pipefail
        # PRIMARY: on-prem RustFS in a subshell so its unset/S3_* env never leaks
        # into the AWS-credentialed fallback below.
        if primary=$( (
          unset AWS_PROFILE AWS_SESSION_TOKEN
          AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
          AWS_REGION=${local.s3_inventory_region} \
          aws --endpoint-url "$S3_ENDPOINT" \
            s3 cp "s3://${local.s3_inventory_bucket}/${local.s3_inventory_key}" - --quiet
        ) 2>/dev/null ) && [ -n "$primary" ]; then
          printf '%s' "$primary"
        else
          # FALLBACK: AWS-S3 mirror with the ambient credential chain. A failure
          # here exits non-zero (last command) -> run_cmd raises. FAIL-LOUD.
          echo "deployment.json: on-prem fetch failed, reading AWS-S3 mirror" >&2
          AWS_REGION=us-east-2 aws --region us-east-2 \
            s3 cp "s3://${local.s3_mirror_bucket}/${local.s3_mirror_key}" - --quiet
        fi
      FETCH
    )
  )
  deployment_config = jsondecode(trimspace(local.deployment_json))

  # Environment selector: the fetched input declares its own identity in `environment`,
  # and the state key derives from THAT field (the authority that travels with the data),
  # so staging a prod candidate under a temp key still targets prod state.
  deployment_env_raw = local.deployment_config.environment

  # Safety cross-check (the load-bearing invariant): the explicitly-selected input
  # (S3_INVENTORY_KEY) and the object's declared `environment` MUST agree, or a mislabeled
  # object could point develop guests at PRODUCTION state. `deployment.develop.json` must
  # carry `environment: develop`; any other key (prod default or a staging candidate) must
  # carry `environment: homelab`. This one-key map — keyed by the filename's EXPECTED env,
  # indexed by the object's ACTUAL env — raises (no try(), same fail-loud contract as the
  # fetch) on ANY mismatch, which also enforces the {homelab,develop} allowlist.
  input_expected_env = local.s3_inventory_key == "deployment.develop.json" ? "develop" : "homelab"
  deployment_env = {
    (local.input_expected_env) = local.deployment_env_raw
  }[local.deployment_env_raw]

  # Production ("homelab") pins the state key to today's EXACT literal so a prod plan never
  # migrates state; develop nests under its own prefix (separate key => separate S3/DynamoDB
  # lock, so envs never collide). The published inventory key derives symmetrically from
  # var.environment in inventory_publish.tf.
  # ponytail: two-env map; add the env + its state prefix here when a third one appears.
  s3_state_key = {
    homelab = "terraform-proxmox/terraform.tfstate"
    develop = "terraform-proxmox/develop/terraform.tfstate"
  }[local.deployment_env]

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

  # Parameterized generated infrastructure. The private deployment.json keeps
  # shared OpenBao defaults once under openbao_cluster, and this expands them
  # into normal container inputs before Terraform sees the map.
  openbao_cluster         = try(local.deployment_config.openbao_cluster, {})
  openbao_cluster_enabled = try(local.openbao_cluster.enabled, false)
  openbao_cluster_peers = local.openbao_cluster_enabled ? flatten([
    for node_name, suffixes in local.openbao_cluster.placement : [
      for suffix in suffixes : {
        node_name = node_name
        suffix    = suffix
      }
    ]
  ]) : []
  openbao_generated_containers = local.openbao_cluster_enabled ? {
    for peer in local.openbao_cluster_peers :
    format("%s%02d", try(local.openbao_cluster.name_prefix, "openbao-"), peer.suffix) => merge(
      try(local.openbao_cluster.container_defaults, {}),
      {
        vm_id     = try(local.openbao_cluster.vm_id_base, 110000) + peer.suffix
        vlan      = local.openbao_cluster.vlan
        hostname  = format("%s%02d", try(local.openbao_cluster.name_prefix, "openbao-"), peer.suffix)
        node_name = peer.node_name
        ip_config = {
          ipv4_address = format(
            "%s/%s",
            cidrhost(local.network_cidrs[local.openbao_cluster.vlan], peer.suffix),
            split("/", local.network_cidrs[local.openbao_cluster.vlan])[1],
          )
        }
        root_disk = {
          size         = tonumber(local.openbao_cluster.root_disk.size)
          datastore_id = try(local.openbao_cluster.root_disk_datastore_by_node[peer.node_name], try(local.openbao_cluster.root_disk.datastore_id, null))
        }
      }
    )
  } : {}

  # Strip any "_"-prefixed key: deployment.json uses "_comment" / "_*_comment"
  # keys for inline documentation (JSON has no comment syntax). These are not
  # Terraform variables and must not be passed as inputs. openbao_cluster is a
  # Terragrunt-side generator input, not a Terraform variable.
  deployment_inputs_base = {
    for k, v in local.deployment_config : k => v
    if !startswith(k, "_") && !contains(["containers", "openbao_cluster"], k)
  }
  deployment_inputs = merge(
    local.deployment_inputs_base,
    {
      containers = merge(
        try(local.deployment_config.containers, {}),
        local.openbao_generated_containers,
      )
    }
  )

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

  # Refresh the AWS-S3 mirror of the desired-state INPUT (deployment.json) after
  # every successful apply, so the fetch-failover fallback above always has a
  # current copy if the on-prem RustFS is later unreachable. Best-effort: the
  # script warns and exits 0 on a mirror hiccup so a transient S3 blip never fails
  # an otherwise-good apply (the prior mirror copy simply persists). Logic lives in
  # scripts/mirror-deployment-json.sh (no-inline-scripts rule).
  after_hook "mirror_deployment_json" {
    commands     = ["apply"]
    execute      = ["bash", "${get_terragrunt_dir()}/scripts/mirror-deployment-json.sh"]
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
    key            = local.s3_state_key
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
