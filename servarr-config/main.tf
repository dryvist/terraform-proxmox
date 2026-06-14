# Declarative Sonarr/Radarr structural config via the devopsarr providers — the
# CI-reachable replacement for the hand-rolled servarr wiring. `tofu plan`
# doubles as drift detection. Prowlarr lives behind the download-vpn killswitch
# and is handled separately (see README); TRaSH custom-formats/quality come from
# Configarr.

provider "sonarr" {
  url     = var.sonarr_url
  api_key = var.sonarr_api_key
}

provider "radarr" {
  url     = var.radarr_url
  api_key = var.radarr_api_key
}

# --- Sonarr ------------------------------------------------------------------
resource "sonarr_root_folder" "tv" {
  path = var.tv_root_folder
}

resource "sonarr_download_client_qbittorrent" "qbittorrent" {
  name                       = "qBittorrent"
  enable                     = true
  priority                   = 1
  host                       = var.qbittorrent_host
  port                       = var.qbittorrent_port
  username                   = var.qbittorrent_username
  password                   = var.qbittorrent_password
  use_ssl                    = false
  tv_category                = var.tv_category
  remove_completed_downloads = true
}

# --- Radarr ------------------------------------------------------------------
resource "radarr_root_folder" "movies" {
  path = var.movie_root_folder
}

resource "radarr_download_client_qbittorrent" "qbittorrent" {
  name                       = "qBittorrent"
  enable                     = true
  priority                   = 1
  host                       = var.qbittorrent_host
  port                       = var.qbittorrent_port
  username                   = var.qbittorrent_username
  password                   = var.qbittorrent_password
  use_ssl                    = false
  movie_category             = var.movie_category
  remove_completed_downloads = true
}
