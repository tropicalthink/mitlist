import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import 'package:share_plus/share_plus.dart';

import '../models/group_models.dart';
import '../providers/group_provider.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../utils/friendly_error.dart';
import '../utils/invite_link.dart';
import '../widgets/alert.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_icon.dart';

class InviteHouseholdSheet extends ConsumerStatefulWidget {
  const InviteHouseholdSheet({super.key, required this.groupId});

  final String groupId;

  static const double _qrSize = MitlistSpacing.space24 * 2;

  static Future<void> show(BuildContext context, {required String groupId}) {
    final l10n = AppLocalizations.of(context)!;
    return showAppBottomSheet<void>(
      context: context,
      title: l10n.sheetInviteTitle,
      body: InviteHouseholdSheet(groupId: groupId),
    );
  }

  @override
  ConsumerState<InviteHouseholdSheet> createState() =>
      _InviteHouseholdSheetState();
}

class _InviteHouseholdSheetState extends ConsumerState<InviteHouseholdSheet>
    with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _copied = false;
  String? _error;
  GroupInvite? _invite;
  Timer? _copiedTimer;

  late final AnimationController _codeAnim;
  late final AnimationController _qrAnim;

  @override
  void initState() {
    super.initState();
    _codeAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _qrAnim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    );
    _createInvite();
  }

  @override
  void dispose() {
    _copiedTimer?.cancel();
    _codeAnim.dispose();
    _qrAnim.dispose();
    super.dispose();
  }

  Future<void> _createInvite() async {
    setState(() {
      _isLoading = true;
      _error = null;
      // Don't clear _invite — keeps old code visible while regenerating.
      _copied = false;
    });
    _codeAnim.reset();
    _qrAnim.reset();

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

      final disableAnimations = MediaQuery.of(context).disableAnimations;
      if (disableAnimations) {
        _codeAnim.value = 1.0;
        _qrAnim.value = 1.0;
      } else {
        unawaited(_codeAnim.forward());
        Future.delayed(const Duration(milliseconds: 240), () {
          if (mounted) _qrAnim.forward();
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e, AppLocalizations.of(context)!);
        _isLoading = false;
      });
    }
  }

  Future<void> _copyCode() async {
    final code = _invite?.code;
    if (code == null || code.trim().isEmpty || _copied) return;
    try {
      await Clipboard.setData(ClipboardData(text: code.trim()));
    } catch (_) {
      return; // Clipboard unavailable; silently ignore.
    }
    if (!mounted) return;
    setState(() => _copied = true);
    _copiedTimer?.cancel();
    _copiedTimer = Timer(const Duration(milliseconds: 1800), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  List<String> get _codeParts {
    final code = _invite?.code ?? '';
    if (code.trim().isEmpty) return [];
    return code.trim().split('-');
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final code = _invite?.code ?? '';

    if (_isLoading && _invite == null) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: MitlistSpacing.xl),
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

          // Animated code segments
          if (_codeParts.isNotEmpty) ...[
            Semantics(
              label: l10n.inviteCodeLabel(code.trim()),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < _codeParts.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: MitlistSpacing.xs,
                        ),
                        child: Text(
                          '—',
                          style: Theme.of(context)
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurfaceVariant,
                              ),
                        ),
                      ),
                    _AnimatedSegment(
                      key: ValueKey('${_invite?.code}-$i'),
                      text: _codeParts[i],
                      controller: _codeAnim,
                      startFraction: (_codeParts.length > 1)
                          ? (i / _codeParts.length) * 0.4
                          : 0.0,
                      endFraction: ((i / _codeParts.length) * 0.4 + 0.6)
                          .clamp(0.0, 1.0),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: MitlistSpacing.lg),
          ],

          // QR code — fades in after segments appear
          FadeTransition(
            opacity: _qrAnim,
            child: Center(
              child: Semantics(
                label: l10n.inviteQrTitle,
                button: true,
                child: GestureDetector(
                  onTap: _copyCode,
                  child: code.isEmpty
                      ? SizedBox(
                          width: InviteHouseholdSheet._qrSize,
                          height: InviteHouseholdSheet._qrSize,
                        )
                      : Builder(
                          builder: (context) {
                            final qrFg =
                                Theme.of(context).brightness == Brightness.dark
                                    ? Colors.white
                                    : Colors.black;
                            return QrImageView(
                              data: buildWebInviteLink(code),
                              version: QrVersions.auto,
                              size: InviteHouseholdSheet._qrSize,
                              backgroundColor: Colors.transparent,
                              eyeStyle: QrEyeStyle(color: qrFg),
                              dataModuleStyle:
                                  QrDataModuleStyle(color: qrFg),
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                              semanticsLabel: l10n.inviteQrSemantic,
                              errorStateBuilder: (context, _) => SizedBox(
                                width: InviteHouseholdSheet._qrSize,
                                height: InviteHouseholdSheet._qrSize,
                                child: Center(
                                  child: Text(
                                    l10n.inviteQrUnavailable,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodySmall,
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ),
          ),
          const SizedBox(height: MitlistSpacing.xs),
          FadeTransition(
            opacity: _qrAnim,
            child: Text(
              l10n.inviteQrHint,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(height: MitlistSpacing.md),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 200),
                  child: AppButton(
                    key: ValueKey(_copied),
                    text: _copied ? l10n.sheetInviteCopied : l10n.sheetInviteCopy,
                    icon: _copied
                        ? const AppIcon(name: 'checkCircle', size: 18)
                        : const AppIcon(name: 'copy', size: 18),
                    onPressed: code.isEmpty ? null : _copyCode,
                    variant: _copied
                        ? AppButtonVariant.solid
                        : AppButtonVariant.outline,
                    color: _copied
                        ? AppButtonColor.success
                        : AppButtonColor.neutral,
                  ),
                ),
              ),
              const SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: AppButton(
                  variant: AppButtonVariant.outline,
                  text: _isLoading ? l10n.inviteGenerating : l10n.inviteNewCode,
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _createInvite,
                ),
              ),
            ],
          ),
          const SizedBox(height: MitlistSpacing.sm),
          AppButton(
            variant: AppButtonVariant.solid,
            color: AppButtonColor.primary,
            text: l10n.sheetInviteShare,
            icon: const AppIcon(name: 'share', size: 18),
            onPressed: code.isEmpty
                ? null
                : () => Share.share(inviteShareText(code, l10n)),
          ),
        ],
      ),
    );
  }
}

// A single code segment that slides up and fades in on its own interval
class _AnimatedSegment extends StatelessWidget {
  final String text;
  final AnimationController controller;
  final double startFraction;
  final double endFraction;

  const _AnimatedSegment({
    super.key,
    required this.text,
    required this.controller,
    required this.startFraction,
    required this.endFraction,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final fade = CurvedAnimation(
      parent: controller,
      curve: Interval(startFraction, endFraction, curve: Curves.easeOut),
    );
    final slide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: controller,
      curve:
          Interval(startFraction, endFraction, curve: Curves.easeOutCubic),
    ));

    return FadeTransition(
      opacity: fade,
      child: SlideTransition(
        position: slide,
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.md,
            vertical: MitlistSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerLow,
            border: Border.all(color: colorScheme.outline, width: 2),
          ),
          child: Text(
            text,
            style: MitlistTypography.monoBody(color: colorScheme.onSurface),
          ),
        ),
      ),
    );
  }
}
