# Infrastructure variables: environment identity and Proxmox host connectivity

variable "domain" {
  description = "Internal domain for FQDN resolution (e.g., example.com)"
  type        = string
  default     = ""
}

variable "environment" {
  description = "Environment name for resource tagging and organization"
  type        = string
  default     = "homelab"
}

variable "proxmox_node" {
  description = "The name of the Proxmox node to deploy resources on"
  type        = string
  default     = "pve"
}

variable "proxmox_ssh_username" {
  description = "The SSH username for connecting to the Proxmox node (for cloud-init, etc.)"
  type        = string
  default     = "root@pam"
}

variable "proxmox_ssh_private_key" {
  description = "The SSH private key content for connecting to the Proxmox node (use secure parameter store or environment variable)"
  type        = string
  sensitive   = true
  default     = "~/.ssh/id_rsa"
  validation {
    condition     = can(regex("^(~/.ssh/|/.*|-----BEGIN)", var.proxmox_ssh_private_key))
    error_message = "SSH private key must be either a file path starting with ~/ or /, or the actual key content starting with -----BEGIN."
  }
}

variable "proxmox_ssh_host" {
  description = "Hostname or IP for SSH access to the Proxmox node. Used by the acme-certificate module's null_resource provisioner to deliver issued certs to LXCs/VMs. Sourced from PROXMOX_VE_HOSTNAME via Doppler/terragrunt."
  type        = string
  default     = ""
}
