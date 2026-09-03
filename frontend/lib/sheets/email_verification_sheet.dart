import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../providers/auth_provider.dart';
import '../theme/spacing.dart';
import '../widgets/alert.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';

/// Asks for the code mailed to [email] and proves the address with it.
///
/// Used wherever an unproven address blocks the way: signing in to an
/// account that never finished sign-up, and a guest who gave an email but
/// has not entered the code yet. Verifying saves a session exactly like a
/// login does, honouring [rememberMe].
///
/// Resolves true once the server accepted the code, false if the sheet was
/// dismissed. With [sendCodeOnOpen] a fresh code is requested as the sheet
/// opens, for the case where the old one is likely expired.
Future<bool> showEmailVerificationSheet({
  required BuildContext context,
  required WidgetRef ref,
  required String email,
  bool rememberMe = true,
  bool sendCodeOnOpen = false,
}) async {
  final l10n = AppLocalizations.of(context)!;
  final result = await showAppBottomSheet<bool>(
    context: context,
    title: l10n.authVerifyTitle,
    body: _EmailVerificationBody(
      email: email,
      rememberMe: rememberMe,
      sendCodeOnOpen: sendCodeOnOpen,
    ),
  );
  return result == true;
}

/// Owns the field's controller and focus so they live exactly as long as the
/// sheet does, closing animation included.
class _EmailVerificationBody extends ConsumerStatefulWidget {
  const _EmailVerificationBody({
    required this.email,
    required this.rememberMe,
    required this.sendCodeOnOpen,
  });

  final String email;
  final bool rememberMe;
  final bool sendCodeOnOpen;

  @override
  ConsumerState<_EmailVerificationBody> createState() =>
      _EmailVerificationBodyState();
}

class _EmailVerificationBodyState
    extends ConsumerState<_EmailVerificationBody> {
  final _codeController = TextEditingController();
  final _codeFocus = FocusNode();
  bool _isVerifying = false;
  bool _isSending = false;
  String? _error;
  String? _notice;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _codeFocus.requestFocus();
      if (widget.sendCodeOnOpen) _resend();
    });
  }

  @override
  void dispose() {
    _codeController.dispose();
    _codeFocus.dispose();
    super.dispose();
  }

  Future<void> _resend() async {
    if (_isSending) return;
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _isSending = true;
      _error = null;
      _notice = null;
    });
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      await authService.resendEmailVerification(widget.email);
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _notice = l10n.authVerifySent;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSending = false;
        _error = l10n.errorGenericRetry;
      });
    }
  }

  Future<void> _verify() async {
    final l10n = AppLocalizations.of(context)!;
    final code = _codeController.text.trim();
    if (code.isEmpty) {
      setState(() => _error = l10n.authVerifyCodeRequired);
      return;
    }
    setState(() {
      _isVerifying = true;
      _error = null;
      _notice = null;
    });
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      await authService.verifyEmail(code, rememberMe: widget.rememberMe);
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isVerifying = false;
        _error = l10n.authVerifyInvalid;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final busy = _isVerifying || _isSending;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.authVerifyBody(widget.email),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        const SizedBox(height: MitlistSpacing.lg),
        if (_error != null) ...[
          AppAlert(type: AppAlertType.error, message: _error!),
          const SizedBox(height: MitlistSpacing.md),
        ],
        if (_notice != null) ...[
          AppAlert(type: AppAlertType.info, message: _notice!),
          const SizedBox(height: MitlistSpacing.md),
        ],
        AppInput(
          label: l10n.authVerifyCodeLabel,
          hint: l10n.authVerifyCodeHint,
          controller: _codeController,
          focusNode: _codeFocus,
          textInputAction: TextInputAction.done,
          autofillHints: const [AutofillHints.oneTimeCode],
          onSubmitted: (_) => _verify(),
        ),
        const SizedBox(height: MitlistSpacing.lg),
        AppButton(
          text: l10n.authVerifyButton,
          variant: AppButtonVariant.solid,
          color: AppButtonColor.primary,
          size: AppButtonSize.lg,
          isLoading: _isVerifying,
          onPressed: busy ? null : _verify,
        ),
        const SizedBox(height: MitlistSpacing.sm),
        AppButton(
          text: l10n.authVerifyResend,
          variant: AppButtonVariant.ghost,
          color: AppButtonColor.neutral,
          isLoading: _isSending,
          onPressed: busy ? null : _resend,
        ),
      ],
    );
  }
}
