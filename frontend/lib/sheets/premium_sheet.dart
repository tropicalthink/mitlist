import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../l10n/app_localizations.dart';
import '../models/billing_models.dart';
import '../providers/billing_provider.dart';
import '../services/iap_service.dart';
import '../config/iap_config.dart';
import '../theme/spacing.dart';
import '../widgets/alert.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icon.dart';

import '../widgets/app_toast.dart';

/// Opens the premium sheet for [groupId].
///
/// It renders one of three states, decided by the household's entitlement:
///
///  * already premium — nothing to sell, just show who covers it;
///  * the caller pays but for a *different* household — offer to move their
///    premium here rather than sell them a second subscription;
///  * nobody pays — offer checkout.
///
/// Checkout itself happens in the browser on the provider's hosted page, so
/// this sheet hands off and the webhook activates premium a moment later.
Future<void> showPremiumSheet(
  BuildContext context,
  WidgetRef ref, {
  required String groupId,
}) {
  final l10n = AppLocalizations.of(context)!;

  return showAppBottomSheet<void>(
    context: context,
    title: l10n.billingPremiumTitle,
    body: _PremiumSheetBody(groupId: groupId),
  );
}

class _PremiumSheetBody extends ConsumerStatefulWidget {
  const _PremiumSheetBody({required this.groupId});

  final String groupId;

  @override
  ConsumerState<_PremiumSheetBody> createState() => _PremiumSheetBodyState();
}

class _PremiumSheetBodyState extends ConsumerState<_PremiumSheetBody> {
  BillingInterval _interval = BillingInterval.yearly;
  bool _busy = false;
  String? _error;

  /// The native IAP service and its purchase-result subscription, used only on
  /// iOS and Android. Null on web/desktop, which keep the Polar hosted checkout.
  IapService? _iap;
  StreamSubscription<IapResult>? _iapSub;

  @override
  void initState() {
    super.initState();
    // Preload store products so the selector can show the store's own localized
    // price (which already includes the +€2 annual uplift).
    if (IapService.isSupported) {
      _loadStoreProducts();
    }
  }

  @override
  void dispose() {
    _iapSub?.cancel();
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

  /// Entry point for the subscribe button: native IAP on mobile, Polar checkout
  /// in a browser everywhere else.
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

  /// Runs the native store purchase. The store confirms payment asynchronously,
  /// so this subscribes to the result stream: only a verified success (the
  /// backend validated the receipt) activates premium and closes the sheet.
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

  /// Formats the price for an interval. On mobile the store is the source of
  /// truth — its localized string already includes the +€2 annual uplift — so
  /// the Polar [plan] is used only on web/desktop. Null renders a tile with no
  /// price rather than a wrong one.
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final entitlementAsync =
        ref.watch(householdEntitlementProvider(widget.groupId));

    return entitlementAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: MitlistSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => AppAlert(
        type: AppAlertType.error,
        message: l10n.commonSomethingWentWrong,
      ),
      data: (entitlement) {
        if (entitlement == null) {
          // Billing is not configured on this server — nothing to show.
          return const SizedBox.shrink();
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _UsageCard(entitlement: entitlement),
            const SizedBox(height: MitlistSpacing.md),
            if (_error != null) ...[
              AppAlert(type: AppAlertType.error, message: _error!),
              const SizedBox(height: MitlistSpacing.md),
            ],
            if (entitlement.premium)
              _PremiumActiveBody(entitlement: entitlement)
            else if (entitlement.canMovePremiumHere)
              ..._buildMoveBody(l10n, theme)
            else
              ..._buildCheckoutBody(l10n, theme),
          ],
        );
      },
    );
  }

  List<Widget> _buildMoveBody(AppLocalizations l10n, ThemeData theme) {
    return [
      Text(l10n.billingMoveHereTitle, style: theme.textTheme.titleMedium),
      const SizedBox(height: MitlistSpacing.xs),
      Text(
        l10n.billingMoveHereBody,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: MitlistSpacing.lg),
      AppButton(
        text: l10n.billingMoveHereAction,
        variant: AppButtonVariant.solid,
        color: AppButtonColor.primary,
        isLoading: _busy,
        onPressed: _busy ? null : _movePremiumHere,
      ),
    ];
  }

  List<Widget> _buildCheckoutBody(AppLocalizations l10n, ThemeData theme) {
    // Prices come from the provider's catalog via /billing/status. When it is
    // unreachable the selector simply renders without them.
    final status = ref.watch(billingStatusProvider).valueOrNull;

    return [
      Text(
        l10n.billingCoversOneHousehold,
        style: theme.textTheme.bodySmall
            ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
      ),
      const SizedBox(height: MitlistSpacing.md),
      _IntervalSelector(
        selected: _interval,
        enabled: !_busy,
        yearlyPrice: _priceLabel(
            BillingInterval.yearly, status?.planFor(BillingInterval.yearly)),
        monthlyPrice: _priceLabel(
            BillingInterval.monthly, status?.planFor(BillingInterval.monthly)),
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
        isLoading: _busy,
        onPressed: _busy ? null : _startCheckout,
      ),
      const SizedBox(height: MitlistSpacing.sm),
      if (IapService.isSupported)
        // Apple requires a restore affordance; it is also how a user recovers
        // premium on a reinstalled or new device.
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
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
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
    ];
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
}

/// Header card: how many of the free places are used, and why it matters.
class _UsageCard extends StatelessWidget {
  const _UsageCard({required this.entitlement});

  final HouseholdEntitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final atLimit = !entitlement.canAddMember;

    return AppCard(
      variant: AppCardVariant.filled,
      padding: AppCardPadding.md,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AppIcon(
                name: entitlement.premium ? 'star' : 'userGroup',
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: Text(
                  entitlement.premium
                      ? l10n.billingUnlimitedMembers
                      : l10n.billingMemberUsage(
                          entitlement.memberCount,
                          entitlement.freeLimit,
                        ),
                  style: theme.textTheme.titleSmall,
                ),
              ),
            ],
          ),
          if (atLimit) ...[
            const SizedBox(height: MitlistSpacing.sm),
            Text(
              l10n.billingLimitReachedTitle,
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: MitlistSpacing.xs),
            Text(
              l10n.billingLimitReachedBody(
                entitlement.freeLimit,
                entitlement.freeLimit + 1,
              ),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shown when this household is already covered — there is nothing to sell.
class _PremiumActiveBody extends StatelessWidget {
  const _PremiumActiveBody({required this.entitlement});

  final HouseholdEntitlement entitlement;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final coveredBy = entitlement.coveredBy;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.billingPremiumActive, style: theme.textTheme.titleMedium),
        if (coveredBy != null && coveredBy.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.xs),
          Text(
            l10n.billingCoveredBy(coveredBy),
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
        ],
      ],
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

    return Row(
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
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(
            vertical: MitlistSpacing.md,
            horizontal: MitlistSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
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
