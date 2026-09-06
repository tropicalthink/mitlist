import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/iap_config.dart';
import '../l10n/app_localizations.dart';
import '../models/billing_models.dart';
import '../providers/billing_provider.dart';
import '../services/iap_service.dart';
import '../theme/spacing.dart';
import '../widgets/alert.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_toast.dart';

/// Opens the supporter pack sheet: the one-time purchase that thanks the
/// buyer with a badge and accent colours, and helps pay for the servers.
Future<void> showSupporterSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showAppBottomSheet<void>(
    context: context,
    title: l10n.supporterTitle,
    body: const SupporterSheetBody(),
  );
}

/// The sheet's content. On mobile the purchase runs through the native store;
/// on web and desktop it hands off to the hosted checkout and the webhook
/// records the purchase a moment later — the same split premium uses.
class SupporterSheetBody extends ConsumerStatefulWidget {
  const SupporterSheetBody({super.key});

  @override
  ConsumerState<SupporterSheetBody> createState() => _SupporterSheetBodyState();
}

class _SupporterSheetBodyState extends ConsumerState<SupporterSheetBody> {
  bool _busy = false;
  String? _error;
  IapService? _iap;
  StreamSubscription<IapResult>? _iapSub;

  @override
  void initState() {
    super.initState();
    if (IapService.isSupported) _loadStoreProduct();
  }

  @override
  void dispose() {
    _iapSub?.cancel();
    super.dispose();
  }

  Future<void> _loadStoreProduct() async {
    try {
      final iap = await ref.read(iapServiceProvider.future);
      await iap.loadProducts();
      if (!mounted) return;
      setState(() => _iap = iap);
    } catch (_) {
      // The price is decoration; the button still works without it.
    }
  }

  Future<void> _buy() async {
    if (IapService.isSupported) {
      await _buyInStore();
    } else {
      await _buyOnWeb();
    }
  }

  Future<void> _buyOnWeb() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = await ref.read(billingServiceProvider.future);
      final url = await service.createSupporterCheckout();
      final launched = await launchUrl(
        Uri.parse(url),
        mode: LaunchMode.externalApplication,
      );
      if (!launched) throw Exception('launch failed');
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

  Future<void> _buyInStore() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final iap = await ref.read(iapServiceProvider.future);
      await _iapSub?.cancel();
      _iapSub = iap.results.listen(_onIapResult);
      await iap.buySupporter();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = l10n.billingCheckoutFailed;
      });
    }
  }

  Future<void> _restore() async {
    final l10n = AppLocalizations.of(context)!;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final iap = await ref.read(iapServiceProvider.future);
      await _iapSub?.cancel();
      _iapSub = iap.results.listen(_onIapResult);
      await iap.restore();
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
        final message = l10n.supporterPurchased;
        navigator.pop();
        if (mounted) AppToast.success(context, message);
    }
  }

  /// The price to show on the button: the store's own string on mobile, the
  /// provider's catalog price elsewhere. Null renders the button without one.
  String? _priceLabel(BillingStatus? status) {
    if (IapService.isSupported) return _iap?.supporterPriceLabel;
    final offer = status?.supporterOffer;
    if (offer == null) return null;
    final locale = Localizations.localeOf(context).toString();
    return NumberFormat.simpleCurrency(locale: locale, name: offer.currency)
        .format(offer.amountCents / 100);
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final status = ref.watch(billingStatusProvider).valueOrNull;
    final isSupporter = status?.supporter ?? false;
    final price = _priceLabel(status);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            AppIcon(
              name: 'heartSolid',
              size: 28,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(width: MitlistSpacing.sm),
            Expanded(
              child: Text(
                l10n.supporterSheetHeadline,
                style: theme.textTheme.titleLarge,
              ),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Text(
          isSupporter ? l10n.supporterCardActiveBody : l10n.supporterCardBody,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: MitlistSpacing.md),
        _PerkRow(icon: 'heartSolid', text: l10n.supporterPerkBadge),
        const SizedBox(height: MitlistSpacing.sm),
        _PerkRow(icon: 'palette', text: l10n.supporterPerkAccent),
        const SizedBox(height: MitlistSpacing.sm),
        _PerkRow(icon: 'server', text: l10n.supporterPerkHosting),
        const SizedBox(height: MitlistSpacing.lg),
        if (_error != null) ...[
          AppAlert(type: AppAlertType.error, message: _error!),
          const SizedBox(height: MitlistSpacing.md),
        ],
        if (!isSupporter) ...[
          AppButton(
            text: _busy
                ? (IapService.isSupported
                    ? l10n.billingProcessing
                    : l10n.billingOpeningCheckout)
                : (price == null
                    ? l10n.supporterBuy
                    : l10n.supporterBuyWithPrice(price)),
            variant: AppButtonVariant.solid,
            color: AppButtonColor.primary,
            size: AppButtonSize.lg,
            isLoading: _busy,
            onPressed: _busy ? null : _buy,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          Text(
            l10n.supporterOnce,
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
          ),
          if (IapService.isSupported) ...[
            Center(
              child: TextButton(
                onPressed: _busy ? null : _restore,
                child: Text(l10n.billingRestore),
              ),
            ),
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
          ] else ...[
            const SizedBox(height: MitlistSpacing.xs),
            Text(
              l10n.billingReturnHint,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
            ),
          ],
        ] else
          AppButton(
            text: l10n.commonClose,
            variant: AppButtonVariant.outline,
            size: AppButtonSize.lg,
            onPressed: () => Navigator.of(context).pop(),
          ),
      ],
    );
  }
}

class _PerkRow extends StatelessWidget {
  const _PerkRow({required this.icon, required this.text});

  final String icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppIcon(name: icon, size: 18, color: theme.colorScheme.primary),
        const SizedBox(width: MitlistSpacing.sm),
        Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
      ],
    );
  }
}
