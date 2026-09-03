package config

import (
	"fmt"
	"net"
	"net/url"
	"os"
	"reflect"
	"strconv"
	"strings"

	"github.com/joho/godotenv"
	"github.com/rs/zerolog/log"
	standardwebhooks "github.com/standard-webhooks/standard-webhooks/libraries/go"
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
	TokenIssuer              string `env:"TOKEN_ISSUER" default:"mitlist"`
	TokenAudience            string `env:"TOKEN_AUDIENCE" default:"mitlist-api"`
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

	// Email + password sign-in. The hosted service signs people in with
	// Google or Apple only; a self-hosted instance usually has neither, so
	// this is the door it needs. Off by default because turning it on
	// exposes register, login, password reset and change-password on the
	// public API. Clients read the flag from GET /oauth/providers.
	PasswordAuthEnabled bool `env:"PASSWORD_AUTH_ENABLED" default:"false"`

	// Guest accounts: a one-tap "continue without signing up" session. Off by
	// default because an unauthenticated POST that mints working accounts is
	// the easiest thing on the API to abuse, and the hosted service no longer
	// offers it. Existing guests keep refreshing and upgrading either way;
	// only the creation of new ones is gated. Clients read the flag from
	// GET /oauth/providers and hide the door when it is off.
	GuestAuthEnabled bool `env:"GUEST_AUTH_ENABLED" default:"false"`

	// Web Push
	VapidPrivateKey string `env:"VAPID_PRIVATE_KEY"`
	VapidPublicKey  string `env:"VAPID_PUBLIC_KEY"`
	VapidSubject    string `env:"VAPID_SUBJECT" default:"mailto:noreply@mitlist.me"`

	// Firebase / FCM (mobile push)
	// Set FIREBASE_PROJECT_ID and FIREBASE_SERVICE_ACCOUNT_JSON (raw JSON string)
	// to enable FCM push to Android and iOS devices.
	FirebaseProjectID string `env:"FIREBASE_PROJECT_ID"`
	// App Check JWTs use the numeric Firebase project number for issuer and
	// audience validation. It is separate from FirebaseProjectID, which is
	// sufficient for FCM but not for verifying App Check tokens.
	FirebaseProjectNumber         string `env:"FIREBASE_PROJECT_NUMBER"`
	FirebaseAppCheckRequired      bool   `env:"FIREBASE_APP_CHECK_REQUIRED" default:"false"`
	FirebaseAppCheckAllowedAppIDs string `env:"FIREBASE_APP_CHECK_ALLOWED_APP_IDS"`
	FirebaseServiceAccount        string `env:"FIREBASE_SERVICE_ACCOUNT_JSON"`

	// Cloudflare Turnstile guards guest creation from the web, where App
	// Check's attestation providers (Play Integrity, App Attest) do not apply.
	// Web builds no longer ship an App Check provider at all; mobile still does,
	// so the two run side by side rather than one replacing the other.
	TurnstileSecretKey string `env:"TURNSTILE_SECRET_KEY"`

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

	// Polar (household premium billing, opt-in). Leave POLAR_ACCESS_TOKEN empty
	// to keep billing disabled — households then grow without limit, which is
	// the correct behaviour for a self-hosted instance.
	PolarAccessToken      string `env:"POLAR_ACCESS_TOKEN"`
	PolarWebhookSecret    string `env:"POLAR_WEBHOOK_SECRET"`
	PolarProductIDMonthly string `env:"POLAR_PRODUCT_ID_MONTHLY"`
	PolarProductIDYearly  string `env:"POLAR_PRODUCT_ID_YEARLY"`
	// PolarBaseURL points at the sandbox (https://sandbox-api.polar.sh) when
	// testing. Defaults to production.
	PolarBaseURL string `env:"POLAR_BASE_URL" default:"https://api.polar.sh"`
	// PolarDefaultDiscountID auto-applies a discount to every new checkout —
	// a launch promo, for instance. Customers can still enter their own code.
	PolarDefaultDiscountID string `env:"POLAR_DEFAULT_DISCOUNT_ID"`
	// CheckoutSuccessURL is where Polar returns the customer after paying.
	CheckoutSuccessURL string `env:"CHECKOUT_SUCCESS_URL" default:"https://mitlist.me/billing/success"`

	// FreeMemberLimit is the largest household size that stays free. Only
	// enforced when billing is configured.
	FreeMemberLimit int `env:"FREE_MEMBER_LIMIT" default:"4"`

	// Apple In-App Purchase (opt-in, mobile only). Signed StoreKit transactions
	// and notifications are verified locally and only require the bundle id.
	// App Store Server API credentials are intentionally absent: this code does
	// not call that API, so accepting an unused private key would be misleading.
	AppleIAPBundleID    string `env:"APPLE_IAP_BUNDLE_ID"`
	AppleIAPEnvironment string `env:"APPLE_IAP_ENVIRONMENT" default:"Production"`
	// AppleIAPAppID is the numeric App Store Connect Apple ID. Apple includes it
	// in production notifications, where it is checked alongside the bundle id.
	AppleIAPAppID int `env:"APPLE_IAP_APP_ID"`
	// AppleIAPProductMonthly and AppleIAPProductYearly map an App Store product
	// id back to a billing interval, since StoreKit reports the product but not
	// the plan cadence in a form we key on.
	AppleIAPProductMonthly string `env:"APPLE_IAP_PRODUCT_MONTHLY"`
	AppleIAPProductYearly  string `env:"APPLE_IAP_PRODUCT_YEARLY"`

	// Google Play In-App Purchase (opt-in, mobile only). Leave
	// GOOGLE_PLAY_SERVICE_ACCOUNT_JSON empty to keep Google IAP disabled. The
	// service account verifies purchase tokens via the Play Developer API.
	GooglePlayPackageName        string `env:"GOOGLE_PLAY_PACKAGE_NAME"`
	GooglePlayServiceAccountJSON string `env:"GOOGLE_PLAY_SERVICE_ACCOUNT_JSON"`
	// GooglePubSubAudience and GooglePubSubServiceAccount secure the RTDN push
	// endpoint with Pub/Sub's Google-signed OIDC bearer token.
	GooglePubSubAudience       string `env:"GOOGLE_PUBSUB_AUDIENCE"`
	GooglePubSubServiceAccount string `env:"GOOGLE_PUBSUB_SERVICE_ACCOUNT"`
	// GooglePlaySubscriptionID is the Play Console subscription product id.
	GooglePlaySubscriptionID string `env:"GOOGLE_PLAY_SUBSCRIPTION_ID" default:"premium"`
	// GooglePlayProductMonthly and GooglePlayProductYearly are the base-plan ids
	// mapped to a billing interval, mirroring the Apple pair above.
	GooglePlayProductMonthly string `env:"GOOGLE_PLAY_PRODUCT_MONTHLY"`
	GooglePlayProductYearly  string `env:"GOOGLE_PLAY_PRODUCT_YEARLY"`
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
	appCheckOn := c.FirebaseAppCheckRequired
	storageOn := c.S3BucketName != ""
	oauthOn := c.GoogleClientID != "" || c.AppleClientID != ""
	passwordOn := c.PasswordAuthEnabled
	guestOn := c.GuestAuthEnabled
	errorReportingOn := c.SentryDSN != ""
	errorTracingOn := errorReportingOn && c.SentryTracesSampleRate > 0
	fxOn := c.FxRateAPIURL != ""
	billingOn := c.PolarAccessToken != ""

	log.Info().
		Bool("email", emailOn).
		Bool("web_push", webPushOn).
		Bool("mobile_push", mobilePushOn).
		Bool("firebase_app_check", appCheckOn).
		Bool("file_storage", storageOn).
		Bool("oauth", oauthOn).
		Bool("password_auth", passwordOn).
		Bool("guest_auth", guestOn).
		Bool("error_reporting", errorReportingOn).
		Bool("error_tracing", errorTracingOn).
		Bool("fx_rates", fxOn).
		Bool("billing", billingOn).
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
	if !passwordOn {
		disabled = append(disabled, "password_auth (set PASSWORD_AUTH_ENABLED=true for email + password sign-in)")
	}
	if !billingOn {
		disabled = append(disabled, "billing (set POLAR_ACCESS_TOKEN and POLAR_WEBHOOK_SECRET; households grow without limit until then)")
	}
	if !c.AppleIAPEnabled() {
		disabled = append(disabled, "apple_iap (set APPLE_IAP_BUNDLE_ID and both APPLE_IAP_PRODUCT_* ids for App Store subscriptions)")
	}
	if !c.GoogleIAPEnabled() {
		disabled = append(disabled, "google_iap (set GOOGLE_PLAY_SERVICE_ACCOUNT_JSON and GOOGLE_PLAY_PACKAGE_NAME for Play Store subscriptions)")
	}
	if len(disabled) > 0 {
		log.Warn().Strs("disabled_integrations", disabled).
			Msg("some optional integrations are disabled; features depending on them will not work")
	}
	if !oauthOn && !passwordOn {
		if guestOn {
			log.Warn().Msg("no sign-in method is configured: only guest accounts can be created, and nobody can sign back in on another device. Set PASSWORD_AUTH_ENABLED=true or configure Google/Apple OAuth")
		} else {
			log.Warn().Msg("no way to create an account is configured: guests are off and there is no sign-in method. Set PASSWORD_AUTH_ENABLED=true, configure Google/Apple OAuth, or set GUEST_AUTH_ENABLED=true")
		}
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
	masked.PolarAccessToken = mask(masked.PolarAccessToken)
	masked.PolarWebhookSecret = mask(masked.PolarWebhookSecret)
	masked.GooglePlayServiceAccountJSON = mask(masked.GooglePlayServiceAccountJSON)
	return masked
}

// AppleIAPEnabled reports whether Apple In-App Purchase verification is
// configured. Mobile IAP is independent of the Polar web checkout: a server can
// run one, both, or neither.
func (c *Config) AppleIAPEnabled() bool {
	return c.AppleIAPBundleID != "" && c.AppleIAPProductMonthly != "" &&
		c.AppleIAPProductYearly != ""
}

// GoogleIAPEnabled reports whether Google Play purchase verification is
// configured.
func (c *Config) GoogleIAPEnabled() bool {
	return c.GooglePlayServiceAccountJSON != "" && c.GooglePlayPackageName != "" &&
		c.GooglePlaySubscriptionID != "" && c.GooglePlayProductMonthly != "" &&
		c.GooglePlayProductYearly != ""
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
	if c.Environment == "production" {
		frontendURL, err := url.Parse(c.FrontendURL)
		if err != nil || frontendURL.Host == "" || (frontendURL.Scheme != "http" && frontendURL.Scheme != "https") {
			return fmt.Errorf("FRONTEND_URL must be an absolute http(s) origin in production")
		}
		host := strings.ToLower(frontendURL.Hostname())
		if host == "localhost" || strings.HasSuffix(host, ".localhost") {
			return fmt.Errorf("FRONTEND_URL must not use localhost in production")
		}
		if ip := net.ParseIP(host); ip != nil && ip.IsLoopback() {
			return fmt.Errorf("FRONTEND_URL must not use a loopback address in production")
		}
	}
	if c.FirebaseAppCheckRequired && strings.TrimSpace(c.FirebaseProjectNumber) == "" {
		return fmt.Errorf("FIREBASE_PROJECT_NUMBER is required when Firebase App Check is enabled")
	}
	if c.FirebaseAppCheckRequired && strings.TrimSpace(c.FirebaseAppCheckAllowedAppIDs) == "" {
		return fmt.Errorf("FIREBASE_APP_CHECK_ALLOWED_APP_IDS is required when Firebase App Check is enabled")
	}
	if c.SecretKey != "" && c.SecretKey == c.SessionSecretKey {
		return fmt.Errorf("SECRET_KEY and SESSION_SECRET_KEY must be different")
	}

	// Checked here rather than where the handler is built, because that
	// happens after the database is up and the job runner has started — so a
	// malformed secret killed a booted process instead of failing config
	// validation, and the container crash-looped in production on 2026-08-21.
	//
	// standard-webhooks strips an optional "whsec_" prefix and base64-decodes
	// the rest. Polar hands out a raw secret, so it has to be encoded before
	// it gets here.
	if c.PolarWebhookSecret != "" {
		if _, err := standardwebhooks.NewWebhook(c.PolarWebhookSecret); err != nil {
			return fmt.Errorf(
				"POLAR_WEBHOOK_SECRET is not a valid standard-webhooks secret (%w) — "+
					"it must be base64, optionally prefixed with whsec_", err)
		}
	}
	if (c.GooglePubSubAudience == "") != (c.GooglePubSubServiceAccount == "") {
		return fmt.Errorf("GOOGLE_PUBSUB_AUDIENCE and GOOGLE_PUBSUB_SERVICE_ACCOUNT must be set together")
	}
	switch strings.ToLower(c.AppleIAPEnvironment) {
	case "", "production", "sandbox", "both":
	default:
		return fmt.Errorf("invalid APPLE_IAP_ENVIRONMENT: must be Production, Sandbox, or Both")
	}
	if c.AppleIAPEnabled() && strings.ToLower(c.AppleIAPEnvironment) != "sandbox" && c.AppleIAPAppID <= 0 {
		return fmt.Errorf("production Apple IAP requires APPLE_IAP_APP_ID")
	}
	if c.GoogleIAPEnabled() && (c.GooglePubSubAudience == "" || c.GooglePubSubServiceAccount == "") {
		return fmt.Errorf("Google IAP requires authenticated RTDN: set GOOGLE_PUBSUB_AUDIENCE and GOOGLE_PUBSUB_SERVICE_ACCOUNT")
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
