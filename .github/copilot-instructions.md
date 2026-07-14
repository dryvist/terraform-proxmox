# GitHub Copilot Instructions — terraform-proxmox

## Repository Purpose

Infrastructure as code for provisioning VMs and containers on Proxmox VE using
OpenTofu. Terrakube owns execution, state, and workspace locking. Downstream
repos (ansible-proxmox, ansible-proxmox-apps, ansible-splunk) consume the
published Ansible inventory.

## CRITICAL: OpenTofu, Not Terraform

This repo uses **OpenTofu** (`tofu`), not Terraform. Never generate `terraform` CLI commands.
The binary is `tofu`. All HCL is OpenTofu-compatible.

## Running Commands

Static checks run locally without credentials:

```bash
tofu init -backend=false
tofu validate
tofu test
```

Plans, applies, imports, and state operations run only in the private
Terrakube workspace — never locally. There is no local credential wrapper to
run: Terrakube exchanges its workload identity for a short-lived OpenBao
token, and providers read Proxmox, SSH, Route53, and RustFS credentials
through native ephemeral resources.

## Technology Stack

- **OpenTofu** (not Terraform) — IaC engine
- **Terrakube** — remote execution, state, workspace locking, and run audit
- **OpenBao** — native workload identity and ephemeral provider credentials
  (including AWS STS for Route53, via OpenBao's AWS secrets engine —
  replacing the retired static aws-vault base key)
- **RustFS** — private desired-state (`deployment.json`) and published
  Ansible inventory objects

## HCL Conventions

- Module inputs in `variables.tf`, outputs in `outputs.tf`, providers in `providers.tf`
- Use `deployment.json` for environment-specific non-secret config — private,
  not committed, fetched from homelab RustFS at plan/apply (see
  `agentsmd/rules/infra/deployment-json-source-of-truth.md`)
- Credentials live in OpenBao KV, delivered through native ephemeral
  resources — never copied into Terrakube workspace variables or
  `deployment.json`

## CI

The `Terraform CI` workflow validates HCL syntax and runs `tofu validate`.
Fix all validation errors before merging.
