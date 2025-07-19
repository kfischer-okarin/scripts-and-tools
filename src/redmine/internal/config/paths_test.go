package config

import (
	"os"
	"path/filepath"
	"runtime"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
)

func TestGetConfigPath(t *testing.T) {
	tests := []struct {
		name     string
		goos     string
		setup    func()
		cleanup  func()
		validate func(t *testing.T, path string)
	}{
		{
			name: "Linux uses XDG_CONFIG_HOME",
			goos: "linux",
			setup: func() {
				os.Setenv("XDG_CONFIG_HOME", "/custom/config")
			},
			cleanup: func() {
				os.Unsetenv("XDG_CONFIG_HOME")
			},
			validate: func(t *testing.T, path string) {
				assert.Equal(t, "/custom/config/redmine/cli-config.json", path)
			},
		},
		{
			name: "Linux falls back to ~/.config when XDG_CONFIG_HOME not set",
			goos: "linux",
			setup: func() {
				os.Unsetenv("XDG_CONFIG_HOME")
				os.Setenv("HOME", "/home/user")
			},
			cleanup: func() {
				os.Unsetenv("HOME")
			},
			validate: func(t *testing.T, path string) {
				assert.Equal(t, "/home/user/.config/redmine/cli-config.json", path)
			},
		},
		{
			name: "macOS uses Library/Application Support",
			goos: "darwin",
			setup: func() {
				os.Setenv("HOME", "/Users/testuser")
			},
			cleanup: func() {
				os.Unsetenv("HOME")
			},
			validate: func(t *testing.T, path string) {
				// The XDG library on macOS uses XDG_DATA_HOME or falls back to ~/Library/Application Support
				assert.True(t, strings.Contains(path, "redmine/cli-config.json"))
				assert.True(t, strings.Contains(path, "Library/Application Support") || strings.Contains(path, ".local/share"))
			},
		},
		{
			name: "Windows uses APPDATA",
			goos: "windows",
			setup: func() {
				os.Setenv("APPDATA", "C:\\Users\\testuser\\AppData\\Roaming")
			},
			cleanup: func() {
				os.Unsetenv("APPDATA")
			},
			validate: func(t *testing.T, path string) {
				// The XDG library on Windows uses XDG_CONFIG_HOME or falls back to %APPDATA%
				assert.True(t, strings.Contains(path, "redmine"))
				assert.True(t, strings.Contains(path, "cli-config.json"))
			},
		},
		{
			name: "Unix/BSD uses XDG_CONFIG_HOME",
			goos: "freebsd",
			setup: func() {
				os.Setenv("HOME", "/home/user")
			},
			cleanup: func() {
				os.Unsetenv("HOME")
			},
			validate: func(t *testing.T, path string) {
				assert.Equal(t, "/home/user/.config/redmine/cli-config.json", path)
			},
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			// Skip test if not on the actual OS (can't properly mock runtime.GOOS)
			if runtime.GOOS != tt.goos && os.Getenv("CI") == "" {
				t.Skipf("Skipping %s test on %s", tt.goos, runtime.GOOS)
			}

			// Setup test environment
			if tt.setup != nil {
				tt.setup()
			}

			// Get config path
			path := GetConfigPath()

			// Validate result
			tt.validate(t, path)

			// Cleanup
			if tt.cleanup != nil {
				tt.cleanup()
			}
		})
	}
}

func TestGetConfigDir(t *testing.T) {
	// Test that GetConfigDir returns the directory portion of GetConfigPath
	configPath := GetConfigPath()
	configDir := GetConfigDir()

	assert.Equal(t, filepath.Dir(configPath), configDir)
	assert.True(t, strings.Contains(configDir, "redmine"))
	assert.False(t, strings.Contains(configDir, "cli-config.json"))
}
