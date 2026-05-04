import 'dart:typed_data';

import 'package:flutter/material.dart' hide Split;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../models/expense_receipt_models.dart';
import '../models/finance_models.dart';
import '../providers/attachment_provider.dart';
import '../providers/finance_provider.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';

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
  });

  final String groupId;
  final String expenseId;
  final String description;
  final String amountLabel;
  final String payer;
  final DateTime createdAt;
  final VoidCallback? onDelete;

  static Future<void> show(
    BuildContext context, {
    required String groupId,
    required String expenseId,
    required String description,
    required String amountLabel,
    required String payer,
    required DateTime createdAt,
    VoidCallback? onDelete,
  }) async {
    return showAppBottomSheet(
      context: context,
      title: 'Expense Details',
      body: ExpenseDetailSheet(
        groupId: groupId,
        expenseId: expenseId,
        description: description,
        amountLabel: amountLabel,
        payer: payer,
        createdAt: createdAt,
        onDelete: onDelete,
      ),
    );
  }

  @override
  ConsumerState<ExpenseDetailSheet> createState() => _ExpenseDetailSheetState();
}

class _ExpenseDetailSheetState extends ConsumerState<ExpenseDetailSheet> {
  bool _loadingReceipts = true;
  bool _uploading = false;
  bool _removing = false;
  String? _error;
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
      if (mounted) setState(() => _loadingSplits = false);
    }
  }

  Future<void> _loadReceipts() async {
    setState(() {
      _loadingReceipts = true;
      _error = null;
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
        _error = 'Failed to load receipts';
        _loadingReceipts = false;
      });
    }
  }

  Future<void> _addReceiptFromGallery() async {
    if (_uploading) return;
    setState(() {
      _uploading = true;
      _error = null;
    });

    try {
      final picker = ImagePicker();
      final file = await picker.pickImage(source: ImageSource.gallery);
      if (file == null) {
        if (!mounted) return;
        setState(() => _uploading = false);
        return;
      }

      final bytes = await file.readAsBytes();
      final attachmentRepo = await ref.read(attachmentRepositoryProvider.future);
      final attachment = await attachmentRepo.uploadAttachment(
        groupId: widget.groupId,
        purpose: 'expense_receipt',
        filename: file.name,
        contentType: 'image/*',
        bytes: Uint8List.fromList(bytes),
      );

      final finance = await ref.read(financeServiceProviderAsync.future);
      await finance.attachExpenseReceipt(
        groupId: widget.groupId,
        expenseId: widget.expenseId,
        attachmentId: attachment.id,
      );

      if (!mounted) return;
      setState(() => _uploading = false);
      await _loadReceipts();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Upload failed';
        _uploading = false;
      });
    }
  }

  Future<void> _openReceiptViewer(ExpenseReceipt receipt) async {
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => Dialog.fullscreen(
        backgroundColor: Colors.black,
        child: Stack(
          children: [
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4,
                child: Image.network(
                  receipt.url,
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'Failed to load receipt',
                      style: TextStyle(color: Colors.white),
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
                  icon: const Icon(Icons.close, color: Colors.white),
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
      _error = null;
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
        debugPrint('[ExpenseDetail] Attachment cleanup failed for ${receipt.attachmentId}');
      }

      if (!mounted) return;
      setState(() => _removing = false);
      await _loadReceipts();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to remove receipt';
        _removing = false;
      });
    }
  }

  Future<void> _showReceiptActions(ExpenseReceipt receipt) async {
    if (!mounted) return;
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_full),
              title: const Text('View'),
              onTap: () => Navigator.of(context).pop('view'),
            ),
            ListTile(
              leading: const Icon(Icons.remove_circle_outline),
              title: Text(_removing ? 'Removing…' : 'Remove'),
              onTap: _removing ? null : () => Navigator.of(context).pop('remove'),
            ),
            const SizedBox(height: 8),
          ],
        ),
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
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Text(
          widget.amountLabel,
          style: MitlistTypography.monoBody(color: MitlistColors.textPrimary),
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
                  if (i > 0) const Divider(),
                  _SplitRow(split: _splits[i]),
                ],
              ],
            ),
          ),
          const SizedBox(height: MitlistSpacing.md),
        ],
        if (_loadingReceipts)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
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
                      borderRadius: BorderRadius.circular(8),
                      child: AspectRatio(
                        aspectRatio: 1,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.network(
                              r.url,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => Container(
                                color: MitlistColors.neutral100,
                                alignment: Alignment.center,
                                child: const Icon(Icons.receipt_long_outlined),
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
          const Divider(),
          const SizedBox(height: MitlistSpacing.sm),
          SizedBox(
            width: double.infinity,
            child: AppButton(
              variant: AppButtonVariant.ghost,
              color: AppButtonColor.error,
              size: AppButtonSize.lg,
              text: 'Delete expense',
              onPressed: widget.onDelete,
            ),
          ),
        ],
      ],
    );
  }
}

class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ),
        Text(
          value,
          style: MitlistTypography.monoBody(color: MitlistColors.textSecondary),
        ),
      ],
    );
  }
}

class _SplitRow extends StatelessWidget {
  const _SplitRow({required this.split});

  final Split split;

  @override
  Widget build(BuildContext context) {
    final label = split.userId.length > 8
        ? split.userId.substring(0, 8)
        : split.userId;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyMedium),
          ),
          if (split.isSettled)
            Padding(
              padding: const EdgeInsets.only(right: MitlistSpacing.sm),
              child: Icon(Icons.check_circle,
                  size: 16, color: MitlistColors.success500),
            ),
          Text(
            '\$${(split.amount / 100).toStringAsFixed(2)}',
            style: MitlistTypography.monoBody(),
          ),
        ],
      ),
    );
  }
}
