// lib/screens/tutorial_screen.dart
//
// Shown once on first launch (gate kept by shared_preferences key
// 'tutorial_done').  Four pages:
//   1. Introduction — what KakaWise is
//   2. How to use — take photo or upload
//   3. Distance tip — how far to stand from the pod
//   4. Disclaimer — characteristics may vary

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';

class TutorialScreen extends StatefulWidget {
  /// Called after the user finishes or skips the tutorial.
  final VoidCallback onDone;

  const TutorialScreen({super.key, required this.onDone});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  final PageController _ctrl = PageController();
  int _page = 0;
  static const int _total = 4;

  void _next() {
    if (_page < _total - 1) {
      _ctrl.nextPage(
        duration: const Duration(milliseconds: 380),
        curve: Curves.easeInOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _finish() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('tutorial_done', true);
    widget.onDone();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KakaWiseTheme.surface,
      body: SafeArea(
        child: Column(children: [
          // ── Skip button ────────────────────────────────────────────────
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: _finish,
              child: Text('Skip',
                  style: GoogleFonts.dmSans(
                      fontSize: 13,
                      color: KakaWiseTheme.textSecondary,
                      fontWeight: FontWeight.w500)),
            ),
          ),

          // ── Pages ──────────────────────────────────────────────────────
          Expanded(
            child: PageView(
              controller: _ctrl,
              onPageChanged: (i) => setState(() => _page = i),
              children: const [
                _Page1Intro(),
                _Page2HowTo(),
                _Page3Distance(),
                _Page4Disclaimer(),
              ],
            ),
          ),

          // ── Dots + Next/Done button ────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Row(children: [
              // Dots
              Row(
                children: List.generate(_total, (i) {
                  final active = i == _page;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 260),
                    curve: Curves.easeInOut,
                    width: active ? 22 : 7,
                    height: 7,
                    margin: const EdgeInsets.only(right: 5),
                    decoration: BoxDecoration(
                      color: active
                          ? KakaWiseTheme.primary
                          : KakaWiseTheme.border,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  );
                }),
              ),
              const Spacer(),
              // Next / Done
              FilledButton(
                onPressed: _next,
                style: FilledButton.styleFrom(
                  backgroundColor: KakaWiseTheme.primary,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(
                    _page < _total - 1 ? 'Next' : 'Get started',
                    style: GoogleFonts.dmSans(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: Colors.white),
                  ),
                  const SizedBox(width: 6),
                  Icon(
                    _page < _total - 1
                        ? Icons.arrow_forward_rounded
                        : Icons.check_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ]),
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

// ─── Shared layout ────────────────────────────────────────────────────────────

class _TutorialPage extends StatelessWidget {
  final Widget illustration;
  final String title;
  final String body;
  final Color accentColor;

  const _TutorialPage({
    required this.illustration,
    required this.title,
    required this.body,
    this.accentColor = KakaWiseTheme.primary,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration card
          Container(
            width: double.infinity,
            height: 220,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                  color: accentColor.withValues(alpha: 0.18), width: 0.5),
            ),
            child: illustration,
          ),
          const SizedBox(height: 32),
          Text(title,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSerifDisplay(
                  fontSize: 26,
                  color: KakaWiseTheme.textPrimary,
                  height: 1.2)),
          const SizedBox(height: 12),
          Text(body,
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  fontSize: 14,
                  color: KakaWiseTheme.textSecondary,
                  height: 1.6)),
        ],
      ),
    );
  }
}

// ─── Page 1 — Introduction ───────────────────────────────────────────────────

class _Page1Intro extends StatelessWidget {
  const _Page1Intro();

  @override
  Widget build(BuildContext context) {
    return _TutorialPage(
      accentColor: KakaWiseTheme.primary,
      title: 'Welcome to KakaWise',
      body:
      'KakaWise helps you identify Philippine NSIC-registered cacao pod '
          'varieties — BR 25, UF 18, and W 10 — using on-device AI. '
          'No internet connection required.',
      illustration: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: KakaWiseTheme.primary,
              borderRadius: BorderRadius.circular(18),
            ),
            child: const Icon(Icons.eco_rounded,
                color: Colors.white, size: 38),
          ),
          const SizedBox(height: 16),
          Text('KakaWise',
              style: GoogleFonts.dmSerifDisplay(
                  fontSize: 28,
                  color: KakaWiseTheme.primary,
                  letterSpacing: -0.5)),
          const SizedBox(height: 4),
          Text('Cacao Variety Identifier',
              style: GoogleFonts.dmSans(
                  fontSize: 13, color: KakaWiseTheme.textSecondary)),
          const SizedBox(height: 12),
          const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            _CloneChip('BR 25', Color(0xFFEF9F27)),
            SizedBox(width: 6),
            _CloneChip('UF 18', Color(0xFF7F77DD)),
            SizedBox(width: 6),
            _CloneChip('W 10', Color(0xFF1D9E75)),
          ]),
        ],
      ),
    );
  }
}

class _CloneChip extends StatelessWidget {
  final String label;
  final Color color;
  const _CloneChip(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Text(label,
          style: GoogleFonts.dmSans(
              fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    );
  }
}

// ─── Page 2 — How to use ─────────────────────────────────────────────────────

class _Page2HowTo extends StatelessWidget {
  const _Page2HowTo();

  @override
  Widget build(BuildContext context) {
    return _TutorialPage(
      accentColor: KakaWiseTheme.primary,
      title: 'Take a photo or upload one',
      body:
      'Tap the Scan Pod tab at the bottom. Choose "Take Photo" to use your camera, or "Upload Image" to pick a photo from your gallery. The app will analyse it automatically.',

      illustration: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // ── Segmented toggle ───────────────────────────────
            Container(
              height: 44,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: KakaWiseTheme.border,
                  width: 0.5,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: double.infinity,
                      decoration: BoxDecoration(
                        color: KakaWiseTheme.primary.withValues(alpha: 0.10),
                        borderRadius: const BorderRadius.horizontal(
                          left: Radius.circular(11),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.camera_alt_outlined,
                            size: 16,
                            color: KakaWiseTheme.primary,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Take Photo',
                            style: GoogleFonts.dmSans(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: KakaWiseTheme.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  Container(
                    width: 0.5,
                    color: KakaWiseTheme.border,
                  ),

                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.photo_library_outlined,
                          size: 16,
                          color: KakaWiseTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Upload Image',
                          style: GoogleFonts.dmSans(
                            fontSize: 11,
                            color: KakaWiseTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 14),

            // ── Main scan button ──────────────────────────────
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: null,
                style: FilledButton.styleFrom(
                  disabledBackgroundColor: KakaWiseTheme.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.symmetric(vertical: 13),
                ),
                icon: const Icon(
                  Icons.camera_alt_rounded,
                  size: 18,
                  color: Colors.white,
                ),
                label: Text(
                  'Take a photo',
                  style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
            ),

            const SizedBox(height: 10),

            Text(
              'Point your camera at a cacao pod',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                fontSize: 11,
                color: KakaWiseTheme.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Page 3 — Distance tip ───────────────────────────────────────────────────

class _Page3Distance extends StatelessWidget {
  const _Page3Distance();

  @override
  Widget build(BuildContext context) {
    return _TutorialPage(
      accentColor: const Color(0xFFEF9F27),
      title: 'Keep a good distance',
      body:
      'For best results, position the cacao pod at arm\'s length '
          '(about 30–50 cm away). Make sure the entire pod is visible '
          'in the frame, with good lighting and a plain background if possible.',
      illustration: Stack(
        alignment: Alignment.center,
        children: [
          // Pod silhouette
          Container(
            width: 64,
            height: 86,
            decoration: BoxDecoration(
              color: const Color(0xFFEF9F27).withValues(alpha: 0.25),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                  color: const Color(0xFFEF9F27).withValues(alpha: 0.6),
                  width: 1.5),
            ),
          ),
          // Distance arrows
          Positioned(
            left: 28,
            child: Row(children: [
              const SizedBox(width: 52),
              _DistanceArrow(),
            ]),
          ),
          // Camera icon at right
          Positioned(
            right: 18,
            child: Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: KakaWiseTheme.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.camera_alt_rounded,
                  size: 24,
                  color: KakaWiseTheme.primary),
            ),
          ),
          // Label
          Positioned(
            bottom: 18,
            child: Text('30–50 cm',
                style: GoogleFonts.dmSans(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFEF9F27))),
          ),
        ],
      ),
    );
  }
}

class _DistanceArrow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Container(
        width: 60,
        height: 1.5,
        color: KakaWiseTheme.textSecondary.withValues(alpha: 0.4),
      ),
      Icon(Icons.arrow_forward_ios_rounded,
          size: 10, color: KakaWiseTheme.textSecondary.withValues(alpha: 0.5)),
    ]);
  }
}

// ─── Page 4 — Disclaimer ─────────────────────────────────────────────────────

class _Page4Disclaimer extends StatelessWidget {
  const _Page4Disclaimer();

  @override
  Widget build(BuildContext context) {
    return _TutorialPage(
      accentColor: const Color(0xFFA0522D),
      title: 'A note on accuracy',
      body:
      'Characteristics displayed may vary due to environmental factors '
          'such as sunlight exposure, soil conditions, and growth stage. '
          'Use KakaWise as a helpful guide — always consult an agronomist '
          'or the Bureau of Plant Industry for official classification.',
      illustration: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: Color(0xFFFAEDE6),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.info_outline_rounded,
                size: 32, color: Color(0xFFA0522D)),
          ),
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '"Results are indicative only and may be affected by '
                  'lighting, image angle, and crop maturity."',
              textAlign: TextAlign.center,
              style: GoogleFonts.dmSans(
                  fontSize: 12,
                  color: const Color(0xFFA0522D),
                  fontStyle: FontStyle.italic,
                  height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}