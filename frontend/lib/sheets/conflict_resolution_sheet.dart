import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/list_provider.dart';
import '../storage/app_database.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';

class ConflictResolutionSheet extends ConsumerStatefulWidget {
  const ConflictResolutionSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showAppBottomSheet(
      context: context,
      title: 'Resolve Conflicts',
      body: const ConflictResolutionSheet(),
    );
  }

  @override
  ConsumerState<ConflictResolutionSheet> createState() =>
      _ConflictResolutionSheetState();
}

class _ConflictResolutionSheetState
    extends ConsumerState<ConflictResolutionSheet> {
  List<Conflict>? _conflicts;
  bool _loading = true;
  final Set<String> _resolving = {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final db = ref.read(appDatabaseProvider);
    final conflicts = await db.getConflicts();
    if (!mounted) return;
    setState(() {
      _conflicts = conflicts;
      _loading = false;
    });
  }

  Future<void> _keepLocal(Conflict conflict) async {
    final db = ref.read(appDatabaseProvider);
    setState(() => _resolving.add(conflict.id));

    await db.enqueueOutbox(
      id: conflict.id,
      type: conflict.entityType,
      payload: jsonDecode(conflict.localPayloadJson) as Map<String, dynamic>,
    );
    await db.resolveConflict(conflict.id);

    if (!mounted) return;
    setState(() => _resolving.remove(conflict.id));
    _conflicts?.removeWhere((c) => c.id == conflict.id);
  }

  Future<void> _acceptServer(Conflict conflict) async {
    final db = ref.read(appDatabaseProvider);
    setState(() => _resolving.add(conflict.id));

    await db.resolveConflict(conflict.id);

    if (!mounted) return;
    setState(() => _resolving.remove(conflict.id));
    _conflicts?.removeWhere((c) => c.id == conflict.id);

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Server version accepted. Changes will sync.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Padding(
        padding: EdgeInsets.all(MitlistSpacing.lg),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    final conflicts = _conflicts ?? [];

    if (conflicts.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(MitlistSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, size: 48, color: MitlistColors.success500),
            SizedBox(height: MitlistSpacing.md),
            Text(
              'All conflicts resolved',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: MitlistColors.textPrimary,
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          conflicts.length == 1
              ? '1 item has conflicting changes'
              : '${conflicts.length} items have conflicting changes',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: MitlistColors.textSecondary,
              ),
        ),
        const SizedBox(height: MitlistSpacing.md),
        ...conflicts.map((conflict) => _ConflictCard(
              conflict: conflict,
              isResolving: _resolving.contains(conflict.id),
              onKeepLocal: () => _keepLocal(conflict),
              onAcceptServer: () => _acceptServer(conflict),
            )),
      ],
    );
  }
}

class _ConflictCard extends StatelessWidget {
  const _ConflictCard({
    required this.conflict,
    required this.isResolving,
    required this.onKeepLocal,
    required this.onAcceptServer,
  });

  final Conflict conflict;
  final bool isResolving;
  final VoidCallback onKeepLocal;
  final VoidCallback onAcceptServer;

  Map<String, dynamic> get _local =>
      jsonDecode(conflict.localPayloadJson) as Map<String, dynamic>;

  Map<String, dynamic> get _server =>
      jsonDecode(conflict.serverPayloadJson) as Map<String, dynamic>;

  @override
  Widget build(BuildContext context) {
    final local = _local;
    final server = _server;
    final keys = <String>{...local.keys, ...server.keys}.toList()
      ..sort();

    return Padding(
      padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
      child: AppCard(
        variant: AppCardVariant.outlined,
        padding: AppCardPadding.md,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.warning_amber_rounded,
                    size: 16, color: MitlistColors.warning500),
                const SizedBox(width: MitlistSpacing.sm),
                Expanded(
                  child: Text(
                    _entityLabel(conflict.entityType),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: MitlistSpacing.sm),
            ...keys.map((key) {
              final localVal = _formatValue(local[key]);
              final serverVal = _formatValue(server[key]);
              final changed = local[key]?.toString() != server[key]?.toString();
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 80,
                      child: Text(
                        key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          color: MitlistColors.textTertiary,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    ),
                    const SizedBox(width: MitlistSpacing.sm),
                    Expanded(
                      child: Text(
                        localVal,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              changed ? FontWeight.w600 : FontWeight.normal,
                          color: changed
                              ? MitlistColors.primary500
                              : MitlistColors.textPrimary,
                          fontFamily: 'JetBrains Mono',
                          decoration: changed
                              ? TextDecoration.underline
                              : TextDecoration.none,
                        ),
                      ),
                    ),
                    const SizedBox(width: MitlistSpacing.xs),
                    Icon(Icons.arrow_forward,
                        size: 12, color: MitlistColors.neutral400),
                    const SizedBox(width: MitlistSpacing.xs),
                    Expanded(
                      child: Text(
                        serverVal,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight:
                              changed ? FontWeight.w600 : FontWeight.normal,
                          color: changed
                              ? MitlistColors.success500
                              : MitlistColors.textPrimary,
                          fontFamily: 'JetBrains Mono',
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: MitlistSpacing.sm),
            isResolving
                ? const SizedBox(
                    height: 36,
                    child: Center(child: SizedBox(
                      width: 18, height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )),
                  )
                : Row(
                    children: [
                      Expanded(
                        child: AppButton(
                          variant: AppButtonVariant.solid,
                          color: AppButtonColor.primary,
                          text: 'Keep my changes',
                          onPressed: onKeepLocal,
                        ),
                      ),
                      const SizedBox(width: MitlistSpacing.sm),
                      Expanded(
                        child: AppButton(
                          variant: AppButtonVariant.outline,
                          text: 'Use server',
                          onPressed: onAcceptServer,
                        ),
                      ),
                    ],
                  ),
          ],
        ),
      ),
    );
  }

  String _entityLabel(String entityType) {
    switch (entityType) {
      case 'list_item':
        return 'List Item';
      case 'expense':
        return 'Expense';
      case 'chore':
        return 'Chore';
      case 'recipe':
        return 'Recipe';
      case 'pinwall_post':
        return 'Pinwall Post';
      default:
        return entityType;
    }
  }

  String _formatValue(dynamic value) {
    if (value == null) return '—';
    if (value is Map || value is List) return jsonEncode(value);
    return value.toString();
  }
}
