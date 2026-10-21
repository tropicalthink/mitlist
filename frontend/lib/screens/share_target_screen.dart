import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../l10n/app_localizations.dart';
import '../theme/spacing.dart';
import '../utils/haptics.dart';
import '../models/list_models.dart';
import '../models/recipe_models.dart';
import '../providers/attachment_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/list_provider.dart';
import '../providers/recipe_provider.dart';
import '../repositories/outbox_error_classifier.dart';
import '../providers/group_provider.dart';
import '../providers/pinwall_provider.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icon.dart';
import '../widgets/mitlist_app_bar.dart';
import '../widgets/app_toast.dart';
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
  final List<XFile> _pendingMedia = [];

  late final List<_DestinationOption> _options = [];

  void _onDestinationTapped(String id) {
    unawaited(Haptics.light());
    setState(() {
      _selectedDestination = id;
      _error = null;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<String?> _pickGroupId() async {
    final groups = await ref.read(cachedGroupsProvider.future);
    if (!mounted) return null;
    if (groups.isEmpty) return null;
    if (groups.length == 1) return groups.first.id;

    final l10n = AppLocalizations.of(context)!;
    return showAppBottomSheet<String>(
      context: context,
      title: l10n.shareTargetSelectHousehold,
      body: ListView.separated(
        padding: EdgeInsets.zero,
        shrinkWrap: true,
        itemCount: groups.length,
        separatorBuilder: (_, __) => const SizedBox(height: MitlistSpacing.xs),
        itemBuilder: (context, i) {
          final g = groups[i];
          return AppCard(
            variant: AppCardVariant.outlined,
            interactive: true,
            onTap: () => Navigator.of(context).pop(g.id),
            semanticLabel: g.name,
            padding: AppCardPadding.md,
            child: Row(
              children: [
                const AppIcon(name: 'userGroup'),
                const SizedBox(width: MitlistSpacing.sm),
                Expanded(
                  child: Text(
                    g.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Future<void> _pickMedia() async {
    final picker = ImagePicker();
    final files = await picker.pickMultiImage();
    if (!mounted || files.isEmpty) return;
    setState(() {
      _pendingMedia.addAll(files);
      _error = null;
    });
  }

  Future<void> _onSave() async {
    final l10n = AppLocalizations.of(context)!;
    if (_selectedDestination == null) return;
    final text = _textController.text.trim();
    final isPinwall = _selectedDestination == 'pinwall';
    if (!isPinwall && text.isEmpty) {
      setState(() => _error = l10n.shareTargetValidationText);
      return;
    }
    if (isPinwall && text.isEmpty && _pendingMedia.isEmpty) {
      setState(() => _error = l10n.shareTargetValidationNote);
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      if (_selectedDestination == 'lists') {
        final groupId = await _pickGroupId();
        if (groupId == null) {
          setState(() {
            _error = l10n.shareTargetValidationHousehold;
            _isSaving = false;
          });
          return;
        }
        await _saveAsList(groupId, text);
      } else if (_selectedDestination == 'pinwall') {
        final groupId = await _pickGroupId();
        if (groupId == null) {
          setState(() {
            _error = l10n.shareTargetValidationHousehold;
            _isSaving = false;
          });
          return;
        }

        if (_pendingMedia.isEmpty) {
          // Text only: queued like a note written on the pinboard, so it
          // saves offline too.
          final repo = await ref.read(pinwallRepositoryProvider.future);
          await repo.createPostOfflineFirst(
            groupId,
            content: text,
            userId: await _currentUserId(),
          );
          repo.noteLocalWrite();
        } else {
          // Media has to be uploaded, which needs a connection.
          final pinwallSvc =
              await ref.read(pinwallServiceProviderAsync.future);
          final post = await pinwallSvc.createPost(
            groupId,
            content: text.isEmpty ? ' ' : text,
          );
          final attachmentRepo =
              await ref.read(attachmentRepositoryProvider.future);
          for (final f in List<XFile>.from(_pendingMedia)) {
            final bytes = await f.readAsBytes();
            final a = await attachmentRepo.uploadAttachment(
              groupId: groupId,
              purpose: 'pinwall_media',
              filename: f.name,
              contentType: f.mimeType ?? '',
              bytes: bytes,
            );
            await pinwallSvc.attachPostAttachment(
              groupId: groupId,
              postId: post.id,
              attachmentId: a.id,
            );
          }
        }
      } else {
        // Same shape the server's share endpoint gave a recipe (the first
        // line as title, the whole text as description), queued so it saves
        // offline.
        final shared = SharedText.parse(text);
        final repo = await ref.read(recipeRepositoryProvider.future);
        await repo.createRecipeOfflineFirst(CreateRecipeRequest(
          title: _clip(shared.title, 200),
          description: _clip(
            shared.url != null ? '$text\n\nSource: ${shared.url}' : text,
            2000,
          ),
          sourceUrl: shared.url ?? '',
        ));
      }

      if (!mounted) return;
      setState(() => _isSaving = false);
      AppToast.success(context, l10n.shareTargetSaved);
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // Only the media upload still needs the network; say so offline.
        _error = classifyOutboxError(e) == OutboxErrorDisposition.unreachable
            ? l10n.commonCheckConnection
            : l10n.shareTargetFailedSave;
        _isSaving = false;
      });
    }
  }

  /// Files shared text as a new shopping list: the first line names it, every
  /// other line becomes an item (what the server's share endpoint did). Built
  /// from the offline-first list and item writes, so sharing into the app
  /// works without a connection.
  Future<void> _saveAsList(String groupId, String text) async {
    final shared = SharedText.parse(text);
    final repo = await ref.read(listRepositoryProvider.future);
    final list = await repo.createListOfflineFirst(CreateListRequest(
      groupId: groupId,
      name: _clip(shared.title, 100),
    ));
    final userId = await _currentUserIdOrNull();
    for (final line in shared.lines) {
      await repo.createItemOfflineFirst(
        list.id,
        CreateListItemRequest(name: _clip(line, 200)),
        deferImmediateSync: true,
        addedBy: userId,
      );
    }
    repo.triggerAutoSync();
  }

  Future<String?> _currentUserIdOrNull() async {
    try {
      return await _currentUserId();
    } catch (_) {
      return null;
    }
  }

  /// The signed-in user's id, from the session's cached profile when there
  /// is one (offline), else fetched.
  Future<String> _currentUserId() async {
    final auth = ref.read(authServiceProvider);
    final cached = auth.cachedMe;
    if (cached != null) return cached.id;
    return (await auth.getMe()).id;
  }

  /// [value] cut to the server's [max] characters (it counts code points).
  static String _clip(String value, int max) {
    final runes = value.runes;
    return runes.length <= max
        ? value
        : String.fromCharCodes(runes.take(max)).trimRight();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    _options.clear();
    _options.addAll([
      _DestinationOption(
        id: 'lists',
        label: l10n.shareTargetDestLists,
        icon: 'queueList',
        description: l10n.shareTargetDestListsDesc,
      ),
      _DestinationOption(
        id: 'pinwall',
        label: l10n.shareTargetDestPinwall,
        icon: 'share',
        description: l10n.shareTargetDestPinwallDesc,
      ),
      _DestinationOption(
        id: 'recipes',
        label: l10n.shareTargetDestRecipes,
        icon: 'informationCircle',
        description: l10n.shareTargetDestRecipesDesc,
      ),
    ]);
    return Scaffold(
      appBar: MitlistAppBar.titleText(
        l10n.shareTargetAppBarTitle,
        showStandardActions: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _textController,
              maxLines: 4,
              decoration: InputDecoration(
                labelText: l10n.shareTargetSharedText,
                hintText: l10n.shareTargetPasteHint,
              ),
            ),
            if (_selectedDestination == 'pinwall') ...[
              const SizedBox(height: MitlistSpacing.sm),
              Row(
                children: [
                  AppButton(
                    size: AppButtonSize.sm,
                    variant: AppButtonVariant.outline,
                    text: _pendingMedia.isEmpty
                        ? l10n.shareTargetAddPhotos
                        : l10n.shareTargetPhotosAdded(_pendingMedia.length),
                    onPressed: _isSaving ? null : _pickMedia,
                  ),
                  const Spacer(),
                  if (_pendingMedia.isNotEmpty)
                    AppButton(
                      variant: AppButtonVariant.ghost,
                      color: AppButtonColor.neutral,
                      text: l10n.commonClear,
                      onPressed: _isSaving
                          ? null
                          : () => setState(() => _pendingMedia.clear()),
                    ),
                ],
              ),
            ],
            const SizedBox(height: MitlistSpacing.md),
            if (_error != null) ...[
              Text(
                _error!,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.error,
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
                    l10n.commonPreview,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                  const SizedBox(height: MitlistSpacing.sm),
                  Row(
                    children: [
                      const AppIcon(name: 'share', size: MitlistSpacing.space6),
                      const SizedBox(width: MitlistSpacing.sm),
                      Expanded(
                        child: Text(
                          l10n.shareTargetPreviewPlaceholder,
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
                    tint:
                        isSelected ? AppCardTint.primary : AppCardTint.neutral,
                    interactive: true,
                    onTap: () => _onDestinationTapped(option.id),
                    semanticLabel: isSelected
                        ? '${option.label}, selected'
                        : '${option.label}, ${option.description}',
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
                          AppIcon(
                            name: 'check',
                            color: Theme.of(context).colorScheme.primary,
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
            text: l10n.commonSave,
            onPressed:
                (_selectedDestination != null && !_isSaving) ? _onSave : null,
          ),
        ),
      ),
    );
  }
}

/// Shared text split the way the server's share endpoint splits it: the first
/// non-empty line that is not the link is the title, the rest are lines, and
/// the first URL is kept apart.
class SharedText {
  final String title;
  final List<String> lines;
  final String? url;

  const SharedText({required this.title, required this.lines, this.url});

  static final RegExp _url = RegExp(r'https?://[^\s]+');

  factory SharedText.parse(String text) {
    final url = _url.firstMatch(text)?.group(0);
    final lines = [
      for (final raw in text.split('\n'))
        if (raw.trim().isNotEmpty && raw.trim() != url) raw.trim(),
    ];
    if (lines.isNotEmpty) {
      return SharedText(title: lines.first, lines: lines.sublist(1), url: url);
    }
    final host = url == null ? null : Uri.tryParse(url)?.host;
    return SharedText(
      title: host != null && host.isNotEmpty
          ? host
          : (url != null ? 'Shared link' : 'Shared items'),
      lines: const [],
      url: url,
    );
  }
}
