package mail

import (
	"net/mail"
	"strings"
	"testing"

	"github.com/mitlist-app/mitlist/internal/config"
)

func TestSendHTMLWithHeaders_SESGetsHeadersAndDisplayName(t *testing.T) {
	fake := &fakeSES{}
	s := newTestService(t, &config.Config{
		SESRegion:     "eu-central-1",
		MailFromEmail: "noreply@mitlist.me",
		MailFromName:  "mitlist",
	}, fake)

	headers := []Header{
		{Name: "List-Unsubscribe", Value: "<https://api.mitlist.me/api/v1/email/unsubscribe?token=abc>"},
		{Name: "List-Unsubscribe-Post", Value: "List-Unsubscribe=One-Click"},
		{Name: "X-Evil\r\nBcc", Value: "attacker@example.com\r\nSubject: pwned"},
	}
	if err := s.SendHTMLWithHeaders("user@example.com", "Tips", "<p>hi</p>", "hi", headers); err != nil {
		t.Fatalf("send: %v", err)
	}
	if got := *fake.last.FromEmailAddress; got != "mitlist <noreply@mitlist.me>" {
		t.Errorf("from = %q, want display name form", got)
	}
	got := fake.last.Content.Simple.Headers
	if len(got) != 3 {
		t.Fatalf("headers = %d, want 3", len(got))
	}
	if *got[0].Name != "List-Unsubscribe" || *got[1].Value != "List-Unsubscribe=One-Click" {
		t.Errorf("headers = %+v", got)
	}
	if strings.ContainsAny(*got[2].Name+*got[2].Value, "\r\n") {
		t.Errorf("CRLF survived sanitization: %q / %q", *got[2].Name, *got[2].Value)
	}
}

func TestBuildMultipartMessage_ExtraHeaders(t *testing.T) {
	raw := buildMultipartMessage("mitlist <noreply@mitlist.me>", "user@example.com", "Tips", "t", "<p>h</p>",
		Header{Name: "List-Unsubscribe", Value: "<https://example.test/u?token=abc>"},
		Header{Name: "Bcc\r\nX-Injected", Value: "x\r\nSubject: pwned"},
	)
	msg, err := mail.ReadMessage(strings.NewReader(string(raw)))
	if err != nil {
		t.Fatalf("message does not parse: %v\n%s", err, raw)
	}
	if got := msg.Header.Get("List-Unsubscribe"); got != "<https://example.test/u?token=abc>" {
		t.Errorf("List-Unsubscribe = %q", got)
	}
	if got := msg.Header.Get("From"); got != "mitlist <noreply@mitlist.me>" {
		t.Errorf("From = %q", got)
	}
	if msg.Header.Get("X-Injected") != "" || msg.Header.Get("Subject") != "Tips" {
		t.Errorf("header injection via extra headers succeeded:\n%s", raw)
	}
}

func TestFromHeader_FallsBackToBareAddress(t *testing.T) {
	s := New(&config.Config{MailFromEmail: "noreply@mitlist.me"}, nil)
	if got := s.fromHeader(); got != "noreply@mitlist.me" {
		t.Errorf("fromHeader with no name = %q", got)
	}
	s = New(&config.Config{MailFromEmail: "noreply@mitlist.me", MailFromName: `mit"list`}, nil)
	if got := s.fromHeader(); got != "mitlist <noreply@mitlist.me>" {
		t.Errorf("fromHeader strips quotes = %q", got)
	}
}
