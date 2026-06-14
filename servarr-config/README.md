# servarr-config

Declarative Sonarr/Radarr structural config via the
[devopsarr](https://registry.terraform.io/namespaces/devopsarr) Terraform
providers. This is the config-as-code replacement for the hand-rolled servarr
wiring: a destroyed/rebuilt app is reconfigured from code, and `tofu plan`
doubles as drift detection.

This config is **self-contained** — it has its own state and is **not** part of
the main terragrunt workspace, so it never touches the cluster/container state.

## Requirements

| Requirement | Version / Note |
| --- | --- |
| OpenTofu / Terraform | `>= 1.6` |
| `devopsarr/sonarr` provider | `~> 3.4` |
| `devopsarr/radarr` provider | `~> 2.3` |
| Network | the runner must reach the Sonarr/Radarr APIs (LAN/CI; not the VPN-locked Prowlarr) |
| Secrets | Sonarr/Radarr API keys + qBittorrent password from the secret store |

## Scope (phase 1)

Manages the CI-reachable apps only:

| App | Resources |
| --- | --- |
| Sonarr | `root_folder` (`/data/media/tv`), `download_client_qbittorrent` |
| Radarr | `root_folder` (`/data/media/movies`), `download_client_qbittorrent` |

Not yet here (see Follow-ups):

- **Prowlarr** (indexers + Sonarr/Radarr app links) — it runs behind the
  download-vpn killswitch, so it is **not reachable from CI/a workstation**. It
  must be driven from inside that container, not from this CI config.
- **Quality profiles / custom formats / media-management** — these are
  community-maintained content best sourced from
  [Configarr](https://configarr.de/) / [Recyclarr](https://recyclarr.dev/)
  ([TRaSH-Guides](https://trash-guides.info/)) rather than hand-declared.

## Usage

```bash
cp terraform.tfvars.example local.auto.tfvars   # gitignored; fill from secret store
tofu init
tofu plan                                        # drift detection — no changes applied
```

Real values (URLs, API keys, qBittorrent password) come from the secret store
(SOPS / Doppler / env), never committed. The example file uses RFC1918
placeholders only.

## Adopting an already-configured instance (import, don't clobber)

The live apps already have these resources. Import them before the first apply
so `tofu` adopts the existing config instead of trying to recreate it:

```bash
tofu import sonarr_root_folder.tv <id>
tofu import sonarr_download_client_qbittorrent.qbittorrent <id>
tofu import radarr_root_folder.movies <id>
tofu import radarr_download_client_qbittorrent.qbittorrent <id>
```

IDs come from each app's API (`GET /api/v3/rootfolder`,
`GET /api/v3/downloadclient`). After import, `tofu plan` should be clean.

## Follow-ups

- Prowlarr config via an in-container runner (devopsarr or Configarr executed
  inside download-vpn).
- Configarr for quality profiles / custom formats (TRaSH).
- Retire the Ansible servarr wiring once parity is verified.
- Wire a scheduled `tofu plan -detailed-exitcode` for drift alerting.
