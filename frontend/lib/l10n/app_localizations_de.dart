// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for German (`de`).
class AppLocalizationsDe extends AppLocalizations {
  AppLocalizationsDe([String locale = 'de']) : super(locale);

  @override
  String get commonCancel => 'Abbrechen';

  @override
  String get commonDelete => 'Löschen';

  @override
  String get commonRetry => 'Erneut versuchen';

  @override
  String get commonSave => 'Speichern';

  @override
  String get commonBack => 'Zurück';

  @override
  String get commonClose => 'Schließen';

  @override
  String get commonDone => 'Fertig';

  @override
  String get commonUndo => 'Rückgängig';

  @override
  String get commonAdd => 'Hinzufügen';

  @override
  String get commonConfirm => 'Bestätigen';

  @override
  String get commonEdit => 'Bearbeiten';

  @override
  String get commonSearch => 'Suchen';

  @override
  String get commonRemove => 'Entfernen';

  @override
  String get commonDismiss => 'Verwerfen';

  @override
  String get commonClear => 'Leeren';

  @override
  String get commonNext => 'Weiter';

  @override
  String get commonSkip => 'Überspringen';

  @override
  String get commonChange => 'Ändern';

  @override
  String get commonCreate => 'Erstellen';

  @override
  String get commonRename => 'Umbenennen';

  @override
  String get commonArchive => 'Archivieren';

  @override
  String get commonOptions => 'Optionen';

  @override
  String get commonSettings => 'Einstellungen';

  @override
  String get commonName => 'Name';

  @override
  String get commonDescription => 'Beschreibung';

  @override
  String get commonNotes => 'Notizen';

  @override
  String get commonAmount => 'Betrag';

  @override
  String get commonPreview => 'Vorschau';

  @override
  String get commonShare => 'Teilen';

  @override
  String get commonCopy => 'Kopieren';

  @override
  String get commonListName => 'Listenname';

  @override
  String get commonSaving => 'Wird gespeichert…';

  @override
  String get commonAdding => 'Wird hinzugefügt…';

  @override
  String get commonDeleting => 'Wird gelöscht…';

  @override
  String get commonNoHousehold => 'Noch kein Haushalt';

  @override
  String get commonCreateJoinHousehold =>
      'Erstelle einen Haushalt oder tritt einem bei, bevor du Einträge hinzufügst.';

  @override
  String get commonGoToHouseholds => 'Zu den Haushalten';

  @override
  String get commonSomethingWentWrong => 'Etwas ist schiefgegangen';

  @override
  String get commonFailedToLoad =>
      'Laden fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get commonCheckConnection =>
      'Überprüfe deine Verbindung und versuche es erneut.';

  @override
  String get commonClearSearch => 'Suche löschen';

  @override
  String commonMember(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder',
      one: '$count Mitglied',
    );
    return '$_temp0';
  }

  @override
  String commonItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '1 Eintrag',
    );
    return '$_temp0';
  }

  @override
  String get commonLoadingMembers => 'Mitglieder werden geladen…';

  @override
  String get welcomeTagline => 'Dein Haushalt, organisiert.';

  @override
  String get welcomeCardTitle => 'Listen, Aufgaben, Geld.\nAlles an einem Ort.';

  @override
  String get welcomeCardBody =>
      'Gemacht für WGs, die weniger Reibung und mehr Klarheit wollen.';

  @override
  String get welcomeCreateHousehold => 'Kostenlosen Haushalt erstellen';

  @override
  String get welcomeSignIn => 'Anmelden';

  @override
  String get welcomeGuestLoading => 'Wird eingerichtet …';

  @override
  String get welcomeContinueAsGuest => 'Als Gast fortfahren';

  @override
  String get welcomeGuestFootnote =>
      'Kein Konto nötig. 30 Tage lang alles kostenlos testen.';

  @override
  String get hubAppBarTitle => 'Start';

  @override
  String get hubHouseholdsSheetTitle => 'Haushalte';

  @override
  String hubSwitchToHousehold(String name) {
    return 'Zu $name wechseln';
  }

  @override
  String get hubCreateHousehold => 'Haushalt erstellen';

  @override
  String get hubJoinHousehold => 'Haushalt beitreten';

  @override
  String get hubInviteToHousehold => 'In den Haushalt einladen';

  @override
  String get hubHouseholdSettings => 'Haushaltseinstellungen';

  @override
  String get hubWelcomeHeadline => 'Willkommen bei mitlist';

  @override
  String get hubWelcomeDescription =>
      'Erstelle einen Haushalt oder tritt einem bei, um Listen, Aufgaben und Ausgaben zu teilen.';

  @override
  String get hubCreateAHousehold => 'Einen Haushalt erstellen';

  @override
  String get hubJoinWithInviteCode => 'Mit Einladungscode beitreten';

  @override
  String get hubQuickAdd => 'Schnell hinzufügen';

  @override
  String get hubLoadError =>
      'Haushalte konnten nicht geladen werden. Überprüfe deine Verbindung und versuche es erneut.';

  @override
  String get hubCalendarTooltip => 'Kalender';

  @override
  String get myHouseholdsTitle => 'Meine Haushalte';

  @override
  String get groupsJoinWithCode => 'Mit Code beitreten';

  @override
  String get groupsFailedLoad => 'Haushalte konnten nicht geladen werden';

  @override
  String get groupsFailedMore =>
      'Weitere Haushalte konnten nicht geladen werden';

  @override
  String get groupsEmptyTitle => 'Noch keine Haushalte';

  @override
  String get groupsEmptyDesc =>
      'Erstelle einen, um dein Zuhause zu organisieren.';

  @override
  String get groupsCreateHousehold => 'Haushalt erstellen';

  @override
  String get choreAppBarTitle => 'Aufgaben';

  @override
  String get choreAddChore => 'Aufgabe hinzufügen';

  @override
  String get choreAddHouseholds => 'Haushalte';

  @override
  String get choreRetry => 'Erneut versuchen';

  @override
  String get choreNoHouseholdTitle => 'Noch kein Haushalt';

  @override
  String get choreNoHouseholdDesc =>
      'Erstelle einen Haushalt oder tritt einem bei, bevor du Aufgaben hinzufügst.';

  @override
  String get choreGoToHouseholds => 'Zu den Haushalten';

  @override
  String get choreNoChoresTitle => 'Noch keine Aufgaben';

  @override
  String get choreNoChoresDesc =>
      'Verwalte wiederkehrende Aufgaben im Haushalt. Weise sie jedem in deiner Gruppe zu.';

  @override
  String get choreAddAChore => 'Aufgabe hinzufügen';

  @override
  String get choreSectionOverdue => 'Überfällig';

  @override
  String get choreSectionToday => 'Heute';

  @override
  String get choreSectionThisWeek => 'Diese Woche';

  @override
  String get choreSectionLater => 'Später';

  @override
  String get choreNothingOnYou => 'Aktuell nichts für dich';

  @override
  String get choreNothingOnYouDesc =>
      'Dein Haushalt hat Aufgaben, aber keine ist dir zugewiesen.';

  @override
  String get choreSeeEveryonesChores => 'Alle Aufgaben anzeigen';

  @override
  String choreDoneSnackbar(String choreTitle) {
    return '$choreTitle erledigt';
  }

  @override
  String get choreFailedComplete =>
      'Aufgabe konnte nicht abgeschlossen werden. Bitte versuche es erneut.';

  @override
  String get choreFailedUndo =>
      'Erledigung konnte nicht rückgängig gemacht werden. Bitte versuche es erneut.';

  @override
  String get choreFailedSkip =>
      'Aufgabe konnte nicht übersprungen werden. Bitte versuche es erneut.';

  @override
  String get choreFailedUpdateSubtask =>
      'Teilaufgabe konnte nicht aktualisiert werden. Bitte versuche es erneut.';

  @override
  String get choreFailedAddSubtask =>
      'Teilaufgabe konnte nicht hinzugefügt werden. Bitte versuche es erneut.';

  @override
  String get choreCreateListFirst => 'Erstelle zuerst eine Einkaufsliste.';

  @override
  String get choreAddSuppliesToList => 'Bedarf zur Liste hinzufügen';

  @override
  String get choreSuppliesAdded => 'Bedarf zur Liste hinzugefügt';

  @override
  String get choreFailedAddSupplies =>
      'Bedarf konnte nicht hinzugefügt werden. Bitte versuche es erneut.';

  @override
  String get choreFailedReschedule =>
      'Aufgabe konnte nicht neu geplant werden. Bitte versuche es erneut.';

  @override
  String get choreDeleteTitle => 'Aufgabe löschen';

  @override
  String get choreDeleteBody =>
      'Dies löscht die Aufgabe und ihren Verlauf dauerhaft. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get choreStatusDone => 'Erledigt';

  @override
  String get choreStatusOverdue => 'Überfällig';

  @override
  String get choreStatusDueToday => 'Heute fällig';

  @override
  String get choreStatusDueSoon => 'Bald fällig';

  @override
  String get choreStatusScheduled => 'Geplant';

  @override
  String get choreStatusPending => 'Ausstehend';

  @override
  String get choreYourTurn => 'Du bist dran';

  @override
  String choreSomeonesTurn(String name) {
    return '$name ist dran';
  }

  @override
  String get choreRefreshFailed =>
      'Aktualisierung fehlgeschlagen. Gespeicherte Aufgaben werden angezeigt.';

  @override
  String choreDoneLast30Days(num count) {
    return '$count erledigt, letzte 30 Tage';
  }

  @override
  String get choreYoureClear => 'Alles erledigt';

  @override
  String choreHeroDescSingular(num count) {
    return '$count Aufgabe wartet auf dich.';
  }

  @override
  String choreHeroDescPlural(num count) {
    return '$count Aufgaben warten auf dich.';
  }

  @override
  String choreMeLabel(num count) {
    return 'Ich ($count)';
  }

  @override
  String choreEveryoneLabel(num count) {
    return 'Alle ($count)';
  }

  @override
  String get choreHowItSplits => 'Verteilung';

  @override
  String choreSupplySingular(num count) {
    return '$count Bedarf';
  }

  @override
  String choreSupplyPlural(num count) {
    return '$count Bedarfe';
  }

  @override
  String get choreFrequencyHourly => 'Stündlich';

  @override
  String get choreFrequencyDaily => 'Täglich';

  @override
  String get choreFrequencyWeekly => 'Wöchentlich';

  @override
  String get choreFrequencyMonthly => 'Monatlich';

  @override
  String get choreFrequencyYearly => 'Jährlich';

  @override
  String get choreFrequencyAsNeeded => 'Nach Bedarf';

  @override
  String get choreFrequencyOneOff => 'Einmalig';

  @override
  String choreEveryInterval(num interval, String unit) {
    return 'Alle $interval $unit';
  }

  @override
  String get choreDoneToday => 'Heute erledigt';

  @override
  String get choreDoneYesterday => 'Gestern erledigt';

  @override
  String choreDoneDaysAgo(num days) {
    return 'Vor $days Tagen erledigt';
  }

  @override
  String get choreSkipped => 'Übersprungen';

  @override
  String choreMarkNotDone(String title) {
    return '$title als unerledigt markieren';
  }

  @override
  String choreMarkDone(String title) {
    return '$title als erledigt markieren';
  }

  @override
  String get choreAllCaughtUp => 'Du hast alles erledigt';

  @override
  String choreCarryingShare(num my, num total) {
    return '$my von $total offenen Aufgaben';
  }

  @override
  String get choreNothingShare => 'Aktuell nichts für dich';

  @override
  String get choreCreationTitle => 'Aufgabe hinzufügen';

  @override
  String get choreCreationNameHint => 'Name der Aufgabe';

  @override
  String get choreCreationYourRoutines => 'Deine Routinen';

  @override
  String get choreCreationStartFromRoutine => 'Aus einer Routine starten';

  @override
  String get choreCreationSuggestions => 'Vorschläge';

  @override
  String get choreCreationZoneLabel => 'Bereich';

  @override
  String get choreCreationZoneKitchen => 'Küche';

  @override
  String get choreCreationZoneBathroom => 'Bad';

  @override
  String get choreCreationZoneLivingRoom => 'Wohnzimmer';

  @override
  String get choreCreationZoneBedroom => 'Schlafzimmer';

  @override
  String get choreCreationZoneOutdoor => 'Außenbereich';

  @override
  String get choreCreationZoneShared => 'Gemeinschaftsraum';

  @override
  String get choreCreationRepeatsLabel => 'Wiederholung';

  @override
  String get choreCreationRecurrenceNone => 'Keine';

  @override
  String get choreCreationRecurrenceHourly => 'Stündlich';

  @override
  String get choreCreationRecurrenceDaily => 'Täglich';

  @override
  String get choreCreationRecurrenceWeekly => 'Wöchentlich';

  @override
  String get choreCreationRecurrenceMonthly => 'Monatlich';

  @override
  String get choreCreationRecurrenceYearly => 'Jährlich';

  @override
  String get choreCreationRecurrenceAdaptive => 'Adaptiv';

  @override
  String get choreCreationHintNone =>
      'Eine einmalige Aufgabe. Sie kommt nicht von selbst wieder.';

  @override
  String get choreCreationHintHourly =>
      'Kommt alle festgelegten Stunden wieder.';

  @override
  String get choreCreationHintDaily => 'Kommt alle festgelegten Tage wieder.';

  @override
  String get choreCreationHintWeekly =>
      'Kommt jede Woche an den gewählten Tagen wieder.';

  @override
  String get choreCreationHintMonthly =>
      'Kommt monatlich am gleichen Datum wieder.';

  @override
  String get choreCreationHintYearly =>
      'Kommt jährlich am gleichen Datum wieder.';

  @override
  String get choreCreationHintAdaptive =>
      'Kommt basierend auf der letzten Erledigung wieder, nicht nach Kalender.';

  @override
  String get choreCreationIntervalHint => '1';

  @override
  String get choreCreationMoreOptions => 'Weitere Optionen';

  @override
  String get choreCreationAssignLabel => 'Zuweisung';

  @override
  String get choreCreationAssignTakeTurns => 'Abwechselnd';

  @override
  String get choreCreationAssignLeastDone => 'Am seltensten';

  @override
  String get choreCreationAssignAlphabetical => 'Alphabetisch';

  @override
  String get choreCreationAssignRandom => 'Zufällig';

  @override
  String get choreCreationAssignNoAssignee => 'Niemand';

  @override
  String get choreCreationAssignHintTurns =>
      'Wechselt jedes Mal zur nächsten Person.';

  @override
  String get choreCreationAssignHintAlpha =>
      'Geht in alphabetischer Reihenfolge der Namen.';

  @override
  String get choreCreationAssignHintLeast =>
      'Geht an die Person, die sie am seltensten gemacht hat.';

  @override
  String get choreCreationAssignHintRandom =>
      'Wählt jedes Mal zufällig jemanden aus.';

  @override
  String get choreCreationAssignHintNone =>
      'Bleibt unzugewiesen. Jeder im Haushalt kann sie übernehmen.';

  @override
  String get choreCreationLogWhenDone => 'Nur aufzeichnen, nicht abhaken';

  @override
  String get choreCreationLogWhenDoneHelper =>
      'Zeichnet das Datum auf, ohne sie als erledigt zu markieren. Gut für Aufgaben, von denen du einen Verlauf möchtest.';

  @override
  String get choreCreationRollOver => 'Bei Versäumnis verschieben';

  @override
  String get choreCreationRollOverHelper =>
      'Verschiebt auf das nächste Fälligkeitsdatum, statt sich als überfällig anzuhäufen.';

  @override
  String get choreCreationNotesHint =>
      'Notizen (optional) — Schritte, Erinnerungen, alles Nützliche';

  @override
  String get choreCreationSaveAsRoutine => 'Als Routine speichern';

  @override
  String get choreCreationSaveAsRoutineSemantic =>
      'Diese Aufgabe als wiederverwendbare Routine speichern';

  @override
  String get choreCreationScanChoreSemantic => 'Aufgabe per Kamera scannen';

  @override
  String get choreCreationChoreAdded => 'Aufgabe hinzugefügt';

  @override
  String choreCreationChoreAddedNextUp(String assignee) {
    return 'Aufgabe hinzugefügt · als nächstes: $assignee';
  }

  @override
  String get choreCreationJoinFirst =>
      'Erstelle zuerst einen Haushalt oder tritt einem bei.';

  @override
  String get choreCreationEditRoutine => 'Routine bearbeiten';

  @override
  String choreCreationEverySingular(String unit) {
    return 'Jede $unit';
  }

  @override
  String choreCreationEveryPlural(num n, String unit) {
    return 'Alle $n $unit';
  }

  @override
  String get choreCreationUnitHourSingular => 'Stunde';

  @override
  String get choreCreationUnitHourPlural => 'Stunden';

  @override
  String get choreCreationUnitDaySingular => 'Tag';

  @override
  String get choreCreationUnitDayPlural => 'Tage';

  @override
  String get choreCreationUnitWeekSingular => 'Woche';

  @override
  String get choreCreationUnitWeekPlural => 'Wochen';

  @override
  String get choreCreationUnitMonthSingular => 'Monat';

  @override
  String get choreCreationUnitMonthPlural => 'Monate';

  @override
  String get choreCreationUnitYearSingular => 'Jahr';

  @override
  String get choreCreationUnitYearPlural => 'Jahre';

  @override
  String get choreDayMon => 'Mo';

  @override
  String get choreDayTue => 'Di';

  @override
  String get choreDayWed => 'Mi';

  @override
  String get choreDayThu => 'Do';

  @override
  String get choreDayFri => 'Fr';

  @override
  String get choreDaySat => 'Sa';

  @override
  String get choreDaySun => 'So';

  @override
  String get choreDetailTitle => 'Aufgabendetails';

  @override
  String get choreDetailAssignee => 'Zugewiesen an';

  @override
  String get choreDetailDue => 'Fällig';

  @override
  String get choreDetailTracked => 'Verfolgt';

  @override
  String get choreDetailLastDone => 'Zuletzt erledigt';

  @override
  String get choreDetailLastBy => 'Zuletzt von';

  @override
  String get choreDetailAverage => 'Durchschnitt';

  @override
  String get choreDetailSubtasks => 'Teilaufgaben';

  @override
  String get choreDetailNewSubtask => 'Neue Teilaufgabe';

  @override
  String get choreDetailSupplies => 'Bedarf';

  @override
  String get choreDetailAddSuppliesToList => 'Bedarf zur Liste hinzufügen';

  @override
  String get choreDetailMarkDone => 'Als erledigt markieren';

  @override
  String get choreDetailMoveToTomorrow => 'Auf morgen verschieben';

  @override
  String get choreDetailUndoLast => 'Letzte Ausführung rückgängig';

  @override
  String get choreDetailSkipTitle => 'Aufgabe überspringen';

  @override
  String get choreDetailSkipReason => 'Grund (optional)';

  @override
  String get choreDetailSkipReasonHint => 'z. B. Diese Woche nicht da';

  @override
  String get choreDetailDeleteTitleDialog => 'Aufgabe löschen';

  @override
  String get choreDetailDeleteBody =>
      'Dies löscht die Aufgabe und ihren Verlauf dauerhaft.';

  @override
  String get choreDetailDeleteSubtask => 'Teilaufgabe löschen';

  @override
  String get choreDetailSubtaskMarkNotDone =>
      'Teilaufgabe als unerledigt markieren';

  @override
  String get choreDetailSubtaskMarkDone => 'Teilaufgabe als erledigt markieren';

  @override
  String get choreLoadTitle => 'Wer macht die Aufgaben';

  @override
  String choreLoadEmpty(num days) {
    return 'In den letzten $days Tagen wurden noch keine Aufgaben erledigt. Sobald jemand anfängt, Dinge abzuhaken, erscheint hier die Verteilung.';
  }

  @override
  String choreLoadCountSingular(num count) {
    return '$count Aufgabe';
  }

  @override
  String choreLoadCountPlural(num count) {
    return '$count Aufgaben';
  }

  @override
  String get recipeAppBarTitle => 'Küche';

  @override
  String get recipeSearchLabel => 'Küche durchsuchen';

  @override
  String get recipeSearchHint => 'Rezept, Tag, Zutat';

  @override
  String get recipeMealPlanTooltip => 'Essensplan';

  @override
  String get recipeSearchTooltip => 'Suchen';

  @override
  String get recipeSortLabel => 'Rezepte sortieren';

  @override
  String get recipeSortNewest => 'Neueste';

  @override
  String get recipeSortOldest => 'Älteste';

  @override
  String get recipeSortAZ => 'A-Z';

  @override
  String get recipeAddRecipe => 'Rezept hinzufügen';

  @override
  String get recipeFailedLoad => 'Küche konnte nicht geladen werden';

  @override
  String get recipeFailedMore => 'Weitere Rezepte konnten nicht geladen werden';

  @override
  String get recipeBuildKitchen => 'Baue deine Küche auf';

  @override
  String get recipeBuildKitchenDesc =>
      'Importiere Rezepte, gruppiere Kochbücher, plane Mahlzeiten und erstelle eine Einkaufsliste für die Woche.';

  @override
  String get recipeNoMatchTitle => 'Keine passenden Rezepte';

  @override
  String get recipeNoMatchDesc =>
      'Versuch eine andere Suche oder einen anderen Filter.';

  @override
  String get recipeShowAllRecipes => 'Alle Rezepte anzeigen';

  @override
  String recipeMealsPlanned(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mahlzeiten diese Woche geplant',
      one: '1 Mahlzeit diese Woche geplant',
    );
    return '$_temp0';
  }

  @override
  String get recipePlanButton => 'Planen';

  @override
  String recipeCountLabel(num visible, num total) {
    return '$visible von $total Rezepten';
  }

  @override
  String recipeCountLabelAll(num total) {
    return '$total Rezepte';
  }

  @override
  String get recipeFilterAll => 'Alle';

  @override
  String get recipeFilterShared => 'Geteilt';

  @override
  String get recipeFilterPrivate => 'Privat';

  @override
  String recipeImageSemantics(String title) {
    return 'Bild von $title';
  }

  @override
  String recipeMinLabel(num minutes) {
    return '$minutes Min.';
  }

  @override
  String recipeServesLabel(num servings) {
    return 'Für $servings Portionen';
  }

  @override
  String recipeOpenRecipe(String title) {
    return 'Rezept $title öffnen';
  }

  @override
  String get recipeAddToList => 'Zur Liste hinzufügen';

  @override
  String recipeSharedPrivate(num shared, num private) {
    return '$shared geteilt · $private privat';
  }

  @override
  String recipeCookbooksLabel(num count) {
    return ' · $count Kochbücher';
  }

  @override
  String recipeRatingLabel(String rating, num count) {
    return '$rating ($count)';
  }

  @override
  String get recipeCreationTitle => 'Neues Rezept';

  @override
  String get recipeCreationStepSource => 'Quelle';

  @override
  String get recipeCreationStepDetails => 'Details';

  @override
  String get recipeCreationStepContent => 'Inhalt';

  @override
  String get recipeCreationStartHeadline => 'Starte dein Rezept';

  @override
  String get recipeCreationStartSubtitle =>
      'Importiere von einem Link, tippe es selbst ein oder scanne ein Foto.';

  @override
  String get recipeCreationImportURL => 'Von URL importieren';

  @override
  String get recipeCreationImportURLDesc =>
      'Füge einen Rezeptlink ein und wir holen die Details';

  @override
  String get recipeCreationTypeItIn => 'Selbst eintippen';

  @override
  String get recipeCreationTypeItInDesc =>
      'Beginne mit einem Titel und füge später Zutaten hinzu';

  @override
  String get recipeCreationScanning => 'Wird gescannt…';

  @override
  String get recipeCreationScanPhoto => 'Foto scannen';

  @override
  String get recipeCreationScanPhotoDesc =>
      'Fotografiere eine Rezeptkarte oder Kochbuchseite';

  @override
  String get recipeCreationURLInput => 'Rezept-URL';

  @override
  String get recipeCreationURLHint => 'https://example.com/rezept';

  @override
  String get recipeCreationFetching => 'Wird abgerufen…';

  @override
  String get recipeCreationFetchDetails => 'Details abrufen';

  @override
  String get recipeCreationChooseImage => 'Bild auswählen';

  @override
  String recipeCreationSelectImage(num index) {
    return 'Bild $index auswählen';
  }

  @override
  String get recipeCreationTitleInput => 'Rezepttitel';

  @override
  String get recipeCreationTitleHint => 'Sonntagspfannkuchen';

  @override
  String get recipeCreationDiscardTitle => 'Rezept verwerfen?';

  @override
  String get recipeCreationDiscardBody =>
      'Du hast ungespeicherte Inhalte in diesem Rezept.';

  @override
  String get recipeCreationKeepEditing => 'Weiter bearbeiten';

  @override
  String get recipeCreationDiscard => 'Verwerfen';

  @override
  String get recipeCreationCouldNotScan =>
      'Rezept konnte nicht gescannt werden.';

  @override
  String recipeCreationImported(String parts) {
    return '$parts';
  }

  @override
  String get recipeCreationCouldNotFetch =>
      'Details konnten von diesem Link nicht abgerufen werden.';

  @override
  String get recipeCreationCreated => 'Rezept erstellt';

  @override
  String get recipeCreationCouldNotCreate =>
      'Rezept konnte nicht erstellt werden.';

  @override
  String get recipeCreationImportedTitle => 'Importiertes Rezept';

  @override
  String recipeCreationFromHost(String host) {
    return 'Rezept von $host';
  }

  @override
  String recipeCreationNutrition(String info) {
    return 'Nährwerte: $info';
  }

  @override
  String get recipeCreationNextDetails => 'Weiter: Details';

  @override
  String get recipeCreationNextContent => 'Weiter: Inhalt';

  @override
  String get recipeCreationTitleOverride => 'Titel überschreiben';

  @override
  String get recipeCreationNotesInput => 'Notizen';

  @override
  String get recipeCreationNotesHint => 'Was macht dieses Rezept besonders';

  @override
  String get recipeCreationPrepLabel => 'Vorbereitung (Min.)';

  @override
  String get recipeCreationPrepHint => '10';

  @override
  String get recipeCreationCookLabel => 'Kochen (Min.)';

  @override
  String get recipeCreationCookHint => '20';

  @override
  String get recipeCreationServingsLabel => 'Portionen';

  @override
  String get recipeCreationServingsHint => '4';

  @override
  String get recipeCreationTagsInput => 'Tags';

  @override
  String get recipeCreationTagsHint => 'schnell, vegetarisch';

  @override
  String get recipeCreationSaveForHousehold => 'Für den Haushalt speichern';

  @override
  String get recipeCreationSaveForHouseholdDesc =>
      'Jeder in diesem Haushalt kann dieses Rezept finden und nutzen.';

  @override
  String get recipeCreationSaveForHouseholdPrivate =>
      'Erstmal privat halten. Du kannst es später teilen.';

  @override
  String recipeCreationSharedWithGroups(String names) {
    return 'Geteilt mit $names';
  }

  @override
  String get recipeCreationIngredients => 'Zutaten';

  @override
  String get recipeCreationIngredientsHelper =>
      'Eine Zutat pro Zeile hinzufügen.';

  @override
  String get recipeCreationAddIngredient => 'Zutat hinzufügen';

  @override
  String get recipeCreationIngredientHint => '2 Tassen Mehl';

  @override
  String get recipeCreationSteps => 'Schritte';

  @override
  String get recipeCreationStepsHelper =>
      'Halte jeden Schritt kurz genug, um beim Kochen folgen zu können.';

  @override
  String get recipeCreationAddStep => 'Schritt hinzufügen';

  @override
  String get recipeCreationStepHint => 'Teig verrühren';

  @override
  String get recipeCreationNutritionInput => 'Nährwerte';

  @override
  String get recipeCreationNutritionHint =>
      '520 kcal, 24g Eiweiß, ballaststoffreich';

  @override
  String get recipeCreationCreating => 'Wird erstellt…';

  @override
  String get recipeCreationCreateRecipe => 'Rezept erstellen';

  @override
  String recipeCreationStepLabel(String type) {
    return '$type';
  }

  @override
  String recipeCreationRemoveItem(String type, num index) {
    return '$type $index entfernen';
  }

  @override
  String recipeCreationStepSemantics(
      num index, num total, String label, String status) {
    return 'Schritt $index von $total, $label, $status';
  }

  @override
  String get recipeDetailTitle => 'Rezept';

  @override
  String get recipeDetailDeleteTooltip => 'Rezept löschen';

  @override
  String get recipeDetailAddToList => 'Zur Liste hinzufügen';

  @override
  String get recipeDetailCook => 'Kochen';

  @override
  String get recipeDetailCouldNotLoad => 'Rezept konnte nicht geladen werden';

  @override
  String get recipeDetailDeleteTitle => 'Rezept löschen';

  @override
  String get recipeDetailDeleteBody =>
      'Dies löscht das Rezept dauerhaft. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get recipeDetailSharedLabel => 'Geteilt';

  @override
  String get recipeDetailPrivateLabel => 'Privat';

  @override
  String recipeDetailBy(String author) {
    return 'Von $author';
  }

  @override
  String get recipeDetailPrep => 'Vorbereitung';

  @override
  String get recipeDetailServings => 'Portionen';

  @override
  String get recipeDetailUpdated => 'Aktualisiert';

  @override
  String get recipeDetailNotSet => 'Nicht angegeben';

  @override
  String get recipeDetailNutrition => 'Nährwerte';

  @override
  String get recipeDetailEquipment => 'Ausrüstung';

  @override
  String get recipeDetailIngredients => 'Zutaten';

  @override
  String get recipeDetailSteps => 'Schritte';

  @override
  String get recipeDetailWatchVideo => 'Video ansehen';

  @override
  String get recipeDetailWatchVideoSemantics => 'Rezeptvideo ansehen';

  @override
  String get recipeDetailViewOriginal => 'Originalrezept anzeigen';

  @override
  String get recipeDetailViewOriginalSemantics =>
      'Originalrezept im Browser anzeigen';

  @override
  String get cookModeCouldNotLoad => 'Rezept konnte nicht geladen werden';

  @override
  String get cookModeClose => 'Schließen';

  @override
  String get cookModeServings => 'Portionen';

  @override
  String get cookModeDecreaseServings => 'Portionen verringern';

  @override
  String get cookModeIncreaseServings => 'Portionen erhöhen';

  @override
  String get cookModeStartCooking => 'Kochen starten';

  @override
  String get cookModeGathered => 'bereitgestellt';

  @override
  String get cookModeNotGathered => 'nicht bereitgestellt';

  @override
  String cookModeStepOf(num step, num total) {
    return 'Schritt $step von $total';
  }

  @override
  String get cookModeExitTooltip => 'Kochmodus verlassen';

  @override
  String get cookModeTimerDone => 'Timer fertig!';

  @override
  String get cookModeDoneArrow => 'Fertig →';

  @override
  String get cookModeFinish => 'Abschließen';

  @override
  String cookModeStepLabel(num number) {
    return 'Schritt $number';
  }

  @override
  String cookModeStepDone(num number) {
    return 'Schritt $number erledigt. Zum Wiederholen tippen';
  }

  @override
  String cookModeCurrentStep(num number) {
    return 'Aktueller Schritt $number';
  }

  @override
  String cookModeStepJump(num number, String description) {
    return 'Schritt $number: $description. Tippen, um zu diesem Schritt zu springen';
  }

  @override
  String cookModeBackToStep(num step) {
    return 'Zurück zu Schritt $step';
  }

  @override
  String get cookModeShowIngredients => 'Zutaten anzeigen';

  @override
  String get cookModeIngredients => 'Zutaten';

  @override
  String get cookModeFinished => 'Fertig — gute Arbeit';

  @override
  String get cookModeFinishCooking => 'Kochen beenden';

  @override
  String get cookModeAdvanceStep => 'Fertig, zum nächsten Schritt';

  @override
  String get expenseAppBarTitle => 'Geld';

  @override
  String get expenseScanReceiptTooltip => 'Beleg scannen';

  @override
  String get expenseRecurringTooltip => 'Wiederkehrend';

  @override
  String get expenseAddExpense => 'Ausgabe hinzufügen';

  @override
  String get expenseYouAreOwed => 'Dir steht Geld zu';

  @override
  String get expenseYouOwe => 'Du schuldest Geld';

  @override
  String get expenseAllSquare => 'Ausgeglichen';

  @override
  String expenseSuggestedPayments(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vorgeschlagene Zahlungen',
      one: '$count vorgeschlagene Zahlung',
    );
    return '$_temp0 zum Ausgleichen';
  }

  @override
  String expenseOpenBalances(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count offene Salden',
      one: '$count offener Saldo',
    );
    return '$_temp0 im Haushalt';
  }

  @override
  String get expenseNoOneOwes => 'Niemand muss gerade jemandem etwas zahlen';

  @override
  String get expenseTabTimeline => 'Verlauf';

  @override
  String get expenseTabSettlements => 'Ausgleich';

  @override
  String get expenseToday => 'Heute';

  @override
  String get expenseYesterday => 'Gestern';

  @override
  String get expenseNoExpensesTitle => 'Noch keine Ausgaben';

  @override
  String get expenseNoExpensesDesc =>
      'Verfolge geteilte Kosten mit deinem Haushalt.';

  @override
  String get expenseAddFirstExpense => 'Erste Ausgabe hinzufügen';

  @override
  String get expenseLoadError =>
      'Ausgaben konnten nicht geladen werden. Überprüfe deine Verbindung.';

  @override
  String get expenseLoadMoreError =>
      'Weitere Ausgaben konnten nicht geladen werden.';

  @override
  String expensePaidBy(String payer) {
    return 'Bezahlt von $payer';
  }

  @override
  String expenseConvertedAmount(String amount) {
    return '≈ $amount';
  }

  @override
  String get expenseDeleteTitle => 'Ausgabe löschen';

  @override
  String get expenseDeleteBody =>
      'Dies löscht die Ausgabe und alle zugehörigen Belege dauerhaft. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get expenseSettlementRecorded => 'Ausgleich aufgezeichnet';

  @override
  String get expenseSettlementFailed =>
      'Ausgleich konnte nicht aufgezeichnet werden.';

  @override
  String get expenseSuggestedPaymentsTitle => 'Vorgeschlagene Zahlungen';

  @override
  String get expenseSuggestedPaymentsDesc =>
      'Berechnet aus jeder Ausgabe, Aufteilung und aufgezeichneten Begleichung in diesem Haushalt.';

  @override
  String get expenseAllSettled => 'Alles ausgeglichen!';

  @override
  String get expenseNoOneOwesRight => 'Niemand schuldet gerade jemandem etwas.';

  @override
  String get expenseSameAccount => 'Gleiches Konto';

  @override
  String get expenseFrom => 'Von';

  @override
  String get expenseTo => 'An';

  @override
  String get expenseRecordHelper =>
      'Zeichne diesen Ausgleich auf, nachdem die Zahlung erfolgt ist.';

  @override
  String get expenseRecording => 'Wird aufgezeichnet…';

  @override
  String get expenseRecordSettlement => 'Ausgleich aufzeichnen';

  @override
  String get expenseBalances => 'Salden';

  @override
  String expenseBalancesOpen(num count) {
    return '$count offen';
  }

  @override
  String get expenseExpandBalances => 'Salden ausklappen';

  @override
  String get expenseCollapseBalances => 'Salden einklappen';

  @override
  String get expenseNoBalances =>
      'Noch keine Salden. Füge eine Ausgabe mit Aufteilungen hinzu, um das Kassenbuch zu starten.';

  @override
  String get expenseIsOwed => 'bekommt';

  @override
  String get expenseOwes => 'schuldet';

  @override
  String get expenseSettled => 'ausgeglichen';

  @override
  String get recurringAppBarTitle => 'Wiederkehrend';

  @override
  String get recurringAddRecurring => 'Wiederkehrend hinzufügen';

  @override
  String get recurringAddRecurringTooltip =>
      'Wiederkehrende Ausgabe hinzufügen';

  @override
  String get recurringNoRecurringTitle => 'Keine wiederkehrenden Ausgaben';

  @override
  String get recurringNoRecurringDesc =>
      'Füge eine wiederkehrende Ausgabe hinzu, um regelmäßige Zahlungen zu verfolgen';

  @override
  String get recurringAddExpense => 'Ausgabe hinzufügen';

  @override
  String get recurringPauseTooltip => 'Pausieren';

  @override
  String get recurringResumeTooltip => 'Fortsetzen';

  @override
  String get recurringDeleteTooltip => 'Löschen';

  @override
  String recurringNextDate(String date) {
    return 'Nächste: $date';
  }

  @override
  String get recurringDeleteTitle => 'Wiederkehrende Ausgabe löschen';

  @override
  String get recurringDeleteBody =>
      'Dies verhindert, dass zukünftige Ausgaben erstellt werden.';

  @override
  String get recurringFrequencyDaily => 'Täglich';

  @override
  String get recurringFrequencyWeekly => 'Wöchentlich';

  @override
  String get recurringFrequencyBiweekly => 'Alle 2 Wochen';

  @override
  String get recurringFrequencyMonthly => 'Monatlich';

  @override
  String get recurringFrequencyQuarterly => 'Vierteljährlich';

  @override
  String get recurringFrequencyYearly => 'Jährlich';

  @override
  String get recurringSheetTitle => 'Wiederkehrende Ausgabe hinzufügen';

  @override
  String get recurringSheetDescription => 'Beschreibung';

  @override
  String get recurringSheetAmount => 'Betrag';

  @override
  String get recurringSheetFrequency => 'Häufigkeit';

  @override
  String get recurringSheetPayer => 'Zahler';

  @override
  String get recurringValidationDesc => 'Gib eine Beschreibung ein.';

  @override
  String get recurringValidationAmount => 'Gib einen Betrag ein.';

  @override
  String get recurringValidationPayer => 'Wähle einen Zahler aus.';

  @override
  String get recurringValidationAmountPositive =>
      'Gib einen gültigen Betrag größer als null ein.';

  @override
  String get recurringNoHouseholdDesc =>
      'Tritt einem Haushalt bei oder erstelle einen, um wiederkehrende Ausgaben zu verwalten';

  @override
  String get listAppBarTitle => 'Listen';

  @override
  String get listShoppingTripTooltip => 'Einkaufstour';

  @override
  String get listSearchLabel => 'Listen durchsuchen';

  @override
  String get listSearchHint => 'Name, z. B. Lebensmittel';

  @override
  String get listScanTooltip => 'Beleg oder Liste scannen';

  @override
  String get listSortLabel => 'Sortieren';

  @override
  String get listSortNewest => 'Neueste';

  @override
  String get listSortOldest => 'Älteste';

  @override
  String get listSortAZ => 'A–Z';

  @override
  String get listSortMostItems => 'Meiste Einträge';

  @override
  String get listSortGridView => 'Rasteransicht';

  @override
  String get listNewList => 'Neue Liste';

  @override
  String get listFilterAll => 'Alle';

  @override
  String get listFilterShopping => 'Einkauf';

  @override
  String get listFilterTodo => 'To-do';

  @override
  String get listFilterCustom => 'Eigene';

  @override
  String get listEmptyShopping => 'Keine Einkaufslisten';

  @override
  String get listEmptyTodo => 'Keine To-do-Listen';

  @override
  String get listEmptyCustom => 'Keine eigenen Listen';

  @override
  String get listEmptyAll => 'Noch keine Listen';

  @override
  String get listEmptyShoppingDesc =>
      'Ideal für Lebensmittel, Essensvorbereitung, Wochenendeinkäufe.';

  @override
  String get listEmptyTodoDesc =>
      'Aufgaben, Erledigungen, alles mit einer Checkbox.';

  @override
  String get listEmptyCustomDesc => 'Freiform — deine Liste, deine Regeln.';

  @override
  String get listEmptyAllDesc =>
      'Füge Zeilen in einer Liste hinzu; die ersten erscheinen als Vorschau auf der Karte.';

  @override
  String get listCreateShopping => 'Einkaufsliste erstellen';

  @override
  String get listCreateTodo => 'To-do-Liste erstellen';

  @override
  String get listCreateCustom => 'Eigene Liste erstellen';

  @override
  String get listCreateFirst => 'Deine erste Liste erstellen';

  @override
  String listNoMatch(String query) {
    return 'Keine Listen passen zu \"$query\"';
  }

  @override
  String get listSearchDesc => 'Namen und Listeneinträge werden durchsucht.';

  @override
  String get listRenameTitle => 'Liste umbenennen';

  @override
  String get listCouldNotRename => 'Liste konnte nicht umbenannt werden.';

  @override
  String get listDeleteTitle => 'Liste löschen';

  @override
  String get listDeleteBody =>
      'Dies löscht die Liste und alle ihre Einträge dauerhaft.';

  @override
  String get listCouldNotDelete => 'Liste konnte nicht gelöscht werden.';

  @override
  String listAddItemTo(String name) {
    return 'Eintrag zu $name hinzufügen';
  }

  @override
  String get listItemName => 'Eintragsname';

  @override
  String get listCouldNotAddItem => 'Eintrag konnte nicht hinzugefügt werden.';

  @override
  String get listQuickAddItemTooltip => 'Schnell hinzufügen';

  @override
  String listQuickAddItemSemantics(String name) {
    return 'Eintrag schnell zu $name hinzufügen';
  }

  @override
  String get listOptionsTooltip => 'Listenoptionen';

  @override
  String listSharedWith(String name) {
    return 'Geteilt mit $name';
  }

  @override
  String listDetailEditName(String name) {
    return 'Listenname bearbeiten, $name';
  }

  @override
  String get listDetailCloseSearch => 'Suche schließen';

  @override
  String get listDetailSearchTooltip => 'Suchen';

  @override
  String get listDetailFilterLabel => 'Einträge filtern';

  @override
  String get listDetailFilterHint => 'Name, z. B. Milch';

  @override
  String get listDetailAllCheckedOff => 'Alles abgehakt';

  @override
  String get listDetailClearChecked => 'Erledigte leeren';

  @override
  String get listDetailCheckedOff => 'Erledigt';

  @override
  String get listDetailNothingHere => 'Noch nichts hier';

  @override
  String get listDetailNothingHereDesc =>
      'Fotografiere eine handgeschriebene Liste, einen Kühlschrankzettel oder Screenshot. Wir extrahieren die Einträge.';

  @override
  String get listDetailScanThisList => 'Diese Liste scannen';

  @override
  String get listDetailTypeItem => 'Eintrag eintippen';

  @override
  String get listDetailNoMatch => 'Keine Einträge zu deinem Filter';

  @override
  String get listDetailCouldNotLoad => 'Liste konnte nicht geladen werden.';

  @override
  String get listDetailCouldNotUpdate =>
      'Konnte nicht aktualisiert werden. Bitte versuche es erneut.';

  @override
  String get listDetailCouldNotAddItem =>
      'Eintrag konnte nicht hinzugefügt werden. Bitte versuche es erneut.';

  @override
  String get listDetailCouldNotClear =>
      'Einträge konnten nicht geleert werden. Bitte versuche es erneut.';

  @override
  String listDetailItemDeleted(String name) {
    return '$name gelöscht';
  }

  @override
  String get listDetailCouldNotRestore =>
      'Eintrag konnte nicht wiederhergestellt werden.';

  @override
  String get listDetailCouldNotReorder =>
      'Einträge konnten nicht neu sortiert werden. Bitte versuche es erneut.';

  @override
  String listDetailItemsAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge zur Liste hinzugefügt',
      one: '1 Eintrag zur Liste hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String get listDetailCouldNotStartScan =>
      'Scan konnte nicht gestartet werden. Versuche es erneut.';

  @override
  String get listDetailSetPrice => 'Preis festlegen';

  @override
  String get listDetailPriceInput => 'Preis';

  @override
  String get listDetailPriceHint => '0,00';

  @override
  String get listDetailCouldNotSetPrice =>
      'Preis konnte nicht festgelegt werden.';

  @override
  String get listDetailClearTitle => 'Liste leeren';

  @override
  String listDetailClearBody(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Einträge',
      one: 'Eintrag',
    );
    return 'Dies entfernt alle $count $_temp0. Dies kann nicht rückgängig gemacht werden.';
  }

  @override
  String get listDetailClearConfirm => 'Liste leeren';

  @override
  String get listDetailArchiveTitle => 'Liste archivieren';

  @override
  String get listDetailArchiveBody =>
      'Diese Liste wird für deinen Haushalt ausgeblendet.';

  @override
  String get listDetailFailedArchive => 'Liste konnte nicht archiviert werden.';

  @override
  String get listDetailDeleteTitle => 'Liste löschen';

  @override
  String get listDetailDeleteBody =>
      'Dies löscht die Liste und alle ihre Einträge dauerhaft. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get listDetailCouldNotDelete => 'Liste konnte nicht gelöscht werden.';

  @override
  String get listDetailExpenseGenerated => 'Ausgabe erstellt';

  @override
  String get listDetailCouldNotLoadCostSummary =>
      'Kostenübersicht konnte nicht geladen werden.';

  @override
  String get listDetailCouldNotAddPhoto =>
      'Foto konnte nicht hinzugefügt werden.';

  @override
  String get listDetailCouldNotRemovePhoto =>
      'Foto konnte nicht entfernt werden.';

  @override
  String get listDetailListImage => 'Listenbild';

  @override
  String get listDetailCheckAll => 'Alle abhaken';

  @override
  String get listDetailUncheckAll => 'Alle demarkieren';

  @override
  String get listDetailCostSummary => 'Kostenübersicht';

  @override
  String get listDetailScanList => 'Liste scannen';

  @override
  String get calendarAppBarTitle => 'Kalender';

  @override
  String get calendarViewWeek => 'Woche';

  @override
  String get calendarViewMonth => 'Monat';

  @override
  String get calendarViewAgenda => 'Agenda';

  @override
  String get calendarWeekView => 'Wochenansicht';

  @override
  String get calendarMonthView => 'Monatsansicht';

  @override
  String get calendarAgendaView => 'Agendaansicht';

  @override
  String get calendarPreviousWeek => 'Vorherige Woche';

  @override
  String get calendarNextWeek => 'Nächste Woche';

  @override
  String get calendarPreviousMonth => 'Vorheriger Monat';

  @override
  String get calendarNextMonth => 'Nächster Monat';

  @override
  String get calendarMonthJanuary => 'Januar';

  @override
  String get calendarMonthFebruary => 'Februar';

  @override
  String get calendarMonthMarch => 'März';

  @override
  String get calendarMonthApril => 'April';

  @override
  String get calendarMonthMay => 'Mai';

  @override
  String get calendarMonthJune => 'Juni';

  @override
  String get calendarMonthJuly => 'Juli';

  @override
  String get calendarMonthAugust => 'August';

  @override
  String get calendarMonthSeptember => 'September';

  @override
  String get calendarMonthOctober => 'Oktober';

  @override
  String get calendarMonthNovember => 'November';

  @override
  String get calendarMonthDecember => 'Dezember';

  @override
  String get calendarShortMon => 'Mo';

  @override
  String get calendarShortTue => 'Di';

  @override
  String get calendarShortWed => 'Mi';

  @override
  String get calendarShortThu => 'Do';

  @override
  String get calendarShortFri => 'Fr';

  @override
  String get calendarShortSat => 'Sa';

  @override
  String get calendarShortSun => 'So';

  @override
  String get calendarWeekdayMonday => 'Montag';

  @override
  String get calendarWeekdayTuesday => 'Dienstag';

  @override
  String get calendarWeekdayWednesday => 'Mittwoch';

  @override
  String get calendarWeekdayThursday => 'Donnerstag';

  @override
  String get calendarWeekdayFriday => 'Freitag';

  @override
  String get calendarWeekdaySaturday => 'Samstag';

  @override
  String get calendarWeekdaySunday => 'Sonntag';

  @override
  String get calendarToday => 'Heute';

  @override
  String calendarDayLabel(num day) {
    return 'Tag $day';
  }

  @override
  String calendarDayEvents(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Termine',
      one: '1 Termin',
    );
    return '$_temp0';
  }

  @override
  String get calendarDayMenuHint => 'Öffnet Tagesoptionen';

  @override
  String get calendarNothingPlanned => 'Nichts geplant';

  @override
  String get calendarNothingAhead => 'Nichts anstehend';

  @override
  String get calendarNothingAheadDesc =>
      'Anstehende Aufgaben, Essenspläne und wiederkehrende Ausgaben erscheinen hier.';

  @override
  String get calendarAddChore => 'Aufgabe hinzufügen';

  @override
  String get calendarAddExpense => 'Ausgabe hinzufügen';

  @override
  String get calendarViewInWeek => 'In Woche anzeigen';

  @override
  String get calendarEventMeal => 'Mahlzeit';

  @override
  String get calendarEventChore => 'Aufgabe';

  @override
  String get calendarEventRecurring => 'Wiederkehrend';

  @override
  String get calendarEventExpense => 'Ausgabe';

  @override
  String get calendarEventReminder => 'Erinnerung';

  @override
  String calendarServingsPpl(num servings) {
    return '$servings Pers. ';
  }

  @override
  String get calendarNoHouseholdDesc =>
      'Tritt einem Haushalt bei oder erstelle einen, um den Kalender zu sehen';

  @override
  String get calendarCreateHousehold => 'Haushalt erstellen';

  @override
  String calendarWeekHeader(String weekStart, String weekEnd) {
    return '$weekStart – $weekEnd';
  }

  @override
  String calendarMonthHeader(String month, num year) {
    return '$month $year';
  }

  @override
  String get mealPlanAppBarTitle => 'Essensplan';

  @override
  String get mealPlanGenerateShoppingList => 'Einkaufsliste erstellen';

  @override
  String get mealPlanPreviousWeek => 'Vorherige Woche';

  @override
  String get mealPlanNextWeek => 'Nächste Woche';

  @override
  String get mealPlanBreakfast => 'Frühstück';

  @override
  String get mealPlanLunch => 'Mittagessen';

  @override
  String get mealPlanDinner => 'Abendessen';

  @override
  String get mealPlanAddMeal => 'Mahlzeit hinzufügen';

  @override
  String get mealPlanRecipeFallback => 'Rezept';

  @override
  String mealPlanServings(num servings) {
    return '$servings P.';
  }

  @override
  String mealPlanShoppingListCreated(num count) {
    return 'Einkaufsliste mit $count Einträgen erstellt';
  }

  @override
  String get mealPlanTrackCosts => 'Kosten verfolgen';

  @override
  String get mealPlanCouldNotAdd => 'Mahlzeit konnte nicht hinzugefügt werden.';

  @override
  String get mealPlanCouldNotRemove => 'Mahlzeit konnte nicht entfernt werden.';

  @override
  String get mealPlanCouldNotUpdate =>
      'Mahlzeit konnte nicht aktualisiert werden.';

  @override
  String get mealPlanPickRecipe => 'Rezept auswählen';

  @override
  String get mealPlanCouldNotLoadRecipes =>
      'Rezepte konnten nicht geladen werden';

  @override
  String get mealPlanNoRecipes => 'Noch keine Rezepte';

  @override
  String get mealPlanAddRecipesDesc =>
      'Füge Rezepte hinzu, um Mahlzeiten zu planen';

  @override
  String get mealPlanSearchRecipes => 'Rezepte suchen…';

  @override
  String mealPlanNoMatch(String query) {
    return 'Keine Rezepte passen zu \"$query\"';
  }

  @override
  String get mealPlanServingsSheet => 'Portionen';

  @override
  String get mealPlanFewerServings => 'Weniger Portionen';

  @override
  String get mealPlanMoreServings => 'Mehr Portionen';

  @override
  String mealPlanOpenRecipe(String slot) {
    return 'Rezept für $slot öffnen';
  }

  @override
  String mealPlanAddMealFor(String slot) {
    return 'Mahlzeit für $slot hinzufügen';
  }

  @override
  String get accountAppBarTitle => 'Du';

  @override
  String get accountFailedLoadProfile =>
      'Profil konnte nicht geladen werden. Bitte versuche es erneut.';

  @override
  String get accountFailedSaveName => 'Name konnte nicht gespeichert werden';

  @override
  String get accountEditYourName => 'Deinen Namen bearbeiten';

  @override
  String get accountChangePassword => 'Passwort ändern';

  @override
  String get accountFillPasswordFields => 'Fülle alle Passwortfelder aus.';

  @override
  String get accountPasswordMinLength =>
      'Das neue Passwort muss mindestens 6 Zeichen haben.';

  @override
  String get accountPasswordsMismatch =>
      'Die neuen Passwörter stimmen nicht überein.';

  @override
  String get accountPasswordChanged => 'Passwort geändert';

  @override
  String get accountCurrentPassword => 'Aktuelles Passwort';

  @override
  String get accountNewPassword => 'Neues Passwort';

  @override
  String get accountConfirmPassword => 'Neues Passwort bestätigen';

  @override
  String get accountChangePasswordButton => 'Passwort ändern';

  @override
  String get accountTermsTitle => 'Nutzungsbedingungen';

  @override
  String get accountTermsBody =>
      'Nutze mitlist verantwortungsvoll und respektiere die Privatsphäre deiner Haushaltsmitglieder. Missbrauche keine geteilten Funktionen oder Daten. mitlist wird ohne Gewährleistung bereitgestellt.';

  @override
  String get accountDeleteAccount => 'Konto löschen';

  @override
  String get accountDeleteAccountBody =>
      'Dies löscht dein Konto und alle zugehörigen Daten dauerhaft. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get accountLogOut => 'Abmelden';

  @override
  String get accountDeleteAccountButton => 'Konto löschen';

  @override
  String get accountHouseholdSection => 'Haushalt';

  @override
  String accountSwitchToHousehold(String name) {
    return 'Zu $name wechseln';
  }

  @override
  String get accountNotificationInbox => 'Benachrichtigungen';

  @override
  String get accountNotificationPreferences => 'Benachrichtigungseinstellungen';

  @override
  String get accountAppearance => 'Erscheinungsbild';

  @override
  String get accountAppearanceSystem => 'System';

  @override
  String get accountAppearanceLight => 'Hell';

  @override
  String get accountAppearanceDark => 'Dunkel';

  @override
  String get accountChangePasswordRow => 'Passwort ändern';

  @override
  String get accountVersion => 'Version';

  @override
  String get accountTermsRow => 'Nutzungsbedingungen';

  @override
  String get accountOpenDataRow => 'Offene Daten';

  @override
  String get accountOpenDataTitle => 'Open-Data-Quellen';

  @override
  String get accountOpenDataBody =>
      'Einige Markennamen für Lebensmittel stammen von Open Food Facts (openfoodfacts.org), verwendet unter der Open Database License (ODbL) v1.0. Die abgeleitete Markenliste wird getrennt von den eigenen Daten von mitlist gehalten.';

  @override
  String get accountGuestTitle => 'Du nutzt ein Gastkonto';

  @override
  String get accountGuestDesc =>
      'Erstelle ein vollständiges Konto, um deine Daten dauerhaft zu behalten und alle Funktionen zu nutzen.';

  @override
  String get accountCreateFullAccount => 'Vollständiges Konto erstellen';

  @override
  String get accountExportCSV => 'Ausgaben exportieren (CSV)';

  @override
  String get accountShareJSON => 'Ausgaben teilen (JSON)';

  @override
  String get accountCopyJSON => 'Ausgaben kopieren (JSON)';

  @override
  String get accountJSONCopied => 'Ausgaben-JSON in die Zwischenablage kopiert';

  @override
  String get accountCreateAccountTitle => 'Dein Konto erstellen';

  @override
  String get accountFillAllFields => 'Bitte fülle alle Felder aus.';

  @override
  String get accountYourName => 'Dein Name';

  @override
  String get accountYourNameHint => 'z. B. Max Mustermann';

  @override
  String get accountEmail => 'E-Mail';

  @override
  String get accountEmailHint => 'du@example.com';

  @override
  String get accountPassword => 'Passwort';

  @override
  String get accountCreatingAccount => 'Konto wird erstellt…';

  @override
  String get accountCreateAccount => 'Konto erstellen';

  @override
  String get accountCreatedWelcome => 'Konto erstellt. Willkommen!';

  @override
  String get notificationsAppBarTitle => 'Benachrichtigungen';

  @override
  String get notificationsMarkAllRead => 'Alle als gelesen markieren';

  @override
  String get notificationsFailedLoad =>
      'Benachrichtigungen konnten nicht geladen werden.';

  @override
  String get notificationsFailedLoadMore =>
      'Weitere Benachrichtigungen konnten nicht geladen werden.';

  @override
  String get notificationsFailedMarkAllRead =>
      'Alle-als-gelesen-Markierung fehlgeschlagen.';

  @override
  String get notificationsFailedMarkRead =>
      'Als-gelesen-Markierung fehlgeschlagen.';

  @override
  String get notificationsNoHouseholdDesc =>
      'Erstelle einen Haushalt oder tritt einem bei, um Benachrichtigungen zu erhalten.';

  @override
  String get notificationsNoNotifications => 'Noch keine Benachrichtigungen';

  @override
  String get notificationsNoNotificationsDesc =>
      'Wenn jemand eine Aufgabe hinzufügt, eine Rechnung aufteilt oder dich erwähnt, erscheint es hier.';

  @override
  String notificationsUnreadLabel(String title) {
    return 'Ungelesen, $title';
  }

  @override
  String get notifPrefAppBarTitle => 'Benachrichtigungseinstellungen';

  @override
  String get notifPrefFailedLoad =>
      'Benachrichtigungseinstellungen konnten nicht geladen werden.';

  @override
  String get notifPrefNoHouseholdDesc =>
      'Tritt einem Haushalt bei oder erstelle einen, um Benachrichtigungseinstellungen zu konfigurieren.';

  @override
  String get notifPrefNoPreferences => 'Noch keine Einstellungen';

  @override
  String get notifPrefNoPreferencesDesc =>
      'Einstellungen werden erstellt, wenn du einem Haushalt beitrittst. Falls du gerade beigetreten bist, sollten sie bald erscheinen.';

  @override
  String get notifPrefGroupName => 'Benachrichtigungen';

  @override
  String get notifPrefChoreDueReminders => 'Erinnerungen an fällige Aufgaben';

  @override
  String get notifPrefChoreDueRemindersDesc =>
      'Wenn eine Aufgabe bald fällig ist';

  @override
  String get notifPrefChoreDueDayOf => 'Aufgaben am Fälligkeitstag';

  @override
  String get notifPrefChoreDueDayOfDesc =>
      'Am Tag, an dem eine Aufgabe fällig ist';

  @override
  String get notifPrefListItemAdded => 'Listeneintrag hinzugefügt';

  @override
  String get notifPrefListItemAddedDesc =>
      'Wenn jemand etwas zu einer geteilten Liste hinzufügt';

  @override
  String get notifPrefExpenseCreated => 'Ausgabe erstellt';

  @override
  String get notifPrefExpenseCreatedDesc =>
      'Wenn eine neue Ausgabe eingetragen wird';

  @override
  String get notifPrefMealPlanChanged => 'Essensplan geändert';

  @override
  String get notifPrefMealPlanChangedDesc =>
      'Wenn der Essensplan aktualisiert wird';

  @override
  String get notifPrefWeeklyDigest => 'Wöchentliche Zusammenfassung';

  @override
  String get notifPrefWeeklyDigestDesc =>
      'Eine Zusammenfassung der Haushaltsaktivität';

  @override
  String get notifPrefPinwallReminders => 'Pinwall-Erinnerungen';

  @override
  String get notifPrefPinwallRemindersDesc =>
      'Wenn jemand eine Erinnerung für später anpinnt';

  @override
  String get notifPrefPushNotifications => 'Push-Benachrichtigungen';

  @override
  String get notifPrefPushNotificationsDesc =>
      'Benachrichtigungen auf diesem Gerät empfangen';

  @override
  String get shoppingTripAppBarTitle => 'Einkaufstour';

  @override
  String get shoppingTripChooseStore => 'Geschäft wählen';

  @override
  String get shoppingTripNoLists => 'Noch keine Listen';

  @override
  String get shoppingTripNoListsDesc =>
      'Erstelle eine Einkaufsliste, um eine Tour zu starten';

  @override
  String get shoppingTripAllCaughtUp => 'Alles erledigt';

  @override
  String get shoppingTripAllCaughtUpDesc =>
      'Keine offenen Einträge in deinen Listen. Füge Einträge hinzu, um sie hier zu sehen.';

  @override
  String get shoppingTripSortedByAisles => 'Nach Gängen sortiert';

  @override
  String shoppingTripSortedByStoreAisles(String store) {
    return 'Nach $store-Gängen sortiert';
  }

  @override
  String get shoppingTripMarkDone => 'Als gekauft markieren';

  @override
  String shoppingTripBasketBar(num collected, String price) {
    return '/ $collected gesammelt$price';
  }

  @override
  String shoppingTripItemsWorthDone(String amount) {
    return '$amount an Artikeln als gekauft markiert';
  }

  @override
  String get shoppingTripAddExpense => 'Ausgabe hinzufügen';

  @override
  String get shoppingTripStampDone => 'FERTIG';

  @override
  String shoppingTripStampItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Artikel',
      one: '1 Artikel',
    );
    return '$_temp0';
  }

  @override
  String get shoppingTripFallbackList => 'Liste';

  @override
  String shoppingTripMarkNotPurchased(String item) {
    return '$item als nicht gekauft markieren';
  }

  @override
  String shoppingTripMarkPurchased(String item) {
    return '$item als gekauft markieren';
  }

  @override
  String get scannerAppBarTitle => 'Scanner';

  @override
  String get scannerShoppingAt => 'Einkaufen bei';

  @override
  String get scannerChooseStore => 'Wähle dein Geschäft';

  @override
  String get scannerHintText =>
      'Scanne einen Beleg, eine Liste, ein Rezept\noder eine Aufgabenerinnerung';

  @override
  String get scannerAnalyzing => 'Wird analysiert…';

  @override
  String get scannerScanGrocery => 'Einkaufsliste scannen';

  @override
  String get scannerScanReceipt => 'Beleg, Rezept oder Aufgabe scannen';

  @override
  String get scannerAnalyzeThis => 'Dieses Bild analysieren';

  @override
  String get scannerTakeOrChoose => 'Foto aufnehmen oder auswählen';

  @override
  String get scannerPickDifferent => 'Anderes Bild wählen';

  @override
  String get scannerScanSheetTitle => 'Einkaufsliste scannen';

  @override
  String get scannerAddScanTitle => 'Scan hinzufügen';

  @override
  String get scannerTakePhoto => 'Foto aufnehmen';

  @override
  String get scannerChooseFromGallery => 'Aus Galerie wählen';

  @override
  String get scannerTypeReceipt => 'Beleg';

  @override
  String get scannerTypeShoppingList => 'Einkaufsliste';

  @override
  String get scannerTypeRecipe => 'Rezept';

  @override
  String get scannerTypeChore => 'Aufgabe';

  @override
  String scannerDetectedType(String type) {
    return 'Erkannt: $type';
  }

  @override
  String scannerItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge',
      one: '$count Eintrag',
    );
    return '$_temp0';
  }

  @override
  String scannerAndMore(num count) {
    return '…und $count weitere';
  }

  @override
  String scannerStepCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Schritte',
      one: '$count Schritt',
    );
    return '$_temp0';
  }

  @override
  String scannerTotal(String amount) {
    return 'Gesamt: $amount';
  }

  @override
  String get scannerAddToLists => 'Zu Listen hinzufügen';

  @override
  String get scannerCreateExpense => 'Ausgabe erstellen';

  @override
  String get scannerCreateRecipe => 'Rezept erstellen';

  @override
  String get scannerCreateChore => 'Aufgabe erstellen';

  @override
  String get scannerUseThis => 'Übernehmen';

  @override
  String get scannerScanAgain => 'Erneut scannen';

  @override
  String get smartCaptureBack => 'Zurück';

  @override
  String get smartCaptureShowEnhanced => 'Verbessert anzeigen';

  @override
  String get smartCaptureOriginal => 'Original';

  @override
  String get smartCaptureUseAnyway => 'Trotzdem verwenden';

  @override
  String get smartCaptureUseScan => 'Scan verwenden';

  @override
  String get smartCaptureRetake => 'Neu aufnehmen';

  @override
  String get smartCaptureReady => 'Bereit';

  @override
  String get smartCaptureUsable => 'Brauchbar';

  @override
  String get smartCaptureRetakeSuggested => 'Neuaufnahme empfohlen';

  @override
  String get liveSmartCaptureNoCamera => 'Keine Kamera verfügbar.';

  @override
  String get liveSmartCaptureCouldNotOpen =>
      'Kamera konnte nicht geöffnet werden.';

  @override
  String get liveSmartCaptureFrameList => 'Liste einrahmen';

  @override
  String get liveSmartCaptureCameraUnavailable => 'Kamera nicht verfügbar';

  @override
  String get liveSmartCaptureGallery => 'Galerie';

  @override
  String get liveSmartCaptureScan => 'Scannen';

  @override
  String get liveSmartCaptureCouldNotCapture =>
      'Foto konnte nicht aufgenommen werden.';

  @override
  String scanReviewAddToList(String list) {
    return 'Zu $list hinzufügen';
  }

  @override
  String get scanReviewReviewItems => 'Einträge prüfen';

  @override
  String scanReviewAcceptAll(num count) {
    return 'Alle übernehmen ($count)';
  }

  @override
  String get scanReviewStoreLabel => 'Geschäft:';

  @override
  String get scanReviewYouMightNeed => 'Das könntest du auch brauchen';

  @override
  String get scanReviewIgnored => 'Ignoriert';

  @override
  String get scanReviewNewList => 'Neue Liste';

  @override
  String get scanReviewAddToWhichList => 'Zu welcher Liste hinzufügen?';

  @override
  String get scanReviewNewListOption => 'Neue Liste…';

  @override
  String get scanReviewScannedList => 'Gescannte Liste';

  @override
  String get scanReviewCreateList => 'Liste erstellen';

  @override
  String get scanReviewAdding => 'Wird hinzugefügt…';

  @override
  String scanReviewRemoveItem(String item) {
    return '$item entfernen';
  }

  @override
  String get scanReviewRestore => 'Wiederherstellen';

  @override
  String get scanReviewEditItem => 'Eintrag bearbeiten';

  @override
  String scanReviewOCRSaw(String text) {
    return 'OCR erkannt: \"$text\"';
  }

  @override
  String get scanReviewItemName => 'Eintragsname';

  @override
  String get scanReviewQty => 'Menge';

  @override
  String get scanReviewUnit => 'Einheit';

  @override
  String get scanReviewDidYouMean => 'Meintest du?';

  @override
  String get shareTargetAppBarTitle => 'In mitlist speichern';

  @override
  String get shareTargetSharedText => 'Geteilter Text';

  @override
  String get shareTargetPasteHint =>
      'Füge den geteilten Text hier ein oder tippe ihn…';

  @override
  String get shareTargetAddPhotos => 'Fotos hinzufügen';

  @override
  String shareTargetPhotosAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Fotos hinzugefügt',
      one: '1 Foto hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String get shareTargetPreviewPlaceholder =>
      'Füge jetzt Text hier ein oder sende Inhalte aus der Teilen-Erweiterung, wenn diese Integration verfügbar ist.';

  @override
  String get shareTargetDestLists => 'Listen';

  @override
  String get shareTargetDestListsDesc =>
      'In einer Einkaufs- oder To-do-Liste speichern';

  @override
  String get shareTargetDestPinwall => 'Pinwall';

  @override
  String get shareTargetDestPinwallDesc =>
      'Eine Notiz (und optional Fotos) an deinen Haushalt senden';

  @override
  String get shareTargetDestRecipes => 'Rezepte';

  @override
  String get shareTargetDestRecipesDesc =>
      'Zu gespeicherten Rezepten hinzufügen';

  @override
  String get shareTargetSelectHousehold => 'Haushalt auswählen';

  @override
  String get shareTargetSaved => 'Gespeichert';

  @override
  String get shareTargetFailedSave =>
      'Speichern fehlgeschlagen. Bitte versuche es erneut.';

  @override
  String get shareTargetValidationText =>
      'Füge etwas ein oder tippe etwas, um zu speichern.';

  @override
  String get shareTargetValidationNote =>
      'Füge eine Notiz oder mindestens ein Foto hinzu.';

  @override
  String get shareTargetValidationHousehold =>
      'Erstelle zuerst einen Haushalt oder tritt einem bei.';

  @override
  String get expenseCreationTitle => 'Ausgabe hinzufügen';

  @override
  String get expenseCreationAmountHint => '0,00';

  @override
  String expenseCreationRateHint(String currency, String groupCurrency) {
    return 'Kurs: 1 $currency = ? $groupCurrency';
  }

  @override
  String get expenseCreationWhatsItFor => 'Wofür ist das?';

  @override
  String get expenseCreationNotesHint => 'Notizen (optional)';

  @override
  String get expenseCreationDateLabel => 'Ausgabedatum. Zum Ändern tippen.';

  @override
  String get expenseCreationReceiptButton => 'Beleg';

  @override
  String get expenseCreationScanning => 'Wird gescannt…';

  @override
  String get expenseCreationScanButton => 'Scannen';

  @override
  String get expenseCreationReceiptAttached =>
      'Beleg angehängt. Zum erneuten Scannen tippen.';

  @override
  String get expenseCreationScanReceiptSemantics => 'Beleg per Kamera scannen';

  @override
  String get expenseCreationSplitMode => 'Aufteilungsmodus';

  @override
  String expenseCreationSplitTotal(String amount) {
    return 'Gesamt $amount';
  }

  @override
  String get expenseCreationSplitEqual => 'Gleich';

  @override
  String get expenseCreationSplitExact => 'Exakt';

  @override
  String get expenseCreationSplitShares => 'Anteile';

  @override
  String get expenseCreationSplitPercent => 'Prozent';

  @override
  String get expenseCreationSplitHintExact =>
      'Gib den exakten Betrag ein, den jede Person schuldet.';

  @override
  String get expenseCreationSplitHintPercent =>
      'Gib den Anteil jeder Person ein; Summe muss 100 % sein.';

  @override
  String get expenseCreationSplitHintShares =>
      'Nach Anteilen aufteilen, z. B. 2 Anteile zahlen doppelt.';

  @override
  String get expenseCreationSplitHintEqual =>
      'Den Gesamtbetrag gleichmäßig auf die ausgewählten Mitglieder aufteilen.';

  @override
  String get expenseCreationSplitSharesLabel => 'Anteile';

  @override
  String get expenseCreationSplitValuesAmount => 'Betrag';

  @override
  String get expenseCreationSplitValuesPercent => '%';

  @override
  String get expenseCreationPaidBy => 'Bezahlt von';

  @override
  String get expenseCreationSplitWith => 'Aufteilen mit';

  @override
  String get expenseCreationSelectSplitter =>
      'Wähle mindestens eine Person zum Aufteilen aus.';

  @override
  String get expenseCreationEnterAmount =>
      'Gib oben einen Betrag ein, um die Anteile zu sehen.';

  @override
  String get expenseCreationValidationAmount =>
      'Gib einen gültigen Betrag größer als null ein.';

  @override
  String get expenseCreationValidationRate =>
      'Gib einen Umrechnungskurs größer als null ein.';

  @override
  String get expenseCreationReceiptUploadFailed =>
      'Ausgabe gespeichert, aber Beleg-Upload fehlgeschlagen.';

  @override
  String get expenseCreationExpenseAdded => 'Ausgabe hinzugefügt';

  @override
  String get pinwallBoardLabel => 'Pinwall';

  @override
  String get pinwallSnapshot => 'Auf einen Blick';

  @override
  String get pinwallDragHint =>
      'Notizen zum Verschieben ziehen  ·  Zum Zoomen kneifen';

  @override
  String get pinwallCloseBoard => 'Board schließen';

  @override
  String get pinwallEmptyBoard =>
      'Die Wand ist leer.\nPinne eine Notiz vom Hub an, um zu starten.';

  @override
  String pinwallNoteSemantics(String user, String content) {
    return '$user · $content';
  }

  @override
  String pinwallReminderLabel(String text) {
    return 'Erinnerung · $text';
  }

  @override
  String pinwallRemindedLabel(String text) {
    return 'Erinnert · $text';
  }

  @override
  String get pinwallChooseReminderDate => 'Erinnerungsdatum wählen';

  @override
  String get pinwallChooseReminderTime => 'Erinnerungszeit wählen';

  @override
  String get pinwallLinkTo => 'Verknüpfen mit…';

  @override
  String get pinwallLinkExpense => 'Einer Ausgabe';

  @override
  String get pinwallRemoveLink => 'Verknüpfung entfernen';

  @override
  String pinwallSelectEntity(String type) {
    return '$type auswählen';
  }

  @override
  String get pinwallOpenBoard => 'Pinwall-Board öffnen';

  @override
  String get pinwallLinkToChore => 'Mit Aufgabe, Liste verknüpfen…';

  @override
  String get pinwallPickFutureTime => 'Wähle eine Zeit in der Zukunft.';

  @override
  String get pinwallCouldNotLoadEntities =>
      'Entitäten konnten nicht geladen werden.';

  @override
  String get pinwallPinned => 'An die Wand gepinnt';

  @override
  String get pinwallOpenBoardBtn => 'Board öffnen';

  @override
  String get pinwallPostHint => 'Eine Notiz an den Haushalt senden…';

  @override
  String get pinwallAddReminder => 'Erinnerung hinzufügen';

  @override
  String pinwallReminderSet(String label) {
    return 'Erinnerung für $label gesetzt. Zum Ändern tippen.';
  }

  @override
  String get pinwallClearReminder => 'Erinnerung löschen';

  @override
  String get pinwallAttachPhoto => 'Foto anhängen';

  @override
  String get pinwallUploading => 'Wird hochgeladen…';

  @override
  String get pinwallPosting => 'Wird gepostet…';

  @override
  String get pinwallPinIt => 'Anpinnen';

  @override
  String get pinwallCouldNotLoadImage => 'Bild konnte nicht geladen werden.';

  @override
  String get pinwallRemoveFromPost => 'Vom Post entfernen';

  @override
  String get pinwallCouldNotRemovePhoto => 'Foto konnte nicht entfernt werden.';

  @override
  String get pinwallCouldNotAddPhoto => 'Foto konnte nicht hinzugefügt werden.';

  @override
  String get pinwallLinkedList => 'Verknüpfte Liste';

  @override
  String get pinwallLinkedChore => 'Verknüpfte Aufgabe';

  @override
  String get pinwallLinkedExpense => 'Verknüpfte Ausgabe';

  @override
  String pinwallOpenLinkedEntity(String entity) {
    return 'Verknüpfte $entity öffnen';
  }

  @override
  String get pinwallPostOptions => 'Post-Optionen';

  @override
  String get pinwallDeletePin => 'Pin löschen';

  @override
  String get pinwallDeletePinBody =>
      'Dieser Pin wird dauerhaft gelöscht. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get pinwallAddPhotoMenu => 'Foto hinzufügen';

  @override
  String get tonightBreakfast => 'Heute · Frühstück';

  @override
  String get tonightLunch => 'Heute · Mittagessen';

  @override
  String tonightOpenRecipe(String title) {
    return 'Heute Abend: $title. Rezept öffnen';
  }

  @override
  String get captureHintClearer => 'Klareres Foto versuchen';

  @override
  String get captureHintHoldSteady => 'Ruhig halten';

  @override
  String get captureHintMoreLight => 'Mehr Licht suchen';

  @override
  String get captureHintReduceGlare => 'Blendung reduzieren';

  @override
  String get captureHintMoveCloser => 'Näher rangehen';

  @override
  String get accountLanguage => 'Sprache';

  @override
  String get accountLanguageSystem => 'System';

  @override
  String get navHome => 'Start';

  @override
  String get navChores => 'Aufgaben';

  @override
  String get navMoney => 'Geld';

  @override
  String get navLists => 'Listen';

  @override
  String get navKitchen => 'Küche';

  @override
  String get offlineBannerTitle => 'Sync-Status';

  @override
  String get offlineBannerStatusOffline => 'Offline';

  @override
  String get offlineBannerStatusPending => 'Ausstehend';

  @override
  String get offlineBannerStatusFailed => 'Fehlgeschlagen';

  @override
  String get offlineBannerRetryHint =>
      'Änderungen werden automatisch wiederholt, wenn die Verbindung wiederhergestellt ist.';

  @override
  String get offlineBannerOfflineHint =>
      'Du kannst offline weiter Änderungen vornehmen. Alles wird synchronisiert, sobald du wieder verbunden bist.';

  @override
  String get offlineBannerBarOffline =>
      'Offline – Änderungen werden bei Verbindung synchronisiert';

  @override
  String offlineBannerSyncingCount(num count) {
    return 'Synchronisiere $count Änderungen…';
  }

  @override
  String get offlineBannerSyncing => 'Synchronisiere Änderungen…';

  @override
  String offlineBannerFailedCount(num count) {
    return 'Konnte $count Änderungen nicht synchronisieren';
  }

  @override
  String get offlineBannerFailedOne =>
      'Konnte eine Änderung nicht synchronisieren';

  @override
  String get offlineBannerRetry => 'Wiederholen';

  @override
  String get composerNewItem => 'Neuer Eintrag';

  @override
  String get composerScanList => 'Liste scannen';

  @override
  String get composerAddItem => 'Eintrag hinzufügen';

  @override
  String get listItemViewPhoto => 'Foto ansehen';

  @override
  String get listItemReplacePhoto => 'Foto ersetzen';

  @override
  String get listItemAddPhoto => 'Foto hinzufügen';

  @override
  String get listItemRemovePhoto => 'Foto entfernen';

  @override
  String get listItemSetPrice => 'Preis festlegen';

  @override
  String get listItemDeleteAction => 'Löschen';

  @override
  String get listItemReorder => 'Neu anordnen';

  @override
  String listItemMarkUnchecked(String name) {
    return '$name als unerledigt markieren';
  }

  @override
  String listItemMarkChecked(String name) {
    return '$name als erledigt markieren';
  }

  @override
  String listItemViewPhotoFor(String name) {
    return 'Foto für $name ansehen';
  }

  @override
  String get listItemFailedSave =>
      'Speichern fehlgeschlagen – tippe auf die Sync-Leiste zum Wiederholen';

  @override
  String get listItemLongPressHint => 'Lang drücken für weitere Optionen';

  @override
  String get scanCheckListPhoto => 'Listenfoto prüfen';

  @override
  String get scanReadingList => 'Liste wird gelesen…';

  @override
  String get scanCouldNotProcess =>
      'Bild konnte nicht verarbeitet werden. Bitte versuche es erneut.';

  @override
  String get scanSnapYourList => 'Liste fotografieren';

  @override
  String get scanTakePhoto => 'Foto aufnehmen';

  @override
  String get scanChooseFromGallery => 'Aus Galerie wählen';

  @override
  String get appDialogClose => 'Schließen';

  @override
  String get appDialogPressBack => 'Zurück drücken zum Schließen';

  @override
  String get shellNotifications => 'Benachrichtigungen';

  @override
  String get shellAccount => 'Konto';

  @override
  String get errorSomethingWentWrong => 'Etwas ist schiefgegangen';

  @override
  String filterRemoveLabel(String label) {
    return '$label-Filter entfernen';
  }

  @override
  String get currencyDropdownLabel => 'Währung';

  @override
  String get passwordStrengthWeak => 'Schwach';

  @override
  String get passwordStrengthFair => 'Mäßig';

  @override
  String get passwordStrengthGood => 'Gut';

  @override
  String get passwordStrengthStrong => 'Stark';

  @override
  String get checkToggleChecked => 'Aktiviert';

  @override
  String get checkToggleNotChecked => 'Deaktiviert';

  @override
  String get notificationsDeleteNotification => 'Benachrichtigung löschen';

  @override
  String get calendarTomorrow => 'Morgen';

  @override
  String get scannerCheckScan => 'Scan prüfen';

  @override
  String get scannerCheckGrocery => 'Einkaufsliste prüfen';

  @override
  String recipeCreationNoItemsYet(String type) {
    return 'Noch keine $type.';
  }

  @override
  String get captureHintReady => 'Bereit zum Scannen';

  @override
  String get captureHintUsable => 'Sieht brauchbar aus';

  @override
  String get authLoginTitle => 'Anmelden';

  @override
  String get authLoginEmail => 'E-Mail';

  @override
  String get authLoginYouExample => 'du@example.com';

  @override
  String get authLoginPassword => 'Passwort';

  @override
  String get authLoginYourPassword => 'Dein Passwort';

  @override
  String get authLoginForgotPassword => 'Passwort vergessen?';

  @override
  String get authLoginSignInButton => 'Anmelden';

  @override
  String get authLoginSigningIn => 'Wird angemeldet…';

  @override
  String get authLoginNoAccount => 'Kein Konto?';

  @override
  String get authLoginCreateOne => 'Konto erstellen';

  @override
  String get authLoginFillAllFields => 'Fülle alle Felder aus.';

  @override
  String get authLoginEmailRequired => 'E-Mail ist erforderlich.';

  @override
  String get authLoginPasswordRequired => 'Passwort ist erforderlich.';

  @override
  String get authLoginGenericError =>
      'Anmeldung fehlgeschlagen. Überprüfe deine Verbindung und versuche es erneut.';

  @override
  String get authLoginRememberMe => 'Angemeldet bleiben';

  @override
  String get authLoginRememberMeOn => 'Angemeldet bleiben: ein';

  @override
  String get authLoginRememberMeOff => 'Angemeldet bleiben: aus';

  @override
  String get authLoginGoogle => 'Mit Google fortfahren';

  @override
  String get authLoginApple => 'Mit Apple fortfahren';

  @override
  String authLoginOAuthUnsupported(String provider) {
    return '$provider-Anmeldung ist derzeit nur im Web, auf Android und iOS verfügbar.';
  }

  @override
  String get authLoginResetPasswordTitle => 'Passwort zurücksetzen';

  @override
  String get authLoginSendResetCode => 'Code senden';

  @override
  String get authLoginResetCodeLabel => 'Code';

  @override
  String get authLoginResetCodeHint => 'Füge den Code aus deiner E-Mail ein';

  @override
  String get authLoginResetPasswordButton => 'Passwort zurücksetzen';

  @override
  String get authLoginResetCodeSent =>
      'Falls diese E-Mail existiert, wurde ein Code gesendet.';

  @override
  String get authLoginResetFillAllFields =>
      'Fülle den Code und beide Passwortfelder aus.';

  @override
  String get authLoginResetSuccess =>
      'Passwort erfolgreich zurückgesetzt. Du kannst dich jetzt anmelden.';

  @override
  String get authSignupTitle => 'Konto erstellen';

  @override
  String get authSignupFirstName => 'Vorname';

  @override
  String get authSignupFirstNameHint => 'Max';

  @override
  String get authSignupLastName => 'Nachname';

  @override
  String get authSignupLastNameHint => 'Mustermann';

  @override
  String get authSignupEmail => 'E-Mail';

  @override
  String get authSignupEmailHint => 'du@example.com';

  @override
  String get authSignupPassword => 'Passwort';

  @override
  String get authSignupPasswordHint => 'Mindestens 6 Zeichen';

  @override
  String get authSignupCreateAccount => 'Konto erstellen';

  @override
  String get authSignupCreatingAccount => 'Konto wird erstellt…';

  @override
  String get authSignupHaveAccount => 'Hast du ein Konto?';

  @override
  String get authSignupSignInLink => 'Anmelden';

  @override
  String get authSignupFillAllFields => 'Fülle alle Felder aus.';

  @override
  String get authSignupPasswordMinLength =>
      'Passwort muss mindestens 6 Zeichen lang sein.';

  @override
  String get authSignupJoinTitle => 'Haushalt beitreten';

  @override
  String get authSignupAccountCreated => 'Konto erstellt. Willkommen!';

  @override
  String get authSignupNameRequired => 'Name ist erforderlich.';

  @override
  String get authSignupEmailRequired => 'E-Mail ist erforderlich.';

  @override
  String get authSignupPasswordRequired => 'Passwort ist erforderlich.';

  @override
  String get authSignupGenericError =>
      'Kontoerstellung fehlgeschlagen. Überprüfe deine Verbindung und versuche es erneut.';

  @override
  String get authSignupNameHint => 'Dein Name';

  @override
  String get authSignupTermsPrefix =>
      'Durch die Kontoerstellung stimmst du unseren ';

  @override
  String get authSignupAnd => ' und ';

  @override
  String get authSignupPeriod => '.';

  @override
  String get authSignupPrivacyPolicy => 'Datenschutzerklärung';

  @override
  String get authSignupTermsP1 =>
      'Nutze mitlist verantwortungsvoll. Geteilte Haushaltsinhalte sind für die Mitglieder dieses Haushalts sichtbar.';

  @override
  String get authSignupTermsP2 =>
      'Lade keine rechtswidrigen Inhalte hoch, gib dich nicht als andere aus und missbrauche den Dienst nicht. Konten und geteilte Daten können bei Missbrauch entfernt werden.';

  @override
  String get authSignupTermsP3 =>
      'Die App wird ohne Gewähr bereitgestellt, solange das Produkt noch in Entwicklung ist. Erstelle eigene Sicherungen für wichtige Inhalte.';

  @override
  String get authSignupPrivacyP1 =>
      'mitlist speichert die Kontodaten und Haushaltsinhalte, die für den Betrieb der App erforderlich sind.';

  @override
  String get authSignupPrivacyP2 =>
      'Geteilte Daten wie Listen, Aufgaben, Ausgaben und Rezepte sind für andere Mitglieder desselben Haushalts sichtbar.';

  @override
  String get authSignupPrivacyP3 =>
      'Gib nur Informationen an, die du in einem gemeinsamen Haushaltsarbeitsbereich teilen möchtest.';

  @override
  String get authJoinTitle => 'Haushalt beitreten';

  @override
  String authJoinInvitedBy(String name) {
    return '$name hat dich eingeladen';
  }

  @override
  String get authJoinJoinNow => 'Jetzt beitreten';

  @override
  String get authJoinSignInToJoin => 'Anmelden zum Beitreten';

  @override
  String get authJoinCreateToJoin => 'Konto erstellen zum Beitreten';

  @override
  String get authJoinGuestWarning =>
      'Gastkonten können keinen Haushalten beitreten.';

  @override
  String get authJoinCouldNotLoad =>
      'Einladungsdetails konnten nicht geladen werden.';

  @override
  String get authJoinJoining => 'Wird beigetreten…';

  @override
  String get authJoinNotNow => 'Nicht jetzt';

  @override
  String get authJoinYoureIn => 'Du bist dabei.';

  @override
  String get authJoinGoToHousehold => 'Zum Haushalt';

  @override
  String authJoinInviteCodeSemantic(String code) {
    return 'Einladungscode: $code';
  }

  @override
  String authJoinErrorWithHint(String error) {
    return '$error\n\nDu kannst auch einen Code über die Haushaltsauswahl eingeben.';
  }

  @override
  String get authOnboardingTitle => 'Willkommen';

  @override
  String get authOnboardingSetupHome => 'Richte dein Zuhause ein';

  @override
  String get authOnboardingCreateOrJoin =>
      'Erstelle oder tritt einem Haushalt bei, um mit Mitbewohnern zu teilen.';

  @override
  String get authOnboardingCreateHousehold => 'Haushalt erstellen';

  @override
  String get authOnboardingJoinInvite => 'Mit Einladungscode beitreten';

  @override
  String get authOnboardingHaveCode => 'Hast du einen Einladungscode?';

  @override
  String get authOnboardingCreateDesc =>
      'Fang neu an: Benenne ihn, lade Mitbewohner ein, teile alles an einem Ort.';

  @override
  String get authOnboardingJoinDesc =>
      'Schon eine Einladung? Gib den Code ein und leg los.';

  @override
  String get authOnboardingJoinSemantic =>
      'Einem Haushalt mit Einladungscode beitreten';

  @override
  String get authOnboardingHomeIconSemantic => 'Haushaltssymbol';

  @override
  String get hubStatsChores => 'Aufgaben';

  @override
  String get hubStatsDue => 'fällig';

  @override
  String get hubStatsMeals => 'Mahlzeiten';

  @override
  String get hubStatsPlanned => 'geplant';

  @override
  String get hubStatsOverdue => 'überfällig';

  @override
  String get hubStatsAllDone => 'alles erledigt';

  @override
  String get hubStatsBalance => 'Saldo';

  @override
  String get hubStatsOpen => 'offen';

  @override
  String get hubStatsLists => 'Listen';

  @override
  String get hubStatsActiveList => 'aktive Liste';

  @override
  String get hubStatsActiveLists => 'aktive Listen';

  @override
  String get hubStatsReminders => 'Erinnerungen';

  @override
  String get hubStatsPinwallReminder => 'Pinwall-Erinnerung';

  @override
  String get hubStatsPinwallReminders => 'Pinwall-Erinnerungen';

  @override
  String get hubQuickAddTitle => 'Schnell hinzufügen';

  @override
  String get hubQuickAddChore => 'Aufgabe hinzufügen';

  @override
  String get hubQuickAddExpense => 'Ausgabe hinzufügen';

  @override
  String get hubQuickAddNote => 'Notiz anpinnen';

  @override
  String get hubQuickAddList => 'Neue Liste';

  @override
  String get hubActivityTitle => 'Aktivität';

  @override
  String get hubActivityEmpty =>
      'Noch nichts los.\nAktivitäten aus deinem Haushalt erscheinen hier.';

  @override
  String get hubActivityError =>
      'Aktivität konnte nicht geladen werden. Zum Aktualisieren auf dem Hub nach unten ziehen.';

  @override
  String get hubOnboardingSwap => 'Tauschen';

  @override
  String get hubOnboardingSettle => 'Ausgleichen';

  @override
  String get hubOnboardingDone => 'Alles erledigt';

  @override
  String get hubOnboardingSwapDesc =>
      'Wähle einen Mitbewohner, der am wenigsten schuldet, um diese Aufgabe zu übernehmen.';

  @override
  String get hubOnboardingSettleDesc =>
      'Gleiche alle auf einmal aus mit vorgeschlagenen Ausgleichszahlungen.';

  @override
  String get hubOnboardingDoneDesc =>
      'Aufgaben, Salden, Listen — alles an einem Ort, vollständig erfasst.';

  @override
  String get appBottomSheetHandle => 'Griff';

  @override
  String get appBottomSheetClose => 'Schließen';

  @override
  String get storePickerTitle => 'Geschäft wählen';

  @override
  String get storePickerSearchLabel => 'Geschäfte suchen';

  @override
  String get storePickerSearchHint => 'Name...';

  @override
  String get storePickerNoMatch => 'Keine Geschäfte passen zu deiner Suche.';

  @override
  String get storePickerNoStore => 'Kein Geschäft';

  @override
  String get storePickerNoStoreDesc =>
      'Nach Kategorie statt nach Ladenlayout sortieren';

  @override
  String get storePickerLoadError => 'Geschäfte konnten nicht geladen werden.';

  @override
  String get smartCaptureLaunchTitle => 'Foto prüfen';

  @override
  String get hubQuickAddToList => 'Zur Liste hinzufügen';

  @override
  String get hubQuickAddShoppingTrip => 'Einkauf starten';

  @override
  String get hubOnboardingGetStarted => 'Loslegen';

  @override
  String get hubOnboardingDismiss => 'Schnellstart schließen';

  @override
  String get hubOnboardingDescription =>
      'Alles beginnt hier. Wähle, was am wichtigsten ist.';

  @override
  String get hubOnboardingInvite => 'Mitbewohner einladen';

  @override
  String get hubOnboardingCreateList => 'Liste erstellen';

  @override
  String get hubOnboardingAddChore => 'Aufgabe hinzufügen';

  @override
  String get hubOnboardingTrackExpense => 'Ausgabe erfassen';

  @override
  String get appBottomSheetDiscardTitle => 'Änderungen verwerfen?';

  @override
  String get appBottomSheetDiscardBody => 'Du hast ungespeicherte Änderungen.';

  @override
  String get appBottomSheetKeepEditing => 'Weiter bearbeiten';

  @override
  String get sheetExpenseDetailTitle => 'Ausgabendetails';

  @override
  String get sheetExpenseDetailSplits => 'Aufteilungen';

  @override
  String sheetExpenseDetailSplitsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Aufteilungen',
      one: '$count Aufteilung',
    );
    return '$_temp0';
  }

  @override
  String get sheetSettlementTitle => 'Ausgleich aufzeichnen';

  @override
  String get sheetSettlementFrom => 'Von';

  @override
  String get sheetSettlementTo => 'An';

  @override
  String get sheetSettlementRecordPayment =>
      'Zeichne diesen Ausgleich auf, nachdem die Zahlung erfolgt ist.';

  @override
  String get sheetSettlementConfirm => 'Ausgleich bestätigen';

  @override
  String get sheetGroupSettingsTitle => 'Haushaltseinstellungen';

  @override
  String get sheetGroupSettingsName => 'Haushaltsname';

  @override
  String get sheetGroupSettingsSaved => 'Einstellungen gespeichert';

  @override
  String get sheetGroupSettingsCouldNotSave =>
      'Einstellungen konnten nicht gespeichert werden.';

  @override
  String get sheetGroupSettingsLeave => 'Haushalt verlassen';

  @override
  String get sheetGroupSettingsLeaveConfirm =>
      'Bist du sicher, dass du diesen Haushalt verlassen möchtest? Alle deine Daten bleiben im Haushalt erhalten.';

  @override
  String get sheetGroupSettingsLeaveAction => 'Verlassen';

  @override
  String get sheetGroupSettingsDelete => 'Haushalt löschen';

  @override
  String get sheetGroupSettingsDeleteConfirm =>
      'Dies löscht diesen Haushalt und alle zugehörigen Daten dauerhaft. Dies kann nicht rückgängig gemacht werden.';

  @override
  String get sheetRecipeAddToListTitle => 'Zur Liste hinzufügen';

  @override
  String sheetRecipeAddToListAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Einträge hinzugefügt',
      one: '1 Eintrag hinzugefügt',
    );
    return '$_temp0';
  }

  @override
  String get sheetRecipeAddToListCouldNotAdd =>
      'Zutaten konnten nicht hinzugefügt werden.';

  @override
  String get sheetJoinTitle => 'Haushalt beitreten';

  @override
  String get sheetJoinCodeLabel => 'Einladungscode';

  @override
  String get sheetJoinCodeHint => 'Einladungscode einfügen';

  @override
  String get sheetJoinJoin => 'Beitreten';

  @override
  String get sheetCreateHouseholdTitle => 'Haushalt erstellen';

  @override
  String get sheetCreateHouseholdName => 'Haushaltsname';

  @override
  String get sheetCreateHouseholdNameHint => 'z. B. WG 4B';

  @override
  String get sheetInviteTitle => 'In den Haushalt einladen';

  @override
  String get sheetInviteCopy => 'Link kopieren';

  @override
  String get sheetInviteCopied => 'Einladungslink kopiert';

  @override
  String get sheetInviteShare => 'Link teilen';

  @override
  String get sheetCreateListTitle => 'Neue Liste';

  @override
  String get sheetCreateListName => 'Listenname';

  @override
  String get sheetCreateListNameHint => 'z. B. Wocheneinkauf';

  @override
  String get sheetCreateListType => 'Typ';

  @override
  String get sheetCreateListTypeShopping => 'Einkauf';

  @override
  String get sheetCreateListTypeTodo => 'To-do';

  @override
  String get sheetCreateListTypeCustom => 'Eigene';

  @override
  String get sheetCreateListCreate => 'Liste erstellen';

  @override
  String get sheetCostSummaryTitle => 'Kostenübersicht';

  @override
  String get sheetCostSummaryTotal => 'Gesamt';

  @override
  String get sheetConflictTitle => 'Sync-Konflikt';

  @override
  String get sheetConflictDescription =>
      'Dieser Eintrag wurde auf einem anderen Gerät geändert, während du ihn bearbeitet hast. Wähle, welche Version behalten werden soll.';

  @override
  String get sheetConflictLocal => 'Deine Version';

  @override
  String get sheetConflictServer => 'Server-Version';

  @override
  String get sheetConflictKeepLocal => 'Deine behalten';

  @override
  String get sheetConflictKeepServer => 'Server behalten';

  @override
  String get sheetFailedChangesTitle => 'Fehlgeschlagene Änderungen';

  @override
  String get sheetFailedChangesDescription =>
      'Diese Änderungen konnten nicht gespeichert werden. Du kannst sie erneut versuchen oder verwerfen.';

  @override
  String get sheetFailedChangesRetryAll => 'Alle wiederholen';

  @override
  String get sheetFailedChangesDiscardAll => 'Alle verwerfen';

  @override
  String get sheetFailedChangesDiscard => 'Verwerfen';

  @override
  String get sheetFailedChangesRetry => 'Wiederholen';

  @override
  String get sheetFailedChangesEmpty =>
      'Keine fehlgeschlagenen Änderungen. Alles ist synchronisiert oder wartet auf Wiederholung.';

  @override
  String get sheetFailedChangesOpAddItem => 'Eintrag hinzufügen';

  @override
  String get sheetFailedChangesOpUpdateItem => 'Eintrag aktualisieren';

  @override
  String get sheetFailedChangesOpDeleteItem => 'Eintrag löschen';

  @override
  String get sheetFailedChangesOpReorderItems => 'Liste umsortieren';

  @override
  String get sheetFailedChangesOpCreateExpense => 'Ausgabe hinzufügen';

  @override
  String get sheetFailedChangesOpUpdateExpense => 'Ausgabe aktualisieren';

  @override
  String get sheetFailedChangesOpDeleteExpense => 'Ausgabe löschen';

  @override
  String get sheetFailedChangesOpCreateRecipe => 'Rezept hinzufügen';

  @override
  String get sheetFailedChangesOpUpdateRecipe => 'Rezept aktualisieren';

  @override
  String get sheetFailedChangesOpDeleteRecipe => 'Rezept löschen';

  @override
  String get sheetFailedChangesOpCompleteChore => 'Aufgabe erledigen';

  @override
  String get sheetFailedChangesOpSkipChore => 'Aufgabe überspringen';

  @override
  String get sheetFailedChangesOpRescheduleChore => 'Aufgabe neu planen';

  @override
  String get sheetFailedChangesOpUndoChore => 'Aufgabe rückgängig';

  @override
  String get sheetFailedChangesOpCreatePinwallPost => 'An Pinwall posten';

  @override
  String get sheetFailedChangesOpDeletePinwallPost => 'Pinwall-Beitrag löschen';

  @override
  String get sheetFailedChangesOpChange => 'Änderung';

  @override
  String get sheetGroupSettingsChoreZonesUpdated =>
      'Aufgabenbereiche aktualisiert';

  @override
  String get sheetGroupSettingsRemoveMember => 'Mitglied entfernen';

  @override
  String sheetGroupSettingsRemoveMemberConfirm(String name) {
    return '$name aus diesem Haushalt entfernen?';
  }

  @override
  String sheetGroupSettingsMemberRemoved(String name) {
    return '$name entfernt';
  }

  @override
  String get sheetGroupSettingsHouseholdDeleted => 'Haushalt gelöscht';

  @override
  String get sheetGroupSettingsDescriptionHint =>
      'Ein paar Worte zu diesem Haushalt';

  @override
  String get sheetGroupSettingsChoreZonesLabel => 'Aufgabenbereiche';

  @override
  String get sheetGroupSettingsChoreZonesDesc =>
      'Bereiche deines Zuhauses zum Gruppieren von Aufgaben. Sie erscheinen beim Hinzufügen einer Aufgabe.';

  @override
  String get sheetGroupSettingsAddZone => 'Bereich hinzufügen';

  @override
  String get sheetGroupSettingsZoneHint => 'Küche, Bad…';

  @override
  String get sheetGroupSettingsSaveZones => 'Bereiche speichern';

  @override
  String get sheetGroupSettingsMembersLabel => 'Mitglieder';

  @override
  String get sheetGroupSettingsInvite => 'Einladen';

  @override
  String sheetGroupSettingsRemoveMemberTooltip(String name) {
    return '$name entfernen';
  }

  @override
  String get tonightRecipe => 'Rezept';

  @override
  String get tonightHeader => 'Heute Abend';

  @override
  String get tonightCook => 'Kochen';

  @override
  String get tonightNothingPlanned => 'Nichts für heute Abend geplant';

  @override
  String get tonightPlanDinner => 'Abendessen planen';

  @override
  String activityAddedToList(String name, String when) {
    return '$name zu einer Liste hinzugefügt · $when';
  }

  @override
  String activityAddedToNamedList(String name, String list, String when) {
    return 'Added $name to $list · $when';
  }

  @override
  String activityAddedItemToList(String when) {
    return 'Einen Eintrag zu einer Liste hinzugefügt · $when';
  }

  @override
  String activityLoggedExpense(String name, String when) {
    return '$name eingetragen · $when';
  }

  @override
  String activityLoggedExpenseGeneric(String when) {
    return 'Eine Ausgabe eingetragen · $when';
  }

  @override
  String activityCompletedChore(String name, String when) {
    return '$name erledigt · $when';
  }

  @override
  String activityCompletedChoreGeneric(String when) {
    return 'Eine Aufgabe erledigt · $when';
  }

  @override
  String activitySavedRecipe(String name, String when) {
    return '$name gespeichert · $when';
  }

  @override
  String activitySavedRecipeGeneric(String when) {
    return 'Ein Rezept gespeichert · $when';
  }

  @override
  String activityPlannedMeal(String name, String when) {
    return '$name geplant · $when';
  }

  @override
  String activityUpdatedMealPlan(String when) {
    return 'Essensplan aktualisiert · $when';
  }

  @override
  String get activityYou => 'Du';

  @override
  String get activityMember => 'Mitglied';

  @override
  String inviteLinkShareText(String link, String code) {
    return 'Tritt meinem Haushalt auf mitlist bei!\nTippe: $link\nOder öffne mitlist und gib den Code ein: $code';
  }

  @override
  String get errorBoundaryTitle => 'Etwas ist schiefgegangen';

  @override
  String get errorBoundaryDesc =>
      'Ein unerwarteter Fehler ist aufgetreten. Bitte versuche es erneut.';

  @override
  String get recurringTomorrow => 'Morgen';

  @override
  String get recurringCouldNotUpdate =>
      'Wiederkehrende Ausgabe konnte nicht aktualisiert werden.';

  @override
  String get recurringCouldNotDelete =>
      'Wiederkehrende Ausgabe konnte nicht gelöscht werden.';

  @override
  String get recurringCouldNotCreate =>
      'Wiederkehrende Ausgabe konnte nicht erstellt werden.';

  @override
  String get recipeAddToListNoLists => 'Keine Listen';

  @override
  String get recipeAddToListCreateListFirst =>
      'Erstelle zuerst eine Liste, um Zutaten hinzuzufügen';

  @override
  String get costSummaryNoPrices => 'Noch keine Artikel mit Preisen...';

  @override
  String get costSummaryNotAvailable => 'k. A.';

  @override
  String get costSummaryEqualShare => 'Gleicher Anteil pro Person';

  @override
  String get costSummaryItemsWithPrices => 'Artikel mit Preisen';

  @override
  String get costSummaryNone => 'Keine';

  @override
  String get costSummaryGenerateExpense => 'Ausgabe erstellen';

  @override
  String get createListScanFinished => 'Scan abgeschlossen';

  @override
  String createListScanned(String name) {
    return '\"$name\" gescannt';
  }

  @override
  String get createListShoppingDesc =>
      'Ideal für Lebensmitteleinkäufe und Besorgungen mit Mengen.';

  @override
  String get createListNameRequired => 'Listenname ist erforderlich';

  @override
  String get createListCreated => 'Liste erstellt';

  @override
  String get recipeCreationScanRecipe => 'Rezept scannen';

  @override
  String get recipeCreationScanRecipeViaCamera => 'Rezept per Kamera scannen';

  @override
  String get joinCodeFormatHint =>
      'Codes sehen aus wie WORT-WORT-42. Frag die Person, die dich eingeladen hat.';

  @override
  String joinEnterGroup(String name) {
    return '$name betreten';
  }

  @override
  String inviteCodeLabel(String code) {
    return 'Einladungscode: $code';
  }

  @override
  String get inviteQrTitle => 'Haushaltseinladungs-QR-Code';

  @override
  String get inviteQrSemantic => 'Haushaltseinladungs-QR';

  @override
  String get inviteQrHint =>
      'Mit einer Handykamera scannen, um beizutreten, oder teile den Code unten.';

  @override
  String get inviteGenerating => 'Wird generiert…';

  @override
  String get inviteNewCode => 'Neuer Code';

  @override
  String get createHouseholdCreated => 'Haushalt erstellt';

  @override
  String get createHouseholdDescriptionOptional => 'Beschreibung (optional)';

  @override
  String get conflictNoneToResolve => 'Keine Konflikte zum Lösen.';

  @override
  String get conflictItemChanged => 'Eintrag geändert';

  @override
  String conflictItemLabel(String name) {
    return 'Eintrag: $name';
  }

  @override
  String get scannerCouldNotAnalyze =>
      'Bild konnte nicht analysiert werden. Bitte versuche es mit einem klareren Foto erneut.';

  @override
  String get oauthMissingParams => 'Fehlende OAuth-Callback-Parameter.';

  @override
  String get oauthSigningYouIn => 'Du wirst angemeldet';

  @override
  String get expenseCreationSharesNegative =>
      'Anteile dürfen nicht negativ sein.';

  @override
  String get expenseCreationAssignShare => 'Weise mindestens einen Anteil zu.';

  @override
  String get expenseCreationCouldNotLoadMembers =>
      'Haushaltsmitglieder konnten nicht geladen werden.';

  @override
  String get expenseCreationJoinHouseholdSplit =>
      'Tritt einem Haushalt bei oder erstelle einen, um diese Ausgabe aufzuteilen.';

  @override
  String expenseCreationRemoveAddSplitter(String name) {
    return '$name aus der/zur Aufteilung entfernen/hinzufügen';
  }

  @override
  String get expenseDetailFailedLoadReceipt =>
      'Beleg konnte nicht geladen werden';

  @override
  String get expenseDetailReceipt => 'Beleg';

  @override
  String get expenseDetailView => 'Ansehen';

  @override
  String get expenseDetailNotSplitYet =>
      'Diese Ausgabe wurde noch nicht aufgeteilt.';

  @override
  String get expenseDetailNoReceipts =>
      'Keine Belege angehängt. Füge einen beim Bearbeiten der Ausgabe hinzu.';

  @override
  String pinwallLinkedTo(String entity) {
    return 'Verknüpft mit $entity';
  }

  @override
  String get commonView => 'Ansehen';

  @override
  String get commonPhoto => 'Foto';

  @override
  String cookModeTimerStart(String label) {
    return 'Timer: $label. Zum Starten tippen';
  }

  @override
  String get errorServerHiccup =>
      'Serverproblem — versuche es gleich noch einmal.';

  @override
  String get errorConflict =>
      'Jemand anderes hat das geändert. Aktualisiere und versuche es erneut.';

  @override
  String get errorNotFound =>
      'Nicht gefunden. Es wurde möglicherweise gelöscht.';

  @override
  String get errorNoPermission => 'Du hast keine Berechtigung dafür.';

  @override
  String get errorSignInAgain => 'Bitte melde dich erneut an.';

  @override
  String get errorGenericRetry =>
      'Etwas ist schiefgegangen. Bitte versuche es erneut.';

  @override
  String get createListTodoDesc =>
      'Eine einfache Checkliste für Aufgaben, die erledigt werden müssen.';

  @override
  String get createListCustomDesc =>
      'Eine flexible Liste für alles, was nicht ins Schema passt.';

  @override
  String get createListScanSemantics => 'Liste per Kamera scannen';

  @override
  String get createListHouseholdLabel => 'Haushalt';

  @override
  String get createListNoHousehold => 'Kein Haushalt verfügbar.';

  @override
  String get sheetJoinCodeExample => 'SUNNY-TACO-42';

  @override
  String joinMembersAlreadyInside(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Mitglieder bereits drin',
      one: '1 Mitglied bereits drin',
    );
    return '$_temp0';
  }

  @override
  String get inviteQrUnavailable => 'QR nicht verfügbar';

  @override
  String expenseCreationSplitAssignedOf(String assigned, String total) {
    return '$assigned von $total';
  }

  @override
  String expenseCreationSplitAmountsNegative(String assigned) {
    return '$assigned · Beträge dürfen nicht negativ sein';
  }

  @override
  String expenseCreationSplitLeftToAssign(String assigned, String remaining) {
    return '$assigned · $remaining noch zuzuweisen';
  }

  @override
  String expenseCreationSplitOver(String assigned, String over) {
    return '$assigned · $over zu viel';
  }

  @override
  String expenseCreationSplitPercentRange(String sum) {
    return '$sum% zugewiesen · jeder Anteil muss 0–100% sein';
  }

  @override
  String expenseCreationSplitPercentOf100(String sum) {
    return '$sum% von 100%';
  }

  @override
  String expenseCreationSplitSharesPerShare(num count, String perShare) {
    return '$count Anteile · $perShare pro Anteil';
  }

  @override
  String expenseCreationSplitEach(String amount) {
    return '$amount pro Person';
  }

  @override
  String expenseCreationSplitApproxEach(String amount) {
    return '≈ $amount pro Person';
  }

  @override
  String expenseCreationRemoveFromSplit(String name) {
    return '$name aus Aufteilung entfernen';
  }

  @override
  String expenseCreationAddToSplit(String name) {
    return '$name zur Aufteilung hinzufügen';
  }

  @override
  String get expenseDetailCouldNotLoadSplits =>
      'Aufteilungen konnten nicht geladen werden.';

  @override
  String get expenseDetailCouldNotLoadReceipts =>
      'Belege konnten nicht geladen werden.';

  @override
  String get expenseDetailCouldNotRemoveReceipt =>
      'Beleg konnte nicht entfernt werden.';

  @override
  String get expenseDetailRemoving => 'Wird entfernt…';

  @override
  String get recipeAddToListTargetList => 'Zielliste';

  @override
  String get recipeAddToListNoIngredients => 'Keine Zutaten';

  @override
  String get recipeAddToListNoIngredientsDesc =>
      'Dieses Rezept hat keine erkannten Zutaten';

  @override
  String recipeAddToListRemoveFromSelection(String name) {
    return '$name aus Auswahl entfernen';
  }

  @override
  String recipeAddToListAddToSelection(String name) {
    return '$name zur Auswahl hinzufügen';
  }

  @override
  String get pinwallLinkChore => 'Eine Aufgabe';

  @override
  String get pinwallLinkList => 'Eine Liste';

  @override
  String get pinwallCouldNotLoad => 'Pinwall konnte nicht geladen werden.';

  @override
  String get composerItemHint => 'z. B. Milch, 2 Avocados oder 500 g Mehl';

  @override
  String get aisleOther => 'Sonstiges';

  @override
  String hubHouseholdsCurrent(String name) {
    return 'Haushalte, aktuell $name';
  }

  @override
  String recipeDetailStepCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count Schritte',
      one: '1 Schritt',
    );
    return '$_temp0';
  }

  @override
  String get currencyUsd => 'USD - US-Dollar';

  @override
  String get currencyEur => 'EUR - Euro';

  @override
  String get currencyGbp => 'GBP - Britisches Pfund';

  @override
  String get currencyJpy => 'JPY - Japanischer Yen';

  @override
  String get currencyCad => 'CAD - Kanadischer Dollar';

  @override
  String get currencyAud => 'AUD - Australischer Dollar';

  @override
  String get currencyChf => 'CHF - Schweizer Franken';

  @override
  String get currencySek => 'SEK - Schwedische Krone';

  @override
  String get currencyNok => 'NOK - Norwegische Krone';

  @override
  String get currencyDkk => 'DKK - Dänische Krone';

  @override
  String get currencyPln => 'PLN - Polnischer Złoty';

  @override
  String get currencyCzk => 'CZK - Tschechische Krone';

  @override
  String get currencyHuf => 'HUF - Ungarischer Forint';
}
