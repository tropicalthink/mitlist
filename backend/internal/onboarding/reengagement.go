package onboarding

import (
	"bytes"
	"fmt"
	"html/template"
	"strings"
	"time"
)

// The re-engagement check-in is a single email to someone who has stopped
// opening the app: no tips, one question. It shares the series' opt-out (the
// tips switch and the same unsubscribe link), because to the reader it is the
// same kind of mail from the same product.
const (
	// ReengagementAfter is how long without opening the app before the
	// check-in goes out.
	ReengagementAfter = 7 * 24 * time.Hour
	// ReengagementMaxIdle bounds the audience from the other side: someone
	// who left months ago did not ask to hear from us and gets nothing.
	ReengagementMaxIdle = 90 * 24 * time.Hour
	// ReengagementCooldown is the minimum gap between two check-ins to the
	// same person, however often they drift away and come back.
	ReengagementCooldown = 90 * 24 * time.Hour

	// FeedbackPath is the in-app feedback board. The web app origin claims
	// it for the installed apps (Android App Links, iOS associated domains),
	// so on a phone the button opens the app on the board.
	FeedbackPath = "/you/feature-board"
	// PlayStoreURL is the store listing. iOS is TestFlight-only, so Google
	// Play is the one store a person can rate mitlist in today.
	PlayStoreURL = "https://play.google.com/store/apps/details?id=me.mitlist"
)

// ReengagementLinks is what the check-in needs beyond its copy.
type ReengagementLinks struct {
	AppURL         string
	UnsubscribeURL string
	// ShowRating adds the Google Play button. Only for people with an
	// Android device, since nobody else can open the listing usefully.
	ShowRating bool
}

type reengagementData struct {
	Lang           string
	Copy           reengagementCopy
	Chrome         chromeCopy
	Greeting       string
	FeedbackURL    string
	RateURL        string
	UnsubscribeURL string
}

// reengagementCopy is the check-in's own text in one language; the greeting
// and footer come from chromeCopies (see i18n.go).
type reengagementCopy struct {
	Subject        string
	Preheader      string
	Eyebrow        string
	Heading        string
	Intro          string
	Ask            string
	FeedbackButton string
	RateAsk        string
	RateButton     string
	// FooterLead leads into the shared unsubscribe link and account note;
	// TextFooterLead is the plain-text version, followed by the bare URL.
	FooterLead     string
	TextFooterLead string
}

// reengagementCopies covers validation.SupportedLanguages; anything else,
// including a person whose app has not reported a language, gets English.
var reengagementCopies = map[string]reengagementCopy{
	"en": {
		Subject:        "Got a minute? Tell us what to fix",
		Preheader:      "We would love to hear what got in the way.",
		Eyebrow:        "Check-in",
		Heading:        "What would make mitlist worth opening again?",
		Intro:          "It has been a little while since you opened mitlist. We are a small team and we build what people ask for, so we would love to hear what got in the way.",
		Ask:            "Something missing, something clumsy, something you would change: put it on the feature board. We read every post, and you can vote on what others have asked for.",
		FeedbackButton: "Share feedback",
		RateAsk:        "Liked it while you used it? A rating on Google Play helps other households find us.",
		RateButton:     "Rate us on Google Play",
		FooterLead:     "You get this because you have a mitlist account. We send it at most once every few months; to stop it and the tips emails,",
		TextFooterLead: "You get this because you have a mitlist account. We send it at most once every few months; to stop it and the tips emails, open this link:",
	},
	"de": {
		Subject:        "Hast du kurz Zeit? Sag uns, was wir besser machen sollen",
		Preheader:      "Wir würden gern hören, was dich ausgebremst hat.",
		Eyebrow:        "Nachgefragt",
		Heading:        "Was würde mitlist für dich wieder lohnenswert machen?",
		Intro:          "Du hast mitlist schon eine Weile nicht mehr geöffnet. Wir sind ein kleines Team und bauen, was sich die Leute wünschen – deshalb würden wir gern hören, was dir im Weg stand.",
		Ask:            "Fehlt dir etwas, ist etwas umständlich, würdest du etwas ändern? Schreib es aufs Feature-Board. Wir lesen jeden Beitrag, und du kannst für die Wünsche anderer abstimmen.",
		FeedbackButton: "Feedback geben",
		RateAsk:        "Hat dir mitlist gefallen? Eine Bewertung bei Google Play hilft anderen Haushalten, uns zu finden.",
		RateButton:     "Bei Google Play bewerten",
		FooterLead:     "Du bekommst diese E-Mail, weil du ein mitlist-Konto hast. Wir schicken sie höchstens alle paar Monate. Wenn du sie und die Tipps per E-Mail nicht mehr möchtest,",
		TextFooterLead: "Du bekommst diese E-Mail, weil du ein mitlist-Konto hast. Wir schicken sie höchstens alle paar Monate. Wenn du sie und die Tipps per E-Mail nicht mehr möchtest, öffne diesen Link:",
	},
	"es": {
		Subject:        "¿Tienes un minuto? Dinos qué mejorar",
		Preheader:      "Nos encantaría saber qué te frenó.",
		Eyebrow:        "¿Qué tal?",
		Heading:        "¿Qué haría que volvieras a abrir mitlist?",
		Intro:          "Hace un tiempo que no abres mitlist. Somos un equipo pequeño y construimos lo que la gente nos pide, así que nos encantaría saber qué te frenó.",
		Ask:            "¿Echas algo en falta, hay algo incómodo, cambiarías algo? Cuéntalo en el tablero de funciones. Leemos todas las publicaciones y puedes votar lo que otros han pedido.",
		FeedbackButton: "Enviar comentarios",
		RateAsk:        "¿Te gustó mientras lo usabas? Una valoración en Google Play ayuda a otros hogares a encontrarnos.",
		RateButton:     "Valóranos en Google Play",
		FooterLead:     "Recibes este correo porque tienes una cuenta de mitlist. Lo enviamos como mucho una vez cada pocos meses; para no recibirlo más, ni tampoco los consejos por correo,",
		TextFooterLead: "Recibes este correo porque tienes una cuenta de mitlist. Lo enviamos como mucho una vez cada pocos meses; para no recibirlo más, ni tampoco los consejos por correo, abre este enlace:",
	},
	"fr": {
		Subject:        "Une minute\u00a0? Dites-nous quoi améliorer",
		Preheader:      "Nous aimerions savoir ce qui vous a freiné.",
		Eyebrow:        "Des nouvelles",
		Heading:        "Qu'est-ce qui vous donnerait envie de rouvrir mitlist\u00a0?",
		Intro:          "Cela fait un moment que vous n'avez pas ouvert mitlist. Nous sommes une petite équipe et nous développons ce que les gens nous demandent\u00a0: nous aimerions donc savoir ce qui vous a freiné.",
		Ask:            "Il vous manque quelque chose, quelque chose n'est pas pratique, vous changeriez quelque chose\u00a0? Dites-le sur le tableau des fonctionnalités. Nous lisons chaque message, et vous pouvez voter pour les demandes des autres.",
		FeedbackButton: "Donner mon avis",
		RateAsk:        "Vous l'avez apprécié\u00a0? Une note sur Google Play aide d'autres foyers à nous trouver.",
		RateButton:     "Nous noter sur Google Play",
		FooterLead:     "Vous recevez cet e-mail parce que vous avez un compte mitlist. Nous l'envoyons au plus une fois tous les quelques mois\u00a0; pour ne plus le recevoir, ni les conseils par e-mail,",
		TextFooterLead: "Vous recevez cet e-mail parce que vous avez un compte mitlist. Nous l'envoyons au plus une fois tous les quelques mois\u00a0; pour ne plus le recevoir, ni les conseils par e-mail, ouvrez ce lien\u00a0:",
	},
	"nl": {
		Subject:        "Heb je even? Vertel ons wat beter kan",
		Preheader:      "We horen graag wat je tegenhield.",
		Eyebrow:        "Even checken",
		Heading:        "Wat zou mitlist weer de moeite waard maken?",
		Intro:          "Je hebt mitlist al een tijdje niet geopend. We zijn een klein team en bouwen wat mensen vragen, dus we horen graag wat je tegenhield.",
		Ask:            "Mis je iets, werkt iets onhandig, zou je iets veranderen? Zet het op het functiebord. We lezen elk bericht en je kunt stemmen op wat anderen hebben gevraagd.",
		FeedbackButton: "Feedback geven",
		RateAsk:        "Vond je het fijn toen je het gebruikte? Een beoordeling in Google Play helpt andere huishoudens ons te vinden.",
		RateButton:     "Beoordeel ons in Google Play",
		FooterLead:     "Je krijgt deze e-mail omdat je een mitlist-account hebt. We sturen hem hooguit eens in de paar maanden. Wil je hem en de tips per e-mail niet meer ontvangen,",
		TextFooterLead: "Je krijgt deze e-mail omdat je een mitlist-account hebt. We sturen hem hooguit eens in de paar maanden. Wil je hem en de tips per e-mail niet meer ontvangen, open dan deze link:",
	},
}

var reengagementTemplate = template.Must(template.New("reengagement-email").Parse(`<!DOCTYPE html>
<html lang="{{.Lang}}" xmlns="http://www.w3.org/1999/xhtml">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta name="color-scheme" content="light">
<meta name="supported-color-schemes" content="light">
<title>{{.Copy.Heading}}</title>
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
<div style="display:none;font-size:1px;line-height:1px;max-height:0;max-width:0;opacity:0;overflow:hidden;mso-hide:all;">{{.Copy.Preheader}}</div>
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

                  <table role="presentation" cellpadding="0" cellspacing="0" border="0"><tr><td style="background:#f97316;border:2px solid #1a1714;padding:4px 10px;font-family:'JetBrains Mono',Menlo,Consolas,monospace;font-size:11px;line-height:14px;font-weight:700;letter-spacing:0.14em;text-transform:uppercase;color:#1a1714;">{{.Copy.Eyebrow}}</td></tr></table>

                  <h1 class="h1" style="margin:20px 0 12px;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:32px;line-height:36px;font-weight:700;letter-spacing:-0.03em;color:#1a1714;">{{.Copy.Heading}}</h1>
                  <p style="margin:0 0 16px;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:16px;line-height:24px;color:#453d36;">{{if .Greeting}}{{.Greeting}} {{end}}{{.Copy.Intro}}</p>
                  <p style="margin:0;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:16px;line-height:24px;color:#453d36;">{{.Copy.Ask}}</p>

                  <!-- Primary action: the feedback board -->
                  <table role="presentation" cellpadding="0" cellspacing="0" border="0" style="margin:28px auto 0;">
                    <tr>
                      <td style="background:#1a1714;padding:0 5px 5px 0;">
                        <a href="{{.FeedbackURL}}" style="display:block;background:#f97316;border:2px solid #1a1714;padding:14px 26px;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:16px;line-height:20px;font-weight:700;color:#1a1714;text-decoration:none;text-align:center;">{{.Copy.FeedbackButton}} &rarr;</a>
                      </td>
                    </tr>
                  </table>

                  {{if .RateURL}}
                  <!-- Secondary action on a sticky note: rate on Google Play -->
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:28px;">
                    <tr>
                      <td style="background:#1a1714;padding:0 5px 5px 0;">
                        <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="background:#fff9c4;border:2px solid #1a1714;">
                          <tr>
                            <td style="padding:14px 16px 16px;">
                              <div style="font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:15px;line-height:22px;color:#1a1714;">{{.Copy.RateAsk}}</div>
                              <a href="{{.RateURL}}" style="display:inline-block;margin-top:10px;font-family:'JetBrains Mono',Menlo,Consolas,monospace;font-size:11px;line-height:14px;font-weight:700;letter-spacing:0.14em;text-transform:uppercase;color:#c2410c;text-decoration:underline;">{{.Copy.RateButton}} &rarr;</a>
                            </td>
                          </tr>
                        </table>
                      </td>
                    </tr>
                  </table>
                  {{end}}

                  <!-- Dashed rule -->
                  <table role="presentation" width="100%" cellpadding="0" cellspacing="0" border="0" style="margin-top:28px;">
                    <tr><td style="border-top:2px dashed #bab1a1;font-size:0;line-height:0;">&nbsp;</td></tr>
                  </table>

                  <p style="margin:16px 0 0;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:13px;line-height:19px;color:#453d36;">{{.Copy.FooterLead}} <a href="{{.UnsubscribeURL}}" style="color:#c2410c;">{{.Chrome.UnsubscribeLink}}</a>. {{.Chrome.AccountNote}}</p>
                </td>
              </tr>
            </table>
          </td>
        </tr>

        <!-- Footer -->
        <tr>
          <td style="padding:22px 2px 0;font-family:'Space Grotesk',Helvetica,Arial,sans-serif;font-size:12px;line-height:18px;color:#453d36;">
            mitlist &middot; {{.Chrome.Tagline}}<br>
            <a href="https://mitlist.me" style="color:#453d36;">mitlist.me</a> &middot; <a href="{{.UnsubscribeURL}}" style="color:#453d36;">{{.Chrome.Unsubscribe}}</a>
          </td>
        </tr>
      </table>
    </td>
  </tr>
</table>
</body>
</html>
`))

// RenderReengagement produces the check-in for one person in their stored
// language (English when it is empty or unsupported). firstName may be empty;
// the greeting is dropped rather than saying "Hi ,".
func RenderReengagement(language, firstName string, links ReengagementLinks) Email {
	lang := languageFor(language)
	c := reengagementCopies[lang]
	chrome := chromeCopies[lang]
	feedbackURL := joinURL(links.AppURL, FeedbackPath)
	rateURL := ""
	if links.ShowRating {
		rateURL = PlayStoreURL
	}
	greeting := ""
	if name := strings.TrimSpace(firstName); name != "" {
		greeting = fmt.Sprintf(chrome.Greeting, name)
	}

	var text strings.Builder
	text.WriteString(c.Heading + "\n\n")
	if greeting != "" {
		text.WriteString(greeting + " ")
	}
	text.WriteString(c.Intro + "\n\n" + c.Ask + "\n")
	text.WriteString("\n" + c.FeedbackButton + ": " + feedbackURL + "\n")
	if rateURL != "" {
		text.WriteString("\n" + c.RateAsk + "\n" + c.RateButton + ": " + rateURL + "\n")
	}
	text.WriteString("\n" + c.TextFooterLead + "\n" + links.UnsubscribeURL + "\n" + chrome.AccountNote + "\n")

	var buf bytes.Buffer
	err := reengagementTemplate.Execute(&buf, reengagementData{
		Lang:           lang,
		Copy:           c,
		Chrome:         chrome,
		Greeting:       greeting,
		FeedbackURL:    feedbackURL,
		RateURL:        rateURL,
		UnsubscribeURL: links.UnsubscribeURL,
	})
	html := buf.String()
	if err != nil {
		// Constant template, plain-string data: cannot fail in practice.
		html = "<pre>" + template.HTMLEscapeString(text.String()) + "</pre>"
	}
	return Email{
		Subject:        c.Subject,
		HTML:           html,
		Text:           text.String(),
		UnsubscribeURL: links.UnsubscribeURL,
	}
}
