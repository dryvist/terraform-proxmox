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

Out of scope for this module (owned elsewhere):

- **Prowlarr** (indexers + Sonarr/Radarr app links) — it runs behind the
  download-vpn killswitch, so it is **not reachable from CI/a workstation**. It is
  driven from inside that container by the Ansible `servarr_wiring` role, not this
  module.
- **Quality profiles / custom formats / media-management** — community-maintained
  TRaSH content, applied by the Ansible `configarr` role
  ([Configarr](https://configarr.de/) / [Recyclarr](https://recyclarr.dev/) /
  [TRaSH-Guides](https://trash-guides.info/)) rather than hand-declared.

## Usage

```bash
cp terraform.tfvars.example local.auto.tfvars   # gitignored; fill from secret store
# bucket embeds the AWS account id, so it is passed at init (never committed):
tofu init -backend-config="bucket=terraform-proxmox-state-useast2-$(aws sts get-caller-identity --query Account --output text)"
tofu plan                                        # drift detection — exit 2 = drift
```

State lives in S3 (`terraform-proxmox/servarr-config/terraform.tfstate`). The live
Sonarr/Radarr resources have already been imported (adopted) and `tofu plan` is
clean, so the config manages them with no behavior change.

Drift detection is **on-demand by design**: run `tofu plan` when you want it. A
scheduled CI workflow was considered and rejected as disproportionate for a
module this small (automating it against the LAN-only *arr APIs would need a
self-hosted runner + a read-only state credential + an enable gate).

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

- Retire the Sonarr/Radarr download-client + root-folder wiring from the Ansible
  `servarr_wiring` role once a live apply of this module proves parity — this
  module and the `configarr` role then own that config. (Prowlarr + the
  deterministic API keys stay in `servarr_wiring`.)
