import 'package:flutter/material.dart';

import '../../models/list_models.dart';
import '../../theme/animations.dart';
import '../../theme/spacing.dart';
import '../app_button.dart';
import '../app_icon.dart';
import '../chip.dart';

class ListComposerBar extends StatelessWidget {
  const ListComposerBar({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onAdd,
    required this.onScan,
    this.productSuggestions = const [],
    this.showProductSuggestions = false,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onAdd;
  final VoidCallback onScan;
  final List<Product> productSuggestions;
  final bool showProductSuggestions;

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final fill = brightness == Brightness.dark
        ? Theme.of(context).colorScheme.onSurface
        : Theme.of(context).colorScheme.surface;

    return SafeArea(
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).colorScheme.outline,
              width: 2,
            ),
          ),
        ),
        padding: const EdgeInsets.fromLTRB(
          MitlistSpacing.md,
          MitlistSpacing.sm,
          MitlistSpacing.md,
          MitlistSpacing.md,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSize(
              duration: MitlistAnimations.micro,
              curve: MitlistAnimations.easeEnter,
              child: showProductSuggestions && productSuggestions.isNotEmpty
                  ? Padding(
                      padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
                      child: SizedBox(
                        height: 32,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: productSuggestions.length,
                          separatorBuilder: (_, __) =>
                              const SizedBox(width: MitlistSpacing.sm),
                          itemBuilder: (context, index) {
                            final product = productSuggestions[index];
                            return AppChip(
                              label: product.name,
                              onSelected: (_) {
                                controller.text = product.name;
                                onAdd();
                              },
                            );
                          },
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: controller,
                    focusNode: focusNode,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => onAdd(),
                    minLines: 1,
                    maxLines: 3,
                    decoration: InputDecoration(
                      labelText: 'New item',
                      hintText: 'e.g. Milk, 2 avocados, or 500g flour',
                      filled: true,
                      fillColor: fill,
                    ),
                  ),
                ),
                const SizedBox(width: MitlistSpacing.sm),
                AppButton(
                  icon: AppIcon(
                    name: 'camera',
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                  variant: AppButtonVariant.outline,
                  onPressed: onScan,
                  size: AppButtonSize.lg,
                  tooltip: 'Scan list',
                ),
                const SizedBox(width: MitlistSpacing.sm),
                AppButton(
                  icon: AppIcon(
                    name: 'plus',
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                  onPressed: onAdd,
                  size: AppButtonSize.lg,
                  tooltip: 'Add item',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
