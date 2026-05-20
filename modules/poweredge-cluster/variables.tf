variable "poweredge_nodes" {
  description = "Map of PowerEdge nodes — passed through from the root variables-poweredge.tf."
  type = map(object({
    chassis     = string
    idrac_ip    = string
    idrac_mac   = string
    service_tag = string
    mgmt_ip     = string
  }))
}
