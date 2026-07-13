# Nix Development Shell

Run `direnv allow` once per worktree. The shell supplies OpenTofu and static
validation tools. Local use is deliberately backend-free; credentialed plan,
apply, state, and import operations belong to Terrakube.

```bash
tofu fmt -check -recursive
tofu init -backend=false
tofu validate
tofu test
```
