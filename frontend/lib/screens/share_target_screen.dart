import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../providers/group_provider.dart';
import '../providers/share_target_provider.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icon.dart';
// ShareTargetService is provided via `shareTargetServiceProviderAsync`.

class _DestinationOption {
  final String id;
  final String label;
  final String icon;
  final String description;

  const _DestinationOption({
    required this.id,
    required this.label,
    required this.icon,
    required this.description,
  });
}

class ShareTargetScreen extends ConsumerStatefulWidget {
  const ShareTargetScreen({super.key});

  @override
  ConsumerState<ShareTargetScreen> createState() => _ShareTargetScreenState();
}

class _ShareTargetScreenState extends ConsumerState<ShareTargetScreen> {
  String? _selectedDestination;
  final TextEditingController _textController = TextEditingController();
  bool _isSaving = false;
  String? _error;

  static const List<_DestinationOption> _options = [
    _DestinationOption(
      id: 'lists',
      label: 'Lists',
      icon: 'queueList',
      description: 'Save to a shopping or to-do list',
    ),
    _DestinationOption(
      id: 'recipes',
      label: 'Recipes',
      icon: 'informationCircle',
      description: 'Add to saved recipes',
    ),
  ];

  void _onDestinationTapped(String id) {
    setState(() {
      _selectedDestination = id;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<void> _onSave() async {
    if (_selectedDestination == null) return;
    final text = _textController.text.trim();
    if (text.isEmpty) {
      setState(() => _error = 'Paste or type something to save.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final shareService = await ref.read(shareTargetServiceProviderAsync.future);

      if (_selectedDestination == 'lists') {
        final groupService = await ref.read(groupServiceProviderAsync.future);
        final groups = await groupService.listGroups(limit: 1);
        if (groups.isEmpty) {
          setState(() {
            _error = 'Create or join a household first.';
            _isSaving = false;
          });
          return;
        }
        await shareService.createListFromShare(groupId: groups.first.id, text: text);
      } else {
        await shareService.createRecipeFromShare(text: text);
      }

      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Failed to save. Please try again.';
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Save to mitlist'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _textController,
              maxLines: 4,
              decoration: const InputDecoration(
                hintText: 'Paste or type the shared text here…',
              ),
            ),
            const SizedBox(height: MitlistSpacing.md),
            if (_error != null) ...[
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: MitlistColors.error500,
                    ),
              ),
              const SizedBox(height: MitlistSpacing.md),
            ],
            AppCard(
              variant: AppCardVariant.outlined,
              padding: AppCardPadding.md,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'PREVIEW',
                    style: MitlistTypography.labelXSmall(),
                  ),
                  const SizedBox(height: MitlistSpacing.sm),
                  Row(
                    children: [
                      const AppIcon(name: 'share', size: MitlistSpacing.space6),
                      const SizedBox(width: MitlistSpacing.sm),
                      Expanded(
                        child: Text(
                          'Paste text here now, or send content from the '
                          'share extension when that integration is available.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: MitlistSpacing.md),
            Expanded(
              child: ListView.separated(
                itemCount: _options.length,
                separatorBuilder: (_, __) => const SizedBox(
                  height: MitlistSpacing.sm,
                ),
                itemBuilder: (context, index) {
                  final option = _options[index];
                  final isSelected = _selectedDestination == option.id;

                  return AppCard(
                    variant: isSelected
                        ? AppCardVariant.elevated
                        : AppCardVariant.outlined,
                    tint: isSelected
                        ? AppCardTint.primary
                        : AppCardTint.neutral,
                    interactive: true,
                    onTap: () => _onDestinationTapped(option.id),
                    padding: AppCardPadding.md,
                    child: Row(
                      children: [
                        AppIcon(name: option.icon),
                        const SizedBox(width: MitlistSpacing.sm),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                option.label,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              Text(
                                option.description,
                                style: Theme.of(context).textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                        if (isSelected)
                          const AppIcon(
                            name: 'check',
                            color: MitlistColors.primary500,
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(MitlistSpacing.md),
          child: AppButton(
            text: 'Save',
            onPressed: (_selectedDestination != null && !_isSaving) ? _onSave : null,
          ),
        ),
      ),
    );
  }
}
