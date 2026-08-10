package config

import (
	"bytes"
	"reflect"
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
			S3BucketName:           "my-bucket",
			GoogleClientID:         "google-client-id.apps.googleusercontent.com",
			SentryDSN:              "https://abc@o123.ingest.sentry.io/456",
			FxRateAPIURL:           "https://api.frankfurter.dev",
			PolarAccessToken:       "polar_at_test",
			PolarWebhookSecret:     "whsec_test",
		}
		out := captureLog(cfg.LogIntegrationStatus)
		if !strings.Contains(out, `"email":true`) {
			t.Errorf("expected email enabled when credentials set; got: %s", out)
		}
		if strings.Contains(out, "disabled_integrations") {
			t.Errorf("expected no disabled integrations for fully configured; got: %s", out)
		}
	})

	t.Run("error_tracing reported when DSN and sample rate set", func(t *testing.T) {
		cfg := &Config{SentryDSN: "https://abc@example.com/1", SentryTracesSampleRate: 0.1}
		out := captureLog(cfg.LogIntegrationStatus)
		if !strings.Contains(out, `"error_tracing":true`) {
			t.Errorf("expected error_tracing enabled; got: %s", out)
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

// TestSetFieldFloat64 guards the float64 support added for SENTRY_TRACES_SAMPLE_RATE.
func TestSetFieldFloat64(t *testing.T) {
	tests := []struct {
		name    string
		raw     string
		def     string
		want    float64
		wantErr bool
	}{
		{name: "parses value", raw: "0.25", want: 0.25},
		{name: "empty falls back to default", raw: "", def: "0.1", want: 0.1},
		{name: "empty and no default is zero", raw: "", want: 0},
		{name: "invalid errors", raw: "notafloat", wantErr: true},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			var f float64
			tag := reflect.StructTag(`default:"` + tc.def + `"`)
			err := setField(reflect.ValueOf(&f).Elem(), tag, tc.raw)
			if tc.wantErr {
				if err == nil {
					t.Fatalf("expected error, got nil")
				}
				return
			}
			if err != nil {
				t.Fatalf("unexpected error: %v", err)
			}
			if f != tc.want {
				t.Errorf("got %v, want %v", f, tc.want)
			}
		})
	}
}

func TestValidateRejectsSharedTokenSigningKey(t *testing.T) {
	cfg := &Config{
		Environment:      "development",
		SecretKey:        "same-key-value",
		SessionSecretKey: "same-key-value",
	}
	if err := cfg.Validate(); err == nil {
		t.Fatal("expected identical access and refresh signing keys to be rejected")
	}
}

func TestValidateProductionFrontendURL(t *testing.T) {
	tests := []struct {
		name        string
		frontendURL string
		wantErr     bool
	}{
		{name: "public https origin", frontendURL: "https://app.mitlist.me"},
		{name: "missing scheme", frontendURL: "app.mitlist.me", wantErr: true},
		{name: "default localhost", frontendURL: "http://localhost:5173", wantErr: true},
		{name: "loopback ip", frontendURL: "http://127.0.0.1:5173", wantErr: true},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cfg := &Config{
				Environment:      "production",
				FrontendURL:      tc.frontendURL,
				SecretKey:        "production-access-secret",
				SessionSecretKey: "production-refresh-secret",
			}
			err := cfg.Validate()
			if tc.wantErr && err == nil {
				t.Fatal("expected validation error")
			}
			if !tc.wantErr && err != nil {
				t.Fatalf("unexpected validation error: %v", err)
			}
		})
	}
}
