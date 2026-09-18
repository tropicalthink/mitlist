import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/home_service.dart';

final homeServiceProviderAsync = FutureProvider<HomeService>((ref) async {
  return HomeService.create(ref);
});
