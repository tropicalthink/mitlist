import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/expense_receipt_models.dart';
import '../models/finance_models.dart';
import '../providers/attachment_provider.dart';
import '../providers/finance_provider.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../utils/format_currency.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/app_divider.dart';
import '../widgets/app_icon.dart';

class ExpenseDetailSheet extends ConsumerStatefulWidget {
  const ExpenseDetailSheet({
    super.key,
    required this.groupId,
    required this.expenseId,
    required this.description,
    required this.amountLabel,
    required this.payer,
    required this.createdAt,
    this.onDelete,
    this.currency = 'USD',
    this.userLabels = const {},
  });

  final String groupId;
  final String expenseId;
  final String description;
  final String amountLabel;
  final String payer;
  final DateTime createdAt;
  final VoidCallback? onDelete;
  final String currency;
  final Map<String, String> userLabels;

  static Future<void> show(
    BuildContext context, {
    required String groupId,
    required String expenseId,
    required String description,
    required String amountLabel,
    required String payer,
    required DateTime createdAt,
    VoidCallback? onDelete,
    String currency = 'USD',
    Map<String, String> userLabels = const {},
  }) async {
    return showAppBottomSheet(
      context: context,
      title: 'Expense details',
      body: ExpenseDetailSheet(
        groupId: groupId,
        expenseId: expenseId,
        description: description,
        amountLabel: amountLabel,
        payer: payer,
        createdAt: createdAt,
        onDelete: onDelete,
        currency: currency,
        userLabels: userLabels,
      ),
    );
  }

  @override
  ConsumerState<ExpenseDetailSheet> createState() => _ExpenseDetailSheetState();
}

class _ExpenseDetailSheetState extends ConsumerState<ExpenseDetailSheet> {
  bool _loadingReceipts = true;
  bool _removing = false;
  List<ExpenseReceipt> _receipts = const [];
  List<Split> _splits = const [];
  bool _loadingSplits = true;

  @override
  void initState() {
    super.initState();
    _loadReceipts();
    _loadSplits();
  }

  Future<void> _loadSplits() async {
    try {
      final finance = await ref.read(financeServiceProviderAsync.future);
      final splits = await finance.listExpenseSplits(widget.expenseId);
      if (!mounted) return;
      setState(() {
        _splits = splits;
        _loadingSplits = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _loadingSplits = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Couldn't load splits.")),
        );
      }
    }
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _loadingReceipts = true;
    });
    try {
      final finance = await ref.read(financeServiceProviderAsync.future);
      final receipts = await finance.listExpenseReceipts(
        groupId: widget.groupId,
        expenseId: widget.expenseId,
      );
      if (!mounted) return;
      setState(() {
        _receipts = receipts;
        _loadingReceipts = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadingReceipts = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't load receipts.")),
      );
    }
  }

  Future<void> _openReceiptViewer(ExpenseReceipt receipt) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  receipt.url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => Padding(
                    padding: const EdgeInsets.all(MitlistSpacing.lg),
                    child: Text(
                      'Failed to load receipt',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Align(
                alignment: Alignment.topLeft,
                child: IconButton(
                  tooltip: 'Close',
                  onPressed: () => Navigator.of(context).pop(),
                  icon: AppIcon(name: 'xMark', color: Theme.of(context).colorScheme.onSurface),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _removeReceipt(ExpenseReceipt receipt) async {
    if (_removing) return;
    setState(() {
      _removing = true;
    });

    try {
      final finance = await ref.read(financeServiceProviderAsync.future);
      await finance.detachExpenseReceipt(
        groupId: widget.groupId,
        expenseId: widget.expenseId,
        attachmentId: receipt.attachmentId,
      );

      // Best-effort: also delete the underlying attachment to avoid orphans.
      try {
        final attSvc = await ref.read(attachmentServiceProviderAsync.future);
        await attSvc.deleteAttachment(
          groupId: widget.groupId,
          attachmentId: receipt.attachmentId,
        );
      } catch (_) {
        // Best-effort attachment cleanup; silently ignore failures.
      }

      if (!mounted) return;
      setState(() => _removing = false);
      await _loadReceipts();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _removing = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Couldn't remove receipt.")),
      );
    }
  }

  Future<void> _showReceiptActions(ExpenseReceipt receipt) async {
    if (!mounted) return;
    final action = await showAppBottomSheet<String>(
      context: context,
      title: 'Receipt',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: const AppIcon(name: 'openInFull'),
            title: const Text('View'),
            onTap: () => Navigator.of(context).pop('view'),
          ),
          ListTile(
            leading: const AppIcon(name: 'minusCircleOutline'),
            title: Text(_removing ? 'Removing…' : 'Remove'),
            onTap: _removing ? null : () => Navigator.of(context).pop('remove'),
          ),
          const SizedBox(height: MitlistSpacing.sm),
        ],
      ),
    );

    if (action == 'view') {
      await _openReceiptViewer(receipt);
    } else if (action == 'remove') {
      await _removeReceipt(receipt);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          widget.description,
          style: textTheme.headlineSmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Text(
          widget.amountLabel,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: MitlistTypography.monoBody(color: Theme.of(context).colorScheme.onSurface),
        ),
        const SizedBox(height: MitlistSpacing.md),
        if (!_loadingSplits && _splits.isNotEmpty) ...[
          Text('Splits', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: MitlistSpacing.sm),
          AppCard(
            variant: AppCardVariant.outlined,
            padding: AppCardPadding.md,
            child: Column(
              children: [
                for (var i = 0; i < _splits.length; i++) ...[
                  if (i > 0) const AppDivider(),
                  _SplitRow(split: _splits[i], currency: widget.currency, userLabels: widget.userLabels),
                ],
              ],
            ),
          ),
          const SizedBox(height: MitlistSpacing.md),
        ],
        if (!_loadingSplits && _splits.isEmpty)
          Text('No splits yet.', style: Theme.of(context).textTheme.bodySmall,),
        if (_loadingReceipts)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
            child: LinearProgressIndicator(),
          )
        else if (_receipts.isEmpty)
          Text(
            'No receipts yet.',
            style: Theme.of(context).textTheme.bodySmall,
          )
        else
          SizedBox(
            height: 84,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemBuilder: (context, i) {
                final r = _receipts[i];
                return GestureDetector(
                  onTap: () => _openReceiptViewer(r),
                  onLongPress: () => _showReceiptActions(r),
                  child: Semantics(
                    button: true,
                    label: 'View receipt',
                    child: ClipRRect(
                      borderRadius: BorderRadius.zero,
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              r.url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: Theme.of(context).colorScheme.surfaceContainerLow,
                                alignment: Alignment.center,
                                child: const AppIcon(name: 'receiptLongOutline'),
                              ),
                            ),
                            if (_removing)
                              const Align(
                                alignment: Alignment.bottomCenter,
                                child: LinearProgressIndicator(minHeight: 2),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: MitlistSpacing.sm),
              itemCount: _receipts.length,
            ),
          ),
        if (widget.onDelete != null) ...[
          const SizedBox(height: MitlistSpacing.lg),
          const AppDivider(),
          const SizedBox(height: MitlistSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              variant: AppButtonVariant.ghost,
              color: AppButtonColor.error,
              size: AppButtonSize.lg,
              text: 'Delete expense',
              onPressed: () async {
                final confirmed = await showAppDialog<bool>(
                  context: context,
                  title: 'Delete expense',
                  body: const Text('This will permanently delete this expense and its records.'),
                  actions: [
                    AppButton(
                      text: 'Cancel',
                      variant: AppButtonVariant.outline,
                      onPressed: () => Navigator.of(context).pop(false),
                    ),
                    AppButton(
                      text: 'Delete',
                      color: AppButtonColor.error,
                      onPressed: () => Navigator.of(context).pop(true),
                    ),
                  ],
                );
                if (confirmed == true && mounted) {
                  widget.onDelete?.call();
                }
              },
            ),
          ),
        ],
      ],
    );
  }
}

class _SplitRow extends StatelessWidget {
  const _SplitRow({required this.split, required this.currency, this.userLabels = const {}});

  final Split split;
  final String currency;
  final Map<String, String> userLabels;

  @override
  Widget build(BuildContext context) {
    final label = userLabels[split.userId] ?? split.userId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (split.isSettled)
            Padding(
              padding: const EdgeInsets.only(right: MitlistSpacing.sm),
              child: AppIcon(
                  name: 'checkCircle',
                  size: 16,
                  color: Theme.of(context).colorScheme.tertiary,
                ),
            ),
          Text(
            formatCurrency(split.amount, currency),
            style: MitlistTypography.monoBody(),
          ),
        ],
      ),
    );
  }
}
