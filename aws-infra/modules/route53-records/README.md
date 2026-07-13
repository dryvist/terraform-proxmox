# Route53 DNS Records Module

Manages AWS Route53 DNS records for Proxmox VE infrastructure.

## Purpose

Creates and manages an A record in Route53 that points a fully qualified
domain name to the active Proxmox VE API endpoint IP addresses. This enables
HTTPS access to the Proxmox UI/API via a custom domain with valid TLS
certificates while allowing DNS round-robin across cluster nodes.

## Usage

```hcl
module "route53_records" {
  source = "./modules/route53-records"

  route53_zone_id      = "Z0123456789ABCDEFGHIJ"
  proxmox_domain       = "pve.example.com"
  proxmox_ip_addresses = ["192.168.10.10", "192.168.10.11", "192.168.10.12"]
  environment          = "homelab"
}
```

## Requirements

- AWS provider configured in parent module with Route53 permissions
- Route53 hosted zone already created
- Proxmox VE host records with static IP addresses

## Inputs

| Name                 | Description                                | Type         | Default   | Required |
| -------------------- | ------------------------------------------ | ------------ | --------- | -------- |
| route53_zone_id      | Route53 hosted zone ID                     | string       | n/a       | yes      |
| proxmox_domain       | FQDN for Proxmox UI/API                    | string       | n/a       | yes      |
| proxmox_ip_addresses | Proxmox API endpoint IPs                   | list(string) | []        | no       |
| proxmox_ip_address   | Legacy fallback single Proxmox IP          | string       | ""        | no       |
| route53_cnames       | Service-alias CNAMEs: label -> target FQDN | map(string)  | {}        | no       |
| route53_a_records    | Host A records: label -> IPv4 address      | map(string)  | {}        | no       |
| dns_ttl              | DNS TTL in seconds                         | number       | 300       | no       |
| environment          | Environment name                           | string       | "homelab" | no       |

## Service-alias CNAMEs and host A records

Two additional record sets exist beyond the Proxmox A record above:

- `route53_cnames` creates CNAMEs at the zone apex (label -> target FQDN),
  e.g. a capability alias pointing at the host that serves it. ACME DNS-01
  clients that locate the hosted zone by stripping one label need these
  aliases placed directly under the public zone.
- `route53_a_records` creates the terminal A record a CNAME chain resolves
  to (label -> IPv4 address). A CNAME target that isn't also an A record
  here is a dangling alias — it will NXDOMAIN for every resolver, internal
  and external alike, since Technitium (the internal resolver) is
  authoritative for the guest subdomain only and forwards apex names to
  public resolvers.

Both maps are populated by the parent `aws-infra/native root configuration` from
`ROUTE53_CNAMES` / `ROUTE53_A_RECORDS` env vars (private RustFS) — no
hostname or IP literal is ever committed.

## Outputs

| Name                 | Description                             |
| -------------------- | --------------------------------------- |
| proxmox_record_fqdn  | FQDN of the Proxmox A record            |
| proxmox_record_name  | Name of the Proxmox A record            |
| proxmox_record_ttl   | TTL of the Proxmox A record             |
| proxmox_ip_address   | First IP address the domain resolves to |
| proxmox_ip_addresses | IP addresses the domain resolves to     |
| route53_zone_id      | Route53 hosted zone ID                  |

## Architecture

This module is part of the `aws-infra/` root module, which is completely
separated from the Proxmox infrastructure:

```text
terraform-proxmox/
├── aws-infra/                    # AWS resources (this module's parent)
│   ├── main.tf                   # AWS provider and module calls
│   ├── native root configuration            # Separate state management
│   └── modules/
│       └── route53-records/      # This module
│
└── (root)                        # Proxmox resources only
    ├── main.tf
    └── modules/
        └── acme-certificate/     # ACME certs (uses Route53 for validation)
```

## Notes

- AWS provider is configured in the parent module (aws-infra/main.tf)
- This module inherits the authenticated provider from its parent
- Route53 is a global service
- DNS changes may take up to the TTL duration to propagate
- Default TTL is 300 seconds (5 minutes)
