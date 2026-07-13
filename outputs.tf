output "vm_ssh_public_key" { value = module.homelab.vm_ssh_public_key }
output "vm_ssh_key_file" { value = module.homelab.vm_ssh_key_file }
output "pools" { value = module.homelab.pools }
output "cloud_init_file_id" { value = module.homelab.cloud_init_file_id }
output "storage_validated" { value = module.homelab.storage_validated }
output "vms" { value = module.homelab.vms }
output "vm_network_info" { value = module.homelab.vm_network_info }
output "containers" { value = module.homelab.containers }
output "container_network_info" { value = module.homelab.container_network_info }
output "acme_certificates" { value = module.homelab.acme_certificates }
output "acme_accounts" { value = module.homelab.acme_accounts }
output "acme_dns_plugins" {
  value     = module.homelab.acme_dns_plugins
  sensitive = true
}
output "ansible_inventory" { value = module.homelab.ansible_inventory }
output "rack_servers" {
  value     = module.homelab.rack_servers
  sensitive = true
}
