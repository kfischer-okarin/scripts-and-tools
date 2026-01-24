# Plan: Port with-secure-env to Golang

## Overview
Port the Ruby CLI tool `with-secure-env` to Go using TDD, mirroring the existing Ruby test cases.

## Target Go Version
**Go 1.25.x** (latest stable: 1.25.6)

## Approach
**Kent Beck TDD**: Port Ruby tests one-by-one → write failing Go test → implement minimal code to pass → repeat

---

## Library Choices

| Component | Library | Rationale |
|-----------|---------|-----------|
| **CLI** | `github.com/spf13/cobra` | Maps to Thor's subcommand model. Industry standard. |
| **Keychain** | `github.com/keybase/go-keychain` | Native macOS Security.framework bindings. Cleaner than shelling out. |
| **Crypto** | stdlib `crypto/aes`, `crypto/cipher` | Idiomatic Go AES-256-GCM. No Ruby compatibility needed. |
| **JSON** | stdlib `encoding/json` | Simple file format, stdlib sufficient. |
| **Testing** | stdlib `testing` | Standard Go testing, table-driven where appropriate. |

---

## Test-First Implementation Order

### Phase 1: Launcher Tests (10 tests in Ruby)

Source: `../with-secure-env-ruby/test/secure_env_launcher_test.rb`

| # | Ruby Test | Go Test | Status |
|---|-----------|---------|--------|
| 1 | `test_init_generates_and_returns_key` | `TestInit_GeneratesAndReturnsKey` | ✅ |
| 2 | `test_init_with_existing_key_uses_that_key` | `TestInit_WithExistingKey` | ✅ |
| 3 | `test_list_applications_returns_configured_apps` | `TestListApplications` | ✅ |
| 4 | `test_list_env_keys_returns_keys_for_app` | `TestListEnvKeys` | ✅ |
| 5 | `test_remove_deletes_app_config` | `TestRemove_DeletesConfig` | ✅ |
| 6 | `test_edit_envs_saves_updated_envs` | `TestEditEnvs_SavesUpdatedEnvs` | ✅ |
| 7 | `test_edit_envs_does_not_save_when_cancelled` | `TestEditEnvs_NoSaveOnCancel` | ✅ |
| 8 | `test_raises_unknown_app_when_no_envs_configured` | `TestLaunch_UnknownAppError` | ✅ |
| 9 | `test_raises_permission_denied_when_access_denied_without_accessing_secrets` | `TestLaunch_PermissionDenied_NoSecretsAccess` | ✅ |
| 10 | `test_launches_app_with_envs_and_args_when_access_granted` | `TestLaunch_InjectsEnvVarsAndArgs` | ✅ |

### Phase 2: EnvStorage Tests (11 tests in Ruby)

Source: `../with-secure-env-ruby/test/env_storage_test.rb`

| # | Ruby Test | Go Test | Status |
|---|-----------|---------|--------|
| 1 | `test_init_generates_key_stores_in_keychain_and_returns_it` | `TestInit_GeneratesAndStoresKey` | ⬜ |
| 2 | `test_init_with_existing_key_uses_that_key` | `TestInit_WithProvidedKey` | ⬜ |
| 3 | `test_init_raises_if_file_already_exists` | `TestInit_ErrorIfAlreadyExists` | ⬜ |
| 4 | `test_set_and_get_roundtrip` | `TestSetGet_RoundTrip` | ⬜ |
| 5 | `test_get_returns_empty_hash_for_unknown_app` | `TestGet_EmptyForUnknownApp` | ⬜ |
| 6 | `test_app_configured_returns_false_for_unknown_app` | `TestAppConfigured_False` | ⬜ |
| 7 | `test_app_configured_returns_true_after_set` | `TestAppConfigured_True` | ⬜ |
| 8 | `test_list_applications_returns_all_configured_apps` | `TestListApplications` | ⬜ |
| 9 | `test_available_keys_returns_env_var_names` | `TestAvailableKeys` | ⬜ |
| 10 | `test_remove_deletes_app_config` | `TestRemove_DeletesConfig` | ⬜ |
| 11 | `test_file_format_is_readable_json_with_encrypted_values` | `TestFileFormat_JSONWithEncryptedValues` | ⬜ |

---

## Directory Structure (create as needed)

```
./                              # Current directory (Go project)
├── cmd/with-secure-env/
│   └── main.go
├── internal/
│   ├── launcher/
│   │   ├── launcher.go
│   │   └── launcher_test.go      # Phase 1
│   ├── storage/
│   │   ├── storage.go
│   │   ├── crypto.go
│   │   └── storage_test.go       # Phase 2
│   ├── keychain/
│   │   ├── keychain.go
│   │   └── keychain_darwin.go
│   ├── editor/
│   │   └── editor.go
│   └── policy/
│       └── policy.go
├── go.mod
├── mise.toml
└── PLAN.md

../with-secure-env-ruby/        # Ruby source (reference)
```

---

## Test Double Strategy (matching Ruby)

Ruby uses stub classes in tests. Go equivalent: interface implementations.

```go
// StubStorage, StubPolicy, StubEditor as test doubles
// Track method calls to verify "secrets not accessed before permission"
```

---

## Current Progress

- [x] Initialize Go module (`go.mod`)
- [x] Phase 1: Launcher Tests (10/10) ✅
- [ ] Phase 2: EnvStorage Tests (0/11)
- [ ] CLI wiring

---

## Verification

After all tests pass:
1. `go test ./...` - all tests green
2. Manual CLI smoke test: init → edit → list → exec → remove
