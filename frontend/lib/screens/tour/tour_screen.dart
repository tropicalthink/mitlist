import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/oauth_provider.dart';
import '../../theme/animations.dart';
import '../../theme/spacing.dart';
import '../../services/product_events.dart';
import '../../utils/haptics.dart';
import '../../widgets/app_button.dart';
import '../../widgets/board/board_page_sheet.dart';
import '../../widgets/board/cork_board.dart';
import 'tour_account_choice.dart';
import 'tour_pages.dart';

/// The feature tour behind "Get started": three pages on the cork board
/// (lists, money, chores), each showing one thing mitlist does with a real,
/// tappable widget on a sample household — not a picture of one. The account
/// choice sits under the chores on the last page (plans/048 stage 6: short,
/// and skippable from the first page straight to sign-up).
///
/// Shape borrowed from the onboarding flows that do this well: a thin
/// progress bar, one headline per page, one full-width button, Skip in the
/// corner.
class TourScreen extends ConsumerStatefulWidget {
  const TourScreen({super.key});

  static const int pageCount = 3;

  @override
  ConsumerState<TourScreen> createState() => _TourScreenState();
}

class _TourScreenState extends ConsumerState<TourScreen> {
  final _controller = PageController();
  int _page = 0;

  @override
  void initState() {
    super.initState();
    ProductEvents.instance.track(ProductEventName.tourStarted);
  }

  /// Straight to creating an account. Without passwords a new account is
  /// made with Google or Apple on the login screen, so that is where it goes.
  void _skip() {
    ProductEvents.instance.track(
      ProductEventName.tourSkipped,
      props: {'page': '${_page + 1}'},
    );
    unawaited(Haptics.light());
    final passwordAuth =
        ref.read(oauthProvidersProvider).valueOrNull?.password ?? true;
    context.goNamed(passwordAuth ? 'signup' : 'login');
  }

  void _onPageChanged(int i) {
    setState(() => _page = i);
    if (i == TourScreen.pageCount - 1) {
      ProductEvents.instance.track(ProductEventName.tourCompleted);
    }
  }

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
                BoardStepBar(
                  page: _page,
                  total: TourScreen.pageCount,
                  onBack: _back,
                  onSkip: _isLast ? null : _skip,
                ),
                Expanded(
                  child: PageView(
                    controller: _controller,
                    onPageChanged: _onPageChanged,
                    children: const [
                      TourListsPage(),
                      TourMoneyPage(),
                      TourChoresPage(footer: TourAccountChoice()),
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
                            text: l10n.tourNext,
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

/// The tour's page body and eyebrow are the generic board-page pieces, shared
/// with the premium flow. Kept under their tour names so the pages read the
/// same as they always have.
typedef TourPageSheet = BoardPageSheet;
typedef TourEyebrow = BoardEyebrow;
