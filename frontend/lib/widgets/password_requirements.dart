import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/animations.dart';
import '../theme/colors.dart';
import '../theme/spacing.dart';
import '../theme/typography.dart';
import '../utils/password_policy.dart';

/// Live checklist of the password rules, shown under the password field.
///
/// Every requirement stays visible whether met or not — a list that hides
/// satisfied rules makes the remaining ones look like new errors appearing as
/// the user types.
class PasswordRequirements extends StatelessWidget {
  final String password;

  const PasswordRequirements({super.key, required this.password});

  String _labelFor(AppLocalizations l10n, PasswordRequirement requirement) {
    return switch (requirement) {
      PasswordRequirement.length => l10n.passwordRequirementLength,
      PasswordRequirement.uppercase => l10n.passwordRequirementUppercase,
      PasswordRequirement.digit => l10n.passwordRequirementDigit,
      PasswordRequirement.special => l10n.passwordRequirementSpecial,
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final unmetColor = theme.colorScheme.onSurfaceVariant;
    final disableAnimations = MediaQuery.of(context).disableAnimations;
    final duration =
        disableAnimations ? Duration.zero : MitlistAnimations.medium;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l10n.passwordRequirementsTitle,
          style: MitlistTypography.labelXSmall(color: unmetColor),
        ),
        const SizedBox(height: MitlistSpacing.xs),
        for (final requirement in PasswordRequirement.values) ...[
          Builder(builder: (context) {
            final met = requirement.isMetBy(password);
            final color = met ? MitlistColors.success500 : unmetColor;
            return Padding(
              padding: const EdgeInsets.only(bottom: MitlistSpacing.xs),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  AnimatedSwitcher(
                    duration: duration,
                    child: Icon(
                      met ? Icons.check_circle_rounded : Icons.circle_outlined,
                      key: ValueKey(met),
                      size: 14,
                      color: color,
                      // The icon duplicates the colour cue for anyone who
                      // cannot distinguish the two states by colour alone.
                      semanticLabel: met ? l10n.commonDone : null,
                    ),
                  ),
                  const SizedBox(width: MitlistSpacing.xs),
                  Expanded(
                    child: Text(
                      _labelFor(l10n, requirement),
                      style: MitlistTypography.labelXSmall(color: color),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ],
    );
  }
}
