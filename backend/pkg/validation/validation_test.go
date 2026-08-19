package validation

import (
	"strings"
	"testing"
)

func TestEmail(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		wantErr bool
	}{
		{"valid", "user@example.com", false},
		{"valid with plus", "user+tag@example.com", false},
		{"empty", "", true},
		{"whitespace", "   ", true},
		{"no at", "userexample.com", true},
		{"too long", strings.Repeat("a", 250) + "@example.com", true},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := Email(tt.input)
			if (err != nil) != tt.wantErr {
				t.Fatalf("Email(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
			}
		})
	}
}

func TestPassword(t *testing.T) {
	tests := []struct {
		name    string
		input   string
		wantErr bool
	}{
		{"valid", "Passw0rd!", false},
		{"too short", "Pa0!aaa", true},
		{"too long", strings.Repeat("a", 129), true},
		{"no uppercase", "passw0rd!", true},
		{"no digit", "Password!", true},
		{"no special", "Passw0rdd", true},
		{"space does not count as special", "Passw0rd 1", true},
		{"unicode uppercase counts", "Ünicode1!", false},
		{"symbol counts as special", "Passw0rd~", false},
	}
	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			err := Password(tt.input)
			if (err != nil) != tt.wantErr {
				t.Fatalf("Password(%q) error = %v, wantErr %v", tt.input, err, tt.wantErr)
			}
		})
	}
}

func TestRequiredString(t *testing.T) {
	if err := RequiredString("", "name"); err == nil {
		t.Fatal("expected error for empty string")
	}
	if err := RequiredString("  ", "name"); err == nil {
		t.Fatal("expected error for whitespace-only string")
	}
	if err := RequiredString("hello", "name"); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
}

func TestMaxLength(t *testing.T) {
	if err := MaxLength("hello", 10, "field"); err != nil {
		t.Fatal("expected no error")
	}
	if err := MaxLength("hello world", 5, "field"); err == nil {
		t.Fatal("expected error for exceeding max length")
	}
}

func TestName(t *testing.T) {
	if err := Name("Alice", "first_name"); err != nil {
		t.Fatalf("unexpected error: %v", err)
	}
	if err := Name("", "first_name"); err == nil {
		t.Fatal("expected error for empty name")
	}
	if err := Name(strings.Repeat("a", 101), "first_name"); err == nil {
		t.Fatal("expected error for name too long")
	}
}
