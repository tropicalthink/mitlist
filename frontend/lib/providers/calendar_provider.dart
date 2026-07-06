import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/calendar_service.dart';

final calendarServiceProviderAsync =
    FutureProvider<CalendarService>((ref) async {
  return await CalendarService.create(ref);
});
