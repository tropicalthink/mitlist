package services

import (
	"regexp"
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

var inviteCodeShape = regexp.MustCompile(`^[A-Z]+-[A-Z]+-[A-Z2-9]{13}$`)

func TestGeneratePlayfulInviteCode_Shape(t *testing.T) {
	for i := 0; i < 100; i++ {
		code, err := generatePlayfulInviteCode()
		require.NoError(t, err)
		assert.Regexp(t, inviteCodeShape, code, "code %q did not match expected shape", code)
	}
}

func TestGeneratePlayfulInviteCode_Uniqueness(t *testing.T) {
	const n = 10000
	seen := make(map[string]struct{}, n)
	for i := 0; i < n; i++ {
		code, err := generatePlayfulInviteCode()
		require.NoError(t, err)
		if _, dup := seen[code]; dup {
			t.Fatalf("duplicate invite code generated: %s", code)
		}
		seen[code] = struct{}{}
	}
}

func TestGeneratePlayfulInviteCode_TokenAlphabet(t *testing.T) {
	for i := 0; i < 200; i++ {
		code, err := generatePlayfulInviteCode()
		require.NoError(t, err)

		parts := strings.Split(code, "-")
		require.Len(t, parts, 3, "code %q should have 3 hyphen-separated parts", code)

		token := parts[2]
		require.Len(t, token, inviteTokenLen)
		for _, c := range token {
			assert.Contains(t, inviteAlphabet, string(c), "token %q contains character outside inviteAlphabet", token)
		}
	}
}

func TestRandToken_Length(t *testing.T) {
	tok, err := randToken(inviteTokenLen)
	require.NoError(t, err)
	assert.Len(t, tok, inviteTokenLen)
	for _, c := range tok {
		assert.Contains(t, inviteAlphabet, string(c))
	}
}
