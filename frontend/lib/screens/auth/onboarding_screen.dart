import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/group_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../sheets/create_household_sheet.dart';
import '../../sheets/invite_household_sheet.dart';
import '../../sheets/join_household_sheet.dart';
import '../../theme/animations.dart';
import '../../theme/colors.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/haptics.dart';

/// First-run choice, staged as the app's own metaphor: a cork board.
///
/// "Create a household" is a fresh sticky note; "join with invite" is a torn
/// paper slip. Both drop onto the board and settle with a spring wobble, the
/// same physical language the pinwall uses once the household exists. Under
/// reduced motion the board is simply already dressed.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  // One master timeline; each element owns an interval of it. Springs are
  // expressed as curves so the whole entrance is a single ticker (no timers,
  // deterministic under test, trivially skippable for reduced motion).
  late final Animation<double> _headerT;
  late final Animation<double> _createT;
  late final Animation<double> _joinT;

  // Landing haptics fire once per note as its spring first reaches rest.
  static const double _createLandsAt = 0.66;
  static const double _joinLandsAt = 0.84;
  bool _createLanded = false;
  bool _joinLanded = false;
  bool _didStart = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _headerT = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.0, 0.22, curve: MitlistAnimations.easeEnter),
    );
    _createT = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.12, 0.72, curve: _SettleCurve()),
    );
    _joinT = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0.30, 0.90, curve: _SettleCurve()),
    );

    _controller.addListener(_onTick);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _startAnimation();
      unawaited(_checkExistingGroups());
    });
  }

  void _onTick() {
    final v = _controller.value;
    if (!_createLanded && v >= _createLandsAt) {
      _createLanded = true;
      unawaited(Haptics.light());
    }
    if (!_joinLanded && v >= _joinLandsAt) {
      _joinLanded = true;
      unawaited(Haptics.light());
    }
  }

  Future<void> _checkExistingGroups() async {
    try {
      final groups = await ref
          .read(cachedGroupsProvider.future)
          .timeout(const Duration(seconds: 10));
      if (!mounted) return;
      // Only skip onboarding when the user already belongs to a shared household.
      final hasHousehold = groups.any((g) => g.isPersonal == false);
      if (hasHousehold) {
        context.goNamed('home');
      }
    } catch (_) {
      // API slow/unavailable — keep onboarding visible so the user can proceed.
    }
  }

  void _startAnimation() {
    if (_didStart) return;
    _didStart = true;
    if (MediaQuery.of(context).disableAnimations) {
      _createLanded = true;
      _joinLanded = true;
      _controller.value = 1.0;
    } else {
      unawaited(_controller.forward());
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onCreateHousehold() async {
    await Haptics.light();
    if (!mounted) return;
    final group = await CreateHouseholdSheet.show(context);
    if (group == null || !mounted) return;
    unawaited(ref.read(currentGroupIdProvider.notifier).set(group.id));
    // A one-person household is an empty product. The moment right after
    // creation is the highest-value time to invite the rest of the house, so
    // offer the invite code here (still on the board) — dismissing it lands
    // on the hub either way.
    await InviteHouseholdSheet.show(context, groupId: group.id);
    if (!mounted) return;
    context.goNamed('home');
  }

  Future<void> _onJoinHousehold() async {
    await Haptics.light();
    if (!mounted) return;
    final group = await JoinHouseholdSheet.show(context);
    if (group != null && mounted) {
      unawaited(ref.read(currentGroupIdProvider.notifier).set(group.id));
      context.goNamed('home');
    }
  }

  /// Fade + drop + settle-into-tilt for one board object. The spring curve
  /// overshoots past 1.0, which reads as the note dipping past its rest
  /// position and tipping past its final tilt before settling: the landing.
  Widget _boardDrop({
    required Animation<double> t,
    required double tilt,
    required Widget child,
  }) {
    return AnimatedBuilder(
      animation: t,
      child: child,
      builder: (context, child) {
        final v = t.value;
        return Opacity(
          opacity: (v * 2.5).clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - v) * -120),
            child: Transform.rotate(angle: tilt * v, child: child),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Boundary keeps the grain from re-rasterizing on every frame of
          // the entrance animation above it.
          RepaintBoundary(
            child: CustomPaint(painter: _CorkBoardPainter(dark: dark)),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final noteWidth = math.min(400.0, constraints.maxWidth * 0.86);
                return SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: Center(
                      child: Padding(
                        padding: const EdgeInsets.all(MitlistSpacing.md),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _boardDrop(
                              t: _headerT,
                              tilt: 0.010,
                              child: Center(
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 440),
                                  child: _TapedHeader(l10n: l10n),
                                ),
                              ),
                            ),
                            const SizedBox(height: MitlistSpacing.space8),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: SizedBox(
                                width: noteWidth,
                                child: _boardDrop(
                                  t: _createT,
                                  tilt: -0.040,
                                  child: _Pressable(
                                    semanticLabel:
                                        l10n.authOnboardingCreateHousehold,
                                    onTap: _onCreateHousehold,
                                    child: _StickyNote(
                                      dark: dark,
                                      title: l10n.authOnboardingCreateHousehold,
                                      body: l10n.authOnboardingCreateDesc,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(height: MitlistSpacing.space7),
                            Align(
                              alignment: Alignment.centerRight,
                              child: SizedBox(
                                width: noteWidth,
                                child: _boardDrop(
                                  t: _joinT,
                                  tilt: 0.032,
                                  child: _Pressable(
                                    semanticLabel:
                                        l10n.authOnboardingJoinSemantic,
                                    onTap: _onJoinHousehold,
                                    child: _TornSlip(
                                      title: l10n.authOnboardingJoinInvite,
                                      body: l10n.authOnboardingJoinDesc,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Motion ───────────────────────────────────────────────────────────────────

/// Underdamped spring response as a curve: rises, overshoots ~8%, settles.
/// Expressed as a curve (not a SpringSimulation) so several elements can share
/// one master controller and stagger via [Interval] without pending timers.
class _SettleCurve extends Curve {
  const _SettleCurve();

  static const double _zeta = 0.62;
  static const double _omega = 5.9;

  @override
  double transformInternal(double t) {
    final omegaD = _omega * math.sqrt(1 - _zeta * _zeta);
    final decay = math.exp(-_zeta * _omega * t);
    return 1 -
        decay *
            (math.cos(omegaD * t) +
                (_zeta * _omega / omegaD) * math.sin(omegaD * t));
  }
}

// ─── Board objects ────────────────────────────────────────────────────────────

/// Press affordance shared by both notes: the object lifts slightly under the
/// finger (scale down against its hard shadow reads as being pressed onto the
/// board), then triggers.
class _Pressable extends StatefulWidget {
  const _Pressable({
    required this.semanticLabel,
    required this.onTap,
    required this.child,
  });

  final String semanticLabel;
  final VoidCallback onTap;
  final Widget child;

  @override
  State<_Pressable> createState() => _PressableState();
}

class _PressableState extends State<_Pressable> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedScale(
            scale: _pressed ? 0.975 : 1.0,
            duration: MitlistAnimations.micro,
            curve: MitlistAnimations.easeExit,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

/// The headline, written on a strip of paper taped to the board.
class _TapedHeader extends StatelessWidget {
  const _TapedHeader({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(
            MitlistSpacing.lg,
            MitlistSpacing.space5,
            MitlistSpacing.lg,
            MitlistSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: MitlistColors.surfacePrimary,
            border: Border.all(color: MitlistColors.borderPrimary, width: 2),
            boxShadow: MitlistShadows.shadowMedium,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.authOnboardingSetupHome,
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: MitlistColors.textPrimary,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.5,
                      height: 1.05,
                    ),
              ),
              const SizedBox(height: MitlistSpacing.space2),
              Text(
                l10n.authOnboardingCreateOrJoin,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: MitlistColors.textPrimary.withValues(alpha: 0.72),
                      height: 1.4,
                    ),
              ),
            ],
          ),
        ),
        const _Tape(left: 18, angle: -0.35),
        const _Tape(right: 18, angle: 0.30),
      ],
    );
  }
}

/// A piece of translucent tape crossing the paper's top edge.
class _Tape extends StatelessWidget {
  const _Tape({this.left, this.right, required this.angle});

  final double? left;
  final double? right;
  final double angle;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: -8,
      left: left,
      right: right,
      child: Transform.rotate(
        angle: angle,
        child: Container(
          width: 52,
          height: 18,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.45),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.65),
              width: 1,
            ),
          ),
        ),
      ),
    );
  }
}

/// "Create a household": a fresh sticky note held by a pushpin.
class _StickyNote extends StatelessWidget {
  const _StickyNote({
    required this.dark,
    required this.title,
    required this.body,
  });

  final bool dark;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final noteColor =
        dark ? MitlistColors.noteYellowDark : MitlistColors.noteYellow;
    final ink = dark ? MitlistColors.neutral50 : MitlistColors.textPrimary;

    return Stack(
      clipBehavior: Clip.none,
      alignment: Alignment.topCenter,
      children: [
        Container(
          width: double.infinity,
          margin: const EdgeInsets.only(top: MitlistSpacing.space2),
          padding: const EdgeInsets.fromLTRB(
            MitlistSpacing.lg,
            MitlistSpacing.space6,
            MitlistSpacing.lg,
            MitlistSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: noteColor,
            border: Border.all(color: MitlistColors.borderPrimary, width: 2),
            boxShadow: MitlistShadows.shadowStrong,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: ink,
                      fontWeight: FontWeight.w800,
                      height: 1.1,
                    ),
              ),
              const SizedBox(height: MitlistSpacing.space2),
              Text(
                body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: ink.withValues(alpha: 0.82),
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: MitlistSpacing.space3),
              Align(
                alignment: Alignment.centerRight,
                child: Icon(Icons.arrow_forward, size: 20, color: ink),
              ),
            ],
          ),
        ),
        // The pushpin holding the note to the board.
        Positioned(top: 0, child: _PushPin()),
      ],
    );
  }
}

class _PushPin extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 20,
      height: 20,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: MitlistColors.primary500,
        border: Border.fromBorderSide(
          BorderSide(color: MitlistColors.borderPrimary, width: 2),
        ),
        boxShadow: MitlistShadows.shadowSoft,
      ),
    );
  }
}

/// "Join with invite": a slip of paper torn off a note, pinned at one corner,
/// with a blank code field waiting to be filled.
class _TornSlip extends StatelessWidget {
  const _TornSlip({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    // Paper stays paper-white in both themes, like the invite code chips on
    // the welcome screen, so ink contrast is constant.
    const ink = MitlistColors.textPrimary;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CustomPaint(
          painter: const _TornPaperPainter(),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              MitlistSpacing.lg,
              MitlistSpacing.space6,
              MitlistSpacing.lg,
              MitlistSpacing.lg,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: ink,
                        fontWeight: FontWeight.w800,
                        height: 1.1,
                      ),
                ),
                const SizedBox(height: MitlistSpacing.space2),
                Text(
                  body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: ink.withValues(alpha: 0.72),
                        height: 1.4,
                      ),
                ),
                const SizedBox(height: MitlistSpacing.space4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MitlistSpacing.space3,
                        vertical: MitlistSpacing.space2,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: ink.withValues(alpha: 0.45),
                          width: 2,
                        ),
                      ),
                      child: Text(
                        '····-····',
                        style: MitlistTypography.monoBody(
                          color: ink.withValues(alpha: 0.55),
                        ),
                      ),
                    ),
                    const Spacer(),
                    const Icon(Icons.arrow_forward, size: 20, color: ink),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Pinned by one corner, so the slip hangs slightly askew.
        const Positioned(top: -6, right: 26, child: _CornerPin()),
      ],
    );
  }
}

class _CornerPin extends StatelessWidget {
  const _CornerPin();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 18,
      height: 18,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: MitlistColors.primary500,
        border: Border.fromBorderSide(
          BorderSide(color: MitlistColors.borderPrimary, width: 2),
        ),
        boxShadow: MitlistShadows.shadowSoft,
      ),
    );
  }
}

/// Paper with a torn top edge, drawn with the brand's hard offset shadow so
/// the border can follow the tear (a clipped Container's border can't).
class _TornPaperPainter extends CustomPainter {
  const _TornPaperPainter();

  Path _paperPath(Size size) {
    final path = Path()..moveTo(0, 12);
    // Deterministic tear: fixed jitter heights so the edge never dances
    // between repaints.
    const teeth = [4.0, 13.0, 7.0, 15.0, 5.0, 11.0, 3.0, 14.0, 8.0];
    for (var i = 0; i < teeth.length; i++) {
      final x = size.width * (i + 1) / teeth.length;
      path.lineTo(x, teeth[i]);
    }
    path
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paper = _paperPath(size);

    // Hard offset shadow, same idiom as MitlistShadows.
    canvas.save();
    canvas.translate(6, 6);
    canvas.drawPath(paper, Paint()..color = MitlistColors.neutral950);
    canvas.restore();

    canvas.drawPath(paper, Paint()..color = MitlistColors.surfacePrimary);
    canvas.drawPath(
      paper,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..color = MitlistColors.borderPrimary,
    );
  }

  @override
  bool shouldRepaint(_TornPaperPainter oldDelegate) => false;
}

// ─── The board itself ─────────────────────────────────────────────────────────

/// Full-bleed cork with grain flecks and an edge vignette: the same surface
/// the pinwall board is made of, so the first screen and the household's
/// board are recognizably one material.
class _CorkBoardPainter extends CustomPainter {
  const _CorkBoardPainter({required this.dark});

  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final cork =
        dark ? MitlistColors.pinwallBoardDark : MitlistColors.pinwallBoard;
    final grain = dark
        ? MitlistColors.pinwallBoardBorderDark
        : MitlistColors.pinwallBoardBorder;

    canvas.drawRect(Offset.zero & size, Paint()..color = cork);

    final rng = _LCG(seed: 42);
    final grainPaint = Paint()
      ..color = grain.withValues(alpha: dark ? 0.18 : 0.12)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 500; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final len = 8 + rng.nextDouble() * 24;
      final drift = (rng.nextDouble() - 0.5) * 0.4;
      canvas.drawLine(
        Offset(x, y),
        Offset(
          x + len * (1 + drift),
          y + len * 0.15 * (rng.nextDouble() - 0.5),
        ),
        grainPaint,
      );
    }

    final vignette = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          (dark ? Colors.black : MitlistColors.pinwallBoardBorder)
              .withValues(alpha: dark ? 0.28 : 0.14),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Offset.zero & size);
    canvas.drawRect(Offset.zero & size, vignette);
  }

  @override
  bool shouldRepaint(_CorkBoardPainter oldDelegate) => oldDelegate.dark != dark;
}

// Deterministic pseudo-random (LCG), matching the pinwall's grain generator.
class _LCG {
  _LCG({required int seed}) : _s = seed;
  int _s;
  double nextDouble() {
    _s = (_s * 1664525 + 1013904223) & 0xFFFFFFFF;
    return (_s & 0x7FFFFFFF) / 0x7FFFFFFF;
  }
}
