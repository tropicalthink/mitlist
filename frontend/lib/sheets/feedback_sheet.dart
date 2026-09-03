import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../l10n/app_localizations.dart';
import '../models/feature_board_models.dart';
import '../screens/you/feature_board_widgets.dart';
import '../services/feedback_service.dart';
import '../theme/spacing.dart';
import '../utils/route_history.dart';
import '../widgets/alert.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';
import '../widgets/app_toast.dart';

/// Opens the "Send feedback" bottom sheet.
///
/// The current route is captured at open time (before the sheet itself shows)
/// so the submission can report which screen the user was on; the previous
/// route rides along in metadata for when the sheet is reached via the
/// account screen.
Future<void> showFeedbackSheet(BuildContext context, WidgetRef ref) {
  final l10n = AppLocalizations.of(context)!;

  String? sourcePage;
  try {
    sourcePage = GoRouterState.of(context).uri.toString();
  } catch (_) {
    sourcePage = RouteHistory.current;
  }
  final previousPage = RouteHistory.previous;

  final textController = TextEditingController();
  var kind = FeatureBoardKind.feature;
  var isSending = false;
  String? error;

  return showAppBottomSheet<void>(
    context: context,
    title: l10n.feedbackSheetTitle,
    body: StatefulBuilder(
      builder: (sheetContext, setSheetState) {
        Future<void> submit() async {
          final text = textController.text.trim();
          if (text.isEmpty) {
            setSheetState(() => error = l10n.feedbackEmpty);
            return;
          }
          setSheetState(() {
            isSending = true;
            error = null;
          });
          try {
            await ref.read(feedbackServiceProvider).submitFeatureRequest(
                  text: text,
                  kind: kind,
                  sourcePage: sourcePage,
                  previousPage: previousPage,
                );
            if (!sheetContext.mounted) return;
            Navigator.of(sheetContext).pop();
            if (!context.mounted) return;
            AppToast.success(context, l10n.feedbackSent);
          } catch (_) {
            setSheetState(() {
              isSending = false;
              error = l10n.feedbackFailed;
            });
          }
        }

        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              l10n.feedbackSheetIntro,
              style: Theme.of(sheetContext).textTheme.bodyMedium,
            ),
            const SizedBox(height: MitlistSpacing.md),
            FeatureBoardKindSelector(
              value: kind,
              onChanged: (value) => setSheetState(() => kind = value),
            ),
            const SizedBox(height: MitlistSpacing.md),
            if (error != null) ...[
              AppAlert(type: AppAlertType.error, message: error!),
              const SizedBox(height: MitlistSpacing.md),
            ],
            AppInput(
              controller: textController,
              label: l10n.feedbackFieldLabel,
              hint: l10n.feedbackFieldHint,
              minLines: 3,
              maxLines: 6,
              maxLength: 5000,
              keyboardType: TextInputType.multiline,
            ),
            const SizedBox(height: MitlistSpacing.lg),
            AppButton(
              text: isSending ? l10n.feedbackSending : l10n.feedbackSend,
              isLoading: isSending,
              onPressed: isSending ? null : submit,
            ),
          ],
        );
      },
    ),
  ).whenComplete(textController.dispose);
}
