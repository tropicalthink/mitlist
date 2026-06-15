import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../l10n/app_localizations.dart';
import '../theme/spacing.dart';
import '../widgets/app_button.dart';
import '../services/error_reporter.dart';

class MitlistErrorBoundary extends StatefulWidget {
  final Widget child;

  const MitlistErrorBoundary({super.key, required this.child});

  @override
  State<MitlistErrorBoundary> createState() => _MitlistErrorBoundaryState();
}

class _MitlistErrorBoundaryState extends State<MitlistErrorBoundary> {
  Object? _error;
  StackTrace? _stackTrace;

  @override
  void initState() {
    super.initState();
    FlutterError.onError = (details) {
      FlutterError.presentError(details);
      ErrorReporter().captureException(
        details.exception,
        stackTrace: details.stack,
      );
    };
    PlatformDispatcher.instance.onError = (error, stack) {
      ErrorReporter().captureException(error, stackTrace: stack);
      return true;
    };
  }

  @override
  Widget build(BuildContext context) {
    return _error != null
        ? _ErrorFallback(
            error: _error!,
            stackTrace: _stackTrace,
            onRetry: () => setState(() {
              _error = null;
              _stackTrace = null;
            }),
          )
        : widget.child;
  }
}

class _ErrorFallback extends StatelessWidget {
  final Object error;
  final StackTrace? stackTrace;
  final VoidCallback onRetry;

  const _ErrorFallback({
    required this.error,
    required this.stackTrace,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;

    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(MitlistSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.error_outline,
                  size: 48, color: colorScheme.error),
              const SizedBox(height: MitlistSpacing.md),
              Text(
                l10n.errorSomethingWentWrong,
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MitlistSpacing.sm),
              Text(
                l10n.errorSomethingWentWrong,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MitlistSpacing.lg),
              AppButton(
                text: l10n.commonRetry,
                icon: const Icon(Icons.refresh),
                variant: AppButtonVariant.outline,
                onPressed: onRetry,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
