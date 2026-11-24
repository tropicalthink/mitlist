import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../services/widgets/home_widget_kind.dart';
import '../theme/shadows.dart';
import '../theme/spacing.dart';
import 'app_icon.dart';

/// The display name of a home screen widget, as the Widgets page and the
/// widget gallery call it.
String homeWidgetName(AppLocalizations l10n, HomeWidgetKind kind) =>
    switch (kind) {
      HomeWidgetKind.shoppingList => l10n.widgetsPageShoppingListName,
      HomeWidgetKind.chores => l10n.widgetsPageChoresName,
      HomeWidgetKind.quickAdd => l10n.widgetsPageQuickAddName,
      HomeWidgetKind.household => l10n.widgetsPageHouseholdName,
    };

String homeWidgetDescription(AppLocalizations l10n, HomeWidgetKind kind) =>
    switch (kind) {
      HomeWidgetKind.shoppingList => l10n.widgetsPageShoppingListDesc,
      HomeWidgetKind.chores => l10n.widgetsPageChoresDesc,
      HomeWidgetKind.quickAdd => l10n.widgetsPageQuickAddDesc,
      HomeWidgetKind.household => l10n.widgetsPageHouseholdDesc,
    };

/// A home screen widget drawn in Flutter with sample content, so people can
/// see what they would be adding. The real widgets are native (plans/047);
/// this only has to read like them: square, 2px outline, orange accent.
///
/// Drawn at a fixed design size and scaled down to the space it gets, so a
/// preview looks the same on every phone.
class HomeWidgetPreview extends StatelessWidget {
  const HomeWidgetPreview({
    super.key,
    required this.kind,
    this.householdName,
    this.platform = TargetPlatform.android,
  });

  final HomeWidgetKind kind;

  /// Whose widget to draw where the platforms differ: quick add is a 4x1
  /// bar on Android and a small square on iOS.
  final TargetPlatform platform;

  bool get _isIosQuickAdd =>
      kind == HomeWidgetKind.quickAdd && platform == TargetPlatform.iOS;

  /// The household the preview names; a sample name when null.
  final String? householdName;

  static const double _defaultWidth = 320;

  /// The iOS small widget's design size (a square).
  static const double _iosSmallSide = 170;

  double get _width => _isIosQuickAdd ? _iosSmallSide : _defaultWidth;

  double get _height => switch (kind) {
        _ when _isIosQuickAdd => _iosSmallSide,
        HomeWidgetKind.shoppingList => 168,
        HomeWidgetKind.chores => 116,
        HomeWidgetKind.quickAdd => 72,
        HomeWidgetKind.household => 300,
      };

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final household = (householdName?.trim().isNotEmpty ?? false)
        ? householdName!.trim()
        : l10n.widgetsPageSampleHousehold;

    final body = switch (kind) {
      HomeWidgetKind.shoppingList => _ShoppingListBody(l10n: l10n),
      HomeWidgetKind.chores => _ChoresBody(l10n: l10n),
      HomeWidgetKind.quickAdd when _isIosQuickAdd =>
        _IosQuickAddBody(l10n: l10n),
      HomeWidgetKind.quickAdd => _QuickAddBody(l10n: l10n),
      HomeWidgetKind.household =>
        _HouseholdBody(l10n: l10n, household: household),
    };

    return Semantics(
      image: true,
      label: l10n.widgetsPagePreviewLabel(homeWidgetName(l10n, kind)),
      child: ExcludeSemantics(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: _width),
          child: AspectRatio(
            aspectRatio: _width / _height,
            child: FittedBox(
              fit: BoxFit.contain,
              // A picture of a widget, drawn at its design size: the user's
              // text size would only make the sample rows overflow it.
              child: MediaQuery.withNoTextScaling(
                child: Container(
                  width: _width,
                  height: _height,
                  padding: const EdgeInsets.all(MitlistSpacing.space3),
                  decoration: BoxDecoration(
                    color: scheme.surface,
                    border: Border.all(color: scheme.outline, width: 2),
                    boxShadow: MitlistShadows.shadowMedium,
                  ),
                  child: body,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.icon,
    required this.title,
    this.count,
    this.showAdd = false,
  });

  final String icon;
  final String title;
  final String? count;
  final bool showAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        AppIcon(name: icon, size: 18, color: scheme.primary),
        const SizedBox(width: MitlistSpacing.sm),
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
        ),
        if (count != null) ...[
          const SizedBox(width: MitlistSpacing.sm),
          Text(
            count!,
            maxLines: 1,
            style: theme.textTheme.labelSmall?.copyWith(
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
        if (showAdd) ...[
          const SizedBox(width: MitlistSpacing.sm),
          _AddBox(size: MitlistSpacing.space8),
        ],
      ],
    );
  }
}

class _AddBox extends StatelessWidget {
  const _AddBox({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.primary,
        border: Border.all(color: scheme.outline, width: 2),
      ),
      child: AppIcon(name: 'plus', size: size * 0.55, color: scheme.onPrimary),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({required this.label, this.done = false, this.trailing});

  final String label;
  final bool done;
  final String? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.space0_5),
      child: Row(
        children: [
          Container(
            width: MitlistSpacing.space4,
            height: MitlistSpacing.space4,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: done ? scheme.primary : scheme.surface,
              border: Border.all(
                color: done ? scheme.primary : scheme.outline,
                width: 2,
              ),
            ),
            child: done
                ? AppIcon(name: 'check', size: 11, color: scheme.onPrimary)
                : null,
          ),
          const SizedBox(width: MitlistSpacing.sm),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: done ? scheme.onSurfaceVariant : scheme.onSurface,
                decoration: done ? TextDecoration.lineThrough : null,
              ),
            ),
          ),
          if (trailing != null)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: MitlistSpacing.xs + MitlistSpacing.space0_5,
              ),
              decoration: BoxDecoration(
                border: Border.all(color: scheme.outline, width: 2),
              ),
              child: Text(
                trailing!,
                maxLines: 1,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: scheme.onSurface,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ShoppingListBody extends StatelessWidget {
  const _ShoppingListBody({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          icon: 'shoppingCart',
          title: l10n.widgetsPageSampleListName,
          count: l10n.widgetsPageSampleLeft(3),
          showAdd: true,
        ),
        const SizedBox(height: MitlistSpacing.sm),
        _CheckRow(label: l10n.widgetsPageSampleItem1),
        _CheckRow(label: l10n.widgetsPageSampleItem2, done: true),
        _CheckRow(label: l10n.widgetsPageSampleItem3),
        _CheckRow(label: l10n.widgetsPageSampleItem4),
      ],
    );
  }
}

class _ChoresBody extends StatelessWidget {
  const _ChoresBody({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(
          icon: 'clipboardDocumentList',
          title: l10n.widgetsPageChoresName,
          count: l10n.widgetsPageSampleDue(2),
        ),
        const SizedBox(height: MitlistSpacing.sm),
        _CheckRow(label: l10n.widgetsPageSampleChore1, trailing: 'Ines'),
        _CheckRow(label: l10n.widgetsPageSampleChore2, trailing: 'Sam'),
      ],
    );
  }
}

class _QuickAddBody extends StatelessWidget {
  const _QuickAddBody({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Row(
      children: [
        Expanded(
          child: Container(
            height: MitlistSpacing.space10,
            padding: const EdgeInsets.symmetric(horizontal: MitlistSpacing.sm),
            alignment: Alignment.centerLeft,
            decoration: BoxDecoration(
              border: Border.all(color: scheme.outline, width: 2),
            ),
            child: Text(
              l10n.widgetsPageSampleAddHint,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
        const SizedBox(width: MitlistSpacing.sm),
        const _AddBox(size: MitlistSpacing.space10),
      ],
    );
  }
}

/// iOS quick add (`systemSmall`): the orange plus square on top, "Add to"
/// and the list's name below, as the WidgetKit widget draws it.
class _IosQuickAddBody extends StatelessWidget {
  const _IosQuickAddBody({required this.l10n});

  final AppLocalizations l10n;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _AddBox(size: MitlistSpacing.space16),
        const Spacer(),
        Text(
          l10n.widgetsPageSampleAddTo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.labelMedium?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        Text(
          l10n.widgetsPageSampleListName,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleMedium?.copyWith(
            color: scheme.onSurface,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HouseholdBody extends StatelessWidget {
  const _HouseholdBody({required this.l10n, required this.household});

  final AppLocalizations l10n;
  final String household;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    Widget rule() => Padding(
          padding: const EdgeInsets.symmetric(vertical: MitlistSpacing.sm),
          child: Container(height: 2, color: scheme.outline),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Header(icon: 'home', title: household),
        rule(),
        _Header(
          icon: 'clipboardDocumentList',
          title: l10n.widgetsPageChoresName,
          count: l10n.widgetsPageSampleDue(2),
        ),
        const SizedBox(height: MitlistSpacing.xs),
        _CheckRow(label: l10n.widgetsPageSampleChore1, trailing: 'Ines'),
        _CheckRow(label: l10n.widgetsPageSampleChore2, trailing: 'Sam'),
        rule(),
        _Header(
          icon: 'shoppingCart',
          title: l10n.widgetsPageSampleListName,
          count: l10n.widgetsPageSampleLeft(3),
        ),
        const SizedBox(height: MitlistSpacing.xs),
        _CheckRow(label: l10n.widgetsPageSampleItem1),
        _CheckRow(label: l10n.widgetsPageSampleItem3),
        rule(),
        Row(
          children: [
            AppIcon(name: 'calendarDays', size: 18, color: scheme.primary),
            const SizedBox(width: MitlistSpacing.sm),
            Expanded(
              child: Text(
                l10n.widgetsPageSampleMeal,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.onSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
