import 'dart:async';

import 'dart:math' show min;

import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';

import '../models/group_models.dart';
import '../providers/group_provider.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../utils/friendly_error.dart';
import '../utils/haptics.dart';
import '../utils/invite_link.dart';
import '../widgets/alert.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../l10n/app_localizations.dart';
import '../widgets/app_input.dart';

enum _Phase { entry, joining, success }

class JoinHouseholdSheet extends ConsumerStatefulWidget {
  const JoinHouseholdSheet({super.key});

  static Future<Group?> show(BuildContext context) async {
    final l10n = AppLocalizations.of(context)!;
    return showAppBottomSheet<Group>(
      context: context,
      title: l10n.sheetJoinTitle,
      body: const JoinHouseholdSheet(),
    );
  }

  @override
  ConsumerState<JoinHouseholdSheet> createState() => _JoinHouseholdSheetState();
}

class _JoinHouseholdSheetState extends ConsumerState<JoinHouseholdSheet>
    with TickerProviderStateMixin {
  final _codeController = TextEditingController();
  _Phase _phase = _Phase.entry;
  String? _error;
  Group? _joinedGroup;

  late final ConfettiController _confetti;
  late final AnimationController _lottie;
  late final AnimationController _reveal;
  late final Animation<double> _nameFade;
  late final Animation<Offset> _nameSlide;
  late final Animation<double> _subtitleFade;
  late final Animation<double> _membersFade;
  late final Animation<double> _buttonFade;

  bool get _canJoin =>
      _codeController.text.trim().length >= 4 && _phase == _Phase.entry;

  @override
  void initState() {
    super.initState();
    _confetti = ConfettiController(duration: const Duration(seconds: 3));
    _lottie = AnimationController(
        vsync: this,
        duration: Duration.zero); // duration overridden by Lottie.onLoaded
    _reveal = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _nameFade = CurvedAnimation(
      parent: _reveal,
      curve: const Interval(0.15, 0.65, curve: Curves.easeOut),
    );
    _nameSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _reveal,
      curve: const Interval(0.10, 0.60, curve: Curves.easeOutCubic),
    ));
    _subtitleFade = CurvedAnimation(
      parent: _reveal,
      curve: const Interval(0.30, 0.80, curve: Curves.easeOut),
    );
    _membersFade = CurvedAnimation(
      parent: _reveal,
      curve: const Interval(0.42, 0.88, curve: Curves.easeOut),
    );
    _buttonFade = CurvedAnimation(
      parent: _reveal,
      curve: const Interval(0.56, 1.0, curve: Curves.easeOut),
    );
  }

  @override
  void dispose() {
    _codeController.dispose();
    _confetti.dispose();
    _lottie.dispose();
    _reveal.dispose();
    super.dispose();
  }

  Future<void> _onJoin() async {
    if (!_canJoin) return;
    setState(() {
      _phase = _Phase.joining;
      _error = null;
    });

    try {
      final svc = await ref.read(groupServiceProviderAsync.future);
      final group = await svc.joinGroup(
        JoinGroupRequest(code: _codeController.text.trim().toUpperCase()),
      );
      // The cached household list must be refetched before any screen
      // resolves its active group against it — without this the joined group
      // is missing from the cache and the home screen lands on "no household"
      // until an app restart.
      ref.invalidate(cachedGroupsProvider);
      if (!mounted) return;

      setState(() {
        _phase = _Phase.success;
        _joinedGroup = group;
      });

      unawaited(Haptics.success());
      _confetti.play();

      final disableAnimations = MediaQuery.of(context).disableAnimations;
      if (disableAnimations) {
        _lottie.value = 1.0;
        _reveal.value = 1.0;
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _lottie.forward();
            _reveal.forward();
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      unawaited(Haptics.failure());
      setState(() {
        _phase = _Phase.entry;
        _error = friendlyErrorMessage(e, AppLocalizations.of(context)!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 350),
      switchInCurve: Curves.easeOutCubic,
      switchOutCurve: Curves.easeIn,
      transitionBuilder: (child, anim) =>
          FadeTransition(opacity: anim, child: child),
      child: _phase == _Phase.success ? _buildSuccess() : _buildEntry(),
    );
  }

  /// Fills the code field from the clipboard, accepting a bare code, a deep
  /// link, or the web invite link people receive over chat. Most joiners have
  /// the code sitting on their clipboard, so this is the fast path — the QR on
  /// the inviter's screen is scannable with the phone's own camera (it opens
  /// the app via the invite deep link).
  Future<void> _pasteCode() async {
    final l10n = AppLocalizations.of(context)!;
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted) return;
    final code = data?.text == null ? null : extractInviteCode(data!.text!);
    if (code == null) {
      unawaited(Haptics.failure());
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.joinPasteNoCode)),
      );
      return;
    }
    _codeController.value = TextEditingValue(
      text: code,
      selection: TextSelection.collapsed(offset: code.length),
    );
    unawaited(Haptics.light());
    setState(() => _error = null);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.joinPasteFilled)),
    );
  }

  Widget _buildEntry() {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final isJoining = _phase == _Phase.joining;
    return KeyedSubtree(
      key: const ValueKey('entry'),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (_error != null) ...[
            AppAlert(type: AppAlertType.error, message: _error!),
            const SizedBox(height: MitlistSpacing.md),
          ],
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  l10n.sheetJoinCodeLabel,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
              AppButton(
                variant: AppButtonVariant.ghost,
                color: AppButtonColor.primary,
                size: AppButtonSize.sm,
                text: l10n.joinPasteButton,
                icon: const Icon(Icons.content_paste_rounded, size: 16),
                onPressed: isJoining ? null : _pasteCode,
              ),
            ],
          ),
          const SizedBox(height: MitlistSpacing.xs),
          AppInput(
            hint: l10n.sheetJoinCodeExample,
            controller: _codeController,
            enabled: !isJoining,
            textInputAction: TextInputAction.done,
            maxLength: 20,
            prefixIcon: const Icon(Icons.confirmation_number_outlined),
            onChanged: (val) {
              final upper = val.toUpperCase();
              if (upper != val) {
                _codeController.value = _codeController.value.copyWith(
                  text: upper,
                  selection: TextSelection.collapsed(offset: upper.length),
                );
              }
              setState(() {});
            },
            onSubmitted: (_) => _onJoin(),
            keyboardType: TextInputType.text,
          ),
          const SizedBox(height: MitlistSpacing.xs),
          Text(
            l10n.joinCodeFormatHint,
            style: MitlistTypography.labelXSmall(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: MitlistSpacing.lg),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              variant: AppButtonVariant.solid,
              color: AppButtonColor.primary,
              size: AppButtonSize.lg,
              text: isJoining ? l10n.authJoinJoining : l10n.sheetJoinJoin,
              isLoading: isJoining,
              onPressed: _canJoin ? _onJoin : null,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccess() {
    final l10n = AppLocalizations.of(context)!;
    final group = _joinedGroup;
    if (group == null) return _buildEntry();
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final memberCount = group.memberCount ?? 0;

    return KeyedSubtree(
      key: const ValueKey('success'),
      child: Stack(
        alignment: Alignment.topCenter,
        children: [
          ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 48,
            maxBlastForce: 34,
            minBlastForce: 14,
            gravity: 0.22,
            colors: [
              colorScheme.primary,
              colorScheme.tertiary,
              colorScheme.secondary,
              colorScheme.primaryContainer,
            ],
            shouldLoop: false,
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(
              MitlistSpacing.md,
              MitlistSpacing.lg,
              MitlistSpacing.md,
              MitlistSpacing.md,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Lottie checkmark — plays once on reveal
                SizedBox(
                  width: 96,
                  height: 96,
                  child: Lottie.asset(
                    'assets/animations/lottie/Checkmark.lottie',
                    controller: _lottie,
                    onLoaded: (comp) => _lottie.duration = comp.duration,
                    repeat: false,
                  ),
                ),
                const SizedBox(height: MitlistSpacing.md),

                // Household name — slides up and fades in
                FadeTransition(
                  opacity: _nameFade,
                  child: SlideTransition(
                    position: _nameSlide,
                    child: Text(
                      group.name,
                      style: textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),

                // Confirmation line
                const SizedBox(height: MitlistSpacing.xs),
                FadeTransition(
                  opacity: _subtitleFade,
                  child: Text(
                    l10n.authJoinYoureIn,
                    style: textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),

                // Member pips + count
                if (memberCount > 0) ...[
                  const SizedBox(height: MitlistSpacing.md),
                  FadeTransition(
                    opacity: _membersFade,
                    child: _MemberPips(
                      count: memberCount,
                      accentColor: colorScheme.primary,
                      borderColor: colorScheme.surfaceContainerHighest,
                    ),
                  ),
                  const SizedBox(height: MitlistSpacing.xs),
                  FadeTransition(
                    opacity: _membersFade,
                    child: Text(
                      l10n.joinMembersAlreadyInside(memberCount),
                      style: textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ],

                const SizedBox(height: MitlistSpacing.xl),

                // Enter button
                FadeTransition(
                  opacity: _buttonFade,
                  child: SizedBox(
                    width: double.infinity,
                    child: AppButton(
                      variant: AppButtonVariant.solid,
                      size: AppButtonSize.lg,
                      text: l10n.joinEnterGroup(group.name),
                      onPressed: () => Navigator.of(context).pop(group),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Stacked overlapping pip circles representing household members
class _MemberPips extends StatelessWidget {
  final int count;
  final Color accentColor;
  final Color borderColor;

  const _MemberPips({
    required this.count,
    required this.accentColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    const pipSize = 32.0;
    const overlap = 10.0;
    const maxVisible = 5;

    final visible = min(count, maxVisible);
    final hasOverflow = count > maxVisible;
    final totalItems = visible + (hasOverflow ? 1 : 0);
    final totalWidth = pipSize + (totalItems - 1) * (pipSize - overlap);

    return SizedBox(
      width: totalWidth,
      height: pipSize,
      child: Stack(
        children: [
          for (var i = 0; i < visible; i++)
            Positioned(
              left: i * (pipSize - overlap),
              child: Container(
                width: pipSize,
                height: pipSize,
                decoration: BoxDecoration(
                  color: accentColor.withValues(
                    alpha: 1.0 - i * (0.55 / maxVisible),
                  ),
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 2),
                ),
              ),
            ),
          if (hasOverflow)
            Positioned(
              left: visible * (pipSize - overlap),
              child: Container(
                width: pipSize,
                height: pipSize,
                decoration: BoxDecoration(
                  color: borderColor,
                  shape: BoxShape.circle,
                  border: Border.all(color: borderColor, width: 2),
                ),
                alignment: Alignment.center,
                child: Text(
                  '+${count - maxVisible}',
                  style: MitlistTypography.labelXSmall(color: accentColor),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
