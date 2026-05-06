// lib/widgets/pod_image_gallery.dart
//
// Reusable section that shows a 2×2 grid of representative cacao pod photos
// for a given variety.  Tapping any thumbnail opens a full-screen lightbox
// with a swipeable PageView (animated slide + fade transitions) and a close
// button.
//
// Asset paths follow the convention:
//   assets/images/pods/<variety_id_lowercase>_<1-4>.jpg
// e.g.  assets/images/pods/br25_1.jpg … br25_4.jpg
//
// If an asset is missing, a placeholder tile is shown instead.

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme.dart';

// ─────────────────────────────────────────────────────────────────────────────
//  Public widget
// ─────────────────────────────────────────────────────────────────────────────

class PodImageGallery extends StatelessWidget {
  final String varietyId;   // e.g. 'BR25', 'UF18', 'W10'
  final Color accentColor;
  final int imageCount;      // how many images to show (default 4)

  const PodImageGallery({
    super.key,
    required this.varietyId,
    required this.accentColor,
    this.imageCount = 4,
  });

  /// Asset path for image at [index] (1-based).
  String _assetPath(int index) =>
      'assets/images/pods/${varietyId.toLowerCase()}_$index.jpg';


  @override
  Widget build(BuildContext context) {
    final images = List.generate(imageCount, (i) => _assetPath(i + 1));

    debugPrint('Generated Asset Paths for $varietyId: $images');

    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 2 × 2 grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 1.15,
            ),
            itemCount: images.length,
            itemBuilder: (context, index) {
              return _GalleryTile(
                assetPath: images[index],
                index: index,
                allPaths: images,
                accentColor: accentColor,
                varietyId: varietyId,
              );
            },
          ),
          const SizedBox(height: 10),
          Row(children: [
            Icon(Icons.touch_app_outlined,
                size: 13, color: KakaWiseTheme.textSecondary.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text(
              'Tap any photo to view full screen',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  color: KakaWiseTheme.textSecondary.withValues(alpha: 0.7)),
            ),
          ]),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Single thumbnail tile
// ─────────────────────────────────────────────────────────────────────────────

class _GalleryTile extends StatefulWidget {
  final String assetPath;
  final int index;
  final List<String> allPaths;
  final Color accentColor;
  final String varietyId;

  const _GalleryTile({
    required this.assetPath,
    required this.index,
    required this.allPaths,
    required this.accentColor,
    required this.varietyId,
  });

  @override
  State<_GalleryTile> createState() => _GalleryTileState();
}

class _GalleryTileState extends State<_GalleryTile>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pressCtrl;
  late final Animation<double> _scaleAnim;

  @override
  void initState() {
    super.initState();
    _pressCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
      reverseDuration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.94).animate(
      CurvedAnimation(parent: _pressCtrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pressCtrl.dispose();
    super.dispose();
  }

  void _open() {
    _pressCtrl.reverse();
    _PodLightbox.show(
      context: context,
      paths: widget.allPaths,
      initialIndex: widget.index,
      accentColor: widget.accentColor,
      varietyId: widget.varietyId,
    );
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _pressCtrl.forward(),
      onTapCancel: () => _pressCtrl.reverse(),
      onTap: _open,
      child: ScaleTransition(
        scale: _scaleAnim,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(fit: StackFit.expand, children: [
            // Image
            Image.asset(
              widget.assetPath,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _PlaceholderTile(
                color: widget.accentColor,
                index: widget.index + 1,
              ),
            ),
            // Subtle gradient + index badge
            Positioned(
              bottom: 0, left: 0, right: 0,
              child: Container(
                height: 32,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [
                      Colors.black.withValues(alpha: 0.45),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: 5, right: 7,
              child: Text(
                '${widget.index + 1}/${widget.allPaths.length}',
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: Colors.white70),
              ),
            ),
            // Expand icon on hover area (top-right)
            Positioned(
              top: 5, right: 5,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                    color: Colors.black38,
                    borderRadius: BorderRadius.circular(5)),
                child: const Icon(Icons.open_in_full_rounded,
                    size: 11, color: Colors.white70),
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Placeholder tile (when asset is missing)
// ─────────────────────────────────────────────────────────────────────────────

class _PlaceholderTile extends StatelessWidget {
  final Color color;
  final int index;
  const _PlaceholderTile({required this.color, required this.index});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: color.withValues(alpha: 0.08),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.image_outlined, size: 26, color: color.withValues(alpha: 0.4)),
          const SizedBox(height: 4),
          Text(
            'Photo $index',
            style: GoogleFonts.inter(
                fontSize: 11,
                color: color.withValues(alpha: 0.5),
                fontWeight: FontWeight.w500),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Lightbox dialog
// ─────────────────────────────────────────────────────────────────────────────

class _PodLightbox extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;
  final Color accentColor;
  final String varietyId;

  const _PodLightbox({
    required this.paths,
    required this.initialIndex,
    required this.accentColor,
    required this.varietyId,
  });

  static void show({
    required BuildContext context,
    required List<String> paths,
    required int initialIndex,
    required Color accentColor,
    required String varietyId,
  }) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Close lightbox',
      barrierColor: Colors.black87,
      transitionDuration: const Duration(milliseconds: 280),
      transitionBuilder: (_, anim, __, child) => FadeTransition(
        opacity: CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.92, end: 1.0).animate(
            CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      ),
      pageBuilder: (ctx, _, __) => _PodLightbox(
        paths: paths,
        initialIndex: initialIndex,
        accentColor: accentColor,
        varietyId: varietyId,
      ),
    );
  }

  @override
  State<_PodLightbox> createState() => _PodLightboxState();
}

class _PodLightboxState extends State<_PodLightbox>
    with SingleTickerProviderStateMixin {
  late final PageController _pageCtrl;
  late int _currentIndex;

  // Slide-indicator animation
  late final AnimationController _dotCtrl;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
    _dotCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    _dotCtrl.dispose();
    super.dispose();
  }

  void _onPageChanged(int index) {
    setState(() => _currentIndex = index);
    // Animate the dot indicator
    _dotCtrl.forward(from: 0);
  }

  void _goTo(int index) {
    _pageCtrl.animateToPage(
      index,
      duration: const Duration(milliseconds: 380),
      curve: Curves.easeInOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final canPrev = _currentIndex > 0;
    final canNext = _currentIndex < widget.paths.length - 1;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        // ── PageView ────────────────────────────────────────────────
        PageView.builder(
          controller: _pageCtrl,
          onPageChanged: _onPageChanged,
          itemCount: widget.paths.length,
          itemBuilder: (context, index) {
            return _LightboxPage(
              assetPath: widget.paths[index],
              accentColor: widget.accentColor,
              isActive: index == _currentIndex,
            );
          },
        ),

        // ── Top bar: close + title ───────────────────────────────────
        Positioned(
          top: 0, left: 0, right: 0,
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(children: [
                // Close button
                GestureDetector(
                  onTap: () => Navigator.pop(context),
                  child: Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.15)),
                    ),
                    child: const Icon(Icons.close_rounded,
                        color: Colors.white, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.varietyId,
                        style: GoogleFonts.inter(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: Colors.white),
                      ),
                      Text(
                        'Photo ${_currentIndex + 1} of ${widget.paths.length}',
                        style: GoogleFonts.inter(
                            fontSize: 11,
                            color: Colors.white60),
                      ),
                    ],
                  ),
                ),
              ]),
            ),
          ),
        ),

        // ── Left / Right arrow buttons ───────────────────────────────
        if (canPrev)
          Positioned(
            left: 12,
            top: size.height / 2 - 22,
            child: _ArrowButton(
              icon: Icons.chevron_left_rounded,
              onTap: () => _goTo(_currentIndex - 1),
            ),
          ),
        if (canNext)
          Positioned(
            right: 12,
            top: size.height / 2 - 22,
            child: _ArrowButton(
              icon: Icons.chevron_right_rounded,
              onTap: () => _goTo(_currentIndex + 1),
            ),
          ),

        // ── Dot indicator ────────────────────────────────────────────
        Positioned(
          bottom: 36,
          left: 0, right: 0,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(widget.paths.length, (i) {
              final isActive = i == _currentIndex;
              return AnimatedContainer(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeInOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3.5),
                width: isActive ? 20 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: isActive
                      ? widget.accentColor
                      : Colors.white.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(4),
                ),
              );
            }),
          ),
        ),

        // ── Swipe hint (fades after first swipe) ─────────────────────
        if (_currentIndex == widget.initialIndex && widget.paths.length > 1)
          Positioned(
            bottom: 68,
            left: 0, right: 0,
            child: Center(
              child: Container(
                padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                decoration: BoxDecoration(
                  color: Colors.black45,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.swipe_rounded,
                      size: 14, color: Colors.white70),
                  const SizedBox(width: 5),
                  Text('Swipe to browse',
                      style: GoogleFonts.inter(
                          fontSize: 11, color: Colors.white70)),
                ]),
              ),
            ),
          ),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Single page inside the lightbox
// ─────────────────────────────────────────────────────────────────────────────

class _LightboxPage extends StatelessWidget {
  final String assetPath;
  final Color accentColor;
  final bool isActive;

  const _LightboxPage({
    required this.assetPath,
    required this.accentColor,
    required this.isActive,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: isActive ? 1.0 : 0.96,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeOutCubic,
      child: Center(
        child: InteractiveViewer(
          minScale: 0.8,
          maxScale: 4.0,
          child: Image.asset(
            assetPath,
            fit: BoxFit.contain,
            errorBuilder: (_, __, ___) => Container(
              margin: const EdgeInsets.all(40),
              decoration: BoxDecoration(
                color: accentColor.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                    color: accentColor.withValues(alpha: 0.25)),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.image_not_supported_outlined,
                      size: 48,
                      color: accentColor.withValues(alpha: 0.4)),
                  const SizedBox(height: 12),
                  Text('Image not available',
                      style: GoogleFonts.inter(
                          fontSize: 14, color: Colors.white60)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Arrow nav button
// ─────────────────────────────────────────────────────────────────────────────

class _ArrowButton extends StatefulWidget {
  final IconData icon;
  final VoidCallback onTap;
  const _ArrowButton({required this.icon, required this.onTap});

  @override
  State<_ArrowButton> createState() => _ArrowButtonState();
}

class _ArrowButtonState extends State<_ArrowButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
      reverseDuration: const Duration(milliseconds: 180),
    );
    _scale = Tween<double>(begin: 1.0, end: 0.88)
        .animate(CurvedAnimation(parent: _ctrl, curve: Curves.easeIn));
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) {
        _ctrl.reverse();
        widget.onTap();
      },
      onTapCancel: () => _ctrl.reverse(),
      child: ScaleTransition(
        scale: _scale,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: Colors.black54,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
          ),
          child: Icon(widget.icon, color: Colors.white, size: 26),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
//  Local copy of _InfoCard (avoids cross-file private dependency)
// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: KakaWiseTheme.cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: KakaWiseTheme.border, width: 0.5),
      ),
      child: child,
    );
  }
}