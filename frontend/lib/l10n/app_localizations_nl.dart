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
  String get integrationsTitle => 'Integrations';

  @override
  String get homeAssistantTitle => 'Home Assistant';

  @override
  String get homeAssistantDescription =>
      'Connect your household to dashboards, voice control, and automations.';

  @override
  String get homeAssistantConnections => 'Connections';

  @override
  String get homeAssistantNoConnections => 'No Home Assistant connections yet.';

  @override
  String get homeAssistantCreateConnection => 'Create connection';

  @override
  String get homeAssistantConnectionName => 'Connection name';

  @override
  String get homeAssistantConnectionNameHint => 'Home Assistant';

  @override
  String get homeAssistantHouseholds => 'Households';

  @override
  String get homeAssistantPermissions => 'Permissions';

  @override
  String get homeAssistantWriteAccess => 'Allow Home Assistant to make changes';

  @override
  String get homeAssistantFinanceAccess => 'Include financial data';

  @override
  String get homeAssistantTokenTitle => 'Connection token';

  @override
  String get homeAssistantTokenBody =>
      'Copy this token into Home Assistant now. For security, mitlist cannot show it again.';

  @override
  String get homeAssistantTokenCopied => 'Connection token copied';

  @override
  String get homeAssistantRevoke => 'Revoke connection';

  @override
  String get homeAssistantRevokeConfirm =>
      'This immediately disconnects Home Assistant. You can create a new connection later.';

  @override
  String get homeAssistantRevoked => 'Revoked';

  @override
  String get homeAssistantNeverUsed => 'Never used';

  @override
  String homeAssistantLastUsed(String date) {
    return 'Last used $date';
  }

  @override
  String get homeAssistantSelectHousehold => 'Select at least one household.';

  @override
  String get homeAssistantCreated => 'Home Assistant connection created';

  @override
  String get homeAssistantRevokedSuccess => 'Home Assistant connection revoked';

  @override
  String get homeAssistantLoadFailed =>
      'Could not load Home Assistant connections.';

  @override
  String get homeAssistantSaveFailed =>
      'Could not create the connection. Please try again.';

  @override
  String get homeAssistantReadOnly => 'Read only';

  @override
  String get homeAssistantReadWrite => 'Read and write';

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
  String get welcomeInviteHeadline => 'Je bent uitgenodigd';

  @override
  String get welcomeInviteSubtitle =>
      'Word lid van het huishouden om lijsten, taken en kosten te delen.';

  @override
  String get welcomeGuestFootnote =>
      'Geen registratie nodig. Maak later een account aan om je gegevens te bewaren.';

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
  String get choreManageZones => 'Zones beheren';

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
  String get choreDoneRecently => 'Done recently';

  @override
  String get choreLedgerYou => 'You';

  @override
  String get choreLedgerSomeone => 'Someone';

  @override
  String choreLedgerDoneBy(String who, String when) {
    return '$who · $when';
  }

  @override
  String get choreLedgerJustNow => 'just now';

  @override
  String choreLedgerHoursAgo(int count) {
    return '${count}h ago';
  }

  @override
  String get choreLedgerYesterday => 'yesterday';

  @override
  String choreBackOnDate(String date) {
    return 'back $date';
  }

  @override
  String get choreUpForGrabs => 'Up for grabs';

  @override
  String choreDoneBackSnackbar(String choreTitle, String date) {
    return '$choreTitle done — back $date';
  }

  @override
  String get choreWhoEveryone => 'Everyone';

  @override
  String get choreWhoNoOne => 'No one';

  @override
  String choreWhoAlways(String name) {
    return 'Always $name';
  }

  @override
  String choreWhoAmongSelected(int count) {
    return 'Rotates between the $count people you picked.';
  }

  @override
  String get choreWhoOrderLabel => 'Order';

  @override
  String get choreDetailRhythm => 'Repeats';

  @override
  String choreLoadSummary(num count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count chores',
      one: '1 chore',
    );
    return '$_temp0 done in the last $days days';
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
  String choreSomeonesTurn(String name) {
    return '$name is aan de beurt';
  }

  @override
  String get choreRefreshFailed =>
      'Vernieuwen mislukt. Opgeslagen taken worden getoond.';

  @override
  String choreDoneLast30Days(num count) {
    return '$count gedaan, afgelopen 30 dagen';
  }

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
  String get choreHouseAllClear => 'Niets achterstallig in huis';

  @override
  String choreHouseOverdue(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count taken achterstallig in huis',
      one: '1 taak achterstallig in huis',
    );
    return '$_temp0';
  }

  @override
  String choreNextInRotation(String name) {
    return 'daarna $name';
  }

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
  String get choreEditTitle => 'Klus bewerken';

  @override
  String get choreEditSaved => 'Klus bijgewerkt';

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
  String get choreCreationZoneNone => 'Geen zone';

  @override
  String get choreCreationZoneManageHint =>
      'Houd een zone ingedrukt om hem te verwijderen';

  @override
  String get choreCreationRemoveZoneTitle => 'Zone verwijderen?';

  @override
  String choreCreationRemoveZoneBody(String zone) {
    return '$zone wordt niet meer aangeboden bij het toevoegen van een taak. Taken die hem al gebruiken behouden hem.';
  }

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
  String get choreCreationAssignLabel => 'Wie';

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
  String get choreDetailAssignee => 'Wie is aan de beurt';

  @override
  String get choreDetailNextUp => 'Daarna';

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
  String get recipeNoMatchTitle => 'Geen recepten komen overeen';

  @override
  String get recipeNoMatchDesc => 'Probeer een andere zoekopdracht of filter.';

  @override
  String get recipeShowAllRecipes => 'Alle recepten tonen';

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
  String get recipeAddOnlyMissing => 'Alleen wat ontbreekt toevoegen';

  @override
  String recipeAddMissingAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ontbrekende items toegevoegd',
      one: '1 ontbrekend item toegevoegd',
      zero: 'Niets ontbreekt — helemaal compleet',
    );
    return '$_temp0';
  }

  @override
  String get productsTitle => 'Producten';

  @override
  String get productsSearchHint => 'Producten zoeken';

  @override
  String get productsEmptyTitle => 'Nog geen producten';

  @override
  String get productsEmptyDesc =>
      'Bewaar producten die je vaak koopt om ze in al je lijsten te hergebruiken.';

  @override
  String get productsNoResults =>
      'Geen producten komen overeen met je zoekopdracht';

  @override
  String get productsAdd => 'Product toevoegen';

  @override
  String get productsSheetTitle => 'Nieuw product';

  @override
  String get productsFieldName => 'Naam';

  @override
  String get productsFieldUnit => 'Eenheid (optioneel)';

  @override
  String get productsFieldBarcode => 'Barcode (optioneel)';

  @override
  String get productsValidationName => 'Voer een productnaam in';

  @override
  String get productsCouldNotCreate => 'Kon product niet aanmaken';

  @override
  String get productsNoHouseholdDesc =>
      'Word lid van een huishouden of maak er een om een productcatalogus bij te houden.';

  @override
  String get shoppingLocationsTitle => 'Winkellocaties';

  @override
  String get shoppingLocationsEmptyTitle => 'Nog geen locaties';

  @override
  String get shoppingLocationsEmptyDesc =>
      'Benoem de winkels waar je boodschappen doet om je uitjes te organiseren.';

  @override
  String get shoppingLocationsAdd => 'Locatie toevoegen';

  @override
  String get shoppingLocationsSheetTitle => 'Nieuwe locatie';

  @override
  String get shoppingLocationsFieldName => 'Naam';

  @override
  String get shoppingLocationsValidationName => 'Voer een locatienaam in';

  @override
  String get shoppingLocationsCouldNotCreate => 'Kon locatie niet aanmaken';

  @override
  String get shoppingLocationsNoHouseholdDesc =>
      'Word lid van een huishouden of maak er een om winkellocaties op te slaan.';

  @override
  String get cookbooksTitle => 'Kookboeken';

  @override
  String get cookbooksButton => 'Kookboeken';

  @override
  String get cookbooksEmptyTitle => 'Nog geen kookboeken';

  @override
  String get cookbooksEmptyDesc =>
      'Groepeer je recepten in kookboeken om ze sneller terug te vinden.';

  @override
  String get cookbooksAdd => 'Nieuw kookboek';

  @override
  String get cookbooksSheetTitle => 'Nieuw kookboek';

  @override
  String get cookbooksRenameSheetTitle => 'Kookboek hernoemen';

  @override
  String get cookbooksFieldName => 'Naam';

  @override
  String get cookbooksValidationName => 'Voer een kookboeknaam in';

  @override
  String get cookbooksCouldNotCreate => 'Kon kookboek niet aanmaken';

  @override
  String get cookbooksCouldNotRename => 'Kon kookboek niet hernoemen';

  @override
  String get cookbooksCouldNotDelete => 'Kon kookboek niet verwijderen';

  @override
  String get cookbooksDeleteTitle => 'Kookboek verwijderen?';

  @override
  String get cookbooksDeleteBody =>
      'Dit verwijdert het kookboek. Je recepten blijven in je keuken.';

  @override
  String cookbooksRecipeCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recepten',
      one: '1 recept',
      zero: 'Geen recepten',
    );
    return '$_temp0';
  }

  @override
  String get cookbooksRename => 'Hernoemen';

  @override
  String get cookbooksNoHouseholdDesc =>
      'Word lid van een huishouden of maak er een om kookboeken samen te stellen.';

  @override
  String get cookbookDetailEmptyTitle => 'Hier nog geen recepten';

  @override
  String get cookbookDetailEmptyDesc =>
      'Voeg recepten toe aan dit kookboek om ze hier te zien.';

  @override
  String get cookbookDetailAddRecipes => 'Recepten toevoegen';

  @override
  String get cookbookAddRecipesSheetTitle => 'Recepten toevoegen';

  @override
  String get cookbookAddRecipesEmpty =>
      'Al je recepten staan al in dit kookboek.';

  @override
  String get cookbookRemoveRecipe => 'Uit kookboek verwijderen';

  @override
  String get cookbookRecipeRemoved => 'Uit kookboek verwijderd';

  @override
  String cookbookRecipesAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recepten toegevoegd',
      one: '1 recept toegevoegd',
    );
    return '$_temp0';
  }

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
  String recipeCreationSharedWithGroups(String names) {
    return 'Gedeeld met $names';
  }

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
  String get expenseSettlementRecorded =>
      'Vereffening vastgelegd – wacht op bevestiging';

  @override
  String get expenseSettlementFailed => 'Kon vereffening niet vastleggen.';

  @override
  String get expenseSettlementNeedsYou => 'Wacht op jouw bevestiging';

  @override
  String get expenseSettlementWaiting => 'Wacht op bevestiging';

  @override
  String get expenseSettlementHistory => 'Recente vereffeningen';

  @override
  String expenseSettlementRow(String from, String to) {
    return '$from heeft $to betaald';
  }

  @override
  String get expenseSettlementConfirmAction => 'Bevestigen';

  @override
  String get expenseSettlementDeclineAction => 'Afwijzen';

  @override
  String get expenseSettlementCancelAction => 'Verzoek intrekken';

  @override
  String get expenseSettlementStatusConfirmed => 'Bevestigd';

  @override
  String get expenseSettlementStatusDeclined => 'Afgewezen';

  @override
  String get expenseSettlementResponseFailed =>
      'Vereffening kon niet worden bijgewerkt.';

  @override
  String get expenseSettlementCancelFailed =>
      'Vereffening kon niet worden ingetrokken.';

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
  String listSharedWith(String name) {
    return 'Gedeeld met $name';
  }

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
  String calendarDayEvents(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count afspraken',
      one: '1 afspraak',
    );
    return '$_temp0';
  }

  @override
  String get calendarDayMenuHint => 'Opent dagopties';

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
      'Nieuw wachtwoord moet minstens 8 tekens bevatten.';

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
  String get accountOpenDataRow => 'Open data';

  @override
  String get accountSupportRow => 'Steun mitlist';

  @override
  String get accountServerRow => 'Server';

  @override
  String get accountOpenDataTitle => 'Open data-bronvermelding';

  @override
  String get accountOpenDataBody =>
      'Sommige merknamen van levensmiddelen komen van Open Food Facts (openfoodfacts.org), gebruikt onder de Open Database License (ODbL) v1.0. De afgeleide merkenlijst wordt los van mitlists eigen gegevens gehouden.';

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
  String get accountExportCalendar => 'Export calendar (.ics)';

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
  String get notificationsSectionToday => 'Vandaag';

  @override
  String get notificationsSectionYesterday => 'Gisteren';

  @override
  String get notificationsSectionEarlier => 'Eerder';

  @override
  String get notificationsTimeNow => 'nu';

  @override
  String notificationsTimeMinutes(int minutes) {
    return '$minutes m';
  }

  @override
  String notificationsTimeHours(int hours) {
    return '$hours u';
  }

  @override
  String notificationsTimeDays(int days) {
    return '$days d';
  }

  @override
  String notificationsUnreadCount(int count) {
    return '$count nieuw';
  }

  @override
  String get notifPrefAppBarTitle => 'Notificatievoorkeuren';

  @override
  String get notifPrefFailedLoad => 'Notificatievoorkeuren laden mislukt.';

  @override
  String get notifPrefFailedSave =>
      'Kan deze voorkeur niet opslaan. Controleer je verbinding en probeer het opnieuw.';

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
  String get notifPrefExpenseCreated => 'Geldactiviteit';

  @override
  String get notifPrefExpenseCreatedDesc =>
      'Uitgaven, terugkerende kosten en verrekeningen';

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
  String get notifPrefEmailNotifications => 'E-mailmeldingen';

  @override
  String get notifPrefEmailNotificationsDesc =>
      'Belangrijke herinneringen per e-mail ontvangen';

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
  String scanReviewBestGuess(String name) {
    return 'Beste gok: $name';
  }

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
  String get expenseCreationCategoryLabel => 'Category';

  @override
  String get expenseCreationDatePrefix => 'Datum';

  @override
  String get expenseCategoryGroceries => 'Groceries';

  @override
  String get expenseCategoryDining => 'Dining';

  @override
  String get expenseCategoryTransport => 'Transport';

  @override
  String get expenseCategoryUtilities => 'Utilities';

  @override
  String get expenseCategoryHousehold => 'Household';

  @override
  String get expenseCategoryEntertainment => 'Entertainment';

  @override
  String get expenseCategoryHealth => 'Health';

  @override
  String get expenseCategoryOther => 'Other';

  @override
  String get expenseCreationNotesHint => 'Notities (optioneel)';

  @override
  String get expenseCreationDateLabel => 'Uitgavedatum. Tik om te wijzigen.';

  @override
  String expenseCreationStartsOn(String date) {
    return 'Vanaf $date';
  }

  @override
  String get expenseCreationNextDueLabel => 'Eerste keer. Tik om te wijzigen.';

  @override
  String get expenseCreationEditRepeatSemantic =>
      'Herhaling. Tik om te wijzigen.';

  @override
  String get expenseCreationRepeatNever => 'Herhaalt niet';

  @override
  String get expenseCreationRepeatNeverOption => 'Nooit';

  @override
  String get expenseCreationRepeatDaily => 'Herhaalt dagelijks';

  @override
  String get expenseCreationRepeatWeekly => 'Herhaalt wekelijks';

  @override
  String get expenseCreationRepeatBiweekly => 'Herhaalt elke 2 weken';

  @override
  String get expenseCreationRepeatMonthly => 'Herhaalt maandelijks';

  @override
  String get expenseCreationRepeatQuarterly => 'Herhaalt per kwartaal';

  @override
  String get expenseCreationRepeatYearly => 'Herhaalt jaarlijks';

  @override
  String expenseCreationRepeatCurrencyHint(String currency) {
    return 'Terugkerende uitgaven worden vastgelegd in $currency.';
  }

  @override
  String get expenseCreationRecurringTitle => 'Nieuwe terugkerende uitgave';

  @override
  String get expenseCreationRecurringEditTitle =>
      'Terugkerende uitgave bewerken';

  @override
  String get expenseCreationRecurringAdded => 'Terugkerende uitgave toegevoegd';

  @override
  String get expenseCreationRecurringSaved => 'Terugkerende uitgave bijgewerkt';

  @override
  String get recurringEditTooltip => 'Bewerken';

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
  String expenseCreationSplitTotal(String amount) {
    return 'Totaal $amount';
  }

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
  String get expenseCreationRateAutoFilled =>
      'Koers automatisch ingevuld — je kunt het bewerken.';

  @override
  String get expenseCreationReceiptUploadFailed =>
      'Uitgave opgeslagen, maar bon-upload mislukt.';

  @override
  String get expenseCreationExpenseAdded => 'Uitgave toegevoegd';

  @override
  String expenseCreationSummaryPaidBySplit(String payer, String how) {
    return 'Betaald door $payer · $how gedeeld';
  }

  @override
  String get expenseCreationSummaryYou => 'jou';

  @override
  String get expenseCreationSplitHowEqual => 'gelijk';

  @override
  String get expenseCreationSplitHowExact => 'op exacte bedragen';

  @override
  String get expenseCreationSplitHowShares => 'op aandelen';

  @override
  String get expenseCreationSplitHowPercent => 'op percentages';

  @override
  String get expenseCreationEditSplitSemantic =>
      'Bewerken wie betaald heeft en hoe het verdeeld is';

  @override
  String get pinwallBoardLabel => 'Prikbord';

  @override
  String get pinwallSnapshot => 'In één oogopslag';

  @override
  String get pinwallDragHint =>
      'Sleep notities om te verplaatsen  ·  Knijp om te zoomen';

  @override
  String get pinwallAddNote => 'Notitie toevoegen';

  @override
  String pinwallPresenceHere(String names) {
    return '$names here now';
  }

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
  String get initialSyncRefreshing => 'Vernieuwen…';

  @override
  String get initialSyncFailed =>
      'Vernieuwen mislukt — tik om opnieuw te proberen';

  @override
  String get offlineBannerSyncing => 'Wijzigingen synchroniseren…';

  @override
  String offlineBannerFailedCount(num count) {
    return 'Kon $count wijzigingen niet synchroniseren';
  }

  @override
  String get offlineBannerFailedOne => 'Kon een wijziging niet synchroniseren';

  @override
  String offlineBannerConflictCount(int count) {
    return '$count wijzigingen vereisen uw beoordeling';
  }

  @override
  String get offlineBannerConflictOne => 'Een wijziging vereist uw beoordeling';

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
  String get listItemChangeQuantity => 'Aantal wijzigen';

  @override
  String get listItemQuantityAmount => 'Aantal';

  @override
  String get listItemQuantityUnit => 'Eenheid (optioneel)';

  @override
  String get listItemAddNote => 'Notitie toevoegen';

  @override
  String get listItemEditNote => 'Notitie bewerken';

  @override
  String get listItemNoteLabel => 'Notitie';

  @override
  String listDetailProgress(int done, int total) {
    return '$done van $total klaar';
  }

  @override
  String listOpenCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count te gaan',
      one: '1 te gaan',
      zero: 'Alles klaar',
    );
    return '$_temp0';
  }

  @override
  String get listSortListView => 'Lijstweergave';

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
  String get authLoginTitle => 'Inloggen';

  @override
  String get authLoginEmail => 'E-mail';

  @override
  String get authLoginYouExample => 'jij@voorbeeld.nl';

  @override
  String get authLoginPassword => 'Wachtwoord';

  @override
  String get authLoginYourPassword => 'Je wachtwoord';

  @override
  String get authLoginForgotPassword => 'Wachtwoord vergeten?';

  @override
  String get authLoginSignInButton => 'Inloggen';

  @override
  String get authLoginSigningIn => 'Inloggen…';

  @override
  String get authLoginNoAccount => 'Geen account?';

  @override
  String get authLoginCreateOne => 'Maak er een';

  @override
  String get authLoginFillAllFields => 'Vul alle velden in.';

  @override
  String get authLoginEmailRequired => 'E-mail is verplicht.';

  @override
  String get authLoginPasswordRequired => 'Wachtwoord is verplicht.';

  @override
  String get authLoginGenericError =>
      'Inloggen mislukt. Controleer je verbinding en probeer het opnieuw.';

  @override
  String get authLoginRememberMe => 'Onthoud mij';

  @override
  String get authLoginRememberMeOn => 'Onthoud mij: aan';

  @override
  String get authLoginRememberMeOff => 'Onthoud mij: uit';

  @override
  String get authLoginGoogle => 'Doorgaan met Google';

  @override
  String get authLoginApple => 'Doorgaan met Apple';

  @override
  String authLoginOAuthUnsupported(String provider) {
    return '$provider-inloggen is momenteel alleen beschikbaar op web, Android en iOS.';
  }

  @override
  String get authLoginResetPasswordTitle => 'Wachtwoord herstellen';

  @override
  String get authLoginSendResetCode => 'Code versturen';

  @override
  String get authLoginResetCodeLabel => 'Herstelcode';

  @override
  String get authLoginResetCodeHint => 'Plak de code uit je e-mail';

  @override
  String get authLoginResetPasswordButton => 'Wachtwoord herstellen';

  @override
  String get authServerLink => 'Kies je server';

  @override
  String get authServerSheetTitle => 'Kies je server';

  @override
  String get authServerSheetBody =>
      'mitlist is open source en zelf te hosten. Verbind de app met je eigen server, of laat dit leeg om de standaardserver te gebruiken.';

  @override
  String get authServerUrlLabel => 'Server-URL';

  @override
  String get authServerUrlHint => 'https://mitlist.example.com';

  @override
  String get authServerUrlInvalid =>
      'Voer een volledige URL in die begint met http:// of https://.';

  @override
  String get authServerUnreachable =>
      'Er antwoordde geen mitlist-server op dit adres.';

  @override
  String get authServerSave => 'Deze server gebruiken';

  @override
  String get authServerReset => 'Terug naar de standaardserver';

  @override
  String get authServerNoDefault =>
      'Deze build heeft geen standaardserver. Voer het adres van je server in om door te gaan.';

  @override
  String get authLoginResetCodeSent =>
      'Als dat e-mailadres bestaat, is er een herstelcode verstuurd.';

  @override
  String get authLoginResetFillAllFields =>
      'Vul de code en beide wachtwoordvelden in.';

  @override
  String get authLoginResetSuccess =>
      'Wachtwoord hersteld. Je kunt nu inloggen.';

  @override
  String get authSignupTitle => 'Account aanmaken';

  @override
  String get authSignupFirstName => 'Voornaam';

  @override
  String get authSignupFirstNameHint => 'Alex';

  @override
  String get authSignupLastName => 'Achternaam';

  @override
  String get authSignupLastNameHint => 'Jansen';

  @override
  String get authSignupEmail => 'E-mail';

  @override
  String get authSignupEmailHint => 'jij@voorbeeld.nl';

  @override
  String get authSignupPassword => 'Wachtwoord';

  @override
  String get authSignupPasswordHint => 'Minstens 8 tekens';

  @override
  String get authSignupCreateAccount => 'Account aanmaken';

  @override
  String get authSignupCreatingAccount => 'Account wordt aangemaakt…';

  @override
  String get authSignupHaveAccount => 'Heb je al een account?';

  @override
  String get authSignupSignInLink => 'Inloggen';

  @override
  String get authSignupFillAllFields => 'Vul alle velden in.';

  @override
  String get authSignupPasswordMinLength =>
      'Wachtwoord moet minstens 8 tekens lang zijn.';

  @override
  String get authSignupJoinTitle => 'Deelnemen aan huishouden';

  @override
  String get authSignupAccountCreated => 'Account aangemaakt. Welkom!';

  @override
  String get authSignupNameRequired => 'Naam is verplicht.';

  @override
  String get authSignupEmailRequired => 'E-mail is verplicht.';

  @override
  String get authSignupPasswordRequired => 'Wachtwoord is verplicht.';

  @override
  String get authSignupConfirmPassword => 'Confirm password';

  @override
  String get authSignupConfirmPasswordHint => 'Re-enter your password';

  @override
  String get authSignupConfirmPasswordRequired =>
      'Please confirm your password.';

  @override
  String get authSignupPasswordMismatch => 'Passwords do not match.';

  @override
  String get authSignupPasswordRequirementsNotMet =>
      'Password does not meet the requirements below.';

  @override
  String get passwordRequirementsTitle => 'Your password must contain:';

  @override
  String get passwordRequirementLength => 'At least 8 characters';

  @override
  String get passwordRequirementUppercase => 'One uppercase letter';

  @override
  String get passwordRequirementDigit => 'One number';

  @override
  String get passwordRequirementSpecial => 'One special character';

  @override
  String get authSignupGenericError =>
      'Account aanmaken mislukt. Controleer je verbinding en probeer het opnieuw.';

  @override
  String get authSignupNameHint => 'Je naam';

  @override
  String get authSignupTermsPrefix =>
      'Door een account aan te maken ga je akkoord met onze ';

  @override
  String get authSignupAnd => ' en ';

  @override
  String get authSignupPeriod => '.';

  @override
  String get authSignupPrivacyPolicy => 'Privacybeleid';

  @override
  String get authSignupTermsP1 =>
      'Gebruik mitlist verantwoord. Gedeelde huishoudeninhoud is zichtbaar voor de leden van dat huishouden.';

  @override
  String get authSignupTermsP2 =>
      'Upload geen onwettige inhoud, doe je niet voor als iemand anders en misbruik de dienst niet. Accounts en gedeelde gegevens kunnen bij misbruik worden verwijderd.';

  @override
  String get authSignupTermsP3 =>
      'De app wordt geleverd zoals hij is terwijl het product nog evolueert. Bewaar zelf back-ups van alles wat belangrijk is.';

  @override
  String get authSignupPrivacyP1 =>
      'mitlist slaat de accountgegevens en huishoudeninhoud op die nodig zijn om de app te laten werken.';

  @override
  String get authSignupPrivacyP2 =>
      'Gedeelde gegevens zoals lijsten, klussen, uitgaven en recepten zijn zichtbaar voor andere leden van hetzelfde huishouden.';

  @override
  String get authSignupPrivacyP3 =>
      'Geef alleen informatie door die je prettig vindt in een gedeelde huishoudenwerkruimte.';

  @override
  String get authJoinTitle => 'Deelnemen aan huishouden';

  @override
  String authJoinInvitedBy(String name) {
    return '$name heeft je uitgenodigd';
  }

  @override
  String get authJoinJoinNow => 'Nu deelnemen';

  @override
  String get authJoinSignInToJoin => 'Log in om mee te doen';

  @override
  String get authJoinCreateToJoin => 'Account aanmaken om mee te doen';

  @override
  String get authJoinGuestWarning =>
      'Gastaccounts kunnen niet deelnemen aan huishoudens.';

  @override
  String get authJoinCouldNotLoad =>
      'Uitnodigingsdetails konden niet worden geladen.';

  @override
  String get authJoinJoining => 'Deelnemen…';

  @override
  String get authJoinNotNow => 'Niet nu';

  @override
  String get authJoinYoureIn => 'Je zit erbij.';

  @override
  String get authJoinGoToHousehold => 'Naar huishouden';

  @override
  String authJoinInviteCodeSemantic(String code) {
    return 'Uitnodigingscode: $code';
  }

  @override
  String authJoinErrorWithHint(String error) {
    return '$error\n\nJe kunt ook een code invoeren via de huishoudenwisselaar.';
  }

  @override
  String get authOnboardingTitle => 'Welkom';

  @override
  String get authOnboardingSetupHome => 'Richt je thuis in';

  @override
  String get authOnboardingCreateOrJoin =>
      'Maak of sluit je aan bij een huishouden om te delen met huisgenoten.';

  @override
  String get authOnboardingCreateHousehold => 'Huishouden aanmaken';

  @override
  String get authOnboardingJoinInvite => 'Deelnemen met uitnodigingscode';

  @override
  String get authOnboardingHaveCode => 'Heb je een uitnodigingscode?';

  @override
  String get authOnboardingCreateDesc =>
      'Begin opnieuw: geef het een naam, nodig huisgenoten uit en deel alles op één plek.';

  @override
  String get authOnboardingJoinDesc =>
      'Al een uitnodiging? Voer de code in en ga meteen aan de slag.';

  @override
  String get authOnboardingJoinSemantic =>
      'Deelnemen aan een huishouden met uitnodigingscode';

  @override
  String get authOnboardingHomeIconSemantic => 'Huishouden-startpictogram';

  @override
  String get welcomePillarsSemantic =>
      'Gedeelde lijsten, geld, klusjes en keuken. Alles op één plek.';

  @override
  String get authOnboardingNameTitle => 'Geef je huishouden een naam';

  @override
  String get authOnboardingNameBody =>
      'Schrijf hem op het briefje. Je kunt hem later aanpassen.';

  @override
  String get authOnboardingPinIt => 'Prik hem op het prikbord';

  @override
  String get authOnboardingInviteTitle => 'Haal je huisgenoten erbij';

  @override
  String get authOnboardingInviteBody =>
      'Deel deze code. Wie hem invoert, komt bij je huishouden.';

  @override
  String get authOnboardingGoToBoard => 'Verder';

  @override
  String get authOnboardingReadyTitle => 'Je huishouden is klaar';

  @override
  String get authOnboardingReadyBody =>
      'Drie dingen om te weten. Dat is de hele kaart.';

  @override
  String get authOnboardingOrientationHome =>
      'Home laat zien wat aandacht nodig heeft';

  @override
  String get authOnboardingOrientationTabs =>
      'Tabs geven elk deel van het huishouden een vaste plek';

  @override
  String get authOnboardingOrientationAdd =>
      'Met de knop + voeg je overal iets toe';

  @override
  String authOnboardingEnterHousehold(String name) {
    return '$name openen';
  }

  @override
  String get authOnboardingResolving => 'Je prikbord wordt geopend…';

  @override
  String get hubChecklistTitle => 'Breng het huis op gang';

  @override
  String get hubChecklistDone => 'Klaar';

  @override
  String hubChecklistProgress(int done, int total) {
    return '$done van $total klaar';
  }

  @override
  String get hubStatsChores => 'Klussen';

  @override
  String get hubStatsDue => 'te doen';

  @override
  String get hubStatsMeals => 'Maaltijden';

  @override
  String get hubStatsPlanned => 'gepland';

  @override
  String get hubStatsOverdue => 'te laat';

  @override
  String get hubStatsAllDone => 'alles klaar';

  @override
  String get hubStatsBalance => 'Saldo';

  @override
  String get hubStatsOpen => 'open';

  @override
  String get hubStatsLists => 'Lijsten';

  @override
  String get hubStatsActiveList => 'actieve lijst';

  @override
  String get hubStatsActiveLists => 'actieve lijsten';

  @override
  String get hubStatsReminders => 'Herinneringen';

  @override
  String get hubStatsPinwallReminder => 'prikbordherinnering';

  @override
  String get hubStatsPinwallReminders => 'prikbordherinneringen';

  @override
  String get hubQuickAddTitle => 'Snel toevoegen';

  @override
  String get hubQuickAddChore => 'Klus toevoegen';

  @override
  String get hubQuickAddExpense => 'Uitgave toevoegen';

  @override
  String get hubQuickAddNote => 'Notitie vastpinnen';

  @override
  String get hubQuickAddList => 'Nieuwe lijst';

  @override
  String get hubActivityTitle => 'Activiteit';

  @override
  String get hubActivityEmpty =>
      'Nog niets aan de hand.\nActiviteit van je huishouden verschijnt hier.';

  @override
  String get hubActivityError =>
      'Activiteit kon niet worden geladen. Trek naar beneden op de hub om te vernieuwen.';

  @override
  String get hubOnboardingSwap => 'Ruilen';

  @override
  String get hubOnboardingSettle => 'Verrekenen';

  @override
  String get hubOnboardingDone => 'Alles klaar';

  @override
  String get hubOnboardingSwapDesc =>
      'Kies een huisgenoot die het minst verschuldigd is om deze klus over te nemen.';

  @override
  String get hubOnboardingSettleDesc =>
      'Betaal iedereen in één keer terug met voorgestelde verrekeningen.';

  @override
  String get hubOnboardingDoneDesc =>
      'Klussen, saldi, lijsten — alles op één plek, netjes bijgehouden.';

  @override
  String get appBottomSheetHandle => 'Handvat';

  @override
  String get appBottomSheetClose => 'Sluiten';

  @override
  String get storePickerTitle => 'Winkel kiezen';

  @override
  String get storePickerSearchLabel => 'Winkels zoeken';

  @override
  String get storePickerSearchHint => 'Naam...';

  @override
  String get storePickerNoMatch =>
      'Geen winkels komen overeen met je zoekopdracht.';

  @override
  String get storePickerNoStore => 'Geen winkel';

  @override
  String get storePickerNoStoreDesc =>
      'Sorteer op categorie in plaats van winkelindeling';

  @override
  String get storePickerLoadError => 'Winkels konden niet worden geladen.';

  @override
  String get smartCaptureLaunchTitle => 'Foto controleren';

  @override
  String get hubQuickAddToList => 'Toevoegen aan lijst';

  @override
  String get hubQuickAddShoppingTrip => 'Boodschappen starten';

  @override
  String get hubOnboardingGetStarted => 'Aan de slag';

  @override
  String get hubOnboardingDismiss => 'Snelstart sluiten';

  @override
  String get hubOnboardingDescription =>
      'Alles begint hier. Kies wat het belangrijkst is.';

  @override
  String get hubOnboardingInvite => 'Huisgenoten uitnodigen';

  @override
  String get hubOnboardingCreateList => 'Lijst aanmaken';

  @override
  String get hubOnboardingAddChore => 'Klus toevoegen';

  @override
  String get hubOnboardingTrackExpense => 'Uitgave bijhouden';

  @override
  String hubQuickStartNextSemantic(String label) {
    return 'Volgende stap: $label';
  }

  @override
  String get hubQuickStartDismissedToast =>
      'Snelstart opgeborgen. Je haalt hem altijd terug via Account.';

  @override
  String get accountShowQuickStart => 'Snelstart op het prikbord tonen';

  @override
  String get accountQuickStartRestored =>
      'De snelstart staat weer op je prikbord.';

  @override
  String get appBottomSheetDiscardTitle => 'Wijzigingen negeren?';

  @override
  String get appBottomSheetDiscardBody =>
      'Je hebt niet-opgeslagen wijzigingen.';

  @override
  String get appBottomSheetKeepEditing => 'Verder bewerken';

  @override
  String get sheetExpenseDetailTitle => 'Uitgavedetails';

  @override
  String get sheetExpenseDetailSplits => 'Verdelingen';

  @override
  String sheetExpenseDetailSplitsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count verdelingen',
      one: '$count verdeling',
    );
    return '$_temp0';
  }

  @override
  String get sheetSettlementTitle => 'Verrekening registreren';

  @override
  String get sheetSettlementFrom => 'Van';

  @override
  String get sheetSettlementTo => 'Naar';

  @override
  String get sheetSettlementRecordPayment =>
      'Registreer deze verrekening nadat de betaling is gedaan.';

  @override
  String get sheetSettlementConfirm => 'Verrekening bevestigen';

  @override
  String get sheetGroupSettingsTitle => 'Huishoudinstellingen';

  @override
  String get sheetGroupSettingsName => 'Huishoudennaam';

  @override
  String get sheetGroupSettingsSaved => 'Instellingen opgeslagen';

  @override
  String get sheetGroupSettingsCouldNotSave =>
      'Instellingen konden niet worden opgeslagen.';

  @override
  String get sheetGroupSettingsLeave => 'Huishouden verlaten';

  @override
  String get sheetGroupSettingsLeaveConfirm =>
      'Weet je zeker dat je dit huishouden wilt verlaten? Al je gegevens blijven in het huishouden bewaard.';

  @override
  String get sheetGroupSettingsLeaveAction => 'Verlaten';

  @override
  String get sheetGroupSettingsDelete => 'Huishouden verwijderen';

  @override
  String get sheetGroupSettingsDeleteConfirm =>
      'Dit verwijdert dit huishouden en alle bijbehorende gegevens permanent. Dit kan niet ongedaan worden gemaakt.';

  @override
  String get sheetRecipeAddToListTitle => 'Toevoegen aan lijst';

  @override
  String sheetRecipeAddToListAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items toegevoegd',
      one: '1 item toegevoegd',
    );
    return '$_temp0';
  }

  @override
  String get sheetRecipeAddToListCouldNotAdd =>
      'Ingrediënten konden niet worden toegevoegd.';

  @override
  String get sheetJoinTitle => 'Deelnemen aan huishouden';

  @override
  String get sheetJoinCodeLabel => 'Uitnodigingscode';

  @override
  String get sheetJoinCodeHint => 'Plak uitnodigingscode';

  @override
  String get sheetJoinJoin => 'Deelnemen';

  @override
  String get joinPasteButton => 'Paste';

  @override
  String get joinPasteFilled => 'Invite code pasted';

  @override
  String get joinPasteNoCode =>
      'No invite code or link found on your clipboard';

  @override
  String get sheetCreateHouseholdTitle => 'Huishouden aanmaken';

  @override
  String get sheetCreateHouseholdName => 'Huishoudennaam';

  @override
  String get sheetCreateHouseholdNameHint => 'bijv. Appartement 4B';

  @override
  String get sheetInviteTitle => 'Uitnodigen voor huishouden';

  @override
  String get sheetInviteCopy => 'Link kopiëren';

  @override
  String get sheetInviteCopied => 'Uitnodigingslink gekopieerd';

  @override
  String get sheetInviteShare => 'Link delen';

  @override
  String get sheetCreateListTitle => 'Nieuwe lijst';

  @override
  String get sheetCreateListName => 'Lijstnaam';

  @override
  String get sheetCreateListNameHint => 'bijv. Weekboodschappen';

  @override
  String get sheetCreateListType => 'Type';

  @override
  String get sheetCreateListTypeShopping => 'Boodschappen';

  @override
  String get sheetCreateListTypeTodo => 'Taken';

  @override
  String get sheetCreateListTypeCustom => 'Aangepast';

  @override
  String get sheetCreateListCreate => 'Lijst aanmaken';

  @override
  String get sheetCostSummaryTitle => 'Kostenoverzicht';

  @override
  String get sheetCostSummaryTotal => 'Totaal';

  @override
  String get sheetConflictTitle => 'Synchronisatieconflict';

  @override
  String get sheetConflictDescription =>
      'Dit item is op een ander apparaat gewijzigd terwijl je het bewerkte. Kies welke versie je wilt behouden.';

  @override
  String get sheetConflictLocal => 'Jouw versie';

  @override
  String get sheetConflictServer => 'Serverversie';

  @override
  String get sheetConflictKeepLocal => 'Jouwe behouden';

  @override
  String get sheetConflictKeepServer => 'Server behouden';

  @override
  String get sheetFailedChangesTitle => 'Mislukte wijzigingen';

  @override
  String get sheetFailedChangesDescription =>
      'Deze wijzigingen konden niet worden opgeslagen. Je kunt opnieuw proberen of ze negeren.';

  @override
  String get sheetFailedChangesRetryAll => 'Alles opnieuw';

  @override
  String get sheetFailedChangesDiscardAll => 'Alles negeren';

  @override
  String get sheetFailedChangesDiscard => 'Negeren';

  @override
  String get sheetFailedChangesRetry => 'Opnieuw';

  @override
  String get sheetFailedChangesEmpty =>
      'Geen mislukte wijzigingen. Alles is gesynchroniseerd of wacht op een nieuwe poging.';

  @override
  String get sheetFailedChangesOpAddItem => 'Item toevoegen';

  @override
  String get sheetFailedChangesOpUpdateItem => 'Item bijwerken';

  @override
  String get sheetFailedChangesOpDeleteItem => 'Item verwijderen';

  @override
  String get sheetFailedChangesOpReorderItems => 'Lijst herschikken';

  @override
  String get sheetFailedChangesOpCreateExpense => 'Uitgave toevoegen';

  @override
  String get sheetFailedChangesOpUpdateExpense => 'Uitgave bijwerken';

  @override
  String get sheetFailedChangesOpDeleteExpense => 'Uitgave verwijderen';

  @override
  String get sheetFailedChangesOpCreateRecipe => 'Recept toevoegen';

  @override
  String get sheetFailedChangesOpUpdateRecipe => 'Recept bijwerken';

  @override
  String get sheetFailedChangesOpDeleteRecipe => 'Recept verwijderen';

  @override
  String get sheetFailedChangesOpCompleteChore => 'Klus voltooien';

  @override
  String get sheetFailedChangesOpSkipChore => 'Klus overslaan';

  @override
  String get sheetFailedChangesOpRescheduleChore => 'Klus opnieuw plannen';

  @override
  String get sheetFailedChangesOpUndoChore => 'Klus ongedaan maken';

  @override
  String get sheetFailedChangesOpCreatePinwallPost => 'Op prikbord plaatsen';

  @override
  String get sheetFailedChangesOpDeletePinwallPost =>
      'Prikbordbericht verwijderen';

  @override
  String get sheetFailedChangesOpChange => 'Wijziging';

  @override
  String get sheetGroupSettingsChoreZonesUpdated => 'Kluszones bijgewerkt';

  @override
  String get sheetGroupSettingsRemoveMember => 'Lid verwijderen';

  @override
  String sheetGroupSettingsRemoveMemberConfirm(String name) {
    return '$name uit dit huishouden verwijderen?';
  }

  @override
  String sheetGroupSettingsMemberRemoved(String name) {
    return '$name verwijderd';
  }

  @override
  String get sheetGroupSettingsHouseholdDeleted => 'Huishouden verwijderd';

  @override
  String get sheetGroupSettingsDescriptionHint =>
      'Een paar woorden over dit huishouden';

  @override
  String get sheetGroupSettingsChoreZonesLabel => 'Kluszones';

  @override
  String get sheetGroupSettingsChoreZonesDesc =>
      'Ruimtes in je huis om klussen te groeperen. Ze verschijnen bij het toevoegen van een klus.';

  @override
  String get sheetGroupSettingsAddZone => 'Zone toevoegen';

  @override
  String get sheetGroupSettingsZoneHint => 'Keuken, Badkamer…';

  @override
  String get sheetGroupSettingsSaveZones => 'Zones opslaan';

  @override
  String get sheetGroupSettingsMembersLabel => 'Leden';

  @override
  String get sheetGroupSettingsInvite => 'Uitnodigen';

  @override
  String sheetGroupSettingsRemoveMemberTooltip(String name) {
    return '$name verwijderen';
  }

  @override
  String get tonightRecipe => 'Recept';

  @override
  String get tonightHeader => 'Vanavond';

  @override
  String get tonightCook => 'Koken';

  @override
  String get tonightNothingPlanned => 'Niets gepland voor vanavond';

  @override
  String get tonightPlanDinner => 'Avondeten plannen';

  @override
  String activityAddedToList(String name, String when) {
    return 'Heeft $name aan een lijst toegevoegd · $when';
  }

  @override
  String activityAddedToNamedList(String name, String list, String when) {
    return '$name toegevoegd aan $list · $when';
  }

  @override
  String activityAddedItemToList(String when) {
    return 'Heeft een item aan een lijst toegevoegd · $when';
  }

  @override
  String activityLoggedExpense(String name, String when) {
    return 'Heeft $name geregistreerd · $when';
  }

  @override
  String activityLoggedExpenseGeneric(String when) {
    return 'Heeft een uitgave geregistreerd · $when';
  }

  @override
  String activityCompletedChore(String name, String when) {
    return 'Heeft $name voltooid · $when';
  }

  @override
  String activityCompletedChoreGeneric(String when) {
    return 'Heeft een klus voltooid · $when';
  }

  @override
  String activitySavedRecipe(String name, String when) {
    return 'Heeft $name opgeslagen · $when';
  }

  @override
  String activitySavedRecipeGeneric(String when) {
    return 'Heeft een recept opgeslagen · $when';
  }

  @override
  String activityPlannedMeal(String name, String when) {
    return 'Heeft $name gepland · $when';
  }

  @override
  String activityUpdatedMealPlan(String when) {
    return 'Maaltijdplan bijgewerkt · $when';
  }

  @override
  String get activityYou => 'Jij';

  @override
  String get activityMember => 'Lid';

  @override
  String inviteLinkShareText(String link, String code) {
    return 'Doe mee met mijn huishouden op mitlist!\nTik: $link\nOf open mitlist en voer de code in: $code';
  }

  @override
  String get errorBoundaryTitle => 'Er ging iets mis';

  @override
  String get errorBoundaryDesc =>
      'Er is een onverwachte fout opgetreden. Probeer het opnieuw.';

  @override
  String get recurringTomorrow => 'Morgen';

  @override
  String get recurringCouldNotUpdate =>
      'Terugkerende uitgave kon niet worden bijgewerkt.';

  @override
  String get recurringCouldNotDelete =>
      'Terugkerende uitgave kon niet worden verwijderd.';

  @override
  String get recurringCouldNotCreate =>
      'Terugkerende uitgave kon niet worden aangemaakt.';

  @override
  String get recipeAddToListNoLists => 'Geen lijsten';

  @override
  String get recipeAddToListCreateListFirst =>
      'Maak eerst een lijst om ingrediënten toe te voegen';

  @override
  String get costSummaryNoPrices =>
      'Nog geen items met prijzen. Open de itemopties (⋯) en kies Prijs instellen om het kostenoverzicht te zien.';

  @override
  String get costSummaryNotAvailable => 'N.v.t.';

  @override
  String get costSummaryEqualShare => 'Gelijk aandeel per persoon';

  @override
  String get costSummaryItemsWithPrices => 'Items met prijzen';

  @override
  String get costSummaryNone => 'Geen';

  @override
  String get costSummaryGenerateExpense => 'Uitgave genereren';

  @override
  String get createListScanFinished => 'Scan voltooid';

  @override
  String createListScanned(String name) {
    return '\"$name\" gescand';
  }

  @override
  String get createListShoppingDesc =>
      'Het beste voor boodschappen en klusjes met hoeveelheden.';

  @override
  String get createListNameRequired => 'Lijstnaam is verplicht';

  @override
  String get createListCreated => 'Lijst aangemaakt';

  @override
  String get recipeCreationScanRecipe => 'Recept scannen';

  @override
  String get recipeCreationScanRecipeViaCamera => 'Recept scannen via camera';

  @override
  String get joinCodeFormatHint =>
      'Codes zien eruit als WOORD-WOORD-X7WM2K9PQ6R8S. Vraag het aan degene die je heeft uitgenodigd.';

  @override
  String joinEnterGroup(String name) {
    return '$name openen';
  }

  @override
  String inviteCodeLabel(String code) {
    return 'Uitnodigingscode: $code';
  }

  @override
  String get inviteQrTitle => 'Huishoudenuitnodigings-QR-code';

  @override
  String get inviteQrSemantic => 'Huishoudenuitnodigings-QR';

  @override
  String get inviteQrHint =>
      'Scan met je telefooncamera om mee te doen, of deel de code hieronder.';

  @override
  String get inviteGenerating => 'Genereren…';

  @override
  String get inviteNewCode => 'Nieuwe code';

  @override
  String get createHouseholdCreated => 'Huishouden aangemaakt';

  @override
  String get createHouseholdDescriptionOptional => 'Beschrijving (optioneel)';

  @override
  String get conflictNoneToResolve => 'Geen conflicten om op te lossen.';

  @override
  String get conflictItemChanged => 'Item gewijzigd';

  @override
  String conflictItemLabel(String name) {
    return 'Item: $name';
  }

  @override
  String get scannerCouldNotAnalyze =>
      'Afbeelding kon niet worden geanalyseerd. Probeer het opnieuw met een duidelijkere foto.';

  @override
  String get oauthMissingParams => 'Ontbrekende OAuth-callbackparameters.';

  @override
  String get oauthSigningYouIn => 'Je wordt ingelogd';

  @override
  String get expenseCreationSharesNegative =>
      'Aandelen kunnen niet negatief zijn.';

  @override
  String get expenseCreationAssignShare => 'Wijs minstens één aandeel toe.';

  @override
  String get expenseCreationCouldNotLoadMembers =>
      'Huishoudleden konden niet worden geladen.';

  @override
  String get expenseCreationJoinHouseholdSplit =>
      'Sluit je aan bij of maak een huishouden om deze uitgave te verdelen.';

  @override
  String expenseCreationRemoveAddSplitter(String name) {
    return '$name verwijderen/toevoegen bij verdeling';
  }

  @override
  String get expenseDetailFailedLoadReceipt => 'Bon laden mislukt';

  @override
  String get expenseDetailReceipt => 'Bon';

  @override
  String get expenseDetailView => 'Bekijken';

  @override
  String get expenseDetailNotSplitYet => 'Deze uitgave is nog niet verdeeld.';

  @override
  String get expenseDetailNoReceipts =>
      'Geen bonnen bijgevoegd. Voeg er een toe bij het bewerken van de uitgave.';

  @override
  String pinwallLinkedTo(String entity) {
    return 'Gekoppeld aan $entity';
  }

  @override
  String get commonView => 'Bekijken';

  @override
  String get notificationsOpenList => 'Lijst openen';

  @override
  String get notificationsOpenChore => 'Taak openen';

  @override
  String get notificationsOpenMoney => 'Geldzaken openen';

  @override
  String get notificationsOpenRecipes => 'Recepten openen';

  @override
  String get notificationsOpenHousehold => 'Huishouden openen';

  @override
  String get notificationChoreDueSoonTitle => 'Taak binnenkort verwacht';

  @override
  String notificationChoreDueSoonBody(String choreName) {
    return '$choreName moet binnenkort gebeuren';
  }

  @override
  String get notificationChoreDueTodayTitle => 'Taak voor vandaag';

  @override
  String notificationChoreDueTodayBody(String choreName) {
    return '$choreName moet vandaag gebeuren';
  }

  @override
  String notificationListUpdatedTitle(String listName) {
    return '$listName bijgewerkt';
  }

  @override
  String notificationListUpdatedOneBody(
      String actorName, String itemName, String listName, String groupName) {
    return '$actorName voegde $itemName toe aan $listName in $groupName.';
  }

  @override
  String notificationListUpdatedManyBody(
      String actorName, num count, String listName, String groupName) {
    return '$actorName voegde $count items toe aan $listName in $groupName.';
  }

  @override
  String get notificationExpenseCreatedTitle => 'Uitgave toegevoegd';

  @override
  String notificationExpenseCreatedBody(
      String actorName, String expenseName, String groupName) {
    return '$actorName voegde $expenseName toe in $groupName.';
  }

  @override
  String get notificationRecurringExpenseTitle =>
      'Terugkerende uitgave toegevoegd';

  @override
  String notificationRecurringExpenseBody(String expenseName) {
    return '$expenseName is toegevoegd.';
  }

  @override
  String get notificationSettlementRequestTitle => 'Betaling bevestigen';

  @override
  String notificationSettlementPaidYouBody(
      String actorName, String amount, String groupName) {
    return '$actorName zegt je $amount te hebben betaald in $groupName. Bevestig om de saldi bij te werken.';
  }

  @override
  String notificationSettlementYouPaidBody(
      String actorName, String amount, String groupName) {
    return '$actorName zegt dat jij $amount betaalde in $groupName. Bevestig om de saldi bij te werken.';
  }

  @override
  String get notificationSettlementConfirmedTitle => 'Betaling bevestigd';

  @override
  String notificationSettlementConfirmedBody(
      String actorName, String amount, String groupName) {
    return '$actorName bevestigde je betaling van $amount in $groupName.';
  }

  @override
  String get notificationSettlementDeclinedTitle => 'Betaling afgewezen';

  @override
  String notificationSettlementDeclinedBody(
      String actorName, String amount, String groupName) {
    return '$actorName wees je betaling van $amount in $groupName af.';
  }

  @override
  String get notificationMealPlanTitle => 'Maaltijdplan bijgewerkt';

  @override
  String notificationMealPlanBody(String actorName, String groupName) {
    return '$actorName werkte het maaltijdplan bij in $groupName.';
  }

  @override
  String get notificationWeeklyDigestTitle => 'Weekoverzicht';

  @override
  String notificationWeeklyDigestBody(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Je huishouden had deze week $count activiteiten',
      one: 'Je huishouden had deze week 1 activiteit',
      zero: 'Deze week was er geen huishoudactiviteit',
    );
    return '$_temp0';
  }

  @override
  String get notificationPinwallReminderTitle => 'Herinnering';

  @override
  String get commonPhoto => 'Foto';

  @override
  String cookModeTimerStart(String label) {
    return 'Timer: $label. Tik om te starten';
  }

  @override
  String get errorServerHiccup =>
      'Serverprobleem — probeer het zo meteen opnieuw.';

  @override
  String get errorConflict =>
      'Iemand anders heeft dit gewijzigd. Vernieuw en probeer het opnieuw.';

  @override
  String get errorNotFound => 'Niet gevonden. Het is mogelijk verwijderd.';

  @override
  String get errorNoPermission => 'Je hebt geen toestemming hiervoor.';

  @override
  String get errorSignInAgain => 'Log opnieuw in.';

  @override
  String get errorGenericRetry => 'Er ging iets mis. Probeer het opnieuw.';

  @override
  String get createListTodoDesc =>
      'Een eenvoudige checklist voor taken die gedaan moeten worden.';

  @override
  String get createListCustomDesc =>
      'Een flexibele lijst voor alles wat niet past.';

  @override
  String get createListScanSemantics => 'Lijst scannen via camera';

  @override
  String get createListHouseholdLabel => 'Huishouden';

  @override
  String get createListNoHousehold => 'Geen huishouden beschikbaar.';

  @override
  String get sheetJoinCodeExample => 'SUNNY-TACO-X7WM2K9PQ6R8S';

  @override
  String joinMembersAlreadyInside(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count leden al binnen',
      one: '1 lid al binnen',
    );
    return '$_temp0';
  }

  @override
  String get inviteQrUnavailable => 'QR niet beschikbaar';

  @override
  String expenseCreationSplitAssignedOf(String assigned, String total) {
    return '$assigned van $total';
  }

  @override
  String expenseCreationSplitAmountsNegative(String assigned) {
    return '$assigned · bedragen kunnen niet negatief zijn';
  }

  @override
  String expenseCreationSplitLeftToAssign(String assigned, String remaining) {
    return '$assigned · $remaining nog toe te wijzen';
  }

  @override
  String expenseCreationSplitOver(String assigned, String over) {
    return '$assigned · $over te veel';
  }

  @override
  String expenseCreationSplitPercentRange(String sum) {
    return '$sum% toegewezen · elk aandeel moet 0–100% zijn';
  }

  @override
  String expenseCreationSplitPercentOf100(String sum) {
    return '$sum% van 100%';
  }

  @override
  String expenseCreationSplitSharesPerShare(num count, String perShare) {
    return '$count aandelen · $perShare per aandeel';
  }

  @override
  String expenseCreationSplitEach(String amount) {
    return '$amount per persoon';
  }

  @override
  String expenseCreationSplitApproxEach(String amount) {
    return '≈ $amount per persoon';
  }

  @override
  String expenseCreationRemoveFromSplit(String name) {
    return '$name verwijderen uit verdeling';
  }

  @override
  String expenseCreationAddToSplit(String name) {
    return '$name toevoegen aan verdeling';
  }

  @override
  String get expenseDetailCouldNotLoadSplits =>
      'Verdelingen konden niet worden geladen.';

  @override
  String get expenseDetailCouldNotLoadReceipts =>
      'Bonnen konden niet worden geladen.';

  @override
  String get expenseDetailCouldNotRemoveReceipt =>
      'Bon kon niet worden verwijderd.';

  @override
  String get expenseDetailRemoving => 'Verwijderen…';

  @override
  String get recipeAddToListTargetList => 'Doellijst';

  @override
  String get recipeAddToListNoIngredients => 'Geen ingrediënten';

  @override
  String get recipeAddToListNoIngredientsDesc =>
      'Dit recept heeft geen verwerkte ingrediënten';

  @override
  String recipeAddToListRemoveFromSelection(String name) {
    return '$name verwijderen uit selectie';
  }

  @override
  String recipeAddToListAddToSelection(String name) {
    return '$name toevoegen aan selectie';
  }

  @override
  String get pinwallLinkChore => 'Een klus';

  @override
  String get pinwallLinkList => 'Een lijst';

  @override
  String get pinwallCouldNotLoad => 'Prikbord kon niet worden geladen.';

  @override
  String get composerItemHint => 'bijv. Melk, 2 avocado\'s of 500 g bloem';

  @override
  String get aisleOther => 'Overig';

  @override
  String hubHouseholdsCurrent(String name) {
    return 'Huishoudens, huidig $name';
  }

  @override
  String recipeDetailStepCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stappen',
      one: '1 stap',
    );
    return '$_temp0';
  }

  @override
  String get currencyUsd => 'USD - Amerikaanse dollar';

  @override
  String get currencyEur => 'EUR - Euro';

  @override
  String get currencyGbp => 'GBP - Britse pond';

  @override
  String get currencyJpy => 'JPY - Japanse yen';

  @override
  String get currencyCad => 'CAD - Canadese dollar';

  @override
  String get currencyAud => 'AUD - Australische dollar';

  @override
  String get currencyChf => 'CHF - Zwitserse frank';

  @override
  String get currencySek => 'SEK - Zweedse kroon';

  @override
  String get currencyNok => 'NOK - Noorse kroon';

  @override
  String get currencyDkk => 'DKK - Deense kroon';

  @override
  String get currencyPln => 'PLN - Poolse złoty';

  @override
  String get currencyCzk => 'CZK - Tsjechische kroon';

  @override
  String get currencyHuf => 'HUF - Hongaarse forint';

  @override
  String get runningLowHeading => 'Bijna op';

  @override
  String runningLowDaysAgo(num days) {
    return '${days}d geleden';
  }

  @override
  String get restockReasonDue => 'Weer nodig';

  @override
  String get restockReasonUsual => 'Vaste aankoop';

  @override
  String get restockReasonGoesWith => 'Past bij deze lijst';

  @override
  String get householdStorageTitle => 'Huishoudopslag';

  @override
  String householdStorageUsedOf(String used, String limit) {
    return '$used van $limit gebruikt';
  }

  @override
  String householdStorageUsedUnlimited(String used) {
    return '$used gebruikt · geen limiet';
  }

  @override
  String householdStoragePending(String pending) {
    return '$pending is gereserveerd voor lopende uploads.';
  }

  @override
  String get householdStorageProgressLabel => 'Gebruikte huishoudopslag';

  @override
  String get accountSendFeedback => 'Feedback sturen';

  @override
  String get feedbackCardTitle => 'Help mitlist vormgeven';

  @override
  String get feedbackCardBody =>
      'Vraag een functie aan, meld een bug of deel een idee — het gaat direct naar het team.';

  @override
  String get feedbackSheetTitle => 'Feedback sturen';

  @override
  String get feedbackSheetIntro =>
      'Vraag een functie aan, meld een bug of vertel ons wat beter kan — we lezen elk bericht.';

  @override
  String get feedbackFieldLabel => 'Je bericht';

  @override
  String get feedbackFieldHint => 'Ik zou willen dat mitlist…';

  @override
  String get feedbackSend => 'Versturen';

  @override
  String get feedbackSending => 'Wordt verstuurd…';

  @override
  String get feedbackSent => 'Bedankt — je verzoek is verstuurd!';

  @override
  String get feedbackEmpty => 'Schrijf eerst een kort bericht.';

  @override
  String get feedbackFailed =>
      'Je verzoek kon nu niet worden verstuurd. Probeer het later opnieuw.';

  @override
  String get accountOcrTrainingTitle => 'Offline handschrift-OCR verbeteren';

  @override
  String get accountOcrTrainingDescription =>
      'Handmatig gecontroleerde regeluitsneden blijven op dit apparaat totdat je ze exporteert of verwijdert. Er wordt niets geüpload.';

  @override
  String get accountOcrTrainingExport => 'OCR-trainingsgegevens exporteren';

  @override
  String accountOcrTrainingSamples(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gecorrigeerde regels',
      one: '1 gecorrigeerde regel',
      zero: 'Geen gecorrigeerde regels',
    );
    return '$_temp0';
  }

  @override
  String get accountOcrTrainingClear => 'OCR-trainingsgegevens verwijderen';

  @override
  String get accountOcrTrainingExportEmpty =>
      'Er zijn nog geen gecorrigeerde OCR-regels om te exporteren.';

  @override
  String get accountOcrTrainingClearTitle =>
      'OCR-trainingsgegevens verwijderen?';

  @override
  String get accountOcrTrainingClearBody =>
      'Hiermee worden alle opgeslagen regeluitsneden permanent van dit apparaat verwijderd.';

  @override
  String get billingPremiumTitle => 'mitlist premium';

  @override
  String get billingLimitReachedTitle => 'Dit huishouden is vol';

  @override
  String billingLimitReachedBody(num limit, num next) {
    return 'Huishoudens tot $limit personen zijn gratis. Om een ${next}e lid toe te voegen heeft één persoon premium nodig — en dat geldt voor iedereen hier.';
  }

  @override
  String get billingCoversOneHousehold =>
      'Premium geldt voor één huishouden tegelijk. Jij kiest welke en kunt altijd wisselen.';

  @override
  String billingCoveredBy(String name) {
    return 'Premium op dit huishouden, betaald door $name.';
  }

  @override
  String get billingPremiumActive => 'Premium is hier actief';

  @override
  String get billingMoveHereTitle => 'Verplaats je premium hierheen';

  @override
  String get billingMoveHereBody =>
      'Je hebt al premium op een ander huishouden. Verplaats het hierheen in plaats van dubbel te betalen — het andere huishouden houdt iedereen die er al is, maar kan er niemand meer bij nemen.';

  @override
  String get billingMoveHereAction => 'Premium hierheen verplaatsen';

  @override
  String get billingMoved => 'Premium geldt nu voor dit huishouden.';

  @override
  String get billingMoveFailed =>
      'Je premium kon niet worden verplaatst. Probeer het opnieuw.';

  @override
  String get billingChooseHousehold => 'Kies je premium-huishouden';

  @override
  String get billingMonthly => 'Maandelijks';

  @override
  String get billingYearly => 'Jaarlijks';

  @override
  String get billingYearlyBadge => 'Beste prijs';

  @override
  String get billingSubscribe => 'Premium nemen';

  @override
  String get billingOpeningCheckout => 'Afrekenen wordt geopend...';

  @override
  String get billingCheckoutFailed =>
      'Afrekenen kon niet worden gestart. Probeer het opnieuw.';

  @override
  String get billingManage => 'Abonnement beheren';

  @override
  String get billingPortalFailed =>
      'Het facturatieportaal kon niet worden geopend.';

  @override
  String get billingReturnHint =>
      'Rond het af in je browser en kom terug — premium wordt automatisch geactiveerd.';

  @override
  String get billingProcessing => 'Processing your purchase...';

  @override
  String get billingRestore => 'Restore purchases';

  @override
  String get billingAutoRenewDisclosure =>
      'Payment is charged to your store account. The subscription renews automatically unless canceled at least 24 hours before the current period ends. Manage or cancel it in your App Store or Google Play account.';

  @override
  String get billingPurchased => 'Premium is active. Thanks!';

  @override
  String get billingAccountCardTitle => 'Premium';

  @override
  String billingAccountCardFree(num limit) {
    return 'Je gebruikt het gratis abonnement. Huishoudens tot $limit personen zijn gratis.';
  }

  @override
  String billingAccountCardActive(String household) {
    return 'Premium is actief op $household.';
  }

  @override
  String get billingAccountCardUnassigned =>
      'Premium is actief maar nog niet aan een huishouden toegewezen.';

  @override
  String billingRenewsOn(String date) {
    return 'Verlengt op $date';
  }

  @override
  String billingEndsOn(String date) {
    return 'Eindigt op $date';
  }

  @override
  String billingMemberUsage(num count, num limit) {
    return '$count van $limit gratis plekken gebruikt';
  }

  @override
  String get billingUnlimitedMembers => 'Onbeperkt aantal leden';
}
