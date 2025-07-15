package config

// Config holds the configuration for the Redmine CLI
type Config struct {
	BaseURL   string
	APIKey    string
	ProjectID string
}

// LoadConfig returns hardcoded configuration values for MVP
func LoadConfig() (*Config, error) {
	return &Config{
		BaseURL:   "https://redmine.example.com",
		APIKey:    "your-api-key-here",
		ProjectID: "sample-project",
	}, nil
}
