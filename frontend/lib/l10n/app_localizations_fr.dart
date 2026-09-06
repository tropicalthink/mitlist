// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get commonCancel => 'Annuler';

  @override
  String get commonDelete => 'Supprimer';

  @override
  String get commonRetry => 'Réessayer';

  @override
  String get commonSave => 'Enregistrer';

  @override
  String get commonBack => 'Retour';

  @override
  String get commonClose => 'Fermer';

  @override
  String get commonDone => 'Terminé';

  @override
  String get commonUndo => 'Annuler';

  @override
  String get commonAdd => 'Ajouter';

  @override
  String get commonConfirm => 'Confirmer';

  @override
  String get commonEdit => 'Modifier';

  @override
  String get commonSearch => 'Rechercher';

  @override
  String get commonRemove => 'Retirer';

  @override
  String get commonDismiss => 'Ignorer';

  @override
  String get commonClear => 'Effacer';

  @override
  String get commonNext => 'Suivant';

  @override
  String get commonSkip => 'Passer';

  @override
  String get commonChange => 'Changer';

  @override
  String get commonCreate => 'Créer';

  @override
  String get commonRename => 'Renommer';

  @override
  String get commonArchive => 'Archiver';

  @override
  String get commonOptions => 'Options';

  @override
  String get commonSettings => 'Paramètres';

  @override
  String get commonName => 'Nom';

  @override
  String get commonDescription => 'Description';

  @override
  String get commonNotes => 'Notes';

  @override
  String get commonAmount => 'Montant';

  @override
  String get commonPreview => 'Aperçu';

  @override
  String get commonShare => 'Partager';

  @override
  String get commonCopy => 'Copier';

  @override
  String get commonListName => 'Nom de la liste';

  @override
  String get commonSaving => 'Enregistrement…';

  @override
  String get commonAdding => 'Ajout…';

  @override
  String get commonDeleting => 'Suppression…';

  @override
  String get commonNoHousehold => 'Pas encore de foyer';

  @override
  String get commonCreateJoinHousehold =>
      'Crée ou rejoins un foyer avant d\'ajouter des éléments.';

  @override
  String get commonGoToHouseholds => 'Voir les foyers';

  @override
  String get commonSomethingWentWrong => 'Une erreur est survenue';

  @override
  String get commonFailedToLoad => 'Échec du chargement. Réessaie.';

  @override
  String get commonCheckConnection => 'Vérifie ta connexion et réessaie.';

  @override
  String get commonClearSearch => 'Effacer la recherche';

  @override
  String commonMember(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '$count membre',
    );
    return '$_temp0';
  }

  @override
  String commonItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '1 élément',
      zero: 'Aucun élément',
    );
    return '$_temp0';
  }

  @override
  String get commonLoadingMembers => 'Chargement des membres...';

  @override
  String get integrationsTitle => 'Intégrations';

  @override
  String get homeAssistantTitle => 'Home Assistant';

  @override
  String get homeAssistantDescription =>
      'Connecte ton foyer à des tableaux de bord, à la commande vocale et à des automatisations.';

  @override
  String get homeAssistantConnections => 'Connexions';

  @override
  String get homeAssistantNoConnections =>
      'Aucune connexion Home Assistant pour l\'instant.';

  @override
  String get homeAssistantCreateConnection => 'Créer une connexion';

  @override
  String get homeAssistantConnectionName => 'Nom de la connexion';

  @override
  String get homeAssistantConnectionNameHint => 'Home Assistant';

  @override
  String get homeAssistantHouseholds => 'Foyers';

  @override
  String get homeAssistantPermissions => 'Autorisations';

  @override
  String get homeAssistantWriteAccess =>
      'Autoriser Home Assistant à faire des modifications';

  @override
  String get homeAssistantFinanceAccess => 'Inclure les données financières';

  @override
  String get homeAssistantTokenTitle => 'Jeton de connexion';

  @override
  String get homeAssistantTokenBody =>
      'Copie ce jeton dans Home Assistant maintenant. Pour des raisons de sécurité, mitlist ne pourra plus l\'afficher.';

  @override
  String get homeAssistantTokenCopied => 'Jeton de connexion copié';

  @override
  String get homeAssistantRevoke => 'Révoquer la connexion';

  @override
  String get homeAssistantRevokeConfirm =>
      'Cela déconnecte immédiatement Home Assistant. Tu pourras créer une nouvelle connexion plus tard.';

  @override
  String get homeAssistantRevoked => 'Révoquée';

  @override
  String get homeAssistantNeverUsed => 'Jamais utilisée';

  @override
  String homeAssistantLastUsed(String date) {
    return 'Dernière utilisation le $date';
  }

  @override
  String get homeAssistantSelectHousehold => 'Sélectionne au moins un foyer.';

  @override
  String get homeAssistantCreated => 'Connexion Home Assistant créée';

  @override
  String get homeAssistantRevokedSuccess => 'Connexion Home Assistant révoquée';

  @override
  String get homeAssistantLoadFailed =>
      'Impossible de charger les connexions Home Assistant.';

  @override
  String get homeAssistantSaveFailed =>
      'Impossible de créer la connexion. Réessaie.';

  @override
  String get homeAssistantReadOnly => 'Lecture seule';

  @override
  String get homeAssistantReadWrite => 'Lecture et écriture';

  @override
  String get welcomeTagline => 'Ton foyer, organisé.';

  @override
  String get welcomeCardTitle =>
      'Listes, tâches, argent.\nTout au même endroit.';

  @override
  String get welcomeCardBody =>
      'Conçu pour les colocs qui veulent moins de frictions et plus de clarté.';

  @override
  String get welcomeCreateHousehold => 'Créer un foyer gratuit';

  @override
  String get welcomeSignIn => 'Se connecter';

  @override
  String get welcomeGuestLoading => 'Configuration...';

  @override
  String get welcomeContinueAsGuest => 'Continuer en tant qu\'invité';

  @override
  String get welcomeInviteHeadline => 'Vous êtes invité';

  @override
  String get welcomeInviteSubtitle =>
      'Rejoignez le foyer pour partager listes, tâches et dépenses.';

  @override
  String get welcomeGuestFootnote =>
      'Pas d\'inscription nécessaire. Crée un compte plus tard pour garder tes données.';

  @override
  String get hubAppBarTitle => 'Accueil';

  @override
  String get hubHouseholdsSheetTitle => 'Foyers';

  @override
  String hubSwitchToHousehold(String name) {
    return 'Passer à $name';
  }

  @override
  String get hubCreateHousehold => 'Créer un foyer';

  @override
  String get hubJoinHousehold => 'Rejoindre un foyer';

  @override
  String get hubInviteToHousehold => 'Inviter au foyer';

  @override
  String get hubHouseholdSettings => 'Paramètres du foyer';

  @override
  String get hubWelcomeHeadline => 'Bienvenue sur mitlist';

  @override
  String get hubWelcomeDescription =>
      'Crée ou rejoins un foyer pour partager des listes, des tâches et les dépenses.';

  @override
  String get hubCreateAHousehold => 'Créer un foyer';

  @override
  String get hubJoinWithInviteCode => 'Rejoindre avec un code d\'invitation';

  @override
  String get hubQuickAdd => 'Ajout rapide';

  @override
  String get hubLoadError =>
      'Impossible de charger tes foyers. Vérifie ta connexion et réessaie.';

  @override
  String get hubCalendarTooltip => 'Calendrier';

  @override
  String get myHouseholdsTitle => 'Mes foyers';

  @override
  String get groupsJoinWithCode => 'Rejoindre avec un code';

  @override
  String get groupsFailedLoad => 'Échec du chargement des foyers';

  @override
  String get groupsFailedMore => 'Échec du chargement de plus de foyers';

  @override
  String get groupsEmptyTitle => 'Pas encore de foyer';

  @override
  String get groupsEmptyDesc =>
      'Crées-en un pour commencer à organiser ton chez-toi.';

  @override
  String get groupsCreateHousehold => 'Créer un foyer';

  @override
  String get choreAppBarTitle => 'Tâches';

  @override
  String get choreManageZones => 'Gérer les zones';

  @override
  String get choreAddChore => 'Ajouter une tâche';

  @override
  String get choreAddHouseholds => 'Foyers';

  @override
  String get choreRetry => 'Réessayer';

  @override
  String get choreNoHouseholdTitle => 'Pas encore de foyer';

  @override
  String get choreNoHouseholdDesc =>
      'Crée ou rejoins un foyer avant d\'ajouter des tâches.';

  @override
  String get choreGoToHouseholds => 'Voir les foyers';

  @override
  String get choreNoChoresTitle => 'Pas encore de tâches';

  @override
  String get choreNoChoresDesc =>
      'Suis les tâches récurrentes du foyer. Attribue-les à n\'importe qui dans ton groupe.';

  @override
  String get choreAddAChore => 'Ajouter une tâche';

  @override
  String get choreSectionOverdue => 'En retard';

  @override
  String get choreSectionToday => 'Aujourd\'hui';

  @override
  String get choreSectionThisWeek => 'Cette semaine';

  @override
  String get choreSectionLater => 'Plus tard';

  @override
  String get choreNothingOnYou => 'Rien pour toi en ce moment';

  @override
  String get choreNothingOnYouDesc =>
      'Votre foyer a des tâches, mais aucune ne t\'est attribuée.';

  @override
  String get choreSeeEveryonesChores => 'Voir les tâches de tout le monde';

  @override
  String choreDoneSnackbar(String choreTitle) {
    return '$choreTitle terminée';
  }

  @override
  String get choreDoneRecently => 'Faites récemment';

  @override
  String get choreLedgerYou => 'Toi';

  @override
  String get choreLedgerSomeone => 'Quelqu\'un';

  @override
  String choreLedgerDoneBy(String who, String when) {
    return '$who · $when';
  }

  @override
  String get choreLedgerJustNow => 'à l\'instant';

  @override
  String choreLedgerHoursAgo(int count) {
    return 'il y a $count h';
  }

  @override
  String get choreLedgerYesterday => 'hier';

  @override
  String choreBackOnDate(String date) {
    return 'de retour le $date';
  }

  @override
  String get choreUpForGrabs => 'À prendre';

  @override
  String choreDoneBackSnackbar(String choreTitle, String date) {
    return '$choreTitle faite — de retour le $date';
  }

  @override
  String get choreWhoEveryone => 'Tout le monde';

  @override
  String get choreWhoNoOne => 'Personne';

  @override
  String choreWhoAlways(String name) {
    return 'Toujours $name';
  }

  @override
  String choreWhoAmongSelected(int count) {
    return 'Tourne entre les $count personnes que tu as choisies.';
  }

  @override
  String get choreWhoOrderLabel => 'Ordre';

  @override
  String get choreDetailRhythm => 'Répétition';

  @override
  String choreLoadSummary(num count, int days) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches faites',
      one: '1 tâche faite',
    );
    return '$_temp0 au cours des $days derniers jours';
  }

  @override
  String get choreFailedComplete =>
      'Impossible de terminer la tâche. Réessaie.';

  @override
  String get choreFailedUndo =>
      'Impossible d\'annuler l\'exécution de la tâche. Réessaie.';

  @override
  String get choreFailedSkip => 'Impossible de passer la tâche. Réessaie.';

  @override
  String get choreFailedUpdateSubtask =>
      'Impossible de modifier la sous-tâche. Réessaie.';

  @override
  String get choreFailedAddSubtask =>
      'Impossible d\'ajouter la sous-tâche. Réessaie.';

  @override
  String get choreCreateListFirst => 'Crée d\'abord une liste de courses.';

  @override
  String get choreAddSuppliesToList => 'Ajouter les fournitures à la liste';

  @override
  String get choreSuppliesAdded => 'Fournitures ajoutées à la liste';

  @override
  String get choreFailedAddSupplies =>
      'Impossible d\'ajouter les fournitures. Réessaie.';

  @override
  String get choreFailedReschedule =>
      'Impossible de replanifier la tâche. Réessaie.';

  @override
  String get choreDeleteTitle => 'Supprimer la tâche';

  @override
  String get choreDeleteBody =>
      'Cela supprimera définitivement cette tâche et son historique. Cette action est irréversible.';

  @override
  String get choreStatusDone => 'Terminée';

  @override
  String get choreStatusOverdue => 'En retard';

  @override
  String get choreStatusDueToday => 'À faire aujourd\'hui';

  @override
  String get choreStatusDueSoon => 'À faire bientôt';

  @override
  String get choreStatusScheduled => 'Planifiée';

  @override
  String get choreStatusPending => 'En attente';

  @override
  String get choreYourTurn => 'À ton tour';

  @override
  String choreSomeonesTurn(String name) {
    return 'Au tour de $name';
  }

  @override
  String get choreRefreshFailed =>
      'Échec de l\'actualisation. Affichage des tâches enregistrées.';

  @override
  String choreDoneLast30Days(num count) {
    return '$count faites, 30 derniers jours';
  }

  @override
  String get choreYoureClear => 'Tu es tranquille';

  @override
  String choreHeroDescSingular(num count) {
    return '$count tâche t\'attend.';
  }

  @override
  String choreHeroDescPlural(num count) {
    return '$count tâches t\'attendent.';
  }

  @override
  String choreMeLabel(num count) {
    return 'Moi ($count)';
  }

  @override
  String choreEveryoneLabel(num count) {
    return 'Tous ($count)';
  }

  @override
  String get choreHowItSplits => 'Répartition';

  @override
  String get choreHouseAllClear => 'Rien en retard dans la maison';

  @override
  String choreHouseOverdue(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tâches en retard dans la maison',
      one: '1 tâche en retard dans la maison',
    );
    return '$_temp0';
  }

  @override
  String choreNextInRotation(String name) {
    return 'ensuite $name';
  }

  @override
  String choreSupplySingular(num count) {
    return '$count fourniture';
  }

  @override
  String choreSupplyPlural(num count) {
    return '$count fournitures';
  }

  @override
  String get choreFrequencyHourly => 'Toutes les heures';

  @override
  String get choreFrequencyDaily => 'Quotidienne';

  @override
  String get choreFrequencyWeekly => 'Hebdomadaire';

  @override
  String get choreFrequencyMonthly => 'Mensuelle';

  @override
  String get choreFrequencyYearly => 'Annuelle';

  @override
  String get choreFrequencyAsNeeded => 'Au besoin';

  @override
  String get choreFrequencyOneOff => 'Ponctuelle';

  @override
  String choreEveryInterval(num interval, String unit) {
    return 'Tous les $interval $unit';
  }

  @override
  String get choreDoneToday => 'Faite aujourd\'hui';

  @override
  String get choreDoneYesterday => 'Faite hier';

  @override
  String choreDoneDaysAgo(num days) {
    return 'Faite il y a $days j';
  }

  @override
  String get choreSkipped => 'Passée';

  @override
  String choreMarkNotDone(String title) {
    return 'Marquer $title comme non faite';
  }

  @override
  String choreMarkDone(String title) {
    return 'Marquer $title comme faite';
  }

  @override
  String get choreAllCaughtUp => 'Tu es à jour';

  @override
  String choreCarryingShare(num my, num total) {
    return 'Tu as $my tâche(s) sur $total ouvertes';
  }

  @override
  String get choreNothingShare => 'Rien pour toi en ce moment';

  @override
  String get choreCreationTitle => 'Ajouter une tâche';

  @override
  String get choreEditTitle => 'Modifier la tâche';

  @override
  String get choreEditSaved => 'Tâche mise à jour';

  @override
  String get choreCreationNameHint => 'Nom de la tâche';

  @override
  String get choreCreationYourRoutines => 'Tes routines';

  @override
  String get choreCreationStartFromRoutine =>
      'Commencer à partir d\'une routine';

  @override
  String get choreCreationSuggestions => 'Suggestions';

  @override
  String get choreCreationZoneLabel => 'Zone';

  @override
  String get choreCreationZoneNone => 'Aucune zone';

  @override
  String get choreCreationZoneManageHint =>
      'Appuyez longuement sur une zone pour la supprimer';

  @override
  String get choreCreationRemoveZoneTitle => 'Supprimer la zone ?';

  @override
  String choreCreationRemoveZoneBody(String zone) {
    return '$zone ne sera plus proposée lors de la création d’une tâche. Les tâches qui l’utilisent déjà la conservent.';
  }

  @override
  String get choreCreationZoneKitchen => 'Cuisine';

  @override
  String get choreCreationZoneBathroom => 'Salle de bain';

  @override
  String get choreCreationZoneLivingRoom => 'Salon';

  @override
  String get choreCreationZoneBedroom => 'Chambre';

  @override
  String get choreCreationZoneOutdoor => 'Extérieur';

  @override
  String get choreCreationZoneShared => 'Partagé';

  @override
  String get choreCreationRepeatsLabel => 'Répétition';

  @override
  String get choreCreationRecurrenceNone => 'Aucune';

  @override
  String get choreCreationRecurrenceHourly => 'Toutes les heures';

  @override
  String get choreCreationRecurrenceDaily => 'Quotidienne';

  @override
  String get choreCreationRecurrenceWeekly => 'Hebdomadaire';

  @override
  String get choreCreationRecurrenceMonthly => 'Mensuelle';

  @override
  String get choreCreationRecurrenceYearly => 'Annuelle';

  @override
  String get choreCreationRecurrenceAdaptive => 'Adaptative';

  @override
  String get choreCreationHintNone =>
      'Une tâche ponctuelle. Elle ne reviendra pas toute seule.';

  @override
  String get choreCreationHintHourly => 'Revient toutes les X heures.';

  @override
  String get choreCreationHintDaily => 'Revient tous les X jours.';

  @override
  String get choreCreationHintWeekly =>
      'Revient chaque semaine les jours que tu choisis.';

  @override
  String get choreCreationHintMonthly => 'Revient chaque mois à la même date.';

  @override
  String get choreCreationHintYearly => 'Revient chaque année à la même date.';

  @override
  String get choreCreationHintAdaptive =>
      'Revient en fonction de la dernière fois qu\'elle a été faite, pas du calendrier.';

  @override
  String get choreCreationIntervalHint => '1';

  @override
  String get choreCreationMoreOptions => 'Plus d\'options';

  @override
  String get choreCreationAssignLabel => 'Qui';

  @override
  String get choreCreationAssignTakeTurns => 'À tour de rôle';

  @override
  String get choreCreationAssignLeastDone => 'Moins faite';

  @override
  String get choreCreationAssignAlphabetical => 'Alphabétique';

  @override
  String get choreCreationAssignRandom => 'Aléatoire';

  @override
  String get choreCreationAssignNoAssignee => 'Sans attribution';

  @override
  String get choreCreationAssignHintTurns =>
      'Passe à la personne suivante à chaque fois.';

  @override
  String get choreCreationAssignHintAlpha =>
      'Suit l\'ordre alphabétique des prénoms.';

  @override
  String get choreCreationAssignHintLeast =>
      'Va à la personne qui l\'a le moins faite.';

  @override
  String get choreCreationAssignHintRandom =>
      'Choisit quelqu\'un au hasard à chaque fois.';

  @override
  String get choreCreationAssignHintNone =>
      'Reste sans attribution. N\'importe qui dans le foyer peut la prendre.';

  @override
  String get choreCreationLogWhenDone => 'Noter quand c\'est fait, sans cocher';

  @override
  String get choreCreationLogWhenDoneHelper =>
      'Enregistre la date sans la marquer comme terminée. Utile pour les tâches dont tu veux garder un historique.';

  @override
  String get choreCreationRollOver => 'Reporter si manquée';

  @override
  String get choreCreationRollOverHelper =>
      'Décale à la prochaine échéance au lieu de s\'accumuler en retard.';

  @override
  String get choreCreationNotesHint =>
      'Notes (optionnel) — étapes, rappels, tout ce qui est utile';

  @override
  String get choreCreationSaveAsRoutine => 'Enregistrer comme routine';

  @override
  String get choreCreationSaveAsRoutineSemantic =>
      'Enregistrer cette tâche comme routine réutilisable';

  @override
  String get choreCreationScanChoreSemantic =>
      'Scanner une tâche via l\'appareil photo';

  @override
  String get choreCreationChoreAdded => 'Tâche ajoutée';

  @override
  String choreCreationChoreAddedNextUp(String assignee) {
    return 'Tâche ajoutée · prochaine : $assignee';
  }

  @override
  String get choreCreationJoinFirst => 'Crée ou rejoins d\'abord un foyer.';

  @override
  String get choreCreationEditRoutine => 'Modifier la routine';

  @override
  String choreCreationEverySingular(String unit) {
    return 'Tous les $unit';
  }

  @override
  String choreCreationEveryPlural(num n, String unit) {
    return 'Tous les $n $unit';
  }

  @override
  String get choreCreationUnitHourSingular => 'heure';

  @override
  String get choreCreationUnitHourPlural => 'heures';

  @override
  String get choreCreationUnitDaySingular => 'jour';

  @override
  String get choreCreationUnitDayPlural => 'jours';

  @override
  String get choreCreationUnitWeekSingular => 'semaine';

  @override
  String get choreCreationUnitWeekPlural => 'semaines';

  @override
  String get choreCreationUnitMonthSingular => 'mois';

  @override
  String get choreCreationUnitMonthPlural => 'mois';

  @override
  String get choreCreationUnitYearSingular => 'an';

  @override
  String get choreCreationUnitYearPlural => 'ans';

  @override
  String get choreDayMon => 'Lun';

  @override
  String get choreDayTue => 'Mar';

  @override
  String get choreDayWed => 'Mer';

  @override
  String get choreDayThu => 'Jeu';

  @override
  String get choreDayFri => 'Ven';

  @override
  String get choreDaySat => 'Sam';

  @override
  String get choreDaySun => 'Dim';

  @override
  String get choreDetailTitle => 'Détails de la tâche';

  @override
  String get choreDetailAssignee => 'À qui le tour';

  @override
  String get choreDetailNextUp => 'Tour suivant';

  @override
  String get choreDetailDue => 'Échéance';

  @override
  String get choreDetailTracked => 'Suivi';

  @override
  String get choreDetailLastDone => 'Dernière fois';

  @override
  String get choreDetailLastBy => 'Dernier par';

  @override
  String get choreDetailAverage => 'Moyenne';

  @override
  String get choreDetailSubtasks => 'Sous-tâches';

  @override
  String get choreDetailNewSubtask => 'Nouvelle sous-tâche';

  @override
  String get choreDetailSupplies => 'Fournitures';

  @override
  String get choreDetailAddSuppliesToList =>
      'Ajouter les fournitures à la liste';

  @override
  String get choreDetailMarkDone => 'Marquer comme faite';

  @override
  String get choreDetailMoveToTomorrow => 'Reporter à demain';

  @override
  String get choreDetailUndoLast => 'Annuler la dernière exécution';

  @override
  String get choreDetailSkipTitle => 'Passer la tâche';

  @override
  String get choreDetailSkipReason => 'Raison (optionnel)';

  @override
  String get choreDetailSkipReasonHint => 'ex. Absent cette semaine';

  @override
  String get choreDetailDeleteTitleDialog => 'Supprimer la tâche';

  @override
  String get choreDetailDeleteBody =>
      'Cela supprimera définitivement cette tâche et son historique.';

  @override
  String get choreDetailDeleteSubtask => 'Supprimer la sous-tâche';

  @override
  String get choreDetailSubtaskMarkNotDone =>
      'Marquer la sous-tâche comme non faite';

  @override
  String get choreDetailSubtaskMarkDone => 'Marquer la sous-tâche comme faite';

  @override
  String get choreLoadTitle => 'Qui fait les tâches';

  @override
  String choreLoadEmpty(num days) {
    return 'Aucune tâche n\'a été terminée ces $days derniers jours. Quand les gens commenceront à cocher des choses, la répartition apparaîtra ici.';
  }

  @override
  String choreLoadCountSingular(num count) {
    return '$count tâche';
  }

  @override
  String choreLoadCountPlural(num count) {
    return '$count tâches';
  }

  @override
  String get recipeAppBarTitle => 'Cuisine';

  @override
  String get recipeSearchLabel => 'Rechercher dans la cuisine';

  @override
  String get recipeSearchHint => 'Recette, étiquette, ingrédient';

  @override
  String get recipeMealPlanTooltip => 'Plan de repas';

  @override
  String get recipeSearchTooltip => 'Rechercher';

  @override
  String get recipeSortLabel => 'Trier les recettes';

  @override
  String get recipeSortNewest => 'Plus récentes';

  @override
  String get recipeSortOldest => 'Plus anciennes';

  @override
  String get recipeSortAZ => 'A-Z';

  @override
  String get recipeAddRecipe => 'Ajouter une recette';

  @override
  String get recipeFailedLoad => 'Impossible de charger la cuisine';

  @override
  String get recipeFailedMore => 'Impossible de charger plus de recettes';

  @override
  String get recipeBuildKitchen => 'Construis ta cuisine';

  @override
  String get recipeBuildKitchenDesc =>
      'Importe des recettes, regroupe des livres de cuisine, planifie des repas et transforme la semaine en liste de courses.';

  @override
  String get recipeNoMatchTitle => 'Aucune recette ne correspond';

  @override
  String get recipeNoMatchDesc =>
      'Essaie une autre recherche ou un autre filtre.';

  @override
  String get recipeShowAllRecipes => 'Afficher toutes les recettes';

  @override
  String recipeMealsPlanned(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count repas prévus cette semaine',
      one: '1 repas prévu cette semaine',
    );
    return '$_temp0';
  }

  @override
  String get recipePlanButton => 'Planifier';

  @override
  String recipeCountLabel(num visible, num total) {
    return '$visible sur $total recettes';
  }

  @override
  String recipeCountLabelAll(num total) {
    return '$total recettes';
  }

  @override
  String get recipeFilterAll => 'Toutes';

  @override
  String get recipeFilterShared => 'Partagées';

  @override
  String get recipeFilterPrivate => 'Privées';

  @override
  String recipeImageSemantics(String title) {
    return 'Image de $title';
  }

  @override
  String recipeMinLabel(num minutes) {
    return '$minutes min';
  }

  @override
  String recipeServesLabel(num servings) {
    return 'Pour $servings pers.';
  }

  @override
  String recipeOpenRecipe(String title) {
    return 'Ouvrir la recette $title';
  }

  @override
  String get recipeAddToList => 'Ajouter à la liste';

  @override
  String get recipeAddOnlyMissing => 'Ajouter seulement ce qui manque';

  @override
  String recipeAddMissingAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles manquants ajoutés',
      one: '1 article manquant ajouté',
      zero: 'Rien ne manque — tout est là',
    );
    return '$_temp0';
  }

  @override
  String get productsTitle => 'Produits';

  @override
  String get productsSearchHint => 'Rechercher des produits';

  @override
  String get productsEmptyTitle => 'Aucun produit pour l\'instant';

  @override
  String get productsEmptyDesc =>
      'Enregistre les produits que tu achètes souvent pour les réutiliser dans tes listes.';

  @override
  String get productsNoResults => 'Aucun produit ne correspond à ta recherche';

  @override
  String get productsAdd => 'Ajouter un produit';

  @override
  String get productsSheetTitle => 'Nouveau produit';

  @override
  String get productsFieldName => 'Nom';

  @override
  String get productsFieldUnit => 'Unité (facultatif)';

  @override
  String get productsFieldBarcode => 'Code-barres (facultatif)';

  @override
  String get productsValidationName => 'Saisis un nom de produit';

  @override
  String get productsCouldNotCreate => 'Impossible de créer le produit';

  @override
  String get productsNoHouseholdDesc =>
      'Rejoins ou crée un foyer pour tenir un catalogue de produits.';

  @override
  String get shoppingLocationsTitle => 'Lieux d\'achat';

  @override
  String get shoppingLocationsEmptyTitle => 'Aucun lieu pour l\'instant';

  @override
  String get shoppingLocationsEmptyDesc =>
      'Nomme les magasins où tu fais tes courses pour organiser tes sorties.';

  @override
  String get shoppingLocationsAdd => 'Ajouter un lieu';

  @override
  String get shoppingLocationsSheetTitle => 'Nouveau lieu';

  @override
  String get shoppingLocationsFieldName => 'Nom';

  @override
  String get shoppingLocationsValidationName => 'Saisis un nom de lieu';

  @override
  String get shoppingLocationsCouldNotCreate => 'Impossible de créer le lieu';

  @override
  String get shoppingLocationsNoHouseholdDesc =>
      'Rejoins ou crée un foyer pour enregistrer des lieux d\'achat.';

  @override
  String get cookbooksTitle => 'Livres de recettes';

  @override
  String get cookbooksButton => 'Livres de recettes';

  @override
  String get cookbooksEmptyTitle => 'Aucun livre de recettes pour l\'instant';

  @override
  String get cookbooksEmptyDesc =>
      'Regroupe tes recettes dans des livres de recettes pour les retrouver plus vite.';

  @override
  String get cookbooksAdd => 'Nouveau livre de recettes';

  @override
  String get cookbooksSheetTitle => 'Nouveau livre de recettes';

  @override
  String get cookbooksRenameSheetTitle => 'Renommer le livre de recettes';

  @override
  String get cookbooksFieldName => 'Nom';

  @override
  String get cookbooksValidationName => 'Saisis un nom de livre de recettes';

  @override
  String get cookbooksCouldNotCreate =>
      'Impossible de créer le livre de recettes';

  @override
  String get cookbooksCouldNotRename =>
      'Impossible de renommer le livre de recettes';

  @override
  String get cookbooksCouldNotDelete =>
      'Impossible de supprimer le livre de recettes';

  @override
  String get cookbooksDeleteTitle => 'Supprimer le livre de recettes ?';

  @override
  String get cookbooksDeleteBody =>
      'Cela supprime le livre de recettes. Tes recettes restent dans ta cuisine.';

  @override
  String cookbooksRecipeCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recettes',
      one: '1 recette',
      zero: 'Aucune recette',
    );
    return '$_temp0';
  }

  @override
  String get cookbooksRename => 'Renommer';

  @override
  String get cookbooksNoHouseholdDesc =>
      'Rejoins ou crée un foyer pour créer des livres de recettes.';

  @override
  String get cookbookDetailEmptyTitle => 'Aucune recette ici pour l\'instant';

  @override
  String get cookbookDetailEmptyDesc =>
      'Ajoute des recettes à ce livre de recettes pour les voir ici.';

  @override
  String get cookbookDetailAddRecipes => 'Ajouter des recettes';

  @override
  String get cookbookAddRecipesSheetTitle => 'Ajouter des recettes';

  @override
  String get cookbookAddRecipesEmpty =>
      'Toutes tes recettes sont déjà dans ce livre de recettes.';

  @override
  String get cookbookRemoveRecipe => 'Retirer du livre de recettes';

  @override
  String get cookbookRecipeRemoved => 'Retirée du livre de recettes';

  @override
  String cookbookRecipesAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recettes ajoutées',
      one: '1 recette ajoutée',
    );
    return '$_temp0';
  }

  @override
  String recipeSharedPrivate(num shared, num private) {
    return '$shared partagées · $private privées';
  }

  @override
  String recipeCookbooksLabel(num count) {
    return ' · $count livres de cuisine';
  }

  @override
  String recipeRatingLabel(String rating, num count) {
    return '$rating ($count)';
  }

  @override
  String get recipeCreationTitle => 'Nouvelle recette';

  @override
  String get recipeCreationStepSource => 'Source';

  @override
  String get recipeCreationStepDetails => 'Détails';

  @override
  String get recipeCreationStepContent => 'Contenu';

  @override
  String get recipeCreationStartHeadline => 'Commence ta recette';

  @override
  String get recipeCreationStartSubtitle =>
      'Importe depuis un lien, écris-la toi-même ou scanne une photo.';

  @override
  String get recipeCreationImportURL => 'Importer depuis une URL';

  @override
  String get recipeCreationImportURLDesc =>
      'Colle un lien de recette et on récupère les détails';

  @override
  String get recipeCreationTypeItIn => 'Écrire à la main';

  @override
  String get recipeCreationTypeItInDesc =>
      'Commence avec un titre et ajoute les ingrédients plus tard';

  @override
  String get recipeCreationScanning => 'Scan en cours…';

  @override
  String get recipeCreationScanPhoto => 'Scanner une photo';

  @override
  String get recipeCreationScanPhotoDesc =>
      'Prends en photo une fiche recette ou une page de livre';

  @override
  String get recipeCreationURLInput => 'URL de la recette';

  @override
  String get recipeCreationURLHint => 'https://exemple.com/recette';

  @override
  String get recipeCreationFetching => 'Récupération…';

  @override
  String get recipeCreationFetchDetails => 'Récupérer les détails';

  @override
  String get recipeCreationChooseImage => 'Choisir une image';

  @override
  String recipeCreationSelectImage(num index) {
    return 'Sélectionner l\'image $index';
  }

  @override
  String get recipeCreationTitleInput => 'Titre de la recette';

  @override
  String get recipeCreationTitleHint => 'Crêpes du dimanche';

  @override
  String get recipeCreationDiscardTitle => 'Abandonner la recette ?';

  @override
  String get recipeCreationDiscardBody =>
      'Tu as du contenu non enregistré dans cette recette.';

  @override
  String get recipeCreationKeepEditing => 'Continuer à modifier';

  @override
  String get recipeCreationDiscard => 'Abandonner';

  @override
  String get recipeCreationCouldNotScan => 'Impossible de scanner la recette.';

  @override
  String recipeCreationImported(String parts) {
    return '$parts';
  }

  @override
  String get recipeCreationCouldNotFetch =>
      'Impossible de récupérer les détails depuis ce lien.';

  @override
  String get recipeCreationCreated => 'Recette créée';

  @override
  String get recipeCreationCouldNotCreate => 'Impossible de créer la recette.';

  @override
  String get recipeCreationImportedTitle => 'Recette importée';

  @override
  String recipeCreationFromHost(String host) {
    return 'Recette de $host';
  }

  @override
  String recipeCreationNutrition(String info) {
    return 'Nutrition : $info';
  }

  @override
  String get recipeCreationNextDetails => 'Suivant : détails';

  @override
  String get recipeCreationNextContent => 'Suivant : contenu';

  @override
  String get recipeCreationTitleOverride => 'Modifier le titre';

  @override
  String get recipeCreationNotesInput => 'Notes';

  @override
  String get recipeCreationNotesHint => 'Ce qui rend cette recette mémorable';

  @override
  String get recipeCreationPrepLabel => 'Préparation (min)';

  @override
  String get recipeCreationPrepHint => '10';

  @override
  String get recipeCreationCookLabel => 'Cuisson (min)';

  @override
  String get recipeCreationCookHint => '20';

  @override
  String get recipeCreationServingsLabel => 'Portions';

  @override
  String get recipeCreationServingsHint => '4';

  @override
  String get recipeCreationTagsInput => 'Étiquettes';

  @override
  String get recipeCreationTagsHint => 'rapide, végétarien';

  @override
  String get recipeCreationSaveForHousehold => 'Enregistrer pour le foyer';

  @override
  String get recipeCreationSaveForHouseholdDesc =>
      'Tout le monde dans ce foyer peut trouver et utiliser cette recette.';

  @override
  String get recipeCreationSaveForHouseholdPrivate =>
      'Garde-la privée pour l\'instant. Tu pourras la partager plus tard.';

  @override
  String recipeCreationSharedWithGroups(String names) {
    return 'Partagé avec $names';
  }

  @override
  String get recipeCreationIngredients => 'Ingrédients';

  @override
  String get recipeCreationIngredientsHelper =>
      'Ajoute un ingrédient par ligne.';

  @override
  String get recipeCreationAddIngredient => 'Ajouter un ingrédient';

  @override
  String get recipeCreationIngredientHint => '200g de farine';

  @override
  String get recipeCreationSteps => 'Étapes';

  @override
  String get recipeCreationStepsHelper =>
      'Garde chaque étape assez courte pour la suivre en cuisinant.';

  @override
  String get recipeCreationAddStep => 'Ajouter une étape';

  @override
  String get recipeCreationStepHint => 'Mélanger la pâte';

  @override
  String get recipeCreationNutritionInput => 'Nutrition';

  @override
  String get recipeCreationNutritionHint =>
      '520 kcal, 24g protéines, riche en fibres';

  @override
  String get recipeCreationCreating => 'Création…';

  @override
  String get recipeCreationCreateRecipe => 'Créer la recette';

  @override
  String recipeCreationStepLabel(String type) {
    return '$type';
  }

  @override
  String recipeCreationRemoveItem(String type, num index) {
    return 'Retirer $type $index';
  }

  @override
  String recipeCreationStepSemantics(
      num index, num total, String label, String status) {
    return 'Étape $index sur $total, $label, $status';
  }

  @override
  String get recipeDetailTitle => 'Recette';

  @override
  String get recipeDetailDeleteTooltip => 'Supprimer la recette';

  @override
  String get recipeDetailAddToList => 'Ajouter à la liste';

  @override
  String get recipeDetailCook => 'Cuisson';

  @override
  String get recipeDetailCouldNotLoad => 'Impossible de charger la recette';

  @override
  String get recipeDetailDeleteTitle => 'Supprimer la recette';

  @override
  String get recipeDetailDeleteBody =>
      'Cela supprimera définitivement cette recette. Cette action est irréversible.';

  @override
  String get recipeDetailSharedLabel => 'Partagée';

  @override
  String get recipeDetailPrivateLabel => 'Privée';

  @override
  String recipeDetailBy(String author) {
    return 'Par $author';
  }

  @override
  String get recipeDetailPrep => 'Préparation';

  @override
  String get recipeDetailServings => 'Portions';

  @override
  String get recipeDetailUpdated => 'Mise à jour';

  @override
  String get recipeDetailNotSet => 'Non défini';

  @override
  String get recipeDetailNutrition => 'Nutrition';

  @override
  String get recipeDetailEquipment => 'Équipement';

  @override
  String get recipeDetailIngredients => 'Ingrédients';

  @override
  String get recipeDetailSteps => 'Étapes';

  @override
  String get recipeDetailWatchVideo => 'Voir la vidéo';

  @override
  String get recipeDetailWatchVideoSemantics => 'Voir la vidéo de la recette';

  @override
  String get recipeDetailViewOriginal => 'Voir la recette originale';

  @override
  String get recipeDetailViewOriginalSemantics =>
      'Voir la recette originale dans le navigateur';

  @override
  String get cookModeCouldNotLoad => 'Impossible de charger la recette';

  @override
  String get cookModeClose => 'Fermer';

  @override
  String get cookModeServings => 'Portions';

  @override
  String get cookModeDecreaseServings => 'Diminuer les portions';

  @override
  String get cookModeIncreaseServings => 'Augmenter les portions';

  @override
  String get cookModeStartCooking => 'Commencer à cuisiner';

  @override
  String get cookModeGathered => 'rassemblé';

  @override
  String get cookModeNotGathered => 'non rassemblé';

  @override
  String cookModeStepOf(num step, num total) {
    return 'Étape $step sur $total';
  }

  @override
  String get cookModeExitTooltip => 'Quitter le mode cuisine';

  @override
  String get cookModeTimerDone => 'Minuteur terminé !';

  @override
  String get cookModeDoneArrow => 'Fait →';

  @override
  String get cookModeFinish => 'Terminer';

  @override
  String cookModeStepLabel(num number) {
    return 'Étape $number';
  }

  @override
  String cookModeStepDone(num number) {
    return 'Étape $number terminée. Appuie pour revoir';
  }

  @override
  String cookModeCurrentStep(num number) {
    return 'Étape en cours $number';
  }

  @override
  String cookModeStepJump(num number, String description) {
    return 'Étape $number : $description. Appuie pour aller à cette étape';
  }

  @override
  String cookModeBackToStep(num step) {
    return 'Retour à l\'étape $step';
  }

  @override
  String get cookModeShowIngredients => 'Afficher les ingrédients';

  @override
  String get cookModeIngredients => 'Ingrédients';

  @override
  String get cookModeFinished => 'Terminé — beau travail';

  @override
  String get cookModeFinishCooking => 'Terminer la cuisson';

  @override
  String get cookModeAdvanceStep => 'Fait, passer à l\'étape suivante';

  @override
  String get expenseAppBarTitle => 'Argent';

  @override
  String get expenseScanReceiptTooltip => 'Scanner un reçu';

  @override
  String get expenseRecurringTooltip => 'Récurrent';

  @override
  String get expenseAddExpense => 'Ajouter une dépense';

  @override
  String get expenseYouAreOwed => 'On te doit';

  @override
  String get expenseYouOwe => 'Tu dois';

  @override
  String get expenseAllSquare => 'Tout est réglé';

  @override
  String expenseSuggestedPayments(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count paiements suggérés',
      one: '$count paiement suggéré',
    );
    return '$_temp0 pour équilibrer';
  }

  @override
  String expenseOpenBalances(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count balances ouvertes',
      one: '$count balance ouverte',
    );
    return '$_temp0 dans le foyer';
  }

  @override
  String get expenseNoOneOwes =>
      'Personne ne doit rien à personne pour le moment';

  @override
  String get expenseTabTimeline => 'Chronologie';

  @override
  String get expenseTabSettlements => 'Règlements';

  @override
  String get expenseToday => 'Aujourd\'hui';

  @override
  String get expenseYesterday => 'Hier';

  @override
  String get expenseNoExpensesTitle => 'Pas encore de dépenses';

  @override
  String get expenseNoExpensesDesc => 'Suis les frais partagés avec ton foyer.';

  @override
  String get expenseAddFirstExpense => 'Ajouter une première dépense';

  @override
  String get expenseLoadError =>
      'Impossible de charger les dépenses. Vérifie ta connexion.';

  @override
  String get expenseLoadMoreError => 'Impossible de charger plus de dépenses.';

  @override
  String expensePaidBy(String payer) {
    return 'Payé par $payer';
  }

  @override
  String expenseConvertedAmount(String amount) {
    return '≈ $amount';
  }

  @override
  String get expenseDeleteTitle => 'Supprimer la dépense';

  @override
  String get expenseDeleteBody =>
      'Cela supprimera définitivement cette dépense et tous les reçus associés. Cette action est irréversible.';

  @override
  String get expenseSettlementRecorded =>
      'Règlement enregistré – en attente de confirmation';

  @override
  String get expenseSettlementFailed =>
      'Impossible d\'enregistrer le règlement.';

  @override
  String get expenseSettlementNeedsYou => 'Nécessite ta confirmation';

  @override
  String get expenseSettlementWaiting => 'En attente de confirmation';

  @override
  String get expenseSettlementHistory => 'Règlements récents';

  @override
  String expenseSettlementRow(String from, String to) {
    return '$from a payé $to';
  }

  @override
  String get expenseSettlementConfirmAction => 'Confirmer';

  @override
  String get expenseSettlementDeclineAction => 'Refuser';

  @override
  String get expenseSettlementCancelAction => 'Annuler la demande';

  @override
  String get expenseSettlementStatusConfirmed => 'Confirmé';

  @override
  String get expenseSettlementStatusDeclined => 'Refusé';

  @override
  String get expenseSettlementResponseFailed =>
      'Impossible de mettre à jour le règlement.';

  @override
  String get expenseSettlementCancelFailed =>
      'Impossible d\'annuler le règlement.';

  @override
  String get expenseSuggestedPaymentsTitle => 'Paiements suggérés';

  @override
  String get expenseSuggestedPaymentsDesc =>
      'Calculé à partir de chaque dépense, partage et règlement enregistré dans ce foyer.';

  @override
  String get expenseAllSettled => 'Tout est réglé !';

  @override
  String get expenseNoOneOwesRight =>
      'Personne ne doit rien à personne pour le moment.';

  @override
  String get expenseSameAccount => 'Même compte';

  @override
  String get expenseFrom => 'De';

  @override
  String get expenseTo => 'À';

  @override
  String get expenseRecordHelper =>
      'Enregistre ce règlement après que le paiement a été effectué.';

  @override
  String get expenseRecording => 'Enregistrement...';

  @override
  String get expenseRecordSettlement => 'Enregistrer le règlement';

  @override
  String get expenseBalances => 'Balances';

  @override
  String expenseBalancesOpen(num count) {
    return '$count ouvertes';
  }

  @override
  String get expenseExpandBalances => 'Afficher les balances';

  @override
  String get expenseCollapseBalances => 'Masquer les balances';

  @override
  String get expenseNoBalances =>
      'Pas encore de balances. Ajoute une dépense avec des partages pour démarrer le livre de comptes.';

  @override
  String get expenseIsOwed => 'a une créance sur';

  @override
  String get expenseOwes => 'doit';

  @override
  String get expenseSettled => 'réglé';

  @override
  String get recurringAppBarTitle => 'Récurrent';

  @override
  String get recurringAddRecurring => 'Ajouter une dépense récurrente';

  @override
  String get recurringAddRecurringTooltip => 'Ajouter une dépense récurrente';

  @override
  String get recurringNoRecurringTitle => 'Pas de dépenses récurrentes';

  @override
  String get recurringNoRecurringDesc =>
      'Ajoute une dépense récurrente pour suivre les paiements réguliers';

  @override
  String get recurringAddExpense => 'Ajouter une dépense';

  @override
  String get recurringPauseTooltip => 'Mettre en pause';

  @override
  String get recurringResumeTooltip => 'Reprendre';

  @override
  String get recurringDeleteTooltip => 'Supprimer';

  @override
  String recurringNextDate(String date) {
    return 'Prochain : $date';
  }

  @override
  String get recurringDeleteTitle => 'Supprimer la dépense récurrente';

  @override
  String get recurringDeleteBody =>
      'Cela empêchera la création de futures dépenses.';

  @override
  String get recurringFrequencyDaily => 'Quotidienne';

  @override
  String get recurringFrequencyWeekly => 'Hebdomadaire';

  @override
  String get recurringFrequencyBiweekly => 'Toutes les 2 semaines';

  @override
  String get recurringFrequencyMonthly => 'Mensuelle';

  @override
  String get recurringFrequencyQuarterly => 'Trimestrielle';

  @override
  String get recurringFrequencyYearly => 'Annuelle';

  @override
  String get recurringSheetTitle => 'Ajouter une dépense récurrente';

  @override
  String get recurringSheetDescription => 'Description';

  @override
  String get recurringSheetAmount => 'Montant';

  @override
  String get recurringSheetFrequency => 'Fréquence';

  @override
  String get recurringSheetPayer => 'Payeur';

  @override
  String get recurringValidationDesc => 'Saisis une description.';

  @override
  String get recurringValidationAmount => 'Saisis un montant.';

  @override
  String get recurringValidationPayer => 'Choisis un payeur.';

  @override
  String get recurringValidationAmountPositive =>
      'Saisis un montant valide supérieur à zéro.';

  @override
  String get recurringNoHouseholdDesc =>
      'Rejoins ou crée un foyer pour gérer les dépenses récurrentes';

  @override
  String get listAppBarTitle => 'Listes';

  @override
  String get listShoppingTripTooltip => 'Courses';

  @override
  String get listSearchLabel => 'Rechercher dans les listes';

  @override
  String get listSearchHint => 'Nom, ex. courses';

  @override
  String get listScanTooltip => 'Scanner un reçu ou une liste';

  @override
  String get listSortLabel => 'Trier';

  @override
  String get listSortNewest => 'Plus récentes';

  @override
  String get listSortOldest => 'Plus anciennes';

  @override
  String get listSortAZ => 'A–Z';

  @override
  String get listSortMostItems => 'Plus d\'éléments';

  @override
  String get listSortGridView => 'Vue grille';

  @override
  String get listNewList => 'Nouvelle liste';

  @override
  String get listFilterAll => 'Toutes';

  @override
  String get listFilterShopping => 'Courses';

  @override
  String get listFilterTodo => 'Tâches';

  @override
  String get listFilterCustom => 'Personnalisé';

  @override
  String get listEmptyShopping => 'Pas de listes de courses';

  @override
  String get listEmptyTodo => 'Pas de listes de tâches';

  @override
  String get listEmptyCustom => 'Pas de listes personnalisées';

  @override
  String get listEmptyAll => 'Pas encore de listes';

  @override
  String get listEmptyShoppingDesc =>
      'Idéal pour les courses, la préparation des repas, les courses du week-end.';

  @override
  String get listEmptyTodoDesc => 'Tâches, corvées, tout ce qui se coche.';

  @override
  String get listEmptyCustomDesc => 'Forme libre — ta liste, tes règles.';

  @override
  String get listEmptyAllDesc =>
      'Ajoute des lignes dans une liste ; les premières apparaissent en aperçu sur sa carte.';

  @override
  String get listCreateShopping => 'Créer une liste de courses';

  @override
  String get listCreateTodo => 'Créer une liste de tâches';

  @override
  String get listCreateCustom => 'Créer une liste personnalisée';

  @override
  String get listCreateFirst => 'Créer ta première liste';

  @override
  String listNoMatch(String query) {
    return 'Aucune liste ne correspond à « $query »';
  }

  @override
  String get listSearchDesc =>
      'Les noms et les éléments de liste sont recherchés.';

  @override
  String get listRenameTitle => 'Renommer la liste';

  @override
  String get listCouldNotRename => 'Impossible de renommer la liste.';

  @override
  String get listDeleteTitle => 'Supprimer la liste';

  @override
  String get listDeleteBody =>
      'Cela supprimera définitivement cette liste et tous ses éléments.';

  @override
  String get listCouldNotDelete => 'Impossible de supprimer la liste.';

  @override
  String listAddItemTo(String name) {
    return 'Ajouter un élément à $name';
  }

  @override
  String get listItemName => 'Nom de l\'élément';

  @override
  String get listCouldNotAddItem => 'Impossible d\'ajouter l\'élément.';

  @override
  String get listQuickAddItemTooltip => 'Ajout rapide';

  @override
  String listQuickAddItemSemantics(String name) {
    return 'Ajout rapide à $name';
  }

  @override
  String get listOptionsTooltip => 'Options de la liste';

  @override
  String listSharedWith(String name) {
    return 'Partagé avec $name';
  }

  @override
  String listDetailEditName(String name) {
    return 'Modifier le nom de la liste, $name';
  }

  @override
  String get listDetailCloseSearch => 'Fermer la recherche';

  @override
  String get listDetailSearchTooltip => 'Rechercher';

  @override
  String get listDetailFilterLabel => 'Filtrer les éléments';

  @override
  String get listDetailFilterHint => 'Nom, ex. lait';

  @override
  String get listDetailAllCheckedOff => 'Tout est coché';

  @override
  String get listDetailClearChecked => 'Effacer les éléments cochés';

  @override
  String get listDetailCheckedOff => 'Cochés';

  @override
  String get listDetailNothingHere => 'Rien ici pour l\'instant';

  @override
  String get listDetailNothingHereDesc =>
      'Photographie une liste manuscrite, une note sur le frigo ou une capture d\'écran. On extrait les éléments.';

  @override
  String get listDetailScanThisList => 'Scanner cette liste';

  @override
  String get listDetailTypeItem => 'Saisir un élément';

  @override
  String get listDetailNoMatch => 'Aucun élément ne correspond à ton filtre';

  @override
  String get listDetailCouldNotLoad => 'Impossible de charger la liste.';

  @override
  String get listDetailCouldNotUpdate =>
      'Impossible de mettre à jour. Réessaie.';

  @override
  String get listDetailCouldNotAddItem =>
      'Impossible d\'ajouter l\'élément. Réessaie.';

  @override
  String get listDetailCouldNotClear =>
      'Impossible d\'effacer les éléments. Réessaie.';

  @override
  String listDetailItemDeleted(String name) {
    return '$name supprimé';
  }

  @override
  String get listDetailCouldNotRestore => 'Impossible de restaurer l\'élément.';

  @override
  String get listDetailCouldNotReorder =>
      'Impossible de réorganiser les éléments. Réessaie.';

  @override
  String listDetailItemsAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments ajoutés à la liste',
      one: '1 élément ajouté à la liste',
    );
    return '$_temp0';
  }

  @override
  String get listDetailCouldNotStartScan =>
      'Impossible de lancer le scan. Réessaie.';

  @override
  String get listDetailSetPrice => 'Définir le prix';

  @override
  String get listDetailPriceInput => 'Prix';

  @override
  String get listDetailPriceHint => '0,00';

  @override
  String get listDetailCouldNotSetPrice => 'Impossible de définir le prix.';

  @override
  String get listDetailClearTitle => 'Vider la liste';

  @override
  String listDetailClearBody(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'les $count éléments',
      one: 'l\'élément',
    );
    return 'Cela supprimera $_temp0. Cette action est irréversible.';
  }

  @override
  String get listDetailClearConfirm => 'Vider la liste';

  @override
  String get listDetailArchiveTitle => 'Archiver la liste';

  @override
  String get listDetailArchiveBody => 'Cette liste sera masquée de ton foyer.';

  @override
  String get listDetailFailedArchive => 'Impossible d\'archiver la liste.';

  @override
  String get listDetailDeleteTitle => 'Supprimer la liste';

  @override
  String get listDetailDeleteBody =>
      'Cela supprimera définitivement cette liste et tous ses éléments. Cette action est irréversible.';

  @override
  String get listDetailCouldNotDelete => 'Impossible de supprimer la liste.';

  @override
  String get listDetailExpenseGenerated => 'Dépense générée';

  @override
  String get listDetailCouldNotLoadCostSummary =>
      'Impossible de charger le récapitulatif des coûts.';

  @override
  String get listDetailCouldNotAddPhoto => 'Impossible d\'ajouter la photo.';

  @override
  String get listDetailCouldNotRemovePhoto => 'Impossible de retirer la photo.';

  @override
  String get listDetailListImage => 'Image de la liste';

  @override
  String get listDetailCheckAll => 'Tout cocher';

  @override
  String get listDetailUncheckAll => 'Tout décocher';

  @override
  String get listDetailCostSummary => 'Récapitulatif des coûts';

  @override
  String get listDetailScanList => 'Scanner la liste';

  @override
  String get calendarAppBarTitle => 'Calendrier';

  @override
  String get calendarViewWeek => 'Semaine';

  @override
  String get calendarViewMonth => 'Mois';

  @override
  String get calendarViewAgenda => 'Agenda';

  @override
  String get calendarWeekView => 'Vue semaine';

  @override
  String get calendarMonthView => 'Vue mois';

  @override
  String get calendarAgendaView => 'Vue agenda';

  @override
  String get calendarPreviousWeek => 'Semaine précédente';

  @override
  String get calendarNextWeek => 'Semaine suivante';

  @override
  String get calendarPreviousMonth => 'Mois précédent';

  @override
  String get calendarNextMonth => 'Mois suivant';

  @override
  String get calendarMonthJanuary => 'Janvier';

  @override
  String get calendarMonthFebruary => 'Février';

  @override
  String get calendarMonthMarch => 'Mars';

  @override
  String get calendarMonthApril => 'Avril';

  @override
  String get calendarMonthMay => 'Mai';

  @override
  String get calendarMonthJune => 'Juin';

  @override
  String get calendarMonthJuly => 'Juillet';

  @override
  String get calendarMonthAugust => 'Août';

  @override
  String get calendarMonthSeptember => 'Septembre';

  @override
  String get calendarMonthOctober => 'Octobre';

  @override
  String get calendarMonthNovember => 'Novembre';

  @override
  String get calendarMonthDecember => 'Décembre';

  @override
  String get calendarShortMon => 'Lun';

  @override
  String get calendarShortTue => 'Mar';

  @override
  String get calendarShortWed => 'Mer';

  @override
  String get calendarShortThu => 'Jeu';

  @override
  String get calendarShortFri => 'Ven';

  @override
  String get calendarShortSat => 'Sam';

  @override
  String get calendarShortSun => 'Dim';

  @override
  String get calendarWeekdayMonday => 'Lundi';

  @override
  String get calendarWeekdayTuesday => 'Mardi';

  @override
  String get calendarWeekdayWednesday => 'Mercredi';

  @override
  String get calendarWeekdayThursday => 'Jeudi';

  @override
  String get calendarWeekdayFriday => 'Vendredi';

  @override
  String get calendarWeekdaySaturday => 'Samedi';

  @override
  String get calendarWeekdaySunday => 'Dimanche';

  @override
  String get calendarToday => 'Aujourd\'hui';

  @override
  String calendarDayLabel(num day) {
    return 'Jour $day';
  }

  @override
  String calendarDayEvents(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count événements',
      one: '1 événement',
    );
    return '$_temp0';
  }

  @override
  String get calendarDayMenuHint => 'Ouvre les options du jour';

  @override
  String get calendarNothingPlanned => 'Rien de prévu';

  @override
  String get calendarNothingAhead => 'Rien à venir';

  @override
  String get calendarNothingAheadDesc =>
      'Les tâches à venir, les plans de repas et les dépenses récurrentes apparaîtront ici.';

  @override
  String get calendarAddChore => 'Ajouter une tâche';

  @override
  String get calendarAddExpense => 'Ajouter une dépense';

  @override
  String get calendarViewInWeek => 'Voir dans la semaine';

  @override
  String get calendarEventMeal => 'Repas';

  @override
  String get calendarEventChore => 'Tâche';

  @override
  String get calendarEventRecurring => 'Récurrent';

  @override
  String get calendarEventExpense => 'Dépense';

  @override
  String get calendarEventReminder => 'Rappel';

  @override
  String calendarServingsPpl(num servings) {
    return '$servings pers. ';
  }

  @override
  String get calendarNoHouseholdDesc =>
      'Rejoins ou crée un foyer pour voir le calendrier';

  @override
  String get calendarCreateHousehold => 'Créer un foyer';

  @override
  String calendarWeekHeader(String weekStart, String weekEnd) {
    return '$weekStart – $weekEnd';
  }

  @override
  String calendarMonthHeader(String month, num year) {
    return '$month $year';
  }

  @override
  String get mealPlanAppBarTitle => 'Plan de repas';

  @override
  String get mealPlanGenerateShoppingList => 'Générer une liste de courses';

  @override
  String get mealPlanPreviousWeek => 'Semaine précédente';

  @override
  String get mealPlanNextWeek => 'Semaine suivante';

  @override
  String get mealPlanBreakfast => 'Petit-déjeuner';

  @override
  String get mealPlanLunch => 'Déjeuner';

  @override
  String get mealPlanDinner => 'Dîner';

  @override
  String get mealPlanAddMeal => 'Ajouter un repas';

  @override
  String get mealPlanRecipeFallback => 'Recette';

  @override
  String mealPlanServings(num servings) {
    return '${servings}p';
  }

  @override
  String mealPlanShoppingListCreated(num count) {
    return 'Liste de courses créée avec $count éléments';
  }

  @override
  String get mealPlanTrackCosts => 'Suivre les coûts';

  @override
  String get mealPlanCouldNotAdd => 'Impossible d\'ajouter le repas.';

  @override
  String get mealPlanCouldNotRemove => 'Impossible de retirer le repas.';

  @override
  String get mealPlanCouldNotUpdate => 'Impossible de modifier le repas.';

  @override
  String get mealPlanPickRecipe => 'Choisir une recette';

  @override
  String get mealPlanCouldNotLoadRecipes =>
      'Impossible de charger les recettes';

  @override
  String get mealPlanNoRecipes => 'Pas encore de recettes';

  @override
  String get mealPlanAddRecipesDesc =>
      'Ajoute des recettes pour planifier les repas';

  @override
  String get mealPlanSearchRecipes => 'Rechercher des recettes...';

  @override
  String mealPlanNoMatch(String query) {
    return 'Aucune recette ne correspond à « $query »';
  }

  @override
  String get mealPlanServingsSheet => 'Portions';

  @override
  String get mealPlanFewerServings => 'Moins de portions';

  @override
  String get mealPlanMoreServings => 'Plus de portions';

  @override
  String mealPlanOpenRecipe(String slot) {
    return 'Ouvrir la recette pour $slot';
  }

  @override
  String mealPlanAddMealFor(String slot) {
    return 'Ajouter un repas pour $slot';
  }

  @override
  String get accountAppBarTitle => 'Toi';

  @override
  String get accountFailedLoadProfile =>
      'Impossible de charger le profil. Réessaie.';

  @override
  String get accountFailedSaveName => 'Impossible d\'enregistrer le nom';

  @override
  String get accountEditYourName => 'Modifier ton nom';

  @override
  String get accountChangePassword => 'Changer le mot de passe';

  @override
  String get accountFillPasswordFields =>
      'Remplis tous les champs du mot de passe.';

  @override
  String get accountPasswordMinLength =>
      'Le nouveau mot de passe doit contenir au moins 8 caractères.';

  @override
  String get accountPasswordsMismatch =>
      'Les nouveaux mots de passe ne correspondent pas.';

  @override
  String get accountPasswordChanged => 'Mot de passe modifié';

  @override
  String get accountCurrentPassword => 'Mot de passe actuel';

  @override
  String get accountNewPassword => 'Nouveau mot de passe';

  @override
  String get accountConfirmPassword => 'Confirmer le nouveau mot de passe';

  @override
  String get accountChangePasswordButton => 'Changer le mot de passe';

  @override
  String get accountTermsTitle => 'Conditions d\'utilisation';

  @override
  String get accountTermsBody =>
      'mitlist est fourni par tropicalthink selon les Conditions d\'utilisation publiées sur mitlist.me/terms. Les foyers de quatre membres au plus utilisent le service hébergé gratuitement ; les foyers plus grands ont besoin d\'un abonnement Premium. Utilise le service de manière responsable et respecte la vie privée des personnes avec qui tu partages un foyer.';

  @override
  String get accountDeleteAccount => 'Supprimer le compte';

  @override
  String get accountDeleteAccountBody =>
      'Cela supprimera définitivement ton compte et toutes les données associées. Cette action est irréversible.';

  @override
  String get accountLogOut => 'Se déconnecter';

  @override
  String get accountDeleteAccountButton => 'Supprimer le compte';

  @override
  String get accountHouseholdSection => 'Foyer';

  @override
  String accountSwitchToHousehold(String name) {
    return 'Passer à $name';
  }

  @override
  String get accountNotificationInbox => 'Boîte de notifications';

  @override
  String get accountNotificationPreferences => 'Préférences de notifications';

  @override
  String get accountAppearance => 'Apparence';

  @override
  String get accountAppearanceSystem => 'Système';

  @override
  String get accountAppearanceLight => 'Clair';

  @override
  String get accountAppearanceDark => 'Sombre';

  @override
  String get accountChangePasswordRow => 'Changer le mot de passe';

  @override
  String get accountVersion => 'Version';

  @override
  String get accountTermsRow => 'Conditions d\'utilisation';

  @override
  String get accountOpenDataRow => 'Données ouvertes';

  @override
  String get accountSupportRow => 'Soutenir mitlist';

  @override
  String get accountServerRow => 'Serveur';

  @override
  String get accountOpenDataTitle => 'Attribution des données ouvertes';

  @override
  String get accountOpenDataBody =>
      'Certaines marques de produits alimentaires proviennent d\'Open Food Facts (openfoodfacts.org), utilisées sous la licence Open Database License (ODbL) v1.0. La liste de marques dérivée est conservée séparément des données propres à mitlist.';

  @override
  String get accountGuestTitle => 'Tu utilises un compte invité';

  @override
  String get accountGuestDesc =>
      'Crée un compte complet pour garder tes données définitivement et accéder à toutes les fonctionnalités.';

  @override
  String get accountCreateFullAccount => 'Créer un compte complet';

  @override
  String get accountExportCSV => 'Exporter les dépenses (CSV)';

  @override
  String get accountShareJSON => 'Partager les dépenses (JSON)';

  @override
  String get accountCopyJSON => 'Copier les dépenses (JSON)';

  @override
  String get accountExportCalendar => 'Exporter le calendrier (.ics)';

  @override
  String get accountJSONCopied =>
      'JSON des dépenses copié dans le presse-papier';

  @override
  String get accountCreateAccountTitle => 'Créer ton compte';

  @override
  String get accountFillAllFields => 'Remplis tous les champs.';

  @override
  String get accountYourName => 'Ton nom';

  @override
  String get accountYourNameHint => 'ex. Alex Dupont';

  @override
  String get accountEmail => 'Email';

  @override
  String get accountEmailHint => 'toi@exemple.com';

  @override
  String get accountPassword => 'Mot de passe';

  @override
  String get accountCreatingAccount => 'Création du compte…';

  @override
  String get accountCreateAccount => 'Créer le compte';

  @override
  String get accountCreatedWelcome => 'Compte créé. Bienvenue !';

  @override
  String get notificationsAppBarTitle => 'Notifications';

  @override
  String get notificationsMarkAllRead => 'Tout marquer comme lu';

  @override
  String get notificationsFailedLoad =>
      'Impossible de charger les notifications.';

  @override
  String get notificationsFailedLoadMore =>
      'Impossible de charger plus de notifications.';

  @override
  String get notificationsFailedMarkAllRead =>
      'Impossible de tout marquer comme lu.';

  @override
  String get notificationsFailedMarkRead => 'Impossible de marquer comme lu.';

  @override
  String get notificationsNoHouseholdDesc =>
      'Crée ou rejoins un foyer pour recevoir des notifications.';

  @override
  String get notificationsNoNotifications => 'Pas encore de notifications';

  @override
  String get notificationsNoNotificationsDesc =>
      'Quand quelqu\'un ajoute une tâche, partage une facture ou te mentionne, ça apparaîtra ici.';

  @override
  String notificationsUnreadLabel(String title) {
    return 'Non lu, $title';
  }

  @override
  String get notificationsSectionToday => 'Aujourd’hui';

  @override
  String get notificationsSectionYesterday => 'Hier';

  @override
  String get notificationsSectionEarlier => 'Plus ancien';

  @override
  String get notificationsTimeNow => 'à l’instant';

  @override
  String notificationsTimeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String notificationsTimeHours(int hours) {
    return '$hours h';
  }

  @override
  String notificationsTimeDays(int days) {
    return '$days j';
  }

  @override
  String notificationsUnreadCount(int count) {
    return '$count nouvelles';
  }

  @override
  String get notifPrefAppBarTitle => 'Préférences de notifications';

  @override
  String get notifPrefFailedLoad =>
      'Impossible de charger les préférences de notifications.';

  @override
  String get notifPrefFailedSave =>
      'Impossible d’enregistrer cette préférence. Vérifiez votre connexion et réessayez.';

  @override
  String get notifPrefNoHouseholdDesc =>
      'Rejoins ou crée un foyer pour configurer les préférences de notifications.';

  @override
  String get notifPrefNoPreferences => 'Pas encore de préférences';

  @override
  String get notifPrefNoPreferencesDesc =>
      'Les préférences sont créées quand tu rejoins un foyer. Si tu viens de rejoindre, elles devraient apparaître bientôt.';

  @override
  String get notifPrefGroupName => 'Notifications';

  @override
  String get notifPrefChoreDueReminders => 'Rappels de tâches à échéance';

  @override
  String get notifPrefChoreDueRemindersDesc =>
      'Quand une tâche approche de son échéance';

  @override
  String get notifPrefChoreDueDayOf => 'Tâche due le jour même';

  @override
  String get notifPrefChoreDueDayOfDesc => 'Le jour où une tâche est due';

  @override
  String get notifPrefListItemAdded => 'Élément ajouté à une liste';

  @override
  String get notifPrefListItemAddedDesc =>
      'Quand quelqu\'un ajoute à une liste partagée';

  @override
  String get notifPrefExpenseCreated => 'Activité financière';

  @override
  String get notifPrefExpenseCreatedDesc =>
      'Dépenses, frais récurrents et règlements';

  @override
  String get notifPrefMealPlanChanged => 'Plan de repas modifié';

  @override
  String get notifPrefMealPlanChangedDesc =>
      'Quand le plan de repas est mis à jour';

  @override
  String get notifPrefWeeklyDigest => 'Résumé hebdomadaire';

  @override
  String get notifPrefWeeklyDigestDesc => 'Un résumé de l\'activité du foyer';

  @override
  String get notifPrefPinwallReminders => 'Rappels Pinwall';

  @override
  String get notifPrefPinwallRemindersDesc =>
      'Quand quelqu\'un épingle un rappel pour plus tard';

  @override
  String get notifPrefPushNotifications => 'Notifications push';

  @override
  String get notifPrefPushNotificationsDesc =>
      'Recevoir les notifications sur cet appareil';

  @override
  String get notifPrefEmailNotifications => 'Notifications par e-mail';

  @override
  String get notifPrefEmailNotificationsDesc =>
      'Recevoir les rappels importants par e-mail';

  @override
  String get shoppingTripAppBarTitle => 'Courses';

  @override
  String get shoppingTripChooseStore => 'Choisir le magasin';

  @override
  String get shoppingTripNoLists => 'Pas encore de listes';

  @override
  String get shoppingTripNoListsDesc =>
      'Crée une liste de courses pour commencer';

  @override
  String get shoppingTripAllCaughtUp => 'Tout est réglé';

  @override
  String get shoppingTripAllCaughtUpDesc =>
      'Aucun élément ouvert dans tes listes. Ajoute des éléments à une liste pour les voir ici.';

  @override
  String get shoppingTripSortedByAisles => 'Trié par rayons du magasin';

  @override
  String shoppingTripSortedByStoreAisles(String store) {
    return 'Trié par les rayons de $store';
  }

  @override
  String get shoppingTripMarkDone => 'Marquer comme acheté';

  @override
  String shoppingTripBasketBar(num collected, String price) {
    return '/ $collected collectés$price';
  }

  @override
  String shoppingTripItemsWorthDone(String amount) {
    return '$amount d\'articles marqués comme achetés';
  }

  @override
  String get shoppingTripAddExpense => 'Ajouter une dépense';

  @override
  String get shoppingTripStampDone => 'FAIT';

  @override
  String shoppingTripStampItems(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count articles',
      one: '1 article',
    );
    return '$_temp0';
  }

  @override
  String get shoppingTripFallbackList => 'Liste';

  @override
  String shoppingTripMarkNotPurchased(String item) {
    return 'Marquer $item comme non acheté';
  }

  @override
  String shoppingTripMarkPurchased(String item) {
    return 'Marquer $item comme acheté';
  }

  @override
  String get scannerAppBarTitle => 'Scanner';

  @override
  String get scannerShoppingAt => 'Courses à';

  @override
  String get scannerChooseStore => 'Choisis ton magasin';

  @override
  String get scannerHintText =>
      'Scanne un reçu, une liste, une recette,\nou un rappel de tâche';

  @override
  String get scannerAnalyzing => 'Analyse en cours…';

  @override
  String get scannerScanGrocery => 'Scanner une liste de courses';

  @override
  String get scannerScanReceipt => 'Scanner un reçu, une recette ou une tâche';

  @override
  String get scannerAnalyzeThis => 'Analyser cette image';

  @override
  String get scannerTakeOrChoose => 'Prends une photo ou choisis-en une';

  @override
  String get scannerPickDifferent => 'Choisir une autre image';

  @override
  String get scannerScanSheetTitle => 'Scanner une liste de courses';

  @override
  String get scannerAddScanTitle => 'Ajouter un scan';

  @override
  String get scannerTakePhoto => 'Prendre une photo';

  @override
  String get scannerChooseFromGallery => 'Choisir dans la galerie';

  @override
  String get scannerTypeReceipt => 'Reçu';

  @override
  String get scannerTypeShoppingList => 'Liste de courses';

  @override
  String get scannerTypeRecipe => 'Recette';

  @override
  String get scannerTypeChore => 'Tâche';

  @override
  String scannerDetectedType(String type) {
    return 'Détecté : $type';
  }

  @override
  String scannerItemCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments',
      one: '$count élément',
    );
    return '$_temp0';
  }

  @override
  String scannerAndMore(num count) {
    return '…et $count de plus';
  }

  @override
  String scannerStepCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count étapes',
      one: '$count étape',
    );
    return '$_temp0';
  }

  @override
  String scannerTotal(String amount) {
    return 'Total : $amount';
  }

  @override
  String get scannerAddToLists => 'Ajouter aux listes';

  @override
  String get scannerCreateExpense => 'Créer une dépense';

  @override
  String get scannerCreateRecipe => 'Créer une recette';

  @override
  String get scannerCreateChore => 'Créer une tâche';

  @override
  String get scannerUseThis => 'Utiliser ceci';

  @override
  String get scannerScanAgain => 'Scanner à nouveau';

  @override
  String get smartCaptureBack => 'Retour';

  @override
  String get smartCaptureShowEnhanced => 'Afficher amélioré';

  @override
  String get smartCaptureOriginal => 'Original';

  @override
  String get smartCaptureUseAnyway => 'Utiliser quand même';

  @override
  String get smartCaptureUseScan => 'Utiliser le scan';

  @override
  String get smartCaptureRetake => 'Reprendre';

  @override
  String get smartCaptureReady => 'Prêt';

  @override
  String get smartCaptureUsable => 'Utilisable';

  @override
  String get smartCaptureRetakeSuggested => 'Reprise suggérée';

  @override
  String get liveSmartCaptureNoCamera => 'Aucun appareil photo disponible.';

  @override
  String get liveSmartCaptureCouldNotOpen =>
      'Impossible d\'ouvrir l\'appareil photo.';

  @override
  String get liveSmartCaptureFrameList => 'Cadre la liste';

  @override
  String get liveSmartCaptureCameraUnavailable => 'Appareil photo indisponible';

  @override
  String get liveSmartCaptureGallery => 'Galerie';

  @override
  String get liveSmartCaptureScan => 'Scanner';

  @override
  String get liveSmartCaptureCouldNotCapture =>
      'Impossible de capturer cette photo.';

  @override
  String scanReviewAddToList(String list) {
    return 'Ajouter à $list';
  }

  @override
  String get scanReviewReviewItems => 'Vérifier les éléments';

  @override
  String scanReviewAcceptAll(num count) {
    return 'Tout accepter ($count)';
  }

  @override
  String get scanReviewStoreLabel => 'Magasin :';

  @override
  String get scanReviewYouMightNeed => 'Tu pourrais aussi avoir besoin de';

  @override
  String get scanReviewIgnored => 'Ignorés';

  @override
  String get scanReviewNewList => 'Nouvelle liste';

  @override
  String get scanReviewAddToWhichList => 'Ajouter à quelle liste ?';

  @override
  String get scanReviewNewListOption => 'Nouvelle liste…';

  @override
  String get scanReviewScannedList => 'Liste scannée';

  @override
  String get scanReviewCreateList => 'Créer la liste';

  @override
  String get scanReviewAdding => 'Ajout…';

  @override
  String scanReviewRemoveItem(String item) {
    return 'Retirer $item';
  }

  @override
  String get scanReviewRestore => 'Restaurer';

  @override
  String get scanReviewEditItem => 'Modifier l\'élément';

  @override
  String scanReviewOCRSaw(String text) {
    return 'OCR a vu : « $text »';
  }

  @override
  String get scanReviewItemName => 'Nom de l\'élément';

  @override
  String get scanReviewQty => 'Qté';

  @override
  String get scanReviewUnit => 'Unité';

  @override
  String get scanReviewDidYouMean => 'Tu voulais dire ?';

  @override
  String scanReviewBestGuess(String name) {
    return 'Suggestion : $name';
  }

  @override
  String get shareTargetAppBarTitle => 'Enregistrer dans mitlist';

  @override
  String get shareTargetSharedText => 'Texte partagé';

  @override
  String get shareTargetPasteHint => 'Colle ou saisis le texte partagé ici…';

  @override
  String get shareTargetAddPhotos => 'Ajouter des photos';

  @override
  String shareTargetPhotosAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos ajoutées',
      one: '1 photo ajoutée',
    );
    return '$_temp0';
  }

  @override
  String get shareTargetPreviewPlaceholder =>
      'Colle le texte ici maintenant, ou envoie du contenu depuis l\'extension de partage quand cette intégration sera disponible.';

  @override
  String get shareTargetDestLists => 'Listes';

  @override
  String get shareTargetDestListsDesc =>
      'Enregistrer dans une liste de courses ou de tâches';

  @override
  String get shareTargetDestPinwall => 'Pinwall';

  @override
  String get shareTargetDestPinwallDesc =>
      'Poster une note (et des photos optionnelles) dans ton foyer';

  @override
  String get shareTargetDestRecipes => 'Recettes';

  @override
  String get shareTargetDestRecipesDesc => 'Ajouter aux recettes enregistrées';

  @override
  String get shareTargetSelectHousehold => 'Choisir le foyer';

  @override
  String get shareTargetSaved => 'Enregistré';

  @override
  String get shareTargetFailedSave => 'Impossible d\'enregistrer. Réessaie.';

  @override
  String get shareTargetValidationText =>
      'Colle ou saisis quelque chose à enregistrer.';

  @override
  String get shareTargetValidationNote =>
      'Ajoute une note ou au moins une photo.';

  @override
  String get shareTargetValidationHousehold =>
      'Crée ou rejoins d\'abord un foyer.';

  @override
  String get expenseCreationTitle => 'Ajouter une dépense';

  @override
  String get expenseCreationAmountHint => '0,00';

  @override
  String expenseCreationRateHint(String currency, String groupCurrency) {
    return 'Taux : 1 $currency = ? $groupCurrency';
  }

  @override
  String get expenseCreationWhatsItFor => 'C\'est pour quoi ?';

  @override
  String get expenseCreationCategoryLabel => 'Catégorie';

  @override
  String get expenseCreationDatePrefix => 'Date';

  @override
  String get expenseCategoryGroceries => 'Courses';

  @override
  String get expenseCategoryDining => 'Restaurants';

  @override
  String get expenseCategoryTransport => 'Transports';

  @override
  String get expenseCategoryUtilities => 'Charges';

  @override
  String get expenseCategoryHousehold => 'Maison';

  @override
  String get expenseCategoryEntertainment => 'Divertissement';

  @override
  String get expenseCategoryHealth => 'Santé';

  @override
  String get expenseCategoryOther => 'Autre';

  @override
  String get expenseCreationNotesHint => 'Notes (optionnel)';

  @override
  String get expenseCreationDateLabel =>
      'Date de la dépense. Appuie pour changer.';

  @override
  String expenseCreationStartsOn(String date) {
    return 'À partir du $date';
  }

  @override
  String get expenseCreationNextDueLabel =>
      'Première échéance. Appuie pour changer.';

  @override
  String get expenseCreationEditRepeatSemantic =>
      'Récurrence. Appuie pour changer.';

  @override
  String get expenseCreationRepeatNever => 'Ne se répète pas';

  @override
  String get expenseCreationRepeatNeverOption => 'Jamais';

  @override
  String get expenseCreationRepeatDaily => 'Se répète chaque jour';

  @override
  String get expenseCreationRepeatWeekly => 'Se répète chaque semaine';

  @override
  String get expenseCreationRepeatBiweekly => 'Se répète toutes les 2 semaines';

  @override
  String get expenseCreationRepeatMonthly => 'Se répète chaque mois';

  @override
  String get expenseCreationRepeatQuarterly => 'Se répète chaque trimestre';

  @override
  String get expenseCreationRepeatYearly => 'Se répète chaque année';

  @override
  String expenseCreationRepeatCurrencyHint(String currency) {
    return 'Les dépenses récurrentes sont enregistrées en $currency.';
  }

  @override
  String get expenseCreationRecurringTitle => 'Nouvelle dépense récurrente';

  @override
  String get expenseCreationRecurringEditTitle =>
      'Modifier la dépense récurrente';

  @override
  String get expenseCreationRecurringAdded => 'Dépense récurrente ajoutée';

  @override
  String get expenseCreationRecurringSaved => 'Dépense récurrente mise à jour';

  @override
  String get recurringEditTooltip => 'Modifier';

  @override
  String get expenseCreationReceiptButton => 'Reçu';

  @override
  String get expenseCreationScanning => 'Scan en cours…';

  @override
  String get expenseCreationScanButton => 'Scanner';

  @override
  String get expenseCreationReceiptAttached =>
      'Reçu joint. Appuie pour rescanner.';

  @override
  String get expenseCreationScanReceiptSemantics =>
      'Scanner un reçu via l\'appareil photo';

  @override
  String get expenseCreationSplitMode => 'Mode de partage';

  @override
  String expenseCreationSplitTotal(String amount) {
    return 'Total $amount';
  }

  @override
  String get expenseCreationSplitEqual => 'Égal';

  @override
  String get expenseCreationSplitExact => 'Exact';

  @override
  String get expenseCreationSplitShares => 'Parts';

  @override
  String get expenseCreationSplitPercent => 'Pourcentage';

  @override
  String get expenseCreationSplitHintExact =>
      'Saisis le montant exact que chaque personne doit.';

  @override
  String get expenseCreationSplitHintPercent =>
      'Saisis la part de chacun ; le total doit faire 100 %.';

  @override
  String get expenseCreationSplitHintShares =>
      'Partage par parts, ex. 2 parts paie le double.';

  @override
  String get expenseCreationSplitHintEqual =>
      'Divise le total de manière égale entre les membres sélectionnés.';

  @override
  String get expenseCreationSplitSharesLabel => 'Parts';

  @override
  String get expenseCreationSplitValuesAmount => 'Montant';

  @override
  String get expenseCreationSplitValuesPercent => '%';

  @override
  String get expenseCreationPaidBy => 'Payé par';

  @override
  String get expenseCreationSplitWith => 'Partager avec';

  @override
  String get expenseCreationSelectSplitter =>
      'Sélectionne au moins une personne avec qui partager.';

  @override
  String get expenseCreationEnterAmount =>
      'Saisis un montant ci-dessus pour prévisualiser chaque part.';

  @override
  String get expenseCreationValidationAmount =>
      'Saisis un montant valide supérieur à zéro.';

  @override
  String get expenseCreationValidationRate =>
      'Saisis un taux de conversion supérieur à zéro.';

  @override
  String get expenseCreationRateAutoFilled =>
      'Taux rempli automatiquement — tu peux le modifier.';

  @override
  String get expenseCreationReceiptUploadFailed =>
      'Dépense enregistrée, mais l\'envoi du reçu a échoué.';

  @override
  String get expenseCreationExpenseAdded => 'Dépense ajoutée';

  @override
  String expenseCreationSummaryPaidBySplit(String payer, String how) {
    return 'Payé par $payer · partagé $how';
  }

  @override
  String get expenseCreationSummaryYou => 'vous';

  @override
  String get expenseCreationSplitHowEqual => 'à parts égales';

  @override
  String get expenseCreationSplitHowExact => 'par montants exacts';

  @override
  String get expenseCreationSplitHowShares => 'par parts';

  @override
  String get expenseCreationSplitHowPercent => 'par pourcentages';

  @override
  String get expenseCreationEditSplitSemantic =>
      'Modifier qui a payé et comment c\'est partagé';

  @override
  String get pinwallBoardLabel => 'Pinwall';

  @override
  String get pinwallSnapshot => 'Vue d\'ensemble';

  @override
  String get pinwallDragHint =>
      'Glisser les notes pour déplacer  ·  Pincer pour zoomer';

  @override
  String get pinwallAddNote => 'Ajouter une note';

  @override
  String pinwallPresenceHere(String names) {
    return '$names ici en ce moment';
  }

  @override
  String get pinwallCloseBoard => 'Fermer le tableau';

  @override
  String get pinwallEmptyBoard =>
      'Le tableau est vide.\nÉpingle une note depuis l\'accueil pour commencer.';

  @override
  String pinwallNoteSemantics(String user, String content) {
    return '$user · $content';
  }

  @override
  String pinwallReminderLabel(String text) {
    return 'Rappel · $text';
  }

  @override
  String pinwallRemindedLabel(String text) {
    return 'Rappelé · $text';
  }

  @override
  String get pinwallChooseReminderDate => 'Choisir la date du rappel';

  @override
  String get pinwallChooseReminderTime => 'Choisir l\'heure du rappel';

  @override
  String get pinwallLinkTo => 'Lier à…';

  @override
  String get pinwallLinkExpense => 'Une dépense';

  @override
  String get pinwallRemoveLink => 'Supprimer le lien';

  @override
  String pinwallSelectEntity(String type) {
    return 'Sélectionner un(e) $type';
  }

  @override
  String get pinwallOpenBoard => 'Ouvrir le tableau pinwall';

  @override
  String get pinwallLinkToChore => 'Lier à une tâche, liste…';

  @override
  String get pinwallPickFutureTime => 'Choisissez une heure future.';

  @override
  String get pinwallCouldNotLoadEntities =>
      'Impossible de charger les entités.';

  @override
  String get pinwallPinned => 'Épinglé au mur';

  @override
  String get pinwallOpenBoardBtn => 'Ouvrir le tableau';

  @override
  String get pinwallPostHint => 'Publier une note pour le foyer…';

  @override
  String get pinwallAddReminder => 'Ajouter un rappel';

  @override
  String pinwallReminderSet(String label) {
    return 'Rappel défini pour $label. Appuyez pour modifier.';
  }

  @override
  String get pinwallClearReminder => 'Effacer le rappel';

  @override
  String get pinwallAttachPhoto => 'Joindre une photo';

  @override
  String get pinwallUploading => 'Téléversement…';

  @override
  String get pinwallPosting => 'Publication…';

  @override
  String get pinwallPinIt => 'Épingler';

  @override
  String get pinwallCouldNotLoadImage => 'Impossible de charger l\'image.';

  @override
  String get pinwallRemoveFromPost => 'Retirer de la publication';

  @override
  String get pinwallCouldNotRemovePhoto => 'Impossible de retirer la photo.';

  @override
  String get pinwallCouldNotAddPhoto => 'Impossible d\'ajouter la photo.';

  @override
  String get pinwallLinkedList => 'Liste liée';

  @override
  String get pinwallLinkedChore => 'Tâche liée';

  @override
  String get pinwallLinkedExpense => 'Dépense liée';

  @override
  String pinwallOpenLinkedEntity(String entity) {
    return 'Ouvrir $entity lié(e)';
  }

  @override
  String get pinwallPostOptions => 'Options de publication';

  @override
  String get pinwallDeletePin => 'Supprimer l\'épingle';

  @override
  String get pinwallDeletePinBody =>
      'Cette épingle sera définitivement supprimée. Cette action est irréversible.';

  @override
  String get pinwallEditNote => 'Modifier la note';

  @override
  String get pinwallNoteColor => 'Couleur';

  @override
  String get pinwallNoteSize => 'Taille';

  @override
  String get pinwallNoteSizeSmall => 'Petite';

  @override
  String get pinwallNoteSizeMedium => 'Moyenne';

  @override
  String get pinwallNoteSizeLarge => 'Grande';

  @override
  String get pinwallColorYellow => 'Jaune';

  @override
  String get pinwallColorPeach => 'Pêche';

  @override
  String get pinwallColorMint => 'Menthe';

  @override
  String get pinwallColorSky => 'Ciel';

  @override
  String get pinwallColorBlush => 'Rose';

  @override
  String get pinwallColorLavender => 'Lavande';

  @override
  String get pinwallCouldNotSaveNote => 'Impossible d\'enregistrer la note.';

  @override
  String get sheetFailedChangesOpUpdatePinwallPost =>
      'Modifier la note du tableau';

  @override
  String get pinwallAddPhotoMenu => 'Ajouter une photo';

  @override
  String get tonightBreakfast => 'Aujourd\'hui · Petit-déjeuner';

  @override
  String get tonightLunch => 'Aujourd\'hui · Déjeuner';

  @override
  String tonightOpenRecipe(String title) {
    return 'Ce soir : $title. Ouvrir la recette';
  }

  @override
  String get captureHintClearer => 'Essayez une photo plus nette';

  @override
  String get captureHintHoldSteady => 'Restez stable';

  @override
  String get captureHintMoreLight => 'Trouvez plus de lumière';

  @override
  String get captureHintReduceGlare => 'Réduisez les reflets';

  @override
  String get captureHintMoveCloser => 'Rapprochez-vous';

  @override
  String get accountLanguage => 'Langue';

  @override
  String get accountLanguageSystem => 'Système';

  @override
  String get navHome => 'Accueil';

  @override
  String get navChores => 'Tâches';

  @override
  String get navMoney => 'Argent';

  @override
  String get navLists => 'Listes';

  @override
  String get navKitchen => 'Cuisine';

  @override
  String get offlineBannerTitle => 'Statut de synchronisation';

  @override
  String get offlineBannerStatusOffline => 'Hors ligne';

  @override
  String get offlineBannerStatusPending => 'En attente';

  @override
  String get offlineBannerStatusFailed => 'Échoué';

  @override
  String get offlineBannerRetryHint =>
      'Les modifications seront réessayées automatiquement lorsque la connexion sera rétablie.';

  @override
  String get offlineBannerOfflineHint =>
      'Vous pouvez continuer à faire des modifications hors ligne. Tout sera synchronisé lors de la reconnexion.';

  @override
  String get offlineBannerBarOffline =>
      'Hors ligne — les modifications seront synchronisées à la reconnexion';

  @override
  String offlineBannerSyncingCount(num count) {
    return 'Synchronisation de $count modifications…';
  }

  @override
  String get initialSyncRefreshing => 'Actualisation…';

  @override
  String get initialSyncFailed =>
      'Échec de l\'actualisation — touchez pour réessayer';

  @override
  String get offlineBannerSyncing => 'Synchronisation des modifications…';

  @override
  String offlineBannerFailedCount(num count) {
    return 'Impossible de synchroniser $count modifications';
  }

  @override
  String get offlineBannerFailedOne =>
      'Impossible de synchroniser une modification';

  @override
  String offlineBannerConflictCount(int count) {
    return '$count modifications nécessitent votre révision';
  }

  @override
  String get offlineBannerConflictOne =>
      'Une modification nécessite votre révision';

  @override
  String get offlineBannerRetry => 'Réessayer';

  @override
  String get composerNewItem => 'Nouvel article';

  @override
  String get composerScanList => 'Scanner la liste';

  @override
  String get composerAddItem => 'Ajouter un article';

  @override
  String get listItemViewPhoto => 'Voir la photo';

  @override
  String get listItemReplacePhoto => 'Remplacer la photo';

  @override
  String get listItemAddPhoto => 'Ajouter une photo';

  @override
  String get listItemRemovePhoto => 'Supprimer la photo';

  @override
  String get listItemSetPrice => 'Définir le prix';

  @override
  String get listItemChangeQuantity => 'Modifier la quantité';

  @override
  String get listItemQuantityAmount => 'Quantité';

  @override
  String get listItemQuantityUnit => 'Unité (facultatif)';

  @override
  String get listItemAddNote => 'Ajouter une note';

  @override
  String get listItemEditNote => 'Modifier la note';

  @override
  String get listItemNoteLabel => 'Note';

  @override
  String listDetailProgress(int done, int total) {
    return '$done sur $total faits';
  }

  @override
  String listOpenCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count restants',
      one: '1 restant',
      zero: 'Tout est fait',
    );
    return '$_temp0';
  }

  @override
  String get listSortListView => 'Vue liste';

  @override
  String get listItemDeleteAction => 'Supprimer';

  @override
  String get listItemReorder => 'Réorganiser';

  @override
  String listItemMarkUnchecked(String name) {
    return 'Marquer $name comme non coché';
  }

  @override
  String listItemMarkChecked(String name) {
    return 'Marquer $name comme coché';
  }

  @override
  String listItemViewPhotoFor(String name) {
    return 'Voir la photo de $name';
  }

  @override
  String get listItemFailedSave =>
      'Échec de l\'enregistrement — appuyez sur la barre de synchronisation pour réessayer';

  @override
  String get listItemLongPressHint => 'Appui long pour plus d\'options';

  @override
  String get scanCheckListPhoto => 'Vérifier la photo de la liste';

  @override
  String get scanReadingList => 'Lecture de votre liste…';

  @override
  String get scanCouldNotProcess =>
      'Impossible de traiter l\'image. Veuillez réessayer.';

  @override
  String get scanSnapYourList => 'Prendre votre liste en photo';

  @override
  String get scanTakePhoto => 'Prendre une photo';

  @override
  String get scanChooseFromGallery => 'Choisir dans la galerie';

  @override
  String get appDialogClose => 'Fermer';

  @override
  String get appDialogPressBack => 'Appuyez sur retour pour fermer';

  @override
  String get shellNotifications => 'Notifications';

  @override
  String get shellAccount => 'Compte';

  @override
  String get errorSomethingWentWrong => 'Quelque chose s\'est mal passé';

  @override
  String filterRemoveLabel(String label) {
    return 'Supprimer le filtre $label';
  }

  @override
  String get currencyDropdownLabel => 'Devise';

  @override
  String get passwordStrengthWeak => 'Faible';

  @override
  String get passwordStrengthFair => 'Moyen';

  @override
  String get passwordStrengthGood => 'Bon';

  @override
  String get passwordStrengthStrong => 'Fort';

  @override
  String get checkToggleChecked => 'Coché';

  @override
  String get checkToggleNotChecked => 'Non coché';

  @override
  String get notificationsDeleteNotification => 'Supprimer la notification';

  @override
  String get calendarTomorrow => 'Demain';

  @override
  String get scannerCheckScan => 'Vérifier le scan';

  @override
  String get scannerCheckGrocery => 'Vérifier la liste de courses';

  @override
  String recipeCreationNoItemsYet(String type) {
    return 'Pas encore de $type.';
  }

  @override
  String get captureHintReady => 'Prêt à scanner';

  @override
  String get captureHintUsable => 'Semble utilisable';

  @override
  String get authLoginTitle => 'Se connecter';

  @override
  String get authLoginEmail => 'E-mail';

  @override
  String get authLoginYouExample => 'toi@exemple.com';

  @override
  String get authLoginPassword => 'Mot de passe';

  @override
  String get authLoginYourPassword => 'Ton mot de passe';

  @override
  String get authLoginForgotPassword => 'Mot de passe oublié ?';

  @override
  String get authLoginSignInButton => 'Se connecter';

  @override
  String get authLoginSigningIn => 'Connexion en cours…';

  @override
  String get authLoginNoAccount => 'Pas de compte ?';

  @override
  String get authLoginCreateOne => 'En créer un';

  @override
  String get authLoginFillAllFields => 'Remplis tous les champs.';

  @override
  String get authLoginEmailRequired => 'L\'e-mail est requis.';

  @override
  String get authLoginPasswordRequired => 'Le mot de passe est requis.';

  @override
  String get authLoginGenericError =>
      'Connexion impossible. Vérifie ta connexion et réessaie.';

  @override
  String get authLoginRememberMe => 'Se souvenir de moi';

  @override
  String get authLoginRememberMeOn => 'Se souvenir de moi : activé';

  @override
  String get authLoginRememberMeOff => 'Se souvenir de moi : désactivé';

  @override
  String get authLoginGoogle => 'Continuer avec Google';

  @override
  String get authLoginApple => 'Continuer avec Apple';

  @override
  String get authLoginNoMethods =>
      'Ce serveur n’a aucune méthode de connexion activée. La personne qui l’administre doit activer la connexion par e-mail ou connecter Google ou Apple.';

  @override
  String get authLoginWithEmailButton => 'Se connecter par e-mail';

  @override
  String get authSignupWithEmailButton => 'S\'inscrire par e-mail';

  @override
  String get authVerifyTitle => 'Vérifiez votre e-mail';

  @override
  String authVerifyBody(String email) {
    return 'Saisissez le code envoyé à $email.';
  }

  @override
  String get authVerifyCodeLabel => 'Code de vérification';

  @override
  String get authVerifyCodeHint => 'Code à 8 caractères de l’e-mail';

  @override
  String get authVerifyButton => 'Vérifier';

  @override
  String get authVerifyResend => 'Envoyer un nouveau code';

  @override
  String get authVerifySent =>
      'Un nouveau code est en route. Vérifiez votre boîte de réception et vos spams.';

  @override
  String get authVerifyInvalid => 'Ce code est invalide ou expiré.';

  @override
  String get authVerifyCodeRequired => 'Saisissez le code reçu par e-mail.';

  @override
  String get authLoginUnverified =>
      'Votre e-mail n’est pas encore vérifié. Vérifiez-le pour vous connecter.';

  @override
  String get accountVerifyPendingTitle =>
      'Terminez la configuration de votre compte';

  @override
  String accountVerifyPendingBody(String email) {
    return 'Nous avons envoyé un code à $email. Saisissez-le pour terminer la création de votre compte.';
  }

  @override
  String get accountVerifyEnterCode => 'Saisir le code';

  @override
  String get accountVerifyLater =>
      'Vous pourrez saisir le code à tout moment depuis la page de votre compte.';

  @override
  String get accountUpgradeWithEmail => 'Utiliser un e-mail et un mot de passe';

  @override
  String get oauthBackToAccount => 'Retour au compte';

  @override
  String authLoginOAuthUnsupported(String provider) {
    return 'La connexion $provider n\'est disponible que sur le web, Android et iOS pour l\'instant.';
  }

  @override
  String get authLoginResetPasswordTitle => 'Réinitialiser le mot de passe';

  @override
  String get authLoginSendResetCode => 'Envoyer le code';

  @override
  String get authLoginResetCodeLabel => 'Code de réinitialisation';

  @override
  String get authLoginResetCodeHint => 'Colle le code de ton e-mail';

  @override
  String get authLoginResetPasswordButton => 'Réinitialiser le mot de passe';

  @override
  String get authServerLink => 'Choisir le serveur';

  @override
  String get authServerSheetTitle => 'Choisissez votre serveur';

  @override
  String get authServerSheetBody =>
      'mitlist est open source et auto-hébergeable. Connectez l\'application à votre propre serveur, ou laissez vide pour utiliser le serveur par défaut.';

  @override
  String get authServerUrlLabel => 'URL du serveur';

  @override
  String get authServerUrlHint => 'https://mitlist.example.com';

  @override
  String get authServerUrlInvalid =>
      'Saisissez une URL complète commençant par http:// ou https://.';

  @override
  String get authServerUnreachable =>
      'Aucun serveur mitlist n\'a répondu à cette adresse.';

  @override
  String get authServerSave => 'Utiliser ce serveur';

  @override
  String get authServerReset => 'Revenir au serveur par défaut';

  @override
  String get authServerNoDefault =>
      'Cette version n\'a pas de serveur par défaut. Saisissez l\'adresse de votre serveur pour continuer.';

  @override
  String get authLoginResetCodeSent =>
      'Si cet e-mail existe, un code de réinitialisation a été envoyé.';

  @override
  String get authLoginResetFillAllFields =>
      'Remplis le code et les deux champs de mot de passe.';

  @override
  String get authLoginResetSuccess =>
      'Mot de passe mis à jour. Vous êtes connecté.';

  @override
  String get authLinkOpenInApp => 'Ouvrir dans l\'app mitlist';

  @override
  String get authLinkContinueInBrowser => 'Continuer dans le navigateur';

  @override
  String get authLinkBackToLogin => 'Retour à la connexion';

  @override
  String get authVerifyLinkBody =>
      'Plus qu\'un geste. Vérifiez dans l\'app installée ou directement ici dans le navigateur.';

  @override
  String get authVerifyLinkMissing =>
      'Ce lien ne contient pas de code. Saisissez plutôt le code reçu par e-mail.';

  @override
  String get authVerifyLinkVerifying => 'Vérification de votre e-mail…';

  @override
  String get authVerifyLinkSuccess => 'E-mail vérifié. Vous êtes connecté !';

  @override
  String get authResetTitle => 'Choisissez un nouveau mot de passe';

  @override
  String get authResetBody =>
      'Choisissez un nouveau mot de passe pour votre compte. Vous serez connecté dès son enregistrement.';

  @override
  String get authResetSubmit => 'Enregistrer et se connecter';

  @override
  String get authResetInvalidCode =>
      'Ce code est invalide ou expiré. Demandez-en un nouveau depuis l\'écran de connexion.';

  @override
  String get authSignupTitle => 'Créer un compte';

  @override
  String get authSignupFirstName => 'Prénom';

  @override
  String get authSignupFirstNameHint => 'Alex';

  @override
  String get authSignupLastName => 'Nom';

  @override
  String get authSignupLastNameHint => 'Martin';

  @override
  String get authSignupEmail => 'E-mail';

  @override
  String get authSignupEmailHint => 'toi@exemple.com';

  @override
  String get authSignupPassword => 'Mot de passe';

  @override
  String get authSignupPasswordHint => 'Au moins 8 caractères';

  @override
  String get authSignupCreateAccount => 'Créer un compte';

  @override
  String get authSignupCreatingAccount => 'Création du compte…';

  @override
  String get authSignupHaveAccount => 'Tu as déjà un compte ?';

  @override
  String get authSignupSignInLink => 'Se connecter';

  @override
  String get authSignupFillAllFields => 'Remplis tous les champs.';

  @override
  String get authSignupPasswordMinLength =>
      'Le mot de passe doit contenir au moins 8 caractères.';

  @override
  String get authSignupJoinTitle => 'Rejoindre un foyer';

  @override
  String get authSignupAccountCreated => 'Compte créé. Bienvenue !';

  @override
  String get authSignupNameRequired => 'Le nom est requis.';

  @override
  String get authSignupEmailRequired => 'L\'e-mail est requis.';

  @override
  String get authSignupPasswordRequired => 'Le mot de passe est requis.';

  @override
  String get authSignupConfirmPassword => 'Confirmer le mot de passe';

  @override
  String get authSignupConfirmPasswordHint =>
      'Saisis à nouveau ton mot de passe';

  @override
  String get authSignupConfirmPasswordRequired => 'Confirme ton mot de passe.';

  @override
  String get authSignupPasswordMismatch =>
      'Les mots de passe ne correspondent pas.';

  @override
  String get authSignupPasswordRequirementsNotMet =>
      'Le mot de passe ne remplit pas les critères ci-dessous.';

  @override
  String get passwordRequirementsTitle => 'Ton mot de passe doit contenir :';

  @override
  String get passwordRequirementLength => 'Au moins 8 caractères';

  @override
  String get passwordRequirementUppercase => 'Une lettre majuscule';

  @override
  String get passwordRequirementDigit => 'Un chiffre';

  @override
  String get passwordRequirementSpecial => 'Un caractère spécial';

  @override
  String get authSignupGenericError =>
      'Impossible de créer le compte. Vérifie ta connexion et réessaie.';

  @override
  String get authSignupNameHint => 'Ton nom';

  @override
  String get authSignupTermsPrefix => 'En créant un compte, tu acceptes nos ';

  @override
  String get authSignupAnd => ' et ';

  @override
  String get authSignupPeriod => '.';

  @override
  String get authSignupPrivacyPolicy => 'Politique de confidentialité';

  @override
  String get authSignupTermsP1 =>
      'Utilise mitlist de manière responsable. Le contenu partagé du foyer est visible par les membres de ce foyer.';

  @override
  String get authSignupTermsP2 =>
      'Ne téléverse pas de contenu illégal, n\'usurpe pas l\'identité d\'autrui et n\'abuse pas du service. Les comptes et données partagées peuvent être supprimés en cas d\'abus.';

  @override
  String get authSignupTermsP3 =>
      'Les foyers de quatre membres au plus utilisent le service hébergé gratuitement. Les foyers plus grands ont besoin d\'un abonnement Premium, résiliable à tout moment. Garde ton propre export de tout ce qui est important.';

  @override
  String get legalReadFullText => 'Lire le texte complet';

  @override
  String get authSignupPrivacyP1 =>
      'mitlist stocke les détails du compte et le contenu du foyer nécessaires au fonctionnement de l\'app.';

  @override
  String get authSignupPrivacyP2 =>
      'Les données partagées comme les listes, tâches, dépenses et recettes sont visibles par les autres membres du même foyer.';

  @override
  String get authSignupPrivacyP3 =>
      'Ne fournis que les informations que tu es prêt à partager dans un espace de foyer partagé.';

  @override
  String get authJoinInvitedTo => 'Tu es invité·e à rejoindre';

  @override
  String authJoinMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres',
      one: '1 membre',
    );
    return '$_temp0';
  }

  @override
  String get authJoinAccept => 'Accepter l\'invitation';

  @override
  String get authJoinDecline => 'Refuser';

  @override
  String get authJoinCheckingInvite => 'Vérification de l\'invitation…';

  @override
  String get authJoinExpired =>
      'Cette invitation a expiré. Demande-en une nouvelle.';

  @override
  String authJoinAlreadyMember(String name) {
    return 'Tu fais déjà partie de $name.';
  }

  @override
  String get authJoinTitle => 'Rejoindre un foyer';

  @override
  String authJoinInvitedBy(String name) {
    return '$name t\'a invité';
  }

  @override
  String get authJoinJoinNow => 'Rejoindre maintenant';

  @override
  String get authJoinSignInToJoin => 'Connecte-toi pour rejoindre';

  @override
  String get authJoinCreateToJoin => 'Créer un compte pour rejoindre';

  @override
  String get authJoinGuestWarning =>
      'Les comptes invités ne peuvent pas rejoindre de foyers.';

  @override
  String get authJoinCouldNotLoad =>
      'Impossible de charger les détails de l\'invitation.';

  @override
  String get authJoinJoining => 'Connexion en cours…';

  @override
  String get authJoinNotNow => 'Pas maintenant';

  @override
  String get authJoinYoureIn => 'Tu es dedans.';

  @override
  String get authJoinGoToHousehold => 'Aller au foyer';

  @override
  String authJoinInviteCodeSemantic(String code) {
    return 'Code d\'invitation : $code';
  }

  @override
  String authJoinErrorWithHint(String error) {
    return '$error\n\nTu peux aussi saisir un code depuis le sélecteur de foyers.';
  }

  @override
  String get authOnboardingTitle => 'Bienvenue';

  @override
  String get authOnboardingSetupHome => 'Configure ton foyer';

  @override
  String get authOnboardingCreateOrJoin =>
      'Crée ou rejoins un foyer pour commencer à partager avec tes colocs.';

  @override
  String get authOnboardingCreateHousehold => 'Créer un foyer';

  @override
  String get authOnboardingJoinInvite => 'Rejoindre avec un code d\'invitation';

  @override
  String get authOnboardingHaveCode => 'Tu as un code d\'invitation ?';

  @override
  String get authOnboardingCreateDesc =>
      'Repartir de zéro : nomme-le, invite tes colocs, partage tout au même endroit.';

  @override
  String get authOnboardingJoinDesc =>
      'Déjà une invitation ? Saisis le code et entre directement.';

  @override
  String get authOnboardingJoinSemantic =>
      'Rejoindre un foyer avec un code d\'invitation';

  @override
  String get authOnboardingHomeIconSemantic => 'Icône d\'accueil du foyer';

  @override
  String get welcomePillarsSemantic =>
      'Listes, argent, tâches et cuisine partagés. Tout au même endroit.';

  @override
  String get authOnboardingNameTitle => 'Donne un nom à ton foyer';

  @override
  String get authOnboardingNameBody =>
      'Écris-le sur la note. Tu pourras le changer plus tard.';

  @override
  String get authOnboardingPinIt => 'Épingle-le au tableau';

  @override
  String get authOnboardingInviteTitle => 'Fais venir tes colocs';

  @override
  String get authOnboardingInviteBody =>
      'Partage ce code. Qui le saisit rejoint ton foyer.';

  @override
  String get authOnboardingGoToBoard => 'Continuer';

  @override
  String get authOnboardingReadyTitle => 'Ton foyer est prêt';

  @override
  String get authOnboardingReadyBody =>
      'Trois choses à savoir. C’est toute la carte.';

  @override
  String get authOnboardingOrientationHome =>
      'Accueil montre ce qui demande ton attention';

  @override
  String get authOnboardingOrientationTabs =>
      'Les onglets rangent chaque partie du foyer';

  @override
  String get authOnboardingOrientationAdd =>
      'Le bouton + ajoute quelque chose depuis partout';

  @override
  String authOnboardingEnterHousehold(String name) {
    return 'Ouvrir $name';
  }

  @override
  String get authOnboardingResolving => 'Ouverture de ton tableau…';

  @override
  String get hubChecklistTitle => 'Mets la maison en route';

  @override
  String get hubChecklistDone => 'Fait';

  @override
  String hubChecklistProgress(int done, int total) {
    return '$done sur $total faits';
  }

  @override
  String get hubStatsChores => 'Tâches';

  @override
  String get hubStatsDue => 'à faire';

  @override
  String get hubStatsMeals => 'Repas';

  @override
  String get hubStatsPlanned => 'planifiés';

  @override
  String get hubStatsOverdue => 'en retard';

  @override
  String get hubStatsAllDone => 'tout fait';

  @override
  String get hubStatsBalance => 'Solde';

  @override
  String get hubStatsOpen => 'ouvertes';

  @override
  String get hubStatsLists => 'Listes';

  @override
  String get hubStatsActiveList => 'liste active';

  @override
  String get hubStatsActiveLists => 'listes actives';

  @override
  String get hubStatsReminders => 'Rappels';

  @override
  String get hubStatsPinwallReminder => 'rappel pinwall';

  @override
  String get hubStatsPinwallReminders => 'rappels pinwall';

  @override
  String get hubQuickAddTitle => 'Ajout rapide';

  @override
  String get hubQuickAddChore => 'Ajouter une tâche';

  @override
  String get hubQuickAddExpense => 'Ajouter une dépense';

  @override
  String get hubQuickAddNote => 'Épingler une note';

  @override
  String get hubQuickAddList => 'Nouvelle liste';

  @override
  String get hubActivityTitle => 'Activité';

  @override
  String get hubActivityEmpty =>
      'Rien pour l\'instant.\nL\'activité de ton foyer apparaîtra ici.';

  @override
  String get hubActivityError =>
      'Impossible de charger l\'activité. Tire vers le bas sur l\'accueil pour actualiser.';

  @override
  String get hubOnboardingSwap => 'Échanger';

  @override
  String get hubOnboardingSettle => 'Régler';

  @override
  String get hubOnboardingDone => 'Tout est fait';

  @override
  String get hubOnboardingSwapDesc =>
      'Choisis le coloc qui doit le moins pour reprendre cette tâche.';

  @override
  String get hubOnboardingSettleDesc =>
      'Rembourse tout le monde d\'un coup avec des règlements suggérés.';

  @override
  String get hubOnboardingDoneDesc =>
      'Tâches, soldes, listes — tout au même endroit, bien suivi.';

  @override
  String get appBottomSheetHandle => 'Poignée';

  @override
  String get appBottomSheetClose => 'Fermer';

  @override
  String get storePickerTitle => 'Choisir un magasin';

  @override
  String get storePickerSearchLabel => 'Rechercher des magasins';

  @override
  String get storePickerSearchHint => 'Nom...';

  @override
  String get storePickerNoMatch =>
      'Aucun magasin ne correspond à ta recherche.';

  @override
  String get storePickerNoStore => 'Pas de magasin';

  @override
  String get storePickerNoStoreDesc =>
      'Trier par catégorie plutôt que par disposition du magasin';

  @override
  String get storePickerLoadError => 'Impossible de charger les magasins.';

  @override
  String get smartCaptureLaunchTitle => 'Vérifier la photo';

  @override
  String get hubQuickAddToList => 'Ajouter à une liste';

  @override
  String get hubQuickAddShoppingTrip => 'Lancer les courses';

  @override
  String get hubOnboardingGetStarted => 'Commencer';

  @override
  String get hubOnboardingDismiss => 'Fermer le démarrage rapide';

  @override
  String get hubOnboardingDescription =>
      'Tout commence ici. Choisis ce qui compte le plus.';

  @override
  String get hubOnboardingInvite => 'Inviter des colocs';

  @override
  String get hubOnboardingCreateList => 'Créer une liste';

  @override
  String get hubOnboardingAddChore => 'Ajouter une tâche';

  @override
  String get hubOnboardingTrackExpense => 'Suivre une dépense';

  @override
  String hubQuickStartNextSemantic(String label) {
    return 'Étape suivante : $label';
  }

  @override
  String get hubQuickStartDismissedToast =>
      'Démarrage rapide rangé. Tu le retrouves à tout moment dans Compte.';

  @override
  String get accountShowQuickStart =>
      'Afficher le démarrage rapide sur le tableau';

  @override
  String get accountQuickStartRestored =>
      'Le démarrage rapide est de retour sur ton tableau.';

  @override
  String get appBottomSheetDiscardTitle => 'Abandonner les modifications ?';

  @override
  String get appBottomSheetDiscardBody =>
      'Tu as des modifications non enregistrées.';

  @override
  String get appBottomSheetKeepEditing => 'Continuer à modifier';

  @override
  String get sheetExpenseDetailTitle => 'Détails de la dépense';

  @override
  String get sheetExpenseDetailSplits => 'Parts';

  @override
  String sheetExpenseDetailSplitsCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count parts',
      one: '$count part',
    );
    return '$_temp0';
  }

  @override
  String get sheetSettlementTitle => 'Enregistrer un règlement';

  @override
  String get sheetSettlementFrom => 'De';

  @override
  String get sheetSettlementTo => 'À';

  @override
  String get sheetSettlementRecordPayment =>
      'Enregistre ce règlement après le paiement.';

  @override
  String get sheetSettlementConfirm => 'Confirmer le règlement';

  @override
  String get sheetGroupSettingsTitle => 'Paramètres du foyer';

  @override
  String get sheetGroupSettingsName => 'Nom du foyer';

  @override
  String get sheetGroupSettingsSaved => 'Paramètres enregistrés';

  @override
  String get sheetGroupSettingsCouldNotSave =>
      'Impossible d\'enregistrer les paramètres.';

  @override
  String get sheetGroupSettingsLeave => 'Quitter le foyer';

  @override
  String get sheetGroupSettingsLeaveConfirm =>
      'Es-tu sûr de vouloir quitter ce foyer ? Toutes tes données resteront dans le foyer.';

  @override
  String get sheetGroupSettingsLeaveAction => 'Quitter';

  @override
  String get sheetGroupSettingsDelete => 'Supprimer le foyer';

  @override
  String get sheetGroupSettingsDeleteConfirm =>
      'Cela supprimera définitivement ce foyer et toutes les données associées. Cette action est irréversible.';

  @override
  String get sheetRecipeAddToListTitle => 'Ajouter à la liste';

  @override
  String sheetRecipeAddToListAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count éléments ajoutés',
      one: '1 élément ajouté',
    );
    return '$_temp0';
  }

  @override
  String get sheetRecipeAddToListCouldNotAdd =>
      'Impossible d\'ajouter les ingrédients.';

  @override
  String get sheetJoinTitle => 'Rejoindre un foyer';

  @override
  String get sheetJoinCodeLabel => 'Code d\'invitation';

  @override
  String get sheetJoinCodeHint => 'Coller le code d\'invitation';

  @override
  String get sheetJoinJoin => 'Rejoindre';

  @override
  String get joinPasteButton => 'Coller';

  @override
  String get joinScanButton => 'Scanner';

  @override
  String get joinScanTitle => 'Scanner le code d\'invitation';

  @override
  String get joinScanHint =>
      'Pointez la caméra vers le code QR d\'invitation du foyer';

  @override
  String get joinScanCameraError =>
      'Impossible d\'ouvrir la caméra. Vérifiez les autorisations de la caméra et réessayez.';

  @override
  String get joinPasteFilled => 'Code d\'invitation collé';

  @override
  String get joinPasteNoCode =>
      'Aucun code ou lien d\'invitation trouvé dans ton presse-papiers';

  @override
  String get sheetCreateHouseholdTitle => 'Créer un foyer';

  @override
  String get sheetCreateHouseholdName => 'Nom du foyer';

  @override
  String get sheetCreateHouseholdNameHint => 'ex. Appart 4B';

  @override
  String get sheetInviteTitle => 'Inviter au foyer';

  @override
  String get sheetInviteCopy => 'Copier le lien';

  @override
  String get sheetInviteCopied => 'Lien d\'invitation copié';

  @override
  String get sheetInviteShare => 'Partager le lien';

  @override
  String get sheetCreateListTitle => 'Nouvelle liste';

  @override
  String get sheetCreateListName => 'Nom de la liste';

  @override
  String get sheetCreateListNameHint => 'ex. Courses hebdo';

  @override
  String get sheetCreateListType => 'Type';

  @override
  String get sheetCreateListTypeShopping => 'Courses';

  @override
  String get sheetCreateListTypeTodo => 'À faire';

  @override
  String get sheetCreateListTypeCustom => 'Personnalisée';

  @override
  String get sheetCreateListCreate => 'Créer la liste';

  @override
  String get sheetCostSummaryTitle => 'Récapitulatif des coûts';

  @override
  String get sheetCostSummaryTotal => 'Total';

  @override
  String get sheetConflictTitle => 'Conflit de synchronisation';

  @override
  String get sheetConflictDescription =>
      'Cet élément a été modifié sur un autre appareil pendant que tu l\'éditais. Choisis quelle version garder.';

  @override
  String get sheetConflictLocal => 'Ta version';

  @override
  String get sheetConflictServer => 'Version serveur';

  @override
  String get sheetConflictKeepLocal => 'Garder la tienne';

  @override
  String get sheetConflictKeepServer => 'Garder celle du serveur';

  @override
  String get sheetFailedChangesTitle => 'Modifications échouées';

  @override
  String get sheetFailedChangesDescription =>
      'Ces modifications n\'ont pas pu être enregistrées. Tu peux réessayer ou les abandonner.';

  @override
  String get sheetFailedChangesRetryAll => 'Tout réessayer';

  @override
  String get sheetFailedChangesDiscardAll => 'Tout abandonner';

  @override
  String get sheetFailedChangesDiscard => 'Abandonner';

  @override
  String get sheetFailedChangesRetry => 'Réessayer';

  @override
  String get sheetFailedChangesEmpty =>
      'Aucune modification échouée. Tout est synchronisé ou en attente de nouvelle tentative.';

  @override
  String get sheetFailedChangesOpAddItem => 'Ajouter un élément';

  @override
  String get sheetFailedChangesOpUpdateItem => 'Mettre à jour l\'élément';

  @override
  String get sheetFailedChangesOpDeleteItem => 'Supprimer l\'élément';

  @override
  String get sheetFailedChangesOpReorderItems => 'Réorganiser la liste';

  @override
  String get sheetFailedChangesOpCreateExpense => 'Ajouter une dépense';

  @override
  String get sheetFailedChangesOpUpdateExpense => 'Mettre à jour la dépense';

  @override
  String get sheetFailedChangesOpDeleteExpense => 'Supprimer la dépense';

  @override
  String get sheetFailedChangesOpCreateRecipe => 'Ajouter une recette';

  @override
  String get sheetFailedChangesOpUpdateRecipe => 'Mettre à jour la recette';

  @override
  String get sheetFailedChangesOpDeleteRecipe => 'Supprimer la recette';

  @override
  String get sheetFailedChangesOpCompleteChore => 'Terminer la tâche';

  @override
  String get sheetFailedChangesOpSkipChore => 'Passer la tâche';

  @override
  String get sheetFailedChangesOpRescheduleChore => 'Replanifier la tâche';

  @override
  String get sheetFailedChangesOpUndoChore => 'Annuler la tâche';

  @override
  String get sheetFailedChangesOpCreatePinwallPost => 'Publier sur le pinwall';

  @override
  String get sheetFailedChangesOpDeletePinwallPost =>
      'Supprimer la publication pinwall';

  @override
  String get sheetFailedChangesOpChange => 'Modification';

  @override
  String get sheetGroupSettingsChoreZonesUpdated =>
      'Zones de tâches mises à jour';

  @override
  String get sheetGroupSettingsRemoveMember => 'Retirer le membre';

  @override
  String sheetGroupSettingsRemoveMemberConfirm(String name) {
    return 'Retirer $name de ce foyer ?';
  }

  @override
  String sheetGroupSettingsMemberRemoved(String name) {
    return '$name retiré';
  }

  @override
  String get sheetGroupSettingsHouseholdDeleted => 'Foyer supprimé';

  @override
  String get sheetGroupSettingsDescriptionHint => 'Quelques mots sur ce foyer';

  @override
  String get sheetGroupSettingsChoreZonesLabel => 'Zones de tâches';

  @override
  String get sheetGroupSettingsChoreZonesDesc =>
      'Zones de ton logement pour regrouper les tâches. Elles apparaissent lors de l\'ajout d\'une tâche.';

  @override
  String get sheetGroupSettingsAddZone => 'Ajouter une zone';

  @override
  String get sheetGroupSettingsZoneHint => 'Cuisine, Salle de bain…';

  @override
  String get sheetGroupSettingsSaveZones => 'Enregistrer les zones';

  @override
  String get sheetGroupSettingsMembersLabel => 'Membres';

  @override
  String get sheetGroupSettingsInvite => 'Inviter';

  @override
  String sheetGroupSettingsRemoveMemberTooltip(String name) {
    return 'Retirer $name';
  }

  @override
  String get tonightRecipe => 'Recette';

  @override
  String get tonightHeader => 'Ce soir';

  @override
  String get tonightCook => 'Cuisiner';

  @override
  String get tonightNothingPlanned => 'Rien de prévu pour ce soir';

  @override
  String get tonightPlanDinner => 'Planifier le dîner';

  @override
  String activityAddedToList(String name, String when) {
    return 'A ajouté $name à une liste · $when';
  }

  @override
  String activityAddedToNamedList(String name, String list, String when) {
    return '$name ajouté à $list · $when';
  }

  @override
  String activityAddedItemToList(String when) {
    return 'A ajouté un élément à une liste · $when';
  }

  @override
  String activityLoggedExpense(String name, String when) {
    return 'A enregistré $name · $when';
  }

  @override
  String activityLoggedExpenseGeneric(String when) {
    return 'A enregistré une dépense · $when';
  }

  @override
  String activityCompletedChore(String name, String when) {
    return 'A terminé $name · $when';
  }

  @override
  String activityCompletedChoreGeneric(String when) {
    return 'A terminé une tâche · $when';
  }

  @override
  String activitySavedRecipe(String name, String when) {
    return 'A enregistré $name · $when';
  }

  @override
  String activitySavedRecipeGeneric(String when) {
    return 'A enregistré une recette · $when';
  }

  @override
  String activityPlannedMeal(String name, String when) {
    return 'A planifié $name · $when';
  }

  @override
  String activityUpdatedMealPlan(String when) {
    return 'A mis à jour le plan de repas · $when';
  }

  @override
  String get activityYou => 'Toi';

  @override
  String get activityMember => 'Membre';

  @override
  String inviteLinkShareText(String link, String code) {
    return 'Rejoins mon foyer sur mitlist !\nAppuie : $link\nOu ouvre mitlist et saisis le code : $code';
  }

  @override
  String get errorBoundaryTitle => 'Une erreur est survenue';

  @override
  String get errorBoundaryDesc =>
      'Une erreur inattendue s\'est produite. Réessaie.';

  @override
  String get recurringTomorrow => 'Demain';

  @override
  String get recurringCouldNotUpdate =>
      'Impossible de mettre à jour la dépense récurrente.';

  @override
  String get recurringCouldNotDelete =>
      'Impossible de supprimer la dépense récurrente.';

  @override
  String get recurringCouldNotCreate =>
      'Impossible de créer la dépense récurrente.';

  @override
  String get recipeAddToListNoLists => 'Pas de listes';

  @override
  String get recipeAddToListCreateListFirst =>
      'Crée d\'abord une liste pour ajouter des ingrédients';

  @override
  String get costSummaryNoPrices =>
      'Aucun élément n\'a encore de prix. Ouvre les options de l\'élément (⋯) et choisis Définir le prix pour voir le récapitulatif des coûts.';

  @override
  String get costSummaryNotAvailable => 'N/D';

  @override
  String get costSummaryEqualShare => 'Part égale par personne';

  @override
  String get costSummaryItemsWithPrices => 'Éléments avec prix';

  @override
  String get costSummaryNone => 'Aucun';

  @override
  String get costSummaryGenerateExpense => 'Générer une dépense';

  @override
  String get createListScanFinished => 'Scan terminé';

  @override
  String createListScanned(String name) {
    return '\"$name\" scanné';
  }

  @override
  String get createListShoppingDesc =>
      'Idéal pour les courses et les commissions avec quantités.';

  @override
  String get createListNameRequired => 'Le nom de la liste est requis';

  @override
  String get createListCreated => 'Liste créée';

  @override
  String get recipeCreationScanRecipe => 'Scanner une recette';

  @override
  String get recipeCreationScanRecipeViaCamera =>
      'Scanner une recette via l\'appareil photo';

  @override
  String get joinCodeFormatHint =>
      'Les codes ressemblent à MOT-MOT-X7WM2K9PQ6R8S. Demande à la personne qui t\'a invité.';

  @override
  String joinEnterGroup(String name) {
    return 'Entrer dans $name';
  }

  @override
  String inviteCodeLabel(String code) {
    return 'Code d\'invitation : $code';
  }

  @override
  String get inviteQrTitle => 'Code QR d\'invitation au foyer';

  @override
  String get inviteQrSemantic => 'QR d\'invitation au foyer';

  @override
  String get inviteQrHint =>
      'Scanne avec l\'appareil photo pour rejoindre, ou partage le code ci-dessous.';

  @override
  String get inviteGenerating => 'Génération…';

  @override
  String get inviteNewCode => 'Nouveau code';

  @override
  String get createHouseholdCreated => 'Foyer créé';

  @override
  String get createHouseholdDescriptionOptional => 'Description (optionnel)';

  @override
  String get conflictNoneToResolve => 'Aucun conflit à résoudre.';

  @override
  String get conflictItemChanged => 'Élément modifié';

  @override
  String conflictItemLabel(String name) {
    return 'Élément : $name';
  }

  @override
  String get scannerCouldNotAnalyze =>
      'Impossible d\'analyser l\'image. Réessaie avec une photo plus nette.';

  @override
  String get oauthMissingParams => 'Paramètres de retour OAuth manquants.';

  @override
  String get oauthSigningYouIn => 'Connexion en cours';

  @override
  String get expenseCreationSharesNegative =>
      'Les parts ne peuvent pas être négatives.';

  @override
  String get expenseCreationAssignShare => 'Attribue au moins une part.';

  @override
  String get expenseCreationCouldNotLoadMembers =>
      'Impossible de charger les membres du foyer.';

  @override
  String get expenseCreationJoinHouseholdSplit =>
      'Rejoins ou crée un foyer pour partager cette dépense.';

  @override
  String expenseCreationRemoveAddSplitter(String name) {
    return 'Retirer/Ajouter $name du/au partage';
  }

  @override
  String get expenseDetailFailedLoadReceipt => 'Échec du chargement du reçu';

  @override
  String get expenseDetailReceipt => 'Reçu';

  @override
  String get expenseDetailView => 'Voir';

  @override
  String get expenseDetailNotSplitYet =>
      'Cette dépense n\'est pas encore partagée.';

  @override
  String get expenseDetailNoReceipts =>
      'Aucun reçu joint. Ajoute-en un en modifiant la dépense.';

  @override
  String pinwallLinkedTo(String entity) {
    return 'Lié à $entity';
  }

  @override
  String get commonView => 'Voir';

  @override
  String get notificationsOpenList => 'Ouvrir la liste';

  @override
  String get notificationsOpenChore => 'Ouvrir la tâche';

  @override
  String get notificationsOpenMoney => 'Ouvrir les finances';

  @override
  String get notificationsOpenRecipes => 'Ouvrir les recettes';

  @override
  String get notificationsOpenHousehold => 'Ouvrir le foyer';

  @override
  String get notificationChoreDueSoonTitle => 'Tâche bientôt due';

  @override
  String notificationChoreDueSoonBody(String choreName) {
    return '$choreName arrive bientôt à échéance';
  }

  @override
  String get notificationChoreDueTodayTitle => 'Tâche due aujourd’hui';

  @override
  String notificationChoreDueTodayBody(String choreName) {
    return '$choreName est à faire aujourd’hui';
  }

  @override
  String notificationListUpdatedTitle(String listName) {
    return '$listName mise à jour';
  }

  @override
  String notificationListUpdatedOneBody(
      String actorName, String itemName, String listName, String groupName) {
    return '$actorName a ajouté $itemName à $listName dans $groupName.';
  }

  @override
  String notificationListUpdatedManyBody(
      String actorName, num count, String listName, String groupName) {
    return '$actorName a ajouté $count éléments à $listName dans $groupName.';
  }

  @override
  String notificationListUpdatedManyNamesBody(String actorName, num count,
      String listName, String groupName, String itemNames) {
    return '$actorName a ajouté $count éléments à $listName dans $groupName : $itemNames';
  }

  @override
  String get notificationExpenseCreatedTitle => 'Dépense ajoutée';

  @override
  String notificationExpenseCreatedBody(
      String actorName, String expenseName, String groupName) {
    return '$actorName a ajouté $expenseName dans $groupName.';
  }

  @override
  String get notificationRecurringExpenseTitle => 'Dépense récurrente ajoutée';

  @override
  String notificationRecurringExpenseBody(String expenseName) {
    return '$expenseName a été ajoutée.';
  }

  @override
  String get notificationSettlementRequestTitle => 'Règlement à confirmer';

  @override
  String notificationSettlementPaidYouBody(
      String actorName, String amount, String groupName) {
    return '$actorName indique vous avoir payé $amount dans $groupName. Confirmez pour actualiser les soldes.';
  }

  @override
  String notificationSettlementYouPaidBody(
      String actorName, String amount, String groupName) {
    return '$actorName indique que vous lui avez payé $amount dans $groupName. Confirmez pour actualiser les soldes.';
  }

  @override
  String get notificationSettlementConfirmedTitle => 'Règlement confirmé';

  @override
  String notificationSettlementConfirmedBody(
      String actorName, String amount, String groupName) {
    return '$actorName a confirmé votre règlement de $amount dans $groupName.';
  }

  @override
  String get notificationSettlementDeclinedTitle => 'Règlement refusé';

  @override
  String notificationSettlementDeclinedBody(
      String actorName, String amount, String groupName) {
    return '$actorName a refusé votre règlement de $amount dans $groupName.';
  }

  @override
  String get notificationMealPlanTitle => 'Menu mis à jour';

  @override
  String notificationMealPlanBody(String actorName, String groupName) {
    return '$actorName a mis à jour le menu dans $groupName.';
  }

  @override
  String get notificationWeeklyDigestTitle => 'Résumé de la semaine';

  @override
  String notificationWeeklyDigestBody(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Votre foyer a eu $count activités cette semaine',
      one: 'Votre foyer a eu 1 activité cette semaine',
      zero: 'Aucune activité du foyer cette semaine',
    );
    return '$_temp0';
  }

  @override
  String get notificationPinwallReminderTitle => 'Rappel';

  @override
  String get commonPhoto => 'Photo';

  @override
  String cookModeTimerStart(String label) {
    return 'Minuteur : $label. Appuie pour démarrer';
  }

  @override
  String get errorServerHiccup =>
      'Problème serveur — réessaie dans un instant.';

  @override
  String get errorConflict =>
      'Quelqu\'un d\'autre a modifié ceci. Actualise et réessaie.';

  @override
  String get errorNotFound => 'Introuvable. Il a peut-être été supprimé.';

  @override
  String get errorNoPermission => 'Tu n\'as pas la permission pour cela.';

  @override
  String get errorSignInAgain => 'Reconnecte-toi.';

  @override
  String get errorGenericRetry => 'Une erreur est survenue. Réessaie.';

  @override
  String get createListTodoDesc =>
      'Une simple liste de tâches pour ce qu\'il faut faire.';

  @override
  String get createListCustomDesc =>
      'Une liste flexible pour tout ce qui ne rentre pas dans les cases.';

  @override
  String get createListScanSemantics =>
      'Scanner une liste via l\'appareil photo';

  @override
  String get createListHouseholdLabel => 'Foyer';

  @override
  String get createListNoHousehold => 'Aucun foyer disponible.';

  @override
  String get sheetJoinCodeExample => 'SUNNY-TACO-X7WM2K9PQ6R8S';

  @override
  String joinMembersAlreadyInside(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count membres déjà présents',
      one: '1 membre déjà présent',
    );
    return '$_temp0';
  }

  @override
  String get inviteQrUnavailable => 'QR indisponible';

  @override
  String expenseCreationSplitAssignedOf(String assigned, String total) {
    return '$assigned sur $total';
  }

  @override
  String expenseCreationSplitAmountsNegative(String assigned) {
    return '$assigned · les montants ne peuvent pas être négatifs';
  }

  @override
  String expenseCreationSplitLeftToAssign(String assigned, String remaining) {
    return '$assigned · $remaining restant à attribuer';
  }

  @override
  String expenseCreationSplitOver(String assigned, String over) {
    return '$assigned · $over en trop';
  }

  @override
  String expenseCreationSplitPercentRange(String sum) {
    return '$sum % attribué · chaque part doit être entre 0 et 100 %';
  }

  @override
  String expenseCreationSplitPercentOf100(String sum) {
    return '$sum % de 100 %';
  }

  @override
  String expenseCreationSplitSharesPerShare(num count, String perShare) {
    return '$count parts · $perShare par part';
  }

  @override
  String expenseCreationSplitEach(String amount) {
    return '$amount chacun';
  }

  @override
  String expenseCreationSplitApproxEach(String amount) {
    return '≈ $amount chacun';
  }

  @override
  String expenseCreationRemoveFromSplit(String name) {
    return 'Retirer $name du partage';
  }

  @override
  String expenseCreationAddToSplit(String name) {
    return 'Ajouter $name au partage';
  }

  @override
  String get expenseDetailCouldNotLoadSplits =>
      'Impossible de charger les parts.';

  @override
  String get expenseDetailCouldNotLoadReceipts =>
      'Impossible de charger les reçus.';

  @override
  String get expenseDetailCouldNotRemoveReceipt =>
      'Impossible de supprimer le reçu.';

  @override
  String get expenseDetailRemoving => 'Suppression…';

  @override
  String get recipeAddToListTargetList => 'Liste cible';

  @override
  String get recipeAddToListNoIngredients => 'Pas d\'ingrédients';

  @override
  String get recipeAddToListNoIngredientsDesc =>
      'Cette recette n\'a pas d\'ingrédients analysés';

  @override
  String recipeAddToListRemoveFromSelection(String name) {
    return 'Retirer $name de la sélection';
  }

  @override
  String recipeAddToListAddToSelection(String name) {
    return 'Ajouter $name à la sélection';
  }

  @override
  String get pinwallLinkChore => 'Une tâche';

  @override
  String get pinwallLinkList => 'Une liste';

  @override
  String get pinwallCouldNotLoad => 'Impossible de charger le pinwall.';

  @override
  String get composerItemHint => 'ex. Lait, 2 avocats ou 500 g de farine';

  @override
  String get aisleOther => 'Autre';

  @override
  String hubHouseholdsCurrent(String name) {
    return 'Foyers, actuel $name';
  }

  @override
  String recipeDetailStepCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count étapes',
      one: '1 étape',
    );
    return '$_temp0';
  }

  @override
  String get currencyUsd => 'USD - Dollar américain';

  @override
  String get currencyEur => 'EUR - Euro';

  @override
  String get currencyGbp => 'GBP - Livre sterling';

  @override
  String get currencyJpy => 'JPY - Yen japonais';

  @override
  String get currencyCad => 'CAD - Dollar canadien';

  @override
  String get currencyAud => 'AUD - Dollar australien';

  @override
  String get currencyChf => 'CHF - Franc suisse';

  @override
  String get currencySek => 'SEK - Couronne suédoise';

  @override
  String get currencyNok => 'NOK - Couronne norvégienne';

  @override
  String get currencyDkk => 'DKK - Couronne danoise';

  @override
  String get currencyPln => 'PLN - Złoty polonais';

  @override
  String get currencyCzk => 'CZK - Couronne tchèque';

  @override
  String get currencyHuf => 'HUF - Forint hongrois';

  @override
  String get runningLowHeading => 'Presque épuisé';

  @override
  String runningLowDaysAgo(num days) {
    return 'il y a ${days}j';
  }

  @override
  String get restockReasonDue => 'À racheter';

  @override
  String get restockReasonUsual => 'Achat habituel';

  @override
  String get restockReasonGoesWith => 'Va avec cette liste';

  @override
  String get householdStorageTitle => 'Stockage du foyer';

  @override
  String householdStorageUsedOf(String used, String limit) {
    return '$used utilisés sur $limit';
  }

  @override
  String householdStorageUsedUnlimited(String used) {
    return '$used utilisés · sans limite';
  }

  @override
  String householdStoragePending(String pending) {
    return '$pending sont réservés pour les envois en cours.';
  }

  @override
  String get householdStorageProgressLabel => 'Stockage du foyer utilisé';

  @override
  String get accountSendFeedback => 'Envoyer un avis';

  @override
  String get feedbackCardTitle => 'Aidez à façonner mitlist';

  @override
  String get feedbackCardBody =>
      'Proposez une fonctionnalité, signalez un bug ou partagez une idée — ça arrive directement à l\'équipe.';

  @override
  String get feedbackSheetTitle => 'Envoyer un avis';

  @override
  String get feedbackSheetIntro =>
      'Proposez une fonctionnalité, signalez un bug ou dites-nous ce qui pourrait mieux fonctionner — nous lisons chaque message.';

  @override
  String get feedbackFieldLabel => 'Votre message';

  @override
  String get feedbackFieldHint => 'J\'aimerais que mitlist puisse…';

  @override
  String get feedbackSend => 'Envoyer';

  @override
  String get feedbackSending => 'Envoi…';

  @override
  String get feedbackSent => 'Merci — votre demande a été envoyée !';

  @override
  String get feedbackEmpty => 'Veuillez d\'abord écrire un court message.';

  @override
  String get feedbackFailed =>
      'Impossible d\'envoyer votre demande pour le moment. Veuillez réessayer plus tard.';

  @override
  String get accountOcrTrainingTitle => 'Améliorer l’OCR manuscrit hors ligne';

  @override
  String get accountOcrTrainingDescription =>
      'Les lignes vérifiées manuellement restent sur cet appareil jusqu’à leur exportation ou suppression. Rien n’est envoyé.';

  @override
  String get accountOcrTrainingExport =>
      'Exporter les données d’entraînement OCR';

  @override
  String accountOcrTrainingSamples(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes corrigées',
      one: '1 ligne corrigée',
      zero: 'Aucune ligne corrigée',
    );
    return '$_temp0';
  }

  @override
  String get accountOcrTrainingClear =>
      'Supprimer les données d’entraînement OCR';

  @override
  String get accountOcrTrainingExportEmpty =>
      'Il n’y a pas encore de lignes OCR corrigées à exporter.';

  @override
  String get accountOcrTrainingClearTitle =>
      'Supprimer les données d’entraînement OCR ?';

  @override
  String get accountOcrTrainingClearBody =>
      'Cette action supprime définitivement toutes les lignes enregistrées sur cet appareil.';

  @override
  String get billingPremiumTitle => 'mitlist premium';

  @override
  String get billingLimitReachedTitle => 'Ce foyer est complet';

  @override
  String billingLimitReachedBody(num limit, num next) {
    return 'Les foyers jusqu’à $limit personnes sont gratuits. Pour ajouter un ${next}e membre, une personne doit prendre premium — et cela couvre tout le monde ici.';
  }

  @override
  String get billingCoversOneHousehold =>
      'Premium s’applique à un seul foyer à la fois. Vous choisissez lequel et pouvez en changer quand vous voulez.';

  @override
  String billingCoveredBy(String name) {
    return 'Premium sur ce foyer, payé par $name.';
  }

  @override
  String get billingPremiumActive => 'Premium est actif ici';

  @override
  String get billingMoveHereTitle => 'Déplacer votre premium ici';

  @override
  String get billingMoveHereBody =>
      'Vous avez déjà premium sur un autre foyer. Déplacez-le ici au lieu de payer deux fois : l’autre foyer garde tous ses membres, mais ne pourra plus en ajouter.';

  @override
  String get billingMoveHereAction => 'Déplacer premium ici';

  @override
  String get billingMoved => 'Premium couvre maintenant ce foyer.';

  @override
  String get billingMoveFailed =>
      'Impossible de déplacer votre premium. Veuillez réessayer.';

  @override
  String get billingChooseHousehold => 'Choisissez votre foyer premium';

  @override
  String get billingMonthly => 'Mensuel';

  @override
  String get billingYearly => 'Annuel';

  @override
  String get billingYearlyBadge => 'Meilleure offre';

  @override
  String get billingSubscribe => 'Obtenir premium';

  @override
  String get billingOpeningCheckout => 'Ouverture du paiement...';

  @override
  String get billingCheckoutFailed =>
      'Impossible de démarrer le paiement. Veuillez réessayer.';

  @override
  String get billingManage => 'Gérer l’abonnement';

  @override
  String get billingPortalFailed =>
      'Impossible d’ouvrir le portail de facturation.';

  @override
  String get billingReturnHint =>
      'Terminez dans votre navigateur, puis revenez — premium s’active automatiquement.';

  @override
  String get billingProcessing => 'Traitement de ton achat...';

  @override
  String get billingRestore => 'Restaurer les achats';

  @override
  String get billingAutoRenewDisclosure =>
      'Le paiement est débité sur ton compte de la boutique. L\'abonnement se renouvelle automatiquement, sauf annulation au moins 24 heures avant la fin de la période en cours. Gère-le ou annule-le dans ton compte App Store ou Google Play.';

  @override
  String get billingPurchased => 'Premium est actif. Merci !';

  @override
  String get billingAccountCardTitle => 'Premium';

  @override
  String billingAccountCardFree(num limit) {
    return 'Vous êtes sur l’offre gratuite. Les foyers jusqu’à $limit personnes sont gratuits.';
  }

  @override
  String billingAccountCardActive(String household) {
    return 'Premium est actif sur $household.';
  }

  @override
  String get billingAccountCardUnassigned =>
      'Premium est actif mais n’est encore attribué à aucun foyer.';

  @override
  String billingRenewsOn(String date) {
    return 'Renouvellement le $date';
  }

  @override
  String billingEndsOn(String date) {
    return 'Se termine le $date';
  }

  @override
  String billingMemberUsage(num count, num limit) {
    return '$count place(s) gratuite(s) sur $limit utilisée(s)';
  }

  @override
  String get billingUnlimitedMembers => 'Membres illimités';

  @override
  String get premiumSeatsEyebrow => 'Votre foyer';

  @override
  String get premiumSeatsHeadline => 'De la place pour une personne de plus';

  @override
  String premiumSeatsBody(int limit) {
    return 'Les foyers jusqu’à $limit personnes sont gratuits. Premium ouvre la place suivante et toutes celles d’après, et couvre tout le monde ici — pas seulement la personne qui paie.';
  }

  @override
  String get premiumSeatsOpenPlace => 'Place libre';

  @override
  String get premiumListsEyebrow => 'Listes';

  @override
  String get premiumListsHeadline => 'Personne n’achète le lait deux fois';

  @override
  String get premiumListsBody =>
      'Une seule liste, toutes les mains. Cochez un article et il est réglé pour tout le foyer d’un coup — y compris pour la personne que vous essayez d’ajouter.';

  @override
  String get premiumMoneyEyebrow => 'Argent';

  @override
  String get premiumMoneyHeadline =>
      'Une personne de plus, une part plus petite';

  @override
  String get premiumMoneyBody =>
      'Retirez un nom du partage et regardez la part de chacun augmenter. Voilà ce que vaut une personne de plus, chaque semaine.';

  @override
  String get premiumMoneyExpense => 'Les grosses courses';

  @override
  String premiumMoneySplitLine(int ways, String each) {
    return '$ways parts · $each chacun';
  }

  @override
  String get premiumChoresEyebrow => 'Tâches';

  @override
  String get premiumChoresHeadline => 'Votre tour revient moins souvent';

  @override
  String premiumChoresBody(int count) {
    return 'Un roulement se répartit entre autant de personnes qu’il y en a. Cochez une tâche pour la passer : à $count, votre nom est à $count tours.';
  }

  @override
  String premiumChoresTurnEvery(int count) {
    return 'De retour chez vous dans $count tours';
  }

  @override
  String get premiumPlanEyebrow => 'Premium';

  @override
  String get premiumPlanHeadline => 'Ouvrir le foyer';

  @override
  String get premiumSeeThePlan => 'Voir l’offre';

  @override
  String listDetailItemRestored(String name) {
    return '$name est de retour dans la liste';
  }

  @override
  String listDetailItemAlreadyOnList(String name) {
    return '$name est déjà dans la liste';
  }

  @override
  String get composerSuggestionCheckedOff => 'Coché';

  @override
  String get composerSuggestionOnList => 'Dans la liste';

  @override
  String get featureBoardTitle => 'Tableau des fonctionnalités';

  @override
  String get featureBoardBannerTitle => 'Que devons-nous créer ensuite ?';

  @override
  String get featureBoardBannerBody =>
      'Découvrez nos projets, proposez une idée et votez pour les fonctionnalités qui comptent.';

  @override
  String get featureBoardBannerAction => 'Ouvrir le tableau';

  @override
  String get featureBoardAdd => 'Ajouter une demande';

  @override
  String get featureBoardIntroTitle => 'Créé avec vos idées';

  @override
  String get featureBoardIntroBody =>
      'Votez pour vos idées préférées, signalez ce qui ne va pas et suivez ce sur quoi nous travaillons.';

  @override
  String get featureBoardLoadFailed => 'Impossible de charger le tableau';

  @override
  String get featureBoardTryAgain => 'Vérifiez votre connexion et réessayez.';

  @override
  String get featureBoardNoFeaturesTitle => 'Aucune idée pour le moment';

  @override
  String get featureBoardNoFeaturesBody =>
      'Soyez la première personne à proposer une amélioration pour mitlist.';

  @override
  String get featureBoardNewTitle => 'Nouvelle demande';

  @override
  String get featureBoardNewIntro =>
      'Décrivez une amélioration pour laquelle d’autres foyers pourront aussi voter.';

  @override
  String get featureBoardTitleLabel => 'Titre de la fonctionnalité';

  @override
  String get featureBoardTitleHint => 'Modèles de listes de courses partagées';

  @override
  String get featureBoardDescriptionLabel =>
      'Pourquoi serait-ce utile ? (facultatif)';

  @override
  String get featureBoardDescriptionHint =>
      'Expliquez-nous comment vous l’utiliseriez…';

  @override
  String get featureBoardEmpty => 'Ajoutez un titre court à votre idée.';

  @override
  String get featureBoardSubmit => 'Ajouter au tableau';

  @override
  String get featureBoardSubmitting => 'Ajout…';

  @override
  String get featureBoardCreated => 'Votre idée est sur le tableau.';

  @override
  String get featureBoardFailed =>
      'Impossible de mettre à jour le tableau. Réessayez.';

  @override
  String get featureBoardInProgress => 'En cours';

  @override
  String get featureBoardShipped => 'Publié';

  @override
  String get featureBoardUpvote => 'Voter pour la fonctionnalité';

  @override
  String get featureBoardUpvoted => 'Vote enregistré';

  @override
  String featureBoardVotes(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
    );
    return '$_temp0';
  }

  @override
  String get featureBoardUnderReview => 'En cours d\'examen';

  @override
  String get featureBoardFilterAll => 'Tout';

  @override
  String get featureBoardFilterFeatures => 'Fonctionnalités';

  @override
  String get featureBoardFilterBugs => 'Bugs';

  @override
  String get featureBoardSortTop => 'Top';

  @override
  String get featureBoardSortNew => 'Nouveau';

  @override
  String get featureBoardKindLabel => 'De quoi s\'agit-il ?';

  @override
  String get featureBoardKindFeature => 'Demande de fonctionnalité';

  @override
  String get featureBoardKindBug => 'Rapport de bug';

  @override
  String get featureBoardBugChip => 'Bug';

  @override
  String get featureBoardNewBugIntro =>
      'Dites-nous ce qui ne marche pas. Ceux qui ont le même problème pourront voter.';

  @override
  String get featureBoardBugTitleLabel =>
      'Qu\'est-ce qui n\'a pas fonctionné ?';

  @override
  String get featureBoardBugTitleHint =>
      'Les totaux ne correspondent plus après le partage d\'une dépense';

  @override
  String get featureBoardBugDescriptionLabel =>
      'Étapes pour reproduire (facultatif)';

  @override
  String get featureBoardBugDescriptionHint =>
      'Qu\'avez-vous fait, et que s\'est-il passé à la place ?';

  @override
  String get featureBoardBugEmpty => 'Ajoutez un bref résumé du bug.';

  @override
  String get featureBoardBugCreated =>
      'Merci, votre signalement est sur le tableau.';

  @override
  String featureBoardComments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count commentaires',
      one: '1 commentaire',
      zero: 'Aucun commentaire',
    );
    return '$_temp0';
  }

  @override
  String get featureBoardCommentsHeading => 'Conversation';

  @override
  String get featureBoardTeamBadge => 'équipe mitlist';

  @override
  String get featureBoardYou => 'Vous';

  @override
  String get featureBoardAnonymous => 'Un utilisateur mitlist';

  @override
  String get featureBoardCommentHint => 'Ajouter un commentaire…';

  @override
  String get featureBoardCommentSend => 'Publier le commentaire';

  @override
  String get featureBoardCommentFailed =>
      'Impossible de publier votre commentaire. Veuillez réessayer.';

  @override
  String get featureBoardNoComments =>
      'Pas encore de commentaires. Une question ou un cas d\'usage ? Lancez la conversation.';

  @override
  String get featureBoardDetailLoadFailed =>
      'Impossible de charger cette demande';

  @override
  String get featureBoardTimeJustNow => 'À l\'instant';

  @override
  String featureBoardTimeMinutesAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count min',
      one: 'il y a 1 min',
    );
    return '$_temp0';
  }

  @override
  String featureBoardTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count heures',
      one: 'il y a 1 heure',
    );
    return '$_temp0';
  }

  @override
  String featureBoardTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'il y a $count jours',
      one: 'Hier',
    );
    return '$_temp0';
  }

  @override
  String get featureBoardStatusInProgressHint =>
      'Nous y travaillons en ce moment.';

  @override
  String get featureBoardStatusUnderReviewHint =>
      'Nous l\'avons vu et l\'étudions. Les votes et commentaires aident.';

  @override
  String get featureBoardStatusShippedHint =>
      'C\'est en ligne. Mettez l\'app à jour si vous ne le voyez pas encore.';

  @override
  String get weeklySummaryTitle => 'Semaine en revue';

  @override
  String weeklySummaryActivities(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'activités',
      one: 'activité',
    );
    return '$_temp0';
  }

  @override
  String weeklySummaryPercentVsLastWeek(int percent) {
    return '$percent% par rapport à la semaine dernière';
  }

  @override
  String get weeklySummarySameAsLastWeek => 'Comme la semaine dernière';

  @override
  String get weeklySummaryFirstWeek => 'Votre première semaine d\'activité';

  @override
  String get weeklySummaryYourShareTitle => 'Votre part';

  @override
  String weeklySummaryYourShareBody(int mine, int total) {
    return 'Vous avez contribué à $mine sur $total.';
  }

  @override
  String weeklySummaryPersonalUp(int count) {
    return '$count de plus que la semaine dernière. Bravo.';
  }

  @override
  String weeklySummaryPersonalDown(int count) {
    return '$count de moins que la semaine dernière.';
  }

  @override
  String get weeklySummaryPersonalSame =>
      'Exactement autant que la semaine dernière.';

  @override
  String weeklySummaryActiveMembers(int active, int total) {
    return '$active colocataires sur $total ont participé.';
  }

  @override
  String get weeklySummaryBreakdownTitle => 'Où cela s\'est passé';

  @override
  String get weeklySummaryCategoryLists => 'Articles ajoutés';

  @override
  String get weeklySummaryCategoryExpenses => 'Dépenses enregistrées';

  @override
  String get weeklySummaryCategoryChores => 'Tâches terminées';

  @override
  String get weeklySummaryCategoryMeals => 'Repas planifiés';

  @override
  String get weeklySummaryCategoryRecipes => 'Recettes ajoutées';

  @override
  String get weeklySummaryNudgeRollTitle => 'Vous êtes lancés';

  @override
  String weeklySummaryNudgeRollBody(int total) {
    return '$total choses ont été gérées cette semaine, plus que la semaine dernière. Continuez.';
  }

  @override
  String get weeklySummaryNudgeSlipTitle => 'Une semaine plus calme';

  @override
  String get weeklySummaryNudgeSlipBody =>
      'Le rythme a un peu ralenti. Un article de liste ou une tâche suffit à inverser la tendance.';

  @override
  String get weeklySummaryNudgeJoinTitle => 'Participez cette semaine';

  @override
  String get weeklySummaryNudgeJoinBody =>
      'Vos colocataires ont fait tourner la maison. Ajoutez un article, enregistrez une dépense ou cochez une tâche.';

  @override
  String get weeklySummaryOpenHousehold => 'Ouvrir le foyer';

  @override
  String get weeklySummaryEmptyTitle => 'Une semaine calme';

  @override
  String get weeklySummaryEmptyBody =>
      'Rien n\'a été enregistré ces sept derniers jours. Ajoutez quelque chose et cela apparaîtra ici la semaine prochaine.';

  @override
  String get weeklySummaryLoadFailed => 'Impossible de charger votre semaine';

  @override
  String get weeklySummaryTryAgain => 'Vérifiez votre connexion et réessayez.';

  @override
  String recipeCreationSharedWithHousehold(String name) {
    return 'Tout le monde dans $name peut trouver et utiliser cette recette.';
  }

  @override
  String get recipeCreationNoHousehold =>
      'Rejoins un foyer pour partager des recettes avec ceux qui cuisinent avec toi.';

  @override
  String get recipeDetailShareTooltip => 'Partager la recette';

  @override
  String recipeShareText(String title, String url) {
    return '$title — cuisine-la avec moi sur Mitlist : $url';
  }

  @override
  String get recipeTagsClear => 'Effacer les tags';

  @override
  String get sharedRecipeTitle => 'Recette partagée';

  @override
  String sharedRecipeBy(String author) {
    return 'par $author';
  }

  @override
  String get sharedRecipeSavePersonal => 'Ajouter à ma cuisine';

  @override
  String sharedRecipeSaveHousehold(String name) {
    return 'Ajouter à la cuisine de $name';
  }

  @override
  String get sharedRecipeSaved => 'Recette enregistrée';

  @override
  String get sharedRecipeSignInToSave =>
      'Connecte-toi pour enregistrer cette recette';

  @override
  String get sharedRecipeNotFoundTitle => 'Ce lien ne fonctionne plus';

  @override
  String get sharedRecipeNotFoundBody =>
      'La personne qui l\'a partagé l\'a peut-être désactivé. Demande-lui un nouveau lien.';

  @override
  String get sharedRecipeGetAppTitle => 'Cuisine ça dans Mitlist';

  @override
  String get sharedRecipeGetAppBody =>
      'Télécharge l\'app pour enregistrer des recettes, planifier les repas et faire les courses avec ton foyer.';

  @override
  String get recipeQuickCookbooks => 'Livres de recettes';

  @override
  String recipeQuickCookbooksDesc(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count livres',
      one: '1 livre',
      zero: 'Regroupez vos recettes',
    );
    return '$_temp0';
  }

  @override
  String get recipeQuickMealPlan => 'Menu de la semaine';

  @override
  String recipeQuickMealPlanDesc(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count repas cette semaine',
      one: '1 repas cette semaine',
      zero: 'Planifiez la semaine',
    );
    return '$_temp0';
  }

  @override
  String recipeSortChip(String label) {
    return 'Tri : $label';
  }

  @override
  String get recipeFiltersClear => 'Effacer les filtres';

  @override
  String recipeTagsMore(num count) {
    return '+$count de plus';
  }

  @override
  String get recipeTagsLess => 'Afficher moins';

  @override
  String get cookbooksShareWithHousehold => 'Partager avec le foyer';

  @override
  String cookbooksShareWithHouseholdDesc(String name) {
    return 'Tout le monde dans $name peut voir et compléter ce livre.';
  }

  @override
  String get cookbooksPersonalDesc => 'Vous seul pouvez voir ce livre.';

  @override
  String get cookbooksEditSheetTitle => 'Modifier le livre';

  @override
  String get cookbooksEdit => 'Modifier';

  @override
  String cookbooksOpen(String name) {
    return 'Ouvrir le livre $name';
  }

  @override
  String get cookbookAddRecipesSearchHint => 'Rechercher des recettes';

  @override
  String cookbookAddRecipesSubmit(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Ajouter $count recettes',
      one: 'Ajouter 1 recette',
      zero: 'Sélectionnez des recettes',
    );
    return '$_temp0';
  }

  @override
  String get cookbookAddRecipesNoMatch => 'Aucune recette ne correspond';

  @override
  String get cookbookAddRecipesAlreadyIn => 'Déjà dans ce livre';

  @override
  String cookbookDetailSharedWith(String name) {
    return 'Partagé avec $name';
  }

  @override
  String get cookbookDetailPersonal => 'Livre personnel';

  @override
  String get recipeDetailAddToCookbook => 'Ajouter à un livre';

  @override
  String get recipeAddToCookbookEmptyTitle => 'Aucun livre pour l’instant';

  @override
  String get recipeAddToCookbookEmptyDesc =>
      'Créez un livre pour regrouper vos recettes.';

  @override
  String get recipeAddToCookbookNewName => 'Nom du nouveau livre';

  @override
  String recipeAddedToCookbook(String name) {
    return 'Ajouté à $name';
  }

  @override
  String get recipeAddToCookbookFailed => 'Impossible d’ajouter au livre';

  @override
  String get sharedRecipeOpenInApp => 'Ouvrir dans Mitlist';

  @override
  String get openInAppButton => 'Ouvrir dans Mitlist';

  @override
  String recipeShareSubject(String title) {
    return '$title sur Mitlist';
  }

  @override
  String get welcomeGetStarted => 'Commencer';

  @override
  String get welcomeHaveAccount => 'J\'ai déjà un compte';

  @override
  String get tourSkip => 'Passer';

  @override
  String get tourNext => 'Suivant';

  @override
  String get tourShowMe => 'Montre-moi';

  @override
  String get tourBack => 'Retour';

  @override
  String tourStepOf(int step, int total) {
    return 'Étape $step sur $total';
  }

  @override
  String get tourSampleTag => 'Exemple';

  @override
  String get tourWhyEyebrow => 'Ton foyer';

  @override
  String get tourWhyHeadline =>
      'Qui a acheté le lait, qui doit quoi, à qui le tour ?';

  @override
  String get tourWhyBody =>
      'mitlist est le carnet partagé des gens avec qui tu vis. Voici une coloc d\'exemple à explorer.';

  @override
  String get tourWhyNote => 'Le propriétaire passe jeudi à 10h';

  @override
  String tourWhyToBuy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count à acheter',
      one: '1 à acheter',
    );
    return '$_temp0';
  }

  @override
  String tourWhyOverdue(String title) {
    return '$title est en retard';
  }

  @override
  String get tourListsEyebrow => 'Listes';

  @override
  String get tourListsHeadline =>
      'Une liste. Tout le monde ajoute. Celui qui est au magasin achète.';

  @override
  String get tourListsBody =>
      'Coche ce qui est fait, ajoute ce qui manque. Toute la coloc le voit changer.';

  @override
  String get tourListsAddHint => 'Ajouter quelque chose…';

  @override
  String tourListsAddedBy(String name) {
    return 'Ajouté par $name';
  }

  @override
  String get tourMoneyEyebrow => 'Argent';

  @override
  String get tourMoneyHeadline => 'Partage la pizza. Fini le calcul mental.';

  @override
  String get tourMoneyBody =>
      'Touche un prénom pour le retirer du partage. Le solde se met à jour tout seul.';

  @override
  String get tourMoneyPizza => 'Soirée pizza';

  @override
  String get tourMoneyRepair => 'Réparation du lave-linge';

  @override
  String get tourMoneyPaidByYou => 'payé par toi';

  @override
  String tourMoneyPaidBy(String name) {
    return 'payé par $name';
  }

  @override
  String get tourMoneySplitBetween => 'Partagé entre';

  @override
  String tourMoneyOwesYou(String name, String amount) {
    return '$name te doit $amount';
  }

  @override
  String get tourMoneyJustYou => 'Toi seulement. Rien à partager.';

  @override
  String tourMoneyOverallOwed(String amount) {
    return 'Au total, on te doit $amount';
  }

  @override
  String tourMoneyOverallOwe(String amount) {
    return 'Au total, tu dois $amount';
  }

  @override
  String get tourMoneyOverallSquare => 'Au total, vous êtes quittes';

  @override
  String get tourChoresEyebrow => 'Corvées';

  @override
  String get tourChoresHeadline =>
      'Les poubelles sortent jeudi. C\'est le tour d\'Ines, et elle le sait.';

  @override
  String get tourChoresBody =>
      'Les corvées tournent. Coche la tienne et elle passe à la personne suivante.';

  @override
  String get tourChoresOverdue => 'En retard';

  @override
  String get tourChoresDueToday => 'Pour aujourd\'hui';

  @override
  String tourChoresDueIn(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Dans $days jours',
      one: 'Pour demain',
    );
    return '$_temp0';
  }

  @override
  String get tourChoresWeekly => 'Chaque semaine';

  @override
  String get tourChoresYourTurn => 'À toi';

  @override
  String tourChoresTurnOf(String name) {
    return 'Au tour de $name';
  }

  @override
  String tourChoresNext(String name, int days) {
    return 'Ensuite : $name, dans $days jours';
  }

  @override
  String get tourRecipesEyebrow => 'Recettes';

  @override
  String get tourRecipesHeadline =>
      'Jeudi, c\'est shakshuka. Les œufs sont déjà sur la liste.';

  @override
  String get tourRecipesBody =>
      'Planifie un repas et envoie ses ingrédients directement sur la liste de courses.';

  @override
  String get tourRecipesTitle => 'Shakshuka';

  @override
  String get tourRecipesServings => '4 parts · 30 min';

  @override
  String get tourRecipesPlanned => 'Prévu pour jeudi';

  @override
  String get tourRecipesAddIngredients => 'Ajouter à la liste';

  @override
  String get tourRecipesAddedButton => 'Sur la liste';

  @override
  String tourRecipesAddedToast(int count, String list) {
    return '$count articles ajoutés à $list';
  }

  @override
  String get tourFinishEyebrow => 'Ton foyer';

  @override
  String get tourFinishHeadline =>
      'Maintenant, fais-le avec les gens avec qui tu vis vraiment.';

  @override
  String get tourFinishBody =>
      'Crée un compte pour monter ton foyer et les inviter. Gratuit jusqu\'à 4 personnes.';

  @override
  String get tourFinishEmail => 'Continuer avec un e-mail';

  @override
  String get supporterTitle => 'Pack soutien';

  @override
  String get supporterCardTitle => 'Soutenir mitlist';

  @override
  String get supporterCardBody =>
      'mitlist est gratuit et le restera. Une contribution unique aide à payer les serveurs, et vous recevez quelques petits remerciements.';

  @override
  String get supporterCardActiveBody =>
      'Vous soutenez mitlist. Merci de le faire tourner.';

  @override
  String get supporterBuy => 'Soutenir mitlist';

  @override
  String supporterBuyWithPrice(String price) {
    return 'Soutenir mitlist · $price';
  }

  @override
  String get supporterOnce =>
      'Achat unique. Pas d\'abonnement, rien à résilier.';

  @override
  String get supporterPerkBadge =>
      'Un badge de soutien à côté de votre nom, visible par votre foyer';

  @override
  String get supporterPerkAccent =>
      'Des couleurs d\'accent pour personnaliser l\'app';

  @override
  String get supporterPerkHosting => 'Finance les serveurs du service hébergé';

  @override
  String get supporterBadgeLabel => 'Soutien';

  @override
  String get supporterPurchased => 'Vous soutenez maintenant mitlist. Merci !';

  @override
  String get supporterSheetHeadline => 'Faire tourner mitlist';

  @override
  String get accountAccent => 'Couleur d\'accent';

  @override
  String get accentClementine => 'Clémentine';

  @override
  String get accentMoss => 'Mousse';

  @override
  String get accentSky => 'Ciel';

  @override
  String get accentBerry => 'Baie';

  @override
  String get accentViolet => 'Violet';

  @override
  String get accentLockedHint =>
      'Les couleurs autres que Clémentine font partie du pack soutien.';

  @override
  String get accentUnlock => 'Débloquer avec le pack soutien';
}
