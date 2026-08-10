import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:archive/archive_io.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import 'ppocr_processor.dart';
import 'scan_models.dart';

const _uuid = Uuid();
const _enabledPreferencePrefix = 'ocr_training_capture_enabled_';
const _writerPreferencePrefix = 'ocr_training_writer_id_';

/// Opt-in, local-only collection of corrected OCR line crops.
///
/// The store deliberately has no API client and records no account, household,
/// or list identifiers. A random per-account writer token is retained solely so
/// training tools can enforce writer-disjoint validation splits.
class OcrTrainingDataService {
  OcrTrainingDataService({
    Future<Directory> Function()? supportDirectory,
    Future<Directory> Function()? temporaryDirectory,
    PpOcrProcessor processor = const PpOcrProcessor(),
  })  : _supportDirectory = supportDirectory ?? getApplicationSupportDirectory,
        _temporaryDirectory = temporaryDirectory ?? getTemporaryDirectory,
        _processor = processor;

  final Future<Directory> Function() _supportDirectory;
  final Future<Directory> Function() _temporaryDirectory;
  final PpOcrProcessor _processor;
  Future<void> _writeTail = Future.value();

  Future<bool> isEnabled(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_enabledPreferencePrefix$userId') ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> setEnabled(String userId, bool enabled) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('$_enabledPreferencePrefix$userId', enabled);
  }

  /// Saves eligible manually reviewed lines and returns the number written.
  Future<int> recordReviewedLines({
    required String userId,
    required Uint8List imageBytes,
    required String engine,
    required Iterable<GroceryPrediction> items,
  }) async {
    if (!await isEnabled(userId)) return 0;
    final eligible = items.where(_isEligible).toList(growable: false);
    if (eligible.isEmpty) return 0;

    var written = 0;
    final operation = _writeTail.then((_) async {
      written = await _record(
        userId: userId,
        imageBytes: imageBytes,
        engine: engine,
        items: eligible,
      );
    });
    _writeTail = operation.catchError((_) {});
    await operation;
    return written;
  }

  bool _isEligible(GroceryPrediction item) {
    final label = _cleanLabel(item.displayName);
    return item.userConfirmed &&
        item.bbox != null &&
        item.markStatus == MarkStatus.normal &&
        item.quantity == 1 &&
        item.unit.isEmpty &&
        item.priceCents == null &&
        label.isNotEmpty &&
        label.length <= 96;
  }

  Future<int> _record({
    required String userId,
    required Uint8List imageBytes,
    required String engine,
    required List<GroceryPrediction> items,
  }) async {
    final source = _processor.decode(imageBytes);
    final writerId = await _writerId(userId);
    final root = await _writerDirectory(writerId);
    final crops = Directory('${root.path}/crops');
    await crops.create(recursive: true);
    final labels = File('${root.path}/samples.jsonl');
    final sink = labels.openWrite(mode: FileMode.append, encoding: utf8);
    var written = 0;
    try {
      for (final item in items) {
        final box = item.bbox!;
        final region = PpOcrRegion(
          left: box.left.round().clamp(0, source.width - 1).toInt(),
          top: box.top.round().clamp(0, source.height - 1).toInt(),
          right: (box.left + box.width).round().clamp(1, source.width).toInt(),
          bottom:
              (box.top + box.height).round().clamp(1, source.height).toInt(),
          score: 1,
        );
        if (region.right <= region.left || region.bottom <= region.top) {
          continue;
        }
        final id = _uuid.v4();
        final relativePath = 'crops/$id.jpg';
        final crop = _processor.crop(source, region);
        await File('${root.path}/$relativePath').writeAsBytes(
          img.encodeJpg(crop, quality: 95),
          flush: true,
        );
        sink.writeln(jsonEncode({
          'schema_version': 1,
          'id': id,
          'writer_id': writerId,
          'image': relativePath,
          'label': _cleanLabel(item.displayName),
          'raw_ocr': _cleanLabel(item.rawText),
          'engine': engine,
          'created_at': DateTime.now().toUtc().toIso8601String(),
          'bbox': {
            'left': box.left,
            'top': box.top,
            'width': box.width,
            'height': box.height,
          },
        }));
        written++;
      }
    } finally {
      await sink.flush();
      await sink.close();
    }
    return written;
  }

  Future<int> sampleCount(String userId) async {
    final writerId = await _existingWriterId(userId);
    if (writerId == null) return 0;
    final file =
        File('${(await _writerDirectory(writerId)).path}/samples.jsonl');
    if (!file.existsSync()) return 0;
    return file
        .openRead()
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .where((line) => line.trim().isNotEmpty)
        .length;
  }

  /// Produces a deliberate, user-initiated archive. Nothing is uploaded.
  Future<File?> exportArchive(String userId) async {
    await _writeTail;
    final writerId = await _existingWriterId(userId);
    if (writerId == null) return null;
    final root = await _writerDirectory(writerId);
    final samples = File('${root.path}/samples.jsonl');
    if (!samples.existsSync() || await sampleCount(userId) == 0) return null;

    await _writePaddleLabels(root, samples);
    await File('${root.path}/README.txt').writeAsString(
      'Private mitlist OCR correction export.\n'
      'samples.jsonl contains metadata; rec_gt.txt is PaddleOCR format.\n'
      'Images are corrected line crops, not complete list photographs.\n',
      flush: true,
    );
    final temp = await _temporaryDirectory();
    final output = File('${temp.path}/mitlist_ocr_training_$writerId.zip');
    if (output.existsSync()) output.deleteSync();
    await ZipFileEncoder().zipDirectoryAsync(root, filename: output.path);
    return output;
  }

  Future<void> _writePaddleLabels(Directory root, File samples) async {
    final output = File('${root.path}/rec_gt.txt').openWrite(encoding: utf8);
    try {
      await for (final line in samples
          .openRead()
          .transform(utf8.decoder)
          .transform(const LineSplitter())) {
        if (line.trim().isEmpty) continue;
        final sample = jsonDecode(line) as Map<String, dynamic>;
        output.writeln('${sample['image']}\t${sample['label']}');
      }
    } finally {
      await output.flush();
      await output.close();
    }
  }

  Future<void> clear(String userId) async {
    await _writeTail;
    final prefs = await SharedPreferences.getInstance();
    final writerId = prefs.getString('$_writerPreferencePrefix$userId');
    if (writerId != null) {
      final dir = await _writerDirectory(writerId);
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    }
    await prefs.remove('$_writerPreferencePrefix$userId');
    await prefs.remove('$_enabledPreferencePrefix$userId');
  }

  Future<String?> _existingWriterId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_writerPreferencePrefix$userId');
  }

  Future<String> _writerId(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_writerPreferencePrefix$userId';
    final existing = prefs.getString(key);
    if (existing != null) return existing;
    final created = _uuid.v4();
    await prefs.setString(key, created);
    return created;
  }

  Future<Directory> _writerDirectory(String writerId) async {
    final support = await _supportDirectory();
    return Directory('${support.path}/ocr_training/$writerId');
  }

  String _cleanLabel(String value) => value
      .replaceAll(RegExp(r'[\r\n\t]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
