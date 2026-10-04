package onboarding

// Every email in this package is written in the person's stored app language
// (users.language, one of validation.SupportedLanguages). No language on
// record yet, or one without copy, gets English. The wording follows the
// app's own translations (frontend/lib/l10n): the same names for tabs and
// features, and the same form of address (du, tú, vous, je).

// languageFor resolves a stored language to one the emails are written in.
func languageFor(language string) string {
	if _, ok := chromeCopies[language]; ok {
		return language
	}
	return "en"
}

// chromeCopy is the text around an email's content that every email in the
// package shares: greeting, opt-out, footer.
type chromeCopy struct {
	// Greeting is a format string for the first name ("Hi %s.").
	Greeting    string
	Tagline     string
	Unsubscribe string
	// UnsubscribeLink is the linked words at the end of an opt-out sentence;
	// AccountNote follows it.
	UnsubscribeLink string
	AccountNote     string

	// The tips series: the progress marker (a format string for position
	// and total), the label above the button, and the tip link label.
	EmailCounter string
	TryItNow     string
	Open         string
	// TipsFooterLead leads into UnsubscribeLink in HTML; TipsTextFooterLead
	// is the plain-text version, followed by the bare URL.
	TipsFooterLead     string
	TipsTextFooterLead string
}

var chromeCopies = map[string]chromeCopy{
	"en": {
		Greeting:           "Hi %s.",
		Tagline:            "the shared household desk: lists, money, chores, recipes.",
		Unsubscribe:        "Unsubscribe",
		UnsubscribeLink:    "unsubscribe",
		AccountNote:        "Account emails like password resets still arrive.",
		EmailCounter:       "EMAIL %d / %d",
		TryItNow:           "Try it now",
		Open:               "Open",
		TipsFooterLead:     "You get these because you made a mitlist account. They stop after a few weeks; to stop them now,",
		TipsTextFooterLead: "You get these because you made a mitlist account. They stop after a few weeks; to stop them now, open this link:",
	},
	"de": {
		Greeting:           "Hallo %s.",
		Tagline:            "der gemeinsame Haushalts-Schreibtisch: Listen, Geld, Aufgaben, Rezepte.",
		Unsubscribe:        "Abmelden",
		UnsubscribeLink:    "melde dich ab",
		AccountNote:        "Konto-E-Mails wie das Zurücksetzen deines Passworts kommen weiterhin an.",
		EmailCounter:       "E-MAIL %d / %d",
		TryItNow:           "Probier es aus",
		Open:               "Öffnen",
		TipsFooterLead:     "Du bekommst diese E-Mails, weil du ein mitlist-Konto angelegt hast. Sie hören nach ein paar Wochen auf; wenn du sie schon jetzt nicht mehr möchtest,",
		TipsTextFooterLead: "Du bekommst diese E-Mails, weil du ein mitlist-Konto angelegt hast. Sie hören nach ein paar Wochen auf; wenn du sie schon jetzt nicht mehr möchtest, öffne diesen Link:",
	},
	"es": {
		Greeting:           "Hola, %s.",
		Tagline:            "el escritorio compartido del hogar: listas, dinero, tareas, recetas.",
		Unsubscribe:        "Darse de baja",
		UnsubscribeLink:    "date de baja",
		AccountNote:        "Los correos de la cuenta, como el de restablecer la contraseña, seguirán llegando.",
		EmailCounter:       "CORREO %d / %d",
		TryItNow:           "Pruébalo ahora",
		Open:               "Abrir",
		TipsFooterLead:     "Recibes estos correos porque creaste una cuenta de mitlist. Terminan en unas semanas; para dejar de recibirlos ya,",
		TipsTextFooterLead: "Recibes estos correos porque creaste una cuenta de mitlist. Terminan en unas semanas; para dejar de recibirlos ya, abre este enlace:",
	},
	"fr": {
		Greeting:           "Bonjour %s.",
		Tagline:            "le bureau partagé du foyer : listes, argent, tâches, recettes.",
		Unsubscribe:        "Se désabonner",
		UnsubscribeLink:    "désabonnez-vous",
		AccountNote:        "Les e-mails liés au compte, comme la réinitialisation du mot de passe, arrivent toujours.",
		EmailCounter:       "E-MAIL %d / %d",
		TryItNow:           "Essayez maintenant",
		Open:               "Ouvrir",
		TipsFooterLead:     "Vous recevez ces e-mails parce que vous avez créé un compte mitlist. Ils s'arrêtent au bout de quelques semaines ; pour ne plus les recevoir dès maintenant,",
		TipsTextFooterLead: "Vous recevez ces e-mails parce que vous avez créé un compte mitlist. Ils s'arrêtent au bout de quelques semaines ; pour ne plus les recevoir dès maintenant, ouvrez ce lien :",
	},
	"nl": {
		Greeting:           "Hoi %s.",
		Tagline:            "het gedeelde huishoudbureau: lijsten, geld, klusjes, recepten.",
		Unsubscribe:        "Afmelden",
		UnsubscribeLink:    "meld je dan af",
		AccountNote:        "Account-e-mails, zoals een wachtwoordreset, komen gewoon aan.",
		EmailCounter:       "E-MAIL %d / %d",
		TryItNow:           "Probeer het nu",
		Open:               "Openen",
		TipsFooterLead:     "Je krijgt deze e-mails omdat je een mitlist-account hebt aangemaakt. Ze stoppen na een paar weken; wil je ze nu al niet meer ontvangen,",
		TipsTextFooterLead: "Je krijgt deze e-mails omdat je een mitlist-account hebt aangemaakt. Ze stoppen na een paar weken; wil je ze nu al niet meer ontvangen, open dan deze link:",
	},
}
