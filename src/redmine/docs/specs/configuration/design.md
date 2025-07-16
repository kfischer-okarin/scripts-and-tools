# Design Document: Configuration Feature

## Overview

This design document outlines the technical implementation for the configuration
management feature of the Redmine CLI tool. The feature enables users to set and
view Redmine connection settings (URL and API key) through command-line
interface commands, providing a user-friendly alternative to manual file
editing.

### Design Goals

1. **Security**: Protect sensitive API keys with appropriate file permissions
   and storage practices
2. **Portability**: Support cross-platform configuration storage following OS
   conventions
3. **Simplicity**: Provide intuitive commands for setting and viewing
   configuration
4. **Reliability**: Ensure configuration persists between sessions with proper
   error handling
5. **Extensibility**: Design for future configuration options without breaking
   changes

## Architecture

### High-Level Architecture

```text
┌─────────────────┐
│   CLI Layer     │
│  (Cobra CLI)    │
└────────┬────────┘
         │
┌────────▼────────┐
│ Config Commands │
│  (config.go)    │
└────────┬────────┘
         │
┌────────▼────────┐
│ Config Manager  │
│  (manager.go)   │
└────────┬────────┘
         │
┌────────▼────────┐
│   File Store    │
│ (filestore.go)  │
└────────┬────────┘
         │
┌────────▼────────┐
│  File System    │
│   (OS-native)   │
└─────────────────┘
```

### Module Structure

```text
internal/
├── cli/
│   ├── config/
│   │   ├── config.go        # Config command group
│   │   ├── set.go          # Set command implementation
│   │   └── show.go         # Show command implementation
├── config/
│   ├── config.go           # Config structure (existing)
│   ├── manager.go          # Configuration management logic
│   ├── filestore.go        # File-based storage implementation
│   └── paths.go            # Cross-platform path resolution
```

## Components and Interfaces

### 1. CLI Commands

**Purpose**: Handle command-line interface for configuration management

**Components**:

- `internal/cli/config/config.go`: Config command group
- `internal/cli/config/set.go`: Set subcommand implementation
- `internal/cli/config/show.go`: Show subcommand implementation

**Command Structure**:

```bash
redmine config set url <URL>
redmine config set api-key <KEY>
redmine config set project-id <ID>
redmine config show
```

### 2. Configuration Manager

**Purpose**: Business logic for configuration operations

**Interface**:

```go
type ConfigManager interface {
    Set(key string, value string) error
    Get(key string) (string, error)
    GetAll() (*Config, error)
    Save(config *Config) error
}

type configManager struct {
    store ConfigStore
}
```

**Supported Keys**:

- `url`: Redmine server URL
- `api-key`: API authentication key
- `project-id`: Default Redmine project identifier

### 3. Configuration Storage

**Purpose**: Persist configuration to filesystem with security

**Interface**:

```go
type ConfigStore interface {
    Load() (*Config, error)
    Save(config *Config) error
    Exists() bool
    GetPath() string
}

type fileStore struct {
    path string
}
```

### 4. Path Resolution

**Purpose**: Determine appropriate configuration file location per OS

**Implementation Strategy**:

- Use XDG Base Directory specification on Linux/Unix
- Use standard application data directories on Windows/macOS
- Fall back to home directory if XDG not available

**Path Hierarchy**:

1. `$XDG_CONFIG_HOME/redmine/cli-config.json` (Linux/Unix)
2. `$HOME/.config/redmine/cli-config.json` (Linux/Unix fallback)
3. `$HOME/Library/Application Support/redmine/cli-config.json` (macOS)
4. `%APPDATA%\redmine\cli-config.json` (Windows)

## Data Models

### Configuration File Format

**Format**: JSON (human-readable, widely supported)

**Structure**:

```json
{
  "url": "https://redmine.example.com",
  "api_key": "your-api-key-here",
  "project_id": "sample-project"
}
```

### Config Structure Updates

The existing `Config` struct will be enhanced with JSON tags:

```go
type Config struct {
    BaseURL   string `json:"url,omitempty"`
    APIKey    string `json:"api_key,omitempty"`
    ProjectID string `json:"project_id,omitempty"` // Keep for future use
}
```

### Migration Strategy

The `LoadConfig()` function will be updated to:

1. Check for configuration file
2. Load from file if exists
3. Fall back to hardcoded values if not configured
4. Return appropriate errors for missing configuration

## Error Handling

### Error Types

1. **File System Errors**

   - Permission denied (creating directory/file)
   - Disk full
   - Invalid path

2. **Configuration Errors**

   - Invalid URL format
   - Empty values for required fields
   - Malformed configuration file

3. **Security Errors**

   - Insecure file permissions detected
   - Configuration directory not writable

### Error Messages

User-friendly error messages with actionable guidance:

```go
var errorMessages = map[ErrorType]string{
    PermissionError:     "Unable to save configuration: permission denied",
    InvalidURLError:     "Invalid URL format. Please provide a valid HTTPS URL",
    EmptyValueError:     "Configuration value cannot be empty",
    FileCorruptedError:  "Configuration file is corrupted. Please reconfigure",
    InsecureFileError:   "Configuration file has insecure permissions",
}
```

### Security Measures

1. **File Permissions**

   - Set configuration file to 0600 (owner read/write only)
   - Verify permissions on load, warn if insecure

2. **Directory Permissions**

   - Create configuration directory with 0700 permissions
   - Ensure parent directories have appropriate permissions

3. **Validation**

   - Validate URL format (require HTTPS for security)
   - Sanitize input to prevent injection attacks
   - Never log or display API keys in output

## Testing Strategy

### Unit Tests

1. **Configuration Manager Tests**

   ```go
   // internal/config/manager_test.go
   - Test Set() with valid/invalid keys
   - Test Get() for existing/missing keys
   - Test GetAll() with various states
   - Test validation logic
   ```

2. **File Store Tests**

   ```go
   // internal/config/filestore_test.go
   - Test Load() with valid/invalid/missing files
   - Test Save() with permission scenarios
   - Test file permission verification
   - Test directory creation
   ```

3. **Path Resolution Tests**

   ```go
   // internal/config/paths_test.go
   - Test cross-platform path generation
   - Test XDG compliance
   - Test fallback mechanisms
   ```

4. **CLI Command Tests**

   ```go
   // internal/cli/config/*_test.go
   - Test command parsing
   - Test output formatting
   - Test error handling
   ```

### Acceptance Tests

```gherkin
Feature: Configuration Management
  As a user
  I want to configure my Redmine connection settings
  So that I can connect to my Redmine server

  Scenario: Set Redmine URL
    When I run "redmine config set url https://redmine.example.com"
    Then the output should contain "Configuration saved successfully"
    And the configuration file should contain the URL

  Scenario: Set API Key
    When I run "redmine config set api-key abc123"
    Then the output should contain "Configuration saved successfully"
    And the configuration file should contain the API key

  Scenario: Set Project ID
    When I run "redmine config set project-id my-project"
    Then the output should contain "Configuration saved successfully"
    And the configuration file should contain the project ID

  Scenario: Show Configuration
    Given I have configured URL "https://redmine.example.com"
    And I have configured API key "abc123"
    And I have configured project ID "my-project"
    When I run "redmine config show"
    Then the output should contain "URL: https://redmine.example.com"
    And the output should contain "API Key: ****23"
    And the output should contain "Project ID: my-project"

  Scenario: Show Empty Configuration
    Given no configuration exists
    When I run "redmine config show"
    Then the output should contain "No configuration found"

  Scenario: Invalid URL Format
    When I run "redmine config set url not-a-url"
    Then the error output should contain "Invalid URL format"
    And the exit code should be 1

  Scenario: Empty Value
    When I run "redmine config set url"
    Then the error output should contain "value cannot be empty"
    And the exit code should be 1

  Scenario: File Permission Security
    Given I have a configuration file with world-readable permissions
    When I run "redmine config show"
    Then the output should contain a security warning
```

### Integration Tests

Test integration with existing `list` command:

1. Configure valid settings
2. Run `redmine issue list`
3. Verify it uses configured values

## Implementation Plan

### Phase 1: Core Implementation

1. Implement path resolution logic
2. Create file store with security measures
3. Implement configuration manager
4. Add CLI commands (set, show)
5. Update existing LoadConfig() to use new system

### Phase 2: Security Hardening

1. Implement file permission checks
2. Add permission correction prompts
3. Validate HTTPS URLs
4. Add API key masking in output

### Phase 3: Enhanced Features

1. Add configuration validation command
2. Support environment variable overrides
3. Add configuration reset command
4. Support multiple profiles (future)

## Security Considerations

### API Key Protection

1. **Storage**: Store in user-specific directory with 0600 permissions
2. **Display**: Mask API keys in `show` command (show last 2 chars only)
3. **Validation**: Never log full API keys
4. **Transport**: Enforce HTTPS for API communications

### File System Security

1. **Permissions**: Strict file permissions (0600) on config files
2. **Directory**: User-only access (0700) on config directory
3. **Validation**: Check and warn about insecure permissions
4. **Atomic Writes**: Use temporary files to prevent corruption

### Input Validation

1. **URL Validation**: Require valid HTTPS URLs
2. **Path Traversal**: Prevent directory traversal attacks
3. **Injection**: Sanitize all user input
4. **Size Limits**: Enforce reasonable value size limits

## Dependencies

### New Dependencies

- `github.com/adrg/xdg` (v0.4.0): Cross-platform directory standards
- Standard library only for other functionality

### Existing Dependencies

- `github.com/spf13/cobra`: CLI framework (already in use)
- Standard library packages:
  - `encoding/json`: Configuration serialization
  - `os`: File operations
  - `path/filepath`: Path manipulation
  - `net/url`: URL validation

## Future Considerations

1. **Multiple Profiles**: Support for multiple Redmine instances
2. **Encrypted Storage**: Optional encryption for sensitive data
3. **Configuration Migration**: Tools for upgrading config format
4. **Global vs Project Config**: Hierarchy of configuration files
5. **Interactive Setup**: Guided configuration wizard
6. **Keyring Integration**: OS keyring support for API keys

## Summary

This design provides a secure, cross-platform configuration management system
that:

- Follows OS-specific conventions for configuration storage
- Implements security best practices for API key storage
- Provides intuitive CLI commands for configuration management
- Maintains backward compatibility with existing code
- Enables future extensibility without breaking changes

The implementation focuses on security, usability, and cross-platform
compatibility while keeping the solution simple and maintainable.

### Design Decision: Why Not Viper?

While Viper is a popular configuration library, we chose a simpler approach
because:

1. **Minimal Requirements**: With only 3 configuration values, Viper's extensive
   features are unnecessary
2. **Security Control**: Direct file operations give us precise control over
   permissions (0600)
3. **Reduced Dependencies**: Fewer dependencies mean smaller binaries and easier
   maintenance
4. **Simplicity**: The standard library provides all we need for JSON config
   files
5. **Future Flexibility**: We can always migrate to Viper later if configuration
   needs grow complex
