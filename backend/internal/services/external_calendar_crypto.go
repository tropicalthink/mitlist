package services

import (
	"crypto/aes"
	"crypto/cipher"
	"crypto/hkdf"
	"crypto/rand"
	"crypto/sha256"
	"errors"

	"github.com/google/uuid"
)

// icsURLSealer encrypts ICS subscription URLs at rest. A private iCal link
// is a bearer credential for someone's whole calendar, so the database only
// holds AES-256-GCM ciphertext, bound to its connection id (a ciphertext
// copied to another row does not open). The key is derived with HKDF from
// SECRET_KEY, which every deployment already has.
type icsURLSealer struct{ aead cipher.AEAD }

const icsURLKeyInfo = "mitlist external calendar ics url v1"

var errSealedURL = errors.New("sealed calendar url does not open")

func newICSURLSealer(secret string) (*icsURLSealer, error) {
	key, err := hkdf.Key(sha256.New, []byte(secret), nil, icsURLKeyInfo, 32)
	if err != nil {
		return nil, err
	}
	block, err := aes.NewCipher(key)
	if err != nil {
		return nil, err
	}
	aead, err := cipher.NewGCM(block)
	if err != nil {
		return nil, err
	}
	return &icsURLSealer{aead: aead}, nil
}

func (s *icsURLSealer) seal(connID uuid.UUID, url string) ([]byte, error) {
	nonce := make([]byte, s.aead.NonceSize())
	if _, err := rand.Read(nonce); err != nil {
		return nil, err
	}
	return s.aead.Seal(nonce, nonce, []byte(url), connID[:]), nil
}

func (s *icsURLSealer) open(connID uuid.UUID, blob []byte) (string, error) {
	n := s.aead.NonceSize()
	if len(blob) < n {
		return "", errSealedURL
	}
	plain, err := s.aead.Open(nil, blob[:n], blob[n:], connID[:])
	if err != nil {
		return "", errSealedURL
	}
	return string(plain), nil
}
