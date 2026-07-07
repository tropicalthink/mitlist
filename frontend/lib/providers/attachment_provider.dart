import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../repositories/attachment_repository.dart';
import '../services/attachment_service.dart';

final attachmentServiceProviderAsync =
    FutureProvider<AttachmentService>((ref) async {
  return AttachmentService.create();
});

final attachmentRepositoryProvider =
    FutureProvider<AttachmentRepository>((ref) async {
  final svc = await ref.read(attachmentServiceProviderAsync.future);
  return AttachmentRepository(remote: svc);
});
