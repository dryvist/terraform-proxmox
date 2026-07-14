# OpenTofu Validation Guidelines

## Repository Context

This is an OpenTofu repository for Proxmox Virtual Environment infrastructure
management. Plans, applies, and state operations run remotely in a self-hosted
Terrakube workspace (state in RustFS, locking in Terrakube); Terragrunt and the
per-project S3/DynamoDB backend are retired. Local checks are static only and
need no credentials.

## Validation Priorities

### High Priority Checks

- **Syntax**: Ensure `tofu validate` passes (`tofu init -backend=false` first).
- **Code Formatting**: Check if `tofu fmt` is needed.
- **Tests**: Verify `tofu test` passes.
- **Plans/applies are remote**: Never gate a commit on a plan/apply — those run
  in the Terrakube workspace under OIDC, not locally.

### Security Considerations

- **No Hardcoded Secrets**: Scan for API tokens, passwords, or sensitive data.
  Provider credentials come from OpenBao via ephemeral resources, never state.
- **Variable Usage**: Prefer variables over hardcoded values.
- **State File Safety**: Ensure no state files are being committed.

### Infrastructure-Specific Concerns

- **Resource Naming**: Follow consistent naming conventions.
- **Network Configurations**: Validate network settings make sense.
- **VM Specifications**: Ensure resource allocations are reasonable.
- **Dependencies**: Check for resource dependency issues.

## Suggested Validation Flow

1. Run the static checks: `tofu init -backend=false`, `tofu validate`,
   `tofu fmt -check`, `tofu test`.
2. Check for formatting issues and suggest fixes.
3. Scan for sensitive data exposure.
4. Verify infrastructure changes make logical sense.
5. Suggest a testing approach for changes.

## Common Issues to Watch For

- Hardcoded IP addresses that should be derived (`cidrhost(...)`) or variables.
- API endpoints that should reference variables.
- Resource conflicts or naming collisions.
- Provider version compatibility.

## Flexibility Notes

- Use discretion when validation tools aren't available.
- Adapt validation based on the scope of changes.
- Consider the impact level of modifications.
- Balance thoroughness with practicality.
