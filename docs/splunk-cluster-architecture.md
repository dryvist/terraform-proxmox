# Splunk Cluster Infrastructure Architecture

**Version**: 1.0.0

## Executive Summary

This document defines the architecture for a 3-node Splunk Enterprise cluster on Proxmox VE for local log aggregation and analysis.
The cluster consists of two indexer VMs and one management LXC container, with network isolation blocking outbound internet while allowing internal cluster communication.

### Key Objectives

1. Deploy air-gapped Splunk cluster (no outbound internet)
2. Support development license (500MB/day ingestion)
3. Minimize resource usage on Proxmox host
4. Provide centralized logging for homelab infrastructure
5. Maintain DRY principles in infrastructure code

## Architecture

### Infrastructure Summary

| Component | ID | IP | Storage | Purpose |
| --- | --- | --- | --- | --- |
| splunk-mgmt (LXC) | 205 | 192.168.x.205/24 | local-zfs | All-in-one management |
| splunk-idx1 (VM) | 100 | 192.168.x.100/24 | local-zfs | Indexer 1 |
| splunk-idx2 (VM) | 101 | 192.168.x.101/24 | local-zfs | Indexer 2 |

Resource allocations (cores, RAM, disk) are defined in `deployment.json`.

### Network Configuration

- Domain: `proxmox-1.example.com`
- Network: 192.168.x.0/24
- Gateway: 192.168.x.1
- Bridge: vmbr0

### Splunk Configuration

- **License**: Development (500MB/day)
- **Installation**: Pre-staged package (air-gapped)

**Cluster Roles**:

- **splunk-mgmt**: Search Head, Deployment Server, License Manager, Monitoring Console, Cluster Manager
- **splunk-idx1/idx2**: Indexer peers

**Cluster Settings**: RF=2, SF=1, Cluster Master URI: `https://192.168.x.205:8089`

## Network Security

### Defense-in-Depth Firewall Strategy

**Layer 1: Proxmox Firewall** (hardware-level)

- Default policy: DROP all inbound and outbound
- Inbound ALLOW: SSH (22), Splunk Web (8000), Management (8089), Forwarding (9997), Replication (8080, 9887)
- Outbound ALLOW: To Splunk cluster IPs only

**Layer 2: VM iptables** (OS-level)

- INPUT/OUTPUT policy: DROP
- ALLOW established/related, loopback, Splunk ports from LAN
- NO internet access

**Port Matrix**:

| Port | Protocol | Purpose | Allowed From |
| --- | --- | --- | --- |
| 22 | TCP | SSH | LAN subnet |
| 8000 | TCP | Splunk Web UI | LAN subnet |
| 8089 | TCP | Splunk Management | Splunk cluster only |
| 9997 | TCP | Splunk Forwarding | Splunk cluster only |
| 8080 | TCP | Replication | Splunk cluster only |
| 9887 | TCP | Clustering | Splunk cluster only |

## Secrets Management

### Approach: File-Based (Simplified)

**Rationale**: Proxmox is air-gapped with no internet access. Cloud-based secrets management is not viable for the cluster nodes.

- **Local (Mac)**: Doppler for Proxmox API creds; SSH keys for host/VM access
- **Proxmox Host**: Splunk package pre-staged on host
- **Terraform State**: S3 backend with DynamoDB locking, encryption enabled
- **Splunk Credentials**: Managed by Ansible (admin password and cluster secret via Ansible Vault)

## Constraints and Decisions

### DRY Principle

Duplicated VM definitions identified; solution is `modules/splunk-indexer/`.

### Secrets Management

File-based secrets chosen over Vault/BWS/Doppler on Proxmox due to air-gap.
Real `terraform.tfvars` never committed to git.

### Manual Configuration

Splunk-to-Splunk communication deferred to post-deployment (tracked in GitHub issues).

## Prerequisites

### Already Staged

- Splunk Package on proxmox host
- Network config in `terraform.tfvars`
- "logging" pool exists
- Domain: `proxmox-1.example.com`

### User Must Provide

1. Cloud-init Template: VM 9000 with Debian 13
2. SSH Keys: VM and PVE SSH key pairs (paths configured in SOPS)
3. AWS Credentials: For Terragrunt S3 backend
4. Doppler: Configured locally for Proxmox API credentials

## References

- [Splunk Docs](https://docs.splunk.com/)
- [Proxmox VE](https://pve.proxmox.com/wiki/)
- [Terraform Proxmox Provider](https://registry.terraform.io/providers/bpg/proxmox/)
- [Ansible Best Practices](https://docs.ansible.com/ansible/latest/user_guide/playbooks_best_practices.html)
