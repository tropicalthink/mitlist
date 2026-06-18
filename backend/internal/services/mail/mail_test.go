package mail

import (
	"strings"
	"testing"
)

// TestBuildMessage_NormalSend verifies that a normal message contains the
// required RFC 2822 headers: From, To, Subject, Date, MIME-Version, Content-Type.
func TestBuildMessage_NormalSend(t *testing.T) {
	msg := string(buildMessage("noreply@mitlist.me", "user@example.com", "Hello world", "body text", false))

	requiredHeaders := []string{
		"From: noreply@mitlist.me",
		"To: user@example.com",
		"Subject: Hello world",
		"MIME-Version: 1.0",
		"Content-Type: text/plain",
		"Date: ",
	}
	for _, h := range requiredHeaders {
		if !strings.Contains(msg, h) {
			t.Errorf("expected header %q to be present in message:\n%s", h, msg)
		}
	}
}

// TestBuildMessage_HTMLContentType verifies the Content-Type switches to text/html
// when isHTML is true.
func TestBuildMessage_HTMLContentType(t *testing.T) {
	msg := string(buildMessage("noreply@mitlist.me", "user@example.com", "Subject", "<p>body</p>", true))
	if !strings.Contains(msg, "Content-Type: text/html") {
		t.Errorf("expected HTML content type, got:\n%s", msg)
	}
}

// hasBccHeader returns true if there is a line in the header block that starts
// with "Bcc:" (i.e., a real injected Bcc header). A sanitized value that merely
// contains the substring "Bcc:" on an existing header line does NOT count as
// injection — it is benign concatenation on the same header.
func hasBccHeader(headers string) bool {
	for _, line := range strings.Split(headers, "\r\n") {
		if strings.HasPrefix(line, "Bcc:") {
			return true
		}
	}
	return false
}

// TestBuildMessage_InjectionInSubject verifies that a subject containing CRLF
// cannot inject an additional header (e.g., Bcc). After sanitization the CRLF
// is stripped so the injected text becomes part of the Subject value, not a
// separate header line.
func TestBuildMessage_InjectionInSubject(t *testing.T) {
	maliciousSubject := "Legit subject\r\nBcc: attacker@evil.com"
	msg := string(buildMessage("from@mitlist.me", "user@example.com", maliciousSubject, "body", false))

	// Split headers from body (separated by \r\n\r\n)
	parts := strings.SplitN(msg, "\r\n\r\n", 2)
	headers := parts[0]

	if hasBccHeader(headers) {
		t.Errorf("header injection succeeded — standalone Bcc: header found:\n%s", headers)
	}
}

// TestBuildMessage_InjectionInTo verifies that a To address containing CRLF
// cannot inject an additional header.
func TestBuildMessage_InjectionInTo(t *testing.T) {
	maliciousTo := "user@example.com\r\nBcc: attacker@evil.com"
	msg := string(buildMessage("from@mitlist.me", maliciousTo, "Normal subject", "body", false))

	parts := strings.SplitN(msg, "\r\n\r\n", 2)
	headers := parts[0]

	if hasBccHeader(headers) {
		t.Errorf("header injection via To: succeeded — standalone Bcc: header found:\n%s", headers)
	}
}

// TestBuildMessage_InjectionInFrom verifies that a From address containing CRLF
// cannot inject an additional header.
func TestBuildMessage_InjectionInFrom(t *testing.T) {
	maliciousFrom := "legit@mitlist.me\r\nBcc: attacker@evil.com"
	msg := string(buildMessage(maliciousFrom, "user@example.com", "Normal subject", "body", false))

	parts := strings.SplitN(msg, "\r\n\r\n", 2)
	headers := parts[0]

	if hasBccHeader(headers) {
		t.Errorf("header injection via From: succeeded — standalone Bcc: header found:\n%s", headers)
	}
}

// TestBuildMessage_BodyPreserved verifies that the message body is preserved
// intact after the blank-line separator.
func TestBuildMessage_BodyPreserved(t *testing.T) {
	body := "Hello, this is the email body!"
	msg := string(buildMessage("from@mitlist.me", "to@example.com", "subj", body, false))

	parts := strings.SplitN(msg, "\r\n\r\n", 2)
	if len(parts) != 2 {
		t.Fatalf("message has no header/body separator: %q", msg)
	}
	if parts[1] != body {
		t.Errorf("body mismatch: want %q, got %q", body, parts[1])
	}
}

// TestSanitizeHeader verifies that sanitizeHeader strips both CR and LF.
func TestSanitizeHeader(t *testing.T) {
	tests := []struct {
		input string
		want  string
	}{
		{"normal", "normal"},
		{"with\nnewline", "withnewline"},
		{"with\rcarriage", "withcarriage"},
		{"with\r\nboth", "withboth"},
		{"a\r\nBcc: evil@x.com", "aBcc: evil@x.com"},
	}
	for _, tt := range tests {
		got := sanitizeHeader(tt.input)
		if got != tt.want {
			t.Errorf("sanitizeHeader(%q) = %q, want %q", tt.input, got, tt.want)
		}
	}
}
