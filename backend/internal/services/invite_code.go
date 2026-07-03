package services

import (
	"crypto/rand"
	"fmt"
	"math/big"
	"strings"
)

// inviteAlphabet is an unambiguous base32-style alphabet: no 0/O/1/I/L, so
// codes are easy to read aloud and transcribe without confusion.
const inviteAlphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789" // 31 chars

// inviteTokenLen is the length of the crypto-random suffix. 31 chars ≈ 4.954
// bits/char (log2(31)); 13 chars ≈ 64.4 bits, comfortably clearing the 2^60
// target keyspace on its own (the ADJ-NOUN prefix adds further entropy on
// top but is not required to hit the bar).
const inviteTokenLen = 13

// generatePlayfulInviteCode returns a short, readable, human-shareable invite code.
// Format: ADJ-NOUN-TOKEN (uppercase, hyphen-separated), where TOKEN is a
// 13-character crypto-random suffix providing ~64.4 bits of entropy.
func generatePlayfulInviteCode() (string, error) {
	adj, err := pickOne(inviteAdjectives)
	if err != nil {
		return "", err
	}
	noun, err := pickOne(inviteNouns)
	if err != nil {
		return "", err
	}

	token, err := randToken(inviteTokenLen)
	if err != nil {
		return "", err
	}

	code := fmt.Sprintf("%s-%s-%s", adj, noun, token)
	return strings.ToUpper(code), nil
}

// randToken returns an n-character crypto-random string drawn from
// inviteAlphabet, which is already uppercase and collision-free after
// strings.ToUpper.
func randToken(n int) (string, error) {
	b := make([]byte, n)
	for i := range b {
		idx, err := cryptoRandInt(0, len(inviteAlphabet)-1)
		if err != nil {
			return "", err
		}
		b[i] = inviteAlphabet[idx]
	}
	return string(b), nil
}

func pickOne(items []string) (string, error) {
	if len(items) == 0 {
		return "", fmt.Errorf("invite code wordlist is empty")
	}
	i, err := cryptoRandInt(0, len(items)-1)
	if err != nil {
		return "", err
	}
	return items[i], nil
}

func cryptoRandInt(min, max int) (int, error) {
	if max < min {
		return 0, fmt.Errorf("invalid range: %d..%d", min, max)
	}
	n := big.NewInt(int64(max - min + 1))
	v, err := rand.Int(rand.Reader, n)
	if err != nil {
		return 0, err
	}
	return min + int(v.Int64()), nil
}

var inviteAdjectives = []string{
	"sunny",
	"cozy",
	"brave",
	"fresh",
	"happy",
	"bright",
	"snappy",
	"neat",
	"kind",
	"zesty",
	"mellow",
	"peppy",
	"chill",
	"quick",
	"tidy",
	"warm",
	"punchy",
	"calm",
	"lucky",
	"clever",
}

var inviteNouns = []string{
	"taco",
	"toast",
	"pasta",
	"cider",
	"peach",
	"donut",
	"bagel",
	"soup",
	"basil",
	"mango",
	"oat",
	"cookie",
	"cocoa",
	"pocket",
	"notebook",
	"marker",
	"lamp",
	"teapot",
	"plant",
	"rocket",
}

