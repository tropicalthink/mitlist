import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/weekly_summary_models.dart';
import '../services/weekly_summary_service.dart';

final weeklySummaryServiceProviderAsync =
    FutureProvider<WeeklySummaryService>((ref) async {
  return WeeklySummaryService.create(ref);
});

/// The weekly summary for one household.
///
/// Keyed by group id rather than reading the current group inside the provider:
/// a weekly-digest notification can name a household other than the active one,
/// and the screen must be able to show that household's week while the group
/// switch settles.
final weeklySummaryProvider =
    FutureProvider.family<WeeklySummary, String>((ref, groupId) async {
  final service = await ref.watch(weeklySummaryServiceProviderAsync.future);
  return service.getWeeklySummary(groupId);
});
