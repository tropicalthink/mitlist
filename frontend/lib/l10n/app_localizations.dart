import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_de.dart';
import 'app_localizations_en.dart';
import 'app_localizations_es.dart';
import 'app_localizations_fr.dart';
import 'app_localizations_nl.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('de'),
    Locale('en'),
    Locale('es'),
    Locale('fr'),
    Locale('nl')
  ];

  /// Generic cancel button
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get commonCancel;

  /// Generic delete button
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get commonDelete;

  /// Generic retry button
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get commonRetry;

  /// Generic save button
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get commonSave;

  /// Generic back button tooltip
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get commonBack;

  /// Generic close button tooltip
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get commonClose;

  /// Generic done/ready label
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get commonDone;

  /// Generic undo action label
  ///
  /// In en, this message translates to:
  /// **'Undo'**
  String get commonUndo;

  /// Generic add button
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get commonAdd;

  /// Generic confirm button
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get commonConfirm;

  /// Generic edit button tooltip
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get commonEdit;

  /// Generic search tooltip/label
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get commonSearch;

  /// Generic remove button
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get commonRemove;

  /// Generic dismiss button
  ///
  /// In en, this message translates to:
  /// **'Dismiss'**
  String get commonDismiss;

  /// Generic clear/reset button
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get commonClear;

  /// Generic next/forward button
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get commonNext;

  /// Generic skip button
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get commonSkip;

  /// Generic change/switch action
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get commonChange;

  /// Generic create button
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get commonCreate;

  /// Generic rename action
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get commonRename;

  /// Generic archive action
  ///
  /// In en, this message translates to:
  /// **'Archive'**
  String get commonArchive;

  /// Generic options menu tooltip
  ///
  /// In en, this message translates to:
  /// **'Options'**
  String get commonOptions;

  /// Generic settings tooltip/label
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get commonSettings;

  /// Generic name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get commonName;

  /// Generic description field label
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get commonDescription;

  /// Generic notes field label
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get commonNotes;

  /// Generic amount/price field label
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get commonAmount;

  /// Generic preview label
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get commonPreview;

  /// Generic share action
  ///
  /// In en, this message translates to:
  /// **'Share'**
  String get commonShare;

  /// Generic copy action
  ///
  /// In en, this message translates to:
  /// **'Copy'**
  String get commonCopy;

  /// Generic list name input label
  ///
  /// In en, this message translates to:
  /// **'List name'**
  String get commonListName;

  /// Generic saving-in-progress button text
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get commonSaving;

  /// Generic adding-in-progress button text
  ///
  /// In en, this message translates to:
  /// **'Adding…'**
  String get commonAdding;

  /// Generic deleting-in-progress button text
  ///
  /// In en, this message translates to:
  /// **'Deleting…'**
  String get commonDeleting;

  /// Empty state when user has no household
  ///
  /// In en, this message translates to:
  /// **'No household yet'**
  String get commonNoHousehold;

  /// Description shown when no household exists
  ///
  /// In en, this message translates to:
  /// **'Create or join a household before adding items.'**
  String get commonCreateJoinHousehold;

  /// Button to navigate to household management
  ///
  /// In en, this message translates to:
  /// **'Go to households'**
  String get commonGoToHouseholds;

  /// Generic error title
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get commonSomethingWentWrong;

  /// Generic load failure message
  ///
  /// In en, this message translates to:
  /// **'Failed to load. Please try again.'**
  String get commonFailedToLoad;

  /// Hint to check network connectivity
  ///
  /// In en, this message translates to:
  /// **'Check your connection and try again.'**
  String get commonCheckConnection;

  /// Button to clear active search filter
  ///
  /// In en, this message translates to:
  /// **'Clear search'**
  String get commonClearSearch;

  /// Member count with plural forms
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} member} other{{count} members}}'**
  String commonMember(num count);

  /// Item count with plural forms
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String commonItemCount(num count);

  /// Placeholder shown while household members load
  ///
  /// In en, this message translates to:
  /// **'Loading members...'**
  String get commonLoadingMembers;

  /// Subtitle under the app name on the welcome screen
  ///
  /// In en, this message translates to:
  /// **'Your household, organized.'**
  String get welcomeTagline;

  /// Headline in the welcome card; contains a line break
  ///
  /// In en, this message translates to:
  /// **'Lists, chores, money.\nAll in one place.'**
  String get welcomeCardTitle;

  /// Supporting body text in the welcome card
  ///
  /// In en, this message translates to:
  /// **'Built for flatmates who want less friction and more clarity.'**
  String get welcomeCardBody;

  /// Primary CTA button on the welcome screen
  ///
  /// In en, this message translates to:
  /// **'Create free household'**
  String get welcomeCreateHousehold;

  /// Secondary sign-in button on the welcome screen
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get welcomeSignIn;

  /// Loading label shown while guest account is being created
  ///
  /// In en, this message translates to:
  /// **'Setting up...'**
  String get welcomeGuestLoading;

  /// Ghost button to continue without an account
  ///
  /// In en, this message translates to:
  /// **'Continue as guest'**
  String get welcomeContinueAsGuest;

  /// Headline on the invite-accept welcome card
  ///
  /// In en, this message translates to:
  /// **'You\'re invited'**
  String get welcomeInviteHeadline;

  /// Subtitle on the invite-accept welcome card
  ///
  /// In en, this message translates to:
  /// **'Join the household to share lists, chores, and money.'**
  String get welcomeInviteSubtitle;

  /// Footnote below the guest button explaining the trial
  ///
  /// In en, this message translates to:
  /// **'No account needed. Try everything free for 30 days.'**
  String get welcomeGuestFootnote;

  /// AppBar title for the household hub screen
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get hubAppBarTitle;

  /// Bottom sheet title for household switcher
  ///
  /// In en, this message translates to:
  /// **'Households'**
  String get hubHouseholdsSheetTitle;

  /// Semantics label for switching households
  ///
  /// In en, this message translates to:
  /// **'Switch to {name}'**
  String hubSwitchToHousehold(String name);

  /// Button to create a new household
  ///
  /// In en, this message translates to:
  /// **'Create household'**
  String get hubCreateHousehold;

  /// Button to join an existing household
  ///
  /// In en, this message translates to:
  /// **'Join household'**
  String get hubJoinHousehold;

  /// Button to invite someone to the household
  ///
  /// In en, this message translates to:
  /// **'Invite to household'**
  String get hubInviteToHousehold;

  /// Button to open household settings
  ///
  /// In en, this message translates to:
  /// **'Household settings'**
  String get hubHouseholdSettings;

  /// Headline when user has no household yet
  ///
  /// In en, this message translates to:
  /// **'Welcome to mitlist'**
  String get hubWelcomeHeadline;

  /// Description when user has no household yet
  ///
  /// In en, this message translates to:
  /// **'Create or join a household to start sharing lists, chores, and expenses.'**
  String get hubWelcomeDescription;

  /// Primary CTA to create a household
  ///
  /// In en, this message translates to:
  /// **'Create a household'**
  String get hubCreateAHousehold;

  /// Secondary CTA to join via invite code
  ///
  /// In en, this message translates to:
  /// **'Join with invite code'**
  String get hubJoinWithInviteCode;

  /// FAB text and tooltip for quick-add action
  ///
  /// In en, this message translates to:
  /// **'Quick add'**
  String get hubQuickAdd;

  /// Error shown when households fail to load
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load your households. Check your connection and try again.'**
  String get hubLoadError;

  /// Tooltip for the calendar icon button
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get hubCalendarTooltip;

  /// AppBar title for the groups/landing screen
  ///
  /// In en, this message translates to:
  /// **'My Households'**
  String get myHouseholdsTitle;

  /// Button tooltip to join via invite code
  ///
  /// In en, this message translates to:
  /// **'Join with code'**
  String get groupsJoinWithCode;

  /// Error message when household list fails
  ///
  /// In en, this message translates to:
  /// **'Failed to load households'**
  String get groupsFailedLoad;

  /// Error when pagination fails
  ///
  /// In en, this message translates to:
  /// **'Failed to load more households'**
  String get groupsFailedMore;

  /// Empty state when no households exist
  ///
  /// In en, this message translates to:
  /// **'No households yet'**
  String get groupsEmptyTitle;

  /// Empty state description for no households
  ///
  /// In en, this message translates to:
  /// **'Create one to start organizing your home.'**
  String get groupsEmptyDesc;

  /// Button to create first household
  ///
  /// In en, this message translates to:
  /// **'Create household'**
  String get groupsCreateHousehold;

  /// AppBar title for chores screen
  ///
  /// In en, this message translates to:
  /// **'Chores'**
  String get choreAppBarTitle;

  /// Menu item / button that opens the chore zones editor
  ///
  /// In en, this message translates to:
  /// **'Manage zones'**
  String get choreManageZones;

  /// FAB text and tooltip to add a chore
  ///
  /// In en, this message translates to:
  /// **'Add chore'**
  String get choreAddChore;

  /// FAB text when no household exists
  ///
  /// In en, this message translates to:
  /// **'Households'**
  String get choreAddHouseholds;

  /// Retry button on chores screen
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get choreRetry;

  /// Empty state when no household
  ///
  /// In en, this message translates to:
  /// **'No household yet'**
  String get choreNoHouseholdTitle;

  /// Empty description when no household
  ///
  /// In en, this message translates to:
  /// **'Create or join a household before adding chores.'**
  String get choreNoHouseholdDesc;

  /// Navigate to household management
  ///
  /// In en, this message translates to:
  /// **'Go to households'**
  String get choreGoToHouseholds;

  /// Empty state when household has no chores
  ///
  /// In en, this message translates to:
  /// **'No chores yet'**
  String get choreNoChoresTitle;

  /// Description for no chores empty state
  ///
  /// In en, this message translates to:
  /// **'Track recurring household tasks. Assign them to anyone in your group.'**
  String get choreNoChoresDesc;

  /// CTA button to add first chore
  ///
  /// In en, this message translates to:
  /// **'Add a chore'**
  String get choreAddAChore;

  /// Section header for overdue chores
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get choreSectionOverdue;

  /// Section header for today's chores
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get choreSectionToday;

  /// Section header for this week's chores
  ///
  /// In en, this message translates to:
  /// **'This week'**
  String get choreSectionThisWeek;

  /// Section header for future chores
  ///
  /// In en, this message translates to:
  /// **'Later'**
  String get choreSectionLater;

  /// Empty state when user has no assigned chores
  ///
  /// In en, this message translates to:
  /// **'Nothing on you right now'**
  String get choreNothingOnYou;

  /// Description when no chores assigned to user
  ///
  /// In en, this message translates to:
  /// **'Your household has chores, but none are assigned to you.'**
  String get choreNothingOnYouDesc;

  /// Button to show all household chores
  ///
  /// In en, this message translates to:
  /// **'See everyone\'s chores'**
  String get choreSeeEveryonesChores;

  /// Snackbar when a chore is marked done
  ///
  /// In en, this message translates to:
  /// **'{choreTitle} done'**
  String choreDoneSnackbar(String choreTitle);

  /// Header of the recently-completed ledger section
  ///
  /// In en, this message translates to:
  /// **'Done recently'**
  String get choreDoneRecently;

  /// Ledger: the current user did it
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get choreLedgerYou;

  /// Ledger: unknown member did it
  ///
  /// In en, this message translates to:
  /// **'Someone'**
  String get choreLedgerSomeone;

  /// Ledger line: who did it and when
  ///
  /// In en, this message translates to:
  /// **'{who} · {when}'**
  String choreLedgerDoneBy(String who, String when);

  /// Relative time: under an hour ago
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get choreLedgerJustNow;

  /// Relative time in hours
  ///
  /// In en, this message translates to:
  /// **'{count}h ago'**
  String choreLedgerHoursAgo(int count);

  /// Relative time: yesterday
  ///
  /// In en, this message translates to:
  /// **'yesterday'**
  String get choreLedgerYesterday;

  /// When a recurring chore comes back
  ///
  /// In en, this message translates to:
  /// **'back {date}'**
  String choreBackOnDate(String date);

  /// Chore with no assignee — anyone can claim it
  ///
  /// In en, this message translates to:
  /// **'Up for grabs'**
  String get choreUpForGrabs;

  /// Snackbar: chore done, comes back on date
  ///
  /// In en, this message translates to:
  /// **'{choreTitle} done — back {date}'**
  String choreDoneBackSnackbar(String choreTitle, String date);

  /// Who-picker: whole household rotates
  ///
  /// In en, this message translates to:
  /// **'Everyone'**
  String get choreWhoEveryone;

  /// Who-picker: chore stays unassigned
  ///
  /// In en, this message translates to:
  /// **'No one'**
  String get choreWhoNoOne;

  /// Who-picker hint: single fixed owner
  ///
  /// In en, this message translates to:
  /// **'Always {name}'**
  String choreWhoAlways(String name);

  /// Who-picker hint: rotation over a subset
  ///
  /// In en, this message translates to:
  /// **'Rotates between the {count} people you picked.'**
  String choreWhoAmongSelected(int count);

  /// Label for the rotation-policy chips
  ///
  /// In en, this message translates to:
  /// **'Order'**
  String get choreWhoOrderLabel;

  /// Detail row: how often the chore repeats
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get choreDetailRhythm;

  /// Load sheet summary line
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 chore} other{{count} chores}} done in the last {days} days'**
  String choreLoadSummary(num count, int days);

  /// Error snackbar when chore completion fails
  ///
  /// In en, this message translates to:
  /// **'Failed to complete chore. Please try again.'**
  String get choreFailedComplete;

  /// Error snackbar when undoing chore fails
  ///
  /// In en, this message translates to:
  /// **'Failed to undo chore execution. Please try again.'**
  String get choreFailedUndo;

  /// Error snackbar when skipping chore fails
  ///
  /// In en, this message translates to:
  /// **'Failed to skip chore. Please try again.'**
  String get choreFailedSkip;

  /// Error snackbar when subtask update fails
  ///
  /// In en, this message translates to:
  /// **'Failed to update subtask. Please try again.'**
  String get choreFailedUpdateSubtask;

  /// Error snackbar when subtask creation fails
  ///
  /// In en, this message translates to:
  /// **'Failed to add subtask. Please try again.'**
  String get choreFailedAddSubtask;

  /// Snackbar when trying to add supplies without a list
  ///
  /// In en, this message translates to:
  /// **'Create a shopping list first.'**
  String get choreCreateListFirst;

  /// Dialog title for adding supplies
  ///
  /// In en, this message translates to:
  /// **'Add supplies to list'**
  String get choreAddSuppliesToList;

  /// Snackbar when supplies are added to a list
  ///
  /// In en, this message translates to:
  /// **'Supplies added to list'**
  String get choreSuppliesAdded;

  /// Error when adding supplies fails
  ///
  /// In en, this message translates to:
  /// **'Failed to add supplies. Please try again.'**
  String get choreFailedAddSupplies;

  /// Error when rescheduling chore fails
  ///
  /// In en, this message translates to:
  /// **'Failed to reschedule chore. Please try again.'**
  String get choreFailedReschedule;

  /// Dialog title for deleting a chore
  ///
  /// In en, this message translates to:
  /// **'Delete chore'**
  String get choreDeleteTitle;

  /// Dialog body for chore deletion
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete this chore and its history. This cannot be undone.'**
  String get choreDeleteBody;

  /// Chore status label: completed
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get choreStatusDone;

  /// Chore status label: overdue
  ///
  /// In en, this message translates to:
  /// **'Overdue'**
  String get choreStatusOverdue;

  /// Chore status label: due today
  ///
  /// In en, this message translates to:
  /// **'Due today'**
  String get choreStatusDueToday;

  /// Chore status label: due soon
  ///
  /// In en, this message translates to:
  /// **'Due soon'**
  String get choreStatusDueSoon;

  /// Chore status label: scheduled
  ///
  /// In en, this message translates to:
  /// **'Scheduled'**
  String get choreStatusScheduled;

  /// Chore status label: pending
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get choreStatusPending;

  /// Label when it's the current user's turn
  ///
  /// In en, this message translates to:
  /// **'Your turn'**
  String get choreYourTurn;

  /// Label when it's another member's turn
  ///
  /// In en, this message translates to:
  /// **'{name}\'s turn'**
  String choreSomeonesTurn(String name);

  /// Inline notice when a background refresh fails but cached chores are shown
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t refresh. Showing saved chores.'**
  String get choreRefreshFailed;

  /// Fairness strip summary of completed chores over 30 days
  ///
  /// In en, this message translates to:
  /// **'{count} done, last 30 days'**
  String choreDoneLast30Days(num count);

  /// Hero text when user has no active chores
  ///
  /// In en, this message translates to:
  /// **'You\'re clear'**
  String get choreYoureClear;

  /// Hero description for 1 chore due
  ///
  /// In en, this message translates to:
  /// **'{count} chore needs you now.'**
  String choreHeroDescSingular(num count);

  /// Hero description for multiple chores due
  ///
  /// In en, this message translates to:
  /// **'{count} chores need you now.'**
  String choreHeroDescPlural(num count);

  /// Filter chip for user's own chores
  ///
  /// In en, this message translates to:
  /// **'Me ({count})'**
  String choreMeLabel(num count);

  /// Filter chip for all household chores
  ///
  /// In en, this message translates to:
  /// **'Everyone ({count})'**
  String choreEveryoneLabel(num count);

  /// Fairness strip header text
  ///
  /// In en, this message translates to:
  /// **'How it splits'**
  String get choreHowItSplits;

  /// Supply count label (1)
  ///
  /// In en, this message translates to:
  /// **'{count} supply'**
  String choreSupplySingular(num count);

  /// Supply count label (2+)
  ///
  /// In en, this message translates to:
  /// **'{count} supplies'**
  String choreSupplyPlural(num count);

  /// Hourly recurrence label
  ///
  /// In en, this message translates to:
  /// **'Hourly'**
  String get choreFrequencyHourly;

  /// Daily recurrence label
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get choreFrequencyDaily;

  /// Weekly recurrence label
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get choreFrequencyWeekly;

  /// Monthly recurrence label
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get choreFrequencyMonthly;

  /// Yearly recurrence label
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get choreFrequencyYearly;

  /// As-needed frequency label
  ///
  /// In en, this message translates to:
  /// **'As needed'**
  String get choreFrequencyAsNeeded;

  /// One-off frequency label
  ///
  /// In en, this message translates to:
  /// **'One-off'**
  String get choreFrequencyOneOff;

  /// Recurrence interval summary
  ///
  /// In en, this message translates to:
  /// **'Every {interval} {unit}'**
  String choreEveryInterval(num interval, String unit);

  /// Last action label: done today
  ///
  /// In en, this message translates to:
  /// **'Done today'**
  String get choreDoneToday;

  /// Last action label: done yesterday
  ///
  /// In en, this message translates to:
  /// **'Done yesterday'**
  String get choreDoneYesterday;

  /// Last action label for days ago
  ///
  /// In en, this message translates to:
  /// **'Done {days}d ago'**
  String choreDoneDaysAgo(num days);

  /// Last action label: skipped
  ///
  /// In en, this message translates to:
  /// **'Skipped'**
  String get choreSkipped;

  /// Semantics: toggle chore undone
  ///
  /// In en, this message translates to:
  /// **'Mark {title} as not done'**
  String choreMarkNotDone(String title);

  /// Semantics: toggle chore done
  ///
  /// In en, this message translates to:
  /// **'Mark {title} as done'**
  String choreMarkDone(String title);

  /// Semantics when no chores pending
  ///
  /// In en, this message translates to:
  /// **'You are all caught up'**
  String get choreAllCaughtUp;

  /// Share of open chores
  ///
  /// In en, this message translates to:
  /// **'Carrying {my} of {total} open chores'**
  String choreCarryingShare(num my, num total);

  /// Share label when no chores
  ///
  /// In en, this message translates to:
  /// **'Nothing on you right now'**
  String get choreNothingShare;

  /// Bottom sheet title for chore creation
  ///
  /// In en, this message translates to:
  /// **'Add chore'**
  String get choreCreationTitle;

  /// Input hint for chore name
  ///
  /// In en, this message translates to:
  /// **'Chore name'**
  String get choreCreationNameHint;

  /// Label for saved routines section
  ///
  /// In en, this message translates to:
  /// **'Your routines'**
  String get choreCreationYourRoutines;

  /// Prompt to pick a routine
  ///
  /// In en, this message translates to:
  /// **'Start from a routine'**
  String get choreCreationStartFromRoutine;

  /// Label for AI suggestions section
  ///
  /// In en, this message translates to:
  /// **'Suggestions'**
  String get choreCreationSuggestions;

  /// Label for zone selector
  ///
  /// In en, this message translates to:
  /// **'Zone'**
  String get choreCreationZoneLabel;

  /// Kitchen zone preset
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get choreCreationZoneKitchen;

  /// Bathroom zone preset
  ///
  /// In en, this message translates to:
  /// **'Bathroom'**
  String get choreCreationZoneBathroom;

  /// Living room zone preset
  ///
  /// In en, this message translates to:
  /// **'Living room'**
  String get choreCreationZoneLivingRoom;

  /// Bedroom zone preset
  ///
  /// In en, this message translates to:
  /// **'Bedroom'**
  String get choreCreationZoneBedroom;

  /// Outdoor zone preset
  ///
  /// In en, this message translates to:
  /// **'Outdoor'**
  String get choreCreationZoneOutdoor;

  /// Shared space zone preset
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get choreCreationZoneShared;

  /// Label for recurrence selector
  ///
  /// In en, this message translates to:
  /// **'Repeats'**
  String get choreCreationRepeatsLabel;

  /// No recurrence option
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get choreCreationRecurrenceNone;

  /// Hourly recurrence option
  ///
  /// In en, this message translates to:
  /// **'Hourly'**
  String get choreCreationRecurrenceHourly;

  /// Daily recurrence option
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get choreCreationRecurrenceDaily;

  /// Weekly recurrence option
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get choreCreationRecurrenceWeekly;

  /// Monthly recurrence option
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get choreCreationRecurrenceMonthly;

  /// Yearly recurrence option
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get choreCreationRecurrenceYearly;

  /// Adaptive recurrence option
  ///
  /// In en, this message translates to:
  /// **'Adaptive'**
  String get choreCreationRecurrenceAdaptive;

  /// Description of no recurrence
  ///
  /// In en, this message translates to:
  /// **'A one-time chore. It won\'t come back on its own.'**
  String get choreCreationHintNone;

  /// Description of hourly recurrence
  ///
  /// In en, this message translates to:
  /// **'Comes back every set number of hours.'**
  String get choreCreationHintHourly;

  /// Description of daily recurrence
  ///
  /// In en, this message translates to:
  /// **'Comes back every set number of days.'**
  String get choreCreationHintDaily;

  /// Description of weekly recurrence
  ///
  /// In en, this message translates to:
  /// **'Comes back each week on the days you pick.'**
  String get choreCreationHintWeekly;

  /// Description of monthly recurrence
  ///
  /// In en, this message translates to:
  /// **'Comes back monthly on the same date.'**
  String get choreCreationHintMonthly;

  /// Description of yearly recurrence
  ///
  /// In en, this message translates to:
  /// **'Comes back yearly on the same date.'**
  String get choreCreationHintYearly;

  /// Description of adaptive recurrence
  ///
  /// In en, this message translates to:
  /// **'Comes back based on when it was last done, not the calendar.'**
  String get choreCreationHintAdaptive;

  /// Default interval value hint
  ///
  /// In en, this message translates to:
  /// **'1'**
  String get choreCreationIntervalHint;

  /// Toggle to show more chore options
  ///
  /// In en, this message translates to:
  /// **'More options'**
  String get choreCreationMoreOptions;

  /// Label for assignee selector
  ///
  /// In en, this message translates to:
  /// **'Who'**
  String get choreCreationAssignLabel;

  /// Rotation assignment mode
  ///
  /// In en, this message translates to:
  /// **'Take turns'**
  String get choreCreationAssignTakeTurns;

  /// Least-done assignment mode
  ///
  /// In en, this message translates to:
  /// **'Least done'**
  String get choreCreationAssignLeastDone;

  /// Alphabetical assignment mode
  ///
  /// In en, this message translates to:
  /// **'Alphabetical'**
  String get choreCreationAssignAlphabetical;

  /// Random assignment mode
  ///
  /// In en, this message translates to:
  /// **'Random'**
  String get choreCreationAssignRandom;

  /// Unassigned option
  ///
  /// In en, this message translates to:
  /// **'No assignee'**
  String get choreCreationAssignNoAssignee;

  /// Description of rotation assignment
  ///
  /// In en, this message translates to:
  /// **'Rotates to the next person each time.'**
  String get choreCreationAssignHintTurns;

  /// Description of alphabetical assignment
  ///
  /// In en, this message translates to:
  /// **'Goes in alphabetical order of names.'**
  String get choreCreationAssignHintAlpha;

  /// Description of least-done assignment
  ///
  /// In en, this message translates to:
  /// **'Goes to whoever has done it least.'**
  String get choreCreationAssignHintLeast;

  /// Description of random assignment
  ///
  /// In en, this message translates to:
  /// **'Picks someone at random each time.'**
  String get choreCreationAssignHintRandom;

  /// Description of no-assignee option
  ///
  /// In en, this message translates to:
  /// **'Stays unassigned. Anyone in the household can pick it up.'**
  String get choreCreationAssignHintNone;

  /// Toggle to log without marking complete
  ///
  /// In en, this message translates to:
  /// **'Log when done, don\'t tick off'**
  String get choreCreationLogWhenDone;

  /// Helper text for log-only toggle
  ///
  /// In en, this message translates to:
  /// **'Records the date without marking it complete. Good for tasks you want a history of.'**
  String get choreCreationLogWhenDoneHelper;

  /// Toggle for roll-over behavior
  ///
  /// In en, this message translates to:
  /// **'Roll over if missed'**
  String get choreCreationRollOver;

  /// Helper text for roll-over toggle
  ///
  /// In en, this message translates to:
  /// **'Shifts to the next due date instead of piling up as overdue.'**
  String get choreCreationRollOverHelper;

  /// Placeholder for chore notes field
  ///
  /// In en, this message translates to:
  /// **'Notes (optional) — steps, reminders, anything useful'**
  String get choreCreationNotesHint;

  /// Button to save chore as reusable routine
  ///
  /// In en, this message translates to:
  /// **'Save as routine'**
  String get choreCreationSaveAsRoutine;

  /// Semantic label for save-as-routine
  ///
  /// In en, this message translates to:
  /// **'Save this chore as a reusable routine'**
  String get choreCreationSaveAsRoutineSemantic;

  /// Semantic label for scan chore action
  ///
  /// In en, this message translates to:
  /// **'Scan chore via camera'**
  String get choreCreationScanChoreSemantic;

  /// Snackbar when chore is created
  ///
  /// In en, this message translates to:
  /// **'Chore added'**
  String get choreCreationChoreAdded;

  /// Snackbar when chore is created with assignee
  ///
  /// In en, this message translates to:
  /// **'Chore added · next up: {assignee}'**
  String choreCreationChoreAddedNextUp(String assignee);

  /// Snackbar when creating chore without household
  ///
  /// In en, this message translates to:
  /// **'Create or join a household first.'**
  String get choreCreationJoinFirst;

  /// Dialog title for editing a routine
  ///
  /// In en, this message translates to:
  /// **'Edit routine'**
  String get choreCreationEditRoutine;

  /// Singular recurrence label
  ///
  /// In en, this message translates to:
  /// **'Every {unit}'**
  String choreCreationEverySingular(String unit);

  /// Plural recurrence label
  ///
  /// In en, this message translates to:
  /// **'Every {n} {unit}'**
  String choreCreationEveryPlural(num n, String unit);

  /// Singular hour unit
  ///
  /// In en, this message translates to:
  /// **'hour'**
  String get choreCreationUnitHourSingular;

  /// Plural hours unit
  ///
  /// In en, this message translates to:
  /// **'hours'**
  String get choreCreationUnitHourPlural;

  /// Singular day unit
  ///
  /// In en, this message translates to:
  /// **'day'**
  String get choreCreationUnitDaySingular;

  /// Plural days unit
  ///
  /// In en, this message translates to:
  /// **'days'**
  String get choreCreationUnitDayPlural;

  /// Singular week unit
  ///
  /// In en, this message translates to:
  /// **'week'**
  String get choreCreationUnitWeekSingular;

  /// Plural weeks unit
  ///
  /// In en, this message translates to:
  /// **'weeks'**
  String get choreCreationUnitWeekPlural;

  /// Singular month unit
  ///
  /// In en, this message translates to:
  /// **'month'**
  String get choreCreationUnitMonthSingular;

  /// Plural months unit
  ///
  /// In en, this message translates to:
  /// **'months'**
  String get choreCreationUnitMonthPlural;

  /// Singular year unit
  ///
  /// In en, this message translates to:
  /// **'year'**
  String get choreCreationUnitYearSingular;

  /// Plural years unit
  ///
  /// In en, this message translates to:
  /// **'years'**
  String get choreCreationUnitYearPlural;

  /// Monday abbreviation
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get choreDayMon;

  /// Tuesday abbreviation
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get choreDayTue;

  /// Wednesday abbreviation
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get choreDayWed;

  /// Thursday abbreviation
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get choreDayThu;

  /// Friday abbreviation
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get choreDayFri;

  /// Saturday abbreviation
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get choreDaySat;

  /// Sunday abbreviation
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get choreDaySun;

  /// Bottom sheet title for chore detail
  ///
  /// In en, this message translates to:
  /// **'Chore details'**
  String get choreDetailTitle;

  /// Detail row: assigned to
  ///
  /// In en, this message translates to:
  /// **'Whose turn'**
  String get choreDetailAssignee;

  /// Detail row: due date
  ///
  /// In en, this message translates to:
  /// **'Due'**
  String get choreDetailDue;

  /// Detail row: tracking info
  ///
  /// In en, this message translates to:
  /// **'Tracked'**
  String get choreDetailTracked;

  /// Detail row: last completed
  ///
  /// In en, this message translates to:
  /// **'Last done'**
  String get choreDetailLastDone;

  /// Detail row: last completed by
  ///
  /// In en, this message translates to:
  /// **'Last by'**
  String get choreDetailLastBy;

  /// Detail row: average interval
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get choreDetailAverage;

  /// Section header for subtasks
  ///
  /// In en, this message translates to:
  /// **'Subtasks'**
  String get choreDetailSubtasks;

  /// Placeholder for new subtask input
  ///
  /// In en, this message translates to:
  /// **'New subtask'**
  String get choreDetailNewSubtask;

  /// Section header for supplies
  ///
  /// In en, this message translates to:
  /// **'Supplies'**
  String get choreDetailSupplies;

  /// Button to add supplies to a shopping list
  ///
  /// In en, this message translates to:
  /// **'Add supplies to list'**
  String get choreDetailAddSuppliesToList;

  /// Button to mark chore as done
  ///
  /// In en, this message translates to:
  /// **'Mark done'**
  String get choreDetailMarkDone;

  /// Button to reschedule for tomorrow
  ///
  /// In en, this message translates to:
  /// **'Move to tomorrow'**
  String get choreDetailMoveToTomorrow;

  /// Button to undo most recent completion
  ///
  /// In en, this message translates to:
  /// **'Undo last execution'**
  String get choreDetailUndoLast;

  /// Dialog title for skipping a chore
  ///
  /// In en, this message translates to:
  /// **'Skip chore'**
  String get choreDetailSkipTitle;

  /// Optional skip reason input label
  ///
  /// In en, this message translates to:
  /// **'Reason (optional)'**
  String get choreDetailSkipReason;

  /// Placeholder for skip reason
  ///
  /// In en, this message translates to:
  /// **'e.g. Away this week'**
  String get choreDetailSkipReasonHint;

  /// Dialog title for deleting chore
  ///
  /// In en, this message translates to:
  /// **'Delete chore'**
  String get choreDetailDeleteTitleDialog;

  /// Dialog body for chore deletion
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete this chore and its history.'**
  String get choreDetailDeleteBody;

  /// Tooltip for deleting a subtask
  ///
  /// In en, this message translates to:
  /// **'Delete subtask'**
  String get choreDetailDeleteSubtask;

  /// Toggle subtask to undone
  ///
  /// In en, this message translates to:
  /// **'Mark subtask as not done'**
  String get choreDetailSubtaskMarkNotDone;

  /// Toggle subtask to done
  ///
  /// In en, this message translates to:
  /// **'Mark subtask as done'**
  String get choreDetailSubtaskMarkDone;

  /// Bottom sheet title for chore load/fairness view
  ///
  /// In en, this message translates to:
  /// **'Who\'s doing the chores'**
  String get choreLoadTitle;

  /// Empty state for chore load when no data
  ///
  /// In en, this message translates to:
  /// **'No chores have been completed in the last {days} days yet. Once people start ticking things off, the split shows up here.'**
  String choreLoadEmpty(num days);

  /// Singular chore count in load view
  ///
  /// In en, this message translates to:
  /// **'{count} chore'**
  String choreLoadCountSingular(num count);

  /// Plural chore count in load view
  ///
  /// In en, this message translates to:
  /// **'{count} chores'**
  String choreLoadCountPlural(num count);

  /// AppBar title for recipes/kitchen screen
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get recipeAppBarTitle;

  /// TextField label for recipe search
  ///
  /// In en, this message translates to:
  /// **'Search kitchen'**
  String get recipeSearchLabel;

  /// TextField hint for recipe search
  ///
  /// In en, this message translates to:
  /// **'Recipe, tag, ingredient'**
  String get recipeSearchHint;

  /// Tooltip for meal plan navigation
  ///
  /// In en, this message translates to:
  /// **'Meal plan'**
  String get recipeMealPlanTooltip;

  /// Tooltip for search toggle
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get recipeSearchTooltip;

  /// Disabled menu item for sort label
  ///
  /// In en, this message translates to:
  /// **'Sort recipes'**
  String get recipeSortLabel;

  /// Sort by newest
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get recipeSortNewest;

  /// Sort by oldest
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get recipeSortOldest;

  /// Sort alphabetically
  ///
  /// In en, this message translates to:
  /// **'A-Z'**
  String get recipeSortAZ;

  /// FAB text and tooltip to add recipe
  ///
  /// In en, this message translates to:
  /// **'Add recipe'**
  String get recipeAddRecipe;

  /// Error when recipes fail to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load kitchen'**
  String get recipeFailedLoad;

  /// Error when recipe pagination fails
  ///
  /// In en, this message translates to:
  /// **'Failed to load more recipes'**
  String get recipeFailedMore;

  /// Empty state title for no recipes
  ///
  /// In en, this message translates to:
  /// **'Build your kitchen'**
  String get recipeBuildKitchen;

  /// Empty state description for no recipes
  ///
  /// In en, this message translates to:
  /// **'Import recipes, group cookbooks, plan meals, and turn the week into a shopping list.'**
  String get recipeBuildKitchenDesc;

  /// Empty state title when a search or filter excludes every recipe
  ///
  /// In en, this message translates to:
  /// **'No recipes match'**
  String get recipeNoMatchTitle;

  /// Empty state description when a search or filter excludes every recipe
  ///
  /// In en, this message translates to:
  /// **'Try a different search or filter.'**
  String get recipeNoMatchDesc;

  /// Button that clears the active search and filter to show every recipe
  ///
  /// In en, this message translates to:
  /// **'Show all recipes'**
  String get recipeShowAllRecipes;

  /// Meal plan summary label
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 meal planned this week} other{{count} meals planned this week}}'**
  String recipeMealsPlanned(num count);

  /// Button text for planning recipes into meal plan
  ///
  /// In en, this message translates to:
  /// **'Plan'**
  String get recipePlanButton;

  /// Header count label when filtered
  ///
  /// In en, this message translates to:
  /// **'{visible} of {total} recipes'**
  String recipeCountLabel(num visible, num total);

  /// Header count label when showing all
  ///
  /// In en, this message translates to:
  /// **'{total} recipes'**
  String recipeCountLabelAll(num total);

  /// Filter chip: all recipes
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get recipeFilterAll;

  /// Filter chip: shared recipes
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get recipeFilterShared;

  /// Filter chip: private recipes
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get recipeFilterPrivate;

  /// Semantics label for recipe image
  ///
  /// In en, this message translates to:
  /// **'Image of {title}'**
  String recipeImageSemantics(String title);

  /// Cooking time display
  ///
  /// In en, this message translates to:
  /// **'{minutes} min'**
  String recipeMinLabel(num minutes);

  /// Servings display
  ///
  /// In en, this message translates to:
  /// **'Serves {servings}'**
  String recipeServesLabel(num servings);

  /// Semantics: open recipe
  ///
  /// In en, this message translates to:
  /// **'Open recipe {title}'**
  String recipeOpenRecipe(String title);

  /// Icon button tooltip: add ingredients to list
  ///
  /// In en, this message translates to:
  /// **'Add to list'**
  String get recipeAddToList;

  /// Secondary button: add only the recipe ingredients not already on the list
  ///
  /// In en, this message translates to:
  /// **'Add only what\'s missing'**
  String get recipeAddOnlyMissing;

  /// Snackbar after adding only missing ingredients
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing missing — you\'re all set} =1{1 missing item added} other{{count} missing items added}}'**
  String recipeAddMissingAdded(num count);

  /// Products catalog screen title
  ///
  /// In en, this message translates to:
  /// **'Products'**
  String get productsTitle;

  /// Products search field hint
  ///
  /// In en, this message translates to:
  /// **'Search products'**
  String get productsSearchHint;

  /// Products empty state title
  ///
  /// In en, this message translates to:
  /// **'No products yet'**
  String get productsEmptyTitle;

  /// Products empty state description
  ///
  /// In en, this message translates to:
  /// **'Save products you buy often to reuse them across your lists.'**
  String get productsEmptyDesc;

  /// Products search no-results title
  ///
  /// In en, this message translates to:
  /// **'No products match your search'**
  String get productsNoResults;

  /// Add product button
  ///
  /// In en, this message translates to:
  /// **'Add product'**
  String get productsAdd;

  /// New product sheet title
  ///
  /// In en, this message translates to:
  /// **'New product'**
  String get productsSheetTitle;

  /// Product name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get productsFieldName;

  /// Product unit field label
  ///
  /// In en, this message translates to:
  /// **'Unit (optional)'**
  String get productsFieldUnit;

  /// Product barcode field label
  ///
  /// In en, this message translates to:
  /// **'Barcode (optional)'**
  String get productsFieldBarcode;

  /// Product name validation message
  ///
  /// In en, this message translates to:
  /// **'Enter a product name'**
  String get productsValidationName;

  /// Product create error snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create product'**
  String get productsCouldNotCreate;

  /// Products no-household description
  ///
  /// In en, this message translates to:
  /// **'Join or create a household to keep a product catalog.'**
  String get productsNoHouseholdDesc;

  /// Shopping locations screen title
  ///
  /// In en, this message translates to:
  /// **'Shopping locations'**
  String get shoppingLocationsTitle;

  /// Shopping locations empty state title
  ///
  /// In en, this message translates to:
  /// **'No locations yet'**
  String get shoppingLocationsEmptyTitle;

  /// Shopping locations empty state description
  ///
  /// In en, this message translates to:
  /// **'Name the stores you shop at to organize your trips.'**
  String get shoppingLocationsEmptyDesc;

  /// Add shopping location button
  ///
  /// In en, this message translates to:
  /// **'Add location'**
  String get shoppingLocationsAdd;

  /// New shopping location sheet title
  ///
  /// In en, this message translates to:
  /// **'New location'**
  String get shoppingLocationsSheetTitle;

  /// Location name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get shoppingLocationsFieldName;

  /// Location name validation message
  ///
  /// In en, this message translates to:
  /// **'Enter a location name'**
  String get shoppingLocationsValidationName;

  /// Location create error snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create location'**
  String get shoppingLocationsCouldNotCreate;

  /// Shopping locations no-household description
  ///
  /// In en, this message translates to:
  /// **'Join or create a household to save shopping locations.'**
  String get shoppingLocationsNoHouseholdDesc;

  /// Cookbooks screen title
  ///
  /// In en, this message translates to:
  /// **'Cookbooks'**
  String get cookbooksTitle;

  /// Kitchen header button that opens cookbooks
  ///
  /// In en, this message translates to:
  /// **'Cookbooks'**
  String get cookbooksButton;

  /// Cookbooks empty state title
  ///
  /// In en, this message translates to:
  /// **'No cookbooks yet'**
  String get cookbooksEmptyTitle;

  /// Cookbooks empty state description
  ///
  /// In en, this message translates to:
  /// **'Group your recipes into cookbooks to find them faster.'**
  String get cookbooksEmptyDesc;

  /// Create cookbook button
  ///
  /// In en, this message translates to:
  /// **'New cookbook'**
  String get cookbooksAdd;

  /// New cookbook sheet title
  ///
  /// In en, this message translates to:
  /// **'New cookbook'**
  String get cookbooksSheetTitle;

  /// Rename cookbook sheet title
  ///
  /// In en, this message translates to:
  /// **'Rename cookbook'**
  String get cookbooksRenameSheetTitle;

  /// Cookbook name field label
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get cookbooksFieldName;

  /// Cookbook name validation message
  ///
  /// In en, this message translates to:
  /// **'Enter a cookbook name'**
  String get cookbooksValidationName;

  /// Cookbook create error snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create cookbook'**
  String get cookbooksCouldNotCreate;

  /// Cookbook rename error snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t rename cookbook'**
  String get cookbooksCouldNotRename;

  /// Cookbook delete error snackbar
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete cookbook'**
  String get cookbooksCouldNotDelete;

  /// Delete cookbook confirm title
  ///
  /// In en, this message translates to:
  /// **'Delete cookbook?'**
  String get cookbooksDeleteTitle;

  /// Delete cookbook confirm body
  ///
  /// In en, this message translates to:
  /// **'This removes the cookbook. Your recipes stay in your kitchen.'**
  String get cookbooksDeleteBody;

  /// Recipe count on a cookbook row
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No recipes} =1{1 recipe} other{{count} recipes}}'**
  String cookbooksRecipeCount(num count);

  /// Rename cookbook menu action
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get cookbooksRename;

  /// Cookbooks no-household description
  ///
  /// In en, this message translates to:
  /// **'Join or create a household to build cookbooks.'**
  String get cookbooksNoHouseholdDesc;

  /// Cookbook detail empty state title
  ///
  /// In en, this message translates to:
  /// **'No recipes here yet'**
  String get cookbookDetailEmptyTitle;

  /// Cookbook detail empty state description
  ///
  /// In en, this message translates to:
  /// **'Add recipes to this cookbook to see them here.'**
  String get cookbookDetailEmptyDesc;

  /// Add recipes to cookbook button
  ///
  /// In en, this message translates to:
  /// **'Add recipes'**
  String get cookbookDetailAddRecipes;

  /// Add recipes to cookbook sheet title
  ///
  /// In en, this message translates to:
  /// **'Add recipes'**
  String get cookbookAddRecipesSheetTitle;

  /// Add recipes sheet empty state
  ///
  /// In en, this message translates to:
  /// **'All your recipes are already in this cookbook.'**
  String get cookbookAddRecipesEmpty;

  /// Remove recipe from cookbook action
  ///
  /// In en, this message translates to:
  /// **'Remove from cookbook'**
  String get cookbookRemoveRecipe;

  /// Snackbar after removing a recipe from a cookbook
  ///
  /// In en, this message translates to:
  /// **'Removed from cookbook'**
  String get cookbookRecipeRemoved;

  /// Snackbar after adding recipes to a cookbook
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 recipe added} other{{count} recipes added}}'**
  String cookbookRecipesAdded(num count);

  /// Shared/private count detail
  ///
  /// In en, this message translates to:
  /// **'{shared} shared · {private} private'**
  String recipeSharedPrivate(num shared, num private);

  /// Cookbook count suffix
  ///
  /// In en, this message translates to:
  /// **' · {count} cookbooks'**
  String recipeCookbooksLabel(num count);

  /// Rating value and count
  ///
  /// In en, this message translates to:
  /// **'{rating} ({count})'**
  String recipeRatingLabel(String rating, num count);

  /// AppBar title for recipe creation
  ///
  /// In en, this message translates to:
  /// **'New recipe'**
  String get recipeCreationTitle;

  /// Wizard step: source
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get recipeCreationStepSource;

  /// Wizard step: details
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get recipeCreationStepDetails;

  /// Wizard step: content
  ///
  /// In en, this message translates to:
  /// **'Content'**
  String get recipeCreationStepContent;

  /// Headline for recipe creation start
  ///
  /// In en, this message translates to:
  /// **'Start your recipe'**
  String get recipeCreationStartHeadline;

  /// Subtitle for recipe creation start
  ///
  /// In en, this message translates to:
  /// **'Import from a link, type it yourself, or scan a photo.'**
  String get recipeCreationStartSubtitle;

  /// Card title: import from URL
  ///
  /// In en, this message translates to:
  /// **'Import from URL'**
  String get recipeCreationImportURL;

  /// Card subtitle: import from URL
  ///
  /// In en, this message translates to:
  /// **'Paste a recipe link and we\'ll pull the details'**
  String get recipeCreationImportURLDesc;

  /// Card title: type recipe manually
  ///
  /// In en, this message translates to:
  /// **'Type it in'**
  String get recipeCreationTypeItIn;

  /// Card subtitle: type manually
  ///
  /// In en, this message translates to:
  /// **'Start with a title and add ingredients later'**
  String get recipeCreationTypeItInDesc;

  /// Card title: scanning in progress
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get recipeCreationScanning;

  /// Card title: scan recipe photo
  ///
  /// In en, this message translates to:
  /// **'Scan a photo'**
  String get recipeCreationScanPhoto;

  /// Card subtitle: scan photo
  ///
  /// In en, this message translates to:
  /// **'Snap a recipe card or cookbook page'**
  String get recipeCreationScanPhotoDesc;

  /// Input label for recipe URL
  ///
  /// In en, this message translates to:
  /// **'Recipe URL'**
  String get recipeCreationURLInput;

  /// Placeholder for recipe URL
  ///
  /// In en, this message translates to:
  /// **'https://example.com/recipe'**
  String get recipeCreationURLHint;

  /// Button text while fetching
  ///
  /// In en, this message translates to:
  /// **'Fetching…'**
  String get recipeCreationFetching;

  /// Button to fetch recipe from URL
  ///
  /// In en, this message translates to:
  /// **'Fetch details'**
  String get recipeCreationFetchDetails;

  /// CTA to pick an image for scanning
  ///
  /// In en, this message translates to:
  /// **'Choose an image'**
  String get recipeCreationChooseImage;

  /// Semantics: select image
  ///
  /// In en, this message translates to:
  /// **'Select image {index}'**
  String recipeCreationSelectImage(num index);

  /// Input label for recipe title
  ///
  /// In en, this message translates to:
  /// **'Recipe title'**
  String get recipeCreationTitleInput;

  /// Placeholder for recipe title
  ///
  /// In en, this message translates to:
  /// **'Sunday pancakes'**
  String get recipeCreationTitleHint;

  /// Dialog title when discarding recipe
  ///
  /// In en, this message translates to:
  /// **'Discard recipe?'**
  String get recipeCreationDiscardTitle;

  /// Dialog body when discarding recipe
  ///
  /// In en, this message translates to:
  /// **'You have unsaved content in this recipe.'**
  String get recipeCreationDiscardBody;

  /// Button to continue editing
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get recipeCreationKeepEditing;

  /// Button to discard recipe
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get recipeCreationDiscard;

  /// Snackbar when recipe scan fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t scan recipe.'**
  String get recipeCreationCouldNotScan;

  /// Snackbar when recipe is imported
  ///
  /// In en, this message translates to:
  /// **'{parts}'**
  String recipeCreationImported(String parts);

  /// Snackbar when URL fetch fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t fetch details from that link.'**
  String get recipeCreationCouldNotFetch;

  /// Snackbar when recipe is created
  ///
  /// In en, this message translates to:
  /// **'Recipe created'**
  String get recipeCreationCreated;

  /// Snackbar when recipe creation fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create recipe.'**
  String get recipeCreationCouldNotCreate;

  /// Fallback recipe title from import
  ///
  /// In en, this message translates to:
  /// **'Imported recipe'**
  String get recipeCreationImportedTitle;

  /// Recipe title derived from URL host
  ///
  /// In en, this message translates to:
  /// **'Recipe from {host}'**
  String recipeCreationFromHost(String host);

  /// Nutrition info displayed as description
  ///
  /// In en, this message translates to:
  /// **'Nutrition: {info}'**
  String recipeCreationNutrition(String info);

  /// Next button: go to details step
  ///
  /// In en, this message translates to:
  /// **'Next: details'**
  String get recipeCreationNextDetails;

  /// Next button: go to content step
  ///
  /// In en, this message translates to:
  /// **'Next: content'**
  String get recipeCreationNextContent;

  /// Input label for overriding recipe title
  ///
  /// In en, this message translates to:
  /// **'Title override'**
  String get recipeCreationTitleOverride;

  /// Input label for recipe notes
  ///
  /// In en, this message translates to:
  /// **'Notes'**
  String get recipeCreationNotesInput;

  /// Placeholder for recipe notes
  ///
  /// In en, this message translates to:
  /// **'What makes this recipe worth saving'**
  String get recipeCreationNotesHint;

  /// Input label for prep time
  ///
  /// In en, this message translates to:
  /// **'Prep (min)'**
  String get recipeCreationPrepLabel;

  /// Placeholder for prep time
  ///
  /// In en, this message translates to:
  /// **'10'**
  String get recipeCreationPrepHint;

  /// Input label for cook time
  ///
  /// In en, this message translates to:
  /// **'Cook (min)'**
  String get recipeCreationCookLabel;

  /// Placeholder for cook time
  ///
  /// In en, this message translates to:
  /// **'20'**
  String get recipeCreationCookHint;

  /// Input label for servings
  ///
  /// In en, this message translates to:
  /// **'Servings'**
  String get recipeCreationServingsLabel;

  /// Placeholder for servings
  ///
  /// In en, this message translates to:
  /// **'4'**
  String get recipeCreationServingsHint;

  /// Input label for tags
  ///
  /// In en, this message translates to:
  /// **'Tags'**
  String get recipeCreationTagsInput;

  /// Placeholder for tags
  ///
  /// In en, this message translates to:
  /// **'quick, vegetarian'**
  String get recipeCreationTagsHint;

  /// Switch label for sharing with household
  ///
  /// In en, this message translates to:
  /// **'Save for household'**
  String get recipeCreationSaveForHousehold;

  /// Switch subtitle when sharing
  ///
  /// In en, this message translates to:
  /// **'Everyone in this household can find and use this recipe.'**
  String get recipeCreationSaveForHouseholdDesc;

  /// Switch subtitle when private
  ///
  /// In en, this message translates to:
  /// **'Keep it private for now. You can share it later.'**
  String get recipeCreationSaveForHouseholdPrivate;

  /// Switch subtitle listing group names when recipe is public
  ///
  /// In en, this message translates to:
  /// **'Shared with {names}'**
  String recipeCreationSharedWithGroups(String names);

  /// Section header for ingredients
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get recipeCreationIngredients;

  /// Helper text for ingredients
  ///
  /// In en, this message translates to:
  /// **'Add one ingredient per row.'**
  String get recipeCreationIngredientsHelper;

  /// Button to add an ingredient
  ///
  /// In en, this message translates to:
  /// **'Add ingredient'**
  String get recipeCreationAddIngredient;

  /// Placeholder for ingredient input
  ///
  /// In en, this message translates to:
  /// **'2 cups flour'**
  String get recipeCreationIngredientHint;

  /// Section header for steps
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get recipeCreationSteps;

  /// Helper text for steps
  ///
  /// In en, this message translates to:
  /// **'Keep each step short enough to follow while cooking.'**
  String get recipeCreationStepsHelper;

  /// Button to add a step
  ///
  /// In en, this message translates to:
  /// **'Add step'**
  String get recipeCreationAddStep;

  /// Placeholder for step input
  ///
  /// In en, this message translates to:
  /// **'Mix batter'**
  String get recipeCreationStepHint;

  /// Input label for nutrition info
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get recipeCreationNutritionInput;

  /// Placeholder for nutrition info
  ///
  /// In en, this message translates to:
  /// **'520 kcal, 24g protein, high fiber'**
  String get recipeCreationNutritionHint;

  /// Button text while creating recipe
  ///
  /// In en, this message translates to:
  /// **'Creating…'**
  String get recipeCreationCreating;

  /// Submit button for recipe creation
  ///
  /// In en, this message translates to:
  /// **'Create recipe'**
  String get recipeCreationCreateRecipe;

  /// Step/ingredient label
  ///
  /// In en, this message translates to:
  /// **'{type}'**
  String recipeCreationStepLabel(String type);

  /// Tooltip for removing a step/ingredient
  ///
  /// In en, this message translates to:
  /// **'Remove {type} {index}'**
  String recipeCreationRemoveItem(String type, num index);

  /// Semantics label for step item
  ///
  /// In en, this message translates to:
  /// **'Step {index} of {total}, {label}, {status}'**
  String recipeCreationStepSemantics(
      num index, num total, String label, String status);

  /// AppBar title for recipe detail
  ///
  /// In en, this message translates to:
  /// **'Recipe'**
  String get recipeDetailTitle;

  /// Tooltip for delete recipe button
  ///
  /// In en, this message translates to:
  /// **'Delete recipe'**
  String get recipeDetailDeleteTooltip;

  /// Button to add ingredients to shopping list
  ///
  /// In en, this message translates to:
  /// **'Add to list'**
  String get recipeDetailAddToList;

  /// Detail row: cook time
  ///
  /// In en, this message translates to:
  /// **'Cook'**
  String get recipeDetailCook;

  /// Empty state when recipe fails to load
  ///
  /// In en, this message translates to:
  /// **'Could not load recipe'**
  String get recipeDetailCouldNotLoad;

  /// Dialog title for deleting recipe
  ///
  /// In en, this message translates to:
  /// **'Delete recipe'**
  String get recipeDetailDeleteTitle;

  /// Dialog body for recipe deletion
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete this recipe. This cannot be undone.'**
  String get recipeDetailDeleteBody;

  /// Chip label for shared recipe
  ///
  /// In en, this message translates to:
  /// **'Shared'**
  String get recipeDetailSharedLabel;

  /// Chip label for private recipe
  ///
  /// In en, this message translates to:
  /// **'Private'**
  String get recipeDetailPrivateLabel;

  /// Author attribution
  ///
  /// In en, this message translates to:
  /// **'By {author}'**
  String recipeDetailBy(String author);

  /// Detail row: prep time
  ///
  /// In en, this message translates to:
  /// **'Prep'**
  String get recipeDetailPrep;

  /// Detail row: servings
  ///
  /// In en, this message translates to:
  /// **'Servings'**
  String get recipeDetailServings;

  /// Detail row: last updated
  ///
  /// In en, this message translates to:
  /// **'Updated'**
  String get recipeDetailUpdated;

  /// Fallback when a detail is not set
  ///
  /// In en, this message translates to:
  /// **'Not set'**
  String get recipeDetailNotSet;

  /// Section header: nutrition
  ///
  /// In en, this message translates to:
  /// **'Nutrition'**
  String get recipeDetailNutrition;

  /// Section header: equipment
  ///
  /// In en, this message translates to:
  /// **'Equipment'**
  String get recipeDetailEquipment;

  /// Section header: ingredients
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get recipeDetailIngredients;

  /// Section header: steps
  ///
  /// In en, this message translates to:
  /// **'Steps'**
  String get recipeDetailSteps;

  /// Link label to watch recipe video
  ///
  /// In en, this message translates to:
  /// **'Watch video'**
  String get recipeDetailWatchVideo;

  /// Semantics label for video link
  ///
  /// In en, this message translates to:
  /// **'Watch recipe video'**
  String get recipeDetailWatchVideoSemantics;

  /// Link label to original source
  ///
  /// In en, this message translates to:
  /// **'View original recipe'**
  String get recipeDetailViewOriginal;

  /// Semantics label for original link
  ///
  /// In en, this message translates to:
  /// **'View original recipe in browser'**
  String get recipeDetailViewOriginalSemantics;

  /// Empty state when recipe fails in cook mode
  ///
  /// In en, this message translates to:
  /// **'Could not load recipe'**
  String get cookModeCouldNotLoad;

  /// Icon button tooltip to exit cook mode
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get cookModeClose;

  /// Servings label in cook mode
  ///
  /// In en, this message translates to:
  /// **'Servings'**
  String get cookModeServings;

  /// Semantics: decrease servings
  ///
  /// In en, this message translates to:
  /// **'Decrease servings'**
  String get cookModeDecreaseServings;

  /// Semantics: increase servings
  ///
  /// In en, this message translates to:
  /// **'Increase servings'**
  String get cookModeIncreaseServings;

  /// Button to begin cooking
  ///
  /// In en, this message translates to:
  /// **'Start cooking'**
  String get cookModeStartCooking;

  /// Semantics: ingredient gathered
  ///
  /// In en, this message translates to:
  /// **'gathered'**
  String get cookModeGathered;

  /// Semantics: ingredient not gathered
  ///
  /// In en, this message translates to:
  /// **'not gathered'**
  String get cookModeNotGathered;

  /// Glance bar current step
  ///
  /// In en, this message translates to:
  /// **'Step {step} of {total}'**
  String cookModeStepOf(num step, num total);

  /// Tooltip to exit cook mode
  ///
  /// In en, this message translates to:
  /// **'Exit cook mode'**
  String get cookModeExitTooltip;

  /// Snackbar when a timer finishes
  ///
  /// In en, this message translates to:
  /// **'Timer done!'**
  String get cookModeTimerDone;

  /// Button to advance to next step
  ///
  /// In en, this message translates to:
  /// **'Done →'**
  String get cookModeDoneArrow;

  /// Finish button on last step
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get cookModeFinish;

  /// Step number label
  ///
  /// In en, this message translates to:
  /// **'Step {number}'**
  String cookModeStepLabel(num number);

  /// Semantics: completed step
  ///
  /// In en, this message translates to:
  /// **'Step {number} done. Tap to revisit'**
  String cookModeStepDone(num number);

  /// Semantics: current step
  ///
  /// In en, this message translates to:
  /// **'Current step {number}'**
  String cookModeCurrentStep(num number);

  /// Semantics: jump to step
  ///
  /// In en, this message translates to:
  /// **'Step {number}: {description}. Tap to jump to this step'**
  String cookModeStepJump(num number, String description);

  /// Button to return to current step
  ///
  /// In en, this message translates to:
  /// **'Back to step {step}'**
  String cookModeBackToStep(num step);

  /// Semantics: show ingredients sheet
  ///
  /// In en, this message translates to:
  /// **'Show ingredients'**
  String get cookModeShowIngredients;

  /// Ingredients bottom sheet title
  ///
  /// In en, this message translates to:
  /// **'Ingredients'**
  String get cookModeIngredients;

  /// Text shown when all steps complete
  ///
  /// In en, this message translates to:
  /// **'Finished — nice work'**
  String get cookModeFinished;

  /// Semantics: finish cooking
  ///
  /// In en, this message translates to:
  /// **'Finish cooking'**
  String get cookModeFinishCooking;

  /// Semantics: advance to next step
  ///
  /// In en, this message translates to:
  /// **'Done, advance to next step'**
  String get cookModeAdvanceStep;

  /// AppBar title for expenses screen
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get expenseAppBarTitle;

  /// Tooltip for scan receipt action
  ///
  /// In en, this message translates to:
  /// **'Scan receipt'**
  String get expenseScanReceiptTooltip;

  /// Tooltip for recurring expenses
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get expenseRecurringTooltip;

  /// FAB text and tooltip to add expense
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get expenseAddExpense;

  /// Balance headline when user is owed money
  ///
  /// In en, this message translates to:
  /// **'You are owed'**
  String get expenseYouAreOwed;

  /// Balance headline when user owes money
  ///
  /// In en, this message translates to:
  /// **'You owe'**
  String get expenseYouOwe;

  /// Balance headline when net zero
  ///
  /// In en, this message translates to:
  /// **'All square'**
  String get expenseAllSquare;

  /// Balance description with suggestion count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} suggested payment} other{{count} suggested payments}} to settle up'**
  String expenseSuggestedPayments(num count);

  /// Balance description with open balance count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} open balance} other{{count} open balances}} in the household'**
  String expenseOpenBalances(num count);

  /// Balance description when all settled
  ///
  /// In en, this message translates to:
  /// **'No one needs to pay anyone right now'**
  String get expenseNoOneOwes;

  /// Tab label for expense timeline
  ///
  /// In en, this message translates to:
  /// **'Timeline'**
  String get expenseTabTimeline;

  /// Tab label for settlements
  ///
  /// In en, this message translates to:
  /// **'Settlements'**
  String get expenseTabSettlements;

  /// Today date section label
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get expenseToday;

  /// Yesterday date section label
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get expenseYesterday;

  /// Empty state when no expenses exist
  ///
  /// In en, this message translates to:
  /// **'No expenses yet'**
  String get expenseNoExpensesTitle;

  /// Description for no expenses empty state
  ///
  /// In en, this message translates to:
  /// **'Track shared costs with your household.'**
  String get expenseNoExpensesDesc;

  /// CTA to add the first expense
  ///
  /// In en, this message translates to:
  /// **'Add first expense'**
  String get expenseAddFirstExpense;

  /// Error when expenses fail to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load expenses. Check your connection.'**
  String get expenseLoadError;

  /// Error when expense pagination fails
  ///
  /// In en, this message translates to:
  /// **'Failed to load more expenses.'**
  String get expenseLoadMoreError;

  /// Card subtitle showing who paid
  ///
  /// In en, this message translates to:
  /// **'Paid by {payer}'**
  String expensePaidBy(String payer);

  /// Converted currency amount display
  ///
  /// In en, this message translates to:
  /// **'≈ {amount}'**
  String expenseConvertedAmount(String amount);

  /// Dialog title for deleting expense
  ///
  /// In en, this message translates to:
  /// **'Delete expense'**
  String get expenseDeleteTitle;

  /// Dialog body for expense deletion
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete this expense and all associated receipts. This cannot be undone.'**
  String get expenseDeleteBody;

  /// Snackbar when settlement is saved and pending counterparty approval
  ///
  /// In en, this message translates to:
  /// **'Settlement recorded — awaiting confirmation'**
  String get expenseSettlementRecorded;

  /// Snackbar when settlement fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t record settlement.'**
  String get expenseSettlementFailed;

  /// Section title for settlements awaiting the current user's response
  ///
  /// In en, this message translates to:
  /// **'Needs your confirmation'**
  String get expenseSettlementNeedsYou;

  /// Section title for the user's own pending settlements
  ///
  /// In en, this message translates to:
  /// **'Waiting for confirmation'**
  String get expenseSettlementWaiting;

  /// Section title for resolved settlements
  ///
  /// In en, this message translates to:
  /// **'Recent settlements'**
  String get expenseSettlementHistory;

  /// Settlement row label
  ///
  /// In en, this message translates to:
  /// **'{from} paid {to}'**
  String expenseSettlementRow(String from, String to);

  /// Button to confirm a settlement
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get expenseSettlementConfirmAction;

  /// Button to decline a settlement
  ///
  /// In en, this message translates to:
  /// **'Decline'**
  String get expenseSettlementDeclineAction;

  /// Button to cancel own pending settlement
  ///
  /// In en, this message translates to:
  /// **'Cancel request'**
  String get expenseSettlementCancelAction;

  /// Status label: confirmed settlement
  ///
  /// In en, this message translates to:
  /// **'Confirmed'**
  String get expenseSettlementStatusConfirmed;

  /// Status label: declined settlement
  ///
  /// In en, this message translates to:
  /// **'Declined'**
  String get expenseSettlementStatusDeclined;

  /// Snackbar when confirm/decline fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update the settlement.'**
  String get expenseSettlementResponseFailed;

  /// Snackbar when cancelling a settlement fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t cancel the settlement.'**
  String get expenseSettlementCancelFailed;

  /// Section title for suggested settlements
  ///
  /// In en, this message translates to:
  /// **'Suggested payments'**
  String get expenseSuggestedPaymentsTitle;

  /// Description of how suggestions are computed
  ///
  /// In en, this message translates to:
  /// **'Calculated from every expense, split, and recorded settlement in this household.'**
  String get expenseSuggestedPaymentsDesc;

  /// Empty state when no settlements needed
  ///
  /// In en, this message translates to:
  /// **'All settled up!'**
  String get expenseAllSettled;

  /// Description when all settled
  ///
  /// In en, this message translates to:
  /// **'No one owes anyone right now.'**
  String get expenseNoOneOwesRight;

  /// Label when payment is within same account
  ///
  /// In en, this message translates to:
  /// **'Same account'**
  String get expenseSameAccount;

  /// Party label: sender
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get expenseFrom;

  /// Party label: receiver
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get expenseTo;

  /// Helper text for recording settlement
  ///
  /// In en, this message translates to:
  /// **'Record this settlement after the payment is made.'**
  String get expenseRecordHelper;

  /// Button text while recording settlement
  ///
  /// In en, this message translates to:
  /// **'Recording...'**
  String get expenseRecording;

  /// Button to confirm settlement
  ///
  /// In en, this message translates to:
  /// **'Record settlement'**
  String get expenseRecordSettlement;

  /// Section header for balance list
  ///
  /// In en, this message translates to:
  /// **'Balances'**
  String get expenseBalances;

  /// Open balance count label
  ///
  /// In en, this message translates to:
  /// **'{count} open'**
  String expenseBalancesOpen(num count);

  /// Semantics: expand balances
  ///
  /// In en, this message translates to:
  /// **'Expand balances'**
  String get expenseExpandBalances;

  /// Semantics: collapse balances
  ///
  /// In en, this message translates to:
  /// **'Collapse balances'**
  String get expenseCollapseBalances;

  /// Empty state when no balances exist
  ///
  /// In en, this message translates to:
  /// **'No balances yet. Add an expense with splits to start the ledger.'**
  String get expenseNoBalances;

  /// Balance status: person is owed
  ///
  /// In en, this message translates to:
  /// **'is owed'**
  String get expenseIsOwed;

  /// Balance status: person owes
  ///
  /// In en, this message translates to:
  /// **'owes'**
  String get expenseOwes;

  /// Balance status: settled
  ///
  /// In en, this message translates to:
  /// **'settled'**
  String get expenseSettled;

  /// AppBar title for recurring expenses
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get recurringAppBarTitle;

  /// Button to add recurring expense
  ///
  /// In en, this message translates to:
  /// **'Add recurring'**
  String get recurringAddRecurring;

  /// Tooltip for add recurring button
  ///
  /// In en, this message translates to:
  /// **'Add recurring expense'**
  String get recurringAddRecurringTooltip;

  /// Empty state when no recurring expenses
  ///
  /// In en, this message translates to:
  /// **'No recurring expenses'**
  String get recurringNoRecurringTitle;

  /// Description for no recurring expenses
  ///
  /// In en, this message translates to:
  /// **'Add a recurring expense to track regular payments'**
  String get recurringNoRecurringDesc;

  /// CTA to add first recurring expense
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get recurringAddExpense;

  /// Tooltip to pause a recurring expense
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get recurringPauseTooltip;

  /// Tooltip to resume a recurring expense
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get recurringResumeTooltip;

  /// Tooltip to delete a recurring expense
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get recurringDeleteTooltip;

  /// Label showing next due date
  ///
  /// In en, this message translates to:
  /// **'Next: {date}'**
  String recurringNextDate(String date);

  /// Dialog title for deleting recurring expense
  ///
  /// In en, this message translates to:
  /// **'Delete recurring expense'**
  String get recurringDeleteTitle;

  /// Dialog body for deleting recurring expense
  ///
  /// In en, this message translates to:
  /// **'This will stop future expenses from being created.'**
  String get recurringDeleteBody;

  /// Daily frequency format
  ///
  /// In en, this message translates to:
  /// **'Daily'**
  String get recurringFrequencyDaily;

  /// Weekly frequency format
  ///
  /// In en, this message translates to:
  /// **'Weekly'**
  String get recurringFrequencyWeekly;

  /// Biweekly frequency format
  ///
  /// In en, this message translates to:
  /// **'Every 2 weeks'**
  String get recurringFrequencyBiweekly;

  /// Monthly frequency format
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get recurringFrequencyMonthly;

  /// Quarterly frequency format
  ///
  /// In en, this message translates to:
  /// **'Quarterly'**
  String get recurringFrequencyQuarterly;

  /// Yearly frequency format
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get recurringFrequencyYearly;

  /// Sheet title for creating recurring expense
  ///
  /// In en, this message translates to:
  /// **'Add recurring expense'**
  String get recurringSheetTitle;

  /// Input label for description
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get recurringSheetDescription;

  /// Input label for amount
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get recurringSheetAmount;

  /// Dropdown label for frequency
  ///
  /// In en, this message translates to:
  /// **'Frequency'**
  String get recurringSheetFrequency;

  /// Dropdown label for payer
  ///
  /// In en, this message translates to:
  /// **'Payer'**
  String get recurringSheetPayer;

  /// Validation: description required
  ///
  /// In en, this message translates to:
  /// **'Enter a description.'**
  String get recurringValidationDesc;

  /// Validation: amount required
  ///
  /// In en, this message translates to:
  /// **'Enter an amount.'**
  String get recurringValidationAmount;

  /// Validation: payer required
  ///
  /// In en, this message translates to:
  /// **'Select a payer.'**
  String get recurringValidationPayer;

  /// Validation: amount must be positive
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount greater than zero.'**
  String get recurringValidationAmountPositive;

  /// No-household description for recurring
  ///
  /// In en, this message translates to:
  /// **'Join or create a household to manage recurring expenses'**
  String get recurringNoHouseholdDesc;

  /// AppBar title for lists screen
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get listAppBarTitle;

  /// Tooltip for shopping trip navigation
  ///
  /// In en, this message translates to:
  /// **'Shopping trip'**
  String get listShoppingTripTooltip;

  /// TextField label for list search
  ///
  /// In en, this message translates to:
  /// **'Search lists'**
  String get listSearchLabel;

  /// TextField hint for list search
  ///
  /// In en, this message translates to:
  /// **'Name, e.g. groceries'**
  String get listSearchHint;

  /// Menu item to scan a list
  ///
  /// In en, this message translates to:
  /// **'Scan receipt or list'**
  String get listScanTooltip;

  /// Disabled menu item for sort
  ///
  /// In en, this message translates to:
  /// **'Sort'**
  String get listSortLabel;

  /// Sort by newest
  ///
  /// In en, this message translates to:
  /// **'Newest'**
  String get listSortNewest;

  /// Sort by oldest
  ///
  /// In en, this message translates to:
  /// **'Oldest'**
  String get listSortOldest;

  /// Sort alphabetically
  ///
  /// In en, this message translates to:
  /// **'A–Z'**
  String get listSortAZ;

  /// Sort by item count
  ///
  /// In en, this message translates to:
  /// **'Most items'**
  String get listSortMostItems;

  /// Toggle grid view
  ///
  /// In en, this message translates to:
  /// **'Grid view'**
  String get listSortGridView;

  /// FAB text and tooltip to create list
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get listNewList;

  /// Filter chip: all lists
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get listFilterAll;

  /// Filter chip: shopping lists
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get listFilterShopping;

  /// Filter chip: to-do lists
  ///
  /// In en, this message translates to:
  /// **'To-do'**
  String get listFilterTodo;

  /// Filter chip: custom lists
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get listFilterCustom;

  /// Empty state for shopping filter
  ///
  /// In en, this message translates to:
  /// **'No shopping lists'**
  String get listEmptyShopping;

  /// Empty state for to-do filter
  ///
  /// In en, this message translates to:
  /// **'No to-do lists'**
  String get listEmptyTodo;

  /// Empty state for custom filter
  ///
  /// In en, this message translates to:
  /// **'No custom lists'**
  String get listEmptyCustom;

  /// Empty state when no lists exist
  ///
  /// In en, this message translates to:
  /// **'No lists yet'**
  String get listEmptyAll;

  /// Description for shopping empty state
  ///
  /// In en, this message translates to:
  /// **'Great for groceries, meal prep, weekend errands.'**
  String get listEmptyShoppingDesc;

  /// Description for to-do empty state
  ///
  /// In en, this message translates to:
  /// **'Tasks, chores, anything with a checkbox.'**
  String get listEmptyTodoDesc;

  /// Description for custom empty state
  ///
  /// In en, this message translates to:
  /// **'Free-form — your list, your rules.'**
  String get listEmptyCustomDesc;

  /// Description for general empty state
  ///
  /// In en, this message translates to:
  /// **'Add lines inside a list; the first few appear as a snippet on its card.'**
  String get listEmptyAllDesc;

  /// CTA to create first shopping list
  ///
  /// In en, this message translates to:
  /// **'Create a shopping list'**
  String get listCreateShopping;

  /// CTA to create first to-do list
  ///
  /// In en, this message translates to:
  /// **'Create a to-do list'**
  String get listCreateTodo;

  /// CTA to create first custom list
  ///
  /// In en, this message translates to:
  /// **'Create a custom list'**
  String get listCreateCustom;

  /// CTA to create first list (all filter)
  ///
  /// In en, this message translates to:
  /// **'Create your first list'**
  String get listCreateFirst;

  /// Search empty result
  ///
  /// In en, this message translates to:
  /// **'No lists match \"{query}\"'**
  String listNoMatch(String query);

  /// Description for search no-results
  ///
  /// In en, this message translates to:
  /// **'Names and list items are searched.'**
  String get listSearchDesc;

  /// Dialog title for renaming a list
  ///
  /// In en, this message translates to:
  /// **'Rename list'**
  String get listRenameTitle;

  /// Snackbar when rename fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t rename list.'**
  String get listCouldNotRename;

  /// Dialog title for deleting a list
  ///
  /// In en, this message translates to:
  /// **'Delete list'**
  String get listDeleteTitle;

  /// Dialog body for list deletion
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete this list and all its items.'**
  String get listDeleteBody;

  /// Snackbar when delete fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete list.'**
  String get listCouldNotDelete;

  /// Dialog title for adding item
  ///
  /// In en, this message translates to:
  /// **'Add item to {name}'**
  String listAddItemTo(String name);

  /// Input label for item name
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get listItemName;

  /// Snackbar when adding item fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add item.'**
  String get listCouldNotAddItem;

  /// Tooltip for quick-add button
  ///
  /// In en, this message translates to:
  /// **'Quick add item'**
  String get listQuickAddItemTooltip;

  /// Semantics for quick-add
  ///
  /// In en, this message translates to:
  /// **'Quick add item to {name}'**
  String listQuickAddItemSemantics(String name);

  /// Tooltip for list options menu
  ///
  /// In en, this message translates to:
  /// **'List options'**
  String get listOptionsTooltip;

  /// Label showing which household a list is shared with
  ///
  /// In en, this message translates to:
  /// **'Shared with {name}'**
  String listSharedWith(String name);

  /// Semantics for editing list name
  ///
  /// In en, this message translates to:
  /// **'Edit list name, {name}'**
  String listDetailEditName(String name);

  /// Tooltip to close search
  ///
  /// In en, this message translates to:
  /// **'Close search'**
  String get listDetailCloseSearch;

  /// Tooltip to open search
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get listDetailSearchTooltip;

  /// TextField label for filtering items
  ///
  /// In en, this message translates to:
  /// **'Filter items'**
  String get listDetailFilterLabel;

  /// TextField hint for filtering items
  ///
  /// In en, this message translates to:
  /// **'Name, e.g. milk'**
  String get listDetailFilterHint;

  /// Panel shown when all items are checked
  ///
  /// In en, this message translates to:
  /// **'All checked off'**
  String get listDetailAllCheckedOff;

  /// Button to clear checked items
  ///
  /// In en, this message translates to:
  /// **'Clear checked'**
  String get listDetailClearChecked;

  /// Section header for completed items
  ///
  /// In en, this message translates to:
  /// **'Checked off'**
  String get listDetailCheckedOff;

  /// Empty state when list has no items
  ///
  /// In en, this message translates to:
  /// **'Nothing here yet'**
  String get listDetailNothingHere;

  /// Description for empty list
  ///
  /// In en, this message translates to:
  /// **'Photograph a handwritten list, fridge note, or screenshot. We\'ll pull out the items.'**
  String get listDetailNothingHereDesc;

  /// CTA to scan list content
  ///
  /// In en, this message translates to:
  /// **'Scan this list'**
  String get listDetailScanThisList;

  /// CTA to type an item manually
  ///
  /// In en, this message translates to:
  /// **'Type an item'**
  String get listDetailTypeItem;

  /// Search empty result for items
  ///
  /// In en, this message translates to:
  /// **'No items match your filter'**
  String get listDetailNoMatch;

  /// Error when list fails to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load list.'**
  String get listDetailCouldNotLoad;

  /// Snackbar when update fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update. Please try again.'**
  String get listDetailCouldNotUpdate;

  /// Snackbar when adding item fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add item. Please try again.'**
  String get listDetailCouldNotAddItem;

  /// Snackbar when clearing items fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t clear items. Please try again.'**
  String get listDetailCouldNotClear;

  /// Snackbar when item is deleted
  ///
  /// In en, this message translates to:
  /// **'{name} deleted'**
  String listDetailItemDeleted(String name);

  /// Snackbar when restore fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t restore item.'**
  String get listDetailCouldNotRestore;

  /// Snackbar when reorder fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t reorder items. Please try again.'**
  String get listDetailCouldNotReorder;

  /// Snackbar when items are scanned
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item added to list} other{{count} items added to list}}'**
  String listDetailItemsAdded(num count);

  /// Snackbar when scan fails to start
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t start scan. Try again.'**
  String get listDetailCouldNotStartScan;

  /// Dialog title for setting item price
  ///
  /// In en, this message translates to:
  /// **'Set price'**
  String get listDetailSetPrice;

  /// Input label for price
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get listDetailPriceInput;

  /// Placeholder for price input
  ///
  /// In en, this message translates to:
  /// **'0.00'**
  String get listDetailPriceHint;

  /// Snackbar when price set fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t set price.'**
  String get listDetailCouldNotSetPrice;

  /// Dialog title for clearing list
  ///
  /// In en, this message translates to:
  /// **'Clear list'**
  String get listDetailClearTitle;

  /// Dialog body for clearing list
  ///
  /// In en, this message translates to:
  /// **'This will remove all {count} {count, plural, =1{item} other{items}}. This cannot be undone.'**
  String listDetailClearBody(num count);

  /// Confirmation button to clear list
  ///
  /// In en, this message translates to:
  /// **'Clear list'**
  String get listDetailClearConfirm;

  /// Dialog title for archiving list
  ///
  /// In en, this message translates to:
  /// **'Archive list'**
  String get listDetailArchiveTitle;

  /// Dialog body for archiving list
  ///
  /// In en, this message translates to:
  /// **'This list will be hidden from your household.'**
  String get listDetailArchiveBody;

  /// Snackbar when archive fails
  ///
  /// In en, this message translates to:
  /// **'Failed to archive list.'**
  String get listDetailFailedArchive;

  /// Dialog title for deleting list
  ///
  /// In en, this message translates to:
  /// **'Delete list'**
  String get listDetailDeleteTitle;

  /// Dialog body for deleting list
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete this list and all its items. This cannot be undone.'**
  String get listDetailDeleteBody;

  /// Snackbar when delete fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete list.'**
  String get listDetailCouldNotDelete;

  /// Snackbar when expense is created from list
  ///
  /// In en, this message translates to:
  /// **'Expense generated'**
  String get listDetailExpenseGenerated;

  /// Snackbar when cost summary fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load cost summary.'**
  String get listDetailCouldNotLoadCostSummary;

  /// Snackbar when photo add fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add photo.'**
  String get listDetailCouldNotAddPhoto;

  /// Snackbar when photo remove fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove photo.'**
  String get listDetailCouldNotRemovePhoto;

  /// Semantics label for list image
  ///
  /// In en, this message translates to:
  /// **'List image'**
  String get listDetailListImage;

  /// Menu item to check all items
  ///
  /// In en, this message translates to:
  /// **'Check all'**
  String get listDetailCheckAll;

  /// Menu item to uncheck all items
  ///
  /// In en, this message translates to:
  /// **'Uncheck all'**
  String get listDetailUncheckAll;

  /// Menu item for cost summary
  ///
  /// In en, this message translates to:
  /// **'Cost summary'**
  String get listDetailCostSummary;

  /// Tooltip to scan list
  ///
  /// In en, this message translates to:
  /// **'Scan list'**
  String get listDetailScanList;

  /// AppBar title for calendar screen
  ///
  /// In en, this message translates to:
  /// **'Calendar'**
  String get calendarAppBarTitle;

  /// Toggle label for week view
  ///
  /// In en, this message translates to:
  /// **'Week'**
  String get calendarViewWeek;

  /// Toggle label for month view
  ///
  /// In en, this message translates to:
  /// **'Month'**
  String get calendarViewMonth;

  /// Toggle label for agenda view
  ///
  /// In en, this message translates to:
  /// **'Agenda'**
  String get calendarViewAgenda;

  /// Semantics: week view
  ///
  /// In en, this message translates to:
  /// **'Week view'**
  String get calendarWeekView;

  /// Semantics: month view
  ///
  /// In en, this message translates to:
  /// **'Month view'**
  String get calendarMonthView;

  /// Semantics: agenda view
  ///
  /// In en, this message translates to:
  /// **'Agenda view'**
  String get calendarAgendaView;

  /// Tooltip for previous week
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get calendarPreviousWeek;

  /// Tooltip for next week
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get calendarNextWeek;

  /// Tooltip for previous month
  ///
  /// In en, this message translates to:
  /// **'Previous month'**
  String get calendarPreviousMonth;

  /// Tooltip for next month
  ///
  /// In en, this message translates to:
  /// **'Next month'**
  String get calendarNextMonth;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'January'**
  String get calendarMonthJanuary;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'February'**
  String get calendarMonthFebruary;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'March'**
  String get calendarMonthMarch;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'April'**
  String get calendarMonthApril;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'May'**
  String get calendarMonthMay;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'June'**
  String get calendarMonthJune;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'July'**
  String get calendarMonthJuly;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'August'**
  String get calendarMonthAugust;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'September'**
  String get calendarMonthSeptember;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'October'**
  String get calendarMonthOctober;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'November'**
  String get calendarMonthNovember;

  /// Month name
  ///
  /// In en, this message translates to:
  /// **'December'**
  String get calendarMonthDecember;

  /// Monday header
  ///
  /// In en, this message translates to:
  /// **'Mon'**
  String get calendarShortMon;

  /// Tuesday header
  ///
  /// In en, this message translates to:
  /// **'Tue'**
  String get calendarShortTue;

  /// Wednesday header
  ///
  /// In en, this message translates to:
  /// **'Wed'**
  String get calendarShortWed;

  /// Thursday header
  ///
  /// In en, this message translates to:
  /// **'Thu'**
  String get calendarShortThu;

  /// Friday header
  ///
  /// In en, this message translates to:
  /// **'Fri'**
  String get calendarShortFri;

  /// Saturday header
  ///
  /// In en, this message translates to:
  /// **'Sat'**
  String get calendarShortSat;

  /// Sunday header
  ///
  /// In en, this message translates to:
  /// **'Sun'**
  String get calendarShortSun;

  /// Full weekday name
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get calendarWeekdayMonday;

  /// Full weekday name
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get calendarWeekdayTuesday;

  /// Full weekday name
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get calendarWeekdayWednesday;

  /// Full weekday name
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get calendarWeekdayThursday;

  /// Full weekday name
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get calendarWeekdayFriday;

  /// Full weekday name
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get calendarWeekdaySaturday;

  /// Full weekday name
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get calendarWeekdaySunday;

  /// Today label
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get calendarToday;

  /// Semantics: specific day
  ///
  /// In en, this message translates to:
  /// **'Day {day}'**
  String calendarDayLabel(num day);

  /// Semantics: event count for a day
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 event} other{{count} events}}'**
  String calendarDayEvents(num count);

  /// Semantics hint: long-press opens the day options menu
  ///
  /// In en, this message translates to:
  /// **'Opens day options'**
  String get calendarDayMenuHint;

  /// Empty day text
  ///
  /// In en, this message translates to:
  /// **'Nothing planned'**
  String get calendarNothingPlanned;

  /// Empty state when no events ahead
  ///
  /// In en, this message translates to:
  /// **'Nothing ahead'**
  String get calendarNothingAhead;

  /// Description when no events ahead
  ///
  /// In en, this message translates to:
  /// **'Upcoming chores, meal plans, and recurring expenses will appear here.'**
  String get calendarNothingAheadDesc;

  /// Menu item to add chore from calendar
  ///
  /// In en, this message translates to:
  /// **'Add chore'**
  String get calendarAddChore;

  /// Menu item to add expense from calendar
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get calendarAddExpense;

  /// Menu item to navigate to week view
  ///
  /// In en, this message translates to:
  /// **'View in week'**
  String get calendarViewInWeek;

  /// Default event label: meal
  ///
  /// In en, this message translates to:
  /// **'Meal'**
  String get calendarEventMeal;

  /// Default event label: chore
  ///
  /// In en, this message translates to:
  /// **'Chore'**
  String get calendarEventChore;

  /// Default event label: recurring
  ///
  /// In en, this message translates to:
  /// **'Recurring'**
  String get calendarEventRecurring;

  /// Default event label: expense
  ///
  /// In en, this message translates to:
  /// **'Expense'**
  String get calendarEventExpense;

  /// Default event label: reminder
  ///
  /// In en, this message translates to:
  /// **'Reminder'**
  String get calendarEventReminder;

  /// Meal servings in calendar
  ///
  /// In en, this message translates to:
  /// **'{servings} ppl '**
  String calendarServingsPpl(num servings);

  /// No-household description for calendar
  ///
  /// In en, this message translates to:
  /// **'Join or create a household to view the calendar'**
  String get calendarNoHouseholdDesc;

  /// CTA to create household
  ///
  /// In en, this message translates to:
  /// **'Create household'**
  String get calendarCreateHousehold;

  /// Week range header
  ///
  /// In en, this message translates to:
  /// **'{weekStart} – {weekEnd}'**
  String calendarWeekHeader(String weekStart, String weekEnd);

  /// Month header label
  ///
  /// In en, this message translates to:
  /// **'{month} {year}'**
  String calendarMonthHeader(String month, num year);

  /// AppBar title for meal plan screen
  ///
  /// In en, this message translates to:
  /// **'Meal Plan'**
  String get mealPlanAppBarTitle;

  /// Tooltip for generating shopping list
  ///
  /// In en, this message translates to:
  /// **'Generate shopping list'**
  String get mealPlanGenerateShoppingList;

  /// Tooltip for previous week
  ///
  /// In en, this message translates to:
  /// **'Previous week'**
  String get mealPlanPreviousWeek;

  /// Tooltip for next week
  ///
  /// In en, this message translates to:
  /// **'Next week'**
  String get mealPlanNextWeek;

  /// Meal slot: breakfast
  ///
  /// In en, this message translates to:
  /// **'Breakfast'**
  String get mealPlanBreakfast;

  /// Meal slot: lunch
  ///
  /// In en, this message translates to:
  /// **'Lunch'**
  String get mealPlanLunch;

  /// Meal slot: dinner
  ///
  /// In en, this message translates to:
  /// **'Dinner'**
  String get mealPlanDinner;

  /// CTA for empty meal slot
  ///
  /// In en, this message translates to:
  /// **'Add meal'**
  String get mealPlanAddMeal;

  /// Fallback title when recipe name missing
  ///
  /// In en, this message translates to:
  /// **'Recipe'**
  String get mealPlanRecipeFallback;

  /// Compact servings display
  ///
  /// In en, this message translates to:
  /// **'{servings}p'**
  String mealPlanServings(num servings);

  /// Snackbar when shopping list is created
  ///
  /// In en, this message translates to:
  /// **'Shopping list created with {count} items'**
  String mealPlanShoppingListCreated(num count);

  /// Snackbar action to navigate to money
  ///
  /// In en, this message translates to:
  /// **'Track costs'**
  String get mealPlanTrackCosts;

  /// Snackbar when adding meal fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add meal.'**
  String get mealPlanCouldNotAdd;

  /// Snackbar when removing meal fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove meal.'**
  String get mealPlanCouldNotRemove;

  /// Snackbar when updating meal fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update meal.'**
  String get mealPlanCouldNotUpdate;

  /// Bottom sheet title for recipe picker
  ///
  /// In en, this message translates to:
  /// **'Pick a recipe'**
  String get mealPlanPickRecipe;

  /// Error when recipes fail to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load recipes'**
  String get mealPlanCouldNotLoadRecipes;

  /// Empty state when no recipes exist
  ///
  /// In en, this message translates to:
  /// **'No recipes yet'**
  String get mealPlanNoRecipes;

  /// Description when no recipes
  ///
  /// In en, this message translates to:
  /// **'Add recipes to plan meals'**
  String get mealPlanAddRecipesDesc;

  /// Search field hint in recipe picker
  ///
  /// In en, this message translates to:
  /// **'Search recipes...'**
  String get mealPlanSearchRecipes;

  /// No search results in recipe picker
  ///
  /// In en, this message translates to:
  /// **'No recipes match \"{query}\"'**
  String mealPlanNoMatch(String query);

  /// Bottom sheet title for servings adjustment
  ///
  /// In en, this message translates to:
  /// **'Servings'**
  String get mealPlanServingsSheet;

  /// Tooltip to reduce servings
  ///
  /// In en, this message translates to:
  /// **'Fewer servings'**
  String get mealPlanFewerServings;

  /// Tooltip to increase servings
  ///
  /// In en, this message translates to:
  /// **'More servings'**
  String get mealPlanMoreServings;

  /// Semantics: open planned recipe
  ///
  /// In en, this message translates to:
  /// **'Open recipe for {slot}'**
  String mealPlanOpenRecipe(String slot);

  /// Semantics: add meal to slot
  ///
  /// In en, this message translates to:
  /// **'Add meal for {slot}'**
  String mealPlanAddMealFor(String slot);

  /// AppBar title for account/profile screen
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get accountAppBarTitle;

  /// Error when profile fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load profile. Please try again.'**
  String get accountFailedLoadProfile;

  /// Error when name save fails
  ///
  /// In en, this message translates to:
  /// **'Failed to save name'**
  String get accountFailedSaveName;

  /// Semantics: edit name field
  ///
  /// In en, this message translates to:
  /// **'Edit your name'**
  String get accountEditYourName;

  /// Bottom sheet title for password change
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get accountChangePassword;

  /// Validation: all password fields required
  ///
  /// In en, this message translates to:
  /// **'Fill out all password fields.'**
  String get accountFillPasswordFields;

  /// Validation: password too short
  ///
  /// In en, this message translates to:
  /// **'New password must be at least 6 characters.'**
  String get accountPasswordMinLength;

  /// Validation: passwords don't match
  ///
  /// In en, this message translates to:
  /// **'New passwords do not match.'**
  String get accountPasswordsMismatch;

  /// Snackbar when password is changed
  ///
  /// In en, this message translates to:
  /// **'Password changed'**
  String get accountPasswordChanged;

  /// Input label for current password
  ///
  /// In en, this message translates to:
  /// **'Current password'**
  String get accountCurrentPassword;

  /// Input label for new password
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get accountNewPassword;

  /// Input label for confirm password
  ///
  /// In en, this message translates to:
  /// **'Confirm new password'**
  String get accountConfirmPassword;

  /// Button text to change password
  ///
  /// In en, this message translates to:
  /// **'Change password'**
  String get accountChangePasswordButton;

  /// Bottom sheet title for terms
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get accountTermsTitle;

  /// Terms of service body text
  ///
  /// In en, this message translates to:
  /// **'Use mitlist responsibly and respect your household members\' privacy. Do not misuse shared features or data. mitlist is provided as-is without warranties.'**
  String get accountTermsBody;

  /// Dialog title for account deletion
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDeleteAccount;

  /// Dialog body for account deletion
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete your account and all associated data. This cannot be undone.'**
  String get accountDeleteAccountBody;

  /// Button to log out
  ///
  /// In en, this message translates to:
  /// **'Log out'**
  String get accountLogOut;

  /// Button to delete your account
  ///
  /// In en, this message translates to:
  /// **'Delete account'**
  String get accountDeleteAccountButton;

  /// Section title for household info
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get accountHouseholdSection;

  /// Semantics for household switch
  ///
  /// In en, this message translates to:
  /// **'Switch to {name}'**
  String accountSwitchToHousehold(String name);

  /// Menu row: notification inbox
  ///
  /// In en, this message translates to:
  /// **'Notification inbox'**
  String get accountNotificationInbox;

  /// Menu row: notification preferences
  ///
  /// In en, this message translates to:
  /// **'Notification preferences'**
  String get accountNotificationPreferences;

  /// Menu row: appearance settings
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get accountAppearance;

  /// Theme option: follow system
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get accountAppearanceSystem;

  /// Theme option: light mode
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get accountAppearanceLight;

  /// Theme option: dark mode
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get accountAppearanceDark;

  /// Menu row: change password
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get accountChangePasswordRow;

  /// Menu row: app version
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get accountVersion;

  /// Menu row: terms of service
  ///
  /// In en, this message translates to:
  /// **'Terms of Service'**
  String get accountTermsRow;

  /// Menu row: open data attribution
  ///
  /// In en, this message translates to:
  /// **'Open data'**
  String get accountOpenDataRow;

  /// Menu row: opens the support/donate page
  ///
  /// In en, this message translates to:
  /// **'Support mitlist'**
  String get accountSupportRow;

  /// Menu row: shows which server the app talks to
  ///
  /// In en, this message translates to:
  /// **'Server'**
  String get accountServerRow;

  /// Bottom sheet title for open data attribution
  ///
  /// In en, this message translates to:
  /// **'Open data attribution'**
  String get accountOpenDataTitle;

  /// Open data attribution body text (Open Food Facts / ODbL)
  ///
  /// In en, this message translates to:
  /// **'Some grocery brand names come from Open Food Facts (openfoodfacts.org), used under the Open Database License (ODbL) v1.0. The derived brand list is kept separable from mitlist\'s own data.'**
  String get accountOpenDataBody;

  /// Card title for guest account status
  ///
  /// In en, this message translates to:
  /// **'You\'re on a guest account'**
  String get accountGuestTitle;

  /// Description for guest account upgrade
  ///
  /// In en, this message translates to:
  /// **'Create a full account to keep your data permanently and access all features.'**
  String get accountGuestDesc;

  /// Button to upgrade from guest
  ///
  /// In en, this message translates to:
  /// **'Create full account'**
  String get accountCreateFullAccount;

  /// Menu row: export expenses as CSV
  ///
  /// In en, this message translates to:
  /// **'Export expenses (CSV)'**
  String get accountExportCSV;

  /// Menu row: share expenses as JSON
  ///
  /// In en, this message translates to:
  /// **'Share expenses (JSON)'**
  String get accountShareJSON;

  /// Menu row: copy expenses JSON
  ///
  /// In en, this message translates to:
  /// **'Copy expenses (JSON)'**
  String get accountCopyJSON;

  /// Menu row: export the household calendar as an iCalendar file
  ///
  /// In en, this message translates to:
  /// **'Export calendar (.ics)'**
  String get accountExportCalendar;

  /// Snackbar when JSON is copied
  ///
  /// In en, this message translates to:
  /// **'Expenses JSON copied to clipboard'**
  String get accountJSONCopied;

  /// Bottom sheet title for account creation
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get accountCreateAccountTitle;

  /// Validation: all fields required
  ///
  /// In en, this message translates to:
  /// **'Please fill in all fields.'**
  String get accountFillAllFields;

  /// Input label for name
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get accountYourName;

  /// Placeholder for name input
  ///
  /// In en, this message translates to:
  /// **'e.g. Alex Smith'**
  String get accountYourNameHint;

  /// Input label for email
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get accountEmail;

  /// Placeholder for email input
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get accountEmailHint;

  /// Input label for password
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get accountPassword;

  /// Button text while creating account
  ///
  /// In en, this message translates to:
  /// **'Creating account…'**
  String get accountCreatingAccount;

  /// Button to submit account creation
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get accountCreateAccount;

  /// Snackbar after account creation
  ///
  /// In en, this message translates to:
  /// **'Account created. Welcome!'**
  String get accountCreatedWelcome;

  /// AppBar title for notifications screen
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notificationsAppBarTitle;

  /// Button to mark all notifications read
  ///
  /// In en, this message translates to:
  /// **'Mark all read'**
  String get notificationsMarkAllRead;

  /// Error when notifications fail to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load notifications.'**
  String get notificationsFailedLoad;

  /// Error when notification pagination fails
  ///
  /// In en, this message translates to:
  /// **'Failed to load more notifications.'**
  String get notificationsFailedLoadMore;

  /// Error when mark-all-read fails
  ///
  /// In en, this message translates to:
  /// **'Failed to mark all as read.'**
  String get notificationsFailedMarkAllRead;

  /// Error when marking single notification fails
  ///
  /// In en, this message translates to:
  /// **'Failed to mark as read.'**
  String get notificationsFailedMarkRead;

  /// No-household description for notifications
  ///
  /// In en, this message translates to:
  /// **'Create or join a household to receive notifications.'**
  String get notificationsNoHouseholdDesc;

  /// Empty state when no notifications
  ///
  /// In en, this message translates to:
  /// **'No notifications yet'**
  String get notificationsNoNotifications;

  /// Description for empty notifications
  ///
  /// In en, this message translates to:
  /// **'When someone adds a chore, splits a bill, or mentions you, it will show up here.'**
  String get notificationsNoNotificationsDesc;

  /// Semantics label for unread notification
  ///
  /// In en, this message translates to:
  /// **'Unread, {title}'**
  String notificationsUnreadLabel(String title);

  /// Feed section header: notifications from today
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get notificationsSectionToday;

  /// Feed section header: notifications from yesterday
  ///
  /// In en, this message translates to:
  /// **'Yesterday'**
  String get notificationsSectionYesterday;

  /// Feed section header: older notifications
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get notificationsSectionEarlier;

  /// Relative time: under a minute ago
  ///
  /// In en, this message translates to:
  /// **'now'**
  String get notificationsTimeNow;

  /// Compact relative time in minutes
  ///
  /// In en, this message translates to:
  /// **'{minutes}m'**
  String notificationsTimeMinutes(int minutes);

  /// Compact relative time in hours
  ///
  /// In en, this message translates to:
  /// **'{hours}h'**
  String notificationsTimeHours(int hours);

  /// Compact relative time in days
  ///
  /// In en, this message translates to:
  /// **'{days}d'**
  String notificationsTimeDays(int days);

  /// Unread count chip in the app bar
  ///
  /// In en, this message translates to:
  /// **'{count} new'**
  String notificationsUnreadCount(int count);

  /// AppBar title for notification preferences
  ///
  /// In en, this message translates to:
  /// **'Notification Preferences'**
  String get notifPrefAppBarTitle;

  /// Error when preferences fail to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load notification preferences.'**
  String get notifPrefFailedLoad;

  /// No-household description for preferences
  ///
  /// In en, this message translates to:
  /// **'Join or create a household to configure notification preferences.'**
  String get notifPrefNoHouseholdDesc;

  /// Empty state when no preferences
  ///
  /// In en, this message translates to:
  /// **'No preferences yet'**
  String get notifPrefNoPreferences;

  /// Description for empty preferences
  ///
  /// In en, this message translates to:
  /// **'Preferences are created when you join a household. If you just joined, they should appear shortly.'**
  String get notifPrefNoPreferencesDesc;

  /// Fallback group name for preferences
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifPrefGroupName;

  /// Toggle label for chore due reminders
  ///
  /// In en, this message translates to:
  /// **'Chore due reminders'**
  String get notifPrefChoreDueReminders;

  /// Toggle subtitle for chore due reminders
  ///
  /// In en, this message translates to:
  /// **'When a chore is coming due'**
  String get notifPrefChoreDueRemindersDesc;

  /// Toggle label for day-of chore reminders
  ///
  /// In en, this message translates to:
  /// **'Chore due day-of'**
  String get notifPrefChoreDueDayOf;

  /// Toggle subtitle for day-of chore reminders
  ///
  /// In en, this message translates to:
  /// **'On the day a chore is due'**
  String get notifPrefChoreDueDayOfDesc;

  /// Toggle label for list item notifications
  ///
  /// In en, this message translates to:
  /// **'List item added'**
  String get notifPrefListItemAdded;

  /// Toggle subtitle for list item notifications
  ///
  /// In en, this message translates to:
  /// **'When someone adds to a shared list'**
  String get notifPrefListItemAddedDesc;

  /// Toggle label for expense notifications
  ///
  /// In en, this message translates to:
  /// **'Expense created'**
  String get notifPrefExpenseCreated;

  /// Toggle subtitle for expense notifications
  ///
  /// In en, this message translates to:
  /// **'When a new expense is logged'**
  String get notifPrefExpenseCreatedDesc;

  /// Toggle label for meal plan notifications
  ///
  /// In en, this message translates to:
  /// **'Meal plan changed'**
  String get notifPrefMealPlanChanged;

  /// Toggle subtitle for meal plan notifications
  ///
  /// In en, this message translates to:
  /// **'When the meal plan is updated'**
  String get notifPrefMealPlanChangedDesc;

  /// Toggle label for weekly digest
  ///
  /// In en, this message translates to:
  /// **'Weekly digest'**
  String get notifPrefWeeklyDigest;

  /// Toggle subtitle for weekly digest
  ///
  /// In en, this message translates to:
  /// **'A summary of household activity'**
  String get notifPrefWeeklyDigestDesc;

  /// Toggle label for pinwall reminders
  ///
  /// In en, this message translates to:
  /// **'Pinwall reminders'**
  String get notifPrefPinwallReminders;

  /// Toggle subtitle for pinwall reminders
  ///
  /// In en, this message translates to:
  /// **'When someone pins a reminder for later'**
  String get notifPrefPinwallRemindersDesc;

  /// Toggle label for push notifications
  ///
  /// In en, this message translates to:
  /// **'Push notifications'**
  String get notifPrefPushNotifications;

  /// Toggle subtitle for push notifications
  ///
  /// In en, this message translates to:
  /// **'Receive notifications on this device'**
  String get notifPrefPushNotificationsDesc;

  /// AppBar title for shopping trip
  ///
  /// In en, this message translates to:
  /// **'Shopping Trip'**
  String get shoppingTripAppBarTitle;

  /// Tooltip to pick a store
  ///
  /// In en, this message translates to:
  /// **'Choose store'**
  String get shoppingTripChooseStore;

  /// Empty state when no lists
  ///
  /// In en, this message translates to:
  /// **'No lists yet'**
  String get shoppingTripNoLists;

  /// Description when no lists
  ///
  /// In en, this message translates to:
  /// **'Create a shopping list to start a trip'**
  String get shoppingTripNoListsDesc;

  /// Empty state when no open items
  ///
  /// In en, this message translates to:
  /// **'All caught up'**
  String get shoppingTripAllCaughtUp;

  /// Description when all caught up
  ///
  /// In en, this message translates to:
  /// **'No open items across your lists. Add items to a list to see them here.'**
  String get shoppingTripAllCaughtUpDesc;

  /// Default aisle sorting label
  ///
  /// In en, this message translates to:
  /// **'Sorted by store aisles'**
  String get shoppingTripSortedByAisles;

  /// Store-specific aisle sorting label
  ///
  /// In en, this message translates to:
  /// **'Sorted by {store} aisles'**
  String shoppingTripSortedByStoreAisles(String store);

  /// Button to mark item as purchased
  ///
  /// In en, this message translates to:
  /// **'Mark done'**
  String get shoppingTripMarkDone;

  /// Basket bar: collected count and price
  ///
  /// In en, this message translates to:
  /// **'/ {collected} collected{price}'**
  String shoppingTripBasketBar(num collected, String price);

  /// Snackbar when items are checked off with prices
  ///
  /// In en, this message translates to:
  /// **'{amount} worth of items marked as done'**
  String shoppingTripItemsWorthDone(String amount);

  /// Snackbar action to create expense
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get shoppingTripAddExpense;

  /// Stamp text when shopping complete
  ///
  /// In en, this message translates to:
  /// **'DONE'**
  String get shoppingTripStampDone;

  /// Stamp item count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item} other{{count} items}}'**
  String shoppingTripStampItems(num count);

  /// Fallback list name
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get shoppingTripFallbackList;

  /// Toggle item to not purchased
  ///
  /// In en, this message translates to:
  /// **'Mark {item} as not purchased'**
  String shoppingTripMarkNotPurchased(String item);

  /// Toggle item to purchased
  ///
  /// In en, this message translates to:
  /// **'Mark {item} as purchased'**
  String shoppingTripMarkPurchased(String item);

  /// AppBar title for scanner screen
  ///
  /// In en, this message translates to:
  /// **'Scanner'**
  String get scannerAppBarTitle;

  /// Label for store picker
  ///
  /// In en, this message translates to:
  /// **'Shopping at'**
  String get scannerShoppingAt;

  /// Placeholder for store picker
  ///
  /// In en, this message translates to:
  /// **'Choose your store'**
  String get scannerChooseStore;

  /// Placeholder describing scan capabilities
  ///
  /// In en, this message translates to:
  /// **'Scan a receipt, list, recipe,\nor chore reminder'**
  String get scannerHintText;

  /// Text shown while AI is analyzing image
  ///
  /// In en, this message translates to:
  /// **'Analyzing…'**
  String get scannerAnalyzing;

  /// Button to scan as grocery list
  ///
  /// In en, this message translates to:
  /// **'Scan grocery list'**
  String get scannerScanGrocery;

  /// Button to scan as receipt/etc
  ///
  /// In en, this message translates to:
  /// **'Scan receipt, recipe, or chore'**
  String get scannerScanReceipt;

  /// Button to analyze selected image
  ///
  /// In en, this message translates to:
  /// **'Analyze this image'**
  String get scannerAnalyzeThis;

  /// Button prompt when no image selected
  ///
  /// In en, this message translates to:
  /// **'Take a photo or choose one'**
  String get scannerTakeOrChoose;

  /// Button to change image
  ///
  /// In en, this message translates to:
  /// **'Pick different image'**
  String get scannerPickDifferent;

  /// Bottom sheet title for scan start
  ///
  /// In en, this message translates to:
  /// **'Scan grocery list'**
  String get scannerScanSheetTitle;

  /// Alternate bottom sheet title for scan
  ///
  /// In en, this message translates to:
  /// **'Add scan'**
  String get scannerAddScanTitle;

  /// Option to take a photo
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get scannerTakePhoto;

  /// Option to pick from gallery
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get scannerChooseFromGallery;

  /// Scan type label: receipt
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get scannerTypeReceipt;

  /// Scan type label: shopping list
  ///
  /// In en, this message translates to:
  /// **'Shopping list'**
  String get scannerTypeShoppingList;

  /// Scan type label: recipe
  ///
  /// In en, this message translates to:
  /// **'Recipe'**
  String get scannerTypeRecipe;

  /// Scan type label: chore
  ///
  /// In en, this message translates to:
  /// **'Chore'**
  String get scannerTypeChore;

  /// Label showing detected scan type
  ///
  /// In en, this message translates to:
  /// **'Detected: {type}'**
  String scannerDetectedType(String type);

  /// Item count in scan result
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} item} other{{count} items}}'**
  String scannerItemCount(num count);

  /// Truncation indicator for long item list
  ///
  /// In en, this message translates to:
  /// **'…and {count} more'**
  String scannerAndMore(num count);

  /// Step count in scan result
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} step} other{{count} steps}}'**
  String scannerStepCount(num count);

  /// Total amount in scan result
  ///
  /// In en, this message translates to:
  /// **'Total: {amount}'**
  String scannerTotal(String amount);

  /// Action: add scan to lists
  ///
  /// In en, this message translates to:
  /// **'Add to lists'**
  String get scannerAddToLists;

  /// Action: create expense from scan
  ///
  /// In en, this message translates to:
  /// **'Create expense'**
  String get scannerCreateExpense;

  /// Action: create recipe from scan
  ///
  /// In en, this message translates to:
  /// **'Create recipe'**
  String get scannerCreateRecipe;

  /// Action: create chore from scan
  ///
  /// In en, this message translates to:
  /// **'Create chore'**
  String get scannerCreateChore;

  /// Action: use scan result
  ///
  /// In en, this message translates to:
  /// **'Use this'**
  String get scannerUseThis;

  /// Button to scan another item
  ///
  /// In en, this message translates to:
  /// **'Scan again'**
  String get scannerScanAgain;

  /// Back button tooltip
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get smartCaptureBack;

  /// Toggle to show enhanced image
  ///
  /// In en, this message translates to:
  /// **'Show enhanced'**
  String get smartCaptureShowEnhanced;

  /// Toggle to show original image
  ///
  /// In en, this message translates to:
  /// **'Original'**
  String get smartCaptureOriginal;

  /// Button to accept imperfect capture
  ///
  /// In en, this message translates to:
  /// **'Use anyway'**
  String get smartCaptureUseAnyway;

  /// Button to use the capture
  ///
  /// In en, this message translates to:
  /// **'Use scan'**
  String get smartCaptureUseScan;

  /// Button to retake the photo
  ///
  /// In en, this message translates to:
  /// **'Retake'**
  String get smartCaptureRetake;

  /// Quality label: ready
  ///
  /// In en, this message translates to:
  /// **'Ready'**
  String get smartCaptureReady;

  /// Quality label: usable
  ///
  /// In en, this message translates to:
  /// **'Usable'**
  String get smartCaptureUsable;

  /// Quality label: retake suggested
  ///
  /// In en, this message translates to:
  /// **'Retake suggested'**
  String get smartCaptureRetakeSuggested;

  /// Error when camera is unavailable
  ///
  /// In en, this message translates to:
  /// **'No camera available.'**
  String get liveSmartCaptureNoCamera;

  /// Error when camera fails to open
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t open the camera.'**
  String get liveSmartCaptureCouldNotOpen;

  /// Hint text for camera framing
  ///
  /// In en, this message translates to:
  /// **'Frame the list'**
  String get liveSmartCaptureFrameList;

  /// Fallback error when camera is missing
  ///
  /// In en, this message translates to:
  /// **'Camera unavailable'**
  String get liveSmartCaptureCameraUnavailable;

  /// Button to pick from gallery
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get liveSmartCaptureGallery;

  /// Button to scan/capture
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get liveSmartCaptureScan;

  /// Error when photo capture fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t capture that photo.'**
  String get liveSmartCaptureCouldNotCapture;

  /// AppBar title when adding to list
  ///
  /// In en, this message translates to:
  /// **'Add to {list}'**
  String scanReviewAddToList(String list);

  /// AppBar title when reviewing items
  ///
  /// In en, this message translates to:
  /// **'Review items'**
  String get scanReviewReviewItems;

  /// Button to accept all scanned items
  ///
  /// In en, this message translates to:
  /// **'Accept all ({count})'**
  String scanReviewAcceptAll(num count);

  /// Store label prefix
  ///
  /// In en, this message translates to:
  /// **'Store:'**
  String get scanReviewStoreLabel;

  /// Section label for suggestions
  ///
  /// In en, this message translates to:
  /// **'You might also need'**
  String get scanReviewYouMightNeed;

  /// Section label for ignored items
  ///
  /// In en, this message translates to:
  /// **'Ignored'**
  String get scanReviewIgnored;

  /// Bottom sheet title for new list creation
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get scanReviewNewList;

  /// Bottom sheet title for list picker
  ///
  /// In en, this message translates to:
  /// **'Add to which list?'**
  String get scanReviewAddToWhichList;

  /// Option to create a new list
  ///
  /// In en, this message translates to:
  /// **'New list…'**
  String get scanReviewNewListOption;

  /// Default name for a scanned list
  ///
  /// In en, this message translates to:
  /// **'Scanned list'**
  String get scanReviewScannedList;

  /// Button to create the new list
  ///
  /// In en, this message translates to:
  /// **'Create list'**
  String get scanReviewCreateList;

  /// Button text while adding items
  ///
  /// In en, this message translates to:
  /// **'Adding…'**
  String get scanReviewAdding;

  /// Semantics: remove scanned item
  ///
  /// In en, this message translates to:
  /// **'Remove {item}'**
  String scanReviewRemoveItem(String item);

  /// Button to restore an ignored item
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get scanReviewRestore;

  /// Bottom sheet title for editing item
  ///
  /// In en, this message translates to:
  /// **'Edit item'**
  String get scanReviewEditItem;

  /// Original OCR text for reference
  ///
  /// In en, this message translates to:
  /// **'OCR saw: \"{text}\"'**
  String scanReviewOCRSaw(String text);

  /// Input label for item name
  ///
  /// In en, this message translates to:
  /// **'Item name'**
  String get scanReviewItemName;

  /// Input label for quantity
  ///
  /// In en, this message translates to:
  /// **'Qty'**
  String get scanReviewQty;

  /// Input label for unit
  ///
  /// In en, this message translates to:
  /// **'Unit'**
  String get scanReviewUnit;

  /// Label for alternative suggestions
  ///
  /// In en, this message translates to:
  /// **'Did you mean?'**
  String get scanReviewDidYouMean;

  /// Tentative resolver guess under the user's OCR text on a low-confidence scan-review row
  ///
  /// In en, this message translates to:
  /// **'Best guess: {name}'**
  String scanReviewBestGuess(String name);

  /// AppBar title for share target screen
  ///
  /// In en, this message translates to:
  /// **'Save to mitlist'**
  String get shareTargetAppBarTitle;

  /// TextField label for shared content
  ///
  /// In en, this message translates to:
  /// **'Shared text'**
  String get shareTargetSharedText;

  /// TextField hint for shared content
  ///
  /// In en, this message translates to:
  /// **'Paste or type the shared text here…'**
  String get shareTargetPasteHint;

  /// Button to add photos
  ///
  /// In en, this message translates to:
  /// **'Add photos'**
  String get shareTargetAddPhotos;

  /// Button text showing photo count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 photo added} other{{count} photos added}}'**
  String shareTargetPhotosAdded(num count);

  /// Preview placeholder text
  ///
  /// In en, this message translates to:
  /// **'Paste text here now, or send content from the share extension when that integration is available.'**
  String get shareTargetPreviewPlaceholder;

  /// Destination option: lists
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get shareTargetDestLists;

  /// Description for lists destination
  ///
  /// In en, this message translates to:
  /// **'Save to a shopping or to-do list'**
  String get shareTargetDestListsDesc;

  /// Destination option: pinwall
  ///
  /// In en, this message translates to:
  /// **'Pinwall'**
  String get shareTargetDestPinwall;

  /// Description for pinwall destination
  ///
  /// In en, this message translates to:
  /// **'Post a note (and optional photos) to your household'**
  String get shareTargetDestPinwallDesc;

  /// Destination option: recipes
  ///
  /// In en, this message translates to:
  /// **'Recipes'**
  String get shareTargetDestRecipes;

  /// Description for recipes destination
  ///
  /// In en, this message translates to:
  /// **'Add to saved recipes'**
  String get shareTargetDestRecipesDesc;

  /// Bottom sheet title for household picker
  ///
  /// In en, this message translates to:
  /// **'Select household'**
  String get shareTargetSelectHousehold;

  /// Snackbar when content is saved
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get shareTargetSaved;

  /// Error when save fails
  ///
  /// In en, this message translates to:
  /// **'Failed to save. Please try again.'**
  String get shareTargetFailedSave;

  /// Validation: content required
  ///
  /// In en, this message translates to:
  /// **'Paste or type something to save.'**
  String get shareTargetValidationText;

  /// Validation: note or photo required
  ///
  /// In en, this message translates to:
  /// **'Add a note or at least one photo.'**
  String get shareTargetValidationNote;

  /// Validation: household required
  ///
  /// In en, this message translates to:
  /// **'Create or join a household first.'**
  String get shareTargetValidationHousehold;

  /// Bottom sheet title for expense creation
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get expenseCreationTitle;

  /// Placeholder for amount input
  ///
  /// In en, this message translates to:
  /// **'0.00'**
  String get expenseCreationAmountHint;

  /// Placeholder for FX rate input
  ///
  /// In en, this message translates to:
  /// **'Rate: 1 {currency} = ? {groupCurrency}'**
  String expenseCreationRateHint(String currency, String groupCurrency);

  /// Placeholder for expense description
  ///
  /// In en, this message translates to:
  /// **'What\'s this for?'**
  String get expenseCreationWhatsItFor;

  /// Label for the expense category picker
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get expenseCreationCategoryLabel;

  /// Expense category
  ///
  /// In en, this message translates to:
  /// **'Groceries'**
  String get expenseCategoryGroceries;

  /// Expense category
  ///
  /// In en, this message translates to:
  /// **'Dining'**
  String get expenseCategoryDining;

  /// Expense category
  ///
  /// In en, this message translates to:
  /// **'Transport'**
  String get expenseCategoryTransport;

  /// Expense category
  ///
  /// In en, this message translates to:
  /// **'Utilities'**
  String get expenseCategoryUtilities;

  /// Expense category
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get expenseCategoryHousehold;

  /// Expense category
  ///
  /// In en, this message translates to:
  /// **'Entertainment'**
  String get expenseCategoryEntertainment;

  /// Expense category
  ///
  /// In en, this message translates to:
  /// **'Health'**
  String get expenseCategoryHealth;

  /// Expense category (default/fallback)
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get expenseCategoryOther;

  /// Placeholder for optional notes
  ///
  /// In en, this message translates to:
  /// **'Notes (optional)'**
  String get expenseCreationNotesHint;

  /// Semantics label for date picker
  ///
  /// In en, this message translates to:
  /// **'Expense date. Tap to change.'**
  String get expenseCreationDateLabel;

  /// Button text for receipt scan
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get expenseCreationReceiptButton;

  /// Button text while scanning receipt
  ///
  /// In en, this message translates to:
  /// **'Scanning…'**
  String get expenseCreationScanning;

  /// Button text to scan receipt
  ///
  /// In en, this message translates to:
  /// **'Scan'**
  String get expenseCreationScanButton;

  /// Button text when receipt is attached
  ///
  /// In en, this message translates to:
  /// **'Receipt attached. Tap to re-scan.'**
  String get expenseCreationReceiptAttached;

  /// Semantics label for receipt scan
  ///
  /// In en, this message translates to:
  /// **'Scan receipt via camera'**
  String get expenseCreationScanReceiptSemantics;

  /// Section label for split mode
  ///
  /// In en, this message translates to:
  /// **'Split mode'**
  String get expenseCreationSplitMode;

  /// Running total shown beside the split mode label, e.g. 'Total $42.00'
  ///
  /// In en, this message translates to:
  /// **'Total {amount}'**
  String expenseCreationSplitTotal(String amount);

  /// Equal split mode
  ///
  /// In en, this message translates to:
  /// **'Equal'**
  String get expenseCreationSplitEqual;

  /// Exact amounts split mode
  ///
  /// In en, this message translates to:
  /// **'Exact'**
  String get expenseCreationSplitExact;

  /// Shares split mode
  ///
  /// In en, this message translates to:
  /// **'Shares'**
  String get expenseCreationSplitShares;

  /// Percentage split mode
  ///
  /// In en, this message translates to:
  /// **'Percent'**
  String get expenseCreationSplitPercent;

  /// Hint for exact split mode
  ///
  /// In en, this message translates to:
  /// **'Enter the exact amount each person owes.'**
  String get expenseCreationSplitHintExact;

  /// Hint for percent split mode
  ///
  /// In en, this message translates to:
  /// **'Enter each person\'s share; must total 100%.'**
  String get expenseCreationSplitHintPercent;

  /// Hint for shares split mode
  ///
  /// In en, this message translates to:
  /// **'Split by shares, e.g. 2 shares pays double.'**
  String get expenseCreationSplitHintShares;

  /// Hint for equal split mode
  ///
  /// In en, this message translates to:
  /// **'Split the total evenly among selected members.'**
  String get expenseCreationSplitHintEqual;

  /// Shares column label
  ///
  /// In en, this message translates to:
  /// **'Shares'**
  String get expenseCreationSplitSharesLabel;

  /// Amount column label
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get expenseCreationSplitValuesAmount;

  /// Percent column label
  ///
  /// In en, this message translates to:
  /// **'%'**
  String get expenseCreationSplitValuesPercent;

  /// Section label for payer selection
  ///
  /// In en, this message translates to:
  /// **'Paid by'**
  String get expenseCreationPaidBy;

  /// Section label for split participants
  ///
  /// In en, this message translates to:
  /// **'Split with'**
  String get expenseCreationSplitWith;

  /// Prompt when no splitters selected
  ///
  /// In en, this message translates to:
  /// **'Select at least one person to split with.'**
  String get expenseCreationSelectSplitter;

  /// Prompt when amount is empty
  ///
  /// In en, this message translates to:
  /// **'Enter an amount above to preview each share.'**
  String get expenseCreationEnterAmount;

  /// Validation: invalid amount
  ///
  /// In en, this message translates to:
  /// **'Enter a valid amount greater than zero.'**
  String get expenseCreationValidationAmount;

  /// Validation: invalid FX rate
  ///
  /// In en, this message translates to:
  /// **'Enter a conversion rate greater than zero.'**
  String get expenseCreationValidationRate;

  /// Subtle hint shown when FX rate was prefilled from the live-rate endpoint
  ///
  /// In en, this message translates to:
  /// **'Rate auto-filled — you can edit it.'**
  String get expenseCreationRateAutoFilled;

  /// Snackbar: expense saved without receipt
  ///
  /// In en, this message translates to:
  /// **'Expense saved, but receipt upload failed.'**
  String get expenseCreationReceiptUploadFailed;

  /// Snackbar when expense is created
  ///
  /// In en, this message translates to:
  /// **'Expense added'**
  String get expenseCreationExpenseAdded;

  /// Collapsed one-line summary of payer + split mode
  ///
  /// In en, this message translates to:
  /// **'Paid by {payer} · split {how}'**
  String expenseCreationSummaryPaidBySplit(String payer, String how);

  /// Payer name shown when the current user paid
  ///
  /// In en, this message translates to:
  /// **'you'**
  String get expenseCreationSummaryYou;

  /// Split descriptor in the summary line, equal mode
  ///
  /// In en, this message translates to:
  /// **'equally'**
  String get expenseCreationSplitHowEqual;

  /// Split descriptor in the summary line, exact-amount mode
  ///
  /// In en, this message translates to:
  /// **'by exact amounts'**
  String get expenseCreationSplitHowExact;

  /// Split descriptor in the summary line, shares mode
  ///
  /// In en, this message translates to:
  /// **'by shares'**
  String get expenseCreationSplitHowShares;

  /// Split descriptor in the summary line, percentage mode
  ///
  /// In en, this message translates to:
  /// **'by percentages'**
  String get expenseCreationSplitHowPercent;

  /// Semantic label for the tappable summary line that expands the split editor
  ///
  /// In en, this message translates to:
  /// **'Edit who paid and how it\'s split'**
  String get expenseCreationEditSplitSemantic;

  /// Board chip label for pinwall
  ///
  /// In en, this message translates to:
  /// **'Pinwall'**
  String get pinwallBoardLabel;

  /// Header for the collapsible household stats summary under the composer
  ///
  /// In en, this message translates to:
  /// **'At a glance'**
  String get pinwallSnapshot;

  /// Hint text for pinwall interactions
  ///
  /// In en, this message translates to:
  /// **'Drag notes to move  ·  Pinch to zoom'**
  String get pinwallDragHint;

  /// Accessibility label listing the household members currently viewing the board
  ///
  /// In en, this message translates to:
  /// **'{names} here now'**
  String pinwallPresenceHere(String names);

  /// Button/semantics to close pinwall
  ///
  /// In en, this message translates to:
  /// **'Close board'**
  String get pinwallCloseBoard;

  /// Empty state for pinwall board
  ///
  /// In en, this message translates to:
  /// **'The wall is clear.\nPin a note from the hub to get started.'**
  String get pinwallEmptyBoard;

  /// Semantics label for a pinwall note
  ///
  /// In en, this message translates to:
  /// **'{user} · {content}'**
  String pinwallNoteSemantics(String user, String content);

  /// Label for active pinwall reminder
  ///
  /// In en, this message translates to:
  /// **'Reminder · {text}'**
  String pinwallReminderLabel(String text);

  /// Label for past pinwall reminder
  ///
  /// In en, this message translates to:
  /// **'Reminded · {text}'**
  String pinwallRemindedLabel(String text);

  /// DatePicker help text for pinwall reminder
  ///
  /// In en, this message translates to:
  /// **'Choose reminder date'**
  String get pinwallChooseReminderDate;

  /// TimePicker help text for pinwall reminder
  ///
  /// In en, this message translates to:
  /// **'Choose reminder time'**
  String get pinwallChooseReminderTime;

  /// Title of the link entity bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Link to…'**
  String get pinwallLinkTo;

  /// Link action: link an expense
  ///
  /// In en, this message translates to:
  /// **'An expense'**
  String get pinwallLinkExpense;

  /// Button to remove linked entity
  ///
  /// In en, this message translates to:
  /// **'Remove link'**
  String get pinwallRemoveLink;

  /// Title for entity picker
  ///
  /// In en, this message translates to:
  /// **'Select a {type}'**
  String pinwallSelectEntity(String type);

  /// Semantics label to open the pinwall board
  ///
  /// In en, this message translates to:
  /// **'Open pinwall board'**
  String get pinwallOpenBoard;

  /// Button text to link a post to an entity
  ///
  /// In en, this message translates to:
  /// **'Link to a chore, list…'**
  String get pinwallLinkToChore;

  /// Snackbar: reminder must be in the future
  ///
  /// In en, this message translates to:
  /// **'Pick a time in the future.'**
  String get pinwallPickFutureTime;

  /// Snackbar when entity picker fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load entities.'**
  String get pinwallCouldNotLoadEntities;

  /// Snackbar when post is created
  ///
  /// In en, this message translates to:
  /// **'Pinned to the wall'**
  String get pinwallPinned;

  /// Button/semantics to open full pinwall board
  ///
  /// In en, this message translates to:
  /// **'Open board'**
  String get pinwallOpenBoardBtn;

  /// Placeholder for pinwall composer input
  ///
  /// In en, this message translates to:
  /// **'Post a note to the household…'**
  String get pinwallPostHint;

  /// Button to add a reminder to a post
  ///
  /// In en, this message translates to:
  /// **'Add reminder'**
  String get pinwallAddReminder;

  /// Button when a reminder is configured
  ///
  /// In en, this message translates to:
  /// **'Reminder set for {label}. Tap to change.'**
  String pinwallReminderSet(String label);

  /// Tooltip to clear the reminder
  ///
  /// In en, this message translates to:
  /// **'Clear reminder'**
  String get pinwallClearReminder;

  /// Button to attach a photo to a post
  ///
  /// In en, this message translates to:
  /// **'Attach photo'**
  String get pinwallAttachPhoto;

  /// Button text while media is uploading
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get pinwallUploading;

  /// Button text while post is being created
  ///
  /// In en, this message translates to:
  /// **'Posting…'**
  String get pinwallPosting;

  /// Button to submit a pinwall post
  ///
  /// In en, this message translates to:
  /// **'Pin it'**
  String get pinwallPinIt;

  /// Snackbar when image fails to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load image.'**
  String get pinwallCouldNotLoadImage;

  /// Button to remove media from a post
  ///
  /// In en, this message translates to:
  /// **'Remove from post'**
  String get pinwallRemoveFromPost;

  /// Snackbar when photo removal fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove photo.'**
  String get pinwallCouldNotRemovePhoto;

  /// Snackbar when photo add fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add photo.'**
  String get pinwallCouldNotAddPhoto;

  /// Label for a post linked to a list
  ///
  /// In en, this message translates to:
  /// **'Linked list'**
  String get pinwallLinkedList;

  /// Label for a post linked to a chore
  ///
  /// In en, this message translates to:
  /// **'Linked chore'**
  String get pinwallLinkedChore;

  /// Label for a post linked to an expense
  ///
  /// In en, this message translates to:
  /// **'Linked expense'**
  String get pinwallLinkedExpense;

  /// Semantics: open linked entity
  ///
  /// In en, this message translates to:
  /// **'Open linked {entity}'**
  String pinwallOpenLinkedEntity(String entity);

  /// Tooltip for post options menu
  ///
  /// In en, this message translates to:
  /// **'Post options'**
  String get pinwallPostOptions;

  /// Dialog title for deleting a pinwall post
  ///
  /// In en, this message translates to:
  /// **'Delete pin'**
  String get pinwallDeletePin;

  /// Dialog body for pinwall post deletion
  ///
  /// In en, this message translates to:
  /// **'This pin will be permanently deleted. This cannot be undone.'**
  String get pinwallDeletePinBody;

  /// Menu item to add photo to post
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get pinwallAddPhotoMenu;

  /// Tonight card header for breakfast
  ///
  /// In en, this message translates to:
  /// **'Today · Breakfast'**
  String get tonightBreakfast;

  /// Tonight card header for lunch
  ///
  /// In en, this message translates to:
  /// **'Today · Lunch'**
  String get tonightLunch;

  /// Semantics label for tonight's meal
  ///
  /// In en, this message translates to:
  /// **'Tonight: {title}. Open recipe'**
  String tonightOpenRecipe(String title);

  /// Camera capture quality: try a clearer photo
  ///
  /// In en, this message translates to:
  /// **'Try a clearer photo'**
  String get captureHintClearer;

  /// Camera capture quality: hold steady
  ///
  /// In en, this message translates to:
  /// **'Hold steady'**
  String get captureHintHoldSteady;

  /// Camera capture quality: need more light
  ///
  /// In en, this message translates to:
  /// **'Find more light'**
  String get captureHintMoreLight;

  /// Camera capture quality: reduce glare
  ///
  /// In en, this message translates to:
  /// **'Reduce glare'**
  String get captureHintReduceGlare;

  /// Camera capture quality: move closer
  ///
  /// In en, this message translates to:
  /// **'Move closer'**
  String get captureHintMoveCloser;

  /// Menu row label for language selector
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get accountLanguage;

  /// Language option: follow device locale
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get accountLanguageSystem;

  /// Bottom navigation label for home/hub
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get navHome;

  /// Bottom navigation label for chores
  ///
  /// In en, this message translates to:
  /// **'Chores'**
  String get navChores;

  /// Bottom navigation label for money/expenses
  ///
  /// In en, this message translates to:
  /// **'Money'**
  String get navMoney;

  /// Bottom navigation label for shopping lists
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get navLists;

  /// Bottom navigation label for recipes/kitchen
  ///
  /// In en, this message translates to:
  /// **'Kitchen'**
  String get navKitchen;

  /// Dialog title for sync status details
  ///
  /// In en, this message translates to:
  /// **'Sync Status'**
  String get offlineBannerTitle;

  /// Sync status label: offline
  ///
  /// In en, this message translates to:
  /// **'Offline'**
  String get offlineBannerStatusOffline;

  /// Sync status label: pending
  ///
  /// In en, this message translates to:
  /// **'Pending sync'**
  String get offlineBannerStatusPending;

  /// Sync status label: failed
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get offlineBannerStatusFailed;

  /// Hint when sync has failed items
  ///
  /// In en, this message translates to:
  /// **'Changes will be retried automatically when connectivity is restored.'**
  String get offlineBannerRetryHint;

  /// Hint when device is offline
  ///
  /// In en, this message translates to:
  /// **'You can keep making changes offline. Everything will sync when you reconnect.'**
  String get offlineBannerOfflineHint;

  /// Banner text when offline
  ///
  /// In en, this message translates to:
  /// **'Offline — changes will sync when you reconnect'**
  String get offlineBannerBarOffline;

  /// Banner text when syncing with count
  ///
  /// In en, this message translates to:
  /// **'Syncing {count} changes…'**
  String offlineBannerSyncingCount(num count);

  /// Banner text when syncing (no count)
  ///
  /// In en, this message translates to:
  /// **'Syncing changes…'**
  String get offlineBannerSyncing;

  /// Banner text when sync failed with count
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sync {count} changes'**
  String offlineBannerFailedCount(num count);

  /// Banner text when sync failed (single)
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sync a change'**
  String get offlineBannerFailedOne;

  /// Sync banner: multiple conflicts to resolve
  ///
  /// In en, this message translates to:
  /// **'{count} changes need your review'**
  String offlineBannerConflictCount(int count);

  /// Sync banner: one conflict to resolve
  ///
  /// In en, this message translates to:
  /// **'A change needs your review'**
  String get offlineBannerConflictOne;

  /// Retry button in offline banner
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get offlineBannerRetry;

  /// Placeholder for the list composer input
  ///
  /// In en, this message translates to:
  /// **'New item'**
  String get composerNewItem;

  /// Tooltip for scanning a list from composer
  ///
  /// In en, this message translates to:
  /// **'Scan list'**
  String get composerScanList;

  /// Tooltip for adding item via composer
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get composerAddItem;

  /// Action: view attached photo
  ///
  /// In en, this message translates to:
  /// **'View photo'**
  String get listItemViewPhoto;

  /// Action: replace attached photo
  ///
  /// In en, this message translates to:
  /// **'Replace photo'**
  String get listItemReplacePhoto;

  /// Action: add photo to item
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get listItemAddPhoto;

  /// Action: remove attached photo
  ///
  /// In en, this message translates to:
  /// **'Remove photo'**
  String get listItemRemovePhoto;

  /// Action: set price on item
  ///
  /// In en, this message translates to:
  /// **'Set price'**
  String get listItemSetPrice;

  /// Action: change item quantity/unit
  ///
  /// In en, this message translates to:
  /// **'Change quantity'**
  String get listItemChangeQuantity;

  /// Input label for item quantity
  ///
  /// In en, this message translates to:
  /// **'Amount'**
  String get listItemQuantityAmount;

  /// Input label for item unit
  ///
  /// In en, this message translates to:
  /// **'Unit (optional)'**
  String get listItemQuantityUnit;

  /// Action: add a note to an item
  ///
  /// In en, this message translates to:
  /// **'Add note'**
  String get listItemAddNote;

  /// Action: edit an item's note
  ///
  /// In en, this message translates to:
  /// **'Edit note'**
  String get listItemEditNote;

  /// Input label for item note
  ///
  /// In en, this message translates to:
  /// **'Note'**
  String get listItemNoteLabel;

  /// Semantics label for the list progress stripe
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done'**
  String listDetailProgress(int done, int total);

  /// Open (unchecked) item count on a hub list card
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{All done} =1{1 left} other{{count} left}}'**
  String listOpenCount(num count);

  /// Toggle list view
  ///
  /// In en, this message translates to:
  /// **'List view'**
  String get listSortListView;

  /// Action: delete item from list
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get listItemDeleteAction;

  /// Semantics label for reorder handle
  ///
  /// In en, this message translates to:
  /// **'Reorder'**
  String get listItemReorder;

  /// Semantics: mark item unchecked
  ///
  /// In en, this message translates to:
  /// **'Mark {name} as unchecked'**
  String listItemMarkUnchecked(String name);

  /// Semantics: mark item checked
  ///
  /// In en, this message translates to:
  /// **'Mark {name} as checked'**
  String listItemMarkChecked(String name);

  /// Semantics: view photo for item
  ///
  /// In en, this message translates to:
  /// **'View photo for {name}'**
  String listItemViewPhotoFor(String name);

  /// Error shown when item save fails locally
  ///
  /// In en, this message translates to:
  /// **'Failed to save — tap the sync bar to retry'**
  String get listItemFailedSave;

  /// Accessibility hint for list item long press
  ///
  /// In en, this message translates to:
  /// **'Long press for more options'**
  String get listItemLongPressHint;

  /// Smart capture review title for a list photo
  ///
  /// In en, this message translates to:
  /// **'Check list photo'**
  String get scanCheckListPhoto;

  /// Text shown while OCR processes a list photo
  ///
  /// In en, this message translates to:
  /// **'Reading your list…'**
  String get scanReadingList;

  /// Error when image OCR/processing fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t process the image. Please try again.'**
  String get scanCouldNotProcess;

  /// Bottom sheet title for list photo capture
  ///
  /// In en, this message translates to:
  /// **'Snap your list'**
  String get scanSnapYourList;

  /// Option label: take a photo
  ///
  /// In en, this message translates to:
  /// **'Take a photo'**
  String get scanTakePhoto;

  /// Option label: choose from gallery
  ///
  /// In en, this message translates to:
  /// **'Choose from gallery'**
  String get scanChooseFromGallery;

  /// Tooltip for dialog close button
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get appDialogClose;

  /// Hint text to close the dialog
  ///
  /// In en, this message translates to:
  /// **'Press back to close'**
  String get appDialogPressBack;

  /// Tooltip for notification bell in shell
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get shellNotifications;

  /// Tooltip for account avatar in shell
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get shellAccount;

  /// Generic error boundary fallback text
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorSomethingWentWrong;

  /// Semantics: remove active filter chip
  ///
  /// In en, this message translates to:
  /// **'Remove {label} filter'**
  String filterRemoveLabel(String label);

  /// Label for currency selection dropdown
  ///
  /// In en, this message translates to:
  /// **'Currency'**
  String get currencyDropdownLabel;

  /// Password strength: weak
  ///
  /// In en, this message translates to:
  /// **'Weak'**
  String get passwordStrengthWeak;

  /// Password strength: fair
  ///
  /// In en, this message translates to:
  /// **'Fair'**
  String get passwordStrengthFair;

  /// Password strength: good
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get passwordStrengthGood;

  /// Password strength: strong
  ///
  /// In en, this message translates to:
  /// **'Strong'**
  String get passwordStrengthStrong;

  /// Default semantic label for checked state
  ///
  /// In en, this message translates to:
  /// **'Checked'**
  String get checkToggleChecked;

  /// Default semantic label for unchecked state
  ///
  /// In en, this message translates to:
  /// **'Not checked'**
  String get checkToggleNotChecked;

  /// Semantic label for deleting a notification
  ///
  /// In en, this message translates to:
  /// **'Delete notification'**
  String get notificationsDeleteNotification;

  /// Label for tomorrow's date
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get calendarTomorrow;

  /// Smart capture review title for general scan
  ///
  /// In en, this message translates to:
  /// **'Check scan'**
  String get scannerCheckScan;

  /// Smart capture review title for grocery list
  ///
  /// In en, this message translates to:
  /// **'Check grocery list'**
  String get scannerCheckGrocery;

  /// Empty state for steps/ingredients list
  ///
  /// In en, this message translates to:
  /// **'No {type} yet.'**
  String recipeCreationNoItemsYet(String type);

  /// Camera capture quality: ready
  ///
  /// In en, this message translates to:
  /// **'Ready to scan'**
  String get captureHintReady;

  /// Camera capture quality: usable
  ///
  /// In en, this message translates to:
  /// **'Looks usable'**
  String get captureHintUsable;

  /// Login screen title
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authLoginTitle;

  /// Email input label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authLoginEmail;

  /// Email placeholder
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get authLoginYouExample;

  /// Password input label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authLoginPassword;

  /// Password placeholder
  ///
  /// In en, this message translates to:
  /// **'Your password'**
  String get authLoginYourPassword;

  /// Forgot password link
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get authLoginForgotPassword;

  /// Sign in submit button
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authLoginSignInButton;

  /// Sign in button loading state
  ///
  /// In en, this message translates to:
  /// **'Signing in…'**
  String get authLoginSigningIn;

  /// Prompt to switch to signup
  ///
  /// In en, this message translates to:
  /// **'No account?'**
  String get authLoginNoAccount;

  /// Link text to create account
  ///
  /// In en, this message translates to:
  /// **'Create one'**
  String get authLoginCreateOne;

  /// Validation: all fields required
  ///
  /// In en, this message translates to:
  /// **'Fill out all fields.'**
  String get authLoginFillAllFields;

  /// Validation: email required
  ///
  /// In en, this message translates to:
  /// **'Email is required.'**
  String get authLoginEmailRequired;

  /// Validation: password required
  ///
  /// In en, this message translates to:
  /// **'Password is required.'**
  String get authLoginPasswordRequired;

  /// Generic login error message
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t sign in. Check your connection and try again.'**
  String get authLoginGenericError;

  /// Remember me checkbox label
  ///
  /// In en, this message translates to:
  /// **'Remember me'**
  String get authLoginRememberMe;

  /// Semantic label for remember me checked
  ///
  /// In en, this message translates to:
  /// **'Remember me: on'**
  String get authLoginRememberMeOn;

  /// Semantic label for remember me unchecked
  ///
  /// In en, this message translates to:
  /// **'Remember me: off'**
  String get authLoginRememberMeOff;

  /// OAuth button: Google
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get authLoginGoogle;

  /// OAuth button: Apple
  ///
  /// In en, this message translates to:
  /// **'Continue with Apple'**
  String get authLoginApple;

  /// Error when OAuth is unsupported on platform
  ///
  /// In en, this message translates to:
  /// **'{provider} sign-in is only available on web, Android, and iOS right now.'**
  String authLoginOAuthUnsupported(String provider);

  /// Bottom sheet title for password reset
  ///
  /// In en, this message translates to:
  /// **'Reset Password'**
  String get authLoginResetPasswordTitle;

  /// Button to send password reset code
  ///
  /// In en, this message translates to:
  /// **'Send reset code'**
  String get authLoginSendResetCode;

  /// Input label for reset code
  ///
  /// In en, this message translates to:
  /// **'Reset code'**
  String get authLoginResetCodeLabel;

  /// Placeholder for reset code input
  ///
  /// In en, this message translates to:
  /// **'Paste the code from your email'**
  String get authLoginResetCodeHint;

  /// Button to confirm password reset
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get authLoginResetPasswordButton;

  /// Login screen link opening the server picker sheet
  ///
  /// In en, this message translates to:
  /// **'Choose your server'**
  String get authServerLink;

  /// Bottom sheet title for the server picker
  ///
  /// In en, this message translates to:
  /// **'Choose your server'**
  String get authServerSheetTitle;

  /// Explainer text in the server picker sheet
  ///
  /// In en, this message translates to:
  /// **'mitlist is open source and self-hostable. Point the app at your own server, or leave this empty to use the default server.'**
  String get authServerSheetBody;

  /// Input label for the server URL
  ///
  /// In en, this message translates to:
  /// **'Server URL'**
  String get authServerUrlLabel;

  /// Placeholder for the server URL input
  ///
  /// In en, this message translates to:
  /// **'https://mitlist.example.com'**
  String get authServerUrlHint;

  /// Validation: server URL malformed
  ///
  /// In en, this message translates to:
  /// **'Enter a full URL starting with http:// or https://.'**
  String get authServerUrlInvalid;

  /// Error when the health check against the entered server fails
  ///
  /// In en, this message translates to:
  /// **'No mitlist server answered at this address.'**
  String get authServerUnreachable;

  /// Button saving the custom server URL
  ///
  /// In en, this message translates to:
  /// **'Use this server'**
  String get authServerSave;

  /// Button clearing the custom server URL
  ///
  /// In en, this message translates to:
  /// **'Back to default server'**
  String get authServerReset;

  /// Shown when a build ships without a baked-in server URL
  ///
  /// In en, this message translates to:
  /// **'This build has no default server. Enter your server\'s address to continue.'**
  String get authServerNoDefault;

  /// Success message after requesting reset code
  ///
  /// In en, this message translates to:
  /// **'If that email exists, a reset code has been sent.'**
  String get authLoginResetCodeSent;

  /// Validation: all reset fields required
  ///
  /// In en, this message translates to:
  /// **'Fill out the reset code and both password fields.'**
  String get authLoginResetFillAllFields;

  /// Success message after password reset
  ///
  /// In en, this message translates to:
  /// **'Password reset successful. You can sign in now.'**
  String get authLoginResetSuccess;

  /// Signup screen title
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authSignupTitle;

  /// First name input label
  ///
  /// In en, this message translates to:
  /// **'First name'**
  String get authSignupFirstName;

  /// First name placeholder
  ///
  /// In en, this message translates to:
  /// **'Alex'**
  String get authSignupFirstNameHint;

  /// Last name input label
  ///
  /// In en, this message translates to:
  /// **'Last name'**
  String get authSignupLastName;

  /// Last name placeholder
  ///
  /// In en, this message translates to:
  /// **'Smith'**
  String get authSignupLastNameHint;

  /// Email input label
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get authSignupEmail;

  /// Email placeholder
  ///
  /// In en, this message translates to:
  /// **'you@example.com'**
  String get authSignupEmailHint;

  /// Password input label
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get authSignupPassword;

  /// Password hint text
  ///
  /// In en, this message translates to:
  /// **'At least 6 characters'**
  String get authSignupPasswordHint;

  /// Submit button for signup
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get authSignupCreateAccount;

  /// Loading state for signup button
  ///
  /// In en, this message translates to:
  /// **'Creating account…'**
  String get authSignupCreatingAccount;

  /// Link to login
  ///
  /// In en, this message translates to:
  /// **'Have an account?'**
  String get authSignupHaveAccount;

  /// Link to sign in
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get authSignupSignInLink;

  /// Validation: all fields required
  ///
  /// In en, this message translates to:
  /// **'Fill out all fields.'**
  String get authSignupFillAllFields;

  /// Password too short validation
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters.'**
  String get authSignupPasswordMinLength;

  /// Signup screen title when joining via invite
  ///
  /// In en, this message translates to:
  /// **'Join household'**
  String get authSignupJoinTitle;

  /// Snackbar when account is created
  ///
  /// In en, this message translates to:
  /// **'Account created. Welcome!'**
  String get authSignupAccountCreated;

  /// Validation: name required
  ///
  /// In en, this message translates to:
  /// **'Name is required.'**
  String get authSignupNameRequired;

  /// Validation: email required
  ///
  /// In en, this message translates to:
  /// **'Email is required.'**
  String get authSignupEmailRequired;

  /// Validation: password required
  ///
  /// In en, this message translates to:
  /// **'Password is required.'**
  String get authSignupPasswordRequired;

  /// Generic signup error message
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create account. Check your connection and try again.'**
  String get authSignupGenericError;

  /// Name input placeholder
  ///
  /// In en, this message translates to:
  /// **'Your name'**
  String get authSignupNameHint;

  /// Text before terms link
  ///
  /// In en, this message translates to:
  /// **'By creating an account, you agree to our '**
  String get authSignupTermsPrefix;

  /// Conjunction between legal links
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get authSignupAnd;

  /// Period after legal links
  ///
  /// In en, this message translates to:
  /// **'.'**
  String get authSignupPeriod;

  /// Privacy policy link text
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get authSignupPrivacyPolicy;

  /// Terms paragraph 1
  ///
  /// In en, this message translates to:
  /// **'Use mitlist responsibly. Shared household content is visible to the members of that household.'**
  String get authSignupTermsP1;

  /// Terms paragraph 2
  ///
  /// In en, this message translates to:
  /// **'Do not upload unlawful content, impersonate others, or abuse the service. Accounts and shared data may be removed for misuse.'**
  String get authSignupTermsP2;

  /// Terms paragraph 3
  ///
  /// In en, this message translates to:
  /// **'The app is provided as-is while the product is still evolving. Keep your own backups for anything critical.'**
  String get authSignupTermsP3;

  /// Privacy paragraph 1
  ///
  /// In en, this message translates to:
  /// **'mitlist stores the account details and household content needed to operate the app.'**
  String get authSignupPrivacyP1;

  /// Privacy paragraph 2
  ///
  /// In en, this message translates to:
  /// **'Shared data such as lists, chores, expenses, and recipes is visible to other members of the same household.'**
  String get authSignupPrivacyP2;

  /// Privacy paragraph 3
  ///
  /// In en, this message translates to:
  /// **'Only provide information you are comfortable keeping in a shared household workspace.'**
  String get authSignupPrivacyP3;

  /// Join landing screen title
  ///
  /// In en, this message translates to:
  /// **'Join household'**
  String get authJoinTitle;

  /// Invitation header
  ///
  /// In en, this message translates to:
  /// **'{name} invited you'**
  String authJoinInvitedBy(String name);

  /// CTA to join the household
  ///
  /// In en, this message translates to:
  /// **'Join now'**
  String get authJoinJoinNow;

  /// Sign in CTA with invite context
  ///
  /// In en, this message translates to:
  /// **'Sign in to join'**
  String get authJoinSignInToJoin;

  /// Create account CTA with invite context
  ///
  /// In en, this message translates to:
  /// **'Create account to join'**
  String get authJoinCreateToJoin;

  /// Warning for guest users trying to join
  ///
  /// In en, this message translates to:
  /// **'Guest accounts can\'t join households.'**
  String get authJoinGuestWarning;

  /// Error when invite fails to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load invite details.'**
  String get authJoinCouldNotLoad;

  /// Button loading state for join
  ///
  /// In en, this message translates to:
  /// **'Joining…'**
  String get authJoinJoining;

  /// Dismiss button for join landing
  ///
  /// In en, this message translates to:
  /// **'Not now'**
  String get authJoinNotNow;

  /// Success message after joining
  ///
  /// In en, this message translates to:
  /// **'You\'re in.'**
  String get authJoinYoureIn;

  /// Button to navigate to household after joining
  ///
  /// In en, this message translates to:
  /// **'Go to household'**
  String get authJoinGoToHousehold;

  /// Semantics label for invite code display
  ///
  /// In en, this message translates to:
  /// **'Invite code: {code}'**
  String authJoinInviteCodeSemantic(String code);

  /// Error with hint about household switcher
  ///
  /// In en, this message translates to:
  /// **'{error}\n\nYou can also enter a code from the household switcher.'**
  String authJoinErrorWithHint(String error);

  /// Onboarding screen title
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get authOnboardingTitle;

  /// Onboarding headline for new users
  ///
  /// In en, this message translates to:
  /// **'Set up your home'**
  String get authOnboardingSetupHome;

  /// Onboarding description
  ///
  /// In en, this message translates to:
  /// **'Create or join a household to start sharing with flatmates.'**
  String get authOnboardingCreateOrJoin;

  /// Primary CTA on onboarding
  ///
  /// In en, this message translates to:
  /// **'Create a household'**
  String get authOnboardingCreateHousehold;

  /// Secondary CTA on onboarding
  ///
  /// In en, this message translates to:
  /// **'Join with invite code'**
  String get authOnboardingJoinInvite;

  /// Invite code prompt
  ///
  /// In en, this message translates to:
  /// **'Have an invite code?'**
  String get authOnboardingHaveCode;

  /// Description for create household card
  ///
  /// In en, this message translates to:
  /// **'Start fresh: name it, invite flatmates, share everything in one place.'**
  String get authOnboardingCreateDesc;

  /// Description for join household card
  ///
  /// In en, this message translates to:
  /// **'Already got an invite? Enter the code to jump right in.'**
  String get authOnboardingJoinDesc;

  /// Semantic label for join card
  ///
  /// In en, this message translates to:
  /// **'Join a household with invite code'**
  String get authOnboardingJoinSemantic;

  /// Semantic label for home icon
  ///
  /// In en, this message translates to:
  /// **'Household home icon'**
  String get authOnboardingHomeIconSemantic;

  /// Semantic label for the welcome screen collage of pillar scraps
  ///
  /// In en, this message translates to:
  /// **'Shared lists, money, chores, and kitchen. All in one place.'**
  String get welcomePillarsSemantic;

  /// Inline create stage title on the sticky note
  ///
  /// In en, this message translates to:
  /// **'Name your household'**
  String get authOnboardingNameTitle;

  /// Inline create stage helper text
  ///
  /// In en, this message translates to:
  /// **'Write it on the note. You can change it later.'**
  String get authOnboardingNameBody;

  /// Create household submit button on the sticky note
  ///
  /// In en, this message translates to:
  /// **'Pin it to the board'**
  String get authOnboardingPinIt;

  /// Invite stage title on the torn slip
  ///
  /// In en, this message translates to:
  /// **'Bring in your flatmates'**
  String get authOnboardingInviteTitle;

  /// Invite stage body on the torn slip
  ///
  /// In en, this message translates to:
  /// **'Share this code. Anyone who enters it joins your household.'**
  String get authOnboardingInviteBody;

  /// CTA leaving onboarding for the hub
  ///
  /// In en, this message translates to:
  /// **'Go to your board'**
  String get authOnboardingGoToBoard;

  /// Hub first-run checklist heading
  ///
  /// In en, this message translates to:
  /// **'Get the house going'**
  String get hubChecklistTitle;

  /// Stamp on completed checklist notes
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get hubChecklistDone;

  /// Checklist progress summary
  ///
  /// In en, this message translates to:
  /// **'{done} of {total} done'**
  String hubChecklistProgress(int done, int total);

  /// Stats grid: chores label
  ///
  /// In en, this message translates to:
  /// **'Chores'**
  String get hubStatsChores;

  /// Stats grid: due today label
  ///
  /// In en, this message translates to:
  /// **'due'**
  String get hubStatsDue;

  /// Stats grid: meals planned label
  ///
  /// In en, this message translates to:
  /// **'Meals'**
  String get hubStatsMeals;

  /// Stats grid: planned this week
  ///
  /// In en, this message translates to:
  /// **'planned'**
  String get hubStatsPlanned;

  /// Stats grid: overdue label
  ///
  /// In en, this message translates to:
  /// **'overdue'**
  String get hubStatsOverdue;

  /// Stats grid: all done label
  ///
  /// In en, this message translates to:
  /// **'all done'**
  String get hubStatsAllDone;

  /// Stats grid: balance label
  ///
  /// In en, this message translates to:
  /// **'Balance'**
  String get hubStatsBalance;

  /// Stats grid: open balance label
  ///
  /// In en, this message translates to:
  /// **'open'**
  String get hubStatsOpen;

  /// Stats grid: lists label
  ///
  /// In en, this message translates to:
  /// **'Lists'**
  String get hubStatsLists;

  /// Stats grid: singular active list
  ///
  /// In en, this message translates to:
  /// **'active list'**
  String get hubStatsActiveList;

  /// Stats grid: plural active lists
  ///
  /// In en, this message translates to:
  /// **'active lists'**
  String get hubStatsActiveLists;

  /// Stats grid: reminders label
  ///
  /// In en, this message translates to:
  /// **'Reminders'**
  String get hubStatsReminders;

  /// Stats grid: singular pinwall reminder
  ///
  /// In en, this message translates to:
  /// **'pinwall reminder'**
  String get hubStatsPinwallReminder;

  /// Stats grid: plural pinwall reminders
  ///
  /// In en, this message translates to:
  /// **'pinwall reminders'**
  String get hubStatsPinwallReminders;

  /// Quick add bottom sheet title
  ///
  /// In en, this message translates to:
  /// **'Quick add'**
  String get hubQuickAddTitle;

  /// Quick add: chore option
  ///
  /// In en, this message translates to:
  /// **'Add chore'**
  String get hubQuickAddChore;

  /// Quick add: expense option
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get hubQuickAddExpense;

  /// Quick add: pinwall note option
  ///
  /// In en, this message translates to:
  /// **'Pin a note'**
  String get hubQuickAddNote;

  /// Quick add: new list option
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get hubQuickAddList;

  /// Activity wall section title
  ///
  /// In en, this message translates to:
  /// **'Activity'**
  String get hubActivityTitle;

  /// Activity wall empty state
  ///
  /// In en, this message translates to:
  /// **'Nothing happening yet.\nActivity from your household will appear here.'**
  String get hubActivityEmpty;

  /// Activity wall load error
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load activity. Pull to refresh on the hub.'**
  String get hubActivityError;

  /// Onboarding card: swap tile
  ///
  /// In en, this message translates to:
  /// **'Swap'**
  String get hubOnboardingSwap;

  /// Onboarding card: settle tile
  ///
  /// In en, this message translates to:
  /// **'Settle'**
  String get hubOnboardingSettle;

  /// Onboarding card: done tile
  ///
  /// In en, this message translates to:
  /// **'All done'**
  String get hubOnboardingDone;

  /// Swap tile description
  ///
  /// In en, this message translates to:
  /// **'Pick a flatmate who owes the least to take over this chore.'**
  String get hubOnboardingSwapDesc;

  /// Settle tile description
  ///
  /// In en, this message translates to:
  /// **'Pay everyone back all at once with suggested settlements.'**
  String get hubOnboardingSettleDesc;

  /// Done tile description
  ///
  /// In en, this message translates to:
  /// **'Chores, balances, lists — everything in one place, accounted for.'**
  String get hubOnboardingDoneDesc;

  /// Semantic label for bottom sheet drag handle
  ///
  /// In en, this message translates to:
  /// **'Handle'**
  String get appBottomSheetHandle;

  /// Semantic label for bottom sheet close
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get appBottomSheetClose;

  /// Store picker sheet title
  ///
  /// In en, this message translates to:
  /// **'Choose store'**
  String get storePickerTitle;

  /// Store search label
  ///
  /// In en, this message translates to:
  /// **'Search stores'**
  String get storePickerSearchLabel;

  /// Store search hint
  ///
  /// In en, this message translates to:
  /// **'Name...'**
  String get storePickerSearchHint;

  /// No store search results
  ///
  /// In en, this message translates to:
  /// **'No stores match your search.'**
  String get storePickerNoMatch;

  /// No store option
  ///
  /// In en, this message translates to:
  /// **'No store'**
  String get storePickerNoStore;

  /// No store option description
  ///
  /// In en, this message translates to:
  /// **'Sort by category instead of a store layout'**
  String get storePickerNoStoreDesc;

  /// Store picker load error
  ///
  /// In en, this message translates to:
  /// **'Couldn’t load stores.'**
  String get storePickerLoadError;

  /// Smart capture launcher review title
  ///
  /// In en, this message translates to:
  /// **'Check photo'**
  String get smartCaptureLaunchTitle;

  /// Quick add: add to list option
  ///
  /// In en, this message translates to:
  /// **'Add to a list'**
  String get hubQuickAddToList;

  /// Quick add: shopping trip option
  ///
  /// In en, this message translates to:
  /// **'Start shopping trip'**
  String get hubQuickAddShoppingTrip;

  /// Onboarding card header
  ///
  /// In en, this message translates to:
  /// **'Get started'**
  String get hubOnboardingGetStarted;

  /// Dismiss quick start tooltip
  ///
  /// In en, this message translates to:
  /// **'Dismiss quick start'**
  String get hubOnboardingDismiss;

  /// Onboarding card description
  ///
  /// In en, this message translates to:
  /// **'Everything starts here. Pick what matters most.'**
  String get hubOnboardingDescription;

  /// Invite flatmates action
  ///
  /// In en, this message translates to:
  /// **'Invite flatmates'**
  String get hubOnboardingInvite;

  /// Create a list action
  ///
  /// In en, this message translates to:
  /// **'Create a list'**
  String get hubOnboardingCreateList;

  /// Add a chore action
  ///
  /// In en, this message translates to:
  /// **'Add a chore'**
  String get hubOnboardingAddChore;

  /// Track an expense action
  ///
  /// In en, this message translates to:
  /// **'Track an expense'**
  String get hubOnboardingTrackExpense;

  /// Discard changes dialog title
  ///
  /// In en, this message translates to:
  /// **'Discard changes?'**
  String get appBottomSheetDiscardTitle;

  /// Discard changes dialog body
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes.'**
  String get appBottomSheetDiscardBody;

  /// Keep editing button
  ///
  /// In en, this message translates to:
  /// **'Keep editing'**
  String get appBottomSheetKeepEditing;

  /// Sheet title for expense detail
  ///
  /// In en, this message translates to:
  /// **'Expense details'**
  String get sheetExpenseDetailTitle;

  /// Section header: split details
  ///
  /// In en, this message translates to:
  /// **'Splits'**
  String get sheetExpenseDetailSplits;

  /// Split count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{{count} split} other{{count} splits}}'**
  String sheetExpenseDetailSplitsCount(num count);

  /// Settlement confirmation dialog title
  ///
  /// In en, this message translates to:
  /// **'Record settlement'**
  String get sheetSettlementTitle;

  /// Party label: from
  ///
  /// In en, this message translates to:
  /// **'From'**
  String get sheetSettlementFrom;

  /// Party label: to
  ///
  /// In en, this message translates to:
  /// **'To'**
  String get sheetSettlementTo;

  /// Settlement helper text
  ///
  /// In en, this message translates to:
  /// **'Record this settlement after the payment is made.'**
  String get sheetSettlementRecordPayment;

  /// Confirm settlement button
  ///
  /// In en, this message translates to:
  /// **'Confirm settlement'**
  String get sheetSettlementConfirm;

  /// Sheet title for group settings
  ///
  /// In en, this message translates to:
  /// **'Household settings'**
  String get sheetGroupSettingsTitle;

  /// Name input label
  ///
  /// In en, this message translates to:
  /// **'Household name'**
  String get sheetGroupSettingsName;

  /// Snackbar when settings are saved
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get sheetGroupSettingsSaved;

  /// Error when saving fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t save settings.'**
  String get sheetGroupSettingsCouldNotSave;

  /// Button to leave household
  ///
  /// In en, this message translates to:
  /// **'Leave household'**
  String get sheetGroupSettingsLeave;

  /// Confirmation for leaving household
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to leave this household? All your data will be retained by the household.'**
  String get sheetGroupSettingsLeaveConfirm;

  /// Confirm leave action
  ///
  /// In en, this message translates to:
  /// **'Leave'**
  String get sheetGroupSettingsLeaveAction;

  /// Button to delete household
  ///
  /// In en, this message translates to:
  /// **'Delete household'**
  String get sheetGroupSettingsDelete;

  /// Confirmation for deleting household
  ///
  /// In en, this message translates to:
  /// **'This will permanently delete this household and all associated data. This cannot be undone.'**
  String get sheetGroupSettingsDeleteConfirm;

  /// Sheet title for adding recipe ingredients to list
  ///
  /// In en, this message translates to:
  /// **'Add to list'**
  String get sheetRecipeAddToListTitle;

  /// Snackbar when ingredients are added
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 item added} other{{count} items added}}'**
  String sheetRecipeAddToListAdded(num count);

  /// Error when adding ingredients fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t add ingredients.'**
  String get sheetRecipeAddToListCouldNotAdd;

  /// Sheet title for joining a household
  ///
  /// In en, this message translates to:
  /// **'Join household'**
  String get sheetJoinTitle;

  /// Invite code input label
  ///
  /// In en, this message translates to:
  /// **'Invite code'**
  String get sheetJoinCodeLabel;

  /// Invite code placeholder
  ///
  /// In en, this message translates to:
  /// **'Paste invite code'**
  String get sheetJoinCodeHint;

  /// Join button
  ///
  /// In en, this message translates to:
  /// **'Join'**
  String get sheetJoinJoin;

  /// Button that fills the invite code from the clipboard
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get joinPasteButton;

  /// Confirmation shown after pasting a valid invite code
  ///
  /// In en, this message translates to:
  /// **'Invite code pasted'**
  String get joinPasteFilled;

  /// Shown when the clipboard has no usable invite code
  ///
  /// In en, this message translates to:
  /// **'No invite code or link found on your clipboard'**
  String get joinPasteNoCode;

  /// Sheet title for creating a household
  ///
  /// In en, this message translates to:
  /// **'Create household'**
  String get sheetCreateHouseholdTitle;

  /// Name input label
  ///
  /// In en, this message translates to:
  /// **'Household name'**
  String get sheetCreateHouseholdName;

  /// Name placeholder
  ///
  /// In en, this message translates to:
  /// **'e.g. Flat 4B'**
  String get sheetCreateHouseholdNameHint;

  /// Sheet title for inviting to household
  ///
  /// In en, this message translates to:
  /// **'Invite to household'**
  String get sheetInviteTitle;

  /// Copy invite link button
  ///
  /// In en, this message translates to:
  /// **'Copy link'**
  String get sheetInviteCopy;

  /// Snackbar when link is copied
  ///
  /// In en, this message translates to:
  /// **'Invite link copied'**
  String get sheetInviteCopied;

  /// Share invite link button
  ///
  /// In en, this message translates to:
  /// **'Share link'**
  String get sheetInviteShare;

  /// Sheet title for creating a list
  ///
  /// In en, this message translates to:
  /// **'New list'**
  String get sheetCreateListTitle;

  /// Name input label
  ///
  /// In en, this message translates to:
  /// **'List name'**
  String get sheetCreateListName;

  /// Name placeholder
  ///
  /// In en, this message translates to:
  /// **'e.g. Weekly groceries'**
  String get sheetCreateListNameHint;

  /// List type selector label
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get sheetCreateListType;

  /// Type option: shopping list
  ///
  /// In en, this message translates to:
  /// **'Shopping'**
  String get sheetCreateListTypeShopping;

  /// Type option: to-do list
  ///
  /// In en, this message translates to:
  /// **'To-do'**
  String get sheetCreateListTypeTodo;

  /// Type option: custom list
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get sheetCreateListTypeCustom;

  /// Create list button
  ///
  /// In en, this message translates to:
  /// **'Create list'**
  String get sheetCreateListCreate;

  /// Sheet title for list cost summary
  ///
  /// In en, this message translates to:
  /// **'Cost summary'**
  String get sheetCostSummaryTitle;

  /// Total cost label
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get sheetCostSummaryTotal;

  /// Conflict resolution sheet title
  ///
  /// In en, this message translates to:
  /// **'Sync conflict'**
  String get sheetConflictTitle;

  /// Conflict resolution description
  ///
  /// In en, this message translates to:
  /// **'This item was changed on another device while you were editing. Choose which version to keep.'**
  String get sheetConflictDescription;

  /// Local version label
  ///
  /// In en, this message translates to:
  /// **'Your version'**
  String get sheetConflictLocal;

  /// Server version label
  ///
  /// In en, this message translates to:
  /// **'Server version'**
  String get sheetConflictServer;

  /// Button to keep local version
  ///
  /// In en, this message translates to:
  /// **'Keep yours'**
  String get sheetConflictKeepLocal;

  /// Button to keep server version
  ///
  /// In en, this message translates to:
  /// **'Keep server'**
  String get sheetConflictKeepServer;

  /// Sheet title for failed outbox changes
  ///
  /// In en, this message translates to:
  /// **'Failed changes'**
  String get sheetFailedChangesTitle;

  /// Failed changes description
  ///
  /// In en, this message translates to:
  /// **'These changes couldn\'t be saved. You can retry or discard them.'**
  String get sheetFailedChangesDescription;

  /// Retry all failed changes
  ///
  /// In en, this message translates to:
  /// **'Retry all'**
  String get sheetFailedChangesRetryAll;

  /// Discard all failed changes
  ///
  /// In en, this message translates to:
  /// **'Discard all'**
  String get sheetFailedChangesDiscardAll;

  /// Discard single failed change
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get sheetFailedChangesDiscard;

  /// Retry single failed change
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get sheetFailedChangesRetry;

  /// Empty state when no failed outbox changes
  ///
  /// In en, this message translates to:
  /// **'No failed changes. Everything is synced or waiting to retry.'**
  String get sheetFailedChangesEmpty;

  /// Outbox op label: create item
  ///
  /// In en, this message translates to:
  /// **'Add item'**
  String get sheetFailedChangesOpAddItem;

  /// Outbox op label: update item
  ///
  /// In en, this message translates to:
  /// **'Update item'**
  String get sheetFailedChangesOpUpdateItem;

  /// Outbox op label: delete item
  ///
  /// In en, this message translates to:
  /// **'Delete item'**
  String get sheetFailedChangesOpDeleteItem;

  /// Outbox op label: reorder items
  ///
  /// In en, this message translates to:
  /// **'Reorder list'**
  String get sheetFailedChangesOpReorderItems;

  /// Outbox op label: create expense
  ///
  /// In en, this message translates to:
  /// **'Add expense'**
  String get sheetFailedChangesOpCreateExpense;

  /// Outbox op label: update expense
  ///
  /// In en, this message translates to:
  /// **'Update expense'**
  String get sheetFailedChangesOpUpdateExpense;

  /// Outbox op label: delete expense
  ///
  /// In en, this message translates to:
  /// **'Delete expense'**
  String get sheetFailedChangesOpDeleteExpense;

  /// Outbox op label: create recipe
  ///
  /// In en, this message translates to:
  /// **'Add recipe'**
  String get sheetFailedChangesOpCreateRecipe;

  /// Outbox op label: update recipe
  ///
  /// In en, this message translates to:
  /// **'Update recipe'**
  String get sheetFailedChangesOpUpdateRecipe;

  /// Outbox op label: delete recipe
  ///
  /// In en, this message translates to:
  /// **'Delete recipe'**
  String get sheetFailedChangesOpDeleteRecipe;

  /// Outbox op label: complete chore
  ///
  /// In en, this message translates to:
  /// **'Complete chore'**
  String get sheetFailedChangesOpCompleteChore;

  /// Outbox op label: skip chore
  ///
  /// In en, this message translates to:
  /// **'Skip chore'**
  String get sheetFailedChangesOpSkipChore;

  /// Outbox op label: reschedule chore
  ///
  /// In en, this message translates to:
  /// **'Reschedule chore'**
  String get sheetFailedChangesOpRescheduleChore;

  /// Outbox op label: undo chore
  ///
  /// In en, this message translates to:
  /// **'Undo chore'**
  String get sheetFailedChangesOpUndoChore;

  /// Outbox op label: create pinwall post
  ///
  /// In en, this message translates to:
  /// **'Post to pinwall'**
  String get sheetFailedChangesOpCreatePinwallPost;

  /// Outbox op label: delete pinwall post
  ///
  /// In en, this message translates to:
  /// **'Delete pinwall post'**
  String get sheetFailedChangesOpDeletePinwallPost;

  /// Outbox op label: unknown change
  ///
  /// In en, this message translates to:
  /// **'Change'**
  String get sheetFailedChangesOpChange;

  /// Snackbar when chore zones are saved
  ///
  /// In en, this message translates to:
  /// **'Chore zones updated'**
  String get sheetGroupSettingsChoreZonesUpdated;

  /// Dialog title for removing a member
  ///
  /// In en, this message translates to:
  /// **'Remove member'**
  String get sheetGroupSettingsRemoveMember;

  /// Confirmation dialog body for removing a member
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from this household?'**
  String sheetGroupSettingsRemoveMemberConfirm(String name);

  /// Snackbar when member is removed
  ///
  /// In en, this message translates to:
  /// **'{name} removed'**
  String sheetGroupSettingsMemberRemoved(String name);

  /// Snackbar when household is deleted
  ///
  /// In en, this message translates to:
  /// **'Household deleted'**
  String get sheetGroupSettingsHouseholdDeleted;

  /// Hint text for household description
  ///
  /// In en, this message translates to:
  /// **'A few words about this household'**
  String get sheetGroupSettingsDescriptionHint;

  /// Section label for chore zones
  ///
  /// In en, this message translates to:
  /// **'Chore zones'**
  String get sheetGroupSettingsChoreZonesLabel;

  /// Description of chore zones
  ///
  /// In en, this message translates to:
  /// **'Areas of your home for grouping chores. They show up when adding a chore.'**
  String get sheetGroupSettingsChoreZonesDesc;

  /// Input label for adding a zone
  ///
  /// In en, this message translates to:
  /// **'Add zone'**
  String get sheetGroupSettingsAddZone;

  /// Placeholder for zone input
  ///
  /// In en, this message translates to:
  /// **'Kitchen, Bathroom…'**
  String get sheetGroupSettingsZoneHint;

  /// Button to save chore zones
  ///
  /// In en, this message translates to:
  /// **'Save zones'**
  String get sheetGroupSettingsSaveZones;

  /// Section label for household members
  ///
  /// In en, this message translates to:
  /// **'Members'**
  String get sheetGroupSettingsMembersLabel;

  /// Button to invite a member
  ///
  /// In en, this message translates to:
  /// **'Invite'**
  String get sheetGroupSettingsInvite;

  /// Tooltip to remove a member
  ///
  /// In en, this message translates to:
  /// **'Remove {name}'**
  String sheetGroupSettingsRemoveMemberTooltip(String name);

  /// Fallback recipe title for tonight card
  ///
  /// In en, this message translates to:
  /// **'Recipe'**
  String get tonightRecipe;

  /// Tonight card section header
  ///
  /// In en, this message translates to:
  /// **'Tonight'**
  String get tonightHeader;

  /// Button to start cooking tonight's meal
  ///
  /// In en, this message translates to:
  /// **'Cook'**
  String get tonightCook;

  /// Empty state when no meal planned for tonight
  ///
  /// In en, this message translates to:
  /// **'Nothing planned for tonight'**
  String get tonightNothingPlanned;

  /// CTA to plan tonight's dinner
  ///
  /// In en, this message translates to:
  /// **'Plan dinner'**
  String get tonightPlanDinner;

  /// Activity: item added to list
  ///
  /// In en, this message translates to:
  /// **'Added {name} to a list · {when}'**
  String activityAddedToList(String name, String when);

  /// Activity: item added to a named list
  ///
  /// In en, this message translates to:
  /// **'Added {name} to {list} · {when}'**
  String activityAddedToNamedList(String name, String list, String when);

  /// Activity: generic item added to list
  ///
  /// In en, this message translates to:
  /// **'Added an item to a list · {when}'**
  String activityAddedItemToList(String when);

  /// Activity: expense logged
  ///
  /// In en, this message translates to:
  /// **'Logged {name} · {when}'**
  String activityLoggedExpense(String name, String when);

  /// Activity: generic expense logged
  ///
  /// In en, this message translates to:
  /// **'Logged an expense · {when}'**
  String activityLoggedExpenseGeneric(String when);

  /// Activity: chore completed
  ///
  /// In en, this message translates to:
  /// **'Completed {name} · {when}'**
  String activityCompletedChore(String name, String when);

  /// Activity: generic chore completed
  ///
  /// In en, this message translates to:
  /// **'Completed a chore · {when}'**
  String activityCompletedChoreGeneric(String when);

  /// Activity: recipe saved
  ///
  /// In en, this message translates to:
  /// **'Saved {name} · {when}'**
  String activitySavedRecipe(String name, String when);

  /// Activity: generic recipe saved
  ///
  /// In en, this message translates to:
  /// **'Saved a recipe · {when}'**
  String activitySavedRecipeGeneric(String when);

  /// Activity: meal planned
  ///
  /// In en, this message translates to:
  /// **'Planned {name} · {when}'**
  String activityPlannedMeal(String name, String when);

  /// Activity: meal plan updated
  ///
  /// In en, this message translates to:
  /// **'Updated meal plan · {when}'**
  String activityUpdatedMealPlan(String when);

  /// Display name for current user in activity feed
  ///
  /// In en, this message translates to:
  /// **'You'**
  String get activityYou;

  /// Fallback display name for household member
  ///
  /// In en, this message translates to:
  /// **'Member'**
  String get activityMember;

  /// Shared invite link message
  ///
  /// In en, this message translates to:
  /// **'Join my household on mitlist!\nTap: {link}\nOr open mitlist and enter the code: {code}'**
  String inviteLinkShareText(String link, String code);

  /// Error boundary fallback title
  ///
  /// In en, this message translates to:
  /// **'Something went wrong'**
  String get errorBoundaryTitle;

  /// Error boundary fallback description
  ///
  /// In en, this message translates to:
  /// **'We hit an unexpected error. Please try again.'**
  String get errorBoundaryDesc;

  /// Tomorrow label in recurring expenses date helper
  ///
  /// In en, this message translates to:
  /// **'Tomorrow'**
  String get recurringTomorrow;

  /// Error when updating recurring expense fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t update recurring expense.'**
  String get recurringCouldNotUpdate;

  /// Error when deleting recurring expense fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t delete recurring expense.'**
  String get recurringCouldNotDelete;

  /// Error when creating recurring expense fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t create recurring expense.'**
  String get recurringCouldNotCreate;

  /// Empty state when no lists available to add ingredients to
  ///
  /// In en, this message translates to:
  /// **'No lists'**
  String get recipeAddToListNoLists;

  /// Prompt to create a list before adding ingredients
  ///
  /// In en, this message translates to:
  /// **'Create a list first to add ingredients'**
  String get recipeAddToListCreateListFirst;

  /// Empty state when no items in cost summary have prices
  ///
  /// In en, this message translates to:
  /// **'No items have prices yet. Open the item options (⋯) and choose Set price to see the cost summary.'**
  String get costSummaryNoPrices;

  /// Placeholder when equal share cannot be calculated
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get costSummaryNotAvailable;

  /// Label for equal share amount in cost summary
  ///
  /// In en, this message translates to:
  /// **'Equal share per person'**
  String get costSummaryEqualShare;

  /// Label for items that have prices set
  ///
  /// In en, this message translates to:
  /// **'Items with prices'**
  String get costSummaryItemsWithPrices;

  /// Placeholder when no value is set
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get costSummaryNone;

  /// Button to generate an expense from cost summary
  ///
  /// In en, this message translates to:
  /// **'Generate expense'**
  String get costSummaryGenerateExpense;

  /// Snackbar when scan completes
  ///
  /// In en, this message translates to:
  /// **'Scan finished'**
  String get createListScanFinished;

  /// Snackbar after scanning into a list
  ///
  /// In en, this message translates to:
  /// **'Scanned \"{name}\"'**
  String createListScanned(String name);

  /// Description for shopping list type
  ///
  /// In en, this message translates to:
  /// **'Best for groceries and errands with quantities.'**
  String get createListShoppingDesc;

  /// Validation: list name required
  ///
  /// In en, this message translates to:
  /// **'List name is required'**
  String get createListNameRequired;

  /// Snackbar when list is created
  ///
  /// In en, this message translates to:
  /// **'List created'**
  String get createListCreated;

  /// Button text to scan a recipe
  ///
  /// In en, this message translates to:
  /// **'Scan recipe'**
  String get recipeCreationScanRecipe;

  /// Semantics label for scanning a recipe
  ///
  /// In en, this message translates to:
  /// **'Scan recipe via camera'**
  String get recipeCreationScanRecipeViaCamera;

  /// Hint text describing invite code format
  ///
  /// In en, this message translates to:
  /// **'Codes look like WORD-WORD-42. Ask whoever invited you.'**
  String get joinCodeFormatHint;

  /// Semantics label to enter a household
  ///
  /// In en, this message translates to:
  /// **'Enter {name}'**
  String joinEnterGroup(String name);

  /// Label displaying the invite code
  ///
  /// In en, this message translates to:
  /// **'Invite code: {code}'**
  String inviteCodeLabel(String code);

  /// Title for invite QR code section
  ///
  /// In en, this message translates to:
  /// **'Household invite QR code'**
  String get inviteQrTitle;

  /// Semantics label for invite QR code
  ///
  /// In en, this message translates to:
  /// **'Household invite QR'**
  String get inviteQrSemantic;

  /// Hint for invite QR code
  ///
  /// In en, this message translates to:
  /// **'Scan with a phone camera to join, or share the code below.'**
  String get inviteQrHint;

  /// Text shown while generating invite code
  ///
  /// In en, this message translates to:
  /// **'Generating…'**
  String get inviteGenerating;

  /// Button to generate a new invite code
  ///
  /// In en, this message translates to:
  /// **'New code'**
  String get inviteNewCode;

  /// Snackbar when household is created
  ///
  /// In en, this message translates to:
  /// **'Household created'**
  String get createHouseholdCreated;

  /// Placeholder for optional household description
  ///
  /// In en, this message translates to:
  /// **'Description (optional)'**
  String get createHouseholdDescriptionOptional;

  /// Empty state when no sync conflicts
  ///
  /// In en, this message translates to:
  /// **'No conflicts to resolve.'**
  String get conflictNoneToResolve;

  /// Snackbar when conflict item was changed
  ///
  /// In en, this message translates to:
  /// **'Item changed'**
  String get conflictItemChanged;

  /// Label for conflict item name
  ///
  /// In en, this message translates to:
  /// **'Item: {name}'**
  String conflictItemLabel(String name);

  /// Error when AI image analysis fails in scanner
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t analyze the image. Please try again with a clearer photo.'**
  String get scannerCouldNotAnalyze;

  /// Error when OAuth callback has missing params
  ///
  /// In en, this message translates to:
  /// **'Missing OAuth callback parameters.'**
  String get oauthMissingParams;

  /// Loading text while signing in via OAuth
  ///
  /// In en, this message translates to:
  /// **'Signing you in'**
  String get oauthSigningYouIn;

  /// Validation: shares must not be negative
  ///
  /// In en, this message translates to:
  /// **'Shares can\'t be negative.'**
  String get expenseCreationSharesNegative;

  /// Validation: assign at least one share
  ///
  /// In en, this message translates to:
  /// **'Assign at least one share.'**
  String get expenseCreationAssignShare;

  /// Error when household members fail to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load household members.'**
  String get expenseCreationCouldNotLoadMembers;

  /// Prompt when no household for expense split
  ///
  /// In en, this message translates to:
  /// **'Join or create a household to split this expense.'**
  String get expenseCreationJoinHouseholdSplit;

  /// Checkbox label for adding/removing splitters
  ///
  /// In en, this message translates to:
  /// **'Remove/Add {name} from/to split'**
  String expenseCreationRemoveAddSplitter(String name);

  /// Error when receipt image fails to load
  ///
  /// In en, this message translates to:
  /// **'Failed to load receipt'**
  String get expenseDetailFailedLoadReceipt;

  /// Label for receipt attachment
  ///
  /// In en, this message translates to:
  /// **'Receipt'**
  String get expenseDetailReceipt;

  /// View action label
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get expenseDetailView;

  /// Empty state when expense has no splits
  ///
  /// In en, this message translates to:
  /// **'This expense isn\'t split yet.'**
  String get expenseDetailNotSplitYet;

  /// Empty state when expense has no receipts
  ///
  /// In en, this message translates to:
  /// **'No receipts attached. Add one when editing the expense.'**
  String get expenseDetailNoReceipts;

  /// Semantics label for linked entity
  ///
  /// In en, this message translates to:
  /// **'Linked to {entity}'**
  String pinwallLinkedTo(String entity);

  /// Generic view button
  ///
  /// In en, this message translates to:
  /// **'View'**
  String get commonView;

  /// Generic photo label
  ///
  /// In en, this message translates to:
  /// **'Photo'**
  String get commonPhoto;

  /// Timer semantics label
  ///
  /// In en, this message translates to:
  /// **'Timer: {label}. Tap to start'**
  String cookModeTimerStart(String label);

  /// Friendly error for 5xx responses
  ///
  /// In en, this message translates to:
  /// **'Server hiccup — try again in a moment.'**
  String get errorServerHiccup;

  /// Friendly error for 409 conflict
  ///
  /// In en, this message translates to:
  /// **'Someone else changed this. Refresh and try again.'**
  String get errorConflict;

  /// Friendly error for 404
  ///
  /// In en, this message translates to:
  /// **'Not found. It may have been deleted.'**
  String get errorNotFound;

  /// Friendly error for 403
  ///
  /// In en, this message translates to:
  /// **'You don\'t have permission for this.'**
  String get errorNoPermission;

  /// Friendly error for 401
  ///
  /// In en, this message translates to:
  /// **'Please sign in again.'**
  String get errorSignInAgain;

  /// Generic fallback friendly error
  ///
  /// In en, this message translates to:
  /// **'Something went wrong. Please try again.'**
  String get errorGenericRetry;

  /// Description for to-do list type
  ///
  /// In en, this message translates to:
  /// **'A simple checklist for tasks that need doing.'**
  String get createListTodoDesc;

  /// Description for custom list type
  ///
  /// In en, this message translates to:
  /// **'A flexible list for anything that does not fit.'**
  String get createListCustomDesc;

  /// Semantics label for scan list button
  ///
  /// In en, this message translates to:
  /// **'Scan list via camera'**
  String get createListScanSemantics;

  /// Household selector label in create list sheet
  ///
  /// In en, this message translates to:
  /// **'Household'**
  String get createListHouseholdLabel;

  /// Empty state when no households exist
  ///
  /// In en, this message translates to:
  /// **'No household available.'**
  String get createListNoHousehold;

  /// Example invite code placeholder
  ///
  /// In en, this message translates to:
  /// **'SUNNY-TACO-42'**
  String get sheetJoinCodeExample;

  /// Member count after joining household
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 member already inside} other{{count} members already inside}}'**
  String joinMembersAlreadyInside(num count);

  /// Error when QR code cannot be rendered
  ///
  /// In en, this message translates to:
  /// **'QR unavailable'**
  String get inviteQrUnavailable;

  /// Split summary: assigned amount of total
  ///
  /// In en, this message translates to:
  /// **'{assigned} of {total}'**
  String expenseCreationSplitAssignedOf(String assigned, String total);

  /// Split validation: negative amounts
  ///
  /// In en, this message translates to:
  /// **'{assigned} · amounts can\'t be negative'**
  String expenseCreationSplitAmountsNegative(String assigned);

  /// Split validation: remaining to assign
  ///
  /// In en, this message translates to:
  /// **'{assigned} · {remaining} left to assign'**
  String expenseCreationSplitLeftToAssign(String assigned, String remaining);

  /// Split validation: over-assigned
  ///
  /// In en, this message translates to:
  /// **'{assigned} · {over} over'**
  String expenseCreationSplitOver(String assigned, String over);

  /// Split validation: percent out of range
  ///
  /// In en, this message translates to:
  /// **'{sum}% assigned · each share must be 0–100%'**
  String expenseCreationSplitPercentRange(String sum);

  /// Split summary: percent of 100
  ///
  /// In en, this message translates to:
  /// **'{sum}% of 100%'**
  String expenseCreationSplitPercentOf100(String sum);

  /// Split summary: shares mode
  ///
  /// In en, this message translates to:
  /// **'{count} shares · {perShare} per share'**
  String expenseCreationSplitSharesPerShare(num count, String perShare);

  /// Equal split per person
  ///
  /// In en, this message translates to:
  /// **'{amount} each'**
  String expenseCreationSplitEach(String amount);

  /// Approximate equal split per person
  ///
  /// In en, this message translates to:
  /// **'≈ {amount} each'**
  String expenseCreationSplitApproxEach(String amount);

  /// Semantics: remove member from split
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from split'**
  String expenseCreationRemoveFromSplit(String name);

  /// Semantics: add member to split
  ///
  /// In en, this message translates to:
  /// **'Add {name} to split'**
  String expenseCreationAddToSplit(String name);

  /// Snackbar when expense splits fail to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load splits.'**
  String get expenseDetailCouldNotLoadSplits;

  /// Snackbar when expense receipts fail to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load receipts.'**
  String get expenseDetailCouldNotLoadReceipts;

  /// Snackbar when receipt removal fails
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t remove receipt.'**
  String get expenseDetailCouldNotRemoveReceipt;

  /// Label while removing receipt
  ///
  /// In en, this message translates to:
  /// **'Removing…'**
  String get expenseDetailRemoving;

  /// Dropdown label for target list
  ///
  /// In en, this message translates to:
  /// **'Target list'**
  String get recipeAddToListTargetList;

  /// Empty state when recipe has no ingredients
  ///
  /// In en, this message translates to:
  /// **'No ingredients'**
  String get recipeAddToListNoIngredients;

  /// Description when recipe has no ingredients
  ///
  /// In en, this message translates to:
  /// **'This recipe has no parsed ingredients'**
  String get recipeAddToListNoIngredientsDesc;

  /// Semantics: deselect ingredient
  ///
  /// In en, this message translates to:
  /// **'Remove {name} from selection'**
  String recipeAddToListRemoveFromSelection(String name);

  /// Semantics: select ingredient
  ///
  /// In en, this message translates to:
  /// **'Add {name} to selection'**
  String recipeAddToListAddToSelection(String name);

  /// Link action: link a chore
  ///
  /// In en, this message translates to:
  /// **'A chore'**
  String get pinwallLinkChore;

  /// Link action: link a list
  ///
  /// In en, this message translates to:
  /// **'A list'**
  String get pinwallLinkList;

  /// Error when pinwall posts fail to load
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load the pinwall.'**
  String get pinwallCouldNotLoad;

  /// Hint for list composer input
  ///
  /// In en, this message translates to:
  /// **'e.g. Milk, 2 avocados, or 500g flour'**
  String get composerItemHint;

  /// Fallback aisle name for uncategorized items
  ///
  /// In en, this message translates to:
  /// **'Other'**
  String get aisleOther;

  /// Semantics label for household switcher
  ///
  /// In en, this message translates to:
  /// **'Households, current {name}'**
  String hubHouseholdsCurrent(String name);

  /// Semantics label for recipe step count
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 step} other{{count} steps}}'**
  String recipeDetailStepCount(num count);

  /// US Dollar currency label
  ///
  /// In en, this message translates to:
  /// **'USD - US Dollar'**
  String get currencyUsd;

  /// Euro currency label
  ///
  /// In en, this message translates to:
  /// **'EUR - Euro'**
  String get currencyEur;

  /// British Pound currency label
  ///
  /// In en, this message translates to:
  /// **'GBP - British Pound'**
  String get currencyGbp;

  /// Japanese Yen currency label
  ///
  /// In en, this message translates to:
  /// **'JPY - Japanese Yen'**
  String get currencyJpy;

  /// Canadian Dollar currency label
  ///
  /// In en, this message translates to:
  /// **'CAD - Canadian Dollar'**
  String get currencyCad;

  /// Australian Dollar currency label
  ///
  /// In en, this message translates to:
  /// **'AUD - Australian Dollar'**
  String get currencyAud;

  /// Swiss Franc currency label
  ///
  /// In en, this message translates to:
  /// **'CHF - Swiss Franc'**
  String get currencyChf;

  /// Swedish Krona currency label
  ///
  /// In en, this message translates to:
  /// **'SEK - Swedish Krona'**
  String get currencySek;

  /// Norwegian Krone currency label
  ///
  /// In en, this message translates to:
  /// **'NOK - Norwegian Krone'**
  String get currencyNok;

  /// Danish Krone currency label
  ///
  /// In en, this message translates to:
  /// **'DKK - Danish Krone'**
  String get currencyDkk;

  /// Polish Zloty currency label
  ///
  /// In en, this message translates to:
  /// **'PLN - Polish Zloty'**
  String get currencyPln;

  /// Czech Koruna currency label
  ///
  /// In en, this message translates to:
  /// **'CZK - Czech Koruna'**
  String get currencyCzk;

  /// Hungarian Forint currency label
  ///
  /// In en, this message translates to:
  /// **'HUF - Hungarian Forint'**
  String get currencyHuf;

  /// Section header for the restock suggestion strip above the list
  ///
  /// In en, this message translates to:
  /// **'Running low'**
  String get runningLowHeading;

  /// Per-chip cadence hint showing how many days since last purchase
  ///
  /// In en, this message translates to:
  /// **'{days}d ago'**
  String runningLowDaysAgo(num days);

  /// Household settings storage section title
  ///
  /// In en, this message translates to:
  /// **'Household storage'**
  String get householdStorageTitle;

  /// Household attachment storage usage
  ///
  /// In en, this message translates to:
  /// **'{used} of {limit} used'**
  String householdStorageUsedOf(String used, String limit);

  /// Household attachment storage usage when quota is disabled
  ///
  /// In en, this message translates to:
  /// **'{used} used · no limit'**
  String householdStorageUsedUnlimited(String used);

  /// Pending household upload reservation
  ///
  /// In en, this message translates to:
  /// **'{pending} is reserved by uploads in progress.'**
  String householdStoragePending(String pending);

  /// Accessibility label for storage usage progress
  ///
  /// In en, this message translates to:
  /// **'Household storage used'**
  String get householdStorageProgressLabel;

  /// Account screen row that opens the feedback sheet
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get accountSendFeedback;

  /// Title of the promoted feedback card on the account screen
  ///
  /// In en, this message translates to:
  /// **'Help shape mitlist'**
  String get feedbackCardTitle;

  /// Body of the promoted feedback card on the account screen
  ///
  /// In en, this message translates to:
  /// **'Request a feature, report a bug, or share an idea — it goes straight to the team.'**
  String get feedbackCardBody;

  /// Title of the feedback bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Send feedback'**
  String get feedbackSheetTitle;

  /// Intro text of the feedback bottom sheet
  ///
  /// In en, this message translates to:
  /// **'Request a feature, report a bug, or tell us what could work better — we read every message.'**
  String get feedbackSheetIntro;

  /// Label of the feedback message field
  ///
  /// In en, this message translates to:
  /// **'Your message'**
  String get feedbackFieldLabel;

  /// Hint of the feedback message field
  ///
  /// In en, this message translates to:
  /// **'I wish mitlist could…'**
  String get feedbackFieldHint;

  /// Feedback sheet submit button
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get feedbackSend;

  /// Feedback sheet submit button while sending
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get feedbackSending;

  /// Snackbar after a feedback submission succeeded
  ///
  /// In en, this message translates to:
  /// **'Thanks — your request was sent!'**
  String get feedbackSent;

  /// Validation error when the feedback field is empty
  ///
  /// In en, this message translates to:
  /// **'Please write a short message first.'**
  String get feedbackEmpty;

  /// Error when the feedback submission failed
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t send your request right now. Please try again later.'**
  String get feedbackFailed;

  /// Opt-in local OCR training-data collection title
  ///
  /// In en, this message translates to:
  /// **'Improve offline handwriting OCR'**
  String get accountOcrTrainingTitle;

  /// Privacy explanation for OCR training-data collection
  ///
  /// In en, this message translates to:
  /// **'Manually reviewed line crops stay on this device until you export or delete them. Nothing is uploaded.'**
  String get accountOcrTrainingDescription;

  /// Exports local corrected OCR line crops
  ///
  /// In en, this message translates to:
  /// **'Export OCR training data'**
  String get accountOcrTrainingExport;

  /// Number of locally collected OCR training lines
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No corrected lines} =1{1 corrected line} other{{count} corrected lines}}'**
  String accountOcrTrainingSamples(int count);

  /// Deletes locally collected OCR training data
  ///
  /// In en, this message translates to:
  /// **'Delete OCR training data'**
  String get accountOcrTrainingClear;

  /// Shown when OCR training export is empty
  ///
  /// In en, this message translates to:
  /// **'There are no corrected OCR lines to export yet.'**
  String get accountOcrTrainingExportEmpty;

  /// OCR training data deletion dialog title
  ///
  /// In en, this message translates to:
  /// **'Delete OCR training data?'**
  String get accountOcrTrainingClearTitle;

  /// OCR training data deletion dialog body
  ///
  /// In en, this message translates to:
  /// **'This permanently removes every saved line crop from this device.'**
  String get accountOcrTrainingClearBody;

  /// Title of the premium paywall sheet
  ///
  /// In en, this message translates to:
  /// **'mitlist premium'**
  String get billingPremiumTitle;

  /// Paywall title when a household hit the free member limit
  ///
  /// In en, this message translates to:
  /// **'This household is full'**
  String get billingLimitReachedTitle;

  /// Paywall explanation of the free member limit
  ///
  /// In en, this message translates to:
  /// **'Households of up to {limit} people are free. To add a {next}th member, one person needs premium — and it covers everyone here.'**
  String billingLimitReachedBody(num limit, num next);

  /// Explains the single-household (primary) model
  ///
  /// In en, this message translates to:
  /// **'Premium applies to one household at a time. You choose which, and you can move it whenever you like.'**
  String get billingCoversOneHousehold;

  /// Shown when another member's subscription covers this household
  ///
  /// In en, this message translates to:
  /// **'Premium on this household, paid by {name}.'**
  String billingCoveredBy(String name);

  /// Status line when the current household is premium
  ///
  /// In en, this message translates to:
  /// **'Premium is active here'**
  String get billingPremiumActive;

  /// Title of the move-premium action
  ///
  /// In en, this message translates to:
  /// **'Move your premium here'**
  String get billingMoveHereTitle;

  /// Explains moving premium between households
  ///
  /// In en, this message translates to:
  /// **'You already have premium on another household. Move it here instead of paying twice — the other household keeps everyone it already has, it just can\'t add more.'**
  String get billingMoveHereBody;

  /// Button that reassigns the subscription to this household
  ///
  /// In en, this message translates to:
  /// **'Move premium here'**
  String get billingMoveHereAction;

  /// Confirmation after moving premium
  ///
  /// In en, this message translates to:
  /// **'Premium now covers this household.'**
  String get billingMoved;

  /// Error after a failed premium move
  ///
  /// In en, this message translates to:
  /// **'Could not move your premium. Please try again.'**
  String get billingMoveFailed;

  /// Prompt when a subscriber has not picked a household yet
  ///
  /// In en, this message translates to:
  /// **'Choose your premium household'**
  String get billingChooseHousehold;

  /// Monthly billing interval option
  ///
  /// In en, this message translates to:
  /// **'Monthly'**
  String get billingMonthly;

  /// Yearly billing interval option
  ///
  /// In en, this message translates to:
  /// **'Yearly'**
  String get billingYearly;

  /// Badge highlighting the yearly plan
  ///
  /// In en, this message translates to:
  /// **'Best value'**
  String get billingYearlyBadge;

  /// Button that starts checkout
  ///
  /// In en, this message translates to:
  /// **'Get premium'**
  String get billingSubscribe;

  /// Loading label while the checkout URL is fetched
  ///
  /// In en, this message translates to:
  /// **'Opening checkout...'**
  String get billingOpeningCheckout;

  /// Error when checkout cannot be started
  ///
  /// In en, this message translates to:
  /// **'Could not start checkout. Please try again.'**
  String get billingCheckoutFailed;

  /// Opens the provider's billing portal
  ///
  /// In en, this message translates to:
  /// **'Manage subscription'**
  String get billingManage;

  /// Error when the billing portal cannot be opened
  ///
  /// In en, this message translates to:
  /// **'Could not open the billing portal.'**
  String get billingPortalFailed;

  /// Tells the user checkout continues in a browser
  ///
  /// In en, this message translates to:
  /// **'Finish in your browser, then come back — premium activates automatically.'**
  String get billingReturnHint;

  /// Title of the billing card on the account screen
  ///
  /// In en, this message translates to:
  /// **'Premium'**
  String get billingAccountCardTitle;

  /// Account card body for a non-subscriber
  ///
  /// In en, this message translates to:
  /// **'You\'re on the free plan. Households of up to {limit} people are free.'**
  String billingAccountCardFree(num limit);

  /// Account card body naming the covered household
  ///
  /// In en, this message translates to:
  /// **'Premium is active on {household}.'**
  String billingAccountCardActive(String household);

  /// Account card body when no household is chosen
  ///
  /// In en, this message translates to:
  /// **'Premium is active but not assigned to a household yet.'**
  String get billingAccountCardUnassigned;

  /// Next renewal date
  ///
  /// In en, this message translates to:
  /// **'Renews {date}'**
  String billingRenewsOn(String date);

  /// End date for a subscription set to cancel
  ///
  /// In en, this message translates to:
  /// **'Ends {date}'**
  String billingEndsOn(String date);

  /// Member count against the free limit
  ///
  /// In en, this message translates to:
  /// **'{count} of {limit} free places used'**
  String billingMemberUsage(num count, num limit);

  /// Member allowance for a premium household
  ///
  /// In en, this message translates to:
  /// **'Unlimited members'**
  String get billingUnlimitedMembers;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['de', 'en', 'es', 'fr', 'nl'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'de':
      return AppLocalizationsDe();
    case 'en':
      return AppLocalizationsEn();
    case 'es':
      return AppLocalizationsEs();
    case 'fr':
      return AppLocalizationsFr();
    case 'nl':
      return AppLocalizationsNl();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
