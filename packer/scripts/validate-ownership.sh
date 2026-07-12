#!/usr/bin/env bash
# Validate that all Splunk files are owned by the splunk user
# This prevents permission issues during Splunk runtime

set -euo pipefail

echo 'Validating Splunk file ownership...'

# Count files not owned by splunk:splunk
# shellcheck disable=SC2154
NON_SPLUNK_FILES=$(sudo find "${SPLUNK_HOME}" \
  \( ! -user "${SPLUNK_USER}" -o ! -group "${SPLUNK_GROUP}" \) \
  2>/dev/null | wc -l)

if [ "$NON_SPLUNK_FILES" -ne 0 ]; then
  echo "ERROR: Found $NON_SPLUNK_FILES files not owned by ${SPLUNK_USER}:${SPLUNK_GROUP}"

  # Show first 20 problematic files for debugging
  sudo find "${SPLUNK_HOME}" \
    \( ! -user "${SPLUNK_USER}" -o ! -group "${SPLUNK_GROUP}" \) \
    2>/dev/null | head -20

  exit 1
fi

echo "Validation passed: All files in ${SPLUNK_HOME} owned by ${SPLUNK_USER}:${SPLUNK_GROUP}"
