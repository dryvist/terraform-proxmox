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
  remove_failed_downloads    = true

  # devopsarr stores the qBittorrent password write-only, so it can never be read
  # back and would otherwise show as drift on every plan. The password is managed
  # out-of-band (set by the app/secret store); ignore it so tofu plan stays a
  # meaningful drift signal.
  lifecycle {
    ignore_changes = [password]
  }
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
  remove_failed_downloads    = true

  # See the Sonarr client above — password is write-only in devopsarr.
  lifecycle {
    ignore_changes = [password]
  }
}
