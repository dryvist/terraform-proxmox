# ACME Certificate Implementation Plan

**Status:** In Planning Phase
**Plan File:** `.claude/plans/quizzical-herding-fountain.md`
**Created:** 2026-01-07

## Quick Summary

This document outlines the implementation plan for:

1. **Importing existing ACME certificates** from Proxmox into Terraform state
2. **Configuring Proxmox to accept HTTPS on port 443** (eliminating :8006 requirement)

## Current State

- ACME certificates exist in Proxmox but are not managed by Terraform
- HTTPS access requires `:8006` port suffix
- Certificate management is manual (not in IaC)

## Target Outcome

- All ACME resources managed via Terraform modules
- Proxmox accessible via `https://proxmox-1.example.com` (standard port)
- Automatic certificate renewal via Proxmox + Route53
- Backward compatibility with port 8006 maintained

## Implementation Structure

### Part 1: ACME Import (6 phases)

1. **Discovery** - Query Proxmox API for existing resources
2. **Module Creation** - Create `modules/acme-certificate/`
3. **Root Integration** - Integrate module into main configuration
4. **Doppler Configuration** - Add Route53 secrets
5. **Resource Import** - Import existing resources into Terraform state
6. **Validation** - Zero-drift terraform plan

### Part 2: Port 443 Configuration (5 phases)

1. **Proxmox Config** - Modify pveproxy to listen on port 443
2. **Firewall Rules** - Allow port 443 inbound
3. **DNS Validation** - Verify Route53 A record
4. **Certificate Verification** - Confirm certificate is active
5. **Testing** - Comprehensive HTTPS access validation

## GitHub Issues

Parent Issue + 5 Child Issues will be created:

**Parent:** `feat: Configure ACME certificates and HTTPS access for Proxmox`

**Children:**

1. `feat: Create ACME certificate Terraform module`
2. `feat: Import existing ACME resources into Terraform state`
3. `feat: Configure Proxmox for port 443 HTTPS access`
4. `chore: Configure Doppler secrets for Route53 DNS challenges`
5. `docs: Add ACME certificate management documentation`

See `.claude/plans/quizzical-herding-fountain.md` for detailed issue templates.

## Key Design Decisions

✅ **Import Approach:** Terraform `terraform import` for existing resources (preserves current certificates)
✅ **AWS Auth:** Hybrid - aws-vault for Terraform + Doppler for Proxmox renewal
✅ **Port Strategy:** Direct Proxmox config (simpler than reverse proxy)
✅ **Module Pattern:** Follows existing 7-module architecture with `for_each` patterns
✅ **Secrets:** All AWS credentials in Doppler, never in git or tfvars

### Secret Flow: Doppler → Proxmox

**For Terraform Deployment:**

1. Local workstation runs: `aws-vault exec tf-proxmox -- doppler run -- terragrunt apply`
2. Doppler injects `ROUTE53_ACCESS_KEY` and `ROUTE53_SECRET_KEY` as environment variables
3. Terraform configures Proxmox DNS plugin via BPG provider API calls
4. Proxmox stores credentials in `/etc/pve/priv/acme/plugins.cfg` (encrypted cluster filesystem)

**For Automatic Renewal:**

1. Proxmox's `pve-daily-update.service` runs certificate checks
2. Proxmox reads credentials from `/etc/pve/priv/acme/plugins.cfg`
3. Proxmox uses stored Route53 credentials for DNS-01 challenges
4. No additional secret sync required - credentials persist in Proxmox cluster storage

## Success Criteria

- [ ] All ACME resources imported into Terraform state
- [ ] `terraform plan` shows zero drift after import
- [ ] HTTPS works on port 443 without :8006
- [ ] Valid certificate presented (no warnings)
- [ ] Auto-renewal functional via Proxmox
- [ ] Port 8006 still works (backward compat)
- [ ] No secrets in git
- [ ] Documentation complete
- [ ] GitHub issues created and linked

## Files to Create/Modify

**New Files:**

- `modules/acme-certificate/main.tf`
- `modules/acme-certificate/variables.tf`
- `modules/acme-certificate/outputs.tf`
- `modules/acme-certificate/README.md`

**Modified Files:**

- `main.tf` (add ACME module instantiation and locals for Route53 DNS plugin config)
- `variables.tf` (add ACME variables)
- `outputs.tf` (add ACME outputs)

**Doppler Secrets to Add:**

- ROUTE53_ACCESS_KEY
- ROUTE53_SECRET_KEY
- ROUTE53_ZONE_ID
- ACME_EMAIL
- ACME_DOMAIN

## Next Steps

1. Create GitHub issues with parent/child hierarchy
2. Configure Doppler secrets (requires Route53 IAM setup)
3. Create ACME certificate module
4. Import existing resources
5. Configure Proxmox port 443
6. Run tests and validation
7. Merge PR

---

**For detailed implementation steps, see:** the GitHub issue linked above.
