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
  Uint8List? _correctedImageBytes;
  InferenceResponse? _response;
  Uint8List? _renderedOverlay;
  bool _loading = false;
  String? _error;

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

  Future<void> _infer() async {
    if (_imageFile == null) return;
    setState(() { _loading = true; _error = null; });

    try {
      // EXIF-correct decode → PNG
      final rawBytes = await _imageFile!.readAsBytes();
      final codec = await ui.instantiateImageCodec(rawBytes);
      final frame = await codec.getNextFrame();
      final srcImage = frame.image;
      final pngData = await srcImage.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List corrected = pngData!.buffer.asUint8List();
      srcImage.dispose();

      final resp = await YoloService.classify(_imageFile!);
      // final resp = await YoloMock.classify(_imageFile!);

      // Render overlay PNG for ResultScreen hero
      Uint8List rendered;
      if (resp.annotatedImageBytes != null) {
        final ac = await ui.instantiateImageCodec(resp.annotatedImageBytes!);
        final af = await ac.getNextFrame();
        rendered = await renderOverlay(sourceImage: af.image, inferenceResponse: resp);
        af.image.dispose();
      } else {
        final oc = await ui.instantiateImageCodec(corrected);
        final of = await oc.getNextFrame();
        rendered = await renderOverlay(sourceImage: of.image, inferenceResponse: resp);
        of.image.dispose();
      }

      setState(() {
        _correctedImageBytes = corrected;
        _response = resp;
        _renderedOverlay = rendered;
        _loading = false;
      });
    } catch (e, st) {
      setState(() { _error = e.toString(); _loading = false; });
    }
  }

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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KakaWiseTheme.surface,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _sectionLabel('SCANNING'),
          const SizedBox(height: 8),
          _imageArea(),
          const SizedBox(height: 12),

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
              style: GoogleFonts.inter(fontSize: 11, color: KakaWiseTheme.textSecondary),
            ),
          ),

          if (_error != null) ...[
            const SizedBox(height: 12),
            _ErrorBanner(message: _error!, onRetry: _infer),
          ],

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

  Widget _imageArea() {
    Widget content;
    if (_imageFile == null) {
      content = const _EmptyPlaceholder();
    } else if (_loading) {
      content = const _LoadingView();
    } else if (_response != null &&
        _response!.detections.isNotEmpty &&
        _correctedImageBytes != null) {
      // ── Key fix: pass imageW/imageH so the overlay can compute the
      //    BoxFit.contain content rect and map coordinates into it correctly.
      content = DetectionOverlay(
        inferenceResponse: _response!,
        imageBytes: _correctedImageBytes!,
      );
    } else if (_correctedImageBytes != null) {
      content = Image.memory(_correctedImageBytes!, fit: BoxFit.contain);
    } else {
      content = Image.file(_imageFile!, fit: BoxFit.contain);
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

class _DetectionResultsPanel extends StatelessWidget {
  final InferenceResponse response;
  final ValueChanged<CacaoVariety> onOpenDetail;

  const _DetectionResultsPanel({
    required this.response,
    required this.onOpenDetail,
  });

  @override
  Widget build(BuildContext context) {
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
              border: Border.all(color: color.withValues(alpha: 0.3), width: 0.8),
            ),
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                child: Row(children: [
                  Container(
                    width: 40, height: 40,
                    decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10)),
                      child: _PodImage(color: color),
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
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.06),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(13)),
                ),
                child: Row(children: [
                  Icon(Icons.tag_rounded, size: 13, color: color.withValues(alpha: 0.7)),
                  const SizedBox(width: 5),
                  Text(labelStr,
                      style: GoogleFonts.inter(
                          fontSize: 11, fontWeight: FontWeight.w600,
                          color: color.withValues(alpha: 0.85))),
                  const SizedBox(width: 8),
                  Text('${g.labels.length} detection${g.labels.length != 1 ? 's' : ''}',
                      style: GoogleFonts.inter(
                          fontSize: 10, color: KakaWiseTheme.textSecondary)),
                ]),
              ),
            ]),
          ),
        );
      }).toList(),
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
      height: 44,
      decoration: BoxDecoration(
        color: KakaWiseTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KakaWiseTheme.border, width: 0.5),
      ),
      child: Row(children: [
        _Seg(icon: Icons.camera_alt_outlined, label: 'Take Photo',
            active: mode == _ScanMode.camera, leftCorner: true,
            onTap: () => onChanged(_ScanMode.camera)),
        Container(width: 0.5, color: KakaWiseTheme.border),
        _Seg(icon: Icons.photo_library_outlined, label: 'Upload Image',
            active: mode == _ScanMode.gallery, leftCorner: false,
            onTap: () => onChanged(_ScanMode.gallery)),
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
  const _Seg({required this.icon, required this.label,
    required this.active, required this.leftCorner, required this.onTap});

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
          height: double.infinity,
          decoration: BoxDecoration(
            color: active ? KakaWiseTheme.primary.withValues(alpha: 0.1) : Colors.transparent,
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

// ─── Placeholder / state widgets ──────────────────────────────────────────────

class _EmptyPlaceholder extends StatelessWidget {
  const _EmptyPlaceholder();
  @override
  Widget build(BuildContext context) {
    return Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      SizedBox(
        width: 72, height: 72,
        child: _PodImage(
          color: KakaWiseTheme.primary.withValues(alpha: 0.35),
          large: true,
        ),
      ),
      const SizedBox(height: 14),
      Text('No image selected',
          style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500,
              color: KakaWiseTheme.textSecondary)),
      const SizedBox(height: 4),
      Text('Take or upload a photo to identify\nthe cacao pod variety',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(fontSize: 12,
              color: KakaWiseTheme.textSecondary.withValues(alpha: 0.65), height: 1.5)),
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
          style: GoogleFonts.inter(fontSize: 14, color: KakaWiseTheme.textSecondary)),
      const SizedBox(height: 4),
      Text('Running on-device YOLOv12',
          style: GoogleFonts.inter(fontSize: 11,
              color: KakaWiseTheme.textSecondary.withValues(alpha: 0.6))),
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
        color: KakaWiseTheme.cardBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KakaWiseTheme.border, width: 0.5),
      ),
      child: Center(child: Text('Scan a cacao pod to see results here.',
          style: GoogleFonts.inter(fontSize: 13, color: KakaWiseTheme.textSecondary))),
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
        color: KakaWiseTheme.cardBg, borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KakaWiseTheme.border, width: 0.5),
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        SizedBox(width: 16, height: 16,
            child: CircularProgressIndicator(strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(KakaWiseTheme.primary))),
        const SizedBox(width: 10),
        Text('Running analysis…',
            style: GoogleFonts.inter(fontSize: 13, color: KakaWiseTheme.textSecondary)),
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
        color: const Color(0xFFFFF3E0), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KakaWiseTheme.accent.withValues(alpha: 0.4), width: 0.5),
      ),
      child: Row(children: [
        Icon(Icons.search_off_rounded, color: KakaWiseTheme.accent, size: 20),
        const SizedBox(width: 10),
        Expanded(child: Text(
          'No cacao pod detected with sufficient confidence.\nTry getting closer or improving lighting.',
          style: GoogleFonts.inter(fontSize: 12, color: KakaWiseTheme.textSecondary, height: 1.4),
        )),
        TextButton(onPressed: onRetry,
            child: Text('Retry', style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600, color: KakaWiseTheme.primary))),
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
        color: const Color(0xFFFCEBEB), borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF09595).withValues(alpha: 0.4), width: 0.5),
      ),
      child: Row(children: [
        const Icon(Icons.error_outline, color: Color(0xFFA32D2D), size: 18),
        const SizedBox(width: 8),
        Expanded(child: Text(message,
            style: GoogleFonts.inter(fontSize: 12, color: const Color(0xFFA32D2D)))),
        TextButton(onPressed: onRetry,
            child: Text('Retry', style: GoogleFonts.inter(
                fontSize: 12, fontWeight: FontWeight.w600,
                color: const Color(0xFFA32D2D)))),
      ]),
    );
  }
}

// ─── Cacao Pod icon painter (replaces eco icon throughout) ────────────────────

class _PodImage extends StatelessWidget {
  final Color color;
  final bool large;

  const _PodImage({
    required this.color,
    this.large = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.all(large ? 6 : 8),
      child: Image.asset(
        'assets/images/pods.png',
        fit: BoxFit.contain,
        color: color,
        colorBlendMode: BlendMode.srcIn,
        errorBuilder: (_, __, ___) => Icon(
          Icons.eco_rounded,
          color: color,
          size: large ? 42 : 22,
        ),
      ),
    );
  }
}