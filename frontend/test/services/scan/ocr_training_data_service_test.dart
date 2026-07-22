import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:mitlist/services/scan/ocr_training_data_service.dart';
import 'package:mitlist/services/scan/scan_models.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late OcrTrainingDataService service;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    root = await Directory.systemTemp.createTemp('mitlist_ocr_training_test_');
    service = OcrTrainingDataService(
      supportDirectory: () async => root,
      temporaryDirectory: () async => root,
    );
  });

  tearDown(() async {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  test('records only opted-in manually reviewed line crops', () async {
    const userId = 'private-account-id';
    final image = img.Image(width: 240, height: 100);
    img.fill(image, color: img.ColorRgb8(255, 255, 255));
    final bytes = Uint8List.fromList(img.encodeJpg(image));
    const corrected = GroceryPrediction(
      id: 'line-1',
      rawText: 'Olivenol',
      displayName: 'Olivenöl',
      bbox: OcrBBox(20, 20, 180, 42),
      confidenceLevel: ConfidenceLevel.autoAccept,
      confidenceScore: 1,
      userConfirmed: true,
    );

    expect(
      await service.recordReviewedLines(
        userId: userId,
        imageBytes: bytes,
        engine: 'test-onnx',
        items: const [corrected],
      ),
      0,
    );

    await service.setEnabled(userId, true);
    expect(
      await service.recordReviewedLines(
        userId: userId,
        imageBytes: bytes,
        engine: 'test-onnx',
        items: const [
          corrected,
          GroceryPrediction(
            id: 'not-reviewed',
            rawText: 'Milch',
            displayName: 'Milch',
            bbox: OcrBBox(20, 20, 180, 42),
          ),
        ],
      ),
      1,
    );
    expect(await service.sampleCount(userId), 1);

    final exported = await service.exportArchive(userId);
    expect(exported, isNotNull);
    final archive = ZipDecoder().decodeBytes(await exported!.readAsBytes());
    final names = archive.files.map((file) => file.name).toSet();
    expect(names, containsAll(['samples.jsonl', 'rec_gt.txt', 'README.txt']));
    expect(names.any((name) => name.startsWith('crops/')), isTrue);

    final manifest = utf8.decode(
      (archive.files.singleWhere((file) => file.name == 'samples.jsonl').content
          as List<int>),
    );
    expect(manifest, contains('Olivenöl'));
    expect(manifest, isNot(contains(userId)));
    expect(manifest, isNot(contains('group_id')));
  });

  test('clear removes samples and disables collection', () async {
    const userId = 'account';
    await service.setEnabled(userId, true);
    await service.clear(userId);

    expect(await service.isEnabled(userId), isFalse);
    expect(await service.sampleCount(userId), 0);
  });
}
