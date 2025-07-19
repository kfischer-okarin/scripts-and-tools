package config

import (
	"encoding/json"
	"os"
	"path/filepath"
	"testing"
)

func TestFileStore_Save(t *testing.T) {
	tests := []struct {
		name    string
		config  *Config
		wantErr bool
	}{
		{
			name: "save valid config",
			config: &Config{
				BaseURL:   "https://redmine.example.com",
				APIKey:    "test-api-key",
				ProjectID: "test-project",
			},
			wantErr: false,
		},
		{
			name:    "save empty config",
			config:  &Config{},
			wantErr: false,
		},
		{
			name: "save config with partial fields",
			config: &Config{
				BaseURL: "https://redmine.example.com",
			},
			wantErr: false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tmpDir := t.TempDir()
			configPath := filepath.Join(tmpDir, "redmine", "config.json")
			fs := NewFileStore(configPath)

			err := fs.Save(tt.config)
			if (err != nil) != tt.wantErr {
				t.Errorf("Save() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			if !tt.wantErr {
				info, err := os.Stat(configPath)
				if err != nil {
					t.Fatalf("Failed to stat config file: %v", err)
				}

				if info.Mode().Perm() != 0600 {
					t.Errorf("File permissions = %v, want %v", info.Mode().Perm(), 0600)
				}

				dirInfo, err := os.Stat(filepath.Dir(configPath))
				if err != nil {
					t.Fatalf("Failed to stat config directory: %v", err)
				}

				if dirInfo.Mode().Perm() != 0700 {
					t.Errorf("Directory permissions = %v, want %v", dirInfo.Mode().Perm(), 0700)
				}

				data, err := os.ReadFile(configPath)
				if err != nil {
					t.Fatalf("Failed to read config file: %v", err)
				}

				var savedConfig Config
				if err := json.Unmarshal(data, &savedConfig); err != nil {
					t.Fatalf("Failed to unmarshal saved config: %v", err)
				}

				if savedConfig.BaseURL != tt.config.BaseURL {
					t.Errorf("Saved BaseURL = %v, want %v", savedConfig.BaseURL, tt.config.BaseURL)
				}
				if savedConfig.APIKey != tt.config.APIKey {
					t.Errorf("Saved APIKey = %v, want %v", savedConfig.APIKey, tt.config.APIKey)
				}
				if savedConfig.ProjectID != tt.config.ProjectID {
					t.Errorf("Saved ProjectID = %v, want %v", savedConfig.ProjectID, tt.config.ProjectID)
				}
			}
		})
	}
}

func TestFileStore_Load(t *testing.T) {
	tests := []struct {
		name       string
		setupFunc  func(string) error
		wantConfig *Config
		wantErr    bool
	}{
		{
			name: "load valid config",
			setupFunc: func(path string) error {
				config := &Config{
					BaseURL:   "https://redmine.example.com",
					APIKey:    "test-api-key",
					ProjectID: "test-project",
				}
				data, _ := json.MarshalIndent(config, "", "  ")
				return os.WriteFile(path, data, 0600)
			},
			wantConfig: &Config{
				BaseURL:   "https://redmine.example.com",
				APIKey:    "test-api-key",
				ProjectID: "test-project",
			},
			wantErr: false,
		},
		{
			name:       "load non-existent file",
			setupFunc:  func(path string) error { return nil },
			wantConfig: nil,
			wantErr:    true,
		},
		{
			name: "load malformed json",
			setupFunc: func(path string) error {
				return os.WriteFile(path, []byte("invalid json"), 0600)
			},
			wantConfig: nil,
			wantErr:    true,
		},
		{
			name: "load empty file",
			setupFunc: func(path string) error {
				return os.WriteFile(path, []byte("{}"), 0600)
			},
			wantConfig: &Config{},
			wantErr:    false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tmpDir := t.TempDir()
			configPath := filepath.Join(tmpDir, "config.json")

			os.MkdirAll(filepath.Dir(configPath), 0700)

			if tt.setupFunc != nil {
				if err := tt.setupFunc(configPath); err != nil {
					t.Fatalf("Setup failed: %v", err)
				}
			}

			fs := NewFileStore(configPath)
			gotConfig, err := fs.Load()

			if (err != nil) != tt.wantErr {
				t.Errorf("Load() error = %v, wantErr %v", err, tt.wantErr)
				return
			}

			if !tt.wantErr && tt.wantConfig != nil {
				if gotConfig.BaseURL != tt.wantConfig.BaseURL {
					t.Errorf("Load() BaseURL = %v, want %v", gotConfig.BaseURL, tt.wantConfig.BaseURL)
				}
				if gotConfig.APIKey != tt.wantConfig.APIKey {
					t.Errorf("Load() APIKey = %v, want %v", gotConfig.APIKey, tt.wantConfig.APIKey)
				}
				if gotConfig.ProjectID != tt.wantConfig.ProjectID {
					t.Errorf("Load() ProjectID = %v, want %v", gotConfig.ProjectID, tt.wantConfig.ProjectID)
				}
			}
		})
	}
}

func TestFileStore_Exists(t *testing.T) {
	tests := []struct {
		name      string
		setupFunc func(string) error
		want      bool
	}{
		{
			name: "file exists",
			setupFunc: func(path string) error {
				return os.WriteFile(path, []byte("{}"), 0600)
			},
			want: true,
		},
		{
			name:      "file does not exist",
			setupFunc: func(path string) error { return nil },
			want:      false,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			tmpDir := t.TempDir()
			configPath := filepath.Join(tmpDir, "config.json")

			os.MkdirAll(filepath.Dir(configPath), 0700)

			if tt.setupFunc != nil {
				if err := tt.setupFunc(configPath); err != nil {
					t.Fatalf("Setup failed: %v", err)
				}
			}

			fs := NewFileStore(configPath)
			if got := fs.Exists(); got != tt.want {
				t.Errorf("Exists() = %v, want %v", got, tt.want)
			}
		})
	}
}

func TestFileStore_GetPath(t *testing.T) {
	expectedPath := "/tmp/test/config.json"
	fs := NewFileStore(expectedPath)

	if got := fs.GetPath(); got != expectedPath {
		t.Errorf("GetPath() = %v, want %v", got, expectedPath)
	}
}

func TestFileStore_AtomicWrite(t *testing.T) {
	tmpDir := t.TempDir()
	configPath := filepath.Join(tmpDir, "config.json")
	fs := NewFileStore(configPath)

	originalConfig := &Config{
		BaseURL:   "https://original.example.com",
		APIKey:    "original-key",
		ProjectID: "original-project",
	}

	if err := fs.Save(originalConfig); err != nil {
		t.Fatalf("Failed to save original config: %v", err)
	}

	tempPath := configPath + ".tmp"
	if _, err := os.Stat(tempPath); err == nil {
		t.Errorf("Temporary file should not exist after successful save")
	}

	loaded, err := fs.Load()
	if err != nil {
		t.Fatalf("Failed to load config: %v", err)
	}

	if loaded.BaseURL != originalConfig.BaseURL {
		t.Errorf("Loaded config doesn't match saved config")
	}
}
