variable "node_name" {
  description = "Proxmox node name"
  type        = string
}

variable "splunk_vm_ids" {
  description = "Map of Splunk VM names to their IDs"
  type        = map(number)
  default     = {}
}

variable "splunk_container_ids" {
  description = "Map of Splunk container names to their IDs"
  type        = map(number)
  default     = {}
}

variable "pipeline_container_ids" {
  description = "Map of pipeline container names to their IDs (HAProxy, Cribl Edge - receive NetFlow/syslog)"
  type        = map(number)
  default     = {}
}

variable "notification_container_ids" {
  description = "Map of notification container names to their IDs (Mailpit, ntfy)"
  type        = map(number)
  default     = {}
}

variable "vectordb_container_ids" {
  description = "Map of vector database container names to their IDs (Qdrant)"
  type        = map(number)
  default     = {}
}

variable "rag_container_ids" {
  description = "Map of RAG engine container names to their IDs (LlamaIndex)"
  type        = map(number)
  default     = {}
}

variable "apt_cacher_ng_container_ids" {
  description = "Map of APT caching proxy container names to their IDs (apt-cacher-ng)"
  type        = map(number)
  default     = {}
}

variable "cribl_stream_container_ids" {
  description = "Map of Cribl Stream container names to their IDs (receives from Edge, routes to Splunk)"
  type        = map(number)
  default     = {}
}

variable "minio_container_ids" {
  description = "Map of MinIO container names to their IDs"
  type        = map(number)
  default     = {}
}

variable "infisical_container_ids" {
  description = "Map of Infisical secrets-management container names to their IDs"
  type        = map(number)
  default     = {}
}

variable "idrac_kvm_vm_ids" {
  description = "Map of iDRAC KVM host VM names to IDs (tag-driven, set by root locals)"
  type        = map(number)
  default     = {}
}

variable "management_network" {
  description = "CIDR of management network for SSH/Web access. Configure in terraform.tfvars for your environment."
  type        = string
  # No default - must be specified in .tfvars for environment-specific configuration
}

variable "splunk_network" {
  description = "Comma-separated list of Splunk node IPs for cluster communication. Configure in terraform.tfvars for your environment."
  type        = string
  # No default - must be specified in .tfvars for environment-specific configuration
}

variable "pipeline_constants" {
  description = "Single source of truth for service/syslog/netflow/notification/vector-db ports. Sourced from root locals.pipeline_constants so port literals stay defined exactly once across the whole repo."
  type = object({
    service_ports      = map(number)
    syslog_ports       = map(number)
    netflow_ports      = map(number)
    notification_ports = map(number)
    vector_db_ports    = map(number)
  })
}

variable "internal_networks" {
  description = "RFC1918 networks allowed to access Splunk (SSH, Web UI, forwarding port 9997)"
  type        = list(string)
  default     = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]

  validation {
    condition     = length(var.internal_networks) > 0
    error_message = "internal_networks must contain at least one CIDR — cannot generate firewall rules with no source networks."
  }

  validation {
    condition = alltrue([
      for net in var.internal_networks :
      can(cidrnetmask(net))
    ])
    error_message = "Each internal_networks entry must be a valid CIDR block, for example 10.0.0.0/8."
  }
}
