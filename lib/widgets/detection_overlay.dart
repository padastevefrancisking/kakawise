// lib/widgets/detection_overlay.dart
//
// Renders bounding boxes + segmentation masks on top of any widget
// using a CustomPainter.  Used in the scan screen image preview.
// The result screen uses the pre-rendered PNG from overlay_renderer.dart.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/cacao_variety.dart';
import '../models/detection_result.dart';

class DetectionOverlay extends StatelessWidget {
  final InferenceResponse inferenceResponse;
  final Widget imageWidget;

  const DetectionOverlay({
    super.key,
    required this.inferenceResponse,
    required this.imageWidget,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        imageWidget,
        CustomPaint(
          painter: _OverlayPainter(detections: inferenceResponse.detections),
        ),
      ],
    );
  }
}

class _OverlayPainter extends CustomPainter {
  final List<DetectionResult> detections;

  const _OverlayPainter({required this.detections});

  @override
  void paint(Canvas canvas, Size size) {
    for (final det in detections) {
      final variety = getVarietyById(det.classId);
      final color =
      variety != null ? Color(variety.colorHex) : const Color(0xFF1D9E75);
      _drawSeg(canvas, size, det, color);
      _drawBox(canvas, size, det, color);
      _drawLabel(canvas, size, det, color);
    }
  }

  void _drawSeg(Canvas canvas, Size size, DetectionResult det, Color color) {
    final pts = det.segmentation;
    if (pts == null || pts.isEmpty) return;
    final path = Path()
      ..moveTo(pts.first.dx * size.width, pts.first.dy * size.height);
    for (final p in pts.skip(1)) {
      path.lineTo(p.dx * size.width, p.dy * size.height);
    }
    path.close();
    canvas.drawPath(path,
        Paint()..color = color.withOpacity(0.25)..style = PaintingStyle.fill);
    canvas.drawPath(
        path,
        Paint()
          ..color = color.withOpacity(0.88)
          ..style = PaintingStyle.stroke
          ..strokeWidth = math.max(size.width * 0.005, 2.0)
          ..strokeJoin = StrokeJoin.round);
  }

  void _drawBox(Canvas canvas, Size size, DetectionResult det, Color color) {
    final b = det.boundingBox;
    final rect = Rect.fromLTWH(b.left * size.width, b.top * size.height,
        b.width * size.width, b.height * size.height);
    final sw = math.max(size.width * 0.004, 1.5);
    _dashed(canvas, rect,
        Paint()..color = color..style = PaintingStyle.stroke..strokeWidth = sw);
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
        canvas.drawPath(m.extractPath(d, next.clamp(0, m.length)), paint);
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

  void _drawLabel(Canvas canvas, Size size, DetectionResult det, Color color) {
    final b = det.boundingBox;
    final lx = b.left * size.width;
    final ty = b.top * size.height;
    final fs = math.max(size.width * 0.032, 11.0);
    final label = '${det.yoloTag}  ${(det.confidence * 100).toStringAsFixed(1)}%';

    final pb = ui.ParagraphBuilder(
      ui.ParagraphStyle(fontSize: fs, fontWeight: FontWeight.w700),
    )
      ..pushStyle(ui.TextStyle(color: Colors.white))
      ..addText(label);
    final para = pb.build()..layout(const ui.ParagraphConstraints(width: 240));

    const pad = 4.0;
    final bgH = para.height + pad * 2;
    final bgW = para.longestLine + pad * 2 + 4;
    final bgTop = (ty - bgH).clamp(0.0, size.height - bgH);
    final bgLeft = lx.clamp(0.0, size.width - bgW);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(bgLeft, bgTop, bgW, bgH), const Radius.circular(4)),
      Paint()..color = color,
    );
    canvas.drawParagraph(para, Offset(bgLeft + pad, bgTop + pad));
  }

  @override
  bool shouldRepaint(_OverlayPainter old) => old.detections != detections;
}