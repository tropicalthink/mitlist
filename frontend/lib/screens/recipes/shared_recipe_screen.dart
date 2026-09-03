import 'dart:async';

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform, kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../l10n/app_localizations.dart';
import '../../models/group_models.dart';
import '../../models/recipe_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/group_provider.dart';
import '../../providers/recipe_provider.dart';
import '../../router.dart' show currentGroupIdProvider;
import '../../theme/spacing.dart';
import '../../utils/active_group_context.dart';
import '../../utils/friendly_error.dart';
import '../../utils/haptics.dart';
import '../../widgets/alert.dart';
import '../../widgets/app_button.dart';
import '../../widgets/app_card.dart';
import '../../widgets/app_icon.dart';
import '../../widgets/app_toast.dart';
import '../../widgets/chip.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/mitlist_app_bar.dart';
import '../../widgets/skeleton.dart';

enum _Phase { loading, ready, saving, notFound, error }

/// Landing screen for a recipe share link (`/r/<token>`).
///
/// This is the one screen that renders for a signed-out visitor: the share
/// token is the credential, and someone who was sent a recipe should see it
/// before being asked to install anything. Signed in, they get save buttons;
/// signed out, they get the recipe plus a prompt to get the app.
class SharedRecipeScreen extends ConsumerStatefulWidget {
  const SharedRecipeScreen({super.key, required this.token});

  final String token;

  @override
  ConsumerState<SharedRecipeScreen> createState() => _SharedRecipeScreenState();
}

class _SharedRecipeScreenState extends ConsumerState<SharedRecipeScreen> {
  _Phase _phase = _Phase.loading;
  SharedRecipe? _shared;
  String? _error;
  List<Group> _groups = const [];

  AppLocalizations get l10n => AppLocalizations.of(context)!;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    setState(() {
      _phase = _Phase.loading;
      _error = null;
    });
    try {
      final service = await ref.read(recipeServiceProviderAsync.future);
      final shared = await service.getSharedRecipe(widget.token);
      if (!mounted) return;
      setState(() {
        _shared = shared;
        _phase = _Phase.ready;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        // A revoked or mistyped token is the ordinary case here, not a fault
        // worth an error message full of API wording.
        _phase = _isNotFound(e) ? _Phase.notFound : _Phase.error;
        _error = friendlyErrorMessage(e, l10n);
      });
    }

    // Households are only needed for the "save to household" button, so a
    // failure here must not take the recipe down with it.
    try {
      final groups = await ref.read(cachedGroupsProvider.future);
      if (mounted) setState(() => _groups = groups);
    } catch (_) {}
  }

  bool _isNotFound(Object e) {
    final text = e.toString().toLowerCase();
    return text.contains('not found') || text.contains('404');
  }

  Group? _activeGroup() {
    final id = resolveActiveGroupId(_groups, ref.read(currentGroupIdProvider));
    if (id == null) return null;
    for (final g in _groups) {
      if (g.id == id) return g;
    }
    return null;
  }

  Future<void> _save({Group? household}) async {
    if (_phase == _Phase.saving) return;
    setState(() => _phase = _Phase.saving);
    try {
      final service = await ref.read(recipeServiceProviderAsync.future);
      final saved = await service.saveSharedRecipe(
        widget.token,
        visibility: household == null
            ? RecipeVisibility.private
            : RecipeVisibility.household,
        groupId: household?.id,
      );
      if (!mounted) return;
      unawaited(Haptics.success());
      AppToast.success(context, l10n.sharedRecipeSaved);
      // Straight into the user's own copy — the shared view is a preview and
      // has nothing more to offer once it has been saved.
      context.goNamed('recipeDetail', pathParameters: {'recipeId': saved.id});
    } catch (e) {
      if (!mounted) return;
      setState(() => _phase = _Phase.ready);
      AppToast.error(context, friendlyErrorMessage(e, l10n));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: MitlistAppBar(
        title: Text(l10n.sharedRecipeTitle),
        showStandardActions: false,
      ),
      body: SafeArea(child: _buildBody()),
      bottomNavigationBar: _phase == _Phase.ready || _phase == _Phase.saving
          ? SafeArea(child: _buildActions())
          : null,
    );
  }

  Widget _buildBody() {
    switch (_phase) {
      case _Phase.loading:
        return const Padding(
          padding: EdgeInsets.all(MitlistSpacing.md),
          child: AppSkeleton(width: double.infinity, height: 240),
        );
      case _Phase.notFound:
        return AppEmptyState(
          icon: const AppIcon(name: 'link', size: 40),
          title: l10n.sharedRecipeNotFoundTitle,
          description: l10n.sharedRecipeNotFoundBody,
        );
      case _Phase.error:
        return Padding(
          padding: const EdgeInsets.all(MitlistSpacing.md),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AppAlert(type: AppAlertType.error, message: _error ?? ''),
              const SizedBox(height: MitlistSpacing.md),
              AppButton(text: l10n.commonRetry, onPressed: _load),
            ],
          ),
        );
      case _Phase.ready:
      case _Phase.saving:
        return _buildRecipe();
    }
  }

  /// True in a phone browser, the one place a `mitlist://` link can reach an
  /// installed app. On a desktop browser the same link only produces a
  /// "no application" error, so the button is not offered there.
  bool get _isMobileBrowser =>
      kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS);

  /// Hops from the web page into the installed app.
  ///
  /// The triple slash matters: Flutter hands the router the URL's *path*, so
  /// `mitlist:///r/<token>` arrives as `/r/<token>` and matches the route,
  /// whereas `mitlist://r/<token>` would make `r` the host and leave the
  /// router looking at `/<token>`. The Android intent filter is written for
  /// the same shape. See invite_link.dart for the matching join link.
  Future<void> _openInApp() => launchUrl(
        Uri.parse('mitlist:///r/${widget.token}'),
        webOnlyWindowName: '_self',
      );

  Widget _buildRecipe() {
    final shared = _shared!;
    final recipe = shared.recipe;
    final theme = Theme.of(context);
    final signedIn = ref.watch(authStateProvider);

    return ListView(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      children: [
        if (recipe.imageUrl != null && recipe.imageUrl!.isNotEmpty)
          ClipRRect(
            borderRadius: BorderRadius.circular(MitlistSpacing.sm),
            child: Image.network(
              recipe.imageUrl!,
              height: 200,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const SizedBox.shrink(),
            ),
          ),
        const SizedBox(height: MitlistSpacing.md),
        Text(recipe.title, style: theme.textTheme.headlineSmall),
        if (recipe.author.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.xs),
          Text(
            l10n.sharedRecipeBy(recipe.author),
            style: theme.textTheme.bodySmall,
          ),
        ],
        if (recipe.description.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.sm),
          Text(recipe.description, style: theme.textTheme.bodyMedium),
        ],
        if (recipe.tags.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.sm),
          Wrap(
            spacing: MitlistSpacing.xs,
            runSpacing: MitlistSpacing.xs,
            children: recipe.tags
                .map((t) => AppChip(label: t, selected: false))
                .toList(),
          ),
        ],
        if (shared.ingredients.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.lg),
          Text(l10n.recipeDetailIngredients,
              style: theme.textTheme.titleMedium),
          const SizedBox(height: MitlistSpacing.sm),
          ...shared.ingredients.map(
            (i) => Padding(
              padding: const EdgeInsets.only(bottom: MitlistSpacing.xs),
              child: Text(
                i.rawText.isNotEmpty ? i.rawText : i.name,
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ),
        ],
        if (shared.steps.isNotEmpty) ...[
          const SizedBox(height: MitlistSpacing.lg),
          Text(l10n.recipeDetailSteps, style: theme.textTheme.titleMedium),
          const SizedBox(height: MitlistSpacing.sm),
          ...shared.steps.asMap().entries.map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: MitlistSpacing.sm),
                  child: Text(
                    '${e.key + 1}. ${e.value.description}',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ),
        ],
        // The browser is where a link lands when the device has not claimed
        // it for the app. Signed out, that is the moment to pitch the app.
        // Signed in on a phone, a one-tap hop into the installed app is still
        // worth offering: the recipe belongs in the app's kitchen, not a tab.
        if (kIsWeb && (!signedIn || _isMobileBrowser)) ...[
          const SizedBox(height: MitlistSpacing.lg),
          AppCard(
            child: Padding(
              padding: const EdgeInsets.all(MitlistSpacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (!signedIn) ...[
                    Text(
                      l10n.sharedRecipeGetAppTitle,
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: MitlistSpacing.xs),
                    Text(
                      l10n.sharedRecipeGetAppBody,
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: MitlistSpacing.md),
                  ],
                  // The custom scheme opens the installed app even where the
                  // https App Link has not been verified on the device.
                  AppButton(
                    text: l10n.sharedRecipeOpenInApp,
                    variant: AppButtonVariant.outline,
                    icon: const AppIcon(name: 'openInNew'),
                    onPressed: _openInApp,
                  ),
                ],
              ),
            ),
          ),
        ],
        const SizedBox(height: MitlistSpacing.xl),
      ],
    );
  }

  Widget _buildActions() {
    final saving = _phase == _Phase.saving;
    final household = _activeGroup();

    // Signed out, there is no library to save into: point at sign-in instead of
    // showing buttons that would only bounce them there anyway. The share
    // link is pinned as the post-login destination so signing in brings them
    // straight back to this recipe rather than dropping them on /home.
    if (!ref.watch(authStateProvider)) {
      return Padding(
        padding: const EdgeInsets.all(MitlistSpacing.md),
        child: AppButton(
          text: l10n.sharedRecipeSignInToSave,
          onPressed: () {
            ref.read(pendingAuthNavigationProvider.notifier).state =
                '/r/${widget.token}';
            context.goNamed('welcome');
          },
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(MitlistSpacing.md),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AppButton(
            text: l10n.sharedRecipeSavePersonal,
            isLoading: saving,
            onPressed: saving ? null : () => _save(),
          ),
          if (household != null) ...[
            const SizedBox(height: MitlistSpacing.sm),
            AppButton(
              text: l10n.sharedRecipeSaveHousehold(household.name),
              variant: AppButtonVariant.outline,
              onPressed: saving ? null : () => _save(household: household),
            ),
          ],
        ],
      ),
    );
  }
}
