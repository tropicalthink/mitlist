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
      contentType: _normalizeContentType(contentType, filename),
      byteSize: bytes.length,
    );

    await _remote.uploadToPresignedUrl(
      uploadUrl: intent.uploadUrl,
      bytes: bytes,
      // The presigned URL is signed for the content type the server accepted
      // (it coerces types it doesn't allow), so the PUT must echo that value
      // exactly — sending the caller's raw type breaks the signature and the
      // storage rejects the upload.
      contentType: intent.attachment.contentType,
    );

    return await _remote.finalizeUpload(
      groupId: groupId,
      attachmentId: intent.attachment.id,
    );
  }

  /// The server only accepts concrete MIME types; wildcards like `image/*`
  /// get coerced to `application/octet-stream`, which then serves images
  /// without an image content type. Resolve those from the file extension.
  static String _normalizeContentType(String contentType, String filename) {
    final t = contentType.trim();
    if (t.isNotEmpty && !t.contains('*')) return t;

    final dot = filename.lastIndexOf('.');
    final ext = dot >= 0 ? filename.substring(dot + 1).toLowerCase() : '';
    return switch (ext) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'gif' => 'image/gif',
      'webp' => 'image/webp',
      'heic' => 'image/heic',
      'heif' => 'image/heif',
      'pdf' => 'application/pdf',
      'txt' => 'text/plain',
      'csv' => 'text/csv',
      _ => 'application/octet-stream',
    };
  }
}
