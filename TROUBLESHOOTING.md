# Terraform/Terragrunt Troubleshooting Guide

## ✅ State Management (Resolved)

**All critical state synchronization and DynamoDB lock issues have been resolved. For historical reference and detailed analysis of the previous issues, see [TERRAGRUNT_STATE_TROUBLESHOOTING.md](./TERRAGRUNT_STATE_TROUBLESHOOTING.md).**

## Common Issues and Solutions

### State Lock Issues

#### Problem: Persistent DynamoDB locks from interrupted runs

```bash
# Error: Error acquiring the state lock
# Lock Info: ID: terraform-proxmox-state-{region}-{id}/terraform-proxmox/./terraform.tfstate-md5
```

#### Solutions

1. **Check active locks:**

   ```bash
   aws dynamodb scan --table-name <lock-table-name> --region <region>
   ```

2. **Force unlock via Terragrunt:**

   ```bash
   terragrunt force-unlock -force <LOCK_ID>
   ```

3. **Manual DynamoDB cleanup (if force-unlock fails):**

   ```bash
   aws dynamodb delete-item \
     --table-name <lock-table-name> \
     --region <region> \
     --key '{"LockID": {"S": "<LOCK_ID>"}}'
   ```

### State Drift Issues

#### Problem: Resources in state but not in configuration

```bash
# Shows resources like module.security.* when security module was removed
terragrunt state list
```

#### Solution

```bash
# Remove orphaned resources from state
terragrunt state rm module.security.random_password.vm_password
terragrunt state rm module.security.tls_private_key.vm_key
```

### Timeout Issues

#### Problem: Proxmox API calls timing out during plan/apply refresh phase

Debug logs show: `module.vms.proxmox_virtual_environment_vm.vms["vm_name"]: Refreshing state...` then timeout

#### Root Cause Analysis

- Configuration loads successfully
- SSH key data source works
- VMs exist in state with specific IDs (see INFRASTRUCTURE_NUMBERING.md for current scheme)

#### Solutions

1. **Test API connectivity first:**

   ```bash
   curl -k -X GET "https://proxmox.example.com:8006/api2/json/version" \
     -H "Authorization: PVEAPIToken=<user>@<realm>!<token-name>=<token-value>" --max-time 10
   ```

2. **Emergency: Replace problematic VM resources:**

   ```bash
   # If specific VMs are causing issues, recreate them
   terragrunt state rm module.vms.proxmox_virtual_environment_vm.vms["problematic-vm"]
   terragrunt import module.vms.proxmox_virtual_environment_vm.vms["problematic-vm"] <vm-id>
   ```

### "Context Deadline Exceeded" Analysis

#### Understanding the Error

This error occurs when the Proxmox provider's HTTP client times out during:

1. **State refresh** - Querying all VMs/containers for current status
2. **QEMU agent detection** - Cloud-init waiting for agent to come online
3. **Backend lock operations** - DynamoDB acquiring/releasing locks

#### Root Cause Analysis Checklist

```bash
# Check 1: Is Proxmox API responding?
doppler run -- ./scripts/check-proxmox-api.sh
# Should respond in <5 seconds for all tests

# Check 2: Host resource contention?
ssh root@proxmox-host 'free -h && df -h && uptime'
# Look for: High memory usage, full disks, high load average

# Check 3: DynamoDB lock stuck?
aws dynamodb scan --table-name terraform-proxmox-locks-useast2 --region us-east-2
# Should return quickly; if slow, AWS may be throttling

# Check 4: Specific resource causing issues?
TF_LOG=DEBUG terragrunt refresh 2>&1 | grep -B2 "context deadline\|timeout"
```

#### Proactive Monitoring

Always monitor during long operations:

```bash
# Terminal 1: Run with debug logging
TF_LOG=DEBUG terragrunt apply -auto-approve 2>&1 | tee /tmp/tf.log

# Terminal 2: Real-time monitoring
./scripts/monitor-terraform.sh /tmp/tf.log

# Terminal 3 (optional): DynamoDB locks
watch -n 5 'aws dynamodb scan --table-name terraform-proxmox-locks-useast2 --region us-east-2 --query Count'
```

#### Timeout Configuration

Resource-level timeouts are set in modules (15 min standard, 30 min for clone/create):

- See `modules/proxmox-vm/main.tf` lines 125-132
- See `modules/splunk-vm/main.tf` lines 83-91

For persistent timeout issues, reduce parallelism:

```bash
terragrunt apply -parallelism=1 -auto-approve
```

### Network/Connectivity Issues

#### Problem: Cannot reach infrastructure API endpoint

#### Troubleshooting

1. **Test API connectivity:**

   ```bash
   curl -k -X GET "<api-endpoint>/version" \
     -H "Authorization: <auth-header>"
   ```

2. **Verify SSH connectivity:**

   ```bash
   ssh -i <ssh-key-path> <user>@<host>
   ```

### SSL Certificate Issues

#### Problem: Browser shows certificate error or wrong hostname

After Proxmox upgrades, hostname changes, or domain migrations, certificates may reference old hostnames.

**Symptoms:**

- Browser shows `NET::ERR_CERT_COMMON_NAME_INVALID`
- Certificate shows wrong CN (e.g., `CN=proxmox-1.mgmt` when accessing `proxmox-1.example.com`)
- `curl -vk` shows unexpected subject/issuer

**Diagnosis:**

```bash
# Check what certificate is being served
curl -vk https://proxmox-1.example.com:8006/ 2>&1 | grep -E "(subject|issuer)"

# Check certificate on server
ssh proxmox-1 "openssl x509 -in /etc/pve/local/pveproxy-ssl.pem -noout -subject -ext subjectAltName"

# Check hostname configuration
ssh proxmox-1 "hostname && hostname -f && cat /etc/hosts"
```

**Root Cause:**

Certificate was generated before hostname/domain configuration was corrected. The
`pvecm updatecerts` command uses values from `/etc/hosts` at generation time.

**Fix for Self-Signed Certificates:**

```bash
# Ensure /etc/hosts is correct first:
# <IP> <FQDN> <short-hostname>
# Example: 192.168.10.14 proxmox-1.example.com proxmox-1

ssh proxmox-1 "pvecm updatecerts --force && systemctl restart pveproxy"
```

**Fix for ACME/Let's Encrypt Certificates:**

```bash
# Configure ACME with correct domain
ssh proxmox-1 "cat /etc/pve/nodes/proxmox-1/config"
# Should show: acmedomain0: proxmox-1.example.com,plugin=AWS

# Order new certificate
ssh proxmox-1 "pvenode acme cert order --force"
```

See [docs/ACME.md](./docs/ACME.md) for detailed ACME configuration.

### State vs Infrastructure Mismatch

#### Problem: Terraform state shows different resources than actual infrastructure

This occurs when operations are interrupted, leaving orphaned resources in infrastructure but not in state, or vice versa.

#### Root Cause Analysis

- **State vs Reality**: Terraform state may show empty while infrastructure has running resources
- **Interrupted Operations**: Destroy/apply operations interrupted before state update completion
- **Configuration vs Outputs**: Outputs may display from configuration variables rather than actual resources

#### Solutions

1. **Verify state consistency:**

   ```bash
   # Check Terraform state
   terragrunt state list

   # Check actual infrastructure via API
   curl -k GET "<api-endpoint>/resources"
   ```

2. **Manual cleanup of orphaned resources:**

   ```bash
   # Stop and remove orphaned resources via API
   curl -k DELETE "<api-endpoint>/resource/<resource-id>"
   ```

3. **Import existing resources into state:**

   ```bash
   terragrunt import <resource-type>.<resource-name> <resource-id>
   ```

### Destroy Operations

#### Problem: Incomplete destroy operations leaving orphaned resources

#### Proper Destroy Procedures

1. **Pre-Destroy Checks:**

   ```bash
   # Check for active locks
   aws dynamodb scan --table-name <lock-table> --region <region>

   # Verify current state
   terragrunt state list

   # Check infrastructure reality
   curl -k GET "<api-endpoint>/resources"
   ```

2. **Execute Destroy:**

   ```bash
   # Use appropriate timeout and parallelism
   terragrunt destroy --terragrunt-parallelism=4
   ```

3. **Post-Destroy Verification:**

   ```bash
   # Verify state is empty
   terragrunt state list

   # Verify infrastructure is clean
   curl -k GET "<api-endpoint>/resources"

   # Clean up any orphaned resources manually
   curl -k DELETE "<api-endpoint>/resource/<resource-id>"
   ```

#### Key Findings

- Infrastructure deployment configurations work correctly with proper specifications
- Timeout settings effectively prevent indefinite hangs
- Command timeouts can interrupt state updates, creating orphaned resources
- Destroy operations require careful monitoring to ensure completion

## Targeted VM Operations for Fast Troubleshooting

### Problem: Full destroy/apply cycles take 30+ minutes

When troubleshooting cloud-init configurations, VM provisioning issues, or testing specific VM changes, full infrastructure cycles are
inefficient and time-consuming.

### Solution: Targeted VM Operations

#### Single VM Operations

```bash
# Target single VM for destroy/apply (replace 'vm-name' with actual VM name)
terragrunt destroy -target=module.vms.proxmox_virtual_environment_vm.vms[\"vm-name\"] -auto-approve
terragrunt apply -target=module.vms.proxmox_virtual_environment_vm.vms[\"vm-name\"] -auto-approve

# Multiple VM targeting
terragrunt destroy \
  -target=module.vms.proxmox_virtual_environment_vm.vms[\"vm1\"] \
  -target=module.vms.proxmox_virtual_environment_vm.vms[\"vm2\"] \
  -auto-approve
```

#### Cloud-init Troubleshooting (2-5 minute cycles)

```bash
# Quick VM recreation for cloud-init testing
terragrunt destroy -target=module.vms.proxmox_virtual_environment_vm.vms[\"vm-name\"] -auto-approve
terragrunt apply -target=module.vms.proxmox_virtual_environment_vm.vms[\"vm-name\"] -auto-approve

# Test SSH and cloud-init status
ssh -i <ssh-key> <user>@<vm-ip> 'sudo cloud-init status --long'
ssh -i <ssh-key> <user>@<vm-ip> 'sudo cat /var/log/cloud-init-output.log'
```

#### Emergency VM Cleanup

```bash
# Remove VM from state if targeted destroy fails
terragrunt state rm module.vms.proxmox_virtual_environment_vm.vms[\"vm-name\"]

# Manually destroy via Proxmox host
ssh -i <ssh-key> <user>@<proxmox-host> 'qm stop <vm-id> && qm destroy <vm-id>'

# Re-create VM
terragrunt apply -target=module.vms.proxmox_virtual_environment_vm.vms[\"vm-name\"] -auto-approve
```

## Provider Timeout & Performance Issues

### Problem: Terragrunt operations hanging or timing out

Common causes include:

- Proxmox API timeouts during VM operations
- DynamoDB locks from previous interrupted operations
- Network connectivity issues
- Resource contention on Proxmox host

### Solutions by Issue Type

#### API Connectivity Issues

```bash
# Test Proxmox API responsiveness
curl -k -X GET "https://proxmox.example.com:8006/api2/json/version" \
  -H "Authorization: PVEAPIToken=<user>@<realm>!<token-name>=<token-value>" --max-time 10

# Check basic connectivity
ping -c 3 proxmox.example.com
ssh -i <ssh-key> <user>@<proxmox-host> 'uptime'
```

#### DynamoDB Lock Management

```bash
# Check for existing locks
aws dynamodb scan --table-name <lock-table-name> --region <region>

# Force unlock specific lock
terragrunt force-unlock -force <LOCK_ID>

# Bulk lock cleanup (use with caution)
aws dynamodb scan --table-name <lock-table-name> --region <region> \
  --query 'Items[].LockID.S' --output text | \
  xargs -I {} terragrunt force-unlock -force {}
```

#### Resource Monitoring

```bash
# Check Proxmox host resources
ssh -i <ssh-key> <user>@<proxmox-host> 'free -h && df -h'

# List VMs and containers
ssh -i <ssh-key> <user>@<proxmox-host> 'qm list && pct list'
```

### Prevention & Best Practices

#### Pre-Operation Checks

```bash
# Check for locks and API connectivity before major operations
aws dynamodb scan --table-name <lock-table-name> --region <region> --query 'Count'
curl -k -s "https://proxmox.example.com:8006/api2/json/version" \
  -H "Authorization: PVEAPIToken=<token>" --max-time 10
```

#### Gradual Operations

```bash
# Phase operations instead of full destroy/apply cycles
terragrunt destroy \
  -target=module.vms.proxmox_virtual_environment_vm.vms[\"vm1\"] \
  -target=module.vms.proxmox_virtual_environment_vm.vms[\"vm2\"] \
  -auto-approve

terragrunt apply \
  -target=module.vms.proxmox_virtual_environment_vm.vms[\"vm1\"] \
  -auto-approve
```

## Best Practices

### Operational Guidelines

#### Before Operations

1. Check for existing locks
2. Verify state consistency: `terragrunt state list`
3. Test API connectivity
4. Use targeted operations for specific troubleshooting

#### After Interrupted Runs

1. Clean up locks immediately: `terragrunt force-unlock -force <LOCK_ID>`
2. Verify state vs infrastructure consistency
3. Remove orphaned resources from state if needed
4. Perform manual cleanup via API/SSH if necessary

## Emergency Procedures

### State Inconsistency Fix

```bash
# When state shows resources but they don't exist in Proxmox
# Remove only data sources that are computed values
terragrunt state rm data.local_file.vm_ssh_public_key
```

### Complete State Reset (Use with extreme caution)

```bash
# Only if all other methods fail and you need to start fresh
# This will destroy all managed infrastructure!
terragrunt state list | xargs -I {} terragrunt state rm {}
```

### Complete Lock Table Cleanup

```bash
# Remove all locks (emergency use only when no operations are running)
aws dynamodb scan --table-name <lock-table> --region <region> \
  --query 'Items[].LockID.S' --output text | \
  xargs -I {} aws dynamodb delete-item \
    --table-name <lock-table> \
    --region <region> \
    --key '{"LockID": {"S": "{}"}}'
```

## Key Operational Principles

### Timeout Management

- Set appropriate timeouts (5-15 minutes typically)
- Monitor operations through both Terraform and infrastructure consoles
- Use targeted operations to reduce timeout exposure

### State Consistency

- Regular state vs infrastructure checks
- Backup state files before major operations
- Clean up orphaned resources promptly

### Monitoring

- Track DynamoDB lock table size
- Verify API connectivity before operations
- Monitor resource usage on Proxmox hosts
- Use targeted operations for faster troubleshooting cycles

---

## System Crash Investigation

When the Proxmox host becomes unresponsive and requires a forced power cycle.

### Immediate Post-Recovery Diagnostics

Run these commands immediately after the system boots:

```bash
# 1. Check boot time and uptime
uptime && who -b

# 2. Check previous boot for crash indicators
journalctl -b -1 | grep -iE "mce|panic|oom|lockup|error|killed" | head -50

# 3. Check RAS daemon for hardware errors
ras-mc-ctl --summary
ras-mc-ctl --errors

# 4. Check ZFS health
zpool status

# 5. Check VM/container recovery
qm list && pct list

# 6. Get last messages before crash
journalctl -b -1 --no-pager | tail -100
```

### Crash Type Identification

| Symptom | Likely Cause | Investigation |
| ------- | ------------ | ------------- |
| OOM killer in logs | Memory exhaustion | Check swap usage, ARC limits |
| MCE errors in RAS | Hardware failure | Check memory, CPU, replace hardware |
| Soft lockup messages | Scheduler stall | Check for I/O bottlenecks |
| No errors, logs stop | Silent hang/deadlock | Check kernel params, enable kdump |
| ZFS errors | Storage issue | Run `zpool scrub`, check SMART |

### Silent Hang Investigation

When system hangs with no error messages:

```bash
# Check NMI watchdog is enabled
cat /proc/sys/kernel/nmi_watchdog  # Should be 1

# Check kernel parameters
cat /proc/cmdline

# Look for soft lockups that might not panic
journalctl -b -1 | grep -iE "soft lockup|rcu_sched|hung_task"

# Check ZFS ARC pressure
cat /proc/spl/kstat/zfs/arcstats | grep -E "^(c |c_max|size)"
cat /sys/module/zfs/parameters/zfs_arc_max
```

### Enabling Better Crash Diagnostics

Add to `/etc/default/grub` GRUB_CMDLINE_LINUX:

```text
nmi_watchdog=1 softlockup_panic=1 hung_task_panic=1
```

Then run `update-grub` and reboot.

### ZFS ARC Tuning for Stability

If crashes correlate with memory pressure:

```bash
# Check current ARC max (bytes)
cat /sys/module/zfs/parameters/zfs_arc_max

# Set ARC max to 2GB (recommended for 15GB RAM systems)
echo 2147483648 > /sys/module/zfs/parameters/zfs_arc_max

# Make permanent in /etc/modprobe.d/zfs.conf:
# options zfs zfs_arc_max=2147483648
```

### Crash Investigation Log

Document each crash in `.docs/crash-investigation-log.md` (gitignored) with:

- Timeline (boot time, last log entry, recovery time)
- RAS daemon output
- ZFS pool status
- VM/container recovery status
- Suspected cause and recommendations

### 2026-01-13 Crash Reference

System hung during overnight stress testing. Characteristics:

- No OOM killer, no MCE, no soft lockups in logs
- **NMI watchdog was enabled** (`NMI watchdog: Enabled` in boot logs) but didn't trigger
- **Runtime panic triggers active** (`softlockup_panic=1`, `hung_task_panic=1` via sysctl)
- **TSC clocksource marked unstable at boot** - potential timing issue under load
- ZFS pools healthy, all VMs/containers recovered
- Suspected hard CPU lockup or kernel deadlock

**What's Missing** (needed for next crash):

- **kdump not installed** - no crash dump captured
- **Boot-time kernel params** - panic triggers only set via sysctl, not GRUB
- **Serial console capture** - no crash output preserved

See `.docs/crash-investigation-log.md` for full analysis.
