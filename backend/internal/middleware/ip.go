package middleware

import (
	"net"
	"net/http"
	"strings"
)

var trustedProxies []*net.IPNet

func SetTrustedProxies(cidrs []string) {
	trustedProxies = make([]*net.IPNet, 0, len(cidrs))
	for _, cidr := range cidrs {
		cidr = strings.TrimSpace(cidr)
		if cidr == "" {
			continue
		}
		_, ipNet, err := net.ParseCIDR(cidr)
		if err != nil {
			if ip := net.ParseIP(cidr); ip != nil {
				if ip.To4() != nil {
					ipNet = &net.IPNet{IP: ip, Mask: net.CIDRMask(32, 32)}
				} else {
					ipNet = &net.IPNet{IP: ip, Mask: net.CIDRMask(128, 128)}
				}
			}
		}
		if ipNet != nil {
			trustedProxies = append(trustedProxies, ipNet)
		}
	}
}

func isTrustedProxy(ip net.IP) bool {
	if len(trustedProxies) == 0 {
		return false
	}
	for _, n := range trustedProxies {
		if n.Contains(ip) {
			return true
		}
	}
	return false
}

func peerIP(r *http.Request) net.IP {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		host = r.RemoteAddr
	}
	return net.ParseIP(host)
}

func RealIPFromTrusted(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		if peer := peerIP(r); peer != nil && isTrustedProxy(peer) {
			if xri := r.Header.Get("X-Real-Ip"); xri != "" {
				if ip := net.ParseIP(strings.TrimSpace(xri)); ip != nil {
					r.RemoteAddr = ip.String() + ":0"
				}
			} else if xff := r.Header.Get("X-Forwarded-For"); xff != "" {
				parts := strings.Split(xff, ",")
				for i := len(parts) - 1; i >= 0; i-- {
					candidate := strings.TrimSpace(parts[i])
					ip := net.ParseIP(candidate)
					if ip != nil && !isTrustedProxy(ip) {
						r.RemoteAddr = ip.String() + ":0"
						break
					}
				}
			}
		}
		next.ServeHTTP(w, r)
	})
}

func ExtractIP(r *http.Request) string {
	host, _, err := net.SplitHostPort(r.RemoteAddr)
	if err != nil {
		return r.RemoteAddr
	}
	return host
}
