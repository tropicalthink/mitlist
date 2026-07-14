import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/grocery_provider.dart';
import '../providers/list_provider.dart' show grocerySeedProvider;
import '../services/scan/grocery_suggestion_service.dart';
import '../theme/animations.dart';
import '../theme/spacing.dart';
import 'app_input.dart';
import 'chip.dart';

/// A text field with live, offline grocery autocomplete over the canonical
/// seed. As the user types, alias-powered suggestions (e.g. "mlch" → Milch)
/// appear as chips above the field. Tapping a chip fills the canonical name
/// and, if [submitOnSelect] is set, invokes [onSelected] so callers can add /
/// dismiss immediately.
class GrocerySuggestionField extends ConsumerStatefulWidget {
  const GrocerySuggestionField({
    super.key,
    required this.controller,
    required this.groupId,
    this.label,
    this.focusNode,
    this.maxLength,
    this.onSubmitted,
    this.onSelected,
    this.submitOnSelect = false,
  });

  final TextEditingController controller;
  final String groupId;
  final String? label;
  final FocusNode? focusNode;
  final int? maxLength;
  final ValueChanged<String>? onSubmitted;

  /// Called when a suggestion chip is tapped (after the field is filled).
  final ValueChanged<GrocerySuggestion>? onSelected;
  final bool submitOnSelect;

  @override
  ConsumerState<GrocerySuggestionField> createState() =>
      _GrocerySuggestionFieldState();
}

class _GrocerySuggestionFieldState
    extends ConsumerState<GrocerySuggestionField> {
  List<GrocerySuggestion> _suggestions = const [];
  Timer? _debounce;
  int _queryToken = 0;

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    if (value.trim().length < 2) {
      _queryToken++;
      if (_suggestions.isNotEmpty) {
        setState(() => _suggestions = const []);
      }
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 180), () => _query(value));
  }

  Future<void> _query(String value) async {
    final token = ++_queryToken;
    try {
      await ref.read(grocerySeedProvider.future);
      final svc = ref.read(grocerySuggestionServiceProvider);
      final results = await svc.suggest(value, widget.groupId);
      if (!mounted || token != _queryToken) return;
      setState(() => _suggestions = results);
    } catch (_) {
      if (!mounted || token != _queryToken) return;
      setState(() => _suggestions = const []);
    }
  }

  void _select(GrocerySuggestion s) {
    // Preserve the brand/word the user typed ("Pringles") and link the
    // canonical item ("Chips") underneath; only fall back to the canonical
    // name when the typed text is a fragment or typo (see labelForSelection).
    final label = GrocerySuggestionService.labelForSelection(
        widget.controller.text, s.name);
    widget.controller.text = label;
    widget.controller.selection = TextSelection.collapsed(offset: label.length);
    setState(() => _suggestions = const []);
    widget.onSelected?.call(s);
    if (widget.submitOnSelect) widget.onSubmitted?.call(label);
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AnimatedSize(
          duration: MitlistAnimations.micro,
          curve: MitlistAnimations.easeEnter,
          child: _suggestions.isEmpty
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
                  child: SizedBox(
                    height: 32,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) =>
                          const SizedBox(width: MitlistSpacing.sm),
                      itemBuilder: (context, index) {
                        final s = _suggestions[index];
                        return AppChip(
                          label: s.name,
                          onSelected: (_) => _select(s),
                        );
                      },
                    ),
                  ),
                ),
        ),
        AppInput(
          controller: widget.controller,
          focusNode: widget.focusNode,
          label: widget.label,
          maxLength: widget.maxLength,
          textInputAction: TextInputAction.done,
          onChanged: _onChanged,
          onSubmitted: widget.onSubmitted,
        ),
      ],
    );
  }
}
