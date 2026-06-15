import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_models.dart';
import '../models/notification_models.dart';
import '../providers/group_provider.dart';
import '../providers/notification_provider.dart';
import '../theme/spacing.dart';
import '../widgets/alert.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_divider.dart';
import '../widgets/app_card.dart';
import '../widgets/app_currency_dropdown.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_input.dart';
import '../widgets/app_switch.dart';
import '../widgets/chip.dart';
import '../utils/friendly_error.dart';
import '../l10n/app_localizations.dart';
import 'invite_household_sheet.dart';

class GroupSettingsSheet extends ConsumerStatefulWidget {
  const GroupSettingsSheet({super.key, required this.groupId});

  final String groupId;

  static Future<void> show(BuildContext context, {required String groupId}) {
    final l10n = AppLocalizations.of(context)!;
    return showAppBottomSheet<void>(
      context: context,
      title: l10n.sheetGroupSettingsTitle,
      body: GroupSettingsSheet(groupId: groupId),
    );
  }

  @override
  ConsumerState<GroupSettingsSheet> createState() => _GroupSettingsSheetState();
}

class _GroupSettingsSheetState extends ConsumerState<GroupSettingsSheet> {
  bool _isLoading = true;
  bool _isDeleting = false;
  String? _error;

  Group? _group;
  List<GroupMemberProfile> _members = [];
  NotificationPreferenceModel? _notificationPref;
  final Map<String, bool> _savingKeys = {};

  late final TextEditingController _nameController;
  late final TextEditingController _descriptionController;
  bool _isSaving = false;
  bool _nameChanged = false;
  bool _descChanged = false;
  String _groupCurrency = 'USD';
  bool _currencyChanged = false;
  List<String> _choreZones = [];
  bool _zonesChanged = false;
  final TextEditingController _zoneInputController = TextEditingController();
  bool _isSavingZones = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController();
    _descriptionController = TextEditingController();
    _loadData();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _zoneInputController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final svc = await ref.read(groupServiceProviderAsync.future);
      final notifSvc = await ref.read(notificationServiceProviderAsync.future);
      final results = await Future.wait([
        svc.getGroup(widget.groupId),
        svc.listMembers(widget.groupId),
        notifSvc.getGroupPreference(widget.groupId),
      ]);
      if (!mounted) return;
      final group = results[0] as Group;
      final members = results[1] as List<GroupMemberProfile>;
      final pref = results[2] as NotificationPreferenceModel;
      _nameController.text = group.name;
      _descriptionController.text = group.description ?? '';
      setState(() {
        _group = group;
        _groupCurrency = group.currency;
        _choreZones = List<String>.from(group.choreZones);
        _members = members;
        _notificationPref = pref;
        _isLoading = false;
        _nameChanged = false;
        _descChanged = false;
        _currencyChanged = false;
        _zonesChanged = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e, AppLocalizations.of(context)!);
        _isLoading = false;
      });
    }
  }

  Future<void> _saveZones() async {
    if (_isSavingZones) return;
    setState(() => _isSavingZones = true);
    try {
      final svc = await ref.read(groupServiceProviderAsync.future);
      final updated = await svc.updateGroup(
        widget.groupId,
        UpdateGroupRequest(choreZones: _choreZones),
      );
      if (!mounted) return;
      ref.invalidate(cachedGroupsProvider);
      setState(() {
        _group = updated;
        _choreZones = List<String>.from(updated.choreZones);
        _isSavingZones = false;
        _zonesChanged = false;
      });
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sheetGroupSettingsChoreZonesUpdated)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSavingZones = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
      );
    }
  }

  void _addZone() {
    final zone = _zoneInputController.text.trim();
    if (zone.isEmpty) return;
    if (_choreZones.any((z) => z.toLowerCase() == zone.toLowerCase())) {
      _zoneInputController.clear();
      return;
    }
    setState(() {
      _choreZones = [..._choreZones, zone];
      _zonesChanged = true;
      _zoneInputController.clear();
    });
  }

  void _removeZone(String zone) {
    setState(() {
      _choreZones = _choreZones.where((z) => z != zone).toList();
      _zonesChanged = true;
    });
  }

  Future<void> _saveDetails() async {
    final l10n = AppLocalizations.of(context)!;
    if (_isSaving) return;
    final newName = _nameController.text.trim();
    final newDesc = _descriptionController.text.trim();
    if (newName.isEmpty) return;

    final oldName = _group?.name ?? '';
    final oldDesc = _group?.description ?? '';

    if (newName == oldName && newDesc == oldDesc && !_currencyChanged) return;

    setState(() => _isSaving = true);
    try {
      final svc = await ref.read(groupServiceProviderAsync.future);
      final updated = await svc.updateGroup(
        widget.groupId,
        UpdateGroupRequest(
          name: newName != oldName ? newName : null,
          description: newDesc != oldDesc ? newDesc : null,
          currency: _currencyChanged ? _groupCurrency : null,
        ),
      );
      if (!mounted) return;
      setState(() {
        _group = updated;
        _isSaving = false;
        _nameChanged = false;
        _descChanged = false;
        _currencyChanged = false;
      });
      ref.invalidate(cachedGroupsProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sheetGroupSettingsSaved)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
      );
    }
  }

  Future<void> _confirmRemoveMember(GroupMemberProfile member) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: l10n.sheetGroupSettingsRemoveMember,
      body: Text(l10n.sheetGroupSettingsRemoveMemberConfirm(member.displayName)),
      actions: [
        AppButton(
          text: l10n.commonCancel,
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: l10n.commonRemove,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    try {
      final svc = await ref.read(groupServiceProviderAsync.future);
      await svc.removeMember(widget.groupId, member.userId);
      if (!mounted) return;
      setState(() {
        _members = _members.where((m) => m.userId != member.userId).toList();
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sheetGroupSettingsMemberRemoved(member.displayName))),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
      );
    }
  }

  Future<void> _confirmDeleteGroup() async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: l10n.sheetGroupSettingsDelete,
      body: Text(l10n.sheetGroupSettingsDeleteConfirm),
      actions: [
        AppButton(
          text: l10n.commonCancel,
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: l10n.commonDelete,
          color: AppButtonColor.error,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    setState(() => _isDeleting = true);
    try {
      final svc = await ref.read(groupServiceProviderAsync.future);
      await svc.deleteGroup(widget.groupId);
      if (!mounted) return;
      Navigator.of(context)
        ..pop()
        ..pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sheetGroupSettingsHouseholdDeleted)),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isDeleting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(MitlistSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAlert(type: AppAlertType.error, message: _error!),
            const SizedBox(height: MitlistSpacing.md),
            AppButton(text: l10n.commonRetry, onPressed: _loadData),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildDetailsSection(),
          const SizedBox(height: MitlistSpacing.lg),
          _buildChoreZonesSection(),
          const SizedBox(height: MitlistSpacing.lg),
          _buildMembersSection(),
          const SizedBox(height: MitlistSpacing.lg),
          _buildNotificationsSection(),
          const SizedBox(height: MitlistSpacing.lg),
          _buildDangerZone(),
        ],
      ),
    );
  }

  Future<void> _toggleNotifPref(String field, bool value) async {
    final pref = _notificationPref;
    if (pref == null) return;
    final key = '$field:${pref.id}';
    setState(() => _savingKeys[key] = true);

    try {
      final svc = await ref.read(notificationServiceProviderAsync.future);
      final updated = NotificationPreferenceModel(
        id: pref.id,
        userId: pref.userId,
        groupId: pref.groupId,
        choreDue: field == 'chore_due' ? value : pref.choreDue,
        choreDueDayOf: field == 'chore_due_day_of' ? value : pref.choreDueDayOf,
        listItemAdded: field == 'list_item_added' ? value : pref.listItemAdded,
        expenseCreated: field == 'expense_created' ? value : pref.expenseCreated,
        mealPlanChanged: field == 'meal_plan_changed' ? value : pref.mealPlanChanged,
        weeklyDigest: field == 'weekly_digest' ? value : pref.weeklyDigest,
        pinwallReminder: field == 'pinwall_reminder' ? value : pref.pinwallReminder,
        pushEnabled: field == 'push_enabled' ? value : pref.pushEnabled,
      );
      await svc.updatePreference(updated);
      if (!mounted) return;
      setState(() {
        _notificationPref = updated;
        _savingKeys.remove(key);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _savingKeys.remove(key));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
        );
      }
    }
  }

  Widget _buildNotificationsSection() {
    final l10n = AppLocalizations.of(context)!;
    final pref = _notificationPref;
    if (pref == null) return const SizedBox.shrink();

    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.notifPrefGroupName,
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: MitlistSpacing.sm),
          const AppDivider(),
          _notifToggle(l10n.notifPrefChoreDueReminders, pref.choreDue, 'chore_due'),
          _notifToggle(l10n.notifPrefListItemAdded, pref.listItemAdded, 'list_item_added'),
          _notifToggle(l10n.notifPrefExpenseCreated, pref.expenseCreated, 'expense_created'),
          _notifToggle(l10n.notifPrefMealPlanChanged, pref.mealPlanChanged, 'meal_plan_changed'),
          _notifToggle(l10n.notifPrefWeeklyDigest, pref.weeklyDigest, 'weekly_digest'),
          _notifToggle(l10n.notifPrefPinwallReminders, pref.pinwallReminder, 'pinwall_reminder'),
          const AppDivider(),
          _notifToggle(l10n.notifPrefPushNotifications, pref.pushEnabled, 'push_enabled'),
        ],
      ),
    );
  }

  Widget _notifToggle(String label, bool value, String field) {
    final key = '$field:${_notificationPref?.id}';
    final saving = _savingKeys[key] == true;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.xs),
      child: Row(
        children: [
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (saving)
            const Padding(
              padding: EdgeInsets.all(MitlistSpacing.sm),
              child: SizedBox(
                width: MitlistSpacing.space4,
                height: MitlistSpacing.space4,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            )
          else
            AppSwitch(
              value: value,
              onChanged: (v) => _toggleNotifPref(field, v),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    final l10n = AppLocalizations.of(context)!;
    final hasChanges = _nameChanged || _descChanged || _currencyChanged;
    final nameEmpty = _nameController.text.trim().isEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppInput(
            label: l10n.sheetGroupSettingsName,
            hint: l10n.sheetGroupSettingsName,
            controller: _nameController,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() => _nameChanged = true),
          ),
          const SizedBox(height: MitlistSpacing.md),
          AppInput(
            label: l10n.commonDescription,
            hint: l10n.sheetGroupSettingsDescriptionHint,
            controller: _descriptionController,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() => _descChanged = true),
          ),
          const SizedBox(height: MitlistSpacing.md),
          AppCurrencyDropdown(
            value: _groupCurrency,
            onChanged: (v) {
              if (v != null) {
                setState(() {
                  _groupCurrency = v;
                  _currencyChanged = true;
                });
              }
            },
          ),
          if (hasChanges) ...[
            const SizedBox(height: MitlistSpacing.md),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: _isSaving ? l10n.commonSaving : l10n.commonSave,
                isLoading: _isSaving,
                onPressed: (nameEmpty || _isSaving) ? null : _saveDetails,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildChoreZonesSection() {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.sheetGroupSettingsChoreZonesLabel, style: textTheme.titleSmall),
          const SizedBox(height: MitlistSpacing.xs),
          Text(
            l10n.sheetGroupSettingsChoreZonesDesc,
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (_choreZones.isNotEmpty) ...[
            const SizedBox(height: MitlistSpacing.sm),
            Wrap(
              spacing: MitlistSpacing.sm,
              runSpacing: MitlistSpacing.sm,
              children: [
                for (final zone in _choreZones)
                  AppChip(
                    label: zone,
                    onSelected: (_) => _removeZone(zone),
                  ),
              ],
            ),
          ],
          const SizedBox(height: MitlistSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppInput(
                  label: l10n.sheetGroupSettingsAddZone,
                  hint: l10n.sheetGroupSettingsZoneHint,
                  controller: _zoneInputController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addZone(),
                ),
              ),
              const SizedBox(width: MitlistSpacing.sm),
               AppButton(
                text: l10n.commonAdd,
                size: AppButtonSize.sm,
                onPressed: _addZone,
              ),
            ],
          ),
          if (_zonesChanged) ...[
            const SizedBox(height: MitlistSpacing.md),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: _isSavingZones ? l10n.commonSaving : l10n.sheetGroupSettingsSaveZones,
                isLoading: _isSavingZones,
                onPressed: _isSavingZones ? null : _saveZones,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMembersSection() {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(l10n.sheetGroupSettingsMembersLabel, style: textTheme.titleSmall),
              const Spacer(),
              Text(
                '${_members.length}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall
                    ?.copyWith(color: textTheme.titleSmall?.color),
              ),
              const SizedBox(width: MitlistSpacing.sm),
              AppButton(
                size: AppButtonSize.sm,
                variant: AppButtonVariant.ghost,
                text: l10n.sheetGroupSettingsInvite,
                icon: const AppIcon(name: 'userPlus'),
                onPressed: () => InviteHouseholdSheet.show(
                  context,
                  groupId: widget.groupId,
                ),
              ),
            ],
          ),
          if (_members.isNotEmpty) ...[
            const SizedBox(height: MitlistSpacing.sm),
            const AppDivider(),
            ..._members.map((m) => _buildMemberTile(m)),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberTile(GroupMemberProfile member) {
    final l10n = AppLocalizations.of(context)!;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: MitlistSpacing.space10,
        height: MitlistSpacing.space10,
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primaryContainer,
          border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant,
            width: 2,
          ),
        ),
        alignment: Alignment.center,
        child: Text(
          member.displayName.isNotEmpty
              ? String.fromCharCode(member.displayName.runes.first)
              : '?',
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Theme.of(context).colorScheme.onPrimaryContainer,
          ),
        ),
      ),
      title: Text(member.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(member.role, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        tooltip: l10n.sheetGroupSettingsRemoveMemberTooltip(member.displayName),
        icon: AppIcon(name: 'minusCircleOutline', size: 20),
        onPressed: () => _confirmRemoveMember(member),
      ),
    );
  }

  Widget _buildDangerZone() {
    final l10n = AppLocalizations.of(context)!;
    return SizedBox(
      width: double.infinity,
      child: AppButton(
        text: _isDeleting ? l10n.commonDeleting : l10n.sheetGroupSettingsDelete,
        variant: AppButtonVariant.soft,
        color: AppButtonColor.error,
        size: AppButtonSize.lg,
        isLoading: _isDeleting,
        onPressed: _isDeleting ? null : _confirmDeleteGroup,
      ),
    );
  }
}
