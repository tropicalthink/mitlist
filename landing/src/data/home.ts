import type { SiteLanguage } from "./site";

export interface HomeCopy {
  metaTitle: string;
  metaDescription: string;
  beta: string;
  headline: string;
  intro: string;
  openApp: string;
  mobileBeta: string;
  availability: string;
  overviewEyebrow: string;
  overviewTitle: string;
  overviewIntro: string;
  features: Array<{ title: string; body: string }>;
  workflowsEyebrow: string;
  workflowsTitle: string;
  workflows: Array<{ step: string; title: string; body: string }>;
  scannerEyebrow: string;
  scannerTitle: string;
  scannerBody: string;
  scannerNote: string;
  syncTitle: string;
  syncBody: string;
  pricingEyebrow: string;
  pricingTitle: string;
  pricingBody: string;
  free: string;
  freeDetail: string;
  premium: string;
  premiumDetail: string;
  pricingFootnote: string;
  trustTitle: string;
  trust: Array<{ title: string; body: string; link?: string }>;
  roadmapTitle: string;
  roadmapBody: string;
  roadmapCta: string;
  faqTitle: string;
  faq: Array<{ question: string; answer: string }>;
  finalTitle: string;
  finalBody: string;
  placeholder: string;
}

export const homeCopy: Record<SiteLanguage, HomeCopy> = {
  en: {
    metaTitle: "mitlist — one shared place for your household",
    metaDescription:
      "Share lists, expenses, chores, meals, calendars and notes with your household. Now in public beta on the web, with mobile beta access for iOS and Android.",
    beta: "Now in public beta",
    headline: "One shared place for the life you manage together.",
    intro:
      "Plan meals, share lists, split expenses, rotate chores, and keep everyone’s week together—without chasing each other through the group chat.",
    openApp: "Open mitlist",
    mobileBeta: "Get the mobile beta",
    availability:
      "Free on the web for households of up to four. iOS and Android testing is open.",
    overviewEyebrow: "The whole household",
    overviewTitle: "The everyday things, finally connected.",
    overviewIntro:
      "Not another productivity suite. mitlist gives the people in your household one warm, practical place for what actually needs doing.",
    features: [
      {
        title: "Lists",
        body: "Shop together in real time, claim items, remember prices, and sort the trip around the store.",
      },
      {
        title: "Money",
        body: "Split expenses equally, by shares, percentages, or exact amounts—then settle without a spreadsheet.",
      },
      {
        title: "Chores",
        body: "Set recurring work once, rotate it fairly, add supplies, and remind the right person.",
      },
      {
        title: "Meals",
        body: "Save recipes, plan the week, adjust servings, and turn ingredients into a shopping list.",
      },
      {
        title: "Calendar",
        body: "See meals, chores, expenses, and pinwall reminders together in one household calendar.",
      },
      {
        title: "Pinwall",
        body: "Keep notes, plans, reminders, photos, and linked household items where everyone can find them.",
      },
    ],
    workflowsEyebrow: "One thing leads to the next",
    workflowsTitle: "Less copying. Less remembering.",
    workflows: [
      {
        step: "01",
        title: "Plan dinner. Build the list.",
        body: "Put recipes on the meal plan and send their ingredients straight to shopping.",
      },
      {
        step: "02",
        title: "Finish the shop. Split the cost.",
        body: "Turn priced shopping items into a shared expense while the total is still fresh.",
      },
      {
        step: "03",
        title: "See the week as a household.",
        body: "Meals, chores, expenses, and reminders meet in the same calendar.",
      },
    ],
    scannerEyebrow: "On-device mobile scanner",
    scannerTitle: "Paper in. Useful things out.",
    scannerBody:
      "Scan a printed or handwritten grocery list on iOS or Android. mitlist reads it on your phone, matches familiar groceries, and lets you review everything before it reaches the list.",
    scannerNote:
      "Scanning is mobile-only during the public beta. Images are processed on the device.",
    syncTitle: "Together, even when the signal is patchy.",
    syncBody:
      "Connected households update in real time. mitlist also keeps useful information on your device and queues many changes when your connection drops; offline support continues to improve during the beta.",
    pricingEyebrow: "Simple household pricing",
    pricingTitle: "Every feature is included.",
    pricingBody:
      "Premium pays for a larger household—not a better version of the app.",
    free: "Free",
    freeDetail: "Every feature for households of up to 4 people.",
    premium: "€3.99 monthly or €29.99 yearly",
    premiumDetail:
      "One Premium subscription covers a household of 5 or more people.",
    pricingFootnote:
      "Taxes and the final amount are shown before payment. Store prices may vary by region. Self-hosted households are not subject to the hosted member limit.",
    trustTitle: "It runs on your terms.",
    trust: [
      {
        title: "Open source",
        body: "The complete product is AGPL-3.0 licensed. Read it, improve it, or verify what it does.",
        link: "View the source",
      },
      {
        title: "Self-hostable",
        body: "Run the complete app on your own infrastructure. There is no cut-down community edition.",
        link: "Read the docs",
      },
      {
        title: "No ads. No data sale.",
        body: "Official hosting is funded by larger households, not advertising or selling household activity.",
      },
    ],
    roadmapTitle: "Built with households, not around them.",
    roadmapBody:
      "Tell us what is missing, vote on requests, and follow what the community wants next.",
    roadmapCta: "Feedback & roadmap",
    faqTitle: "Good questions.",
    faq: [
      {
        question: "Is mitlist really free?",
        answer:
          "Yes. Households of up to four people get every feature. Larger households need one Premium subscription; there are no paid feature gates.",
      },
      {
        question: "Where can I use it?",
        answer:
          "The web app is open to everyone. iOS is available through TestFlight and Android through Google Play testing while the mobile apps remain in beta.",
      },
      {
        question: "Does the scanner upload my list?",
        answer:
          "No. Mobile text recognition and grocery matching run on your device. The scanner is not available in the web app during beta.",
      },
      {
        question: "Can I self-host it?",
        answer:
          "Yes. The complete app is open source and self-hostable. It is intended for technically comfortable operators, and the documentation is being expanded for launch.",
      },
      {
        question: "Does it work offline?",
        answer:
          "mitlist caches household information and queues many edits when you lose your connection. Coverage is still being hardened, so offline operation is not yet presented as an absolute guarantee.",
      },
    ],
    finalTitle: "Bring the household together.",
    finalBody:
      "Open the web app now, or join the mobile beta on iOS and Android.",
    placeholder: "Screenshot placeholder — replace before official launch",
  },
  de: {
    metaTitle: "mitlist — ein gemeinsamer Ort für euren Haushalt",
    metaDescription:
      "Teilt Listen, Ausgaben, Aufgaben, Mahlzeiten, Kalender und Notizen. Jetzt als öffentliche Beta im Web sowie als Mobile-Beta für iOS und Android.",
    beta: "Jetzt in der öffentlichen Beta",
    headline:
      "Ein gemeinsamer Ort für das Leben, das ihr zusammen organisiert.",
    intro:
      "Plant Mahlzeiten, teilt Listen und Ausgaben, verteilt Aufgaben und behaltet eure Woche im Blick—ohne einander im Gruppenchat hinterherzulaufen.",
    openApp: "mitlist öffnen",
    mobileBeta: "Mobile-Beta holen",
    availability:
      "Im Web kostenlos für Haushalte mit bis zu vier Personen. Die iOS- und Android-Tests sind offen.",
    overviewEyebrow: "Der ganze Haushalt",
    overviewTitle: "Die Alltagssachen—endlich miteinander verbunden.",
    overviewIntro:
      "Keine weitere Produktivitätssuite. mitlist ist der warme, praktische Ort für alles, was bei euch wirklich ansteht.",
    features: [
      {
        title: "Listen",
        body: "Kauft in Echtzeit zusammen ein, übernehmt Artikel, merkt euch Preise und sortiert den Einkauf passend zum Laden.",
      },
      {
        title: "Geld",
        body: "Teilt Ausgaben gleich, nach Anteilen, Prozenten oder genauen Beträgen—und gleicht sie ohne Tabelle aus.",
      },
      {
        title: "Aufgaben",
        body: "Legt Wiederholungen einmal fest, wechselt fair durch, ergänzt Material und erinnert die richtige Person.",
      },
      {
        title: "Mahlzeiten",
        body: "Speichert Rezepte, plant die Woche, passt Portionen an und macht aus Zutaten eine Einkaufsliste.",
      },
      {
        title: "Kalender",
        body: "Seht Mahlzeiten, Aufgaben, Ausgaben und Pinnwand-Erinnerungen in einem Haushaltskalender.",
      },
      {
        title: "Pinnwand",
        body: "Sammelt Notizen, Pläne, Erinnerungen, Fotos und verknüpfte Einträge an einem gemeinsamen Ort.",
      },
    ],
    workflowsEyebrow: "Eins führt zum Nächsten",
    workflowsTitle: "Weniger übertragen. Weniger merken.",
    workflows: [
      {
        step: "01",
        title: "Essen planen. Liste bauen.",
        body: "Plant Rezepte ein und schickt ihre Zutaten direkt auf die Einkaufsliste.",
      },
      {
        step: "02",
        title: "Einkauf fertig. Kosten teilen.",
        body: "Macht aus bepreisten Einkäufen direkt eine gemeinsame Ausgabe.",
      },
      {
        step: "03",
        title: "Die Woche gemeinsam sehen.",
        body: "Mahlzeiten, Aufgaben, Ausgaben und Erinnerungen treffen sich im selben Kalender.",
      },
    ],
    scannerEyebrow: "Mobiler Scanner auf dem Gerät",
    scannerTitle: "Papier rein. Brauchbare Einträge raus.",
    scannerBody:
      "Scannt gedruckte oder handgeschriebene Einkaufslisten auf iOS oder Android. mitlist liest sie auf eurem Gerät und lässt euch alles prüfen.",
    scannerNote:
      "Der Scanner ist während der Beta nur mobil verfügbar. Bilder werden auf dem Gerät verarbeitet.",
    syncTitle: "Gemeinsam—auch bei wackeligem Empfang.",
    syncBody:
      "Verbundene Haushalte aktualisieren sich in Echtzeit. Viele Änderungen werden bei Verbindungsabbrüchen vorgemerkt; die Offline-Unterstützung wird in der Beta weiter verbessert.",
    pricingEyebrow: "Einfache Haushaltspreise",
    pricingTitle: "Alle Funktionen sind inklusive.",
    pricingBody: "Premium bezahlt einen größeren Haushalt—keine bessere App.",
    free: "Kostenlos",
    freeDetail: "Alle Funktionen für Haushalte mit bis zu 4 Personen.",
    premium: "3,99 € monatlich oder 29,99 € jährlich",
    premiumDetail: "Ein Premium-Abo gilt für einen Haushalt ab 5 Personen.",
    pricingFootnote:
      "Steuern und Endbetrag werden vor dem Kauf angezeigt. Store-Preise können regional abweichen. Selbst gehostete Haushalte haben kein mitlist-Mitgliederlimit.",
    trustTitle: "Es läuft nach euren Regeln.",
    trust: [
      {
        title: "Open Source",
        body: "Das vollständige Produkt steht unter AGPL-3.0. Prüft es, verbessert es oder baut darauf auf.",
        link: "Quellcode ansehen",
      },
      {
        title: "Selbst hostbar",
        body: "Betreibt die vollständige App auf eurer eigenen Infrastruktur—ohne abgespeckte Community-Edition.",
        link: "Dokumentation lesen",
      },
      {
        title: "Keine Werbung. Kein Datenverkauf.",
        body: "Größere Haushalte finanzieren das Hosting, nicht Werbung oder der Verkauf eurer Aktivitäten.",
      },
    ],
    roadmapTitle: "Mit Haushalten gebaut—nicht an ihnen vorbei.",
    roadmapBody:
      "Sagt uns, was fehlt, stimmt über Wünsche ab und verfolgt, was als Nächstes kommt.",
    roadmapCta: "Feedback & Roadmap",
    faqTitle: "Gute Fragen.",
    faq: [
      {
        question: "Ist mitlist wirklich kostenlos?",
        answer:
          "Ja. Bis zu vier Personen erhalten alle Funktionen. Größere Haushalte brauchen ein Premium-Abo; es gibt keine bezahlten Funktionssperren.",
      },
      {
        question: "Wo kann ich mitlist nutzen?",
        answer:
          "Die Web-App ist für alle offen. iOS läuft über TestFlight und Android über den Google-Play-Test.",
      },
      {
        question: "Wird meine gescannte Liste hochgeladen?",
        answer:
          "Nein. Mobile Texterkennung und Zuordnung laufen auf dem Gerät. Im Web ist der Scanner während der Beta nicht verfügbar.",
      },
      {
        question: "Kann ich mitlist selbst hosten?",
        answer:
          "Ja. Die vollständige App ist Open Source und selbst hostbar. Zum Betrieb ist derzeit technisches Wissen sinnvoll.",
      },
      {
        question: "Funktioniert mitlist offline?",
        answer:
          "mitlist speichert Haushaltsinformationen lokal und reiht viele Änderungen bei Verbindungsverlust ein. Die Abdeckung wird noch weiter gehärtet.",
      },
    ],
    finalTitle: "Bringt euren Haushalt zusammen.",
    finalBody: "Öffnet jetzt die Web-App oder nehmt an der Mobile-Beta teil.",
    placeholder: "Screenshot-Platzhalter — vor dem offiziellen Start ersetzen",
  },
  es: {} as HomeCopy,
  fr: {} as HomeCopy,
  nl: {} as HomeCopy,
};

// The remaining translations deliberately inherit the full English structure
// until their reviewed launch copy below overrides every visitor-facing field.
const derived = (language: "es" | "fr" | "nl", values: Partial<HomeCopy>) => {
  homeCopy[language] = { ...homeCopy.en, ...values };
};

derived("es", {
  metaTitle: "mitlist — un lugar compartido para vuestro hogar",
  metaDescription:
    "Compartid listas, gastos, tareas, comidas, calendarios y notas. Ya en beta pública en la web y beta móvil para iOS y Android.",
  beta: "Ya en beta pública",
  headline: "Un lugar compartido para la vida que organizáis juntos.",
  intro:
    "Planificad comidas, compartid listas, repartid gastos y tareas y mantened la semana en orden, sin perseguiros por el chat del grupo.",
  openApp: "Abrir mitlist",
  mobileBeta: "Obtener la beta móvil",
  availability:
    "Gratis en la web para hogares de hasta cuatro personas. Las pruebas de iOS y Android están abiertas.",
  overviewEyebrow: "Todo el hogar",
  overviewTitle: "Las cosas del día a día, por fin conectadas.",
  overviewIntro:
    "No es otra suite de productividad. mitlist ofrece a vuestro hogar un lugar cálido y práctico para lo que realmente hay que hacer.",
  features: [
    {
      title: "Listas",
      body: "Comprad juntos en tiempo real, asignaos productos, recordad precios y ordenad el recorrido por la tienda.",
    },
    {
      title: "Dinero",
      body: "Repartid gastos por igual, participaciones, porcentajes o importes exactos y saldadlos sin hojas de cálculo.",
    },
    {
      title: "Tareas",
      body: "Configurad repeticiones, turnaos de forma justa, añadid materiales y avisad a la persona correcta.",
    },
    {
      title: "Comidas",
      body: "Guardad recetas, planificad la semana, ajustad raciones y convertid ingredientes en una lista.",
    },
    {
      title: "Calendario",
      body: "Reunid comidas, tareas, gastos y recordatorios del tablón en un calendario del hogar.",
    },
    {
      title: "Tablón",
      body: "Guardad notas, planes, recordatorios, fotos y elementos relacionados donde todos los encuentren.",
    },
  ],
  workflowsEyebrow: "Una cosa lleva a la otra",
  workflowsTitle: "Menos copiar. Menos recordar.",
  workflows: [
    {
      step: "01",
      title: "Planificad la cena. Cread la lista.",
      body: "Añadid recetas al plan y enviad sus ingredientes directamente a la compra.",
    },
    {
      step: "02",
      title: "Compra hecha. Coste repartido.",
      body: "Convertid los productos con precio en un gasto compartido al terminar.",
    },
    {
      step: "03",
      title: "Ved la semana en común.",
      body: "Comidas, tareas, gastos y recordatorios se encuentran en el mismo calendario.",
    },
  ],
  scannerEyebrow: "Escáner móvil en el dispositivo",
  scannerTitle: "Del papel a una lista útil.",
  scannerBody:
    "Escanead una lista impresa o manuscrita en iOS o Android. mitlist la lee en el teléfono y os permite revisarlo todo.",
  scannerNote:
    "Durante la beta, el escáner solo está disponible en móviles. Las imágenes se procesan en el dispositivo.",
  syncTitle: "Juntos, incluso con poca cobertura.",
  syncBody:
    "Los hogares conectados se actualizan en tiempo real. mitlist conserva información útil y pone en cola muchos cambios cuando falla la conexión; el modo sin conexión sigue mejorando durante la beta.",
  pricingEyebrow: "Precio sencillo por hogar",
  pricingTitle: "Todas las funciones están incluidas.",
  pricingBody:
    "Premium paga por un hogar más grande, no por una versión mejor de la app.",
  free: "Gratis",
  freeDetail: "Todas las funciones para hogares de hasta 4 personas.",
  premium: "3,99 € al mes o 29,99 € al año",
  premiumDetail: "Una suscripción Premium cubre un hogar de 5 personas o más.",
  pricingFootnote:
    "Los impuestos y el importe final se muestran antes del pago. Los precios de las tiendas pueden variar según la región. El límite no se aplica al autoalojamiento.",
  trustTitle: "Funciona bajo vuestras reglas.",
  trust: [
    {
      title: "Código abierto",
      body: "El producto completo usa la licencia AGPL-3.0. Podéis leerlo, mejorarlo y comprobar qué hace.",
      link: "Ver el código",
    },
    {
      title: "Autoalojable",
      body: "Ejecutad la app completa en vuestra infraestructura. No existe una edición comunitaria recortada.",
      link: "Leer la documentación",
    },
    {
      title: "Sin anuncios ni venta de datos",
      body: "Los hogares grandes financian el servicio, no la publicidad ni la venta de vuestra actividad.",
    },
  ],
  roadmapTitle: "Creado con los hogares, no a sus espaldas.",
  roadmapBody:
    "Contadnos qué falta, votad propuestas y seguid lo que la comunidad quiere después.",
  roadmapCta: "Opiniones y hoja de ruta",
  faqTitle: "Buenas preguntas.",
  faq: [
    {
      question: "¿mitlist es realmente gratis?",
      answer:
        "Sí. Los hogares de hasta cuatro personas reciben todas las funciones. Los hogares mayores necesitan una suscripción Premium.",
    },
    {
      question: "¿Dónde puedo usarlo?",
      answer:
        "La app web está abierta. iOS se prueba mediante TestFlight y Android mediante Google Play.",
    },
    {
      question: "¿Se sube mi lista escaneada?",
      answer:
        "No. El reconocimiento móvil se ejecuta en el dispositivo. El escáner no está disponible en la web durante la beta.",
    },
    {
      question: "¿Puedo alojarlo yo?",
      answer:
        "Sí. La app completa es de código abierto y autoalojable; por ahora conviene tener conocimientos técnicos.",
    },
    {
      question: "¿Funciona sin conexión?",
      answer:
        "mitlist guarda información localmente y pone en cola muchos cambios. Esta cobertura continúa reforzándose.",
    },
  ],
  finalTitle: "Reunid vuestro hogar.",
  finalBody: "Abrid la app web o uníos a la beta móvil en iOS y Android.",
  placeholder: "Marcador de captura — sustituir antes del lanzamiento oficial",
});
derived("fr", {
  metaTitle: "mitlist — un espace commun pour votre foyer",
  metaDescription:
    "Partagez listes, dépenses, tâches, repas, calendriers et notes. Désormais en bêta publique sur le Web et en bêta mobile sur iOS et Android.",
  beta: "Désormais en bêta publique",
  headline: "Un espace commun pour la vie que vous organisez ensemble.",
  intro:
    "Planifiez les repas, partagez les listes et les dépenses, faites tourner les tâches et gardez la semaine en ordre—sans vous courir après dans la conversation de groupe.",
  openApp: "Ouvrir mitlist",
  mobileBeta: "Obtenir la bêta mobile",
  availability:
    "Gratuit sur le Web pour les foyers de quatre personnes maximum. Les tests iOS et Android sont ouverts.",
  overviewEyebrow: "Tout le foyer",
  overviewTitle: "Le quotidien, enfin relié.",
  overviewIntro:
    "Pas une énième suite de productivité. mitlist offre à votre foyer un espace chaleureux et pratique pour ce qu’il faut vraiment faire.",
  features: [
    {
      title: "Listes",
      body: "Faites les courses ensemble en temps réel, attribuez les articles, retenez les prix et organisez le trajet en magasin.",
    },
    {
      title: "Dépenses",
      body: "Répartissez à parts égales, en pourcentages, en parts ou en montants exacts, puis soldez sans tableur.",
    },
    {
      title: "Tâches",
      body: "Réglez les récurrences, faites tourner équitablement, ajoutez le matériel et rappelez la bonne personne.",
    },
    {
      title: "Repas",
      body: "Enregistrez les recettes, planifiez la semaine, ajustez les portions et transformez les ingrédients en liste.",
    },
    {
      title: "Calendrier",
      body: "Réunissez repas, tâches, dépenses et rappels du tableau dans un calendrier commun.",
    },
    {
      title: "Tableau",
      body: "Gardez notes, projets, rappels, photos et éléments liés à portée de tout le monde.",
    },
  ],
  workflowsEyebrow: "Tout s’enchaîne",
  workflowsTitle: "Moins recopier. Moins retenir.",
  workflows: [
    {
      step: "01",
      title: "Planifiez le dîner. Créez la liste.",
      body: "Placez les recettes au menu et envoyez leurs ingrédients directement aux courses.",
    },
    {
      step: "02",
      title: "Courses terminées. Coût partagé.",
      body: "Transformez les articles renseignés en dépense commune dès la fin des courses.",
    },
    {
      step: "03",
      title: "Voyez la semaine ensemble.",
      body: "Repas, tâches, dépenses et rappels se retrouvent dans le même calendrier.",
    },
  ],
  scannerEyebrow: "Scanner mobile sur l’appareil",
  scannerTitle: "Du papier à l’utile.",
  scannerBody:
    "Scannez une liste imprimée ou manuscrite sur iOS ou Android. mitlist la lit sur votre téléphone et vous laisse tout vérifier.",
  scannerNote:
    "Pendant la bêta, le scanner est réservé au mobile. Les images sont traitées sur l’appareil.",
  syncTitle: "Ensemble, même quand le réseau vacille.",
  syncBody:
    "Les foyers connectés se mettent à jour en temps réel. mitlist conserve les informations utiles et met de nombreuses modifications en attente hors connexion; cette prise en charge continue de progresser.",
  pricingEyebrow: "Un tarif simple par foyer",
  pricingTitle: "Toutes les fonctions sont incluses.",
  pricingBody:
    "Premium finance un foyer plus grand, pas une meilleure version de l’app.",
  free: "Gratuit",
  freeDetail: "Toutes les fonctions pour les foyers de 4 personnes maximum.",
  premium: "3,99 € par mois ou 29,99 € par an",
  premiumDetail:
    "Un abonnement Premium couvre un foyer de 5 personnes ou plus.",
  pricingFootnote:
    "Les taxes et le montant final sont affichés avant paiement. Les prix des stores peuvent varier selon la région. La limite ne concerne pas l’auto-hébergement.",
  trustTitle: "Selon vos règles.",
  trust: [
    {
      title: "Open source",
      body: "Le produit complet est sous licence AGPL-3.0. Lisez-le, améliorez-le ou vérifiez son fonctionnement.",
      link: "Voir le code",
    },
    {
      title: "Auto-hébergeable",
      body: "Exécutez l’application complète sur votre infrastructure, sans édition communautaire limitée.",
      link: "Lire la documentation",
    },
    {
      title: "Sans publicité ni vente de données",
      body: "Les grands foyers financent le service, pas la publicité ni la vente de votre activité.",
    },
  ],
  roadmapTitle: "Conçu avec les foyers, pas à leur place.",
  roadmapBody:
    "Dites-nous ce qui manque, votez pour les demandes et suivez les priorités de la communauté.",
  roadmapCta: "Retours et feuille de route",
  faqTitle: "Bonnes questions.",
  faq: [
    {
      question: "mitlist est-il vraiment gratuit ?",
      answer:
        "Oui. Jusqu’à quatre personnes profitent de toutes les fonctions. Les foyers plus grands ont besoin d’un abonnement Premium.",
    },
    {
      question: "Où puis-je l’utiliser ?",
      answer:
        "L’application Web est ouverte. iOS passe par TestFlight et Android par les tests Google Play.",
    },
    {
      question: "Ma liste scannée est-elle envoyée ?",
      answer:
        "Non. La reconnaissance mobile s’effectue sur l’appareil. Le scanner Web n’est pas disponible pendant la bêta.",
    },
    {
      question: "Puis-je l’auto-héberger ?",
      answer:
        "Oui. L’application complète est open source et auto-hébergeable; des connaissances techniques restent utiles.",
    },
    {
      question: "Fonctionne-t-il hors connexion ?",
      answer:
        "mitlist conserve des informations localement et met de nombreuses modifications en attente. Cette couverture est encore renforcée.",
    },
  ],
  finalTitle: "Rassemblez votre foyer.",
  finalBody:
    "Ouvrez l’application Web ou rejoignez la bêta mobile sur iOS et Android.",
  placeholder:
    "Emplacement de capture — à remplacer avant le lancement officiel",
});
derived("nl", {
  metaTitle: "mitlist — één gedeelde plek voor jullie huishouden",
  metaDescription:
    "Deel lijsten, uitgaven, klussen, maaltijden, agenda’s en notities. Nu als openbare bèta op het web en mobiele bèta voor iOS en Android.",
  beta: "Nu in openbare bèta",
  headline: "Eén gedeelde plek voor het leven dat jullie samen regelen.",
  intro:
    "Plan maaltijden, deel lijsten en uitgaven, verdeel klussen en houd ieders week bij—zonder elkaar in de groepschat achterna te zitten.",
  openApp: "Open mitlist",
  mobileBeta: "Download de mobiele bèta",
  availability:
    "Gratis op het web voor huishoudens tot vier personen. De iOS- en Android-tests zijn geopend.",
  overviewEyebrow: "Het hele huishouden",
  overviewTitle: "De dagelijkse dingen, eindelijk verbonden.",
  overviewIntro:
    "Geen nieuw productiviteitspakket. mitlist geeft jullie huishouden een warme, praktische plek voor wat echt moet gebeuren.",
  features: [
    {
      title: "Lijsten",
      body: "Doe samen realtime boodschappen, neem artikelen op je, onthoud prijzen en orden de route door de winkel.",
    },
    {
      title: "Geld",
      body: "Verdeel uitgaven gelijk, in aandelen, percentages of exacte bedragen en reken af zonder spreadsheet.",
    },
    {
      title: "Klussen",
      body: "Stel herhaling in, rouleer eerlijk, voeg benodigdheden toe en herinner de juiste persoon.",
    },
    {
      title: "Maaltijden",
      body: "Bewaar recepten, plan de week, pas porties aan en zet ingrediënten op een boodschappenlijst.",
    },
    {
      title: "Agenda",
      body: "Bekijk maaltijden, klussen, uitgaven en prikbordherinneringen in één huishoudagenda.",
    },
    {
      title: "Prikbord",
      body: "Bewaar notities, plannen, herinneringen, foto’s en gekoppelde items waar iedereen ze vindt.",
    },
  ],
  workflowsEyebrow: "Het een leidt tot het ander",
  workflowsTitle: "Minder overtypen. Minder onthouden.",
  workflows: [
    {
      step: "01",
      title: "Plan het eten. Maak de lijst.",
      body: "Zet recepten in het weekplan en stuur de ingrediënten direct naar de boodschappen.",
    },
    {
      step: "02",
      title: "Klaar met winkelen. Kosten gedeeld.",
      body: "Maak van geprijsde boodschappen meteen een gedeelde uitgave.",
    },
    {
      step: "03",
      title: "Bekijk de week samen.",
      body: "Maaltijden, klussen, uitgaven en herinneringen komen samen in dezelfde agenda.",
    },
  ],
  scannerEyebrow: "Mobiele scanner op het apparaat",
  scannerTitle: "Papier erin. Bruikbare dingen eruit.",
  scannerBody:
    "Scan een gedrukte of handgeschreven boodschappenlijst op iOS of Android. mitlist leest hem op je telefoon en laat je alles controleren.",
  scannerNote:
    "Tijdens de bèta werkt de scanner alleen op mobiel. Afbeeldingen worden op het apparaat verwerkt.",
  syncTitle: "Samen, ook bij slecht bereik.",
  syncBody:
    "Verbonden huishoudens worden realtime bijgewerkt. mitlist bewaart nuttige informatie en zet veel wijzigingen in de wachtrij als de verbinding wegvalt; offline ondersteuning blijft verbeteren.",
  pricingEyebrow: "Eenvoudige prijs per huishouden",
  pricingTitle: "Elke functie is inbegrepen.",
  pricingBody:
    "Premium betaalt voor een groter huishouden, niet voor een betere app.",
  free: "Gratis",
  freeDetail: "Alle functies voor huishoudens tot 4 personen.",
  premium: "€ 3,99 per maand of € 29,99 per jaar",
  premiumDetail:
    "Eén Premium-abonnement dekt een huishouden van 5 personen of meer.",
  pricingFootnote:
    "Belastingen en het definitieve bedrag verschijnen voor betaling. Winkelprijzen kunnen per regio verschillen. De limiet geldt niet voor zelfhosting.",
  trustTitle: "Op jullie voorwaarden.",
  trust: [
    {
      title: "Open source",
      body: "Het complete product heeft een AGPL-3.0-licentie. Lees, verbeter of controleer zelf wat het doet.",
      link: "Bekijk de broncode",
    },
    {
      title: "Zelf te hosten",
      body: "Draai de volledige app op je eigen infrastructuur. Er is geen uitgeklede community-editie.",
      link: "Lees de documentatie",
    },
    {
      title: "Geen advertenties of gegevensverkoop",
      body: "Grotere huishoudens financieren de dienst, niet advertenties of de verkoop van jullie activiteit.",
    },
  ],
  roadmapTitle: "Gebouwd met huishoudens, niet om hen heen.",
  roadmapBody:
    "Vertel wat ontbreekt, stem op verzoeken en volg wat de community hierna wil.",
  roadmapCta: "Feedback en roadmap",
  faqTitle: "Goede vragen.",
  faq: [
    {
      question: "Is mitlist echt gratis?",
      answer:
        "Ja. Huishoudens tot vier personen krijgen elke functie. Grotere huishoudens hebben één Premium-abonnement nodig.",
    },
    {
      question: "Waar kan ik het gebruiken?",
      answer:
        "De webapp staat voor iedereen open. iOS loopt via TestFlight en Android via Google Play-tests.",
    },
    {
      question: "Wordt mijn scan geüpload?",
      answer:
        "Nee. Mobiele tekstherkenning draait op het apparaat. De scanner is tijdens de bèta niet beschikbaar op het web.",
    },
    {
      question: "Kan ik het zelf hosten?",
      answer:
        "Ja. De volledige app is open source en zelf te hosten; technische ervaring is momenteel handig.",
    },
    {
      question: "Werkt het offline?",
      answer:
        "mitlist bewaart huishoudinformatie lokaal en zet veel wijzigingen in de wachtrij. Deze dekking wordt nog versterkt.",
    },
  ],
  finalTitle: "Breng het huishouden samen.",
  finalBody: "Open de webapp of doe mee met de mobiele bèta op iOS en Android.",
  placeholder:
    "Tijdelijke schermafbeelding — vervangen voor officiële lancering",
});
