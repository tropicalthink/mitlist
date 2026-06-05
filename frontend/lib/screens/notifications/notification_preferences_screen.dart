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
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final groups = await groupService.listGroups();
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
        _error = 'Failed to load notification preferences.';
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
      _load();
    }
  }

  Widget _buildPreferenceCard(NotificationPreferenceModel pref) {
    final groupName =
        _groupNames[pref.groupId] ?? 'Notifications';

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
              label: 'Chore due reminders',
              subtitle: 'When a chore is coming due',
              value: pref.choreDue,
              saving: _savingKeys['${pref.id}:chore_due'] == true,
              onChanged: (v) => _toggle(pref.id, 'chore_due', v),
            ),
            _ToggleRow(
              icon: 'calendarDays',
              label: 'Chore due day-of',
              subtitle: 'On the day a chore is due',
              value: pref.choreDueDayOf,
              saving:
                  _savingKeys['${pref.id}:chore_due_day_of'] == true,
              onChanged: (v) =>
                  _toggle(pref.id, 'chore_due_day_of', v),
            ),
            _ToggleRow(
              icon: 'clipboardDocumentList',
              label: 'List item added',
              subtitle: 'When someone adds to a shared list',
              value: pref.listItemAdded,
              saving:
                  _savingKeys['${pref.id}:list_item_added'] == true,
              onChanged: (v) =>
                  _toggle(pref.id, 'list_item_added', v),
            ),
            _ToggleRow(
              icon: 'banknotes',
              label: 'Expense created',
              subtitle: 'When a new expense is logged',
              value: pref.expenseCreated,
              saving:
                  _savingKeys['${pref.id}:expense_created'] == true,
              onChanged: (v) =>
                  _toggle(pref.id, 'expense_created', v),
            ),
            _ToggleRow(
              icon: 'calendarDays',
              label: 'Meal plan changed',
              subtitle: 'When the meal plan is updated',
              value: pref.mealPlanChanged,
              saving:
                  _savingKeys['${pref.id}:meal_plan_changed'] == true,
              onChanged: (v) =>
                  _toggle(pref.id, 'meal_plan_changed', v),
            ),
            _ToggleRow(
              icon: 'chartBar',
              label: 'Weekly digest',
              subtitle: 'A summary of household activity',
              value: pref.weeklyDigest,
              saving:
                  _savingKeys['${pref.id}:weekly_digest'] == true,
              onChanged: (v) =>
                  _toggle(pref.id, 'weekly_digest', v),
            ),
            _ToggleRow(
              icon: 'bell',
              label: 'Pinwall reminders',
              subtitle: 'When someone pins a reminder for later',
              value: pref.pinwallReminder,
              saving:
                  _savingKeys['${pref.id}:pinwall_reminder'] == true,
              onChanged: (v) =>
                  _toggle(pref.id, 'pinwall_reminder', v),
            ),
            const Divider(),
            _ToggleRow(
              icon: 'devicePhoneMobile',
              label: 'Push notifications',
              subtitle: 'Receive notifications on this device',
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
    return Scaffold(
      appBar: MitlistAppBar.titleText(
        'Notification Preferences',
        showStandardActions: false,
        leading: IconButton(
          icon: const AppIcon(name: 'arrowLeft'),
          tooltip: 'Back',
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
                      text: 'Retry',
                      onPressed: _load,
                    ),
                    const SizedBox(height: MitlistSpacing.md),
                  ],
                  if (!_hasHousehold)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.xl),
                      child: AppEmptyState(
                        lottieAsset: 'assets/animations/lottie/House.lottie',
                        icon: const Icon(Icons.home_outlined, size: 56),
                        title: 'No household yet',
                        description: 'Join or create a household to configure notification preferences.',
                        actions: [
                          AppButton(
                            text: 'Go to households',
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
                      icon: Icon(Icons.tune, size: 56),
                      title: 'No preferences yet',
                      description:
                          'Preferences are created when you join a household. If you just joined, they should appear shortly.',
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
          SizedBox(width: MitlistSpacing.sm),
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
              padding: EdgeInsets.all(MitlistSpacing.sm),
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
