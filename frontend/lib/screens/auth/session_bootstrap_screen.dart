import 'package:flutter/material.dart';
import '../../theme/spacing.dart';
import '../../theme/typography.dart';

/// Shown while persisted auth is restored. Avoids flashing marketing / sign-in
/// routes when reloading deep links into the app.
class SessionBootstrapScreen extends StatelessWidget {
  const SessionBootstrapScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('mitlist',
                  style: MitlistTypography.logo(
                    color: Theme.of(context).colorScheme.onSurface,
                  )),
              const SizedBox(height: MitlistSpacing.lg),
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
