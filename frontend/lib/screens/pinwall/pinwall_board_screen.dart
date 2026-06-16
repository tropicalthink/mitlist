import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../models/auth_models.dart';
import '../../models/pinwall_models.dart';
import '../../providers/chore_provider.dart';
import '../../providers/finance_provider.dart';
import '../../providers/list_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/pinwall_provider.dart';
import '../../theme/animations.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../theme/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/haptics.dart';
import '../../utils/hub_helpers.dart';
import '../../widgets/app_button.dart';
import '../../widgets/hub/pinned_memo_card.dart';

// ─── Board layout constants ──────────────────────────────────────────────────

const double _kBoardW = 3200;
const double _kBoardH = 2400;
const double _kCardW = 180;
const double _kCardH = 240;
const double _kMargin = 80;

// Pinned hub-summary band that sits on the cork above the notes.
const double _kSummaryStatsW = 600;
const double _kSummaryTonightW = 420;
const double _kSummaryGap = 40;
const double _kSummaryBandH = 300;
double get _kSummaryRight =>
    _kMargin + _kSummaryStatsW + _kSummaryGap + _kSummaryTonightW;

// ─── Entry point ─────────────────────────────────────────────────────────────

class PinwallBoardScreen extends ConsumerStatefulWidget {
  const PinwallBoardScreen({
    super.key,
    required this.groupId,
    required this.me,
    required this.posts,
  });

  final String groupId;
  final User? me;
  final List<PinwallPost> posts;

  static Future<void> show(
    BuildContext context, {
    required String groupId,
    required User? me,
    required List<PinwallPost> posts,
  }) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder(
        opaque: false,
        barrierColor: Colors.transparent,
        transitionDuration: const Duration(milliseconds: 480),
        reverseTransitionDuration: const Duration(milliseconds: 360),
        pageBuilder: (ctx, animation, secondaryAnimation) =>
            PinwallBoardScreen(groupId: groupId, me: me, posts: posts),
        transitionsBuilder: (ctx, animation, secondaryAnimation, child) =>
            child,
      ),
    );
  }

  @override
  ConsumerState<PinwallBoardScreen> createState() => _PinwallBoardScreenState();
}

class _PinwallBoardScreenState extends ConsumerState<PinwallBoardScreen>
    with TickerProviderStateMixin {
  final TransformationController _transformCtrl = TransformationController();

  late final Map<String, Offset> _positions;
  // Pinned hub-summary cards are draggable too, so they get their own state.
  Offset _statsPos = const Offset(_kMargin, _kMargin);
  Offset _tonightPos =
      const Offset(_kMargin + _kSummaryStatsW + _kSummaryGap, _kMargin);
  late final AnimationController _staggerCtrl;
  late final List<Animation<double>> _noteAnims;
  // Entrance for the pinned summary memos — first beat of the stagger.
  late final CurvedAnimation _summaryAnim;
  // Id of the item currently being dragged, lifted and raised to the front so
  // it can't slide under its neighbours.
  String? _activeId;
  bool _didSetInitialTransform = false;

  static const String _statsId = '__stats__';
  static const String _tonightId = '__tonight__';

  // Shown briefly on first open to hint at pan/zoom
  bool _showHint = true;

  @override
  void initState() {
    super.initState();
    _positions = {
      for (var i = 0; i < widget.posts.length; i++)
        widget.posts[i].id: _gridPosition(i),
    };

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 300 + widget.posts.length * 40,
      ),
    );

    _noteAnims = List.generate(widget.posts.length, (i) {
      final start = (i * 0.07).clamp(0.0, 0.6);
      final end = (start + 0.4).clamp(0.0, 1.0);
      return CurvedAnimation(
        parent: _staggerCtrl,
        curve: Interval(start, end, curve: Curves.easeOutCubic),
      );
    });

    _summaryAnim = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final disableAnim = MediaQuery.of(context).disableAnimations;
      if (disableAnim) {
        _staggerCtrl.value = 1.0;
      } else {
        // Start stagger after Hero flight
        Future.delayed(const Duration(milliseconds: 420), () {
          if (mounted) _staggerCtrl.forward();
        });
      }

      // Hide hint after 3s
      Future.delayed(const Duration(seconds: 3), () {
        if (mounted) setState(() => _showHint = false);
      });
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_didSetInitialTransform) {
      _didSetInitialTransform = true;
      _centerOnNotes();
    }
  }

  @override
  void dispose() {
    _summaryAnim.dispose();
    _transformCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  Offset _gridPosition(int index) {
    const cols = 4;
    final col = index % cols;
    final row = index ~/ cols;

    final baseX = _kMargin + col * (_kCardW + 60.0);
    final baseY = _kMargin + _kSummaryBandH + row * (_kCardH + 50.0);

    final h = widget.posts[index].id.hashCode.abs();
    final jx = ((h % 80) - 40).toDouble();
    final jy = (((h >> 8) % 60) - 30).toDouble();

    return Offset(baseX + jx, baseY + jy);
  }

  void _centerOnNotes() {
    final size = MediaQuery.of(context).size;

    // Start from the pinned summary band so it's always in view, then expand
    // to include the notes cluster.
    double minX = _kMargin, minY = _kMargin;
    double maxX = _kSummaryRight, maxY = _kMargin + _kSummaryBandH;
    for (final p in _positions.values) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx + _kCardW > maxX) maxX = p.dx + _kCardW;
      if (p.dy + _kCardH > maxY) maxY = p.dy + _kCardH;
    }

    final clusterW = maxX - minX;
    final clusterH = maxY - minY;
    final scale = (size.width / (clusterW + 80)).clamp(0.35, 1.0);

    final tx = size.width / 2 - (minX + clusterW / 2) * scale;
    final ty = size.height / 2 - (minY + clusterH / 2) * scale;

    _transformCtrl.value = Matrix4.identity()
      ..translateByDouble(tx, ty, 0, 1)
      ..scaleByDouble(scale, scale, 1, 1);
  }

  // Inside InteractiveViewer's transform, drag deltas are already reported in
  // canvas-local space, so we add them directly (no scale division).
  void _onNoteDrag(String postId, DragUpdateDetails details) {
    setState(() {
      final cur = _positions[postId] ?? Offset.zero;
      _positions[postId] = cur + details.delta;
    });
  }

  void _onStatsDrag(DragUpdateDetails details) {
    setState(() => _statsPos += details.delta);
  }

  void _onTonightDrag(DragUpdateDetails details) {
    setState(() => _tonightPos += details.delta);
  }

  void _lift(String id) {
    unawaited(Haptics.light());
    setState(() => _activeId = id);
  }

  void _drop() {
    if (_activeId == null) return;
    setState(() => _activeId = null);
  }

  /// All draggable cork items, sorted so the lifted card paints last.
  List<Widget> _buildBoardItems(BuildContext context, {required bool dark}) {
    final layers = <({String id, int order, Widget child})>[
      (
        id: _statsId,
        order: 0,
        child: _BoardDraggableItem(
          key: const ValueKey(_statsId),
          position: _statsPos,
          isActive: _activeId == _statsId,
          entrance: _summaryAnim,
          onLift: () => _lift(_statsId),
          onDrop: _drop,
          onDrag: _onStatsDrag,
          child: _BoardStatsCard(groupId: widget.groupId, dark: dark),
        ),
      ),
      (
        id: _tonightId,
        order: 1,
        child: _BoardDraggableItem(
          key: const ValueKey(_tonightId),
          position: _tonightPos,
          isActive: _activeId == _tonightId,
          entrance: _summaryAnim,
          onLift: () => _lift(_tonightId),
          onDrop: _drop,
          onDrag: _onTonightDrag,
          child: _BoardTonightTicket(groupId: widget.groupId, dark: dark),
        ),
      ),
      for (var i = 0; i < widget.posts.length; i++)
        (
          id: widget.posts[i].id,
          order: 2 + i,
          child: _BoardDraggableItem(
            key: ValueKey(widget.posts[i].id),
            position: _positions[widget.posts[i].id]!,
            isActive: _activeId == widget.posts[i].id,
            entrance: _noteAnims[i],
            onLift: () => _lift(widget.posts[i].id),
            onDrop: _drop,
            onDrag: (d) => _onNoteDrag(widget.posts[i].id, d),
            child: _BoardNoteCard(
              index: i,
              groupId: widget.groupId,
              me: widget.me,
              post: widget.posts[i],
            ),
          ),
        ),
    ];

    layers.sort((a, b) {
      final aLifted = a.id == _activeId;
      final bLifted = b.id == _activeId;
      if (aLifted != bLifted) return aLifted ? 1 : -1;
      return a.order.compareTo(b.order);
    });

    return layers.map((l) => l.child).toList();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final boardBg =
        dark ? MitlistColors.pinwallBoardDark : MitlistColors.pinwallBoard;
    final boardBorder = dark
        ? MitlistColors.pinwallBoardBorderDark
        : MitlistColors.pinwallBoardBorder;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Hero(
        tag: 'pinwall_board_${widget.groupId}',
        flightShuttleBuilder: (ctx, anim, dir, fromCtx, toCtx) {
          return AnimatedBuilder(
            animation: anim,
            builder: (_, __) => Container(
              decoration: BoxDecoration(
                color: boardBg,
                borderRadius: BorderRadius.circular(
                  MitlistTheme.radiusLg * (1.0 - anim.value),
                ),
                border: Border.all(color: boardBorder, width: 2),
              ),
            ),
          );
        },
        child: Stack(
          children: [
            // Board surface + notes
            Container(
              color: boardBg,
              child: InteractiveViewer(
                transformationController: _transformCtrl,
                minScale: 0.2,
                maxScale: 2.0,
                constrained: false,
                // Free-pan a canvas larger than the viewport; without this the
                // initial centered transform is clamped and snaps on first touch.
                boundaryMargin: const EdgeInsets.all(double.infinity),
                child: SizedBox(
                  width: _kBoardW,
                  height: _kBoardH,
                  child: _CorkCanvas(
                    dark: dark,
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        ..._buildBoardItems(context, dark: dark),
                        if (widget.posts.isEmpty)
                          Positioned(
                            left: _kMargin,
                            top: _kMargin + _kSummaryBandH,
                            width: _kSummaryRight - _kMargin,
                            child: _EmptyBoardHint(dark: dark),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Top controls
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(MitlistSpacing.md),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _BoardChip(
                      label: l10n.pinwallBoardLabel,
                      icon: Icons.push_pin_outlined,
                      dark: dark,
                    ),
                    _BoardCloseButton(
                      dark: dark,
                      onClose: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),

            // Pan/zoom hint
            if (widget.posts.isNotEmpty)
              AnimatedPositioned(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOut,
                bottom: _showHint ? 32 : -40,
                left: 0,
                right: 0,
                child: IgnorePointer(
                  child: Center(
                    child: _BoardChip(
                      label: l10n.pinwallDragHint,
                      icon: Icons.open_with_rounded,
                      dark: dark,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Cork canvas with grain ───────────────────────────────────────────────────

class _CorkCanvas extends StatelessWidget {
  const _CorkCanvas({required this.dark, required this.child});

  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _CorkGrainPainter(dark: dark),
      child: child,
    );
  }
}

class _CorkGrainPainter extends CustomPainter {
  const _CorkGrainPainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rng = _LCG(seed: 42);
    final grainPaint = Paint()
      ..color = dark
          ? MitlistColors.pinwallBoardBorderDark.withValues(alpha: 0.18)
          : MitlistColors.pinwallBoardBorder.withValues(alpha: 0.12)
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < 1200; i++) {
      final x = rng.nextDouble() * size.width;
      final y = rng.nextDouble() * size.height;
      final len = 8 + rng.nextDouble() * 24;
      final drift = (rng.nextDouble() - 0.5) * 0.4;
      canvas.drawLine(
        Offset(x, y),
        Offset(
            x + len * (1 + drift), y + len * 0.15 * (rng.nextDouble() - 0.5)),
        grainPaint,
      );
    }

    final vignettePaint = Paint()
      ..shader = RadialGradient(
        colors: [
          Colors.transparent,
          (dark ? Colors.black : MitlistColors.pinwallBoardBorder)
              .withValues(alpha: dark ? 0.22 : 0.10),
        ],
        stops: const [0.55, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawRect(
        Rect.fromLTWH(0, 0, size.width, size.height), vignettePaint);
  }

  @override
  bool shouldRepaint(_CorkGrainPainter old) => old.dark != dark;
}

// Deterministic pseudo-random (LCG)
class _LCG {
  _LCG({required int seed}) : _s = seed;
  int _s;
  double nextDouble() {
    _s = (_s * 1664525 + 1013904223) & 0xFFFFFFFF;
    return (_s & 0x7FFFFFFF) / 0x7FFFFFFF;
  }
}

// ─── Empty board state ────────────────────────────────────────────────────────

class _EmptyBoardHint extends StatelessWidget {
  const _EmptyBoardHint({required this.dark});
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textColor = dark
        ? MitlistColors.pinwallNoteTextDark
        : MitlistColors.pinwallNoteTextLight;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.xl),
        child: Text(
          l10n.pinwallEmptyBoard,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: textColor.withValues(alpha: 0.7),
                height: 1.6,
              ),
        ),
      ),
    );
  }
}

// ─── Draggable board item (lift + raise-to-front + entrance) ─────────────────

class _BoardDraggableItem extends StatelessWidget {
  const _BoardDraggableItem({
    super.key,
    required this.position,
    required this.isActive,
    required this.onLift,
    required this.onDrop,
    required this.onDrag,
    required this.child,
    this.entrance,
  });

  final Offset position;
  final bool isActive;
  final VoidCallback onLift;
  final VoidCallback onDrop;
  final void Function(DragUpdateDetails) onDrag;
  final Widget child;
  final Animation<double>? entrance;

  @override
  Widget build(BuildContext context) {
    Widget body = GestureDetector(
      onPanStart: (_) => onLift(),
      onPanUpdate: onDrag,
      onPanEnd: (_) => onDrop(),
      onPanCancel: onDrop,
      behavior: HitTestBehavior.opaque,
      child: AnimatedScale(
        scale: isActive ? 1.04 : 1.0,
        duration: MitlistAnimations.micro,
        curve: MitlistAnimations.easeEnter,
        child: child,
      ),
    );

    final anim = entrance;
    if (anim != null) {
      body = FadeTransition(
        opacity: anim,
        child: ScaleTransition(
          scale: Tween(begin: 0.72, end: 1.0).animate(anim),
          child: body,
        ),
      );
    }

    return Positioned(
      left: position.dx,
      top: position.dy,
      child: body,
    );
  }
}

// ─── Board note card ──────────────────────────────────────────────────────────

class _BoardNoteCard extends ConsumerWidget {
  const _BoardNoteCard({
    required this.index,
    required this.groupId,
    required this.me,
    required this.post,
  });

  final int index;
  final String groupId;
  final User? me;
  final PinwallPost post;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final palette =
        dark ? MitlistColors.notePaletteDark : MitlistColors.notePalette;
    final idHash = post.id.hashCode;
    final bg = palette[idHash.abs() % palette.length];
    final border = bg.withValues(alpha: dark ? 0.3 : 0.6);
    final rot = ((idHash % 13) - 6) * 0.012;

    final pinColors = [
      Theme.of(context).colorScheme.primary,
      Theme.of(context).colorScheme.secondary,
      Theme.of(context).colorScheme.error,
    ];
    final pinColor = pinColors[index % pinColors.length];

    final textColor = dark
        ? MitlistColors.surfaceSoft.withValues(alpha: 0.9)
        : Theme.of(context).colorScheme.onSurface;
    final mutedColor = dark
        ? MitlistColors.surfaceSoft.withValues(alpha: 0.5)
        : Theme.of(context).colorScheme.onSurfaceVariant.withValues(alpha: 0.7);

    final content = post.content.trim();
    final userLabel = formatUserLabel(post.userId, me?.id, l10n);
    final when = relativeDay(post.createdAt);

    final remindAt = post.remindAt;
    final reminderText = remindAt == null
        ? null
        : DateFormat('MMM d · h:mm a').format(remindAt.toLocal());

    final media = ref.watch(
      pinwallMediaByPostProvider((groupId: groupId, postId: post.id)),
    );

    return Semantics(
      label: l10n.pinwallNoteSemantics(userLabel, content),
      child: Transform.rotate(
        angle: rot.toDouble(),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: _kCardW,
              padding: const EdgeInsets.fromLTRB(
                MitlistSpacing.sm + 4,
                MitlistSpacing.lg,
                MitlistSpacing.sm,
                MitlistSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: bg,
                borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
                border: Border.all(color: border, width: 1),
                boxShadow: [
                  BoxShadow(
                    color: MitlistColors.neutral950
                        .withValues(alpha: dark ? 0.5 : 0.2),
                    blurRadius: 12,
                    offset: const Offset(4, 6),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    content,
                    style: textTheme.bodyMedium?.copyWith(
                      color: textColor,
                      height: 1.4,
                    ),
                    maxLines: 10,
                    overflow: TextOverflow.ellipsis,
                  ),
                  media.when(
                    loading: () => const SizedBox(height: 42),
                    error: (_, __) => const SizedBox.shrink(),
                    data: (items) {
                      if (items.isEmpty) return const SizedBox.shrink();
                      final show = items.take(4).toList();
                      return Padding(
                        padding: const EdgeInsets.only(top: MitlistSpacing.xs),
                        child: SizedBox(
                          height: 48,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            physics: const NeverScrollableScrollPhysics(),
                            itemCount: show.length,
                            separatorBuilder: (_, __) =>
                                const SizedBox(width: MitlistSpacing.xs),
                            itemBuilder: (context, i) => ClipRRect(
                              borderRadius:
                                  BorderRadius.circular(MitlistTheme.radiusSm),
                              child: AspectRatio(
                                aspectRatio: 1,
                                child: Image.network(
                                  show[i].url,
                                  fit: BoxFit.cover,
                                  cacheWidth: (48 *
                                          MediaQuery.devicePixelRatioOf(
                                              context) *
                                          1.5)
                                      .round(),
                                  errorBuilder: (_, __, ___) => Container(
                                    color: border.withValues(alpha: 0.3),
                                    child: const Icon(
                                      Icons.image_not_supported_outlined,
                                      size: 14,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  if (reminderText != null)
                    Padding(
                      padding: const EdgeInsets.only(
                          top: MitlistSpacing.xs, bottom: MitlistSpacing.xs),
                      child: Row(
                        children: [
                          Icon(Icons.alarm_on_outlined,
                              size: 12, color: mutedColor),
                          const SizedBox(width: MitlistSpacing.xs),
                          Expanded(
                            child: Text(
                              reminderText,
                              style: textTheme.labelSmall
                                  ?.copyWith(color: mutedColor),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: MitlistSpacing.xs),
                  Text(
                    '$userLabel · $when',
                    style: textTheme.labelSmall?.copyWith(color: mutedColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Positioned(
              top: -14,
              left: 0,
              right: 0,
              child: Center(
                child: PinwallPushpin(
                  headColor: pinColor,
                  size: const Size(26, 32),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Board summary artifacts ─────────────────────────────────────────────────

/// Realistic drop shadow so summary artifacts read as physical paper resting
/// on the cork, a touch heavier than the sticky notes.
List<BoxShadow> _boardArtifactShadow(bool dark) => [
      BoxShadow(
        color: MitlistColors.neutral950.withValues(alpha: dark ? 0.5 : 0.22),
        blurRadius: 16,
        offset: const Offset(5, 9),
      ),
    ];

/// The household summary, redesigned as a pinned **manila index card**: a
/// ruled filing card with a red margin rule and a row of folder tabs, each
/// line a tappable stat that jumps to its tab.
class _BoardStatsCard extends ConsumerWidget {
  const _BoardStatsCard({required this.groupId, required this.dark});

  final String groupId;
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final paper =
        dark ? MitlistColors.composerBgDark : MitlistColors.composerBgLight;
    final border = dark
        ? MitlistColors.composerBorderDark
        : MitlistColors.composerBorderLight;
    final ink = dark
        ? MitlistColors.surfaceSoft.withValues(alpha: 0.92)
        : MitlistColors.pinwallNoteTextLight;
    final muted = ink.withValues(alpha: 0.5);
    final rule = border.withValues(alpha: dark ? 0.5 : 0.75);
    final marginRule = scheme.error.withValues(alpha: dark ? 0.45 : 0.4);

    // ── Chores: due today + overdue ───────────────────────────────────────
    final chores = ref.watch(cachedCurrentChoresByGroupProvider(groupId));
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final choresDue = chores.valueOrNull?.where((c) {
          final due = c.pendingAssignment?.dueDate;
          return due != null &&
              due.isBefore(tomorrow) &&
              due.isAfter(today.subtract(const Duration(days: 1))) &&
              c.pendingAssignment?.status != 'completed';
        }).length ??
        0;
    final choresOverdue = chores.valueOrNull?.where((c) {
          final due = c.pendingAssignment?.dueDate;
          return due != null &&
              due.isBefore(today) &&
              c.pendingAssignment?.status != 'completed';
        }).length ??
        0;
    final choreTotal = choresDue + choresOverdue;

    // ── Balance ───────────────────────────────────────────────────────────
    final finance = ref.watch(cachedFinanceSummaryByGroupProvider(groupId));
    final balance = finance.valueOrNull?.balances
            .fold<int>(0, (sum, b) => sum + b.total) ??
        0;
    String fmtMoney(int cents) => (cents / 100).toStringAsFixed(0);

    // ── Lists ─────────────────────────────────────────────────────────────
    final lists = ref.watch(cachedListsByGroupProvider(groupId));
    final listCount = lists.valueOrNull
            ?.where((l) => l.type == 'shopping' || l.type == 'general')
            .length ??
        0;

    // ── Reminders (optional row) ──────────────────────────────────────────
    final reminders = ref.watch(pinwallPostsByGroupProvider(groupId));
    final reminderCount =
        reminders.valueOrNull?.where((p) => p.remindAt != null).length ?? 0;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: _kSummaryStatsW,
          decoration: BoxDecoration(
            color: paper,
            borderRadius: BorderRadius.circular(MitlistTheme.radiusMd),
            border: Border.all(color: border, width: 1.5),
            boxShadow: _boardArtifactShadow(dark),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header band: folder tabs + "This week".
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MitlistSpacing.md,
                  MitlistSpacing.md,
                  MitlistSpacing.md,
                  MitlistSpacing.sm,
                ),
                child: Row(
                  children: [
                    _FolderTab(color: scheme.secondary),
                    const SizedBox(width: 6),
                    _FolderTab(color: scheme.tertiary),
                    const SizedBox(width: 6),
                    _FolderTab(color: scheme.primary),
                    const SizedBox(width: MitlistSpacing.sm),
                    Text(
                      l10n.choreSectionThisWeek.toUpperCase(),
                      style: textTheme.labelMedium?.copyWith(
                        color: muted,
                        letterSpacing: 1.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              // Ruled body with the red margin rule.
              Stack(
                children: [
                  Positioned(
                    top: 0,
                    bottom: 0,
                    left: 52,
                    child: Container(width: 1.5, color: marginRule),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _IndexRow(
                        icon: Icons.cleaning_services_outlined,
                        label: l10n.hubStatsChores,
                        value: '$choreTotal',
                        subtitle: choresOverdue > 0
                            ? '$choresOverdue ${l10n.hubStatsOverdue}'
                            : (choresDue > 0
                                ? l10n.hubStatsDue
                                : l10n.hubStatsAllDone),
                        accent: choresOverdue > 0
                            ? scheme.error
                            : (choresDue > 0 ? scheme.secondary : scheme.tertiary),
                        rule: rule,
                        ink: ink,
                        muted: muted,
                        onTap: () => context.goNamed('chores'),
                      ),
                      _IndexRow(
                        icon: Icons.receipt_outlined,
                        label: l10n.hubStatsBalance,
                        value: balance > 0
                            ? '+\$${fmtMoney(balance)}'
                            : (balance < 0
                                ? '-\$${fmtMoney(-balance)}'
                                : '\$${fmtMoney(balance)}'),
                        subtitle: balance != 0
                            ? l10n.hubStatsOpen
                            : l10n.expenseSettled,
                        accent: balance > 0
                            ? scheme.tertiary
                            : (balance < 0 ? scheme.error : muted),
                        rule: rule,
                        ink: ink,
                        muted: muted,
                        onTap: () => context.goNamed('money'),
                      ),
                      _IndexRow(
                        icon: Icons.shopping_cart_outlined,
                        label: l10n.hubStatsLists,
                        value: '$listCount',
                        subtitle: listCount == 1
                            ? l10n.hubStatsActiveList
                            : l10n.hubStatsActiveLists,
                        accent: listCount > 0 ? scheme.primary : scheme.tertiary,
                        rule: reminderCount > 0 ? rule : Colors.transparent,
                        ink: ink,
                        muted: muted,
                        onTap: () => context.goNamed('lists'),
                      ),
                      if (reminderCount > 0)
                        _IndexRow(
                          icon: Icons.alarm_outlined,
                          label: l10n.hubStatsReminders,
                          value: '$reminderCount',
                          subtitle: reminderCount == 1
                              ? l10n.hubStatsPinwallReminder
                              : l10n.hubStatsPinwallReminders,
                          accent: scheme.primary,
                          rule: Colors.transparent,
                          ink: ink,
                          muted: muted,
                          onTap: null,
                        ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
        Positioned(
          top: -14,
          left: 0,
          right: 0,
          child: Center(
            child: PinwallPushpin(
              headColor: scheme.secondary,
              size: const Size(26, 32),
            ),
          ),
        ),
      ],
    );
  }
}

/// A small folder-divider tab drawn at the top of the index card.
class _FolderTab extends StatelessWidget {
  const _FolderTab({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 22,
      height: 7,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.85),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(3)),
      ),
    );
  }
}

/// One ruled line on the index card.
class _IndexRow extends StatelessWidget {
  const _IndexRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.subtitle,
    required this.accent,
    required this.rule,
    required this.ink,
    required this.muted,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final String subtitle;
  final Color accent;
  final Color rule;
  final Color ink;
  final Color muted;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: rule, width: 1)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap == null
              ? null
              : () {
                  unawaited(Haptics.light());
                  onTap!();
                },
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              64,
              MitlistSpacing.sm + 2,
              MitlistSpacing.md,
              MitlistSpacing.sm + 2,
            ),
            child: Row(
              children: [
                Icon(icon, size: 18, color: accent),
                const SizedBox(width: MitlistSpacing.sm),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        label,
                        style: textTheme.bodyMedium?.copyWith(
                          color: ink,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        subtitle,
                        style: textTheme.labelSmall?.copyWith(color: accent),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: MitlistSpacing.sm),
                Text(
                  value,
                  style: textTheme.titleLarge?.copyWith(
                    color: ink,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 1,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tonight's meal, redesigned as a pinned **dinner ticket** — a perforated
/// coupon with a colored stub, the dish, and a Cook action.
class _BoardTonightTicket extends ConsumerWidget {
  const _BoardTonightTicket({required this.groupId, required this.dark});

  final String groupId;
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    final paper =
        dark ? MitlistColors.composerBgDark : MitlistColors.composerBgLight;
    final border = dark
        ? MitlistColors.composerBorderDark
        : MitlistColors.composerBorderLight;
    final boardBg =
        dark ? MitlistColors.pinwallBoardDark : MitlistColors.pinwallBoard;
    final ink = dark
        ? MitlistColors.surfaceSoft.withValues(alpha: 0.92)
        : MitlistColors.pinwallNoteTextLight;
    final muted = ink.withValues(alpha: 0.55);
    final accent = scheme.tertiary;

    final async = ref.watch(todayMealPlansProvider(groupId));
    final meals = async.valueOrNull;

    // Resolve the meal to feature (dinner → breakfast → lunch → first).
    TodayMeal? selected;
    if (meals != null && meals.isNotEmpty) {
      for (final slot in const ['dinner', 'breakfast', 'lunch']) {
        selected = meals.firstWhereOrNull((m) => m.plan.slot == slot);
        if (selected != null) {
          break;
        }
      }
      selected ??= meals.first;
    }

    final String eyebrow;
    switch (selected?.plan.slot) {
      case 'breakfast':
        eyebrow = l10n.tonightBreakfast;
      case 'lunch':
        eyebrow = l10n.tonightLunch;
      default:
        eyebrow = l10n.tonightHeader;
    }

    final hasMeal = selected != null;
    final title = hasMeal
        ? (selected.recipe?.title ?? l10n.tonightRecipe)
        : l10n.tonightNothingPlanned;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          width: _kSummaryTonightW,
          decoration: BoxDecoration(
            color: paper,
            borderRadius: BorderRadius.circular(MitlistTheme.radiusMd),
            border: Border.all(color: border, width: 1.5),
            boxShadow: _boardArtifactShadow(dark),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Colored ticket header stub.
              Container(
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: dark ? 0.28 : 0.16),
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(MitlistTheme.radiusMd - 1.5),
                  ),
                ),
                padding: const EdgeInsets.fromLTRB(
                  MitlistSpacing.md,
                  MitlistSpacing.sm,
                  MitlistSpacing.md,
                  MitlistSpacing.sm,
                ),
                child: Row(
                  children: [
                    Icon(Icons.restaurant_outlined, size: 15, color: accent),
                    const SizedBox(width: MitlistSpacing.xs),
                    Text(
                      eyebrow.toUpperCase(),
                      style: textTheme.labelMedium?.copyWith(
                        color: accent,
                        letterSpacing: 1.4,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MitlistSpacing.md,
                  MitlistSpacing.md,
                  MitlistSpacing.md,
                  MitlistSpacing.sm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: hasMeal
                          ? () {
                              unawaited(Haptics.light());
                              context.pushNamed(
                                'recipeDetail',
                                pathParameters: {
                                  'recipeId': selected!.plan.recipeId
                                },
                              );
                            }
                          : null,
                      child: Text(
                        title,
                        style: textTheme.titleLarge?.copyWith(color: ink),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (hasMeal) ...[
                      const SizedBox(height: MitlistSpacing.xs),
                      Text(
                        l10n.recipeServesLabel(selected.plan.servings),
                        style: MitlistTypography.monoBody(color: muted),
                      ),
                    ],
                  ],
                ),
              ),
              // Perforated tear line with punch holes.
              SizedBox(
                height: 14,
                child: CustomPaint(
                  painter: _PerforationPainter(
                    dashColor: border,
                    holeColor: boardBg,
                  ),
                ),
              ),
              // Stub footer with the action.
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MitlistSpacing.md,
                  MitlistSpacing.xs,
                  MitlistSpacing.md,
                  MitlistSpacing.md,
                ),
                child: Row(
                  children: [
                    const Spacer(),
                    if (hasMeal)
                      AppButton(
                        text: l10n.tonightCook,
                        size: AppButtonSize.sm,
                        onPressed: () {
                          unawaited(Haptics.light());
                          context.pushNamed(
                            'recipeCook',
                            pathParameters: {'recipeId': selected!.plan.recipeId},
                          );
                        },
                      )
                    else
                      AppButton(
                        text: l10n.tonightPlanDinner,
                        variant: AppButtonVariant.outline,
                        size: AppButtonSize.sm,
                        onPressed: () {
                          unawaited(Haptics.light());
                          context.pushNamed('mealPlan');
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Positioned(
          top: -14,
          left: 0,
          right: 0,
          child: Center(
            child: PinwallPushpin(
              headColor: scheme.tertiary,
              size: const Size(26, 32),
            ),
          ),
        ),
      ],
    );
  }
}

/// Dashed horizontal tear line with a punched hole at each end, giving the
/// tonight card its torn-ticket silhouette.
class _PerforationPainter extends CustomPainter {
  const _PerforationPainter({required this.dashColor, required this.holeColor});

  final Color dashColor;
  final Color holeColor;

  @override
  void paint(Canvas canvas, Size size) {
    final y = size.height / 2;

    final dash = Paint()
      ..color = dashColor
      ..strokeWidth = 1.4
      ..strokeCap = StrokeCap.round;
    const dashW = 6.0;
    const gap = 5.0;
    for (var x = 14.0; x < size.width - 14; x += dashW + gap) {
      canvas.drawLine(Offset(x, y), Offset(x + dashW, y), dash);
    }

    // Punch holes that bite into each edge.
    final hole = Paint()..color = holeColor;
    canvas.drawCircle(Offset(0, y), 7, hole);
    canvas.drawCircle(Offset(size.width, y), 7, hole);
  }

  @override
  bool shouldRepaint(_PerforationPainter old) =>
      old.dashColor != dashColor || old.holeColor != holeColor;
}

// ─── Overlay chip ─────────────────────────────────────────────────────────────

class _BoardChip extends StatelessWidget {
  const _BoardChip(
      {required this.label, required this.icon, required this.dark});
  final String label;
  final IconData icon;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final bg = dark
        ? MitlistColors.neutral950.withValues(alpha: 0.72)
        : MitlistColors.pinwallBoardBorder.withValues(alpha: 0.75);
    return ClipRRect(
      borderRadius: BorderRadius.circular(MitlistTheme.radiusFull),
      child: Container(
        padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.md, vertical: MitlistSpacing.xs + 2),
        color: bg,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: MitlistColors.surfaceSoft),
            const SizedBox(width: MitlistSpacing.xs),
            Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: MitlistColors.surfaceSoft,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Close button ─────────────────────────────────────────────────────────────

class _BoardCloseButton extends StatelessWidget {
  const _BoardCloseButton({required this.dark, required this.onClose});
  final bool dark;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bg = dark
        ? MitlistColors.neutral950.withValues(alpha: 0.72)
        : MitlistColors.pinwallBoardBorder.withValues(alpha: 0.75);
    return Semantics(
      button: true,
      label: l10n.pinwallCloseBoard,
      child: GestureDetector(
        onTap: () {
          Haptics.light();
          onClose();
        },
        child: Container(
          width: 44,
          height: 44,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(MitlistTheme.radiusFull),
          ),
          child: const Icon(Icons.close,
              size: 18, color: MitlistColors.surfaceSoft),
        ),
      ),
    );
  }
}
