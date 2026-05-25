#!/usr/bin/env bash
# Cleanup VMs in pool that aren't defined in Terraform.
#
# Assumes AWS creds and Doppler are already injected in the parent shell.
# Run as: aws-vault exec tf-proxmox -- doppler run -- ./scripts/cleanup-orphaned-vms.sh <pool-name>
# (the wrapper is the user's responsibility; this script does not invoke aws-vault.)

set -euo pipefail

if ! aws sts get-caller-identity >/dev/null 2>&1; then
  echo "AWS credentials not present; re-run under aws-vault exec tf-proxmox -- doppler run --" >&2
  exit 1
fi

POOL="${1:-logging}"

echo "=== Checking pool '$POOL' for orphaned resources ==="

# Get VMs in pool from Proxmox
echo "Fetching VMs from Proxmox pool..."
POOL_MEMBERS_JSON=$(ssh pve "pvesh get /pools/$POOL --output-format json")
POOL_VMS=$(echo "$POOL_MEMBERS_JSON" | jq -r '.members[]? | select(.type=="qemu") | .vmid' | sort)
POOL_CTS=$(echo "$POOL_MEMBERS_JSON" | jq -r '.members[]? | select(.type=="lxc") | .vmid' | sort)

echo "VMs in pool: ${POOL_VMS:-none}"
echo "Containers in pool: ${POOL_CTS:-none}"
echo

# Get VMs defined in Terraform state
echo "Fetching VMs from Terraform state..."
cd "$(dirname "$0")/.."

run_terragrunt() {
    terragrunt "$@"
}

# Get VM IDs from state
STATE_VMS=$(run_terragrunt state list 2>/dev/null | grep 'module.vms.proxmox_virtual_environment_vm.vms' | sed -E 's/.*\["([^"]+)"\].*/\1/' || true)
STATE_CTS=$(run_terragrunt state list 2>/dev/null | grep 'module.containers.proxmox_virtual_environment_container.containers' | sed -E 's/.*\["([^"]+)"\].*/\1/' || true)

echo "VMs in Terraform state: ${STATE_VMS:-none}"
echo "Containers in Terraform state: ${STATE_CTS:-none}"
echo

# Find orphans (in pool but not in state)
echo "=== Orphaned Resources ==="

cleanup_resources() {
    local type="$1"
    local pve_cmd="$2"
    local name_grep="$3"
    local ids_in_pool="$4"
    local names_in_state="$5"

    for id in $ids_in_pool; do
        local name
        name=$(ssh pve "$pve_cmd config $id" | grep "$name_grep" | cut -d' ' -f2)
        if echo "$names_in_state" | grep -q -w "$name"; then
            echo "✓ $type $id ($name) is managed by Terraform"
        else
            echo "⚠ $type $id ($name) is ORPHANED - not in Terraform state"
            read -p "Destroy $type $id? [y/N] " -n 1 -r
            echo
            if [[ $REPLY =~ ^[Yy]$ ]]; then
                echo "Destroying $type $id..."
                ssh pve "$pve_cmd stop $id --skiplock" || true
                ssh pve "$pve_cmd destroy $id --purge"
                echo "✓ Destroyed $type $id"
            fi
        fi
    done
}

cleanup_resources "VM" "qm" "^name:" "$POOL_VMS" "$STATE_VMS"
cleanup_resources "Container" "pct" "^hostname:" "$POOL_CTS" "$STATE_CTS"

echo
echo "=== Cleanup complete ==="
