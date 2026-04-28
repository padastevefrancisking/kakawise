// lib/screens/scan_screen.dart

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:math' as math;

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
  Uint8List? _correctedImageBytes; // EXIF-decoded PNG — same as what model saw
  InferenceResponse? _response;
  Uint8List? _renderedOverlay;     // used for ResultScreen hero image
  bool _loading = false;
  String? _error;

  // ── Image picking ──────────────────────────────────────────────────────────
  Future<void> _pick() async {
    final src = _mode == _ScanMode.camera ? ImageSource.camera : ImageSource.gallery;
    try {
      final xf = await _picker.pickImage(
          source: src, imageQuality: 92, maxWidth: 1280, maxHeight: 1280);
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

  // ── Inference ──────────────────────────────────────────────────────────────
  Future<void> _infer() async {
    if (_imageFile == null) return;
    setState(() { _loading = true; _error = null; });

    try {
      // EXIF-correct decode → PNG (same preprocessing as YoloService)
      final rawBytes = await _imageFile!.readAsBytes();
      final codec = await ui.instantiateImageCodec(rawBytes);
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;
      final pngData = await srcImage.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List corrected = pngData!.buffer.asUint8List();
      srcImage.dispose();

      // Switch YoloMock → YoloService.classify when model is ready
      final resp = await YoloService.classify(_imageFile!);
      // final resp = await YoloMock.classify(_imageFile!);

      print('=== SCAN RESULT ===');
      print('detections: ${resp.detections.length}  annotatedImage: ${resp.annotatedImageBytes != null}');
      for (var i = 0; i < resp.detections.length; i++) {
        final d = resp.detections[i];
        print('  [${i+1}] ${d.yoloTag} conf=${d.confidence.toStringAsFixed(3)} box=${d.boundingBox}');
      }

      // Render overlay for ResultScreen hero.
      // If the plugin gave us an annotated image, use that; otherwise paint ourselves.
      Uint8List rendered;
      if (resp.annotatedImageBytes != null) {
        // Plugin image already has masks — just draw our numbered labels on top
        final ac = await ui.instantiateImageCodec(resp.annotatedImageBytes!);
        final af = await ac.getNextFrame();
        rendered = await renderOverlay(
            sourceImage: af.image, inferenceResponse: resp);
        af.image.dispose();
      } else {
        final oc = await ui.instantiateImageCodec(corrected);
        final of = await oc.getNextFrame();
        rendered = await renderOverlay(
            sourceImage: of.image, inferenceResponse: resp);
        of.image.dispose();
      }

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

  // ── Navigate to result for a specific variety ──────────────────────────────
  void _openResult(CacaoVariety variety) {
    if (_renderedOverlay == null || _response == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          renderedOverlayBytes: _renderedOverlay!,
          inferenceResponse: _response!,
          variety: variety,
        ),
      ),
    );
  }

  void _setMode(_ScanMode m) {
    if (_mode == m) return;
    setState(() => _mode = m);
  }

  // ── Build ──────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KakaWiseTheme.surface,
      // No header here — it's in _MainShell
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Scanning section ─────────────────────────────────────────────
          _sectionLabel('SCANNING'),
          const SizedBox(height: 8),
          _imageArea(),
          const SizedBox(height: 12),

          // ── Mode toggle — fix 5: fills entire toggle width ───────────────
          _ModeToggle(mode: _mode, onChanged: _setMode),
          const SizedBox(height: 12),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _pick,
              icon: Icon(
                _mode == _ScanMode.camera
                    ? Icons.camera_alt_rounded
                    : Icons.photo_library_rounded,
                size: 18,
              ),
              label: Text(
                _mode == _ScanMode.camera ? 'Take a photo' : 'Choose from gallery',
              ),
            ),
          ),
          const SizedBox(height: 6),
          Center(
            child: Text(
              _mode == _ScanMode.camera
                  ? 'Point your camera at a cacao pod'
                  : 'Select a cacao pod photo from your gallery',
              style: GoogleFonts.inter(
                  fontSize: 11, color: KakaWiseTheme.textSecondary),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _error!, onRetry: _infer),
          ],

          // ── Detection results section ─────────────────────────────────────
          const SizedBox(height: 20),
          _sectionLabel('DETECTION RESULTS'),
          const SizedBox(height: 8),

          if (_loading)
            const _LoadingResultPlaceholder()
          else if (_response == null)
            const _EmptyResultPlaceholder()
          else if (_response!.detections.isEmpty)
              _NoDetectionBanner(onRetry: _pick)
            else
              _DetectionResultsPanel(
                response: _response!,
                onOpenDetail: _openResult,
              ),

          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _sectionLabel(String text) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: KakaWiseTheme.textSecondary,
          letterSpacing: 1.0));

  // ── Image area ─────────────────────────────────────────────────────────────
  Widget _imageArea() {
    // Determine what to show in the square preview
    Widget content;
    if (_imageFile == null) {
      content = const _EmptyPlaceholder();
    } else if (_loading) {
      content = const _LoadingView();
    } else if (_response != null &&
        _response!.detections.isNotEmpty &&
        _correctedImageBytes != null) {
      // Show detection overlay — use annotatedImage if available, else corrected
      content = DetectionOverlay(
        inferenceResponse: _response!,
        imageBytes: _correctedImageBytes!,
      );
    } else if (_correctedImageBytes != null) {
      content = Image.memory(_correctedImageBytes!, fit: BoxFit.cover);
    } else {
      content = Image.file(_imageFile!, fit: BoxFit.cover);
    }

    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(
          color: KakaWiseTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KakaWiseTheme.border, width: 0.5),
        ),
        clipBehavior: Clip.hardEdge,
        child: content,
      ),
    );
  }
}

// ─── Detection results panel ──────────────────────────────────────────────────
//
// Groups detections by variety so that if labels 1, 2, 4 are all UF18,
// there is ONE UF18 card showing "Labels: 1, 2, 4".

class _DetectionResultsPanel extends StatelessWidget {
  final InferenceResponse response;
  final ValueChanged<CacaoVariety> onOpenDetail;

  const _DetectionResultsPanel({
    required this.response,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
    // Group detections by classId, keeping track of 1-based label numbers
    final Map<String, ({CacaoVariety? variety, List<int> labels, double maxConf})> groups = {};

    for (var i = 0; i < response.detections.length; i++) {
      final d = response.detections[i];
      final label = i + 1;
      final variety = getVarietyById(d.classId) ?? getVarietyByYoloClass(d.yoloTag);

      final key = d.classId;
      if (!groups.containsKey(key)) {
        groups[key] = (variety: variety, labels: [label], maxConf: d.confidence);
      } else {
        final existing = groups[key]!;
        groups[key] = (
        variety: existing.variety,
        labels: [...existing.labels, label],
        maxConf: math.max(existing.maxConf, d.confidence),
        );
      }
    }

    return Column(
      children: groups.entries.map((entry) {
        final g = entry.value;
        final variety = g.variety;
        final color = variety != null ? Color(variety.colorHex) : KakaWiseTheme.primary;
        final labelStr = g.labels.map((n) => 'Label $n').join(', ');

        return Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: Container(
            decoration: BoxDecoration(
              color: KakaWiseTheme.cardBg,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: color.withOpacity(0.3), width: 0.8),
            ),
            child: Column(children: [
              // Top row — variety info + confidence
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(children: [
                  // Colour dot
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: color.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(10)),
                    child: Icon(Icons.eco_rounded, color: color, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(variety?.name ?? entry.key,
                          style: GoogleFonts.inter(
                              fontSize: 16, fontWeight: FontWeight.w700,
                              color: KakaWiseTheme.textPrimary)),
                      Text('${(g.maxConf * 100).toStringAsFixed(1)}% confidence',
                          style: GoogleFonts.inter(
                              fontSize: 11, color: KakaWiseTheme.textSecondary)),
                    ]),
                  ),
                  if (variety != null)
                    GestureDetector(
                      onTap: () => onOpenDetail(variety),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                        decoration: BoxDecoration(
                            color: color, borderRadius: BorderRadius.circular(20)),
                        child: Text('Details',
                            style: GoogleFonts.inter(
                                fontSize: 12, fontWeight: FontWeight.w600,
                                color: Colors.white)),
                      ),
                    ),
                ]),
              ),
              // Label numbers row
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.06),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
                ),
                child: Row(children: [
                  Icon(Icons.tag_rounded, size: 13, color: color.withOpacity(0.7)),
                  const SizedBox(width: 5),
                  Text(labelStr,
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: color.withOpacity(0.85))),
                  const SizedBox(width: 8),
                  Text(
                    '${g.labels.length} detection${g.labels.length != 1 ? 's' : ''}',
                    style: GoogleFonts.inter(
                        fontSize: 10, color: KakaWiseTheme.textSecondary),
                  ),
                ]),
              ),
            ]),
          ),
        );
      }).toList(),
    );
  }
}

// ─── Mode toggle — fix 5 ─────────────────────────────────────────────────────
// Uses Material InkWell so the entire half fills visually when active.

class _ModeToggle extends StatelessWidget {
  final _ScanMode mode;
  final ValueChanged<_ScanMode> onChanged;
  const _ModeToggle({required this.mode, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 44,
      decoration: BoxDecoration(
        color: KakaWiseTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KakaWiseTheme.border, width: 0.5),
      ),
      child: Row(children: [
        _Seg(
          icon: Icons.camera_alt_outlined,
          label: 'Take Photo',
          active: mode == _ScanMode.camera,
          leftCorner: true,
          onTap: () => onChanged(_ScanMode.camera),
        ),
        Container(width: 0.5, color: KakaWiseTheme.border),
        _Seg(
          icon: Icons.photo_library_outlined,
          label: 'Upload Image',
          active: mode == _ScanMode.gallery,
          leftCorner: false,
          onTap: () => onChanged(_ScanMode.gallery),
        ),
      ]),
    );
  }
}

class _Seg extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool leftCorner;
  final VoidCallback onTap;
  const _Seg({
    required this.icon, required this.label,
    required this.active, required this.leftCorner, required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? KakaWiseTheme.primary : KakaWiseTheme.textSecondary;
    final br = leftCorner
        ? const BorderRadius.horizontal(left: Radius.circular(11))
        : const BorderRadius.horizontal(right: Radius.circular(11));

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          height: double.infinity,      // fills the full 44px height
          decoration: BoxDecoration(
            // Active: solid primary tint fills the ENTIRE half
            color: active ? KakaWiseTheme.primary.withOpacity(0.1) : Colors.transparent,
            borderRadius: br,
          ),
          child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w400,
                    color: color)),
          ]),
        ),
      ),
    );
  }
}

// ─── Placeholder / loading sub-widgets ───────────────────────────────────────

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      Container(
        width: 72, height: 72,
        decoration: BoxDecoration(
            color: KakaWiseTheme.primary.withOpacity(0.08),
            borderRadius: BorderRadius.circular(18)),
        child: Icon(Icons.eco_outlined,
            size: 36, color: KakaWiseTheme.primary.withOpacity(0.45)),
      ),
      const SizedBox(height: 14),
      Text('No image selected',
          style: GoogleFonts.inter(
              fontSize: 14, fontWeight: FontWeight.w500,
              color: KakaWiseTheme.textSecondary)),
      const SizedBox(height: 4),
      Text('Take or upload a photo to identify\nthe cacao pod variety',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
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
      const CircularProgressIndicator(
          valueColor: AlwaysStoppedAnimation<Color>(KakaWiseTheme.primary),
          strokeWidth: 2.5),
      const SizedBox(height: 16),
      Text('Analyzing image…',
          style: GoogleFonts.inter(fontSize: 14, color: KakaWiseTheme.textSecondary)),
      const SizedBox(height: 4),
      Text('Running on-device YOLOv12',
          style: GoogleFonts.inter(
              fontSize: 11, color: KakaWiseTheme.textSecondary.withOpacity(0.6))),
    ]);
  }
}

class _EmptyResultPlaceholder extends StatelessWidget {
  const _EmptyResultPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KakaWiseTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KakaWiseTheme.border, width: 0.5),
      ),
      child: Center(
        child: Text('Scan a cacao pod to see results here.',
            style: GoogleFonts.inter(
                fontSize: 13, color: KakaWiseTheme.textSecondary)),
      ),
    );
  }
}

class _LoadingResultPlaceholder extends StatelessWidget {
  const _LoadingResultPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: KakaWiseTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KakaWiseTheme.border, width: 0.5),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        const SizedBox(
          width: 16, height: 16,
          child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(KakaWiseTheme.primary)),
        ),
        const SizedBox(width: 10),
        Text('Running analysis…',
            style: GoogleFonts.inter(
                fontSize: 13, color: KakaWiseTheme.textSecondary)),
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
        border: Border.all(color: const Color(0xFFFFB300).withOpacity(0.4), width: 0.5),
      ),
      child: Row(children: [
        const Icon(Icons.search_off_rounded, color: Color(0xFF8A6200), size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            'No cacao pod detected with sufficient confidence.\n'
                'Try getting closer or improving lighting.',
            style: GoogleFonts.inter(
                fontSize: 12, color: const Color(0xFF8A6200), height: 1.4),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text('Retry',
              style: GoogleFonts.inter(
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
        border: Border.all(color: const Color(0xFFF09595).withOpacity(0.4), width: 0.5),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: Color(0xFFA32D2D), size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(message,
              style: GoogleFonts.inter(
                  fontSize: 12, color: const Color(0xFFA32D2D))),
        ),
        TextButton(
          onPressed: onRetry,
          child: Text('Retry',
              style: GoogleFonts.inter(
                  fontSize: 12, fontWeight: FontWeight.w600,
                  color: const Color(0xFFA32D2D))),
        ),
      ]),
    );
  }
}