import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../l10n/app_localizations.dart';
import '../models/external_calendar_models.dart';
import '../providers/external_calendar_provider.dart';
import '../services/api_error_mapper.dart';
import '../theme/spacing.dart';
import '../utils/friendly_error.dart';
import '../widgets/app_bottom_sheet.dart';
import '../widgets/app_button.dart';
import '../widgets/app_input.dart';

/// Adds a private iCal link ("Calendar link"): a name, the link, and short
/// steps for finding it in Google Calendar, iCloud and Outlook. Resolves to
/// the new connection, or null when dismissed.
Future<CalendarConnection?> showAddCalendarLinkSheet(BuildContext context) {
  final l10n = AppLocalizations.of(context)!;
  return showAppBottomSheet<CalendarConnection>(
    context: context,
    title: l10n.calendarLinkSheetTitle,
    body: const AddCalendarLinkForm(),
  );
}

/// Accepts https:// and webcal:// (the server treats webcal as https).
bool isPlausibleCalendarLink(String raw) {
  final uri = Uri.tryParse(raw.trim());
  if (uri == null || uri.host.isEmpty) return false;
  return const {'https', 'webcal', 'webcals'}
      .contains(uri.scheme.toLowerCase());
}

/// The words for a failed add: the server's `not_calendar` and fetch
/// failures get their own explanation; anything else the usual friendly
/// message. Never the raw error.
String addLinkErrorMessage(Object error, AppLocalizations l10n) {
  final code = error is ApiException ? error.code : null;
  final status = error is ApiException
      ? error.cause?.response?.statusCode
      : (error is DioException ? error.response?.statusCode : null);
  switch (code) {
    case 'not_calendar':
      return l10n.calendarLinkErrorNotCalendar;
    case 'too_large':
      return l10n.calendarConnectionErrorTooLarge;
    case 'unauthorized':
      return l10n.calendarConnectionErrorUnauthorized;
    case 'fetch_failed':
      return l10n.calendarLinkErrorFetch;
  }
  // 400 validation_error: the link was refused (not https), or the
  // 10-connection limit; the screen checks the limit before opening.
  if (status == 400) return l10n.calendarLinkErrorUrl;
  if (status == 422 || status == 502 || status == 504) {
    return l10n.calendarLinkErrorFetch;
  }
  return friendlyErrorMessage(error, l10n);
}

class AddCalendarLinkForm extends ConsumerStatefulWidget {
  const AddCalendarLinkForm({super.key});

  @override
  ConsumerState<AddCalendarLinkForm> createState() =>
      _AddCalendarLinkFormState();
}

class _AddCalendarLinkFormState extends ConsumerState<AddCalendarLinkForm> {
  final _name = TextEditingController();
  final _url = TextEditingController();
  String? _urlError;
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final l10n = AppLocalizations.of(context)!;
    final url = _url.text.trim();
    if (!isPlausibleCalendarLink(url)) {
      setState(() => _urlError = l10n.calendarLinkErrorUrl);
      return;
    }
    setState(() {
      _urlError = null;
      _error = null;
      _saving = true;
    });
    try {
      final service = await ref.read(externalCalendarServiceProvider.future);
      // Optional: without one the server names it from the feed.
      final created = await service.addIcsConnection(
        name: _name.text.trim(),
        url: url,
      );
      if (!mounted) return;
      Navigator.of(context).pop(created);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = addLinkErrorMessage(e, l10n);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final muted = theme.textTheme.bodySmall
        ?.copyWith(color: theme.colorScheme.onSurfaceVariant);
    final steps = [
      (l10n.calendarLinkStepsGoogleTitle, l10n.calendarLinkStepsGoogle),
      (l10n.calendarLinkStepsAppleTitle, l10n.calendarLinkStepsApple),
      (l10n.calendarLinkStepsOutlookTitle, l10n.calendarLinkStepsOutlook),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        AppInput(
          key: const ValueKey('calendar-link-name'),
          controller: _name,
          label: l10n.commonName,
          hint: l10n.calendarLinkNameHint,
          maxLength: 60,
          textInputAction: TextInputAction.next,
        ),
        const SizedBox(height: MitlistSpacing.md),
        AppInput(
          key: const ValueKey('calendar-link-url'),
          controller: _url,
          label: l10n.calendarLinkUrlLabel,
          hint: l10n.calendarLinkUrlHint,
          errorText: _urlError,
          keyboardType: TextInputType.url,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
        ),
        const SizedBox(height: MitlistSpacing.xs),
        Text(l10n.calendarLinkPrivacyNote, style: muted),
        if (_error != null) ...[
          const SizedBox(height: MitlistSpacing.sm),
          Semantics(
            liveRegion: true,
            child: Text(
              _error!,
              key: const ValueKey('calendar-link-error'),
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.error),
            ),
          ),
        ],
        const SizedBox(height: MitlistSpacing.md),
        AppButton(
          text: l10n.commonAdd,
          isLoading: _saving,
          onPressed: _saving ? null : _submit,
        ),
        const SizedBox(height: MitlistSpacing.lg),
        Text(
          l10n.calendarLinkStepsTitle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall,
        ),
        for (final (title, body) in steps) ...[
          const SizedBox(height: MitlistSpacing.sm),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelLarge,
          ),
          Text(body, style: muted),
        ],
      ],
    );
  }
}
