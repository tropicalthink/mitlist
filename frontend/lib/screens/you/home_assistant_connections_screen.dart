import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/group_models.dart';
import '../../models/integration_credential_models.dart';
import '../../providers/group_provider.dart';
import '../../providers/integration_credential_provider.dart';
import '../../theme/spacing.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_dialog.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_input.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../utils/friendly_error.dart';

class HomeAssistantConnectionsScreen extends ConsumerWidget {
  const HomeAssistantConnectionsScreen({super.key});

  Future<void> _revoke(
    BuildContext context,
    WidgetRef ref,
    IntegrationCredential credential,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final confirmed = await showAppDialog<bool>(
      context: context,
      title: l10n.homeAssistantRevoke,
      body: Text(l10n.homeAssistantRevokeConfirm),
      actions: [
        AppButton(
          text: l10n.commonCancel,
          variant: AppButtonVariant.outline,
          onPressed: () =>
              Navigator.of(context, rootNavigator: true).pop(false),
        ),
        AppButton(
          text: l10n.homeAssistantRevoke,
          color: AppButtonColor.error,
          onPressed: () => Navigator.of(context, rootNavigator: true).pop(true),
        ),
      ],
    );
    if (confirmed != true || !context.mounted) return;
    try {
      final service =
          await ref.read(integrationCredentialServiceProvider.future);
      await service.revoke(credential.id);
      ref.invalidate(integrationCredentialsProvider);
      if (context.mounted) {
        AppToast.success(context, l10n.homeAssistantRevokedSuccess);
      }
    } catch (error) {
      if (context.mounted) {
        AppToast.error(context, friendlyErrorMessage(error, l10n));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final credentials = ref.watch(integrationCredentialsProvider);
    return Scaffold(
      appBar: MitlistAppBar.titleText(
        l10n.homeAssistantTitle,
        showStandardActions: false,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(integrationCredentialsProvider.future),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(MitlistSpacing.md),
          children: [
            AppCard(
              variant: AppCardVariant.filled,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const AppIcon(name: 'homeOutline'),
                  const SizedBox(width: MitlistSpacing.sm),
                  Expanded(
                    child: Text(
                      l10n.homeAssistantDescription,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: MitlistSpacing.md),
            AppButton(
              text: l10n.homeAssistantCreateConnection,
              icon: const AppIcon(name: 'plus'),
              onPressed: () => context.pushNamed('homeAssistantConnectionNew'),
            ),
            const SizedBox(height: MitlistSpacing.lg),
            Text(
              l10n.homeAssistantConnections,
              style: Theme.of(context).textTheme.titleMedium,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: MitlistSpacing.sm),
            credentials.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (_, __) => AppAlert(
                type: AppAlertType.error,
                message: l10n.homeAssistantLoadFailed,
              ),
              data: (items) {
                if (items.isEmpty) {
                  return AppCard(
                    variant: AppCardVariant.outlined,
                    child: Text(l10n.homeAssistantNoConnections),
                  );
                }
                return Column(
                  children: [
                    for (final credential in items) ...[
                      _ConnectionCard(
                        credential: credential,
                        onRevoke: credential.isActive
                            ? () => _revoke(context, ref, credential)
                            : null,
                      ),
                      const SizedBox(height: MitlistSpacing.sm),
                    ],
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ConnectionCard extends StatelessWidget {
  const _ConnectionCard({required this.credential, this.onRevoke});

  final IntegrationCredential credential;
  final VoidCallback? onRevoke;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final lastUsed = credential.lastUsedAt;
    final status = credential.revokedAt != null
        ? l10n.homeAssistantRevoked
        : lastUsed == null
            ? l10n.homeAssistantNeverUsed
            : l10n.homeAssistantLastUsed(
                MaterialLocalizations.of(context)
                    .formatMediumDate(lastUsed.toLocal()),
              );
    final writable = credential.scopes.any(
      (scope) =>
          scope == 'write' ||
          scope == '*' ||
          scope.endsWith(':write') ||
          scope.endsWith(':*'),
    );
    return AppCard(
      variant: AppCardVariant.outlined,
      semanticLabel: credential.name,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const AppIcon(name: 'server'),
              const SizedBox(width: MitlistSpacing.sm),
              Expanded(
                child: Text(
                  credential.name,
                  style: Theme.of(context).textTheme.titleMedium,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: MitlistSpacing.sm),
          Text(
            '${credential.tokenPrefix}… · ${writable ? l10n.homeAssistantReadWrite : l10n.homeAssistantReadOnly}',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: MitlistSpacing.xs),
          Text(
            status,
            style: Theme.of(context).textTheme.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          if (onRevoke != null) ...[
            const SizedBox(height: MitlistSpacing.md),
            AppButton(
              text: l10n.homeAssistantRevoke,
              variant: AppButtonVariant.ghost,
              color: AppButtonColor.error,
              onPressed: onRevoke,
            ),
          ],
        ],
      ),
    );
  }
}

class HomeAssistantConnectionCreateScreen extends ConsumerStatefulWidget {
  const HomeAssistantConnectionCreateScreen({super.key});

  @override
  ConsumerState<HomeAssistantConnectionCreateScreen> createState() =>
      _HomeAssistantConnectionCreateScreenState();
}

class _HomeAssistantConnectionCreateScreenState
    extends ConsumerState<HomeAssistantConnectionCreateScreen> {
  final _nameController = TextEditingController(text: 'Home Assistant');
  final Set<String> _groupIds = {};
  bool _writeAccess = true;
  bool _financeAccess = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  List<String> _scopes() {
    const readable = [
      'groups',
      'lists',
      'chores',
      'calendar',
      'recipes',
      'pinwall',
      'notifications',
      'groceries',
      'activity',
      'attachments',
    ];
    final scopes = <String>[
      for (final domain in readable) '$domain:read',
    ];
    if (_writeAccess) {
      for (final domain in readable) {
        if (domain != 'groups' &&
            domain != 'calendar' &&
            domain != 'activity') {
          scopes.add('$domain:write');
        }
      }
    }
    if (_financeAccess) {
      scopes.add('finance:read');
      if (_writeAccess) scopes.add('finance:write');
    }
    return scopes;
  }

  Future<void> _create() async {
    final l10n = AppLocalizations.of(context)!;
    if (_groupIds.isEmpty) {
      setState(() => _error = l10n.homeAssistantSelectHousehold);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final service =
          await ref.read(integrationCredentialServiceProvider.future);
      final created = await service.create(
        name: _nameController.text.trim(),
        groupIds: _groupIds.toList(growable: false),
        scopes: _scopes(),
      );
      if (!mounted) return;
      ref.invalidate(integrationCredentialsProvider);
      await _showToken(created.token);
      if (mounted) context.pop();
    } catch (error) {
      if (mounted) {
        setState(() => _error = friendlyErrorMessage(error, l10n));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _showToken(String token) async {
    final l10n = AppLocalizations.of(context)!;
    await showAppDialog<void>(
      context: context,
      title: l10n.homeAssistantTokenTitle,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(l10n.homeAssistantTokenBody),
          const SizedBox(height: MitlistSpacing.md),
          Semantics(
            label: l10n.homeAssistantTokenTitle,
            child: SelectableText(token),
          ),
        ],
      ),
      actions: [
        AppButton(
          text: l10n.commonCopy,
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: token));
            if (mounted) {
              AppToast.success(context, l10n.homeAssistantTokenCopied);
            }
          },
        ),
        AppButton(
          text: l10n.commonDone,
          variant: AppButtonVariant.outline,
          onPressed: () => Navigator.of(context).pop(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final groups = ref.watch(cachedGroupsProvider);
    return Scaffold(
      appBar: MitlistAppBar.titleText(
        l10n.homeAssistantCreateConnection,
        showStandardActions: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        children: [
          AppInput(
            label: l10n.homeAssistantConnectionName,
            hint: l10n.homeAssistantConnectionNameHint,
            controller: _nameController,
            maxLength: 100,
          ),
          const SizedBox(height: MitlistSpacing.lg),
          Text(
            l10n.homeAssistantHouseholds,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          groups.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (_, __) => AppAlert(
              type: AppAlertType.error,
              message: l10n.commonFailedToLoad,
            ),
            data: (items) => AppCard(
              variant: AppCardVariant.outlined,
              padding: AppCardPadding.none,
              child: Column(
                children: [
                  for (final Group group in items)
                    CheckboxListTile(
                      title: Text(
                        group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      value: _groupIds.contains(group.id),
                      onChanged: (selected) {
                        setState(() {
                          if (selected == true) {
                            _groupIds.add(group.id);
                          } else {
                            _groupIds.remove(group.id);
                          }
                        });
                      },
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: MitlistSpacing.lg),
          Text(
            l10n.homeAssistantPermissions,
            style: Theme.of(context).textTheme.titleMedium,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          AppCard(
            variant: AppCardVariant.outlined,
            padding: AppCardPadding.none,
            child: Column(
              children: [
                SwitchListTile.adaptive(
                  title: Text(l10n.homeAssistantWriteAccess),
                  value: _writeAccess,
                  onChanged: (value) => setState(() => _writeAccess = value),
                ),
                Divider(color: Theme.of(context).colorScheme.outlineVariant),
                SwitchListTile.adaptive(
                  title: Text(l10n.homeAssistantFinanceAccess),
                  value: _financeAccess,
                  onChanged: (value) => setState(() => _financeAccess = value),
                ),
              ],
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: MitlistSpacing.md),
            AppAlert(type: AppAlertType.error, message: _error!),
          ],
          const SizedBox(height: MitlistSpacing.lg),
          AppButton(
            text: l10n.homeAssistantCreateConnection,
            isLoading: _saving,
            onPressed: _saving ? null : _create,
          ),
        ],
      ),
    );
  }
}
