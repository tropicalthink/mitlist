import 'package:flutter/material.dart';

/// Drops keyboard focus when the user taps somewhere that nothing else
/// handles — empty space between cards, a heading, a decorative surface.
///
/// Multiline fields ([TextInputAction.newline]) leave the iOS keyboard without
/// a "Done" key, and iPhones have no hardware back, so a screen that inlines
/// such a field (the hub's pinwall composer) has to offer this itself or the
/// keyboard stays up until the user leaves the screen. Wrap the scrollable
/// body, not the whole scaffold, so app-bar actions keep their own gestures.
///
/// Tappable children still win the gesture arena, so buttons, fields and
/// cards behave exactly as before; only otherwise-unhandled taps reach here.
class DismissKeyboardOnTap extends StatelessWidget {
  const DismissKeyboardOnTap({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: child,
    );
  }
}
