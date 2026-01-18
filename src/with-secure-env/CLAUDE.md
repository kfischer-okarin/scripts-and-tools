# with-secure-env - Claude Instructions

A CLI tool that runs processes while injecting environment variables from
encrypted storage, with a Tk GUI permission dialogue.

## Commands

```bash
# Run all tests
bundle exec rake test

# Run the CLI locally
bundle exec ./exe/with-secure-env run /path/to/binary
bundle exec ./exe/with-secure-env edit /path/to/binary
bundle exec ./exe/with-secure-env list
```

## Architecture

- `SecureEnvLauncher` - Orchestrator that coordinates launching with env injection
- `EnvStorage` - Handles encrypted secret storage + Keychain for encryption key
- `AccessPolicy` - Shows Tk permission UI, returns allow/deny
- `EnvEditor` - Tk form for editing env vars
- `ProcessContext` - Value object representing the process tree
- `CLI` - Thin Thor wrapper

## Security Notes

- Never display secret values in UI, only env var names
- Encryption key stored in macOS Keychain or derived from password
- AES-256-GCM authenticated encryption
- File permissions 0600

## After Changes

After modifying behavior or design, update docs/DESIGN.md accordingly.
