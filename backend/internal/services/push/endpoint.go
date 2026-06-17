package push

import (
	"fmt"
	"net"
	"net/url"
	"strings"

	"github.com/mitlist-app/mitlist/internal/api"
)

const maxEndpointLen = 2048

// ValidatePushEndpoint enforces that the supplied endpoint URL is safe to use
// as a web-push delivery target. It rejects:
//   - non-https schemes (http, ftp, file, …)
//   - empty or overly-long URLs
//   - IP literals or hostnames that resolve to loopback, private,
//     link-local, or unspecified addresses (SSRF prevention)
//   - the literal hostname "localhost"
//
// Note: validation happens at registration time. DNS rebinding after
// registration is a residual risk; full protection would require re-validating
// the resolved IP at send time (see push.go). This is the pragmatic 80%.
func ValidatePushEndpoint(raw string) error {
	if raw == "" {
		return &api.ValidationError{Field: "endpoint", Message: "endpoint is required"}
	}
	if len(raw) > maxEndpointLen {
		return &api.ValidationError{Field: "endpoint", Message: fmt.Sprintf("endpoint exceeds maximum length of %d", maxEndpointLen)}
	}

	u, err := url.Parse(raw)
	if err != nil || !u.IsAbs() || u.Host == "" {
		return &api.ValidationError{Field: "endpoint", Message: "endpoint must be an absolute URL"}
	}

	if u.Scheme != "https" {
		return &api.ValidationError{Field: "endpoint", Message: "endpoint scheme must be https"}
	}

	// Strip port to get the bare host.
	host := u.Hostname()

	if strings.EqualFold(host, "localhost") {
		return &api.ValidationError{Field: "endpoint", Message: "endpoint must not target a local host"}
	}

	// If the host is an IP literal, check it directly.
	if ip := net.ParseIP(host); ip != nil {
		if err := checkIP(ip); err != nil {
			return err
		}
		return nil
	}

	// Otherwise resolve the hostname and check every returned address.
	addrs, err := net.LookupHost(host)
	if err != nil {
		// A hostname that doesn't resolve is not a valid push endpoint.
		return &api.ValidationError{Field: "endpoint", Message: "endpoint host could not be resolved"}
	}
	for _, addr := range addrs {
		ip := net.ParseIP(addr)
		if ip == nil {
			continue
		}
		if err := checkIP(ip); err != nil {
			return err
		}
	}

	return nil
}

// checkIP returns a ValidationError if ip is in any private/loopback/link-local/unspecified range.
func checkIP(ip net.IP) error {
	switch {
	case ip.IsLoopback():
		return &api.ValidationError{Field: "endpoint", Message: "endpoint must not target a loopback address"}
	case ip.IsPrivate():
		return &api.ValidationError{Field: "endpoint", Message: "endpoint must not target a private network address"}
	case ip.IsLinkLocalUnicast():
		return &api.ValidationError{Field: "endpoint", Message: "endpoint must not target a link-local address"}
	case ip.IsLinkLocalMulticast():
		return &api.ValidationError{Field: "endpoint", Message: "endpoint must not target a link-local multicast address"}
	case ip.IsUnspecified():
		return &api.ValidationError{Field: "endpoint", Message: "endpoint must not target an unspecified address"}
	}
	return nil
}
