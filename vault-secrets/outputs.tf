# Non-sensitive proof outputs only. The demo secret value is NEVER output.

output "demo_secret_path" {
  description = "OpenBao KV v2 path the demo secret was written to"
  value       = "${vault_kv_secret_v2.demo.mount}/${vault_kv_secret_v2.demo.name}"
}

output "demo_secret_version" {
  description = "Version number of the demo secret written to OpenBao"
  value       = tonumber(vault_kv_secret_v2.demo.metadata["version"])
}
