import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/chore_models.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_bottom_sheet.dart';
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
    return showAppBottomSheet(
      context: context,
      title: 'Chore Details',
      body: ChoreDetailSheet(
        choreId: choreId,
        title: title,
        statusLabel: statusLabel,
        assignee: assignee,
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
    final reason = await showAppDialog<String>(
      context: context,
      title: 'Skip chore',
      body: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppInput(
            label: 'Reason (optional)',
            hint: 'e.g. Away this week',
            onSubmitted: (value) => Navigator.of(context).pop(value),
          ),
          const SizedBox(height: MitlistSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AppButton(
                variant: AppButtonVariant.outline,
                color: AppButtonColor.neutral,
                text: 'Cancel',
                onPressed: () => Navigator.of(context).pop(),
              ),
              const SizedBox(width: MitlistSpacing.sm),
              AppButton(
                variant: AppButtonVariant.outline,
                color: AppButtonColor.neutral,
                text: 'Skip',
                onPressed: () => Navigator.of(context).pop(''),
              ),
            ],
          ),
        ],
      ),
    );
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
    if (title.isEmpty) return;
    final newSubtaskId = await widget.onAddSubtask?.call(title);
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
  }

  void _handleDeleteSubtask(String subtaskId) {
    setState(() {
      _subtasks.removeWhere((s) => s.id == subtaskId);
    });
    widget.onDeleteSubtask?.call(subtaskId);
  }

  @override
  Widget build(BuildContext context) {
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
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppCard(
          variant: AppCardVariant.outlined,
          padding: AppCardPadding.md,
          child: Column(
            children: [
              _DetailRow(label: 'Assignee', value: widget.assignee),
              Divider(color: Theme.of(context).colorScheme.outlineVariant),
              _DetailRow(
                label: 'Due',
                value: DateFormat.yMMMd().format(widget.dueDate),
              ),
              if (widget.trackedCount != null) ...[
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                _DetailRow(label: 'Tracked', value: widget.trackedCount.toString()),
              ],
              if (widget.lastTrackedAt != null) ...[
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                _DetailRow(
                  label: 'Last done',
                  value: DateFormat.yMMMd().format(widget.lastTrackedAt!),
                ),
              ],
              if (widget.lastDoneByLabel != null && widget.lastDoneByLabel!.isNotEmpty) ...[
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                _DetailRow(label: 'Last by', value: widget.lastDoneByLabel!),
              ],
              if (widget.averageFrequencyHours != null) ...[
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                _DetailRow(
                  label: 'Average',
                  value: _formatAverageFrequency(widget.averageFrequencyHours!),
                ),
              ],
            ],
          ),
        ),
        if (_subtasks.isNotEmpty || widget.onAddSubtask != null) ...[
          const SizedBox(height: MitlistSpacing.lg),
          Text('Subtasks', style: textTheme.titleMedium),
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
              hint: 'New subtask',
              controller: _subtaskController,
              onSubmitted: (_) => _handleAddSubtask(),
            ),
          ],
          if (widget.onAddSubtask != null) ...[
            const SizedBox(height: MitlistSpacing.sm),
            AppButton(
              variant: AppButtonVariant.ghost,
              color: AppButtonColor.primary,
              text: _showAddSubtask ? 'Save' : 'Add subtask',
              icon: const AppIcon(name: 'plus'),
              onPressed: _handleAddSubtask,
            ),
          ],
        ],
        if (widget.supplies.isNotEmpty || widget.onAddSuppliesToList != null) ...[
          const SizedBox(height: MitlistSpacing.lg),
          Text('Supplies', style: textTheme.titleMedium),
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
                text: 'Add supplies to list',
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
                text: 'Mark Done',
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
                text: 'Skip',
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
                text: 'Move to Tomorrow',
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
                text: 'Undo Last Execution',
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
                text: 'Delete chore',
                onPressed: () async {
                  final confirmed = await showAppDialog<bool>(
                    context: context,
                    title: 'Delete chore',
                    body: const Text('This will permanently delete this chore and its history.'),
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
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.xs),
      child: Row(
        children: [
          AnimatedCheckToggle(
            value: subtask.completed,
            onChanged: (_) => onToggle(),
            semanticLabelOn: 'Mark subtask as not done',
            semanticLabelOff: 'Mark subtask as done',
          ),
          Expanded(
            child: Text(
              subtask.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                decoration: subtask.completed
                    ? TextDecoration.lineThrough
                    : null,
                color: subtask.completed
                    ? Theme.of(context).colorScheme.onSurfaceVariant
                    : Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ),
          if (onDelete != null)
            IconButton(
              icon: const AppIcon(name: 'xMark', size: 20),
              tooltip: 'Delete subtask',
              onPressed: onDelete,
            ),
        ],
      ),
    );
  }
}
