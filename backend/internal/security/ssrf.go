package security

import (
	"context"
	"fmt"
	"net"
	"net/http"
	"net/url"
	"strings"
	"time"
)

func ValidateURLForFetch(ctx context.Context, raw string) (*url.URL, error) {
	u, resolvedIPs, err := validateAndResolve(ctx, raw)
	if err != nil {
		return nil, err
	}
	_ = resolvedIPs
	return u, nil
}

type ValidatedURL struct {
	URL         *url.URL
	ResolvedIPs []net.IP
	Port        string
}

func ValidateAndResolveURL(ctx context.Context, raw string) (*ValidatedURL, error) {
	u, resolvedIPs, err := validateAndResolve(ctx, raw)
	if err != nil {
		return nil, err
	}

	port := u.Port()
	if port == "" {
		if u.Scheme == "https" {
			port = "443"
		} else {
			port = "80"
		}
	}

	return &ValidatedURL{
		URL:         u,
		ResolvedIPs: resolvedIPs,
		Port:        port,
	}, nil
}

func NewPinnedTransport(v *ValidatedURL) *http.Transport {
	if len(v.ResolvedIPs) == 0 {
		return nil
	}

	dialer := &net.Dialer{
		Timeout: 30 * time.Second,
	}

	return &http.Transport{
		DialContext: func(ctx context.Context, network, addr string) (net.Conn, error) {
			for _, ip := range v.ResolvedIPs {
				target := net.JoinHostPort(ip.String(), v.Port)
				conn, err := dialer.DialContext(ctx, network, target)
				if err == nil {
					return conn, nil
				}
			}
			return nil, fmt.Errorf("dial: no validated address available")
		},
		Proxy:                 http.ProxyFromEnvironment,
		ForceAttemptHTTP2:     true,
		TLSHandshakeTimeout:   10 * time.Second,
		ResponseHeaderTimeout: 10 * time.Second,
		ExpectContinueTimeout: 1 * time.Second,
	}
}

func validateAndResolve(ctx context.Context, raw string) (*url.URL, []net.IP, error) {
	u, err := url.Parse(strings.TrimSpace(raw))
	if err != nil {
		return nil, nil, fmt.Errorf("invalid url")
	}
	if u.Scheme != "http" && u.Scheme != "https" {
		return nil, nil, fmt.Errorf("unsupported url scheme")
	}
	if u.Hostname() == "" {
		return nil, nil, fmt.Errorf("url must include hostname")
	}
	if u.User != nil {
		return nil, nil, fmt.Errorf("userinfo not allowed in url")
	}

	host := strings.TrimSpace(u.Hostname())
	if host == "" {
		return nil, nil, fmt.Errorf("url must include hostname")
	}

	hostLower := strings.ToLower(host)
	if hostLower == "localhost" || strings.HasSuffix(hostLower, ".localhost") {
		return nil, nil, fmt.Errorf("localhost not allowed")
	}

	if ip := net.ParseIP(host); ip != nil {
		if isBlockedIP(ip) {
			return nil, nil, fmt.Errorf("ip not allowed")
		}
		return u, []net.IP{ip}, nil
	}

	lookupCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()
	addrs, err := net.DefaultResolver.LookupIPAddr(lookupCtx, host)
	if err != nil || len(addrs) == 0 {
		return nil, nil, fmt.Errorf("could not resolve host")
	}

	resolvedIPs := make([]net.IP, 0, len(addrs))
	for _, a := range addrs {
		if isBlockedIP(a.IP) {
			return nil, nil, fmt.Errorf("host resolves to a blocked network")
		}
		resolvedIPs = append(resolvedIPs, a.IP)
	}

	return u, resolvedIPs, nil
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

	if ip.To4() == nil {
		if len(ip) == net.IPv6len {
			if ip[0]&0xfe == 0xfc {
				return true
			}
		}
	}

	return false
}
