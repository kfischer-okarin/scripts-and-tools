package config

import (
	"encoding/json"
	"fmt"
	"io"
	"os"
	"path/filepath"
)

type ConfigStore interface {
	Load() (*Config, error)
	Save(config *Config) error
	Exists() bool
	GetPath() string
}

type fileStore struct {
	path string
}

func NewFileStore(path string) ConfigStore {
	return &fileStore{path: path}
}

func (fs *fileStore) Load() (*Config, error) {
	file, err := os.Open(fs.path)
	if err != nil {
		if os.IsNotExist(err) {
			return nil, fmt.Errorf("configuration file not found at %s", fs.path)
		}
		return nil, fmt.Errorf("failed to open configuration file: %w", err)
	}
	defer file.Close()

	data, err := io.ReadAll(file)
	if err != nil {
		return nil, fmt.Errorf("failed to read configuration file: %w", err)
	}

	var config Config
	if err := json.Unmarshal(data, &config); err != nil {
		return nil, fmt.Errorf("failed to parse configuration file: %w", err)
	}

	return &config, nil
}

func (fs *fileStore) Save(config *Config) error {
	dir := filepath.Dir(fs.path)
	if err := os.MkdirAll(dir, 0700); err != nil {
		return fmt.Errorf("failed to create configuration directory: %w", err)
	}

	data, err := json.MarshalIndent(config, "", "  ")
	if err != nil {
		return fmt.Errorf("failed to marshal configuration: %w", err)
	}

	tempFile := fs.path + ".tmp"
	if err := os.WriteFile(tempFile, data, 0600); err != nil {
		return fmt.Errorf("failed to write configuration file: %w", err)
	}

	if err := os.Rename(tempFile, fs.path); err != nil {
		os.Remove(tempFile)
		return fmt.Errorf("failed to save configuration file: %w", err)
	}

	return nil
}

func (fs *fileStore) Exists() bool {
	_, err := os.Stat(fs.path)
	return err == nil
}

func (fs *fileStore) GetPath() string {
	return fs.path
}
