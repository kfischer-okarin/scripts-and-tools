// Package config provides configuration management for the Redmine CLI application.
// It handles loading and accessing configuration values needed to interact with
// the Redmine API.
package config

// Config holds the configuration for the Redmine CLI application.
// All fields are required for proper operation.
type Config struct {
	// BaseURL is the base URL of the Redmine instance (e.g., "https://redmine.example.com")
	BaseURL string

	// APIKey is the personal API key for authenticating with the Redmine API.
	// This can be found in your Redmine account settings under "My account" > "API access key"
	APIKey string

	// ProjectID is the identifier of the default Redmine project to work with.
	// This can be either the project's numeric ID or its string identifier (slug)
	ProjectID string
}

// LoadConfig returns the configuration for the Redmine CLI application.
// In the current MVP implementation, it returns hardcoded values.
//
// Future implementations will support loading from:
//   - Configuration files (e.g., ~/.redmine/config.yaml)
//   - Environment variables (e.g., REDMINE_BASE_URL)
//   - Command-line flags
//
// Returns an error if the configuration cannot be loaded (reserved for future use).
func LoadConfig() (*Config, error) {
	return &Config{
		BaseURL:   "https://redmine.example.com",
		APIKey:    "your-api-key-here",
		ProjectID: "sample-project",
	}, nil
}
