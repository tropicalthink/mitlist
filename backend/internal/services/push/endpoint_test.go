package push

import (
	"strings"
	"testing"
)

func TestValidatePushEndpoint(t *testing.T) {
	t.Parallel()

	// ---- accepted cases ----
	accept := []struct {
		name string
		url  string
	}{
		{
			name: "FCM endpoint",
			url:  "https://fcm.googleapis.com/fcm/send/abc123",
		},
		{
			name: "Mozilla push endpoint",
			url:  "https://updates.push.services.mozilla.com/push/v1/xyz",
		},
	}

	for _, tc := range accept {
		tc := tc
		t.Run("accept/"+tc.name, func(t *testing.T) {
			t.Parallel()
			if err := ValidatePushEndpoint(tc.url); err != nil {
				t.Errorf("expected nil error for %q, got: %v", tc.url, err)
			}
		})
	}

	// ---- rejected cases ----
	reject := []struct {
		name string
		url  string
	}{
		{name: "empty", url: ""},
		{name: "plain string", url: "not-a-url"},
		{name: "http scheme", url: "http://fcm.googleapis.com/push"},
		{name: "ftp scheme", url: "ftp://fcm.googleapis.com/push"},
		{name: "localhost", url: "https://localhost/push"},
		{name: "localhost with port", url: "https://localhost:8080/push"},
		{name: "IPv4 loopback 127.0.0.1", url: "https://127.0.0.1/push"},
		{name: "IPv4 loopback 127.0.0.2", url: "https://127.0.0.2/push"},
		{name: "IPv4 private 10.x", url: "https://10.0.0.5/push"},
		{name: "IPv4 private 192.168.x", url: "https://192.168.1.1/push"},
		{name: "IPv4 private 172.16.x", url: "https://172.16.0.1/push"},
		{name: "link-local metadata 169.254.169.254", url: "https://169.254.169.254/latest/meta-data/"},
		{name: "link-local other", url: "https://169.254.1.1/push"},
		{name: "IPv6 loopback ::1", url: "https://[::1]/push"},
		{name: "unspecified 0.0.0.0", url: "https://0.0.0.0/push"},
		{name: "too long", url: "https://fcm.googleapis.com/" + strings.Repeat("a", 2048)},
	}

	for _, tc := range reject {
		tc := tc
		t.Run("reject/"+tc.name, func(t *testing.T) {
			t.Parallel()
			if err := ValidatePushEndpoint(tc.url); err == nil {
				t.Errorf("expected error for %q, got nil", tc.url)
			}
		})
	}
}
