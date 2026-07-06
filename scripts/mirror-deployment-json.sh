#!/usr/bin/env bash
# Refresh the AWS-S3 mirror of the desired-state INPUT (deployment.json).
#
# The input lives authoritatively in the on-prem RustFS object store, which is a
# single point of failure: if it is down, terragrunt cannot fetch the input and
# plan/apply is blocked. terragrunt.hcl's fetch now falls back to an AWS-S3 mirror
# (same versioned state bucket as the published inventory) when on-prem is
# unreachable. This script keeps that mirror current: it re-reads the authoritative
# on-prem copy and uploads it to the mirror after every successful apply.
#
# BEST-EFFORT by design: any failure here warns and exits 0. A mirror hiccup must
# never fail an otherwise-good apply — the prior mirror copy simply persists until
# the next apply. Staleness is therefore bounded by the apply cadence, which is the
# correct trade for a DR fallback.
# ponytail: best-effort re-fetch+upload; add a content-hash skip only if the extra
# S3 round-trip per apply ever shows up as a cost.
#
# Manual run: aws-vault exec tf-proxmox -- doppler run -- ./scripts/mirror-deployment-json.sh
set -uo pipefail

warn() { echo "mirror-deployment-json: $*" >&2; }

# An explicit local override means there is nothing on-prem to mirror.
if [[ -n "${DEPLOYMENT_JSON_PATH:-}" ]]; then
  warn "DEPLOYMENT_JSON_PATH set — skipping AWS mirror (local override in use)."
  exit 0
fi

SRC_BUCKET="${S3_INVENTORY_BUCKET:-iac-inventory}"
SRC_KEY="${S3_INVENTORY_KEY:-deployment.json}"
SRC_REGION="${S3_INVENTORY_REGION:-us-east-1}"
MIRROR_KEY="terraform-proxmox/input/deployment.json"

for var in S3_ENDPOINT S3_ACCESS_KEY S3_SECRET_KEY; do
  if [[ -z "${!var:-}" ]]; then
    warn "$var unset — cannot read on-prem source; leaving existing mirror untouched."
    exit 0
  fi
done

# Resolve the mirror bucket from the caller's AWS identity (same ambient chain as
# the state backend), so no account id is hardcoded.
acct="$(aws sts get-caller-identity --query Account --output text 2>/dev/null)"
if [[ -z "$acct" || "$acct" == "None" ]]; then
  warn "no AWS identity (ambient creds) — cannot resolve mirror bucket; skipping."
  exit 0
fi
MIRROR_BUCKET="terraform-proxmox-state-useast2-${acct}"

tmp="$(mktemp)"
trap 'rm -f "$tmp"' EXIT

# READ authoritative on-prem copy (S3_* creds, private endpoint) in a subshell so
# its unset/S3_* env never leaks into the AWS-credentialed upload below.
if ! (
  unset AWS_PROFILE AWS_SESSION_TOKEN
  AWS_ACCESS_KEY_ID="$S3_ACCESS_KEY" AWS_SECRET_ACCESS_KEY="$S3_SECRET_KEY" \
    AWS_REGION="$SRC_REGION" \
    aws --endpoint-url "$S3_ENDPOINT" s3 cp "s3://${SRC_BUCKET}/${SRC_KEY}" "$tmp" --quiet
) || [[ ! -s "$tmp" ]]; then
  warn "on-prem read failed or empty — leaving existing mirror untouched."
  exit 0
fi

# Guard: never mirror invalid JSON (would poison the fallback path).
if ! python3 -c "import json,sys; json.load(open(sys.argv[1]))" "$tmp" 2>/dev/null; then
  warn "on-prem copy is not valid JSON — refusing to mirror."
  exit 0
fi

# UPLOAD to the AWS mirror (ambient creds).
if AWS_REGION=us-east-2 aws --region us-east-2 \
  s3 cp "$tmp" "s3://${MIRROR_BUCKET}/${MIRROR_KEY}" --quiet; then
  echo "mirror-deployment-json: refreshed s3://${MIRROR_BUCKET}/${MIRROR_KEY}"
else
  warn "AWS mirror upload failed — prior mirror copy persists."
fi

exit 0
