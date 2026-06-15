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
  String get welcomeGuestFootnote =>
      'Pas de compte nécessaire. Essaie tout gratuitement pendant 30 jours.';

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
  String get choreCreationAssignLabel => 'Attribution';

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
  String get choreDetailAssignee => 'Attribuée à';

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
  String get expenseSettlementRecorded => 'Règlement enregistré';

  @override
  String get expenseSettlementFailed =>
      'Impossible d\'enregistrer le règlement.';

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
      'Le nouveau mot de passe doit contenir au moins 6 caractères.';

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
      'Utilise mitlist de manière responsable et respecte la vie privée des membres de ton foyer. N\'abuse pas des fonctionnalités ou des données partagées. mitlist est fourni tel quel sans garantie.';

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
  String get notifPrefAppBarTitle => 'Préférences de notifications';

  @override
  String get notifPrefFailedLoad =>
      'Impossible de charger les préférences de notifications.';

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
  String get notifPrefExpenseCreated => 'Dépense créée';

  @override
  String get notifPrefExpenseCreatedDesc =>
      'Quand une nouvelle dépense est enregistrée';

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
  String get expenseCreationNotesHint => 'Notes (optionnel)';

  @override
  String get expenseCreationDateLabel =>
      'Date de la dépense. Appuie pour changer.';

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
  String get expenseCreationReceiptUploadFailed =>
      'Dépense enregistrée, mais l\'envoi du reçu a échoué.';

  @override
  String get expenseCreationExpenseAdded => 'Dépense ajoutée';

  @override
  String get pinwallBoardLabel => 'Pinwall';

  @override
  String get pinwallDragHint =>
      'Glisser les notes pour déplacer  ·  Pincer pour zoomer';

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
  String get offlineBannerSyncing => 'Synchronisation des modifications…';

  @override
  String offlineBannerFailedCount(num count) {
    return 'Impossible de synchroniser $count modifications';
  }

  @override
  String get offlineBannerFailedOne =>
      'Impossible de synchroniser une modification';

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
