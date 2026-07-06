import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../l10n/app_localizations.dart';
import '../models/chore_models.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_divider.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_dialog.dart';
import '../widgets/animated_check_toggle.dart';
import '../widgets/app_icon.dart';
import '../widgets/app_input.dart';
import '../widgets/chip.dart';

class ChoreDetailSheet extends StatefulWidget {
  const ChoreDetailSheet({
    super.key,
    required this.choreId,
    required this.title,
    required this.statusLabel,
    required this.assignee,
    this.frequencyLabel,
    required this.dueDate,
    this.trackedCount,
    this.lastTrackedAt,
    this.lastDoneByLabel,
    this.averageFrequencyHours,
    this.subtasks = const [],
    this.supplies = const [],
    this.onMarkDone,
    this.onSkip,
    this.onRescheduleTomorrow,
    this.onUndo,
    this.onToggleSubtask,
    this.onAddSubtask,
    this.onDeleteSubtask,
    this.onReorderSubtasks,
    this.onAddSuppliesToList,
    this.onDelete,
  });

  final String choreId;
  final String title;
  final String statusLabel;
  final String assignee;

  /// Human rhythm label ("Every 2 weeks", "As needed"); the one fact the sheet
  /// was missing about a recurring chore.
  final String? frequencyLabel;
  final DateTime dueDate;
  final int? trackedCount;
  final DateTime? lastTrackedAt;
  final String? lastDoneByLabel;
  final double? averageFrequencyHours;
  final List<ChoreSubtask> subtasks;
  final List<String> supplies;
  final VoidCallback? onMarkDone;
  final ValueChanged<String?>? onSkip;
  final VoidCallback? onRescheduleTomorrow;
  final VoidCallback? onUndo;
  final void Function(String subtaskId, bool completed)? onToggleSubtask;
  final Future<String?> Function(String title)? onAddSubtask;
  final ValueChanged<String>? onDeleteSubtask;
  final ValueChanged<List<String>>? onReorderSubtasks;
  final VoidCallback? onAddSuppliesToList;
  final VoidCallback? onDelete;

  static Future<void> show(
    BuildContext context, {
    required String choreId,
    required String title,
    required String statusLabel,
    required String assignee,
    String? frequencyLabel,
    required DateTime dueDate,
    int? trackedCount,
    DateTime? lastTrackedAt,
    String? lastDoneByLabel,
    double? averageFrequencyHours,
    List<ChoreSubtask> subtasks = const [],
    List<String> supplies = const [],
    VoidCallback? onMarkDone,
    ValueChanged<String?>? onSkip,
    VoidCallback? onRescheduleTomorrow,
    VoidCallback? onUndo,
    void Function(String subtaskId, bool completed)? onToggleSubtask,
    Future<String?> Function(String title)? onAddSubtask,
    ValueChanged<String>? onDeleteSubtask,
    ValueChanged<List<String>>? onReorderSubtasks,
    VoidCallback? onAddSuppliesToList,
    VoidCallback? onDelete,
  }) async {
    final l10n = AppLocalizations.of(context)!;
    return showAppBottomSheet(
      context: context,
      title: l10n.choreDetailTitle,
      body: ChoreDetailSheet(
        choreId: choreId,
        title: title,
        statusLabel: statusLabel,
        assignee: assignee,
        frequencyLabel: frequencyLabel,
        dueDate: dueDate,
        trackedCount: trackedCount,
        lastTrackedAt: lastTrackedAt,
        lastDoneByLabel: lastDoneByLabel,
        averageFrequencyHours: averageFrequencyHours,
        subtasks: subtasks,
        supplies: supplies,
        onMarkDone: onMarkDone,
        onSkip: onSkip,
        onRescheduleTomorrow: onRescheduleTomorrow,
        onUndo: onUndo,
        onToggleSubtask: onToggleSubtask,
        onAddSubtask: onAddSubtask,
        onDeleteSubtask: onDeleteSubtask,
        onReorderSubtasks: onReorderSubtasks,
        onAddSuppliesToList: onAddSuppliesToList,
        onDelete: onDelete,
      ),
    );
  }

  @override
  State<ChoreDetailSheet> createState() => _ChoreDetailSheetState();
}

class _ChoreDetailSheetState extends State<ChoreDetailSheet> {
  late List<ChoreSubtask> _subtasks;
  final TextEditingController _subtaskController = TextEditingController();
  bool _showAddSubtask = false;
  bool _isDeleting = false;
  bool _isSavingSubtask = false;

  @override
  void initState() {
    super.initState();
    _subtasks = List.from(widget.subtasks);
  }

  @override
  void dispose() {
    _subtaskController.dispose();
    super.dispose();
  }

  void _handleSkip() async {
    final l10n = AppLocalizations.of(context)!;
    final reason = await showAppDialog<String>(
      context: context,
      title: l10n.choreDetailSkipTitle,
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppInput(
            label: l10n.choreDetailSkipReason,
            hint: l10n.choreDetailSkipReasonHint,
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          const SizedBox(height: MitlistSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                variant: AppButtonVariant.outline,
                color: AppButtonColor.neutral,
                text: l10n.commonCancel,
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: MitlistSpacing.sm),
              AppButton(
                variant: AppButtonVariant.outline,
                color: AppButtonColor.neutral,
                text: l10n.commonSkip,
                onPressed: () => Navigator.of(context).pop(''),
              ),
            ],
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (reason != null && widget.onSkip != null) {
      widget.onSkip!(reason.isEmpty ? null : reason);
    }
  }

  void _handleToggleSubtask(String subtaskId) {
    bool newCompleted = false;
    setState(() {
      final idx = _subtasks.indexWhere((s) => s.id == subtaskId);
      if (idx != -1) {
        newCompleted = !_subtasks[idx].completed;
        _subtasks[idx] = _subtasks[idx].copyWith(
          completed: newCompleted,
        );
      }
    });
    widget.onToggleSubtask?.call(subtaskId, newCompleted);
  }

  void _handleAddSubtask() async {
    if (!_showAddSubtask) {
      setState(() => _showAddSubtask = true);
      return;
    }
    final title = _subtaskController.text.trim();
    if (title.isEmpty || _isSavingSubtask) return;
    setState(() => _isSavingSubtask = true);
    final newSubtaskId = await widget.onAddSubtask?.call(title);
    if (!mounted) return;
    if (newSubtaskId != null) {
      setState(() {
        _subtasks.add(
          ChoreSubtask(
            id: newSubtaskId,
            choreId: widget.choreId,
            title: title,
            completed: false,
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          ),
        );
        _subtaskController.clear();
        _showAddSubtask = false;
      });
    }
    setState(() => _isSavingSubtask = false);
  }

  void _handleDeleteSubtask(String subtaskId) {
    setState(() {
      _subtasks.removeWhere((s) => s.id == subtaskId);
    });
    widget.onDeleteSubtask?.call(subtaskId);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppChip(
          label: widget.statusLabel,
          selected: true,
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          widget.title,
          style: textTheme.headlineSmall,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppCard(
          variant: AppCardVariant.outlined,
          padding: AppCardPadding.md,
          child: Column(
            children: [
              if (widget.assignee.isNotEmpty) ...[
                _DetailRow(
                    label: l10n.choreDetailAssignee, value: widget.assignee),
                const AppDivider(),
              ],
              if (widget.frequencyLabel != null &&
                  widget.frequencyLabel!.isNotEmpty) ...[
                _DetailRow(
                  label: l10n.choreDetailRhythm,
                  value: widget.frequencyLabel!,
                ),
                const AppDivider(),
              ],
              _DetailRow(
                label: l10n.choreDetailDue,
                value: DateFormat.yMMMd().format(widget.dueDate),
              ),
              if (widget.trackedCount != null) ...[
                const AppDivider(),
                _DetailRow(label: l10n.choreDetailTracked, value: widget.trackedCount.toString()),
              ],
              if (widget.lastTrackedAt != null) ...[
                const AppDivider(),
                _DetailRow(
                  label: l10n.choreDetailLastDone,
                  value: DateFormat.yMMMd().format(widget.lastTrackedAt!),
                ),
              ],
              if (widget.lastDoneByLabel != null && widget.lastDoneByLabel!.isNotEmpty) ...[
                const AppDivider(),
                _DetailRow(label: l10n.choreDetailLastBy, value: widget.lastDoneByLabel!),
              ],
              if (widget.averageFrequencyHours != null) ...[
                const AppDivider(),
                _DetailRow(
                  label: l10n.choreDetailAverage,
                  value: _formatAverageFrequency(widget.averageFrequencyHours!),
                ),
              ],
            ],
          ),
        ),
        if (_subtasks.isNotEmpty || widget.onAddSubtask != null) ...[
          const SizedBox(height: MitlistSpacing.lg),
          Text(l10n.choreDetailSubtasks, style: textTheme.titleMedium),
          const SizedBox(height: MitlistSpacing.sm),
          ..._subtasks.map((subtask) => _SubtaskRow(
                subtask: subtask,
                onToggle: () => _handleToggleSubtask(subtask.id),
                onDelete: widget.onDeleteSubtask != null
                    ? () => _handleDeleteSubtask(subtask.id)
                    : null,
              )),
          if (_showAddSubtask) ...[
            const SizedBox(height: MitlistSpacing.sm),
            AppInput(
              hint: l10n.choreDetailNewSubtask,
              controller: _subtaskController,
              onSubmitted: (_) => _handleAddSubtask(),
            ),
          ],
          if (widget.onAddSubtask != null) ...[
            const SizedBox(height: MitlistSpacing.sm),
              AppButton(
                variant: AppButtonVariant.ghost,
                color: AppButtonColor.primary,
                text: _showAddSubtask
                    ? (_isSavingSubtask ? l10n.commonSaving : l10n.commonSave)
                    : l10n.commonAdd,
                isLoading: _isSavingSubtask,
                icon: const AppIcon(name: 'plus'),
                onPressed: _isSavingSubtask ? null : _handleAddSubtask,
              ),
          ],
        ],
        if (widget.supplies.isNotEmpty || widget.onAddSuppliesToList != null) ...[
          const SizedBox(height: MitlistSpacing.lg),
          Text(l10n.choreDetailSupplies, style: textTheme.titleMedium),
          const SizedBox(height: MitlistSpacing.sm),
          Wrap(
            spacing: MitlistSpacing.sm,
            runSpacing: MitlistSpacing.sm,
            children: [
              ...widget.supplies.map((s) => AppChip(
                    label: s,
                    selected: true,
                  )),
            ],
          ),
          if (widget.onAddSuppliesToList != null) ...[
            const SizedBox(height: MitlistSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                variant: AppButtonVariant.outline,
                color: AppButtonColor.primary,
                size: AppButtonSize.md,
                text: l10n.choreDetailAddSuppliesToList,
                onPressed: widget.onAddSuppliesToList,
              ),
            ),
          ],
        ],
        if (widget.onMarkDone != null ||
            widget.onSkip != null ||
            widget.onRescheduleTomorrow != null ||
            widget.onUndo != null ||
            widget.onDelete != null) ...[
          const SizedBox(height: MitlistSpacing.lg),
          if (widget.onMarkDone != null)
            SizedBox(
              width: double.infinity,
              child: AppButton(
                variant: AppButtonVariant.solid,
                color: AppButtonColor.success,
                size: AppButtonSize.lg,
                text: l10n.choreDetailMarkDone,
                onPressed: widget.onMarkDone,
              ),
            ),
          if (widget.onSkip != null) ...[
            const SizedBox(height: MitlistSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                variant: AppButtonVariant.outline,
                color: AppButtonColor.neutral,
                size: AppButtonSize.lg,
                text: l10n.commonSkip,
                onPressed: _handleSkip,
              ),
            ),
          ],
          if (widget.onRescheduleTomorrow != null) ...[
            const SizedBox(height: MitlistSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                variant: AppButtonVariant.outline,
                color: AppButtonColor.primary,
                size: AppButtonSize.lg,
                text: l10n.choreDetailMoveToTomorrow,
                onPressed: widget.onRescheduleTomorrow,
              ),
            ),
          ],
          if (widget.onUndo != null) ...[
            const SizedBox(height: MitlistSpacing.sm),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                variant: AppButtonVariant.ghost,
                color: AppButtonColor.neutral,
                size: AppButtonSize.lg,
                text: l10n.choreDetailUndoLast,
                onPressed: widget.onUndo,
              ),
            ),
          ],
          if (widget.onDelete != null) ...[
            const SizedBox(height: MitlistSpacing.lg),
            SizedBox(
              width: double.infinity,
              child: AppButton(
                variant: AppButtonVariant.ghost,
                color: AppButtonColor.error,
                size: AppButtonSize.lg,
                text: _isDeleting ? l10n.commonDeleting : l10n.choreDetailDeleteTitleDialog,
                isLoading: _isDeleting,
                onPressed: _isDeleting
                    ? null
                    : () async {
                        final confirmed = await showAppDialog<bool>(
                          context: context,
                          title: l10n.choreDetailDeleteTitleDialog,
                          body: Text(l10n.choreDetailDeleteBody),
                          actions: [
                            AppButton(
                              text: l10n.commonCancel,
                              variant: AppButtonVariant.outline,
                              onPressed: () => Navigator.of(context).pop(false),
                            ),
                            AppButton(
                              text: l10n.commonDelete,
                              color: AppButtonColor.error,
                              onPressed: () => Navigator.of(context).pop(true),
                            ),
                          ],
                        );
                        if (confirmed == true && mounted) {
                          setState(() => _isDeleting = true);
                          widget.onDelete?.call();
                        }
                      },
              ),
            ),
          ],
        ],
      ],
    );
  }

  String _formatAverageFrequency(double hours) {
    if (hours < 24) {
      return '${hours.round()} h';
    }
    final days = hours / 24;
    if (days < 14) {
      return '${days.toStringAsFixed(days >= 10 ? 0 : 1)} d';
    }
    final weeks = days / 7;
    return '${weeks.toStringAsFixed(weeks >= 10 ? 0 : 1)} wk';
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: MitlistTypography.monoBody(color: Theme.of(context).colorScheme.onSurface),
          ),
        ],
      ),
    );
  }
}

class _SubtaskRow extends StatelessWidget {
  const _SubtaskRow({
    required this.subtask,
    required this.onToggle,
    this.onDelete,
  });

  final ChoreSubtask subtask;
  final VoidCallback onToggle;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.xs),
      child: Row(
        children: [
          AnimatedCheckToggle(
            value: subtask.completed,
            onChanged: (_) => onToggle(),
            semanticLabelOn: l10n.choreDetailSubtaskMarkNotDone,
            semanticLabelOff: l10n.choreDetailSubtaskMarkDone,
          ),
          Expanded(
            child: Text(
              subtask.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                decoration: subtask.completed ? TextDecoration.lineThrough : null,
                color: subtask.completed
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const AppIcon(name: 'xMark', size: 20),
              tooltip: l10n.choreDetailDeleteSubtask,
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
