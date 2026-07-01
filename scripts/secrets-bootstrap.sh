#!/usr/bin/env bash
# Materialize "secret-zero" from Proton Pass (the root-of-trust) onto the current
# host so the rest of the toolchain works — most importantly the SOPS age private
# key, which has no other portable home and which Linux cloud agents otherwise
# lack entirely.
#
# This is the BOOTSTRAP layer that runs BEFORE the usual wrapper. It does not
# touch runtime credentials (Doppler still injects those) and writes nothing to
# git. It is idempotent: an existing key is left untouched, never clobbered.
#
#   Tier 0 (Proton Pass)  ->  this script  ->  ~/.config/sops/age/keys.txt
#                                            ->  SOPS decrypt works on any host
#
# References are resolved from .proton-pass.refs.json (committed, paths only — no
# secret values). See docs/PROTON_PASS_STRATEGY.md.
#
# Manual run:  ./scripts/secrets-bootstrap.sh
# Full flow:   ./scripts/secrets-bootstrap.sh && \
#                aws-vault exec tf-proxmox -- doppler run -- terragrunt plan
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
cd "$REPO_ROOT"

REFS_FILE="${PROTON_PASS_REFS:-$REPO_ROOT/.proton-pass.refs.json}"
AGE_KEY_PATH="${SOPS_AGE_KEY_FILE:-$HOME/.config/sops/age/keys.txt}"

# Hard requirements — fail loudly, like the ${VAR:?} guards in sync-inventory.sh.
command -v pass >/dev/null 2>&1 || {
  echo "secrets-bootstrap: Proton Pass CLI ('pass') not found on PATH." >&2
  echo "  Install: https://protonpass.github.io/pass-cli/get-started/installation/" >&2
  exit 1
}
command -v jq >/dev/null 2>&1 || { echo "secrets-bootstrap: 'jq' not found (provided by the Nix shell)." >&2; exit 1; }
[[ -f "$REFS_FILE" ]] || { echo "secrets-bootstrap: refs manifest not found: $REFS_FILE" >&2; exit 1; }

# Read a pass:// reference for a logical secret-zero name from the manifest.
ref_for() { jq -er --arg k "$1" '.references[$k] // empty' "$REFS_FILE"; }

# --- age private key: the one item that unblocks SOPS on non-macOS hosts -------
if [[ -f "$AGE_KEY_PATH" ]]; then
  echo "secrets-bootstrap: age key already present at $AGE_KEY_PATH — leaving untouched." >&2
else
  age_ref="$(ref_for sops_age_key || true)"
  [[ -n "$age_ref" ]] || { echo "secrets-bootstrap: no 'sops_age_key' reference in $REFS_FILE" >&2; exit 1; }
  mkdir -p "$(dirname "$AGE_KEY_PATH")"
  # umask 077 so the key file is created 0600 from the start; secret never echoed.
  ( umask 077 && pass read "$age_ref" > "$AGE_KEY_PATH" )
  chmod 0600 "$AGE_KEY_PATH"
  echo "secrets-bootstrap: wrote age key to $AGE_KEY_PATH (mode 0600)." >&2
fi

# --- additional secret-zero (optional) -----------------------------------------
# Extend here as Tier 2/4 land — e.g. export OpenBao approle or AWS bootstrap from
# their references. Kept minimal for PR-1; nothing else is required to make SOPS
# and the existing wrapper work cross-platform.

echo "secrets-bootstrap: done." >&2
