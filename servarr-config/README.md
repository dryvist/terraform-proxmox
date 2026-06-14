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
# bucket embeds the AWS account id, so it is passed at init (never committed):
tofu init -backend-config="bucket=terraform-proxmox-state-useast2-$(aws sts get-caller-identity --query Account --output text)"
tofu plan                                        # drift detection — exit 2 = drift
```

State lives in S3 (`terraform-proxmox/servarr-config/terraform.tfstate`). The live
Sonarr/Radarr resources have already been imported (adopted) and `tofu plan` is
clean, so the config manages them with no behavior change.

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

## Drift detection (scheduled)

`.github/workflows/servarr-config-drift.yml` runs `tofu plan -detailed-exitcode`
on a daily schedule (and on `workflow_dispatch`). Exit `2` means the live
Sonarr/Radarr config has drifted from this code; the job alerts ntfy and fails
loudly so the drift is triaged (codify into this module, or revert via apply)
rather than silently clobbered.

It runs on the **self-hosted `terraform` runner** because the *arr APIs are on
the homelab LAN. It is **off by default**; activation is gated on the repo
variable `SERVARR_DRIFT_ENABLED` and these secrets, supplied via the same
`dopplerhq/secrets-fetch-action` pattern the rest of CI uses:

| Where | Key | Note |
| --- | --- | --- |
| Repo variable | `SERVARR_DRIFT_ENABLED` | set to `true` to enable |
| Repo secret | `GH_ACTION_DOPPLER_IAC_CONF_MGMT` | Doppler service token, read `iac-conf-mgmt/prd` |
| Doppler `iac-conf-mgmt/prd` | `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` | the **read-only** AWS account — the read counterpart of the `tf-proxmox` write role (one read role per write role). Plan runs `-lock=false`, so it needs S3 read only, no DynamoDB |
| Doppler `iac-conf-mgmt/prd` | `SONARR_URL`, `SONARR_API_KEY`, `RADARR_URL`, `RADARR_API_KEY` | *arr endpoints + keys |
| Doppler `iac-conf-mgmt/prd` | `QBITTORRENT_HOST`, `QBITTORRENT_ADMIN_PASSWORD` | download-client check |
| Doppler `iac-conf-mgmt/prd` | `AWS_ACCOUNT_ID` | already present; builds the bucket name (no aws CLI on the runner) |
| Doppler `iac-conf-mgmt/prd` | `NTFY_BASE_URL` | optional; without it, the job failure is the only signal |

The read-only AWS account is the one genuinely new principal. It can read state
(which contains the *arr keys), so keep it read-only — one shared read role
paired with the `tf-proxmox` write role, not a per-workflow key.

## Follow-ups

- Prowlarr config via an in-container runner (devopsarr or Configarr executed
  inside download-vpn).
- Configarr for quality profiles / custom formats (TRaSH).
- Retire the Ansible servarr wiring once parity is verified.
