// lib/widgets/detection_overlay.dart
//
// ── The double-box problem explained ─────────────────────────────────────────
//
// The ultralytics_yolo plugin returns:
//   'annotatedImage' → JPEG bytes that already have the plugin's OWN bounding
//                      boxes + segmentation mask drawn on them (blue by default).
//
// Previously we were ALSO drawing our own purple bounding boxes on top via
// CustomPainter, producing TWO overlapping boxes per detection.
// The plugin's segmentation mask was also rendered at its own internal scale
// so it didn't align with our normalised coordinates.
//
// ── Fix ───────────────────────────────────────────────────────────────────────
//
// When annotatedImageBytes is available:
//   → Use it as the base image (it has correct segmentation from the model).
//   → Draw ONLY our numbered circle + label chips on top.
//   → Do NOT draw boxes or masks (already in the annotated image).
//
// When annotatedImageBytes is null (mock / fallback):
//   → Draw image + our own boxes + masks + numbered labels.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/cacao_variety.dart';
import '../models/detection_result.dart';

class DetectionOverlay extends StatelessWidget {
  final InferenceResponse inferenceResponse;

  /// EXIF-corrected PNG — used as fallback when no annotatedImage is available.
  final Uint8List imageBytes;

  const DetectionOverlay({
    super.key,
    required this.inferenceResponse,
    required this.imageBytes,
  });

  @override
  Widget build(BuildContext context) {
    final hasAnnotated = inferenceResponse.annotatedImageBytes != null;

    // Base image: plugin's annotated JPEG (masks + boxes already drawn)
    // OR our own EXIF-corrected PNG.
    final baseImage = hasAnnotated
        ? Image.memory(
      inferenceResponse.annotatedImageBytes!,
      fit: BoxFit.contain,
      gaplessPlayback: true,
    )
        : Image.memory(imageBytes, fit: BoxFit.contain, gaplessPlayback: true);

    return Stack(
      fit: StackFit.expand,
      children: [
        baseImage,
        CustomPaint(
          painter: _OverlayPainter(
            detections: inferenceResponse.detections,
            // When annotatedImage is present: SKIP drawing boxes and masks —
            // they are already baked into the annotatedImage.
            drawBoxes: !hasAnnotated,
            drawMasks: !hasAnnotated,
          ),
        ),
      ],
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final bool drawBoxes;
  final bool drawMasks;

  const _OverlayPainter({
    required this.detections,
    required this.drawBoxes,
    required this.drawMasks,
  });

  @override
  void paint(Canvas canvas, Size size) {
    for (var i = 0; i < detections.length; i++) {
      final det = detections[i];
      final variety = getVarietyById(det.classId);
      final color =
      variety != null ? Color(variety.colorHex) : const Color(0xFF1D9E75);

      if (drawMasks) _drawSeg(canvas, size, det, color);
      if (drawBoxes) _drawBox(canvas, size, det, color);
      // Always draw numbered labels regardless of mode
      _drawNumberedLabel(canvas, size, det, color, i + 1);
    }
  }

  // ── Segmentation mask (only for mock / no annotated image) ──────────────────
  void _drawSeg(Canvas canvas, Size size, DetectionResult det, Color color) {
    final pts = det.segmentation;
    if (pts == null || pts.isEmpty) return;
    final path = Path()
      ..moveTo(pts.first.dx * size.width, pts.first.dy * size.height);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx * size.width, p.dy * size.height);
    }
    path.close();
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(0.22)
          ..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(0.85)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(size.width * 0.005, 2.0)
          ..strokeJoin = StrokeJoin.round);
  }

  // ── Bounding box (only for mock / no annotated image) ───────────────────────
  void _drawBox(Canvas canvas, Size size, DetectionResult det, Color color) {
    final b = det.boundingBox;
    final rect = Rect.fromLTRB(
      b.left * size.width,
      b.top * size.height,
      b.right * size.width,
      b.bottom * size.height,
    );
    final sw = math.max(size.width * 0.004, 1.5);
    _dashed(canvas, rect,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = sw);
    _corners(canvas, rect, color, sw * 2.2);
  }

  void _dashed(Canvas canvas, Rect rect, Paint paint) {
    final path = Path()..addRect(rect);
    final m = path.computeMetrics().first;
    final dash = rect.shortestSide * 0.05;
    final gap = dash * 0.55;
    double d = 0;
    bool on = true;
    while (d < m.length) {
      final next = d + (on ? dash : gap);
      if (on) {
        canvas.drawPath(
            m.extractPath(d, next.clamp(0, m.length)), paint);
      }
      d = next;
      on = !on;
    }
  }

  void _corners(Canvas canvas, Rect r, Color color, double sw) {
    final len = r.shortestSide * 0.09;
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = sw
      ..strokeCap = StrokeCap.round;
    void L(Offset a, Offset b) => canvas.drawLine(a, b, p);
    L(r.topLeft, r.topLeft.translate(len, 0));
    L(r.topLeft, r.topLeft.translate(0, len));
    L(r.topRight, r.topRight.translate(-len, 0));
    L(r.topRight, r.topRight.translate(0, len));
    L(r.bottomLeft, r.bottomLeft.translate(len, 0));
    L(r.bottomLeft, r.bottomLeft.translate(0, -len));
    L(r.bottomRight, r.bottomRight.translate(-len, 0));
    L(r.bottomRight, r.bottomRight.translate(0, -len));
  }

  // ── Numbered label: circle with index + "TAG  conf%" text chip ──────────────
  void _drawNumberedLabel(
      Canvas canvas, Size size, DetectionResult det, Color color, int num) {
    final b = det.boundingBox;
    final boxLeft = b.left * size.width;
    final boxTop = b.top * size.height;

    final fs = math.max(size.shortestSide * 0.030, 10.0);
    final circleR = fs * 0.9;

    // ── Numbered circle ──────────────────────────────────────────────────────
    final circleCenter =
    Offset(boxLeft + circleR + 3, boxTop + circleR + 3);
    canvas.drawCircle(circleCenter, circleR, Paint()..color = color);

    final numPb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
          fontSize: fs * 0.85,
          fontWeight: FontWeight.w800,
          textAlign: TextAlign.center),
    )
      ..pushStyle(ui.TextStyle(color: Colors.white))
      ..addText('$num');
    final numPara = numPb.build()
      ..layout(ui.ParagraphConstraints(width: circleR * 2));
    canvas.drawParagraph(
        numPara,
        Offset(circleCenter.dx - circleR,
            circleCenter.dy - numPara.height / 2));

    // ── Text chip ─────────────────────────────────────────────────────────────
    final label =
        '${det.yoloTag}  ${(det.confidence * 100).toStringAsFixed(1)}%';
    final labelPb = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontSize: fs, fontWeight: FontWeight.w700),
    )
      ..pushStyle(ui.TextStyle(color: Colors.white))
      ..addText(label);
    final labelPara = labelPb.build()
      ..layout(const ui.ParagraphConstraints(width: 220));

    const pad = 3.0;
    final bgW = labelPara.longestLine + pad * 2 + 4;
    final bgH = labelPara.height + pad * 2;
    final bgLeft =
    (circleCenter.dx + circleR + 4).clamp(0.0, size.width - bgW);
    final bgTop = boxTop.clamp(0.0, size.height - bgH);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(bgLeft, bgTop, bgW, bgH),
          const Radius.circular(4)),
      Paint()..color = color.withOpacity(0.85),
    );
    canvas.drawParagraph(
        labelPara, Offset(bgLeft + pad, bgTop + pad));
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.detections != detections ||
          old.drawBoxes != drawBoxes ||
          old.drawMasks != drawMasks;
}