# ==============================================================================
# SECRET VARIABLES - Injected from OpenBao as PKR_VAR_* environment variables
# ==============================================================================
# OpenBao fields are exported as PKR_VAR_* environment variables.
# Packer automatically reads PKR_VAR_<name> and maps to variable <name>.
#
# Required OpenBao fields:
#   PROXMOX_VE_ENDPOINT       - API endpoint URL
#   PKR_PVE_USERNAME          - Composed as: ${PROXMOX_VE_USERNAME}@realm!${PROXMOX_TOKEN_ID}
#   PROXMOX_TOKEN             - Just the secret UUID
#   PROXMOX_VE_NODE           - Node name
# ==============================================================================

variable "PROXMOX_VE_ENDPOINT" {
  type        = string
  description = "Proxmox API endpoint"
  sensitive   = false
}

variable "PKR_PVE_USERNAME" {
  type        = string
  description = "Proxmox username with token ID in format user@realm!tokenid"
  sensitive   = false
}

variable "PROXMOX_TOKEN" {
  type        = string
  description = "Proxmox API token secret"
  sensitive   = true
}

variable "PROXMOX_VE_NODE" {
  type        = string
  description = "Proxmox node name"
  sensitive   = false
}

variable "PROXMOX_VE_INSECURE" {
  type        = string
  description = "Skip TLS verification"
  default     = "false"
  sensitive   = false
}

variable "SPLUNK_PASSWORD" {
  type        = string
  description = "Splunk password"
  sensitive   = true
}

variable "SPLUNK_DOWNLOAD_SHA512" {
  type        = string
  description = "SHA512 checksum for Splunk package"
  sensitive   = false
}

# URL construction (concatenation is OK)
locals {
  proxmox_url = "${var.PROXMOX_VE_ENDPOINT}/api2/json"
}

# ==============================================================================
# NON-SECRET VARIABLES - Defined in variables.pkrvars.hcl (committed to git)
# ==============================================================================

variable "SPLUNK_VERSION" {
  type        = string
  description = "Splunk Enterprise version (e.g., 10.0.2)"
}

variable "SPLUNK_BUILD" {
  type        = string
  description = "Splunk build hash (e.g., e2d18b4767e9)"
}

variable "SPLUNK_ARCHITECTURE" {
  type        = string
  description = "CPU architecture for Splunk package (amd64, arm64)"
}

variable "SPLUNK_USER" {
  type        = string
  description = "User account that owns Splunk files and runs Splunk service"
}

variable "SPLUNK_GROUP" {
  type        = string
  description = "Group that owns Splunk files"
}

variable "SPLUNK_HOME" {
  type        = string
  description = "Splunk installation directory (SPLUNK_HOME)"
}
