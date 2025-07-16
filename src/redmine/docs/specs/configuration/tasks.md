# Implementation Tasks: Configuration Feature

This document contains the implementation tasks for the configuration management
feature, broken down into incremental coding steps that build upon each other.

## 1. Foundation: Path Resolution and Configuration Structure

- [ ] 1.1 Create path resolution module for cross-platform configuration storage

  - Create `internal/config/paths.go` with function to determine OS-specific
    config path
  - Implement logic following XDG Base Directory specification for Linux/Unix
  - Implement OS-specific paths for macOS (`~/Library/Application Support`) and
    Windows (`%APPDATA%`)
  - Add fallback to `~/.config/redmine` if XDG not available
  - Create corresponding test file `internal/config/paths_test.go` with tests
    for each OS
  - References: Requirement 3 (Configuration Storage - user-specific location)

- [ ] 1.2 Update existing Config struct with JSON tags

  - Modify `internal/config/config.go` to add JSON tags to Config struct fields
  - Add `json:"url,omitempty"` tag to BaseURL field
  - Add `json:"api_key,omitempty"` tag to APIKey field
  - Add `json:"project_id,omitempty"` tag to ProjectID field
  - Write unit test to verify JSON marshaling/unmarshaling works correctly
  - References: Design data model specification

## 2. Storage Layer: File-Based Configuration Persistence

- [ ] 2.1 Create ConfigStore interface and file store implementation

  - Create `internal/config/filestore.go` with ConfigStore interface
  - Implement fileStore struct with Load(), Save(), Exists(), and GetPath()
    methods
  - Implement atomic file writes using temporary files to prevent corruption
  - Add file permission setting (0600) for security when creating config files
  - Create directory with 0700 permissions if it doesn't exist
  - Create `internal/config/filestore_test.go` with comprehensive tests
  - References: Requirement 3 (Configuration Storage - file permissions)

- [ ] 2.2 Implement file permission verification and security checks

  - Add permission checking logic to fileStore.Load() method
  - Return security warning if file permissions are not 0600
  - Add method to correct insecure file permissions
  - Write tests for permission verification scenarios
  - References: Requirement 3 (Configuration Storage - restricted access)

## 3. Business Logic: Configuration Manager

- [ ] 3.1 Create ConfigManager interface and implementation

  - Create `internal/config/manager.go` with ConfigManager interface
  - Implement configManager struct with Set(), Get(), GetAll(), and Save()
    methods
  - Add validation for supported keys (url, api-key, project-id)
  - Implement URL validation requiring HTTPS for security
  - Create `internal/config/manager_test.go` with unit tests
  - References: Requirement 1 (Set Configuration Values)

- [ ] 3.2 Add configuration validation and error handling

  - Implement custom error types for different failure scenarios
  - Add validation for empty values and invalid formats
  - Create user-friendly error messages with actionable guidance
  - Write tests for all validation scenarios
  - References: Requirement 1.4 (confirmation messages), Design error handling

## 4. CLI Commands: User Interface

- [ ] 4.1 Create config command group structure

  - Create `internal/cli/config/` directory structure
  - Create `internal/cli/config/config.go` with root config command using Cobra
  - Register config command with main CLI in appropriate location
  - Write test to verify command is properly registered
  - References: Requirement 1 (CLI commands structure)

- [ ] 4.2 Implement config set command

  - Create `internal/cli/config/set.go` with set subcommand implementation
  - Add command parsing for "config set <key> <value>" format
  - Integrate with ConfigManager to save values
  - Display success confirmation message after saving
  - Handle errors with appropriate user messages
  - Create `internal/cli/config/set_test.go` with command tests
  - References: Requirement 1.1-1.5 (Set Configuration Values)

- [ ] 4.3 Implement config show command

  - Create `internal/cli/config/show.go` with show subcommand implementation
  - Integrate with ConfigManager to retrieve all values
  - Format output to display URL, masked API key (show only last 2 chars), and
    project ID
  - Handle case when no configuration exists with appropriate message
  - Create `internal/cli/config/show_test.go` with command tests
  - References: Requirement 2.1-2.2 (View Configuration Values)

## 5. Integration: Wire Everything Together

- [ ] 5.1 Update LoadConfig() to use new configuration system

  - Modify existing `LoadConfig()` function to check for configuration file
    first
  - Load configuration from file if it exists using ConfigManager
  - Fall back to hardcoded values if configuration file doesn't exist
  - Return appropriate errors for missing required configuration
  - Update all tests that rely on LoadConfig()
  - References: Design migration strategy

- [ ] 5.2 Add XDG library dependency and update module

  - Run `go get github.com/adrg/xdg@v0.4.0` to add the dependency
  - Update go.mod and go.sum files
  - Modify paths.go to use XDG library for standard directory resolution
  - Test that the dependency is properly integrated
  - References: Design dependencies section

## 6. Comprehensive Testing

- [ ] 6.1 Create integration tests for full configuration workflow

  - Write end-to-end test that sets all configuration values
  - Verify values persist across multiple invocations
  - Test configuration file creation in correct location
  - Test permission settings on created files
  - Test overwriting existing values
  - References: All requirements

- [ ] 6.2 Add acceptance tests for command-line interface

  - Create acceptance test file for configuration commands
  - Test successful configuration setting for all three values
  - Test error cases (invalid URL, empty values)
  - Test show command with and without configuration
  - Test security warnings for incorrect file permissions
  - References: Design acceptance tests section

- [ ] 6.3 Create cross-platform tests

  - Write tests that verify correct behavior on Linux, macOS, and Windows
  - Test path resolution for each platform
  - Mock OS-specific environment variables and paths
  - Ensure file operations work correctly across platforms
  - References: Requirement 3 (OS-specific locations)
