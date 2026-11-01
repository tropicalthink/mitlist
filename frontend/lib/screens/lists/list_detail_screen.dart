import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../../models/list_models.dart';
import '../../repositories/outbox_error_classifier.dart';
import '../../services/restock_service.dart';
import '../../theme/animations.dart';
import '../../theme/list_tile_accent.dart';
import '../../theme/spacing.dart';
import '../../theme/theme.dart';
import '../../utils/format_currency.dart';
import '../../utils/haptics.dart';
import '../../utils/friendly_error.dart';
import '../../utils/reminder_picker.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_toast.dart';
import '../../sheets/cost_summary_sheet.dart';
import '../../widgets/list/list_all_done_panel.dart';
import '../../widgets/list/list_composer_bar.dart';
import '../../widgets/list/list_detail_skeleton.dart';
import '../../utils/list_composer_parser.dart';
import '../../widgets/list/list_detail_states.dart';
import '../../widgets/list/list_done_section_header.dart';
import '../../widgets/list/list_group_banner.dart';
import '../../widgets/list/list_item_edit_sheet.dart';
import '../../widgets/list/list_item_photo_viewer.dart';
import '../../widgets/list/list_item_line.dart';
import '../../widgets/list/list_scan_launcher.dart';
import '../../widgets/list/list_settle_collapse.dart';
import '../../widgets/list/running_low_lines.dart';
import '../../l10n/app_localizations.dart';
import '../../widgets/mitlist_app_bar.dart';
import 'list_detail_controller.dart';

/// Optional [GoRouter] `extra` when opening a list from the hub (title shows immediately).
class ListDetailRouteArgs {
  const ListDetailRouteArgs({
    this.listName,
    this.autoFocusTitle = false,
    this.autoFocusComposer = false,
  });
  final String? listName;
  final bool autoFocusTitle;

  /// Land with the item composer focused — the "add an item to this list"
  /// entry point from a list card.
  final bool autoFocusComposer;
}

class ListDetailScreen extends ConsumerStatefulWidget {
  final String listId;
  final String? initialListName;
  final bool autoFocusTitle;
  final bool autoFocusComposer;

  const ListDetailScreen({
    super.key,
    required this.listId,
    this.initialListName,
    this.autoFocusTitle = false,
    this.autoFocusComposer = false,
  });

  @override
  ConsumerState<ListDetailScreen> createState() => _ListDetailScreenState();
}

class _ListDetailScreenState extends ConsumerState<ListDetailScreen> {
  late ListDetailController _controller;
  bool _showSearch = false;

  /// The item whose words are being edited in place, if any. One at a time,
  /// with its own controller so live updates to the list never overwrite
  /// what is being typed.
  String? _editingItemId;

  /// The typed-suggestion lines under the add line, kept scrolled into view
  /// above the keyboard as they arrive.
  final GlobalKey _typedSuggestionsKey = GlobalKey();

  /// Words are on the add line and it has the keyboard: typed suggestions
  /// show, and the "you might also need" lines step aside for them.
  bool _wasTyping = false;

  bool get _typingAnItem =>
      _showProductSuggestions && _newItemController.text.trim().isNotEmpty;
  final TextEditingController _editController = TextEditingController();
  final FocusNode _editFocusNode = FocusNode();
  final TextEditingController _newItemController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _titleController = TextEditingController();
  final FocusNode _titleFocusNode = FocusNode();
  final FocusNode _composerFocusNode = FocusNode();
  bool _editingTitle = false;
  bool _showProductSuggestions = false;
  String? _pendingCanonicalId;

  /// What was typed when a suggestion was picked, so the pick can teach the
  /// resolver that word.
  String? _pendingTypedQuery;

  /// Operation-scoped re-entrancy guards. Unrelated work (for example adding
  /// an item while another row's photo uploads) must not silently block the
  /// entire screen.
  final Set<String> _activeOperations = {};
  int _operationGeneration = 0;

  /// Guards the one-shot early composer focus for the quick-add entry so it
  /// fires once, as soon as the composer exists.
  bool _autoFocusDone = false;

  String _operationKey(String key) => '$_operationGeneration:$key';

  bool _beginOperation(String key) => _activeOperations.add(key);

  void _finishOperation(String key) => _activeOperations.remove(key);

  bool _isOperationActive(String key) => _activeOperations.contains(key);

  @override
  void initState() {
    super.initState();
    _controller = ListDetailController(
      ref: ref,
      listId: widget.listId,
      initialListName: widget.initialListName,
    )..addListener(_onControllerChanged);
    _composerFocusNode.addListener(_onComposerFocusChanged);
    _newItemController.addListener(_onComposerTextChanged);
    _titleFocusNode.addListener(_onTitleFocusChanged);
    _editFocusNode.addListener(_onEditFocusChanged);
    _controller.suggestionsRevision.addListener(_revealTypedSuggestions);
    if (widget.autoFocusTitle) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _startEditingTitle());
    }
    _runLoad();
  }

  void _onControllerChanged() {
    if (!mounted) return;
    setState(() {});
    // Quick-add (autoFocusComposer) should let you type the moment the composer
    // appears — i.e. right after the cached items load — not after the whole
    // detail finishes its network refresh + SSE + grocery seed. `_runLoad`'s
    // post-load focus below stays as a fallback for the uncached case.
    if (widget.autoFocusComposer &&
        !_autoFocusDone &&
        !_controller.isLoading &&
        !_controller.hasError) {
      _autoFocusDone = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focusComposer();
      });
    }
  }

  /// Focuses the item composer and brings up the keyboard. Opened from
  /// outside the app (a home screen widget's "+", an app icon shortcut), the
  /// route is built before the app is back in the foreground, and Android
  /// drops a keyboard request made before its window has input focus; the
  /// keyboard is asked for again once the app has resumed.
  void _focusComposer() {
    FocusScope.of(context).requestFocus(_composerFocusNode);
    void show() {
      if (mounted &&
          _composerFocusNode.hasFocus &&
          MediaQuery.viewInsetsOf(context).bottom == 0) {
        // Hide first: Android can still think the keyboard is requested
        // from before the app went to the background, and then ignores a
        // plain show.
        SystemChannels.textInput.invokeMethod<void>('TextInput.hide').then(
            (_) =>
                SystemChannels.textInput.invokeMethod<void>('TextInput.show'));
      }
    }

    if (WidgetsBinding.instance.lifecycleState != AppLifecycleState.resumed) {
      late final AppLifecycleListener listener;
      listener = AppLifecycleListener(onResume: () {
        listener.dispose();
        Future<void>.delayed(const Duration(milliseconds: 250), show);
      });
    }
    Future<void>.delayed(const Duration(milliseconds: 600), show);
  }

  /// Runs the controller load, then pops the keyboard only for an empty list
  /// (the next step is clearly typing). On a populated list it would cover the
  /// items people came to read.
  Future<void> _runLoad() async {
    final controller = _controller;
    await controller.load();
    if (!mounted || !identical(_controller, controller)) return;
    if (controller.consumeRefreshFailure()) {
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listDetailCouldNotLoad)),
      );
    }
    // A populated cached list can expose the composer before the remote list
    // metadata (and therefore group id) has arrived. If the user focused the
    // field in that window, the first suggestion request was intentionally a
    // no-op; retry it now that load has resolved the metadata.
    if (_composerFocusNode.hasFocus) {
      unawaited(_controller.refreshSuggestions(_newItemController.text));
    }
    if (!_controller.hasError &&
        !_autoFocusDone &&
        (_controller.items.isEmpty || widget.autoFocusComposer)) {
      _autoFocusDone = true;
      _focusComposer();
    }
  }

  /// Scrolls just enough that the last typed suggestion clears the keyboard.
  void _revealTypedSuggestions() {
    if (!_typingAnItem) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final target = _typedSuggestionsKey.currentContext;
      if (!mounted || target == null || !_typingAnItem) return;
      unawaited(Scrollable.ensureVisible(
        target,
        duration: MediaQuery.of(context).disableAnimations
            ? Duration.zero
            : MitlistAnimations.micro,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      ));
    });
  }

  void _onComposerFocusChanged() {
    if (_composerFocusNode.hasFocus) {
      _controller.refreshSuggestions(_newItemController.text);
      setState(() => _showProductSuggestions = true);
    } else {
      setState(() => _showProductSuggestions = false);
    }
  }

  void _onComposerTextChanged() {
    // Any edit invalidates a previously tapped suggestion's canonical link.
    // A chip tap sets the text first (running this) and the id after, so the
    // suggestion flow itself is unaffected.
    _pendingCanonicalId = null;
    _pendingTypedQuery = null;
    // The first letter swaps "you might also need" for typed suggestions,
    // and clearing the line swaps them back.
    final typing = _typingAnItem;
    if (typing != _wasTyping) setState(() => _wasTyping = typing);
    if (!_composerFocusNode.hasFocus) return;
    _controller.refreshSuggestionsDebounced(_newItemController.text);
  }

  void _startEditingTitle() {
    final name = _controller.listName;
    _titleController.text = name;
    _titleController.selection =
        TextSelection(baseOffset: 0, extentOffset: name.length);
    setState(() => _editingTitle = true);
    _titleFocusNode.requestFocus();
  }

  void _onTitleFocusChanged() {
    if (!_titleFocusNode.hasFocus && _editingTitle) {
      _submitTitleEdit();
    }
  }

  Future<void> _submitTitleEdit() async {
    final newName = _titleController.text.trim();
    setState(() => _editingTitle = false);
    if (newName.isEmpty || newName == _controller.listName) return;
    try {
      await _controller.renameList(newName);
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listCouldNotRename)),
      );
    }
  }

  @override
  void didUpdateWidget(covariant ListDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.listId != widget.listId) {
      // Cancel every transient interaction before swapping controllers. The
      // State object may be reused by the router, but none of the old list's
      // draft, focus, or operation state may follow it to the new list.
      _editingTitle = false;
      _showProductSuggestions = false;
      _pendingCanonicalId = null;
      _pendingTypedQuery = null;
      _autoFocusDone = false;
      _operationGeneration++;
      _activeOperations.clear();
      _titleFocusNode.unfocus();
      _composerFocusNode.unfocus();
      _newItemController.clear();
      _titleController.clear();
      _controller
        ..removeListener(_onControllerChanged)
        ..dispose();
      _showSearch = false;
      _searchController.clear();
      _controller = ListDetailController(
        ref: ref,
        listId: widget.listId,
        initialListName: widget.initialListName,
      )..addListener(_onControllerChanged);
      if (widget.autoFocusTitle) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _startEditingTitle();
        });
      }
      _runLoad();
      return;
    }
    if (widget.initialListName != null &&
        widget.initialListName!.isNotEmpty &&
        widget.initialListName != oldWidget.initialListName) {
      _controller.setListName(widget.initialListName!);
    }
  }

  @override
  void dispose() {
    _composerFocusNode.removeListener(_onComposerFocusChanged);
    _newItemController.removeListener(_onComposerTextChanged);
    _titleFocusNode.removeListener(_onTitleFocusChanged);
    _editFocusNode.removeListener(_onEditFocusChanged);
    _controller.suggestionsRevision.removeListener(_revealTypedSuggestions);
    _controller
      ..removeListener(_onControllerChanged)
      ..dispose();
    _newItemController.dispose();
    _searchController.dispose();
    _titleController.dispose();
    _composerFocusNode.dispose();
    _titleFocusNode.dispose();
    _editController.dispose();
    _editFocusNode.dispose();
    super.dispose();
  }

  /// True for failures that only a connection fixes: the request never
  /// reached the server, or the list has not synced to it yet.
  static bool _needsConnection(Object error) =>
      error is ListNotSyncedException ||
      classifyOutboxError(error) == OutboxErrorDisposition.unreachable;

  Future<void> _addItemPhoto(ListItem item) async {
    final operation = _operationKey('item:${item.id}');
    if (!_beginOperation(operation)) return;
    try {
      await _controller.addItemPhoto(item);
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_needsConnection(e)
                ? l10n.commonCheckConnection
                : l10n.listDetailCouldNotAddPhoto),
          ),
        );
      }
    } finally {
      _finishOperation(operation);
    }
  }

  Future<void> _removeItemPhoto(ListItem item) async {
    final operation = _operationKey('item:${item.id}');
    if (!_beginOperation(operation)) return;
    try {
      await _controller.removeItemPhoto(item);
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(_needsConnection(e)
                ? l10n.commonCheckConnection
                : l10n.listDetailCouldNotRemovePhoto),
          ),
        );
      }
    } finally {
      _finishOperation(operation);
    }
  }

  Future<void> _toggleItem(ListItem item, bool value) async {
    if (_editingItemId != null) unawaited(_commitEdit());
    final operation = _operationKey('toggle:${item.id}');
    if (!_beginOperation(operation)) return;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    try {
      await _controller.toggleItem(item, value,
          disableAnimations: disableAnimations);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listDetailCouldNotUpdate)),
      );
    } finally {
      _finishOperation(operation);
    }
  }

  Future<void> _completeAll() async {
    final operation = _operationKey('bulk');
    if (!_beginOperation(operation)) return;
    try {
      await _controller.completeAll();
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.listDetailCouldNotUpdate)),
        );
      }
    } finally {
      _finishOperation(operation);
    }
  }

  Future<void> _uncheckAll() async {
    final operation = _operationKey('bulk');
    if (!_beginOperation(operation)) return;
    try {
      await _controller.uncheckAll();
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.listDetailCouldNotUpdate)),
        );
      }
    } finally {
      _finishOperation(operation);
    }
  }

  Future<void> _addItem() async {
    final operation = _operationKey('composer');
    if (!_beginOperation(operation)) return;
    final text = _newItemController.text.trim();
    if (text.isEmpty) {
      _finishOperation(operation);
      return;
    }
    final canonicalId = _pendingCanonicalId;
    final typedQuery = _pendingTypedQuery;
    _pendingCanonicalId = null;
    _pendingTypedQuery = null;
    unawaited(Haptics.light());
    // addItem publishes a pending row synchronously before its first database
    // await, so by the time this returns the future the row is already visible.
    // Clear only after that publish, so there is never a frame where the value
    // is visible in neither place.
    final addFuture = _controller.addItem(
      text,
      canonicalItemId: canonicalId,
      pickedFromQuery: canonicalId == null ? null : typedQuery,
    );
    if (_newItemController.text.trim() == text) {
      _newItemController.clear();
    }
    if (mounted) _composerFocusNode.requestFocus();
    // Release the submit guard now — the row is on screen and the field is
    // clear, so the user can immediately queue the next item. We deliberately
    // do NOT hold it across `addFuture`: the local persistence can take many
    // seconds when a large background write (e.g. the first-run grocery seed's
    // FTS rebuild) is holding the shared DB connection, and blocking the
    // composer on it is what made adds feel serialized. The row is optimistic
    // and the write is durable via the outbox, so nothing is lost by letting it
    // settle in the background.
    _finishOperation(operation);
    try {
      final outcome = await addFuture;
      if (!mounted) return;
      _reportAddOutcome(outcome, parseComposerItem(text).name);
    } catch (e) {
      if (!mounted) return;
      // Only restore if the field is still empty — the user may have already
      // typed the next item into the cleared composer.
      if (_newItemController.text.trim().isEmpty) {
        _newItemController.text = text;
        _newItemController.selection =
            TextSelection.collapsed(offset: text.length);
        _pendingCanonicalId = canonicalId;
        _pendingTypedQuery = typedQuery;
      }
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listDetailCouldNotAddItem)),
      );
    }
  }

  /// Surfaces the adds that landed on a row the list already had — silence
  /// there reads as a dropped add, since no new row appears.
  void _reportAddOutcome(AddItemOutcome outcome, String name) {
    final l10n = AppLocalizations.of(context)!;
    final message = switch (outcome) {
      AddItemOutcome.restored => l10n.listDetailItemRestored(name),
      AddItemOutcome.alreadyOnList => l10n.listDetailItemAlreadyOnList(name),
      AddItemOutcome.created || AddItemOutcome.increased => null,
    };
    if (message == null) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _addRestockSuggestion(RestockSuggestion suggestion) async {
    final operation = _operationKey('restock:${suggestion.canonicalItemId}');
    if (!_beginOperation(operation)) return;
    try {
      final outcome = await _controller.addRestockSuggestion(suggestion);
      if (!mounted) return;
      _reportAddOutcome(outcome, suggestion.name);
      unawaited(Haptics.light());
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listDetailCouldNotAddItem)),
      );
    } finally {
      _finishOperation(operation);
    }
  }

  Future<void> _clearItems({required bool onlyChecked}) async {
    final operation = _operationKey('bulk');
    if (!_beginOperation(operation)) return;
    if (!onlyChecked) {
      final count = _controller.items.length;
      final l10n = AppLocalizations.of(context)!;
      final confirmed = await showAppDialog<bool>(
        context: context,
        title: l10n.listDetailClearTitle,
        body: Text(
          l10n.listDetailClearBody(count),
        ),
        actions: [
          AppButton(
            text: l10n.commonCancel,
            variant: AppButtonVariant.outline,
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(false),
          ),
          const SizedBox(width: MitlistSpacing.sm),
          AppButton(
            text: l10n.listDetailClearConfirm,
            color: AppButtonColor.error,
            onPressed: () =>
                Navigator.of(context, rootNavigator: true).pop(true),
          ),
        ],
      );
      if (confirmed != true || !mounted) {
        _finishOperation(operation);
        return;
      }
    }
    try {
      await _controller.clearItems(onlyChecked: onlyChecked);
    } catch (e) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.listDetailCouldNotClear)),
        );
      }
    } finally {
      _finishOperation(operation);
    }
  }

  Future<void> _deleteItem(ListItem item) async {
    final operation = _operationKey('item:${item.id}');
    if (!_beginOperation(operation)) return;
    var deleted = false;
    try {
      await _controller.deleteItem(item);
      deleted = true;
    } catch (e) {
      if (mounted) {
        unawaited(Haptics.failure());
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content:
                  Text(friendlyErrorMessage(e, AppLocalizations.of(context)!))),
        );
      }
    } finally {
      _finishOperation(operation);
    }
    if (!deleted || !mounted) return;
    AppToast.undo(
      context,
      message: AppLocalizations.of(context)!.listDetailItemDeleted(item.name),
      onUndo: () => _restoreDeletedItem(item),
    );
  }

  Future<void> _restoreDeletedItem(ListItem item) async {
    try {
      await _controller.restoreDeletedItem(item);
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listDetailCouldNotRestore)),
      );
    }
  }

  void _onMenuSelected(String value) {
    switch (value) {
      case 'rename':
        _startEditingTitle();
        break;
      case 'complete_all':
        _completeAll();
        break;
      case 'uncheck_all':
        _uncheckAll();
        break;
      case 'clear_all':
        _clearItems(onlyChecked: false);
        break;
      case 'cost_summary':
        _showCostSummary();
        break;
      case 'reminder':
        _pickReminder();
        break;
      case 'clear_reminder':
        _clearReminder();
        break;
      case 'archive':
        _archiveList();
        break;
      case 'delete':
        _deleteList();
        break;
    }
  }

  String _formatReminder(DateTime at) {
    final locale = Localizations.localeOf(context).toString();
    return DateFormat.MMMEd(locale).add_jm().format(at);
  }

  /// Schedules (or reschedules) the household reminder for this list. The
  /// date/time pickers enforce a future time locally, so the only failure the
  /// user can hit here is the network, which gets the generic reminder toast.
  Future<void> _pickReminder() async {
    final operation = _operationKey('list-reminder');
    if (!_beginOperation(operation)) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      final picked = await pickReminderDateTime(
        context,
        initial: _controller.remindAt,
      );
      if (!mounted || picked == null) return;
      unawaited(Haptics.light());
      await _controller.setReminder(picked);
      if (!mounted) return;
      AppToast.success(
          context, l10n.listReminderSaved(_formatReminder(picked)));
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, l10n.listReminderCouldNotSave);
    } finally {
      _finishOperation(operation);
    }
  }

  Future<void> _clearReminder() async {
    final operation = _operationKey('list-reminder');
    if (!_beginOperation(operation)) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      unawaited(Haptics.light());
      await _controller.setReminder(null);
      if (!mounted) return;
      AppToast.info(context, l10n.listReminderCleared);
    } catch (_) {
      if (!mounted) return;
      AppToast.error(context, l10n.listReminderCouldNotSave);
    } finally {
      _finishOperation(operation);
    }
  }

  Future<void> _archiveList() async {
    final operation = _operationKey('list-lifecycle');
    if (!_beginOperation(operation)) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: l10n.listDetailArchiveTitle,
      body: Text(l10n.listDetailArchiveBody),
      actions: [
        AppButton(
          text: l10n.commonCancel,
          variant: AppButtonVariant.outline,
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: l10n.commonArchive,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) {
      _finishOperation(operation);
      return;
    }
    try {
      final ok = await _controller.archiveList();
      if (!mounted) return;
      if (ok) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.listDetailFailedArchive)),
        );
      }
    } finally {
      _finishOperation(operation);
    }
  }

  Future<void> _deleteList() async {
    final operation = _operationKey('list-lifecycle');
    if (!_beginOperation(operation)) return;
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: l10n.listDetailDeleteTitle,
      body: Text(l10n.listDetailDeleteBody),
      actions: [
        AppButton(
          text: l10n.commonCancel,
          variant: AppButtonVariant.outline,
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        AppButton(
          text: l10n.commonDelete,
          color: AppButtonColor.error,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    if (confirmed != true || !mounted) {
      _finishOperation(operation);
      return;
    }
    try {
      final ok = await _controller.deleteList();
      if (!mounted) return;
      if (ok) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.listDetailCouldNotDelete)),
        );
      }
    } finally {
      _finishOperation(operation);
    }
  }

  Future<void> _showCostSummary() async {
    if (!_controller.isReady) return;
    final l10n = AppLocalizations.of(context)!;
    try {
      final summary = await _controller.getCostSummary();
      final totalCents = summary['total_cents'] as int? ?? 0;
      final equalShareCents = summary['equal_share_cents'] as int? ?? 0;
      final pricedItems =
          _controller.items.where((i) => i.priceCents != null).length;

      if (!mounted) return;
      await CostSummarySheet.show(
        context,
        listName: _controller.listName,
        totalCents: totalCents,
        equalShareCents: equalShareCents,
        itemCount: pricedItems,
        currencyCode: _controller.groupCurrency,
        onGenerateExpense: totalCents > 0
            ? () async {
                final operation = _operationKey('generate-expense');
                if (!_beginOperation(operation)) return;
                try {
                  await _controller.generateExpense();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.listDetailExpenseGenerated)),
                    );
                  }
                } catch (e) {
                  if (mounted) {
                    final l10n = AppLocalizations.of(context)!;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text(_needsConnection(e)
                              ? l10n.commonCheckConnection
                              : friendlyErrorMessage(e, l10n))),
                    );
                  }
                } finally {
                  _finishOperation(operation);
                }
              }
            : null,
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.listDetailCouldNotLoadCostSummary)),
        );
      }
    }
  }

  Future<void> _onReorder(int oldIndex, int newIndex) async {
    try {
      await _controller.reorderOpen(oldIndex, newIndex);
    } catch (e) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.listDetailCouldNotReorder),
        ),
      );
    }
  }

  Future<void> _launchScan({ImageSource? source}) async {
    final groupId = _controller.groupId;
    final userId = await _controller.ensureUserId();
    if (groupId == null || userId == null) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listDetailCouldNotStartScan)),
      );
      return;
    }
    if (!mounted) return;
    final addedCount = await launchListScan(
      context,
      ref,
      groupId: groupId,
      userId: userId,
      listId: _controller.listId,
      listName: _controller.listName.isNotEmpty ? _controller.listName : null,
      source: source,
    );
    if (!mounted || addedCount == null || addedCount <= 0) return;
    final l10n2 = AppLocalizations.of(context)!;
    final message = l10n2.listDetailItemsAdded(addedCount);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Long-press: one sheet edits everything about the item. Whatever the
  /// fields hold when it closes is saved in one write; a photo or delete
  /// picked there runs after.
  Future<void> _editItem(ListItem item) async {
    final operation = _operationKey('item:${item.id}');
    if (!_beginOperation(operation)) return;
    final l10n = AppLocalizations.of(context)!;
    final photos = _controller.photosFor(item.id);
    final hasPhoto = photos != null && photos.isNotEmpty;

    final ListItemSheetResult result;
    try {
      result = await ListItemEditSheet.show(
        context,
        item: item,
        hasPhoto: hasPhoto,
        currencySymbol: currencySymbol(_controller.groupCurrency),
      );
    } catch (_) {
      _finishOperation(operation);
      rethrow;
    }

    final draft = result.draft;
    final name = draft.name.trim();
    final amount = double.tryParse(draft.amount.trim().replaceAll(',', '.'));
    final unit = draft.unit.trim();
    final note = draft.note.trim();
    final priceText = draft.price.trim().replaceAll(',', '.');
    final price = priceText.isEmpty ? 0.0 : double.tryParse(priceText);
    final priceCents =
        price == null || price < 0 ? null : (price * 100).round();
    final oldPriceCents = item.priceCents ?? 0;

    final nameChanged = name.isNotEmpty && name != item.name;
    final amountChanged =
        amount != null && amount > 0 && amount != item.quantity;
    final unitChanged = unit != item.unit;
    final noteChanged = note != item.note;
    final priceChanged = priceCents != null && priceCents != oldPriceCents;
    final deleting = result.action == ListItemSheetAction.delete;

    if (!deleting &&
        (nameChanged ||
            amountChanged ||
            unitChanged ||
            noteChanged ||
            priceChanged)) {
      try {
        await _controller.updateItemFields(
          item,
          name: nameChanged ? name : null,
          quantity: amountChanged ? amount : null,
          unit: unitChanged ? unit : null,
          note: noteChanged ? note : null,
          priceCents: priceChanged ? priceCents : null,
        );
      } catch (_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.listDetailCouldNotUpdate)),
          );
        }
      }
    }
    if (priceCents == null && !deleting && mounted) {
      // An unreadable price is dropped, not guessed at; say so.
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.listDetailCouldNotSetPrice)),
      );
    }
    _finishOperation(operation);
    if (!mounted) return;

    switch (result.action) {
      case null:
        break;
      case ListItemSheetAction.viewPhoto:
        final viewPhotos = _controller.photosFor(item.id);
        if (viewPhotos != null && viewPhotos.isNotEmpty) {
          await ListItemPhotoViewer.show(context, viewPhotos.first.url);
        }
      case ListItemSheetAction.photo:
        await _addItemPhoto(item);
      case ListItemSheetAction.removePhoto:
        await _removeItemPhoto(item);
      case ListItemSheetAction.delete:
        await _deleteItem(item);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    // The search row hosts a text field, so its slot must grow with the
    // user's font scale or the field clips.
    final searchRowHeight = MediaQuery.textScalerOf(context).scale(52.0);
    // The reminder banner sits inside the app bar's preferred size too, so
    // the header must grow for it or the row overflows into the body.
    final reminderRowHeight = _reminderRowHeight(context);
    final headerHeight = kToolbarHeight +
        6 +
        (_controller.hasPendingReminder ? reminderRowHeight : 0) +
        (_showSearch ? searchRowHeight : 0);

    return PopScope(
      // System back closes transient editing states (search, title edit)
      // before it may leave the screen, matching the in-app back arrow.
      canPop: !_showSearch && !_editingTitle && _editingItemId == null,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (_editingItemId != null) {
          _editFocusNode.unfocus();
          unawaited(_commitEdit());
        } else if (_editingTitle) {
          // Drop editing state before unfocusing so the blur listener doesn't
          // treat this cancel as a submit.
          setState(() => _editingTitle = false);
          _titleFocusNode.unfocus();
        } else if (_showSearch) {
          _closeSearch();
        }
      },
      child: _buildScaffold(l10n, headerHeight),
    );
  }

  Widget _buildScaffold(AppLocalizations l10n, double headerHeight) {
    final accent = ListTileAccent.fromSeed(
      widget.listId,
      Theme.of(context).brightness,
    );
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(headerHeight),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MitlistAppBar(
              showStandardActions: false,
              leading: IconButton(
                icon: const AppIcon(name: 'arrowLeft'),
                tooltip: l10n.commonBack,
                onPressed: () => Navigator.of(context).pop(_controller.dirty),
              ),
              title: _editingTitle
                  ? TextField(
                      controller: _titleController,
                      focusNode: _titleFocusNode,
                      autofocus: true,
                      textInputAction: TextInputAction.done,
                      style: Theme.of(context).textTheme.titleMedium,
                      decoration: const InputDecoration(
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                      onSubmitted: (_) => _submitTitleEdit(),
                    )
                  : Semantics(
                      button: true,
                      label: l10n.listDetailEditName(_controller.listName),
                      child: GestureDetector(
                        onTap: _startEditingTitle,
                        child: Text(
                          _controller.listName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
              actions: [
                IconButton(
                  icon: AppIcon(
                    name: 'magnifyingGlass',
                    color: _showSearch
                        ? Theme.of(context).colorScheme.primary
                        : null,
                  ),
                  tooltip: _showSearch
                      ? l10n.listDetailCloseSearch
                      : l10n.listDetailSearchTooltip,
                  onPressed: () {
                    unawaited(Haptics.light());
                    if (_showSearch) {
                      _closeSearch();
                    } else {
                      setState(() => _showSearch = true);
                    }
                  },
                ),
                PopupMenuButton<String>(
                  icon: const AppIcon(name: 'ellipsisVertical'),
                  tooltip: l10n.listOptionsTooltip,
                  onSelected: _onMenuSelected,
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'rename',
                      child: Text(l10n.commonRename),
                    ),
                    PopupMenuItem(
                      value: 'cost_summary',
                      child: Text(l10n.listDetailCostSummary),
                    ),
                    PopupMenuItem(
                      value: 'reminder',
                      child: Text(
                        _controller.hasPendingReminder
                            ? l10n.listReminderMenuChange
                            : l10n.listReminderMenuSet,
                      ),
                    ),
                    if (_controller.hasPendingReminder)
                      PopupMenuItem(
                        value: 'clear_reminder',
                        child: Text(l10n.listReminderMenuClear),
                      ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'complete_all',
                      child: Text(l10n.listDetailCheckAll),
                    ),
                    PopupMenuItem(
                      value: 'uncheck_all',
                      child: Text(l10n.listDetailUncheckAll),
                    ),
                    PopupMenuItem(
                      value: 'clear_all',
                      child: Text(l10n.listDetailClearTitle),
                    ),
                    const PopupMenuDivider(),
                    PopupMenuItem(
                      value: 'archive',
                      child: Text(l10n.commonArchive),
                    ),
                    PopupMenuItem(
                      value: 'delete',
                      child: Text(
                        l10n.commonDelete,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: Theme.of(context).colorScheme.error,
                            ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            _buildProgressStripe(accent),
            if (_controller.hasPendingReminder) _buildReminderChip(),
            if (_showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  MitlistSpacing.md,
                  MitlistSpacing.xs,
                  MitlistSpacing.md,
                  MitlistSpacing.sm,
                ),
                child: TextField(
                  controller: _searchController,
                  autofocus: true,
                  decoration: InputDecoration(
                    labelText: l10n.listDetailFilterLabel,
                    hintText: l10n.listDetailFilterHint,
                    isDense: true,
                  ),
                  onChanged: (value) => _controller.setSearchQuery(value),
                ),
              ),
          ],
        ),
      ),
      body: Column(
        children: [
          if (_controller.groupId != null)
            ListGroupBanner(groupId: _controller.groupId!),
          Expanded(child: _buildBody()),
        ],
      ),
    );
  }

  /// The list's 6px accent stripe doubling as a progress bar: the filled
  /// portion tracks checked-off items so "how far along is this list" is
  /// visible from the header ("what's due, clearly"). An empty list renders
  /// the faint track only, keeping the stripe as the list's identity mark.
  Widget _buildProgressStripe(ListTileAccent accent) {
    final l10n = AppLocalizations.of(context)!;
    final total = _controller.items.length;
    final done = _controller.items.where((i) => i.checked).length;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    return Semantics(
      label: total == 0 ? null : l10n.listDetailProgress(done, total),
      child: Container(
        height: 6,
        width: double.infinity,
        color: accent.stripe.withValues(alpha: 0.25),
        alignment: Alignment.centerLeft,
        child: AnimatedFractionallySizedBox(
          duration:
              disableAnimations ? Duration.zero : MitlistAnimations.medium,
          curve: MitlistTheme.easeSettle,
          alignment: Alignment.centerLeft,
          widthFactor: total == 0 ? 0 : (done / total).clamp(0.0, 1.0),
          heightFactor: 1,
          child: ColoredBox(color: accent.stripe),
        ),
      ),
    );
  }

  /// Height of the reminder banner. Hosts a single line of label text, so it
  /// scales with the user's font size like the search row does.
  double _reminderRowHeight(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(36.0);

  /// A tinted banner under the stripe showing when the household will be
  /// reminded about this list, styled like the "shared with" banner below
  /// it. Tap to reschedule; the trailing button clears it.
  Widget _buildReminderChip() {
    final l10n = AppLocalizations.of(context)!;
    final remindAt = _controller.remindAt;
    if (remindAt == null) return const SizedBox.shrink();
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final label = l10n.pinwallReminderLabel(_formatReminder(remindAt));
    return SizedBox(
      height: _reminderRowHeight(context),
      width: double.infinity,
      child: Material(
        color: scheme.primaryContainer,
        child: InkWell(
          onTap: _pickReminder,
          child: Semantics(
            button: true,
            label: l10n.listReminderChipTooltip,
            child: Padding(
              padding: const EdgeInsets.only(
                left: MitlistSpacing.md,
                right: MitlistSpacing.sm,
              ),
              child: Row(
                children: [
                  AppIcon(
                    name: 'bellOutline',
                    size: 14,
                    color: scheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: MitlistSpacing.sm),
                  Expanded(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.labelMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: MitlistSpacing.xs),
                  IconButton(
                    icon: AppIcon(
                      name: 'xMark',
                      size: 16,
                      color: scheme.onPrimaryContainer,
                    ),
                    tooltip: l10n.listReminderMenuClear,
                    onPressed: _clearReminder,
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 32,
                      height: 32,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return RefreshIndicator(
      color: Theme.of(context).colorScheme.primary,
      onRefresh: _runLoad,
      child: _buildBodyContent(),
    );
  }

  Widget _wrapForRefresh(Widget child) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildBodyContent() {
    if (_controller.isLoading) {
      return _wrapForRefresh(const ListDetailSkeleton());
    }
    if (_controller.hasError) {
      return _wrapForRefresh(ListDetailErrorView(
        message: AppLocalizations.of(context)!.listDetailCouldNotLoad,
        onRetry: _runLoad,
        // With no usable local snapshot, dismissing into an empty composer
        // produces a screen whose actions cannot succeed. Leave the detail
        // instead; cached lists never enter this full-screen error state.
        onDismiss: () => Navigator.of(context).maybePop(),
      ));
    }

    if (_controller.searchQuery.isNotEmpty) {
      final ordered = _controller.searchOrderedItems;
      if (ordered.isEmpty) {
        return _wrapForRefresh(
            ListDetailSearchEmptyView(onClearSearch: _clearSearch));
      }
      return _buildSearchResultItemList(ordered);
    }

    final open = _controller.openItemsSorted;
    final done = _controller.doneItemsSorted;

    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (open.isNotEmpty)
          SliverReorderableList(
            itemCount: open.length,
            onReorder: (oldIndex, newIndex) =>
                unawaited(_onReorder(oldIndex, newIndex)),
            itemBuilder: (context, index) {
              final item = open[index];
              return _buildDismissibleItemRow(
                item,
                reorderIndex: index,
                openCount: open.length,
              );
            },
          ),
        SliverToBoxAdapter(
          child: ListAddLine(
            controller: _newItemController,
            focusNode: _composerFocusNode,
            onAdd: _addItem,
            onScan: () => _launchScan(),
          ),
        ),
        // What matches the words being typed, right under them.
        SliverToBoxAdapter(
          child: KeyedSubtree(
            key: _typedSuggestionsKey,
            child: ValueListenableBuilder<int>(
              valueListenable: _controller.suggestionsRevision,
              builder: (context, _, __) => _typingAnItem
                  ? ListComposerSuggestions(
                      controller: _newItemController,
                      onAdd: _addItem,
                      suggestions: _controller.suggestions,
                      onSuggestionSelected: (s, typedQuery) {
                        _pendingCanonicalId = s.canonicalItemId;
                        _pendingTypedQuery = typedQuery;
                      },
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ),
        if (_controller.groupId != null &&
            _controller.listType == 'shopping' &&
            !_typingAnItem)
          SliverToBoxAdapter(
            child: RunningLowLines(
              groupId: _controller.groupId!,
              currentItemNames: _controller.items
                  .where((it) => !it.checked)
                  .map((it) => it.name.toLowerCase())
                  .toSet(),
              currentCanonicalIds: _controller.items
                  .where((it) => !it.checked)
                  .map((it) => it.canonicalItemId)
                  .whereType<String>()
                  .toSet(),
              onAdd: _addRestockSuggestion,
            ),
          ),
        if (open.isEmpty && done.isNotEmpty)
          SliverToBoxAdapter(
            child: ListAllDonePanel(
              onClearChecked: () => _clearItems(onlyChecked: true),
            ),
          ),
        if (done.isNotEmpty)
          SliverToBoxAdapter(
            child: ListDoneSectionHeader(
              doneCount: done.length,
              expanded: _controller.doneSectionExpanded,
              onToggle: _controller.toggleDoneSection,
            ),
          ),
        if (done.isNotEmpty && _controller.doneSectionExpanded)
          SliverList(
            delegate: SliverChildBuilderDelegate(
              (context, index) => _buildDismissibleItemRow(done[index]),
              childCount: done.length,
            ),
          ),
        // Room to scroll the last lines clear of the suggestion strip.
        const SliverToBoxAdapter(
          child: SizedBox(height: MitlistSpacing.xxl * 2),
        ),
      ],
    );
  }

  Widget _buildSearchResultItemList(List<ListItem> items) {
    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.only(bottom: MitlistSpacing.md),
      itemCount: items.length,
      itemBuilder: (context, index) {
        return _buildDismissibleItemRow(items[index]);
      },
    );
  }

  Widget _buildDismissibleItemRow(
    ListItem item, {
    int? reorderIndex,
    int openCount = 0,
  }) {
    return SettleCollapse(
      key: ValueKey(item.id),
      collapsed: _controller.isCollapsing(item.id),
      onCollapsed: () => _controller.finishSettle(item.id),
      child: _buildDismissibleCore(
        item,
        reorderIndex: reorderIndex,
        openCount: openCount,
      ),
    );
  }

  Widget _buildDismissibleCore(
    ListItem item, {
    int? reorderIndex,
    int openCount = 0,
  }) {
    final editing = _editingItemId == item.id;
    return Dismissible(
      key: ValueKey('dismiss-${item.id}'),
      // A line being typed in does not swipe away under the thumb.
      direction: editing ? DismissDirection.none : DismissDirection.endToStart,
      // If another gesture holds the save lock, refuse the dismissal instead
      // of letting the row disappear while _deleteItem no-ops — that mismatch
      // crashes with "a dismissed Dismissible is still part of the tree".
      confirmDismiss: (_) async =>
          !_isOperationActive(_operationKey('item:${item.id}')),
      background: Container(
        color: Theme.of(context).colorScheme.error,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(
          horizontal: MitlistSpacing.md,
        ),
        child: AppIcon(
          name: 'trash',
          color: Theme.of(context).colorScheme.onError,
        ),
      ),
      onDismissed: (_) {
        Haptics.medium();
        _deleteItem(item);
      },
      child: _buildItemRow(
        item,
        reorderIndex: reorderIndex,
        openCount: openCount,
      ),
    );
  }

  Widget _buildItemRow(ListItem item, {int? reorderIndex, int openCount = 0}) {
    final photos = _controller.photosFor(item.id);
    final thumbUrl =
        (photos != null && photos.isNotEmpty) ? photos.first.url : null;
    final editing = _editingItemId == item.id;
    final index = reorderIndex;

    return ListItemLine(
      item: item,
      editing: editing,
      editController: editing ? _editController : null,
      editFocusNode: editing ? _editFocusNode : null,
      onToggle: (val) => _toggleItem(item, val),
      onEdit: () => _startEdit(item),
      onSubmitEdit: () => _commitEdit(thenAddNext: true),
      onDetails: () => _openDetails(item),
      onRemove: () => _removeEditedItem(item),
      photoUrl: thumbUrl,
      onPhotoTap: thumbUrl != null
          ? () => ListItemPhotoViewer.show(context, thumbUrl)
          : null,
      currencySymbol: currencySymbol(_controller.groupCurrency),
      claimed: item.claimedBy != null,
      addedByName: _addedByName(item),
      reorderIndex: index,
      onMoveUp: index != null && index > 0
          ? () => _onReorder(index, index - 1)
          : null,
      onMoveDown: index != null && index < openCount - 1
          ? () => _onReorder(index, index + 2)
          : null,
    );
  }

  /// Starts editing [item]'s words in place, finishing any other line first.
  void _startEdit(ListItem item) {
    if (_editingItemId == item.id) return;
    if (_editingItemId != null) unawaited(_commitEdit());
    _editController.text = item.name;
    _editController.selection =
        TextSelection.collapsed(offset: item.name.length);
    setState(() => _editingItemId = item.id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && _editingItemId == item.id) {
        _editFocusNode.requestFocus();
      }
    });
  }

  void _onEditFocusChanged() {
    if (!_editFocusNode.hasFocus && _editingItemId != null) {
      unawaited(_commitEdit());
    }
  }

  /// Saves the line being edited and closes it. Emptied words remove the
  /// item (with undo), like deleting a line of a note. With [thenAddNext],
  /// the keyboard moves on to the add line, the way return starts the next
  /// line in a checklist.
  Future<void> _commitEdit({bool thenAddNext = false}) async {
    final id = _editingItemId;
    if (id == null) return;
    final name = _editController.text.trim();
    setState(() => _editingItemId = null);
    if (thenAddNext) {
      _composerFocusNode.requestFocus();
    }
    final item = _controller.items.where((i) => i.id == id).firstOrNull;
    if (item == null) return;
    if (name.isEmpty) {
      await _deleteItem(item);
      return;
    }
    if (name == item.name) return;
    final operation = _operationKey('item:$id');
    if (!_beginOperation(operation)) return;
    try {
      await _controller.updateItemFields(item, name: name);
    } catch (_) {
      if (mounted) {
        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.listDetailCouldNotUpdate)),
        );
      }
    } finally {
      _finishOperation(operation);
    }
  }

  Future<void> _removeEditedItem(ListItem item) async {
    setState(() => _editingItemId = null);
    _editFocusNode.unfocus();
    await _deleteItem(item);
  }

  Future<void> _openDetails(ListItem item) async {
    await _commitEdit();
    if (!mounted) return;
    final current =
        _controller.items.where((i) => i.id == item.id).firstOrNull ?? item;
    await _editItem(current);
  }

  /// Name to credit under the row. Your own additions stay unlabelled: on a
  /// list you fill yourself every row would otherwise repeat your name, and
  /// the point of the line is spotting what the others asked for.
  String? _addedByName(ListItem item) {
    final addedBy = item.addedBy;
    if (addedBy == null || addedBy == _controller.userId) return null;
    return _controller.memberName(addedBy);
  }

  void _clearSearch() {
    _searchController.clear();
    _controller.setSearchQuery('');
  }

  void _closeSearch() {
    setState(() => _showSearch = false);
    _clearSearch();
  }
}
