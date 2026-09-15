package onboarding

import (
	"bytes"
	"fmt"
	"html/template"
	"strings"
)

// Email is a rendered step, ready for the mail service.
type Email struct {
	Subject string
	HTML    string
	Text    string
	// UnsubscribeURL is the same link the footer carries, exposed so the
	// sender can put it in List-Unsubscribe as well.
	UnsubscribeURL string
}

// Links is what a step needs beyond its own copy: where the app lives and
// where this person's unsubscribe link points.
type Links struct {
	AppURL         string
	HeroURL        string
	UnsubscribeURL string
}

type emailData struct {
	Preheader      string
	Eyebrow        string
	Heading        string
	Greeting       string
	Intro          string
	Tips           []Tip
	SeriesPosition int
	SeriesTotal    int
	HeroURL        string
	HeroAlt        string
	ButtonLabel    string
	ButtonURL      string
	UnsubscribeURL string
}

// The layout is the auth emails' desk — warm paper, 2px ink borders, flat
// offset shadows, one orange button — carried over so the series looks like
// it comes from the same product. Table layout and inline styles because mail
// clients render nothing else reliably.
var emailTemplate = template.Must(template.New("onboarding-email").Parse(`<!DOCTYPE html>
<html lang="en" xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light">
<meta name="supported-color-schemes" content="light">
<title>{{.Heading}}</title>
<link href="https://fonts.googleapis.com/css2?family=Space+Grotesk:wght@500;700&amp;family=JetBrains+Mono:wght@700&amp;display=swap" rel="stylesheet">
<style>
  body { margin:0; padding:0; background:#f7f4ec; -webkit-text-size-adjust:100%; }
  table { border-collapse:collapse; }
  a { color:#c2410c; }
  @media (max-width: 600px) {
    .wrap { padding: 20px 12px 32px !important; }
    .card-pad { padding: 26px 20px 24px !important; }
    .h1 { font-size: 26px !important; line-height: 30px !important; }
  }
</style>
</head>
<body style="margin:0;padding:0;background:#f7f4ec;">
<div style="display:none;font-size:1px;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;mso-hide:all;">{{.Preheader}}</div>
<table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#f7f4ec;">
  <tr>
    <td align="center" class="wrap" style="padding:36px 16px 44px;">
      <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="max-width:560px;">

        <!-- Wordmark -->
        <tr>
          <td style="padding:0 0 18px 2px;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;">
            <table role="presentation" cellpadding="0" cellspacing="0" border="0">
              <tr>
                <td style="width:14px;height:14px;background:#f97316;border:2px solid #1a1714;font-size:0;line-height:0;">&nbsp;</td>
                <td style="padding-left:10px;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:24px;line-height:24px;font-weight:700;letter-spacing:-0.03em;color:#1a1714;">mitlist</td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Card with flat offset shadow -->
        <tr>
          <td style="background:#1a1714;padding:0 7px 7px 0;">
            <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#fffcf7;border:2px solid #1a1714;">
              <!-- Static, content-specific illustration for this series step. -->
              <tr>
                <td style="background:#f7f4ec;border-bottom:2px solid #1a1714;">
                  <a href="{{.ButtonURL}}" style="display:block;text-decoration:none;">
                    <img src="{{.HeroURL}}" width="556" alt="{{.HeroAlt}}" style="display:block;width:100%;max-width:556px;height:auto;border:0;line-height:100%;">
                  </a>
                </td>
              </tr>
              <tr>
                <td class="card-pad" style="padding:34px 36px 30px;">

                  <!-- Eyebrow and series progress -->
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                    <tr>
                      <td align="left">
                        <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr><td style="background:#f97316;border:2px solid #1a1714;padding:4px 10px;font-family:'JetBrains Mono',Menlo,Consolas,monospace;font-size:11px;line-height:14px;font-weight:700;letter-spacing:0.14em;text-transform:uppercase;color:#1a1714;">{{.Eyebrow}}</td></tr></table>
                      </td>
                      <td align="right" style="font-family:'JetBrains Mono',Menlo,Consolas,monospace;font-size:11px;line-height:14px;font-weight:700;letter-spacing:0.08em;color:#5d4037;">EMAIL {{.SeriesPosition}} / {{.SeriesTotal}}</td>
                    </tr>
                  </table>

                  <h1 class="h1" style="margin:20px 0 12px;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:32px;line-height:36px;font-weight:700;letter-spacing:-0.03em;color:#1a1714;">{{.Heading}}</h1>
                  <p style="margin:0 0 22px;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:16px;line-height:24px;color:#453d36;">{{if .Greeting}}{{.Greeting}} {{end}}{{.Intro}}</p>

                  {{range .Tips}}
                  <!-- Tip on a sticky note -->
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:12px;">
                    <tr>
                      <td style="background:#1a1714;padding:0 5px 5px 0;">
                        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#fff9c4;border:2px solid #1a1714;">
                          <tr>
                            <td style="padding:14px 16px 16px;">
                              <div style="font-family:'JetBrains Mono',Menlo,Consolas,monospace;font-size:11px;line-height:14px;font-weight:700;letter-spacing:0.14em;text-transform:uppercase;color:#5d4037;">{{.Title}}</div>
                              <div style="margin-top:6px;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:15px;line-height:22px;color:#1a1714;">{{.Body}}</div>
                            </td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                  </table>
                  {{end}}

                  <!-- Action block and button with flat offset shadow -->
                  <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:28px auto 0;">
                    <tr>
                      <td align="center" style="padding:0 0 8px;font-family:'JetBrains Mono',Menlo,Consolas,monospace;font-size:11px;line-height:14px;font-weight:700;letter-spacing:0.14em;text-transform:uppercase;color:#5d4037;">Try it now</td>
                    </tr>
                    <tr>
                      <td style="background:#1a1714;padding:0 5px 5px 0;">
                        <a href="{{.ButtonURL}}" style="display:block;background:#f97316;border:2px solid #1a1714;padding:14px 26px;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:16px;line-height:20px;font-weight:700;color:#1a1714;text-decoration:none;text-align:center;">{{.ButtonLabel}} &rarr;</a>
                      </td>
                    </tr>
                  </table>

                  <!-- Dashed rule -->
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:28px;">
                    <tr><td style="border-top:2px dashed #bab1a1;font-size:0;line-height:0;">&nbsp;</td></tr>
                  </table>

                  <p style="margin:16px 0 0;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:13px;line-height:19px;color:#453d36;">You get these because you made a mitlist account. They stop after a few weeks; to stop them now, <a href="{{.UnsubscribeURL}}" style="color:#c2410c;">unsubscribe</a>. Account emails like password resets still arrive.</p>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Footer -->
        <tr>
          <td style="padding:22px 2px 0;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:12px;line-height:18px;color:#453d36;">
            mitlist &middot; the shared household desk: lists, money, chores, recipes.<br>
            <a href="https://mitlist.me" style="color:#453d36;">mitlist.me</a> &middot; <a href="{{.UnsubscribeURL}}" style="color:#453d36;">Unsubscribe</a>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
</body>
</html>
`))

// Render produces the HTML and plain-text bodies of a step for one person.
// firstName may be empty; the greeting is dropped rather than saying "Hi ,".
func Render(step Step, firstName string, links Links) Email {
	buttonURL := joinURL(links.AppURL, step.CTAPath)
	seriesPosition := 1
	for i, candidate := range Steps {
		if candidate.Key == step.Key {
			seriesPosition = i + 1
			break
		}
	}
	greeting := ""
	if name := strings.TrimSpace(firstName); name != "" {
		greeting = "Hi " + name + "."
	}

	var text strings.Builder
	text.WriteString(step.Heading + "\n\n")
	if greeting != "" {
		text.WriteString(greeting + " ")
	}
	text.WriteString(step.Intro + "\n")
	for _, tip := range step.Tips {
		text.WriteString("\n" + strings.ToUpper(tip.Title) + "\n" + tip.Body + "\n")
	}
	text.WriteString("\n" + step.CTALabel + ": " + buttonURL + "\n")
	text.WriteString("\nYou get these because you made a mitlist account. They stop after a few weeks; to stop them now, open this link:\n" + links.UnsubscribeURL + "\nAccount emails like password resets still arrive.\n")

	var buf bytes.Buffer
	err := emailTemplate.Execute(&buf, emailData{
		Preheader:      step.Intro,
		Eyebrow:        step.Eyebrow,
		Heading:        step.Heading,
		Greeting:       greeting,
		Intro:          step.Intro,
		Tips:           step.Tips,
		SeriesPosition: seriesPosition,
		SeriesTotal:    len(Steps),
		HeroURL:        links.HeroURL,
		HeroAlt:        step.HeroAlt,
		ButtonLabel:    step.CTALabel,
		ButtonURL:      buttonURL,
		UnsubscribeURL: links.UnsubscribeURL,
	})
	html := buf.String()
	if err != nil {
		// Constant template, plain-string data: cannot fail in practice. The
		// text body is still a complete message, so ship that.
		html = "<pre>" + template.HTMLEscapeString(text.String()) + "</pre>"
	}
	return Email{
		Subject:        step.Subject,
		HTML:           html,
		Text:           text.String(),
		UnsubscribeURL: links.UnsubscribeURL,
	}
}

// UnsubscribeURL builds the link a step's footer and List-Unsubscribe header
// carry: the public API origin plus the unsubscribe route and this person's
// token.
func UnsubscribeURL(publicAPIURL, apiPrefix, token string) string {
	return fmt.Sprintf("%s/v1/email/unsubscribe?token=%s", joinURL(publicAPIURL, apiPrefix), token)
}

// HeroURL is the public, cacheable static illustration used by one series step.
func HeroURL(publicAPIURL, apiPrefix, filename string) string {
	return joinURL(joinURL(publicAPIURL, apiPrefix), "/v1/email/assets/"+filename)
}
