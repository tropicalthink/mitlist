package config

import "testing"

// TestLogIntegrationStatus verifies that LogIntegrationStatus never panics
// regardless of which fields are populated.
func TestLogIntegrationStatus(t *testing.T) {
	t.Run("fully unconfigured", func(t *testing.T) {
		cfg := &Config{}
		cfg.LogIntegrationStatus() // must not panic
	})

	t.Run("fully configured", func(t *testing.T) {
		cfg := &Config{
			SendGridSMTPHost:       "smtp.sendgrid.net",
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
		cfg.LogIntegrationStatus() // must not panic; disabled slice should be empty
	})

	t.Run("partial: only VAPID set", func(t *testing.T) {
		cfg := &Config{
			VapidPublicKey:  "BExamplePublicKey",
			VapidPrivateKey: "ExamplePrivateKey",
		}
		cfg.LogIntegrationStatus() // must not panic; several integrations in disabled list
	})
}
