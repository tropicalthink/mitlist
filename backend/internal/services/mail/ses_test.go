package mail

import (
	"context"
	"errors"
	"testing"

	"github.com/aws/aws-sdk-go-v2/service/sesv2"

	"github.com/mitlist-app/mitlist/internal/config"
	"github.com/mitlist-app/mitlist/pkg/logger"
)

// fakeSES records the last SendEmail input and returns a canned error.
type fakeSES struct {
	last  *sesv2.SendEmailInput
	calls int
	err   error
}

func (f *fakeSES) SendEmail(_ context.Context, in *sesv2.SendEmailInput, _ ...func(*sesv2.Options)) (*sesv2.SendEmailOutput, error) {
	f.calls++
	f.last = in
	return &sesv2.SendEmailOutput{}, f.err
}

// newTestService builds a Service with the SES client already injected, so no
// test reaches AWS or the credential chain.
func newTestService(t *testing.T, cfg *config.Config, client sesAPI) *Service {
	t.Helper()
	s := New(cfg, logger.New("test"))
	s.sesState.client = client
	return s
}

func TestSESEnabled_RegionIsTheSwitch(t *testing.T) {
	// AWS credentials alone must not opt a self-host into SES: those may be
	// set only for S3-compatible file storage.
	off := New(&config.Config{AWSAccessKeyID: "AKIA", AWSSecretAccessKey: "secret"}, logger.New("test"))
	if off.sesEnabled() {
		t.Error("SES enabled with no AWS_SES_REGION set")
	}
	on := New(&config.Config{SESRegion: "eu-central-1"}, logger.New("test"))
	if !on.sesEnabled() {
		t.Error("SES disabled despite AWS_SES_REGION being set")
	}
}

func TestSendHTML_UsesSESWithBothBodies(t *testing.T) {
	fake := &fakeSES{}
	s := newTestService(t, &config.Config{
		SESRegion:     "eu-central-1",
		MailFromEmail: "noreply@mitlist.me",
	}, fake)

	if err := s.SendHTML("user@example.com", "Verify", "<p>ABC</p>", "code is: ABC"); err != nil {
		t.Fatalf("SendHTML: %v", err)
	}
	if fake.calls != 1 {
		t.Fatalf("SendEmail called %d times, want 1", fake.calls)
	}
	msg := fake.last.Content.Simple
	if got := *fake.last.FromEmailAddress; got != "noreply@mitlist.me" {
		t.Errorf("from = %q", got)
	}
	if got := fake.last.Destination.ToAddresses; len(got) != 1 || got[0] != "user@example.com" {
		t.Errorf("to = %v", got)
	}
	if got := *msg.Subject.Data; got != "Verify" {
		t.Errorf("subject = %q", got)
	}
	if got := *msg.Body.Html.Data; got != "<p>ABC</p>" {
		t.Errorf("html = %q", got)
	}
	if got := *msg.Body.Text.Data; got != "code is: ABC" {
		t.Errorf("text = %q", got)
	}
	if fake.last.ConfigurationSetName != nil {
		t.Errorf("configuration set sent when none configured: %q", *fake.last.ConfigurationSetName)
	}
}

func TestSend_PlainTextGetsNoHTMLPart(t *testing.T) {
	fake := &fakeSES{}
	s := newTestService(t, &config.Config{SESRegion: "eu-central-1", MailFromEmail: "noreply@mitlist.me"}, fake)

	if err := s.Send("user@example.com", "Subject", "plain body", false); err != nil {
		t.Fatalf("Send: %v", err)
	}
	body := fake.last.Content.Simple.Body
	if body.Html != nil {
		t.Errorf("html part present on a plain-text send: %q", *body.Html.Data)
	}
	if body.Text == nil || *body.Text.Data != "plain body" {
		t.Errorf("text part = %+v", body.Text)
	}
}

func TestSend_HTMLGetsNoTextPart(t *testing.T) {
	fake := &fakeSES{}
	s := newTestService(t, &config.Config{SESRegion: "eu-central-1", MailFromEmail: "noreply@mitlist.me"}, fake)

	if err := s.Send("user@example.com", "Subject", "<p>body</p>", true); err != nil {
		t.Fatalf("Send: %v", err)
	}
	body := fake.last.Content.Simple.Body
	if body.Text != nil {
		t.Errorf("text part present on an HTML send: %q", *body.Text.Data)
	}
	if body.Html == nil || *body.Html.Data != "<p>body</p>" {
		t.Errorf("html part = %+v", body.Html)
	}
}

func TestSendViaSES_PassesConfigurationSet(t *testing.T) {
	fake := &fakeSES{}
	s := newTestService(t, &config.Config{
		SESRegion:           "eu-central-1",
		SESConfigurationSet: "mitlist-transactional",
		MailFromEmail:       "noreply@mitlist.me",
	}, fake)

	if err := s.SendHTML("user@example.com", "Verify", "<p>h</p>", "t"); err != nil {
		t.Fatalf("SendHTML: %v", err)
	}
	if fake.last.ConfigurationSetName == nil || *fake.last.ConfigurationSetName != "mitlist-transactional" {
		t.Errorf("configuration set = %v", fake.last.ConfigurationSetName)
	}
}

// TestSendViaSES_SanitizesHeaders: SES takes the subject and addresses as
// fields rather than raw headers, but a CRLF in either would still be a
// header-injection attempt worth stripping before it leaves the process.
func TestSendViaSES_SanitizesHeaders(t *testing.T) {
	fake := &fakeSES{}
	s := newTestService(t, &config.Config{SESRegion: "eu-central-1", MailFromEmail: "noreply@mitlist.me"}, fake)

	err := s.sendViaSES("noreply@mitlist.me", "user@example.com\r\nBcc: attacker@evil.com", "Hi\r\nBcc: attacker@evil.com", "<p>h</p>", "t")
	if err != nil {
		t.Fatalf("sendViaSES: %v", err)
	}
	if got := fake.last.Destination.ToAddresses[0]; got != "user@example.comBcc: attacker@evil.com" {
		t.Errorf("to not sanitized: %q", got)
	}
	if got := *fake.last.Content.Simple.Subject.Data; got != "HiBcc: attacker@evil.com" {
		t.Errorf("subject not sanitized: %q", got)
	}
}

func TestSendViaSES_RejectsEmptyBody(t *testing.T) {
	fake := &fakeSES{}
	s := newTestService(t, &config.Config{SESRegion: "eu-central-1"}, fake)

	if err := s.sendViaSES("noreply@mitlist.me", "user@example.com", "Subject", "", ""); err == nil {
		t.Error("expected an error for a message with neither body")
	}
	if fake.calls != 0 {
		t.Error("empty message was sent to SES anyway")
	}
}

// TestSendHTML_FallsBackToSMTPWhenSESFails asserts the fallback still runs: SES
// rejecting a message must not silently swallow a verification email. With no
// SMTP credentials configured the fallback fails too, and the caller must see
// that failure rather than a nil error.
func TestSendHTML_FallsBackToSMTPWhenSESFails(t *testing.T) {
	fake := &fakeSES{err: errors.New("ses is down")}
	s := newTestService(t, &config.Config{SESRegion: "eu-central-1", MailFromEmail: "noreply@mitlist.me"}, fake)

	err := s.SendHTML("user@example.com", "Verify", "<p>h</p>", "t")
	if err == nil {
		t.Fatal("expected an error once both SES and SMTP fail")
	}
	if fake.calls != 1 {
		t.Errorf("SES attempted %d times, want 1", fake.calls)
	}
}
