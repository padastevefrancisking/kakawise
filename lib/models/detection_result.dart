// lib/models/detection_result.dart

import 'dart:typed_data';
import 'dart:ui';
import 'cacao_variety.dart';

const double kConfidenceThreshold = 0.70;
Uint8List? lastAnnotatedImageBytes;

class DetectionResult {
  final String classId;
  final String className;
  final String yoloTag;
  final double confidence;

  /// Normalised bounding box (0-1) relative to the image shown on screen.
  final Rect boundingBox;
  final List<Offset>? segmentation;

  final Map<String, double> allConfidences;

  const DetectionResult({
    required this.classId,
    required this.className,
    required this.yoloTag,
    required this.confidence,
    required this.boundingBox,
    required this.allConfidences,
    this.segmentation,
  });

  factory DetectionResult.fromBoxMap(
      Map<String, dynamic> box, {
        required Map<String, double> allConfidences,
      }) {

    final raw = (box['class'] ?? box['className'] ?? box['tag'] ?? '').toString().trim();
    final variety = getVarietyByYoloClass(raw)
        ?? getVarietyByYoloClass(raw.toUpperCase())
        ?? getVarietyByYoloClass(raw.toLowerCase());

    final x1n = _d(box['x1_norm']);
    final y1n = _d(box['y1_norm']);
    final x2n = _d(box['x2_norm']);
    final y2n = _d(box['y2_norm']);

    Rect normBox;
    if (x1n == 0 && x2n == 0) {
      normBox = Rect.fromLTRB(
        _d(box['x1']) / 1280, _d(box['y1']) / 1280,
        _d(box['x2']) / 1280, _d(box['y2']) / 1280,
      );
    } else {
      normBox = Rect.fromLTRB(
        x1n.clamp(0.0, 1.0),
        y1n.clamp(0.0, 1.0),
        x2n.clamp(0.0, 1.0),
        y2n.clamp(0.0, 1.0),
      );
    }

    final conf = _d(box['confidence']);

    return DetectionResult(
      classId: variety?.id ?? raw,
      className: variety?.name ?? raw,
      yoloTag: raw,
      confidence: conf,
      boundingBox: normBox,
      segmentation: null,
      allConfidences: allConfidences,
    );
  }
}

double _d(dynamic v) => (v as num? ?? 0).toDouble();

class InferenceResponse {
  final List<DetectionResult> detections;
  final int imageWidth;
  final int imageHeight;

  final Uint8List? annotatedImageBytes;

  const InferenceResponse({
    required this.detections,
    required this.imageWidth,
    required this.imageHeight,
    this.annotatedImageBytes,
  });

  DetectionResult? get topDetection {
    if (detections.isEmpty) return null;
    return detections.reduce((a, b) => a.confidence > b.confidence ? a : b);
  }
}