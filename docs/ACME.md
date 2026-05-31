# ACME/Let's Encrypt Certificate Setup

Proxmox VE supports automatic SSL certificate management via ACME (Let's Encrypt).

## Configuration

### DNS Validation with AWS Route53

For internal servers not accessible from the internet, DNS validation is required.

#### 1. Create ACME Plugin

Via CLI:

```bash
# Check existing plugins
pvenode acme plugin list

# The AWS plugin should already exist if configured via UI
```

Via `/etc/pve/priv/acme/plugins.cfg`:

```ini
standalone: standalone

dns: AWS
    api aws
    data <base64-encoded-credentials>
```

The `data` field contains base64-encoded AWS credentials:

```text
AWS_ACCESS_KEY_ID=<YOUR_ACCESS_KEY_ID>
AWS_SECRET_ACCESS_KEY=<YOUR_SECRET_ACCESS_KEY>
```

#### 2. Configure Node for ACME

Edit `/etc/pve/nodes/<node>/config`:

```ini
acmedomain0: proxmox-1.example.com,plugin=AWS
```

**Key points:**

- Use `acmedomain0` (not `acme`) to specify the DNS plugin
- The domain must match what you access in the browser
- Multiple domains use `acmedomain0`, `acmedomain1`, etc.

#### 3. Order Certificate

```bash
pvenode acme cert order --force
```

This will:

1. Create DNS TXT record via Route53
2. Wait for propagation (30 seconds default)
3. Validate domain ownership
4. Issue certificate
5. Install and restart pveproxy

### Certificate Renewal

Certificates auto-renew via systemd timer. Check status:

```bash
systemctl status pve-daily-update.timer
```

Manual renewal:

```bash
pvenode acme cert renew
```

## Troubleshooting

### Certificate Hostname Mismatch

**Symptom:** Browser shows certificate error for wrong hostname (e.g., `CN=proxmox-1.mgmt` when accessing `proxmox-1.example.com`)

**Cause:** Certificate was generated with old hostname configuration

**Fix:**

1. Verify hostname config:

   ```bash
   hostname -f  # Should show FQDN
   cat /etc/hosts  # Should map IP to FQDN
   ```

2. Regenerate self-signed cert (if not using ACME):

   ```bash
   pvecm updatecerts --force
   systemctl restart pveproxy
   ```

3. Or order new ACME cert:

   ```bash
   pvenode acme cert order --force
   ```

### DNS Validation Failures

**Symptom:** `validating challenge failed - status: invalid`

**Causes:**

- Wrong plugin configured (using `standalone` instead of `AWS`)
- AWS credentials invalid or insufficient permissions
- DNS propagation delay

**Fix:**

1. Verify plugin is specified in domain config:

   ```bash
   cat /etc/pve/nodes/pve/config
   # Should show: acmedomain0: domain.com,plugin=AWS
   ```

2. Test AWS credentials:

   ```bash
   aws route53 list-hosted-zones
   ```

3. Required IAM permissions for Route53:
   - `route53:ListHostedZones`
   - `route53:GetHostedZone`
   - `route53:ChangeResourceRecordSets`
   - `route53:ListResourceRecordSets`

### Duplicate Domain Error

**Symptom:** `duplicate domain 'example.com' in ACME config properties 'acmedomain0' and 'acme'`

**Fix:** Remove the simple `acme:` line, keep only `acmedomain0:`:

```bash
# Wrong - causes duplicate
acme: domains=example.com
acmedomain0: example.com,plugin=AWS

# Correct - single entry with plugin
acmedomain0: example.com,plugin=AWS
```

## Wildcard Certificates

**Note:** Proxmox VE does not support wildcard certificates (`*.example.com`) natively as of version 9.1. This is tracked in [Proxmox Bugzilla #5719](https://bugzilla.proxmox.com/show_bug.cgi?id=5719).

**Workarounds:**

1. Use specific subdomains for each service
2. Use external tools (acme.sh, certbot) and manually install certs
3. Use a reverse proxy with wildcard cert in front of Proxmox

## References

- [Proxmox Certificate Management Wiki](https://pve.proxmox.com/wiki/Certificate_Management)
- [Let's Encrypt Documentation](https://letsencrypt.org/docs/)
- [AWS Route53 – Working with DNS Records](https://docs.aws.amazon.com/Route53/latest/DeveloperGuide/rrsets-working-with.html)
