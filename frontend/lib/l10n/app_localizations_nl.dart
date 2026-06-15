// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Dutch Flemish (`nl`).
class AppLocalizationsNl extends AppLocalizations {
  AppLocalizationsNl([String locale = 'nl']) : super(locale);

  @override
  String get commonCancel => 'Annuleren';

  @override
  String get commonDelete => 'Verwijderen';

  @override
  String get commonRetry => 'Opnieuw';

  @override
  String get commonSave => 'Opslaan';

  @override
  String get commonBack => 'Terug';

  @override
  String get commonClose => 'Sluiten';

  @override
  String get commonDone => 'Klaar';

  @override
  String get commonUndo => 'Ongedaan maken';

  @override
  String get commonAdd => 'Toevoegen';

  @override
  String get commonConfirm => 'Bevestigen';

  @override
  String get commonEdit => 'Bewerken';

  @override
  String get commonSearch => 'Zoeken';

  @override
  String get commonRemove => 'Verwijderen';

  @override
  String get commonDismiss => 'Negeren';

  @override
  String get commonClear => 'Wissen';

  @override
  String get commonNext => 'Volgende';

  @override
  String get commonSkip => 'Overslaan';

  @override
  String get commonChange => 'Wijzigen';

  @override
  String get commonCreate => 'Aanmaken';

  @override
  String get commonRename => 'Hernoemen';

  @override
  String get commonArchive => 'Archiveren';

  @override
  String get commonOptions => 'Opties';

  @override
  String get commonSettings => 'Instellingen';

  @override
  String get commonName => 'Naam';

  @override
  String get commonDescription => 'Beschrijving';

  @override
  String get commonNotes => 'Notities';

  @override
  String get commonAmount => 'Bedrag';

  @override
  String get commonPreview => 'Voorbeeld';

  @override
  String get commonShare => 'Delen';

  @override
  String get commonCopy => 'Kopiëren';

  @override
  String get commonListName => 'Lijstnaam';

  @override
  String get commonSaving => 'Opslaan…';

  @override
  String get commonAdding => 'Toevoegen…';

  @override
  String get commonDeleting => 'Verwijderen…';

  @override
  String get commonNoHousehold => 'Nog geen huishouden';

  @override
  String get commonCreateJoinHousehold =>
      'Maak of word lid van een huishouden voordat je items toevoegt.';

  @override
  String get commonGoToHouseholds => 'Ga naar huishoudens';

  @override
  String get commonSomethingWentWrong => 'Er is iets misgegaan';

  @override
  String get commonFailedToLoad => 'Laden mislukt. Probeer het opnieuw.';

  @override
  String get commonCheckConnection =>
      'Controleer je verbinding en probeer het opnieuw.';

  @override
  String get commonClearSearch => 'Zoekopdracht wissen';

  @override
  String commonMember(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count leden',
      one: '$count lid',
    );
    return '$_temp0';
  }

  @override
  String commonItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get commonLoadingMembers => 'Leden laden...';

  @override
  String get welcomeTagline => 'Jullie huishouden, overzichtelijk.';

  @override
  String get welcomeCardTitle => 'Lijsten, klusjes, geld.\nAlles op één plek.';

  @override
  String get welcomeCardBody =>
      'Gemaakt voor huisgenoten die minder gedoe en meer duidelijkheid willen.';

  @override
  String get welcomeCreateHousehold => 'Gratis huishouden aanmaken';

  @override
  String get welcomeSignIn => 'Inloggen';

  @override
  String get welcomeGuestLoading => 'Instellen...';

  @override
  String get welcomeContinueAsGuest => 'Doorgaan als gast';

  @override
  String get welcomeGuestFootnote =>
      'Geen account nodig. Probeer alles 30 dagen gratis.';

  @override
  String get hubAppBarTitle => 'Home';

  @override
  String get hubHouseholdsSheetTitle => 'Huishoudens';

  @override
  String hubSwitchToHousehold(String name) {
    return 'Wissel naar $name';
  }

  @override
  String get hubCreateHousehold => 'Huishouden aanmaken';

  @override
  String get hubJoinHousehold => 'Lid worden van huishouden';

  @override
  String get hubInviteToHousehold => 'Uitnodigen voor huishouden';

  @override
  String get hubHouseholdSettings => 'Huishoudinstellingen';

  @override
  String get hubWelcomeHeadline => 'Welkom bij mitlist';

  @override
  String get hubWelcomeDescription =>
      'Maak of word lid van een huishouden om lijsten, klusjes en uitgaven te delen.';

  @override
  String get hubCreateAHousehold => 'Maak een huishouden';

  @override
  String get hubJoinWithInviteCode => 'Lid worden met uitnodigingscode';

  @override
  String get hubQuickAdd => 'Snel toevoegen';

  @override
  String get hubLoadError =>
      'Kon je huishoudens niet laden. Controleer je verbinding en probeer het opnieuw.';

  @override
  String get hubCalendarTooltip => 'Kalender';

  @override
  String get myHouseholdsTitle => 'Mijn Huishoudens';

  @override
  String get groupsJoinWithCode => 'Lid worden met code';

  @override
  String get groupsFailedLoad => 'Huishoudens laden mislukt';

  @override
  String get groupsFailedMore => 'Meer huishoudens laden mislukt';

  @override
  String get groupsEmptyTitle => 'Nog geen huishoudens';

  @override
  String get groupsEmptyDesc => 'Maak er een aan om je huis te organiseren.';

  @override
  String get groupsCreateHousehold => 'Huishouden aanmaken';

  @override
  String get choreAppBarTitle => 'Klusjes';

  @override
  String get choreAddChore => 'Klus toevoegen';

  @override
  String get choreAddHouseholds => 'Huishoudens';

  @override
  String get choreRetry => 'Opnieuw';

  @override
  String get choreNoHouseholdTitle => 'Nog geen huishouden';

  @override
  String get choreNoHouseholdDesc =>
      'Maak of word lid van een huishouden voordat je klusjes toevoegt.';

  @override
  String get choreGoToHouseholds => 'Ga naar huishoudens';

  @override
  String get choreNoChoresTitle => 'Nog geen klusjes';

  @override
  String get choreNoChoresDesc =>
      'Houd terugkerende huishoudelijke taken bij. Wijs ze toe aan iedereen in je groep.';

  @override
  String get choreAddAChore => 'Voeg een klus toe';

  @override
  String get choreSectionOverdue => 'Achterstallig';

  @override
  String get choreSectionToday => 'Vandaag';

  @override
  String get choreSectionThisWeek => 'Deze week';

  @override
  String get choreSectionLater => 'Later';

  @override
  String get choreNothingOnYou => 'Niets voor jou nu';

  @override
  String get choreNothingOnYouDesc =>
      'Je huishouden heeft klusjes, maar geen zijn aan jou toegewezen.';

  @override
  String get choreSeeEveryonesChores => 'Bekijk ieders klusjes';

  @override
  String choreDoneSnackbar(String choreTitle) {
    return '$choreTitle gedaan';
  }

  @override
  String get choreFailedComplete =>
      'Klus kon niet worden afgerond. Probeer het opnieuw.';

  @override
  String get choreFailedUndo =>
      'Klus kon niet ongedaan worden gemaakt. Probeer het opnieuw.';

  @override
  String get choreFailedSkip =>
      'Klus kon niet worden overgeslagen. Probeer het opnieuw.';

  @override
  String get choreFailedUpdateSubtask =>
      'Subtaak kon niet worden bijgewerkt. Probeer het opnieuw.';

  @override
  String get choreFailedAddSubtask =>
      'Subtaak kon niet worden toegevoegd. Probeer het opnieuw.';

  @override
  String get choreCreateListFirst => 'Maak eerst een boodschappenlijst.';

  @override
  String get choreAddSuppliesToList => 'Benodigdheden aan lijst toevoegen';

  @override
  String get choreSuppliesAdded => 'Benodigdheden aan lijst toegevoegd';

  @override
  String get choreFailedAddSupplies =>
      'Benodigdheden toevoegen mislukt. Probeer het opnieuw.';

  @override
  String get choreFailedReschedule =>
      'Klus opnieuw inplannen mislukt. Probeer het opnieuw.';

  @override
  String get choreDeleteTitle => 'Klus verwijderen';

  @override
  String get choreDeleteBody =>
      'Dit verwijdert deze klus en zijn geschiedenis permanent. Dit kan niet ongedaan worden gemaakt.';

  @override
  String get choreStatusDone => 'Klaar';

  @override
  String get choreStatusOverdue => 'Achterstallig';

  @override
  String get choreStatusDueToday => 'Vandaag te doen';

  @override
  String get choreStatusDueSoon => 'Binnenkort te doen';

  @override
  String get choreStatusScheduled => 'Ingepland';

  @override
  String get choreStatusPending => 'In afwachting';

  @override
  String get choreYourTurn => 'Jouw beurt';

  @override
  String get choreYoureClear => 'Je bent vrij';

  @override
  String choreHeroDescSingular(num count) {
    return '$count klus heeft je nu nodig.';
  }

  @override
  String choreHeroDescPlural(num count) {
    return '$count klusjes hebben je nu nodig.';
  }

  @override
  String choreMeLabel(num count) {
    return 'Ik ($count)';
  }

  @override
  String choreEveryoneLabel(num count) {
    return 'Iedereen ($count)';
  }

  @override
  String get choreHowItSplits => 'Hoe het verdeelt';

  @override
  String choreSupplySingular(num count) {
    return '$count benodigdheid';
  }

  @override
  String choreSupplyPlural(num count) {
    return '$count benodigdheden';
  }

  @override
  String get choreFrequencyHourly => 'Elk uur';

  @override
  String get choreFrequencyDaily => 'Dagelijks';

  @override
  String get choreFrequencyWeekly => 'Wekelijks';

  @override
  String get choreFrequencyMonthly => 'Maandelijks';

  @override
  String get choreFrequencyYearly => 'Jaarlijks';

  @override
  String get choreFrequencyAsNeeded => 'Naar behoefte';

  @override
  String get choreFrequencyOneOff => 'Eenmalig';

  @override
  String choreEveryInterval(num interval, String unit) {
    return 'Elke $interval $unit';
  }

  @override
  String get choreDoneToday => 'Vandaag gedaan';

  @override
  String get choreDoneYesterday => 'Gisteren gedaan';

  @override
  String choreDoneDaysAgo(num days) {
    return '${days}d geleden gedaan';
  }

  @override
  String get choreSkipped => 'Overgeslagen';

  @override
  String choreMarkNotDone(String title) {
    return 'Markeer $title als niet gedaan';
  }

  @override
  String choreMarkDone(String title) {
    return 'Markeer $title als gedaan';
  }

  @override
  String get choreAllCaughtUp => 'Je bent helemaal bij';

  @override
  String choreCarryingShare(num my, num total) {
    return 'Draagt $my van $total open klusjes';
  }

  @override
  String get choreNothingShare => 'Niets voor jou nu';

  @override
  String get choreCreationTitle => 'Klus toevoegen';

  @override
  String get choreCreationNameHint => 'Klusnaam';

  @override
  String get choreCreationYourRoutines => 'Jouw routines';

  @override
  String get choreCreationStartFromRoutine => 'Begin vanuit een routine';

  @override
  String get choreCreationSuggestions => 'Suggesties';

  @override
  String get choreCreationZoneLabel => 'Zone';

  @override
  String get choreCreationZoneKitchen => 'Keuken';

  @override
  String get choreCreationZoneBathroom => 'Badkamer';

  @override
  String get choreCreationZoneLivingRoom => 'Woonkamer';

  @override
  String get choreCreationZoneBedroom => 'Slaapkamer';

  @override
  String get choreCreationZoneOutdoor => 'Buiten';

  @override
  String get choreCreationZoneShared => 'Gedeeld';

  @override
  String get choreCreationRepeatsLabel => 'Herhaalt';

  @override
  String get choreCreationRecurrenceNone => 'Geen';

  @override
  String get choreCreationRecurrenceHourly => 'Elk uur';

  @override
  String get choreCreationRecurrenceDaily => 'Dagelijks';

  @override
  String get choreCreationRecurrenceWeekly => 'Wekelijks';

  @override
  String get choreCreationRecurrenceMonthly => 'Maandelijks';

  @override
  String get choreCreationRecurrenceYearly => 'Jaarlijks';

  @override
  String get choreCreationRecurrenceAdaptive => 'Adaptief';

  @override
  String get choreCreationHintNone =>
      'Een eenmalige klus. Komt niet vanzelf terug.';

  @override
  String get choreCreationHintHourly =>
      'Komt terug elke ingestelde aantal uren.';

  @override
  String get choreCreationHintDaily =>
      'Komt terug elke ingestelde aantal dagen.';

  @override
  String get choreCreationHintWeekly =>
      'Komt elke week terug op de dagen die je kiest.';

  @override
  String get choreCreationHintMonthly =>
      'Komt maandelijks terug op dezelfde datum.';

  @override
  String get choreCreationHintYearly =>
      'Komt jaarlijks terug op dezelfde datum.';

  @override
  String get choreCreationHintAdaptive =>
      'Komt terug op basis van wanneer het laatst is gedaan, niet de kalender.';

  @override
  String get choreCreationIntervalHint => '1';

  @override
  String get choreCreationMoreOptions => 'Meer opties';

  @override
  String get choreCreationAssignLabel => 'Toewijzen';

  @override
  String get choreCreationAssignTakeTurns => 'Om de beurt';

  @override
  String get choreCreationAssignLeastDone => 'Minst gedaan';

  @override
  String get choreCreationAssignAlphabetical => 'Alfabetisch';

  @override
  String get choreCreationAssignRandom => 'Willekeurig';

  @override
  String get choreCreationAssignNoAssignee => 'Geen toegewezene';

  @override
  String get choreCreationAssignHintTurns =>
      'Rouleert elke keer naar de volgende persoon.';

  @override
  String get choreCreationAssignHintAlpha =>
      'Gaat in alfabetische volgorde van namen.';

  @override
  String get choreCreationAssignHintLeast =>
      'Gaat naar wie het het minst heeft gedaan.';

  @override
  String get choreCreationAssignHintRandom =>
      'Kiest elke keer willekeurig iemand.';

  @override
  String get choreCreationAssignHintNone =>
      'Blijft niet-toegewezen. Iedereen in het huishouden kan het oppakken.';

  @override
  String get choreCreationLogWhenDone => 'Loggen wanneer gedaan, niet afvinken';

  @override
  String get choreCreationLogWhenDoneHelper =>
      'Registreert de datum zonder het als voltooid te markeren. Handig voor taken waarvan je een geschiedenis wilt.';

  @override
  String get choreCreationRollOver => 'Doorschuiven bij gemist';

  @override
  String get choreCreationRollOverHelper =>
      'Schuift door naar de volgende vervaldatum in plaats van op te stapelen als achterstallig.';

  @override
  String get choreCreationNotesHint =>
      'Notities (optioneel) — stappen, herinneringen, alles wat nuttig is';

  @override
  String get choreCreationSaveAsRoutine => 'Opslaan als routine';

  @override
  String get choreCreationSaveAsRoutineSemantic =>
      'Sla deze klus op als herbruikbare routine';

  @override
  String get choreCreationScanChoreSemantic => 'Scan klus via camera';

  @override
  String get choreCreationChoreAdded => 'Klus toegevoegd';

  @override
  String choreCreationChoreAddedNextUp(String assignee) {
    return 'Klus toegevoegd · volgende: $assignee';
  }

  @override
  String get choreCreationJoinFirst =>
      'Maak of word eerst lid van een huishouden.';

  @override
  String get choreCreationEditRoutine => 'Routine bewerken';

  @override
  String choreCreationEverySingular(String unit) {
    return 'Elke $unit';
  }

  @override
  String choreCreationEveryPlural(num n, String unit) {
    return 'Elke $n $unit';
  }

  @override
  String get choreCreationUnitHourSingular => 'uur';

  @override
  String get choreCreationUnitHourPlural => 'uur';

  @override
  String get choreCreationUnitDaySingular => 'dag';

  @override
  String get choreCreationUnitDayPlural => 'dagen';

  @override
  String get choreCreationUnitWeekSingular => 'week';

  @override
  String get choreCreationUnitWeekPlural => 'weken';

  @override
  String get choreCreationUnitMonthSingular => 'maand';

  @override
  String get choreCreationUnitMonthPlural => 'maanden';

  @override
  String get choreCreationUnitYearSingular => 'jaar';

  @override
  String get choreCreationUnitYearPlural => 'jaar';

  @override
  String get choreDayMon => 'Ma';

  @override
  String get choreDayTue => 'Di';

  @override
  String get choreDayWed => 'Wo';

  @override
  String get choreDayThu => 'Do';

  @override
  String get choreDayFri => 'Vr';

  @override
  String get choreDaySat => 'Za';

  @override
  String get choreDaySun => 'Zo';

  @override
  String get choreDetailTitle => 'Klusdetails';

  @override
  String get choreDetailAssignee => 'Toegewezen aan';

  @override
  String get choreDetailDue => 'Vervalt';

  @override
  String get choreDetailTracked => 'Bijgehouden';

  @override
  String get choreDetailLastDone => 'Laatst gedaan';

  @override
  String get choreDetailLastBy => 'Laatst door';

  @override
  String get choreDetailAverage => 'Gemiddeld';

  @override
  String get choreDetailSubtasks => 'Subtaken';

  @override
  String get choreDetailNewSubtask => 'Nieuwe subtaak';

  @override
  String get choreDetailSupplies => 'Benodigdheden';

  @override
  String get choreDetailAddSuppliesToList =>
      'Benodigdheden aan lijst toevoegen';

  @override
  String get choreDetailMarkDone => 'Markeren als gedaan';

  @override
  String get choreDetailMoveToTomorrow => 'Verplaatsen naar morgen';

  @override
  String get choreDetailUndoLast => 'Laatste uitvoering ongedaan maken';

  @override
  String get choreDetailSkipTitle => 'Klus overslaan';

  @override
  String get choreDetailSkipReason => 'Reden (optioneel)';

  @override
  String get choreDetailSkipReasonHint => 'bv. Deze week weg';

  @override
  String get choreDetailDeleteTitleDialog => 'Klus verwijderen';

  @override
  String get choreDetailDeleteBody =>
      'Dit verwijdert deze klus en zijn geschiedenis permanent.';

  @override
  String get choreDetailDeleteSubtask => 'Subtaak verwijderen';

  @override
  String get choreDetailSubtaskMarkNotDone =>
      'Subtaak markeren als niet gedaan';

  @override
  String get choreDetailSubtaskMarkDone => 'Subtaak markeren als gedaan';

  @override
  String get choreLoadTitle => 'Wie doet de klusjes';

  @override
  String choreLoadEmpty(num days) {
    return 'Er zijn nog geen klusjes voltooid in de afgelopen $days dagen. Zodra mensen dingen beginnen af te vinken, verschijnt de verdeling hier.';
  }

  @override
  String choreLoadCountSingular(num count) {
    return '$count klus';
  }

  @override
  String choreLoadCountPlural(num count) {
    return '$count klusjes';
  }

  @override
  String get recipeAppBarTitle => 'Keuken';

  @override
  String get recipeSearchLabel => 'Keuken doorzoeken';

  @override
  String get recipeSearchHint => 'Recept, tag, ingrediënt';

  @override
  String get recipeMealPlanTooltip => 'Maaltijdplanning';

  @override
  String get recipeSearchTooltip => 'Zoeken';

  @override
  String get recipeSortLabel => 'Recepten sorteren';

  @override
  String get recipeSortNewest => 'Nieuwste';

  @override
  String get recipeSortOldest => 'Oudste';

  @override
  String get recipeSortAZ => 'A-Z';

  @override
  String get recipeAddRecipe => 'Recept toevoegen';

  @override
  String get recipeFailedLoad => 'Keuken laden mislukt';

  @override
  String get recipeFailedMore => 'Meer recepten laden mislukt';

  @override
  String get recipeBuildKitchen => 'Bouw je keuken';

  @override
  String get recipeBuildKitchenDesc =>
      'Importeer recepten, groepeer kookboeken, plan maaltijden en zet de week om in een boodschappenlijst.';

  @override
  String recipeMealsPlanned(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count maaltijden gepland deze week',
      one: '1 maaltijd gepland deze week',
    );
    return '$_temp0';
  }

  @override
  String get recipePlanButton => 'Plannen';

  @override
  String recipeCountLabel(num visible, num total) {
    return '$visible van $total recepten';
  }

  @override
  String recipeCountLabelAll(num total) {
    return '$total recepten';
  }

  @override
  String get recipeFilterAll => 'Alle';

  @override
  String get recipeFilterShared => 'Gedeeld';

  @override
  String get recipeFilterPrivate => 'Privé';

  @override
  String recipeImageSemantics(String title) {
    return 'Afbeelding van $title';
  }

  @override
  String recipeMinLabel(num minutes) {
    return '$minutes min';
  }

  @override
  String recipeServesLabel(num servings) {
    return 'Voor $servings personen';
  }

  @override
  String recipeOpenRecipe(String title) {
    return 'Open recept $title';
  }

  @override
  String get recipeAddToList => 'Aan lijst toevoegen';

  @override
  String recipeSharedPrivate(num shared, num private) {
    return '$shared gedeeld · $private privé';
  }

  @override
  String recipeCookbooksLabel(num count) {
    return ' · $count kookboeken';
  }

  @override
  String recipeRatingLabel(String rating, num count) {
    return '$rating ($count)';
  }

  @override
  String get recipeCreationTitle => 'Nieuw recept';

  @override
  String get recipeCreationStepSource => 'Bron';

  @override
  String get recipeCreationStepDetails => 'Details';

  @override
  String get recipeCreationStepContent => 'Inhoud';

  @override
  String get recipeCreationStartHeadline => 'Begin je recept';

  @override
  String get recipeCreationStartSubtitle =>
      'Importeer van een link, typ het zelf of scan een foto.';

  @override
  String get recipeCreationImportURL => 'Importeren van URL';

  @override
  String get recipeCreationImportURLDesc =>
      'Plak een receptlink en wij halen de details op';

  @override
  String get recipeCreationTypeItIn => 'Zelf typen';

  @override
  String get recipeCreationTypeItInDesc =>
      'Begin met een titel en voeg later ingrediënten toe';

  @override
  String get recipeCreationScanning => 'Scannen…';

  @override
  String get recipeCreationScanPhoto => 'Scan een foto';

  @override
  String get recipeCreationScanPhotoDesc =>
      'Maak een foto van een receptenkaart of kookboekpagina';

  @override
  String get recipeCreationURLInput => 'Recept-URL';

  @override
  String get recipeCreationURLHint => 'https://example.com/recept';

  @override
  String get recipeCreationFetching => 'Ophalen…';

  @override
  String get recipeCreationFetchDetails => 'Details ophalen';

  @override
  String get recipeCreationChooseImage => 'Kies een afbeelding';

  @override
  String recipeCreationSelectImage(num index) {
    return 'Selecteer afbeelding $index';
  }

  @override
  String get recipeCreationTitleInput => 'Recepttitel';

  @override
  String get recipeCreationTitleHint => 'Zondagpannenkoeken';

  @override
  String get recipeCreationDiscardTitle => 'Recept weggooien?';

  @override
  String get recipeCreationDiscardBody =>
      'Je hebt niet-opgeslagen inhoud in dit recept.';

  @override
  String get recipeCreationKeepEditing => 'Doorgaan met bewerken';

  @override
  String get recipeCreationDiscard => 'Weggooien';

  @override
  String get recipeCreationCouldNotScan => 'Kon recept niet scannen.';

  @override
  String recipeCreationImported(String parts) {
    return '$parts';
  }

  @override
  String get recipeCreationCouldNotFetch =>
      'Kon geen details ophalen van die link.';

  @override
  String get recipeCreationCreated => 'Recept aangemaakt';

  @override
  String get recipeCreationCouldNotCreate => 'Kon recept niet aanmaken.';

  @override
  String get recipeCreationImportedTitle => 'Geïmporteerd recept';

  @override
  String recipeCreationFromHost(String host) {
    return 'Recept van $host';
  }

  @override
  String recipeCreationNutrition(String info) {
    return 'Voedingswaarde: $info';
  }

  @override
  String get recipeCreationNextDetails => 'Volgende: details';

  @override
  String get recipeCreationNextContent => 'Volgende: inhoud';

  @override
  String get recipeCreationTitleOverride => 'Titel overschrijven';

  @override
  String get recipeCreationNotesInput => 'Notities';

  @override
  String get recipeCreationNotesHint =>
      'Wat dit recept de moeite waard maakt om te bewaren';

  @override
  String get recipeCreationPrepLabel => 'Voorbereiding (min)';

  @override
  String get recipeCreationPrepHint => '10';

  @override
  String get recipeCreationCookLabel => 'Koken (min)';

  @override
  String get recipeCreationCookHint => '20';

  @override
  String get recipeCreationServingsLabel => 'Porties';

  @override
  String get recipeCreationServingsHint => '4';

  @override
  String get recipeCreationTagsInput => 'Tags';

  @override
  String get recipeCreationTagsHint => 'snel, vegetarisch';

  @override
  String get recipeCreationSaveForHousehold => 'Opslaan voor huishouden';

  @override
  String get recipeCreationSaveForHouseholdDesc =>
      'Iedereen in dit huishouden kan dit recept vinden en gebruiken.';

  @override
  String get recipeCreationSaveForHouseholdPrivate =>
      'Houd het voor nu privé. Je kunt het later delen.';

  @override
  String get recipeCreationIngredients => 'Ingrediënten';

  @override
  String get recipeCreationIngredientsHelper =>
      'Voeg één ingrediënt per regel toe.';

  @override
  String get recipeCreationAddIngredient => 'Ingrediënt toevoegen';

  @override
  String get recipeCreationIngredientHint => '200 g bloem';

  @override
  String get recipeCreationSteps => 'Stappen';

  @override
  String get recipeCreationStepsHelper =>
      'Houd elke stap kort genoeg om te volgen tijdens het koken.';

  @override
  String get recipeCreationAddStep => 'Stap toevoegen';

  @override
  String get recipeCreationStepHint => 'Beslag mengen';

  @override
  String get recipeCreationNutritionInput => 'Voedingswaarde';

  @override
  String get recipeCreationNutritionHint => '520 kcal, 24g eiwit, veel vezels';

  @override
  String get recipeCreationCreating => 'Aanmaken…';

  @override
  String get recipeCreationCreateRecipe => 'Recept aanmaken';

  @override
  String recipeCreationStepLabel(String type) {
    return '$type';
  }

  @override
  String recipeCreationRemoveItem(String type, num index) {
    return 'Verwijder $type $index';
  }

  @override
  String recipeCreationStepSemantics(
      num index, num total, String label, String status) {
    return 'Stap $index van $total, $label, $status';
  }

  @override
  String get recipeDetailTitle => 'Recept';

  @override
  String get recipeDetailDeleteTooltip => 'Recept verwijderen';

  @override
  String get recipeDetailAddToList => 'Aan lijst toevoegen';

  @override
  String get recipeDetailCook => 'Koken';

  @override
  String get recipeDetailCouldNotLoad => 'Kon recept niet laden';

  @override
  String get recipeDetailDeleteTitle => 'Recept verwijderen';

  @override
  String get recipeDetailDeleteBody =>
      'Dit verwijdert dit recept permanent. Dit kan niet ongedaan worden gemaakt.';

  @override
  String get recipeDetailSharedLabel => 'Gedeeld';

  @override
  String get recipeDetailPrivateLabel => 'Privé';

  @override
  String recipeDetailBy(String author) {
    return 'Door $author';
  }

  @override
  String get recipeDetailPrep => 'Voorbereiding';

  @override
  String get recipeDetailServings => 'Porties';

  @override
  String get recipeDetailUpdated => 'Bijgewerkt';

  @override
  String get recipeDetailNotSet => 'Niet ingesteld';

  @override
  String get recipeDetailNutrition => 'Voedingswaarde';

  @override
  String get recipeDetailEquipment => 'Uitrusting';

  @override
  String get recipeDetailIngredients => 'Ingrediënten';

  @override
  String get recipeDetailSteps => 'Stappen';

  @override
  String get recipeDetailWatchVideo => 'Bekijk video';

  @override
  String get recipeDetailWatchVideoSemantics => 'Bekijk receptvideo';

  @override
  String get recipeDetailViewOriginal => 'Bekijk origineel recept';

  @override
  String get recipeDetailViewOriginalSemantics =>
      'Bekijk origineel recept in browser';

  @override
  String get cookModeCouldNotLoad => 'Kon recept niet laden';

  @override
  String get cookModeClose => 'Sluiten';

  @override
  String get cookModeServings => 'Porties';

  @override
  String get cookModeDecreaseServings => 'Porties verminderen';

  @override
  String get cookModeIncreaseServings => 'Porties vermeerderen';

  @override
  String get cookModeStartCooking => 'Beginnen met koken';

  @override
  String get cookModeGathered => 'verzameld';

  @override
  String get cookModeNotGathered => 'niet verzameld';

  @override
  String cookModeStepOf(num step, num total) {
    return 'Stap $step van $total';
  }

  @override
  String get cookModeExitTooltip => 'Kookmodus verlaten';

  @override
  String get cookModeTimerDone => 'Timer klaar!';

  @override
  String get cookModeDoneArrow => 'Klaar →';

  @override
  String get cookModeFinish => 'Voltooien';

  @override
  String cookModeStepLabel(num number) {
    return 'Stap $number';
  }

  @override
  String cookModeStepDone(num number) {
    return 'Stap $number gedaan. Tik om te bekijken';
  }

  @override
  String cookModeCurrentStep(num number) {
    return 'Huidige stap $number';
  }

  @override
  String cookModeStepJump(num number, String description) {
    return 'Stap $number: $description. Tik om naar deze stap te springen';
  }

  @override
  String cookModeBackToStep(num step) {
    return 'Terug naar stap $step';
  }

  @override
  String get cookModeShowIngredients => 'Toon ingrediënten';

  @override
  String get cookModeIngredients => 'Ingrediënten';

  @override
  String get cookModeFinished => 'Voltooid — goed gedaan';

  @override
  String get cookModeFinishCooking => 'Koken voltooien';

  @override
  String get cookModeAdvanceStep => 'Klaar, ga naar volgende stap';

  @override
  String get expenseAppBarTitle => 'Geld';

  @override
  String get expenseScanReceiptTooltip => 'Bon scannen';

  @override
  String get expenseRecurringTooltip => 'Terugkerend';

  @override
  String get expenseAddExpense => 'Uitgave toevoegen';

  @override
  String get expenseYouAreOwed => 'Je krijgt';

  @override
  String get expenseYouOwe => 'Je moet';

  @override
  String get expenseAllSquare => 'Helemaal vereffend';

  @override
  String expenseSuggestedPayments(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count voorgestelde betalingen',
      one: '$count voorgestelde betaling',
    );
    return '$_temp0 om te vereffenen';
  }

  @override
  String expenseOpenBalances(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count openstaande saldi',
      one: '$count openstaand saldo',
    );
    return '$_temp0 in het huishouden';
  }

  @override
  String get expenseNoOneOwes => 'Niemand hoeft nu iemand te betalen';

  @override
  String get expenseTabTimeline => 'Tijdlijn';

  @override
  String get expenseTabSettlements => 'Vereffeningen';

  @override
  String get expenseToday => 'Vandaag';

  @override
  String get expenseYesterday => 'Gisteren';

  @override
  String get expenseNoExpensesTitle => 'Nog geen uitgaven';

  @override
  String get expenseNoExpensesDesc =>
      'Houd gedeelde kosten bij met je huishouden.';

  @override
  String get expenseAddFirstExpense => 'Eerste uitgave toevoegen';

  @override
  String get expenseLoadError =>
      'Kon uitgaven niet laden. Controleer je verbinding.';

  @override
  String get expenseLoadMoreError => 'Meer uitgaven laden mislukt.';

  @override
  String expensePaidBy(String payer) {
    return 'Betaald door $payer';
  }

  @override
  String expenseConvertedAmount(String amount) {
    return '≈ $amount';
  }

  @override
  String get expenseDeleteTitle => 'Uitgave verwijderen';

  @override
  String get expenseDeleteBody =>
      'Dit verwijdert deze uitgave en alle bijbehorende bonnen permanent. Dit kan niet ongedaan worden gemaakt.';

  @override
  String get expenseSettlementRecorded => 'Vereffening vastgelegd';

  @override
  String get expenseSettlementFailed => 'Kon vereffening niet vastleggen.';

  @override
  String get expenseSuggestedPaymentsTitle => 'Voorgestelde betalingen';

  @override
  String get expenseSuggestedPaymentsDesc =>
      'Berekend op basis van elke uitgave, splitsing en vastgelegde vereffening in dit huishouden.';

  @override
  String get expenseAllSettled => 'Alles vereffend!';

  @override
  String get expenseNoOneOwesRight =>
      'Niemand is iemand iets verschuldigd op dit moment.';

  @override
  String get expenseSameAccount => 'Zelfde account';

  @override
  String get expenseFrom => 'Van';

  @override
  String get expenseTo => 'Aan';

  @override
  String get expenseRecordHelper =>
      'Leg deze vereffening vast nadat de betaling is gedaan.';

  @override
  String get expenseRecording => 'Vastleggen...';

  @override
  String get expenseRecordSettlement => 'Vereffening vastleggen';

  @override
  String get expenseBalances => 'Saldi';

  @override
  String expenseBalancesOpen(num count) {
    return '$count openstaand';
  }

  @override
  String get expenseExpandBalances => 'Saldi uitklappen';

  @override
  String get expenseCollapseBalances => 'Saldi inklappen';

  @override
  String get expenseNoBalances =>
      'Nog geen saldi. Voeg een uitgave met splitsingen toe om het grootboek te starten.';

  @override
  String get expenseIsOwed => 'krijgt';

  @override
  String get expenseOwes => 'is verschuldigd';

  @override
  String get expenseSettled => 'vereffend';

  @override
  String get recurringAppBarTitle => 'Terugkerend';

  @override
  String get recurringAddRecurring => 'Terugkerend toevoegen';

  @override
  String get recurringAddRecurringTooltip => 'Terugkerende uitgave toevoegen';

  @override
  String get recurringNoRecurringTitle => 'Geen terugkerende uitgaven';

  @override
  String get recurringNoRecurringDesc =>
      'Voeg een terugkerende uitgave toe om regelmatige betalingen bij te houden';

  @override
  String get recurringAddExpense => 'Uitgave toevoegen';

  @override
  String get recurringPauseTooltip => 'Pauzeren';

  @override
  String get recurringResumeTooltip => 'Hervatten';

  @override
  String get recurringDeleteTooltip => 'Verwijderen';

  @override
  String recurringNextDate(String date) {
    return 'Volgende: $date';
  }

  @override
  String get recurringDeleteTitle => 'Terugkerende uitgave verwijderen';

  @override
  String get recurringDeleteBody =>
      'Dit stopt het aanmaken van toekomstige uitgaven.';

  @override
  String get recurringFrequencyDaily => 'Dagelijks';

  @override
  String get recurringFrequencyWeekly => 'Wekelijks';

  @override
  String get recurringFrequencyBiweekly => 'Elke 2 weken';

  @override
  String get recurringFrequencyMonthly => 'Maandelijks';

  @override
  String get recurringFrequencyQuarterly => 'Per kwartaal';

  @override
  String get recurringFrequencyYearly => 'Jaarlijks';

  @override
  String get recurringSheetTitle => 'Terugkerende uitgave toevoegen';

  @override
  String get recurringSheetDescription => 'Beschrijving';

  @override
  String get recurringSheetAmount => 'Bedrag';

  @override
  String get recurringSheetFrequency => 'Frequentie';

  @override
  String get recurringSheetPayer => 'Betaler';

  @override
  String get recurringValidationDesc => 'Voer een beschrijving in.';

  @override
  String get recurringValidationAmount => 'Voer een bedrag in.';

  @override
  String get recurringValidationPayer => 'Selecteer een betaler.';

  @override
  String get recurringValidationAmountPositive =>
      'Voer een geldig bedrag groter dan nul in.';

  @override
  String get recurringNoHouseholdDesc =>
      'Word lid of maak een huishouden om terugkerende uitgaven te beheren';

  @override
  String get listAppBarTitle => 'Lijsten';

  @override
  String get listShoppingTripTooltip => 'Boodschappen doen';

  @override
  String get listSearchLabel => 'Lijsten doorzoeken';

  @override
  String get listSearchHint => 'Naam, bv. boodschappen';

  @override
  String get listScanTooltip => 'Bon of lijst scannen';

  @override
  String get listSortLabel => 'Sorteren';

  @override
  String get listSortNewest => 'Nieuwste';

  @override
  String get listSortOldest => 'Oudste';

  @override
  String get listSortAZ => 'A–Z';

  @override
  String get listSortMostItems => 'Meeste items';

  @override
  String get listSortGridView => 'Rasterweergave';

  @override
  String get listNewList => 'Nieuwe lijst';

  @override
  String get listFilterAll => 'Alle';

  @override
  String get listFilterShopping => 'Boodschappen';

  @override
  String get listFilterTodo => 'Te doen';

  @override
  String get listFilterCustom => 'Aangepast';

  @override
  String get listEmptyShopping => 'Geen boodschappenlijsten';

  @override
  String get listEmptyTodo => 'Geen te-doenlijsten';

  @override
  String get listEmptyCustom => 'Geen aangepaste lijsten';

  @override
  String get listEmptyAll => 'Nog geen lijsten';

  @override
  String get listEmptyShoppingDesc =>
      'Geweldig voor boodschappen, maaltijdvoorbereiding, weekendboodschappen.';

  @override
  String get listEmptyTodoDesc =>
      'Taken, klusjes, alles met een selectievakje.';

  @override
  String get listEmptyCustomDesc => 'Vrije vorm — jouw lijst, jouw regels.';

  @override
  String get listEmptyAllDesc =>
      'Voeg regels toe in een lijst; de eerste paar verschijnen als voorbeeld op de kaart.';

  @override
  String get listCreateShopping => 'Maak een boodschappenlijst';

  @override
  String get listCreateTodo => 'Maak een te-doenlijst';

  @override
  String get listCreateCustom => 'Maak een aangepaste lijst';

  @override
  String get listCreateFirst => 'Maak je eerste lijst';

  @override
  String listNoMatch(String query) {
    return 'Geen lijsten komen overeen met \"$query\"';
  }

  @override
  String get listSearchDesc => 'Namen en lijstitems worden doorzocht.';

  @override
  String get listRenameTitle => 'Lijst hernoemen';

  @override
  String get listCouldNotRename => 'Kon lijst niet hernoemen.';

  @override
  String get listDeleteTitle => 'Lijst verwijderen';

  @override
  String get listDeleteBody =>
      'Dit verwijdert deze lijst en al zijn items permanent.';

  @override
  String get listCouldNotDelete => 'Kon lijst niet verwijderen.';

  @override
  String listAddItemTo(String name) {
    return 'Item toevoegen aan $name';
  }

  @override
  String get listItemName => 'Itemnaam';

  @override
  String get listCouldNotAddItem => 'Kon item niet toevoegen.';

  @override
  String get listQuickAddItemTooltip => 'Snel item toevoegen';

  @override
  String listQuickAddItemSemantics(String name) {
    return 'Snel item toevoegen aan $name';
  }

  @override
  String get listOptionsTooltip => 'Lijstopties';

  @override
  String listDetailEditName(String name) {
    return 'Lijstnaam bewerken, $name';
  }

  @override
  String get listDetailCloseSearch => 'Zoeken sluiten';

  @override
  String get listDetailSearchTooltip => 'Zoeken';

  @override
  String get listDetailFilterLabel => 'Items filteren';

  @override
  String get listDetailFilterHint => 'Naam, bv. melk';

  @override
  String get listDetailAllCheckedOff => 'Alles afgevinkt';

  @override
  String get listDetailClearChecked => 'Afgevinkte wissen';

  @override
  String get listDetailCheckedOff => 'Afgevinkt';

  @override
  String get listDetailNothingHere => 'Nog niets hier';

  @override
  String get listDetailNothingHereDesc =>
      'Fotografeer een handgeschreven lijst, koelkastbriefje of screenshot. Wij halen de items eruit.';

  @override
  String get listDetailScanThisList => 'Scan deze lijst';

  @override
  String get listDetailTypeItem => 'Typ een item';

  @override
  String get listDetailNoMatch => 'Geen items komen overeen met je filter';

  @override
  String get listDetailCouldNotLoad => 'Kon lijst niet laden.';

  @override
  String get listDetailCouldNotUpdate =>
      'Kon niet bijwerken. Probeer het opnieuw.';

  @override
  String get listDetailCouldNotAddItem =>
      'Kon item niet toevoegen. Probeer het opnieuw.';

  @override
  String get listDetailCouldNotClear =>
      'Kon items niet wissen. Probeer het opnieuw.';

  @override
  String listDetailItemDeleted(String name) {
    return '$name verwijderd';
  }

  @override
  String get listDetailCouldNotRestore => 'Kon item niet herstellen.';

  @override
  String get listDetailCouldNotReorder =>
      'Kon items niet herordenen. Probeer het opnieuw.';

  @override
  String listDetailItemsAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items toegevoegd aan lijst',
      one: '1 item toegevoegd aan lijst',
    );
    return '$_temp0';
  }

  @override
  String get listDetailCouldNotStartScan =>
      'Kon scan niet starten. Probeer opnieuw.';

  @override
  String get listDetailSetPrice => 'Prijs instellen';

  @override
  String get listDetailPriceInput => 'Prijs';

  @override
  String get listDetailPriceHint => '0,00';

  @override
  String get listDetailCouldNotSetPrice => 'Kon prijs niet instellen.';

  @override
  String get listDetailClearTitle => 'Lijst wissen';

  @override
  String listDetailClearBody(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'items',
      one: 'item',
    );
    return 'Dit verwijdert alle $count $_temp0. Dit kan niet ongedaan worden gemaakt.';
  }

  @override
  String get listDetailClearConfirm => 'Lijst wissen';

  @override
  String get listDetailArchiveTitle => 'Lijst archiveren';

  @override
  String get listDetailArchiveBody =>
      'Deze lijst wordt verborgen voor je huishouden.';

  @override
  String get listDetailFailedArchive => 'Lijst archiveren mislukt.';

  @override
  String get listDetailDeleteTitle => 'Lijst verwijderen';

  @override
  String get listDetailDeleteBody =>
      'Dit verwijdert deze lijst en al zijn items permanent. Dit kan niet ongedaan worden gemaakt.';

  @override
  String get listDetailCouldNotDelete => 'Kon lijst niet verwijderen.';

  @override
  String get listDetailExpenseGenerated => 'Uitgave aangemaakt';

  @override
  String get listDetailCouldNotLoadCostSummary =>
      'Kon kostenoverzicht niet laden.';

  @override
  String get listDetailCouldNotAddPhoto => 'Kon foto niet toevoegen.';

  @override
  String get listDetailCouldNotRemovePhoto => 'Kon foto niet verwijderen.';

  @override
  String get listDetailListImage => 'Lijstafbeelding';

  @override
  String get listDetailCheckAll => 'Alles aanvinken';

  @override
  String get listDetailUncheckAll => 'Alles uitvinken';

  @override
  String get listDetailCostSummary => 'Kostenoverzicht';

  @override
  String get listDetailScanList => 'Lijst scannen';

  @override
  String get calendarAppBarTitle => 'Kalender';

  @override
  String get calendarViewWeek => 'Week';

  @override
  String get calendarViewMonth => 'Maand';

  @override
  String get calendarViewAgenda => 'Agenda';

  @override
  String get calendarWeekView => 'Weekweergave';

  @override
  String get calendarMonthView => 'Maandweergave';

  @override
  String get calendarAgendaView => 'Agendaweergave';

  @override
  String get calendarPreviousWeek => 'Vorige week';

  @override
  String get calendarNextWeek => 'Volgende week';

  @override
  String get calendarPreviousMonth => 'Vorige maand';

  @override
  String get calendarNextMonth => 'Volgende maand';

  @override
  String get calendarMonthJanuary => 'januari';

  @override
  String get calendarMonthFebruary => 'februari';

  @override
  String get calendarMonthMarch => 'maart';

  @override
  String get calendarMonthApril => 'april';

  @override
  String get calendarMonthMay => 'mei';

  @override
  String get calendarMonthJune => 'juni';

  @override
  String get calendarMonthJuly => 'juli';

  @override
  String get calendarMonthAugust => 'augustus';

  @override
  String get calendarMonthSeptember => 'september';

  @override
  String get calendarMonthOctober => 'oktober';

  @override
  String get calendarMonthNovember => 'november';

  @override
  String get calendarMonthDecember => 'december';

  @override
  String get calendarShortMon => 'Ma';

  @override
  String get calendarShortTue => 'Di';

  @override
  String get calendarShortWed => 'Wo';

  @override
  String get calendarShortThu => 'Do';

  @override
  String get calendarShortFri => 'Vr';

  @override
  String get calendarShortSat => 'Za';

  @override
  String get calendarShortSun => 'Zo';

  @override
  String get calendarWeekdayMonday => 'maandag';

  @override
  String get calendarWeekdayTuesday => 'dinsdag';

  @override
  String get calendarWeekdayWednesday => 'woensdag';

  @override
  String get calendarWeekdayThursday => 'donderdag';

  @override
  String get calendarWeekdayFriday => 'vrijdag';

  @override
  String get calendarWeekdaySaturday => 'zaterdag';

  @override
  String get calendarWeekdaySunday => 'zondag';

  @override
  String get calendarToday => 'Vandaag';

  @override
  String calendarDayLabel(num day) {
    return 'Dag $day';
  }

  @override
  String get calendarNothingPlanned => 'Niets gepland';

  @override
  String get calendarNothingAhead => 'Niets vooruit';

  @override
  String get calendarNothingAheadDesc =>
      'Aankomende klusjes, maaltijdplanningen en terugkerende uitgaven verschijnen hier.';

  @override
  String get calendarAddChore => 'Klus toevoegen';

  @override
  String get calendarAddExpense => 'Uitgave toevoegen';

  @override
  String get calendarViewInWeek => 'Bekijk in week';

  @override
  String get calendarEventMeal => 'Maaltijd';

  @override
  String get calendarEventChore => 'Klus';

  @override
  String get calendarEventRecurring => 'Terugkerend';

  @override
  String get calendarEventExpense => 'Uitgave';

  @override
  String get calendarEventReminder => 'Herinnering';

  @override
  String calendarServingsPpl(num servings) {
    return '$servings pers. ';
  }

  @override
  String get calendarNoHouseholdDesc =>
      'Word lid of maak een huishouden om de kalender te bekijken';

  @override
  String get calendarCreateHousehold => 'Huishouden aanmaken';

  @override
  String calendarWeekHeader(String weekStart, String weekEnd) {
    return '$weekStart – $weekEnd';
  }

  @override
  String calendarMonthHeader(String month, num year) {
    return '$month $year';
  }

  @override
  String get mealPlanAppBarTitle => 'Maaltijdplanning';

  @override
  String get mealPlanGenerateShoppingList => 'Boodschappenlijst genereren';

  @override
  String get mealPlanPreviousWeek => 'Vorige week';

  @override
  String get mealPlanNextWeek => 'Volgende week';

  @override
  String get mealPlanBreakfast => 'Ontbijt';

  @override
  String get mealPlanLunch => 'Lunch';

  @override
  String get mealPlanDinner => 'Avondeten';

  @override
  String get mealPlanAddMeal => 'Maaltijd toevoegen';

  @override
  String get mealPlanRecipeFallback => 'Recept';

  @override
  String mealPlanServings(num servings) {
    return '${servings}p';
  }

  @override
  String mealPlanShoppingListCreated(num count) {
    return 'Boodschappenlijst aangemaakt met $count items';
  }

  @override
  String get mealPlanTrackCosts => 'Kosten bijhouden';

  @override
  String get mealPlanCouldNotAdd => 'Kon maaltijd niet toevoegen.';

  @override
  String get mealPlanCouldNotRemove => 'Kon maaltijd niet verwijderen.';

  @override
  String get mealPlanCouldNotUpdate => 'Kon maaltijd niet bijwerken.';

  @override
  String get mealPlanPickRecipe => 'Kies een recept';

  @override
  String get mealPlanCouldNotLoadRecipes => 'Kon recepten niet laden';

  @override
  String get mealPlanNoRecipes => 'Nog geen recepten';

  @override
  String get mealPlanAddRecipesDesc =>
      'Voeg recepten toe om maaltijden te plannen';

  @override
  String get mealPlanSearchRecipes => 'Recepten zoeken...';

  @override
  String mealPlanNoMatch(String query) {
    return 'Geen recepten komen overeen met \"$query\"';
  }

  @override
  String get mealPlanServingsSheet => 'Porties';

  @override
  String get mealPlanFewerServings => 'Minder porties';

  @override
  String get mealPlanMoreServings => 'Meer porties';

  @override
  String mealPlanOpenRecipe(String slot) {
    return 'Open recept voor $slot';
  }

  @override
  String mealPlanAddMealFor(String slot) {
    return 'Maaltijd toevoegen voor $slot';
  }

  @override
  String get accountAppBarTitle => 'Jij';

  @override
  String get accountFailedLoadProfile =>
      'Profiel laden mislukt. Probeer het opnieuw.';

  @override
  String get accountFailedSaveName => 'Naam opslaan mislukt';

  @override
  String get accountEditYourName => 'Je naam bewerken';

  @override
  String get accountChangePassword => 'Wachtwoord wijzigen';

  @override
  String get accountFillPasswordFields => 'Vul alle wachtwoordvelden in.';

  @override
  String get accountPasswordMinLength =>
      'Nieuw wachtwoord moet minstens 6 tekens bevatten.';

  @override
  String get accountPasswordsMismatch =>
      'Nieuwe wachtwoorden komen niet overeen.';

  @override
  String get accountPasswordChanged => 'Wachtwoord gewijzigd';

  @override
  String get accountCurrentPassword => 'Huidig wachtwoord';

  @override
  String get accountNewPassword => 'Nieuw wachtwoord';

  @override
  String get accountConfirmPassword => 'Bevestig nieuw wachtwoord';

  @override
  String get accountChangePasswordButton => 'Wachtwoord wijzigen';

  @override
  String get accountTermsTitle => 'Servicevoorwaarden';

  @override
  String get accountTermsBody =>
      'Gebruik mitlist verantwoord en respecteer de privacy van je huisgenoten. Misbruik gedeelde functies of gegevens niet. mitlist wordt aangeboden zonder garanties.';

  @override
  String get accountDeleteAccount => 'Account verwijderen';

  @override
  String get accountDeleteAccountBody =>
      'Dit verwijdert je account en alle bijbehorende gegevens permanent. Dit kan niet ongedaan worden gemaakt.';

  @override
  String get accountLogOut => 'Uitloggen';

  @override
  String get accountDeleteAccountButton => 'Account verwijderen';

  @override
  String get accountHouseholdSection => 'Huishouden';

  @override
  String accountSwitchToHousehold(String name) {
    return 'Wissel naar $name';
  }

  @override
  String get accountNotificationInbox => 'Notificatie-inbox';

  @override
  String get accountNotificationPreferences => 'Notificatievoorkeuren';

  @override
  String get accountAppearance => 'Weergave';

  @override
  String get accountAppearanceSystem => 'Systeem';

  @override
  String get accountAppearanceLight => 'Licht';

  @override
  String get accountAppearanceDark => 'Donker';

  @override
  String get accountChangePasswordRow => 'Wachtwoord wijzigen';

  @override
  String get accountVersion => 'Versie';

  @override
  String get accountTermsRow => 'Servicevoorwaarden';

  @override
  String get accountGuestTitle => 'Je gebruikt een gastaccount';

  @override
  String get accountGuestDesc =>
      'Maak een volledig account om je gegevens permanent te bewaren en toegang te krijgen tot alle functies.';

  @override
  String get accountCreateFullAccount => 'Volledig account aanmaken';

  @override
  String get accountExportCSV => 'Uitgaven exporteren (CSV)';

  @override
  String get accountShareJSON => 'Uitgaven delen (JSON)';

  @override
  String get accountCopyJSON => 'Uitgaven kopiëren (JSON)';

  @override
  String get accountJSONCopied => 'Uitgaven JSON gekopieerd naar klembord';

  @override
  String get accountCreateAccountTitle => 'Maak je account';

  @override
  String get accountFillAllFields => 'Vul alle velden in.';

  @override
  String get accountYourName => 'Je naam';

  @override
  String get accountYourNameHint => 'bv. Jan Jansen';

  @override
  String get accountEmail => 'E-mail';

  @override
  String get accountEmailHint => 'jij@voorbeeld.nl';

  @override
  String get accountPassword => 'Wachtwoord';

  @override
  String get accountCreatingAccount => 'Account aanmaken…';

  @override
  String get accountCreateAccount => 'Account aanmaken';

  @override
  String get accountCreatedWelcome => 'Account aangemaakt. Welkom!';

  @override
  String get notificationsAppBarTitle => 'Notificaties';

  @override
  String get notificationsMarkAllRead => 'Alles als gelezen markeren';

  @override
  String get notificationsFailedLoad => 'Notificaties laden mislukt.';

  @override
  String get notificationsFailedLoadMore => 'Meer notificaties laden mislukt.';

  @override
  String get notificationsFailedMarkAllRead =>
      'Alles als gelezen markeren mislukt.';

  @override
  String get notificationsFailedMarkRead => 'Als gelezen markeren mislukt.';

  @override
  String get notificationsNoHouseholdDesc =>
      'Maak of word lid van een huishouden om notificaties te ontvangen.';

  @override
  String get notificationsNoNotifications => 'Nog geen notificaties';

  @override
  String get notificationsNoNotificationsDesc =>
      'Wanneer iemand een klus toevoegt, een rekening splitst of je vermeldt, verschijnt het hier.';

  @override
  String notificationsUnreadLabel(String title) {
    return 'Ongelezen, $title';
  }

  @override
  String get notifPrefAppBarTitle => 'Notificatievoorkeuren';

  @override
  String get notifPrefFailedLoad => 'Notificatievoorkeuren laden mislukt.';

  @override
  String get notifPrefNoHouseholdDesc =>
      'Word lid of maak een huishouden om notificatievoorkeuren te configureren.';

  @override
  String get notifPrefNoPreferences => 'Nog geen voorkeuren';

  @override
  String get notifPrefNoPreferencesDesc =>
      'Voorkeuren worden aangemaakt wanneer je lid wordt van een huishouden. Als je net lid bent geworden, zouden ze snel moeten verschijnen.';

  @override
  String get notifPrefGroupName => 'Notificaties';

  @override
  String get notifPrefChoreDueReminders => 'Klus-herinneringen';

  @override
  String get notifPrefChoreDueRemindersDesc => 'Wanneer een klus eraan komt';

  @override
  String get notifPrefChoreDueDayOf => 'Klus op de dag zelf';

  @override
  String get notifPrefChoreDueDayOfDesc =>
      'Op de dag dat een klus moet gebeuren';

  @override
  String get notifPrefListItemAdded => 'Lijstitem toegevoegd';

  @override
  String get notifPrefListItemAddedDesc =>
      'Wanneer iemand iets aan een gedeelde lijst toevoegt';

  @override
  String get notifPrefExpenseCreated => 'Uitgave aangemaakt';

  @override
  String get notifPrefExpenseCreatedDesc =>
      'Wanneer een nieuwe uitgave wordt geregistreerd';

  @override
  String get notifPrefMealPlanChanged => 'Maaltijdplanning gewijzigd';

  @override
  String get notifPrefMealPlanChangedDesc =>
      'Wanneer de maaltijdplanning wordt bijgewerkt';

  @override
  String get notifPrefWeeklyDigest => 'Wekelijkse samenvatting';

  @override
  String get notifPrefWeeklyDigestDesc =>
      'Een overzicht van huishoudactiviteit';

  @override
  String get notifPrefPinwallReminders => 'Prikbord-herinneringen';

  @override
  String get notifPrefPinwallRemindersDesc =>
      'Wanneer iemand een herinnering voor later vastzet';

  @override
  String get notifPrefPushNotifications => 'Push-notificaties';

  @override
  String get notifPrefPushNotificationsDesc =>
      'Ontvang notificaties op dit apparaat';

  @override
  String get shoppingTripAppBarTitle => 'Boodschappentocht';

  @override
  String get shoppingTripChooseStore => 'Kies winkel';

  @override
  String get shoppingTripNoLists => 'Nog geen lijsten';

  @override
  String get shoppingTripNoListsDesc =>
      'Maak een boodschappenlijst om een tocht te starten';

  @override
  String get shoppingTripAllCaughtUp => 'Helemaal bij';

  @override
  String get shoppingTripAllCaughtUpDesc =>
      'Geen open items in je lijsten. Voeg items toe aan een lijst om ze hier te zien.';

  @override
  String get shoppingTripSortedByAisles => 'Gesorteerd op winkelpaden';

  @override
  String shoppingTripSortedByStoreAisles(String store) {
    return 'Gesorteerd op $store paden';
  }

  @override
  String get shoppingTripMarkDone => 'Markeren als gedaan';

  @override
  String shoppingTripBasketBar(num collected, String price) {
    return '/ $collected verzameld$price';
  }

  @override
  String shoppingTripItemsWorthDone(String amount) {
    return '$amount aan artikelen gemarkeerd als gedaan';
  }

  @override
  String get shoppingTripAddExpense => 'Uitgave toevoegen';

  @override
  String get shoppingTripStampDone => 'KLAAR';

  @override
  String shoppingTripStampItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get shoppingTripFallbackList => 'Lijst';

  @override
  String shoppingTripMarkNotPurchased(String item) {
    return 'Markeer $item als niet gekocht';
  }

  @override
  String shoppingTripMarkPurchased(String item) {
    return 'Markeer $item als gekocht';
  }

  @override
  String get scannerAppBarTitle => 'Scanner';

  @override
  String get scannerShoppingAt => 'Winkelen bij';

  @override
  String get scannerChooseStore => 'Kies je winkel';

  @override
  String get scannerHintText =>
      'Scan een bon, lijst, recept,\nof klus-herinnering';

  @override
  String get scannerAnalyzing => 'Analyseren…';

  @override
  String get scannerScanGrocery => 'Boodschappenlijst scannen';

  @override
  String get scannerScanReceipt => 'Bon, recept of klus scannen';

  @override
  String get scannerAnalyzeThis => 'Deze afbeelding analyseren';

  @override
  String get scannerTakeOrChoose => 'Maak een foto of kies er een';

  @override
  String get scannerPickDifferent => 'Kies andere afbeelding';

  @override
  String get scannerScanSheetTitle => 'Boodschappenlijst scannen';

  @override
  String get scannerAddScanTitle => 'Scan toevoegen';

  @override
  String get scannerTakePhoto => 'Foto maken';

  @override
  String get scannerChooseFromGallery => 'Kies uit galerij';

  @override
  String get scannerTypeReceipt => 'Bon';

  @override
  String get scannerTypeShoppingList => 'Boodschappenlijst';

  @override
  String get scannerTypeRecipe => 'Recept';

  @override
  String get scannerTypeChore => 'Klus';

  @override
  String scannerDetectedType(String type) {
    return 'Gedetecteerd: $type';
  }

  @override
  String scannerItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '$count item',
    );
    return '$_temp0';
  }

  @override
  String scannerAndMore(num count) {
    return '…en nog $count';
  }

  @override
  String scannerStepCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stappen',
      one: '$count stap',
    );
    return '$_temp0';
  }

  @override
  String scannerTotal(String amount) {
    return 'Totaal: $amount';
  }

  @override
  String get scannerAddToLists => 'Aan lijsten toevoegen';

  @override
  String get scannerCreateExpense => 'Uitgave aanmaken';

  @override
  String get scannerCreateRecipe => 'Recept aanmaken';

  @override
  String get scannerCreateChore => 'Klus aanmaken';

  @override
  String get scannerUseThis => 'Gebruik dit';

  @override
  String get scannerScanAgain => 'Opnieuw scannen';

  @override
  String get smartCaptureBack => 'Terug';

  @override
  String get smartCaptureShowEnhanced => 'Toon verbeterd';

  @override
  String get smartCaptureOriginal => 'Origineel';

  @override
  String get smartCaptureUseAnyway => 'Toch gebruiken';

  @override
  String get smartCaptureUseScan => 'Scan gebruiken';

  @override
  String get smartCaptureRetake => 'Opnieuw';

  @override
  String get smartCaptureReady => 'Klaar';

  @override
  String get smartCaptureUsable => 'Bruikbaar';

  @override
  String get smartCaptureRetakeSuggested => 'Opnieuw aanbevolen';

  @override
  String get liveSmartCaptureNoCamera => 'Geen camera beschikbaar.';

  @override
  String get liveSmartCaptureCouldNotOpen => 'Kon de camera niet openen.';

  @override
  String get liveSmartCaptureFrameList => 'Kader de lijst';

  @override
  String get liveSmartCaptureCameraUnavailable => 'Camera niet beschikbaar';

  @override
  String get liveSmartCaptureGallery => 'Galerij';

  @override
  String get liveSmartCaptureScan => 'Scannen';

  @override
  String get liveSmartCaptureCouldNotCapture => 'Kon die foto niet vastleggen.';

  @override
  String scanReviewAddToList(String list) {
    return 'Toevoegen aan $list';
  }

  @override
  String get scanReviewReviewItems => 'Items beoordelen';

  @override
  String scanReviewAcceptAll(num count) {
    return 'Alles accepteren ($count)';
  }

  @override
  String get scanReviewStoreLabel => 'Winkel:';

  @override
  String get scanReviewYouMightNeed => 'Misschien ook nodig';

  @override
  String get scanReviewIgnored => 'Genegeerd';

  @override
  String get scanReviewNewList => 'Nieuwe lijst';

  @override
  String get scanReviewAddToWhichList => 'Aan welke lijst toevoegen?';

  @override
  String get scanReviewNewListOption => 'Nieuwe lijst…';

  @override
  String get scanReviewScannedList => 'Gescande lijst';

  @override
  String get scanReviewCreateList => 'Lijst aanmaken';

  @override
  String get scanReviewAdding => 'Toevoegen…';

  @override
  String scanReviewRemoveItem(String item) {
    return 'Verwijder $item';
  }

  @override
  String get scanReviewRestore => 'Herstellen';

  @override
  String get scanReviewEditItem => 'Item bewerken';

  @override
  String scanReviewOCRSaw(String text) {
    return 'OCR zag: \"$text\"';
  }

  @override
  String get scanReviewItemName => 'Itemnaam';

  @override
  String get scanReviewQty => 'Aant.';

  @override
  String get scanReviewUnit => 'Eenheid';

  @override
  String get scanReviewDidYouMean => 'Bedoelde je?';

  @override
  String get shareTargetAppBarTitle => 'Opslaan in mitlist';

  @override
  String get shareTargetSharedText => 'Gedeelde tekst';

  @override
  String get shareTargetPasteHint => 'Plak of typ de gedeelde tekst hier…';

  @override
  String get shareTargetAddPhotos => 'Foto\'s toevoegen';

  @override
  String shareTargetPhotosAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count foto\'s toegevoegd',
      one: '1 foto toegevoegd',
    );
    return '$_temp0';
  }

  @override
  String get shareTargetPreviewPlaceholder =>
      'Plak hier nu tekst, of stuur inhoud vanuit de deel-extensie wanneer die integratie beschikbaar is.';

  @override
  String get shareTargetDestLists => 'Lijsten';

  @override
  String get shareTargetDestListsDesc =>
      'Opslaan in een boodschappen- of te-doenlijst';

  @override
  String get shareTargetDestPinwall => 'Prikbord';

  @override
  String get shareTargetDestPinwallDesc =>
      'Plaats een notitie (en optionele foto\'s) voor je huishouden';

  @override
  String get shareTargetDestRecipes => 'Recepten';

  @override
  String get shareTargetDestRecipesDesc => 'Toevoegen aan opgeslagen recepten';

  @override
  String get shareTargetSelectHousehold => 'Selecteer huishouden';

  @override
  String get shareTargetSaved => 'Opgeslagen';

  @override
  String get shareTargetFailedSave => 'Opslaan mislukt. Probeer het opnieuw.';

  @override
  String get shareTargetValidationText => 'Plak of typ iets om op te slaan.';

  @override
  String get shareTargetValidationNote =>
      'Voeg een notitie of minstens één foto toe.';

  @override
  String get shareTargetValidationHousehold =>
      'Maak of word eerst lid van een huishouden.';

  @override
  String get expenseCreationTitle => 'Uitgave toevoegen';

  @override
  String get expenseCreationAmountHint => '0,00';

  @override
  String expenseCreationRateHint(String currency, String groupCurrency) {
    return 'Koers: 1 $currency = ? $groupCurrency';
  }

  @override
  String get expenseCreationWhatsItFor => 'Waar is dit voor?';

  @override
  String get expenseCreationNotesHint => 'Notities (optioneel)';

  @override
  String get expenseCreationDateLabel => 'Uitgavedatum. Tik om te wijzigen.';

  @override
  String get expenseCreationReceiptButton => 'Bon';

  @override
  String get expenseCreationScanning => 'Scannen…';

  @override
  String get expenseCreationScanButton => 'Scannen';

  @override
  String get expenseCreationReceiptAttached =>
      'Bon bijgevoegd. Tik om opnieuw te scannen.';

  @override
  String get expenseCreationScanReceiptSemantics => 'Scan bon via camera';

  @override
  String get expenseCreationSplitMode => 'Verdeelmodus';

  @override
  String get expenseCreationSplitEqual => 'Gelijk';

  @override
  String get expenseCreationSplitExact => 'Exact';

  @override
  String get expenseCreationSplitShares => 'Aandelen';

  @override
  String get expenseCreationSplitPercent => 'Percentage';

  @override
  String get expenseCreationSplitHintExact =>
      'Voer het exacte bedrag in dat elke persoon verschuldigd is.';

  @override
  String get expenseCreationSplitHintPercent =>
      'Voer ieders aandeel in; moet optellen tot 100%.';

  @override
  String get expenseCreationSplitHintShares =>
      'Verdeel op basis van aandelen, bv. 2 aandelen betaalt dubbel.';

  @override
  String get expenseCreationSplitHintEqual =>
      'Verdeel het totaal gelijkmatig over geselecteerde leden.';

  @override
  String get expenseCreationSplitSharesLabel => 'Aandelen';

  @override
  String get expenseCreationSplitValuesAmount => 'Bedrag';

  @override
  String get expenseCreationSplitValuesPercent => '%';

  @override
  String get expenseCreationPaidBy => 'Betaald door';

  @override
  String get expenseCreationSplitWith => 'Verdelen met';

  @override
  String get expenseCreationSelectSplitter =>
      'Selecteer minstens één persoon om mee te verdelen.';

  @override
  String get expenseCreationEnterAmount =>
      'Voer een bedrag in om elk aandeel te bekijken.';

  @override
  String get expenseCreationValidationAmount =>
      'Voer een geldig bedrag groter dan nul in.';

  @override
  String get expenseCreationValidationRate =>
      'Voer een wisselkoers groter dan nul in.';

  @override
  String get expenseCreationReceiptUploadFailed =>
      'Uitgave opgeslagen, maar bon-upload mislukt.';

  @override
  String get expenseCreationExpenseAdded => 'Uitgave toegevoegd';

  @override
  String get pinwallBoardLabel => 'Prikbord';

  @override
  String get pinwallDragHint =>
      'Sleep notities om te verplaatsen  ·  Knijp om te zoomen';

  @override
  String get pinwallCloseBoard => 'Bord sluiten';

  @override
  String get pinwallEmptyBoard =>
      'Het bord is leeg.\nPrik een notitie vanuit de hub om te beginnen.';

  @override
  String pinwallNoteSemantics(String user, String content) {
    return '$user · $content';
  }

  @override
  String pinwallReminderLabel(String text) {
    return 'Herinnering · $text';
  }

  @override
  String pinwallRemindedLabel(String text) {
    return 'Herinnerd · $text';
  }

  @override
  String get pinwallChooseReminderDate => 'Kies herinneringsdatum';

  @override
  String get pinwallChooseReminderTime => 'Kies herinneringstijd';

  @override
  String get pinwallLinkTo => 'Koppelen aan…';

  @override
  String get pinwallLinkExpense => 'Een uitgave';

  @override
  String get pinwallRemoveLink => 'Koppeling verwijderen';

  @override
  String pinwallSelectEntity(String type) {
    return 'Selecteer $type';
  }

  @override
  String get pinwallOpenBoard => 'Pinwall-bord openen';

  @override
  String get pinwallLinkToChore => 'Koppelen aan klusje, lijst…';

  @override
  String get pinwallPickFutureTime => 'Kies een tijd in de toekomst.';

  @override
  String get pinwallCouldNotLoadEntities => 'Kon entiteiten niet laden.';

  @override
  String get pinwallPinned => 'Aan de muur geprikt';

  @override
  String get pinwallOpenBoardBtn => 'Bord openen';

  @override
  String get pinwallPostHint => 'Plaats een notitie voor het huishouden…';

  @override
  String get pinwallAddReminder => 'Herinnering toevoegen';

  @override
  String pinwallReminderSet(String label) {
    return 'Herinnering ingesteld voor $label. Tik om te wijzigen.';
  }

  @override
  String get pinwallClearReminder => 'Herinnering wissen';

  @override
  String get pinwallAttachPhoto => 'Foto bijvoegen';

  @override
  String get pinwallUploading => 'Uploaden…';

  @override
  String get pinwallPosting => 'Plaatsen…';

  @override
  String get pinwallPinIt => 'Vastpinnen';

  @override
  String get pinwallCouldNotLoadImage => 'Kon afbeelding niet laden.';

  @override
  String get pinwallRemoveFromPost => 'Uit bericht verwijderen';

  @override
  String get pinwallCouldNotRemovePhoto => 'Kon foto niet verwijderen.';

  @override
  String get pinwallCouldNotAddPhoto => 'Kon foto niet toevoegen.';

  @override
  String get pinwallLinkedList => 'Gekoppelde lijst';

  @override
  String get pinwallLinkedChore => 'Gekoppeld klusje';

  @override
  String get pinwallLinkedExpense => 'Gekoppelde uitgave';

  @override
  String pinwallOpenLinkedEntity(String entity) {
    return 'Gekoppelde $entity openen';
  }

  @override
  String get pinwallPostOptions => 'Berichtopties';

  @override
  String get pinwallDeletePin => 'Pin verwijderen';

  @override
  String get pinwallDeletePinBody =>
      'Deze pin wordt permanent verwijderd. Dit kan niet ongedaan worden gemaakt.';

  @override
  String get pinwallAddPhotoMenu => 'Foto toevoegen';

  @override
  String get tonightBreakfast => 'Vandaag · Ontbijt';

  @override
  String get tonightLunch => 'Vandaag · Lunch';

  @override
  String tonightOpenRecipe(String title) {
    return 'Vanavond: $title. Recept openen';
  }

  @override
  String get captureHintClearer => 'Probeer een duidelijkere foto';

  @override
  String get captureHintHoldSteady => 'Houd stil';

  @override
  String get captureHintMoreLight => 'Zoek meer licht';

  @override
  String get captureHintReduceGlare => 'Verminder schittering';

  @override
  String get captureHintMoveCloser => 'Kom dichterbij';

  @override
  String get accountLanguage => 'Taal';

  @override
  String get accountLanguageSystem => 'Systeem';

  @override
  String get navHome => 'Start';

  @override
  String get navChores => 'Klusjes';

  @override
  String get navMoney => 'Geld';

  @override
  String get navLists => 'Lijsten';

  @override
  String get navKitchen => 'Keuken';

  @override
  String get offlineBannerTitle => 'Sync-status';

  @override
  String get offlineBannerStatusOffline => 'Offline';

  @override
  String get offlineBannerStatusPending => 'In afwachting';

  @override
  String get offlineBannerStatusFailed => 'Mislukt';

  @override
  String get offlineBannerRetryHint =>
      'Wijzigingen worden automatisch opnieuw geprobeerd zodra de verbinding is hersteld.';

  @override
  String get offlineBannerOfflineHint =>
      'Je kunt offline wijzigingen blijven maken. Alles wordt gesynchroniseerd zodra je opnieuw verbinding maakt.';

  @override
  String get offlineBannerBarOffline =>
      'Offline — wijzigingen worden gesynchroniseerd bij verbinding';

  @override
  String offlineBannerSyncingCount(num count) {
    return '$count wijzigingen synchroniseren…';
  }

  @override
  String get offlineBannerSyncing => 'Wijzigingen synchroniseren…';

  @override
  String offlineBannerFailedCount(num count) {
    return 'Kon $count wijzigingen niet synchroniseren';
  }

  @override
  String get offlineBannerFailedOne => 'Kon een wijziging niet synchroniseren';

  @override
  String get offlineBannerRetry => 'Opnieuw';

  @override
  String get composerNewItem => 'Nieuw item';

  @override
  String get composerScanList => 'Lijst scannen';

  @override
  String get composerAddItem => 'Item toevoegen';

  @override
  String get listItemViewPhoto => 'Foto bekijken';

  @override
  String get listItemReplacePhoto => 'Foto vervangen';

  @override
  String get listItemAddPhoto => 'Foto toevoegen';

  @override
  String get listItemRemovePhoto => 'Foto verwijderen';

  @override
  String get listItemSetPrice => 'Prijs instellen';

  @override
  String get listItemDeleteAction => 'Verwijderen';

  @override
  String get listItemReorder => 'Herschikken';

  @override
  String listItemMarkUnchecked(String name) {
    return '$name als niet-afgevinkt markeren';
  }

  @override
  String listItemMarkChecked(String name) {
    return '$name als afgevinkt markeren';
  }

  @override
  String listItemViewPhotoFor(String name) {
    return 'Foto voor $name bekijken';
  }

  @override
  String get listItemFailedSave =>
      'Opslaan mislukt — tik op de sync-balk om opnieuw te proberen';

  @override
  String get listItemLongPressHint => 'Lang indrukken voor meer opties';

  @override
  String get scanCheckListPhoto => 'Controleer lijstfoto';

  @override
  String get scanReadingList => 'Je lijst lezen…';

  @override
  String get scanCouldNotProcess =>
      'Kon de afbeelding niet verwerken. Probeer het opnieuw.';

  @override
  String get scanSnapYourList => 'Maak een foto van je lijst';

  @override
  String get scanTakePhoto => 'Maak een foto';

  @override
  String get scanChooseFromGallery => 'Kies uit galerij';

  @override
  String get appDialogClose => 'Sluiten';

  @override
  String get appDialogPressBack => 'Druk op terug om te sluiten';

  @override
  String get shellNotifications => 'Meldingen';

  @override
  String get shellAccount => 'Account';

  @override
  String get errorSomethingWentWrong => 'Er is iets misgegaan';

  @override
  String filterRemoveLabel(String label) {
    return 'Verwijder filter $label';
  }

  @override
  String get currencyDropdownLabel => 'Valuta';

  @override
  String get passwordStrengthWeak => 'Zwak';

  @override
  String get passwordStrengthFair => 'Redelijk';

  @override
  String get passwordStrengthGood => 'Goed';

  @override
  String get passwordStrengthStrong => 'Sterk';

  @override
  String get checkToggleChecked => 'Aangevinkt';

  @override
  String get checkToggleNotChecked => 'Niet aangevinkt';

  @override
  String get notificationsDeleteNotification => 'Notificatie verwijderen';

  @override
  String get calendarTomorrow => 'Morgen';

  @override
  String get scannerCheckScan => 'Scan controleren';

  @override
  String get scannerCheckGrocery => 'Boodschappenlijst controleren';

  @override
  String recipeCreationNoItemsYet(String type) {
    return 'Nog geen $type.';
  }

  @override
  String get captureHintReady => 'Klaar om te scannen';

  @override
  String get captureHintUsable => 'Ziet er bruikbaar uit';

  @override
  String get authLoginTitle => 'Sign in';

  @override
  String get authLoginEmail => 'Email';

  @override
  String get authLoginYouExample => 'you@example.com';

  @override
  String get authLoginPassword => 'Password';

  @override
  String get authLoginYourPassword => 'Your password';

  @override
  String get authLoginForgotPassword => 'Forgot password?';

  @override
  String get authLoginSignInButton => 'Sign in';

  @override
  String get authLoginSigningIn => 'Signing in…';

  @override
  String get authLoginNoAccount => 'No account?';

  @override
  String get authLoginCreateOne => 'Create one';

  @override
  String get authLoginFillAllFields => 'Fill out all fields.';

  @override
  String get authLoginEmailRequired => 'Email is required.';

  @override
  String get authLoginPasswordRequired => 'Password is required.';

  @override
  String get authLoginGenericError =>
      'Couldn\'t sign in. Check your connection and try again.';

  @override
  String get authLoginRememberMe => 'Remember me';

  @override
  String get authLoginRememberMeOn => 'Remember me: on';

  @override
  String get authLoginRememberMeOff => 'Remember me: off';

  @override
  String get authLoginGoogle => 'Continue with Google';

  @override
  String get authLoginApple => 'Continue with Apple';

  @override
  String authLoginOAuthUnsupported(String provider) {
    return '$provider sign-in is only available on web, Android, and iOS right now.';
  }

  @override
  String get authLoginResetPasswordTitle => 'Reset Password';

  @override
  String get authLoginSendResetCode => 'Send reset code';

  @override
  String get authLoginResetCodeLabel => 'Reset code';

  @override
  String get authLoginResetCodeHint => 'Paste the code from your email';

  @override
  String get authLoginResetPasswordButton => 'Reset password';

  @override
  String get authLoginResetCodeSent =>
      'If that email exists, a reset code has been sent.';

  @override
  String get authLoginResetFillAllFields =>
      'Fill out the reset code and both password fields.';

  @override
  String get authLoginResetSuccess =>
      'Password reset successful. You can sign in now.';

  @override
  String get authSignupTitle => 'Create account';

  @override
  String get authSignupFirstName => 'First name';

  @override
  String get authSignupFirstNameHint => 'Alex';

  @override
  String get authSignupLastName => 'Last name';

  @override
  String get authSignupLastNameHint => 'Smith';

  @override
  String get authSignupEmail => 'Email';

  @override
  String get authSignupEmailHint => 'you@example.com';

  @override
  String get authSignupPassword => 'Password';

  @override
  String get authSignupPasswordHint => 'At least 6 characters';

  @override
  String get authSignupCreateAccount => 'Create account';

  @override
  String get authSignupCreatingAccount => 'Creating account…';

  @override
  String get authSignupHaveAccount => 'Have an account?';

  @override
  String get authSignupSignInLink => 'Sign in';

  @override
  String get authSignupFillAllFields => 'Fill out all fields.';

  @override
  String get authSignupPasswordMinLength =>
      'Password must be at least 6 characters.';

  @override
  String get authSignupJoinTitle => 'Join household';

  @override
  String get authSignupAccountCreated => 'Account created. Welcome!';

  @override
  String get authSignupNameRequired => 'Name is required.';

  @override
  String get authSignupEmailRequired => 'Email is required.';

  @override
  String get authSignupPasswordRequired => 'Password is required.';

  @override
  String get authSignupGenericError =>
      'Couldn\'t create account. Check your connection and try again.';

  @override
  String get authSignupNameHint => 'Your name';

  @override
  String get authSignupTermsPrefix =>
      'By creating an account, you agree to our ';

  @override
  String get authSignupAnd => ' and ';

  @override
  String get authSignupPeriod => '.';

  @override
  String get authSignupPrivacyPolicy => 'Privacy Policy';

  @override
  String get authSignupTermsP1 =>
      'Use mitlist responsibly. Shared household content is visible to the members of that household.';

  @override
  String get authSignupTermsP2 =>
      'Do not upload unlawful content, impersonate others, or abuse the service. Accounts and shared data may be removed for misuse.';

  @override
  String get authSignupTermsP3 =>
      'The app is provided as-is while the product is still evolving. Keep your own backups for anything critical.';

  @override
  String get authSignupPrivacyP1 =>
      'mitlist stores the account details and household content needed to operate the app.';

  @override
  String get authSignupPrivacyP2 =>
      'Shared data such as lists, chores, expenses, and recipes is visible to other members of the same household.';

  @override
  String get authSignupPrivacyP3 =>
      'Only provide information you are comfortable keeping in a shared household workspace.';

  @override
  String get authJoinTitle => 'Join household';

  @override
  String authJoinInvitedBy(String name) {
    return '$name invited you';
  }

  @override
  String get authJoinJoinNow => 'Join now';

  @override
  String get authJoinSignInToJoin => 'Sign in to join';

  @override
  String get authJoinCreateToJoin => 'Create account to join';

  @override
  String get authJoinGuestWarning => 'Guest accounts can\'t join households.';

  @override
  String get authJoinCouldNotLoad => 'Couldn\'t load invite details.';

  @override
  String get authJoinJoining => 'Joining…';

  @override
  String get authJoinNotNow => 'Not now';

  @override
  String get authJoinYoureIn => 'You\'re in.';

  @override
  String get authJoinGoToHousehold => 'Go to household';

  @override
  String authJoinInviteCodeSemantic(String code) {
    return 'Invite code: $code';
  }

  @override
  String authJoinErrorWithHint(String error) {
    return '$error\n\nYou can also enter a code from the household switcher.';
  }

  @override
  String get authOnboardingTitle => 'Welcome';

  @override
  String get authOnboardingSetupHome => 'Set up your home';

  @override
  String get authOnboardingCreateOrJoin =>
      'Create or join a household to start sharing with flatmates.';

  @override
  String get authOnboardingCreateHousehold => 'Create a household';

  @override
  String get authOnboardingJoinInvite => 'Join with invite code';

  @override
  String get authOnboardingHaveCode => 'Have an invite code?';

  @override
  String get authOnboardingCreateDesc =>
      'Start fresh: name it, invite flatmates, share everything in one place.';

  @override
  String get authOnboardingJoinDesc =>
      'Already got an invite? Enter the code to jump right in.';

  @override
  String get authOnboardingJoinSemantic => 'Join a household with invite code';

  @override
  String get authOnboardingHomeIconSemantic => 'Household home icon';

  @override
  String get hubStatsChores => 'Chores';

  @override
  String get hubStatsDue => 'due';

  @override
  String get hubStatsMeals => 'Meals';

  @override
  String get hubStatsPlanned => 'planned';

  @override
  String get hubStatsOverdue => 'overdue';

  @override
  String get hubStatsAllDone => 'all done';

  @override
  String get hubStatsBalance => 'Balance';

  @override
  String get hubStatsOpen => 'open';

  @override
  String get hubStatsLists => 'Lists';

  @override
  String get hubStatsActiveList => 'active list';

  @override
  String get hubStatsActiveLists => 'active lists';

  @override
  String get hubStatsReminders => 'Reminders';

  @override
  String get hubStatsPinwallReminder => 'pinwall reminder';

  @override
  String get hubStatsPinwallReminders => 'pinwall reminders';

  @override
  String get hubQuickAddTitle => 'Quick add';

  @override
  String get hubQuickAddChore => 'Add chore';

  @override
  String get hubQuickAddExpense => 'Add expense';

  @override
  String get hubQuickAddNote => 'Pin a note';

  @override
  String get hubQuickAddList => 'New list';

  @override
  String get hubActivityTitle => 'Activity';

  @override
  String get hubActivityEmpty =>
      'Nothing happening yet.\nActivity from your household will appear here.';

  @override
  String get hubActivityError =>
      'Couldn’t load activity. Pull to refresh on the hub.';

  @override
  String get hubOnboardingSwap => 'Swap';

  @override
  String get hubOnboardingSettle => 'Settle';

  @override
  String get hubOnboardingDone => 'All done';

  @override
  String get hubOnboardingSwapDesc =>
      'Pick a flatmate who owes the least to take over this chore.';

  @override
  String get hubOnboardingSettleDesc =>
      'Pay everyone back all at once with suggested settlements.';

  @override
  String get hubOnboardingDoneDesc =>
      'Chores, balances, lists — everything in one place, accounted for.';

  @override
  String get appBottomSheetHandle => 'Handle';

  @override
  String get appBottomSheetClose => 'Close';

  @override
  String get storePickerTitle => 'Choose store';

  @override
  String get storePickerSearchLabel => 'Search stores';

  @override
  String get storePickerSearchHint => 'Name...';

  @override
  String get storePickerNoMatch => 'No stores match your search.';

  @override
  String get storePickerNoStore => 'No store';

  @override
  String get storePickerNoStoreDesc =>
      'Sort by category instead of a store layout';

  @override
  String get storePickerLoadError => 'Couldn’t load stores.';

  @override
  String get smartCaptureLaunchTitle => 'Check photo';

  @override
  String get hubQuickAddToList => 'Add to a list';

  @override
  String get hubQuickAddShoppingTrip => 'Start shopping trip';

  @override
  String get hubOnboardingGetStarted => 'Get started';

  @override
  String get hubOnboardingDismiss => 'Dismiss quick start';

  @override
  String get hubOnboardingDescription =>
      'Everything starts here. Pick what matters most.';

  @override
  String get hubOnboardingInvite => 'Invite flatmates';

  @override
  String get hubOnboardingCreateList => 'Create a list';

  @override
  String get hubOnboardingAddChore => 'Add a chore';

  @override
  String get hubOnboardingTrackExpense => 'Track an expense';

  @override
  String get appBottomSheetDiscardTitle => 'Discard changes?';

  @override
  String get appBottomSheetDiscardBody => 'You have unsaved changes.';

  @override
  String get appBottomSheetKeepEditing => 'Keep editing';

  @override
  String get sheetExpenseDetailTitle => 'Expense details';

  @override
  String get sheetExpenseDetailSplits => 'Splits';

  @override
  String sheetExpenseDetailSplitsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count splits',
      one: '$count split',
    );
    return '$_temp0';
  }

  @override
  String get sheetSettlementTitle => 'Record settlement';

  @override
  String get sheetSettlementFrom => 'From';

  @override
  String get sheetSettlementTo => 'To';

  @override
  String get sheetSettlementRecordPayment =>
      'Record this settlement after the payment is made.';

  @override
  String get sheetSettlementConfirm => 'Confirm settlement';

  @override
  String get sheetGroupSettingsTitle => 'Household settings';

  @override
  String get sheetGroupSettingsName => 'Household name';

  @override
  String get sheetGroupSettingsSaved => 'Settings saved';

  @override
  String get sheetGroupSettingsCouldNotSave => 'Couldn\'t save settings.';

  @override
  String get sheetGroupSettingsLeave => 'Leave household';

  @override
  String get sheetGroupSettingsLeaveConfirm =>
      'Are you sure you want to leave this household? All your data will be retained by the household.';

  @override
  String get sheetGroupSettingsLeaveAction => 'Leave';

  @override
  String get sheetGroupSettingsDelete => 'Delete household';

  @override
  String get sheetGroupSettingsDeleteConfirm =>
      'This will permanently delete this household and all associated data. This cannot be undone.';

  @override
  String get sheetRecipeAddToListTitle => 'Add to list';

  @override
  String sheetRecipeAddToListAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items added',
      one: '1 item added',
    );
    return '$_temp0';
  }

  @override
  String get sheetRecipeAddToListCouldNotAdd => 'Couldn\'t add ingredients.';

  @override
  String get sheetJoinTitle => 'Join household';

  @override
  String get sheetJoinCodeLabel => 'Invite code';

  @override
  String get sheetJoinCodeHint => 'Paste invite code';

  @override
  String get sheetJoinJoin => 'Join';

  @override
  String get sheetCreateHouseholdTitle => 'Create household';

  @override
  String get sheetCreateHouseholdName => 'Household name';

  @override
  String get sheetCreateHouseholdNameHint => 'e.g. Flat 4B';

  @override
  String get sheetInviteTitle => 'Invite to household';

  @override
  String get sheetInviteCopy => 'Copy link';

  @override
  String get sheetInviteCopied => 'Invite link copied';

  @override
  String get sheetInviteShare => 'Share link';

  @override
  String get sheetCreateListTitle => 'New list';

  @override
  String get sheetCreateListName => 'List name';

  @override
  String get sheetCreateListNameHint => 'e.g. Weekly groceries';

  @override
  String get sheetCreateListType => 'Type';

  @override
  String get sheetCreateListTypeShopping => 'Shopping';

  @override
  String get sheetCreateListTypeTodo => 'To-do';

  @override
  String get sheetCreateListTypeCustom => 'Custom';

  @override
  String get sheetCreateListCreate => 'Create list';

  @override
  String get sheetCostSummaryTitle => 'Cost summary';

  @override
  String get sheetCostSummaryTotal => 'Total';

  @override
  String get sheetConflictTitle => 'Sync conflict';

  @override
  String get sheetConflictDescription =>
      'This item was changed on another device while you were editing. Choose which version to keep.';

  @override
  String get sheetConflictLocal => 'Your version';

  @override
  String get sheetConflictServer => 'Server version';

  @override
  String get sheetConflictKeepLocal => 'Keep yours';

  @override
  String get sheetConflictKeepServer => 'Keep server';

  @override
  String get sheetFailedChangesTitle => 'Failed changes';

  @override
  String get sheetFailedChangesDescription =>
      'These changes couldn\'t be saved. You can retry or discard them.';

  @override
  String get sheetFailedChangesRetryAll => 'Retry all';

  @override
  String get sheetFailedChangesDiscardAll => 'Discard all';

  @override
  String get sheetFailedChangesDiscard => 'Discard';

  @override
  String get sheetFailedChangesRetry => 'Retry';

  @override
  String get sheetFailedChangesEmpty =>
      'No failed changes. Everything is synced or waiting to retry.';

  @override
  String get sheetFailedChangesOpAddItem => 'Add item';

  @override
  String get sheetFailedChangesOpUpdateItem => 'Update item';

  @override
  String get sheetFailedChangesOpDeleteItem => 'Delete item';

  @override
  String get sheetFailedChangesOpReorderItems => 'Reorder list';

  @override
  String get sheetFailedChangesOpCreateExpense => 'Add expense';

  @override
  String get sheetFailedChangesOpUpdateExpense => 'Update expense';

  @override
  String get sheetFailedChangesOpDeleteExpense => 'Delete expense';

  @override
  String get sheetFailedChangesOpCreateRecipe => 'Add recipe';

  @override
  String get sheetFailedChangesOpUpdateRecipe => 'Update recipe';

  @override
  String get sheetFailedChangesOpDeleteRecipe => 'Delete recipe';

  @override
  String get sheetFailedChangesOpCompleteChore => 'Complete chore';

  @override
  String get sheetFailedChangesOpSkipChore => 'Skip chore';

  @override
  String get sheetFailedChangesOpRescheduleChore => 'Reschedule chore';

  @override
  String get sheetFailedChangesOpUndoChore => 'Undo chore';

  @override
  String get sheetFailedChangesOpCreatePinwallPost => 'Post to pinwall';

  @override
  String get sheetFailedChangesOpDeletePinwallPost => 'Delete pinwall post';

  @override
  String get sheetFailedChangesOpChange => 'Change';

  @override
  String get sheetGroupSettingsChoreZonesUpdated => 'Chore zones updated';

  @override
  String get sheetGroupSettingsRemoveMember => 'Remove member';

  @override
  String sheetGroupSettingsRemoveMemberConfirm(String name) {
    return 'Remove $name from this household?';
  }

  @override
  String sheetGroupSettingsMemberRemoved(String name) {
    return '$name removed';
  }

  @override
  String get sheetGroupSettingsHouseholdDeleted => 'Household deleted';

  @override
  String get sheetGroupSettingsDescriptionHint =>
      'A few words about this household';

  @override
  String get sheetGroupSettingsChoreZonesLabel => 'Chore zones';

  @override
  String get sheetGroupSettingsChoreZonesDesc =>
      'Areas of your home for grouping chores. They show up when adding a chore.';

  @override
  String get sheetGroupSettingsAddZone => 'Add zone';

  @override
  String get sheetGroupSettingsZoneHint => 'Kitchen, Bathroom…';

  @override
  String get sheetGroupSettingsSaveZones => 'Save zones';

  @override
  String get sheetGroupSettingsMembersLabel => 'Members';

  @override
  String get sheetGroupSettingsInvite => 'Invite';

  @override
  String sheetGroupSettingsRemoveMemberTooltip(String name) {
    return 'Remove $name';
  }

  @override
  String get tonightRecipe => 'Recipe';

  @override
  String get tonightHeader => 'Tonight';

  @override
  String get tonightCook => 'Cook';

  @override
  String get tonightNothingPlanned => 'Nothing planned for tonight';

  @override
  String get tonightPlanDinner => 'Plan dinner';

  @override
  String activityAddedToList(String name, String when) {
    return 'Added $name to a list · $when';
  }

  @override
  String activityAddedItemToList(String when) {
    return 'Added an item to a list · $when';
  }

  @override
  String activityLoggedExpense(String name, String when) {
    return 'Logged $name · $when';
  }

  @override
  String activityLoggedExpenseGeneric(String when) {
    return 'Logged an expense · $when';
  }

  @override
  String activityCompletedChore(String name, String when) {
    return 'Completed $name · $when';
  }

  @override
  String activityCompletedChoreGeneric(String when) {
    return 'Completed a chore · $when';
  }

  @override
  String activitySavedRecipe(String name, String when) {
    return 'Saved $name · $when';
  }

  @override
  String activitySavedRecipeGeneric(String when) {
    return 'Saved a recipe · $when';
  }

  @override
  String activityPlannedMeal(String name, String when) {
    return 'Planned $name · $when';
  }

  @override
  String activityUpdatedMealPlan(String when) {
    return 'Updated meal plan · $when';
  }

  @override
  String get activityYou => 'You';

  @override
  String get activityMember => 'Member';

  @override
  String inviteLinkShareText(String link, String code) {
    return 'Join my household on mitlist!\nTap: $link\nOr open mitlist and enter the code: $code';
  }

  @override
  String get errorBoundaryTitle => 'Something went wrong';

  @override
  String get errorBoundaryDesc =>
      'We hit an unexpected error. Please try again.';

  @override
  String get recurringTomorrow => 'Tomorrow';

  @override
  String get recurringCouldNotUpdate => 'Couldn\'t update recurring expense.';

  @override
  String get recurringCouldNotDelete => 'Couldn\'t delete recurring expense.';

  @override
  String get recurringCouldNotCreate => 'Couldn\'t create recurring expense.';

  @override
  String get recipeAddToListNoLists => 'No lists';

  @override
  String get recipeAddToListCreateListFirst =>
      'Create a list first to add ingredients';

  @override
  String get costSummaryNoPrices =>
      'No items have prices yet. Open the item options (⋯) and choose Set price to see the cost summary.';

  @override
  String get costSummaryNotAvailable => 'N/A';

  @override
  String get costSummaryEqualShare => 'Equal share per person';

  @override
  String get costSummaryItemsWithPrices => 'Items with prices';

  @override
  String get costSummaryNone => 'None';

  @override
  String get costSummaryGenerateExpense => 'Generate expense';

  @override
  String get createListScanFinished => 'Scan finished';

  @override
  String createListScanned(String name) {
    return 'Scanned \"$name\"';
  }

  @override
  String get createListShoppingDesc =>
      'Best for groceries and errands with quantities.';

  @override
  String get createListNameRequired => 'List name is required';

  @override
  String get createListCreated => 'List created';

  @override
  String get recipeCreationScanRecipe => 'Scan recipe';

  @override
  String get recipeCreationScanRecipeViaCamera => 'Scan recipe via camera';

  @override
  String get joinCodeFormatHint =>
      'Codes look like WORD-WORD-42. Ask whoever invited you.';

  @override
  String joinEnterGroup(String name) {
    return 'Enter $name';
  }

  @override
  String inviteCodeLabel(String code) {
    return 'Invite code: $code';
  }

  @override
  String get inviteQrTitle => 'Household invite QR code';

  @override
  String get inviteQrSemantic => 'Household invite QR';

  @override
  String get inviteQrHint =>
      'Scan with a phone camera to join, or share the code below.';

  @override
  String get inviteGenerating => 'Generating…';

  @override
  String get inviteNewCode => 'New code';

  @override
  String get createHouseholdCreated => 'Household created';

  @override
  String get createHouseholdDescriptionOptional => 'Description (optional)';

  @override
  String get conflictNoneToResolve => 'No conflicts to resolve.';

  @override
  String get conflictItemChanged => 'Item changed';

  @override
  String conflictItemLabel(String name) {
    return 'Item: $name';
  }

  @override
  String get scannerCouldNotAnalyze =>
      'Couldn\'t analyze the image. Please try again with a clearer photo.';

  @override
  String get oauthMissingParams => 'Missing OAuth callback parameters.';

  @override
  String get oauthSigningYouIn => 'Signing you in';

  @override
  String get expenseCreationSharesNegative => 'Shares can\'t be negative.';

  @override
  String get expenseCreationAssignShare => 'Assign at least one share.';

  @override
  String get expenseCreationCouldNotLoadMembers =>
      'Couldn\'t load household members.';

  @override
  String get expenseCreationJoinHouseholdSplit =>
      'Join or create a household to split this expense.';

  @override
  String expenseCreationRemoveAddSplitter(String name) {
    return 'Remove/Add $name from/to split';
  }

  @override
  String get expenseDetailFailedLoadReceipt => 'Failed to load receipt';

  @override
  String get expenseDetailReceipt => 'Receipt';

  @override
  String get expenseDetailView => 'View';

  @override
  String get expenseDetailNotSplitYet => 'This expense isn\'t split yet.';

  @override
  String get expenseDetailNoReceipts =>
      'No receipts attached. Add one when editing the expense.';

  @override
  String pinwallLinkedTo(String entity) {
    return 'Linked to $entity';
  }

  @override
  String get commonView => 'View';

  @override
  String get commonPhoto => 'Photo';

  @override
  String cookModeTimerStart(String label) {
    return 'Timer: $label. Tap to start';
  }

  @override
  String get errorServerHiccup => 'Server hiccup — try again in a moment.';

  @override
  String get errorConflict =>
      'Someone else changed this. Refresh and try again.';

  @override
  String get errorNotFound => 'Not found. It may have been deleted.';

  @override
  String get errorNoPermission => 'You don\'t have permission for this.';

  @override
  String get errorSignInAgain => 'Please sign in again.';

  @override
  String get errorGenericRetry => 'Something went wrong. Please try again.';

  @override
  String get createListTodoDesc =>
      'A simple checklist for tasks that need doing.';

  @override
  String get createListCustomDesc =>
      'A flexible list for anything that does not fit.';

  @override
  String get createListScanSemantics => 'Scan list via camera';

  @override
  String get createListHouseholdLabel => 'Household';

  @override
  String get createListNoHousehold => 'No household available.';

  @override
  String get sheetJoinCodeExample => 'SUNNY-TACO-42';

  @override
  String joinMembersAlreadyInside(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members already inside',
      one: '1 member already inside',
    );
    return '$_temp0';
  }

  @override
  String get inviteQrUnavailable => 'QR unavailable';

  @override
  String expenseCreationSplitAssignedOf(String assigned, String total) {
    return '$assigned of $total';
  }

  @override
  String expenseCreationSplitAmountsNegative(String assigned) {
    return '$assigned · amounts can\'t be negative';
  }

  @override
  String expenseCreationSplitLeftToAssign(String assigned, String remaining) {
    return '$assigned · $remaining left to assign';
  }

  @override
  String expenseCreationSplitOver(String assigned, String over) {
    return '$assigned · $over over';
  }

  @override
  String expenseCreationSplitPercentRange(String sum) {
    return '$sum% assigned · each share must be 0–100%';
  }

  @override
  String expenseCreationSplitPercentOf100(String sum) {
    return '$sum% of 100%';
  }

  @override
  String expenseCreationSplitSharesPerShare(num count, String perShare) {
    return '$count shares · $perShare per share';
  }

  @override
  String expenseCreationSplitEach(String amount) {
    return '$amount each';
  }

  @override
  String expenseCreationSplitApproxEach(String amount) {
    return '≈ $amount each';
  }

  @override
  String expenseCreationRemoveFromSplit(String name) {
    return 'Remove $name from split';
  }

  @override
  String expenseCreationAddToSplit(String name) {
    return 'Add $name to split';
  }

  @override
  String get expenseDetailCouldNotLoadSplits => 'Couldn\'t load splits.';

  @override
  String get expenseDetailCouldNotLoadReceipts => 'Couldn\'t load receipts.';

  @override
  String get expenseDetailCouldNotRemoveReceipt => 'Couldn\'t remove receipt.';

  @override
  String get expenseDetailRemoving => 'Removing…';

  @override
  String get recipeAddToListTargetList => 'Target list';

  @override
  String get recipeAddToListNoIngredients => 'No ingredients';

  @override
  String get recipeAddToListNoIngredientsDesc =>
      'This recipe has no parsed ingredients';

  @override
  String recipeAddToListRemoveFromSelection(String name) {
    return 'Remove $name from selection';
  }

  @override
  String recipeAddToListAddToSelection(String name) {
    return 'Add $name to selection';
  }

  @override
  String get pinwallLinkChore => 'A chore';

  @override
  String get pinwallLinkList => 'A list';

  @override
  String get pinwallCouldNotLoad => 'Couldn\'t load the pinwall.';

  @override
  String get composerItemHint => 'e.g. Milk, 2 avocados, or 500g flour';

  @override
  String get aisleOther => 'Other';

  @override
  String hubHouseholdsCurrent(String name) {
    return 'Households, current $name';
  }

  @override
  String recipeDetailStepCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps',
      one: '1 step',
    );
    return '$_temp0';
  }

  @override
  String get currencyUsd => 'USD - US Dollar';

  @override
  String get currencyEur => 'EUR - Euro';

  @override
  String get currencyGbp => 'GBP - British Pound';

  @override
  String get currencyJpy => 'JPY - Japanese Yen';

  @override
  String get currencyCad => 'CAD - Canadian Dollar';

  @override
  String get currencyAud => 'AUD - Australian Dollar';

  @override
  String get currencyChf => 'CHF - Swiss Franc';

  @override
  String get currencySek => 'SEK - Swedish Krona';

  @override
  String get currencyNok => 'NOK - Norwegian Krone';

  @override
  String get currencyDkk => 'DKK - Danish Krone';

  @override
  String get currencyPln => 'PLN - Polish Zloty';

  @override
  String get currencyCzk => 'CZK - Czech Koruna';

  @override
  String get currencyHuf => 'HUF - Hungarian Forint';
}
