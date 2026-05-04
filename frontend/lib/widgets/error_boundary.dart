import 'dart:ui' show PlatformDispatcher;

import 'package:flutter/material.dart';

import '../theme/colors.dart';
import '../theme/spacing.dart';
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
    return Material(
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(MitlistSpacing.lg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline,
                  size: 48, color: MitlistColors.error500),
              const SizedBox(height: MitlistSpacing.md),
              Text(
                'Something went wrong',
                style: Theme.of(context).textTheme.titleMedium,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MitlistSpacing.sm),
              Text(
                'An unexpected error occurred. The team has been notified.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: MitlistColors.textSecondary,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: MitlistSpacing.lg),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Try again'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
