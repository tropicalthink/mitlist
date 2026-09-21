package handlers

import (
	"bytes"
	"fmt"
	"html/template"
	"strings"
)

// The invitation a mobile-beta signup gets once their platform's app is
// actually installable: one link to the store listing, three things to do
// after installing, and a reminder of why the email arrived. Same desk as
// the account emails (warm paper, 2px ink borders, flat offset shadows, one
// orange button), all inline table layout because mail clients render
// nothing else reliably.

// testingInviteEmail is a rendered invitation ready for the mailer.
type testingInviteEmail struct {
	Subject string
	HTML    string
	Text    string
}

type testingInviteStep struct {
	Title string
	Body  string
}

type testingInviteData struct {
	Preheader   string
	Eyebrow     string
	Heading     string
	Intro       string
	ButtonLabel string
	StoreURL    string
	LinkHint    string
	StepsLabel  string
	FeedbackURL string
	SignupURL   string
	ContactMail string
}

const (
	testingInviteFeedbackURL = "https://feedback.mitlist.me"
	testingInviteSignupURL   = "https://mitlist.me/mobile-beta"
	testingInviteContactMail = "hi@mitlist.me"
)

var testingInviteTemplate = template.Must(template.New("testing-invite").Parse(`<!DOCTYPE html>
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
    .h1 { font-size: 30px !important; line-height: 34px !important; }
    .step-num { width: 36px !important; }
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
              <tr>
                <td class="card-pad" style="padding:34px 36px 30px;">

                  <!-- Eyebrow chip -->
                  <table role="presentation" cellpadding="0" cellspacing="0" border="0">
                    <tr>
                      <td style="background:#f97316;border:2px solid #1a1714;padding:4px 10px;font-family:'JetBrains Mono',Menlo,Consolas,monospace;font-size:11px;line-height:14px;font-weight:700;letter-spacing:0.14em;text-transform:uppercase;color:#1a1714;">{{.Eyebrow}}</td>
                    </tr>
                  </table>

                  <h1 class="h1" style="margin:20px 0 12px;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:36px;line-height:40px;font-weight:700;letter-spacing:-0.03em;color:#1a1714;">{{.Heading}}</h1>
                  <p style="margin:0 0 24px;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:16px;line-height:24px;color:#453d36;">{{.Intro}}</p>

                  <!-- Button with flat offset shadow -->
                  <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:0 auto;">
                    <tr>
                      <td style="background:#1a1714;padding:0 5px 5px 0;">
                        <a href="{{.StoreURL}}" style="display:block;background:#f97316;border:2px solid #1a1714;padding:16px 30px;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:17px;line-height:20px;font-weight:700;color:#1a1714;text-decoration:none;text-align:center;">{{.ButtonLabel}} &rarr;</a>
                      </td>
                    </tr>
                  </table>
                  <p style="margin:18px 0 0;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:13px;line-height:19px;color:#453d36;text-align:center;">{{.LinkHint}}<br><a href="{{.StoreURL}}" style="color:#c2410c;word-break:break-all;">{{.StoreURL}}</a></p>

                  <!-- Steps on a sticky note -->
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:28px;">
                    <tr>
                      <td style="background:#1a1714;padding:0 5px 5px 0;">
                        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#fff9c4;border:2px solid #1a1714;">
                          <tr>
                            <td style="padding:18px 20px 8px;">
                              <div style="font-family:'JetBrains Mono',Menlo,Consolas,monospace;font-size:11px;line-height:14px;font-weight:700;letter-spacing:0.14em;text-transform:uppercase;color:#5d4037;">{{.StepsLabel}}</div>
                              <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:8px;">
                                {{range $i, $s := .Steps}}
                                <tr>
                                  <td class="step-num" valign="top" style="width:44px;padding:8px 0 10px;font-family:'JetBrains Mono',Menlo,Consolas,monospace;font-size:26px;line-height:30px;font-weight:700;color:#f97316;">{{$s.Number}}</td>
                                  <td valign="top" style="padding:8px 0 10px;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:15px;line-height:22px;color:#1a1714;">
                                    <strong style="display:block;font-size:16px;line-height:22px;">{{$s.Title}}</strong>
                                    <span style="color:#453d36;">{{$s.Body}}</span>
                                  </td>
                                </tr>
                                {{end}}
                              </table>
                            </td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                  </table>

                  <!-- Dashed rule -->
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:28px;">
                    <tr><td style="border-top:2px dashed #bab1a1;font-size:0;line-height:0;">&nbsp;</td></tr>
                  </table>

                  <p style="margin:16px 0 0;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:13px;line-height:19px;color:#453d36;">You asked for this invitation at <a href="{{.SignupURL}}" style="color:#c2410c;">mitlist.me/mobile-beta</a>. It is the one email the signup promised; we will not write again about the test unless you also asked for launch news. Questions, bugs, ideas: reply to this email or write to <a href="mailto:{{.ContactMail}}" style="color:#c2410c;">{{.ContactMail}}</a>.</p>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Footer -->
        <tr>
          <td style="padding:22px 2px 0;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:12px;line-height:18px;color:#453d36;">
            mitlist &middot; the shared household desk: lists, money, chores, recipes.<br>
            <a href="https://mitlist.me" style="color:#453d36;">mitlist.me</a> &middot; <a href="{{.FeedbackURL}}" style="color:#453d36;">feedback &amp; roadmap</a>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
</body>
</html>
`))

// numberedStep is what the template iterates over: the step plus its
// display number, because range indexes start at zero.
type numberedStep struct {
	Number int
	Title  string
	Body   string
}

// renderTestingInvite builds the invitation for one platform. storeURL is the
// listing to install from; the caller has checked it is set.
func renderTestingInvite(platform, storeURL string) testingInviteEmail {
	var (
		subject, preheader, eyebrow, heading, intro, button string
		steps                                               []testingInviteStep
	)
	switch platform {
	case "ios":
		subject = "Your mitlist iOS invitation is here"
		preheader = "mitlist is ready for your iPhone. Install it from TestFlight."
		eyebrow = "iOS beta"
		heading = "mitlist is ready for your iPhone"
		intro = "Thanks for waiting. The iOS app is in TestFlight now, and this is your invitation to try it with the people you live with."
		button = "Install with TestFlight"
		steps = []testingInviteStep{
			{"Install TestFlight, then mitlist", "The button opens Apple's TestFlight, which installs the app and keeps it updated as we ship."},
			{"Sign in or create your household", "Your web account works as is. New here? Make a household and invite the others from the You tab."},
			{"Tell us what is off", "Shake-worthy bugs, missing features, odd wording: everything is welcome at feedback.mitlist.me."},
		}
	default:
		subject = "Your mitlist Android invitation is here"
		preheader = "mitlist is on Google Play. Install it and bring your household along."
		eyebrow = "Now on Google Play"
		heading = "mitlist is ready for your Android phone"
		intro = "Thanks for waiting. mitlist is on Google Play now, and this is your invitation to try it with the people you live with: lists, money, chores and recipes in one place."
		button = "Get it on Google Play"
		steps = []testingInviteStep{
			{"Install from Google Play", "The button opens the listing. Use the Google account whose email you signed up with if the page says the app is not available."},
			{"Sign in or create your household", "Your web account works as is. New here? Make a household and invite the others from the You tab."},
			{"Tell us what is off", "Bugs, missing features, odd wording: everything is welcome at feedback.mitlist.me. The scanner is the part we are most curious about."},
		}
	}

	numbered := make([]numberedStep, len(steps))
	var text strings.Builder
	fmt.Fprintf(&text, "%s\n\n%s\n\n%s:\n%s\n\n", heading, intro, button, storeURL)
	for i, s := range steps {
		numbered[i] = numberedStep{Number: i + 1, Title: s.Title, Body: s.Body}
		fmt.Fprintf(&text, "%s\n%s\n\n", s.Title, s.Body)
	}
	fmt.Fprintf(&text, "You asked for this invitation at %s. It is the one email the signup promised. Questions, bugs, ideas: reply to this email or write to %s.\n\nFeedback and roadmap: %s\n", testingInviteSignupURL, testingInviteContactMail, testingInviteFeedbackURL)

	data := struct {
		testingInviteData
		Steps []numberedStep
	}{
		testingInviteData: testingInviteData{
			Preheader:   preheader,
			Eyebrow:     eyebrow,
			Heading:     heading,
			Intro:       intro,
			ButtonLabel: button,
			StoreURL:    storeURL,
			LinkHint:    "If the button does not work, open this link on your phone:",
			StepsLabel:  "After installing",
			FeedbackURL: testingInviteFeedbackURL,
			SignupURL:   testingInviteSignupURL,
			ContactMail: testingInviteContactMail,
		},
		Steps: numbered,
	}
	var buf bytes.Buffer
	if err := testingInviteTemplate.Execute(&buf, data); err != nil {
		return testingInviteEmail{Subject: subject, HTML: "<pre>" + template.HTMLEscapeString(text.String()) + "</pre>", Text: text.String()}
	}
	return testingInviteEmail{Subject: subject, HTML: buf.String(), Text: text.String()}
}
