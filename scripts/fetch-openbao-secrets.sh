#!/usr/bin/env bash
# Fetch a resource-domain's secrets from OpenBao and export them as plain
# environment variables, then exec the wrapped command.
#
# KEEP IN SYNC with ansible-proxmox-apps/scripts/fetch-openbao-secrets.sh —
# same script, two repos (no shared-script mechanism between them yet). If you
# change one, change both.
#
# This is a drop-in link in the SAME chain as `doppler run --` — it sits
# between it and whatever it wraps, and does exactly the same job: get
# secrets into the process environment before the wrapped command starts.
# Nothing downstream (a Terraform `TF_VAR_x`, a CI step) can tell OpenBao was
# involved at all — swap this script for a different one and the config is
# unchanged.
#
# Usage:
#   fetch-openbao-secrets.sh <domain> -- <command> [args...]
#
# Reads from its OWN environment (supplied by whatever already-established
# secret-zero layer wraps this script — Doppler today):
#   BAO_ADDR                      - OpenBao API endpoint
#   <DOMAIN>_VAULT_ROLE_ID        - AppRole role_id for this domain
#   <DOMAIN>_VAULT_SECRET_ID      - AppRole secret_id for this domain
# <DOMAIN> is the domain name, uppercased, hyphens turned to underscores
# (e.g. "media" -> MEDIA) — matching the naming the ansible-proxmox-apps
# roles/openbao_secrets role already uses for the same AppRoles.
#
# Discovers this domain's secret paths by LISTing secret/metadata/apps/<domain>
# (the media AppRole's policy already grants read+list on that subtree) rather
# than hardcoding a path list here — one fewer thing to keep in sync as new
# app KV entries are added under a domain.
#
# SKIPS CLEANLY: if BAO_ADDR or this domain's role_id/secret_id envs are
# unset, this is a no-op passthrough (execs the wrapped command unmodified).

set -euo pipefail

usage() {
  echo "Usage: $0 <domain> -- <command> [args...]" >&2
  exit 1
}

[[ $# -lt 1 ]] && usage
domain="$1"
shift
[[ ${1:-} == "--" ]] || usage
shift
[[ $# -lt 1 ]] && usage

domain_env=$(printf '%s' "$domain" | tr '[:lower:]-' '[:upper:]_')

role_id_var="${domain_env}_VAULT_ROLE_ID"
secret_id_var="${domain_env}_VAULT_SECRET_ID"
role_id="${!role_id_var:-}"
secret_id="${!secret_id_var:-}"

if [[ -z "${BAO_ADDR:-}" || -z "$role_id" || -z "$secret_id" ]]; then
  # Not configured for this domain yet — pass through unchanged.
  exec "$@"
fi

login_resp=$(curl -sS -m 10 -X POST \
  -d "{\"role_id\":\"$role_id\",\"secret_id\":\"$secret_id\"}" \
  "$BAO_ADDR/v1/auth/approle/login")
client_token=$(printf '%s' "$login_resp" | jq -r '.auth.client_token // empty')
unset login_resp role_id secret_id

if [[ -z "$client_token" ]]; then
  echo "fetch-openbao-secrets.sh: AppRole login failed for domain '$domain' — refusing to run with a possibly-stale environment. Check ${role_id_var}/${secret_id_var}." >&2
  exit 1
fi

list_resp=$(curl -sS -m 10 -H "X-Vault-Token: $client_token" -X LIST \
  "$BAO_ADDR/v1/secret/metadata/apps/$domain")
mapfile -t keys < <(printf '%s' "$list_resp" | jq -r '.data.keys[]? // empty')
unset list_resp

if [[ ${#keys[@]} -eq 0 ]]; then
  echo "fetch-openbao-secrets.sh: no secrets found under apps/$domain — continuing with the existing environment unchanged." >&2
fi

for key in "${keys[@]}"; do
  data_resp=$(curl -sS -m 10 -H "X-Vault-Token: $client_token" \
    "$BAO_ADDR/v1/secret/data/apps/$domain/$key")
  # Export every field in this KV entry as its own env var (field names are
  # already the UPPER_SNAKE var names the apps expect, e.g. SONARR_API_KEY).
  while IFS='=' read -r field_name field_value; do
    [[ -z "$field_name" ]] && continue
    export "$field_name=$field_value"
  done < <(printf '%s' "$data_resp" | jq -r '.data.data // {} | to_entries[] | "\(.key)=\(.value)"')
  unset data_resp
done
unset client_token keys key

exec "$@"
