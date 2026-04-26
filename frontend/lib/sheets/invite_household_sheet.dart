import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_models.dart';
import '../providers/group_provider.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/alert.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';

class InviteHouseholdSheet extends ConsumerStatefulWidget {
  const InviteHouseholdSheet({super.key, required this.groupId});

  final String groupId;

  static Future<void> show(BuildContext context, {required String groupId}) {
    return showAppBottomSheet<void>(
      context: context,
      title: 'Invite to household',
      body: InviteHouseholdSheet(groupId: groupId),
    );
  }

  @override
  ConsumerState<InviteHouseholdSheet> createState() => _InviteHouseholdSheetState();
}

class _InviteHouseholdSheetState extends ConsumerState<InviteHouseholdSheet> {
  bool _isLoading = true;
  bool _isCopying = false;
  String? _error;
  GroupInvite? _invite;

  @override
  void initState() {
    super.initState();
    _createInvite();
  }

  Future<void> _createInvite() async {
    setState(() {
      _isLoading = true;
      _error = null;
      _invite = null;
    });

    try {
      final svc = await ref.read(groupServiceProviderAsync.future);
      final invite = await svc.inviteMember(
        widget.groupId,
        const InviteMemberRequest(role: 'member'),
      );
      if (!mounted) return;
      setState(() {
        _invite = invite;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _isLoading = false;
      });
    }
  }

  Future<void> _copyCode() async {
    final code = _invite?.code;
    if (code == null || code.trim().isEmpty || _isCopying) return;

    setState(() => _isCopying = true);
    try {
      await Clipboard.setData(ClipboardData(text: code.trim()));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invite code copied')),
      );
    } finally {
      if (mounted) setState(() => _isCopying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final code = _invite?.code ?? '';

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(MitlistSpacing.md),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AppAlert(type: AppAlertType.error, message: _error!),
            const SizedBox(height: MitlistSpacing.md),
          ],
          AppCard(
            variant: AppCardVariant.outlined,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Invite code',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: MitlistSpacing.sm),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: MitlistSpacing.md,
                    vertical: MitlistSpacing.sm,
                  ),
                  decoration: BoxDecoration(
                    color: MitlistColors.surfaceSoft,
                    border: Border.all(color: MitlistColors.borderSecondary, width: 2),
                  ),
                  child: Text(
                    code.isEmpty ? '—' : code.trim(),
                    style: MitlistTypography.monoBody(),
                  ),
                ),
                const SizedBox(height: MitlistSpacing.sm),
                Text(
                  'They can join from “My Households” → “Join with code”.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          ),
          const SizedBox(height: MitlistSpacing.md),
          Row(
            children: [
              Expanded(
                child: AppButton(
                  text: _isCopying ? 'Copying...' : 'Copy code',
                  onPressed: (code.isEmpty || _isCopying) ? null : _copyCode,
                ),
              ),
              const SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: AppButton(
                  variant: AppButtonVariant.outline,
                  text: 'New code',
                  onPressed: _createInvite,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

