package main

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/rand"
	"encoding/base64"
	"encoding/json"
	"os"

	"github.com/kfischer-okarin/with-secure-env/editdialog"
	"github.com/kfischer-okarin/with-secure-env/keychain"
)

type Launcher struct {
	Keychain         keychain.Keychain
	EditDialog       editdialog.EditDialog
	EncryptedEnvPath string
}

func (l *Launcher) Init() {
	key := make([]byte, 32)
	rand.Read(key)
	l.Keychain.StoreEncryptionKey(key)
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

	fileContent := map[string]map[string]string{
		applicationPath: encryptedEnvs,
	}

	data, _ := json.Marshal(fileContent)
	os.WriteFile(l.EncryptedEnvPath, data, 0600)
}

func (l *Launcher) encrypt(key []byte, plaintext string) string {
	block, _ := aes.NewCipher(key)
	gcm, _ := cipher.NewGCM(block)

	nonce := make([]byte, gcm.NonceSize())
	rand.Read(nonce)

	ciphertext := gcm.Seal(nonce, nonce, []byte(plaintext), nil)
	return base64.StdEncoding.EncodeToString(ciphertext)
}
