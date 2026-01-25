//go:build darwin

package keychain

import (
	gokeychain "github.com/keybase/go-keychain"
)

const (
	serviceName = "with-secure-env"
	accountName = "encryption-key"
)

type MacOSKeychain struct{}

func (m *MacOSKeychain) StoreEncryptionKey(key []byte) error {
	// Delete existing key first (if any)
	m.deleteExisting()

	item := gokeychain.NewItem()
	item.SetSecClass(gokeychain.SecClassGenericPassword)
	item.SetService(serviceName)
	item.SetAccount(accountName)
	item.SetLabel("with-secure-env encryption key")
	item.SetData(key)
	item.SetSynchronizable(gokeychain.SynchronizableNo)
	item.SetAccessible(gokeychain.AccessibleWhenUnlocked)

	return gokeychain.AddItem(item)
}

func (m *MacOSKeychain) RetrieveEncryptionKey() ([]byte, error) {
	query := gokeychain.NewItem()
	query.SetSecClass(gokeychain.SecClassGenericPassword)
	query.SetService(serviceName)
	query.SetAccount(accountName)
	query.SetMatchLimit(gokeychain.MatchLimitOne)
	query.SetReturnData(true)

	results, err := gokeychain.QueryItem(query)
	if err != nil {
		return nil, err
	}
	if len(results) == 0 {
		return nil, gokeychain.ErrorItemNotFound
	}

	return results[0].Data, nil
}

func (m *MacOSKeychain) deleteExisting() {
	item := gokeychain.NewItem()
	item.SetSecClass(gokeychain.SecClassGenericPassword)
	item.SetService(serviceName)
	item.SetAccount(accountName)
	gokeychain.DeleteItem(item)
}
