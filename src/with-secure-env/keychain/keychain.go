package keychain

type Keychain interface {
	StoreEncryptionKey(key []byte) error
	RetrieveEncryptionKey() ([]byte, error)
}
