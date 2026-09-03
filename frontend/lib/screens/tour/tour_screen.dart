import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../l10n/app_localizations.dart';
import '../../theme/animations.dart';
import '../../theme/colors.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/haptics.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/board/cork_board.dart';
import 'tour_finish_page.dart';
import 'tour_pages.dart';

/// The feature tour behind "Get started": six pages on the cork board, each
/// showing one thing mitlist does with a real, tappable widget on a sample
/// household — not a picture of one. The last page is the account choice.
///
/// Shape borrowed from the onboarding flows that do this well: a thin
/// progress bar, one headline per page, one full-width button, Skip in the
/// corner, and an account screen at the end with a guest door.
class TourScreen extends ConsumerStatefulWidget {
  const TourScreen({super.key});

  static const int pageCount = 6;

  @override
  ConsumerState<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends ConsumerState<TourScreen> {
  final _controller = PageController();
  int _page = 0;

  bool get _isLast => _page == TourScreen.pageCount - 1;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int page) {
    final target = page.clamp(0, TourScreen.pageCount - 1);
    if (target == _page) return;
    unawaited(Haptics.light());
    if (MediaQuery.of(context).disableAnimations) {
      _controller.jumpToPage(target);
    } else {
      unawaited(_controller.animateToPage(
        target,
        duration: MitlistAnimations.page,
        curve: MitlistAnimations.easeEnter,
      ));
    }
  }

  void _back() {
    if (_page == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    _goTo(_page - 1);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CorkBoardBackground(),
          SafeArea(
            child: Column(
              children: [
                _TourTopBar(
                  page: _page,
                  total: TourScreen.pageCount,
                  onBack: _back,
                  onSkip:
                      _isLast ? null : () => _goTo(TourScreen.pageCount - 1),
                ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: (i) => setState(() => _page = i),
                    children: const [
                      TourWhyPage(),
                      TourListsPage(),
                      TourMoneyPage(),
                      TourChoresPage(),
                      TourRecipesPage(),
                      TourFinishPage(),
                    ],
                  ),
                ),
                if (!_isLast)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      MitlistSpacing.md,
                      MitlistSpacing.sm,
                      MitlistSpacing.md,
                      MitlistSpacing.md,
                    ),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 440),
                        child: SizedBox(
                          width: double.infinity,
                          child: AppButton(
                            text: _page == 0 ? l10n.tourShowMe : l10n.tourNext,
                            variant: AppButtonVariant.solid,
                            color: AppButtonColor.primary,
                            size: AppButtonSize.lg,
                            onPressed: () => _goTo(_page + 1),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Back chevron, progress bar, Skip. The bar is the brand's hard-edged strip
/// in orange, not a row of dots: six pages is long enough that "how far" is
/// a fairer question than "which".
class _TourTopBar extends StatelessWidget {
  const _TourTopBar({
    required this.page,
    required this.total,
    required this.onBack,
    required this.onSkip,
  });

  final int page;
  final int total;
  final VoidCallback onBack;
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

/// The shared body of a tour page: a scrollable, width-capped sheet of paper
/// taped to the board, carrying the eyebrow, headline, body copy and the live
/// widget the page is about.
class TourPageSheet extends StatelessWidget {
  const TourPageSheet({
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
                TourEyebrow(eyebrow),
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

/// Small mono caps label above a headline (LISTS, MONEY, CHORES…).
class TourEyebrow extends StatelessWidget {
  const TourEyebrow(this.text, {super.key});

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
