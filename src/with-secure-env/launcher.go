package main

import (
	"crypto/rand"

	"github.com/kfischer-okarin/with-secure-env/keychain"
)

type Launcher struct {
	Keychain keychain.Keychain
}

func (l *Launcher) Init() {
	key := make([]byte, 32)
	rand.Read(key)
	l.Keychain.StoreEncryptionKey(key)
}
