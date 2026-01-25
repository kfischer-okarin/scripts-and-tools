package launcher

import (
	"crypto/aes"
	"crypto/cipher"
	"encoding/base64"
	"encoding/json"
	"os"
	"path/filepath"
	"testing"

	"github.com/kfischer-okarin/with-secure-env/internal/permissiondialog"
)

func TestLauncherInit_StoresValidAESKey(t *testing.T) {
	launcher, kc, _, _ := newTestLauncher(t)

	launcher.Init()

	key, _ := kc.RetrieveEncryptionKey()
	if len(key) != 32 {
		t.Errorf("expected key length 32, got %d", len(key))
	}
	allZeros := true
	for _, b := range key {
		if b != 0 {
			allZeros = false
			break
		}
	}
	if allZeros {
		t.Error("expected key to not be all zeros")
	}
}

func TestLauncherInit_GeneratesDifferentKeysEachTime(t *testing.T) {
	launcher1, kc1, _, _ := newTestLauncher(t)
	launcher1.Init()
	key1, _ := kc1.RetrieveEncryptionKey()

	launcher2, kc2, _, _ := newTestLauncher(t)
	launcher2.Init()
	key2, _ := kc2.RetrieveEncryptionKey()

	if string(key1) == string(key2) {
		t.Error("expected different keys for each Init call")
	}
}

func TestEditEnvs_AppsHaveEmptyEnvAtFirst(t *testing.T) {
	launcher, _, dialog, _ := newTestLauncher(t)
	launcher.Init()

	launcher.EditEnvs("/path/to/app")

	if dialog.receivedAppPath != "/path/to/app" {
		t.Errorf("expected app path '/path/to/app', got '%s'", dialog.receivedAppPath)
	}
	if dialog.receivedCurrentValues == nil {
		t.Error("expected empty map, got nil")
	}
	if len(dialog.receivedCurrentValues) != 0 {
		t.Errorf("expected empty map, got %v", dialog.receivedCurrentValues)
	}
}

func TestEditEnvs_SavesEncryptedEnvsToFile(t *testing.T) {
	launcher, kc, dialog, _ := newTestLauncher(t)
	launcher.Init()

	dialog.returnValues = map[string]string{"SECRET_KEY": "mysecretvalue"}
	dialog.returnOk = true
	launcher.EditEnvs("/path/to/app")

	data, _ := os.ReadFile(filepath.Join(launcher.ConfigDirPath, "envs.json"))
	var fileContent map[string]map[string]string
	json.Unmarshal(data, &fileContent)

	encryptedValue := fileContent["/path/to/app"]["SECRET_KEY"]
	decryptedValue := decrypt(t, kc.storedKey, encryptedValue)

	if decryptedValue != "mysecretvalue" {
		t.Errorf("expected 'mysecretvalue', got '%s'", decryptedValue)
	}
}

func TestEditEnvs_ShowsStoredValuesOnSecondEdit(t *testing.T) {
	launcher, _, dialog, _ := newTestLauncher(t)
	launcher.Init()

	dialog.returnValues = map[string]string{"SECRET_KEY": "mysecretvalue"}
	dialog.returnOk = true
	launcher.EditEnvs("/path/to/app")

	dialog.returnValues = map[string]string{"SECRET_KEY": "updatedvalue"}
	launcher.EditEnvs("/path/to/app")

	if dialog.receivedCurrentValues["SECRET_KEY"] != "mysecretvalue" {
		t.Errorf("expected 'mysecretvalue', got '%s'", dialog.receivedCurrentValues["SECRET_KEY"])
	}
}

func TestEditEnvs_DoesNotUpdateWhenCanceled(t *testing.T) {
	launcher, kc, dialog, _ := newTestLauncher(t)
	launcher.Init()

	dialog.returnValues = map[string]string{"SECRET_KEY": "originalvalue"}
	dialog.returnOk = true
	launcher.EditEnvs("/path/to/app")

	dialog.returnOk = false
	launcher.EditEnvs("/path/to/app")

	data, _ := os.ReadFile(filepath.Join(launcher.ConfigDirPath, "envs.json"))
	var fileContent map[string]map[string]string
	json.Unmarshal(data, &fileContent)

	decryptedValue := decrypt(t, kc.storedKey, fileContent["/path/to/app"]["SECRET_KEY"])
	if decryptedValue != "originalvalue" {
		t.Errorf("expected 'originalvalue', got '%s'", decryptedValue)
	}
}

func TestEditEnvs_StoresEnvsForMultipleApps(t *testing.T) {
	launcher, kc, dialog, _ := newTestLauncher(t)
	launcher.Init()

	dialog.returnValues = map[string]string{"API_KEY": "app1secret"}
	dialog.returnOk = true
	launcher.EditEnvs("/path/to/app1")

	dialog.returnValues = map[string]string{"DB_PASS": "app2secret"}
	launcher.EditEnvs("/path/to/app2")

	data, _ := os.ReadFile(filepath.Join(launcher.ConfigDirPath, "envs.json"))
	var fileContent map[string]map[string]string
	json.Unmarshal(data, &fileContent)

	decrypted1 := decrypt(t, kc.storedKey, fileContent["/path/to/app1"]["API_KEY"])
	decrypted2 := decrypt(t, kc.storedKey, fileContent["/path/to/app2"]["DB_PASS"])

	if decrypted1 != "app1secret" {
		t.Errorf("expected 'app1secret', got '%s'", decrypted1)
	}
	if decrypted2 != "app2secret" {
		t.Errorf("expected 'app2secret', got '%s'", decrypted2)
	}
}

func TestLaunch_AsksPermissionWithContext(t *testing.T) {
	launcher, _, editDialog, permDialog := newTestLauncher(t)
	launcher.Init()

	editDialog.returnValues = map[string]string{"API_KEY": "secret", "DB_PASS": "pass"}
	editDialog.returnOk = true
	launcher.EditEnvs("/path/to/app")

	caller := permissiondialog.CallerInfo{Name: "claude", PID: 1234}
	launcher.Launch("/path/to/app", []string{"--flag", "value"}, caller)

	if permDialog.receivedAppPath != "/path/to/app" {
		t.Errorf("expected app path '/path/to/app', got '%s'", permDialog.receivedAppPath)
	}
	if len(permDialog.receivedEnvNames) != 2 {
		t.Errorf("expected 2 env names, got %d", len(permDialog.receivedEnvNames))
	}
	if len(permDialog.receivedArgs) != 2 || permDialog.receivedArgs[0] != "--flag" {
		t.Errorf("expected args ['--flag', 'value'], got %v", permDialog.receivedArgs)
	}
	if permDialog.receivedCaller.Name != "claude" || permDialog.receivedCaller.PID != 1234 {
		t.Errorf("expected caller {claude, 1234}, got %v", permDialog.receivedCaller)
	}
}

func TestLaunch_DoesNotAccessKeychainIfPermissionDenied(t *testing.T) {
	launcher, kc, editDialog, permDialog := newTestLauncher(t)
	launcher.Init()

	editDialog.returnValues = map[string]string{"API_KEY": "secret"}
	editDialog.returnOk = true
	launcher.EditEnvs("/path/to/app")

	kc.retrieveCount = 0
	permDialog.returnGranted = false
	launcher.Launch("/path/to/app", nil, permissiondialog.CallerInfo{})

	if kc.retrieveCount != 0 {
		t.Errorf("expected no keychain access, got %d", kc.retrieveCount)
	}
}

func TestLaunch_ExecutesAppWithEnvsAndArgs(t *testing.T) {
	launcher, _, editDialog, permDialog := newTestLauncher(t)
	launcher.Init()

	editDialog.returnValues = map[string]string{"API_KEY": "secretkey", "DB_PASS": "secretpass"}
	editDialog.returnOk = true
	launcher.EditEnvs("/path/to/app")

	var executedPath string
	var executedArgs []string
	var executedEnv []string
	launcher.Exec = func(path string, args []string, env []string) error {
		executedPath = path
		executedArgs = args
		executedEnv = env
		return nil
	}

	permDialog.returnGranted = true
	launcher.Launch("/path/to/app", []string{"--flag", "value"}, permissiondialog.CallerInfo{})

	if executedPath != "/path/to/app" {
		t.Errorf("expected path '/path/to/app', got '%s'", executedPath)
	}
	if len(executedArgs) != 2 || executedArgs[0] != "--flag" {
		t.Errorf("expected args ['--flag', 'value'], got %v", executedArgs)
	}
	if !containsEnv(executedEnv, "API_KEY=secretkey") || !containsEnv(executedEnv, "DB_PASS=secretpass") {
		t.Errorf("expected envs to contain API_KEY and DB_PASS, got %v", executedEnv)
	}
}

func containsEnv(env []string, needle string) bool {
	for _, e := range env {
		if e == needle {
			return true
		}
	}
	return false
}

func newTestLauncher(t *testing.T) (*Launcher, *stubKeychain, *stubEditDialog, *stubPermissionDialog) {
	tmpDir, _ := os.MkdirTemp("", "config-*")
	t.Cleanup(func() { os.RemoveAll(tmpDir) })

	kc := &stubKeychain{}
	editDialog := &stubEditDialog{}
	permDialog := &stubPermissionDialog{}
	launcher := &Launcher{
		Keychain:         kc,
		EditDialog:       editDialog,
		PermissionDialog: permDialog,
		ConfigDirPath:    tmpDir,
	}

	return launcher, kc, editDialog, permDialog
}

func decrypt(t *testing.T, key []byte, encryptedBase64 string) string {
	data, err := base64.StdEncoding.DecodeString(encryptedBase64)
	if err != nil {
		t.Fatalf("failed to decode base64: %v", err)
	}

	block, err := aes.NewCipher(key)
	if err != nil {
		t.Fatalf("failed to create cipher: %v", err)
	}

	gcm, err := cipher.NewGCM(block)
	if err != nil {
		t.Fatalf("failed to create GCM: %v", err)
	}

	nonceSize := gcm.NonceSize()
	nonce, ciphertext := data[:nonceSize], data[nonceSize:]

	plaintext, err := gcm.Open(nil, nonce, ciphertext, nil)
	if err != nil {
		t.Fatalf("failed to decrypt: %v", err)
	}

	return string(plaintext)
}

type stubKeychain struct {
	storedKey     []byte
	retrieveCount int
}

func (s *stubKeychain) StoreEncryptionKey(key []byte) error {
	s.storedKey = key
	return nil
}

func (s *stubKeychain) RetrieveEncryptionKey() ([]byte, error) {
	s.retrieveCount++
	return s.storedKey, nil
}

type stubEditDialog struct {
	receivedAppPath       string
	receivedCurrentValues map[string]string
	returnValues          map[string]string
	returnOk              bool
}

func (s *stubEditDialog) EditEnvs(applicationPath string, currentValues map[string]string) (map[string]string, bool) {
	s.receivedAppPath = applicationPath
	s.receivedCurrentValues = currentValues
	return s.returnValues, s.returnOk
}

type stubPermissionDialog struct {
	receivedAppPath  string
	receivedArgs     []string
	receivedEnvNames []string
	receivedCaller   permissiondialog.CallerInfo
	returnGranted    bool
}

func (s *stubPermissionDialog) AskPermission(applicationPath string, args []string, envNames []string, caller permissiondialog.CallerInfo) bool {
	s.receivedAppPath = applicationPath
	s.receivedArgs = args
	s.receivedEnvNames = envNames
	s.receivedCaller = caller
	return s.returnGranted
}
