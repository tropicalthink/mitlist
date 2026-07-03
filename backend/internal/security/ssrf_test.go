package security

import (
	"net"
	"testing"
)

func TestIsBlockedIP(t *testing.T) {
	tests := []struct {
		name    string
		ip      string
		blocked bool
	}{
		{name: "loopback", ip: "127.0.0.1", blocked: true},
		{name: "private", ip: "10.0.0.1", blocked: true},
		{name: "link local", ip: "169.254.169.254", blocked: true},
		{name: "cgnat", ip: "100.64.0.1", blocked: true},
		{name: "benchmark", ip: "198.18.0.1", blocked: true},
		{name: "documentation", ip: "203.0.113.1", blocked: true},
		{name: "ipv4 mapped cgnat", ip: "::ffff:100.64.0.1", blocked: true},
		{name: "public", ip: "93.184.216.34", blocked: false},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			if got := IsBlockedIP(net.ParseIP(tt.ip)); got != tt.blocked {
				t.Fatalf("IsBlockedIP(%s) = %v, want %v", tt.ip, got, tt.blocked)
			}
		})
	}
}
