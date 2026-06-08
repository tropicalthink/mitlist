import 'package:flutter/material.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';

class PasswordStrengthBar extends StatelessWidget {
  final String password;

  const PasswordStrengthBar({super.key, required this.password});

  static int computeStrength(String p) {
    if (p.isEmpty) return 0;
    if (p.length < 6) return 1;
    final hasUpper = p.contains(RegExp(r'[A-Z]'));
    final hasLower = p.contains(RegExp(r'[a-z]'));
    final hasDigit = p.contains(RegExp(r'\d'));
    final hasSpecial = p.contains(RegExp(r'[^A-Za-z0-9]'));
    if (p.length >= 10 && hasUpper && hasLower && (hasDigit || hasSpecial)) {
      return 4;
    }
    if (p.length >= 8 && (hasDigit || hasUpper)) return 3;
    return 2;
  }

  static String _label(int strength) {
    return switch (strength) {
      1 => 'Weak',
      2 => 'Fair',
      3 => 'Good',
      4 => 'Strong',
      _ => '',
    };
  }

  static Color _colorForStrength(int strength) {
    return switch (strength) {
      1 => MitlistColors.error500,
      2 => MitlistColors.warning500,
      3 => MitlistColors.primary400,
      4 => MitlistColors.success500,
      _ => Colors.transparent,
    };
  }

  @override
  Widget build(BuildContext context) {
    final strength = computeStrength(password);
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final duration = disableAnimations ? Duration.zero : MitlistAnimations.medium;
    final color = _colorForStrength(strength);
    final label = _label(strength);
    final emptyColor = Theme.of(context).colorScheme.outlineVariant;

    return AnimatedOpacity(
      opacity: password.isEmpty ? 0.0 : 1.0,
      duration: duration,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: List.generate(4, (index) {
              final filled = strength > index;
              return Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    right: index < 3 ? MitlistSpacing.space1 : 0,
                  ),
                  child: AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOut,
                    height: 3,
                    color: filled ? color : emptyColor,
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: MitlistSpacing.xs),
          AnimatedSwitcher(
            duration: duration,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween<Offset>(
                  begin: const Offset(0, 0.3),
                  end: Offset.zero,
                ).animate(CurvedAnimation(
                  parent: animation,
                  curve: Curves.easeOut,
                )),
                child: child,
              ),
            ),
            child: label.isNotEmpty
                ? Text(
                    key: ValueKey(strength),
                    label,
                    style: MitlistTypography.labelXSmall(color: color),
                  )
                : const SizedBox.shrink(key: ValueKey(0)),
          ),
        ],
      ),
    );
  }
}
