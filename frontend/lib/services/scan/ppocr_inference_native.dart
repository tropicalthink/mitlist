import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
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
///
/// Everything after the asset load runs on one long-lived worker isolate:
/// JPEG decode, tensor building, detector post-processing, line crops, CTC
/// beam search and strikethrough analysis are seconds of pure Dart per page,
/// and on the calling (UI) isolate they froze the scan screen. The worker owns
/// both ONNX sessions and runs them synchronously.
class PpOcrInference {
  PpOcrInference({PpOcrProcessor processor = const PpOcrProcessor()})
      : _processor = processor;

  final PpOcrProcessor _processor;
  Future<_OcrWorker>? _worker;
  Completer<void>? _operationLock;
  bool _disposed = false;

  Future<List<OcrLine>> recognise(Uint8List imageBytes) =>
      _withOperationLock(() async {
        final worker = await _ensureWorker();
        return worker.recognise(imageBytes);
      });

  Future<List<OcrLine>> recogniseFromPath(String path) async =>
      recognise(await File(path).readAsBytes());

  Future<_OcrWorker> _ensureWorker() {
    return _worker ??= _OcrWorker.start(_processor).catchError(
      (Object error, StackTrace stackTrace) {
        // A failed start (missing models) may succeed after a later fetch.
        _worker = null;
        Error.throwWithStackTrace(error, stackTrace);
      },
    );
  }

  /// Scans run one at a time so a second capture never interleaves with the
  /// first inside the worker.
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

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    while (_operationLock != null) {
      await _operationLock!.future;
    }
    final pending = _worker;
    _worker = null;
    if (pending == null) return;
    try {
      await (await pending).close();
    } catch (_) {
      // Never started; nothing to release.
    }
  }
}

/// The main-isolate handle on the OCR worker.
class _OcrWorker {
  _OcrWorker._(this._isolate, this._commands);

  final Isolate _isolate;
  final SendPort _commands;

  static Future<_OcrWorker> start(PpOcrProcessor processor) async {
    // rootBundle is a platform channel, so the bytes are read here and moved
    // (not copied) to the worker.
    final detector = await _loadAsset(_detectorAsset);
    final recognizer = await _loadAsset(_recognizerAsset);
    final characters =
        (jsonDecode(await rootBundle.loadString(_charactersAsset)) as List)
            .cast<String>();

    final handshake = ReceivePort();
    final isolate = await Isolate.spawn(
      _ocrWorkerMain,
      handshake.sendPort,
      debugName: 'ppocr-worker',
    );
    final commands = await handshake.first as SendPort;
    handshake.close();

    final reply = ReceivePort();
    commands.send(_InitRequest(
      reply: reply.sendPort,
      detector: TransferableTypedData.fromList([detector]),
      recognizer: TransferableTypedData.fromList([recognizer]),
      characters: characters,
      detectorMaxSide: processor.detectorMaxSide,
    ));
    final result = await reply.first;
    reply.close();
    if (result is _WorkerError) {
      isolate.kill(priority: Isolate.immediate);
      throw StateError('PP-OCR worker failed to start: ${result.message}');
    }
    return _OcrWorker._(isolate, commands);
  }

  Future<List<OcrLine>> recognise(Uint8List imageBytes) async {
    final reply = ReceivePort();
    _commands.send(_RecogniseRequest(
      reply: reply.sendPort,
      image: TransferableTypedData.fromList([imageBytes]),
    ));
    final result = await reply.first;
    reply.close();
    if (result is _WorkerError) {
      throw StateError('PP-OCR recognition failed: ${result.message}');
    }
    return result as List<OcrLine>;
  }

  Future<void> close() async {
    final reply = ReceivePort();
    _commands.send(_CloseRequest(reply.sendPort));
    await reply.first;
    reply.close();
    _isolate.kill();
  }

  static Future<Uint8List> _loadAsset(String path) async {
    final data = await rootBundle.load(path);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}

class _InitRequest {
  const _InitRequest({
    required this.reply,
    required this.detector,
    required this.recognizer,
    required this.characters,
    required this.detectorMaxSide,
  });

  final SendPort reply;
  final TransferableTypedData detector;
  final TransferableTypedData recognizer;
  final List<String> characters;
  final int detectorMaxSide;
}

class _RecogniseRequest {
  const _RecogniseRequest({required this.reply, required this.image});

  final SendPort reply;
  final TransferableTypedData image;
}

class _CloseRequest {
  const _CloseRequest(this.reply);

  final SendPort reply;
}

class _WorkerError {
  const _WorkerError(this.message);

  final String message;
}

void _ocrWorkerMain(SendPort handshake) {
  final commands = ReceivePort();
  handshake.send(commands.sendPort);
  _OcrEngine? engine;

  commands.listen((message) {
    switch (message) {
      case _InitRequest():
        try {
          engine = _OcrEngine.create(message);
          message.reply.send(true);
        } catch (error) {
          message.reply.send(_WorkerError('$error'));
        }
      case _RecogniseRequest():
        final current = engine;
        if (current == null) {
          message.reply.send(const _WorkerError('worker not initialised'));
          return;
        }
        try {
          message.reply.send(
              current.recognise(message.image.materialize().asUint8List()));
        } catch (error) {
          message.reply.send(_WorkerError('$error'));
        }
      case _CloseRequest():
        engine?.release();
        engine = null;
        message.reply.send(true);
        commands.close();
    }
  });
}

/// The worker-side OCR pipeline. Owns the ONNX environment and sessions.
class _OcrEngine {
  _OcrEngine._(
    this._processor,
    this._detector,
    this._recognizer,
    this._characters,
    this._allowedClasses,
  );

  final PpOcrProcessor _processor;
  final OrtSession _detector;
  final OrtSession _recognizer;
  final List<String> _characters;
  final Int32List _allowedClasses;

  static _OcrEngine create(_InitRequest request) {
    OrtEnv.instance.init();
    final options = OrtSessionOptions()
      ..setIntraOpNumThreads(4)
      ..setInterOpNumThreads(1)
      ..setSessionGraphOptimizationLevel(GraphOptimizationLevel.ortEnableAll);
    OrtSession? detector;
    try {
      detector = OrtSession.fromBuffer(
          request.detector.materialize().asUint8List(), options);
      final recognizer = OrtSession.fromBuffer(
          request.recognizer.materialize().asUint8List(), options);
      return _OcrEngine._(
        PpOcrProcessor(detectorMaxSide: request.detectorMaxSide),
        detector,
        recognizer,
        request.characters,
        PpOcrProcessor.latinClasses(request.characters),
      );
    } catch (_) {
      detector?.release();
      OrtEnv.instance.release();
      rethrow;
    } finally {
      options.release();
    }
  }

  List<OcrLine> recognise(Uint8List imageBytes) {
    final source = _processor.decode(imageBytes);
    final detectorInput = _processor.detectorTensor(source);
    final probability = _detectorProbability(_run(
      _detector,
      detectorInput.data,
      [1, 3, detectorInput.height, detectorInput.width],
    ));
    final regions = _processor.detectorRegions(
      probability,
      originalWidth: source.width,
      originalHeight: source.height,
    );

    final recognized = <PpOcrRecognizedRegion>[];
    for (final region in regions.take(80)) {
      final crop = _processor.crop(source, region);
      final recognitionInput = _processor.recognitionTensor(crop);
      final candidates = _processor.decodeCtcCandidates(
        _recognitionLogits(_run(
          _recognizer,
          recognitionInput.data,
          [1, 3, recognitionInput.height, recognitionInput.width],
        )),
        _characters,
        allowedClasses: _allowedClasses,
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

  Object? _run(OrtSession session, Float32List data, List<int> shape) {
    final input = OrtValueTensor.createTensorWithDataList(data, shape);
    final options = OrtRunOptions();
    List<OrtValue?>? outputs;
    try {
      outputs = session.run(options, {'x': input});
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

  void release() {
    _detector.release();
    _recognizer.release();
    OrtEnv.instance.release();
  }
}
