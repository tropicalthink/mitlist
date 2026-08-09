import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/auth_provider.dart';
import '../../theme/animations.dart';
import '../../theme/colors.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/friendly_error.dart';
import '../../widgets/app_button.dart';
import '../../widgets/board/cork_board.dart';

/// The first thing a new user sees: the cork board itself, with the app's name
/// taped to it and four pinned scraps — a shopping list, a receipt, a chore
/// note, a recipe card — that say what mitlist is before a single word of
/// explanation. The same board carries sign-up, household setup, and finally
/// becomes the household's own pinwall.
class WelcomeScreen extends ConsumerStatefulWidget {
  const WelcomeScreen({super.key});

  @override
  ConsumerState<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends ConsumerState<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  bool _isGuestLoading = false;

  late final AnimationController _controller;
  late final Animation<double> _logoT;
  late final List<Animation<double>> _scrapT;

  // One light haptic as the last scrap lands; the board is dressed.
  static const double _lastLandsAt = 0.94;
  bool _landed = false;
  bool _didStart = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _logoT = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.24, curve: MitlistAnimations.easeEnter),
    );
    _scrapT = [
      for (var i = 0; i < 4; i++)
        CurvedAnimation(
          parent: _controller,
          curve: Interval(
            0.14 + i * 0.13,
            0.54 + i * 0.13,
            curve: const SettleCurve(),
          ),
        ),
    ];
    _controller.addListener(_onTick);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _didStart) return;
      _didStart = true;
      if (MediaQuery.of(context).disableAnimations) {
        _landed = true;
        _controller.value = 1.0;
      } else {
        unawaited(_controller.forward());
      }
    });
  }

  void _onTick() {
    if (!_landed && _controller.value >= _lastLandsAt) {
      _landed = true;
      unawaited(HapticFeedback.lightImpact());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String? get _inviteCode =>
      GoRouterState.of(context).uri.queryParameters['invite'];

  void _goToAuth(String routeName) {
    final invite = _inviteCode;
    if (invite != null && invite.isNotEmpty) {
      context.goNamed(routeName, queryParameters: {'invite': invite});
    } else {
      context.goNamed(routeName);
    }
  }

  Future<void> _onGuestContinue() async {
    unawaited(HapticFeedback.lightImpact());
    if (_isGuestLoading) return;
    setState(() => _isGuestLoading = true);
    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      await authService.createGuest();
      final invite = _inviteCode;
      if (invite != null && invite.isNotEmpty) {
        ref.read(pendingAuthNavigationProvider.notifier).state =
            '/join/${Uri.encodeComponent(invite)}';
      } else {
        ref.read(pendingAuthNavigationProvider.notifier).state = '/onboarding';
      }
      ref.read(authStateProvider.notifier).state = true;
      ref.read(isGuestProvider.notifier).state = true;
    } catch (e) {
      if (!mounted) return;
      setState(() => _isGuestLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final invite = _inviteCode;
    final invited = invite != null && invite.isNotEmpty;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CorkBoardBackground(),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(MitlistSpacing.md),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final contentW = math.min(440.0, constraints.maxWidth);
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // The staged part of the screen (logo paper + pinned
                      // scraps) scales down as one piece on short viewports;
                      // the action stack below never leaves the screen.
                      Expanded(
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          child: SizedBox(
                            width: contentW,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                BoardDrop(
                                  t: _logoT,
                                  tilt: -0.008,
                                  dropHeight: 60,
                                  child: _LogoPaper(l10n: l10n),
                                ),
                                const SizedBox(height: MitlistSpacing.space7),
                                if (invited)
                                  _InvitePinnedNote(code: invite)
                                else
                                  _PillarCollage(
                                    l10n: l10n,
                                    anims: _scrapT,
                                    width: contentW,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: MitlistSpacing.space6),
                      if (invited) ...[
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            text: l10n.authJoinCreateToJoin,
                            variant: AppButtonVariant.solid,
                            color: AppButtonColor.primary,
                            size: AppButtonSize.lg,
                            onPressed: () => _goToAuth('signup'),
                          ),
                        ),
                        const SizedBox(height: MitlistSpacing.space3),
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            text: l10n.authJoinSignInToJoin,
                            variant: AppButtonVariant.outline,
                            color: AppButtonColor.primary,
                            size: AppButtonSize.lg,
                            onPressed: () => _goToAuth('login'),
                          ),
                        ),
                      ] else ...[
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            text: l10n.welcomeCreateHousehold,
                            variant: AppButtonVariant.solid,
                            color: AppButtonColor.primary,
                            size: AppButtonSize.lg,
                            onPressed: () => _goToAuth('signup'),
                          ),
                        ),
                        const SizedBox(height: MitlistSpacing.space3),
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            text: l10n.welcomeSignIn,
                            variant: AppButtonVariant.outline,
                            color: AppButtonColor.primary,
                            size: AppButtonSize.lg,
                            onPressed: () => _goToAuth('login'),
                          ),
                        ),
                        const SizedBox(height: MitlistSpacing.space3),
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            text: _isGuestLoading
                                ? l10n.welcomeGuestLoading
                                : l10n.welcomeContinueAsGuest,
                            variant: AppButtonVariant.ghost,
                            // Neutral ink, not the orange accent: mid-tone
                            // orange on mid-tone cork fails contrast.
                            color: AppButtonColor.neutral,
                            size: AppButtonSize.lg,
                            onPressed:
                                _isGuestLoading ? null : _onGuestContinue,
                          ),
                        ),
                        const SizedBox(height: MitlistSpacing.sm),
                        Text(
                          l10n.welcomeGuestFootnote,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface,
                              ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The app's name and tagline on a strip of paper taped to the board.
class _LogoPaper extends StatelessWidget {
  const _LogoPaper({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return TapedPaper(
      padding: const EdgeInsets.fromLTRB(
        MitlistSpacing.lg,
        MitlistSpacing.space5,
        MitlistSpacing.lg,
        MitlistSpacing.space5,
      ),
      child: Column(
        children: [
          Text(
            'mitlist',
            style: MitlistTypography.logo(color: MitlistColors.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MitlistSpacing.space2),
          Text(
            l10n.welcomeTagline,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: MitlistColors.textPrimary.withValues(alpha: 0.72),
                ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// Four pinned scraps that introduce the four pillars without a word of
/// marketing copy: a shopping list, a receipt, a chore note, a recipe card.
/// Purely illustrative — one semantic label covers the group.
class _PillarCollage extends StatelessWidget {
  const _PillarCollage({
    required this.l10n,
    required this.anims,
    required this.width,
  });

  final AppLocalizations l10n;
  final List<Animation<double>> anims;
  final double width;

  @override
  Widget build(BuildContext context) {
    const gap = MitlistSpacing.space4;
    final scrapW = (width - gap) / 2;
    return Semantics(
      label: l10n.welcomePillarsSemantic,
      child: ExcludeSemantics(
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: scrapW,
                    child: BoardDrop(
                      t: anims[0],
                      tilt: -0.035,
                      dropHeight: 90,
                      child: _ListScrap(label: l10n.navLists),
                    ),
                  ),
                  SizedBox(width: gap),
                  SizedBox(
                    width: scrapW,
                    child: Padding(
                      padding:
                          const EdgeInsets.only(top: MitlistSpacing.space3),
                      child: BoardDrop(
                        t: anims[1],
                        tilt: 0.030,
                        dropHeight: 90,
                        child: _ReceiptScrap(label: l10n.navMoney),
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: gap),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: scrapW,
                    child: Padding(
                      padding:
                          const EdgeInsets.only(top: MitlistSpacing.space2),
                      child: BoardDrop(
                        t: anims[2],
                        tilt: 0.026,
                        dropHeight: 90,
                        child: _ChoreScrap(label: l10n.navChores),
                      ),
                    ),
                  ),
                  SizedBox(width: gap),
                  SizedBox(
                    width: scrapW,
                    child: BoardDrop(
                      t: anims[3],
                      tilt: -0.028,
                      dropHeight: 90,
                      child: _RecipeScrap(label: l10n.navKitchen),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Greeked line of text: a soft bar standing in for handwriting.
class _InkBar extends StatelessWidget {
  const _InkBar({required this.width, this.color});

  final double width;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: 6,
      color: color ?? MitlistColors.textPrimary.withValues(alpha: 0.22),
    );
  }
}

class _ScrapLabel extends StatelessWidget {
  const _ScrapLabel(this.text, {this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color ?? MitlistColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

/// White paper scrap pinned to the board; base for the list and receipt props.
class _PaperScrap extends StatelessWidget {
  const _PaperScrap({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: 7),
          padding: const EdgeInsets.fromLTRB(
            MitlistSpacing.space4,
            MitlistSpacing.space4,
            MitlistSpacing.space4,
            MitlistSpacing.space4,
          ),
          decoration: const BoxDecoration(
            color: MitlistColors.surfacePrimary,
            border: Border.fromBorderSide(
              BorderSide(color: MitlistColors.borderPrimary, width: 2),
            ),
            boxShadow: MitlistShadows.shadowMedium,
          ),
          child: child,
        ),
        const Positioned(top: 0, child: BoardPushPin(size: 16)),
      ],
    );
  }
}

/// A scrap of shopping list: checkboxes, one already ticked.
class _ListScrap extends StatelessWidget {
  const _ListScrap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    Widget row({required bool checked, required double barWidth}) {
      return Row(
        children: [
          Container(
            width: 14,
            height: 14,
            decoration: BoxDecoration(
              color: checked ? MitlistColors.primary500 : Colors.transparent,
              border: Border.all(color: MitlistColors.borderPrimary, width: 2),
            ),
            child: checked
                ? const Icon(Icons.check, size: 10, color: Colors.white)
                : null,
          ),
          const SizedBox(width: MitlistSpacing.space2),
          _InkBar(width: barWidth),
        ],
      );
    }

    return _PaperScrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ScrapLabel(label),
          const SizedBox(height: MitlistSpacing.space3),
          row(checked: true, barWidth: 52),
          const SizedBox(height: MitlistSpacing.space2),
          row(checked: false, barWidth: 68),
          const SizedBox(height: MitlistSpacing.space2),
          row(checked: false, barWidth: 44),
        ],
      ),
    );
  }
}

/// A scrap of receipt: two amounts and a settled total.
class _ReceiptScrap extends StatelessWidget {
  const _ReceiptScrap({required this.label});

  final String label;

  TextStyle get _mono => MitlistTypography.monoBody(
        color: MitlistColors.textPrimary.withValues(alpha: 0.75),
        weight: FontWeight.w700,
      ).copyWith(fontSize: 11, height: 1.0);

  @override
  Widget build(BuildContext context) {
    Widget amountRow(double barWidth, String amount) {
      return Row(
        children: [
          _InkBar(width: barWidth),
          const Spacer(),
          Text(amount, style: _mono),
        ],
      );
    }

    return _PaperScrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ScrapLabel(label),
          const SizedBox(height: MitlistSpacing.space3),
          amountRow(44, '4.20'),
          const SizedBox(height: MitlistSpacing.space2),
          amountRow(58, '7.80'),
          const SizedBox(height: MitlistSpacing.space2),
          Container(
            height: 2,
            color: MitlistColors.textPrimary.withValues(alpha: 0.30),
          ),
          const SizedBox(height: MitlistSpacing.space2),
          Row(
            children: [
              const Spacer(),
              Text(
                '12.00',
                style: MitlistTypography.monoBody(
                  color: MitlistColors.primary600,
                ).copyWith(fontSize: 12, height: 1.0),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A chore note on mint: one done, the rota dots underneath.
class _ChoreScrap extends StatelessWidget {
  const _ChoreScrap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? MitlistColors.neutral50 : MitlistColors.textPrimary;

    return StickyNoteSurface(
      color: dark ? MitlistColors.noteMintDark : MitlistColors.noteMint,
      padding: const EdgeInsets.all(MitlistSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ScrapLabel(label, color: ink),
          const SizedBox(height: MitlistSpacing.space3),
          Row(
            children: [
              Container(
                width: 16,
                height: 16,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: MitlistColors.primary500,
                  border: Border.fromBorderSide(
                    BorderSide(color: MitlistColors.borderPrimary, width: 2),
                  ),
                ),
                child: const Icon(Icons.check, size: 10, color: Colors.white),
              ),
              const SizedBox(width: MitlistSpacing.space2),
              _InkBar(width: 56, color: ink.withValues(alpha: 0.28)),
            ],
          ),
          const SizedBox(height: MitlistSpacing.space3),
          Row(
            children: [
              for (var i = 0; i < 3; i++) ...[
                Container(
                  width: 10,
                  height: 10,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i == 0
                        ? ink.withValues(alpha: 0.55)
                        : Colors.transparent,
                    border: Border.all(
                      color: ink.withValues(alpha: 0.55),
                      width: 1.5,
                    ),
                  ),
                ),
                if (i < 2) const SizedBox(width: MitlistSpacing.space1),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// A recipe card on sky blue: title bar and dotted ingredient lines.
class _RecipeScrap extends StatelessWidget {
  const _RecipeScrap({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? MitlistColors.neutral50 : MitlistColors.textPrimary;

    Widget ingredient(double barWidth) {
      return Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ink.withValues(alpha: 0.45),
            ),
          ),
          const SizedBox(width: MitlistSpacing.space2),
          _InkBar(width: barWidth, color: ink.withValues(alpha: 0.28)),
        ],
      );
    }

    return StickyNoteSurface(
      color: dark ? MitlistColors.noteSkyDark : MitlistColors.noteSky,
      padding: const EdgeInsets.all(MitlistSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ScrapLabel(label, color: ink),
          const SizedBox(height: MitlistSpacing.space3),
          _InkBar(width: 72, color: ink.withValues(alpha: 0.40)),
          const SizedBox(height: MitlistSpacing.space3),
          ingredient(48),
          const SizedBox(height: MitlistSpacing.space2),
          ingredient(60),
        ],
      ),
    );
  }
}

/// The invite "moment": the invitation arrives as a sticky note pinned to the
/// board, in mitlist's own pinwall idiom. It drops in and settles into a
/// slight tilt; under reduced-motion it simply appears, already tilted.
class _InvitePinnedNote extends StatelessWidget {
  const _InvitePinnedNote({required this.code});

  final String code;

  static const double _tilt = -0.045; // ~ -2.6°, like a note tacked to a board

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reduce = MediaQuery.of(context).disableAnimations;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final noteColor =
        isDark ? MitlistColors.notePeachDark : MitlistColors.notePeach;
    final ink = isDark ? MitlistColors.neutral50 : MitlistColors.textPrimary;
    final parts = code.trim().toUpperCase().split('-');

    final note = Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 440),
        child: StickyNoteSurface(
          color: noteColor,
          padding: const EdgeInsets.fromLTRB(
            MitlistSpacing.lg,
            MitlistSpacing.space7,
            MitlistSpacing.lg,
            MitlistSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                l10n.welcomeInviteHeadline.toUpperCase(),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.0,
                    ),
              ),
              const SizedBox(height: MitlistSpacing.space3),
              Text(
                l10n.welcomeInviteSubtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ink,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: MitlistSpacing.space5),
              Wrap(
                spacing: MitlistSpacing.space2,
                runSpacing: MitlistSpacing.space2,
                children: [
                  for (final part in parts)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MitlistSpacing.space3,
                        vertical: MitlistSpacing.space2,
                      ),
                      decoration: BoxDecoration(
                        color: MitlistColors.surfacePrimary,
                        border: Border.all(
                          color: MitlistColors.borderPrimary,
                          width: 2,
                        ),
                      ),
                      child: Text(
                        part,
                        style: MitlistTypography.monoBody(
                          color: MitlistColors.textPrimary,
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    final semantic = Semantics(
      label: l10n.authJoinInviteCodeSemantic(code.trim().toUpperCase()),
      child: note,
    );

    if (reduce) {
      return Transform.rotate(angle: _tilt, child: semantic);
    }

    return TweenAnimationBuilder<double>(
      tween: Tween<double>(begin: 0, end: 1),
      duration: const Duration(milliseconds: 460),
      curve: Curves.easeOutCubic,
      child: semantic,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, (1 - t) * -26),
          child: Transform.rotate(angle: _tilt * t, child: child),
        ),
      ),
    );
  }
}
