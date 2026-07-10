#!/usr/bin/env bash
# Render the ansible_inventory output from OpenTofu, validate it against the
# inventory schema (the CONTRACT — what "complete" means is declared there, not
# here), and on success distribute it UNCHANGED to its consumers, including the
# gitignored copy each Ansible repo reads.
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

# Environment scoping: a develop apply must never overwrite the prod artifacts that the
# Ansible consumers read. Derive the env from the selected input (S3_INVENTORY_KEY), the
# same signal as the mirror path — ONLY the develop object nests its data-repo mirror under
# a develop/ prefix and its own sync branch, and skips warming the prod offline-fallback
# cache entirely; every other key (prod default or a staging candidate) keeps the literals.
SRC_KEY="${S3_INVENTORY_KEY:-deployment.json}"
if [[ "$SRC_KEY" == "deployment.develop.json" ]]; then
  ENV_DEST_PREFIX="develop/"
  SYNC_BRANCH_SUFFIX="-develop"
else
  ENV_DEST_PREFIX=""
  SYNC_BRANCH_SUFFIX=""
fi

GIT_HOME="${GIT_HOME:?GIT_HOME must be set}"
# The contract schema. Defaults to the interim schema; Phase 2 points this at the
# homelab-schemas repo via TOFU_INVENTORY_SCHEMA.
SCHEMA="${TOFU_INVENTORY_SCHEMA:-${GIT_HOME_PUBLIC:-$GIT_HOME/public}/ansible-proxmox-apps/main/tests/inventory_load/tofu_inventory.schema.json}"

# Optional versioned-commit destination: a clone under $GIT_HOME named by the
# INVENTORY_DATA_REPO env var. Unset or absent => this step is skipped.
DATA_REPO_DIR=""
if [[ -n "${INVENTORY_DATA_REPO:-}" ]]; then
  for c in "$GIT_HOME/$INVENTORY_DATA_REPO/main" "$GIT_HOME/$INVENTORY_DATA_REPO"; do
    if git -C "$c" rev-parse --git-dir &>/dev/null; then DATA_REPO_DIR="$c"; break; fi
  done
fi

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT
terragrunt output -json ansible_inventory > "$tmp"

# Gate: valid against the contract or abort, writing nothing. A partial output
# that drops schema-required keys fails here.
nix run nixpkgs#check-jsonschema -- --schemafile "$SCHEMA" "$tmp"

# Versioned commit (terraform-proxmox is the source repo name, not yet
# renamed). Two constraints shape the flow:
#   - `git diff --quiet` reports clean for UNTRACKED files, so change
#     detection uses `git status --porcelain` instead.
#   - Direct pushes to a default branch can be rejected by branch rules, so
#     the commit lands on a sync branch in a throwaway worktree (the clone's
#     checked-out branch is never touched) and a PR is opened with gh, which
#     infers everything it needs from the clone's origin.
dest="tofu/terraform-proxmox/${ENV_DEST_PREFIX}ansible_inventory.json"
if [[ -n "$DATA_REPO_DIR" ]]; then
  sync_branch="chore/inventory-sync${SYNC_BRANCH_SUFFIX}"
  sync_wt="$(mktemp -d)"
  git -C "$DATA_REPO_DIR" fetch -q origin
  git -C "$DATA_REPO_DIR" worktree add -q --force -B "$sync_branch" "$sync_wt" origin/main
  install -Dm644 "$tmp" "$sync_wt/$dest"
  if [[ -n "$(git -C "$sync_wt" status --porcelain -- "$dest")" ]]; then
    git -C "$sync_wt" add "$dest"
    git -C "$sync_wt" -c commit.gpgsign=true commit -qm "chore(inventory): sync ansible_inventory from tofu"
    if git -C "$sync_wt" push -qf origin "$sync_branch"; then
      # Reuses the open sync PR when one exists; creation failure is non-fatal.
      (cd "$sync_wt" && gh pr create --head "$sync_branch" \
        --title "chore(inventory): sync ansible_inventory from tofu" \
        --body "Automated inventory snapshot from terraform-proxmox scripts/sync-inventory.sh." \
        2>/dev/null) || echo "sync-inventory: sync branch pushed; PR already open or gh unavailable" >&2
    else
      echo "sync-inventory: versioned-commit push failed" >&2
    fi
  fi
  git -C "$DATA_REPO_DIR" worktree remove --force "$sync_wt"
else
  echo "sync-inventory: INVENTORY_DATA_REPO unset or clone not found — skipped versioned commit" >&2
fi

# Cache-warming: the gitignored copy each consumer's resolver uses as its
# offline fallback (resolution priority 3, after TOFU_INVENTORY_PATH and the
# S3 artifact). This is the PROD fallback — a develop apply must not overwrite it, so
# skip warming entirely for any non-prod environment (develop consumers pin explicitly).
if [[ -n "$ENV_DEST_PREFIX" ]]; then
  echo "sync-inventory: develop env — skipped prod offline-cache warming" >&2
  exit 0
fi
for repo in ansible-proxmox ansible-proxmox-apps ansible-splunk; do
  for root in "${GIT_HOME_PUBLIC:-}" "$GIT_HOME"; do
    if [[ -n "$root" && -d "$root/$repo/main/inventory" ]]; then
      install -m644 "$tmp" "$root/$repo/main/inventory/tofu_inventory.json"
      break
    fi
  done
done
