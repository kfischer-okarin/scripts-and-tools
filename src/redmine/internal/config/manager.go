package config

import (
	"fmt"
	"net/url"
	"strings"
)

// ConfigManager handles configuration operations
type ConfigManager interface {
	Set(key string, value string) error
	Get(key string) (string, error)
	GetAll() (*Config, error)
	Save(config *Config) error
}

// configManager implements the ConfigManager interface
type configManager struct {
	store ConfigStore
}

// NewConfigManager creates a new configuration manager
func NewConfigManager(store ConfigStore) ConfigManager {
	return &configManager{
		store: store,
	}
}

// Set sets a configuration value by key
func (m *configManager) Set(key string, value string) error {
	// Validate the key
	if !isValidKey(key) {
		return fmt.Errorf("invalid configuration key: %s", key)
	}

	// Validate the value
	if err := validateValue(key, value); err != nil {
		return err
	}

	// Load existing config or create new one
	config, err := m.store.Load()
	if err != nil && !isNotExistError(err) {
		return fmt.Errorf("failed to load configuration: %w", err)
	}
	if config == nil {
		config = &Config{}
	}

	// Set the value based on the key
	switch key {
	case "url":
		config.BaseURL = value
	case "api-key":
		config.APIKey = value
	case "project-id":
		config.ProjectID = value
	}

	// Save the updated configuration
	if err := m.store.Save(config); err != nil {
		return fmt.Errorf("failed to save configuration: %w", err)
	}

	return nil
}

// Get retrieves a configuration value by key
func (m *configManager) Get(key string) (string, error) {
	if !isValidKey(key) {
		return "", fmt.Errorf("invalid configuration key: %s", key)
	}

	config, err := m.store.Load()
	if err != nil {
		return "", fmt.Errorf("failed to load configuration: %w", err)
	}

	switch key {
	case "url":
		return config.BaseURL, nil
	case "api-key":
		return config.APIKey, nil
	case "project-id":
		return config.ProjectID, nil
	default:
		return "", fmt.Errorf("unknown configuration key: %s", key)
	}
}

// GetAll retrieves all configuration values
func (m *configManager) GetAll() (*Config, error) {
	config, err := m.store.Load()
	if err != nil {
		return nil, fmt.Errorf("failed to load configuration: %w", err)
	}
	return config, nil
}

// Save saves the entire configuration
func (m *configManager) Save(config *Config) error {
	// Validate all values in the config
	if config.BaseURL != "" {
		if err := validateValue("url", config.BaseURL); err != nil {
			return err
		}
	}

	if config.APIKey != "" {
		if err := validateValue("api-key", config.APIKey); err != nil {
			return err
		}
	}

	if config.ProjectID != "" {
		if err := validateValue("project-id", config.ProjectID); err != nil {
			return err
		}
	}

	return m.store.Save(config)
}

// isValidKey checks if the provided key is supported
func isValidKey(key string) bool {
	validKeys := []string{"url", "api-key", "project-id"}
	for _, validKey := range validKeys {
		if key == validKey {
			return true
		}
	}
	return false
}

// validateValue validates the value based on the key
func validateValue(key string, value string) error {
	// Check for empty values
	if strings.TrimSpace(value) == "" {
		return fmt.Errorf("configuration value cannot be empty")
	}

	// Key-specific validation
	switch key {
	case "url":
		// Validate URL format and require HTTPS
		u, err := url.Parse(value)
		if err != nil {
			return fmt.Errorf("invalid URL format: %w", err)
		}
		if u.Scheme == "" || u.Host == "" {
			return fmt.Errorf("invalid URL format: missing scheme or host")
		}
		if u.Scheme != "https" {
			return fmt.Errorf("URL must use HTTPS for security")
		}
	case "api-key":
		// Basic validation for API key (non-empty already checked)
		if len(value) < 8 {
			return fmt.Errorf("API key seems too short")
		}
	case "project-id":
		// Project ID validation (basic check for now)
		if strings.ContainsAny(value, " \t\n\r") {
			return fmt.Errorf("project ID cannot contain whitespace")
		}
	}

	return nil
}

// isNotExistError checks if an error indicates that a file doesn't exist
func isNotExistError(err error) bool {
	// This is a simple check; in a real implementation, you might want to
	// check for specific error types
	return strings.Contains(err.Error(), "no such file") ||
		strings.Contains(err.Error(), "not found") ||
		strings.Contains(err.Error(), "does not exist")
}
