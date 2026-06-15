import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/notification_models.dart';
import '../../providers/group_provider.dart';
import '../../providers/notification_provider.dart';
import '../../theme/spacing.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/skeleton.dart';
import '../../l10n/app_localizations.dart';

class NotificationPreferencesScreen extends ConsumerStatefulWidget {
  const NotificationPreferencesScreen({super.key});

  @override
  ConsumerState<NotificationPreferencesScreen> createState() =>
      _NotificationPreferencesScreenState();
}

class _NotificationPreferencesScreenState
    extends ConsumerState<NotificationPreferencesScreen> {
  bool _isLoading = true;
  bool _hasHousehold = true;
  String? _error;
  List<NotificationPreferenceModel> _preferences = [];
  Map<String, String> _groupNames = {};
  final Map<String, bool> _savingKeys = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final groups = await ref.read(cachedGroupsProvider.future);
      if (!mounted) return;
      if (groups.isEmpty) {
        setState(() {
          _hasHousehold = false;
          _isLoading = false;
        });
        return;
      }

      final notificationService =
          await ref.read(notificationServiceProviderAsync.future);

      final prefs = await notificationService.getPreferences();
      if (!mounted) return;

      final names = <String, String>{};
      for (final g in groups) {
        names[g.id] = g.name;
      }

      setState(() {
        _preferences = prefs;
        _groupNames = names;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = l10n.notifPrefFailedLoad;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggle(String preferenceId, String field, bool value) async {
    final key = '$preferenceId:$field';
    setState(() => _savingKeys[key] = true);

    try {
      final service =
          await ref.read(notificationServiceProviderAsync.future);
      final idx = _preferences.indexWhere((p) => p.id == preferenceId);
      if (idx < 0) return;

      final pref = _preferences[idx];
      final updated = NotificationPreferenceModel(
        id: pref.id,
        userId: pref.userId,
        groupId: pref.groupId,
        choreDue: field == 'chore_due' ? value : pref.choreDue,
        choreDueDayOf:
            field == 'chore_due_day_of' ? value : pref.choreDueDayOf,
        listItemAdded:
            field == 'list_item_added' ? value : pref.listItemAdded,
        expenseCreated:
            field == 'expense_created' ? value : pref.expenseCreated,
        mealPlanChanged:
            field == 'meal_plan_changed' ? value : pref.mealPlanChanged,
        weeklyDigest:
            field == 'weekly_digest' ? value : pref.weeklyDigest,
        pinwallReminder:
            field == 'pinwall_reminder' ? value : pref.pinwallReminder,
        pushEnabled: field == 'push_enabled' ? value : pref.pushEnabled,
      );

      await service.updatePreference(updated);
      if (!mounted) return;
      setState(() {
        _preferences[idx] = updated;
        _savingKeys.remove(key);
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _savingKeys.remove(key));
      unawaited(_load());
    }
  }

  Widget _buildPreferenceCard(NotificationPreferenceModel pref) {
    final l10n = AppLocalizations.of(context)!;
    final groupName =
        _groupNames[pref.groupId] ?? l10n.notifPrefGroupName;

    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
      child: AppCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_groupNames.length > 1)
              Padding(
                padding:
                    const EdgeInsets.only(bottom: MitlistSpacing.sm),
                child: Text(
                  groupName,
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                      ),
                ),
              ),
            _ToggleRow(
              icon: 'bell',
              label: l10n.notifPrefChoreDueReminders,
              subtitle: l10n.notifPrefChoreDueRemindersDesc,
              value: pref.choreDue,
              saving: _savingKeys['${pref.id}:chore_due'] == true,
              onChanged: (v) => _toggle(pref.id, 'chore_due', v),
            ),
            _ToggleRow(
              icon: 'calendarDays',
              label: l10n.notifPrefChoreDueDayOf,
              subtitle: l10n.notifPrefChoreDueDayOfDesc,
              value: pref.choreDueDayOf,
              saving:
                  _savingKeys['${pref.id}:chore_due_day_of'] == true,
              onChanged: (v) =>
                  _toggle(pref.id, 'chore_due_day_of', v),
            ),
            _ToggleRow(
              icon: 'clipboardDocumentList',
              label: l10n.notifPrefListItemAdded,
              subtitle: l10n.notifPrefListItemAddedDesc,
              value: pref.listItemAdded,
              saving:
                  _savingKeys['${pref.id}:list_item_added'] == true,
              onChanged: (v) =>
                  _toggle(pref.id, 'list_item_added', v),
            ),
            _ToggleRow(
              icon: 'banknotes',
              label: l10n.notifPrefExpenseCreated,
              subtitle: l10n.notifPrefExpenseCreatedDesc,
              value: pref.expenseCreated,
              saving:
                  _savingKeys['${pref.id}:expense_created'] == true,
              onChanged: (v) =>
                  _toggle(pref.id, 'expense_created', v),
            ),
            _ToggleRow(
              icon: 'calendarDays',
              label: l10n.notifPrefMealPlanChanged,
              subtitle: l10n.notifPrefMealPlanChangedDesc,
              value: pref.mealPlanChanged,
              saving:
                  _savingKeys['${pref.id}:meal_plan_changed'] == true,
              onChanged: (v) =>
                  _toggle(pref.id, 'meal_plan_changed', v),
            ),
            _ToggleRow(
              icon: 'chartBar',
              label: l10n.notifPrefWeeklyDigest,
              subtitle: l10n.notifPrefWeeklyDigestDesc,
              value: pref.weeklyDigest,
              saving:
                  _savingKeys['${pref.id}:weekly_digest'] == true,
              onChanged: (v) =>
                  _toggle(pref.id, 'weekly_digest', v),
            ),
            _ToggleRow(
              icon: 'bell',
              label: l10n.notifPrefPinwallReminders,
              subtitle: l10n.notifPrefPinwallRemindersDesc,
              value: pref.pinwallReminder,
              saving:
                  _savingKeys['${pref.id}:pinwall_reminder'] == true,
              onChanged: (v) =>
                  _toggle(pref.id, 'pinwall_reminder', v),
            ),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            _ToggleRow(
              icon: 'devicePhoneMobile',
              label: l10n.notifPrefPushNotifications,
              subtitle: l10n.notifPrefPushNotificationsDesc,
              value: pref.pushEnabled,
              saving:
                  _savingKeys['${pref.id}:push_enabled'] == true,
              onChanged: (v) =>
                  _toggle(pref.id, 'push_enabled', v),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: MitlistAppBar.titleText(
        l10n.notifPrefAppBarTitle,
        showStandardActions: false,
        leading: IconButton(
          icon: const AppIcon(name: 'arrowLeft'),
          tooltip: l10n.commonBack,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: _isLoading
          ? ListView(
              padding: const EdgeInsets.all(MitlistSpacing.md),
              children: List.generate(3, (_) => Padding(
                padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
                child: AppCard(
                  padding: AppCardPadding.md,
                  child: const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AppSkeleton(width: 120, height: 16),
                      SizedBox(height: MitlistSpacing.md),
                      AppSkeleton(width: double.infinity, height: 24),
                      SizedBox(height: MitlistSpacing.sm),
                      AppSkeleton(width: double.infinity, height: 24),
                      SizedBox(height: MitlistSpacing.sm),
                      AppSkeleton(width: double.infinity, height: 24),
                    ],
                  ),
                ),
              )),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(MitlistSpacing.md),
                children: [
                  if (_error != null) ...[
                    AppAlert(
                        type: AppAlertType.error, message: _error!),
                    const SizedBox(height: MitlistSpacing.md),
                    AppButton(
                      text: l10n.commonRetry,
                      onPressed: _load,
                    ),
                    const SizedBox(height: MitlistSpacing.md),
                  ],
                  if (!_hasHousehold)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.xl),
                      child: AppEmptyState(
                        lottieAsset: 'assets/animations/lottie/House.lottie',
                        icon: const AppIcon(name: 'homeOutline', size: 56),
                        title: l10n.commonNoHousehold,
                        description: l10n.notifPrefNoHouseholdDesc,
                        actions: [
                          AppButton(
                            text: l10n.commonGoToHouseholds,
                            onPressed: () => context.goNamed('groupsList'),
                          ),
                        ],
                      ),
                    )
                  else if (_preferences.isNotEmpty)
                    ..._preferences.map(_buildPreferenceCard)
                  else
                    AppEmptyState(
                      lottieAsset: 'assets/animations/lottie/Notifications.lottie',
                      icon: AppIcon(name: 'tune', size: 56),
                      title: l10n.notifPrefNoPreferences,
                      description:
                          l10n.notifPrefNoPreferencesDesc,
                    ),
                  ],
                ),
              ),
            );
  }
}

class _ToggleRow extends StatelessWidget {
  final String icon;
  final String label;
  final String subtitle;
  final bool value;
  final bool saving;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.saving,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding:
          const EdgeInsets.symmetric(vertical: MitlistSpacing.xs),
      child: Row(
        children: [
          AppIcon(
            name: icon,
            size: MitlistSpacing.space5,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          if (saving)
            Padding(
              padding: const EdgeInsets.all(MitlistSpacing.sm),
              child: SizedBox(
                width: MitlistSpacing.space4,
                height: MitlistSpacing.space4,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(
                      Theme.of(context).colorScheme.primary),
                ),
              ),
            )
          else
            Switch(
              value: value,
              onChanged: onChanged,
            ),
        ],
      ),
    );
  }
}
