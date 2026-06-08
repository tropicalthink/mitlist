import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../theme/spacing.dart';
import '../providers/attachment_provider.dart';
import '../providers/group_provider.dart';
import '../providers/pinwall_provider.dart';
import '../providers/share_target_provider.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_card.dart';
import '../widgets/app_icon.dart';
import '../widgets/mitlist_app_bar.dart';
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

  static const List<_DestinationOption> _options = [
    _DestinationOption(
      id: 'lists',
      label: 'Lists',
      icon: 'queueList',
      description: 'Save to a shopping or to-do list',
    ),
    _DestinationOption(
      id: 'pinwall',
      label: 'Pinwall',
      icon: 'share',
      description: 'Post a note (and optional photos) to your household',
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
      _error = null;
    });
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  Future<String?> _pickGroupId() async {
    final groupService = await ref.read(groupServiceProviderAsync.future);
    final groups = await groupService.listGroups(limit: 50);
    if (!mounted) return null;
    if (groups.isEmpty) return null;
    if (groups.length == 1) return groups.first.id;

    return showAppBottomSheet<String>(
      context: context,
      title: 'Select household',
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
    if (_selectedDestination == null) return;
    final text = _textController.text.trim();
    final isPinwall = _selectedDestination == 'pinwall';
    if (!isPinwall && text.isEmpty) {
      setState(() => _error = 'Paste or type something to save.');
      return;
    }
    if (isPinwall && text.isEmpty && _pendingMedia.isEmpty) {
      setState(() => _error = 'Add a note or at least one photo.');
      return;
    }

    setState(() {
      _isSaving = true;
      _error = null;
    });

    try {
      final shareService = await ref.read(shareTargetServiceProviderAsync.future);

      if (_selectedDestination == 'lists') {
        final groupId = await _pickGroupId();
        if (groupId == null) {
          setState(() {
            _error = 'Create or join a household first.';
            _isSaving = false;
          });
          return;
        }
        await shareService.createListFromShare(groupId: groupId, text: text);
      } else if (_selectedDestination == 'pinwall') {
        final groupId = await _pickGroupId();
        if (groupId == null) {
          setState(() {
            _error = 'Create or join a household first.';
            _isSaving = false;
          });
          return;
        }

        final pinwallSvc = await ref.read(pinwallServiceProviderAsync.future);
        final post = await pinwallSvc.createPost(
          groupId,
          content: text.isEmpty ? ' ' : text,
        );

        if (_pendingMedia.isNotEmpty) {
          final attachmentRepo = await ref.read(attachmentRepositoryProvider.future);
          for (final f in List<XFile>.from(_pendingMedia)) {
            final bytes = await f.readAsBytes();
            final a = await attachmentRepo.uploadAttachment(
              groupId: groupId,
              purpose: 'pinwall_media',
              filename: f.name,
              contentType: 'image/*',
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
      appBar: MitlistAppBar.titleText(
        'Save to mitlist',
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
              decoration: const InputDecoration(
                labelText: 'Shared text',
                hintText: 'Paste or type the shared text here\u2026',
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
                        ? 'Add photos'
                        : '${_pendingMedia.length} photo(s) added',
                    onPressed: _isSaving ? null : _pickMedia,
                  ),
                  const Spacer(),
                  if (_pendingMedia.isNotEmpty)
                    AppButton(
                      variant: AppButtonVariant.ghost,
                      color: AppButtonColor.neutral,
                      text: 'Clear',
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
                    'Preview',
                    style: Theme.of(context).textTheme.labelMedium,
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
                    semanticLabel: option.label,
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
            text: 'Save',
            onPressed: (_selectedDestination != null && !_isSaving) ? _onSave : null,
          ),
        ),
      ),
    );
  }
}
