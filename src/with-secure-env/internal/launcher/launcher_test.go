package launcher_test

import (
	"errors"
	"os"
	"path/filepath"
	"strings"
	"testing"

	"github.com/kfischer-okarin/with-secure-env/internal/launcher"
)

func TestInit_GeneratesAndReturnsKey(t *testing.T) {
	storage := &StubEnvStorage{}

	l := launcher.New(launcher.Config{
		EnvStorage: storage,
	})

	key, err := l.Init("")
	if err != nil {
		t.Fatalf("Init() returned error: %v", err)
	}

	if !storage.Initialized {
		t.Error("expected storage to be initialized")
	}

	if key != storage.StoredKey {
		t.Errorf("expected returned key %q to equal stored key %q", key, storage.StoredKey)
	}
}

func TestInit_WithExistingKey(t *testing.T) {
	storage := &StubEnvStorage{}
	existingKey := "my-existing-secret-key-for-recovery"

	l := launcher.New(launcher.Config{
		EnvStorage: storage,
	})

	key, err := l.Init(existingKey)
	if err != nil {
		t.Fatalf("Init() returned error: %v", err)
	}

	if storage.StoredKey != existingKey {
		t.Errorf("expected stored key %q, got %q", existingKey, storage.StoredKey)
	}

	if key != existingKey {
		t.Errorf("expected returned key %q, got %q", existingKey, key)
	}
}

func TestListApplications(t *testing.T) {
	storage := &StubEnvStorage{}
	storage.Set("/usr/bin/app1", map[string]string{"KEY": "val"})
	storage.Set("/usr/bin/app2", map[string]string{"KEY": "val"})

	l := launcher.New(launcher.Config{
		EnvStorage: storage,
	})

	apps := l.ListApplications()

	if len(apps) != 2 {
		t.Fatalf("expected 2 apps, got %d", len(apps))
	}

	expected := map[string]bool{"/usr/bin/app1": true, "/usr/bin/app2": true}
	for _, app := range apps {
		if !expected[app] {
			t.Errorf("unexpected app: %s", app)
		}
	}
}

func TestListEnvKeys(t *testing.T) {
	storage := &StubEnvStorage{}
	storage.Set("/usr/bin/app", map[string]string{"API_KEY": "secret", "TOKEN": "value"})

	l := launcher.New(launcher.Config{
		EnvStorage: storage,
	})

	keys := l.ListEnvKeys("/usr/bin/app")

	if len(keys) != 2 {
		t.Fatalf("expected 2 keys, got %d", len(keys))
	}

	expected := map[string]bool{"API_KEY": true, "TOKEN": true}
	for _, key := range keys {
		if !expected[key] {
			t.Errorf("unexpected key: %s", key)
		}
	}
}

func TestRemove_DeletesConfig(t *testing.T) {
	storage := &StubEnvStorage{}
	storage.Set("/usr/bin/app", map[string]string{"KEY": "val"})

	l := launcher.New(launcher.Config{
		EnvStorage: storage,
	})

	l.Remove("/usr/bin/app")

	if storage.AppConfigured("/usr/bin/app") {
		t.Error("expected app to be removed")
	}
}

func TestEditEnvs_SavesUpdatedEnvs(t *testing.T) {
	storage := &StubEnvStorage{}
	storage.Set("/usr/bin/test", map[string]string{"OLD_KEY": "old_value"})
	editor := &StubEnvEditor{ReturnEnvs: map[string]string{"NEW_KEY": "new_value"}}

	l := launcher.New(launcher.Config{
		EnvStorage: storage,
		EnvEditor:  editor,
	})

	l.EditEnvs("/usr/bin/test")

	expectedReceived := map[string]string{"OLD_KEY": "old_value"}
	if !mapsEqual(editor.ReceivedEnvs, expectedReceived) {
		t.Errorf("expected editor to receive %v, got %v", expectedReceived, editor.ReceivedEnvs)
	}

	expectedStored := map[string]string{"NEW_KEY": "new_value"}
	if !mapsEqual(storage.Get("/usr/bin/test"), expectedStored) {
		t.Errorf("expected storage to have %v, got %v", expectedStored, storage.Get("/usr/bin/test"))
	}
}

func TestEditEnvs_NoSaveOnCancel(t *testing.T) {
	storage := &StubEnvStorage{}
	storage.Set("/usr/bin/test", map[string]string{"OLD_KEY": "old_value"})
	editor := &StubEnvEditor{ReturnEnvs: nil} // nil signals cancel

	l := launcher.New(launcher.Config{
		EnvStorage: storage,
		EnvEditor:  editor,
	})

	l.EditEnvs("/usr/bin/test")

	expectedStored := map[string]string{"OLD_KEY": "old_value"}
	if !mapsEqual(storage.Get("/usr/bin/test"), expectedStored) {
		t.Errorf("expected storage to remain unchanged %v, got %v", expectedStored, storage.Get("/usr/bin/test"))
	}
}

func TestLaunch_UnknownAppError(t *testing.T) {
	storage := &StubEnvStorage{}
	policy := &StubAccessPolicy{}

	l := launcher.New(launcher.Config{
		EnvStorage:   storage,
		AccessPolicy: policy,
	})

	err := l.Launch("/unknown/app", nil, nil)

	if !errors.Is(err, launcher.ErrUnknownApp) {
		t.Errorf("expected ErrUnknownApp, got %v", err)
	}
}

func TestLaunch_PermissionDenied_NoSecretsAccess(t *testing.T) {
	storage := &StubEnvStorage{}
	storage.Set("/usr/bin/env", map[string]string{"SECRET_KEY": "secret_value"})
	policy := &StubAccessPolicy{Allow: false}

	l := launcher.New(launcher.Config{
		EnvStorage:   storage,
		AccessPolicy: policy,
	})

	err := l.Launch("/usr/bin/env", nil, nil)

	if !errors.Is(err, launcher.ErrPermissionDenied) {
		t.Errorf("expected ErrPermissionDenied, got %v", err)
	}

	if storage.SecretsAccessed {
		t.Error("secrets should not be accessed when permission denied")
	}
}

func TestLaunch_InjectsEnvVarsAndArgs(t *testing.T) {
	scriptPath, outputFile := createTestApp(t, []string{"API_KEY", "SECRET"})

	storage := &StubEnvStorage{}
	storage.Set(scriptPath, map[string]string{"API_KEY": "key123", "SECRET": "secret456"})
	policy := &StubAccessPolicy{Allow: true}

	l := launcher.New(launcher.Config{
		EnvStorage:   storage,
		AccessPolicy: policy,
	})

	err := l.Launch(scriptPath, []string{"arg1", "arg2"}, nil)
	if err != nil {
		t.Fatalf("Launch() returned error: %v", err)
	}

	result := readTestAppOutput(t, outputFile)

	if result.Env["API_KEY"] != "key123" {
		t.Errorf("expected API_KEY=key123, got %s", result.Env["API_KEY"])
	}
	if result.Env["SECRET"] != "secret456" {
		t.Errorf("expected SECRET=secret456, got %s", result.Env["SECRET"])
	}
	if len(result.Args) != 2 || result.Args[0] != "arg1" || result.Args[1] != "arg2" {
		t.Errorf("expected args [arg1, arg2], got %v", result.Args)
	}
}

type testAppOutput struct {
	Env  map[string]string
	Args []string
}

func createTestApp(t *testing.T, captureEnvs []string) (scriptPath, outputFile string) {
	t.Helper()
	tmpDir := t.TempDir()
	outputFile = filepath.Join(tmpDir, "output.txt")
	scriptPath = filepath.Join(tmpDir, "test_app.sh")

	// Build echo commands for each env var
	var envEchos string
	for _, env := range captureEnvs {
		envEchos += "echo '" + env + "='$" + env + "\n"
	}

	// Script outputs: ENV section, then ARGS section (one per line)
	script := `#!/bin/sh
exec > ` + outputFile + `
echo "ENV"
` + envEchos + `echo "ARGS"
for arg in "$@"; do
    echo "$arg"
done
`
	if err := os.WriteFile(scriptPath, []byte(script), 0755); err != nil {
		t.Fatal(err)
	}
	return scriptPath, outputFile
}

func readTestAppOutput(t *testing.T, outputFile string) testAppOutput {
	t.Helper()
	data, err := os.ReadFile(outputFile)
	if err != nil {
		t.Fatalf("failed to read output file: %v", err)
	}

	result := testAppOutput{Env: make(map[string]string)}
	lines := strings.Split(string(data), "\n")

	section := ""
	for _, line := range lines {
		if line == "ENV" {
			section = "env"
			continue
		}
		if line == "ARGS" {
			section = "args"
			continue
		}
		if line == "" {
			continue
		}

		switch section {
		case "env":
			parts := strings.SplitN(line, "=", 2)
			if len(parts) == 2 {
				result.Env[parts[0]] = parts[1]
			}
		case "args":
			result.Args = append(result.Args, line)
		}
	}
	return result
}

func mapsEqual(a, b map[string]string) bool {
	if len(a) != len(b) {
		return false
	}
	for k, v := range a {
		if b[k] != v {
			return false
		}
	}
	return true
}

// StubEnvStorage is a test double for the storage interface
type StubEnvStorage struct {
	Initialized     bool
	StoredKey       string
	SecretsAccessed bool
	envsByApp       map[string]map[string]string
}

func (s *StubEnvStorage) Init(key string) (string, error) {
	s.Initialized = true
	if key != "" {
		s.StoredKey = key
	} else {
		s.StoredKey = "generated-key-12345"
	}
	return s.StoredKey, nil
}

func (s *StubEnvStorage) Set(appPath string, envs map[string]string) {
	if s.envsByApp == nil {
		s.envsByApp = make(map[string]map[string]string)
	}
	s.envsByApp[appPath] = envs
}

func (s *StubEnvStorage) ListApplications() []string {
	apps := make([]string, 0, len(s.envsByApp))
	for app := range s.envsByApp {
		apps = append(apps, app)
	}
	return apps
}

func (s *StubEnvStorage) AvailableKeys(appPath string) []string {
	envs := s.envsByApp[appPath]
	if envs == nil {
		return nil
	}
	keys := make([]string, 0, len(envs))
	for key := range envs {
		keys = append(keys, key)
	}
	return keys
}

func (s *StubEnvStorage) Remove(appPath string) {
	delete(s.envsByApp, appPath)
}

func (s *StubEnvStorage) AppConfigured(appPath string) bool {
	_, ok := s.envsByApp[appPath]
	return ok
}

func (s *StubEnvStorage) Get(appPath string) map[string]string {
	s.SecretsAccessed = true
	return s.envsByApp[appPath]
}

// StubEnvEditor is a test double for the editor interface
type StubEnvEditor struct {
	ReturnEnvs   map[string]string
	ReceivedEnvs map[string]string
}

func (e *StubEnvEditor) Edit(currentEnvs map[string]string) map[string]string {
	e.ReceivedEnvs = currentEnvs
	return e.ReturnEnvs
}

// StubAccessPolicy is a test double for the access policy interface
type StubAccessPolicy struct {
	Allow bool
}

func (p *StubAccessPolicy) Check(appPath string, envKeys []string, processContext any) bool {
	return p.Allow
}
