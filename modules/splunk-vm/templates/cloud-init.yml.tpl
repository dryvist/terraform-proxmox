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
  # splunkd runs as uid 41812 (the 'splunk' user baked into the official
  # splunk/splunk image). Pre-own the data-disk mount as 41812 so splunkd can
  # read its own etc/passwd and splunk.secret on every boot. This is first-boot
  # only and the disk was just formatted above, so the recursive chown is cheap.
  # Do NOT use `chmod 777` here — that was a band-aid that masked wrong
  # ownership; correct ownership is the native, supported approach.
  - mkdir -p /opt/splunk/var
  - mkdir -p /opt/splunk/etc
  - chown -R 41812:41812 /opt/splunk

  # Create config directory on root filesystem (not data disk)
  - mkdir -p /opt/splunk-config
  - chown -R root:root /opt/splunk-config

# Final message
final_message: "Splunk Docker VM initialized in $UPTIME seconds"
