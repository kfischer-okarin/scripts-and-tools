package config

import (
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestLoadConfig(t *testing.T) {
	// Test successful configuration loading
	cfg, err := LoadConfig()
	require.NoError(t, err, "LoadConfig should not return an error")
	require.NotNil(t, cfg, "Config should not be nil")

	// Verify all fields are populated with hardcoded values
	assert.Equal(t, "https://redmine.example.com", cfg.BaseURL, "BaseURL should match hardcoded value")
	assert.Equal(t, "your-api-key-here", cfg.APIKey, "APIKey should match hardcoded value")
	assert.Equal(t, "sample-project", cfg.ProjectID, "ProjectID should match hardcoded value")
}

func TestConfigFields(t *testing.T) {
	// Test that Config struct has all required fields
	cfg := &Config{
		BaseURL:   "test-url",
		APIKey:    "test-key",
		ProjectID: "test-project",
	}

	assert.Equal(t, "test-url", cfg.BaseURL)
	assert.Equal(t, "test-key", cfg.APIKey)
	assert.Equal(t, "test-project", cfg.ProjectID)
}
