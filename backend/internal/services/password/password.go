package password

import "golang.org/x/crypto/bcrypt"

const bcryptCost = 12

// Service provides password hashing and verification.
type Service struct{}

// New creates a password hashing service.
func New() *Service {
	return &Service{}
}

// Hash returns a bcrypt hash for password using the application cost.
func (s *Service) Hash(password string) (string, error) {
	hash, err := bcrypt.GenerateFromPassword([]byte(password), bcryptCost)
	if err != nil {
		return "", err
	}
	return string(hash), nil
}

// Compare reports whether password matches hash.
func (s *Service) Compare(hash, password string) bool {
	return bcrypt.CompareHashAndPassword([]byte(hash), []byte(password)) == nil
}
