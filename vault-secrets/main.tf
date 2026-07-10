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
  # The Terraform AppRole is least-privilege for this module and cannot mint
  # child tokens; use the login token directly.
  skip_child_token = true

  auth_login {
    path = "auth/approle/login"

    parameters = {
      role_id   = var.vault_role_id
      secret_id = var.vault_secret_id
    }
  }
}

# apps-seed provider alias — least-privilege writer scoped to secret/apps/* only
# (cannot touch infra/platform/ai). Per-app service secrets are seeded through
# this role instead of widening terraform-apply's blast radius.
provider "vault" {
  alias            = "apps_seed"
  address          = var.vault_addr
  skip_child_token = true

  auth_login {
    path = "auth/approle/login"

    parameters = {
      role_id   = var.apps_seed_role_id
      secret_id = var.apps_seed_secret_id
    }
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

# --- Nautobot service credentials (generate-if-absent) --------------------------
# The three secrets a native Nautobot needs. Each is generated random ONCE and
# stored in state; re-apply reuses the stored value, so credentials never rotate
# under the running service. ignore_changes pins the generator inputs so a later
# edit to length/special can't silently rotate a live credential either — the
# "keepers / ignore_changes" guard the plan calls for. Only the generated value
# lands in OpenBao at secret/apps/nautobot; no real secret is ever committed.
#
# db_password is the shared Postgres credential Nautobot connects with — it lives
# under apps/nautobot because Nautobot is the first (today, only) consumer of the
# shared DB. It is promoted to a shared path only when a second consumer
# (Vikunja/EspoCRM) actually needs it, per the source-tier secrets rule.
resource "random_password" "nautobot_db_password" {
  length  = 32
  special = false # Postgres connection strings/URLs choke on some specials; alnum is safe

  lifecycle {
    ignore_changes = [length, special, override_special]
  }
}

resource "random_password" "nautobot_secret_key" {
  length  = 64
  special = false # Django/Nautobot SECRET_KEY: alnum avoids env-file quoting hazards downstream

  lifecycle {
    ignore_changes = [length, special, override_special]
  }
}

resource "random_password" "nautobot_superuser_password" {
  length  = 24
  special = false

  lifecycle {
    ignore_changes = [length, special, override_special]
  }
}

# Seed OpenBao (KV v2 mount "secret", enabled by the openbao Ansible role). The
# nautobot Ansible role reads secret/apps/nautobot for its DB, SECRET_KEY, and
# initial superuser.
resource "vault_kv_secret_v2" "nautobot" {
  mount = "secret"
  name  = "apps/nautobot"

  data_json = jsonencode({
    db_password        = random_password.nautobot_db_password.result
    secret_key         = random_password.nautobot_secret_key.result
    superuser_password = random_password.nautobot_superuser_password.result
  })
}

# --- Zammad service credentials (generate-if-absent) --------------------------
# Zammad ITSM's three service secrets, each generated random ONCE and pinned via
# ignore_changes so re-apply never rotates a live credential. Seeded into
# secret/apps/zammad through the least-privilege apps-seed AppRole. Consumers:
# the postgres role creates the shared DB with db_password; the zammad role reads
# db_password + admin_password to bootstrap; the Hermes agent reads
# hermes_api_token (via one narrow cross-consumer read grant) to call the Zammad
# API. One home, generated at the source — no secret is ever committed.
resource "random_password" "zammad_db_password" {
  length  = 32
  special = false # Postgres connection strings/URLs choke on some specials; alnum is safe

  lifecycle {
    ignore_changes = [length, special, override_special]
  }
}

resource "random_password" "zammad_admin_password" {
  length  = 24
  special = false # alnum keeps upper+lower+digit for Zammad's policy, no rails-runner quoting hazards

  lifecycle {
    ignore_changes = [length, special, override_special]
  }
}

resource "random_password" "zammad_hermes_api_token" {
  length  = 48
  special = false # Zammad API tokens are alnum; keeps the Authorization header clean

  lifecycle {
    ignore_changes = [length, special, override_special]
  }
}

resource "vault_kv_secret_v2" "zammad" {
  provider = vault.apps_seed
  mount    = "secret"
  name     = "apps/zammad"

  data_json = jsonencode({
    db_password      = random_password.zammad_db_password.result
    admin_password   = random_password.zammad_admin_password.result
    hermes_api_token = random_password.zammad_hermes_api_token.result
  })
}
