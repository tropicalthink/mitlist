package config

import (
	"fmt"
	"os"
	"reflect"
	"strconv"
	"strings"

	"github.com/joho/godotenv"
	"github.com/rs/zerolog/log"
)

// Config holds all application configuration loaded from environment variables.
// Values are populated from a .env file (if present) and the process environment.
type Config struct {
	// Required
	DatabaseURL      string `env:"DATABASE_URL" required:"true"`
	SecretKey        string `env:"SECRET_KEY" required:"true"`
	SessionSecretKey string `env:"SESSION_SECRET_KEY" required:"true"`

	// Application
	Environment              string `env:"ENVIRONMENT" default:"development"`
	FrontendURL              string `env:"FRONTEND_URL" default:"http://localhost:5173"`
	Port                     string `env:"PORT" default:"8000"`
	APIPrefix                string `env:"API_PREFIX" default:"/api"`
	AccessTokenExpireMinutes int    `env:"ACCESS_TOKEN_EXPIRE_MINUTES" default:"15"`
	RunMigrationsOnStartup   bool   `env:"RUN_MIGRATIONS_ON_STARTUP" default:"true"`
	LogLevel                 string `env:"LOG_LEVEL" default:"WARNING"`

	// OAuth — Google
	GoogleClientID     string `env:"GOOGLE_CLIENT_ID"`
	GoogleClientSecret string `env:"GOOGLE_CLIENT_SECRET"`
	GoogleRedirectURI  string `env:"GOOGLE_REDIRECT_URI"`

	// OAuth — Apple
	AppleClientID    string `env:"APPLE_CLIENT_ID"`
	AppleTeamID      string `env:"APPLE_TEAM_ID"`
	AppleKeyID       string `env:"APPLE_KEY_ID"`
	ApplePrivateKey  string `env:"APPLE_PRIVATE_KEY"`
	AppleRedirectURI string `env:"APPLE_REDIRECT_URI" default:"https://mitlistbe.mohamad.dev/api/v1/auth/apple/callback"`

	// OAuth — Allowlist
	OAuthRedirectAllowlist string `env:"OAUTH_REDIRECT_ALLOWLIST"`

	// Web Push
	VapidPrivateKey string `env:"VAPID_PRIVATE_KEY"`
	VapidPublicKey  string `env:"VAPID_PUBLIC_KEY"`
	VapidSubject    string `env:"VAPID_SUBJECT" default:"mailto:noreply@mitlist.me"`

	// Firebase / FCM (mobile push)
	// Set FIREBASE_PROJECT_ID and FIREBASE_SERVICE_ACCOUNT_JSON (raw JSON string)
	// to enable FCM push to Android and iOS devices.
	FirebaseProjectID      string `env:"FIREBASE_PROJECT_ID"`
	FirebaseServiceAccount string `env:"FIREBASE_SERVICE_ACCOUNT_JSON"`

	// Email
	ResendAPIKey    string `env:"RESEND_API_KEY"`
	ResendFromEmail string `env:"RESEND_FROM_EMAIL"`

	// Email SMTP
	SendGridSMTPHost string `env:"SENDGRID_SMTP_HOST" default:"smtp.sendgrid.net"`
	SendGridSMTPPort int    `env:"SENDGRID_SMTP_PORT" default:"587"`
	SendGridSMTPUser string `env:"SENDGRID_SMTP_USER"`
	SendGridSMTPPass string `env:"SENDGRID_SMTP_PASS"`
	BrevoSMTPHost    string `env:"BREVO_SMTP_HOST" default:"smtp-relay.sendinblue.com"`
	BrevoSMTPPort    int    `env:"BREVO_SMTP_PORT" default:"587"`
	BrevoSMTPUser    string `env:"BREVO_SMTP_USER"`
	BrevoSMTPPass    string `env:"BREVO_SMTP_PASS"`
	MailFromEmail    string `env:"MAIL_FROM_EMAIL" default:"noreply@mitlist.me"`

	// Sentry / GlitchTip error tracking
	SentryDSN              string  `env:"SENTRY_DSN"`
	SentryRelease          string  `env:"SENTRY_RELEASE"`
	SentryServerName       string  `env:"SENTRY_SERVER_NAME"`
	SentryTracesSampleRate float64 `env:"SENTRY_TRACES_SAMPLE_RATE" default:"0"`
	SentryDebug            bool    `env:"SENTRY_DEBUG" default:"false"`

	// File Storage
	AWSAccessKeyID     string `env:"AWS_ACCESS_KEY_ID"`
	AWSSecretAccessKey string `env:"AWS_SECRET_ACCESS_KEY"`
	AWSRegion          string `env:"AWS_REGION" default:"us-east-1"`
	S3BucketName       string `env:"S3_BUCKET_NAME"`
	S3EndpointURL      string `env:"S3_ENDPOINT_URL"`

	// Network
	TrustedProxies string `env:"TRUSTED_PROXIES" default:""`

	// Limits
	MaxActiveListsPerGroup int `env:"MAX_ACTIVE_LISTS_PER_GROUP" default:"100"`
	MaxItemsPerList        int `env:"MAX_ITEMS_PER_LIST" default:"1000"`
	MaxFileSizeMB          int `env:"MAX_FILE_SIZE_MB" default:"10"`
	MaxFileSizeBytes       int `env:"MAX_FILE_SIZE_BYTES" default:"10485760"`
	MaxStoragePerGroupGB   int `env:"MAX_STORAGE_PER_GROUP_GB" default:"1"`

	// Feature Flags
	EnableVirusScanning   bool   `env:"ENABLE_VIRUS_SCANNING" default:"false"`
	VirusScannerEndpoint  string `env:"VIRUS_SCANNER_ENDPOINT"`
	EnableContentScanning bool   `env:"ENABLE_CONTENT_SCANNING" default:"true"`

	// FX Rate (opt-in). Set FX_RATE_API_URL to enable live exchange-rate suggestions.
	// Recommended value: https://api.frankfurter.dev (free, no key required).
	// Leave empty to keep the feature disabled (default — users enter rates manually).
	// If your provider requires authentication, set FX_RATE_API_KEY as well.
	FxRateAPIURL string `env:"FX_RATE_API_URL"`
	FxRateAPIKey string `env:"FX_RATE_API_KEY"`
}

// Load reads the .env file (if it exists) and populates a Config from the environment.
// It applies defaults and validates that all required variables are present.
func Load() (*Config, error) {
	// Attempt to load .env file; ignore errors if it doesn't exist.
	_ = godotenv.Load()

	cfg := &Config{}
	v := reflect.ValueOf(cfg).Elem()
	t := v.Type()

	var missing []string

	for i := 0; i < t.NumField(); i++ {
		field := t.Field(i)
		envKey := field.Tag.Get("env")
		if envKey == "" {
			continue
		}

		raw := os.Getenv(envKey)
		if err := setField(v.Field(i), field.Tag, raw); err != nil {
			return nil, fmt.Errorf("failed to parse %s: %w", envKey, err)
		}

		if field.Tag.Get("required") == "true" && raw == "" && field.Tag.Get("default") == "" {
			missing = append(missing, envKey)
		}
	}

	if len(missing) > 0 {
		return nil, fmt.Errorf("missing required environment variables: %s", strings.Join(missing, ", "))
	}

	if err := cfg.Validate(); err != nil {
		return nil, err
	}

	// Additional validations.
	if len(cfg.SecretKey) < 32 {
		return nil, fmt.Errorf("SECRET_KEY must be at least 32 characters")
	}
	if len(cfg.SessionSecretKey) < 32 {
		return nil, fmt.Errorf("SESSION_SECRET_KEY must be at least 32 characters")
	}

	return cfg, nil
}

// LogMasked logs the full configuration using zerolog with all secrets obscured.
func (c *Config) LogMasked() {
	masked := c.MaskSecrets()
	log.Info().Interface("config", masked).Msg("configuration loaded")
}

// LogIntegrationStatus logs which optional integrations are configured, so an
// operator can see at a glance what works on a fresh deployment. It never fails;
// unconfigured integrations are expected and merely reported.
func (c *Config) LogIntegrationStatus() {
	// Gate on credential fields (which have no struct default) rather than the
	// SMTP host fields, which default to non-empty values and would otherwise
	// mask a fresh self-host that has not configured any email credentials.
	emailOn := c.ResendAPIKey != "" || c.SendGridSMTPUser != "" || c.BrevoSMTPUser != ""
	webPushOn := c.VapidPublicKey != "" && c.VapidPrivateKey != ""
	mobilePushOn := c.FirebaseProjectID != "" && c.FirebaseServiceAccount != ""
	storageOn := c.S3BucketName != ""
	oauthOn := c.GoogleClientID != "" || c.AppleClientID != ""
	errorReportingOn := c.SentryDSN != ""
	errorTracingOn := errorReportingOn && c.SentryTracesSampleRate > 0
	fxOn := c.FxRateAPIURL != ""

	log.Info().
		Bool("email", emailOn).
		Bool("web_push", webPushOn).
		Bool("mobile_push", mobilePushOn).
		Bool("file_storage", storageOn).
		Bool("oauth", oauthOn).
		Bool("error_reporting", errorReportingOn).
		Bool("error_tracing", errorTracingOn).
		Bool("fx_rates", fxOn).
		Msg("integration status")

	var disabled []string
	if !emailOn {
		disabled = append(disabled, "email (set RESEND_API_KEY, or SENDGRID_SMTP_USER/PASS, or BREVO_SMTP_USER/PASS)")
	}
	if !webPushOn {
		disabled = append(disabled, "web_push (set VAPID_PUBLIC_KEY and VAPID_PRIVATE_KEY)")
	}
	if !storageOn {
		disabled = append(disabled, "file_storage (set S3_BUCKET_NAME and AWS_* credentials)")
	}
	if len(disabled) > 0 {
		log.Warn().Strs("disabled_integrations", disabled).
			Msg("some optional integrations are disabled; features depending on them will not work")
	}
}

// MaskSecrets returns a shallow copy of the config with sensitive values replaced.
func (c Config) MaskSecrets() Config {
	masked := c
	masked.DatabaseURL = mask(masked.DatabaseURL)
	masked.SecretKey = mask(masked.SecretKey)
	masked.SessionSecretKey = mask(masked.SessionSecretKey)
	masked.GoogleClientSecret = mask(masked.GoogleClientSecret)
	masked.ApplePrivateKey = mask(masked.ApplePrivateKey)
	masked.VapidPrivateKey = mask(masked.VapidPrivateKey)
	masked.FirebaseServiceAccount = mask(masked.FirebaseServiceAccount)
	masked.ResendAPIKey = mask(masked.ResendAPIKey)
	masked.SendGridSMTPPass = mask(masked.SendGridSMTPPass)
	masked.BrevoSMTPPass = mask(masked.BrevoSMTPPass)
	masked.SentryDSN = mask(masked.SentryDSN)
	masked.AWSSecretAccessKey = mask(masked.AWSSecretAccessKey)
	return masked
}

func (c *Config) Validate() error {
	if c.Port != "" {
		if _, err := strconv.Atoi(c.Port); err != nil {
			return fmt.Errorf("invalid PORT: %w", err)
		}
	}
	validEnvs := map[string]bool{"development": true, "staging": true, "production": true}
	if !validEnvs[c.Environment] {
		return fmt.Errorf("invalid ENVIRONMENT: must be development, staging, or production")
	}
	if c.Environment == "production" && (c.SecretKey == "dev-only-insecure-key-do-not-use-in-prod" || c.SessionSecretKey == "dev-only-insecure-key-do-not-use-in-prod") {
		return fmt.Errorf("refusing to start in production with default dev secret keys — set SECRET_KEY and SESSION_SECRET_KEY in environment")
	}
	return nil
}

func setField(field reflect.Value, tag reflect.StructTag, raw string) error {
	defaultVal := tag.Get("default")

	val := raw
	if val == "" {
		val = defaultVal
	}

	switch field.Kind() {
	case reflect.String:
		field.SetString(val)
	case reflect.Int:
		if val == "" {
			field.SetInt(0)
			return nil
		}
		i, err := strconv.Atoi(val)
		if err != nil {
			return fmt.Errorf("invalid integer value %q: %w", val, err)
		}
		field.SetInt(int64(i))
	case reflect.Bool:
		if val == "" {
			field.SetBool(false)
			return nil
		}
		b, err := strconv.ParseBool(val)
		if err != nil {
			return fmt.Errorf("invalid boolean value %q: %w", val, err)
		}
		field.SetBool(b)
	case reflect.Float64:
		if val == "" {
			field.SetFloat(0)
			return nil
		}
		f, err := strconv.ParseFloat(val, 64)
		if err != nil {
			return fmt.Errorf("invalid float value %q: %w", val, err)
		}
		field.SetFloat(f)
	default:
		return fmt.Errorf("unsupported kind %s", field.Kind())
	}
	return nil
}

func mask(s string) string {
	if s == "" {
		return ""
	}
	return "***"
}
