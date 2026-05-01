import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'api_client.dart';

class ScanResult {
  final String type;
  final String? title;
  final List<ScanItem> items;
  final List<String> steps;
  final int? amount;

  const ScanResult({
    required this.type,
    this.title,
    this.items = const [],
    this.steps = const [],
    this.amount,
  });

  factory ScanResult.fromJson(Map<String, dynamic> json) => ScanResult(
        type: json['type'] as String,
        title: json['title'] as String?,
        items: (json['items'] as List<dynamic>?)
                ?.map((e) =>
                    ScanItem.fromJson((e as Map).cast<String, dynamic>()))
                .toList() ??
            const [],
        steps: (json['steps'] as List<dynamic>?)
                ?.map((e) => e as String)
                .toList() ??
            const [],
        amount: json['amount'] as int?,
      );
}

class ScanItem {
  final String name;
  final String? quantity;
  final String? unit;
  final int? priceCents;

  const ScanItem({
    required this.name,
    this.quantity,
    this.unit,
    this.priceCents,
  });

  factory ScanItem.fromJson(Map<String, dynamic> json) => ScanItem(
        name: json['name'] as String,
        quantity: json['quantity'] as String?,
        unit: json['unit'] as String?,
        priceCents: json['price_cents'] as int?,
      );
}

class ScanService {
  final Dio _dio;

  ScanService._(this._dio);

  static Future<ScanService> create([Ref? ref]) async {
    final dio = createApiClient(ref);
    return ScanService._(dio);
  }

  Future<ScanResult> scanImage(List<int> imageBytes, String mimeType) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(
        imageBytes,
        filename: 'scan.$mimeType',
        contentType: DioMediaType.parse(mimeType),
      ),
    });

    final r = await _dio.post('/assistant/scan', data: formData);
    return ScanResult.fromJson((r.data as Map).cast<String, dynamic>());
  }
}
