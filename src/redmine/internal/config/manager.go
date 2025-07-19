package config

import (
	"fmt"
	"net/url"
	"strings"
)

// ErrorType represents different types of configuration errors
type ErrorType string

const (
	InvalidKeyError     ErrorType = "invalid_key"
	EmptyValueError     ErrorType = "empty_value"
	InvalidURLError     ErrorType = "invalid_url"
	InvalidAPIKeyError  ErrorType = "invalid_api_key"
	InvalidProjectError ErrorType = "invalid_project"
	PermissionError     ErrorType = "permission_error"
	FileCorruptedError  ErrorType = "file_corrupted"
	InsecureFileError   ErrorType = "insecure_file"
	LoadError           ErrorType = "load_error"
	SaveError           ErrorType = "save_error"
)

// ConfigError represents a configuration-related error with actionable guidance
type ConfigError struct {
	Type    ErrorType
	Message string
	Cause   error
}

func (e *ConfigError) Error() string {
	if e.Cause != nil {
		return fmt.Sprintf("%s: %v", e.Message, e.Cause)
	}
	return e.Message
}

func (e *ConfigError) Unwrap() error {
	return e.Cause
}

// User-friendly error messages with actionable guidance
var errorMessages = map[ErrorType]string{
	InvalidKeyError:     "Invalid configuration key. Supported keys are: url, api-key, project-id",
	EmptyValueError:     "Configuration value cannot be empty. Please provide a valid value",
	InvalidURLError:     "Invalid URL format. Please provide a valid HTTPS URL (e.g., https://redmine.example.com)",
	InvalidAPIKeyError:  "Invalid API key. Please ensure your API key is at least 8 characters long",
	InvalidProjectError: "Invalid project ID. Project IDs cannot contain spaces or special characters",
	PermissionError:     "Unable to save configuration due to insufficient permissions. Please check file permissions",
	FileCorruptedError:  "Configuration file is corrupted. Please delete the file and reconfigure",
	InsecureFileError:   "Configuration file has insecure permissions. Please run 'chmod 600' on the config file",
	LoadError:           "Failed to load configuration. Please check if the file exists and is readable",
	SaveError:           "Failed to save configuration. Please check if you have write permissions",
}

// newConfigError creates a new ConfigError with user-friendly message
func newConfigError(errorType ErrorType, cause error) *ConfigError {
	message, exists := errorMessages[errorType]
	if !exists {
		message = "Unknown configuration error occurred"
	}

	return &ConfigError{
		Type:    errorType,
		Message: message,
		Cause:   cause,
	}
}

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
		return newConfigError(InvalidKeyError, nil)
	}

	// Validate the value
	if err := validateValue(key, value); err != nil {
		return err
	}

	// Load existing config or create new one
	config, err := m.store.Load()
	if err != nil && !isNotExistError(err) {
		return newConfigError(LoadError, err)
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
		return newConfigError(SaveError, err)
	}

	return nil
}

// Get retrieves a configuration value by key
func (m *configManager) Get(key string) (string, error) {
	if !isValidKey(key) {
		return "", newConfigError(InvalidKeyError, nil)
	}

	config, err := m.store.Load()
	if err != nil {
		return "", newConfigError(LoadError, err)
	}

	switch key {
	case "url":
		return config.BaseURL, nil
	case "api-key":
		return config.APIKey, nil
	case "project-id":
		return config.ProjectID, nil
	default:
		return "", newConfigError(InvalidKeyError, nil)
	}
}

// GetAll retrieves all configuration values
func (m *configManager) GetAll() (*Config, error) {
	config, err := m.store.Load()
	if err != nil {
		return nil, newConfigError(LoadError, err)
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
		return newConfigError(EmptyValueError, nil)
	}

	// Key-specific validation
	switch key {
	case "url":
		// Validate URL format and require HTTPS
		u, err := url.Parse(value)
		if err != nil {
			return newConfigError(InvalidURLError, err)
		}
		if u.Scheme == "" || u.Host == "" {
			return newConfigError(InvalidURLError, fmt.Errorf("missing scheme or host"))
		}
		if u.Scheme != "https" {
			return newConfigError(InvalidURLError, fmt.Errorf("URL must use HTTPS for security"))
		}
	case "api-key":
		// Basic validation for API key (non-empty already checked)
		if len(value) < 8 {
			return newConfigError(InvalidAPIKeyError, fmt.Errorf("API key is too short (minimum 8 characters)"))
		}
	case "project-id":
		// Project ID validation (basic check for now)
		if strings.ContainsAny(value, " \t\n\r") {
			return newConfigError(InvalidProjectError, fmt.Errorf("project ID contains whitespace characters"))
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
