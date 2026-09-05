package services

import (
	"bytes"
	"fmt"
	"html/template"
	"net/url"
	"strings"
)

// The two account emails a person actually reads: the sign-up verification and
// the password reset. Both carry a short code (for typing into the app) and a
// link (for opening it in one tap). The HTML follows the app's neo-brutalist
// desk: warm paper, 2px ink borders, flat offset shadows, one orange button,
// the code on a sticky note. Everything is inline-styled table layout because
// mail clients render nothing else reliably; the offset shadow is an outer
// cell painted ink with padding on the right and bottom only, so it works
// where box-shadow does not.
//
// A plain-text alternative always goes with it. Tests read the code from the
// "code is: XXXXXXXX" line, and text-only clients and spam filters both want
// something other than markup.

// authEmail is a rendered message ready for MailService.SendHTML.
type authEmail struct {
	Subject string
	HTML    string
	Text    string
}

// authEmailData feeds the shared layout template.
type authEmailData struct {
	Preheader   string
	Eyebrow     string
	Heading     string
	Intro       string
	CodeLabel   string
	Code        string
	ButtonLabel string
	Link        string
	LinkHint    string
	Expiry      string
	Unrequested string
}

// codeExpiryMinutes mirrors newEmailVerificationToken; both emails use it.
const codeExpiryMinutes = 30

var authEmailTemplate = template.Must(template.New("auth-email").Parse(`<!DOCTYPE html>
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
    .code { font-size: 26px !important; letter-spacing: 0.14em !important; }
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

                  <h1 class="h1" style="margin:20px 0 12px;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:32px;line-height:36px;font-weight:700;letter-spacing:-0.03em;color:#1a1714;">{{.Heading}}</h1>
                  <p style="margin:0 0 26px;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:16px;line-height:24px;color:#453d36;">{{.Intro}}</p>

                  <!-- Code on a sticky note -->
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0">
                    <tr>
                      <td style="background:#1a1714;padding:0 5px 5px 0;">
                        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#fff9c4;border:2px solid #1a1714;">
                          <tr>
                            <td align="center" style="padding:18px 16px 20px;">
                              <div style="font-family:'JetBrains Mono',Menlo,Consolas,monospace;font-size:11px;line-height:14px;font-weight:700;letter-spacing:0.14em;text-transform:uppercase;color:#5d4037;">{{.CodeLabel}}</div>
                              <div class="code" style="margin-top:8px;font-family:'JetBrains Mono',Menlo,Consolas,monospace;font-size:32px;line-height:40px;font-weight:700;letter-spacing:0.2em;color:#1a1714;">{{.Code}}</div>
                            </td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                  </table>

                  {{if .Link}}
                  <!-- Button with flat offset shadow -->
                  <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:28px auto 0;">
                    <tr>
                      <td style="background:#1a1714;padding:0 5px 5px 0;">
                        <a href="{{.Link}}" style="display:block;background:#f97316;border:2px solid #1a1714;padding:14px 26px;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:16px;line-height:20px;font-weight:700;color:#1a1714;text-decoration:none;text-align:center;">{{.ButtonLabel}} &rarr;</a>
                      </td>
                    </tr>
                  </table>
                  <p style="margin:22px 0 0;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:13px;line-height:19px;color:#453d36;text-align:center;">{{.LinkHint}}<br><a href="{{.Link}}" style="color:#c2410c;word-break:break-all;">{{.Link}}</a></p>
                  {{end}}

                  <!-- Dashed rule -->
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:28px;">
                    <tr><td style="border-top:2px dashed #bab1a1;font-size:0;line-height:0;">&nbsp;</td></tr>
                  </table>

                  <p style="margin:16px 0 0;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:13px;line-height:19px;color:#453d36;">{{.Expiry}} {{.Unrequested}}</p>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Footer -->
        <tr>
          <td style="padding:22px 2px 0;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:12px;line-height:18px;color:#453d36;">
            mitlist &middot; the shared household desk: lists, money, chores, recipes.<br>
            <a href="https://mitlist.me" style="color:#453d36;">mitlist.me</a>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
</body>
</html>
`))

func renderAuthEmail(subject string, data authEmailData, text string) authEmail {
	var buf bytes.Buffer
	if err := authEmailTemplate.Execute(&buf, data); err != nil {
		// The template is a compile-time constant and the data is plain
		// strings; execution cannot fail in practice. Fall back to the text
		// body so a person still gets their code.
		return authEmail{Subject: subject, HTML: "<pre>" + template.HTMLEscapeString(text) + "</pre>", Text: text}
	}
	return authEmail{Subject: subject, HTML: buf.String(), Text: text}
}

// authLink joins the web app origin and an in-app path with the code in the
// query. Empty when no origin is configured (self-hosts without a web app),
// in which case the emails carry the code alone.
func authLink(frontendURL, path, code string) string {
	if frontendURL == "" {
		return ""
	}
	return strings.TrimRight(frontendURL, "/") + path + "?token=" + url.QueryEscape(code)
}

// verificationEmail is the message that proves a new account's address.
// The link opens /verify in the web app, which hands over to the installed
// app on phones; the code alone still works in the sign-up screen.
func verificationEmail(code, frontendURL string) authEmail {
	link := authLink(frontendURL, "/verify", code)
	text := "Your email verification code is: " + code + "\n"
	if link != "" {
		text += "\nOr open this link to verify in one tap:\n" + link + "\n"
	}
	text += fmt.Sprintf("\nThe code expires in %d minutes. If you did not create a mitlist account, ignore this email.\n", codeExpiryMinutes)
	return renderAuthEmail("Verify your mitlist account", authEmailData{
		Preheader:   "Your mitlist verification code is " + code,
		Eyebrow:     "New account",
		Heading:     "One tap and you're in",
		Intro:       "Confirm this is your address and your mitlist account is ready. Open the app with the button, or type the code into the sign-up screen.",
		CodeLabel:   "Your code",
		Code:        code,
		ButtonLabel: "Verify in mitlist",
		Link:        link,
		LinkHint:    "Button not working? Paste this link into your browser:",
		Expiry:      fmt.Sprintf("The code expires in %d minutes.", codeExpiryMinutes),
		Unrequested: "Didn't create a mitlist account? Ignore this email and nothing happens.",
	}, text)
}

// passwordResetEmail carries a recovery code. Opening the link lands on the
// app's reset screen with the code filled in; setting a new password there
// signs the person straight in.
func passwordResetEmail(code, frontendURL string) authEmail {
	link := authLink(frontendURL, "/reset-password", code)
	text := "Your password reset code is: " + code + "\n"
	if link != "" {
		text += "\nOr open this link to choose a new password:\n" + link + "\n"
	}
	text += fmt.Sprintf("\nThe code expires in %d minutes. If you did not ask to reset your password, ignore this email; your password stays as it is.\n", codeExpiryMinutes)
	return renderAuthEmail("Reset your mitlist password", authEmailData{
		Preheader:   "Your mitlist password reset code is " + code,
		Eyebrow:     "Password reset",
		Heading:     "Let's get you back in",
		Intro:       "Someone asked to reset the password for this mitlist account. Open the app with the button to choose a new one, or type the code into the reset form.",
		CodeLabel:   "Reset code",
		Code:        code,
		ButtonLabel: "Reset password in mitlist",
		Link:        link,
		LinkHint:    "Button not working? Paste this link into your browser:",
		Expiry:      fmt.Sprintf("The code expires in %d minutes.", codeExpiryMinutes),
		Unrequested: "Didn't ask for this? Ignore this email; your password stays as it is.",
	}, text)
}

// sendVerificationEmail delivers the verification code to an address. Shared
// by registration, resend, and the guest-to-account upgrade.
func sendVerificationEmail(mail MailService, to, code, frontendURL string) error {
	msg := verificationEmail(code, frontendURL)
	return mail.SendHTML(to, msg.Subject, msg.HTML, msg.Text)
}

func sendPasswordResetEmail(mail MailService, to, code, frontendURL string) error {
	msg := passwordResetEmail(code, frontendURL)
	return mail.SendHTML(to, msg.Subject, msg.HTML, msg.Text)
}
