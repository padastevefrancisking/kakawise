// lib/models/detection_result.dart

import 'dart:typed_data';
import 'dart:ui';
import 'cacao_variety.dart';

/// Minimum confidence to keep a detection.
const double kConfidenceThreshold = 0.70;

/// Holds the annotated image bytes returned by the plugin (JPEG with masks drawn).
/// This is set once per inference call and shared across all detections.
Uint8List? lastAnnotatedImageBytes;

class DetectionResult {
  final String classId;
  final String className;
  final String yoloTag;
  final double confidence;

  /// Normalised bounding box (0-1) relative to the image shown on screen.
  final Rect boundingBox;

  /// Segmentation polygon — null for this plugin version.
  /// Visual segmentation comes from [lastAnnotatedImageBytes] instead.
  final List<Offset>? segmentation;

  /// Confidence per variety id — filled for all known classes.
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

  /// Parse one entry from the 'boxes' list.
  ///
  /// The plugin already provides normalised coords via x1_norm … y2_norm,
  /// so no letterbox math is needed — we use them directly.
  factory DetectionResult.fromBoxMap(
      Map<String, dynamic> box, {
        required Map<String, double> allConfidences,
      }) {

    // The plugin uses 'class' and 'className' (both same value).
    // 'tag' does NOT exist in this version.
    final raw = (box['class'] ?? box['className'] ?? box['tag'] ?? '').toString().trim();
    final variety = getVarietyByYoloClass(raw)
        ?? getVarietyByYoloClass(raw.toUpperCase())
        ?? getVarietyByYoloClass(raw.toLowerCase());

    // Bounding box — use normalised fields directly
    final x1n = _d(box['x1_norm']);
    final y1n = _d(box['y1_norm']);
    final x2n = _d(box['x2_norm']);
    final y2n = _d(box['y2_norm']);

    // Fallback: if norm fields are missing/zero, derive from pixel + image size
    Rect normBox;
    if (x1n == 0 && x2n == 0) {
      // No norm fields — shouldn't happen but guard anyway
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

// InferenceResponse
class InferenceResponse {
  final List<DetectionResult> detections;
  final int imageWidth;
  final int imageHeight;

  /// JPEG bytes of the annotated image from the plugin (masks + boxes drawn).
  /// Used as the hero image in ResultScreen when available.
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