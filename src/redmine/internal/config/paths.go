package config

import (
	"path/filepath"
	"runtime"

	"github.com/adrg/xdg"
)

// GetConfigPath returns the OS-specific path for the configuration file.
// It follows platform conventions:
// - Linux/Unix: Uses XDG Base Directory specification
// - macOS: Uses ~/Library/Application Support
// - Windows: Uses %APPDATA%
func GetConfigPath() string {
	const appName = "redmine"
	const configFileName = "cli-config.json"

	switch runtime.GOOS {
	case "darwin":
		// macOS: ~/Library/Application Support/redmine/cli-config.json
		configDir := filepath.Join(xdg.DataHome, appName)
		return filepath.Join(configDir, configFileName)
	case "windows":
		// Windows: %APPDATA%\redmine\cli-config.json
		configDir := filepath.Join(xdg.ConfigHome, appName)
		return filepath.Join(configDir, configFileName)
	default:
		// Linux/Unix: $XDG_CONFIG_HOME/redmine/cli-config.json
		// Falls back to ~/.config/redmine/cli-config.json if XDG_CONFIG_HOME is not set
		configDir := filepath.Join(xdg.ConfigHome, appName)
		return filepath.Join(configDir, configFileName)
	}
}

// GetConfigDir returns the directory where the configuration file should be stored.
func GetConfigDir() string {
	return filepath.Dir(GetConfigPath())
}
