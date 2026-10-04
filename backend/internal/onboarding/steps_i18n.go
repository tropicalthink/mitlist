package onboarding

// StepCopy is a step's reader-facing text in one language. Everything else
// about a step (key, timing, links, hero image) is language-neutral and lives
// on Step, whose own copy is the English.
type StepCopy struct {
	Subject  string
	Eyebrow  string
	Heading  string
	Intro    string
	HeroAlt  string
	CTALabel string
	// Tips pairs up with Step.Tips by position; each tip keeps its path.
	Tips []TipCopy
}

// TipCopy is one tip's title and body in one language.
type TipCopy struct {
	Title string
	Body  string
}

// Localize returns step with its copy in language, or unchanged for English
// and anything without a translation.
func Localize(step Step, language string) Step {
	c, ok := stepTranslations[languageFor(language)][step.Key]
	if !ok {
		return step
	}
	out := step
	out.Subject, out.Eyebrow, out.Heading, out.Intro = c.Subject, c.Eyebrow, c.Heading, c.Intro
	out.HeroAlt, out.CTALabel = c.HeroAlt, c.CTALabel
	out.Tips = make([]Tip, len(step.Tips))
	for i, tip := range step.Tips {
		out.Tips[i] = tip
		if i < len(c.Tips) {
			out.Tips[i].Title, out.Tips[i].Body = c.Tips[i].Title, c.Tips[i].Body
		}
	}
	return out
}

// stepTranslations holds every non-English language, keyed by step key.
var stepTranslations = map[string]map[string]StepCopy{
	"de": {
		"day1-household": {
			Subject: "Ein Haushalt aus einer Person ist nur eine To-do-Liste",
			Eyebrow: "Tag 1",
			Heading: "Hol die anderen dazu",
			Intro:   "mitlist funktioniert, wenn die Leute, mit denen du wohnst, auch dabei sind. Alles, was du hinzufügst, erscheint sofort auf ihren Handys – und umgekehrt.",
			Tips: []TipCopy{
				{"Schick einen Einladungslink", "Öffne deinen Haushalt, tippe auf Einladen und teile den Link in eurem WG-Chat. Wer ihn öffnet, landet direkt in deinem Haushalt – ohne Codes abzutippen."},
				{"Fang mit der Einkaufsliste an", "Das ist die einfachste gemeinsame Gewohnheit. Eine geteilte Liste, und wer gerade im Laden ist, hakt einfach ab."},
			},
			HeroAlt:  "Lade deine Mitbewohner ein und starte eine gemeinsame Einkaufsliste",
			CTALabel: "Haushalt öffnen",
		},
		"day3-lists": {
			Subject: "Nie wieder „Brauchen wir Milch?“ schreiben",
			Eyebrow: "Tag 3",
			Heading: "Listen, die mit dir Schritt halten",
			Intro:   "Ein paar Dinge, die die Einkaufsliste kann und die man leicht übersieht.",
			Tips: []TipCopy{
				{"Nach Gängen sortiert", "Wähl den Laden, in dem du einkaufst, und die Liste ordnet sich so, wie der Laden aufgebaut ist – kein Zurücklaufen mehr für die Zwiebeln."},
				{"Einen Zettel scannen", "Der Scanner liest eine handgeschriebene Liste direkt in die App ein. Das läuft auf deinem Handy; nichts wird hochgeladen."},
				{"Vom Essensplan zur Liste", "Plan die Abendessen der Woche und schick die Zutaten mit einem Tippen auf die Einkaufsliste."},
			},
			HeroAlt:  "Einen Einkaufszettel scannen, nach Gängen sortieren und Zutaten aus dem Essensplan hinzufügen",
			CTALabel: "Listen öffnen",
		},
		"day7-money": {
			Subject: "Wer wem was schuldet – ohne peinliches Gespräch",
			Eyebrow: "Woche 1",
			Heading: "Rechnungen einmal aufteilen, dann vergessen",
			Intro:   "Beim gemeinsamen Geld wird es in den meisten Haushalten angespannt. mitlist führt einen laufenden Kontostand, damit niemand es ansprechen muss.",
			Tips: []TipCopy{
				{"Ausgabe hinzufügen, Aufteilung wählen", "Gleichmäßig, nach Anteilen oder mit genauen Beträgen. Alle Beteiligten sehen sie, und die Salden sind sofort aktuell."},
				{"Miete, Internet, Streaming", "Stell eine Ausgabe auf monatlich, und sie bucht sich von selbst. Niemand muss an den Monatsersten denken."},
				{"Ausgleichen", "Wenn jemand einem anderen etwas zurückzahlt, trag es ein, und der Saldo steht wieder auf null. Häng an jede Ausgabe ein Foto vom Beleg für später."},
			},
			HeroAlt:  "Ausgaben aufteilen, Rechnungen wiederholen und Salden im Haushalt ausgleichen",
			CTALabel: "Geld öffnen",
		},
		"day14-chores": {
			Subject: "Aufgaben, die sich selbst weiterreichen",
			Eyebrow: "Woche 2",
			Heading: "Hör auf, die Person zu sein, die alle erinnert",
			Intro:   "Richte die wiederkehrenden Aufgaben einmal ein und lass die App das Nachhaken übernehmen.",
			Tips: []TipCopy{
				{"Rotation", "Setz Müll, Bad und Küche auf einen Plan und wähl aus, wer in der Rotation ist. mitlist teilt jedes Mal die nächste Person ein und erinnert sie."},
				{"Die Pinwall", "Für alles, was keine Aufgabe ist: Notizen fürs Haus, das WLAN-Passwort, der Hinweis, dass der Klempner am Donnerstag kommt. Notizen können Erinnerungen haben."},
				{"Dein Kalender, wie du ihn willst", "Aufgaben, Mahlzeiten und Pinwall-Termine erscheinen alle im Kalender-Tab, und du kannst sie in die Kalender-App exportieren, die du schon nutzt."},
			},
			HeroAlt:  "Wiederkehrende Aufgaben rotieren lassen und automatische Erinnerungen schicken",
			CTALabel: "Aufgaben öffnen",
		},
		"day30-checkin": {
			Subject: "Ein Monat dabei: ein paar Dinge, die du vielleicht verpasst hast",
			Eyebrow: "Monat 1",
			Heading: "Mach es zu deinem",
			Intro:   "Du nutzt mitlist seit einem Monat. Drei weitere Dinge, die einen Blick wert sind.",
			Tips: []TipCopy{
				{"Rezepte von überall", "Füg den Link zu einem Rezept ein, und mitlist importiert es samt Zutaten. Plan es für einen Tag ein, und die Zutaten sind nur einen Tipp von der Einkaufsliste entfernt."},
				{"Eine Wochenzusammenfassung, wenn du willst", "Schalte unter Benachrichtigungen die wöchentliche Zusammenfassung ein und bekomm einmal pro Woche eine E-Mail darüber, was im Haushalt los war. Standardmäßig aus."},
				{"Sag uns, was fehlt", "Auf dem Feature-Board entstehen neue Funktionen. Wenn etwas umständlich ist, sag es; wir lesen alles."},
			},
			HeroAlt:  "Rezepte, Wochenzusammenfassungen, Smart-Home-Werkzeuge und Feedback entdecken",
			CTALabel: "mitlist öffnen",
		},
	},
	"es": {
		"day1-household": {
			Subject: "Un hogar de una sola persona es solo una lista de tareas",
			Eyebrow: "Día 1",
			Heading: "Trae a los demás",
			Intro:   "mitlist funciona cuando las personas con las que vives también están dentro. Todo lo que añades aparece al instante en sus móviles, y al revés.",
			Tips: []TipCopy{
				{"Envía un enlace de invitación", "Abre tu hogar, toca Invitar y comparte el enlace en el grupo de chat de casa. Quien lo abra entra directamente en tu hogar, sin códigos que escribir."},
				{"Empieza por la lista de compras", "Es el hábito más fácil de crear juntos. Una lista compartida, y quien esté en la tienda solo tiene que ir marcando."},
			},
			HeroAlt:  "Invita a tus compañeros de piso y empieza una lista de compras compartida",
			CTALabel: "Abrir tu hogar",
		},
		"day3-lists": {
			Subject: "No vuelvas a escribir «¿necesitamos leche?»",
			Eyebrow: "Día 3",
			Heading: "Listas que van a tu ritmo",
			Intro:   "Algunas cosas que hace la lista de compras y que es fácil pasar por alto.",
			Tips: []TipCopy{
				{"Ordenada por pasillos", "Elige la tienda en la que compras y la lista se agrupa según cómo está organizada, así dejas de volver atrás a por las cebollas."},
				{"Escanea una nota en papel", "El escáner pasa una lista escrita a mano directamente a la app. Funciona en tu móvil; no se sube nada."},
				{"Del plan de comidas a la lista", "Planifica las cenas de la semana y manda los ingredientes a la lista de compras con un toque."},
			},
			HeroAlt:  "Escanea una lista en papel, ordénala por pasillos y añade ingredientes del plan de comidas",
			CTALabel: "Abrir tus listas",
		},
		"day7-money": {
			Subject: "Quién debe qué, sin conversaciones incómodas",
			Eyebrow: "Semana 1",
			Heading: "Reparte las facturas una vez y olvídate",
			Intro:   "El dinero compartido es donde más tensión hay en casi todos los hogares. mitlist lleva un saldo al día para que nadie tenga que sacar el tema.",
			Tips: []TipCopy{
				{"Añade un gasto, elige el reparto", "A partes iguales, por proporción o con importes exactos. Todos los implicados lo ven y los saldos se actualizan al momento."},
				{"Alquiler, internet, streaming", "Haz que un gasto se repita cada mes y se registra solo. Nadie tiene que acordarse del día uno."},
				{"Liquida cuentas", "Cuando alguien le devuelve dinero a otra persona, regístralo y el saldo vuelve a cero. Adjunta una foto del tique a cualquier gasto para más adelante."},
			},
			HeroAlt:  "Reparte gastos, repite facturas y liquida los saldos del hogar",
			CTALabel: "Abrir Dinero",
		},
		"day14-chores": {
			Subject: "Tareas que se turnan solas",
			Eyebrow: "Semana 2",
			Heading: "Deja de ser quien se lo recuerda a todos",
			Intro:   "Configura las tareas recurrentes una vez y deja que la app se encargue de insistir.",
			Tips: []TipCopy{
				{"Turnos", "Pon la basura, el baño y la cocina en un calendario y elige quién entra en los turnos. mitlist asigna a la siguiente persona cada vez y se lo recuerda."},
				{"El Pinwall", "Para todo lo que no es una tarea: notas para la casa, la contraseña del wifi, el aviso de que el fontanero viene el jueves. Las notas pueden llevar recordatorios."},
				{"Tu calendario, a tu manera", "Las tareas, las comidas y las fechas del Pinwall aparecen en la pestaña de calendario, y puedes exportarlas a la app de calendario que ya usas."},
			},
			HeroAlt:  "Turna las tareas recurrentes y envía recordatorios automáticos",
			CTALabel: "Abrir Tareas",
		},
		"day30-checkin": {
			Subject: "Un mes después: algunas cosas que quizá te perdiste",
			Eyebrow: "Mes 1",
			Heading: "Hazlo tuyo",
			Intro:   "Llevas un mes con mitlist. Tres cosas más que merece la pena ver.",
			Tips: []TipCopy{
				{"Recetas de cualquier sitio", "Pega el enlace de una receta y mitlist la importa, ingredientes incluidos. Planifícala para un día y los ingredientes quedan a un toque de la lista de compras."},
				{"Un resumen semanal, si lo quieres", "Activa el resumen semanal en notificaciones y recibe un correo a la semana con lo que ha pasado en el hogar. Desactivado por defecto."},
				{"Dinos qué falta", "Del tablero de funciones salen las novedades. Si algo es incómodo, dilo; lo leemos todo."},
			},
			HeroAlt:  "Descubre recetas, resúmenes semanales, herramientas de casa inteligente y comentarios",
			CTALabel: "Abrir mitlist",
		},
	},
	"fr": {
		"day1-household": {
			Subject: "Un foyer d'une personne, c'est juste une liste de tâches",
			Eyebrow: "Jour 1",
			Heading: "Faites venir les autres",
			Intro:   "mitlist fonctionne quand les personnes avec qui vous vivez y sont aussi. Tout ce que vous ajoutez apparaît aussitôt sur leur téléphone, et inversement.",
			Tips: []TipCopy{
				{"Envoyez un lien d'invitation", "Ouvrez votre foyer, touchez Inviter et partagez le lien dans la conversation de groupe de la maison. Toute personne qui l'ouvre rejoint votre foyer, sans code à saisir."},
				{"Commencez par la liste de courses", "C'est l'habitude la plus facile à prendre ensemble. Une seule liste partagée, et la personne qui est au magasin coche au fur et à mesure."},
			},
			HeroAlt:  "Invitez vos colocataires et lancez une liste de courses partagée",
			CTALabel: "Ouvrir votre foyer",
		},
		"day3-lists": {
			Subject: "Ne demandez plus jamais « on a encore du lait ? »",
			Eyebrow: "Jour 3",
			Heading: "Des listes qui suivent le rythme",
			Intro:   "Quelques fonctions de la liste de courses qu'on remarque rarement.",
			Tips: []TipCopy{
				{"Triée par rayon", "Choisissez le magasin où vous faites vos courses et la liste se range selon l'agencement du magasin : plus besoin de revenir sur vos pas pour les oignons."},
				{"Scannez une note papier", "Le scanner transforme une liste manuscrite en liste dans l'app. Tout se passe sur votre téléphone ; rien n'est envoyé."},
				{"Du plan de repas à la liste", "Planifiez les dîners de la semaine et envoyez les ingrédients vers la liste de courses d'un seul geste."},
			},
			HeroAlt:  "Scanner une liste papier, la trier par rayon et ajouter les ingrédients du plan de repas",
			CTALabel: "Ouvrir vos listes",
		},
		"day7-money": {
			Subject: "Qui doit quoi, sans conversation gênante",
			Eyebrow: "Semaine 1",
			Heading: "Partagez les factures une fois, puis oubliez-les",
			Intro:   "L'argent commun, c'est là que la plupart des foyers se tendent. mitlist tient un solde à jour pour que personne n'ait à aborder le sujet.",
			Tips: []TipCopy{
				{"Ajoutez une dépense, choisissez le partage", "À parts égales, par quote-part ou en montants exacts. Toutes les personnes concernées la voient et les soldes se mettent à jour aussitôt."},
				{"Loyer, internet, streaming", "Réglez une dépense pour qu'elle se répète chaque mois, et elle s'enregistre toute seule. Plus besoin de penser au 1er du mois."},
				{"Réglez vos comptes", "Quand quelqu'un rembourse une autre personne, enregistrez-le et le solde revient à zéro. Joignez la photo d'un ticket à n'importe quelle dépense pour plus tard."},
			},
			HeroAlt:  "Partager les dépenses, répéter les factures et régler les soldes du foyer",
			CTALabel: "Ouvrir Argent",
		},
		"day14-chores": {
			Subject: "Des tâches qui tournent toutes seules",
			Eyebrow: "Semaine 2",
			Heading: "Ne soyez plus la personne qui relance tout le monde",
			Intro:   "Configurez les tâches récurrentes une fois et laissez l'app faire les relances.",
			Tips: []TipCopy{
				{"Rotation", "Planifiez les poubelles, la salle de bain, la cuisine et choisissez qui participe à la rotation. mitlist désigne la personne suivante à chaque fois et le lui rappelle."},
				{"Le Pinwall", "Pour tout ce qui n'est pas une tâche : des notes pour la maison, le mot de passe du wifi, un rappel que le plombier passe jeudi. Les notes peuvent avoir des rappels."},
				{"Votre calendrier, à votre façon", "Les tâches, les repas et les dates du Pinwall apparaissent dans l'onglet Calendrier, et vous pouvez les exporter vers l'app de calendrier que vous utilisez déjà."},
			},
			HeroAlt:  "Faire tourner les tâches récurrentes et envoyer des rappels automatiques",
			CTALabel: "Ouvrir Tâches",
		},
		"day30-checkin": {
			Subject: "Un mois déjà : quelques choses que vous avez peut-être manquées",
			Eyebrow: "Mois 1",
			Heading: "Faites-en le vôtre",
			Intro:   "Vous utilisez mitlist depuis un mois. Trois autres choses qui valent le coup d'œil.",
			Tips: []TipCopy{
				{"Des recettes de partout", "Collez le lien d'une recette et mitlist l'importe, ingrédients compris. Planifiez-la pour un jour et les ingrédients sont à un geste de la liste de courses."},
				{"Un résumé hebdomadaire, si vous voulez", "Activez le résumé hebdomadaire dans les notifications et recevez un e-mail par semaine sur ce qui s'est passé dans le foyer. Désactivé par défaut."},
				{"Dites-nous ce qui manque", "C'est du tableau des fonctionnalités que viennent les nouveautés. Si quelque chose n'est pas pratique, dites-le ; nous lisons tout."},
			},
			HeroAlt:  "Découvrir les recettes, les résumés hebdomadaires, les outils de maison connectée et le retour d'expérience",
			CTALabel: "Ouvrir mitlist",
		},
	},
	"nl": {
		"day1-household": {
			Subject: "Een huishouden van één is gewoon een takenlijstje",
			Eyebrow: "Dag 1",
			Heading: "Haal de anderen erbij",
			Intro:   "mitlist werkt als de mensen met wie je woont er ook in zitten. Alles wat je toevoegt, staat meteen op hun telefoon, en andersom.",
			Tips: []TipCopy{
				{"Stuur één uitnodigingslink", "Open je huishouden, tik op Uitnodigen en deel de link in de groepsapp van je huis. Wie hem opent, komt direct in je huishouden terecht, zonder codes over te typen."},
				{"Begin met de boodschappenlijst", "Dat is de makkelijkste gewoonte om samen op te bouwen. Eén gedeelde lijst, en wie in de winkel staat, vinkt gewoon af."},
			},
			HeroAlt:  "Nodig je huisgenoten uit en begin één gedeelde boodschappenlijst",
			CTALabel: "Open je huishouden",
		},
		"day3-lists": {
			Subject: "Nooit meer appen of er nog melk is",
			Eyebrow: "Dag 3",
			Heading: "Lijsten die met je meedenken",
			Intro:   "Een paar dingen die de boodschappenlijst kan en die je makkelijk mist.",
			Tips: []TipCopy{
				{"Op volgorde van de winkel", "Kies de winkel waar je boodschappen doet en de lijst ordent zich zoals de winkel is ingedeeld, zodat je niet meer terugloopt voor de uien."},
				{"Scan een papieren briefje", "De scanner leest een handgeschreven lijstje direct in de app in. Dat gebeurt op je telefoon; er wordt niets geüpload."},
				{"Van maaltijdplanning naar lijst", "Plan de avondmaaltijden van de week en zet de ingrediënten met één tik op de boodschappenlijst."},
			},
			HeroAlt:  "Scan een papieren lijstje, sorteer het per schap en voeg ingrediënten uit je maaltijdplanning toe",
			CTALabel: "Open je lijsten",
		},
		"day7-money": {
			Subject: "Wie wat schuldig is, zonder ongemakkelijk gesprek",
			Eyebrow: "Week 1",
			Heading: "Verdeel de rekeningen één keer en vergeet ze dan",
			Intro:   "Bij gedeeld geld ontstaat in de meeste huishoudens spanning. mitlist houdt een lopend saldo bij, zodat niemand erover hoeft te beginnen.",
			Tips: []TipCopy{
				{"Voeg een uitgave toe, kies een verdeling", "Gelijk, naar aandeel of met exacte bedragen. Iedereen die meedoet ziet hem en de saldi worden meteen bijgewerkt."},
				{"Huur, internet, streaming", "Laat een uitgave maandelijks terugkomen en hij boekt zichzelf. Niemand hoeft aan de eerste van de maand te denken."},
				{"Vereffenen", "Betaalt iemand een ander terug, leg het vast en het saldo staat weer op nul. Voeg een foto van het bonnetje toe aan een uitgave voor later."},
			},
			HeroAlt:  "Verdeel uitgaven, herhaal rekeningen en vereffen de saldi in je huishouden",
			CTALabel: "Open Geld",
		},
		"day14-chores": {
			Subject: "Klusjes die zichzelf doorschuiven",
			Eyebrow: "Week 2",
			Heading: "Wees niet langer degene die iedereen eraan herinnert",
			Intro:   "Stel de terugkerende klusjes één keer in en laat de app het zeuren doen.",
			Tips: []TipCopy{
				{"Rooster", "Zet de vuilnisbakken, de badkamer en de keuken op een schema en kies wie er meedraait. mitlist wijst telkens de volgende persoon aan en herinnert die eraan."},
				{"Het prikbord", "Voor alles wat geen klusje is: briefjes voor het huis, het wifi-wachtwoord, een herinnering dat de loodgieter donderdag komt. Briefjes kunnen een herinnering hebben."},
				{"Jouw agenda, jouw manier", "Klusjes, maaltijden en data van het prikbord staan allemaal op het kalendertabblad, en je kunt ze exporteren naar de agenda-app die je al gebruikt."},
			},
			HeroAlt:  "Laat terugkerende klusjes rouleren en stuur automatische herinneringen",
			CTALabel: "Open Klusjes",
		},
		"day30-checkin": {
			Subject: "Een maand verder: een paar dingen die je misschien hebt gemist",
			Eyebrow: "Maand 1",
			Heading: "Maak het van jou",
			Intro:   "Je gebruikt mitlist nu een maand. Nog drie dingen die de moeite waard zijn.",
			Tips: []TipCopy{
				{"Recepten van overal", "Plak een link naar een recept en mitlist importeert het, ingrediënten en al. Plan het in voor een dag en de ingrediënten staan met één tik op de boodschappenlijst."},
				{"Een weekoverzicht, als je dat wilt", "Zet de wekelijkse samenvatting aan bij meldingen en krijg één e-mail per week met wat er in het huishouden gebeurde. Standaard uit."},
				{"Vertel ons wat er mist", "Op het functiebord ontstaan nieuwe functies. Is iets onhandig, zeg het; we lezen alles."},
			},
			HeroAlt:  "Ontdek recepten, weekoverzichten, smarthome-tools en feedback",
			CTALabel: "Open mitlist",
		},
	},
}
