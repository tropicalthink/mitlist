package handlers

import (
	"crypto/subtle"
	"encoding/json"
	"net"
	"net/http"
	"os"
	"strings"
)

// AdminGuard restricts access using an IP allowlist or HTTP Basic Auth.
func AdminGuard(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if isAdminAllowed(r) {
			next.ServeHTTP(w, r)
			return
		}
		w.Header().Set("Content-Type", "application/json")
		w.Header().Set("WWW-Authenticate", `Basic realm="admin"`)
		w.WriteHeader(http.StatusUnauthorized)
		_ = json.NewEncoder(w).Encode(map[string]string{"error": "unauthorized"})
	})
}

func isAdminAllowed(r *http.Request) bool {
	if allowlist := os.Getenv("DEBUG_ALLOWLIST"); allowlist != "" {
		ip := extractIP(r)
		for _, allowed := range strings.Split(allowlist, ",") {
			if strings.TrimSpace(allowed) == ip {
				return true
			}
		}
	}

	user, pass, ok := r.BasicAuth()
	if !ok {
		return false
	}

	expectedUser := os.Getenv("ADMIN_USER")
	expectedPass := os.Getenv("ADMIN_PASS")
	if expectedUser == "" || expectedPass == "" {
		return false
	}
	if subtle.ConstantTimeCompare([]byte(user), []byte(expectedUser)) != 1 {
		return false
	}
	return subtle.ConstantTimeCompare([]byte(pass), []byte(expectedPass)) == 1
}

func extractIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}
