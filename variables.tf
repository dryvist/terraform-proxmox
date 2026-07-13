variable "openbao_kv_mount" {
  description = "OpenBao KV v2 mount used by Terrakube workspaces"
  type        = string
  default     = "secret"
}

variable "openbao_object_storage_path" {
  description = "Native OpenBao KV path containing RustFS S3 endpoint and credentials"
  type        = string
  default     = "platform/object-storage"
}

variable "openbao_proxmox_path" {
  description = "Native OpenBao KV path containing Proxmox API and SSH credentials"
  type        = string
  default     = "infrastructure/proxmox"
}

variable "deployment_bucket" {
  description = "RustFS bucket containing private desired state"
  type        = string
  default     = "iac-inventory"
}

variable "deployment_key" {
  description = "RustFS object key containing private desired state"
  type        = string
  default     = "deployment.json"
}

variable "inventory_bucket" {
  description = "RustFS bucket receiving the published Ansible inventory"
  type        = string
  default     = "iac-inventory"
}

variable "inventory_key" {
  description = "RustFS object key receiving the published Ansible inventory"
  type        = string
  default     = "ansible_inventory.json"
}
