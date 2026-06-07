# Scheduled rebuild: download-vpn LXC

Runbook for [`.github/workflows/rebuild-download-vpn.yml`](../.github/workflows/rebuild-download-vpn.yml)
— the monthly destroy+recreate of the `download-vpn` container (vm_id 214).
Resolves [`dryvist/ansible-proxmox-apps#368`](https://github.com/dryvist/ansible-proxmox-apps/issues/368).

## Why

`download-vpn` runs qBittorrent/Prowlarr behind a Proton WireGuard tunnel with a
fail-closed nftables killswitch that has **no egress hole** — so it cannot refresh
`apt` in steady state. A periodic rebuild is the supported way to pick up security
updates and reset config drift: package installs succeed during the rebuild
because they run on a fresh shell **before** the killswitch is active.

## The dispatch chain

The rebuild is a 3-repo pipeline, sequenced with the org's `repository_dispatch`
GitHub-App-token idiom (the same pattern as `dryvist/.github`'s
`_dispatch-flake-consumers.yml`). Each hop mints a scoped App token and fires a
`repository_dispatch` (`event_type: rebuild-download-vpn`) at the next repo:

1. **terraform-proxmox** — `rebuild-download-vpn.yml` runs
   `terragrunt apply -replace='module.containers[0].proxmox_virtual_environment_container.containers["download-vpn"]'`
   to recreate the bare LXC shell, then dispatches → ansible-proxmox.
2. **ansible-proxmox** — `converge-media-features.yml` re-applies the host
   bind-mounts, `/dev/net/tun`, and keyctl via the `media_lxc_features` role over
   root@pam (the BPG API token cannot). **Required** — without `/dev/net/tun`
   WireGuard cannot start. On success it dispatches → ansible-proxmox-apps.
3. **ansible-proxmox-apps** — `converge-download-vpn.yml` reinstalls packages and
   reconfigures qBittorrent/Prowlarr via the `download_vpn` role.

Each converge workflow also accepts `workflow_dispatch`, so any hop can be run
standalone (`gh workflow run …`).

### Data: lost vs preserved

A rebuild wipes the container rootfs but never touches the mounted media volumes:

+ **Lost** (rootfs, by design — "config drift is reset"): qBittorrent settings,
  Prowlarr indexers/DB, in-flight torrent state (`BT_backup`). Reconfigured from
  SOPS/role defaults; indexers re-seeded and torrents re-added by the *arr stack.
+ **Preserved** (host ZFS bind-mounts): `/mnt/downloads`, `/mnt/media`.

## Runner prerequisites (operator-provisioned)

All execution targets `runs-on: [self-hosted, Linux]` — the org's existing
self-hosted runner label. The homelab is not reachable from GitHub-hosted
runners. The runner must have line-of-sight to the Proxmox node and be pre-baked
(same model as the E2E self-hosted runner) with:

+ **Nix** (workflows use each repo's committed devshell, e.g.
  `nix develop github:dryvist/nix-devenv?dir=shells/terraform`).
+ **AWS credentials** for the S3/DynamoDB state backend
  (`terraform-proxmox-state-useast2-*`, region `us-east-2`) — e.g. an instance
  profile or a pre-configured profile in the runner environment.
+ **Doppler** access to project `iac-conf-mgmt`, config `prd` (provider auth,
  per-VLAN CIDRs, SSH key) — a `DOPPLER_TOKEN` in the runner environment.
+ **SOPS age key** at `SOPS_AGE_KEY_FILE` (default `~/.config/sops/age/keys.txt`)
  for `terraform.sops.json` and the Ansible repos' `secrets.*`.
+ **SSH** to root@pam and the containers, and the inventory pipeline available
  (clone of the private `int_homelab` repo + `GIT_HOME`/`GIT_HOME_PUBLIC`) so the
  post-apply `sync-inventory.sh` hook distributes `tofu_inventory.json` to the
  Ansible repos the converges read.

The `dispatch` job runs on `ubuntu-latest` (no homelab access needed — it only
mints a token and calls the GitHub API).

## Org App token + variables (already provisioned org-wide)

The dispatch hops reuse the same GitHub App that drives
`_dispatch-flake-consumers.yml`:

+ `GH_APP_CLIENT_ID` (repo/org variable) — client id of the org dispatch App.
+ `GH_APP_PRIVATE_KEY` (repo/org secret) — private key used by
  `actions/create-github-app-token` to mint a token scoped to the next repo
  (`contents: write`, required for `repository_dispatch`).

No new PATs, no third-party actions, no SHA-pinned vendor actions — only
`actions/*` (trusted by the shared `zizmor.yml` policy).

## Schedule and manual trigger

+ **Scheduled:** monthly, `cron: "47 9 1 * *"` (1st of month, 09:47 UTC).
+ **Manual (whole chain):**
  `gh workflow run rebuild-download-vpn.yml -R dryvist/terraform-proxmox`
+ **Manual (single hop):**
  `gh workflow run converge-media-features.yml -R dryvist/ansible-proxmox` or
  `gh workflow run converge-download-vpn.yml -R dryvist/ansible-proxmox-apps`

## First run (do this manually, watch it — it is destructive)

1. Confirm the runner is online with `[self-hosted, Linux]` and all
   prerequisites above, and that `GH_APP_CLIENT_ID` / `GH_APP_PRIVATE_KEY`
   resolve in each repo.
2. Dry-run the replace plan to confirm scope (only download-vpn is replaced):
   `aws-vault exec tf-proxmox -- doppler run -p iac-conf-mgmt -c prd -- terragrunt plan -replace='module.containers[0].proxmox_virtual_environment_container.containers["download-vpn"]'`.
   A full apply runs the whole plan; if other media LXCs (210-213) show drift
   from Ansible-applied mounts (mount ForceNew), resolve that before letting the
   scheduled job run unattended.
3. Trigger the chain and watch all three runs; confirm, on the box: `/dev/net/tun`
   bind-mounts present, WireGuard up, killswitch active, the `download_vpn`
   deploy-time validator green, and the web UIs reachable cross-subnet.

## Rollback

The container is recreated from declarative config, so "rollback" = re-running the
converges (idempotent) or restoring from a Proxmox backup if one exists. The
preserved media volumes are never touched by the rebuild.
