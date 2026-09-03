import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/group_models.dart';
import '../../providers/group_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/friendly_error.dart';
import '../../utils/open_in_app.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/mitlist_app_bar.dart';

enum _Phase { loading, idle, joining, success }

/// Full-screen accept/decline page for an invite link
/// (`mitlist:///join/<code>` or `https://app.mitlist.me/join/<code>`).
///
/// Looks the code up first so the recipient sees *which* household they are
/// being asked into and how big it is, then lets them accept or decline. On
/// success the joined group becomes the current group before heading home.
class JoinLandingScreen extends ConsumerStatefulWidget {
  const JoinLandingScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<JoinLandingScreen> createState() => _JoinLandingScreenState();
}

class _JoinLandingScreenState extends ConsumerState<JoinLandingScreen> {
  _Phase _phase = _Phase.loading;
  InvitePreview? _preview;
  String? _previewError;
  String? _joinError;
  Group? _joinedGroup;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  String get _code => widget.code.trim().toUpperCase();

  @override
  void initState() {
    super.initState();
    unawaited(_loadPreview());
  }

  Future<void> _loadPreview() async {
    try {
      final svc = await ref.read(groupServiceProviderAsync.future);
      final preview = await svc.previewInvite(_code);
      if (!mounted) return;
      setState(() {
        _preview = preview;
        _previewError = null;
        _phase = _Phase.idle;
      });
    } catch (e) {
      if (!mounted) return;
      // The lookup is a courtesy; joining is still the authoritative check,
      // so a failed preview degrades to the code-only page rather than a
      // dead end.
      setState(() {
        _previewError = friendlyErrorMessage(e, l10n);
        _phase = _Phase.idle;
      });
    }
  }

  Future<void> _accept() async {
    if (_phase != _Phase.idle) return;
    setState(() {
      _phase = _Phase.joining;
      _joinError = null;
    });
    try {
      final svc = await ref.read(groupServiceProviderAsync.future);
      final group = await svc.joinGroup(JoinGroupRequest(code: _code));
      if (!mounted) return;
      unawaited(ref.read(currentGroupIdProvider.notifier).set(group.id));
      setState(() {
        _phase = _Phase.success;
        _joinedGroup = group;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _phase = _Phase.idle;
        _joinError = friendlyErrorMessage(e, l10n);
      });
    }
  }

  void _decline() => context.goNamed('home');

  /// The browser is where the invite lands when the phone has not claimed
  /// the https link for the app; this is the one-tap hop back into it.
  Future<void> _openInApp() => launchUrl(
        openInAppUri(
          '/join/$_code',
          isAndroid: isAndroidBrowser,
          fallbackUrl: Uri.base,
        ),
        webOnlyWindowName: '_self',
      );

  void _openExistingHousehold() {
    final preview = _preview;
    if (preview != null) {
      unawaited(ref.read(currentGroupIdProvider.notifier).set(preview.groupId));
    }
    context.goNamed('home');
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: MitlistAppBar(
        showStandardActions: false,
        title: const SizedBox.shrink(),
        leading: IconButton(
          icon: const AppIcon(name: 'xMark'),
          onPressed: _decline,
          tooltip: l10n.commonDismiss,
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.lg,
            vertical: MitlistSpacing.md,
          ),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: switch (_phase) {
              _Phase.loading => _buildLoading(textTheme, colorScheme),
              _Phase.success => _buildSuccess(textTheme, colorScheme),
              _ => _buildEntry(textTheme, colorScheme),
            },
          ),
        ),
      ),
    );
  }

  Widget _buildLoading(TextTheme textTheme, ColorScheme colorScheme) {
    return KeyedSubtree(
      key: const ValueKey('loading'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 32,
            height: 32,
            child: CircularProgressIndicator(strokeWidth: 3),
          ),
          const SizedBox(height: MitlistSpacing.md),
          Text(
            l10n.authJoinCheckingInvite,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildEntry(TextTheme textTheme, ColorScheme colorScheme) {
    final isJoining = _phase == _Phase.joining;
    final preview = _preview;
    final status = preview?.status;
    final alreadyMember = status == InviteStatus.alreadyMember;
    final dead =
        status == InviteStatus.expired || status == InviteStatus.used;

    return KeyedSubtree(
      key: const ValueKey('entry'),
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.authJoinTitle,
              style: textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w700,
                letterSpacing: -0.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: MitlistSpacing.lg),

            if (preview != null) ...[
              _HouseholdCard(preview: preview),
              const SizedBox(height: MitlistSpacing.md),
            ],

            _CodeLine(code: _code),
            const SizedBox(height: MitlistSpacing.xl),

            if (alreadyMember)
              AppAlert(
                type: AppAlertType.info,
                message: l10n.authJoinAlreadyMember(preview!.groupName),
              )
            else if (status == InviteStatus.expired)
              AppAlert(
                type: AppAlertType.warning,
                message: l10n.authJoinExpired,
              )
            else if (status == InviteStatus.used)
              AppAlert(
                type: AppAlertType.warning,
                message: l10n.authJoinAlreadyUsed,
              )
            else if (_previewError != null)
              AppAlert(
                type: AppAlertType.warning,
                message: '${l10n.authJoinCouldNotLoad}\n$_previewError',
              ),
            if (alreadyMember || dead || _previewError != null)
              const SizedBox(height: MitlistSpacing.md),

            if (_joinError != null) ...[
              AppAlert(
                type: AppAlertType.error,
                message: l10n.authJoinErrorWithHint(_joinError!),
              ),
              const SizedBox(height: MitlistSpacing.md),
            ],

            if (alreadyMember)
              AppButton(
                variant: AppButtonVariant.solid,
                color: AppButtonColor.primary,
                size: AppButtonSize.lg,
                text: l10n.authJoinGoToHousehold,
                onPressed: _openExistingHousehold,
              )
            else if (dead)
              AppButton(
                variant: AppButtonVariant.outline,
                color: AppButtonColor.neutral,
                size: AppButtonSize.lg,
                text: l10n.commonDismiss,
                onPressed: _decline,
              )
            else ...[
              AppButton(
                variant: AppButtonVariant.solid,
                color: AppButtonColor.primary,
                size: AppButtonSize.lg,
                text: isJoining ? l10n.authJoinJoining : l10n.authJoinAccept,
                isLoading: isJoining,
                onPressed: isJoining ? null : _accept,
              ),
              const SizedBox(height: MitlistSpacing.sm),
              AppButton(
                variant: AppButtonVariant.outline,
                color: AppButtonColor.neutral,
                size: AppButtonSize.lg,
                text: l10n.authJoinDecline,
                onPressed: isJoining ? null : _decline,
              ),
              // Signed in on a phone browser: the household belongs in the
              // app, so offer the hop before they accept in a tab.
              if (isMobileBrowser) ...[
                const SizedBox(height: MitlistSpacing.sm),
                AppButton(
                  variant: AppButtonVariant.outline,
                  color: AppButtonColor.primary,
                  size: AppButtonSize.lg,
                  text: l10n.openInAppButton,
                  icon: const AppIcon(name: 'openInNew'),
                  onPressed: isJoining ? null : _openInApp,
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildSuccess(TextTheme textTheme, ColorScheme colorScheme) {
    final group = _joinedGroup;
    if (group == null) return _buildEntry(textTheme, colorScheme);

    return KeyedSubtree(
      key: const ValueKey('success'),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppIcon(
            name: 'checkCircle',
            size: 72,
            color: colorScheme.primary,
          ),
          const SizedBox(height: MitlistSpacing.md),
          Text(
            group.name,
            style: textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: MitlistSpacing.xs),
          Text(
            l10n.authJoinYoureIn,
            style: textTheme.bodyLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MitlistSpacing.xl),
          AppButton(
            variant: AppButtonVariant.solid,
            size: AppButtonSize.lg,
            text: l10n.authJoinGoToHousehold,
            onPressed: () => context.goNamed('home'),
          ),
        ],
      ),
    );
  }
}

/// The household the code opens: name front and centre, size underneath.
class _HouseholdCard extends StatelessWidget {
  const _HouseholdCard({required this.preview});

  final InvitePreview preview;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: MitlistSpacing.lg,
        vertical: MitlistSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerLow,
        border: Border.all(color: colorScheme.outline, width: 2),
      ),
      child: Column(
        children: [
          Text(
            l10n.authJoinInvitedTo,
            style: textTheme.labelLarge?.copyWith(
              color: colorScheme.onSurfaceVariant,
              letterSpacing: 0.4,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          Text(
            preview.groupName,
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: MitlistSpacing.xs),
          Text(
            l10n.authJoinMemberCount(preview.memberCount),
            style: textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// The raw code, quietly, so it can still be read out or cross-checked.
class _CodeLine extends StatelessWidget {
  const _CodeLine({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Semantics(
      label: l10n.authJoinInviteCodeSemantic(code),
      child: Text(
        code,
        style: MitlistTypography.monoBody(color: colorScheme.onSurfaceVariant),
        textAlign: TextAlign.center,
      ),
    );
  }
}
