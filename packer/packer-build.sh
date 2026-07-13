#!/usr/bin/env bash
# OpenBao-integrated Packer build script for Splunk template
# Usage: ./packer-build.sh [init|build|validate]
#
# Secret fields use the same names as the Packer variables.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check for required tools
check_requirements() {
    local missing=()
    command -v bao >/dev/null 2>&1 || missing+=("bao")
    command -v packer >/dev/null 2>&1 || missing+=("packer")

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing[*]}"
        exit 1
    fi
}

# Validate that required OpenBao fields exist
validate_secrets() {
    log_info "Validating OpenBao secrets for Packer..."

    local required_secrets=(
        "PROXMOX_VE_ENDPOINT"
        "PKR_PVE_USERNAME"
        "PROXMOX_TOKEN"
        "PROXMOX_VE_NODE"
    )

    local optional_secrets=(
        "PROXMOX_VE_INSECURE"
        "SPLUNK_PASSWORD"
        "SPLUNK_DOWNLOAD_SHA512"
    )

    local missing=()
    local secrets
    secrets=$(bao kv get -format=json "${OPENBAO_PACKER_PATH:-secret/infrastructure/proxmox-packer}" | jq -r '.data.data | keys[]')

    for secret in "${required_secrets[@]}"; do
        if ! echo "$secrets" | grep -q "^${secret}$"; then
            missing+=("$secret")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required OpenBao fields: ${missing[*]}"
        exit 1
    fi

    log_info "Required secrets present."

    # Check optional secrets
    local missing_optional=()
    for secret in "${optional_secrets[@]}"; do
        if ! echo "$secrets" | grep -q "^${secret}$"; then
            missing_optional+=("$secret")
        fi
    done

    if [[ ${#missing_optional[@]} -gt 0 ]]; then
        log_warn "Missing optional OpenBao fields (add these for full functionality):"
        for secret in "${missing_optional[@]}"; do
            echo "  - $secret"
        done
    fi
}

# Run Packer with OpenBao fields exported as PKR_VAR_* variables.
run_packer_with_secrets() {
    local packer_command="$1"
    local path="${OPENBAO_PACKER_PATH:-secret/infrastructure/proxmox-packer}"
    local var value
    local -a packer_args

    for var in PROXMOX_VE_ENDPOINT PKR_PVE_USERNAME PROXMOX_TOKEN PROXMOX_VE_NODE PROXMOX_VE_INSECURE SPLUNK_PASSWORD SPLUNK_DOWNLOAD_SHA512; do
        value=$(bao kv get -field="$var" "$path" 2>/dev/null || true)
        if [[ -n "$value" ]]; then
            export "PKR_VAR_${var}=$value"
        fi
    done

    read -r -a packer_args <<< "$packer_command"
    "${packer_args[@]}"
}

# Main
check_requirements

case "${1:-build}" in
    init)
        log_info "Initializing Packer plugins..."
        packer init .
        ;;
    validate)
        validate_secrets
        log_info "Validating Packer configuration..."
        run_packer_with_secrets "packer validate -var-file=variables.pkrvars.hcl ."
        ;;
    build)
        validate_secrets
        log_info "Building Splunk template (9200)..."
        run_packer_with_secrets "packer build -var-file=variables.pkrvars.hcl ."
        ;;
    *)
        echo "Usage: $0 [init|validate|build]"
        echo ""
        echo "Commands:"
        echo "  init      - Initialize Packer plugins"
        echo "  validate  - Validate configuration and secrets"
        echo "  build     - Build the Splunk template"
        echo ""
        echo "Environment:"
        echo "  OpenBao fields are mapped to PKR_VAR_* at runtime"
        exit 1
        ;;
esac

log_info "Done!"
