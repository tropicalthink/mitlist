/// Models for the household weekly summary
/// (`GET /api/v1/groups/{id}/weekly-summary`).
///
/// The category keys are the server's stable API values — see
/// `backend/internal/models/weekly_summary.go`. The client maps them to icons
/// and localized labels but never invents or reorders them: the order the
/// server sends is the order they render in.
library;

class WeeklyCategoryCount {
  const WeeklyCategoryCount({
    required this.category,
    required this.count,
    required this.previous,
    required this.mine,
  });

  factory WeeklyCategoryCount.fromJson(Map<String, dynamic> json) {
    return WeeklyCategoryCount(
      category: json['category'] as String? ?? '',
      count: (json['count'] as num?)?.toInt() ?? 0,
      previous: (json['previous'] as num?)?.toInt() ?? 0,
      mine: (json['mine'] as num?)?.toInt() ?? 0,
    );
  }

  final String category;
  final int count;
  final int previous;

  /// How many of [count] the signed-in user is attributed with.
  final int mine;

  int get delta => count - previous;
}

class WeeklyDayCount {
  const WeeklyDayCount({required this.date, required this.count});

  factory WeeklyDayCount.fromJson(Map<String, dynamic> json) {
    return WeeklyDayCount(
      date: DateTime.tryParse(json['date'] as String? ?? '')?.toLocal() ??
          DateTime.now(),
      count: (json['count'] as num?)?.toInt() ?? 0,
    );
  }

  final DateTime date;
  final int count;
}

class WeeklySummary {
  const WeeklySummary({
    required this.groupId,
    required this.periodStart,
    required this.periodEnd,
    required this.total,
    required this.previous,
    required this.mine,
    required this.minePrevious,
    required this.categories,
    required this.days,
    required this.activeMembers,
    required this.memberCount,
  });

  factory WeeklySummary.fromJson(Map<String, dynamic> json) {
    final rawCategories = json['categories'] as List<dynamic>? ?? const [];
    final rawDays = json['days'] as List<dynamic>? ?? const [];
    return WeeklySummary(
      groupId: json['group_id'] as String? ?? '',
      periodStart:
          DateTime.tryParse(json['period_start'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      periodEnd:
          DateTime.tryParse(json['period_end'] as String? ?? '')?.toLocal() ??
              DateTime.now(),
      total: (json['total'] as num?)?.toInt() ?? 0,
      previous: (json['previous'] as num?)?.toInt() ?? 0,
      mine: (json['mine'] as num?)?.toInt() ?? 0,
      minePrevious: (json['mine_previous'] as num?)?.toInt() ?? 0,
      categories: rawCategories
          .map((e) =>
              WeeklyCategoryCount.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      days: rawDays
          .map((e) => WeeklyDayCount.fromJson((e as Map).cast<String, dynamic>()))
          .toList(),
      activeMembers: (json['active_members'] as num?)?.toInt() ?? 0,
      memberCount: (json['member_count'] as num?)?.toInt() ?? 0,
    );
  }

  final String groupId;
  final DateTime periodStart;
  final DateTime periodEnd;
  final int total;
  final int previous;
  final int mine;
  final int minePrevious;
  final List<WeeklyCategoryCount> categories;
  final List<WeeklyDayCount> days;
  final int activeMembers;
  final int memberCount;

  int get delta => total - previous;

  /// Week-over-week change as a percentage of last week.
  ///
  /// Null when last week was zero: "up 100%" from nothing is noise, and the UI
  /// shows a "first week" treatment instead of a misleading percentage.
  int? get deltaPercent {
    if (previous == 0) return null;
    return ((total - previous) / previous * 100).round();
  }

  /// The user's share of this week's household total, 0..1.
  double get mineShare => total == 0 ? 0 : mine / total;

  /// True when the user did strictly more than they did last week — the
  /// personal signal, independent of how the household as a whole did.
  bool get personalImprovement => mine > minePrevious;

  /// The busiest single day, used to scale the sparkline. Never zero, so the
  /// chart can divide by it safely.
  int get peakDay =>
      days.fold<int>(1, (max, d) => d.count > max ? d.count : max);

  bool get isEmpty => total == 0;
}
