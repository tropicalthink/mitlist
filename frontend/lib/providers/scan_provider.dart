import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/scan_service.dart';

final scanServiceProviderAsync = FutureProvider<ScanService>((ref) async {
  return ScanService.create(ref);
});
