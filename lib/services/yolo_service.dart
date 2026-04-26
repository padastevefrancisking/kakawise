// lib/services/yolo_service.dart
//
// Parses the actual ultralytics_yolo predict() output observed from device logs:
//
//   Map {
//     'boxes':         List<Map>  — one per detection (see detection_result.dart)
//     'annotatedImage': List<int> — JPEG bytes with boxes/masks already drawn
//   }
//
// Key fixes vs previous version:
//   • Reads 'boxes' key (not 'predictions'/'results')
//   • Uses 'class'/'className' label (not 'tag')
//   • Uses x1_norm…y2_norm for bounding box (no letterbox math needed)
//   • Extracts annotatedImage bytes and stores them on InferenceResponse
//   • classConf map is built from 'boxes' detections, not raw results
//   • Confidence threshold lowered to 0.70 to be less aggressive

import 'dart:io';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui';

import 'package:ultralytics_yolo/ultralytics_yolo.dart';

import '../models/detection_result.dart';
import '../models/cacao_variety.dart';

const String _modelAssetPath = 'assets/models/best_float32.tflite';

class YoloService {
  static YOLO? _yolo;
  static bool _loaded = false;

  static Future<void> loadModel() async {
    if (_loaded) return;
    _yolo = YOLO(modelPath: _modelAssetPath, task: YOLOTask.segment);
    await _yolo!.loadModel();
    _loaded = true;
  }

  static Future<InferenceResponse> classify(File imageFile) async {
    if (!_loaded) await loadModel();

    // ── EXIF-correct decode → PNG ────────────────────────────────────────────
    final rawBytes = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(rawBytes);
    final frame = await codec.getNextFrame();
    final image = frame.image;
    final imgW = image.width;
    final imgH = image.height;
    final pngData = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    final Uint8List pngBytes = pngData!.buffer.asUint8List();

    // ── Run inference ────────────────────────────────────────────────────────
    final dynamic raw = await _yolo!.predict(pngBytes);

    print('=== RAW YOLO KEYS: ${raw is Map ? (raw as Map).keys.toList() : raw.runtimeType}');

    // ── Extract boxes list ───────────────────────────────────────────────────
    // The plugin returns { 'boxes': [...], 'annotatedImage': [...] }
    List<dynamic> boxes = [];
    Uint8List? annotatedBytes;

    if (raw is Map<String, dynamic>) {
      // Primary structure observed in logs
      final rawBoxes = raw['boxes'];
      if (rawBoxes is List) boxes = rawBoxes;

      // annotatedImage is List<int> JPEG bytes
      final rawAnnotated = raw['annotatedImage'];
      if (rawAnnotated is List && rawAnnotated.isNotEmpty) {
        annotatedBytes = Uint8List.fromList(rawAnnotated.cast<int>());
      }
    } else if (raw is List) {
      // Older plugin versions return a flat list of detection maps
      boxes = raw;
    }

    print('boxes count: ${boxes.length}');
    for (final b in boxes) {
      print('  box: $b');
    }

    // ── Build per-class confidence map (pre-filter, all detections) ──────────
    final Map<String, double> classConf = {
      for (final v in cacaoVarieties) v.id: 0.0,
    };
    for (final b in boxes) {
      final map = b as Map<String, dynamic>;
      final raw_tag = (map['class'] ?? map['className'] ?? map['tag'] ?? '').toString().trim();
      final conf = _d(map['confidence']);
      final variety = getVarietyByYoloClass(raw_tag)
          ?? getVarietyByYoloClass(raw_tag.toUpperCase())
          ?? getVarietyByYoloClass(raw_tag.toLowerCase());
      final id = variety?.id ?? raw_tag;
      if (classConf.containsKey(id) && conf > (classConf[id] ?? 0)) {
        classConf[id] = conf;
      }
    }

    print('classConf: $classConf');

    // ── Parse detections, apply threshold ────────────────────────────────────
    final List<DetectionResult> detections = [];
    for (final b in boxes) {
      final map = b as Map<String, dynamic>;
      final conf = _d(map['confidence']);

      print('parsing box: conf=$conf class=${map['class']} x1_norm=${map['x1_norm']} y1_norm=${map['y1_norm']} x2_norm=${map['x2_norm']} y2_norm=${map['y2_norm']}');

      if (conf < kConfidenceThreshold) {
        print('  → dropped (conf $conf < $kConfidenceThreshold)');
        continue;
      }

      detections.add(DetectionResult.fromBoxMap(
        map,
        allConfidences: Map.from(classConf),
      ));
    }

    detections.sort((a, b) => b.confidence.compareTo(a.confidence));
    print('final accepted detections: ${detections.length}');

    return InferenceResponse(
      detections: detections,
      imageWidth: imgW,
      imageHeight: imgH,
      annotatedImageBytes: annotatedBytes,
    );
  }
}

double _d(dynamic v) => (v as num? ?? 0).toDouble();

// ─── MOCK ─────────────────────────────────────────────────────────────────────
class YoloMock {
  static Future<InferenceResponse> classify(File imageFile) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    final rng = Random();
    final ids = ['W10', 'UF18', 'BR25'];
    final topIdx = rng.nextInt(3);
    final topConf = 0.85 + rng.nextDouble() * 0.14;
    final other1 = rng.nextDouble() * 0.06;
    final other2 = rng.nextDouble() * 0.03;

    final allConf = <String, double>{};
    for (var i = 0; i < 3; i++) {
      allConf[ids[i]] = i == topIdx
          ? topConf
          : (i == (topIdx + 1) % 3 ? other1 : other2);
    }

    final rawBytes = await imageFile.readAsBytes();
    final codec = await ui.instantiateImageCodec(rawBytes);
    final frame = await codec.getNextFrame();
    final imgW = frame.image.width;
    final imgH = frame.image.height;
    frame.image.dispose();

    final mask = List.generate(32, (i) {
      final angle = (i / 32) * 2 * pi;
      return Offset(0.50 + 0.30 * cos(angle), 0.50 + 0.35 * sin(angle));
    });

    final variety = getVarietyById(ids[topIdx])!;
    return InferenceResponse(
      imageWidth: imgW,
      imageHeight: imgH,
      detections: [
        DetectionResult(
          classId: variety.id,
          className: variety.name,
          yoloTag: variety.id,
          confidence: topConf,
          boundingBox: const Rect.fromLTWH(0.14, 0.10, 0.72, 0.80),
          segmentation: mask,
          allConfidences: allConf,
        ),
      ],
    );
  }
}