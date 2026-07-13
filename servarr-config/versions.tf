terraform {
  required_version = ">= 1.11"

  cloud {
    organization = "dryvist"

    workspaces {
      name = "tofu-proxmox-servarr-config"
    }
  }

  required_providers {
    sonarr = {
      source  = "devopsarr/sonarr"
      version = "~> 3.4"
    }
    radarr = {
      source  = "devopsarr/radarr"
      version = "~> 2.3"
    }
    vault = {
      source = "hashicorp/vault"
    }
  }
}
