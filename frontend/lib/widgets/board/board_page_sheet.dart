import 'package:flutter/material.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/animations.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../app_button.dart';
import '../app_icon.dart';
import 'cork_board.dart';

/// The shared body of a paged board screen: a scrollable, width-capped sheet
/// of paper taped to the board, carrying an eyebrow, a headline, body copy and
/// the live widget the page is about.
///
/// Used by the feature tour and by the premium flow, which are the same shape
/// — a sequence of one-idea pages on the cork board — pointed at different
/// audiences.
class BoardPageSheet extends StatelessWidget {
  const BoardPageSheet({
    super.key,
    required this.eyebrow,
    required this.headline,
    required this.body,
    required this.child,
  });

  final String eyebrow;
  final String headline;
  final String body;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        MitlistSpacing.md,
        MitlistSpacing.lg,
        MitlistSpacing.md,
        MitlistSpacing.sm,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 440),
          child: TapedPanel(
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
                BoardEyebrow(eyebrow),
                const SizedBox(height: MitlistSpacing.space2),
                Text(
                  headline,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: MitlistSpacing.space3),
                Text(
                  body,
                  style: textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: MitlistSpacing.space5),
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Back chevron, progress bar, Skip. The bar is the brand's hard-edged strip
/// in orange, not a row of dots: these flows are long enough that "how far" is
/// a fairer question than "which".
class BoardStepBar extends StatelessWidget {
  const BoardStepBar({
    super.key,
    required this.page,
    required this.total,
    required this.onBack,
    required this.onSkip,
  });

  final int page;
  final int total;
  final VoidCallback onBack;

  /// Null hides the Skip affordance — on the last page there is nowhere to
  /// skip to.
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final reduce = MediaQuery.of(context).disableAnimations;
    final fraction = (page + 1) / total;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        MitlistSpacing.sm,
        MitlistSpacing.sm,
        MitlistSpacing.sm,
        0,
      ),
      child: Row(
        children: [
          Semantics(
            button: true,
            label: l10n.tourBack,
            child: InkWell(
              onTap: onBack,
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: AppIcon(
                    name: 'arrowLeft',
                    size: 22,
                    color: MitlistColors.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: Semantics(
              label: l10n.tourStepOf(page + 1, total),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  color: MitlistColors.surfacePrimary,
                  border: Border.all(
                    color: MitlistColors.borderPrimary,
                    width: 2,
                  ),
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedFractionallySizedBox(
                    duration: reduce ? Duration.zero : MitlistAnimations.medium,
                    curve: MitlistAnimations.easeEnter,
                    widthFactor: fraction,
                    heightFactor: 1,
                    child: const ColoredBox(color: MitlistColors.primary500),
                  ),
                ),
              ),
            ),
          ),
          SizedBox(
            width: 88,
            child: onSkip == null
                ? null
                : Align(
                    alignment: Alignment.centerRight,
                    child: AppButton(
                      text: l10n.tourSkip,
                      variant: AppButtonVariant.ghost,
                      color: AppButtonColor.neutral,
                      size: AppButtonSize.sm,
                      onPressed: onSkip,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

/// Small mono caps label above a headline (LISTS, MONEY, CHORES...).
class BoardEyebrow extends StatelessWidget {
  const BoardEyebrow(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: MitlistTypography.monoBody(color: MitlistColors.primary600)
          .copyWith(fontSize: 12, letterSpacing: 1.4, height: 1.2),
    );
  }
}
