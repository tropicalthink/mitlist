package services

import (
	"crypto/rand"
	"fmt"
	"math/big"
	"strings"
)

// generatePlayfulInviteCode returns a short, readable, human-shareable invite code.
// Format: ADJ-NOUN-## (uppercase, hyphen-separated).
func generatePlayfulInviteCode() (string, error) {
	adj, err := pickOne(inviteAdjectives)
	if err != nil {
		return "", err
	}
	noun, err := pickOne(inviteNouns)
	if err != nil {
		return "", err
	}

	// 2 digits keeps it short; word pairs carry most of the uniqueness.
	num, err := cryptoRandInt(0, 99)
	if err != nil {
		return "", err
	}

	code := fmt.Sprintf("%s-%s-%02d", adj, noun, num)
	return strings.ToUpper(code), nil
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

