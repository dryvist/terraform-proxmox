variable "rack_servers" {
  description = "Map of rack servers — passed through from the root variables-rack-servers.tf."
  type = map(object({
    chassis     = string
    bmc_ip      = string
    bmc_mac     = string
    service_tag = string
    mgmt_ip     = string
  }))
}
