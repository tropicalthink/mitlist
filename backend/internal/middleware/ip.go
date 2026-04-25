package middleware

import (
	"net"
	"net/http"
	"strings"
)

// ExtractIP extracts the client IP from X-Forwarded-For, X-Real-Ip, or RemoteAddr.
func ExtractIP(r *http.Request) string {
	if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
		if i := strings.Index(xff, ","); i != -1 {
			xff = strings.TrimSpace(xff[:i])
		}
		if ip := net.ParseIP(xff); ip != nil {
			return ip.String()
		}
	}

	if xri := r.Header.Get("X-Real-Ip"); xri != "" {
		if ip := net.ParseIP(xri); ip != nil {
			return ip.String()
		}
	}

	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}
