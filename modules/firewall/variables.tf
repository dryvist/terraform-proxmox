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

variable "cribl_edge_container_ids" {
  description = "Map of Cribl Edge container names to their IDs. Subset of pipeline_container_ids that additionally gets license-telemetry HTTPS egress (HAProxy in the same group does not)."
  type        = map(number)
  default     = {}
}

variable "minio_container_ids" {
  description = "Map of MinIO container names to their IDs (DEPRECATED — kept during the RustFS migration soak; remove after object-storage cutover)"
  type        = map(number)
  default     = {}
}

variable "object_storage_container_ids" {
  description = "Map of object storage (RustFS) container names to their IDs"
  type        = map(number)
  default     = {}
}

variable "infisical_container_ids" {
  description = "Map of Infisical secrets-management container names to their IDs"
  type        = map(number)
  default     = {}
}

variable "openbao_container_ids" {
  description = "Map of OpenBao secrets-management container names to their IDs"
  type        = map(number)
  default     = {}
}

variable "idrac_kvm_container_ids" {
  description = "Map of iDRAC KVM LXC names to IDs (tag-driven, set by root locals)"
  type        = map(number)
  default     = {}
}

variable "monitoring_container_ids" {
  description = "Map of network-quality monitoring LXC names to IDs (SmokePing + speedtest-exporter, tag-driven)"
  type        = map(number)
  default     = {}
}

variable "hermes_agent_container_ids" {
  description = "Map of Hermes Agent LXC names to IDs (tag-driven). Autonomous agent: internal access + outbound to internal services + outbound HTTPS for its web tools."
  type        = map(number)
  default     = {}
}

variable "ai_orchestration_container_ids" {
  description = "Map of AI orchestration LXC names to IDs (tag-driven: Dify, LangFlow, agent-exec). Inbound UI ports from internal + outbound internal/HTTPS (model endpoints, external APIs)."
  type        = map(number)
  default     = {}
}

variable "langfuse_container_ids" {
  description = "Map of Langfuse LLM-observability LXC names to IDs (tag-driven). Inbound web/OTLP-ingest (3000) from internal + outbound internal/HTTPS."
  type        = map(number)
  default     = {}
}

variable "management_network" {
  description = "CIDR of management network for SSH/Web access. Configure in terraform.tfvars for your environment."
  type        = string
  # No default - must be specified in .tfvars for environment-specific configuration
}

variable "ai_network" {
  description = "CIDR of the AI VLAN — source scope for the Cribl Edge OTLP ingest (only AI-orchestration apps emit OpenTelemetry). Derived from the Doppler-sourced network_cidrs map in root locals; never committed."
  type        = string
}

variable "splunk_network" {
  description = "Comma-separated list of Splunk node IPs for cluster communication. Configure in terraform.tfvars for your environment."
  type        = string
  # No default - must be specified in .tfvars for environment-specific configuration
}

variable "pipeline_constants" {
  description = "Single source of truth for service/syslog/netflow/notification/vector-db ports. Sourced from root locals.pipeline_constants so port literals stay defined exactly once across the whole repo."
  type = object({
    service_ports = map(number)
    syslog_ports  = map(number)
    syslog_port_map = map(object({
      standard   = number
      high       = number
      index      = string
      sourcetype = string
    }))
    netflow_ports      = map(number)
    notification_ports = map(number)
    vector_db_ports    = map(number)
  })
}

variable "internal_networks" {
  description = "Internal CIDRs allowed through guest firewalls (SSH, service ports). No default — the real ranges come from Doppler via the root module and are never committed."
  type        = list(string)

  validation {
    condition     = length(var.internal_networks) > 0
    error_message = "internal_networks must contain at least one CIDR — cannot generate firewall rules with no source networks."
  }

  validation {
    condition = alltrue([
      for net in var.internal_networks :
      can(cidrnetmask(net))
    ])
    error_message = "Each internal_networks entry must be a valid CIDR block, for example 192.168.0.0/16."
  }
}
