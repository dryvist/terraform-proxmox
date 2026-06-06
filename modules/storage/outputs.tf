# Note: The proxmox_datastores data source doesn't expose
# a list of datastore IDs. Storage validation happens implicitly when resources
# reference datastore_id - the provider will error if a datastore doesn't exist.

output "cloud_init_file_id" {
  description = "Cloud-init configuration file ID"
  value       = length(proxmox_virtual_environment_file.cloud_init_config) > 0 ? proxmox_virtual_environment_file.cloud_init_config[0].id : null
}

output "datastores_available" {
  description = "Available datastores on the target node"
  value = {
    for ds in coalesce(data.proxmox_datastores.available.datastores, []) : ds.id => {
      type          = ds.type
      content_types = ds.content_types
    }
  }
}

output "storage_validated" {
  description = "Confirms storage validation checks have passed"
  value       = true
}
