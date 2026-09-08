package config

import (
	"bytes"
	"encoding/base64"
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
			SendGridSMTPHost:             "smtp.sendgrid.net",
			SendGridSMTPUser:             "apikey",
			SESRegion:                    "eu-central-1",
			VapidPublicKey:               "BExamplePublicKey",
			VapidPrivateKey:              "ExamplePrivateKey",
			FirebaseProjectID:            "my-project",
			FirebaseServiceAccount:       `{"type":"service_account"}`,
			S3BucketName:                 "my-bucket",
			GoogleClientID:               "google-client-id.apps.googleusercontent.com",
			PasswordAuthEnabled:          true,
			SentryDSN:                    "https://abc@o123.ingest.sentry.io/456",
			FxRateAPIURL:                 "https://api.frankfurter.dev",
			PolarAccessToken:             "polar_at_test",
			PolarWebhookSecret:           "whsec_test",
			AppleIAPBundleID:             "dev.mohamad.mitlist",
			AppleIAPAppID:                1234567890,
			AppleIAPProductMonthly:       "dev.mohamad.mitlist.premium.monthly",
			AppleIAPProductYearly:        "dev.mohamad.mitlist.premium.yearly",
			GooglePlayPackageName:        "dev.mohamad.mitlist",
			GooglePlayServiceAccountJSON: `{"type":"service_account"}`,
			GooglePlaySubscriptionID:     "premium",
			GooglePlayProductMonthly:     "premium-monthly",
			GooglePlayProductYearly:      "premium-yearly",
			GooglePubSubAudience:         "https://api.mitlist.me/webhooks/google",
			GooglePubSubServiceAccount:   "pubsub@project.iam.gserviceaccount.com",
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

// The secret exactly as the Polar dashboard shows it must pass validation —
// in both shapes Polar has issued. The raw, non-base64 shape used to pass
// validation and then kill the process later, where standard-webhooks decoded
// it; production crash-looped on that on 2026-08-21 and the secret was parked,
// which left every webhook answered with 503.
func TestValidateAcceptsPolarWebhookSecretAsIssued(t *testing.T) {
	cfg := &Config{
		Environment:        "development",
		SecretKey:          "access-key-value",
		SessionSecretKey:   "refresh-key-value",
		PolarWebhookSecret: "whsec_Ab3dEfGh1jKlMnOpQrStUvWxYz0123456789abcdefg",
	}
	if err := cfg.Validate(); err != nil {
		t.Fatalf("expected a pre-2026-09-08 Polar secret to be accepted verbatim, got %v", err)
	}

	cfg.PolarWebhookSecret = "whsec_" + base64.StdEncoding.EncodeToString([]byte("a-32-byte-standard-webhooks-key!"))
	if err := cfg.Validate(); err != nil {
		t.Fatalf("expected a Standard Webhooks secret to be accepted, got %v", err)
	}

	// Unset stays valid: billing is opt-in, and a self-hosted instance without
	// Polar must still boot.
	cfg.PolarWebhookSecret = ""
	if err := cfg.Validate(); err != nil {
		t.Fatalf("expected an unset secret to be accepted, got %v", err)
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

func TestValidateAppCheckRequiresProjectAndAppAllowlist(t *testing.T) {
	tests := []struct {
		name          string
		projectNumber string
		allowedAppIDs string
		wantErr       bool
	}{
		{name: "disabled needs no Firebase config"},
		{name: "missing project number", allowedAppIDs: "1:123:android:abc", wantErr: true},
		{name: "missing app allowlist", projectNumber: "123", wantErr: true},
		{name: "fully configured", projectNumber: "123", allowedAppIDs: "1:123:android:abc,1:123:ios:def"},
	}
	for _, tc := range tests {
		t.Run(tc.name, func(t *testing.T) {
			cfg := &Config{
				Environment:                   "development",
				SecretKey:                     "access-secret",
				SessionSecretKey:              "refresh-secret",
				FirebaseAppCheckRequired:      tc.name != "disabled needs no Firebase config",
				FirebaseProjectNumber:         tc.projectNumber,
				FirebaseAppCheckAllowedAppIDs: tc.allowedAppIDs,
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

func TestValidateRejectsUnknownAppleIAPEnvironment(t *testing.T) {
	cfg := &Config{Environment: "development", AppleIAPEnvironment: "staging"}
	if err := cfg.Validate(); err == nil {
		t.Fatal("expected invalid Apple IAP environment to be rejected")
	}
}

func TestValidateRequiresAppleAppIDOutsideSandbox(t *testing.T) {
	cfg := &Config{
		Environment:            "development",
		AppleIAPEnvironment:    "Production",
		AppleIAPBundleID:       "me.mitlist",
		AppleIAPProductMonthly: "me.mitlist.premium.monthly",
		AppleIAPProductYearly:  "me.mitlist.premium.yearly",
	}
	if err := cfg.Validate(); err == nil {
		t.Fatal("expected production Apple IAP without an app Apple ID to be rejected")
	}
	cfg.AppleIAPEnvironment = "Sandbox"
	if err := cfg.Validate(); err != nil {
		t.Fatalf("sandbox Apple IAP should not require an app Apple ID: %v", err)
	}
}
