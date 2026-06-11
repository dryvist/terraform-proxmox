# Local values for common computed expressions
locals {
  # DRY per-VLAN Network Configuration - Single Source of Truth.
  # Every guest IP is derived from its VLAN's CIDR (network-form, from Doppler)
  # and its VM ID: cidrhost(network_cidrs[vlan], vm_id). The gateway is the .1
  # host of that same subnet. Masks come from the CIDR itself, so this repo
  # holds zero literal IP octets.
  #
  # var.network_cidrs is `sensitive` so the full subnet map never leaks via a
  # stray `tofu output`/log. Individual resolved values below are wrapped in
  # nonsensitive(): a single host address (<vlan subnet>.<vmid>) or a guest's
  # own gateway is not independently secret, and these must flow into the
  # ansible_inventory output and module inputs (which are non-sensitive),
  # exactly as the terraform-unifi reference resolves its Doppler CIDRs.

  # Splunk lives on the siem VLAN (per network/architecture.md). The siem CIDR
  # is the only VLAN referenced by name here; all other guests resolve via their
  # own `vlan` field below.
  splunk_derived_ip      = nonsensitive("${cidrhost(var.network_cidrs["siem"], var.splunk_vm_id)}/${split("/", var.network_cidrs["siem"])[1]}")
  splunk_network_gateway = nonsensitive(cidrhost(var.network_cidrs["siem"], 1))

  # Per-guest IPv4 (CIDR notation) and gateway, keyed by resource name. IP is
  # cidrhost(<guest VLAN CIDR>, vm_id); gateway is the .1 of that subnet.
  # A container MAY pin a static ipv4_address (CIDR form, e.g. "192.168.5.10/24") to
  # override the vm_id-derived address — for fixed low-number hosts (e.g. a DNS server
  # at .10) whose address must not follow the vm_id. Otherwise derived as usual.
  # DNS-first guests (dhcp = true) resolve to the literal "dhcp" instead: cidrhost is
  # NOT evaluated for them (the ternary short-circuits), so a 6-digit positional VMID
  # that would overflow the /24 host space is fine. Their gateway is null (DHCP-provided).
  container_ipv4 = {
    for k, v in var.containers : k => (
      try(v.dhcp, false) ? "dhcp" : nonsensitive(coalesce(
        try(v.ip_config.ipv4_address, null),
        "${cidrhost(var.network_cidrs[v.vlan], v.vm_id)}/${split("/", var.network_cidrs[v.vlan])[1]}"
      ))
    )
  }
  container_gateway = {
    for k, v in var.containers : k => (
      try(v.dhcp, false) ? null : nonsensitive(cidrhost(var.network_cidrs[v.vlan], 1))
    )
  }

  # Reachable address each container advertises to downstream consumers (the
  # ansible_inventory ip field and the Traefik ingress backend). Static guests
  # advertise their derived host IP (CIDR mask stripped); DNS-first guests
  # (dhcp = true) advertise their FQDN {hostname}.{domain} so nothing downstream
  # pins an address the DHCP lease can change — reachable by name regardless of IP.
  container_address = {
    for k, v in var.containers : k => (
      try(v.dhcp, false)
      ? (var.domain != "" ? "${v.hostname}.${var.domain}" : v.hostname)
      : split("/", local.container_ipv4[k])[0]
    )
  }
  vm_ipv4 = {
    for k, v in var.vms : k =>
    nonsensitive("${cidrhost(var.network_cidrs[v.vlan], v.vm_id)}/${split("/", var.network_cidrs[v.vlan])[1]}")
  }
  vm_gateway = {
    for k, v in var.vms : k => nonsensitive(cidrhost(var.network_cidrs[v.vlan], 1))
  }

  # VGA type validation helper
  valid_vga_types = ["std", "cirrus", "vmware", "qxl"]

  # Management network for the host firewall module: the compute VLAN CIDR
  # (Proxmox hosts live on compute). Inter-VLAN policy is enforced at UniFi;
  # the Proxmox host firewall keeps host-local protection only.
  management_network = nonsensitive(var.network_cidrs["compute"])

  # Splunk cluster IPs (host-form, no mask) for the firewall splunk-cluster
  # rules: the Splunk VM on siem + any containers tagged "splunk" (e.g.
  # splunk-mgmt), each at its own VLAN address.
  splunk_network_ips = nonsensitive(concat(
    [cidrhost(var.network_cidrs["siem"], var.splunk_vm_id)],
    [for k, v in var.containers : cidrhost(var.network_cidrs[v.vlan], v.vm_id) if contains(coalesce(v.tags, []), "splunk")]
  ))

  # Pipeline containers: HAProxy (haproxy tag) and Cribl Edge (cribl + edge tags)
  # These receive syslog and NetFlow data from network devices
  pipeline_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "haproxy") || (
      contains(coalesce(try(v.tags, null), []), "cribl") && contains(coalesce(try(v.tags, null), []), "edge")
    )
  }

  # Notification containers: Mailpit and ntfy (notifications tag)
  notification_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "notifications")
  }

  # Vector database containers: Qdrant (vectordb tag)
  vectordb_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "vectordb")
  }

  # RAG engine containers: LlamaIndex (rag tag)
  rag_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "rag")
  }

  # APT caching proxy containers: apt-cacher-ng (apt-cache tag)
  apt_cacher_ng_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "apt-cache")
  }

  # MinIO object storage containers (minio tag)
  minio_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "minio")
  }

  # Infisical secrets-management containers (infisical tag)
  infisical_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "infisical")
  }

  # OpenBao secrets-management containers (openbao tag)
  openbao_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "openbao")
  }

  # HAProxy LXCs (haproxy tag) — receive delivered ACME certs for HTTPS frontends.
  # Distinct from pipeline_container_ids (which also includes Cribl Edge); this
  # local is dedicated to cert-delivery targeting.
  haproxy_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "haproxy")
  }

  # Cribl Stream containers: tagged cribl + stream (receives from Edge, routes to Splunk)
  # Distinct from pipeline_container_ids (HAProxy + Cribl Edge) as it doesn't receive external traffic
  cribl_stream_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "cribl") && contains(coalesce(try(v.tags, null), []), "stream")
  }

  # Cribl Edge containers: tagged cribl + edge. Subset of pipeline_container_ids
  # used by modules/firewall to grant license-telemetry HTTPS egress to Edge
  # without opening it for HAProxy in the same group.
  cribl_edge_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "cribl") && contains(coalesce(try(v.tags, null), []), "edge")
  }

  # iDRAC KVM LXC: tagged "idrac" (domistyle/idrac6-based viewers, Docker-in-LXC)
  idrac_kvm_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "idrac")
  }

  # Network-quality monitoring LXC (smokeping tag "monitoring"): SmokePing web UI
  # (80) + speedtest-exporter metrics (9798). Egress is open (output ACCEPT) so
  # fping/DNS/HTTPS probes can reach internal and external targets freely.
  monitoring_container_ids = {
    for k, v in var.containers : k => v.vm_id
    if contains(coalesce(try(v.tags, null), []), "monitoring")
  }
}
