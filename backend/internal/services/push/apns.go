package push

import (
	"bytes"
	"context"
	"crypto/ecdsa"
	"crypto/x509"
	"encoding/pem"
	"errors"
	"fmt"
	"io"
	"net/http"
	"strings"
	"sync"
	"time"

	"github.com/golang-jwt/jwt/v5"
)

// APNs hosts. Tokens from development builds are only valid on the sandbox.
const (
	apnsProductionHost = "https://api.push.apple.com"
	apnsSandboxHost    = "https://api.sandbox.push.apple.com"
)

// apnsJWTLifetime: Apple rejects provider tokens older than an hour and
// throttles ones refreshed more often than every 20 minutes.
const apnsJWTLifetime = 45 * time.Minute

// ErrAPNSUnregistered means the device token is no longer valid and should
// be forgotten.
var ErrAPNSUnregistered = errors.New("apns: device token is no longer valid")

// APNSClient talks to APNs directly with token (.p8) authentication. FCM
// cannot send the WidgetKit push type, so iOS 26 widget pushes go this way
// (plans/047, contract C6).
type APNSClient struct {
	keyID  string
	teamID string
	key    *ecdsa.PrivateKey
	host   string
	topic  string
	client *http.Client
	now    func() time.Time

	mu        sync.Mutex
	jwt       string
	jwtIssued time.Time
}

// NewAPNSClient returns nil (and no error) when APNs is not configured.
// keyP8 is the contents of the AuthKey_<keyID>.p8 file.
func NewAPNSClient(keyP8, keyID, teamID, bundleID string, sandbox bool) (*APNSClient, error) {
	if keyP8 == "" || keyID == "" || teamID == "" {
		return nil, nil
	}
	block, _ := pem.Decode([]byte(strings.TrimSpace(keyP8)))
	if block == nil {
		return nil, errors.New("apns: key is not PEM")
	}
	parsed, err := x509.ParsePKCS8PrivateKey(block.Bytes)
	if err != nil {
		return nil, fmt.Errorf("apns: parse key: %w", err)
	}
	key, ok := parsed.(*ecdsa.PrivateKey)
	if !ok {
		return nil, errors.New("apns: key is not an ECDSA key")
	}
	host := apnsProductionHost
	if sandbox {
		host = apnsSandboxHost
	}
	return &APNSClient{
		keyID: keyID, teamID: teamID, key: key, host: host,
		topic:  bundleID + ".push-type.widgets",
		client: &http.Client{Timeout: 10 * time.Second},
		now:    time.Now,
	}, nil
}

func (c *APNSClient) providerToken() (string, error) {
	c.mu.Lock()
	defer c.mu.Unlock()
	now := c.now()
	if c.jwt != "" && now.Sub(c.jwtIssued) < apnsJWTLifetime {
		return c.jwt, nil
	}
	token := jwt.NewWithClaims(jwt.SigningMethodES256, jwt.MapClaims{"iss": c.teamID, "iat": now.Unix()})
	token.Header["kid"] = c.keyID
	signed, err := token.SignedString(c.key)
	if err != nil {
		return "", fmt.Errorf("apns: sign provider token: %w", err)
	}
	c.jwt, c.jwtIssued = signed, now
	return signed, nil
}

// SendWidgetPush asks WidgetKit on the device to reload the app's widgets.
func (c *APNSClient) SendWidgetPush(ctx context.Context, deviceToken string) error {
	bearer, err := c.providerToken()
	if err != nil {
		return err
	}
	req, err := http.NewRequestWithContext(ctx, http.MethodPost, c.host+"/3/device/"+deviceToken,
		bytes.NewReader([]byte(`{"aps":{"content-changed":true}}`)))
	if err != nil {
		return err
	}
	req.Header.Set("authorization", "bearer "+bearer)
	req.Header.Set("apns-topic", c.topic)
	req.Header.Set("apns-push-type", "widgets")
	req.Header.Set("content-type", "application/json")
	resp, err := c.client.Do(req)
	if err != nil {
		return err
	}
	defer resp.Body.Close()
	if resp.StatusCode == http.StatusOK {
		return nil
	}
	body, _ := io.ReadAll(io.LimitReader(resp.Body, 4096))
	if resp.StatusCode == http.StatusGone || bytes.Contains(body, []byte("BadDeviceToken")) {
		return ErrAPNSUnregistered
	}
	return fmt.Errorf("apns: HTTP %d: %s", resp.StatusCode, strings.TrimSpace(string(body)))
}
