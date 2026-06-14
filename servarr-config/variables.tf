# All real values are supplied at apply time from the secret store
# (SOPS / Doppler / env / a gitignored *.auto.tfvars) — never committed. The
# examples in terraform.tfvars.example use RFC1918 192.168.x placeholders only.

variable "sonarr_url" {
  type        = string
  description = "Base URL of the Sonarr instance (e.g. http://192.168.55.222:8989)."
}

variable "sonarr_api_key" {
  type        = string
  sensitive   = true
  description = "Sonarr API key (SONARR_API_KEY from the secret store)."
}

variable "radarr_url" {
  type        = string
  description = "Base URL of the Radarr instance (e.g. http://192.168.55.223:7878)."
}

variable "radarr_api_key" {
  type        = string
  sensitive   = true
  description = "Radarr API key (RADARR_API_KEY from the secret store)."
}

variable "qbittorrent_host" {
  type        = string
  description = "Host/IP the *arr apps use to reach qBittorrent on the download-vpn LAN address (e.g. 192.168.55.224)."
}

variable "qbittorrent_port" {
  type        = number
  default     = 8080
  description = "qBittorrent WebUI port."
}

variable "qbittorrent_username" {
  type        = string
  default     = "admin"
  description = "qBittorrent WebUI username."
}

variable "qbittorrent_password" {
  type        = string
  sensitive   = true
  description = "qBittorrent WebUI password (QBITTORRENT_ADMIN_PASSWORD from the secret store)."
}

variable "tv_root_folder" {
  type        = string
  default     = "/data/media/tv"
  description = "Sonarr root folder (unified /data hardlink layout)."
}

variable "movie_root_folder" {
  type        = string
  default     = "/data/media/movies"
  description = "Radarr root folder (unified /data hardlink layout)."
}

variable "tv_category" {
  type        = string
  default     = "tv"
  description = "qBittorrent category Sonarr assigns to its downloads."
}

variable "movie_category" {
  type        = string
  default     = "movies"
  description = "qBittorrent category Radarr assigns to its downloads."
}
