import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';

import '../models/attachment_models.dart';
import 'api_client.dart';
import 'group_id_validator.dart';

class AttachmentService {
  final Dio _dio;
  final Logger _logger = Logger();

  AttachmentService._(this._dio);

  static Future<AttachmentService> create() async {
    final dio = createApiClient();
    return AttachmentService._(dio);
  }

  Future<UploadIntent> createUploadIntent({
    required String groupId,
    required String purpose,
    required String filename,
    required String contentType,
    required int byteSize,
  }) async {
    ensureValidGroupId(groupId);
    final r = await _dio.post(
      '/attachments/upload-intent',
      data: {
        'group_id': groupId,
        'purpose': purpose,
        'filename': filename,
        'content_type': contentType,
        'byte_size': byteSize,
      },
    );
    return UploadIntent.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<void> uploadToPresignedUrl({
    required String uploadUrl,
    required Uint8List bytes,
    required String contentType,
  }) async {
    final putClient = Dio(
      BaseOptions(
        // Presigned URL already has full host + query signature
        headers: {
          'Content-Type': contentType,
        },
        sendTimeout: const Duration(minutes: 2),
        receiveTimeout: const Duration(minutes: 2),
        connectTimeout: const Duration(seconds: 30),
      ),
    );

    try {
      await putClient.putUri(
        Uri.parse(uploadUrl),
        // A byte buffer lets native and browser HTTP stacks supply the exact
        // signed Content-Length themselves. Browsers forbid setting that
        // header manually.
        data: bytes,
        options: Options(
          contentType: contentType,
          headers: {
            // Ensure we don't accidentally send app Authorization header.
            'Authorization': null,
          },
        ),
      );
    } on DioException catch (e) {
      _logger.e(
          'Presigned upload failed: ${e.response?.statusCode} ${e.response?.data}');
      rethrow;
    }
  }

  Future<Attachment> finalizeUpload({
    required String groupId,
    required String attachmentId,
  }) async {
    ensureValidGroupId(groupId);
    final r = await _dio.post(
      '/attachments/$attachmentId/finalize',
      data: {'group_id': groupId},
    );
    return Attachment.fromJson((r.data as Map).cast<String, dynamic>());
  }

  Future<String> getDownloadUrl({
    required String groupId,
    required String attachmentId,
  }) async {
    ensureValidGroupId(groupId);
    final r = await _dio.get(
      '/attachments/$attachmentId/url',
      queryParameters: {'group_id': groupId},
    );
    final data = (r.data as Map).cast<String, dynamic>();
    return data['url'] as String;
  }

  Future<void> deleteAttachment({
    required String groupId,
    required String attachmentId,
  }) async {
    ensureValidGroupId(groupId);
    await _dio.delete(
      '/attachments/$attachmentId',
      queryParameters: {'group_id': groupId},
    );
  }
}
