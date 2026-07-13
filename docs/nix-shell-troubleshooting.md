# Nix Shell Troubleshooting

If direnv does not activate, run `direnv allow` and confirm `tofu version`.
Local initialization must use `-backend=false`. If a command requests live
credentials or remote state, stop and run it through the private Terrakube
workspace instead.
