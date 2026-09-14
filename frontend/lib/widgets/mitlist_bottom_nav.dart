import 'package:flutter/material.dart';

import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/shadows.dart';
import '../theme/spacing.dart';
import '../theme/theme.dart';
import '../theme/typography.dart';
import '../utils/haptics.dart';
import 'app_icon.dart';
import 'odometer.dart';

/// One destination in [MitlistBottomNav].
class MitlistNavItem {
  const MitlistNavItem({
    required this.iconName,
    required this.label,
    this.badgeCount = 0,
  });

  /// Semantic icon name resolved by [AppIcon].
  final String iconName;

  final String label;

  /// Pending-work count. Zero hides the badge.
  final int badgeCount;
}

/// The app's bottom navigation.
///
/// Material's [BottomNavigationBar] tints an icon and calls it a day, which
/// says nothing in a system built on 2px ink borders, zero radius and hard
/// offset shadows. Here the selection is a physical object instead: a solid
/// primary slab that *slides* to the tab you picked, so the thing that tells
/// you where you are is continuous rather than teleporting between tints.
///
/// Every tab presses into its shadow on touch — the same move [AppButton] and
/// [AppCard] make — so the control the user touches most often finally shares
/// the app's signature physics.
///
/// Respects [MediaQueryData.disableAnimations]: the slab jumps, badges snap,
/// and the press translation is dropped.
class MitlistBottomNav extends StatefulWidget {
  const MitlistBottomNav({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onTap,
    this.animate = true,
  });

  final List<MitlistNavItem> items;
  final int currentIndex;

  /// False while the shell is still restoring the tab the user left on. The
  /// slab has to be sitting there when the app appears, not slide into place
  /// while the user watches: a product loads into a task, it doesn't perform.
  final bool animate;

  /// Fires for every tab, including the one already selected — the caller
  /// decides whether that means "switch branch" or "pop to root".
  final ValueChanged<int> onTap;

  /// Height of the bar's content, above the bottom safe area.
  static const double contentHeight = 56;

  /// Inset between a cell's edge and the selection slab.
  static const double _slabInset = MitlistSpacing.space1;

  @override
  State<MitlistBottomNav> createState() => _MitlistBottomNavState();
}

class _MitlistBottomNavState extends State<MitlistBottomNav> {
  int? _pressedIndex;
  int? _focusedIndex;

  void _handleTap(int index) {
    Haptics.light();
    widget.onTap(index);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final isDark = theme.brightness == Brightness.dark;
    final disableAnimations =
        MediaQuery.of(context).disableAnimations || !widget.animate;

    // The slab carries the accent as a fill, so it needs the shade that keeps
    // ink legible on it in each mode (light 6.3:1, dark 8.4:1).
    final slabColor = Theme.of(context).colorScheme.primary;
    const onSlabColor = MitlistColors.neutral950;

    final barColor =
        isDark ? MitlistColors.neutral900 : MitlistColors.surfacePrimary;

    // One weight for every label. The slab and the ink/muted colour carry the
    // selected state; changing weight mid-slide would reflow the text while
    // it moves, and a nav bar that twitches is worse than one that doesn't
    // shout.
    final labelStyle = theme.textTheme.labelSmall!.copyWith(
      fontWeight: FontWeight.w600,
    );
    final restColor =
        isDark ? MitlistColors.neutral400 : MitlistColors.textTertiary;

    // Let the bar grow with the user's text scale instead of clipping labels,
    // but stop it from eating the screen at the extreme end of the range.
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.6);
    final labelExtent =
        scaler.scale(labelStyle.fontSize ?? 11) * (labelStyle.height ?? 1.45);
    final barHeight = MitlistBottomNav.contentHeight +
        (labelExtent - 16).clamp(0, double.infinity);

    return Semantics(
      container: true,
      explicitChildNodes: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: barColor,
          border: Border(
            top: BorderSide(color: colorScheme.outline, width: 2),
          ),
        ),
        // Scaffold does not wrap bottomNavigationBar in a Material, and the
        // cells' InkWells need one for focus and gesture plumbing. Transparent
        // so the DecoratedBox above stays the visible surface.
        child: Material(
          type: MaterialType.transparency,
          child: SafeArea(
            top: false,
            child: SizedBox(
              height: barHeight,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final count = widget.items.length;
                  final cellWidth = constraints.maxWidth / count;
                  final isRtl = Directionality.of(context) == TextDirection.rtl;
                  final slabPressed = _pressedIndex == widget.currentIndex;
                  final slabShift = slabPressed
                      ? MitlistShadows.shadowSoft[0].offset
                      : Offset.zero;
                  // The ink offset stands in for a shadow, so it has to be the
                  // ink of the current mode. In dark mode the outline is light
                  // and a black offset would simply disappear.
                  final inkColor = colorScheme.outline;

                  // Leave the slab's offset room inside the bar so the shadow
                  // isn't sheared off at the outer tabs.
                  const inset = MitlistBottomNav._slabInset;
                  final offset = MitlistShadows.shadowSoft[0].offset.dx;
                  final slabWidth = cellWidth - inset * 2 - offset;
                  final slabHeight = barHeight - inset * 2 - offset;

                  return TweenAnimationBuilder<double>(
                    tween: Tween<double>(end: widget.currentIndex.toDouble()),
                    duration: disableAnimations
                        ? Duration.zero
                        : MitlistAnimations.navSlab,
                    curve: MitlistAnimations.easeEnter,
                    builder: (context, position, _) {
                      final slabSlot =
                          isRtl ? (count - 1) - position : position;
                      final slabRect = Rect.fromLTWH(
                        slabSlot * cellWidth + inset + slabShift.dx,
                        inset + slabShift.dy,
                        slabWidth,
                        slabHeight,
                      );

                      Widget row(Color contentColor, {required bool live}) {
                        return Row(
                          children: [
                            for (var i = 0; i < count; i++)
                              Expanded(
                                child: _NavCell(
                                  item: widget.items[i],
                                  contentColor: contentColor,
                                  pressed: _pressedIndex == i,
                                  focused: _focusedIndex == i,
                                  selected: i == widget.currentIndex,
                                  disableAnimations: disableAnimations,
                                  labelStyle: labelStyle,
                                  outlineColor: inkColor,
                                  onTap: live ? () => _handleTap(i) : null,
                                  onPressChanged: live
                                      ? (down) => setState(
                                            () =>
                                                _pressedIndex = down ? i : null,
                                          )
                                      : null,
                                  onFocusChanged: live
                                      ? (has) => setState(
                                            () =>
                                                _focusedIndex = has ? i : null,
                                          )
                                      : null,
                                ),
                              ),
                          ],
                        );
                      }

                      return Stack(
                        children: [
                          Positioned.fromRect(
                            rect: slabRect,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                color: slabColor,
                                border: Border.all(color: inkColor, width: 2),
                                boxShadow: slabPressed
                                    ? MitlistShadows.shadowNone
                                    : [
                                        BoxShadow(
                                          color: inkColor,
                                          offset: Offset(offset, offset),
                                        ),
                                      ],
                              ),
                            ),
                          ),
                          row(restColor, live: true),
                          // The same row again in ink, clipped to the slab.
                          // Lerping a label's colour as the slab arrives leaves
                          // it a mid-tone on orange for the length of the slide,
                          // which is exactly when it can't be read. Clipping
                          // instead means the colour boundary IS the slab edge:
                          // a label the slab is halfway across is ink where the
                          // orange is and muted where it isn't, legible in both
                          // halves, for every frame of the travel.
                          Positioned.fill(
                            child: IgnorePointer(
                              child: ExcludeSemantics(
                                child: ClipRect(
                                  clipper: _RectClipper(slabRect),
                                  child: row(onSlabColor, live: false),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({
    required this.item,
    required this.contentColor,
    required this.pressed,
    required this.focused,
    required this.selected,
    required this.disableAnimations,
    required this.labelStyle,
    required this.outlineColor,
    required this.onTap,
    required this.onPressChanged,
    required this.onFocusChanged,
  });

  final MitlistNavItem item;
  final Color contentColor;
  final bool pressed;
  final bool focused;
  final bool selected;
  final bool disableAnimations;
  final TextStyle labelStyle;
  final Color outlineColor;

  /// Null for the clipped ink copy, which is decoration only.
  final VoidCallback? onTap;
  final ValueChanged<bool>? onPressChanged;
  final ValueChanged<bool>? onFocusChanged;

  @override
  Widget build(BuildContext context) {
    // Unselected cells have no slab to sink into, so their content makes the
    // same press move on its own — the physics stay identical across tabs.
    final shift = pressed && !disableAnimations
        ? MitlistShadows.shadowSoft[0].offset
        : Offset.zero;

    final style = labelStyle.copyWith(color: contentColor);

    final content = AnimatedContainer(
      duration: disableAnimations ? Duration.zero : MitlistAnimations.micro,
      curve: MitlistTheme.easeMicro,
      transform: Matrix4.translationValues(shift.dx, shift.dy, 0),
      alignment: Alignment.center,
      // Keyboard focus needs to read against both the bar and the slab, so it
      // is drawn on the cell rather than inside it, where the slab's own
      // border would swallow it.
      foregroundDecoration: focused
          ? BoxDecoration(border: Border.all(color: outlineColor, width: 2))
          : null,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          _NavIcon(
            iconName: item.iconName,
            color: contentColor,
            badgeCount: item.badgeCount,
            outlineColor: outlineColor,
            disableAnimations: disableAnimations,
          ),
          const SizedBox(height: MitlistSpacing.space0_5),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: MitlistSpacing.space1,
            ),
            child: Text(
              item.label,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );

    // The clipped ink copy is decoration: no gestures, no focus node, no
    // second semantics node for the same tab.
    if (onTap == null) return content;

    // Merged, not excluded: the tab has to announce as ONE node carrying the
    // label from here and the tap action and focusability from the InkWell.
    // Excluding the subtree instead would silence the action and leave a
    // button a screen reader cannot activate.
    return MergeSemantics(
      child: Semantics(
        button: true,
        enabled: true,
        selected: selected,
        label: item.badgeCount > 0
            ? '${item.label}, ${item.badgeCount}'
            : item.label,
        // InkWell rather than a bare GestureDetector: it carries the focus
        // node and Enter/Space activation that Material's BottomNavigationBar
        // gave for free, which a raw detector would quietly drop. Its ink
        // effects are all off — this system presses, it does not ripple.
        child: InkWell(
          onTap: onTap,
          onTapDown: (_) => onPressChanged?.call(true),
          onTapUp: (_) => onPressChanged?.call(false),
          onTapCancel: () => onPressChanged?.call(false),
          onFocusChange: onFocusChanged,
          splashFactory: NoSplash.splashFactory,
          splashColor: Colors.transparent,
          highlightColor: Colors.transparent,
          hoverColor: Colors.transparent,
          focusColor: Colors.transparent,
          // The icon and label are already spoken by the label above.
          child: ExcludeSemantics(child: content),
        ),
      ),
    );
  }
}

/// Clips to an absolute rectangle in the bar's own coordinate space.
class _RectClipper extends CustomClipper<Rect> {
  const _RectClipper(this.rect);

  final Rect rect;

  @override
  Rect getClip(Size size) => rect;

  @override
  bool shouldReclip(_RectClipper oldClipper) => oldClipper.rect != rect;
}

class _NavIcon extends StatelessWidget {
  const _NavIcon({
    required this.iconName,
    required this.color,
    required this.badgeCount,
    required this.outlineColor,
    required this.disableAnimations,
  });

  final String iconName;
  final Color? color;
  final int badgeCount;
  final Color outlineColor;
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    final icon = AppIcon(name: iconName, size: 22, color: color);
    if (badgeCount <= 0) return icon;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        icon,
        Positioned(
          top: -MitlistSpacing.space2,
          right: -MitlistSpacing.space2,
          child: _NavBadge(
            count: badgeCount,
            outlineColor: outlineColor,
            disableAnimations: disableAnimations,
          ),
        ),
      ],
    );
  }
}

/// A hard-edged count. Material's badge is a soft pill that floats; this one
/// is a bordered square that belongs to the same drawing as everything else,
/// and its digits roll rather than pop so a count going 2 → 3 reads as the
/// same badge changing instead of a new badge appearing.
class _NavBadge extends StatelessWidget {
  const _NavBadge({
    required this.count,
    required this.outlineColor,
    required this.disableAnimations,
  });

  final int count;
  final Color outlineColor;
  final bool disableAnimations;

  @override
  Widget build(BuildContext context) {
    // Fully specified on purpose. MitlistOdometer measures a digit with the
    // style it is handed but renders through Text, which merges the ambient
    // DefaultTextStyle — any field left open (family, letter spacing) makes
    // the measured wheel wider than the glyph and the digits drift apart.
    // The mono face settles it for good: every figure has the same advance.
    final scaler = MediaQuery.textScalerOf(context).clamp(maxScaleFactor: 1.6);
    final style = TextStyle(
      fontFamily: MitlistTypography.monoFamily,
      fontSize: scaler.scale(10),
      height: 1.2,
      letterSpacing: 0,
      fontWeight: FontWeight.w700,
      color: MitlistColors.textOnError,
    );

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 16),
      child: DecoratedBox(
        decoration: BoxDecoration(
          // error600, not error500: white on error500 is 3.77:1, below AA.
          color: MitlistColors.error600,
          border: Border.all(color: outlineColor, width: 1.5),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: MitlistSpacing.space1 / 2,
            vertical: 1,
          ),
          // The size above is already scaled, so the subtree must not scale it
          // a second time — that would render glyphs larger than the wheels
          // the odometer measured and clip them.
          child: MediaQuery.withNoTextScaling(
            child: Center(
              widthFactor: 1,
              child: count > 99
                  ? Text('99+', style: style)
                  : MitlistOdometer(
                      value: count,
                      textStyle: style,
                      duration: disableAnimations
                          ? Duration.zero
                          : MitlistAnimations.medium,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}
