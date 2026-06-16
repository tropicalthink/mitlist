// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonSave => 'Save';

  @override
  String get commonBack => 'Back';

  @override
  String get commonClose => 'Close';

  @override
  String get commonDone => 'Done';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonConfirm => 'Confirm';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonNext => 'Next';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonChange => 'Change';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonArchive => 'Archive';

  @override
  String get commonOptions => 'Options';

  @override
  String get commonSettings => 'Settings';

  @override
  String get commonName => 'Name';

  @override
  String get commonDescription => 'Description';

  @override
  String get commonNotes => 'Notes';

  @override
  String get commonAmount => 'Amount';

  @override
  String get commonPreview => 'Preview';

  @override
  String get commonShare => 'Share';

  @override
  String get commonCopy => 'Copy';

  @override
  String get commonListName => 'List name';

  @override
  String get commonSaving => 'Saving…';

  @override
  String get commonAdding => 'Adding…';

  @override
  String get commonDeleting => 'Deleting…';

  @override
  String get commonNoHousehold => 'No household yet';

  @override
  String get commonCreateJoinHousehold =>
      'Create or join a household before adding items.';

  @override
  String get commonGoToHouseholds => 'Go to households';

  @override
  String get commonSomethingWentWrong => 'Something went wrong';

  @override
  String get commonFailedToLoad => 'Failed to load. Please try again.';

  @override
  String get commonCheckConnection => 'Check your connection and try again.';

  @override
  String get commonClearSearch => 'Clear search';

  @override
  String commonMember(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '$count member',
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
  String get commonLoadingMembers => 'Loading members...';

  @override
  String get welcomeTagline => 'Your household, organized.';

  @override
  String get welcomeCardTitle => 'Lists, chores, money.\nAll in one place.';

  @override
  String get welcomeCardBody =>
      'Built for flatmates who want less friction and more clarity.';

  @override
  String get welcomeCreateHousehold => 'Create free household';

  @override
  String get welcomeSignIn => 'Sign in';

  @override
  String get welcomeGuestLoading => 'Setting up...';

  @override
  String get welcomeContinueAsGuest => 'Continue as guest';

  @override
  String get welcomeGuestFootnote =>
      'No account needed. Try everything free for 30 days.';

  @override
  String get hubAppBarTitle => 'Home';

  @override
  String get hubHouseholdsSheetTitle => 'Households';

  @override
  String hubSwitchToHousehold(String name) {
    return 'Switch to $name';
  }

  @override
  String get hubCreateHousehold => 'Create household';

  @override
  String get hubJoinHousehold => 'Join household';

  @override
  String get hubInviteToHousehold => 'Invite to household';

  @override
  String get hubHouseholdSettings => 'Household settings';

  @override
  String get hubWelcomeHeadline => 'Welcome to mitlist';

  @override
  String get hubWelcomeDescription =>
      'Create or join a household to start sharing lists, chores, and expenses.';

  @override
  String get hubCreateAHousehold => 'Create a household';

  @override
  String get hubJoinWithInviteCode => 'Join with invite code';

  @override
  String get hubQuickAdd => 'Quick add';

  @override
  String get hubLoadError =>
      'Couldn’t load your households. Check your connection and try again.';

  @override
  String get hubCalendarTooltip => 'Calendar';

  @override
  String get myHouseholdsTitle => 'My Households';

  @override
  String get groupsJoinWithCode => 'Join with code';

  @override
  String get groupsFailedLoad => 'Failed to load households';

  @override
  String get groupsFailedMore => 'Failed to load more households';

  @override
  String get groupsEmptyTitle => 'No households yet';

  @override
  String get groupsEmptyDesc => 'Create one to start organizing your home.';

  @override
  String get groupsCreateHousehold => 'Create household';

  @override
  String get choreAppBarTitle => 'Chores';

  @override
  String get choreAddChore => 'Add chore';

  @override
  String get choreAddHouseholds => 'Households';

  @override
  String get choreRetry => 'Retry';

  @override
  String get choreNoHouseholdTitle => 'No household yet';

  @override
  String get choreNoHouseholdDesc =>
      'Create or join a household before adding chores.';

  @override
  String get choreGoToHouseholds => 'Go to households';

  @override
  String get choreNoChoresTitle => 'No chores yet';

  @override
  String get choreNoChoresDesc =>
      'Track recurring household tasks. Assign them to anyone in your group.';

  @override
  String get choreAddAChore => 'Add a chore';

  @override
  String get choreSectionOverdue => 'Overdue';

  @override
  String get choreSectionToday => 'Today';

  @override
  String get choreSectionThisWeek => 'This week';

  @override
  String get choreSectionLater => 'Later';

  @override
  String get choreNothingOnYou => 'Nothing on you right now';

  @override
  String get choreNothingOnYouDesc =>
      'Your household has chores, but none are assigned to you.';

  @override
  String get choreSeeEveryonesChores => 'See everyone\'s chores';

  @override
  String choreDoneSnackbar(String choreTitle) {
    return '$choreTitle done';
  }

  @override
  String get choreFailedComplete =>
      'Failed to complete chore. Please try again.';

  @override
  String get choreFailedUndo =>
      'Failed to undo chore execution. Please try again.';

  @override
  String get choreFailedSkip => 'Failed to skip chore. Please try again.';

  @override
  String get choreFailedUpdateSubtask =>
      'Failed to update subtask. Please try again.';

  @override
  String get choreFailedAddSubtask =>
      'Failed to add subtask. Please try again.';

  @override
  String get choreCreateListFirst => 'Create a shopping list first.';

  @override
  String get choreAddSuppliesToList => 'Add supplies to list';

  @override
  String get choreSuppliesAdded => 'Supplies added to list';

  @override
  String get choreFailedAddSupplies =>
      'Failed to add supplies. Please try again.';

  @override
  String get choreFailedReschedule =>
      'Failed to reschedule chore. Please try again.';

  @override
  String get choreDeleteTitle => 'Delete chore';

  @override
  String get choreDeleteBody =>
      'This will permanently delete this chore and its history. This cannot be undone.';

  @override
  String get choreStatusDone => 'Done';

  @override
  String get choreStatusOverdue => 'Overdue';

  @override
  String get choreStatusDueToday => 'Due today';

  @override
  String get choreStatusDueSoon => 'Due soon';

  @override
  String get choreStatusScheduled => 'Scheduled';

  @override
  String get choreStatusPending => 'Pending';

  @override
  String get choreYourTurn => 'Your turn';

  @override
  String choreSomeonesTurn(String name) {
    return '$name\'s turn';
  }

  @override
  String get choreRefreshFailed => 'Couldn\'t refresh. Showing saved chores.';

  @override
  String choreDoneLast30Days(num count) {
    return '$count done, last 30 days';
  }

  @override
  String get choreYoureClear => 'You\'re clear';

  @override
  String choreHeroDescSingular(num count) {
    return '$count chore needs you now.';
  }

  @override
  String choreHeroDescPlural(num count) {
    return '$count chores need you now.';
  }

  @override
  String choreMeLabel(num count) {
    return 'Me ($count)';
  }

  @override
  String choreEveryoneLabel(num count) {
    return 'Everyone ($count)';
  }

  @override
  String get choreHowItSplits => 'How it splits';

  @override
  String choreSupplySingular(num count) {
    return '$count supply';
  }

  @override
  String choreSupplyPlural(num count) {
    return '$count supplies';
  }

  @override
  String get choreFrequencyHourly => 'Hourly';

  @override
  String get choreFrequencyDaily => 'Daily';

  @override
  String get choreFrequencyWeekly => 'Weekly';

  @override
  String get choreFrequencyMonthly => 'Monthly';

  @override
  String get choreFrequencyYearly => 'Yearly';

  @override
  String get choreFrequencyAsNeeded => 'As needed';

  @override
  String get choreFrequencyOneOff => 'One-off';

  @override
  String choreEveryInterval(num interval, String unit) {
    return 'Every $interval $unit';
  }

  @override
  String get choreDoneToday => 'Done today';

  @override
  String get choreDoneYesterday => 'Done yesterday';

  @override
  String choreDoneDaysAgo(num days) {
    return 'Done ${days}d ago';
  }

  @override
  String get choreSkipped => 'Skipped';

  @override
  String choreMarkNotDone(String title) {
    return 'Mark $title as not done';
  }

  @override
  String choreMarkDone(String title) {
    return 'Mark $title as done';
  }

  @override
  String get choreAllCaughtUp => 'You are all caught up';

  @override
  String choreCarryingShare(num my, num total) {
    return 'Carrying $my of $total open chores';
  }

  @override
  String get choreNothingShare => 'Nothing on you right now';

  @override
  String get choreCreationTitle => 'Add chore';

  @override
  String get choreCreationNameHint => 'Chore name';

  @override
  String get choreCreationYourRoutines => 'Your routines';

  @override
  String get choreCreationStartFromRoutine => 'Start from a routine';

  @override
  String get choreCreationSuggestions => 'Suggestions';

  @override
  String get choreCreationZoneLabel => 'Zone';

  @override
  String get choreCreationZoneKitchen => 'Kitchen';

  @override
  String get choreCreationZoneBathroom => 'Bathroom';

  @override
  String get choreCreationZoneLivingRoom => 'Living room';

  @override
  String get choreCreationZoneBedroom => 'Bedroom';

  @override
  String get choreCreationZoneOutdoor => 'Outdoor';

  @override
  String get choreCreationZoneShared => 'Shared';

  @override
  String get choreCreationRepeatsLabel => 'Repeats';

  @override
  String get choreCreationRecurrenceNone => 'None';

  @override
  String get choreCreationRecurrenceHourly => 'Hourly';

  @override
  String get choreCreationRecurrenceDaily => 'Daily';

  @override
  String get choreCreationRecurrenceWeekly => 'Weekly';

  @override
  String get choreCreationRecurrenceMonthly => 'Monthly';

  @override
  String get choreCreationRecurrenceYearly => 'Yearly';

  @override
  String get choreCreationRecurrenceAdaptive => 'Adaptive';

  @override
  String get choreCreationHintNone =>
      'A one-time chore. It won\'t come back on its own.';

  @override
  String get choreCreationHintHourly => 'Comes back every set number of hours.';

  @override
  String get choreCreationHintDaily => 'Comes back every set number of days.';

  @override
  String get choreCreationHintWeekly =>
      'Comes back each week on the days you pick.';

  @override
  String get choreCreationHintMonthly => 'Comes back monthly on the same date.';

  @override
  String get choreCreationHintYearly => 'Comes back yearly on the same date.';

  @override
  String get choreCreationHintAdaptive =>
      'Comes back based on when it was last done, not the calendar.';

  @override
  String get choreCreationIntervalHint => '1';

  @override
  String get choreCreationMoreOptions => 'More options';

  @override
  String get choreCreationAssignLabel => 'Assign';

  @override
  String get choreCreationAssignTakeTurns => 'Take turns';

  @override
  String get choreCreationAssignLeastDone => 'Least done';

  @override
  String get choreCreationAssignAlphabetical => 'Alphabetical';

  @override
  String get choreCreationAssignRandom => 'Random';

  @override
  String get choreCreationAssignNoAssignee => 'No assignee';

  @override
  String get choreCreationAssignHintTurns =>
      'Rotates to the next person each time.';

  @override
  String get choreCreationAssignHintAlpha =>
      'Goes in alphabetical order of names.';

  @override
  String get choreCreationAssignHintLeast =>
      'Goes to whoever has done it least.';

  @override
  String get choreCreationAssignHintRandom =>
      'Picks someone at random each time.';

  @override
  String get choreCreationAssignHintNone =>
      'Stays unassigned. Anyone in the household can pick it up.';

  @override
  String get choreCreationLogWhenDone => 'Log when done, don\'t tick off';

  @override
  String get choreCreationLogWhenDoneHelper =>
      'Records the date without marking it complete. Good for tasks you want a history of.';

  @override
  String get choreCreationRollOver => 'Roll over if missed';

  @override
  String get choreCreationRollOverHelper =>
      'Shifts to the next due date instead of piling up as overdue.';

  @override
  String get choreCreationNotesHint =>
      'Notes (optional) — steps, reminders, anything useful';

  @override
  String get choreCreationSaveAsRoutine => 'Save as routine';

  @override
  String get choreCreationSaveAsRoutineSemantic =>
      'Save this chore as a reusable routine';

  @override
  String get choreCreationScanChoreSemantic => 'Scan chore via camera';

  @override
  String get choreCreationChoreAdded => 'Chore added';

  @override
  String choreCreationChoreAddedNextUp(String assignee) {
    return 'Chore added · next up: $assignee';
  }

  @override
  String get choreCreationJoinFirst => 'Create or join a household first.';

  @override
  String get choreCreationEditRoutine => 'Edit routine';

  @override
  String choreCreationEverySingular(String unit) {
    return 'Every $unit';
  }

  @override
  String choreCreationEveryPlural(num n, String unit) {
    return 'Every $n $unit';
  }

  @override
  String get choreCreationUnitHourSingular => 'hour';

  @override
  String get choreCreationUnitHourPlural => 'hours';

  @override
  String get choreCreationUnitDaySingular => 'day';

  @override
  String get choreCreationUnitDayPlural => 'days';

  @override
  String get choreCreationUnitWeekSingular => 'week';

  @override
  String get choreCreationUnitWeekPlural => 'weeks';

  @override
  String get choreCreationUnitMonthSingular => 'month';

  @override
  String get choreCreationUnitMonthPlural => 'months';

  @override
  String get choreCreationUnitYearSingular => 'year';

  @override
  String get choreCreationUnitYearPlural => 'years';

  @override
  String get choreDayMon => 'Mon';

  @override
  String get choreDayTue => 'Tue';

  @override
  String get choreDayWed => 'Wed';

  @override
  String get choreDayThu => 'Thu';

  @override
  String get choreDayFri => 'Fri';

  @override
  String get choreDaySat => 'Sat';

  @override
  String get choreDaySun => 'Sun';

  @override
  String get choreDetailTitle => 'Chore details';

  @override
  String get choreDetailAssignee => 'Assignee';

  @override
  String get choreDetailDue => 'Due';

  @override
  String get choreDetailTracked => 'Tracked';

  @override
  String get choreDetailLastDone => 'Last done';

  @override
  String get choreDetailLastBy => 'Last by';

  @override
  String get choreDetailAverage => 'Average';

  @override
  String get choreDetailSubtasks => 'Subtasks';

  @override
  String get choreDetailNewSubtask => 'New subtask';

  @override
  String get choreDetailSupplies => 'Supplies';

  @override
  String get choreDetailAddSuppliesToList => 'Add supplies to list';

  @override
  String get choreDetailMarkDone => 'Mark done';

  @override
  String get choreDetailMoveToTomorrow => 'Move to tomorrow';

  @override
  String get choreDetailUndoLast => 'Undo last execution';

  @override
  String get choreDetailSkipTitle => 'Skip chore';

  @override
  String get choreDetailSkipReason => 'Reason (optional)';

  @override
  String get choreDetailSkipReasonHint => 'e.g. Away this week';

  @override
  String get choreDetailDeleteTitleDialog => 'Delete chore';

  @override
  String get choreDetailDeleteBody =>
      'This will permanently delete this chore and its history.';

  @override
  String get choreDetailDeleteSubtask => 'Delete subtask';

  @override
  String get choreDetailSubtaskMarkNotDone => 'Mark subtask as not done';

  @override
  String get choreDetailSubtaskMarkDone => 'Mark subtask as done';

  @override
  String get choreLoadTitle => 'Who\'s doing the chores';

  @override
  String choreLoadEmpty(num days) {
    return 'No chores have been completed in the last $days days yet. Once people start ticking things off, the split shows up here.';
  }

  @override
  String choreLoadCountSingular(num count) {
    return '$count chore';
  }

  @override
  String choreLoadCountPlural(num count) {
    return '$count chores';
  }

  @override
  String get recipeAppBarTitle => 'Kitchen';

  @override
  String get recipeSearchLabel => 'Search kitchen';

  @override
  String get recipeSearchHint => 'Recipe, tag, ingredient';

  @override
  String get recipeMealPlanTooltip => 'Meal plan';

  @override
  String get recipeSearchTooltip => 'Search';

  @override
  String get recipeSortLabel => 'Sort recipes';

  @override
  String get recipeSortNewest => 'Newest';

  @override
  String get recipeSortOldest => 'Oldest';

  @override
  String get recipeSortAZ => 'A-Z';

  @override
  String get recipeAddRecipe => 'Add recipe';

  @override
  String get recipeFailedLoad => 'Failed to load kitchen';

  @override
  String get recipeFailedMore => 'Failed to load more recipes';

  @override
  String get recipeBuildKitchen => 'Build your kitchen';

  @override
  String get recipeBuildKitchenDesc =>
      'Import recipes, group cookbooks, plan meals, and turn the week into a shopping list.';

  @override
  String get recipeNoMatchTitle => 'No recipes match';

  @override
  String get recipeNoMatchDesc => 'Try a different search or filter.';

  @override
  String get recipeShowAllRecipes => 'Show all recipes';

  @override
  String recipeMealsPlanned(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count meals planned this week',
      one: '1 meal planned this week',
    );
    return '$_temp0';
  }

  @override
  String get recipePlanButton => 'Plan';

  @override
  String recipeCountLabel(num visible, num total) {
    return '$visible of $total recipes';
  }

  @override
  String recipeCountLabelAll(num total) {
    return '$total recipes';
  }

  @override
  String get recipeFilterAll => 'All';

  @override
  String get recipeFilterShared => 'Shared';

  @override
  String get recipeFilterPrivate => 'Private';

  @override
  String recipeImageSemantics(String title) {
    return 'Image of $title';
  }

  @override
  String recipeMinLabel(num minutes) {
    return '$minutes min';
  }

  @override
  String recipeServesLabel(num servings) {
    return 'Serves $servings';
  }

  @override
  String recipeOpenRecipe(String title) {
    return 'Open recipe $title';
  }

  @override
  String get recipeAddToList => 'Add to list';

  @override
  String recipeSharedPrivate(num shared, num private) {
    return '$shared shared · $private private';
  }

  @override
  String recipeCookbooksLabel(num count) {
    return ' · $count cookbooks';
  }

  @override
  String recipeRatingLabel(String rating, num count) {
    return '$rating ($count)';
  }

  @override
  String get recipeCreationTitle => 'New recipe';

  @override
  String get recipeCreationStepSource => 'Source';

  @override
  String get recipeCreationStepDetails => 'Details';

  @override
  String get recipeCreationStepContent => 'Content';

  @override
  String get recipeCreationStartHeadline => 'Start your recipe';

  @override
  String get recipeCreationStartSubtitle =>
      'Import from a link, type it yourself, or scan a photo.';

  @override
  String get recipeCreationImportURL => 'Import from URL';

  @override
  String get recipeCreationImportURLDesc =>
      'Paste a recipe link and we\'ll pull the details';

  @override
  String get recipeCreationTypeItIn => 'Type it in';

  @override
  String get recipeCreationTypeItInDesc =>
      'Start with a title and add ingredients later';

  @override
  String get recipeCreationScanning => 'Scanning…';

  @override
  String get recipeCreationScanPhoto => 'Scan a photo';

  @override
  String get recipeCreationScanPhotoDesc =>
      'Snap a recipe card or cookbook page';

  @override
  String get recipeCreationURLInput => 'Recipe URL';

  @override
  String get recipeCreationURLHint => 'https://example.com/recipe';

  @override
  String get recipeCreationFetching => 'Fetching…';

  @override
  String get recipeCreationFetchDetails => 'Fetch details';

  @override
  String get recipeCreationChooseImage => 'Choose an image';

  @override
  String recipeCreationSelectImage(num index) {
    return 'Select image $index';
  }

  @override
  String get recipeCreationTitleInput => 'Recipe title';

  @override
  String get recipeCreationTitleHint => 'Sunday pancakes';

  @override
  String get recipeCreationDiscardTitle => 'Discard recipe?';

  @override
  String get recipeCreationDiscardBody =>
      'You have unsaved content in this recipe.';

  @override
  String get recipeCreationKeepEditing => 'Keep editing';

  @override
  String get recipeCreationDiscard => 'Discard';

  @override
  String get recipeCreationCouldNotScan => 'Couldn\'t scan recipe.';

  @override
  String recipeCreationImported(String parts) {
    return '$parts';
  }

  @override
  String get recipeCreationCouldNotFetch =>
      'Couldn\'t fetch details from that link.';

  @override
  String get recipeCreationCreated => 'Recipe created';

  @override
  String get recipeCreationCouldNotCreate => 'Couldn\'t create recipe.';

  @override
  String get recipeCreationImportedTitle => 'Imported recipe';

  @override
  String recipeCreationFromHost(String host) {
    return 'Recipe from $host';
  }

  @override
  String recipeCreationNutrition(String info) {
    return 'Nutrition: $info';
  }

  @override
  String get recipeCreationNextDetails => 'Next: details';

  @override
  String get recipeCreationNextContent => 'Next: content';

  @override
  String get recipeCreationTitleOverride => 'Title override';

  @override
  String get recipeCreationNotesInput => 'Notes';

  @override
  String get recipeCreationNotesHint => 'What makes this recipe worth saving';

  @override
  String get recipeCreationPrepLabel => 'Prep (min)';

  @override
  String get recipeCreationPrepHint => '10';

  @override
  String get recipeCreationCookLabel => 'Cook (min)';

  @override
  String get recipeCreationCookHint => '20';

  @override
  String get recipeCreationServingsLabel => 'Servings';

  @override
  String get recipeCreationServingsHint => '4';

  @override
  String get recipeCreationTagsInput => 'Tags';

  @override
  String get recipeCreationTagsHint => 'quick, vegetarian';

  @override
  String get recipeCreationSaveForHousehold => 'Save for household';

  @override
  String get recipeCreationSaveForHouseholdDesc =>
      'Everyone in this household can find and use this recipe.';

  @override
  String get recipeCreationSaveForHouseholdPrivate =>
      'Keep it private for now. You can share it later.';

  @override
  String recipeCreationSharedWithGroups(String names) {
    return 'Shared with $names';
  }

  @override
  String get recipeCreationIngredients => 'Ingredients';

  @override
  String get recipeCreationIngredientsHelper => 'Add one ingredient per row.';

  @override
  String get recipeCreationAddIngredient => 'Add ingredient';

  @override
  String get recipeCreationIngredientHint => '2 cups flour';

  @override
  String get recipeCreationSteps => 'Steps';

  @override
  String get recipeCreationStepsHelper =>
      'Keep each step short enough to follow while cooking.';

  @override
  String get recipeCreationAddStep => 'Add step';

  @override
  String get recipeCreationStepHint => 'Mix batter';

  @override
  String get recipeCreationNutritionInput => 'Nutrition';

  @override
  String get recipeCreationNutritionHint => '520 kcal, 24g protein, high fiber';

  @override
  String get recipeCreationCreating => 'Creating…';

  @override
  String get recipeCreationCreateRecipe => 'Create recipe';

  @override
  String recipeCreationStepLabel(String type) {
    return '$type';
  }

  @override
  String recipeCreationRemoveItem(String type, num index) {
    return 'Remove $type $index';
  }

  @override
  String recipeCreationStepSemantics(
      num index, num total, String label, String status) {
    return 'Step $index of $total, $label, $status';
  }

  @override
  String get recipeDetailTitle => 'Recipe';

  @override
  String get recipeDetailDeleteTooltip => 'Delete recipe';

  @override
  String get recipeDetailAddToList => 'Add to list';

  @override
  String get recipeDetailCook => 'Cook';

  @override
  String get recipeDetailCouldNotLoad => 'Could not load recipe';

  @override
  String get recipeDetailDeleteTitle => 'Delete recipe';

  @override
  String get recipeDetailDeleteBody =>
      'This will permanently delete this recipe. This cannot be undone.';

  @override
  String get recipeDetailSharedLabel => 'Shared';

  @override
  String get recipeDetailPrivateLabel => 'Private';

  @override
  String recipeDetailBy(String author) {
    return 'By $author';
  }

  @override
  String get recipeDetailPrep => 'Prep';

  @override
  String get recipeDetailServings => 'Servings';

  @override
  String get recipeDetailUpdated => 'Updated';

  @override
  String get recipeDetailNotSet => 'Not set';

  @override
  String get recipeDetailNutrition => 'Nutrition';

  @override
  String get recipeDetailEquipment => 'Equipment';

  @override
  String get recipeDetailIngredients => 'Ingredients';

  @override
  String get recipeDetailSteps => 'Steps';

  @override
  String get recipeDetailWatchVideo => 'Watch video';

  @override
  String get recipeDetailWatchVideoSemantics => 'Watch recipe video';

  @override
  String get recipeDetailViewOriginal => 'View original recipe';

  @override
  String get recipeDetailViewOriginalSemantics =>
      'View original recipe in browser';

  @override
  String get cookModeCouldNotLoad => 'Could not load recipe';

  @override
  String get cookModeClose => 'Close';

  @override
  String get cookModeServings => 'Servings';

  @override
  String get cookModeDecreaseServings => 'Decrease servings';

  @override
  String get cookModeIncreaseServings => 'Increase servings';

  @override
  String get cookModeStartCooking => 'Start cooking';

  @override
  String get cookModeGathered => 'gathered';

  @override
  String get cookModeNotGathered => 'not gathered';

  @override
  String cookModeStepOf(num step, num total) {
    return 'Step $step of $total';
  }

  @override
  String get cookModeExitTooltip => 'Exit cook mode';

  @override
  String get cookModeTimerDone => 'Timer done!';

  @override
  String get cookModeDoneArrow => 'Done →';

  @override
  String get cookModeFinish => 'Finish';

  @override
  String cookModeStepLabel(num number) {
    return 'Step $number';
  }

  @override
  String cookModeStepDone(num number) {
    return 'Step $number done. Tap to revisit';
  }

  @override
  String cookModeCurrentStep(num number) {
    return 'Current step $number';
  }

  @override
  String cookModeStepJump(num number, String description) {
    return 'Step $number: $description. Tap to jump to this step';
  }

  @override
  String cookModeBackToStep(num step) {
    return 'Back to step $step';
  }

  @override
  String get cookModeShowIngredients => 'Show ingredients';

  @override
  String get cookModeIngredients => 'Ingredients';

  @override
  String get cookModeFinished => 'Finished — nice work';

  @override
  String get cookModeFinishCooking => 'Finish cooking';

  @override
  String get cookModeAdvanceStep => 'Done, advance to next step';

  @override
  String get expenseAppBarTitle => 'Money';

  @override
  String get expenseScanReceiptTooltip => 'Scan receipt';

  @override
  String get expenseRecurringTooltip => 'Recurring';

  @override
  String get expenseAddExpense => 'Add expense';

  @override
  String get expenseYouAreOwed => 'You are owed';

  @override
  String get expenseYouOwe => 'You owe';

  @override
  String get expenseAllSquare => 'All square';

  @override
  String expenseSuggestedPayments(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count suggested payments',
      one: '$count suggested payment',
    );
    return '$_temp0 to settle up';
  }

  @override
  String expenseOpenBalances(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count open balances',
      one: '$count open balance',
    );
    return '$_temp0 in the household';
  }

  @override
  String get expenseNoOneOwes => 'No one needs to pay anyone right now';

  @override
  String get expenseTabTimeline => 'Timeline';

  @override
  String get expenseTabSettlements => 'Settlements';

  @override
  String get expenseToday => 'Today';

  @override
  String get expenseYesterday => 'Yesterday';

  @override
  String get expenseNoExpensesTitle => 'No expenses yet';

  @override
  String get expenseNoExpensesDesc => 'Track shared costs with your household.';

  @override
  String get expenseAddFirstExpense => 'Add first expense';

  @override
  String get expenseLoadError =>
      'Couldn\'t load expenses. Check your connection.';

  @override
  String get expenseLoadMoreError => 'Failed to load more expenses.';

  @override
  String expensePaidBy(String payer) {
    return 'Paid by $payer';
  }

  @override
  String expenseConvertedAmount(String amount) {
    return '≈ $amount';
  }

  @override
  String get expenseDeleteTitle => 'Delete expense';

  @override
  String get expenseDeleteBody =>
      'This will permanently delete this expense and all associated receipts. This cannot be undone.';

  @override
  String get expenseSettlementRecorded => 'Settlement recorded';

  @override
  String get expenseSettlementFailed => 'Couldn\'t record settlement.';

  @override
  String get expenseSuggestedPaymentsTitle => 'Suggested payments';

  @override
  String get expenseSuggestedPaymentsDesc =>
      'Calculated from every expense, split, and recorded settlement in this household.';

  @override
  String get expenseAllSettled => 'All settled up!';

  @override
  String get expenseNoOneOwesRight => 'No one owes anyone right now.';

  @override
  String get expenseSameAccount => 'Same account';

  @override
  String get expenseFrom => 'From';

  @override
  String get expenseTo => 'To';

  @override
  String get expenseRecordHelper =>
      'Record this settlement after the payment is made.';

  @override
  String get expenseRecording => 'Recording...';

  @override
  String get expenseRecordSettlement => 'Record settlement';

  @override
  String get expenseBalances => 'Balances';

  @override
  String expenseBalancesOpen(num count) {
    return '$count open';
  }

  @override
  String get expenseExpandBalances => 'Expand balances';

  @override
  String get expenseCollapseBalances => 'Collapse balances';

  @override
  String get expenseNoBalances =>
      'No balances yet. Add an expense with splits to start the ledger.';

  @override
  String get expenseIsOwed => 'is owed';

  @override
  String get expenseOwes => 'owes';

  @override
  String get expenseSettled => 'settled';

  @override
  String get recurringAppBarTitle => 'Recurring';

  @override
  String get recurringAddRecurring => 'Add recurring';

  @override
  String get recurringAddRecurringTooltip => 'Add recurring expense';

  @override
  String get recurringNoRecurringTitle => 'No recurring expenses';

  @override
  String get recurringNoRecurringDesc =>
      'Add a recurring expense to track regular payments';

  @override
  String get recurringAddExpense => 'Add expense';

  @override
  String get recurringPauseTooltip => 'Pause';

  @override
  String get recurringResumeTooltip => 'Resume';

  @override
  String get recurringDeleteTooltip => 'Delete';

  @override
  String recurringNextDate(String date) {
    return 'Next: $date';
  }

  @override
  String get recurringDeleteTitle => 'Delete recurring expense';

  @override
  String get recurringDeleteBody =>
      'This will stop future expenses from being created.';

  @override
  String get recurringFrequencyDaily => 'Daily';

  @override
  String get recurringFrequencyWeekly => 'Weekly';

  @override
  String get recurringFrequencyBiweekly => 'Every 2 weeks';

  @override
  String get recurringFrequencyMonthly => 'Monthly';

  @override
  String get recurringFrequencyQuarterly => 'Quarterly';

  @override
  String get recurringFrequencyYearly => 'Yearly';

  @override
  String get recurringSheetTitle => 'Add recurring expense';

  @override
  String get recurringSheetDescription => 'Description';

  @override
  String get recurringSheetAmount => 'Amount';

  @override
  String get recurringSheetFrequency => 'Frequency';

  @override
  String get recurringSheetPayer => 'Payer';

  @override
  String get recurringValidationDesc => 'Enter a description.';

  @override
  String get recurringValidationAmount => 'Enter an amount.';

  @override
  String get recurringValidationPayer => 'Select a payer.';

  @override
  String get recurringValidationAmountPositive =>
      'Enter a valid amount greater than zero.';

  @override
  String get recurringNoHouseholdDesc =>
      'Join or create a household to manage recurring expenses';

  @override
  String get listAppBarTitle => 'Lists';

  @override
  String get listShoppingTripTooltip => 'Shopping trip';

  @override
  String get listSearchLabel => 'Search lists';

  @override
  String get listSearchHint => 'Name, e.g. groceries';

  @override
  String get listScanTooltip => 'Scan receipt or list';

  @override
  String get listSortLabel => 'Sort';

  @override
  String get listSortNewest => 'Newest';

  @override
  String get listSortOldest => 'Oldest';

  @override
  String get listSortAZ => 'A–Z';

  @override
  String get listSortMostItems => 'Most items';

  @override
  String get listSortGridView => 'Grid view';

  @override
  String get listNewList => 'New list';

  @override
  String get listFilterAll => 'All';

  @override
  String get listFilterShopping => 'Shopping';

  @override
  String get listFilterTodo => 'To-do';

  @override
  String get listFilterCustom => 'Custom';

  @override
  String get listEmptyShopping => 'No shopping lists';

  @override
  String get listEmptyTodo => 'No to-do lists';

  @override
  String get listEmptyCustom => 'No custom lists';

  @override
  String get listEmptyAll => 'No lists yet';

  @override
  String get listEmptyShoppingDesc =>
      'Great for groceries, meal prep, weekend errands.';

  @override
  String get listEmptyTodoDesc => 'Tasks, chores, anything with a checkbox.';

  @override
  String get listEmptyCustomDesc => 'Free-form — your list, your rules.';

  @override
  String get listEmptyAllDesc =>
      'Add lines inside a list; the first few appear as a snippet on its card.';

  @override
  String get listCreateShopping => 'Create a shopping list';

  @override
  String get listCreateTodo => 'Create a to-do list';

  @override
  String get listCreateCustom => 'Create a custom list';

  @override
  String get listCreateFirst => 'Create your first list';

  @override
  String listNoMatch(String query) {
    return 'No lists match \"$query\"';
  }

  @override
  String get listSearchDesc => 'Names and list items are searched.';

  @override
  String get listRenameTitle => 'Rename list';

  @override
  String get listCouldNotRename => 'Couldn\'t rename list.';

  @override
  String get listDeleteTitle => 'Delete list';

  @override
  String get listDeleteBody =>
      'This will permanently delete this list and all its items.';

  @override
  String get listCouldNotDelete => 'Couldn\'t delete list.';

  @override
  String listAddItemTo(String name) {
    return 'Add item to $name';
  }

  @override
  String get listItemName => 'Item name';

  @override
  String get listCouldNotAddItem => 'Couldn\'t add item.';

  @override
  String get listQuickAddItemTooltip => 'Quick add item';

  @override
  String listQuickAddItemSemantics(String name) {
    return 'Quick add item to $name';
  }

  @override
  String get listOptionsTooltip => 'List options';

  @override
  String listSharedWith(String name) {
    return 'Shared with $name';
  }

  @override
  String listDetailEditName(String name) {
    return 'Edit list name, $name';
  }

  @override
  String get listDetailCloseSearch => 'Close search';

  @override
  String get listDetailSearchTooltip => 'Search';

  @override
  String get listDetailFilterLabel => 'Filter items';

  @override
  String get listDetailFilterHint => 'Name, e.g. milk';

  @override
  String get listDetailAllCheckedOff => 'All checked off';

  @override
  String get listDetailClearChecked => 'Clear checked';

  @override
  String get listDetailCheckedOff => 'Checked off';

  @override
  String get listDetailNothingHere => 'Nothing here yet';

  @override
  String get listDetailNothingHereDesc =>
      'Photograph a handwritten list, fridge note, or screenshot. We\'ll pull out the items.';

  @override
  String get listDetailScanThisList => 'Scan this list';

  @override
  String get listDetailTypeItem => 'Type an item';

  @override
  String get listDetailNoMatch => 'No items match your filter';

  @override
  String get listDetailCouldNotLoad => 'Couldn\'t load list.';

  @override
  String get listDetailCouldNotUpdate => 'Couldn\'t update. Please try again.';

  @override
  String get listDetailCouldNotAddItem =>
      'Couldn\'t add item. Please try again.';

  @override
  String get listDetailCouldNotClear =>
      'Couldn\'t clear items. Please try again.';

  @override
  String listDetailItemDeleted(String name) {
    return '$name deleted';
  }

  @override
  String get listDetailCouldNotRestore => 'Couldn\'t restore item.';

  @override
  String get listDetailCouldNotReorder =>
      'Couldn\'t reorder items. Please try again.';

  @override
  String listDetailItemsAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items added to list',
      one: '1 item added to list',
    );
    return '$_temp0';
  }

  @override
  String get listDetailCouldNotStartScan => 'Couldn\'t start scan. Try again.';

  @override
  String get listDetailSetPrice => 'Set price';

  @override
  String get listDetailPriceInput => 'Price';

  @override
  String get listDetailPriceHint => '0.00';

  @override
  String get listDetailCouldNotSetPrice => 'Couldn\'t set price.';

  @override
  String get listDetailClearTitle => 'Clear list';

  @override
  String listDetailClearBody(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'items',
      one: 'item',
    );
    return 'This will remove all $count $_temp0. This cannot be undone.';
  }

  @override
  String get listDetailClearConfirm => 'Clear list';

  @override
  String get listDetailArchiveTitle => 'Archive list';

  @override
  String get listDetailArchiveBody =>
      'This list will be hidden from your household.';

  @override
  String get listDetailFailedArchive => 'Failed to archive list.';

  @override
  String get listDetailDeleteTitle => 'Delete list';

  @override
  String get listDetailDeleteBody =>
      'This will permanently delete this list and all its items. This cannot be undone.';

  @override
  String get listDetailCouldNotDelete => 'Couldn\'t delete list.';

  @override
  String get listDetailExpenseGenerated => 'Expense generated';

  @override
  String get listDetailCouldNotLoadCostSummary =>
      'Couldn\'t load cost summary.';

  @override
  String get listDetailCouldNotAddPhoto => 'Couldn\'t add photo.';

  @override
  String get listDetailCouldNotRemovePhoto => 'Couldn\'t remove photo.';

  @override
  String get listDetailListImage => 'List image';

  @override
  String get listDetailCheckAll => 'Check all';

  @override
  String get listDetailUncheckAll => 'Uncheck all';

  @override
  String get listDetailCostSummary => 'Cost summary';

  @override
  String get listDetailScanList => 'Scan list';

  @override
  String get calendarAppBarTitle => 'Calendar';

  @override
  String get calendarViewWeek => 'Week';

  @override
  String get calendarViewMonth => 'Month';

  @override
  String get calendarViewAgenda => 'Agenda';

  @override
  String get calendarWeekView => 'Week view';

  @override
  String get calendarMonthView => 'Month view';

  @override
  String get calendarAgendaView => 'Agenda view';

  @override
  String get calendarPreviousWeek => 'Previous week';

  @override
  String get calendarNextWeek => 'Next week';

  @override
  String get calendarPreviousMonth => 'Previous month';

  @override
  String get calendarNextMonth => 'Next month';

  @override
  String get calendarMonthJanuary => 'January';

  @override
  String get calendarMonthFebruary => 'February';

  @override
  String get calendarMonthMarch => 'March';

  @override
  String get calendarMonthApril => 'April';

  @override
  String get calendarMonthMay => 'May';

  @override
  String get calendarMonthJune => 'June';

  @override
  String get calendarMonthJuly => 'July';

  @override
  String get calendarMonthAugust => 'August';

  @override
  String get calendarMonthSeptember => 'September';

  @override
  String get calendarMonthOctober => 'October';

  @override
  String get calendarMonthNovember => 'November';

  @override
  String get calendarMonthDecember => 'December';

  @override
  String get calendarShortMon => 'Mon';

  @override
  String get calendarShortTue => 'Tue';

  @override
  String get calendarShortWed => 'Wed';

  @override
  String get calendarShortThu => 'Thu';

  @override
  String get calendarShortFri => 'Fri';

  @override
  String get calendarShortSat => 'Sat';

  @override
  String get calendarShortSun => 'Sun';

  @override
  String get calendarWeekdayMonday => 'Monday';

  @override
  String get calendarWeekdayTuesday => 'Tuesday';

  @override
  String get calendarWeekdayWednesday => 'Wednesday';

  @override
  String get calendarWeekdayThursday => 'Thursday';

  @override
  String get calendarWeekdayFriday => 'Friday';

  @override
  String get calendarWeekdaySaturday => 'Saturday';

  @override
  String get calendarWeekdaySunday => 'Sunday';

  @override
  String get calendarToday => 'Today';

  @override
  String calendarDayLabel(num day) {
    return 'Day $day';
  }

  @override
  String calendarDayEvents(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count events',
      one: '1 event',
    );
    return '$_temp0';
  }

  @override
  String get calendarDayMenuHint => 'Opens day options';

  @override
  String get calendarNothingPlanned => 'Nothing planned';

  @override
  String get calendarNothingAhead => 'Nothing ahead';

  @override
  String get calendarNothingAheadDesc =>
      'Upcoming chores, meal plans, and recurring expenses will appear here.';

  @override
  String get calendarAddChore => 'Add chore';

  @override
  String get calendarAddExpense => 'Add expense';

  @override
  String get calendarViewInWeek => 'View in week';

  @override
  String get calendarEventMeal => 'Meal';

  @override
  String get calendarEventChore => 'Chore';

  @override
  String get calendarEventRecurring => 'Recurring';

  @override
  String get calendarEventExpense => 'Expense';

  @override
  String get calendarEventReminder => 'Reminder';

  @override
  String calendarServingsPpl(num servings) {
    return '$servings ppl ';
  }

  @override
  String get calendarNoHouseholdDesc =>
      'Join or create a household to view the calendar';

  @override
  String get calendarCreateHousehold => 'Create household';

  @override
  String calendarWeekHeader(String weekStart, String weekEnd) {
    return '$weekStart – $weekEnd';
  }

  @override
  String calendarMonthHeader(String month, num year) {
    return '$month $year';
  }

  @override
  String get mealPlanAppBarTitle => 'Meal Plan';

  @override
  String get mealPlanGenerateShoppingList => 'Generate shopping list';

  @override
  String get mealPlanPreviousWeek => 'Previous week';

  @override
  String get mealPlanNextWeek => 'Next week';

  @override
  String get mealPlanBreakfast => 'Breakfast';

  @override
  String get mealPlanLunch => 'Lunch';

  @override
  String get mealPlanDinner => 'Dinner';

  @override
  String get mealPlanAddMeal => 'Add meal';

  @override
  String get mealPlanRecipeFallback => 'Recipe';

  @override
  String mealPlanServings(num servings) {
    return '${servings}p';
  }

  @override
  String mealPlanShoppingListCreated(num count) {
    return 'Shopping list created with $count items';
  }

  @override
  String get mealPlanTrackCosts => 'Track costs';

  @override
  String get mealPlanCouldNotAdd => 'Couldn\'t add meal.';

  @override
  String get mealPlanCouldNotRemove => 'Couldn\'t remove meal.';

  @override
  String get mealPlanCouldNotUpdate => 'Couldn\'t update meal.';

  @override
  String get mealPlanPickRecipe => 'Pick a recipe';

  @override
  String get mealPlanCouldNotLoadRecipes => 'Couldn\'t load recipes';

  @override
  String get mealPlanNoRecipes => 'No recipes yet';

  @override
  String get mealPlanAddRecipesDesc => 'Add recipes to plan meals';

  @override
  String get mealPlanSearchRecipes => 'Search recipes...';

  @override
  String mealPlanNoMatch(String query) {
    return 'No recipes match \"$query\"';
  }

  @override
  String get mealPlanServingsSheet => 'Servings';

  @override
  String get mealPlanFewerServings => 'Fewer servings';

  @override
  String get mealPlanMoreServings => 'More servings';

  @override
  String mealPlanOpenRecipe(String slot) {
    return 'Open recipe for $slot';
  }

  @override
  String mealPlanAddMealFor(String slot) {
    return 'Add meal for $slot';
  }

  @override
  String get accountAppBarTitle => 'You';

  @override
  String get accountFailedLoadProfile =>
      'Failed to load profile. Please try again.';

  @override
  String get accountFailedSaveName => 'Failed to save name';

  @override
  String get accountEditYourName => 'Edit your name';

  @override
  String get accountChangePassword => 'Change password';

  @override
  String get accountFillPasswordFields => 'Fill out all password fields.';

  @override
  String get accountPasswordMinLength =>
      'New password must be at least 6 characters.';

  @override
  String get accountPasswordsMismatch => 'New passwords do not match.';

  @override
  String get accountPasswordChanged => 'Password changed';

  @override
  String get accountCurrentPassword => 'Current password';

  @override
  String get accountNewPassword => 'New password';

  @override
  String get accountConfirmPassword => 'Confirm new password';

  @override
  String get accountChangePasswordButton => 'Change password';

  @override
  String get accountTermsTitle => 'Terms of Service';

  @override
  String get accountTermsBody =>
      'Use mitlist responsibly and respect your household members\' privacy. Do not misuse shared features or data. mitlist is provided as-is without warranties.';

  @override
  String get accountDeleteAccount => 'Delete account';

  @override
  String get accountDeleteAccountBody =>
      'This will permanently delete your account and all associated data. This cannot be undone.';

  @override
  String get accountLogOut => 'Log out';

  @override
  String get accountDeleteAccountButton => 'Delete account';

  @override
  String get accountHouseholdSection => 'Household';

  @override
  String accountSwitchToHousehold(String name) {
    return 'Switch to $name';
  }

  @override
  String get accountNotificationInbox => 'Notification inbox';

  @override
  String get accountNotificationPreferences => 'Notification preferences';

  @override
  String get accountAppearance => 'Appearance';

  @override
  String get accountAppearanceSystem => 'System';

  @override
  String get accountAppearanceLight => 'Light';

  @override
  String get accountAppearanceDark => 'Dark';

  @override
  String get accountChangePasswordRow => 'Change Password';

  @override
  String get accountVersion => 'Version';

  @override
  String get accountTermsRow => 'Terms of Service';

  @override
  String get accountOpenDataRow => 'Open data';

  @override
  String get accountOpenDataTitle => 'Open data attribution';

  @override
  String get accountOpenDataBody =>
      'Some grocery brand names come from Open Food Facts (openfoodfacts.org), used under the Open Database License (ODbL) v1.0. The derived brand list is kept separable from mitlist\'s own data.';

  @override
  String get accountGuestTitle => 'You\'re on a guest account';

  @override
  String get accountGuestDesc =>
      'Create a full account to keep your data permanently and access all features.';

  @override
  String get accountCreateFullAccount => 'Create full account';

  @override
  String get accountExportCSV => 'Export expenses (CSV)';

  @override
  String get accountShareJSON => 'Share expenses (JSON)';

  @override
  String get accountCopyJSON => 'Copy expenses (JSON)';

  @override
  String get accountJSONCopied => 'Expenses JSON copied to clipboard';

  @override
  String get accountCreateAccountTitle => 'Create your account';

  @override
  String get accountFillAllFields => 'Please fill in all fields.';

  @override
  String get accountYourName => 'Your name';

  @override
  String get accountYourNameHint => 'e.g. Alex Smith';

  @override
  String get accountEmail => 'Email';

  @override
  String get accountEmailHint => 'you@example.com';

  @override
  String get accountPassword => 'Password';

  @override
  String get accountCreatingAccount => 'Creating account…';

  @override
  String get accountCreateAccount => 'Create account';

  @override
  String get accountCreatedWelcome => 'Account created. Welcome!';

  @override
  String get notificationsAppBarTitle => 'Notifications';

  @override
  String get notificationsMarkAllRead => 'Mark all read';

  @override
  String get notificationsFailedLoad => 'Failed to load notifications.';

  @override
  String get notificationsFailedLoadMore =>
      'Failed to load more notifications.';

  @override
  String get notificationsFailedMarkAllRead => 'Failed to mark all as read.';

  @override
  String get notificationsFailedMarkRead => 'Failed to mark as read.';

  @override
  String get notificationsNoHouseholdDesc =>
      'Create or join a household to receive notifications.';

  @override
  String get notificationsNoNotifications => 'No notifications yet';

  @override
  String get notificationsNoNotificationsDesc =>
      'When someone adds a chore, splits a bill, or mentions you, it will show up here.';

  @override
  String notificationsUnreadLabel(String title) {
    return 'Unread, $title';
  }

  @override
  String get notifPrefAppBarTitle => 'Notification Preferences';

  @override
  String get notifPrefFailedLoad => 'Failed to load notification preferences.';

  @override
  String get notifPrefNoHouseholdDesc =>
      'Join or create a household to configure notification preferences.';

  @override
  String get notifPrefNoPreferences => 'No preferences yet';

  @override
  String get notifPrefNoPreferencesDesc =>
      'Preferences are created when you join a household. If you just joined, they should appear shortly.';

  @override
  String get notifPrefGroupName => 'Notifications';

  @override
  String get notifPrefChoreDueReminders => 'Chore due reminders';

  @override
  String get notifPrefChoreDueRemindersDesc => 'When a chore is coming due';

  @override
  String get notifPrefChoreDueDayOf => 'Chore due day-of';

  @override
  String get notifPrefChoreDueDayOfDesc => 'On the day a chore is due';

  @override
  String get notifPrefListItemAdded => 'List item added';

  @override
  String get notifPrefListItemAddedDesc => 'When someone adds to a shared list';

  @override
  String get notifPrefExpenseCreated => 'Expense created';

  @override
  String get notifPrefExpenseCreatedDesc => 'When a new expense is logged';

  @override
  String get notifPrefMealPlanChanged => 'Meal plan changed';

  @override
  String get notifPrefMealPlanChangedDesc => 'When the meal plan is updated';

  @override
  String get notifPrefWeeklyDigest => 'Weekly digest';

  @override
  String get notifPrefWeeklyDigestDesc => 'A summary of household activity';

  @override
  String get notifPrefPinwallReminders => 'Pinwall reminders';

  @override
  String get notifPrefPinwallRemindersDesc =>
      'When someone pins a reminder for later';

  @override
  String get notifPrefPushNotifications => 'Push notifications';

  @override
  String get notifPrefPushNotificationsDesc =>
      'Receive notifications on this device';

  @override
  String get shoppingTripAppBarTitle => 'Shopping Trip';

  @override
  String get shoppingTripChooseStore => 'Choose store';

  @override
  String get shoppingTripNoLists => 'No lists yet';

  @override
  String get shoppingTripNoListsDesc =>
      'Create a shopping list to start a trip';

  @override
  String get shoppingTripAllCaughtUp => 'All caught up';

  @override
  String get shoppingTripAllCaughtUpDesc =>
      'No open items across your lists. Add items to a list to see them here.';

  @override
  String get shoppingTripSortedByAisles => 'Sorted by store aisles';

  @override
  String shoppingTripSortedByStoreAisles(String store) {
    return 'Sorted by $store aisles';
  }

  @override
  String get shoppingTripMarkDone => 'Mark done';

  @override
  String shoppingTripBasketBar(num collected, String price) {
    return '/ $collected collected$price';
  }

  @override
  String shoppingTripItemsWorthDone(String amount) {
    return '$amount worth of items marked as done';
  }

  @override
  String get shoppingTripAddExpense => 'Add expense';

  @override
  String get shoppingTripStampDone => 'DONE';

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
  String get shoppingTripFallbackList => 'List';

  @override
  String shoppingTripMarkNotPurchased(String item) {
    return 'Mark $item as not purchased';
  }

  @override
  String shoppingTripMarkPurchased(String item) {
    return 'Mark $item as purchased';
  }

  @override
  String get scannerAppBarTitle => 'Scanner';

  @override
  String get scannerShoppingAt => 'Shopping at';

  @override
  String get scannerChooseStore => 'Choose your store';

  @override
  String get scannerHintText =>
      'Scan a receipt, list, recipe,\nor chore reminder';

  @override
  String get scannerAnalyzing => 'Analyzing…';

  @override
  String get scannerScanGrocery => 'Scan grocery list';

  @override
  String get scannerScanReceipt => 'Scan receipt, recipe, or chore';

  @override
  String get scannerAnalyzeThis => 'Analyze this image';

  @override
  String get scannerTakeOrChoose => 'Take a photo or choose one';

  @override
  String get scannerPickDifferent => 'Pick different image';

  @override
  String get scannerScanSheetTitle => 'Scan grocery list';

  @override
  String get scannerAddScanTitle => 'Add scan';

  @override
  String get scannerTakePhoto => 'Take a photo';

  @override
  String get scannerChooseFromGallery => 'Choose from gallery';

  @override
  String get scannerTypeReceipt => 'Receipt';

  @override
  String get scannerTypeShoppingList => 'Shopping list';

  @override
  String get scannerTypeRecipe => 'Recipe';

  @override
  String get scannerTypeChore => 'Chore';

  @override
  String scannerDetectedType(String type) {
    return 'Detected: $type';
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
    return '…and $count more';
  }

  @override
  String scannerStepCount(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps',
      one: '$count step',
    );
    return '$_temp0';
  }

  @override
  String scannerTotal(String amount) {
    return 'Total: $amount';
  }

  @override
  String get scannerAddToLists => 'Add to lists';

  @override
  String get scannerCreateExpense => 'Create expense';

  @override
  String get scannerCreateRecipe => 'Create recipe';

  @override
  String get scannerCreateChore => 'Create chore';

  @override
  String get scannerUseThis => 'Use this';

  @override
  String get scannerScanAgain => 'Scan again';

  @override
  String get smartCaptureBack => 'Back';

  @override
  String get smartCaptureShowEnhanced => 'Show enhanced';

  @override
  String get smartCaptureOriginal => 'Original';

  @override
  String get smartCaptureUseAnyway => 'Use anyway';

  @override
  String get smartCaptureUseScan => 'Use scan';

  @override
  String get smartCaptureRetake => 'Retake';

  @override
  String get smartCaptureReady => 'Ready';

  @override
  String get smartCaptureUsable => 'Usable';

  @override
  String get smartCaptureRetakeSuggested => 'Retake suggested';

  @override
  String get liveSmartCaptureNoCamera => 'No camera available.';

  @override
  String get liveSmartCaptureCouldNotOpen => 'Couldn\'t open the camera.';

  @override
  String get liveSmartCaptureFrameList => 'Frame the list';

  @override
  String get liveSmartCaptureCameraUnavailable => 'Camera unavailable';

  @override
  String get liveSmartCaptureGallery => 'Gallery';

  @override
  String get liveSmartCaptureScan => 'Scan';

  @override
  String get liveSmartCaptureCouldNotCapture => 'Couldn\'t capture that photo.';

  @override
  String scanReviewAddToList(String list) {
    return 'Add to $list';
  }

  @override
  String get scanReviewReviewItems => 'Review items';

  @override
  String scanReviewAcceptAll(num count) {
    return 'Accept all ($count)';
  }

  @override
  String get scanReviewStoreLabel => 'Store:';

  @override
  String get scanReviewYouMightNeed => 'You might also need';

  @override
  String get scanReviewIgnored => 'Ignored';

  @override
  String get scanReviewNewList => 'New list';

  @override
  String get scanReviewAddToWhichList => 'Add to which list?';

  @override
  String get scanReviewNewListOption => 'New list…';

  @override
  String get scanReviewScannedList => 'Scanned list';

  @override
  String get scanReviewCreateList => 'Create list';

  @override
  String get scanReviewAdding => 'Adding…';

  @override
  String scanReviewRemoveItem(String item) {
    return 'Remove $item';
  }

  @override
  String get scanReviewRestore => 'Restore';

  @override
  String get scanReviewEditItem => 'Edit item';

  @override
  String scanReviewOCRSaw(String text) {
    return 'OCR saw: \"$text\"';
  }

  @override
  String get scanReviewItemName => 'Item name';

  @override
  String get scanReviewQty => 'Qty';

  @override
  String get scanReviewUnit => 'Unit';

  @override
  String get scanReviewDidYouMean => 'Did you mean?';

  @override
  String get shareTargetAppBarTitle => 'Save to mitlist';

  @override
  String get shareTargetSharedText => 'Shared text';

  @override
  String get shareTargetPasteHint => 'Paste or type the shared text here…';

  @override
  String get shareTargetAddPhotos => 'Add photos';

  @override
  String shareTargetPhotosAdded(num count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count photos added',
      one: '1 photo added',
    );
    return '$_temp0';
  }

  @override
  String get shareTargetPreviewPlaceholder =>
      'Paste text here now, or send content from the share extension when that integration is available.';

  @override
  String get shareTargetDestLists => 'Lists';

  @override
  String get shareTargetDestListsDesc => 'Save to a shopping or to-do list';

  @override
  String get shareTargetDestPinwall => 'Pinwall';

  @override
  String get shareTargetDestPinwallDesc =>
      'Post a note (and optional photos) to your household';

  @override
  String get shareTargetDestRecipes => 'Recipes';

  @override
  String get shareTargetDestRecipesDesc => 'Add to saved recipes';

  @override
  String get shareTargetSelectHousehold => 'Select household';

  @override
  String get shareTargetSaved => 'Saved';

  @override
  String get shareTargetFailedSave => 'Failed to save. Please try again.';

  @override
  String get shareTargetValidationText => 'Paste or type something to save.';

  @override
  String get shareTargetValidationNote => 'Add a note or at least one photo.';

  @override
  String get shareTargetValidationHousehold =>
      'Create or join a household first.';

  @override
  String get expenseCreationTitle => 'Add expense';

  @override
  String get expenseCreationAmountHint => '0.00';

  @override
  String expenseCreationRateHint(String currency, String groupCurrency) {
    return 'Rate: 1 $currency = ? $groupCurrency';
  }

  @override
  String get expenseCreationWhatsItFor => 'What\'s this for?';

  @override
  String get expenseCreationNotesHint => 'Notes (optional)';

  @override
  String get expenseCreationDateLabel => 'Expense date. Tap to change.';

  @override
  String get expenseCreationReceiptButton => 'Receipt';

  @override
  String get expenseCreationScanning => 'Scanning…';

  @override
  String get expenseCreationScanButton => 'Scan';

  @override
  String get expenseCreationReceiptAttached =>
      'Receipt attached. Tap to re-scan.';

  @override
  String get expenseCreationScanReceiptSemantics => 'Scan receipt via camera';

  @override
  String get expenseCreationSplitMode => 'Split mode';

  @override
  String expenseCreationSplitTotal(String amount) {
    return 'Total $amount';
  }

  @override
  String get expenseCreationSplitEqual => 'Equal';

  @override
  String get expenseCreationSplitExact => 'Exact';

  @override
  String get expenseCreationSplitShares => 'Shares';

  @override
  String get expenseCreationSplitPercent => 'Percent';

  @override
  String get expenseCreationSplitHintExact =>
      'Enter the exact amount each person owes.';

  @override
  String get expenseCreationSplitHintPercent =>
      'Enter each person\'s share; must total 100%.';

  @override
  String get expenseCreationSplitHintShares =>
      'Split by shares, e.g. 2 shares pays double.';

  @override
  String get expenseCreationSplitHintEqual =>
      'Split the total evenly among selected members.';

  @override
  String get expenseCreationSplitSharesLabel => 'Shares';

  @override
  String get expenseCreationSplitValuesAmount => 'Amount';

  @override
  String get expenseCreationSplitValuesPercent => '%';

  @override
  String get expenseCreationPaidBy => 'Paid by';

  @override
  String get expenseCreationSplitWith => 'Split with';

  @override
  String get expenseCreationSelectSplitter =>
      'Select at least one person to split with.';

  @override
  String get expenseCreationEnterAmount =>
      'Enter an amount above to preview each share.';

  @override
  String get expenseCreationValidationAmount =>
      'Enter a valid amount greater than zero.';

  @override
  String get expenseCreationValidationRate =>
      'Enter a conversion rate greater than zero.';

  @override
  String get expenseCreationReceiptUploadFailed =>
      'Expense saved, but receipt upload failed.';

  @override
  String get expenseCreationExpenseAdded => 'Expense added';

  @override
  String get pinwallBoardLabel => 'Pinwall';

  @override
  String get pinwallSnapshot => 'At a glance';

  @override
  String get pinwallDragHint => 'Drag notes to move  ·  Pinch to zoom';

  @override
  String get pinwallCloseBoard => 'Close board';

  @override
  String get pinwallEmptyBoard =>
      'The wall is clear.\nPin a note from the hub to get started.';

  @override
  String pinwallNoteSemantics(String user, String content) {
    return '$user · $content';
  }

  @override
  String pinwallReminderLabel(String text) {
    return 'Reminder · $text';
  }

  @override
  String pinwallRemindedLabel(String text) {
    return 'Reminded · $text';
  }

  @override
  String get pinwallChooseReminderDate => 'Choose reminder date';

  @override
  String get pinwallChooseReminderTime => 'Choose reminder time';

  @override
  String get pinwallLinkTo => 'Link to…';

  @override
  String get pinwallLinkExpense => 'An expense';

  @override
  String get pinwallRemoveLink => 'Remove link';

  @override
  String pinwallSelectEntity(String type) {
    return 'Select a $type';
  }

  @override
  String get pinwallOpenBoard => 'Open pinwall board';

  @override
  String get pinwallLinkToChore => 'Link to a chore, list…';

  @override
  String get pinwallPickFutureTime => 'Pick a time in the future.';

  @override
  String get pinwallCouldNotLoadEntities => 'Couldn\'t load entities.';

  @override
  String get pinwallPinned => 'Pinned to the wall';

  @override
  String get pinwallOpenBoardBtn => 'Open board';

  @override
  String get pinwallPostHint => 'Post a note to the household…';

  @override
  String get pinwallAddReminder => 'Add reminder';

  @override
  String pinwallReminderSet(String label) {
    return 'Reminder set for $label. Tap to change.';
  }

  @override
  String get pinwallClearReminder => 'Clear reminder';

  @override
  String get pinwallAttachPhoto => 'Attach photo';

  @override
  String get pinwallUploading => 'Uploading…';

  @override
  String get pinwallPosting => 'Posting…';

  @override
  String get pinwallPinIt => 'Pin it';

  @override
  String get pinwallCouldNotLoadImage => 'Couldn\'t load image.';

  @override
  String get pinwallRemoveFromPost => 'Remove from post';

  @override
  String get pinwallCouldNotRemovePhoto => 'Couldn\'t remove photo.';

  @override
  String get pinwallCouldNotAddPhoto => 'Couldn\'t add photo.';

  @override
  String get pinwallLinkedList => 'Linked list';

  @override
  String get pinwallLinkedChore => 'Linked chore';

  @override
  String get pinwallLinkedExpense => 'Linked expense';

  @override
  String pinwallOpenLinkedEntity(String entity) {
    return 'Open linked $entity';
  }

  @override
  String get pinwallPostOptions => 'Post options';

  @override
  String get pinwallDeletePin => 'Delete pin';

  @override
  String get pinwallDeletePinBody =>
      'This pin will be permanently deleted. This cannot be undone.';

  @override
  String get pinwallAddPhotoMenu => 'Add photo';

  @override
  String get tonightBreakfast => 'Today · Breakfast';

  @override
  String get tonightLunch => 'Today · Lunch';

  @override
  String tonightOpenRecipe(String title) {
    return 'Tonight: $title. Open recipe';
  }

  @override
  String get captureHintClearer => 'Try a clearer photo';

  @override
  String get captureHintHoldSteady => 'Hold steady';

  @override
  String get captureHintMoreLight => 'Find more light';

  @override
  String get captureHintReduceGlare => 'Reduce glare';

  @override
  String get captureHintMoveCloser => 'Move closer';

  @override
  String get accountLanguage => 'Language';

  @override
  String get accountLanguageSystem => 'System';

  @override
  String get navHome => 'Home';

  @override
  String get navChores => 'Chores';

  @override
  String get navMoney => 'Money';

  @override
  String get navLists => 'Lists';

  @override
  String get navKitchen => 'Kitchen';

  @override
  String get offlineBannerTitle => 'Sync Status';

  @override
  String get offlineBannerStatusOffline => 'Offline';

  @override
  String get offlineBannerStatusPending => 'Pending sync';

  @override
  String get offlineBannerStatusFailed => 'Failed';

  @override
  String get offlineBannerRetryHint =>
      'Changes will be retried automatically when connectivity is restored.';

  @override
  String get offlineBannerOfflineHint =>
      'You can keep making changes offline. Everything will sync when you reconnect.';

  @override
  String get offlineBannerBarOffline =>
      'Offline — changes will sync when you reconnect';

  @override
  String offlineBannerSyncingCount(num count) {
    return 'Syncing $count changes…';
  }

  @override
  String get offlineBannerSyncing => 'Syncing changes…';

  @override
  String offlineBannerFailedCount(num count) {
    return 'Couldn\'t sync $count changes';
  }

  @override
  String get offlineBannerFailedOne => 'Couldn\'t sync a change';

  @override
  String get offlineBannerRetry => 'Retry';

  @override
  String get composerNewItem => 'New item';

  @override
  String get composerScanList => 'Scan list';

  @override
  String get composerAddItem => 'Add item';

  @override
  String get listItemViewPhoto => 'View photo';

  @override
  String get listItemReplacePhoto => 'Replace photo';

  @override
  String get listItemAddPhoto => 'Add photo';

  @override
  String get listItemRemovePhoto => 'Remove photo';

  @override
  String get listItemSetPrice => 'Set price';

  @override
  String get listItemDeleteAction => 'Delete';

  @override
  String get listItemReorder => 'Reorder';

  @override
  String listItemMarkUnchecked(String name) {
    return 'Mark $name as unchecked';
  }

  @override
  String listItemMarkChecked(String name) {
    return 'Mark $name as checked';
  }

  @override
  String listItemViewPhotoFor(String name) {
    return 'View photo for $name';
  }

  @override
  String get listItemFailedSave => 'Failed to save — tap the sync bar to retry';

  @override
  String get listItemLongPressHint => 'Long press for more options';

  @override
  String get scanCheckListPhoto => 'Check list photo';

  @override
  String get scanReadingList => 'Reading your list…';

  @override
  String get scanCouldNotProcess =>
      'Couldn\'t process the image. Please try again.';

  @override
  String get scanSnapYourList => 'Snap your list';

  @override
  String get scanTakePhoto => 'Take a photo';

  @override
  String get scanChooseFromGallery => 'Choose from gallery';

  @override
  String get appDialogClose => 'Close';

  @override
  String get appDialogPressBack => 'Press back to close';

  @override
  String get shellNotifications => 'Notifications';

  @override
  String get shellAccount => 'Account';

  @override
  String get errorSomethingWentWrong => 'Something went wrong';

  @override
  String filterRemoveLabel(String label) {
    return 'Remove $label filter';
  }

  @override
  String get currencyDropdownLabel => 'Currency';

  @override
  String get passwordStrengthWeak => 'Weak';

  @override
  String get passwordStrengthFair => 'Fair';

  @override
  String get passwordStrengthGood => 'Good';

  @override
  String get passwordStrengthStrong => 'Strong';

  @override
  String get checkToggleChecked => 'Checked';

  @override
  String get checkToggleNotChecked => 'Not checked';

  @override
  String get notificationsDeleteNotification => 'Delete notification';

  @override
  String get calendarTomorrow => 'Tomorrow';

  @override
  String get scannerCheckScan => 'Check scan';

  @override
  String get scannerCheckGrocery => 'Check grocery list';

  @override
  String recipeCreationNoItemsYet(String type) {
    return 'No $type yet.';
  }

  @override
  String get captureHintReady => 'Ready to scan';

  @override
  String get captureHintUsable => 'Looks usable';

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
  String activityAddedToNamedList(String name, String list, String when) {
    return 'Added $name to $list · $when';
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
