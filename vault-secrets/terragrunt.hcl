# Terragrunt configuration for the vault-secrets unit
# Applied AFTER OpenBao is live; proves the Terraform read+write loop against
# OpenBao via the AppRole-authenticated Vault provider.
# COMPLETELY SEPARATE from Proxmox and aws-infra state.

terraform {
  source = "."
}

# Remote state backend configuration using S3 + DynamoDB
# Uses a DIFFERENT state key than aws-infra and Proxmox to keep states isolated
remote_state {
  backend = "s3"
  generate = {
    path      = "backend.tf"
    if_exists = "overwrite_terragrunt"
  }
  config = {
    bucket         = "terraform-proxmox-state-useast2-${get_aws_account_id()}"
    key            = "terraform-proxmox/vault-secrets/terraform.tfstate"
    region         = "us-east-2"
    encrypt        = true
    dynamodb_table = "terraform-proxmox-locks-useast2"

    max_retries = 5
  }
}

# OpenBao connection + AppRole auth from Doppler environment variables.
# VAULT_ADDR / VAULT_ROLE_ID / VAULT_SECRET_ID are populated once the openbao
# Ansible role brings OpenBao live and provisions the Terraform AppRole.
inputs = {
  vault_addr      = get_env("VAULT_ADDR", "")
  vault_role_id   = get_env("VAULT_ROLE_ID", "")
  vault_secret_id = get_env("VAULT_SECRET_ID", "")
  # apps-seed writer (secret/apps/* only), Doppler-published like the main role.
  apps_seed_role_id   = get_env("APPS_SEED_VAULT_ROLE_ID", "")
  apps_seed_secret_id = get_env("APPS_SEED_VAULT_SECRET_ID", "")
}

# Terragrunt will generate provider_override.tf with the Vault provider settings
generate "provider" {
  path      = "provider_override.tf"
  if_exists = "overwrite"
  contents  = <<EOF
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
EOF
}
