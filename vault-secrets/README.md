# OpenBao Application Secret Workspace

The `tofu-proxmox-vault-secrets` Terrakube workspace manages application
secret material in OpenBao. Terrakube authenticates with workload identity and
injects a short-lived `VAULT_TOKEN`; no AppRole secret or root token is stored
in repository or workspace variables.

```bash
tofu init -backend=false
tofu validate
```

Credentialed plans and applies run only in Terrakube.
