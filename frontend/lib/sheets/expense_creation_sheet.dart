import 'dart:async';

import 'dart:io';
import 'dart:typed_data';

import '../../l10n/app_localizations.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/finance_models.dart';
import '../models/group_models.dart';
import '../providers/attachment_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/finance_provider.dart';
import '../providers/group_provider.dart';
import '../router.dart' show currentGroupIdProvider;
import '../theme/spacing.dart';
import '../utils/active_group_context.dart';
import '../utils/format_currency.dart';
import '../utils/haptics.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/animated_check_toggle.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_currency_dropdown.dart';
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
    final l10n = AppLocalizations.of(context)!;
    final dirty = ValueNotifier<bool>(false);
    final future = showAppBottomSheet<bool>(
      context: context,
      title: l10n.expenseCreationTitle,
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
  // Starts empty: a foreign expense must get an explicit rate, never an
  // accidental 1:1 conversion.
  final TextEditingController _fxRateController = TextEditingController();
  final Map<String, TextEditingController> _splitControllers = {};

  /// Lets a blocked submit scroll the live split summary into view instead of
  /// failing silently with only a haptic buzz.
  final GlobalKey _splitSummaryKey = GlobalKey();
  List<GroupMemberProfile> _members = [];
  final Set<String> _selectedMemberIds = {};
  String _splitMode = 'equal';
  String _currency = 'USD';
  String? _payerId;

  /// The household's base currency. Splits and balances are denominated in it;
  /// [_currency] may differ when recording a foreign-currency expense.
  String _groupCurrency = 'USD';
  // 0 until the user enters a rate, so an untouched foreign expense fails
  // validation rather than recording at 1:1.
  double _fxRate = 0.0;
  DateTime _date = DateTime.now();
  bool _membersLoading = true;
  bool _membersFailed = false;
  bool _isSaving = false;

  String? _descriptionError;
  String? _amountError;
  String? _fxRateError;

  /// True when the chosen expense currency differs from the household base
  /// currency, which is when an FX rate is needed.
  bool get _isForeignCurrency => _currency != _groupCurrency;

  /// True when the current FX rate was prefilled by the live-rate service.
  /// Reset to false the moment the user edits the field.
  bool _rateAutoFilled = false;

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
      final authService = await ref.read(authServiceProviderAsync.future);
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final groups = await ref.read(cachedGroupsProvider.future);
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
      final me = await authService.getMe();
      final group = await groupService.getGroup(groupId);
      final members = await groupService.listMembers(groupId);
      if (!mounted) return;
      setState(() {
        _groupCurrency = group.currency;
        _currency = group.currency;
        _members = members;
        _membersLoading = false;
        _membersFailed = false;
        _payerId ??= me.id;
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

  /// Attempts to prefill the FX rate field from the live-rate advisory endpoint.
  /// On any failure (feature disabled, network error, provider down) this is a
  /// no-op and the field stays empty for manual entry — never blocking the form.
  Future<void> _fetchAndPrefillRate(String from, String to) async {
    try {
      final financeService = await ref.read(financeServiceProviderAsync.future);
      if (!mounted) return;
      final rate = await financeService.fetchAdvisoryFxRate(from, to);
      if (!mounted || rate == null || rate <= 0) return;
      setState(() {
        _fxRate = rate;
        _fxRateController.text = rate
            .toStringAsFixed(6)
            .replaceAll(RegExp(r'0+$'), '')
            .replaceAll(RegExp(r'\.$'), '');
        _rateAutoFilled = true;
        _fxRateError = null;
      });
    } catch (_) {
      // Fail-soft: leave field empty for manual entry.
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (picked == null || !mounted) return;
    setState(() => _date = picked);
    _markDirty();
  }

  bool get _canCreate =>
      _descriptionController.text.trim().isNotEmpty &&
      _amountController.text.trim().isNotEmpty &&
      !_membersLoading &&
      _selectedMemberIds.isNotEmpty &&
      !_isSaving;

  Future<void> _onCreate() async {
    final l10n = AppLocalizations.of(context)!;
    if (!_canCreate) return;

    final amount = _parseAmountToCents(_amountController.text);
    if (amount == null) {
      setState(() => _amountError = l10n.expenseCreationValidationAmount);
      return;
    }

    if (_isForeignCurrency && _fxRate <= 0) {
      setState(() => _fxRateError = l10n.expenseCreationValidationRate);
      return;
    }

    // Splits and balances live in the household base currency, so the split
    // summary is reconciled against the converted (base) amount.
    final baseAmount = _isForeignCurrency ? (amount * _fxRate).round() : amount;

    final summary = computeSplitSummary(
      l10n: l10n,
      mode: _splitMode,
      selectedIds: _selectedMemberIds,
      controllers: _splitControllers,
      totalCents: baseAmount,
      currency: _groupCurrency,
    );
    if (!summary.isValid) {
      // The live split summary shows the reason in red. Bring it into view so a
      // blocked submit points at its cause instead of buzzing silently.
      unawaited(Haptics.medium());
      final summaryContext = _splitSummaryKey.currentContext;
      if (summaryContext != null) {
        unawaited(
          Scrollable.ensureVisible(
            summaryContext,
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            alignment: 0.5,
          ),
        );
      }
      return;
    }

    setState(() => _isSaving = true);

    try {
      final authService = await ref.read(authServiceProviderAsync.future);
      final financeService = await ref.read(financeServiceProviderAsync.future);
      final groups = await ref.read(cachedGroupsProvider.future);

      if (!mounted) return;
      final groupId = resolveActiveGroupId(
        groups,
        ref.read(currentGroupIdProvider),
      );
      if (groupId == null) {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.choreCreationJoinFirst)),
        );
        return;
      }

      final me = await authService.getMe();
      final splitUserIds = _selectedMemberIds.toList();
      final splitRequests = _buildSplitRequests();
      final expense = await financeService.createExpense(
        CreateExpenseRequest(
          groupId: groupId,
          payerId: _payerId ?? me.id,
          amount: amount,
          baseAmount: baseAmount,
          fxRate: _isForeignCurrency ? _fxRate : 1.0,
          description: _descriptionController.text.trim(),
          notes: _notesController.text.trim(),
          currency: _currency,
          date: _date.toUtc(),
          splitMode: _splitMode,
          splitUserIds: _splitMode == 'equal' ? splitUserIds : const [],
          splits: _splitMode == 'equal' ? const [] : splitRequests,
        ),
      );

      final receipt = widget.receiptImage;
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
              SnackBar(
                content: Text(l10n.expenseCreationReceiptUploadFailed),
              ),
            );
          }
        }
      }

      if (!mounted) return;
      widget.dirtyNotifier?.value = false;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.expenseCreationExpenseAdded)),
      );
      unawaited(Haptics.success());
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
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
    _fxRateController.dispose();
    for (final controller in _splitControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalCents = _parseAmountToCents(_amountController.text);
    // Foreign expenses have no known base value until a positive rate is set,
    // so the split preview waits rather than reconciling against a 1:1 guess.
    final baseCents = totalCents == null
        ? null
        : _isForeignCurrency
            ? (_fxRate > 0 ? (totalCents * _fxRate).round() : null)
            : totalCents;
    final colorScheme = Theme.of(context).colorScheme;
    final l10n = AppLocalizations.of(context)!;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Amount + currency (hero row) ──────────────────────────────
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: AppInput(
                size: AppInputSize.lg,
                hint: l10n.expenseCreationAmountHint,
                controller: _amountController,
                textInputAction: TextInputAction.next,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                prefixIcon: _CurrencyPrefix(currency: _currency),
                errorText: _amountError,
                onChanged: (_) {
                  _markDirty();
                  setState(() => _amountError = null);
                },
              ),
            ),
            const SizedBox(width: MitlistSpacing.xs),
            _CompactCurrencyButton(
              value: _currency,
              onChanged: (value) {
                if (value == null) return;
                setState(() {
                  _currency = value;
                  _rateAutoFilled = false;
                  if (_currency == _groupCurrency) {
                    // Back to base currency: no conversion needed.
                    _fxRate = 1.0;
                    _fxRateController.clear();
                    _fxRateError = null;
                  } else {
                    // Switched to a foreign currency: clear stale rate, then
                    // attempt to prefill from the advisory endpoint.
                    _fxRate = 0.0;
                    _fxRateController.clear();
                    _fxRateError = null;
                  }
                });
                // Attempt advisory prefill for foreign currencies (fail-soft).
                if (_currency != _groupCurrency) {
                  _fetchAndPrefillRate(_currency, _groupCurrency);
                }
                _markDirty();
              },
            ),
          ],
        ),
        if (_isForeignCurrency) ...[
          const SizedBox(height: MitlistSpacing.sm),
          AppInput(
            hint: l10n.expenseCreationRateHint(_currency, _groupCurrency),
            controller: _fxRateController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            errorText: _fxRateError,
            onChanged: (value) {
              _markDirty();
              setState(() {
                _fxRate =
                    double.tryParse(value.replaceAll(',', '.').trim()) ?? 0;
                _fxRateError = null;
                _rateAutoFilled = false; // user overrode the prefilled value
              });
            },
          ),
          if (_rateAutoFilled) ...[
            const SizedBox(height: MitlistSpacing.xs),
            _AutoFilledRateHint(text: l10n.expenseCreationRateAutoFilled),
          ],
          if (totalCents != null && baseCents != null) ...[
            const SizedBox(height: MitlistSpacing.xs),
            _ConversionPreview(
              original: formatCurrency(totalCents, _currency),
              converted: formatCurrency(baseCents, _groupCurrency),
            ),
          ],
        ],
        // ── Description + payer (what & who) ──────────────────────────
        const SizedBox(height: MitlistSpacing.lg),
        AppInput(
          hint: l10n.expenseCreationWhatsItFor,
          controller: _descriptionController,
          textInputAction: TextInputAction.next,
          maxLength: 200,
          errorText: _descriptionError,
          onChanged: (_) {
            _markDirty();
            setState(() => _descriptionError = null);
          },
        ),
        // ── Paid by ───────────────────────────────────────────────────
        if (_membersLoading) ...[
          const SizedBox(height: MitlistSpacing.md),
          const _PaidBySkeleton(),
        ] else if (_members.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.md),
          _PaidByRow(
            members: _members,
            payerId: _payerId,
            onChanged: (id) {
              setState(() => _payerId = id);
              _markDirty();
            },
          ),
        ],
        // ── Date + Scan + notes (details) ─────────────────────────────
        const SizedBox(height: MitlistSpacing.lg),
        Row(
          children: [
            Expanded(
              child: AppButton(
                text: MaterialLocalizations.of(context).formatMediumDate(_date),
                icon: const AppIcon(name: 'calendarDays', size: 18),
                variant: AppButtonVariant.outline,
                color: AppButtonColor.neutral,
                onPressed: _pickDate,
                semanticLabel: l10n.expenseCreationDateLabel,
              ),
            ),
          ],
        ),
        // ── Notes (optional, recedes) ─────────────────────────────────
        const SizedBox(height: MitlistSpacing.sm),
        AppInput(
          variant: AppInputVariant.soft,
          hint: l10n.expenseCreationNotesHint,
          controller: _notesController,
          textInputAction: TextInputAction.newline,
          keyboardType: TextInputType.multiline,
          minLines: 1,
          maxLines: 4,
          onChanged: (_) => _markDirty(),
        ),
        // ── Split ─────────────────────────────────────────────────────
        const SizedBox(height: MitlistSpacing.lg),
        Divider(
          height: 1,
          thickness: 1,
          color: colorScheme.outlineVariant,
        ),
        const SizedBox(height: MitlistSpacing.lg),
        _SplitOptions(
          summaryKey: _splitSummaryKey,
          members: _members,
          loading: _membersLoading,
          failed: _membersFailed,
          selectedMemberIds: _selectedMemberIds,
          splitMode: _splitMode,
          controllers: _splitControllers,
          totalCents: baseCents,
          currency: _groupCurrency,
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
            text: _isSaving ? l10n.commonAdding : l10n.expenseAddExpense,
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
  required AppLocalizations l10n,
  required String mode,
  required Set<String> selectedIds,
  required Map<String, TextEditingController> controllers,
  required int? totalCents,
  required String currency,
}) {
  final n = selectedIds.length;
  if (n == 0) {
    return SplitSummary(l10n.expenseCreationSelectSplitter, false);
  }
  if (totalCents == null) {
    return SplitSummary(l10n.expenseCreationEnterAmount, false);
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
      final assignedLabel = l10n.expenseCreationSplitAssignedOf(
        formatCurrency(assignedCents, currency),
        formatCurrency(totalCents, currency),
      );
      if (negative) {
        return SplitSummary(
          l10n.expenseCreationSplitAmountsNegative(assignedLabel),
          false,
        );
      }
      if (remaining > 0) {
        return SplitSummary(
          l10n.expenseCreationSplitLeftToAssign(
            assignedLabel,
            formatCurrency(remaining, currency),
          ),
          false,
        );
      }
      if (remaining < 0) {
        return SplitSummary(
          l10n.expenseCreationSplitOver(
            assignedLabel,
            formatCurrency(-remaining, currency),
          ),
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
      final sumLabel =
          sum % 1 == 0 ? sum.toStringAsFixed(0) : sum.toStringAsFixed(1);
      if (outOfRange) {
        return SplitSummary(
          l10n.expenseCreationSplitPercentRange(sumLabel),
          false,
        );
      }
      final balanced = (sum - 100).abs() < 0.05;
      return SplitSummary(
          l10n.expenseCreationSplitPercentOf100(sumLabel), balanced);

    case 'shares':
      var totalShares = 0;
      var negative = false;
      for (final id in selectedIds) {
        final v = int.tryParse((controllers[id]?.text ?? '').trim()) ?? 0;
        if (v < 0) negative = true;
        totalShares += v;
      }
      if (negative) {
        return SplitSummary(l10n.expenseCreationSharesNegative, false);
      }
      if (totalShares <= 0) {
        return SplitSummary(l10n.expenseCreationAssignShare, false);
      }
      final perShare = (totalCents / totalShares).round();
      return SplitSummary(
        l10n.expenseCreationSplitSharesPerShare(
          totalShares,
          formatCurrency(perShare, currency),
        ),
        true,
      );

    default: // equal
      final perPerson = totalCents ~/ n;
      final remainder = totalCents - perPerson * n;
      final each = l10n.expenseCreationSplitEach(
        formatCurrency(perPerson, currency),
      );
      return SplitSummary(
        remainder == 0
            ? each
            : l10n.expenseCreationSplitApproxEach(
                formatCurrency(perPerson, currency),
              ),
        true,
      );
  }
}

class _SplitOptions extends StatelessWidget {
  final Key summaryKey;
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
    required this.summaryKey,
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
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;

    if (loading) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.expenseCreationSplitWith, style: textTheme.labelMedium),
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
            l10n.expenseCreationCouldNotLoadMembers,
            style: textTheme.bodyMedium,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          AppButton(
            text: l10n.commonRetry,
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
        l10n.expenseCreationJoinHouseholdSplit,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      );
    }

    final summary = computeSplitSummary(
      l10n: l10n,
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
        // Keep the total the split reconciles against in view, so editing many
        // member rows never means scrolling back up to remember the amount.
        Row(
          children: [
            Expanded(
              child: Text(
                l10n.expenseCreationSplitMode,
                style: textTheme.labelMedium,
              ),
            ),
            const SizedBox(width: MitlistSpacing.sm),
            Text(
              totalCents == null
                  ? l10n.expenseCreationSplitTotal('—')
                  : l10n.expenseCreationSplitTotal(
                      formatCurrency(totalCents!, currency),
                    ),
              style: textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
          children: [
            AppChip(
              label: l10n.expenseCreationSplitEqual,
              selected: splitMode == 'equal',
              onSelected: (_) => onModeChanged('equal'),
            ),
            AppChip(
              label: l10n.expenseCreationSplitExact,
              selected: splitMode == 'amount',
              onSelected: (_) => onModeChanged('amount'),
            ),
            AppChip(
              label: l10n.expenseCreationSplitShares,
              selected: splitMode == 'shares',
              onSelected: (_) => onModeChanged('shares'),
            ),
            AppChip(
              label: l10n.expenseCreationSplitPercent,
              selected: splitMode == 'percentage',
              onSelected: (_) => onModeChanged('percentage'),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Text(
          _modeHint(splitMode, context),
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
                  width: splitMode == 'amount' ? 116 : 96,
                  child: Text(
                    _valueLabel(splitMode, context).toUpperCase(),
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
                  semanticLabelOn:
                      l10n.expenseCreationRemoveFromSplit(member.displayName),
                  semanticLabelOff:
                      l10n.expenseCreationAddToSplit(member.displayName),
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
                    width: splitMode == 'amount' ? 116 : 96,
                    child: Semantics(
                      label:
                          '${member.displayName} ${_valueLabel(splitMode, context)}',
                      child: AppInput(
                        // Money fields read as money: a currency prefix and a
                        // "0.00" hint, matching the main amount input. Shares
                        // and percent are bare counts.
                        prefixIcon: splitMode == 'amount'
                            ? _CurrencyPrefix(currency: currency)
                            : null,
                        hint: switch (splitMode) {
                          'percentage' => '50',
                          'amount' => '0.00',
                          _ => '1',
                        },
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
          key: summaryKey,
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

  String _modeHint(String mode, BuildContext context) => switch (mode) {
        'amount' => AppLocalizations.of(context)!.expenseCreationSplitHintExact,
        'percentage' =>
          AppLocalizations.of(context)!.expenseCreationSplitHintPercent,
        'shares' =>
          AppLocalizations.of(context)!.expenseCreationSplitHintShares,
        _ => AppLocalizations.of(context)!.expenseCreationSplitHintEqual,
      };

  String _valueLabel(String mode, BuildContext context) => switch (mode) {
        'amount' =>
          AppLocalizations.of(context)!.expenseCreationSplitValuesAmount,
        'percentage' =>
          AppLocalizations.of(context)!.expenseCreationSplitValuesPercent,
        _ => AppLocalizations.of(context)!.expenseCreationSplitSharesLabel,
      };
}

/// Subtle inline notice that the FX rate was prefilled by the advisory service.
/// Disappears as soon as the user edits the field.
class _AutoFilledRateHint extends StatelessWidget {
  final String text;

  const _AutoFilledRateHint({required this.text});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        AppIcon(
          name: 'arrowPath',
          size: 14,
          color: colorScheme.primary.withValues(alpha: 0.7),
        ),
        const SizedBox(width: MitlistSpacing.xs),
        Expanded(
          child: Text(
            text,
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.primary.withValues(alpha: 0.7),
            ),
          ),
        ),
      ],
    );
  }
}

class _ConversionPreview extends StatelessWidget {
  final String original;
  final String converted;

  const _ConversionPreview({required this.original, required this.converted});

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        AppIcon(
          name: 'arrowPath',
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        const SizedBox(width: MitlistSpacing.xs),
        Expanded(
          child: Text(
            '$original ≈ $converted',
            style: textTheme.bodySmall?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}

/// Minimal inline currency selector — just the 3-letter code + chevron in muted
/// text. Keeps the amount row clean; tap to open the system dropdown menu.
class _CompactCurrencyButton extends StatelessWidget {
  final String value;
  final ValueChanged<String?>? onChanged;

  const _CompactCurrencyButton({required this.value, this.onChanged});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value,
        isDense: true,
        style: textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
        icon: Icon(
          Icons.keyboard_arrow_down_rounded,
          size: 16,
          color: colorScheme.onSurfaceVariant,
        ),
        items: currencyDropdownItems(l10n),
        onChanged: onChanged,
      ),
    );
  }
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

class _PaidByRow extends StatelessWidget {
  final List<GroupMemberProfile> members;
  final String? payerId;
  final ValueChanged<String> onChanged;

  const _PaidByRow({
    required this.members,
    required this.payerId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.expenseCreationPaidBy,
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: MitlistSpacing.xs),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: members.map((member) {
              final selected = member.userId == payerId;
              return Padding(
                padding: const EdgeInsets.only(right: MitlistSpacing.xs),
                child: AppChip(
                  label: member.displayName,
                  selected: selected,
                  onSelected: (_) => onChanged(member.userId),
                ),
              );
            }).toList(),
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

/// Reserves the "Paid by" row while members load so it doesn't pop in and shift
/// the form, matching the skeleton treatment used by the split list.
class _PaidBySkeleton extends StatelessWidget {
  const _PaidBySkeleton();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.expenseCreationPaidBy,
          style: textTheme.labelMedium?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: MitlistSpacing.xs),
        Row(
          children: const [
            AppSkeleton(width: 88, height: 32),
            SizedBox(width: MitlistSpacing.xs),
            AppSkeleton(width: 72, height: 32),
          ],
        ),
      ],
    );
  }
}
