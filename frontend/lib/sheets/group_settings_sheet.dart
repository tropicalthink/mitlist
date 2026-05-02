import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_models.dart';
import '../providers/group_provider.dart';
import '../theme/spacing.dart';
import '../widgets/alert.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
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
      final results = await Future.wait([
        svc.getGroup(widget.groupId),
        svc.listMembers(widget.groupId),
      ]);
      if (!mounted) return;
      final group = results[0] as Group;
      final members = results[1] as List<GroupMemberProfile>;
      _nameController.text = group.name;
      _descriptionController.text = group.description ?? '';
      setState(() {
        _group = group;
        _members = members;
        _isLoading = false;
        _nameChanged = false;
        _descChanged = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
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
                'Failed to save: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  Future<void> _confirmRemoveMember(GroupMemberProfile member) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove member'),
        content: Text('Remove ${member.displayName} from this group?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
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
                'Failed to remove member: ${e.toString().replaceFirst('Exception: ', '')}')),
      );
    }
  }

  Future<void> _confirmDeleteGroup() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete group'),
        content: const Text(
            'This will permanently delete this household and all its data. This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
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
                'Failed to delete group: ${e.toString().replaceFirst('Exception: ', '')}')),
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
          _buildDangerZone(),
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
      title: Text(member.displayName),
      subtitle: Text(member.role),
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
