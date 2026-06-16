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
	RedisURL         string `env:"REDIS_URL" required:"true" default:"redis://localhost:6379"`
	GeminiAPIKey string `env:"GEMINI_API_KEY"`

	// CrofAI (OpenAI-compatible)
	CrofAIAPIKey  string `env:"CROFAI_API_KEY"`
	CrofAIBaseURL string `env:"CROFAI_BASE_URL" default:"https://crof.ai/v1"`

	// Database & Cache
	RedisPassword string `env:"REDIS_PASSWORD" default:""`

	// Application
	Environment              string `env:"ENVIRONMENT" default:"development"`
	FrontendURL              string `env:"FRONTEND_URL" default:"http://localhost:5173"`
	Port                     string `env:"PORT" default:"8000"`
	APIPrefix                string `env:"API_PREFIX" default:"/api"`
	AccessTokenExpireMinutes int    `env:"ACCESS_TOKEN_EXPIRE_MINUTES" default:"60"`
	RunMigrationsOnStartup   bool   `env:"RUN_MIGRATIONS_ON_STARTUP" default:"true"`
	WarmCacheOnStartup       bool   `env:"WARM_CACHE_ON_STARTUP" default:"false"`
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

	// External APIs
	OpenRouterAPIKey  string `env:"OPENROUTER_API_KEY"`
	OpenRouterBaseURL string `env:"OPENROUTER_BASE_URL" default:"https://openrouter.ai/api/v1"`

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

	// Sentry
	SentryDSN string `env:"SENTRY_DSN"`

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
	MaxFileSizeBytes       int `env:"MAX_FILE_SIZE_BYTES" default:"52428800"`
	MaxStoragePerGroupGB   int `env:"MAX_STORAGE_PER_GROUP_GB" default:"10"`

	// Feature Flags
	EnableVirusScanning   bool   `env:"ENABLE_VIRUS_SCANNING" default:"false"`
	VirusScannerEndpoint  string `env:"VIRUS_SCANNER_ENDPOINT"`
	EnableContentScanning bool   `env:"ENABLE_CONTENT_SCANNING" default:"true"`
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

// MaskSecrets returns a shallow copy of the config with sensitive values replaced.
func (c Config) MaskSecrets() Config {
	masked := c
	masked.DatabaseURL = mask(masked.DatabaseURL)
	masked.SecretKey = mask(masked.SecretKey)
	masked.SessionSecretKey = mask(masked.SessionSecretKey)
	masked.GeminiAPIKey = mask(masked.GeminiAPIKey)
	masked.CrofAIAPIKey = mask(masked.CrofAIAPIKey)
	masked.RedisPassword = mask(masked.RedisPassword)
	masked.GoogleClientSecret = mask(masked.GoogleClientSecret)
	masked.ApplePrivateKey = mask(masked.ApplePrivateKey)
	masked.OpenRouterAPIKey = mask(masked.OpenRouterAPIKey)
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
