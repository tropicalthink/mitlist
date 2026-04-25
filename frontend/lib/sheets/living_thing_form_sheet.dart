import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/living_models.dart';
import '../providers/group_provider.dart';
import '../providers/living_provider.dart';
import '../theme/spacing.dart';
import '../widgets/alert.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';

class LivingThingFormSheet extends ConsumerStatefulWidget {
  const LivingThingFormSheet({super.key});

  static Future<bool?> show(BuildContext context) async {
    return showAppBottomSheet<bool>(
      context: context,
      title: 'Add Pet or Plant',
      body: const LivingThingFormSheet(),
    );
  }

  @override
  ConsumerState<LivingThingFormSheet> createState() =>
      _LivingThingFormSheetState();
}

class _LivingThingFormSheetState extends ConsumerState<LivingThingFormSheet> {
  final _nameController = TextEditingController();
  final _locationController = TextEditingController();
  String _species = 'pet';
  bool _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _locationController.dispose();
    super.dispose();
  }

  Future<void> _onCreate() async {
    final name = _nameController.text.trim();
    final location = _locationController.text.trim();

    if (name.isEmpty) {
      setState(() {
        _errorMessage = 'Name is required.';
      });
      return;
    }

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      final groupService = await ref.read(groupServiceProviderAsync.future);
      final livingService = await ref.read(livingServiceProviderAsync.future);
      final groups = await groupService.listGroups(limit: 1);
      final groupId = groups.first.id;

      await livingService.createLivingThing(
        CreateLivingThingRequest(
          groupId: groupId,
          name: name,
          species: _species,
          location: location.isEmpty ? null : location,
        ),
      );

      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorMessage = 'Failed to save pet or plant.';
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_errorMessage != null) ...[
          AppAlert(
            type: AppAlertType.error,
            message: _errorMessage!,
          ),
          const SizedBox(height: MitlistSpacing.md),
        ],
        TextField(
          controller: _nameController,
          enabled: !_isSubmitting,
          textInputAction: TextInputAction.next,
          decoration: const InputDecoration(
            labelText: 'Name',
          ),
        ),
        const SizedBox(height: MitlistSpacing.md),
        DropdownButtonFormField<String>(
          value: _species,
          onChanged: _isSubmitting
              ? null
              : (value) {
                  if (value == null) return;
                  setState(() {
                    _species = value;
                  });
                },
          decoration: const InputDecoration(
            labelText: 'Type',
          ),
          items: const [
            DropdownMenuItem(
              value: 'pet',
              child: Text('Pet'),
            ),
            DropdownMenuItem(
              value: 'plant',
              child: Text('Plant'),
            ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.md),
        TextField(
          controller: _locationController,
          enabled: !_isSubmitting,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            labelText: 'Location',
          ),
        ),
        const SizedBox(height: MitlistSpacing.lg),
        SizedBox(
          width: double.infinity,
          child: AppButton(
            text: 'Add Item',
            onPressed: _isSubmitting ? null : _onCreate,
          ),
        ),
      ],
    );
  }
}
