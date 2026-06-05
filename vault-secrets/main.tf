terraform {
  required_version = ">= 1.10"

  required_providers {
    vault = {
      source  = "hashicorp/vault"
      version = "~> 5.9"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.7"
    }
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.1"
    }
  }
}

# Vault (OpenBao) provider — authenticates via AppRole.
# address / role_id / secret_id come from Doppler env vars (see terragrunt.hcl).
provider "vault" {
  address = var.vault_addr

  auth_login_approle {
    role_id   = var.vault_role_id
    secret_id = var.vault_secret_id
  }
}

# Reuse the existing security module to generate a demo password + SSH key pair.
module "security" {
  source = "../modules/security"
}

# Write the generated credentials into OpenBao to prove the write path.
# The KV v2 mount "secret" is enabled by the openbao Ansible role.
resource "vault_kv_secret_v2" "demo" {
  mount = "secret"
  name  = "homelab/demo/vm"

  data_json = jsonencode({
    password    = module.security.vm_password
    private_key = module.security.vm_private_key
    public_key  = module.security.vm_public_key
  })
}

# Read the same path back to prove the read path.
data "vault_kv_secret_v2" "demo_read" {
  mount = "secret"
  name  = "homelab/demo/vm"

  depends_on = [vault_kv_secret_v2.demo]
}
