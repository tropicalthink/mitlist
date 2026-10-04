import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/pinwall_models.dart';
import '../providers/pinwall_provider.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/theme.dart';
import '../utils/haptics.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_toast.dart';

/// Bottom-sheet editor for an existing pinwall note: rewrite the text, pick a
/// sticky-note color, and choose the card size. Saves offline-first through
/// [PinwallRepository.updatePostOfflineFirst]; other members see the change
/// via the pinwall:post_updated broadcast.
Future<void> showPinwallNoteEditorSheet(
  BuildContext context, {
  required String groupId,
  required PinwallPost post,
}) {
  final l10n = AppLocalizations.of(context)!;
  return showAppBottomSheet<void>(
    context: context,
    title: l10n.pinwallEditNote,
    body: _PinwallNoteEditorBody(groupId: groupId, post: post),
  );
}

class _PinwallNoteEditorBody extends ConsumerStatefulWidget {
  const _PinwallNoteEditorBody({required this.groupId, required this.post});

  final String groupId;
  final PinwallPost post;

  @override
  ConsumerState<_PinwallNoteEditorBody> createState() =>
      _PinwallNoteEditorBodyState();
}

class _PinwallNoteEditorBodyState
    extends ConsumerState<_PinwallNoteEditorBody> {
  late final TextEditingController _controller;
  String? _color;
  late String _size;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.post.content);
    _controller.addListener(_onTextChanged);
    _color = widget.post.color;
    _size = widget.post.size ?? 'medium';
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  // Re-evaluate the save button's enabled state as the text changes.
  void _onTextChanged() => setState(() {});

  String _colorLabel(AppLocalizations l10n, String name) {
    return switch (name) {
      'yellow' => l10n.pinwallColorYellow,
      'peach' => l10n.pinwallColorPeach,
      'mint' => l10n.pinwallColorMint,
      'sky' => l10n.pinwallColorSky,
      'blush' => l10n.pinwallColorBlush,
      'lavender' => l10n.pinwallColorLavender,
      _ => name,
    };
  }

  String _sizeLabel(AppLocalizations l10n, String name) {
    return switch (name) {
      'small' => l10n.pinwallNoteSizeSmall,
      'large' => l10n.pinwallNoteSizeLarge,
      _ => l10n.pinwallNoteSizeMedium,
    };
  }

  Future<void> _save() async {
    final l10n = AppLocalizations.of(context)!;
    final content = _controller.text.trim();
    if (content.isEmpty || _isSaving) return;
    unawaited(Haptics.light());
    setState(() => _isSaving = true);
    try {
      final repo = await ref.read(pinwallRepositoryProvider.future);
      await repo.updatePostOfflineFirst(
        widget.groupId,
        widget.post.id,
        content: content,
        color: _color ?? '',
        // A medium pick maps to the server default, so store it as "no
        // explicit choice" rather than pinning the note to medium forever.
        size: _size == 'medium' ? '' : _size,
      );
      repo.noteLocalWrite();
      if (mounted) Navigator.of(context).pop();
    } catch (_) {
      if (mounted) {
        setState(() => _isSaving = false);
        AppToast.error(context, l10n.pinwallCouldNotSaveNote);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final textTheme = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final paletteByName = dark
        ? MitlistColors.notePaletteByNameDark
        : MitlistColors.notePaletteByName;
    final canSave = _controller.text.trim().isNotEmpty && !_isSaving;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _controller,
          autofocus: true,
          minLines: 3,
          maxLines: 6,
          maxLength: 2000,
          textInputAction: TextInputAction.newline,
          style: textTheme.bodyMedium?.copyWith(height: 1.5),
          decoration: InputDecoration(
            hintText: l10n.pinwallPostHint,
            counterText: '',
          ),
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          l10n.pinwallNoteColor,
          style: textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Row(
          children: [
            for (final name in kPinwallNoteColors)
              Padding(
                padding: const EdgeInsets.only(right: MitlistSpacing.sm),
                child: _ColorSwatch(
                  color: paletteByName[name]!,
                  label: _colorLabel(l10n, name),
                  selected: _color == name,
                  onTap: () {
                    unawaited(Haptics.light());
                    setState(() => _color = name);
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.md),
        Text(
          l10n.pinwallNoteSize,
          style: textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        Row(
          children: [
            for (final name in kPinwallNoteSizes)
              Padding(
                padding: const EdgeInsets.only(right: MitlistSpacing.sm),
                child: _SizeChip(
                  label: _sizeLabel(l10n, name),
                  selected: _size == name,
                  onTap: () {
                    unawaited(Haptics.light());
                    setState(() => _size = name);
                  },
                ),
              ),
          ],
        ),
        const SizedBox(height: MitlistSpacing.lg),
        AppButton(
          text: l10n.commonSave,
          isLoading: _isSaving,
          onPressed: canSave ? _save : null,
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.color,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final Color color;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      child: Tooltip(
        message: label,
        child: GestureDetector(
          onTap: onTap,
          // 44dp touch target around the visible 32dp swatch.
          child: Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(
                  color: selected ? scheme.primary : MitlistColors.borderSubtle,
                  width: selected ? 3 : 1.5,
                ),
              ),
              child: selected
                  ? Icon(Icons.check, size: 16, color: scheme.primary)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

class _SizeChip extends StatelessWidget {
  const _SizeChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.md,
            vertical: MitlistSpacing.sm,
          ),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected
                ? scheme.primary.withValues(alpha: 0.12)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(MitlistTheme.radiusSm),
            border: Border.all(
              color: selected ? scheme.primary : MitlistColors.borderSubtle,
              width: selected ? 2 : 1.5,
            ),
          ),
          child: Text(
            label,
            style: textTheme.labelMedium?.copyWith(
              color: selected ? scheme.primary : scheme.onSurface,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
    );
  }
}
