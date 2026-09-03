import 'dart:async';

import 'package:collection/collection.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/auth_models.dart';
import '../../models/pinwall_models.dart';
import '../../providers/pinwall_provider.dart';
import '../../providers/list_provider.dart';
import '../../providers/meal_plan_provider.dart';
import '../../repositories/pinwall_repository.dart';
import '../../screens/pinwall/pinwall_board_screen.dart';
import '../../sheets/pinwall_note_editor_sheet.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../utils/haptics.dart';
import '../app_button.dart';
import '../pinwall/pinwall_composer.dart';
import '../pinwall/pinwall_note_card.dart';
import '../pinwall/pinwall_stat_rows.dart';

/// Column count and card width for the hub pinwall at [availableWidth].
///
/// The cards are sized so a whole number of columns exactly fills the row. A
/// fixed card width cannot do that: as soon as the viewport is narrower than
/// two cards plus spacing — which happens on ordinary phones once the system
/// display-size setting is raised — the wrap breaks to a single card per row
/// and leaves the rest of the row empty.
@visibleForTesting
({int columns, double cardWidth}) pinwallHubLayout(double availableWidth) {
  const spacing = MitlistSpacing.md;
  // Two per row on phones. Wider surfaces (tablets, landscape) take more
  // columns so notes keep a readable size instead of stretching.
  final columns = (availableWidth / 200).floor().clamp(2, 4);
  return (
    columns: columns,
    cardWidth: (availableWidth - spacing * (columns - 1)) / columns,
  );
}

class PinwallSection extends ConsumerStatefulWidget {
  const PinwallSection({super.key, required this.groupId, required this.me});

  final String groupId;
  final User? me;

  @override
  ConsumerState<PinwallSection> createState() => _PinwallSectionState();
}

class _PinwallSectionState extends ConsumerState<PinwallSection> {
  PinwallRepository? _repo;

  @override
  void initState() {
    super.initState();
    // Open the realtime stream for the household so pins from flatmates land
    // live on the hub wall (and, by extension, the full-screen board).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final repo = await ref.read(pinwallRepositoryProvider.future);
      if (!mounted) return;
      _repo = repo;
      repo.attachSse(ref.read(sseServiceProvider), widget.groupId);
    });
  }

  @override
  void didUpdateWidget(covariant PinwallSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    // The hub keeps this widget across a household switch, so the realtime
    // stream has to move with it or the wall keeps listening to the old house.
    if (oldWidget.groupId != widget.groupId) {
      final repo = _repo;
      if (repo != null) {
        repo.detachSse();
        repo.attachSse(ref.read(sseServiceProvider), widget.groupId);
      }
    }
  }

  @override
  void dispose() {
    _repo?.detachSse();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;

    final boardBg =
        dark ? MitlistColors.pinwallBoardDark : MitlistColors.pinwallBoard;
    final boardBorder = dark
        ? MitlistColors.pinwallBoardBorderDark
        : MitlistColors.pinwallBoardBorder;
    final boardShadow =
        MitlistColors.neutral950.withValues(alpha: dark ? 0.38 : 0.16);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
          child: Row(
            children: [
              Expanded(
                child:
                    Text(l10n.pinwallBoardLabel, style: textTheme.titleMedium),
              ),
              _PinwallOpenBoardButton(
                groupId: widget.groupId,
                me: widget.me,
                boardBg: boardBg,
                boardBorder: boardBorder,
                dark: dark,
                textTheme: textTheme,
              ),
            ],
          ),
        ),
        Hero(
          tag: 'pinwall_board_${widget.groupId}',
          flightShuttleBuilder: (ctx, anim, dir, fromCtx, toCtx) {
            return AnimatedBuilder(
              animation: anim,
              builder: (_, __) => Container(
                decoration: BoxDecoration(
                  color: boardBg,
                  borderRadius: BorderRadius.circular(
                    MitlistTheme.radiusLg * (1 - anim.value),
                  ),
                  border: Border.all(color: boardBorder, width: 2),
                ),
              ),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(MitlistSpacing.sm),
            decoration: BoxDecoration(
              color: boardBg,
              borderRadius: BorderRadius.circular(MitlistTheme.radiusLg),
              border: Border.all(color: boardBorder, width: 2),
              boxShadow: [
                BoxShadow(
                  color: boardShadow,
                  blurRadius: 10,
                  offset: const Offset(4, 5),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const SizedBox(height: MitlistSpacing.sm),
                PinwallComposer(groupId: widget.groupId, me: widget.me),
                const SizedBox(height: MitlistSpacing.sm),
                _PinwallQuickStats(groupId: widget.groupId),
                const SizedBox(height: MitlistSpacing.lg),
                RepaintBoundary(
                  child: _PinwallPostsList(
                    groupId: widget.groupId,
                    me: widget.me,
                    boardBorder: boardBorder,
                    dark: dark,
                    textTheme: textTheme,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PinwallOpenBoardButton extends ConsumerWidget {
  const _PinwallOpenBoardButton({
    required this.groupId,
    required this.me,
    required this.boardBg,
    required this.boardBorder,
    required this.dark,
    required this.textTheme,
  });

  final String groupId;
  final User? me;
  final Color boardBg;
  final Color boardBorder;
  final bool dark;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final posts = ref.watch(pinwallPostsByGroupProvider(groupId));

    return Semantics(
      label: l10n.pinwallOpenBoard,
      child: GestureDetector(
        onTap: () {
          Haptics.light();
          PinwallBoardScreen.show(
            context,
            groupId: groupId,
            me: me,
            posts: posts.value!,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.sm,
            vertical: MitlistSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: boardBg,
            borderRadius: BorderRadius.circular(MitlistTheme.radiusFull),
            border: Border.all(color: boardBorder, width: 1.5),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.open_in_full_rounded,
                size: 13,
                color: dark
                    ? MitlistColors.pinwallNoteTextDark
                    : MitlistColors.pinwallNoteTextLight,
              ),
              const SizedBox(width: 4),
              Text(
                l10n.pinwallOpenBoardBtn,
                style: textTheme.labelSmall?.copyWith(
                  color: dark
                      ? MitlistColors.pinwallNoteTextDark
                      : MitlistColors.pinwallNoteTextLight,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// How many notes the hub preview shows before the rest is left to the board.
@visibleForTesting
const int kPinwallHubMaxNotes = 6;

/// The [limit] most recently created posts, newest first. The cache is
/// normally already newest-first (server order plus offline creates at the
/// front), but the hub should not depend on that.
@visibleForTesting
List<PinwallPost> latestPinwallPosts(List<PinwallPost> rows, int limit) {
  final sorted = List<PinwallPost>.of(rows)
    ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
  return sorted.take(limit).toList();
}

class _PinwallPostsList extends ConsumerWidget {
  const _PinwallPostsList({
    required this.groupId,
    required this.me,
    required this.boardBorder,
    required this.dark,
    required this.textTheme,
  });

  final String groupId;
  final User? me;
  final Color boardBorder;
  final bool dark;
  final TextTheme textTheme;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final posts = ref.watch(pinwallPostsByGroupProvider(groupId));

    return posts.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => Container(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        decoration: BoxDecoration(
          color: dark
              ? MitlistColors.pinwallNoteErrorDark
              : MitlistColors.noteYellow,
          borderRadius: BorderRadius.circular(MitlistTheme.radiusLg),
          border: Border.all(color: boardBorder, width: 1.5),
        ),
        child: Row(
          children: [
            Icon(Icons.warning_amber_rounded,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: MitlistSpacing.sm),
            Expanded(
              child: Text(
                l10n.pinwallCouldNotLoad,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall,
              ),
            ),
            AppButton(
              text: l10n.commonRetry,
              variant: AppButtonVariant.ghost,
              size: AppButtonSize.sm,
              onPressed: () =>
                  ref.invalidate(pinwallPostsByGroupProvider(groupId)),
            ),
          ],
        ),
      ),
      data: (rows) {
        if (rows.isEmpty) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.md),
            child: Text(
              l10n.pinwallEmptyBoard,
              textAlign: TextAlign.center,
              style: textTheme.bodySmall?.copyWith(
                color: dark
                    ? MitlistColors.pinwallNoteTextDark
                    : MitlistColors.pinwallNoteTextLight,
              ),
            ),
          );
        }
        // The hub is a preview, not the whole board: only the newest few
        // notes, so a busy household doesn't push the rest of the home screen
        // off the bottom. The full set lives on the board (header button).
        final show = latestPinwallPosts(rows, kPinwallHubMaxNotes);
        return LayoutBuilder(
          builder: (context, constraints) {
            final layout = pinwallHubLayout(constraints.maxWidth);

            return Wrap(
              spacing: MitlistSpacing.md,
              runSpacing: MitlistSpacing.lg,
              children: [
                for (var i = 0; i < show.length; i++)
                  PinwallNoteCard(
                    variant: PinwallNoteCardVariant.hub,
                    index: i,
                    groupId: groupId,
                    me: me,
                    post: show[i],
                    width: layout.cardWidth,
                    onOpenLinkedEntity: (ctx) =>
                        _navigateToLinkedEntity(ctx, show[i]),
                    onEdit: () => showPinwallNoteEditorSheet(
                      context,
                      groupId: groupId,
                      post: show[i],
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}

/// Compact, inline "torn paper" list of household stats that sits directly
/// under the composer note — Chores / Balance / Lists / Tonight, each a
/// tappable row that jumps to its tab.
///
/// Collapsed by default so the pinned notes surface sooner; tapping the header
/// expands the detail rows.
class _PinwallQuickStats extends StatefulWidget {
  const _PinwallQuickStats({required this.groupId});

  final String groupId;

  @override
  State<_PinwallQuickStats> createState() => _PinwallQuickStatsState();
}

class _PinwallQuickStatsState extends State<_PinwallQuickStats> {
  bool _expanded = false;

  void _toggle() {
    unawaited(Haptics.light());
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final bg =
        dark ? MitlistColors.composerBgDark : MitlistColors.composerBgLight;
    final border = dark
        ? MitlistColors.composerBorderDark
        : MitlistColors.composerBorderLight;
    final textColor = dark
        ? MitlistColors.surfaceSoft.withValues(alpha: 0.9)
        : MitlistColors.pinwallNoteTextLight;
    final mutedColor = textColor.withValues(alpha: 0.6);

    return Container(
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(MitlistTheme.radiusMd),
        border: Border.all(color: border, width: 1.5),
        boxShadow: [
          BoxShadow(
            color:
                MitlistColors.neutral950.withValues(alpha: dark ? 0.42 : 0.16),
            blurRadius: 0,
            offset: const Offset(4, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            button: true,
            expanded: _expanded,
            label: l10n.pinwallSnapshot,
            child: InkWell(
              onTap: _toggle,
              borderRadius: BorderRadius.circular(MitlistTheme.radiusMd),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: MitlistSpacing.md,
                  vertical: MitlistSpacing.sm + 2,
                ),
                child: Row(
                  children: [
                    Icon(Icons.insights_outlined, size: 18, color: mutedColor),
                    const SizedBox(width: MitlistSpacing.sm),
                    Text(
                      l10n.pinwallSnapshot,
                      style: textTheme.bodyMedium?.copyWith(
                        color: textColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Spacer(),
                    AnimatedRotation(
                      turns: _expanded ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child:
                          Icon(Icons.expand_more, size: 20, color: mutedColor),
                    ),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _expanded
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _StatRowDivider(color: border),
                      PinwallChoresStatRow(
                        groupId: widget.groupId,
                        style: PinwallStatRowStyle.inline,
                        ink: textColor,
                        muted: mutedColor,
                      ),
                      _StatRowDivider(color: border),
                      PinwallFinanceStatRow(
                        groupId: widget.groupId,
                        style: PinwallStatRowStyle.inline,
                        ink: textColor,
                        muted: mutedColor,
                      ),
                      _StatRowDivider(color: border),
                      PinwallListsStatRow(
                        groupId: widget.groupId,
                        style: PinwallStatRowStyle.inline,
                        ink: textColor,
                        muted: mutedColor,
                      ),
                      _StatRowDivider(color: border),
                      _TonightStatRow(groupId: widget.groupId),
                    ],
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _StatRowDivider extends StatelessWidget {
  const _StatRowDivider({required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 1,
      thickness: 1,
      indent: MitlistSpacing.md,
      endIndent: MitlistSpacing.md,
      color: color.withValues(alpha: 0.5),
    );
  }
}

class _TonightStatRow extends ConsumerWidget {
  const _TonightStatRow({required this.groupId});

  final String groupId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final async = ref.watch(todayMealPlansProvider(groupId));
    final theme = Theme.of(context).colorScheme;

    final meals = async.valueOrNull;
    String value;
    if (meals == null || meals.isEmpty) {
      value = l10n.tonightNothingPlanned;
    } else {
      TodayMeal? selected;
      for (final slot in const ['dinner', 'breakfast', 'lunch']) {
        selected = meals.firstWhereOrNull((m) => m.plan.slot == slot);
        if (selected != null) {
          break;
        }
      }
      selected ??= meals.first;
      value = selected.recipe?.title ?? l10n.tonightRecipe;
    }

    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark
        ? MitlistColors.surfaceSoft.withValues(alpha: 0.9)
        : MitlistColors.pinwallNoteTextLight;
    final muted = ink.withValues(alpha: 0.6);

    return PinwallStatRow(
      style: PinwallStatRowStyle.inline,
      icon: Icons.restaurant_outlined,
      label: l10n.tonightHeader,
      value: value,
      accent: theme.tertiary,
      ink: ink,
      muted: muted,
      onTap: () => context.pushNamed('mealPlan'),
    );
  }
}

void _navigateToLinkedEntity(BuildContext context, PinwallPost post) {
  final type = post.linkedEntityType;
  final id = post.linkedEntityId;
  if (type == null) return;
  switch (type) {
    case 'list':
      if (id != null && id.isNotEmpty) {
        context.go('/lists/$id');
      } else {
        context.go('/lists');
      }
    case 'chore':
      // Chores live in a shell tab branch; go() switches to the tab.
      context.go('/chores');
    case 'expense':
      // Money lives in a shell tab branch; go() switches to the tab.
      context.go('/money');
  }
}
