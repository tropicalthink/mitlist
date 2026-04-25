import 'package:flutter/material.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icon.dart';

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

class ShareTargetScreen extends StatefulWidget {
  const ShareTargetScreen({super.key});

  @override
  State<ShareTargetScreen> createState() => _ShareTargetScreenState();
}

class _ShareTargetScreenState extends State<ShareTargetScreen> {
  String? _selectedDestination;

  static const List<_DestinationOption> _options = [
    _DestinationOption(
      id: 'lists',
      label: 'Lists',
      icon: 'queueList',
      description: 'Save to a shopping or to-do list',
    ),
    _DestinationOption(
      id: 'vault',
      label: 'Vault',
      icon: 'safe',
      description: 'Store in the household vault',
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

  void _onSave() {
    if (_selectedDestination == null) return;
    // TODO: wire up save logic and navigation.
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
                          'Shared content will appear here when integrated '
                          'with the share extension.',
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
            onPressed: _selectedDestination != null ? _onSave : null,
          ),
        ),
      ),
    );
  }
}
