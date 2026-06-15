import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../l10n/app_localizations.dart';
import '../../models/group_models.dart';
import '../../providers/group_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../theme/spacing.dart';
import '../../theme/typography.dart';
import '../../utils/friendly_error.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/mitlist_app_bar.dart';

enum _Phase { idle, joining, success }

/// Full-screen landing for an invite deep link (`mitlist://join/<code>`).
///
/// Shows the code, lets the user confirm or dismiss, and on success sets the
/// joined group as the current group before navigating to home.
class JoinLandingScreen extends ConsumerStatefulWidget {
  const JoinLandingScreen({super.key, required this.code});

  final String code;

  @override
  ConsumerState<JoinLandingScreen> createState() => _JoinLandingScreenState();
}

class _JoinLandingScreenState extends ConsumerState<JoinLandingScreen> {
  _Phase _phase = _Phase.idle;
  String? _error;
  Group? _joinedGroup;

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  Future<void> _join() async {
    if (_phase != _Phase.idle) return;
    setState(() {
      _phase = _Phase.joining;
      _error = null;
    });
    try {
      final svc = await ref.read(groupServiceProviderAsync.future);
      final group = await svc.joinGroup(
        JoinGroupRequest(code: widget.code.trim().toUpperCase()),
      );
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
        _error = friendlyErrorMessage(e, AppLocalizations.of(context)!);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      appBar: MitlistAppBar(
        showStandardActions: false,
        title: const SizedBox.shrink(),
        leading: IconButton(
          icon: const AppIcon(name: 'xMark'),
          onPressed: () => context.goNamed('home'),
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
            child: _phase == _Phase.success
                ? _buildSuccess(textTheme, colorScheme)
                : _buildEntry(textTheme, colorScheme),
          ),
        ),
      ),
    );
  }

  Widget _buildEntry(TextTheme textTheme, ColorScheme colorScheme) {
    final isJoining = _phase == _Phase.joining;
    final codeParts = widget.code.trim().toUpperCase().split('-');

    return KeyedSubtree(
      key: const ValueKey('entry'),
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

          // Code displayed in segmented mono style
          Semantics(
            label: l10n.authJoinInviteCodeSemantic(widget.code.trim().toUpperCase()),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < codeParts.length; i++) ...[
                  if (i > 0)
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: MitlistSpacing.xs,
                      ),
                      child: Text(
                        '—',
                        style: textTheme.titleMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: MitlistSpacing.md,
                      vertical: MitlistSpacing.sm,
                    ),
                    decoration: BoxDecoration(
                      color: colorScheme.surfaceContainerLow,
                      border: Border.all(color: colorScheme.outline, width: 2),
                    ),
                    child: Text(
                      codeParts[i],
                      style: MitlistTypography.monoBody(
                        color: colorScheme.onSurface,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          const SizedBox(height: MitlistSpacing.xl),

          if (_error != null) ...[
            AppAlert(
              type: AppAlertType.error,
              message: l10n.authJoinErrorWithHint(_error!),
            ),
            const SizedBox(height: MitlistSpacing.md),
          ],

          AppButton(
            variant: AppButtonVariant.solid,
            color: AppButtonColor.primary,
            size: AppButtonSize.lg,
            text: isJoining ? l10n.authJoinJoining : l10n.authJoinJoinNow,
            isLoading: isJoining,
            onPressed: isJoining ? null : _join,
          ),
          const SizedBox(height: MitlistSpacing.sm),
          AppButton(
            variant: AppButtonVariant.outline,
            color: AppButtonColor.neutral,
            size: AppButtonSize.lg,
            text: l10n.authJoinNotNow,
            onPressed: () => context.goNamed('home'),
          ),
        ],
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
