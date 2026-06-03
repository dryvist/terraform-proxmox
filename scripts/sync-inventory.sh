#!/usr/bin/env bash
# Render the ansible_inventory output from OpenTofu, validate it against the
# inventory schema (the CONTRACT — what "complete" means is declared there, not
# here), and on success distribute it UNCHANGED: a versioned commit into the
# private int_homelab repo, plus the gitignored copy each Ansible repo reads.
#
# The sync deliberately adds no interpretation of its own — shape comes from the
# tofu output declarations, meaning comes from the consuming Ansible repos, and
# "is this complete" comes from the schema. A partial output (e.g. from a
# `-target` apply) fails the schema, so nothing is written — the guard the old
# inline after_hook lacked.
#
# Manual run: aws-vault exec tf-proxmox -- doppler run -- ./scripts/sync-inventory.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

GIT_HOME="${GIT_HOME:?GIT_HOME must be set}"
# The contract schema. Defaults to the interim schema; Phase 2 points this at the
# homelab-schemas repo via TOFU_INVENTORY_SCHEMA.
SCHEMA="${TOFU_INVENTORY_SCHEMA:-${GIT_HOME_PUBLIC:-$GIT_HOME/public}/ansible-proxmox-apps/main/tests/inventory_load/tofu_inventory.schema.json}"

# Locate the private int_homelab data repo (bare+worktree or plain clone).
INT_HOMELAB="${INT_HOMELAB_DIR:-}"
if [[ -z "$INT_HOMELAB" ]]; then
  for c in "$GIT_HOME/int_homelab/main" "$GIT_HOME/int_homelab"; do
    if git -C "$c" rev-parse --git-dir &>/dev/null; then INT_HOMELAB="$c"; break; fi
  done
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
terragrunt output -json ansible_inventory > "$tmp"

# Gate: valid against the contract or abort, writing nothing. A partial output
# that drops schema-required keys fails here.
nix run nixpkgs#check-jsonschema -- --schemafile "$SCHEMA" "$tmp"

# Versioned commit into the private int_homelab data repo (terraform-proxmox is
# the source repo name, not yet renamed).
dest="tofu/terraform-proxmox/ansible_inventory.json"
if [[ -n "$INT_HOMELAB" ]]; then
  install -Dm644 "$tmp" "$INT_HOMELAB/$dest"
  if ! git -C "$INT_HOMELAB" diff --quiet -- "$dest" 2>/dev/null; then
    git -C "$INT_HOMELAB" add "$dest"
    git -C "$INT_HOMELAB" -c commit.gpgsign=true commit -qm "chore(inventory): sync ansible_inventory from tofu"
    git -C "$INT_HOMELAB" push -q || echo "sync-inventory: committed to int_homelab but push failed" >&2
  fi
else
  echo "sync-inventory: int_homelab clone not found under $GIT_HOME — skipped versioned commit" >&2
fi

# Transitional: the gitignored copy each Ansible repo reads until Phase 2 points
# them at int_homelab.
for repo in ansible-proxmox ansible-proxmox-apps ansible-splunk; do
  for root in "${GIT_HOME_PUBLIC:-}" "$GIT_HOME"; do
    if [[ -n "$root" && -d "$root/$repo/main/inventory" ]]; then
      install -m644 "$tmp" "$root/$repo/main/inventory/tofu_inventory.json"
      break
    fi
  done
done
