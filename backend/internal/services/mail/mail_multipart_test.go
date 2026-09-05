package mail

import (
	"io"
	"mime"
	"mime/multipart"
	"net/mail"
	"strings"
	"testing"
)

// TestBuildMultipartMessage_HasTextAndHTMLParts parses the assembled message
// back with net/mail and mime/multipart: a client that cannot render HTML
// must find a text/plain part, and one that can must find text/html.
func TestBuildMultipartMessage_HasTextAndHTMLParts(t *testing.T) {
	raw := buildMultipartMessage("noreply@mitlist.me", "user@example.com", "Verify", "code is: ABC", "<p>ABC</p>")

	msg, err := mail.ReadMessage(strings.NewReader(string(raw)))
	if err != nil {
		t.Fatalf("message does not parse: %v\n%s", err, raw)
	}
	if got := msg.Header.Get("Subject"); got != "Verify" {
		t.Errorf("subject = %q", got)
	}
	mediaType, params, err := mime.ParseMediaType(msg.Header.Get("Content-Type"))
	if err != nil {
		t.Fatalf("content type: %v", err)
	}
	if mediaType != "multipart/alternative" {
		t.Fatalf("media type = %q, want multipart/alternative", mediaType)
	}

	parts := map[string]string{}
	mr := multipart.NewReader(msg.Body, params["boundary"])
	for {
		p, err := mr.NextPart()
		if err == io.EOF {
			break
		}
		if err != nil {
			t.Fatalf("next part: %v", err)
		}
		body, _ := io.ReadAll(p)
		ct, _, _ := mime.ParseMediaType(p.Header.Get("Content-Type"))
		parts[ct] = string(body)
	}
	if parts["text/plain"] != "code is: ABC" {
		t.Errorf("text part = %q", parts["text/plain"])
	}
	if parts["text/html"] != "<p>ABC</p>" {
		t.Errorf("html part = %q", parts["text/html"])
	}
}

// TestBuildMultipartMessage_SanitizesHeaders: the multipart builder must not
// reopen the header-injection hole buildMessage closed.
func TestBuildMultipartMessage_SanitizesHeaders(t *testing.T) {
	raw := string(buildMultipartMessage("noreply@mitlist.me", "user@example.com", "Hi\r\nBcc: victim@example.com", "t", "<p>h</p>"))
	headerEnd := strings.Index(raw, "\r\n\r\n")
	if headerEnd < 0 {
		t.Fatal("no header/body separator")
	}
	if hasBccHeader(raw[:headerEnd]) {
		t.Errorf("injected Bcc header survived:\n%s", raw[:headerEnd])
	}
}
