#!/usr/bin/env bash
# Splunk installation script for Packer provisioner
# Downloads, verifies, and installs Splunk Enterprise

set -euo pipefail

# Wait for cloud-init to complete
cloud-init status --wait || true

# Update package cache and install wget
sudo apt-get update
sudo apt-get install -y wget

# Download Splunk package
TMPDIR=${TMPDIR:-/tmp}
cd "$TMPDIR"

# shellcheck disable=SC2154
wget -O "splunk-${SPLUNK_VERSION}-${SPLUNK_BUILD}-linux-${SPLUNK_ARCHITECTURE}.deb" \
  "https://download.splunk.com/products/splunk/releases/${SPLUNK_VERSION}/linux/splunk-${SPLUNK_VERSION}-${SPLUNK_BUILD}-linux-${SPLUNK_ARCHITECTURE}.deb"

# Verify checksum
echo "${SPLUNK_DOWNLOAD_SHA512}  splunk-${SPLUNK_VERSION}-${SPLUNK_BUILD}-linux-${SPLUNK_ARCHITECTURE}.deb" | sha512sum -c -

# Install Splunk
sudo dpkg -i "splunk-${SPLUNK_VERSION}-${SPLUNK_BUILD}-linux-${SPLUNK_ARCHITECTURE}.deb"

# Enable Splunk at boot
# shellcheck disable=SC2154
sudo "${SPLUNK_HOME}/bin/splunk" enable boot-start \
  -user "${SPLUNK_USER}" \
  --accept-license \
  --answer-yes \
  --no-prompt \
  --seed-passwd "${SPLUNK_PASSWORD}"

# Set proper ownership
sudo chown -R "${SPLUNK_USER}:${SPLUNK_GROUP}" "${SPLUNK_HOME}"

# Clean cloud-init for template preparation
sudo cloud-init clean
sudo truncate -s 0 /etc/machine-id
