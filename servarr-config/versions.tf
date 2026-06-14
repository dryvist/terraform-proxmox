terraform {
  required_version = ">= 1.6"

  required_providers {
    sonarr = {
      source  = "devopsarr/sonarr"
      version = "~> 3.4"
    }
    radarr = {
      source  = "devopsarr/radarr"
      version = "~> 2.3"
    }
  }
}
