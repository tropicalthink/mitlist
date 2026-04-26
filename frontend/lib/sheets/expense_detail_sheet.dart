import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';

import '../models/expense_receipt_models.dart';
import '../providers/attachment_provider.dart';
import '../providers/finance_provider.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
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
  });

  final String groupId;
  final String expenseId;
  final String description;
  final String amountLabel;
  final String payer;
  final DateTime createdAt;

  static Future<void> show(
    BuildContext context, {
    required String groupId,
    required String expenseId,
    required String description,
    required String amountLabel,
    required String payer,
    required DateTime createdAt,
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

  @override
  void initState() {
    super.initState();
    _loadReceipts();
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
      } catch (_) {}

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
        AppCard(
          variant: AppCardVariant.outlined,
          padding: AppCardPadding.md,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _HistoryRow(label: 'Paid by', value: widget.payer),
              const SizedBox(height: MitlistSpacing.sm),
              _HistoryRow(
                label: 'Created',
                value: DateFormat.yMMMd().format(widget.createdAt),
              ),
            ],
          ),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Row(
          children: [
            Expanded(
              child: Text(
                'Receipts',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            TextButton(
              onPressed: _uploading ? null : _addReceiptFromGallery,
              child: Text(_uploading ? 'Uploading…' : 'Add'),
            ),
          ],
        ),
        if (_error != null) ...[
          Text(_error!, style: Theme.of(context).textTheme.bodySmall),
          const SizedBox(height: MitlistSpacing.sm),
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
                );
              },
              separatorBuilder: (_, __) => const SizedBox(width: MitlistSpacing.sm),
              itemCount: _receipts.length,
            ),
          ),
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
