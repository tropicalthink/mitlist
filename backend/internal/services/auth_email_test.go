package services

import (
	"strings"
	"testing"

	"github.com/stretchr/testify/assert"
	"github.com/stretchr/testify/require"
)

func TestVerificationEmail(t *testing.T) {
	msg := verificationEmail("ABCD1234", "https://app.mitlist.me/")

	assert.Equal(t, "Verify your mitlist account", msg.Subject)

	// The text part is what tests and text-only clients read: the code sits
	// on the "code is:" line, followed by the link.
	assert.Contains(t, msg.Text, "Your email verification code is: ABCD1234\n")
	assert.Contains(t, msg.Text, "https://app.mitlist.me/verify?token=ABCD1234")

	// The HTML part carries the same code and the button link, without a
	// doubled slash from the trailing one on the origin.
	assert.Contains(t, msg.HTML, ">ABCD1234<")
	assert.Contains(t, msg.HTML, `href="https://app.mitlist.me/verify?token=ABCD1234"`)
	assert.NotContains(t, msg.HTML, "me//verify")
	assert.Contains(t, msg.HTML, "Verify in mitlist")
	assert.Contains(t, msg.HTML, "30 minutes")
}

func TestPasswordResetEmail(t *testing.T) {
	msg := passwordResetEmail("ZZZZ9999", "https://app.mitlist.me")

	assert.Equal(t, "Reset your mitlist password", msg.Subject)
	assert.Contains(t, msg.Text, "Your password reset code is: ZZZZ9999\n")
	assert.Contains(t, msg.Text, "https://app.mitlist.me/reset-password?token=ZZZZ9999")
	assert.Contains(t, msg.HTML, `href="https://app.mitlist.me/reset-password?token=ZZZZ9999"`)
	assert.Contains(t, msg.HTML, ">ZZZZ9999<")
	assert.Contains(t, msg.HTML, "Reset password in mitlist")
}

func TestAuthEmail_NoFrontendURLMeansNoLink(t *testing.T) {
	// A self-host without a web app gets the code alone; an empty href would
	// be a broken button.
	msg := verificationEmail("ABCD1234", "")
	assert.NotContains(t, msg.HTML, "href=\"\"")
	assert.NotContains(t, msg.HTML, "Verify in mitlist")
	assert.NotContains(t, msg.Text, "http")
	assert.Contains(t, msg.Text, "code is: ABCD1234")
}

func TestAuthEmail_EscapesCodeInHTMLAndURL(t *testing.T) {
	// Codes are server-generated and alphanumeric, but the template must not
	// rely on that: anything reaching the markup or the query is escaped.
	msg := verificationEmail(`<b>&x</b>`, "https://app.mitlist.me")
	require.NotContains(t, msg.HTML, "<b>&x</b>")
	assert.Contains(t, msg.HTML, "&lt;b&gt;")
	assert.True(t, strings.Contains(msg.HTML, "token=%3Cb%3E%26x%3C%2Fb%3E"), "query must be percent-encoded: %s", msg.HTML)
}
