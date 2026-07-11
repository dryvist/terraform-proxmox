# OpenBao (Vault) connection + AppRole auth

variable "vault_addr" {
  description = "OpenBao API address (e.g., https://openbao.example.com:8200)"
  type        = string
}

variable "vault_role_id" {
  description = "AppRole role ID for Terraform authentication to OpenBao"
  type        = string
  sensitive   = true
}

variable "vault_secret_id" {
  description = "AppRole secret ID for Terraform authentication to OpenBao"
  type        = string
  sensitive   = true
}

# apps-seed AppRole — least-privilege writer scoped to secret/apps/* only. Used
# to seed per-app service credentials (e.g. secret/apps/zammad) without widening
# the terraform-apply role. Creds are Doppler-published, same as the main role.
variable "apps_seed_role_id" {
  description = "AppRole role ID for the apps-seed writer (secret/apps/* only)"
  type        = string
  sensitive   = true
}

variable "apps_seed_secret_id" {
  description = "AppRole secret ID for the apps-seed writer (secret/apps/* only)"
  type        = string
  sensitive   = true
}

# Length for generated service credentials (passwords + API tokens). One knob
# for every password/token so lengths are never hardcoded per-resource; the
# value applied is a config concern, not visible at the use site. Keys that need
# a specific length for functional reasons (e.g. a Django SECRET_KEY) set their
# own and do not use this.
variable "credential_length" {
  description = "Character length for generated service passwords and API tokens"
  type        = number
  default     = 40
}
