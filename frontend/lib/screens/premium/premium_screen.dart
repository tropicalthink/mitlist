import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../config/iap_config.dart';
import '../../l10n/app_localizations.dart';
import '../../models/billing_models.dart';
import '../../providers/billing_provider.dart';
import '../../services/iap_service.dart';
import '../../theme/animations.dart';
import '../../theme/spacing.dart';
import '../../utils/haptics.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/board/board_page_sheet.dart';
import '../../widgets/board/cork_board.dart';
import 'premium_pages.dart';

/// The premium flow for [groupId]: a paged screen on the cork board that makes
/// the case for one more person before it asks for money.
///
/// The household's entitlement decides how long the flow is:
///
///  * nobody pays — four pages showing what a household one person larger
///    actually does, then the plan;
///  * the caller pays but for a *different* household — one page offering to
///    move their premium here rather than sell them a second subscription;
///  * already premium — one page saying so, with nothing to sell.
///
/// On mobile the purchase happens in the native store; everywhere else it
/// hands off to the provider's hosted checkout in a browser and the webhook
/// activates premium a moment later.
class PremiumScreen extends ConsumerStatefulWidget {
  const PremiumScreen({super.key, required this.groupId});

  final String groupId;

  @override
  ConsumerState<PremiumScreen> createState() => _PremiumScreenState();
}

class _PremiumScreenState extends ConsumerState<PremiumScreen> {
  final _controller = PageController();
  int _page = 0;

  BillingInterval _interval = BillingInterval.yearly;
  bool _busy = false;
  String? _error;

  /// The native IAP service and its purchase-result subscription, used only on
  /// iOS and Android. Null on web/desktop, which keep the hosted checkout.
  IapService? _iap;
  StreamSubscription<IapResult>? _iapSub;

  @override
  void initState() {
    super.initState();
    // Preload store products so the selector can show the store's own
    // localized price (which already includes the +€2 annual uplift).
    if (IapService.isSupported) {
      _loadStoreProducts();
    }
  }

  @override
  void dispose() {
    _iapSub?.cancel();
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadStoreProducts() async {
    try {
      final iap = await ref.read(iapServiceProvider.future);
      await iap.loadProducts();
      if (!mounted) return;
      setState(() => _iap = iap);
    } catch (_) {
      // Prices are decoration; a failure just leaves the tiles without them.
    }
  }

  // -------------------------------------------------------------------------
  // Paging
  // -------------------------------------------------------------------------

  void _goTo(int page, int total) {
    final target = page.clamp(0, total - 1);
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

  void _back(int total) {
    if (_page == 0) {
      Navigator.of(context).maybePop();
      return;
    }
    _goTo(_page - 1, total);
  }

  // -------------------------------------------------------------------------
  // Buying
  // -------------------------------------------------------------------------

  /// Entry point for the subscribe button: native IAP on mobile, hosted
  /// checkout in a browser everywhere else.
  Future<void> _startCheckout() async {
    if (IapService.isSupported) {
      await _startIapPurchase();
    } else {
      await _startWebCheckout();
    }
  }

  Future<void> _startWebCheckout() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = await ref.read(billingServiceProvider.future);
      final url = await service.createCheckout(
        interval: _interval,
        groupId: widget.groupId,
      );
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw Exception('launch failed');
      // The subscription only exists once the provider's webhook lands, so
      // refresh rather than assuming success.
      invalidateBilling(ref);
      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.billingCheckoutFailed;
      });
    }
  }

  /// Runs the native store purchase. The store confirms payment
  /// asynchronously, so this subscribes to the result stream: only a verified
  /// success (the backend validated the receipt) activates premium and leaves.
  Future<void> _startIapPurchase() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final iap = await ref.read(iapServiceProvider.future);
      await _iapSub?.cancel();
      _iapSub = iap.results.listen(_onIapResult);
      await iap.buy(interval: _interval, groupId: widget.groupId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.billingCheckoutFailed;
      });
    }
  }

  void _onIapResult(IapResult result) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context)!;
    switch (result.status) {
      case IapStatus.pending:
        // Keep the button busy; the store is still processing.
        break;
      case IapStatus.canceled:
        setState(() => _busy = false);
      case IapStatus.error:
        setState(() {
          _busy = false;
          _error = l10n.billingCheckoutFailed;
        });
      case IapStatus.success:
        invalidateBilling(ref);
        final navigator = Navigator.of(context);
        final message = l10n.billingPurchased;
        navigator.pop();
        if (mounted) AppToast.success(context, message);
    }
  }

  Future<void> _restorePurchases() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final iap = await ref.read(iapServiceProvider.future);
      await _iapSub?.cancel();
      _iapSub = iap.results.listen(_onIapResult);
      await iap.restore(groupId: widget.groupId);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.billingCheckoutFailed;
      });
    }
  }

  Future<void> _movePremiumHere() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = await ref.read(billingServiceProvider.future);
      await service.setPremiumHousehold(widget.groupId);
      invalidateBilling(ref);
      if (!mounted) return;
      final navigator = Navigator.of(context);
      final message = l10n.billingMoved;
      navigator.pop();
      if (!mounted) return;
      AppToast.success(context, message);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.billingMoveFailed;
      });
    }
  }

  /// Formats the price for an interval. On mobile the store is the source of
  /// truth — its localized string already includes the +€2 annual uplift — so
  /// the [plan] is used only on web/desktop. Null renders a tile with no price
  /// rather than a wrong one.
  String? _priceLabel(BillingInterval interval, BillingPlan? plan) {
    if (IapService.isSupported) {
      return _iap?.priceLabel(interval);
    }
    if (plan == null) return null;
    final locale = Localizations.localeOf(context).toString();
    return NumberFormat.simpleCurrency(
      locale: locale,
      name: plan.currency,
    ).format(plan.amountCents / 100);
  }

  Future<void> _openLegalUrl(String value) async {
    final launched = await launchUrl(
      Uri.parse(value),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      AppToast.error(
          context, AppLocalizations.of(context)!.commonSomethingWentWrong);
    }
  }

  // -------------------------------------------------------------------------
  // Build
  // -------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final entitlementAsync =
        ref.watch(householdEntitlementProvider(widget.groupId));

    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const CorkBoardBackground(),
          SafeArea(
            child: entitlementAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => _SinglePanel(
                onClose: () => Navigator.of(context).maybePop(),
                child: AppAlert(
                  type: AppAlertType.error,
                  message: l10n.commonSomethingWentWrong,
                ),
              ),
              data: (entitlement) {
                if (entitlement == null) {
                  // Billing is not configured on this server. Nothing to sell,
                  // and nothing worth keeping the person here for.
                  return _SinglePanel(
                    onClose: () => Navigator.of(context).maybePop(),
                    child: const SizedBox.shrink(),
                  );
                }
                return _buildFlow(entitlement);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFlow(HouseholdEntitlement entitlement) {
    // A household that is already covered, and a caller who only needs to move
    // premium they already pay for, are both one-page answers. Neither is a
    // sale, so neither gets the four-page argument for one.
    if (entitlement.premium) {
      return _SinglePanel(
        onClose: () => Navigator.of(context).maybePop(),
        child: _PremiumActivePanel(entitlement: entitlement),
      );
    }
    if (entitlement.canMovePremiumHere) {
      return _SinglePanel(
        onClose: () => Navigator.of(context).maybePop(),
        child: _MovePanel(
          error: _error,
          busy: _busy,
          onMove: _movePremiumHere,
        ),
      );
    }
    return _buildPagedFlow(entitlement);
  }

  Widget _buildPagedFlow(HouseholdEntitlement entitlement) {
    final l10n = AppLocalizations.of(context)!;
    const total = 5;
    final isLast = _page == total - 1;

    return Column(
      children: [
        BoardStepBar(
          page: _page,
          total: total,
          onBack: () => _back(total),
          onSkip: isLast ? null : () => _goTo(total - 1, total),
        ),
        Expanded(
          child: PageView(
            controller: _controller,
            onPageChanged: (i) => setState(() => _page = i),
            children: [
              PremiumSeatsPage(entitlement: entitlement),
              const PremiumListsPage(),
              const PremiumMoneyPage(),
              const PremiumChoresPage(),
              _buildPlanPage(),
            ],
          ),
        ),
        if (!isLast)
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
                    text: _page == total - 2
                        ? l10n.premiumSeeThePlan
                        : l10n.tourNext,
                    variant: AppButtonVariant.solid,
                    color: AppButtonColor.primary,
                    size: AppButtonSize.lg,
                    onPressed: () => _goTo(_page + 1, total),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// The last page: what it costs and the button that starts the purchase.
  Widget _buildPlanPage() {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    // Prices come from the provider's catalog via /billing/status. When it is
    // unreachable the selector simply renders without them.
    final status = ref.watch(billingStatusProvider).valueOrNull;

    return BoardPageSheet(
      eyebrow: l10n.premiumPlanEyebrow,
      headline: l10n.premiumPlanHeadline,
      body: l10n.billingCoversOneHousehold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_error != null) ...[
            AppAlert(type: AppAlertType.error, message: _error!),
            const SizedBox(height: MitlistSpacing.md),
          ],
          _IntervalSelector(
            selected: _interval,
            enabled: !_busy,
            yearlyPrice: _priceLabel(BillingInterval.yearly,
                status?.planFor(BillingInterval.yearly)),
            monthlyPrice: _priceLabel(BillingInterval.monthly,
                status?.planFor(BillingInterval.monthly)),
            onChanged: (value) => setState(() => _interval = value),
          ),
          const SizedBox(height: MitlistSpacing.lg),
          AppButton(
            text: _busy
                ? (IapService.isSupported
                    ? l10n.billingProcessing
                    : l10n.billingOpeningCheckout)
                : l10n.billingSubscribe,
            variant: AppButtonVariant.solid,
            color: AppButtonColor.primary,
            size: AppButtonSize.lg,
            isLoading: _busy,
            onPressed: _busy ? null : _startCheckout,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          if (IapService.isSupported)
            // Apple requires a restore affordance; it is also how a user
            // recovers premium on a reinstalled or new device.
            Center(
              child: TextButton(
                onPressed: _busy ? null : _restorePurchases,
                child: Text(l10n.billingRestore),
              ),
            )
          else
            Text(
              l10n.billingReturnHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          if (IapService.isSupported) ...[
            const SizedBox(height: MitlistSpacing.sm),
            Text(
              l10n.billingAutoRenewDisclosure,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: MitlistSpacing.xs),
            Wrap(
              alignment: WrapAlignment.center,
              children: [
                TextButton(
                  onPressed: () => _openLegalUrl(IapConfig.termsUrl),
                  child: Text(l10n.accountTermsTitle),
                ),
                TextButton(
                  onPressed: () => _openLegalUrl(IapConfig.privacyUrl),
                  child: Text(l10n.authSignupPrivacyPolicy),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// A one-page answer on the board, with a close button where the step bar
/// would otherwise be. Used for the states that are not a sale.
class _SinglePanel extends StatelessWidget {
  const _SinglePanel({required this.onClose, required this.child});

  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Column(
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: Semantics(
            button: true,
            label: l10n.commonClose,
            child: InkWell(
              onTap: onClose,
              child: const SizedBox(
                width: 44,
                height: 44,
                child: Center(child: AppIcon(name: 'arrowLeft', size: 22)),
              ),
            ),
          ),
        ),
        Expanded(child: child),
      ],
    );
  }
}

/// Shown when this household is already covered — there is nothing to sell.
class _PremiumActivePanel extends StatelessWidget {
  const _PremiumActivePanel({required this.entitlement});

  final HouseholdEntitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final coveredBy = entitlement.coveredBy;

    return BoardPageSheet(
      eyebrow: l10n.premiumPlanEyebrow,
      headline: l10n.billingPremiumActive,
      body: coveredBy != null && coveredBy.isNotEmpty
          ? l10n.billingCoveredBy(coveredBy)
          : l10n.billingUnlimitedMembers,
      child: Row(
        children: [
          AppIcon(name: 'star', color: theme.colorScheme.primary),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(
            child: Text(
              l10n.billingUnlimitedMembers,
              style: theme.textTheme.titleSmall,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shown when the caller already pays, for a different household.
class _MovePanel extends StatelessWidget {
  const _MovePanel({
    required this.error,
    required this.busy,
    required this.onMove,
  });

  final String? error;
  final bool busy;
  final VoidCallback onMove;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return BoardPageSheet(
      eyebrow: l10n.premiumPlanEyebrow,
      headline: l10n.billingMoveHereTitle,
      body: l10n.billingMoveHereBody,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (error != null) ...[
            AppAlert(type: AppAlertType.error, message: error!),
            const SizedBox(height: MitlistSpacing.md),
          ],
          AppButton(
            text: l10n.billingMoveHereAction,
            variant: AppButtonVariant.solid,
            color: AppButtonColor.primary,
            size: AppButtonSize.lg,
            isLoading: busy,
            onPressed: busy ? null : onMove,
          ),
        ],
      ),
    );
  }
}

/// Monthly / yearly toggle. Yearly leads because it is the better deal for the
/// customer and loses far less of each payment to processing fees.
class _IntervalSelector extends StatelessWidget {
  const _IntervalSelector({
    required this.selected,
    required this.enabled,
    required this.onChanged,
    this.yearlyPrice,
    this.monthlyPrice,
  });

  final BillingInterval selected;
  final bool enabled;
  final ValueChanged<BillingInterval> onChanged;

  /// Preformatted prices, or null when the provider reported none.
  final String? yearlyPrice;
  final String? monthlyPrice;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    // The page scrolls, so the row has no height to stretch into on its own:
    // IntrinsicHeight is what lets the shorter tile match the taller one.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _IntervalTile(
              label: l10n.billingYearly,
              price: yearlyPrice,
              badge: l10n.billingYearlyBadge,
              isSelected: selected == BillingInterval.yearly,
              enabled: enabled,
              onTap: () => onChanged(BillingInterval.yearly),
            ),
          ),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(
            child: _IntervalTile(
              label: l10n.billingMonthly,
              price: monthlyPrice,
              isSelected: selected == BillingInterval.monthly,
              enabled: enabled,
              onTap: () => onChanged(BillingInterval.monthly),
            ),
          ),
        ],
      ),
    );
  }
}

class _IntervalTile extends StatelessWidget {
  const _IntervalTile({
    required this.label,
    required this.isSelected,
    required this.enabled,
    required this.onTap,
    this.price,
    this.badge,
  });

  final String label;

  /// Preformatted price. Absent when the provider could not be reached; the
  /// tile then shows only the interval, never a guessed or stale amount.
  final String? price;
  final String? badge;
  final bool isSelected;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;

    return Semantics(
      selected: isSelected,
      button: true,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: MitlistSpacing.md,
            horizontal: MitlistSpacing.sm,
          ),
          decoration: BoxDecoration(
            border: Border.all(
              color: isSelected ? scheme.primary : scheme.outlineVariant,
              width: isSelected ? 2 : 1,
            ),
            color: isSelected ? scheme.primaryContainer : null,
          ),
          child: Column(
            children: [
              Text(label, style: theme.textTheme.titleSmall),
              if (price != null) ...[
                const SizedBox(height: MitlistSpacing.xs),
                Text(
                  price!,
                  style: theme.textTheme.titleMedium
                      ?.copyWith(color: scheme.onSurface),
                ),
              ],
              if (badge != null) ...[
                const SizedBox(height: MitlistSpacing.xs),
                Text(
                  badge!,
                  style: theme.textTheme.labelSmall
                      ?.copyWith(color: scheme.primary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
