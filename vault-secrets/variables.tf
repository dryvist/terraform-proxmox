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
