package push

import (
	"context"
	"crypto/ecdsa"
	"crypto/elliptic"
	"crypto/rand"
	"crypto/x509"
	"encoding/pem"
	"errors"
	"io"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"

	"github.com/golang-jwt/jwt/v5"
	"github.com/stretchr/testify/require"
)

func testAPNSKey(t *testing.T) (*ecdsa.PrivateKey, string) {
	t.Helper()
	key, err := ecdsa.GenerateKey(elliptic.P256(), rand.Reader)
	require.NoError(t, err)
	der, err := x509.MarshalPKCS8PrivateKey(key)
	require.NoError(t, err)
	return key, string(pem.EncodeToMemory(&pem.Block{Type: "PRIVATE KEY", Bytes: der}))
}

func TestNewAPNSClientIsOffWithoutConfig(t *testing.T) {
	client, err := NewAPNSClient("", "", "", "me.mitlist", false)
	require.NoError(t, err)
	require.Nil(t, client)

	_, err = NewAPNSClient("not a key", "KEY123", "TEAM123", "me.mitlist", false)
	require.Error(t, err)
}

func TestAPNSClientSendsWidgetPush(t *testing.T) {
	key, p8 := testAPNSKey(t)
	var calls int
	status, body := http.StatusOK, ""
	server := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		calls++
		require.Equal(t, http.MethodPost, r.Method)
		require.Equal(t, "/3/device/abcdef", r.URL.Path)
		require.Equal(t, "me.mitlist.push-type.widgets", r.Header.Get("apns-topic"))
		require.Equal(t, "widgets", r.Header.Get("apns-push-type"))
		payload, _ := io.ReadAll(r.Body)
		require.JSONEq(t, `{"aps":{"content-changed":true}}`, string(payload))

		bearer := strings.TrimPrefix(r.Header.Get("authorization"), "bearer ")
		parsed, err := jwt.Parse(bearer, func(*jwt.Token) (any, error) { return &key.PublicKey, nil },
			jwt.WithValidMethods([]string{"ES256"}))
		require.NoError(t, err)
		require.Equal(t, "KEY123", parsed.Header["kid"])
		claims := parsed.Claims.(jwt.MapClaims)
		require.Equal(t, "TEAM123", claims["iss"])

		w.WriteHeader(status)
		_, _ = w.Write([]byte(body))
	}))
	defer server.Close()

	client, err := NewAPNSClient(p8, "KEY123", "TEAM123", "me.mitlist", true)
	require.NoError(t, err)
	require.Equal(t, apnsSandboxHost, client.host)
	client.host = server.URL
	first := time.Now()
	client.now = func() time.Time { return first }

	require.NoError(t, client.SendWidgetPush(context.Background(), "abcdef"))
	signed := client.jwt
	require.NoError(t, client.SendWidgetPush(context.Background(), "abcdef"))
	require.Equal(t, signed, client.jwt, "the provider token is reused within its lifetime")
	client.now = func() time.Time { return first.Add(apnsJWTLifetime + time.Minute) }
	require.NoError(t, client.SendWidgetPush(context.Background(), "abcdef"))
	require.NotEqual(t, signed, client.jwt, "and refreshed after it")

	status, body = http.StatusGone, `{"reason":"Unregistered"}`
	require.ErrorIs(t, client.SendWidgetPush(context.Background(), "abcdef"), ErrAPNSUnregistered)
	status, body = http.StatusBadRequest, `{"reason":"BadDeviceToken"}`
	require.ErrorIs(t, client.SendWidgetPush(context.Background(), "abcdef"), ErrAPNSUnregistered)
	status, body = http.StatusInternalServerError, `{"reason":"InternalServerError"}`
	err = client.SendWidgetPush(context.Background(), "abcdef")
	require.Error(t, err)
	require.False(t, errors.Is(err, ErrAPNSUnregistered))
	require.Equal(t, 6, calls)
}
