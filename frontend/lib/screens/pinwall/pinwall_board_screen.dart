import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../models/auth_models.dart';
import '../../models/pinwall_models.dart';
import '../../providers/pinwall_provider.dart';
import '../../theme/animations.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../utils/haptics.dart';
import '../../utils/hub_helpers.dart';
import '../../widgets/hub/pinned_memo_card.dart';
import '../../widgets/hub/stats_grid.dart';
import '../../widgets/hub/tonight_card.dart';

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
    final colorScheme = Theme.of(context).colorScheme;
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
          child: PinnedMemoCard(
            width: _kSummaryStatsW,
            pinColor: colorScheme.secondary,
            child: StatsGrid(groupId: widget.groupId),
          ),
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
          child: PinnedMemoCard(
            width: _kSummaryTonightW,
            pinColor: colorScheme.tertiary,
            child: TonightCard(groupId: widget.groupId),
          ),
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
                      label: 'Pinwall',
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
                      label: 'Drag notes to move  ·  Pinch to zoom',
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
    final textColor = dark
        ? MitlistColors.pinwallNoteTextDark
        : MitlistColors.pinwallNoteTextLight;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.xl),
        child: Text(
          'The wall is clear.\nPin a note from the hub to get started.',
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
    final userLabel = formatUserLabel(post.userId, me?.id);
    final when = relativeDay(post.createdAt);

    final remindAt = post.remindAt;
    final reminderText = remindAt == null
        ? null
        : DateFormat('MMM d · h:mm a').format(remindAt.toLocal());

    final media = ref.watch(
      pinwallMediaByPostProvider((groupId: groupId, postId: post.id)),
    );

    return Semantics(
      label: '$userLabel · $content',
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
    final bg = dark
        ? MitlistColors.neutral950.withValues(alpha: 0.72)
        : MitlistColors.pinwallBoardBorder.withValues(alpha: 0.75);
    return Semantics(
      button: true,
      label: 'Close board',
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
