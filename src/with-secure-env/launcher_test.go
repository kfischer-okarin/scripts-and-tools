package main

import (
	"crypto/aes"
	"crypto/cipher"
	"encoding/base64"
	"encoding/json"
	"os"
	"testing"
)

func TestLauncherInit_StoresValidAESKey(t *testing.T) {
	kc := &stubKeychain{}
	launcher := Launcher{Keychain: kc}

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
	kc1 := &stubKeychain{}
	launcher1 := Launcher{Keychain: kc1}
	launcher1.Init()
	key1, _ := kc1.RetrieveEncryptionKey()

	kc2 := &stubKeychain{}
	launcher2 := Launcher{Keychain: kc2}
	launcher2.Init()
	key2, _ := kc2.RetrieveEncryptionKey()

	if string(key1) == string(key2) {
		t.Error("expected different keys for each Init call")
	}
}

func TestEditEnvs_AppsHaveEmptyEnvAtFirst(t *testing.T) {
	dialog := &stubEditDialog{returnOk: false}
	launcher := Launcher{EditDialog: dialog}

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
	tmpFile, _ := os.CreateTemp("", "envs-*.json")
	tmpFile.Close()
	defer os.Remove(tmpFile.Name())

	kc := &stubKeychain{}
	dialog := &stubEditDialog{}
	launcher := Launcher{
		Keychain:         kc,
		EditDialog:       dialog,
		EncryptedEnvPath: tmpFile.Name(),
	}
	launcher.Init()

	dialog.returnValues = map[string]string{"SECRET_KEY": "mysecretvalue"}
	dialog.returnOk = true
	launcher.EditEnvs("/path/to/app")

	data, _ := os.ReadFile(tmpFile.Name())
	var fileContent map[string]map[string]string
	json.Unmarshal(data, &fileContent)

	encryptedValue := fileContent["/path/to/app"]["SECRET_KEY"]
	decryptedValue := decrypt(t, kc.storedKey, encryptedValue)

	if decryptedValue != "mysecretvalue" {
		t.Errorf("expected 'mysecretvalue', got '%s'", decryptedValue)
	}
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
	storedKey []byte
}

func (s *stubKeychain) StoreEncryptionKey(key []byte) error {
	s.storedKey = key
	return nil
}

func (s *stubKeychain) RetrieveEncryptionKey() ([]byte, error) {
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
