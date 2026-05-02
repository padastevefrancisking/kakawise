// lib/services/overlay_renderer.dart
//
// Composites the YOLOv12 segmentation overlay (mask + bbox + label)
// onto the original image pixels and returns the result as PNG bytes.
// This rendered image is what is displayed at the top of ResultScreen.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../models/cacao_variety.dart';
import '../models/detection_result.dart';

/// Takes the decoded [ui.Image] and overlays all detections onto it.
/// Returns PNG-encoded bytes of the composited image.
Future<Uint8List> renderOverlay({
  required ui.Image sourceImage,
  required InferenceResponse inferenceResponse,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(
    recorder,
    Rect.fromLTWH(
      0,
      0,
      sourceImage.width.toDouble(),
      sourceImage.height.toDouble(),
    ),
  );

  // Draw the base image
  canvas.drawImage(sourceImage, Offset.zero, Paint());

  final size = Size(
    sourceImage.width.toDouble(),
    sourceImage.height.toDouble(),
  );

  // When the plugin returned an annotated image (masks + boxes already baked in),
  // only add our numbered labels — skip drawing boxes and masks again.
  final hasAnnotated = inferenceResponse.annotatedImageBytes != null;

  for (var i = 0; i < inferenceResponse.detections.length; i++) {
    final det = inferenceResponse.detections[i];
    final variety = getVarietyById(det.classId);
    final color =
    variety != null ? Color(variety.colorHex) : const Color(0xFF1D9E75);

    if (!hasAnnotated) {
      _drawSegmentation(canvas, size, det, color);
      _drawBoundingBox(canvas, size, det, color);
    }
    _drawLabel(canvas, size, det, color, labelNum: i + 1);
  }

  final picture = recorder.endRecording();
  final rendered = await picture.toImage(sourceImage.width, sourceImage.height);
  final byteData = await rendered.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}

void _drawSegmentation(
    Canvas canvas, Size size, DetectionResult det, Color color) {
  final points = det.segmentation;
  if (points == null || points.isEmpty) return;

  final path = Path();
  path.moveTo(points.first.dx * size.width, points.first.dy * size.height);
  for (final pt in points.skip(1)) {
    path.lineTo(pt.dx * size.width, pt.dy * size.height);
  }
  path.close();

  canvas.drawPath(
      path, Paint()..color = color.withValues(alpha: 0.28)..style = PaintingStyle.fill);
  canvas.drawPath(
      path,
      Paint()
        ..color = color.withValues(alpha: 0.90)
        ..style = PaintingStyle.stroke
        ..strokeWidth = math.max(size.width * 0.004, 2.0)
        ..strokeJoin = StrokeJoin.round);
}

void _drawBoundingBox(
    Canvas canvas, Size size, DetectionResult det, Color color) {
  final b = det.boundingBox;
  final rect = Rect.fromLTWH(
    b.left * size.width,
    b.top * size.height,
    b.width * size.width,
    b.height * size.height,
  );

  final strokeW = math.max(size.width * 0.003, 1.5);
  _drawDashedRect(
    canvas,
    rect,
    Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeW,
  );
  _drawCorners(canvas, rect, color, strokeW * 2);
}

void _drawDashedRect(Canvas canvas, Rect rect, Paint paint) {
  final path = Path()..addRect(rect);
  final metric = path.computeMetrics().first;
  final dash = rect.shortestSide * 0.04;
  final gap = dash * 0.6;
  double dist = 0;
  bool draw = true;
  while (dist < metric.length) {
    final next = dist + (draw ? dash : gap);
    if (draw) {
      canvas.drawPath(
        metric.extractPath(dist, next.clamp(0, metric.length)),
        paint,
      );
    }
    dist = next;
    draw = !draw;
  }
}

void _drawCorners(Canvas canvas, Rect rect, Color color, double strokeW) {
  final len = rect.shortestSide * 0.08;
  final paint = Paint()
    ..color = color
    ..style = PaintingStyle.stroke
    ..strokeWidth = strokeW
    ..strokeCap = StrokeCap.round;
  for (final corner in [
    rect.topLeft,
    rect.topRight,
    rect.bottomLeft,
    rect.bottomRight,
  ]) {
    final dx = corner == rect.topLeft || corner == rect.bottomLeft ? len : -len;
    final dy = corner == rect.topLeft || corner == rect.topRight ? len : -len;
    canvas.drawLine(corner, corner.translate(dx, 0), paint);
    canvas.drawLine(corner, corner.translate(0, dy), paint);
  }
}

void _drawLabel(
    Canvas canvas, Size size, DetectionResult det, Color color, {int labelNum = 1}) {
  final b = det.boundingBox;
  final left = b.left * size.width;
  final top = b.top * size.height;

  final fontSize = math.max(size.width * 0.022, 12.0);
  final label =
      '$labelNum · ${det.yoloTag}  ${(det.confidence * 100).toStringAsFixed(1)}%';

  final pb = ui.ParagraphBuilder(
    ui.ParagraphStyle(fontSize: fontSize, fontWeight: FontWeight.w700),
  )
    ..pushStyle(ui.TextStyle(color: const Color(0xFFFFFFFF)))
    ..addText(label);

  final para = pb.build()
    ..layout(const ui.ParagraphConstraints(width: 300));

  const pad = 5.0;
  final bgH = para.height + pad * 2;
  final bgW = para.longestLine + pad * 2 + 6;
  final bgTop = (top - bgH).clamp(0.0, size.height - bgH);
  final bgLeft = left.clamp(0.0, size.width - bgW);

  canvas.drawRRect(
    RRect.fromRectAndRadius(
      Rect.fromLTWH(bgLeft, bgTop, bgW, bgH),
      const Radius.circular(5),
    ),
    Paint()..color = color,
  );
  canvas.drawParagraph(para, Offset(bgLeft + pad, bgTop + pad));
}