package config

import (
	"errors"
	"testing"
)

// mockConfigStore is a mock implementation of ConfigStore for testing
type mockConfigStore struct {
	config     *Config
	loadError  error
	saveError  error
	exists     bool
	loadCalled int
	saveCalled int
}

func (m *mockConfigStore) Load() (*Config, error) {
	m.loadCalled++
	if m.loadError != nil {
		return nil, m.loadError
	}
	if m.config == nil {
		return nil, errors.New("file does not exist")
	}
	return m.config, nil
}

func (m *mockConfigStore) Save(config *Config) error {
	m.saveCalled++
	if m.saveError != nil {
		return m.saveError
	}
	m.config = config
	return nil
}

func (m *mockConfigStore) Exists() bool {
	return m.exists
}

func (m *mockConfigStore) GetPath() string {
	return "/mock/config/path"
}

func (m *mockConfigStore) CheckPermissions() error {
	return nil
}

func (m *mockConfigStore) FixPermissions() error {
	return nil
}

func TestConfigManager_Set(t *testing.T) {
	tests := []struct {
		name          string
		key           string
		value         string
		initialConfig *Config
		loadError     error
		saveError     error
		wantError     bool
		errorContains string
	}{
		{
			name:          "set valid URL",
			key:           "url",
			value:         "https://redmine.example.com",
			initialConfig: &Config{},
			wantError:     false,
		},
		{
			name:          "set valid API key",
			key:           "api-key",
			value:         "abcdef123456",
			initialConfig: &Config{},
			wantError:     false,
		},
		{
			name:          "set valid project ID",
			key:           "project-id",
			value:         "my-project",
			initialConfig: &Config{},
			wantError:     false,
		},
		{
			name:  "update existing URL",
			key:   "url",
			value: "https://new.redmine.com",
			initialConfig: &Config{
				BaseURL: "https://old.redmine.com",
				APIKey:  "existing-key",
			},
			wantError: false,
		},
		{
			name:          "invalid key",
			key:           "invalid-key",
			value:         "some-value",
			wantError:     true,
			errorContains: "Invalid configuration key",
		},
		{
			name:          "empty value",
			key:           "url",
			value:         "",
			wantError:     true,
			errorContains: "Configuration value cannot be empty",
		},
		{
			name:          "whitespace only value",
			key:           "api-key",
			value:         "   ",
			wantError:     true,
			errorContains: "Configuration value cannot be empty",
		},
		{
			name:          "non-HTTPS URL",
			key:           "url",
			value:         "http://insecure.redmine.com",
			wantError:     true,
			errorContains: "URL must use HTTPS",
		},
		{
			name:          "invalid URL format",
			key:           "url",
			value:         "not-a-url",
			wantError:     true,
			errorContains: "missing scheme or host",
		},
		{
			name:          "URL without host",
			key:           "url",
			value:         "https://",
			wantError:     true,
			errorContains: "missing scheme or host",
		},
		{
			name:          "API key too short",
			key:           "api-key",
			value:         "short",
			wantError:     true,
			errorContains: "Invalid API key",
		},
		{
			name:          "project ID with whitespace",
			key:           "project-id",
			value:         "my project",
			wantError:     true,
			errorContains: "Invalid project ID",
		},
		{
			name:          "save error",
			key:           "url",
			value:         "https://redmine.example.com",
			saveError:     errors.New("permission denied"),
			wantError:     true,
			errorContains: "Failed to save configuration",
		},
		{
			name:      "create new config when none exists",
			key:       "url",
			value:     "https://redmine.example.com",
			wantError: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := &mockConfigStore{
				config:    tt.initialConfig,
				loadError: tt.loadError,
				saveError: tt.saveError,
			}

			manager := NewConfigManager(store)
			err := manager.Set(tt.key, tt.value)

			if tt.wantError {
				if err == nil {
					t.Errorf("expected error but got none")
				} else if tt.errorContains != "" && !containsString(err.Error(), tt.errorContains) {
					t.Errorf("error = %v, want error containing %v", err, tt.errorContains)
				}
			} else {
				if err != nil {
					t.Errorf("unexpected error: %v", err)
				}

				// Verify the value was set correctly
				if store.config != nil {
					switch tt.key {
					case "url":
						if store.config.BaseURL != tt.value {
							t.Errorf("BaseURL = %v, want %v", store.config.BaseURL, tt.value)
						}
					case "api-key":
						if store.config.APIKey != tt.value {
							t.Errorf("APIKey = %v, want %v", store.config.APIKey, tt.value)
						}
					case "project-id":
						if store.config.ProjectID != tt.value {
							t.Errorf("ProjectID = %v, want %v", store.config.ProjectID, tt.value)
						}
					}
				}
			}
		})
	}
}

func TestConfigManager_Get(t *testing.T) {
	config := &Config{
		BaseURL:   "https://redmine.example.com",
		APIKey:    "test-api-key",
		ProjectID: "test-project",
	}

	tests := []struct {
		name          string
		key           string
		config        *Config
		loadError     error
		want          string
		wantError     bool
		errorContains string
	}{
		{
			name:   "get URL",
			key:    "url",
			config: config,
			want:   "https://redmine.example.com",
		},
		{
			name:   "get API key",
			key:    "api-key",
			config: config,
			want:   "test-api-key",
		},
		{
			name:   "get project ID",
			key:    "project-id",
			config: config,
			want:   "test-project",
		},
		{
			name:          "invalid key",
			key:           "invalid-key",
			config:        config,
			wantError:     true,
			errorContains: "Invalid configuration key",
		},
		{
			name:          "load error",
			key:           "url",
			loadError:     errors.New("permission denied"),
			wantError:     true,
			errorContains: "Failed to load configuration",
		},
		{
			name:   "get empty value",
			key:    "url",
			config: &Config{},
			want:   "",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := &mockConfigStore{
				config:    tt.config,
				loadError: tt.loadError,
			}

			manager := NewConfigManager(store)
			got, err := manager.Get(tt.key)

			if tt.wantError {
				if err == nil {
					t.Errorf("expected error but got none")
				} else if tt.errorContains != "" && !containsString(err.Error(), tt.errorContains) {
					t.Errorf("error = %v, want error containing %v", err, tt.errorContains)
				}
			} else {
				if err != nil {
					t.Errorf("unexpected error: %v", err)
				}
				if got != tt.want {
					t.Errorf("Get() = %v, want %v", got, tt.want)
				}
			}
		})
	}
}

func TestConfigManager_GetAll(t *testing.T) {
	tests := []struct {
		name          string
		config        *Config
		loadError     error
		wantError     bool
		errorContains string
	}{
		{
			name: "get all values",
			config: &Config{
				BaseURL:   "https://redmine.example.com",
				APIKey:    "test-api-key",
				ProjectID: "test-project",
			},
		},
		{
			name:   "empty config",
			config: &Config{},
		},
		{
			name:          "load error",
			loadError:     errors.New("permission denied"),
			wantError:     true,
			errorContains: "Failed to load configuration",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := &mockConfigStore{
				config:    tt.config,
				loadError: tt.loadError,
			}

			manager := NewConfigManager(store)
			got, err := manager.GetAll()

			if tt.wantError {
				if err == nil {
					t.Errorf("expected error but got none")
				} else if tt.errorContains != "" && !containsString(err.Error(), tt.errorContains) {
					t.Errorf("error = %v, want error containing %v", err, tt.errorContains)
				}
			} else {
				if err != nil {
					t.Errorf("unexpected error: %v", err)
				}
				if got != tt.config {
					t.Errorf("GetAll() returned different config pointer")
				}
			}
		})
	}
}

func TestConfigManager_Save(t *testing.T) {
	tests := []struct {
		name          string
		config        *Config
		saveError     error
		wantError     bool
		errorContains string
	}{
		{
			name: "save valid config",
			config: &Config{
				BaseURL:   "https://redmine.example.com",
				APIKey:    "valid-api-key",
				ProjectID: "valid-project",
			},
		},
		{
			name:   "save empty config",
			config: &Config{},
		},
		{
			name: "save config with invalid URL",
			config: &Config{
				BaseURL: "http://insecure.com",
			},
			wantError:     true,
			errorContains: "URL must use HTTPS",
		},
		{
			name: "save config with empty API key",
			config: &Config{
				APIKey: "",
			},
		},
		{
			name: "save config with short API key",
			config: &Config{
				APIKey: "short",
			},
			wantError:     true,
			errorContains: "Invalid API key",
		},
		{
			name: "save config with invalid project ID",
			config: &Config{
				ProjectID: "has spaces",
			},
			wantError:     true,
			errorContains: "Invalid project ID",
		},
		{
			name: "save error from store",
			config: &Config{
				BaseURL: "https://redmine.example.com",
			},
			saveError:     errors.New("disk full"),
			wantError:     true,
			errorContains: "disk full",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			store := &mockConfigStore{
				saveError: tt.saveError,
			}

			manager := NewConfigManager(store)
			err := manager.Save(tt.config)

			if tt.wantError {
				if err == nil {
					t.Errorf("expected error but got none")
				} else if tt.errorContains != "" && !containsString(err.Error(), tt.errorContains) {
					t.Errorf("error = %v, want error containing %v", err, tt.errorContains)
				}
			} else {
				if err != nil {
					t.Errorf("unexpected error: %v", err)
				}
				if store.saveCalled != 1 {
					t.Errorf("Save() called %d times, want 1", store.saveCalled)
				}
			}
		})
	}
}

func TestIsValidKey(t *testing.T) {
	tests := []struct {
		key   string
		valid bool
	}{
		{"url", true},
		{"api-key", true},
		{"project-id", true},
		{"invalid", false},
		{"", false},
		{"URL", false},     // case sensitive
		{"api_key", false}, // wrong format
	}

	for _, tt := range tests {
		t.Run(tt.key, func(t *testing.T) {
			if got := isValidKey(tt.key); got != tt.valid {
				t.Errorf("isValidKey(%q) = %v, want %v", tt.key, got, tt.valid)
			}
		})
	}
}

func TestValidateValue(t *testing.T) {
	tests := []struct {
		name          string
		key           string
		value         string
		wantError     bool
		errorContains string
	}{
		// URL validation tests
		{
			name:  "valid HTTPS URL",
			key:   "url",
			value: "https://redmine.example.com",
		},
		{
			name:  "valid HTTPS URL with path",
			key:   "url",
			value: "https://redmine.example.com/path",
		},
		{
			name:          "HTTP URL",
			key:           "url",
			value:         "http://redmine.example.com",
			wantError:     true,
			errorContains: "must use HTTPS",
		},
		{
			name:          "invalid URL",
			key:           "url",
			value:         "not a url",
			wantError:     true,
			errorContains: "missing scheme or host",
		},
		{
			name:          "URL without host",
			key:           "url",
			value:         "https://",
			wantError:     true,
			errorContains: "missing scheme or host",
		},
		// API key validation tests
		{
			name:  "valid API key",
			key:   "api-key",
			value: "abcdef123456789",
		},
		{
			name:          "short API key",
			key:           "api-key",
			value:         "short",
			wantError:     true,
			errorContains: "Invalid API key",
		},
		// Project ID validation tests
		{
			name:  "valid project ID",
			key:   "project-id",
			value: "my-project",
		},
		{
			name:  "project ID with numbers",
			key:   "project-id",
			value: "project-123",
		},
		{
			name:          "project ID with space",
			key:           "project-id",
			value:         "my project",
			wantError:     true,
			errorContains: "Invalid project ID",
		},
		{
			name:          "project ID with tab",
			key:           "project-id",
			value:         "my\tproject",
			wantError:     true,
			errorContains: "Invalid project ID",
		},
		// General validation tests
		{
			name:          "empty value",
			key:           "url",
			value:         "",
			wantError:     true,
			errorContains: "Configuration value cannot be empty",
		},
		{
			name:          "whitespace only",
			key:           "api-key",
			value:         "   ",
			wantError:     true,
			errorContains: "Configuration value cannot be empty",
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := validateValue(tt.key, tt.value)

			if tt.wantError {
				if err == nil {
					t.Errorf("expected error but got none")
				} else if tt.errorContains != "" && !containsString(err.Error(), tt.errorContains) {
					t.Errorf("error = %v, want error containing %v", err, tt.errorContains)
				}
			} else {
				if err != nil {
					t.Errorf("unexpected error: %v", err)
				}
			}
		})
	}
}

// Helper function to check if a string contains a substring
func containsString(s, substr string) bool {
	return len(s) >= len(substr) && (s == substr || len(s) > 0 && (s[0:len(substr)] == substr || containsString(s[1:], substr)))
}
