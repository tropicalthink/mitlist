import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../l10n/app_localizations.dart';
import '../../providers/oauth_provider.dart';
import '../../theme/animations.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/open_in_app.dart';
import '../../widgets/app_button.dart';
import '../../widgets/board/artifact_scraps.dart';
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final invite = _inviteCode;
    final invited = invite != null && invite.isNotEmpty;
    // Sign-up is an email + password form; without passwords a new account is
    // made by Google or Apple on the login screen, so "create" goes there.
    final passwordAuth =
        ref.watch(oauthProvidersProvider).valueOrNull?.password ?? true;
    final createRoute = passwordAuth ? 'signup' : 'login';

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
                        // A phone browser is where the invite lands when the
                        // device has not claimed the link for the app. Someone
                        // who already has the app installed is signed in
                        // there, not here, so the hop comes first.
                        if (isMobileBrowser) ...[
                          SizedBox(
                            width: double.infinity,
                            child: AppButton(
                              text: l10n.openInAppButton,
                              variant: AppButtonVariant.solid,
                              color: AppButtonColor.primary,
                              size: AppButtonSize.lg,
                              onPressed: () => launchUrl(
                                openInAppUri(
                                  '/join/${invite.trim().toUpperCase()}',
                                  isAndroid: isAndroidBrowser,
                                  fallbackUrl: Uri.base,
                                ),
                                webOnlyWindowName: '_self',
                              ),
                            ),
                          ),
                          const SizedBox(height: MitlistSpacing.space3),
                        ],
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            text: l10n.authJoinCreateToJoin,
                            // Secondary once the app hop is the headline.
                            variant: isMobileBrowser
                                ? AppButtonVariant.outline
                                : AppButtonVariant.solid,
                            color: AppButtonColor.primary,
                            size: AppButtonSize.lg,
                            onPressed: () => _goToAuth(createRoute),
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
                        // Two doors. "Get started" is the tour, which ends
                        // on the account choice (including guest); the
                        // sign-in door is for people who already have one.
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            text: l10n.welcomeGetStarted,
                            variant: AppButtonVariant.solid,
                            color: AppButtonColor.primary,
                            size: AppButtonSize.lg,
                            onPressed: () => context.goNamed('tour'),
                          ),
                        ),
                        const SizedBox(height: MitlistSpacing.space3),
                        SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            text: l10n.welcomeHaveAccount,
                            variant: AppButtonVariant.outline,
                            color: AppButtonColor.primary,
                            size: AppButtonSize.lg,
                            onPressed: () => _goToAuth('login'),
                          ),
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
                      child: ListScrap(label: l10n.navLists),
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
                        child: ReceiptScrap(label: l10n.navMoney),
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
                        child: ChoreScrap(label: l10n.navChores),
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
                      child: RecipeScrap(label: l10n.navKitchen),
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
