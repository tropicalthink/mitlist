import 'package:flutter/material.dart';

import '../../theme/colors.dart';
import '../../theme/shadows.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import 'cork_board.dart';

/// Miniature artifacts in the board idiom: a shopping list scrap, a receipt,
/// a chore note, a recipe card. They are the app explaining itself without
/// words — the welcome collage shows them *filled* (believable content, the
/// promise), and empty surfaces show them as *ghosts* (dashed checkboxes,
/// faint greeked lines — the same object, visibly waiting for the household's
/// first real one). A ghost turning into its filled form IS the progress
/// signal; no sentence needs to say so.
///
/// All content inside is decorative: callers own the semantics.

/// Greeked line of text: a soft bar standing in for handwriting.
class InkBar extends StatelessWidget {
  const InkBar({super.key, required this.width, this.color});

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

/// The short handwritten label at the top of a scrap.
class ScrapLabel extends StatelessWidget {
  const ScrapLabel(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
      style: Theme.of(context).textTheme.titleSmall?.copyWith(
            color: color ?? MitlistColors.textPrimary,
            fontWeight: FontWeight.w800,
          ),
    );
  }
}

/// White paper scrap pinned to the board; base for the list and receipt
/// artifacts. Paper stays paper-white in both themes so ink contrast is
/// constant.
class PaperScrap extends StatelessWidget {
  const PaperScrap({super.key, required this.child});

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
          padding: const EdgeInsets.all(MitlistSpacing.space4),
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

/// Dashed outline for ghost checkboxes and empty seats — the universal
/// "this goes here" shape.
class DashedShapePainter extends CustomPainter {
  const DashedShapePainter({
    required this.color,
    this.circle = false,
    this.strokeWidth = 2,
    this.dash = 3.5,
    this.gap = 3,
  });

  final Color color;
  final bool circle;
  final double strokeWidth;
  final double dash;
  final double gap;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    final inset = strokeWidth / 2;
    final rect = Rect.fromLTWH(
      inset,
      inset,
      size.width - strokeWidth,
      size.height - strokeWidth,
    );
    final path = Path();
    if (circle) {
      path.addOval(rect);
    } else {
      path.addRect(rect);
    }

    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(
          metric.extractPath(distance, distance + dash),
          paint,
        );
        distance += dash + gap;
      }
    }
  }

  @override
  bool shouldRepaint(DashedShapePainter oldDelegate) =>
      color != oldDelegate.color ||
      circle != oldDelegate.circle ||
      strokeWidth != oldDelegate.strokeWidth;
}

class _DashedBox extends StatelessWidget {
  const _DashedBox({required this.size, required this.color, this.circle = false});

  final double size;
  final Color color;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: Size.square(size),
      painter: DashedShapePainter(color: color, circle: circle),
    );
  }
}

/// The solid "add" affordance pinned to the corner of a ghost artifact: the
/// same hard-edged primary square the rest of the app uses for creating
/// things. One glance says "tap to make this real".
class ScrapPlusBadge extends StatelessWidget {
  const ScrapPlusBadge({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        color: MitlistColors.primary500,
        border: Border.fromBorderSide(
          BorderSide(color: MitlistColors.borderPrimary, width: 2),
        ),
        boxShadow: MitlistShadows.shadowMedium,
      ),
      child: Icon(Icons.add, size: size * 0.62, color: Colors.white),
    );
  }
}

/// A scrap of shopping list. Filled: checkboxes with one already ticked.
/// Ghost: dashed empty checkboxes and faint lines — a list waiting to be
/// started.
class ListScrap extends StatelessWidget {
  const ListScrap({super.key, required this.label, this.ghost = false});

  final String label;
  final bool ghost;

  @override
  Widget build(BuildContext context) {
    final faintInk = MitlistColors.textPrimary.withValues(alpha: 0.14);
    final dashInk = MitlistColors.textPrimary.withValues(alpha: 0.38);

    Widget row({required bool checked, required double barWidth}) {
      return Row(
        children: [
          if (ghost)
            _DashedBox(size: 14, color: dashInk)
          else
            Container(
              width: 14,
              height: 14,
              decoration: BoxDecoration(
                color: checked ? MitlistColors.primary500 : Colors.transparent,
                border:
                    Border.all(color: MitlistColors.borderPrimary, width: 2),
              ),
              child: checked
                  ? const Icon(Icons.check, size: 10, color: Colors.white)
                  : null,
            ),
          const SizedBox(width: MitlistSpacing.space2),
          InkBar(width: barWidth, color: ghost ? faintInk : null),
        ],
      );
    }

    return PaperScrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScrapLabel(label),
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

/// A scrap of receipt. Filled: two amounts and a settled total. Ghost: faint
/// lines and blank amounts — a first shared cost waiting to be logged.
class ReceiptScrap extends StatelessWidget {
  const ReceiptScrap({super.key, required this.label, this.ghost = false});

  final String label;
  final bool ghost;

  TextStyle _mono(double alpha) => MitlistTypography.monoBody(
        color: MitlistColors.textPrimary.withValues(alpha: alpha),
        weight: FontWeight.w700,
      ).copyWith(fontSize: 11, height: 1.0);

  @override
  Widget build(BuildContext context) {
    final barColor = ghost
        ? MitlistColors.textPrimary.withValues(alpha: 0.14)
        : MitlistColors.textPrimary.withValues(alpha: 0.22);
    final amountStyle = _mono(ghost ? 0.30 : 0.75);

    Widget amountRow(double barWidth, String amount) {
      return Row(
        children: [
          InkBar(width: barWidth, color: barColor),
          const Spacer(),
          Text(ghost ? '–.––' : amount, style: amountStyle),
        ],
      );
    }

    return PaperScrap(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScrapLabel(label),
          const SizedBox(height: MitlistSpacing.space3),
          amountRow(44, '4.20'),
          const SizedBox(height: MitlistSpacing.space2),
          amountRow(58, '7.80'),
          const SizedBox(height: MitlistSpacing.space2),
          Container(
            height: 2,
            color: MitlistColors.textPrimary
                .withValues(alpha: ghost ? 0.16 : 0.30),
          ),
          const SizedBox(height: MitlistSpacing.space2),
          Row(
            children: [
              const Spacer(),
              Text(
                ghost ? '–.––' : '12.00',
                style: ghost
                    ? _mono(0.30).copyWith(fontSize: 12)
                    : MitlistTypography.monoBody(
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

/// A chore note on mint. Filled: one chore done, the rota dots underneath.
/// Ghost: dashed circle, faint line, every rota dot empty — a rhythm waiting
/// to start.
class ChoreScrap extends StatelessWidget {
  const ChoreScrap({super.key, required this.label, this.ghost = false});

  final String label;
  final bool ghost;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? MitlistColors.neutral50 : MitlistColors.textPrimary;
    final barColor = ink.withValues(alpha: ghost ? 0.16 : 0.28);
    final dotColor = ink.withValues(alpha: ghost ? 0.38 : 0.55);

    return StickyNoteSurface(
      color: dark ? MitlistColors.noteMintDark : MitlistColors.noteMint,
      padding: const EdgeInsets.all(MitlistSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScrapLabel(label, color: ink),
          const SizedBox(height: MitlistSpacing.space3),
          Row(
            children: [
              if (ghost)
                _DashedBox(size: 16, color: dotColor, circle: true)
              else
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
              InkBar(width: 56, color: barColor),
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
                    color: (!ghost && i == 0) ? dotColor : Colors.transparent,
                    border: Border.all(color: dotColor, width: 1.5),
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

/// A recipe card on sky blue. Filled: title bar and dotted ingredient lines.
/// Ghost: everything faint — a kitchen waiting for its first recipe.
class RecipeScrap extends StatelessWidget {
  const RecipeScrap({super.key, required this.label, this.ghost = false});

  final String label;
  final bool ghost;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final ink = dark ? MitlistColors.neutral50 : MitlistColors.textPrimary;
    final titleAlpha = ghost ? 0.20 : 0.40;
    final barAlpha = ghost ? 0.16 : 0.28;
    final dotAlpha = ghost ? 0.24 : 0.45;

    Widget ingredient(double barWidth) {
      return Row(
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ink.withValues(alpha: dotAlpha),
            ),
          ),
          const SizedBox(width: MitlistSpacing.space2),
          InkBar(width: barWidth, color: ink.withValues(alpha: barAlpha)),
        ],
      );
    }

    return StickyNoteSurface(
      color: dark ? MitlistColors.noteSkyDark : MitlistColors.noteSky,
      padding: const EdgeInsets.all(MitlistSpacing.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ScrapLabel(label, color: ink),
          const SizedBox(height: MitlistSpacing.space3),
          InkBar(width: 72, color: ink.withValues(alpha: titleAlpha)),
          const SizedBox(height: MitlistSpacing.space3),
          ingredient(48),
          const SizedBox(height: MitlistSpacing.space2),
          ingredient(60),
        ],
      ),
    );
  }
}

/// The household's seats: one solid circle per member already here, dashed
/// circles for the empty chairs. Empty chairs ask to be filled — no sentence
/// required.
class InviteSeats extends StatelessWidget {
  const InviteSeats({super.key, required this.members, this.seats = 3});

  /// How many people are actually in the household.
  final int members;

  /// Total chairs drawn; clamped so at least one empty chair shows while the
  /// household is short of it.
  final int seats;

  @override
  Widget build(BuildContext context) {
    const ink = MitlistColors.textPrimary;
    final total = members >= seats ? members + 1 : seats;
    const size = 22.0;

    return Row(
      children: [
        for (var i = 0; i < total; i++) ...[
          if (i > 0) const SizedBox(width: MitlistSpacing.space2),
          if (i < members)
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: MitlistColors.primary500,
                border: Border.all(
                  color: MitlistColors.borderPrimary,
                  width: 2,
                ),
              ),
              child: const Icon(Icons.person, size: 13, color: Colors.white),
            )
          else
            _DashedBox(
              size: size,
              color: ink.withValues(alpha: 0.40),
              circle: true,
            ),
        ],
      ],
    );
  }
}
