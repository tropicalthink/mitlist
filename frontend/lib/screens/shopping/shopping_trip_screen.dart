import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../models/list_models.dart';
import '../../providers/group_provider.dart';
import '../../providers/list_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../theme/animations.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../theme/theme.dart';
import '../../utils/active_group_context.dart';
import '../../utils/friendly_error.dart';
import '../../widgets/animated_check_toggle.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/odometer.dart';
import '../../widgets/skeleton.dart';

class ShoppingTripScreen extends ConsumerStatefulWidget {
  const ShoppingTripScreen({super.key});

  @override
  ConsumerState<ShoppingTripScreen> createState() => _ShoppingTripScreenState();
}

class _ShoppingTripScreenState extends ConsumerState<ShoppingTripScreen> {
  bool _isLoading = true;
  bool _hasHousehold = true;
  String? _error;
  final List<ItemList> _lists = [];
  final Map<String, List<ListItem>> _itemsByList = {};
  final Set<String> _checkedItemIds = {};
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final groupId = await _resolveGroupId();
      if (groupId == null) {
        setState(() {
          _hasHousehold = false;
          _isLoading = false;
        });
        return;
      }

      final listSvc = await ref.read(listServiceProviderAsync.future);
      final lists = await listSvc.listLists(groupId, limit: 100);
      final shoppingLists = lists.where((l) => l.type == 'shopping' || l.type == 'general').toList();

      if (shoppingLists.isEmpty) {
        setState(() {
          _isLoading = false;
        });
        return;
      }

      final listIds = shoppingLists.map((l) => l.id).toList();
      final result = await listSvc.getShoppingTrip(listIds, groupId: groupId);

      final itemsByList = <String, List<ListItem>>{};
      final rawLists = result['lists'] as List<dynamic>? ?? [];
      for (final rl in rawLists) {
        final listId = rl['list_id'] as String? ?? '';
        final rawItems = rl['items'] as List<dynamic>? ?? [];
        final items = rawItems.map((ri) {
          final m = Map<String, dynamic>.from(ri as Map);
          return ListItem.fromJson(m);
        }).where((i) => !i.checked).toList();
        if (items.isNotEmpty) {
          itemsByList[listId] = items;
        }
      }

      setState(() {
        _lists.clear();
        _lists.addAll(shoppingLists);
        _itemsByList.clear();
        _itemsByList.addAll(itemsByList);
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = friendlyErrorMessage(e);
        _isLoading = false;
      });
    }
  }

  Future<String?> _resolveGroupId() async {
    try {
      final groupSvc = await ref.read(groupServiceProviderAsync.future);
      final groups = await groupSvc.listGroups(limit: 50);
      return resolveActiveGroupId(groups, ref.read(currentGroupIdProvider));
    } catch (_) {
      return null;
    }
  }

  void _toggleItem(String itemId) {
    // A light tap of feedback every time something lands in the basket.
    HapticFeedback.selectionClick();
    setState(() {
      if (_checkedItemIds.contains(itemId)) {
        _checkedItemIds.remove(itemId);
      } else {
        _checkedItemIds.add(itemId);
      }
    });
  }

  Future<void> _completeChecked() async {
    if (_checkedItemIds.isEmpty) return;
    setState(() => _isSubmitting = true);

    final checkedItems = <ListItem>[];
    for (final items in _itemsByList.values) {
      for (final item in items) {
        if (_checkedItemIds.contains(item.id)) {
          checkedItems.add(item);
        }
      }
    }
    final completedCount = checkedItems.length;
    final totalCents = checkedItems.fold<int>(
        0, (sum, item) => sum + (item.priceCents ?? 0));

    try {
      final listSvc = await ref.read(listServiceProviderAsync.future);
      await listSvc.completeShoppingItems(_checkedItemIds.toList());

      if (!mounted) return;
      // The trip is done: a heavy stamp and the matching thwack.
      HapticFeedback.heavyImpact();
      _showDoneStamp(completedCount, totalCents);

      setState(() => _checkedItemIds.clear());
      await _load();
      if (!mounted) return;

      if (totalCents > 0) {
        final totalStr = (totalCents / 100).toStringAsFixed(2);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('€$totalStr worth of items marked as done'),
            action: SnackBarAction(
              label: 'Add expense',
              onPressed: () => context.pushNamed('money'),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(friendlyErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  void _showDoneStamp(int count, int totalCents) {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (_) => _DoneStamp(
        count: count,
        totalCents: totalCents,
        onComplete: () => entry.remove(),
      ),
    );
    overlay.insert(entry);
  }

  String _listName(String listId) {
    final list = _lists.cast<ItemList?>().firstWhere(
          (l) => l?.id == listId,
          orElse: () => null,
        );
    return list?.name ?? 'List';
  }

  int get _totalItems {
    return _itemsByList.values.fold(0, (sum, items) => sum + items.length);
  }

  int get _checkedCount => _checkedItemIds.length;

  int get _checkedTotalCents {
    var cents = 0;
    for (final items in _itemsByList.values) {
      for (final item in items) {
        if (_checkedItemIds.contains(item.id)) {
          cents += item.priceCents ?? 0;
        }
      }
    }
    return cents;
  }

  bool get _showBasketBar =>
      !_isLoading &&
      _hasHousehold &&
      _error == null &&
      _lists.isNotEmpty &&
      _totalItems > 0;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: MitlistAppBar(
        leading: IconButton(
          icon: const AppIcon(name: 'arrowLeft'),
          tooltip: 'Back',
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('Shopping Trip'),
      ),
      body: _buildBody(textTheme),
      bottomNavigationBar: _showBasketBar
          ? _BasketBar(
              checkedCount: _checkedCount,
              totalCount: _totalItems,
              totalCents: _checkedTotalCents,
              isSubmitting: _isSubmitting,
              onDone: _checkedCount > 0 && !_isSubmitting ? _completeChecked : null,
            )
          : null,
    );
  }

  Widget _buildBody(TextTheme textTheme) {
    if (_isLoading) {
      return _buildSkeleton();
    }
    if (!_hasHousehold) {
      return Center(
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/House.lottie',
          icon: const AppIcon(name: 'homeOutline'),
          title: 'No household yet',
          description: 'Create or join a household before starting a shopping trip.',
          actions: [
            AppButton(
              text: 'Go to households',
              onPressed: () => context.goNamed('groupsList'),
            ),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/404.lottie',
          icon: const AppIcon(name: 'alertCircleOutline'),
          title: 'Something went wrong',
          description: _error,
          actions: [
            AppButton(
              variant: AppButtonVariant.outline,
              text: 'Retry',
              onPressed: _load,
            ),
          ],
        ),
      );
    }
    if (_lists.isEmpty) {
      return const Center(
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/checklist.lottie',
          icon: AppIcon(name: 'shoppingBagOutline'),
          title: 'No lists yet',
          description: 'Create a shopping list to start a trip',
        ),
      );
    }
    if (_totalItems == 0) {
      return const Center(
        child: AppEmptyState(
          lottieAsset: 'assets/animations/lottie/Checkmark.lottie',
          icon: AppIcon(name: 'checkCircleOutline'),
          title: 'All caught up',
          description: 'No open items across your lists. Add items to a list to see them here.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.md, vertical: MitlistSpacing.sm),
        itemCount: _itemsByList.length,
        itemBuilder: (context, index) {
          final listId = _itemsByList.keys.elementAt(index);
          final items = _itemsByList[listId]!;
          final listName = _listName(listId);
          return _ListSection(
            listId: listId,
            listName: listName,
            items: items,
            checkedIds: _checkedItemIds,
            onToggle: _toggleItem,
            onTapList: () => context.pushNamed('listDetail', pathParameters: {'listId': listId}),
          );
        },
      ),
    );
  }

  Widget _buildSkeleton() {
    return ListView.builder(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      itemCount: 3,
      itemBuilder: (_, index) => Padding(
        padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
        child: AppCard(
          variant: AppCardVariant.outlined,
          padding: AppCardPadding.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const AppSkeleton(width: 140, height: 16),
              const SizedBox(height: MitlistSpacing.sm),
              Divider(color: Theme.of(context).colorScheme.outlineVariant),
              const SizedBox(height: MitlistSpacing.sm),
              for (var i = 0; i < 4; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
                  child: Row(
                    children: [
                      const AppSkeleton(width: 20, height: 20),
                      const SizedBox(width: MitlistSpacing.sm),
                      Expanded(
                        child: AppSkeleton(
                          width: double.infinity,
                          height: 14,
                        ),
                      ),
                      const SizedBox(width: MitlistSpacing.md),
                      AppSkeleton(
                        width: MitlistSpacing.space10,
                        height: 14,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Persistent bottom bar that frames the trip: a hard-edged progress fill, a
/// rolling count of what's in the basket, an optional running total when items
/// carry prices, and the primary "mark done" action within thumb reach.
class _BasketBar extends StatelessWidget {
  const _BasketBar({
    required this.checkedCount,
    required this.totalCount,
    required this.totalCents,
    required this.isSubmitting,
    required this.onDone,
  });

  final int checkedCount;
  final int totalCount;
  final int totalCents;
  final bool isSubmitting;
  final VoidCallback? onDone;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final fillDuration =
        disableAnimations ? Duration.zero : MitlistAnimations.medium;

    final fraction =
        totalCount == 0 ? 0.0 : (checkedCount / totalCount).clamp(0.0, 1.0);

    final countStyle = TextStyle(
      fontFamily: MitlistTypography.monoFamily,
      fontSize: 22,
      fontWeight: FontWeight.w700,
      height: 1.0,
      color: checkedCount > 0 ? colorScheme.primary : colorScheme.onSurfaceVariant,
    );

    final priceSuffix = totalCents > 0
        ? '  ·  €${(totalCents / 100).toStringAsFixed(2)}'
        : '';

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          top: BorderSide(color: colorScheme.outline, width: 2),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MitlistSpacing.md,
            MitlistSpacing.sm + MitlistSpacing.xs,
            MitlistSpacing.md,
            MitlistSpacing.sm,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  // Border insets the content box by 2px on each side.
                  final innerWidth = math.max(0.0, constraints.maxWidth - 4);
                  return Container(
                    height: 12,
                    clipBehavior: Clip.hardEdge,
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerHighest,
                      border: Border.all(color: colorScheme.outline, width: 2),
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: AnimatedContainer(
                        duration: fillDuration,
                        curve: MitlistAnimations.easeEnter,
                        width: innerWidth * fraction,
                        color: colorScheme.primary,
                      ),
                    ),
                  );
                },
              ),
              const SizedBox(height: MitlistSpacing.sm),
              Row(
                children: [
                  AppIcon(
                    name: 'shoppingBagOutline',
                    size: 22,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: MitlistSpacing.sm),
                  MitlistOdometer(value: checkedCount, textStyle: countStyle),
                  const SizedBox(width: MitlistSpacing.xs),
                  Expanded(
                    child: Text(
                      '/ $totalCount collected$priceSuffix',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(width: MitlistSpacing.sm),
                  AppButton(
                    text: 'Mark done',
                    icon: const AppIcon(name: 'checkCircleOutline'),
                    onPressed: onDone,
                    isLoading: isSubmitting,
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

class _ListSection extends StatelessWidget {
  final String listId;
  final String listName;
  final List<ListItem> items;
  final Set<String> checkedIds;
  final ValueChanged<String> onToggle;
  final VoidCallback onTapList;

  const _ListSection({
    required this.listId,
    required this.listName,
    required this.items,
    required this.checkedIds,
    required this.onToggle,
    required this.onTapList,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
      child: AppCard(
        variant: AppCardVariant.outlined,
        padding: AppCardPadding.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            InkWell(
              onTap: onTapList,
              borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      listName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const AppIcon(name: 'chevronRight', size: 16),
                ],
              ),
            ),
            const SizedBox(height: MitlistSpacing.sm),
            Divider(color: Theme.of(context).colorScheme.outlineVariant),
            const SizedBox(height: MitlistSpacing.sm),
            ...items.map((item) {
              final isChecked = checkedIds.contains(item.id);
              return _ItemRow(
                key: ValueKey(item.id),
                item: item,
                isChecked: isChecked,
                onToggle: () => onToggle(item.id),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _ItemRow extends StatefulWidget {
  final ListItem item;
  final bool isChecked;
  final VoidCallback onToggle;

  const _ItemRow({
    super.key,
    required this.item,
    required this.isChecked,
    required this.onToggle,
  });

  @override
  State<_ItemRow> createState() => _ItemRowState();
}

class _ItemRowState extends State<_ItemRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MitlistAnimations.checkToggle,
      value: widget.isChecked ? 1.0 : 0.0,
    );
  }

  @override
  void didUpdateWidget(_ItemRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isChecked != oldWidget.isChecked) {
      if (widget.isChecked) {
        _controller.forward();
      } else {
        _controller.reverse();
      }
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final disableAnimations = MediaQuery.of(context).disableAnimations;

    final qtyText = widget.item.quantity > 0
        ? '${widget.item.quantity.toStringAsFixed(widget.item.quantity == widget.item.quantity.roundToDouble() ? 0 : 1)} ${widget.item.unit}'
        : '';

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = disableAnimations
            ? (widget.isChecked ? 1.0 : 0.0)
            : _controller.value;
        // A single small hop as the item lands in (or leaves) the basket;
        // peaks mid-transition and settles flat. Never persists when checked.
        final hop = disableAnimations ? 0.0 : -math.sin(math.pi * t) * 3.0;
        final strikeProgress = Curves.easeOutCubic.transform(t);
        final textColor = Color.lerp(
          colorScheme.onSurface,
          colorScheme.onSurfaceVariant,
          t,
        )!;

        return Transform.translate(
          offset: Offset(0, hop),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: colorScheme.primary.withValues(alpha: 0.06 * t),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(
                vertical: MitlistSpacing.xs,
                horizontal: MitlistSpacing.xs,
              ),
              child: Row(
                children: [
                  AnimatedCheckToggle(
                    value: widget.isChecked,
                    onChanged: (_) => widget.onToggle(),
                    semanticLabelOn: 'Mark ${widget.item.name} as not purchased',
                    semanticLabelOff: 'Mark ${widget.item.name} as purchased',
                  ),
                  Expanded(
                    child: CustomPaint(
                      foregroundPainter: _StrikePainter(
                        progress: strikeProgress,
                        color: colorScheme.onSurfaceVariant,
                      ),
                      child: Text(
                        widget.item.name,
                        style: textTheme.bodyMedium?.copyWith(color: textColor),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: 1.0 - 0.35 * t,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (qtyText.isNotEmpty)
                          Text(
                            qtyText.trim(),
                            style: MitlistTypography.labelXSmall(),
                          ),
                        if (widget.item.priceCents != null &&
                            widget.item.priceCents! > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: MitlistSpacing.sm),
                            child: Text(
                              '€${(widget.item.priceCents! / 100).toStringAsFixed(2)}',
                              style: MitlistTypography.labelXSmall(),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Draws an ink strike-through that grows across the label from left to right
/// as [progress] goes 0 -> 1.
class _StrikePainter extends CustomPainter {
  _StrikePainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0) return;
    final paint = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    final y = size.height / 2;
    canvas.drawLine(
      Offset(0, y),
      Offset(size.width * progress.clamp(0.0, 1.0), y),
      paint,
    );
  }

  @override
  bool shouldRepaint(_StrikePainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// The completion "stamp" — a rotated, hard-bordered DONE mark that thwacks
/// onto the screen, holds, then lifts away. With reduced motion it simply
/// appears and fades, no scale or rotation.
class _DoneStamp extends StatefulWidget {
  const _DoneStamp({
    required this.count,
    required this.totalCents,
    required this.onComplete,
  });

  final int count;
  final int totalCents;
  final VoidCallback onComplete;

  @override
  State<_DoneStamp> createState() => _DoneStampState();
}

class _DoneStampState extends State<_DoneStamp>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  bool _reduceMotion = false;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this);
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        widget.onComplete();
      }
    });
    // Read reduced-motion next frame, once we have a MediaQuery.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reduceMotion = MediaQuery.of(context).disableAnimations;
      _controller.duration = _reduceMotion
          ? const Duration(milliseconds: 900)
          : const Duration(milliseconds: 1250);
      _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    final priceStr = widget.totalCents > 0
        ? '€${(widget.totalCents / 100).toStringAsFixed(2)}'
        : null;

    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          final t = _controller.value;
          double opacity;
          double scale;
          double rotation;

          if (_reduceMotion) {
            // Appear, hold, fade. No movement.
            opacity = t < 0.75 ? 1.0 : (1.0 - (t - 0.75) / 0.25);
            scale = 1.0;
            rotation = -0.08;
          } else {
            const enter = 0.22;
            const exitStart = 0.72;
            if (t < enter) {
              final p = Curves.easeOutBack.transform(t / enter);
              opacity = (t / enter).clamp(0.0, 1.0);
              scale = 1.5 - 0.5 * p;
              rotation = -0.20 + 0.12 * p;
            } else if (t < exitStart) {
              opacity = 1.0;
              scale = 1.0;
              rotation = -0.08;
            } else {
              final p = (t - exitStart) / (1.0 - exitStart);
              opacity = (1.0 - p).clamp(0.0, 1.0);
              scale = 1.0 + 0.08 * p;
              rotation = -0.08;
            }
          }

          return Opacity(
            opacity: opacity.clamp(0.0, 1.0),
            child: Container(
              color: colorScheme.scrim.withValues(alpha: 0.18 * opacity.clamp(0.0, 1.0)),
              alignment: Alignment.center,
              child: Transform.rotate(
                angle: rotation,
                child: Transform.scale(scale: scale, child: child),
              ),
            ),
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.xl,
            vertical: MitlistSpacing.lg,
          ),
          decoration: BoxDecoration(
            color: colorScheme.surface,
            border: Border.all(color: colorScheme.primary, width: 4),
            boxShadow: MitlistShadows.shadowStrong,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'DONE',
                style: textTheme.displaySmall?.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 2,
                ),
              ),
              const SizedBox(height: MitlistSpacing.xs),
              Text(
                widget.count == 1 ? '1 item' : '${widget.count} items',
                style: textTheme.titleSmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
              if (priceStr != null) ...[
                const SizedBox(height: MitlistSpacing.xs),
                Text(
                  priceStr,
                  style: textTheme.titleLarge?.copyWith(
                    color: colorScheme.onSurface,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
