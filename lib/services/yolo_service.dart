// lib/services/yolo_service.dart
//
// ── ONNX inference engine for KakaWise ───────────────────────────────────────
//
// Replaces ultralytics_yolo (.tflite) with flutter_onnxruntime (.onnx).
// Everything above this file (UI, screens, detection_result, overlay) is
// unchanged — only inference and pre/post-processing live here.
//
// ── Export your model ─────────────────────────────────────────────────────────
//
//   from ultralytics import YOLO
//   model = YOLO("best.pt")
//   model.export(
//       format="onnx",
//       imgsz=640,
//       opset=12,        # opset 12 is safest for mobile ONNX Runtime
//       simplify=True,   # removes unused nodes
//       dynamic=False,   # fixed batch size = 1
//   )
//   # Produces: best.onnx
//   # Rename to: kakawisev12_seg.onnx
//   # Place at:  assets/models/kakawisev12_seg.onnx
//
// ── ONNX model tensor layout (YOLOv8/v12 seg) ────────────────────────────────
//
//   INPUT   'images'   float32  [1, 3, 640, 640]
//                               Batch=1, RGB channels, Height, Width.
//                               Values normalised to [0.0, 1.0].
//                               Channel-first (CHW), letterboxed with grey padding.
//
//   OUTPUT0 'output0'  float32  [1, 4 + C + 32, 8400]
//                               8400 anchors, each column is one candidate detection.
//                               Rows 0–3:        cx, cy, w, h  (normalised 0-1, already
//                                                un-letterboxed by the model export)
//                               Rows 4 … 4+C-1:  class confidence per class (sigmoid)
//                               Rows 4+C … end:  32 mask prototype coefficients
//                               C = number of classes (3 for W10/UF18/BR25)
//
//   OUTPUT1 'output1'  float32  [1, 32, 160, 160]
//                               32 prototype masks, each 160×160.
//                               Multiply by mask coefficients from output0 to get
//                               per-detection soft masks.
//
// ── Post-processing pipeline ──────────────────────────────────────────────────
//
//   1.  Filter anchors: keep only those where max(class scores) >= confThreshold
//   2.  NMS: suppress overlapping boxes using IoU threshold
//   3.  Mask decode: dot(maskCoeff[32], protos[32,160,160]) → sigmoid → threshold
//   4.  Contour extract: walk mask boundary → normalised polygon points
//   5.  Un-letterbox: convert model coords back to original image space

import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_onnxruntime/flutter_onnxruntime.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../models/cacao_variety.dart';
import '../models/detection_result.dart';

// ── Configuration ─────────────────────────────────────────────────────────────

const String _modelAsset = 'assets/models/kakawisev12_seg.onnx';

/// Square size the model was exported at.
const int _inSize = 640;

/// Number of classes — must match your training configuration.
/// Verify with: from ultralytics import YOLO; print(YOLO("best.pt").names)
const int _numClasses = 3;

/// Class index → YOLO tag.  Order must match your model's class indices.
const List<String> _classNames = ['BR25', 'UF18', 'W10'];

/// Minimum confidence to keep a detection.
const double kConfidenceThreshold = 0.70;

/// IoU threshold for NMS: boxes with more overlap than this are suppressed.
const double _iouThreshold = 0.45;

/// Prototype mask spatial resolution (output1 H and W).
const int _protoSize = 160;

/// Number of prototype channels (must equal 32 for standard YOLOv8/v12 seg).
const int _maskDim = 32;

// ── Session singleton ─────────────────────────────────────────────────────────

class YoloService {
  static OrtSession? _session;
  static bool _loaded = false;

  /// Load model once — call from main() after WidgetsFlutterBinding.ensureInitialized().
  static Future<void> loadModel() async {
    if (_loaded) return;

    // Load Flutter asset bytes
    final data = await rootBundle.load(_modelAsset);
    final bytes = data.buffer.asUint8List();

    // Write to temp directory
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/kakawisev12_seg.onnx');

    await file.writeAsBytes(bytes, flush: true);

    // Load from real filesystem path
    final ort = OnnxRuntime();
    _session = await ort.createSession(file.path);

    _loaded = true;
  }

  // ── Main classify entry point ──────────────────────────────────────────────

  static Future<InferenceResponse> classify(File imageFile) async {
    if (!_loaded) await loadModel();

    // ── 1. Read & EXIF-correct decode ────────────────────────────────────────
    // dart:ui's instantiateImageCodec honours the EXIF rotation tag so that
    // the decoded pixel grid is always upright, regardless of phone orientation.
    final rawBytes = await imageFile.readAsBytes();

    final uiCodec = await ui.instantiateImageCodec(rawBytes);
    final uiFrame = await uiCodec.getNextFrame();
    final origW = uiFrame.image.width;
    final origH = uiFrame.image.height;
    uiFrame.image.dispose();

    // Re-encode to PNG so the `image` package can read it without EXIF issues
    // (it doesn't apply EXIF rotation on its own).
    // Use the dart:ui decoded frame as the source of truth.
    final uiCodec2 = await ui.instantiateImageCodec(rawBytes);
    final uiFrame2 = await uiCodec2.getNextFrame();
    final pngByteData =
    await uiFrame2.image.toByteData(format: ui.ImageByteFormat.png);
    uiFrame2.image.dispose();
    final Uint8List pngBytes = pngByteData!.buffer.asUint8List();

    // Decode with `image` package for pixel-level access
    final srcImg = img.decodePng(pngBytes);
    if (srcImg == null) throw Exception('Image decode failed');

    // ── 2. Letterbox resize to _inSize × _inSize ─────────────────────────────
    final _Letterbox lb = _letterbox(srcImg, _inSize);

    // ── 3. Build float32 CHW input tensor [1, 3, 640, 640] ───────────────────
    final Float32List inputData = _toChwFloat32(lb.image, _inSize);

    // ── 4. Run ONNX session ───────────────────────────────────────────────────
    final OrtValue inputTensor = await OrtValue.fromList(
      inputData,
      [1, 3, _inSize, _inSize],
    );

    final Map<String, OrtValue> outputs =
    await _session!.run({'images': inputTensor});

    await inputTensor.dispose();

    final OrtValue out0 = outputs['output0']!;
    final OrtValue out1 = outputs['output1']!;

    // Flatten to List<double> for easy indexing
    List<double> flatten(dynamic x) {
      if (x is num) return [x.toDouble()];
      if (x is List) return x.expand((e) => flatten(e)).toList();
      return [];
    }

    final raw0 = flatten(await out0.asList());
    final raw1 = flatten(await out1.asList());

    await out0.dispose();
    await out1.dispose();

    // ── 5. Parse output0: filter by confidence ────────────────────────────────
    // output0 shape: [1, rows, 8400] stored in row-major order.
    // Element at row r, anchor a: raw0[r * 8400 + a]
    const int numAnchors = 8400;

    final List<_Candidate> candidates = [];

    for (int a = 0; a < numAnchors; a++) {
      // Find best class score
      double bestConf = 0.0;
      int bestCls = 0;
      for (int c = 0; c < _numClasses; c++) {
        final s = raw0[(4 + c) * numAnchors + a];
        if (s > bestConf) {
          bestConf = s;
          bestCls = c;
        }
      }
      if (bestConf < kConfidenceThreshold) continue;

      // cx, cy, w, h — normalised in the 640×640 letterboxed space
      final cx = raw0[0 * numAnchors + a] / 640.0;
      final cy = raw0[1 * numAnchors + a] / 640.0;
      final bw = raw0[2 * numAnchors + a] / 640.0;
      final bh = raw0[3 * numAnchors + a] / 640.0;

      // 32 mask coefficients
      final List<double> mc = List.generate(
          _maskDim, (i) => raw0[(4 + _numClasses + i) * numAnchors + a]);

      candidates.add(_Candidate(
        cx: cx, cy: cy, w: bw, h: bh,
        conf: bestConf, cls: bestCls, maskCoeff: mc,
      ));
    }


    // ── 6. NMS ────────────────────────────────────────────────────────────────
    final List<_Candidate> kept = _nms(candidates, _iouThreshold);

    // ── 7. Build per-class confidence map ─────────────────────────────────────
    final Map<String, double> classConf = {
      for (final v in cacaoVarieties) v.id: 0.0,
    };
    for (final c in kept) {
      final id = _classNames[c.cls];
      if (c.conf > (classConf[id] ?? 0)) classConf[id] = c.conf;
    }

    // ── 8. Decode masks + build DetectionResult list ──────────────────────────
    final List<DetectionResult> detections = [];

    for (final cand in kept) {
      // Convert cx/cy/w/h (letterboxed 0-1) → LTRB (letterboxed 0-1)
      final lbX1 = cand.cx - cand.w / 2;
      final lbY1 = cand.cy - cand.h / 2;
      final lbX2 = cand.cx + cand.w / 2;
      final lbY2 = cand.cy + cand.h / 2;

      // Un-letterbox bbox → original image normalised coords
      final normBox = _unletterboxRect(lbX1, lbY1, lbX2, lbY2, origW, origH, lb);

      // Decode segmentation mask → contour polygon in original image space
      final List<ui.Offset> polygon =
      _decodeMask(cand.maskCoeff, raw1, lbX1, lbY1, lbX2, lbY2, origW, origH, lb);

      final tag = _classNames[cand.cls];
      final variety = getVarietyByYoloClass(tag);

      detections.add(DetectionResult(
        classId: variety?.id ?? tag,
        className: variety?.name ?? tag,
        yoloTag: tag,
        confidence: cand.conf,
        boundingBox: normBox,
        segmentation: polygon.isEmpty ? null : polygon,
        allConfidences: Map.from(classConf),
      ));
    }

    detections.sort((a, b) => b.confidence.compareTo(a.confidence));

    return InferenceResponse(
      detections: detections,
      imageWidth: origW,
      imageHeight: origH,
      annotatedImageBytes: null, // ONNX draws its own overlay via DetectionOverlay
    );
  }
}

// ─── Internal data class ──────────────────────────────────────────────────────

class _Candidate {
  final double cx, cy, w, h, conf;
  final int cls;
  final List<double> maskCoeff;
  const _Candidate({
    required this.cx, required this.cy, required this.w, required this.h,
    required this.conf, required this.cls, required this.maskCoeff,
  });
}

// ─── Letterbox ────────────────────────────────────────────────────────────────

class _Letterbox {
  final img.Image image; // padded square image ready for inference
  final double scale;   // factor: original pixel → padded pixel
  final int padX;       // left grey-bar width  (pixels in padded image)
  final int padY;       // top  grey-bar height (pixels in padded image)
  const _Letterbox(this.image, this.scale, this.padX, this.padY);
}

_Letterbox _letterbox(img.Image src, int sz) {
  // Scale to fit inside sz×sz, preserving aspect ratio
  final scale = math.min(sz / src.width, sz / src.height);
  final newW = (src.width * scale).round();
  final newH = (src.height * scale).round();

  // Grey padding offsets (centred)
  final padX = ((sz - newW) / 2).round();
  final padY = ((sz - newH) / 2).round();

  // Resize
  final resized = img.copyResize(src,
      width: newW, height: newH, interpolation: img.Interpolation.linear);

  // Fill canvas with grey (114, 114, 114) — standard YOLO letterbox colour
  final canvas = img.Image(width: sz, height: sz);
  img.fill(canvas, color: img.ColorRgb8(114, 114, 114));
  img.compositeImage(canvas, resized, dstX: padX, dstY: padY);

  return _Letterbox(canvas, scale, padX, padY);
}

// ─── Tensor build ─────────────────────────────────────────────────────────────

/// Convert HWC uint8 img.Image → flat CHW float32 array normalised to [0,1].
Float32List _toChwFloat32(img.Image image, int sz) {
  final out = Float32List(3 * sz * sz);
  // Channel offsets
  final rBase = 0;
  final gBase = sz * sz;
  final bBase = 2 * sz * sz;
  for (int y = 0; y < sz; y++) {
    for (int x = 0; x < sz; x++) {
      final px = image.getPixel(x, y);
      final idx = y * sz + x;
      out[rBase + idx] = px.r / 255.0;
      out[gBase + idx] = px.g / 255.0;
      out[bBase + idx] = px.b / 255.0;
    }
  }
  return out;
}

// ─── NMS ─────────────────────────────────────────────────────────────────────

List<_Candidate> _nms(List<_Candidate> dets, double iouThr) {
  dets.sort((a, b) => b.conf.compareTo(a.conf));
  final suppressed = List.filled(dets.length, false);
  final out = <_Candidate>[];
  for (var i = 0; i < dets.length; i++) {
    if (suppressed[i]) continue;
    out.add(dets[i]);
    for (var j = i + 1; j < dets.length; j++) {
      if (suppressed[j]) continue;
      if (_iou(dets[i], dets[j]) > iouThr) suppressed[j] = true;
    }
  }
  return out;
}

double _iou(_Candidate a, _Candidate b) {
  final ax1 = a.cx - a.w / 2, ay1 = a.cy - a.h / 2;
  final ax2 = a.cx + a.w / 2, ay2 = a.cy + a.h / 2;
  final bx1 = b.cx - b.w / 2, by1 = b.cy - b.h / 2;
  final bx2 = b.cx + b.w / 2, by2 = b.cy + b.h / 2;
  final iw = math.max(0.0, math.min(ax2, bx2) - math.max(ax1, bx1));
  final ih = math.max(0.0, math.min(ay2, by2) - math.max(ay1, by1));
  final inter = iw * ih;
  if (inter == 0) return 0;
  return inter / (a.w * a.h + b.w * b.h - inter);
}

// ─── Mask decode ──────────────────────────────────────────────────────────────
//
// raw1 layout: [1, 32, 160, 160] → index: ch * 160*160 + y * 160 + x
//
// Steps:
//   1. Weighted sum of 32 prototype masks using maskCoeff
//   2. Sigmoid → probability per prototype pixel
//   3. Crop to detection bbox region (in prototype-grid space)
//   4. Threshold at 0.5 → binary mask
//   5. Walk boundary → collect edge pixels → convert to normalised polygon

List<ui.Offset> _decodeMask(
    List<double> mc,
    List<double> raw1,
    double lbX1,
    double lbY1,
    double lbX2,
    double lbY2,
    int origW,
    int origH,
    _Letterbox lb,
    ) {
  const int mh = _protoSize; //160
  const int mw = _protoSize;
  const double thr = 0.5;

  // ------------------------------------------------------------
  // 1. Build logits mask from prototypes
  // ------------------------------------------------------------
  final mask = Float64List(mh * mw);

  for (int c = 0; c < _maskDim; c++) {
    final coeff = mc[c];
    final base = c * mh * mw;

    for (int i = 0; i < mh * mw; i++) {
      mask[i] += coeff * raw1[base + i];
    }
  }

  // sigmoid
  for (int i = 0; i < mask.length; i++) {
    mask[i] = 1 / (1 + math.exp(-mask[i]));
  }

  // ------------------------------------------------------------
  // 2. bbox region in proto scale
  // ------------------------------------------------------------
  final x1 = (lbX1 * mw).floor().clamp(0, mw - 1);
  final y1 = (lbY1 * mh).floor().clamp(0, mh - 1);
  final x2 = (lbX2 * mw).ceil().clamp(1, mw);
  final y2 = (lbY2 * mh).ceil().clamp(1, mh);

  final List<_Pt> border = [];

  // ------------------------------------------------------------
  // 3. Find border pixels only
  // ------------------------------------------------------------
  for (int y = y1; y < y2; y++) {
    for (int x = x1; x < x2; x++) {
      final v = mask[y * mw + x];
      if (v < thr) continue;

      bool edge = false;

      for (final d in const [
        [-1, 0],
        [1, 0],
        [0, -1],
        [0, 1],
      ]) {
        final nx = x + d[0];
        final ny = y + d[1];

        if (nx < x1 || nx >= x2 || ny < y1 || ny >= y2) {
          edge = true;
          break;
        }

        if (mask[ny * mw + nx] < thr) {
          edge = true;
          break;
        }
      }

      if (edge) border.add(_Pt(x.toDouble(), y.toDouble()));
    }
  }

  if (border.isEmpty) return [];

  // ------------------------------------------------------------
  // 4. Compute center
  // ------------------------------------------------------------
  double cx = 0, cy = 0;

  for (final p in border) {
    cx += p.x;
    cy += p.y;
  }

  cx /= border.length;
  cy /= border.length;

  // ------------------------------------------------------------
  // 5. Sort clockwise around center
  // ------------------------------------------------------------
  border.sort((a, b) {
    final aa = math.atan2(a.y - cy, a.x - cx);
    final bb = math.atan2(b.y - cy, b.x - cx);
    return aa.compareTo(bb);
  });

  // ------------------------------------------------------------
  // 6. Convert to image normalized coords
  // ------------------------------------------------------------
  final List<ui.Offset> pts = [];

  for (int i = 0; i < border.length; i += 2) {
    final p = border[i];

    final nx = (p.x + 0.5) / mw;
    final ny = (p.y + 0.5) / mh;

    pts.add(
      _unletterboxPoint(nx, ny, origW, origH, lb),
    );
  }

  return pts;
}

class _Pt {
  final double x;
  final double y;

  const _Pt(this.x, this.y);
}

// ─── Coordinate un-letterboxing ───────────────────────────────────────────────

/// Letterboxed-640 normalised coords → original image normalised coords.
ui.Rect _unletterboxRect(
    double x1, double y1, double x2, double y2,
    int origW, int origH, _Letterbox lb) {
  double u(double v, double pad, int dim) =>
      ((v * _inSize - pad) / (dim * lb.scale)).clamp(0.0, 1.0);
  return ui.Rect.fromLTRB(
    u(x1, lb.padX.toDouble(), origW),
    u(y1, lb.padY.toDouble(), origH),
    u(x2, lb.padX.toDouble(), origW),
    u(y2, lb.padY.toDouble(), origH),
  );
}

ui.Offset _unletterboxPoint(
    double nx, double ny, int origW, int origH, _Letterbox lb) {
  double u(double v, double pad, int dim) =>
      ((v * _inSize - pad) / (dim * lb.scale)).clamp(0.0, 1.0);
  return ui.Offset(
    u(nx, lb.padX.toDouble(), origW),
    u(ny, lb.padY.toDouble(), origH),
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// MOCK — returns fake results for UI development without the real model
// In scan_screen.dart swap: YoloMock.classify → YoloService.classify
// ─────────────────────────────────────────────────────────────────────────────
class YoloMock {
  static Future<InferenceResponse> classify(File imageFile) async {
    await Future.delayed(const Duration(milliseconds: 1200));

    final rng = math.Random();
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

    // Ellipse as mock segmentation polygon
    final mask = List.generate(48, (i) {
      final angle = (i / 48) * 2 * math.pi;
      return ui.Offset(
          0.50 + 0.30 * math.cos(angle), 0.50 + 0.35 * math.sin(angle));
    });

    final variety = getVarietyById(ids[topIdx])!;
    return InferenceResponse(
      imageWidth: imgW,
      imageHeight: imgH,
      annotatedImageBytes: null, // ONNX path never returns annotatedImage
      detections: [
        DetectionResult(
          classId: variety.id,
          className: variety.name,
          yoloTag: variety.id,
          confidence: topConf,
          boundingBox: const ui.Rect.fromLTWH(0.14, 0.10, 0.72, 0.80),
          segmentation: mask,
          allConfidences: allConf,
        ),
      ],
    );
  }
}