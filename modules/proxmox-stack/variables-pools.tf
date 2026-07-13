# Pool variables: Proxmox resource pool definitions

variable "pools" {
  description = "Map of resource pools to create"
  type = map(object({
    comment = optional(string)
  }))
  default = {}
}
