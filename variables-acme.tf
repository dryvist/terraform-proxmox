# ACME variables: Let's Encrypt accounts, DNS challenge plugins, and certificates

variable "acme_accounts" {
  description = "ACME account configurations for Let's Encrypt certificate management"
  type = map(object({
    email     = string
    directory = string
    tos       = string
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.acme_accounts :
      can(regex("^[^@]+@[^@]+\\.[^@]+$", v.email))
    ])
    error_message = "Each email must be a valid email address."
  }

  validation {
    condition = alltrue([
      for k, v in var.acme_accounts :
      can(regex("^https://[A-Za-z0-9._~:/?#\\[\\]@!$&'()*+,;=%-]+$", v.directory))
    ])
    error_message = "Each ACME directory must be a valid HTTPS URL (e.g., https://acme-v02.api.letsencrypt.org/directory)."
  }
}

variable "dns_plugins" {
  description = "DNS challenge plugins for ACME validation (e.g., AWS Route53)"
  type = map(object({
    plugin_type = string      # API plugin name (e.g., "route53")
    data        = map(string) # DNS plugin data as key=value pairs (e.g., AWS credentials)
  }))
  default = {}

  sensitive = true
}

variable "acme_certificates" {
  description = <<-EOT
    ACME certificates to provision and manage. Each entry maps to a single
    proxmox_acme_certificate resource per node, which can cover one primary
    domain plus a list of SANs. After issuance, the cert (combined PEM
    bundle and/or split cert+key files) can be delivered to LXCs or VMs
    via the module's null_resource provisioner.
  EOT
  type = map(object({
    node_name     = string
    domain        = string                      # primary CN (e.g., "pve.example.com")
    account_id    = string                      # ACME account name (key in var.acme_accounts)
    dns_plugin_id = string                      # DNS plugin name (key in var.dns_plugins)
    sans          = optional(list(string), []) # Additional SANs (each uses dns_plugin_id)
    destinations = optional(list(object({
      kind        = string                       # "lxc" or "vm"
      target_id   = number                       # vm_id of the LXC or VM
      target_ip   = optional(string)             # required when kind = "vm" (SSH host for scp)
      bundle_path = optional(string)             # combined cert+key PEM (e.g., "/etc/ssl/private/infisical.pem")
      cert_path   = optional(string)             # separate cert+chain PEM (e.g., "/opt/splunk/etc/auth/server.pem")
      key_path    = optional(string)             # separate private key (e.g., "/opt/splunk/etc/auth/server.key")
      mode        = optional(string, "0600")     # file mode for delivered files
      owner       = optional(string, "root")     # file owner
      group       = optional(string, "root")     # file group
      reload_cmd  = optional(string, "")         # command to run on the target after delivery
    })), [])
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.acme_certificates : alltrue([
        for d in v.destinations : contains(["lxc", "vm"], d.kind)
      ])
    ])
    error_message = "Each destination.kind must be either \"lxc\" or \"vm\"."
  }

  validation {
    condition = alltrue([
      for k, v in var.acme_certificates : alltrue([
        for d in v.destinations : (d.kind == "vm" ? d.target_ip != null && d.target_ip != "" : true)
      ])
    ])
    error_message = "destinations with kind = \"vm\" must set target_ip (SSH host for scp delivery)."
  }

  validation {
    condition = alltrue([
      for k, v in var.acme_certificates : alltrue([
        for d in v.destinations : (
          d.bundle_path != null && d.bundle_path != "" ||
          (d.cert_path != null && d.cert_path != "" && d.key_path != null && d.key_path != "")
        )
      ])
    ])
    error_message = "Each destination must set either bundle_path (combined PEM) or both cert_path and key_path (split)."
  }
}

# NOTE: Route53 DNS configuration is now managed separately in aws-infra/
# See aws-infra/variables.tf for AWS-related variables
