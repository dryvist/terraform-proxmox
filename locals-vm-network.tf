# Per-VM addressing locals — extracted from locals.tf so that file stays under
# the shared _file-size workflow's 12 KB limit (locals merge across files in a
# module, so this is a pure relocation with no behavior change). Mirrors the
# container_* addressing locals in locals.tf.

locals {
  # Per-VM IPv4/gateway, same DRY + short-circuit rules as containers, so a VM
  # can carry a 6-7-digit positional VMID (which overflows the /24 host space)
  # by going DHCP-first (dhcp = true) or pinning a static ipv4_address. The
  # cidrhost derive branch is reached ONLY when neither is set (legacy ≤254 ids),
  # exactly mirroring container_ipv4 — see the extended note in that block.
  vm_ipv4 = {
    for k, v in var.vms : k => (
      try(v.dhcp, false) ? "dhcp" : (
        try(v.ip_config.ipv4_address, null) != null
        ? nonsensitive(v.ip_config.ipv4_address)
        : nonsensitive("${cidrhost(var.network_cidrs[v.vlan], v.vm_id)}/${split("/", var.network_cidrs[v.vlan])[1]}")
      )
    )
  }
  vm_gateway = {
    for k, v in var.vms : k => (
      try(v.dhcp, false) ? null : nonsensitive(cidrhost(var.network_cidrs[v.vlan], 1))
    )
  }

  # Deterministic MAC + reserved IP + advertised address for DHCP-first VMs —
  # identical join-key shape to the container_* locals so tofu-unifi pins the
  # reservation and technitium_dns points the A record at the same address.
  vm_mac = {
    for k, v in var.vms : k => format("02:%s:%s:%s:%s:%s",
      substr(md5(v.name), 0, 2), substr(md5(v.name), 2, 2),
      substr(md5(v.name), 4, 2), substr(md5(v.name), 6, 2),
    substr(md5(v.name), 8, 2))
  }
  vm_reserved_ip = {
    for k, v in var.vms : k => (
      try(v.dhcp, false) && try(v.reserved_host, null) != null
      ? nonsensitive(cidrhost(var.network_cidrs[v.vlan], v.reserved_host)) : null
    )
  }
  vm_address = {
    for k, v in var.vms : k => (
      try(v.dhcp, false)
      ? (var.domain != "" ? "${v.name}.${var.domain}" : v.name)
      : split("/", local.vm_ipv4[k])[0]
    )
  }
}
