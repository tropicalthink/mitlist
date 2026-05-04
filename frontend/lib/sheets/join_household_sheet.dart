import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_models.dart';
import '../providers/group_provider.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/alert.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';

class JoinHouseholdSheet extends ConsumerStatefulWidget {
  const JoinHouseholdSheet({super.key});

  static Future<bool?> show(BuildContext context) async {
    return showAppBottomSheet<bool>(
      context: context,
      title: 'Join Household',
      body: const JoinHouseholdSheet(),
    );
  }

  @override
  ConsumerState<JoinHouseholdSheet> createState() => _JoinHouseholdSheetState();
}

class _JoinHouseholdSheetState extends ConsumerState<JoinHouseholdSheet> {
  final TextEditingController _codeController = TextEditingController();
  bool _isJoining = false;
  String? _errorMessage;

  bool get _canJoin => _codeController.text.trim().length >= 4 && !_isJoining;

  Future<void> _onJoin() async {
    if (!_canJoin) return;

    setState(() {
      _isJoining = true;
      _errorMessage = null;
    });

    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);
      await groupService.joinGroup(
        JoinGroupRequest(code: _normalizeCode(_codeController.text)),
      );
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Something went wrong.';
        _isJoining = false;
      });
    }
  }

  String _normalizeCode(String value) {
    return value.trim().toUpperCase();
  }

  @override
  void dispose() {
    _codeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_errorMessage != null) ...[
          AppAlert(
            type: AppAlertType.error,
            message: _errorMessage!,
          ),
          const SizedBox(height: MitlistSpacing.md),
        ],
        AppInput(
          label: 'Invite Code',
          hint: 'SUNNY-TACO-42',
          controller: _codeController,
          enabled: !_isJoining,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Text(
          'Tip: codes are short words + numbers. Uppercase works best.',
          style:
              MitlistTypography.labelXSmall(color: MitlistColors.textTertiary),
        ),
        const SizedBox(height: MitlistSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            variant: AppButtonVariant.solid,
            color: AppButtonColor.primary,
            size: AppButtonSize.lg,
            text: _isJoining ? 'Joining...' : 'Join Household',
            isLoading: _isJoining,
            onPressed: _canJoin ? _onJoin : null,
          ),
        ),
      ],
    );
  }
}
