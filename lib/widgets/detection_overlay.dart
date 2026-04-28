// lib/widgets/detection_overlay.dart
//
// ── Fix for "bbox/mask don't align on non-square images in scan preview" ──────
//
// Root cause:
//   The scan-screen image area is a 1:1 AspectRatio square container.
//   Image.memory(..., fit: BoxFit.contain) centres the image inside that square
//   and adds transparent bars on the short axis — exactly like letterboxing.
//   Our CustomPainter received `size` = the full square (e.g. 360×360), but the
//   actual image pixels only occupied a sub-rectangle of that square.
//   So coordinates like (0.5, 0.5) were mapped to the centre of the SQUARE,
//   not the centre of the IMAGE CONTENT — causing the overlay to drift.
//
// Fix:
//   Compute the image-content rect inside the square (same math as BoxFit.contain),
//   then map all normalised coordinates into THAT rect instead of the full square.
//   This is done in `_imageRect()` and applied in every draw call.
//
// Result screen is not affected — it uses the pre-rendered PNG from
// overlay_renderer.dart which is always at the original image's pixel dimensions.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/cacao_variety.dart';
import '../models/detection_result.dart';

class DetectionOverlay extends StatelessWidget {
  final InferenceResponse inferenceResponse;

  /// EXIF-corrected PNG bytes — pixel dimensions must match the model's origW/origH.
  final Uint8List imageBytes;

  const DetectionOverlay({
    super.key,
    required this.inferenceResponse,
    required this.imageBytes,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      final containerW = constraints.maxWidth;
      final containerH = constraints.maxHeight;

      return Stack(
        fit: StackFit.expand,
        children: [
          // Base image — BoxFit.contain centres it within the container
          Image.memory(
            imageBytes,
            fit: BoxFit.contain,
            gaplessPlayback: true,
          ),
          // Overlay painter — receives container size and image dimensions
          // so it can compute the exact content rect
          CustomPaint(
            painter: _OverlayPainter(
              detections: inferenceResponse.detections,
              imageW: inferenceResponse.imageWidth.toDouble(),
              imageH: inferenceResponse.imageHeight.toDouble(),
            ),
            size: Size(containerW, containerH),
          ),
        ],
      );
    });
  }
}

class _OverlayPainter extends CustomPainter {
  final List<DetectionResult> detections;
  final double imageW; // original image pixel width
  final double imageH; // original image pixel height

  const _OverlayPainter({
    required this.detections,
    required this.imageW,
    required this.imageH,
  });

  /// Computes the sub-rectangle occupied by the image content when displayed
  /// with BoxFit.contain inside a container of [size].
  /// This is identical to what Flutter's engine does internally.
  Rect _imageRect(Size size) {
    if (imageW <= 0 || imageH <= 0) return Rect.fromLTWH(0, 0, size.width, size.height);
    final scale = math.min(size.width / imageW, size.height / imageH);
    final fitW = imageW * scale;
    final fitH = imageH * scale;
    final left = (size.width - fitW) / 2;
    final top = (size.height - fitH) / 2;
    return Rect.fromLTWH(left, top, fitW, fitH);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final imgRect = _imageRect(size);

    for (var i = 0; i < detections.length; i++) {
      final det = detections[i];
      final variety = getVarietyById(det.classId);
      final color =
      variety != null ? Color(variety.colorHex) : const Color(0xFF7B2D00);

      _drawSeg(canvas, imgRect, det, color);
      _drawBox(canvas, imgRect, det, color);
      _drawNumberedLabel(canvas, imgRect, det, color, i + 1);
    }
  }

  /// Maps a normalised (0-1) coord to a pixel offset within [imgRect].
  Offset _map(double nx, double ny, Rect r) =>
      Offset(r.left + nx * r.width, r.top + ny * r.height);

  // ── Segmentation mask ────────────────────────────────────────────────────────
  void _drawSeg(Canvas canvas, Rect imgRect, DetectionResult det, Color color) {
    final pts = det.segmentation;
    if (pts == null || pts.isEmpty) return;

    final path = Path();
    final first = _map(pts.first.dx, pts.first.dy, imgRect);
    path.moveTo(first.dx, first.dy);
    for (final p in pts.skip(1)) {
      final mapped = _map(p.dx, p.dy, imgRect);
      path.lineTo(mapped.dx, mapped.dy);
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
          ..strokeWidth = math.max(imgRect.width * 0.004, 1.5)
          ..strokeJoin = StrokeJoin.round);
  }

  // ── Bounding box ─────────────────────────────────────────────────────────────
  void _drawBox(Canvas canvas, Rect imgRect, DetectionResult det, Color color) {
    final b = det.boundingBox;
    final rect = Rect.fromLTRB(
      imgRect.left + b.left * imgRect.width,
      imgRect.top  + b.top  * imgRect.height,
      imgRect.left + b.right * imgRect.width,
      imgRect.top  + b.bottom * imgRect.height,
    );
    final sw = math.max(imgRect.width * 0.004, 1.5);
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
      if (on) canvas.drawPath(m.extractPath(d, next.clamp(0, m.length)), paint);
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

  // ── Numbered label ────────────────────────────────────────────────────────────
  void _drawNumberedLabel(
      Canvas canvas, Rect imgRect, DetectionResult det, Color color, int num) {
    final b = det.boundingBox;
    final boxLeft = imgRect.left + b.left * imgRect.width;
    final boxTop  = imgRect.top  + b.top  * imgRect.height;

    final fs = math.max(imgRect.shortestSide * 0.030, 10.0);
    final circleR = fs * 0.9;
    final circleCenter = Offset(boxLeft + circleR + 3, boxTop + circleR + 3);

    // Circle
    canvas.drawCircle(circleCenter, circleR, Paint()..color = color);
    final numPb = ui.ParagraphBuilder(
      ui.ParagraphStyle(
          fontSize: fs * 0.85, fontWeight: FontWeight.w800,
          textAlign: TextAlign.center),
    )
      ..pushStyle(ui.TextStyle(color: Colors.white))
      ..addText('$num');
    final numPara = numPb.build()
      ..layout(ui.ParagraphConstraints(width: circleR * 2));
    canvas.drawParagraph(numPara,
        Offset(circleCenter.dx - circleR, circleCenter.dy - numPara.height / 2));

    // Label chip
    final label = '${det.yoloTag}  ${(det.confidence * 100).toStringAsFixed(1)}%';
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
    // Keep label chip within the image rect, not the full container
    final bgLeft = (circleCenter.dx + circleR + 4)
        .clamp(imgRect.left, imgRect.right - bgW);
    final bgTop = boxTop.clamp(imgRect.top, imgRect.bottom - bgH);

    canvas.drawRRect(
      RRect.fromRectAndRadius(
          Rect.fromLTWH(bgLeft, bgTop, bgW, bgH), const Radius.circular(4)),
      Paint()..color = color.withOpacity(0.85),
    );
    canvas.drawParagraph(labelPara, Offset(bgLeft + pad, bgTop + pad));
  }

  @override
  bool shouldRepaint(_OverlayPainter old) =>
      old.detections != detections ||
          old.imageW != imageW ||
          old.imageH != imageH;
}