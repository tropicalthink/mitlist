import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';

class JoinHouseholdSheet extends StatefulWidget {
  const JoinHouseholdSheet({super.key});

  static Future<void> show(BuildContext context) async {
    return showAppBottomSheet(
      context: context,
      title: 'Join Household',
      body: const JoinHouseholdSheet(),
    );
  }

  @override
  State<JoinHouseholdSheet> createState() => _JoinHouseholdSheetState();
}

class _JoinHouseholdSheetState extends State<JoinHouseholdSheet> {
  final TextEditingController _codeController = TextEditingController();

  bool get _canJoin => _codeController.text.trim().length >= 4;

  void _onJoin() {
    if (!_canJoin) return;
    Navigator.of(context).pop();
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
        AppInput(
          label: 'Invite Code',
          hint: 'XXXX-XXXX',
          controller: _codeController,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
          keyboardType: TextInputType.text,
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Text(
          'Codes are uppercase and use a monospace font for readability.',
          style: MitlistTypography.labelXSmall(color: MitlistColors.textTertiary),
        ),
        const SizedBox(height: MitlistSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            variant: AppButtonVariant.solid,
            color: AppButtonColor.primary,
            size: AppButtonSize.lg,
            text: 'Join',
            onPressed: _canJoin ? _onJoin : null,
          ),
        ),
      ],
    );
  }
}
