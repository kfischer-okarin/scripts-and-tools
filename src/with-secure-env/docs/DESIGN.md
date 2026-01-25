# with-secure-env Design

## Problem

Secrets for local scripts and tools end up in plain text `.env` files scattered
around the filesystem.

## Solution

Encrypt the secrets. Add security layers:

1. **Execution approval** - User must approve before secrets are injected (at
   least the first time; session memory / ACLs are on the roadmap)
2. **Keychain-stored encryption key** - Cannot be accessed silently; macOS
   prompts for approval, and the user can permanently allow access for this
   binary

## CLI Commands

```bash
with-secure-env init                      # Generate and store encryption key
with-secure-env edit /path/to/app         # Edit envs for an application
with-secure-env launch /path/to/app args  # Launch with injected envs
```

## Architecture

Humble Object pattern. The `Launcher` struct implements all CLI command logic
and is fully testable. External systems are injected as dependencies:

- `Keychain` - encryption key storage
- `EditDialog` - UI for editing envs
- `PermissionDialog` - UI for launch approval
- `Exec` - process execution (for easy mocking)

## Development Methodology

Behavioral TDD from the Launcher layer. Tests describe behavior in terms of
user-visible outcomes, using test doubles for all external dependencies.

## Storage Format

Envs stored in `{ConfigDir}/envs.json`:

```json
{
  "/path/to/app": {
    "VAR_NAME": "base64(nonce || ciphertext || tag)"
  }
}
```

Each value is independently encrypted (AES-256-GCM) with its own random nonce.
