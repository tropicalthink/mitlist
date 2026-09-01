import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/auth_models.dart';
import '../../models/group_models.dart';
import '../../models/pinwall_models.dart';
import '../../providers/list_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../providers/pinwall_provider.dart';
import '../../providers/presence_provider.dart';
import '../../theme/animations.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../theme/typography.dart';
import '../../l10n/app_localizations.dart';
import '../../utils/haptics.dart';
import '../../utils/hub_helpers.dart';
import '../../sheets/pinwall_note_editor_sheet.dart';
import '../../widgets/app_bottom_sheet.dart';
import '../../widgets/app_button.dart';
import '../../widgets/pinwall/pinwall_composer.dart';
import '../../widgets/hub/pinned_memo_card.dart';
import '../../widgets/pinwall/pinwall_note_card.dart';
import '../../widgets/pinwall/pinwall_stat_rows.dart';

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

  // Live list of notes, seeded from the snapshot handed in at open time and
  // then kept in sync with the realtime stream (see _syncPosts).
  late List<PinwallPost> _posts;
  late final Map<String, Offset> _positions;
  late final Map<String, Offset> _persistedPositions;
  final Map<String, int> _positionGenerations = {};
  // Pinned hub-summary cards are draggable too, so they get their own state.
  Offset _statsPos = const Offset(_kMargin, _kMargin);
  Offset _tonightPos =
      const Offset(_kMargin + _kSummaryStatsW + _kSummaryGap, _kMargin);
  late final AnimationController _staggerCtrl;
  // Staggered entrance keyed by post id (stable across live reordering).
  late final Map<String, Animation<double>> _initialEntranceById;
  final List<CurvedAnimation> _ownedCurves = [];
  // Notes that arrived live (after the first paint) — they pin on individually.
  final Set<String> _enteringIds = {};
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
    _posts = List.of(widget.posts);
    _positions = {
      for (var i = 0; i < widget.posts.length; i++)
        widget.posts[i].id: _positionFor(widget.posts[i], i),
    };
    _persistedPositions = Map.of(_positions);

    _staggerCtrl = AnimationController(
      vsync: this,
      duration: Duration(
        milliseconds: 300 + widget.posts.length * 40,
      ),
    );

    _initialEntranceById = {
      for (var i = 0; i < widget.posts.length; i++)
        widget.posts[i].id: _ownedCurve(
          (i * 0.07).clamp(0.0, 0.6),
          ((i * 0.07) + 0.4).clamp(0.0, 1.0),
        ),
    };

    _summaryAnim = CurvedAnimation(
      parent: _staggerCtrl,
      curve: const Interval(0.0, 0.4, curve: Curves.easeOutCubic),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) async {
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

      // Open the realtime stream so a flatmate's note appears as it's pinned.
      // Idempotent and owned by the hub section's lifecycle, so the board does
      // not detach on close (that would also silence the home hub).
      final repo = await ref.read(pinwallRepositoryProvider.future);
      if (!mounted) return;
      repo.attachSse(ref.read(sseServiceProvider), widget.groupId);
    });
  }

  CurvedAnimation _ownedCurve(double start, double end) {
    final curve = CurvedAnimation(
      parent: _staggerCtrl,
      curve: Interval(start, end, curve: Curves.easeOutCubic),
    );
    _ownedCurves.add(curve);
    return curve;
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
    for (final c in _ownedCurves) {
      c.dispose();
    }
    _summaryAnim.dispose();
    _transformCtrl.dispose();
    _staggerCtrl.dispose();
    super.dispose();
  }

  /// Reconcile the board with the live post list: keep existing card positions,
  /// drop notes that were removed, and lay out newly-arrived ones on the next
  /// free grid slot so they pin on in place.
  void _syncPosts(List<PinwallPost> incoming) {
    if (!mounted) return;
    final incomingIds = {for (final p in incoming) p.id};
    final added = <String>[];
    for (final p in incoming) {
      if (!_positions.containsKey(p.id)) {
        _positions[p.id] = _positionFor(p, _positions.length);
        _persistedPositions[p.id] = _positions[p.id]!;
        added.add(p.id);
      } else if (p.id != _activeId && p.posX != null && p.posY != null) {
        // Adopt a placement made on another device (or the server's confirmed
        // value), but never yank a card the user is actively dragging.
        final confirmed =
            _clamp(Offset(p.posX!, p.posY!), _noteWidth(p), _kCardH);
        _positions[p.id] = confirmed;
        _persistedPositions[p.id] = confirmed;
      }
    }
    _positions.removeWhere((id, _) => !incomingIds.contains(id));
    _persistedPositions.removeWhere((id, _) => !incomingIds.contains(id));
    _positionGenerations.removeWhere((id, _) => !incomingIds.contains(id));

    // The stream only emits on real cache writes, so always adopt the new list.
    setState(() {
      _posts = incoming;
      _enteringIds.addAll(added);
    });
  }

  /// A note's rendered width on the board, which follows its chosen size.
  /// Used for clamping so a large note can't hang off the cork's edge.
  static double _noteWidth(PinwallPost post) {
    return switch (post.size) {
      'small' => 150,
      'large' => 250,
      _ => _kCardW,
    };
  }

  double _noteWidthById(String id) {
    final post = _posts.firstWhereOrNull((p) => p.id == id);
    return post == null ? _kCardW : _noteWidth(post);
  }

  /// A note's board position: its saved placement when the server has one,
  /// otherwise a stable grid slot so never-placed notes still fan out.
  Offset _positionFor(PinwallPost post, int index) {
    final px = post.posX;
    final py = post.posY;
    if (px != null && py != null) {
      return _clamp(Offset(px, py), _noteWidth(post), _kCardH);
    }
    return _gridPosition(index, post.id.hashCode);
  }

  Offset _gridPosition(int index, int idHash) {
    const cols = 4;
    final col = index % cols;
    final row = index ~/ cols;

    final baseX = _kMargin + col * (_kCardW + 60.0);
    final baseY = _kMargin + _kSummaryBandH + row * (_kCardH + 50.0);

    final h = idHash.abs();
    final jx = ((h % 80) - 40).toDouble();
    final jy = (((h >> 8) % 60) - 30).toDouble();

    return _clamp(Offset(baseX + jx, baseY + jy), _kCardW, _kCardH);
  }

  /// Keep a card's top-left inside the cork so a note can never be dragged off
  /// the board and lost. The camera still roams free; the cards do not.
  Offset _clamp(Offset o, double w, double h) {
    const inset = 16.0;
    final maxX = _kBoardW - w - inset;
    final maxY = _kBoardH - h - inset;
    return Offset(
      o.dx.clamp(inset, maxX < inset ? inset : maxX),
      o.dy.clamp(inset, maxY < inset ? inset : maxY),
    );
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
      _positions[postId] =
          _clamp(cur + details.delta, _noteWidthById(postId), _kCardH);
    });
  }

  void _onStatsDrag(DragUpdateDetails details) {
    setState(() => _statsPos =
        _clamp(_statsPos + details.delta, _kSummaryStatsW, _kSummaryBandH));
  }

  void _onTonightDrag(DragUpdateDetails details) {
    setState(() => _tonightPos =
        _clamp(_tonightPos + details.delta, _kSummaryTonightW, _kSummaryBandH));
  }

  void _lift(String id) {
    unawaited(Haptics.light());
    setState(() => _activeId = id);
  }

  void _drop() {
    final id = _activeId;
    if (id == null) return;
    setState(() => _activeId = null);
    // The pinned summary cards (__stats__/__tonight__) are per-viewer scratch
    // positions and stay local; only real notes persist + sync to the household.
    if (id == _statsId || id == _tonightId) return;
    final pos = _positions[id];
    if (pos != null) {
      final previous = _persistedPositions[id] ?? pos;
      unawaited(_persistPosition(id, pos, previous));
    }
  }

  Future<void> _persistPosition(
    String postId,
    Offset pos,
    Offset previous,
  ) async {
    final generation = (_positionGenerations[postId] ?? 0) + 1;
    _positionGenerations[postId] = generation;
    try {
      final repo = await ref.read(pinwallRepositoryProvider.future);
      await repo.updatePostPositionOfflineFirst(
        widget.groupId,
        postId,
        pos.dx,
        pos.dy,
      );
      // Sync now, the way creates and deletes already do. Nothing else arms a
      // drain after an enqueue — the coordinator only schedules a retry once a
      // drain has already run and found work left over — so without this the
      // move sits in the outbox, and on the sync banner, until connectivity
      // flips or the app is resumed.
      unawaited(repo.drainOutboxOnce().catchError((_) {}));
      if (mounted && _positionGenerations[postId] == generation) {
        _persistedPositions[postId] = pos;
      }
    } catch (_) {
      if (!mounted || _positionGenerations[postId] != generation) return;
      unawaited(Haptics.failure());
      setState(() {
        _positions[postId] = previous;
        _persistedPositions[postId] = previous;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AppLocalizations.of(context)!.commonSomethingWentWrong),
        ),
      );
    }
  }

  /// Compose a note right from the board: a sheet hosts the same full
  /// composer as the hub (text, reminder, entity link, photos). Plain notes
  /// take the offline-first path and pin on via the live stream a frame or
  /// two later; media/linked posts land after the server confirms.
  Future<void> _composeNote() async {
    unawaited(Haptics.light());
    final l10n = AppLocalizations.of(context)!;
    await showAppBottomSheet<void>(
      context: context,
      title: l10n.pinwallAddNote,
      body: PinwallComposer(
        groupId: widget.groupId,
        me: widget.me,
        autofocus: true,
        // The sheet is the navigator's top route while the composer is up, so
        // this closes just the sheet and leaves the board open underneath.
        onPosted: () => Navigator.of(context).pop(),
      ),
    );
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
      for (var i = 0; i < _posts.length; i++)
        () {
          final post = _posts[i];
          final id = post.id;
          // Initial batch keeps its staggered entrance (keyed by id so it
          // survives reordering); notes that arrive live pin on individually.
          final initial = _initialEntranceById[id];
          final isLive = initial == null && _enteringIds.contains(id);
          Widget card = PinwallNoteCard(
            variant: PinwallNoteCardVariant.board,
            index: i,
            groupId: widget.groupId,
            me: widget.me,
            post: post,
            onOpenLinkedEntity: (ctx) => _openLinkedEntity(ctx, post),
            onEdit: () {
              unawaited(Haptics.light());
              showPinwallNoteEditorSheet(
                context,
                groupId: widget.groupId,
                post: post,
              );
            },
          );
          if (isLive) card = _PinOnEntrance(child: card);
          return (
            id: id,
            order: 2 + i,
            child: _BoardDraggableItem(
              key: ValueKey(id),
              position: _positions[id]!,
              isActive: _activeId == id,
              entrance: initial,
              onLift: () => _lift(id),
              onDrop: _drop,
              onDrag: (d) => _onNoteDrag(id, d),
              child: card,
            ),
          );
        }(),
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

    // Keep the board in sync with the realtime stream while it's open, so a
    // flatmate pinning or removing a note repaints here without a reopen.
    ref.listen<AsyncValue<List<PinwallPost>>>(
      pinwallPostsByGroupProvider(widget.groupId),
      (_, next) => next.whenData(_syncPosts),
    );

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
          // Fill the screen even though every layer below is Positioned.fill,
          // so the board never collapses if the parent hands loose constraints.
          fit: StackFit.expand,
          children: [
            // The wall the board hangs on — static behind the pannable cork, so
            // panning/zooming reveals a framed board floating in space rather
            // than an infinite sea of cork.
            Positioned.fill(
              child: CustomPaint(painter: _WallPainter(dark: dark)),
            ),
            // Board surface + notes (free pan/zoom over the static wall).
            Positioned.fill(
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
                        if (_posts.isEmpty)
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
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _BoardChip(
                            label: l10n.pinwallBoardLabel,
                            icon: Icons.push_pin_outlined,
                            dark: dark,
                          ),
                          const SizedBox(width: MitlistSpacing.sm),
                          Flexible(
                            child: _PresenceBar(
                              groupId: widget.groupId,
                              meId: widget.me?.id,
                              dark: dark,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: MitlistSpacing.sm),
                    _BoardCloseButton(
                      dark: dark,
                      onClose: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
              ),
            ),

            // Compose a new note without leaving the board.
            SafeArea(
              child: Align(
                alignment: Alignment.bottomRight,
                child: Padding(
                  padding: const EdgeInsets.all(MitlistSpacing.md),
                  child: _BoardAddNoteButton(dark: dark, onTap: _composeNote),
                ),
              ),
            ),

            // Pan/zoom hint
            if (_posts.isNotEmpty)
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

/// The cork board itself: a filled, wood-framed surface that casts a soft
/// shadow onto the wall behind it, so the whole board reads as one physical
/// object you can pan around rather than a bottomless field of cork.
class _CorkCanvas extends StatelessWidget {
  const _CorkCanvas({required this.dark, required this.child});

  final bool dark;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final cork =
        dark ? MitlistColors.pinwallBoardDark : MitlistColors.pinwallBoard;
    final frame = dark
        ? MitlistColors.pinwallBoardBorderDark
        : MitlistColors.pinwallBoardBorder;

    return Container(
      decoration: BoxDecoration(
        color: cork,
        border: Border.all(color: frame, width: 26),
        boxShadow: [
          // Ambient lift off the wall.
          BoxShadow(
            color: Colors.black.withValues(alpha: dark ? 0.55 : 0.32),
            blurRadius: 90,
            spreadRadius: 6,
            offset: const Offset(0, 34),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _CorkGrainPainter(dark: dark),
        child: child,
      ),
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

// ─── The wall behind the board ────────────────────────────────────────────────

/// A static plaster wall painted behind the pannable cork. It does not move
/// with the board, so panning the cork over it reads as parallax depth and the
/// board feels like a framed object hung in a room.
class _WallPainter extends CustomPainter {
  const _WallPainter({required this.dark});
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final base = dark ? const Color(0xFF14110E) : const Color(0xFF7C7064);
    canvas.drawRect(rect, Paint()..color = base);

    // Faint vertical plaster streaks for a hand-troweled texture.
    final rng = _LCG(seed: 7);
    final streak = Paint()
      ..color = (dark ? Colors.white : Colors.black)
          .withValues(alpha: dark ? 0.018 : 0.03)
      ..strokeWidth = 1.0;
    final count = (size.width / 26).clamp(8, 80).toInt();
    for (var i = 0; i < count; i++) {
      final x = rng.nextDouble() * size.width;
      canvas.drawLine(
        Offset(x, 0),
        Offset(x + (rng.nextDouble() - 0.5) * 8, size.height),
        streak,
      );
    }

    // Vignette to sink the edges and lift the centered board.
    final vignette = Paint()
      ..shader = RadialGradient(
        radius: 0.9,
        colors: [
          Colors.transparent,
          Colors.black.withValues(alpha: dark ? 0.5 : 0.28),
        ],
        stops: const [0.5, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, vignette);
  }

  @override
  bool shouldRepaint(_WallPainter old) => old.dark != dark;
}

// ─── Presence: who's on the board right now ──────────────────────────────────

/// A live cluster of avatars for the household members currently viewing the
/// board, led by a pulsing dot to signal it updates in real time.
class _PresenceBar extends ConsumerWidget {
  const _PresenceBar({
    required this.groupId,
    required this.meId,
    required this.dark,
  });

  final String groupId;
  final String? meId;
  final bool dark;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final present =
        ref.watch(presentMembersProvider((groupId: groupId, meId: meId)));
    if (present.isEmpty) return const SizedBox.shrink();

    const maxShown = 4;
    const size = 26.0;
    const overlap = 17.0;
    final shown = present.take(maxShown).toList();
    final extra = present.length - shown.length;
    final stackW =
        size + (shown.length - 1) * overlap + (extra > 0 ? overlap : 0);

    final bg = dark
        ? MitlistColors.neutral950.withValues(alpha: 0.72)
        : MitlistColors.pinwallBoardBorder.withValues(alpha: 0.78);

    final names = present
        .map((m) => m.displayName.isEmpty ? '?' : m.displayName)
        .join(', ');

    return Semantics(
      label: AppLocalizations.of(context)!.pinwallPresenceHere(names),
      child: Container(
        padding: const EdgeInsets.fromLTRB(8, 4, 10, 4),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(MitlistTheme.radiusFull),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const _LiveDot(),
            const SizedBox(width: 7),
            SizedBox(
              width: stackW,
              height: size,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  for (var i = 0; i < shown.length; i++)
                    Positioned(
                      left: i * overlap,
                      child: _InitialAvatar(
                        member: shown[i],
                        isMe: shown[i].userId == meId,
                        size: size,
                      ),
                    ),
                  if (extra > 0)
                    Positioned(
                      left: shown.length * overlap,
                      child: _MoreAvatar(extra: extra, size: size),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A round initials avatar, tinted by a stable per-user color.
class _InitialAvatar extends StatelessWidget {
  const _InitialAvatar({
    required this.member,
    required this.isMe,
    required this.size,
  });

  final GroupMemberProfile member;
  final bool isMe;
  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final palette = [
      scheme.primary,
      scheme.secondary,
      scheme.tertiary,
      scheme.error,
    ];
    final color = palette[member.userId.hashCode.abs() % palette.length];
    final initials =
        member.displayName.isEmpty ? '?' : avatarInitials(member.displayName);

    final avatar = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(
          // Ring the viewer's own avatar so "you" reads at a glance.
          color: isMe
              ? MitlistColors.surfaceSoft
              : Colors.black.withValues(alpha: 0.25),
          width: isMe ? 2 : 1.5,
        ),
      ),
      child: Text(
        initials,
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.38,
          fontWeight: FontWeight.w700,
          height: 1.0,
          shadows: const [
            Shadow(
                color: Colors.black26, blurRadius: 1, offset: Offset(0, 0.5)),
          ],
        ),
      ),
    );

    if (member.displayName.isEmpty) return avatar;
    return Tooltip(message: member.displayName, child: avatar);
  }
}

/// The "+N" overflow chip when more members are present than fit the stack.
class _MoreAvatar extends StatelessWidget {
  const _MoreAvatar({required this.extra, required this.size});

  final int extra;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: MitlistColors.neutral800,
        shape: BoxShape.circle,
        border:
            Border.all(color: Colors.black.withValues(alpha: 0.25), width: 1.5),
      ),
      child: Text(
        '+$extra',
        style: TextStyle(
          color: Colors.white,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
          height: 1.0,
        ),
      ),
    );
  }
}

/// Small green dot with a soft pulsing halo — the board's "live" signal.
class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const green = Color(0xFF4ADE80);
    const core = 8.0;
    final dot = Container(
      width: core,
      height: core,
      decoration: const BoxDecoration(color: green, shape: BoxShape.circle),
    );

    if (MediaQuery.of(context).disableAnimations) return dot;

    return SizedBox(
      width: core + 10,
      height: core + 10,
      child: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, child) {
            final t = Curves.easeOut.transform(_c.value);
            return Stack(
              alignment: Alignment.center,
              children: [
                Opacity(
                  opacity: (1 - t) * 0.55,
                  child: Container(
                    width: core + 10 * t,
                    height: core + 10 * t,
                    decoration: const BoxDecoration(
                        color: green, shape: BoxShape.circle),
                  ),
                ),
                child!,
              ],
            );
          },
          child: dot,
        ),
      ),
    );
  }
}

/// One-shot entrance for a note that arrives live: it drops and scales in as if
/// pinned onto the board by a flatmate.
class _PinOnEntrance extends StatelessWidget {
  const _PinOnEntrance({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.of(context).disableAnimations) return child;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: MitlistAnimations.medium,
      curve: MitlistAnimations.easeEnter,
      builder: (context, t, child) {
        return Opacity(
          opacity: t.clamp(0.0, 1.0),
          child: Transform.translate(
            offset: Offset(0, (1 - t) * -12),
            child: Transform.scale(scale: 0.85 + 0.15 * t, child: child),
          ),
        );
      },
      child: child,
    );
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

void _openLinkedEntity(BuildContext context, PinwallPost post) {
  final id = post.linkedEntityId;
  switch (post.linkedEntityType) {
    case 'list':
      if (id != null && id.isNotEmpty) {
        context.goNamed('listDetail', pathParameters: {'listId': id});
      } else {
        context.goNamed('lists');
      }
    case 'chore':
      context.pushNamed('chores');
    case 'expense':
      context.pushNamed('money');
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

    // ── Reminders (optional row; no hub equivalent) ─────────────────────────
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
                      PinwallChoresStatRow(
                        groupId: groupId,
                        style: PinwallStatRowStyle.indexCard,
                        ink: ink,
                        muted: muted,
                        rule: rule,
                      ),
                      PinwallFinanceStatRow(
                        groupId: groupId,
                        style: PinwallStatRowStyle.indexCard,
                        ink: ink,
                        muted: muted,
                        rule: rule,
                      ),
                      PinwallListsStatRow(
                        groupId: groupId,
                        style: PinwallStatRowStyle.indexCard,
                        ink: ink,
                        muted: muted,
                        rule: reminderCount > 0 ? rule : Colors.transparent,
                      ),
                      if (reminderCount > 0)
                        PinwallStatRow(
                          style: PinwallStatRowStyle.indexCard,
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
                            pathParameters: {
                              'recipeId': selected!.plan.recipeId
                            },
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

// ─── Add-note button + composer sheet ────────────────────────────────────────

class _BoardAddNoteButton extends StatelessWidget {
  const _BoardAddNoteButton({required this.dark, required this.onTap});
  final bool dark;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bg = dark
        ? MitlistColors.neutral950.withValues(alpha: 0.72)
        : MitlistColors.pinwallBoardBorder.withValues(alpha: 0.75);
    return Semantics(
      button: true,
      label: l10n.pinwallAddNote,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(MitlistTheme.radiusFull),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.push_pin_outlined,
                  size: 16, color: MitlistColors.surfaceSoft),
              const SizedBox(width: MitlistSpacing.xs),
              Text(
                l10n.pinwallAddNote,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: MitlistColors.surfaceSoft,
                    ),
              ),
            ],
          ),
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
