package onboarding

import (
	"bytes"
	"image/jpeg"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"
)

func TestUnsubscribeToken_RoundTrip(t *testing.T) {
	secret := []byte("a-long-enough-secret-for-tests-0123456789")
	id := uuid.New()
	tok := UnsubscribeToken(secret, id)
	got, ok := ParseUnsubscribeToken(secret, tok)
	if !ok || got != id {
		t.Fatalf("parse = (%v, %v), want (%v, true)", got, ok, id)
	}
}

func TestUnsubscribeToken_RejectsTamperingAndWrongSecret(t *testing.T) {
	secret := []byte("a-long-enough-secret-for-tests-0123456789")
	id := uuid.New()
	tok := UnsubscribeToken(secret, id)

	if _, ok := ParseUnsubscribeToken([]byte("another-secret"), tok); ok {
		t.Error("token verified under a different secret")
	}
	// Flip a character in the MAC half.
	b := []byte(tok)
	last := len(b) - 1
	if b[last] == 'A' {
		b[last] = 'B'
	} else {
		b[last] = 'A'
	}
	if _, ok := ParseUnsubscribeToken(secret, string(b)); ok {
		t.Error("tampered token verified")
	}
	for _, bad := range []string{"", "not-base64!!", "AAAA", tok + "AA"} {
		if _, ok := ParseUnsubscribeToken(secret, bad); ok {
			t.Errorf("malformed token %q verified", bad)
		}
	}
}

func TestDue_WindowsAndOldAccounts(t *testing.T) {
	now := time.Date(2026, 9, 8, 12, 0, 0, 0, time.UTC)

	// Brand new: nothing yet.
	if got := Due(now.Add(-1*time.Hour), now); len(got) != 0 {
		t.Errorf("1h old account due %d steps, want 0", len(got))
	}
	// A day old: the first step only.
	got := Due(now.Add(-24*time.Hour), now)
	if len(got) != 1 || got[0].Key != "day1-household" {
		t.Errorf("24h old account due %v, want [day1-household]", keys(got))
	}
	// Signed up before the series existed: past every window, gets nothing.
	if got := Due(now.Add(-120*24*time.Hour), now); len(got) != 0 {
		t.Errorf("120d old account due %v, want none", keys(got))
	}
	// Exactly one step in flight at day 8: day7 is inside its 72h window,
	// day3 and day1 are long past theirs.
	got = Due(now.Add(-8*24*time.Hour), now)
	if len(got) != 1 || got[0].Key != "day7-money" {
		t.Errorf("8d old account due %v, want [day7-money]", keys(got))
	}
}

func TestSteps_KeysUniqueAndOrdered(t *testing.T) {
	seen := map[string]bool{}
	heroes := map[string]bool{}
	var prev time.Duration
	for _, s := range Steps {
		if seen[s.Key] {
			t.Errorf("duplicate step key %q", s.Key)
		}
		seen[s.Key] = true
		if s.After <= prev {
			t.Errorf("step %q (after %v) is not later than the one before (%v)", s.Key, s.After, prev)
		}
		prev = s.After
		if s.Subject == "" || s.Heading == "" || len(s.Tips) == 0 || s.CTAPath == "" || s.HeroFilename == "" || s.HeroAlt == "" {
			t.Errorf("step %q is missing copy", s.Key)
		}
		if heroes[s.HeroFilename] {
			t.Errorf("step %q reuses hero %q", s.Key, s.HeroFilename)
		}
		heroes[s.HeroFilename] = true
	}
}

func TestRender_CarriesUnsubscribeAndButton(t *testing.T) {
	links := Links{
		AppURL:         "https://app.mitlist.me/",
		HeroURL:        "https://api.mitlist.me/api/v1/email/assets/day3-lists.jpg",
		UnsubscribeURL: "https://api.mitlist.me/api/v1/email/unsubscribe?token=abc",
	}
	msg := Render(Steps[1], "Sam", links)

	if msg.Subject != Steps[1].Subject {
		t.Errorf("subject = %q", msg.Subject)
	}
	for _, body := range []string{msg.HTML, msg.Text} {
		if !strings.Contains(body, links.UnsubscribeURL) {
			t.Error("body lacks the unsubscribe link")
		}
		if !strings.Contains(body, "https://app.mitlist.me/lists") {
			t.Error("body lacks the button URL (and doubled or lost the slash)")
		}
		if !strings.Contains(body, "Hi Sam.") {
			t.Error("body lacks the greeting")
		}
	}
	// No name, no dangling "Hi ,".
	anon := Render(Steps[1], "  ", links)
	if strings.Contains(anon.HTML, "Hi ") || strings.Contains(anon.Text, "Hi ") {
		t.Error("greeting rendered with an empty name")
	}
	if !strings.Contains(msg.HTML, `src="https://api.mitlist.me/api/v1/email/assets/day3-lists.jpg"`) {
		t.Error("HTML lacks the onboarding hero")
	}
	if !strings.Contains(msg.HTML, "EMAIL 2 / 5") {
		t.Error("HTML lacks the series progress marker")
	}
	if !strings.Contains(msg.HTML, `alt="Scan a paper list, sort it by aisle, and add meal-plan ingredients"`) {
		t.Error("linked hero lacks an accessible action label")
	}
	// Copy is HTML-escaped on the way in.
	if strings.Contains(msg.HTML, "\"do we need milk?\"") {
		t.Error("subject quotes leaked unescaped into HTML")
	}
}

func TestUnsubscribeURL(t *testing.T) {
	got := UnsubscribeURL("https://api.mitlist.me/", "/api", "tok")
	if got != "https://api.mitlist.me/api/v1/email/unsubscribe?token=tok" {
		t.Errorf("url = %q", got)
	}
}

func TestHeroURL(t *testing.T) {
	got := HeroURL("https://api.mitlist.me/", "/api", "day7-money.jpg")
	if got != "https://api.mitlist.me/api/v1/email/assets/day7-money.jpg" {
		t.Errorf("hero URL = %q", got)
	}
}

func TestHeroImagesAreValidJPEGs(t *testing.T) {
	for _, step := range Steps {
		data, ok := HeroImage(step.HeroFilename)
		if !ok {
			t.Errorf("hero %q is not embedded", step.HeroFilename)
			continue
		}
		image, err := jpeg.Decode(bytes.NewReader(data))
		if err != nil {
			t.Errorf("decode JPEG hero %q: %v", step.HeroFilename, err)
			continue
		}
		bounds := image.Bounds()
		if bounds.Dx() != 1040 || bounds.Dy() != 693 {
			t.Errorf("hero %q size = %dx%d, want 1040x693", step.HeroFilename, bounds.Dx(), bounds.Dy())
		}
	}
}

func keys(steps []Step) []string {
	out := make([]string, 0, len(steps))
	for _, s := range steps {
		out = append(out, s.Key)
	}
	return out
}
