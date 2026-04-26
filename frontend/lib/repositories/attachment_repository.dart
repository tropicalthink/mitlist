import 'dart:typed_data';

import '../models/attachment_models.dart';
import '../services/attachment_service.dart';

class AttachmentRepository {
  final AttachmentService _remote;

  AttachmentRepository({required AttachmentService remote}) : _remote = remote;

  /// Performs intent -> PUT -> finalize and returns the ready attachment.
  Future<Attachment> uploadAttachment({
    required String groupId,
    required String purpose,
    required String filename,
    required String contentType,
    required Uint8List bytes,
  }) async {
    final intent = await _remote.createUploadIntent(
      groupId: groupId,
      purpose: purpose,
      filename: filename,
      contentType: contentType,
      byteSize: bytes.length,
    );

    await _remote.uploadToPresignedUrl(
      uploadUrl: intent.uploadUrl,
      bytes: bytes,
      contentType: contentType,
    );

    return await _remote.finalizeUpload(
      groupId: groupId,
      attachmentId: intent.attachment.id,
    );
  }
}

