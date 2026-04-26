// lib/screens/scan_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../models/cacao_variety.dart';
import '../models/detection_result.dart';
import '../services/yolo_service.dart';
import '../services/overlay_renderer.dart';
import '../theme.dart';
import '../widgets/detection_overlay.dart';
import 'result_screen.dart';

enum _ScanMode { camera, gallery }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  final _picker = ImagePicker();

  _ScanMode _mode = _ScanMode.camera;
  File? _imageFile;

  // The EXIF-corrected PNG bytes that were actually fed to the model.
  // We use these for the overlay renderer so dimensions always match.
  Uint8List? _correctedImageBytes;

  InferenceResponse? _response;
  Uint8List? _renderedOverlay;
  bool _loading = false;
  String? _error;

  // ── Image picking ────────────────────────────────────────────────────────────
  Future<void> _pick() async {
    final src = _mode == _ScanMode.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    try {
      final xf = await _picker.pickImage(
        source: src,
        imageQuality: 92,
        maxWidth: 1280,
        maxHeight: 1280,
      );
      if (xf == null) return;
      setState(() {
        _imageFile = File(xf.path);
        _correctedImageBytes = null;
        _response = null;
        _renderedOverlay = null;
        _error = null;
      });
      await _infer();
    } catch (e) {
      setState(() => _error = 'Could not open image: $e');
    }
  }

  // ── Inference + overlay render ───────────────────────────────────────────────
  Future<void> _infer() async {
    if (_imageFile == null) return;
    setState(() { _loading = true; _error = null; });

    try {
      // ── Step 1: EXIF-correct decode ──────────────────────────────────────
      // Decode the raw JPEG honouring EXIF orientation, then re-encode to PNG.
      // This is the same step YoloService does internally — we keep the result
      // here so the overlay renderer uses the exact same pixel dimensions.
      final rawBytes = await _imageFile!.readAsBytes();
      final codec = await ui.instantiateImageCodec(rawBytes);
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;
      final pngData = await srcImage.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List corrected = pngData!.buffer.asUint8List();

      // ── Step 2: Run inference ─────────────────────────────────────────────
      // Switch comment to use the real model:
      final resp = await YoloService.classify(_imageFile!);

      print('=== SCAN RESULT ===');
      print('detections: ${resp.detections.length}');
      print('imageW=${resp.imageWidth} imageH=${resp.imageHeight}');
      for (final d in resp.detections) {
        print('  ${d.yoloTag} conf=${d.confidence.toStringAsFixed(3)} '
            'box=${d.boundingBox} mask_pts=${d.segmentation?.length ?? 0}');
      }

      // ── Step 3: Render overlay onto the corrected image ───────────────────
      // Re-decode the corrected PNG to a ui.Image for the canvas painter.
      final overlayCodec = await ui.instantiateImageCodec(corrected);
      final overlayFrame = await overlayCodec.getNextFrame();
      final rendered = await renderOverlay(
        sourceImage: overlayFrame.image,
        inferenceResponse: resp,
      );
      overlayFrame.image.dispose();
      srcImage.dispose();

      setState(() {
        _correctedImageBytes = corrected;
        _response = resp;
        _renderedOverlay = rendered;
        _loading = false;
      });
    } catch (e, st) {
      print('_infer error: $e\n$st');
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

  // ── Navigate to result ────────────────────────────────────────────────────────
  void _openResult() {
    final top = _response?.topDetection;

    print('_openResult: top=$top renderedOverlay=${_renderedOverlay != null}');

    if (top == null) {
      setState(() => _error = 'No detection found. Try scanning again.');
      return;
    }
    if (_renderedOverlay == null) {
      setState(() => _error = 'Overlay render failed. Try scanning again.');
      return;
    }

    // Resolve variety — try classId first, then yoloTag as fallback
    CacaoVariety? variety = getVarietyById(top.classId);
    variety ??= getVarietyByYoloClass(top.yoloTag);

    print('variety resolved: ${variety?.name} (classId=${top.classId} tag=${top.yoloTag})');

    if (variety == null) {
      setState(() => _error =
      'Unknown variety "${top.yoloTag}". Check yoloClassToVarietyId map.');
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          renderedOverlayBytes: _renderedOverlay!,
          inferenceResponse: _response!,
          variety: variety!,
        ),
      ),
    );
  }

  void _setMode(_ScanMode m) {
    if (_mode == m) return;
    setState(() => _mode = m);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KakaWiseTheme.surface,
      body: SafeArea(
        child: Column(children: [
          _buildHeader(),
          Container(height: 0.5, color: KakaWiseTheme.border),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _imageArea(),
                  const SizedBox(height: 16),

                  _ModeToggle(mode: _mode, onChanged: _setMode),
                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: _pick,
                    icon: Icon(
                      _mode == _ScanMode.camera
                          ? Icons.camera_alt_rounded
                          : Icons.photo_library_rounded,
                      size: 18,
                    ),
                    label: Text(
                      _mode == _ScanMode.camera
                          ? 'Take a photo'
                          : 'Choose from gallery',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Center(
                    child: Text(
                      _mode == _ScanMode.camera
                          ? 'Point your camera at a cacao pod'
                          : 'Select a cacao pod photo from your gallery',
                      style: GoogleFonts.dmSans(
                          fontSize: 11, color: KakaWiseTheme.textSecondary),
                    ),
                  ),

                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    _ErrorBanner(message: _error!, onRetry: _infer),
                  ],

                  if (_response != null && !_loading) ...[
                    const SizedBox(height: 14),
                    // Show chip only when there are actual detections
                    if (_response!.detections.isNotEmpty)
                      _ResultChip(
                          response: _response!, onDetails: _openResult)
                    else
                      _NoDetectionBanner(onRetry: _pick),
                  ],
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _buildHeader() => Padding(
    padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
    child: Row(children: [
      Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
            color: KakaWiseTheme.primary,
            borderRadius: BorderRadius.circular(8)),
        child: const Icon(Icons.eco_rounded, color: Colors.white, size: 18),
      ),
      const SizedBox(width: 10),
      Text('KakaWise',
          style: GoogleFonts.dmSerifDisplay(
              fontSize: 26,
              color: KakaWiseTheme.primary,
              letterSpacing: -0.3)),
    ]),
  );

  Widget _imageArea() {
    // Use the EXIF-corrected bytes for display when available so the image
    // shown matches the coordinate space used by the overlay painter.
    final Widget imageWidget = _correctedImageBytes != null
        ? Image.memory(_correctedImageBytes!, fit: BoxFit.cover)
        : (_imageFile != null
        ? Image.file(_imageFile!, fit: BoxFit.cover)
        : const _EmptyPlaceholder());

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: KakaWiseTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KakaWiseTheme.border, width: 0.5),
        ),
        clipBehavior: Clip.hardEdge,
        child: _imageFile == null
            ? const _EmptyPlaceholder()
            : _loading
            ? const _LoadingView()
            : _response != null && _response!.detections.isNotEmpty
            ? DetectionOverlay(
          inferenceResponse: _response!,
          imageWidget: imageWidget,
        )
            : imageWidget,
      ),
    );
  }
}

// ─── Mode toggle ──────────────────────────────────────────────────────────────

class _ModeToggle extends StatelessWidget {
  final _ScanMode mode;
  final ValueChanged<_ScanMode> onChanged;
  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: KakaWiseTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KakaWiseTheme.border, width: 0.5),
      ),
      child: Row(children: [
        _Segment(
          icon: Icons.camera_alt_outlined,
          label: 'Take Photo',
          active: mode == _ScanMode.camera,
          isFirst: true,
          onTap: () => onChanged(_ScanMode.camera),
        ),
        Container(width: 0.5, color: KakaWiseTheme.border),
        _Segment(
          icon: Icons.photo_library_outlined,
          label: 'Upload Image',
          active: mode == _ScanMode.gallery,
          isFirst: false,
          onTap: () => onChanged(_ScanMode.gallery),
        ),
      ]),
    );
  }
}

class _Segment extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool isFirst;
  final VoidCallback onTap;
  const _Segment({
    required this.icon, required this.label,
    required this.active, required this.isFirst, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? KakaWiseTheme.primary : KakaWiseTheme.textSecondary;
    final radius = isFirst
        ? const BorderRadius.horizontal(left: Radius.circular(11))
        : const BorderRadius.horizontal(right: Radius.circular(11));
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          decoration: BoxDecoration(
            color: active ? KakaWiseTheme.primary.withOpacity(0.08) : Colors.transparent,
            borderRadius: radius,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.dmSans(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                    color: color)),
          ]),
        ),
      ),
    );
  }
}

// ─── Sub-widgets ──────────────────────────────────────────────────────────────

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 72,
        height: 72,
        decoration: BoxDecoration(
          color: KakaWiseTheme.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(18),
        ),
        child: Icon(Icons.eco_outlined,
            size: 36, color: KakaWiseTheme.primary.withOpacity(0.45)),
      ),
      const SizedBox(height: 14),
      Text('No image selected',
          style: GoogleFonts.dmSans(
              fontSize: 14, fontWeight: FontWeight.w500,
              color: KakaWiseTheme.textSecondary)),
      const SizedBox(height: 4),
      Text('Take or upload a photo to identify\nthe cacao pod variety',
          textAlign: TextAlign.center,
          style: GoogleFonts.dmSans(
              fontSize: 12,
              color: KakaWiseTheme.textSecondary.withOpacity(0.65),
              height: 1.5)),
    ]);
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(KakaWiseTheme.primary),
          strokeWidth: 2.5),
      const SizedBox(height: 16),
      Text('Analyzing image…',
          style: GoogleFonts.dmSans(fontSize: 14, color: KakaWiseTheme.textSecondary)),
      const SizedBox(height: 4),
      Text('Running on-device YOLOv12',
          style: GoogleFonts.dmSans(
              fontSize: 11, color: KakaWiseTheme.textSecondary.withOpacity(0.6))),
    ]);
  }
}

class _ResultChip extends StatelessWidget {
  final InferenceResponse response;
  final VoidCallback onDetails;
  const _ResultChip({required this.response, required this.onDetails});

  @override
  Widget build(BuildContext context) {
    final top = response.topDetection;
    if (top == null) return const SizedBox.shrink();
    final variety = getVarietyById(top.classId) ?? getVarietyByYoloClass(top.yoloTag);
    final color = variety != null ? Color(variety.colorHex) : KakaWiseTheme.primary;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.25), width: 0.5),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10)),
          child: Icon(Icons.eco_rounded, color: color, size: 20),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(top.className,
                style: GoogleFonts.dmSerifDisplay(
                    fontSize: 17, color: KakaWiseTheme.textPrimary)),
            Text(
                '${(top.confidence * 100).toStringAsFixed(1)}% confidence · '
                    '${response.detections.length} detection'
                    '${response.detections.length != 1 ? 's' : ''}',
                style: GoogleFonts.dmSans(
                    fontSize: 11, color: KakaWiseTheme.textSecondary)),
          ]),
        ),
        GestureDetector(
          onTap: onDetails,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
            decoration: BoxDecoration(
                color: color, borderRadius: BorderRadius.circular(20)),
            child: Text('Details',
                style: GoogleFonts.dmSans(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: Colors.white)),
          ),
        ),
      ]),
    );
  }
}

class _NoDetectionBanner extends StatelessWidget {
  final VoidCallback onRetry;
  const _NoDetectionBanner({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF8E1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFFFB300).withOpacity(0.4), width: 0.5),
      ),
      child: Row(children: [
        const Icon(Icons.search_off_rounded,
            color: Color(0xFF8A6200), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'No cacao pod detected with sufficient confidence.\n'
                'Try getting closer or improving the lighting.',
            style: GoogleFonts.dmSans(
                fontSize: 12, color: const Color(0xFF8A6200), height: 1.4),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text('Retry',
              style: GoogleFonts.dmSans(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: const Color(0xFF8A6200))),
        ),
      ]),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBanner({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFCEBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: const Color(0xFFF09595).withOpacity(0.4), width: 0.5),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: Color(0xFFA32D2D), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: GoogleFonts.dmSans(
                  fontSize: 12, color: const Color(0xFFA32D2D))),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text('Retry',
              style: GoogleFonts.dmSans(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: const Color(0xFFA32D2D))),
        ),
      ]),
    );
  }
}