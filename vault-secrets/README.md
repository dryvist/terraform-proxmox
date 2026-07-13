# OpenBao Application Secret Root

This root generates application service credentials (demo, Nautobot, Zammad) and
seeds them into OpenBao under `secret/apps/*`.

It is **not** a Terrakube workspace. Because it writes `secret/apps/*`, it must
not run under a Terrakube machine identity (OpenBao admin-write gate). The
Terrakube `cloud{}` wiring was removed; its backend and auth are unresolved
pending a decision on the root's home — the most likely outcome is folding this
seeding into the human-gated `openbao` Ansible role. Until then it writes via
the Doppler-published `apps-seed` AppRole, the sanctioned human-gated writer for
`secret/apps/*`.

## Installation

No standalone install. The root is consumed by the tofu-proxmox toolchain (Nix
dev shell provides `tofu`); the `apps-seed` AppRole credentials are published via
Doppler.

## Usage

```bash
tofu init -backend=false
tofu validate
```

Credentialed plans and applies are gated pending the backend/home decision
above; do not run them until the root's execution path is resolved.
