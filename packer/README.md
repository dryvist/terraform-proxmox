# Packer Templates for Proxmox

This directory contains Packer templates for building VM templates on Proxmox VE.

## Requirements

Variables are injected from two sources:

1. **Doppler Secrets** (via `PKR_VAR_*` environment variables):
   - `PROXMOX_VE_ENDPOINT` - API endpoint URL (e.g., `https://proxmox-1.example.com`)
   - `PKR_PVE_USERNAME` - Proxmox username with token ID in format `user@realm!tokenid`
   - `PROXMOX_TOKEN` - Proxmox API token secret (the secret portion of the token)
   - `PROXMOX_VE_NODE` - Target Proxmox node name
   - `PROXMOX_VE_INSECURE` (optional) - Set to "true" to skip TLS verification
   - `SPLUNK_PASSWORD` (optional) - Initial Splunk password
   - `SPLUNK_DOWNLOAD_SHA512` (optional) - SHA512 checksum for Splunk package validation

2. **Committed Config File** (`variables.pkrvars.hcl`):
   - `SPLUNK_VERSION` - Splunk version (e.g., 10.0.2)
   - `SPLUNK_BUILD` - Splunk build number (e.g., e2d18b4767e9)
   - `SPLUNK_ARCHITECTURE` - CPU architecture (amd64 or arm64)
   - `SPLUNK_USER` - User account running Splunk (typically "splunk")
   - `SPLUNK_GROUP` - Group owning Splunk files (typically "splunk")
   - `SPLUNK_HOME` - Splunk installation directory (typically "/opt/splunk")

## Usage

```bash
# Initialize Packer plugins
./packer-build.sh init

# Validate configuration
./packer-build.sh validate

# Build template
./packer-build.sh build
```

The build script automatically validates Doppler secrets and injects them as environment variables.

## Splunk Enterprise Template

The `splunk.pkr.hcl` template builds a Splunk Enterprise All-in-One template (VM ID 9200) by cloning
the Debian 12 base template (VM ID 9000) and installing Splunk.

### Critical Hardware Configuration

**IMPORTANT**: The following hardware settings are critical to prevent system freezes and instability:

#### CPU Type: `host`

```hcl
cpu_type = "host"
```

**Why**: Exposes all host CPU features to the VM with **zero CPU emulation overhead**. This provides
maximum stability and performance for single-node homelab use. The default `kvm64` type causes:

- TSC (Time Stamp Counter) clock instability
- High CPU emulation overhead
- System freezes during VM clone/start operations

**Single-Node Design**: All VMs in this homelab use `cpu_type = "host"` (both Packer and Terraform)
for maximum stability. VMs will only run on identical/similar CPUs, which is acceptable for homelab use.

#### SCSI Controller: `virtio-scsi-pci`

```hcl
scsi_controller = "virtio-scsi-pci"
```

**Why**: Modern, high-performance SCSI controller with low CPU overhead. The default `lsi` (LSI Logic)
controller is:

- Ancient technology (~2003)
- Adds significant CPU overhead during disk I/O
- Causes performance degradation during clone operations

#### OS Type: `l26`

```hcl
os_type = "l26"
```

**Why**: Optimizes VM for Linux 2.6+ kernel instead of generic "other" type.

### Terraform Integration

VMs cloned from this template use the BPG Proxmox provider in Terraform with identical hardware settings:

- **CPU Type**: `cpu_type = "host"` (maximum stability, zero emulation overhead)
- **SCSI Controller**: `virtio-scsi-pci` (modern, high-performance)
- **OS Type**: `l26` (Linux 2.6+ kernel)

All VMs in this single-node homelab use these settings for consistent, stable performance.

## References

- [Packer Proxmox Plugin](https://developer.hashicorp.com/packer/integrations/hashicorp/proxmox/latest/components/builder/clone)
- [Packer CPU Type Bug #307](https://github.com/hashicorp/packer-plugin-proxmox/issues/307)
- [Proxmox CPU Types Discussion](https://forum.proxmox.com/threads/cpu-type-host-vs-kvm64.111165/)
