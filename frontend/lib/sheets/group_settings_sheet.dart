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
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_input.dart';

class GroupSettingsSheet extends ConsumerStatefulWidget {
  const GroupSettingsSheet({super.key, required this.groupId});

  final String groupId;

  static Future<void> show(BuildContext context, {required String groupId}) {
    return showAppBottomSheet<void>(
      context: context,
      title: 'Group Settings',
      body: GroupSettingsSheet(groupId: groupId),
    );
  }

  @override
  ConsumerState<GroupSettingsSheet> createState() => _GroupSettingsSheetState();
}

class _GroupSettingsSheetState extends ConsumerState<GroupSettingsSheet> {
  bool _isLoading = true;
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
        _members = members;
        _notificationPref = pref;
        _isLoading = false;
        _nameChanged = false;
        _descChanged = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Something went wrong.';
        _isLoading = false;
      });
    }
  }

  Future<void> _saveDetails() async {
    if (_isSaving) return;
    final newName = _nameController.text.trim();
    final newDesc = _descriptionController.text.trim();
    if (newName.isEmpty) return;

    final oldName = _group?.name ?? '';
    final oldDesc = _group?.description ?? '';

    if (newName == oldName && newDesc == oldDesc) return;

    setState(() => _isSaving = true);
    try {
      final svc = await ref.read(groupServiceProviderAsync.future);
      final updated = await svc.updateGroup(
        widget.groupId,
        UpdateGroupRequest(
          name: newName != oldName ? newName : null,
          description: newDesc != oldDesc ? newDesc : null,
        ),
      );
      if (!mounted) return;
      setState(() {
        _group = updated;
        _isSaving = false;
        _nameChanged = false;
        _descChanged = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group updated')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Failed to save: ${'Something went wrong.'}')),
      );
    }
  }

  Future<void> _confirmRemoveMember(GroupMemberProfile member) async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: 'Remove member',
      body: Text('Remove ${member.displayName} from this group?'),
      actions: [
        AppButton(
          text: 'Cancel',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: 'Remove',
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
        SnackBar(content: Text('${member.displayName} removed')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Failed to remove member: ${'Something went wrong.'}')),
      );
    }
  }

  Future<void> _confirmDeleteGroup() async {
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: 'Delete group',
      body: const Text('This will permanently delete this household and all its data. This cannot be undone.'),
      actions: [
        AppButton(
          text: 'Cancel',
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: 'Delete',
          color: AppButtonColor.error,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) return;
    try {
      final svc = await ref.read(groupServiceProviderAsync.future);
      await svc.deleteGroup(widget.groupId);
      if (!mounted) return;
      Navigator.of(context)
        ..pop()
        ..pop();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Group deleted')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                'Failed to delete group: ${'Something went wrong.'}')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
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
            AppButton(text: 'Retry', onPressed: _loadData),
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
    } catch (_) {
      if (mounted) {
        setState(() => _savingKeys.remove(key));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to update preference')),
        );
      }
    }
  }

  Widget _buildNotificationsSection() {
    final pref = _notificationPref;
    if (pref == null) return const SizedBox.shrink();

    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Notifications',
              style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: MitlistSpacing.sm),
          const Divider(),
          _notifToggle('Chore due', pref.choreDue, 'chore_due'),
          _notifToggle('List item added', pref.listItemAdded, 'list_item_added'),
          _notifToggle('Expense created', pref.expenseCreated, 'expense_created'),
          _notifToggle('Meal plan changed', pref.mealPlanChanged, 'meal_plan_changed'),
          _notifToggle('Weekly digest', pref.weeklyDigest, 'weekly_digest'),
          _notifToggle('Pinwall reminder', pref.pinwallReminder, 'pinwall_reminder'),
          const Divider(),
          _notifToggle('Push enabled', pref.pushEnabled, 'push_enabled'),
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
            Switch(
              value: value,
              onChanged: (v) => _toggleNotifPref(field, v),
            ),
        ],
      ),
    );
  }

  Widget _buildDetailsSection() {
    final hasChanges = _nameChanged || _descChanged;
    final nameEmpty = _nameController.text.trim().isEmpty;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppInput(
            label: 'Group name',
            hint: 'Household name',
            controller: _nameController,
            textInputAction: TextInputAction.next,
            onChanged: (_) => setState(() => _nameChanged = true),
          ),
          const SizedBox(height: MitlistSpacing.md),
          AppInput(
            label: 'Description',
            hint: 'A few words about this household',
            controller: _descriptionController,
            textInputAction: TextInputAction.done,
            onChanged: (_) => setState(() => _descChanged = true),
          ),
          if (hasChanges) ...[
            const SizedBox(height: MitlistSpacing.md),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                text: _isSaving ? 'Saving...' : 'Save',
                isLoading: _isSaving,
                onPressed: (nameEmpty || _isSaving) ? null : _saveDetails,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMembersSection() {
    final textTheme = Theme.of(context).textTheme;

    return AppCard(
      variant: AppCardVariant.outlined,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Members', style: textTheme.titleSmall),
              const Spacer(),
              Text(
                '${_members.length}',
                style:
                    textTheme.bodySmall?.copyWith(color: textTheme.titleSmall?.color),
              ),
            ],
          ),
          if (_members.isNotEmpty) ...[
            const SizedBox(height: MitlistSpacing.sm),
            const Divider(),
            ..._members.map((m) => _buildMemberTile(m)),
          ],
        ],
      ),
    );
  }

  Widget _buildMemberTile(GroupMemberProfile member) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).colorScheme.primaryContainer,
        child: Text(
          member.displayName.isNotEmpty ? member.displayName[0].toUpperCase() : '?',
        ),
      ),
      title: Text(member.displayName, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(member.role, maxLines: 1, overflow: TextOverflow.ellipsis),
      trailing: IconButton(
        tooltip: 'Remove ${member.displayName}',
        icon: const Icon(Icons.remove_circle_outline, size: 20),
        onPressed: () => _confirmRemoveMember(member),
      ),
    );
  }

  Widget _buildDangerZone() {
    return SizedBox(
      width: double.infinity,
      child: AppButton(
        text: 'Delete group',
        variant: AppButtonVariant.soft,
        color: AppButtonColor.error,
        size: AppButtonSize.lg,
        onPressed: _confirmDeleteGroup,
      ),
    );
  }
}
