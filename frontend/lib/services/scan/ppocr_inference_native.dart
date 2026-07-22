import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/services.dart';
import 'package:onnxruntime/onnxruntime.dart';

import 'ppocr_processor.dart';
import 'scan_models.dart';

const _detectorAsset = 'assets/models/ocr/ppocrv6_small_det/inference.onnx';
const _recognizerAsset = 'assets/models/ocr/ppocrv6_medium_rec/inference.onnx';
const _charactersAsset = 'assets/models/ocr/ppocrv6_medium_rec/characters.json';

/// Runs both PP-OCRv6 graphs locally through the same ONNX Runtime CPU path on
/// Android and iOS. No platform OCR API, network request, or cloud model is
/// involved.
class PpOcrInference {
  PpOcrInference({PpOcrProcessor processor = const PpOcrProcessor()})
      : _processor = processor;

  final PpOcrProcessor _processor;
  OrtSession? _detector;
  OrtSession? _recognizer;
  List<String>? _characters;
  Future<void>? _initializing;
  Completer<void>? _operationLock;
  bool _environmentInitialized = false;
  bool _disposed = false;

  Future<List<OcrLine>> recognise(Uint8List imageBytes) =>
      _withOperationLock(() => _recognise(imageBytes));

  Future<List<OcrLine>> _recognise(Uint8List imageBytes) async {
    await _ensureInitialized();
    final source = _processor.decode(imageBytes);
    final detectorInput = _processor.detectorTensor(source);
    final detectorOutput = await _run(
      _detector!,
      detectorInput.data,
      [1, 3, detectorInput.height, detectorInput.width],
    );
    final probability = _detectorProbability(detectorOutput);
    final regions = _processor.detectorRegions(
      probability,
      originalWidth: source.width,
      originalHeight: source.height,
    );

    final recognized = <PpOcrRecognizedRegion>[];
    for (final region in regions.take(80)) {
      final crop = _processor.crop(source, region);
      final recognitionInput = _processor.recognitionTensor(crop);
      final recognitionOutput = await _run(
        _recognizer!,
        recognitionInput.data,
        [1, 3, recognitionInput.height, recognitionInput.width],
      );
      final candidates = _processor.decodeCtcCandidates(
        _recognitionLogits(recognitionOutput),
        _characters!,
      );
      final decoded = candidates.first;
      if (decoded.text.isEmpty) continue;
      recognized.add(PpOcrRecognizedRegion(
        region: region,
        text: decoded.text,
        confidence: decoded.confidence,
        crossedOut: _processor.hasStrikethrough(crop),
        alternatives: candidates.skip(1).toList(growable: false),
      ));
    }

    return _processor.mergeLineFragments(recognized).map((line) {
      final region = line.region;
      return OcrLine(
        text: line.text,
        confidence: line.confidence,
        markStatus: line.crossedOut ? MarkStatus.crossedOut : MarkStatus.normal,
        bbox: OcrBBox(
          region.left.toDouble(),
          region.top.toDouble(),
          region.width.toDouble(),
          region.height.toDouble(),
        ),
        alternatives: [
          for (final candidate in line.alternatives)
            OcrAlternative(
              text: candidate.text,
              relativeScore: candidate.confidence,
            ),
        ],
      );
    }).toList(growable: false);
  }

  Future<List<OcrLine>> recogniseFromPath(String path) async =>
      recognise(await File(path).readAsBytes());

  /// The wrapper's async session has one response stream per model. Serializing
  /// complete scans prevents overlapping captures from consuming each other's
  /// detector or recognizer response.
  Future<T> _withOperationLock<T>(Future<T> Function() operation) async {
    while (_operationLock != null) {
      await _operationLock!.future;
    }
    if (_disposed) throw StateError('PP-OCR inference has been disposed.');
    final lock = Completer<void>();
    _operationLock = lock;
    try {
      return await operation();
    } finally {
      if (identical(_operationLock, lock)) _operationLock = null;
      lock.complete();
    }
  }

  Future<void> _ensureInitialized() => _initializing ??= _initialize();

  Future<void> _initialize() async {
    OrtEnv.instance.init();
    _environmentInitialized = true;
    final options = OrtSessionOptions()
      ..setIntraOpNumThreads(4)
      ..setInterOpNumThreads(1)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    try {
      final detectorBytes = await _loadAsset(_detectorAsset);
      _detector = OrtSession.fromBuffer(detectorBytes, options);
      final recognizerBytes = await _loadAsset(_recognizerAsset);
      _recognizer = OrtSession.fromBuffer(recognizerBytes, options);
      _characters = (jsonDecode(await rootBundle.loadString(_charactersAsset))
              as List<dynamic>)
          .cast<String>();
    } catch (_) {
      _detector?.release();
      _recognizer?.release();
      _detector = null;
      _recognizer = null;
      if (_environmentInitialized) {
        OrtEnv.instance.release();
        _environmentInitialized = false;
      }
      rethrow;
    } finally {
      options.release();
    }
  }

  Future<Uint8List> _loadAsset(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }

  Future<Object?> _run(
    OrtSession session,
    Float32List data,
    List<int> shape,
  ) async {
    final input = OrtValueTensor.createTensorWithDataList(data, shape);
    final options = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      final future = session.runAsync(options, {'x': input});
      if (future == null) throw StateError('Could not start ONNX inference.');
      outputs = await future;
      if (outputs.isEmpty || outputs.first == null) {
        throw StateError('ONNX inference returned no output.');
      }
      return outputs.first!.value;
    } finally {
      input.release();
      options.release();
      if (outputs != null) {
        for (final output in outputs) {
          output?.release();
        }
      }
    }
  }

  List<List<double>> _detectorProbability(Object? output) {
    final batch = output as List<dynamic>;
    final channels = batch.single as List<dynamic>;
    final rows = channels.single as List<dynamic>;
    return rows
        .map((row) => (row as List<dynamic>)
            .map((value) => (value as num).toDouble())
            .toList(growable: false))
        .toList(growable: false);
  }

  List<List<double>> _recognitionLogits(Object? output) {
    final batch = output as List<dynamic>;
    return (batch.single as List<dynamic>)
        .map((timestep) => (timestep as List<dynamic>)
            .map((value) => (value as num).toDouble())
            .toList(growable: false))
        .toList(growable: false);
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    while (_operationLock != null) {
      await _operationLock!.future;
    }
    if (_initializing != null) {
      try {
        await _initializing;
      } catch (_) {
        return;
      }
    }
    _detector?.release();
    _recognizer?.release();
    _detector = null;
    _recognizer = null;
    if (_environmentInitialized) {
      OrtEnv.instance.release();
      _environmentInitialized = false;
    }
  }
}
