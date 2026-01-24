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

	fileContent := l.loadFileContent()
	fileContent[applicationPath] = encryptedEnvs

	data, _ := json.Marshal(fileContent)
	os.WriteFile(l.EncryptedEnvPath, data, 0600)
}

func (l *Launcher) loadFileContent() map[string]map[string]string {
	fileContent := map[string]map[string]string{}
	data, _ := os.ReadFile(l.EncryptedEnvPath)
	json.Unmarshal(data, &fileContent)
	return fileContent
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

func (l *Launcher) decrypt(key []byte, encryptedBase64 string) string {
	data, _ := base64.StdEncoding.DecodeString(encryptedBase64)
	block, _ := aes.NewCipher(key)
	gcm, _ := cipher.NewGCM(block)
	nonceSize := gcm.NonceSize()
	nonce, ciphertext := data[:nonceSize], data[nonceSize:]
	plaintext, _ := gcm.Open(nil, nonce, ciphertext, nil)
	return string(plaintext)
}

func (l *Launcher) encrypt(key []byte, plaintext string) string {
	block, _ := aes.NewCipher(key)
	gcm, _ := cipher.NewGCM(block)

	nonce := make([]byte, gcm.NonceSize())
	rand.Read(nonce)

	ciphertext := gcm.Seal(nonce, nonce, []byte(plaintext), nil)
	return base64.StdEncoding.EncodeToString(ciphertext)
}
