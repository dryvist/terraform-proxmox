# Infrastructure Numbering Scheme

**Status**: Active Production Infrastructure (100% Terraform-managed)

---

## Numbering Conventions

### LXC Containers (100-199)

All services run as lightweight LXC containers, organized by function:

- **100-110**: Infrastructure (Ansible, PVE scripts)
- **150-169**: AI development (Claude Code, Gemini, Qdrant)
- **171-179**: Cribl Stream (log processing)
- **181-189**: Cribl Edge (log forwarding)
- **190-199**: Splunk management

### VMs (200+)

Heavy I/O workloads run as full VMs:

- **200**: Splunk Enterprise all-in-one VM
- **201+**: Reserved for future VMs

---

## Complete Infrastructure Map

### LXC Containers - Infrastructure (100-110)

| ID  | Name              | Type | Cores | RAM  | Storage | Pool           | Purpose                              |
|-----|-------------------|------|-------|------|---------|----------------|--------------------------------------|
| 100 | ansible           | LXC  | 2     | 2GB  | 64GB    | infrastructure | Ansible control node - primary       |
| 101 | ansible-2         | LXC  | 2     | 2GB  | 64GB    | infrastructure | Ansible control node - secondary     |
| 102 | pve-scripts-local | LXC  | 1     | 512MB| 8GB     | infrastructure | Proxmox VE Helper Scripts            |

### LXC Containers - AI Development (150-169)

| ID  | Name           | Type | Cores | RAM  | Storage | Pool | Purpose                              |
|-----|----------------|------|-------|------|---------|------|--------------------------------------|
| 150 | claude-code-01 | LXC  | 2     | 2GB  | 64GB    | ai   | Claude Code development environment 1|
| 151 | claude-code-02 | LXC  | 2     | 2GB  | 64GB    | ai   | Claude Code development environment 2|
| 161 | gemini-01      | LXC  | 2     | 2GB  | 64GB    | ai   | Gemini development environment 1     |
| 162 | gemini-02      | LXC  | 2     | 2GB  | 64GB    | ai   | Gemini development environment 2     |
| 165 | qdrant         | LXC  | 2     | 8GB  | 108GB   | ai   | Qdrant vector database - AI RAG      |
| 166 | llamaindex     | LXC  | 2     | 4GB  | 16GB    | ai   | LlamaIndex RAG engine (CPU)          |
| 167 | hermes-infer   | LXC  | 6     | 6GB  | 144GB   | ai   | Ollama LLM inference (GPU RX 6800)   |
| 168 | hermes-chat    | LXC  | 2     | 2GB  | 16GB    | ai   | Open WebUI chat frontend             |

The GPU LLM stack (`hermes-infer` + `hermes-chat`) is documented end-to-end at
[docs.jacobpevans.com/infrastructure/local-llm](https://docs.jacobpevans.com/infrastructure/local-llm).
`hermes-infer` is a privileged LXC with the RX 6800 passed through (`/dev/kfd`,
`/dev/dri`) and a 120 GB model volume at `/var/lib/ollama`.

### LXC Containers - Cribl Stream (171-179)

| ID  | Name           | Type | Cores | RAM  | Storage | Pool    | Purpose                              |
|-----|----------------|------|-------|------|---------|---------|--------------------------------------|
| 171 | cribl-stream-1 | LXC  | 2     | 2GB  | 32GB    | logging | Cribl Stream processing node 1       |
| 172 | cribl-stream-2 | LXC  | 2     | 2GB  | 32GB    | logging | Cribl Stream processing node 2       |

### LXC Containers - Cribl Edge (181-189)

| ID  | Name           | Type | Cores | RAM  | Storage | Pool    | Purpose                              |
|-----|----------------|------|-------|------|---------|---------|--------------------------------------|
| 181 | cribl-edge-01  | LXC  | 2     | 2GB  | 32GB    | logging | Cribl Edge log forwarder 1           |
| 182 | cribl-edge-02  | LXC  | 2     | 2GB  | 32GB    | logging | Cribl Edge log forwarder 2           |

### LXC Containers - Load Balancer & Syslog (190-199)

| ID  | Name            | Type | Cores | RAM  | Storage | Pool    | Purpose                              |
|-----|-----------------|------|-------|------|---------|---------|--------------------------------------|
| 190 | haproxy-syslog  | LXC  | 1     | 512MB| 16GB    | logging | HAProxy load balancer + syslog       |
| 199 | splunk-mgmt     | LXC  | 3     | 3GB  | 100GB   | logging | Splunk SH, DS, LM, MC, CM            |

### VMs - Splunk Enterprise (200+)

| ID  | Name      | Type | Cores | RAM  | Storage | Pool    | Purpose                              |
|-----|-----------|------|-------|------|---------|---------|--------------------------------------|
| 200 | splunk-vm | VM   | 8     | 12GB | 200GB   | logging | Splunk Enterprise all-in-one         |

---

## Resource Pools

| Pool           | Purpose                              | Resources                                    |
|----------------|--------------------------------------|----------------------------------------------|
| infrastructure | Core infrastructure services         | ansible, ansible-2, pve-scripts-local        |
| ai             | AI development environments          | claude-code-01/02, gemini-01/02, qdrant      |
| logging        | Logging and observability            | cribl-*, splunk-mgmt, splunk-vm              |

---

## Resource Totals

### Containers (14 total)

| Category       | Cores | RAM   | Storage |
|----------------|-------|-------|---------|
| Infrastructure | 5     | 4.5GB | 136GB   |
| AI Development | 10    | 16GB  | 364GB   |
| Cribl Stream   | 4     | 4GB   | 264GB   |
| Cribl Edge     | 4     | 4GB   | 264GB   |
| HAProxy/Syslog | 1     | 512MB | 16GB    |
| Splunk Mgmt    | 3     | 3GB   | 100GB   |
| **Subtotal**   | 27    | 32GB  | 1144GB  |

### VMs (1 total)

| Category       | Cores | RAM   | Storage |
|----------------|-------|-------|---------|
| Splunk VM      | 8     | 12GB  | 200GB   |

### Grand Total

- **Cores**: 35 (oversubscribed)
- **RAM**: 44GB
- **Storage**: 1369GB

---

## Network Addressing

All resources use /24 CIDR notation for host addresses on the management network.

Example configuration uses 192.168.1.0/24:

### Infrastructure (100-110)

- 192.168.1.100/24 - ansible
- 192.168.1.101/24 - ansible-2
- 192.168.1.102/24 - pve-scripts-local

### AI Development (150-169)

- 192.168.1.150/24 - claude-code-01
- 192.168.1.151/24 - claude-code-02
- 192.168.1.161/24 - gemini-01
- 192.168.1.162/24 - gemini-02
- 192.168.1.165/24 - qdrant
- 192.168.1.166/24 - llamaindex
- 192.168.1.167/24 - hermes-infer
- 192.168.1.168/24 - hermes-chat

### Cribl Stream (171-179)

- 192.168.1.171/24 - cribl-stream-1
- 192.168.1.172/24 - cribl-stream-2

### Cribl Edge (181-189)

- 192.168.1.181/24 - cribl-edge-01
- 192.168.1.182/24 - cribl-edge-02

### Load Balancer & Syslog (190-199)

- 192.168.1.190/24 - haproxy-syslog
- 192.168.1.199/24 - splunk-mgmt

### VMs (200+)

- 192.168.1.200/24 - splunk-vm

---

## Splunk Configuration

### Architecture

Single all-in-one Splunk Enterprise deployment:

- **VM (200)**: Splunk Enterprise with all data roles
- **Container (199)**: Management roles (SH, DS, LM, MC, CM)

### Splunk Network

```text
192.168.1.199,192.168.1.200
```

### Port Matrix

| Port | Protocol | Purpose             | Allowed From            |
|------|----------|---------------------|-------------------------|
| 22   | TCP      | SSH                 | management_network      |
| 8000 | TCP      | Splunk Web UI       | management_network      |
| 8089 | TCP      | Splunk Management   | Splunk network          |
| 9997 | TCP      | Splunk Forwarding   | Splunk network + Cribl  |
| 8080 | TCP      | Replication         | Splunk network          |
| 9887 | TCP      | Clustering          | Splunk network          |

---

## Storage Configuration

### Cribl Persistent Queue Disks

Cribl Stream and Cribl Edge containers include 100GB persistent queue storage mounted at `/opt/cribl/data`:

**Cribl Stream (171-172)**:

- Root disk: 32GB (OS + application)
- Data disk: 100GB (persistent queue, on-disk persistence)

**Cribl Edge (181-182)**:

- Root disk: 32GB (OS + application)
- Data disk: 100GB (persistent queue, buffer storage)

Configuration in `terraform.tfvars.example`:

```hcl
mount_points = [{
  volume = "local-zfs"
  size   = "100G"
  path   = "/opt/cribl/data"
}]
```

**Note**: Ansible configuration is responsible for formatting and mounting the volume. See `ansible/roles/` for implementation details.

### Splunk VM Disk Layout

Splunk Enterprise VM (200) uses separate boot and data disks:

- **Boot disk (virtio0)**: 25GB - OS, Splunk application, configuration
- **Data disk (virtio1)**: 200GB - Splunk index storage and event data

Configuration in `terraform.tfvars.example`:

```hcl
splunk_boot_disk_size = 25   # Boot disk: 25GB
splunk_data_disk_size  = 200 # Data disk: 200GB for indexes
```

**Note**: Ansible configuration mounts the data disk to `/opt/splunk/var` for index storage. See `ansible/roles/splunk-enterprise/` for disk mount details.

---

## Terraform Management

### State

All resources are 100% Terraform-managed:

- 14 LXC containers
- 1 VM (Splunk)
- 3 resource pools
- Firewall rules

### Configuration

See `terraform.tfvars.example` for complete configuration templates.

### Fresh Deploy

To deploy from scratch (e.g., after PVE 9.x upgrade):

```bash
terragrunt apply
```

This will create all 20 resources from the configuration.

---

## Reserved Ranges

| Range     | Purpose                              |
|-----------|--------------------------------------|
| 100-110   | Infrastructure containers            |
| 111-149   | Reserved                             |
| 150-169   | AI development containers            |
| 170       | Reserved                             |
| 171-179   | Cribl Stream containers              |
| 180       | Reserved                             |
| 181-189   | Cribl Edge containers                |
| 190-199   | Load balancer, HAProxy, Splunk mgmt  |
| 200       | Splunk Enterprise VM                 |
| 201-299   | Reserved for future VMs              |
