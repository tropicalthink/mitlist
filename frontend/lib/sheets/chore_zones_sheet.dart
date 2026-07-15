import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/group_models.dart';
import '../providers/group_provider.dart';
import '../theme/spacing.dart';
import '../utils/friendly_error.dart';
import '../widgets/alert.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/chip.dart';
import '../l10n/app_localizations.dart';

/// Editor for a household's chore zones (kitchen, bathroom, ...).
///
/// Reachable from both the chores screen overflow menu and household
/// settings, so zone upkeep lives next to the chores it organizes.
class ChoreZonesSheet extends ConsumerStatefulWidget {
  const ChoreZonesSheet({super.key, required this.groupId});

  final String groupId;

  static Future<void> show(BuildContext context, {required String groupId}) {
    final l10n = AppLocalizations.of(context)!;
    return showAppBottomSheet<void>(
      context: context,
      title: l10n.sheetGroupSettingsChoreZonesLabel,
      body: ChoreZonesSheet(groupId: groupId),
    );
  }

  @override
  ConsumerState<ChoreZonesSheet> createState() => _ChoreZonesSheetState();
}

class _ChoreZonesSheetState extends ConsumerState<ChoreZonesSheet> {
  bool _isLoading = true;
  bool _isSaving = false;
  bool _zonesChanged = false;
  String? _error;
  List<String> _zones = [];
  final TextEditingController _zoneInputController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadZones();
  }

  @override
  void dispose() {
    _zoneInputController.dispose();
    super.dispose();
  }

  Future<void> _loadZones() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final svc = await ref.read(groupServiceProviderAsync.future);
      final group = await svc.getGroup(widget.groupId);
      if (!mounted) return;
      setState(() {
        _zones = List<String>.from(group.choreZones);
        _isLoading = false;
        _zonesChanged = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = friendlyErrorMessage(e, AppLocalizations.of(context)!);
        _isLoading = false;
      });
    }
  }

  void _addZone() {
    final zone = _zoneInputController.text.trim();
    if (zone.isEmpty) return;
    if (_zones.any((z) => z.toLowerCase() == zone.toLowerCase())) {
      _zoneInputController.clear();
      return;
    }
    setState(() {
      _zones = [..._zones, zone];
      _zonesChanged = true;
      _zoneInputController.clear();
    });
  }

  void _removeZone(String zone) {
    setState(() {
      _zones = _zones.where((z) => z != zone).toList();
      _zonesChanged = true;
    });
  }

  Future<void> _saveZones() async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    try {
      final svc = await ref.read(groupServiceProviderAsync.future);
      final updated = await svc.updateGroup(
        widget.groupId,
        UpdateGroupRequest(choreZones: _zones),
      );
      if (!mounted) return;
      ref.invalidate(cachedGroupsProvider);
      setState(() {
        _zones = List<String>.from(updated.choreZones);
        _isSaving = false;
        _zonesChanged = false;
      });
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.sheetGroupSettingsChoreZonesUpdated)),
      );
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

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;

    if (_isLoading) {
      return const Padding(
        padding: EdgeInsets.all(MitlistSpacing.xl),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppAlert(type: AppAlertType.error, message: _error!),
            const SizedBox(height: MitlistSpacing.md),
            AppButton(text: l10n.commonRetry, onPressed: _loadZones),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            l10n.sheetGroupSettingsChoreZonesDesc,
            style: textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          if (_zones.isNotEmpty) ...[
            const SizedBox(height: MitlistSpacing.sm),
            Wrap(
              spacing: MitlistSpacing.sm,
              runSpacing: MitlistSpacing.sm,
              children: [
                for (final zone in _zones)
                  AppChip(
                    label: zone,
                    onSelected: (_) => _removeZone(zone),
                  ),
              ],
            ),
          ],
          const SizedBox(height: MitlistSpacing.md),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppInput(
                  label: l10n.sheetGroupSettingsAddZone,
                  hint: l10n.sheetGroupSettingsZoneHint,
                  controller: _zoneInputController,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _addZone(),
                ),
              ),
              const SizedBox(width: MitlistSpacing.sm),
              AppButton(
                text: l10n.commonAdd,
                size: AppButtonSize.sm,
                onPressed: _addZone,
              ),
            ],
          ),
          if (_zonesChanged) ...[
            const SizedBox(height: MitlistSpacing.md),
            AppButton(
              text: _isSaving ? l10n.commonSaving : l10n.sheetGroupSettingsSaveZones,
              isLoading: _isSaving,
              onPressed: _isSaving ? null : _saveZones,
            ),
          ],
        ],
      ),
    );
  }
}
