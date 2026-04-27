package security

import (
	"context"
	"fmt"
	"net"
	"net/url"
	"strings"
	"time"
)

// ValidateURLForFetch blocks common SSRF vectors.
//
// It validates scheme, host, and resolved IPs (A/AAAA). This is a best-effort
// guardrail; callers must ALSO validate redirects.
func ValidateURLForFetch(ctx context.Context, raw string) (*url.URL, error) {
	u, err := url.Parse(strings.TrimSpace(raw))
	if err != nil {
		return nil, fmt.Errorf("invalid url")
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return nil, fmt.Errorf("unsupported url scheme")
	}
	if u.Hostname() == "" {
		return nil, fmt.Errorf("url must include hostname")
	}
	if u.User != nil {
		return nil, fmt.Errorf("userinfo not allowed in url")
	}

	host := strings.TrimSpace(u.Hostname())
	if host == "" {
		return nil, fmt.Errorf("url must include hostname")
	}

	// Block obvious localhost variants early.
	hostLower := strings.ToLower(host)
	if hostLower == "localhost" || strings.HasSuffix(hostLower, ".localhost") {
		return nil, fmt.Errorf("localhost not allowed")
	}

	// Literal IPs are allowed only if public.
	if ip := net.ParseIP(host); ip != nil {
		if isBlockedIP(ip) {
			return nil, fmt.Errorf("ip not allowed")
		}
		return u, nil
	}

	// Resolve DNS and block any private/link-local/etc results.
	lookupCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	addrs, err := net.DefaultResolver.LookupIPAddr(lookupCtx, host)
	if err != nil || len(addrs) == 0 {
		return nil, fmt.Errorf("could not resolve host")
	}
	for _, a := range addrs {
		if isBlockedIP(a.IP) {
			return nil, fmt.Errorf("host resolves to a blocked network")
		}
	}
	return u, nil
}

func isBlockedIP(ip net.IP) bool {
	if ip == nil {
		return true
	}
	if ip.IsLoopback() || ip.IsLinkLocalUnicast() || ip.IsLinkLocalMulticast() || ip.IsMulticast() || ip.IsUnspecified() {
		return true
	}
	if ip.IsPrivate() {
		return true
	}

	// Extra IPv6 ranges that net.IP helpers don't fully classify across versions.
	// Unique local: fc00::/7
	if ip.To4() == nil {
		if len(ip) == net.IPv6len {
			if ip[0]&0xfe == 0xfc {
				return true
			}
		}
	}

	return false
}

