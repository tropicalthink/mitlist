package onboarding

import (
	"bytes"
	"fmt"
	"html/template"
	"image/jpeg"
	"reflect"
	"strings"
	"testing"
	"time"

	"github.com/google/uuid"

	"github.com/mitlist-app/mitlist/pkg/validation"
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
		if len(s.Tips) > MaxTips {
			t.Errorf("step %q asks for %d things; at most %d per email", s.Key, len(s.Tips), MaxTips)
		}
		for _, tip := range s.Tips {
			if tip.Title == "" || tip.Body == "" {
				t.Errorf("step %q has a tip missing copy", s.Key)
			}
			if !strings.HasPrefix(tip.Path, "/") {
				t.Errorf("step %q tip %q does not link anywhere (path %q)", s.Key, tip.Title, tip.Path)
			}
		}
	}
}

func TestRender_CarriesUnsubscribeAndButton(t *testing.T) {
	links := Links{
		AppURL:         "https://app.mitlist.me/",
		HeroURL:        "https://api.mitlist.me/api/v1/email/assets/day3-lists.jpg",
		UnsubscribeURL: "https://api.mitlist.me/api/v1/email/unsubscribe?token=abc",
	}
	msg := Render(Steps[1], "", "Sam", links)

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
	anon := Render(Steps[1], "en", "  ", links)
	if strings.Contains(anon.HTML, "Hi ") || strings.Contains(anon.Text, "Hi ") {
		t.Error("greeting rendered with an empty name")
	}
	// Every tip is a link to the screen it talks about, in both bodies.
	for _, tip := range Steps[1].Tips {
		want := "https://app.mitlist.me" + tip.Path
		if !strings.Contains(msg.HTML, `href="`+want+`"`) {
			t.Errorf("HTML tip %q does not link to %s", tip.Title, want)
		}
		if !strings.Contains(msg.Text, "Open: "+want) {
			t.Errorf("text tip %q does not link to %s", tip.Title, want)
		}
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

func TestRenderReengagement_LinksAndOptionalRating(t *testing.T) {
	links := ReengagementLinks{
		AppURL:         "https://app.example.test/",
		UnsubscribeURL: "https://api.example.test/api/v1/email/unsubscribe?token=abc",
	}
	msg := RenderReengagement("", "  ", links)
	if !strings.Contains(msg.HTML, `href="https://app.example.test/you/feature-board"`) {
		t.Error("html lacks the feedback board button")
	}
	if !strings.Contains(msg.Text, "Share feedback: https://app.example.test/you/feature-board") {
		t.Error("text lacks the feedback board link")
	}
	if strings.Contains(msg.HTML, "play.google.com") || strings.Contains(msg.Text, "play.google.com") {
		t.Error("rating link shown without ShowRating")
	}
	if strings.Contains(msg.Text, "Hi ") {
		t.Error("blank first name produced a greeting")
	}
	if strings.Count(msg.HTML, links.UnsubscribeURL) < 2 || !strings.Contains(msg.Text, links.UnsubscribeURL) {
		t.Error("unsubscribe link missing from html footer, html card, or text")
	}

	links.ShowRating = true
	msg = RenderReengagement("en", "Ada", links)
	if !strings.Contains(msg.HTML, `href="`+PlayStoreURL+`"`) || !strings.Contains(msg.Text, PlayStoreURL) {
		t.Error("ShowRating did not add the Google Play link")
	}
	if !strings.Contains(msg.HTML, "Hi Ada.") {
		t.Error("greeting missing")
	}
}

func TestReengagementCopies_CoverEverySupportedLanguage(t *testing.T) {
	if len(reengagementCopies) != len(validation.SupportedLanguages) {
		t.Errorf("copy for %d languages, app supports %d", len(reengagementCopies), len(validation.SupportedLanguages))
	}
	for _, lang := range validation.SupportedLanguages {
		c, ok := reengagementCopies[lang]
		if !ok {
			t.Errorf("no re-engagement copy for %q", lang)
			continue
		}
		v := reflect.ValueOf(c)
		for i := 0; i < v.NumField(); i++ {
			if strings.TrimSpace(v.Field(i).String()) == "" {
				t.Errorf("%s: %s is empty", lang, v.Type().Field(i).Name)
			}
		}
	}
}

func TestRenderReengagement_UsesStoredLanguage(t *testing.T) {
	links := ReengagementLinks{
		AppURL:         "https://app.example.test",
		UnsubscribeURL: "https://api.example.test/api/v1/email/unsubscribe?token=abc",
		ShowRating:     true,
	}
	for _, lang := range validation.SupportedLanguages {
		c := reengagementCopies[lang]
		msg := RenderReengagement(lang, "Ada", links)
		if msg.Subject != c.Subject {
			t.Errorf("%s: subject %q, want %q", lang, msg.Subject, c.Subject)
		}
		if !strings.Contains(msg.HTML, `<html lang="`+lang+`"`) {
			t.Errorf("%s: html lang attribute missing", lang)
		}
		for _, want := range []string{c.RateButton, chromeCopies[lang].Unsubscribe} {
			if !strings.Contains(msg.Text+msg.HTML, template.HTMLEscapeString(want)) && !strings.Contains(msg.Text, want) {
				t.Errorf("%s: %q not rendered", lang, want)
			}
		}
		if !strings.Contains(msg.Text, c.FeedbackButton+": https://app.example.test/you/feature-board") {
			t.Errorf("%s: text lacks the localized feedback link", lang)
		}
	}

	for _, fallback := range []string{"", "it", "EN", "de-DE"} {
		if got := RenderReengagement(fallback, "", links).Subject; got != reengagementCopies["en"].Subject {
			t.Errorf("language %q: subject %q, want the English fallback", fallback, got)
		}
	}
}

func TestChromeCopies_CoverEverySupportedLanguage(t *testing.T) {
	if len(chromeCopies) != len(validation.SupportedLanguages) {
		t.Errorf("chrome for %d languages, app supports %d", len(chromeCopies), len(validation.SupportedLanguages))
	}
	for _, lang := range validation.SupportedLanguages {
		c, ok := chromeCopies[lang]
		if !ok {
			t.Errorf("no email chrome for %q", lang)
			continue
		}
		v := reflect.ValueOf(c)
		for i := 0; i < v.NumField(); i++ {
			if strings.TrimSpace(v.Field(i).String()) == "" {
				t.Errorf("%s: %s is empty", lang, v.Type().Field(i).Name)
			}
		}
		if strings.Count(c.Greeting, "%s") != 1 {
			t.Errorf("%s: greeting %q must take exactly one name", lang, c.Greeting)
		}
		if strings.Count(c.EmailCounter, "%d") != 2 {
			t.Errorf("%s: counter %q must take position and total", lang, c.EmailCounter)
		}
	}
}

func TestStepTranslations_CoverEveryStepAndTip(t *testing.T) {
	for _, lang := range validation.SupportedLanguages {
		if lang == "en" {
			continue // English is the copy on Steps itself.
		}
		byKey, ok := stepTranslations[lang]
		if !ok {
			t.Errorf("no step translations for %q", lang)
			continue
		}
		if len(byKey) != len(Steps) {
			t.Errorf("%s: %d translated steps, series has %d", lang, len(byKey), len(Steps))
		}
		for _, step := range Steps {
			c, ok := byKey[step.Key]
			if !ok {
				t.Errorf("%s: step %q untranslated", lang, step.Key)
				continue
			}
			for name, v := range map[string]string{"Subject": c.Subject, "Eyebrow": c.Eyebrow, "Heading": c.Heading, "Intro": c.Intro, "HeroAlt": c.HeroAlt, "CTALabel": c.CTALabel} {
				if strings.TrimSpace(v) == "" {
					t.Errorf("%s/%s: %s is empty", lang, step.Key, name)
				}
			}
			if len(c.Tips) != len(step.Tips) {
				t.Errorf("%s/%s: %d tips, English has %d", lang, step.Key, len(c.Tips), len(step.Tips))
			}
			for i, tip := range c.Tips {
				if strings.TrimSpace(tip.Title) == "" || strings.TrimSpace(tip.Body) == "" {
					t.Errorf("%s/%s: tip %d missing copy", lang, step.Key, i)
				}
			}
		}
	}
}

func TestRender_UsesStoredLanguage(t *testing.T) {
	links := Links{
		AppURL:         "https://app.example.test",
		HeroURL:        "https://api.example.test/api/v1/email/assets/day7-money.jpg",
		UnsubscribeURL: "https://api.example.test/api/v1/email/unsubscribe?token=abc",
	}
	step := Steps[2]
	for _, lang := range validation.SupportedLanguages {
		want := Localize(step, lang)
		chrome := chromeCopies[lang]
		msg := Render(step, lang, "Ada", links)
		if msg.Subject != want.Subject {
			t.Errorf("%s: subject %q, want %q", lang, msg.Subject, want.Subject)
		}
		if lang != "en" && msg.Subject == step.Subject {
			t.Errorf("%s: subject left in English", lang)
		}
		if !strings.Contains(msg.HTML, `<html lang="`+lang+`"`) {
			t.Errorf("%s: html lang attribute missing", lang)
		}
		if !strings.Contains(msg.HTML, template.HTMLEscapeString(fmt.Sprintf(chrome.EmailCounter, 3, len(Steps)))) {
			t.Errorf("%s: series marker missing", lang)
		}
		if !strings.Contains(msg.Text, fmt.Sprintf(chrome.Greeting, "Ada")) {
			t.Errorf("%s: greeting missing", lang)
		}
		// Tips keep their links in every language.
		for i, tip := range step.Tips {
			url := "https://app.example.test" + tip.Path
			if !strings.Contains(msg.Text, chrome.Open+": "+url) {
				t.Errorf("%s: tip %d lost its link", lang, i)
			}
			if !strings.Contains(msg.Text, strings.ToUpper(want.Tips[i].Title)) {
				t.Errorf("%s: tip %d title not translated", lang, i)
			}
		}
		if !strings.Contains(msg.HTML, links.UnsubscribeURL) || !strings.Contains(msg.Text, links.UnsubscribeURL) {
			t.Errorf("%s: unsubscribe link missing", lang)
		}
	}
	if got := Render(step, "it", "", links).Subject; got != step.Subject {
		t.Errorf("unsupported language: subject %q, want the English", got)
	}
}
