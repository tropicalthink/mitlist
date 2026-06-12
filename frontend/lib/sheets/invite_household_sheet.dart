import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../models/group_models.dart';
import '../providers/group_provider.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../utils/friendly_error.dart';
import '../widgets/alert.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_icon.dart';

class InviteHouseholdSheet extends ConsumerStatefulWidget {
  const InviteHouseholdSheet({super.key, required this.groupId});

  final String groupId;

  static const double _qrSize = MitlistSpacing.space24 * 2;

  static Future<void> show(BuildContext context, {required String groupId}) {
    return showAppBottomSheet<void>(
      context: context,
      title: 'Invite to household',
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
        _error = friendlyErrorMessage(e);
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
              label: 'Invite code: ${code.trim()}',
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
                label: 'Household invite QR code',
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
                              data: code.trim(),
                              version: QrVersions.auto,
                              size: InviteHouseholdSheet._qrSize,
                              backgroundColor: Colors.transparent,
                              eyeStyle: QrEyeStyle(color: qrFg),
                              dataModuleStyle:
                                  QrDataModuleStyle(color: qrFg),
                              errorCorrectionLevel: QrErrorCorrectLevel.M,
                              semanticsLabel: 'Household invite QR',
                              errorStateBuilder: (context, _) => SizedBox(
                                width: InviteHouseholdSheet._qrSize,
                                height: InviteHouseholdSheet._qrSize,
                                child: Center(
                                  child: Text(
                                    'QR unavailable',
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
              'Scan to join, or share the code below.',
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
                    text: _copied ? 'Copied!' : 'Copy code',
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
                  text: _isLoading ? 'Generating…' : 'New code',
                  isLoading: _isLoading,
                  onPressed: _isLoading ? null : _createInvite,
                ),
              ),
            ],
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
