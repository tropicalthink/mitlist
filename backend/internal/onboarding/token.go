// Package onboarding is the post-sign-up tips series: which emails go out,
// when, what they say, and the unsubscribe token that lets a person stop them
// from the email itself, signed in or not.
package onboarding

import (
	"crypto/hmac"
	"crypto/sha256"
	"encoding/base64"

	"github.com/google/uuid"
)

// tokenPurpose keys the MAC so a token minted here cannot be replayed against
// any other HMAC-signed thing that shares the secret.
const tokenPurpose = "onboarding-unsubscribe:"

// macLen is how much of the HMAC-SHA256 tag the token carries. 16 bytes is
// 128 bits, which is plenty for a link that can only ever turn one flag off.
const macLen = 16

// UnsubscribeToken is the stateless credential in the unsubscribe link:
// the user id and a truncated HMAC over it, base64url-encoded. Stateless so
// the link keeps working for as long as the account exists and needs no
// table of its own; bound to the id so a token for one person says nothing
// about another.
func UnsubscribeToken(secret []byte, userID uuid.UUID) string {
	raw := make([]byte, 0, 16+macLen)
	raw = append(raw, userID[:]...)
	raw = append(raw, sign(secret, userID)...)
	return base64.RawURLEncoding.EncodeToString(raw)
}

// ParseUnsubscribeToken verifies a token and returns the user it names. The
// bool is false for anything malformed or with a bad MAC; callers treat both
// the same way and never say which.
func ParseUnsubscribeToken(secret []byte, token string) (uuid.UUID, bool) {
	raw, err := base64.RawURLEncoding.DecodeString(token)
	if err != nil || len(raw) != 16+macLen {
		return uuid.Nil, false
	}
	var id uuid.UUID
	copy(id[:], raw[:16])
	if !hmac.Equal(raw[16:], sign(secret, id)) {
		return uuid.Nil, false
	}
	return id, true
}

func sign(secret []byte, userID uuid.UUID) []byte {
	mac := hmac.New(sha256.New, secret)
	mac.Write([]byte(tokenPurpose))
	mac.Write(userID[:])
	return mac.Sum(nil)[:macLen]
}
