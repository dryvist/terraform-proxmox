output "acme_accounts" {
  description = "ACME account details"
  value = {
    for k, v in proxmox_acme_account.accounts : k => {
      id    = v.account_id
      email = v.email
    }
  }
}

output "dns_plugins" {
  description = "Configured DNS challenge plugins"
  value = {
    for k, v in proxmox_acme_dns_plugin.dns_plugins : k => {
      id     = v.id
      plugin = v.plugin
    }
  }
  sensitive = true
}

output "certificates" {
  description = "ACME certificates information (includes primary CN + all SANs)"
  value = {
    for k, v in proxmox_acme_certificate.certificates : k => {
      node_name = v.node_name
      account   = v.account
      domains   = [for d in v.domains : d.domain]
      not_after = v.not_after
      issuer    = v.issuer
      subject   = v.subject
    }
  }
}

output "cert_deliveries" {
  description = "Cert delivery destinations (after null_resource provisioning)"
  value = {
    for k, j in local.cert_deliveries : k => {
      cert_key    = j.cert_key
      kind        = j.kind
      target_id   = j.target_id
      target_ip   = j.target_ip
      bundle_path = j.bundle_path
      cert_path   = j.cert_path
      key_path    = j.key_path
    }
  }
}
