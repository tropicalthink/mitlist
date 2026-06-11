import 'dart:async';

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../models/finance_models.dart';
import '../models/group_models.dart';
import '../providers/attachment_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/group_provider.dart';
import '../providers/scan_provider.dart';
import '../router.dart' show currentGroupIdProvider;
import '../theme/spacing.dart';
import '../utils/active_group_context.dart';
import '../utils/format_currency.dart';
import '../utils/haptics.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/animated_check_toggle.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_input.dart';
import '../utils/friendly_error.dart';
import '../widgets/chip.dart';
import '../widgets/skeleton.dart';

class ExpenseCreationSheet extends ConsumerStatefulWidget {
  final String? initialDescription;
  final String? initialAmount;
  final File? receiptImage;
  final ValueNotifier<bool>? dirtyNotifier;

  const ExpenseCreationSheet({
    super.key,
    this.initialDescription,
    this.initialAmount,
    this.receiptImage,
    this.dirtyNotifier,
  });

  static Future<bool?> show(
    BuildContext context, {
    String? initialDescription,
    String? initialAmount,
    File? receiptImage,
  }) async {
    final dirty = ValueNotifier<bool>(false);
    final future = showAppBottomSheet<bool>(
      context: context,
      title: 'Add expense',
      isDirtyListenable: dirty,
      body: ExpenseCreationSheet(
        initialDescription: initialDescription,
        initialAmount: initialAmount,
        receiptImage: receiptImage,
        dirtyNotifier: dirty,
      ),
    );
    unawaited(future.whenComplete(dirty.dispose));
    return future;
  }

  @override
  ConsumerState<ExpenseCreationSheet> createState() =>
      _ExpenseCreationSheetState();
}

class _ExpenseCreationSheetState extends ConsumerState<ExpenseCreationSheet> {
  final TextEditingController _descriptionController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();
  final Map<String, TextEditingController> _splitControllers = {};
  List<GroupMemberProfile> _members = [];
  final Set<String> _selectedMemberIds = {};
  String _splitMode = 'equal';
  String _currency = 'USD';
  DateTime _date = DateTime.now();
  File? _scannedReceipt;
  bool _membersLoading = true;
  bool _membersFailed = false;
  bool _isSaving = false;
  bool _isScanning = false;

  String? _descriptionError;
  String? _amountError;

  bool get _hasReceipt =>
      widget.receiptImage != null || _scannedReceipt != null;

  @override
  void initState() {
    super.initState();
    if (widget.initialDescription != null) {
      _descriptionController.text = widget.initialDescription!;
    }
    if (widget.initialAmount != null) {
      _amountController.text = widget.initialAmount!;
      _amountController.selection = TextSelection.fromPosition(
        TextPosition(offset: widget.initialAmount!.length),
      );
    }
    _loadGroupContext();
  }

  void _markDirty() => widget.dirtyNotifier?.value = true;

  /// Resolves the active household once, then loads its members and currency.
  /// A single `listGroups` round-trip backs both the split list and the
  /// currency shown on the amount field.
  Future<void> _loadGroupContext() async {
    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final groups = await groupService.listGroups(limit: 50);
      if (!mounted) return;
      if (groups.isEmpty) {
        setState(() => _membersLoading = false);
        return;
      }
      final groupId = resolveActiveGroupId(
        groups,
        ref.read(currentGroupIdProvider),
      );
      if (groupId == null) {
        setState(() => _membersLoading = false);
        return;
      }
      final group = await groupService.getGroup(groupId);
      final members = await groupService.listMembers(groupId);
      if (!mounted) return;
      setState(() {
        _currency = group.currency;
        _members = members;
        _membersLoading = false;
        _membersFailed = false;
        _selectedMemberIds
          ..clear()
          ..addAll(members.map((m) => m.userId));
        for (final member in members) {
          _splitControllers.putIfAbsent(
            member.userId,
            () => TextEditingController(text: '1'),
          );
        }
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _membersLoading = false;
        _membersFailed = true;
      });
    }
  }

  void _retryLoad() {
    setState(() {
      _membersLoading = true;
      _membersFailed = false;
    });
    _loadGroupContext();
  }

  Future<void> _onScan() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.camera,
      maxWidth: 2048,
      maxHeight: 2048,
    );
    if (picked == null || !mounted) return;

    setState(() => _isScanning = true);
    _markDirty();

    try {
      final service = await ref.read(scanServiceProviderAsync.future);
      final bytes = await File(picked.path).readAsBytes();
      final result = await service.scanImage(bytes, 'image/jpeg');

      if (!mounted) return;

      if (result.title != null && result.title!.isNotEmpty) {
        _descriptionController.text = result.title!;
      }
      if (result.amount != null && result.amount! > 0) {
        _amountController.text = (result.amount! / 100).toStringAsFixed(2);
        _amountError = null;
      }
      if (result.items.isNotEmpty && _descriptionController.text.isEmpty) {
        _descriptionController.text =
            result.items.map((i) => i.name).join(', ');
      }

      setState(() {
        // Keep the scanned image so it is attached to the expense, not just
        // read for OCR.
        _scannedReceipt = File(picked.path);
        _isScanning = false;
      });
    } catch (e) {
      if (!mounted) return;
      // The photo is still usable as a receipt even if OCR failed.
      setState(() {
        _scannedReceipt = File(picked.path);
        _isScanning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 2),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
    _markDirty();
  }

  bool get _canCreate =>
      _descriptionController.text.trim().isNotEmpty &&
      _amountController.text.trim().isNotEmpty &&
      !_isSaving;

  Future<void> _onCreate() async {
    if (!_canCreate) return;

    final amount = _parseAmountToCents(_amountController.text);
    if (amount == null) {
      setState(() => _amountError = 'Enter a valid amount greater than zero.');
      return;
    }

    final summary = computeSplitSummary(
      mode: _splitMode,
      selectedIds: _selectedMemberIds,
      controllers: _splitControllers,
      totalCents: amount,
      currency: _currency,
    );
    if (!summary.isValid) {
      // The live split summary already shows the reason in red; just block.
      unawaited(Haptics.medium());
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final financeService = await ref.read(financeServiceProviderAsync.future);
      final groups = await groupService.listGroups(limit: 50);

      if (!mounted) return;
      final groupId = resolveActiveGroupId(
        groups,
        ref.read(currentGroupIdProvider),
      );
      if (groupId == null) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Create or join a household first.')),
        );
        return;
      }

      final me = await authService.getMe();
      final splitUserIds = _selectedMemberIds.toList();
      final splitRequests = _buildSplitRequests();
      final expense = await financeService.createExpense(
        CreateExpenseRequest(
          groupId: groupId,
          payerId: me.id,
          amount: amount,
          description: _descriptionController.text.trim(),
          notes: _notesController.text.trim(),
          currency: _currency,
          date: _date.toUtc(),
          splitMode: _splitMode,
          splitUserIds: _splitMode == 'equal' ? splitUserIds : const [],
          splits: _splitMode == 'equal' ? const [] : splitRequests,
        ),
      );

      final receipt = widget.receiptImage ?? _scannedReceipt;
      if (receipt != null) {
        try {
          final bytes = await receipt.readAsBytes();
          final attachmentRepo =
              await ref.read(attachmentRepositoryProvider.future);
          final attachment = await attachmentRepo.uploadAttachment(
            groupId: groupId,
            purpose: 'expense_receipt',
            filename: receipt.path.split('/').last,
            contentType: 'image/jpeg',
            bytes: Uint8List.fromList(bytes),
          );
          await financeService.attachExpenseReceipt(
            groupId: groupId,
            expenseId: expense.id,
            attachmentId: attachment.id,
          );
        } catch (e) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Expense saved, but receipt upload failed.'),
              ),
            );
          }
        }
      }

      if (!mounted) return;
      widget.dirtyNotifier?.value = false;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense added')),
      );
      unawaited(Haptics.success());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(friendlyErrorMessage(e))),
      );
    }
  }

  int? _parseAmountToCents(String value) {
    final normalized = value.replaceAll(',', '.').trim();
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed <= 0) {
      return null;
    }
    if (parsed > 9999999) {
      return null; // Reject unrealistically large values.
    }
    return (parsed * 100).round();
  }

  List<CreateExpenseSplitRequest> _buildSplitRequests() {
    return _selectedMemberIds.map((userId) {
      final raw = _splitControllers[userId]?.text.trim() ?? '';
      switch (_splitMode) {
        case 'amount':
          return CreateExpenseSplitRequest(
            userId: userId,
            amount: _parseAmountToCents(raw) ?? 0,
          );
        case 'percentage':
          final value = double.tryParse(raw.replaceAll(',', '.')) ?? 0;
          return CreateExpenseSplitRequest(
            userId: userId,
            percentage: (value * 100).round(),
          );
        case 'shares':
          return CreateExpenseSplitRequest(
            userId: userId,
            shares: int.tryParse(raw) ?? 0,
          );
        default:
          return CreateExpenseSplitRequest(userId: userId);
      }
    }).toList();
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    _amountController.dispose();
    _notesController.dispose();
    for (final controller in _splitControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalCents = _parseAmountToCents(_amountController.text);

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppButton(
          text: _isScanning ? 'Scanning…' : 'Scan receipt',
          icon: AppIcon(
            name: _isScanning ? 'hourglassEmpty' : 'documentScanner',
            size: 20,
          ),
          variant: AppButtonVariant.outline,
          color: AppButtonColor.neutral,
          onPressed: _isScanning ? null : _onScan,
          semanticLabel: 'Scan receipt via camera',
        ),
        if (_hasReceipt) ...[
          const SizedBox(height: MitlistSpacing.sm),
          _ReceiptAttachedRow(),
        ],
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          label: 'Description',
          hint: 'e.g. Dinner at Luigi\'s',
          controller: _descriptionController,
          textInputAction: TextInputAction.next,
          maxLength: 200,
          errorText: _descriptionError,
          onChanged: (_) {
            _markDirty();
            setState(() => _descriptionError = null);
          },
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          label: 'Amount ($_currency)',
          hint: '0.00',
          controller: _amountController,
          textInputAction: TextInputAction.done,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          prefixIcon: _CurrencyPrefix(currency: _currency),
          errorText: _amountError,
          onChanged: (_) {
            _markDirty();
            setState(() => _amountError = null);
          },
        ),
        const SizedBox(height: MitlistSpacing.md),
        _DateField(date: _date, onTap: _pickDate),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          label: 'Notes',
          hint: 'Optional context, receipt note, or reimbursement detail',
          controller: _notesController,
          textInputAction: TextInputAction.newline,
          keyboardType: TextInputType.multiline,
          minLines: 1,
          maxLines: 4,
          onChanged: (_) => _markDirty(),
        ),
        const SizedBox(height: MitlistSpacing.lg),
        Divider(
          height: 1,
          thickness: 1,
          color: Theme.of(context).colorScheme.outlineVariant,
        ),
        const SizedBox(height: MitlistSpacing.lg),
        _SplitOptions(
          members: _members,
          loading: _membersLoading,
          failed: _membersFailed,
          selectedMemberIds: _selectedMemberIds,
          splitMode: _splitMode,
          controllers: _splitControllers,
          totalCents: totalCents,
          currency: _currency,
          onRetry: _retryLoad,
          onModeChanged: (mode) {
            setState(() => _splitMode = mode);
            _markDirty();
          },
          onMemberChanged: (memberId, selected) {
            setState(() {
              if (selected) {
                _selectedMemberIds.add(memberId);
              } else {
                _selectedMemberIds.remove(memberId);
              }
            });
            _markDirty();
          },
          onValueChanged: () {
            setState(() {});
            _markDirty();
          },
        ),
        const SizedBox(height: MitlistSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            variant: AppButtonVariant.solid,
            color: AppButtonColor.primary,
            size: AppButtonSize.lg,
            text: _isSaving ? 'Adding…' : 'Add expense',
            isLoading: _isSaving,
            onPressed: _canCreate ? _onCreate : null,
          ),
        ),
      ],
    );
  }
}

/// Result of reconciling the split inputs against the expense total.
class SplitSummary {
  final String text;
  final bool isValid;

  const SplitSummary(this.text, this.isValid);
}

/// Computes a human-readable, live breakdown of how the expense divides, plus
/// whether the split is internally consistent (sums to the total / to 100%).
SplitSummary computeSplitSummary({
  required String mode,
  required Set<String> selectedIds,
  required Map<String, TextEditingController> controllers,
  required int? totalCents,
  required String currency,
}) {
  final n = selectedIds.length;
  if (n == 0) {
    return const SplitSummary('Select at least one person to split with.', false);
  }
  if (totalCents == null) {
    return const SplitSummary(
      'Enter an amount above to preview each share.',
      false,
    );
  }

  double parseValue(String userId) =>
      double.tryParse((controllers[userId]?.text ?? '').replaceAll(',', '.')) ??
      0;

  switch (mode) {
    case 'amount':
      var assignedCents = 0;
      var negative = false;
      for (final id in selectedIds) {
        final v = parseValue(id);
        if (v < 0) negative = true;
        assignedCents += (v * 100).round();
      }
      final remaining = totalCents - assignedCents;
      final assignedLabel =
          '${formatCurrency(assignedCents, currency)} of ${formatCurrency(totalCents, currency)}';
      if (negative) {
        return SplitSummary('$assignedLabel · amounts can\'t be negative', false);
      }
      if (remaining > 0) {
        return SplitSummary(
          '$assignedLabel · ${formatCurrency(remaining, currency)} left to assign',
          false,
        );
      }
      if (remaining < 0) {
        return SplitSummary(
          '$assignedLabel · ${formatCurrency(-remaining, currency)} over',
          false,
        );
      }
      return SplitSummary(assignedLabel, true);

    case 'percentage':
      double sum = 0;
      var outOfRange = false;
      for (final id in selectedIds) {
        final v = parseValue(id);
        if (v < 0 || v > 100) outOfRange = true;
        sum += v;
      }
      final sumLabel = sum % 1 == 0
          ? sum.toStringAsFixed(0)
          : sum.toStringAsFixed(1);
      if (outOfRange) {
        return SplitSummary(
          '$sumLabel% assigned · each share must be 0–100%',
          false,
        );
      }
      final balanced = (sum - 100).abs() < 0.05;
      return SplitSummary('$sumLabel% of 100%', balanced);

    case 'shares':
      var totalShares = 0;
      var negative = false;
      for (final id in selectedIds) {
        final v = int.tryParse((controllers[id]?.text ?? '').trim()) ?? 0;
        if (v < 0) negative = true;
        totalShares += v;
      }
      if (negative) {
        return const SplitSummary('Shares can\'t be negative.', false);
      }
      if (totalShares <= 0) {
        return const SplitSummary('Assign at least one share.', false);
      }
      final perShare = (totalCents / totalShares).round();
      return SplitSummary(
        '$totalShares shares · ${formatCurrency(perShare, currency)} per share',
        true,
      );

    default: // equal
      final perPerson = totalCents ~/ n;
      final remainder = totalCents - perPerson * n;
      final each = '${formatCurrency(perPerson, currency)} each';
      return SplitSummary(remainder == 0 ? each : '≈ $each', true);
  }
}

class _SplitOptions extends StatelessWidget {
  final List<GroupMemberProfile> members;
  final bool loading;
  final bool failed;
  final Set<String> selectedMemberIds;
  final String splitMode;
  final Map<String, TextEditingController> controllers;
  final int? totalCents;
  final String currency;
  final VoidCallback onRetry;
  final ValueChanged<String> onModeChanged;
  final void Function(String memberId, bool selected) onMemberChanged;
  final VoidCallback onValueChanged;

  const _SplitOptions({
    required this.members,
    required this.loading,
    required this.failed,
    required this.selectedMemberIds,
    required this.splitMode,
    required this.controllers,
    required this.totalCents,
    required this.currency,
    required this.onRetry,
    required this.onModeChanged,
    required this.onMemberChanged,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Split with', style: textTheme.labelMedium),
          const SizedBox(height: MitlistSpacing.md),
          for (var i = 0; i < 3; i++)
            const Padding(
              padding: EdgeInsets.only(bottom: MitlistSpacing.sm),
              child: _SplitRowSkeleton(),
            ),
        ],
      );
    }

    if (failed) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Couldn\'t load household members.',
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          AppButton(
            text: 'Retry',
            variant: AppButtonVariant.outline,
            color: AppButtonColor.neutral,
            size: AppButtonSize.sm,
            onPressed: onRetry,
          ),
        ],
      );
    }

    if (members.isEmpty) {
      return Text(
        'Join or create a household to split this expense.',
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    final summary = computeSplitSummary(
      mode: splitMode,
      selectedIds: selectedMemberIds,
      controllers: controllers,
      totalCents: totalCents,
      currency: currency,
    );
    final summaryColor = totalCents == null
        ? colorScheme.onSurfaceVariant
        : summary.isValid
            ? colorScheme.tertiary
            : colorScheme.error;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Split mode', style: textTheme.labelMedium),
        const SizedBox(height: MitlistSpacing.sm),
        Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
          children: [
            AppChip(
              label: 'Equal',
              selected: splitMode == 'equal',
              onSelected: (_) => onModeChanged('equal'),
            ),
            AppChip(
              label: 'Exact',
              selected: splitMode == 'amount',
              onSelected: (_) => onModeChanged('amount'),
            ),
            AppChip(
              label: 'Shares',
              selected: splitMode == 'shares',
              onSelected: (_) => onModeChanged('shares'),
            ),
            AppChip(
              label: 'Percent',
              selected: splitMode == 'percentage',
              onSelected: (_) => onModeChanged('percentage'),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Text(
          _modeHint(splitMode),
          style: textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: MitlistSpacing.md),
        if (splitMode != 'equal')
          Padding(
            padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
            child: Row(
              children: [
                const Spacer(),
                SizedBox(
                  width: 96,
                  child: Text(
                    _valueLabel(splitMode).toUpperCase(),
                    textAlign: TextAlign.end,
                    style: textTheme.labelMedium?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ...members.map((member) {
          final selected = selectedMemberIds.contains(member.userId);
          return Padding(
            padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
            child: Row(
              children: [
                AnimatedCheckToggle(
                  value: selected,
                  onChanged: (value) => onMemberChanged(member.userId, value),
                  semanticLabelOn: 'Remove ${member.displayName} from split',
                  semanticLabelOff: 'Add ${member.displayName} to split',
                ),
                Expanded(
                  child: Text(
                    member.displayName,
                    style: textTheme.bodyMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (splitMode != 'equal') ...[
                  const SizedBox(width: MitlistSpacing.sm),
                  SizedBox(
                    width: 96,
                    child: Semantics(
                      label: '${member.displayName} ${_valueLabel(splitMode)}',
                      child: AppInput(
                        hint: splitMode == 'percentage' ? '50' : '1',
                        controller: controllers[member.userId],
                        enabled: selected,
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        onChanged: (_) => onValueChanged(),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
        const SizedBox(height: MitlistSpacing.sm),
        Row(
          children: [
            AppIcon(
              name: summary.isValid ? 'checkCircle' : 'alertCircleOutline',
              size: 16,
              color: summaryColor,
            ),
            const SizedBox(width: MitlistSpacing.xs),
            Expanded(
              child: Text(
                summary.text,
                style: textTheme.bodySmall?.copyWith(
                  color: summaryColor,
                  fontWeight: summary.isValid ? null : FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _modeHint(String mode) => switch (mode) {
        'amount' => 'Enter the exact amount each person owes.',
        'percentage' => 'Enter each person\'s share; must total 100%.',
        'shares' => 'Split by shares, e.g. 2 shares pays double.',
        _ => 'Split the total evenly among selected members.',
      };

  String _valueLabel(String mode) => switch (mode) {
        'amount' => 'Amount',
        'percentage' => '%',
        _ => 'Shares',
      };
}

class _CurrencyPrefix extends StatelessWidget {
  final String currency;

  const _CurrencyPrefix({required this.currency});

  @override
  Widget build(BuildContext context) {
    return Center(
      widthFactor: 1,
      child: FittedBox(
        fit: BoxFit.scaleDown,
        child: Text(
          currencySymbol(currency).trim(),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
        ),
      ),
    );
  }
}

class _DateField extends StatelessWidget {
  final DateTime date;
  final VoidCallback onTap;

  const _DateField({required this.date, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final label = MaterialLocalizations.of(context).formatMediumDate(date);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'DATE',
          style: textTheme.labelMedium,
        ),
        const SizedBox(height: MitlistSpacing.sm),
        AppButton(
          text: label,
          icon: const AppIcon(name: 'calendarDays', size: 20),
          variant: AppButtonVariant.outline,
          color: AppButtonColor.neutral,
          onPressed: onTap,
          semanticLabel: 'Expense date: $label. Tap to change.',
        ),
      ],
    );
  }
}

class _ReceiptAttachedRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        AppIcon(name: 'checkCircle', size: 16, color: colorScheme.tertiary),
        const SizedBox(width: MitlistSpacing.xs),
        Text(
          'Receipt attached',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: colorScheme.tertiary,
              ),
        ),
      ],
    );
  }
}

class _SplitRowSkeleton extends StatelessWidget {
  const _SplitRowSkeleton();

  @override
  Widget build(BuildContext context) {
    return const Row(
      children: [
        AppSkeleton(width: 24, height: 24),
        SizedBox(width: MitlistSpacing.sm),
        AppSkeleton(width: 120, height: 16),
      ],
    );
  }
}
