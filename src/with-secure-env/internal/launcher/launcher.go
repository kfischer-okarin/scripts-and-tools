package launcher

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"os"
	"path/filepath"

	"github.com/kfischer-okarin/with-secure-env/internal/editdialog"
	"github.com/kfischer-okarin/with-secure-env/internal/keychain"
	"github.com/kfischer-okarin/with-secure-env/internal/permissiondialog"
)

type Launcher struct {
	Keychain         keychain.Keychain
	EditDialog       editdialog.EditDialog
	PermissionDialog permissiondialog.PermissionDialog
	ConfigDirPath    string
	Exec             func(path string, args []string, env []string) error
}

func (l *Launcher) Init() {
	key := make([]byte, 32)
	rand.Read(key)
	l.Keychain.StoreEncryptionKey(key)
}

func (l *Launcher) Launch(applicationPath string, args []string, caller permissiondialog.CallerInfo) {
	fileContent := l.loadFileContent()
	encryptedEnvs := fileContent[applicationPath]

	envNames := make([]string, 0, len(encryptedEnvs))
	for name := range encryptedEnvs {
		envNames = append(envNames, name)
	}

	granted := l.PermissionDialog.AskPermission(applicationPath, args, envNames, caller)
	if !granted {
		return
	}

	key, _ := l.Keychain.RetrieveEncryptionKey()

	env := make([]string, 0, len(encryptedEnvs))
	for name, encrypted := range encryptedEnvs {
		env = append(env, name+"="+l.decrypt(key, encrypted))
	}

	l.Exec(applicationPath, args, env)
}

func (l *Launcher) EditEnvs(applicationPath string) {
	key, _ := l.Keychain.RetrieveEncryptionKey()
	currentValues := l.loadEnvs(applicationPath, key)

	newValues, ok := l.EditDialog.EditEnvs(applicationPath, currentValues)
	if !ok {
		return
	}

	encryptedEnvs := make(map[string]string)
	for envName, value := range newValues {
		encryptedEnvs[envName] = l.encrypt(key, value)
	}

	fileContent := l.loadFileContent()
	fileContent[applicationPath] = encryptedEnvs

	data, _ := json.Marshal(fileContent)
	os.WriteFile(l.encryptedEnvsPath(), data, 0600)
}

func (l *Launcher) loadEnvs(applicationPath string, key []byte) map[string]string {
	fileContent := l.loadFileContent()
	encryptedEnvs := fileContent[applicationPath]
	if encryptedEnvs == nil {
		return map[string]string{}
	}

	decryptedEnvs := make(map[string]string)
	for envName, encryptedValue := range encryptedEnvs {
		decryptedEnvs[envName] = l.decrypt(key, encryptedValue)
	}
	return decryptedEnvs
}

func (l *Launcher) loadFileContent() map[string]map[string]string {
	fileContent := map[string]map[string]string{}
	data, _ := os.ReadFile(l.encryptedEnvsPath())
	json.Unmarshal(data, &fileContent)
	return fileContent
}

func (l *Launcher) encryptedEnvsPath() string {
	return filepath.Join(l.ConfigDirPath, "envs.json")
}

func (l *Launcher) encrypt(key []byte, plaintext string) string {
	block, _ := aes.NewCipher(key)
	gcm, _ := cipher.NewGCM(block)

	nonce := make([]byte, gcm.NonceSize())
	rand.Read(nonce)

	ciphertext := gcm.Seal(nonce, nonce, []byte(plaintext), nil)
	return base64.StdEncoding.EncodeToString(ciphertext)
}

func (l *Launcher) decrypt(key []byte, encryptedBase64 string) string {
	data, _ := base64.StdEncoding.DecodeString(encryptedBase64)
	block, _ := aes.NewCipher(key)
	gcm, _ := cipher.NewGCM(block)
	nonceSize := gcm.NonceSize()
	nonce, ciphertext := data[:nonceSize], data[nonceSize:]
	plaintext, _ := gcm.Open(nil, nonce, ciphertext, nil)
	return string(plaintext)
}
