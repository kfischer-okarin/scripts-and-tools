package main

import "testing"

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
