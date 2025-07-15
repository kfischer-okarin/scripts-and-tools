# Design Document: List Issues Feature

## Overview

This design document outlines the technical implementation for the
`list_issues` feature of the Redmine CLI tool. The feature allows users to
retrieve and display issues from a Redmine project via the command line
interface.

### Technology Stack Selection

For this MVP, we'll use **Go** as the primary programming language because:

- Excellent CLI tooling support with libraries like Cobra
- Native binary compilation for easy distribution
- Strong HTTP client libraries for API interaction
- Built-in concurrency for future enhancements
- Minimal runtime dependencies

### Design Goals

1. **Simplicity**: Keep the MVP focused on core functionality
2. **Reliability**: Provide robust error handling for common failure scenarios
3. **Usability**: Present issue information in a clear, readable format
4. **Maintainability**: Structure code for future feature additions

## Architecture

### High-Level Architecture

```text
┌─────────────────┐
│   CLI Layer     │
│  (Cobra CLI)    │
└────────┬────────┘
         │
┌────────▼────────┐
│ Command Handler │
│   (list.go)     │
└────────┬────────┘
         │
┌────────▼────────┐
│   API Client    │
│ (redmine.go)    │
└────────┬────────┘
         │
┌────────▼────────┐
│  HTTP Transport │
│  (net/http)     │
└────────┬────────┘
         │
┌────────▼────────┐
│ Redmine Server  │
│   (External)    │
└─────────────────┘
```

### Project Structure

```text
redmine/
├── cmd/
│   └── redmine/
│       └── main.go          # Entry point
├── internal/
│   ├── cli/
│   │   ├── root.go          # Root command setup
│   │   └── issue/
│   │       └── list.go      # List command implementation
│   ├── api/
│   │   ├── client.go        # Redmine API client
│   │   └── models.go        # API data models
│   ├── config/
│   │   └── config.go        # Configuration management
│   └── formatter/
│       └── issue.go         # Issue formatting logic
├── go.mod
├── go.sum
└── docs/
    └── specs/
        └── list_issues/
            ├── requirements.md
            └── design.md
```

## Components and Interfaces

### 1. CLI Layer (Cobra)

**Purpose**: Handle command-line parsing and user interaction

**Key Components**:

- `cmd/redmine/main.go`: Application entry point
- `internal/cli/root.go`: Root command configuration
- `internal/cli/issue/list.go`: List command implementation

**Interface**:

```go
// Command interface
type ListCommand struct {
    client api.Client
}

func (c *ListCommand) Execute() error
```

### 2. API Client

**Purpose**: Encapsulate all Redmine API interactions

**Key Components**:

- `internal/api/client.go`: HTTP client wrapper
- `internal/api/models.go`: Data transfer objects

**Interface**:

```go
type Client interface {
    ListIssues(projectID string) ([]Issue, error)
}

type RedmineClient struct {
    baseURL    string
    apiKey     string
    httpClient *http.Client
}
```

### 3. Configuration

**Purpose**: Manage hardcoded configuration for MVP

**Key Components**:

- `internal/config/config.go`: Configuration structure

**Interface**:

```go
type Config struct {
    BaseURL   string
    APIKey    string
    ProjectID string
}

func LoadConfig() (*Config, error)
```

### 4. Formatter

**Purpose**: Format issue data for terminal display

**Key Components**:

- `internal/formatter/issue.go`: Issue formatting logic

**Interface**:

```go
type IssueFormatter interface {
    Format(issues []api.Issue) string
}
```

## Data Models

### Issue Model

Based on the Redmine API response:

```go
package api

type Issue struct {
    ID      int      `json:"id"`
    Subject string   `json:"subject"`
    Status  Status   `json:"status"`
    Project Project  `json:"project"`
}

type Status struct {
    ID   int    `json:"id"`
    Name string `json:"name"`
}

type Project struct {
    ID   int    `json:"id"`
    Name string `json:"name"`
}

type IssuesResponse struct {
    Issues []Issue `json:"issues"`
    Count  int     `json:"count"`
}
```

### Display Format

Issues will be displayed in a table format:

```text
ID     | Subject                           | Status
-------|-----------------------------------|--------
12345  | Fix login validation bug          | New
12346  | Add user profile feature          | In Progress
12347  | Update API documentation          | Closed
```

## Error Handling

### Error Types

1. **Network Errors**
   - Connection refused
   - Timeout
   - DNS resolution failure

2. **API Errors**
   - Authentication failure (401)
   - Project not found (404)
   - Server errors (5xx)

3. **Configuration Errors**
   - Missing API key
   - Invalid base URL

### Error Handling Strategy

```go
// Custom error types
type RedmineError struct {
    Type    ErrorType
    Message string
    Cause   error
}

type ErrorType int

const (
    NetworkError ErrorType = iota
    AuthenticationError
    NotFoundError
    ServerError
    ConfigurationError
)

// Error messages mapping
var errorMessages = map[ErrorType]string{
    NetworkError:        "Error: Unable to connect to Redmine server",
    AuthenticationError: "Error: Authentication failed. Please check your API key",
    NotFoundError:       "Error: Project not found",
    ServerError:         "Error: Redmine server error",
    ConfigurationError:  "Error: Invalid configuration",
}
```

### Error Display

Errors will be displayed to stderr with clear, actionable messages:

- Network errors: "Error: Unable to connect to Redmine server"
- Empty results: "No issues found"
- Invalid arguments: Display usage information

## Testing Strategy

### Unit Tests

1. **API Client Tests**
   - Mock HTTP responses
   - Test error scenarios
   - Verify request formatting

2. **Formatter Tests**
   - Test various issue counts
   - Test empty results
   - Test formatting edge cases

3. **Command Tests**
   - Test command execution flow
   - Verify error handling
   - Test output formatting

### Integration Tests

1. **Mock Server Tests**
   - Use httptest to create mock Redmine server
   - Test full command execution
   - Verify end-to-end behavior

### Test Structure

```text
redmine/
├── internal/
│   ├── api/
│   │   ├── client_test.go
│   │   └── testdata/
│   │       └── issues_response.json
│   ├── cli/
│   │   └── issue/
│   │       └── list_test.go
│   └── formatter/
│       └── issue_test.go
└── test/
    └── integration/
        └── list_issues_test.go
```

### Testing Approach

1. Use Go's built-in testing package
2. Use testify for assertions
3. Use httptest for mocking HTTP responses
4. Maintain test coverage above 80%

## Implementation Notes

### Phase 1: MVP Implementation

1. Hardcode configuration values
2. Implement basic issue listing
3. Simple table formatting
4. Basic error handling

### Future Considerations

1. Configuration file support
2. Multiple output formats (JSON, CSV)
3. Filtering and sorting options
4. Pagination support
5. Interactive mode

### Security Considerations

1. API key should not be logged or displayed
2. Use HTTPS for all API communications
3. Validate all input data
4. Sanitize output to prevent injection attacks

## Dependencies

### External Dependencies

- `github.com/spf13/cobra`: CLI framework
- `github.com/stretchr/testify`: Testing assertions

### Standard Library

- `net/http`: HTTP client
- `encoding/json`: JSON parsing
- `fmt`: Formatting output
- `os`: System operations

## Summary

This design provides a clean, modular architecture for the list_issues feature
that:

- Separates concerns between CLI, API, and formatting layers
- Provides comprehensive error handling
- Supports easy testing through interfaces
- Allows for future expansion while keeping the MVP simple
- Follows Go best practices and idioms

The implementation will focus on delivering a reliable, user-friendly
experience for listing Redmine issues from the command line.
