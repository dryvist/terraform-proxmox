# Container variables: LXC container definitions and configuration

variable "containers" {
  description = "Map of containers to create"
  type = map(object({
    vm_id       = number
    hostname    = string
    description = optional(string)
    tags        = optional(list(string), ["terraform", "container"])
    pool_id     = optional(string)

    # Node placement (optional). When unset, main.tf defaults to var.proxmox_node
    # (the primary node). Set to "pve2"/"pve3" to place an LXC on another cluster node.
    node_name = optional(string)

    # Resource configuration
    cpu_cores        = optional(number, 2)
    memory_dedicated = optional(number, 512)
    memory_swap      = optional(number, 512)

    # Storage
    root_disk = optional(object({
      datastore_id = optional(string)
      size         = optional(number, 16)
    }), {})

    # Mount points (additional volumes mounted into the container)
    mount_points = optional(list(object({
      volume = string
      size   = string
      path   = string
    })), [])

    # Network
    network_interfaces = optional(list(object({
      name     = optional(string, "eth0")
      bridge   = optional(string, "vmbr0")
      firewall = optional(bool, true)
    })), [{ name = "eth0", bridge = "vmbr0", firewall = true }])

    # Initialization
    ip_config = optional(object({
      ipv4_address = optional(string)
      ipv4_gateway = optional(string)
    }), {})

    # User account configuration
    user_account = optional(object({
      username = string
      password = string
      keys     = list(string)
    }))

    unprivileged  = optional(bool, false)
    protection    = optional(bool, false)
    os_type       = optional(string, "debian")
    start_on_boot = optional(bool, true)

    # LXC features (set nesting=true for Docker-in-LXC on unprivileged containers;
    # privileged containers run Docker without features — requires root@pam to set any flag)
    features = optional(object({
      nesting = optional(bool, false)
      keyctl  = optional(bool, false)
      fuse    = optional(bool, false)
      mount   = optional(list(string), [])
    }), { nesting = false, keyctl = false, fuse = false, mount = [] })
  }))
  default = {}

  validation {
    condition = alltrue([
      for k, v in var.containers : v.vm_id >= 100 && v.vm_id <= 999999999
    ])
    error_message = "Container IDs must be between 100 and 999999999."
  }

  validation {
    condition = alltrue([
      for k, v in var.containers : v.cpu_cores >= 1 && v.cpu_cores <= 32
    ])
    error_message = "Container CPU cores must be between 1 and 32."
  }

  validation {
    condition = alltrue([
      for k, v in var.containers : v.memory_dedicated >= 64 && v.memory_dedicated <= 65536
    ])
    error_message = "Container memory must be between 64 MB and 64 GB."
  }
}
