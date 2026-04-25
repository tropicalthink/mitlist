package middleware

import (
	"net/http"
	"net/url"
	"strings"
)

// CorsMiddleware returns a simple CORS middleware.
func CorsMiddleware(allowedOrigin, environment string) func(next http.Handler) http.Handler {
	return func(next http.Handler) http.Handler {
		return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
			if origin := resolveAllowedOrigin(r.Header.Get("Origin"), allowedOrigin, environment); origin != "" {
				w.Header().Set("Access-Control-Allow-Origin", origin)
				w.Header().Set("Access-Control-Allow-Credentials", "true")
				w.Header().Add("Vary", "Origin")
			}

			w.Header().Set("Access-Control-Allow-Methods", "GET, POST, PATCH, PUT, DELETE, OPTIONS")
			w.Header().Set("Access-Control-Allow-Headers", "Content-Type, Authorization, X-Request-ID")
			if r.Method == http.MethodOptions {
				w.WriteHeader(http.StatusNoContent)
				return
			}
			next.ServeHTTP(w, r)
		})
	}
}

func resolveAllowedOrigin(requestOrigin, allowedOrigin, environment string) string {
	if requestOrigin == "" {
		return ""
	}

	if requestOrigin == allowedOrigin {
		return requestOrigin
	}

	if !strings.EqualFold(environment, "development") {
		return ""
	}

	originURL, err := url.Parse(requestOrigin)
	if err != nil {
		return ""
	}

	switch strings.ToLower(originURL.Hostname()) {
	case "localhost", "127.0.0.1":
		return requestOrigin
	default:
		return ""
	}
}
