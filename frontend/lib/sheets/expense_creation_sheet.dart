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
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../utils/active_group_context.dart';
import '../utils/haptics.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';

class ExpenseCreationSheet extends ConsumerStatefulWidget {
  final String? initialDescription;
  final String? initialAmount;
  final File? receiptImage;

  const ExpenseCreationSheet({
    super.key,
    this.initialDescription,
    this.initialAmount,
    this.receiptImage,
  });

  static Future<bool?> show(
    BuildContext context, {
    String? initialDescription,
    String? initialAmount,
    File? receiptImage,
  }) async {
    return showAppBottomSheet<bool>(
      context: context,
      title: 'Add Expense',
      body: ExpenseCreationSheet(
        initialDescription: initialDescription,
        initialAmount: initialAmount,
        receiptImage: receiptImage,
      ),
    );
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
  bool _isSaving = false;
  bool _isScanning = false;

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
    _loadMembers();
    _loadCurrency();
  }

  Future<void> _loadMembers() async {
    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final groups = await groupService.listGroups(limit: 50);
      if (!mounted || groups.isEmpty) return;
      final groupId = resolveActiveGroupId(
        groups,
        ref.read(currentGroupIdProvider),
      );
      if (groupId == null) return;
      final members = await groupService.listMembers(groupId);
      if (!mounted) return;
      setState(() {
        _members = members;
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
      // Member loading is optional; expense creation still works without splits.
    }
  }

  Future<void> _loadCurrency() async {
    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final groups = await groupService.listGroups(limit: 50);
      if (!mounted || groups.isEmpty) return;
      final groupId = resolveActiveGroupId(
        groups,
        ref.read(currentGroupIdProvider),
      );
      if (groupId == null) return;
      final group = await groupService.getGroup(groupId);
      if (!mounted) return;
      setState(() => _currency = group.currency);
    } catch (_) {
      // Currency loading is optional; defaults to USD.
    }
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

    try {
      final service = await ref.read(scanServiceProviderAsync.future);
      final bytes = await File(picked.path).readAsBytes();
      final result = await service.scanImage(bytes, 'image/jpeg');

      if (!mounted) return;

      if (result.title != null && result.title!.isNotEmpty) {
        _descriptionController.text = result.title!;
      }
      if (result.amount != null && result.amount! > 0) {
        _amountController.text =
            (result.amount! / 100).toStringAsFixed(2);
      }
      if (result.items.isNotEmpty &&
          _descriptionController.text.isEmpty) {
        _descriptionController.text =
            result.items.map((i) => i.name).join(', ');
      }

      setState(() => _isScanning = false);
    } catch (_) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\u2019t scan receipt.')),
      );
    }
  }

  bool get _canCreate =>
      _descriptionController.text.trim().isNotEmpty &&
      _amountController.text.trim().isNotEmpty &&
      !_isSaving;

  Future<void> _onCreate() async {
    if (!_canCreate) return;

    final amount = _parseAmountToCents(_amountController.text);
    if (amount == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount.')),
      );
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
          date: DateTime.now().toUtc(),
          splitMode: _splitMode,
          splitUserIds: _splitMode == 'equal' ? splitUserIds : const [],
          splits: _splitMode == 'equal' ? const [] : splitRequests,
        ),
      );

      if (widget.receiptImage != null) {
        try {
          final bytes = await widget.receiptImage!.readAsBytes();
          final attachmentRepo = await ref.read(attachmentRepositoryProvider.future);
          final attachment = await attachmentRepo.uploadAttachment(
            groupId: groupId,
            purpose: 'expense_receipt',
            filename: widget.receiptImage!.path.split('/').last,
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
              SnackBar(content: Text('Expense saved but receipt upload failed: $e')),
            );
          }
        }
      }

      if (!mounted) return;
      Navigator.of(context).pop(true);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Expense added')),
      );
      Haptics.success();
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Couldn\u2019t add expense.')),
      );
    }
  }

  int? _parseAmountToCents(String value) {
    final normalized = value.replaceAll(',', '.').trim();
    final parsed = double.tryParse(normalized);
    if (parsed == null || parsed <= 0) {
      return null;
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
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppButton(
          text: _isScanning ? 'Scanning…' : 'Scan receipt',
          icon: Icon(
            _isScanning ? Icons.hourglass_empty : Icons.document_scanner_outlined,
            size: 20,
          ),
          variant: AppButtonVariant.outline,
          color: AppButtonColor.neutral,
          onPressed: _isScanning ? null : _onScan,
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          label: 'Description',
          hint: 'e.g. Dinner at Luigi\'s',
          controller: _descriptionController,
          textInputAction: TextInputAction.next,
          maxLength: 200,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          label: 'Amount',
          hint: '0.00',
          controller: _amountController,
          textInputAction: TextInputAction.done,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          label: 'Notes',
          hint: 'Optional context, receipt note, or reimbursement detail',
          controller: _notesController,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() {}),
        ),
        const SizedBox(height: MitlistSpacing.md),
        _SplitOptions(
          members: _members,
          selectedMemberIds: _selectedMemberIds,
          splitMode: _splitMode,
          controllers: _splitControllers,
          onModeChanged: (mode) => setState(() => _splitMode = mode),
          onMemberChanged: (memberId, selected) {
            setState(() {
              if (selected) {
                _selectedMemberIds.add(memberId);
              } else {
                _selectedMemberIds.remove(memberId);
              }
            });
          },
          onValueChanged: () => setState(() {}),
        ),
        const SizedBox(height: MitlistSpacing.md),
        const SizedBox(height: MitlistSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            variant: AppButtonVariant.solid,
            color: AppButtonColor.primary,
            size: AppButtonSize.lg,
            text: _isSaving ? 'Adding...' : 'Add Expense',
            isLoading: _isSaving,
            onPressed: _canCreate ? _onCreate : null,
          ),
        ),
      ],
    );
  }
}

class _SplitOptions extends StatelessWidget {
  final List<GroupMemberProfile> members;
  final Set<String> selectedMemberIds;
  final String splitMode;
  final Map<String, TextEditingController> controllers;
  final ValueChanged<String> onModeChanged;
  final void Function(String memberId, bool selected) onMemberChanged;
  final VoidCallback onValueChanged;

  const _SplitOptions({
    required this.members,
    required this.selectedMemberIds,
    required this.splitMode,
    required this.controllers,
    required this.onModeChanged,
    required this.onMemberChanged,
    required this.onValueChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (members.isEmpty) {
      return Text(
        'Members will be available for split selection after the household loads.',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: MitlistColors.textSecondary,
            ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Split mode', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: MitlistSpacing.sm),
        Wrap(
          spacing: MitlistSpacing.sm,
          runSpacing: MitlistSpacing.sm,
          children: [
            for (final mode in const [
              'equal',
              'amount',
              'shares',
              'percentage'
            ])
              ChoiceChip(
                label: Text(_modeLabel(mode)),
                selected: splitMode == mode,
                onSelected: (_) => onModeChanged(mode),
              ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.md),
        ...members.map((member) {
          final selected = selectedMemberIds.contains(member.userId);
          return Padding(
            padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
            child: Row(
              children: [
                Checkbox(
                  value: selected,
                  onChanged: (value) =>
                      onMemberChanged(member.userId, value ?? false),
                ),
                Expanded(
                  child: Text(
                    member.displayName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (splitMode != 'equal') ...[
                  const SizedBox(width: MitlistSpacing.sm),
                  SizedBox(
                    width: 96,
                    child: AppInput(
                      label: _valueLabel(splitMode),
                      hint: splitMode == 'percentage' ? '50' : '1',
                      controller: controllers[member.userId],
                      enabled: selected,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => onValueChanged(),
                    ),
                  ),
                ],
              ],
            ),
          );
        }),
      ],
    );
  }

  String _modeLabel(String mode) => switch (mode) {
        'amount' => 'Exact',
        'shares' => 'Shares',
        'percentage' => 'Percent',
        _ => 'Equal',
      };

  String _valueLabel(String mode) => switch (mode) {
        'amount' => 'Amount',
        'percentage' => '%',
        _ => 'Shares',
      };
}
