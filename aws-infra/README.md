# AWS Infrastructure Workspace

The `tofu-proxmox-aws-infra` Terrakube workspace manages Route53 records with
native OpenTofu. State and locking are owned by Terrakube.

Terrakube workload identity obtains a short-lived OpenBao token. The Vault
provider then requests ephemeral AWS STS credentials from the native
`aws/creds/tf-proxmox` path; no AWS access key is stored in state or workspace
variables. Record definitions are typed Terrakube inputs.

Local validation is backend-free:

```bash
tofu init -backend=false
tofu validate
```

Plans and applies run only in Terrakube.
