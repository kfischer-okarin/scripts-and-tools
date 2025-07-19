package config

import (
	"encoding/json"
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

func TestConfigJSONMarshalUnmarshal(t *testing.T) {
	t.Run("marshal config to JSON", func(t *testing.T) {
		cfg := &Config{
			BaseURL:   "https://redmine.example.com",
			APIKey:    "test-api-key-123",
			ProjectID: "my-project",
		}

		data, err := json.Marshal(cfg)
		require.NoError(t, err, "should marshal config to JSON")

		expectedJSON := `{"url":"https://redmine.example.com","api_key":"test-api-key-123","project_id":"my-project"}`
		assert.JSONEq(t, expectedJSON, string(data), "JSON output should match expected format")
	})

	t.Run("unmarshal JSON to config", func(t *testing.T) {
		jsonData := `{"url":"https://redmine.test.com","api_key":"api-key-456","project_id":"test-project"}`

		var cfg Config
		err := json.Unmarshal([]byte(jsonData), &cfg)
		require.NoError(t, err, "should unmarshal JSON to config")

		assert.Equal(t, "https://redmine.test.com", cfg.BaseURL)
		assert.Equal(t, "api-key-456", cfg.APIKey)
		assert.Equal(t, "test-project", cfg.ProjectID)
	})

	t.Run("omitempty behavior", func(t *testing.T) {
		// Test that empty fields are omitted from JSON
		cfg := &Config{
			BaseURL: "https://redmine.example.com",
			// APIKey and ProjectID are empty
		}

		data, err := json.Marshal(cfg)
		require.NoError(t, err, "should marshal config with empty fields")

		expectedJSON := `{"url":"https://redmine.example.com"}`
		assert.JSONEq(t, expectedJSON, string(data), "empty fields should be omitted from JSON")
	})

	t.Run("round-trip marshal/unmarshal", func(t *testing.T) {
		original := &Config{
			BaseURL:   "https://redmine.round-trip.com",
			APIKey:    "round-trip-key",
			ProjectID: "round-trip-project",
		}

		// Marshal to JSON
		data, err := json.Marshal(original)
		require.NoError(t, err)

		// Unmarshal back to struct
		var result Config
		err = json.Unmarshal(data, &result)
		require.NoError(t, err)

		// Verify fields match
		assert.Equal(t, original.BaseURL, result.BaseURL)
		assert.Equal(t, original.APIKey, result.APIKey)
		assert.Equal(t, original.ProjectID, result.ProjectID)
	})
}
