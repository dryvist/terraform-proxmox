#!/usr/bin/env bash
# Test Splunk VM protection guarantees
# Run: aws-vault exec tf-proxmox -- doppler run -- ./scripts/test-splunk-protection.sh [--live]
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "${SCRIPT_DIR}")"

# Colors
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

PASS=0
FAIL=0
SKIP=0
LIVE=false

for arg in "$@"; do
  case "$arg" in
    --live) LIVE=true ;;
  esac
done

pass() { echo -e "  ${GREEN}PASS${NC}: $1"; ((PASS++)); }
fail() { echo -e "  ${RED}FAIL${NC}: $1"; ((FAIL++)); }
skip() { echo -e "  ${YELLOW}SKIP${NC}: $1"; ((SKIP++)); }
section() { echo -e "\n${BLUE}=== $1 ===${NC}"; }

# ---------------------------------------------------------------------------
# Section 1: Terraform test suite
# ---------------------------------------------------------------------------
section "Terraform Test Suite"

cd "${PROJECT_ROOT}"

if command -v tofu &>/dev/null; then
  if tofu test; then
    pass "tofu test suite passed"
  else
    fail "tofu test suite had failures"
  fi
elif command -v terraform &>/dev/null; then
  if terraform test; then
    pass "terraform test suite passed"
  else
    fail "terraform test suite had failures"
  fi
else
  skip "neither tofu nor terraform found in PATH"
fi

# ---------------------------------------------------------------------------
# Section 2: Terragrunt plan - no destroy/replace
# ---------------------------------------------------------------------------
section "Terragrunt Plan Safety"

cd "${PROJECT_ROOT}"

PLAN_OUTPUT=$(mktemp)
trap 'rm -f "${PLAN_OUTPUT}"' EXIT

PLAN_EXIT=0
terragrunt plan -no-color -detailed-exitcode > "${PLAN_OUTPUT}" 2>&1 || PLAN_EXIT=$?

if [[ ${PLAN_EXIT} -eq 1 ]]; then
  fail "terragrunt plan returned an error"
  # Show last 20 lines for debugging
  tail -20 "${PLAN_OUTPUT}" | while IFS= read -r line; do echo "    ${line}"; done
else
  if grep -qiE 'will be destroyed|must be replaced' "${PLAN_OUTPUT}"; then
    fail "plan contains destroy or replace actions"
    grep -iE 'will be destroyed|must be replaced' "${PLAN_OUTPUT}" | while IFS= read -r line; do echo "    ${line}"; done
  else
    pass "plan has no destroy or replace actions (exit code ${PLAN_EXIT})"
  fi
fi

# ---------------------------------------------------------------------------
# Section 3: Terraform output structure validation
# ---------------------------------------------------------------------------
section "Output Structure Validation"

cd "${PROJECT_ROOT}"

INVENTORY_JSON=$(terragrunt output -json ansible_inventory 2>/dev/null) || {
  fail "could not retrieve ansible_inventory output"
  INVENTORY_JSON=""
}

if [[ -n "${INVENTORY_JSON}" ]]; then
  # Check splunk_vm key exists at root level
  if echo "${INVENTORY_JSON}" | jq -e '.splunk_vm' >/dev/null 2>&1; then
    pass "splunk_vm key exists in ansible_inventory"
  else
    fail "splunk_vm key missing from ansible_inventory"
  fi

  # Check splunk_vm.splunk.ip
  SPLUNK_IP=$(echo "${INVENTORY_JSON}" | jq -r '.splunk_vm.splunk.ip // empty' 2>/dev/null)
  if [[ -n "${SPLUNK_IP}" ]]; then
    pass "splunk_vm.splunk.ip is set (${SPLUNK_IP})"
  else
    fail "splunk_vm.splunk.ip is missing or empty"
  fi

  # Check splunk_vm.splunk.hostname
  SPLUNK_HOSTNAME=$(echo "${INVENTORY_JSON}" | jq -r '.splunk_vm.splunk.hostname // empty' 2>/dev/null)
  if [[ -n "${SPLUNK_HOSTNAME}" ]]; then
    pass "splunk_vm.splunk.hostname is set (${SPLUNK_HOSTNAME})"
  else
    fail "splunk_vm.splunk.hostname is missing or empty"
  fi

  # Check splunk_vm.splunk.vmid
  if echo "${INVENTORY_JSON}" | jq -e '.splunk_vm.splunk.vmid' >/dev/null 2>&1; then
    pass "splunk_vm.splunk.vmid exists"
  else
    fail "splunk_vm.splunk.vmid is missing"
  fi
fi

# ---------------------------------------------------------------------------
# Section 4: Live VM health checks (--live flag only)
# ---------------------------------------------------------------------------
if [[ "${LIVE}" == "true" ]]; then
  section "Live VM Health Checks"

  # Derive IP from terraform output if not already set
  if [[ -z "${SPLUNK_IP:-}" ]]; then
    SPLUNK_IP=$(terragrunt output -json ansible_inventory 2>/dev/null \
      | jq -r '.splunk_vm.splunk.ip // empty')
  fi

  if [[ -z "${SPLUNK_IP}" ]]; then
    fail "cannot determine Splunk VM IP for live checks"
  else
    SSH_KEY="${PROXMOX_SSH_KEY_PATH:-${HOME}/.ssh/id_ed25519}"
    SSH_USER="debian"
    SSH_OPTS=(-i "${SSH_KEY}" -o StrictHostKeyChecking=no -o ConnectTimeout=10)

    # a. SSH connectivity
    if ssh "${SSH_OPTS[@]}" "${SSH_USER}@${SPLUNK_IP}" "echo ok" >/dev/null 2>&1; then
      pass "SSH connectivity to ${SPLUNK_IP}"
    else
      fail "SSH connectivity to ${SPLUNK_IP}"
    fi

    # b. Data disk mounted
    if ssh "${SSH_OPTS[@]}" "${SSH_USER}@${SPLUNK_IP}" "mount | grep /opt/splunk" >/dev/null 2>&1; then
      pass "data disk mounted at /opt/splunk"
    else
      fail "data disk NOT mounted at /opt/splunk"
    fi

    # c. Swap inactive
    if ssh "${SSH_OPTS[@]}" "${SSH_USER}@${SPLUNK_IP}" 'test -z "$(swapon --show --noheadings)"' 2>/dev/null; then
      pass "swap is inactive"
    else
      fail "swap is active"
    fi

    # d. Docker running
    if ssh "${SSH_OPTS[@]}" "${SSH_USER}@${SPLUNK_IP}" "sudo docker info >/dev/null 2>&1"; then
      pass "Docker is running"
    else
      fail "Docker is NOT running"
    fi

    # e. Splunk container running
    if ssh "${SSH_OPTS[@]}" "${SSH_USER}@${SPLUNK_IP}" "sudo docker ps --format '{{.Names}}' | grep -q splunk"; then
      pass "Splunk container is running"
    else
      fail "Splunk container is NOT running"
    fi

    # f. HEC endpoint responding
    HEC_STATUS=$(ssh "${SSH_OPTS[@]}" "${SSH_USER}@${SPLUNK_IP}" \
      "curl -sk -o /dev/null -w '%{http_code}' http://localhost:8088/services/collector/health" 2>/dev/null) || HEC_STATUS="000"
    if [[ "${HEC_STATUS}" == "200" ]]; then
      pass "HEC endpoint responding (HTTP ${HEC_STATUS})"
    else
      fail "HEC endpoint returned HTTP ${HEC_STATUS} (expected 200)"
    fi
  fi
else
  section "Live VM Health Checks"
  skip "live checks require --live flag"
fi

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "================================"
echo -e "Results: ${GREEN}${PASS} passed${NC}, ${RED}${FAIL} failed${NC}, ${YELLOW}${SKIP} skipped${NC}"
if [[ ${FAIL} -gt 0 ]]; then
  exit 1
fi
