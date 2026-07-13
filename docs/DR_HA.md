# Autonomous DR / HA

The disaster-recovery / high-availability design for the cluster. Owner law:
**DR/HA must be 100% autonomous** — no manual step to detect an outage or switch
nodes. Resilience comes from being cleanly rebuildable and from app-layer
redundancy, not from un-killable guests (ChaosMonkey philosophy).

The cluster runs **four** nodes (`proxmox-1..4`), all quorate. With four real
corosync votes, losing one node keeps quorum (quorum = 3), so HA fencing is safe
— no surviving node self-fences.

The tier-0 guests that must survive a node failure:

| Guest(s) | Redundancy mechanism | DR wave |
| --- | --- | --- |
| ingress (`traefik`, future `traefik-2`) | keepalived VRRP VIP floats across nodes | W1 + W5 |
| OpenBao (`openbao-01`, `openbao-02`, future `openbao-03`) | Raft quorum | W6 |
| DNS (`technitium-dns`, `technitium-dns-2`) | two independent instances | W5 |

## W4 — corosync vote integrity

Target: exactly **N real votes for N nodes**, with **no `two_node` and no manual
`expected_votes` override** in `corosync.conf`. A leftover 2-node override from
the pre-multi-node era changes the quorum math and would break fencing (a lone
survivor could stay quorate and skip self-fencing).

Verified live: four nodes, Expected votes 4, Quorum 3, Quorate — clean, no
overrides. Regression is guarded by `ansible-proxmox`'s `pve_cluster` role,
which fails loud on the primary if either override reappears.

## W5 — PVE HA rules (`ansible-proxmox` `pve_ha` role)

Models Proxmox VE 9 HA (the new "HA rules", not legacy HA groups) as IaC. Inert
by default; enabling is a deliberate, gated step.

When enabled it:

1. Places each tier-0 LXC under HA (`ha-manager add ct:VMID --state started
   --max_restart 3 --max_relocate 1`). VMIDs resolve from the tofu inventory by
   hostname, so a renumber flows through with no edit.
2. Adds `resource-affinity` **negative** rules so the two halves of each
   redundant pair (the OpenBao voters, the Technitium DNS pair, the Traefik
   ingress pair) never share a node.

**Why anti-affinity is the payload, not relocation.** These guests sit on
**local ZFS**, not shared storage, and each already has a redundant peer on
another node. So a crash auto-restarts the guest in place, and a node loss is
covered by the surviving peer (the failed guest returns when its node heals).
Live cross-node relocation would need PVE storage replication (`pvesr`) — a
tracked follow-up, deliberately **not** required for the node-loss story. Hence
`max_relocate` is low; anti-affinity is what keeps each pair genuinely split.

A non-destructive failover drill
(`ansible-proxmox` `scripts/ha-failover-drill.sh`) proves auto-restart +
relocation against a disposable test guest only.

## W6 — OpenBao 3-voter Raft

Today OpenBao is a fragile **2-voter** Raft (`openbao-01` at mgmt host octet
`.4`, `openbao-02` at `.5`) — no quorum tolerance, a single node loss can wedge
it. The target is **3 voters** (add `openbao-03` on `proxmox-4`, mgmt host octet
`.6`), giving real quorum that survives one node loss.

**No ansible role change is needed.** The `openbao` role
(`ansible-proxmox-apps`) is already built for rolling expansion: every node
carries a `retry_join` for each peer (built from the `openbao` group's
container IPs), and `openbao_allow_fresh_init` defaults to `false`, so a new
node joins the existing cluster and self-unseals via the shared static seal
key — it never re-inits and never orphans the live data. Adding the guest to
`deployment.json` and re-converging the `openbao` group is the whole job.

### Topology hazards to resolve BEFORE the live join

The OpenBao guests currently follow **two conflicting schemes** in
`deployment.json`, and this must be reconciled first:

- **Live cluster = explicit** `openbao-01` / `openbao-02` entries in the
  `containers` map. These are the only nodes with a real `/etc/openbao` config
  and live Raft data.
- **`openbao_cluster` generator** (expanded by OpenTofu) currently emits
  **five more** containers (suffixes 10/20/21/30/31). They exist as running
  LXCs but have **no OpenBao config** — orphan shells that were created and
  never converged. Because they carry the `openbao` tag, a full `openbao`
  converge would try to configure and join **all seven**, producing an
  unintended 7-node cluster rather than the intended 3.
- **VMID collision:** the generator's suffix `40` maps to the same VMID as the
  explicit `openbao-01`. Any placement using suffix 40 collides.
- **`protection: true`** on every OpenBao container (repo-law violation: no
  destroy-protection) also blocks cleanly removing the orphan shells. Removed
  from the generator defaults in `deployment.json.example` here; removing it on
  the live containers is a gated apply.

**Reconciliation before adding a 3rd voter:** pick ONE scheme. The lazy, correct
path for a single 3rd voter is to keep the live explicit pair and add an
explicit `openbao-03` (host octet `.6`, on `proxmox-4`, `openbao` tags,
`memory_swap: 0`), then either disable the `openbao_cluster` generator
(`enabled: false`) or remove the five orphan shells so the `openbao` group is
exactly the three real voters. Otherwise a converge joins the orphans too.

### Live join sequence (gated — held for lead approval)

1. Reconcile the orphans (disable generator / remove the 5 shells; drop
   `protection` so they are removable). Verify the `openbao` group resolves to
   exactly `openbao-01/02/03`.
2. Add `openbao-03` to `deployment.json` (private S3 input) and `tofu
   apply` (full apply, never `-target`) to create the LXC on `proxmox-4`.
3. Converge the `openbao` group. `openbao-03` renders its config with
   `retry_join` to `.4/.5`, joins as a 3rd voter, and self-unseals via the
   shared static seal key. `openbao-01/02` re-render to also list `.6`.
4. Verify 3 voters: `pvesh`/`bao operator raft list-peers` shows three voters,
   one leader, all `voter=true`.

**Unseal / recovery:** no new unseal step — the shared static-key auto-unseal
means `openbao-03` unseals itself on start, same as the existing peers. The
recovery shares and root token are unchanged (a join does not re-init). The new
node inherits the automated raft-snapshot timer on converge.

## Media tier

Deliberately **no cluster HA and no vzdump** for the media guests — every one
rebuilds from IaC alone, proven by a live `seerr` destroy/recreate canary
(container replaced, 117-request history intact). The protection budget goes to
the irreplaceable per-app state instead:

- Each app's config/DB lives on its own `bulk/appdata/<app>` dataset,
  bind-mounted over the app's config dir by `ansible-proxmox`
  `media_lxc_features` (seed-before-mount on first cutover).
- `bulk/appdata` is on the sanoid `critical` template (hourly, recursive) and
  syncoid-replicated from the bulk-storage node to the DR node.
- The `bulk/data` library itself is deliberately **unsnapshotted and
  unreplicated** (`com.sun:auto-snapshot=false`): torrent churn makes snapshots
  expensive and the payload is re-acquirable, so a loss is a re-download, not a
  disaster.
- Rebuild path: OpenTofu recreates the LXC → `media_lxc_features` re-mounts the
  persisted appdata (seed skipped, dataset non-empty) → the app role reinstalls
  the runtime. No manual step; vzdump would only duplicate what IaC + appdata
  already guarantee.
