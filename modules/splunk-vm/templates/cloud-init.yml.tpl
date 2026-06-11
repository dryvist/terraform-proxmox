#cloud-config
# Splunk Docker VM Cloud-Init Configuration
# Managed by Terraform - do not edit directly
# Firewall rules managed by Proxmox firewall module (not iptables)
# Config files (indexes.conf, inputs.conf, docker-compose.yml) are
# deployed by Ansible after first boot.

hostname: ${hostname}
%{ if domain != "" ~}
fqdn: ${hostname}.${domain}
manage_etc_hosts: true
%{ endif ~}

runcmd:
  # --- Data disk setup (idempotent) ---
  # disk_setup/fs_setup modules run before user-data is available in Proxmox NoCloud,
  # causing them to be silently skipped. Disk initialization is handled here instead.
  - |
    if ! blkid -L splunk-data >/dev/null 2>&1; then
      parted /dev/vdb --script mklabel gpt mkpart primary ext4 0% 100%
      partprobe /dev/vdb
      mkfs.ext4 -L splunk-data /dev/vdb1
    fi
  - |
    if ! grep -qE '^\s*LABEL=splunk-data\s+' /etc/fstab; then
      echo 'LABEL=splunk-data /opt/splunk ext4 defaults,nofail 0 2' >> /etc/fstab
    fi
  - mkdir -p /opt/splunk
  - |
    if ! mountpoint -q /opt/splunk; then
      mount /opt/splunk
    fi

  # --- Splunk directories ---
  # Permissions allow container entrypoint to chown to splunk user
  # (SPLUNK_HOME_OWNERSHIP_ENFORCEMENT=true handles this dynamically)
  - mkdir -p /opt/splunk/var
  - mkdir -p /opt/splunk/etc
  - chmod 777 /opt/splunk /opt/splunk/var /opt/splunk/etc

  # Create config directory on root filesystem (not data disk)
  - mkdir -p /opt/splunk-config
  - chown -R root:root /opt/splunk-config

# Final message
final_message: "Splunk Docker VM initialized in $UPTIME seconds"
