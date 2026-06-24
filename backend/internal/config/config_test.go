package config

import (
	"bytes"
	"strings"
	"testing"

	"github.com/rs/zerolog"
	"github.com/rs/zerolog/log"
)

// captureLog runs fn while redirecting the global zerolog logger to a buffer
// and returns everything it wrote. It restores the original logger afterward.
func captureLog(fn func()) string {
	var buf bytes.Buffer
	orig := log.Logger
	log.Logger = zerolog.New(&buf)
	defer func() { log.Logger = orig }()
	fn()
	return buf.String()
}

// TestLogIntegrationStatus verifies that LogIntegrationStatus never panics
// regardless of which fields are populated, and that email enablement is gated
// on credentials rather than the defaulted SMTP host fields.
func TestLogIntegrationStatus(t *testing.T) {
	t.Run("fully unconfigured", func(t *testing.T) {
		cfg := &Config{}
		cfg.LogIntegrationStatus() // must not panic
	})

	t.Run("fully configured", func(t *testing.T) {
		cfg := &Config{
			SendGridSMTPHost:       "smtp.sendgrid.net",
			SendGridSMTPUser:       "apikey",
			ResendAPIKey:           "re_test_key",
			VapidPublicKey:         "BExamplePublicKey",
			VapidPrivateKey:        "ExamplePrivateKey",
			FirebaseProjectID:      "my-project",
			FirebaseServiceAccount: `{"type":"service_account"}`,
			OpenRouterAPIKey:       "sk-or-test",
			S3BucketName:           "my-bucket",
			GoogleClientID:         "google-client-id.apps.googleusercontent.com",
			SentryDSN:              "https://abc@o123.ingest.sentry.io/456",
			FxRateAPIURL:           "https://api.frankfurter.dev",
		}
		out := captureLog(cfg.LogIntegrationStatus)
		if !strings.Contains(out, `"email":true`) {
			t.Errorf("expected email enabled when credentials set; got: %s", out)
		}
		if strings.Contains(out, "disabled_integrations") {
			t.Errorf("expected no disabled integrations for fully configured; got: %s", out)
		}
	})

	t.Run("partial: only VAPID set", func(t *testing.T) {
		cfg := &Config{
			VapidPublicKey:  "BExamplePublicKey",
			VapidPrivateKey: "ExamplePrivateKey",
		}
		cfg.LogIntegrationStatus() // must not panic; several integrations in disabled list
	})

	// Regression guard for the defaulted-host bug: SendGridSMTPHost and
	// BrevoSMTPHost carry non-empty struct defaults, so gating email on the
	// hosts would always report email as enabled even with no credentials.
	// Email must be treated as DISABLED here.
	t.Run("default SMTP hosts but no credentials -> email disabled", func(t *testing.T) {
		cfg := &Config{
			SendGridSMTPHost: "smtp.sendgrid.net",         // default value, no creds
			BrevoSMTPHost:    "smtp-relay.sendinblue.com", // default value, no creds
		}
		out := captureLog(cfg.LogIntegrationStatus)
		if !strings.Contains(out, `"email":false`) {
			t.Errorf("expected email DISABLED when only default hosts present; got: %s", out)
		}
		if !strings.Contains(out, "disabled_integrations") {
			t.Errorf("expected disabled_integrations warning; got: %s", out)
		}
	})
}
