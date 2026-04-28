// lib/screens/result_screen.dart

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/cacao_variety.dart';
import '../models/detection_result.dart';
import '../theme.dart';

class ResultScreen extends StatelessWidget {
  final Uint8List renderedOverlayBytes;
  final InferenceResponse inferenceResponse;
  final CacaoVariety variety;

  const ResultScreen({
    super.key,
    required this.renderedOverlayBytes,
    required this.inferenceResponse,
    required this.variety,
  });

  @override
  Widget build(BuildContext context) {
    final color = Color(variety.colorHex);
    final top = inferenceResponse.topDetection!;

    return Scaffold(
      backgroundColor: KakaWiseTheme.surface,
      body: CustomScrollView(
        slivers: [
          // ── Hero: composited image with YOLO overlay ───────────────────
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: color,
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                      color: Colors.black26,
                      borderRadius: BorderRadius.circular(10)),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: Colors.white, size: 16),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(fit: StackFit.expand, children: [
                Image.memory(renderedOverlayBytes, fit: BoxFit.cover),
                // Bottom fade
                Positioned(
                  bottom: 0, left: 0, right: 0,
                  child: Container(
                    height: 90,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Colors.transparent, Colors.black.withValues(alpha: 0.6)],
                      ),
                    ),
                  ),
                ),
                const Positioned(
                  top: kToolbarHeight + 6, right: 12,
                  child: _Badge(label: 'YOLOv12 · On-device', dark: true),
                ),
                Positioned(
                  bottom: 10, left: 14,
                  child: Text(
                    '${inferenceResponse.detections.length} pod${inferenceResponse.detections.length != 1 ? 's' : ''} detected',
                    style: GoogleFonts.inter(fontSize: 12, color: Colors.white70),
                  ),
                ),
                Positioned(
                  bottom: 10, right: 12,
                  child: _Badge(
                    label: '${(top.confidence * 100).toStringAsFixed(1)}% match',
                    color: color,
                  ),
                ),
              ]),
            ),
          ),

          // ── Classification details ─────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Name + registration
                Text(variety.name,
                    style: GoogleFonts.inter(fontWeight: FontWeight.w700,
                        fontSize: 28, color: KakaWiseTheme.textPrimary)),
                const SizedBox(height: 2),
                Text(variety.registrationNo,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        color: KakaWiseTheme.textSecondary)),
                const SizedBox(height: 10),

                // Tags (only shown when non-empty)
                if (variety.tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: variety.tags.map((t) => _Tag(label: t, color: color)).toList(),
                  ),
                  const SizedBox(height: 18),
                ] else
                  const SizedBox(height: 8),

                // ── NSIC STATUS ────────────────────────────────────────
                _SectionHeader(label: 'NSIC STATUS', color: color),
                const SizedBox(height: 8),
                _NsicCard(variety: variety, color: color),
                const SizedBox(height: 16),

                // ── AVERAGE POD INDEX ──────────────────────────────────
                _SectionHeader(
                  label: 'AVERAGE POD INDEX (API)',
                  color: color,
                  tooltip:
                  'Average Pod Index (API) is the number of fresh cacao pods '
                      'needed to produce 1 kg of dry cacao beans. '
                      'A lower value indicates higher bean efficiency per pod.',
                ),
                const SizedBox(height: 8),
                _ApiCard(variety: variety, color: color),
                const SizedBox(height: 16),

                // ── POD MEASUREMENTS ──────────────────────────────────
                _SectionHeader(label: 'POD MEASUREMENTS', color: color),
                const SizedBox(height: 8),
                _PodMeasurementsCard(variety: variety, color: color),
                const SizedBox(height: 16),

                // ── LEAF MORPHOLOGY ───────────────────────────────────
                _SectionHeader(label: 'LEAF MORPHOLOGY', color: color),
                const SizedBox(height: 8),
                _TwoColCard(
                  items: [
                    ('Leaf Shape', variety.leafShape, Icons.eco_outlined),
                    ('Leaf Margin', variety.leafMargin, Icons.linear_scale_rounded),
                  ],
                  color: color,
                ),
                const SizedBox(height: 16),

                // ── DISEASE / PEST RESISTANCE ─────────────────────────
                _SectionHeader(label: 'DISEASE & PEST RESISTANCE', color: color),
                const SizedBox(height: 8),
                _ResistanceCard(variety: variety, color: color),
                const SizedBox(height: 16),

                // ── CHARACTERISTICS ────────────────────────────────────
                if (variety.characteristics.isNotEmpty) ...[
                  _SectionHeader(label: 'CHARACTERISTICS', color: color),
                  const SizedBox(height: 8),
                  _CharacteristicsCard(variety: variety, color: color),
                  const SizedBox(height: 16),
                ],

                // ── CONFIDENCE SCORES ──────────────────────────────────
                _SectionHeader(label: 'CONFIDENCE SCORES', color: color),
                const SizedBox(height: 8),
                _ConfidenceCard(
                  allConfidences: top.allConfidences,
                  topClassId: top.classId,
                ),
                const SizedBox(height: 16),

                // ── ABOUT ──────────────────────────────────────────────
                _SectionHeader(label: 'ABOUT THIS CLONE', color: color),
                const SizedBox(height: 8),
                _InfoCard(
                  child: Text(variety.description,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: KakaWiseTheme.textPrimary,
                          height: 1.6)),
                ),
                const SizedBox(height: 20),

                // Owner
                _InfoCard(
                  child: Row(children: [
                    const Icon(Icons.account_balance_outlined,
                        size: 16, color: KakaWiseTheme.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Text('Owner / Institution',
                            style: GoogleFonts.inter(
                                fontSize: 10, color: KakaWiseTheme.textSecondary)),
                        Text(variety.owner,
                            style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: KakaWiseTheme.textPrimary)),
                      ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 20),

                OutlinedButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.document_scanner_outlined, size: 18),
                  label: const Text('Scan another pod'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: KakaWiseTheme.primary,
                    side: const BorderSide(color: KakaWiseTheme.primary, width: 1),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    textStyle:
                    GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Section header with optional ? tooltip ───────────────────────────────────

class _SectionHeader extends StatelessWidget {
  final String label;
  final Color color;
  final String? tooltip;

  const _SectionHeader({required this.label, required this.color, this.tooltip});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Text(label,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: KakaWiseTheme.textSecondary,
              letterSpacing: 0.9)),
      if (tooltip != null) ...[
        const SizedBox(width: 5),
        GestureDetector(
          onTap: () => _showDialog(context),
          child: Icon(Icons.help_outline_rounded,
              size: 15, color: KakaWiseTheme.textSecondary.withValues(alpha: 0.6)),
        ),
      ],
    ]);
  }

  void _showDialog(BuildContext ctx) {
    // Use a custom page-route so we can control the fade transition duration.
    showGeneralDialog(
      context: ctx,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black54,
      // Fade in over 220 ms, fade out handled by Flutter automatically
      transitionDuration: const Duration(milliseconds: 220),
      transitionBuilder: (_, anim, __, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim, curve: Curves.easeInOut),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1.0).animate(
              CurvedAnimation(parent: anim, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
      pageBuilder: (dialogCtx, _, __) {
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 32),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: KakaWiseTheme.cardBg,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.12),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Average Pod Index (API)',
                      style: GoogleFonts.inter(fontWeight: FontWeight.w700,
                          fontSize: 18, color: KakaWiseTheme.textPrimary)),
                  const SizedBox(height: 10),
                  Text(tooltip!,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: KakaWiseTheme.textPrimary,
                          height: 1.6)),
                  const SizedBox(height: 18),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: () => Navigator.pop(dialogCtx),
                      style: TextButton.styleFrom(
                        foregroundColor: KakaWiseTheme.primary,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Got it',
                          style: GoogleFonts.inter(
                              fontWeight: FontWeight.w600,
                              color: KakaWiseTheme.primary)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─── NSIC card ────────────────────────────────────────────────────────────────

class _NsicCard extends StatelessWidget {
  final CacaoVariety variety;
  final Color color;
  const _NsicCard({required this.variety, required this.color});

  @override
  Widget build(BuildContext context) {
    final approved = variety.isApproved;
    final statusColor = approved ? const Color(0xFF2D7A2D) : const Color(0xFFA0522D);
    final statusBg   = approved ? const Color(0xFFE8F5E8) : const Color(0xFFFAEDE6);

    return _InfoCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          // Registration badge
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Registration No.',
                  style: GoogleFonts.inter(
                      fontSize: 9, color: KakaWiseTheme.textSecondary)),
              Text(variety.registrationNo,
                  style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: KakaWiseTheme.textPrimary)),
            ]),
          ),
          const SizedBox(width: 10),
          // Status pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: statusBg,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Icon(
                approved ? Icons.verified_rounded : Icons.cancel_outlined,
                size: 13,
                color: statusColor,
              ),
              const SizedBox(width: 4),
              Text(variety.nsicStatus,
                  style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: statusColor)),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          const Icon(Icons.account_balance_outlined,
              size: 14, color: KakaWiseTheme.textSecondary),
          const SizedBox(width: 6),
          Expanded(
            child: Text(variety.owner,
                style: GoogleFonts.inter(
                    fontSize: 12,
                    color: KakaWiseTheme.textSecondary)),
          ),
        ]),
      ]),
    );
  }
}

// ─── Average Pod Index card ────────────────────────────────────────────────────

class _ApiCard extends StatelessWidget {
  final CacaoVariety variety;
  final Color color;
  const _ApiCard({required this.variety, required this.color});

  @override
  Widget build(BuildContext context) {
    final hasData = variety.averagePodIndex > 0;
    // Lower is better: normalise so 10→full, 30→empty
    final normalized = hasData
        ? ((30 - variety.averagePodIndex) / 20).clamp(0.0, 1.0)
        : 0.0;

    return _InfoCard(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
          Text(
            hasData ? variety.averagePodIndex.toStringAsFixed(2) : 'N.A.',
            style: GoogleFonts.inter(fontWeight: FontWeight.w700,
                fontSize: 36, color: KakaWiseTheme.textPrimary),
          ),
          if (hasData) ...[
            const SizedBox(width: 8),
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('pods / kg dry beans',
                  style: GoogleFonts.inter(
                      fontSize: 11, color: KakaWiseTheme.textSecondary)),
            ),
          ],
        ]),
        if (hasData) ...[
          const SizedBox(height: 6),
          // Rating pill
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(variety.podIndexRating,
                style: GoogleFonts.inter(
                    fontSize: 10, fontWeight: FontWeight.w700, color: color)),
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: normalized,
              minHeight: 7,
              backgroundColor: KakaWiseTheme.border,
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          const SizedBox(height: 4),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('High (> 30 pods)',
                style: GoogleFonts.inter(
                    fontSize: 9, color: KakaWiseTheme.textSecondary)),
            Text('Good (< 15 pods)',
                style: GoogleFonts.inter(
                    fontSize: 9, color: KakaWiseTheme.textSecondary)),
          ]),
        ] else
          Text('No data available for this clone.',
              style: GoogleFonts.inter(
                  fontSize: 12, color: KakaWiseTheme.textSecondary)),
      ]),
    );
  }
}

// ─── Pod measurements card (length, width, pod colors) ────────────────────────

class _PodMeasurementsCard extends StatelessWidget {
  final CacaoVariety variety;
  final Color color;
  const _PodMeasurementsCard({required this.variety, required this.color});

  @override
  Widget build(BuildContext context) {
    final hasData = variety.averagePodLength > 0;

    return _InfoCard(
      child: Column(children: [
        // Length + Width as big numbers
        Row(children: [
          Expanded(child: _BigStat(
            label: 'Avg. Pod Length',
            value: hasData ? '${variety.averagePodLength.toStringAsFixed(2)} cm' : 'N.A.',
            color: color,
          )),
          Container(width: 0.5, height: 48, color: KakaWiseTheme.border),
          Expanded(child: _BigStat(
            label: 'Avg. Pod Width',
            value: hasData ? '${variety.averagePodWidth.toStringAsFixed(2)} cm' : 'N.A.',
            color: color,
          )),
        ]),
        const SizedBox(height: 12),
        const Divider(height: 1, thickness: 0.5, color: KakaWiseTheme.border),
        const SizedBox(height: 12),
        // Pod colors
        Row(children: [
          Expanded(child: _ColorChip(
            label: 'Young Pod Color',
            value: variety.youngPodColor,
            icon: Icons.circle_outlined,
            color: color,
          )),
          const SizedBox(width: 8),
          Expanded(child: _ColorChip(
            label: 'Mature Pod Color',
            value: variety.maturePodColor,
            icon: Icons.circle,
            color: color,
          )),
        ]),
      ]),
    );
  }
}

class _BigStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _BigStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10, color: KakaWiseTheme.textSecondary)),
        const SizedBox(height: 2),
        Text(value,
            style: GoogleFonts.inter(fontWeight: FontWeight.w700,
                fontSize: 20, color: KakaWiseTheme.textPrimary)),
      ]),
    );
  }
}

class _ColorChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;
  const _ColorChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.2), width: 0.5),
      ),
      child: Row(children: [
        Icon(icon, size: 14, color: color.withValues(alpha: 0.6)),
        const SizedBox(width: 6),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 9, color: KakaWiseTheme.textSecondary)),
            Text(value,
                style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: KakaWiseTheme.textPrimary),
                maxLines: 2,
                overflow: TextOverflow.ellipsis),
          ]),
        ),
      ]),
    );
  }
}

// ─── Two-column stat card (leaf morphology) ────────────────────────────────────

class _TwoColCard extends StatelessWidget {
  final List<(String, String, IconData)> items;
  final Color color;
  const _TwoColCard({required this.items, required this.color});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      child: Row(
        children: items.map((e) {
          final isLast = e == items.last;
          return Expanded(
            child: Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Icon(e.$3, size: 13, color: KakaWiseTheme.textSecondary),
                    const SizedBox(width: 5),
                    Text(e.$1,
                        style: GoogleFonts.inter(
                            fontSize: 10, color: KakaWiseTheme.textSecondary)),
                  ]),
                  const SizedBox(height: 3),
                  Text(e.$2,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: KakaWiseTheme.textPrimary)),
                ]),
              ),
              if (!isLast)
                Container(
                    width: 0.5, height: 36, color: KakaWiseTheme.border,
                    margin: const EdgeInsets.symmetric(horizontal: 8)),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Resistance card ──────────────────────────────────────────────────────────

class _ResistanceCard extends StatelessWidget {
  final CacaoVariety variety;
  final Color color;
  const _ResistanceCard({required this.variety, required this.color});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Pod Borer', variety.podBorerResistance),
      ('Dieback Borer', variety.diebackBorerResistance),
      ('Pod Rot', variety.podRotResistance),
    ];

    return _InfoCard(
      child: Column(
        children: rows.map((r) {
          final isLast = r == rows.last;
          return Column(children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Text(r.$1,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: KakaWiseTheme.textPrimary)),
              _ResistancePill(level: r.$2, fallbackColor: color),
            ]),
            if (!isLast) ...[
              const SizedBox(height: 8),
              const Divider(height: 1, thickness: 0.5, color: KakaWiseTheme.border),
              const SizedBox(height: 8),
            ],
          ]);
        }).toList(),
      ),
    );
  }
}

class _ResistancePill extends StatelessWidget {
  final String level;
  final Color fallbackColor;
  const _ResistancePill({required this.level, required this.fallbackColor});

  @override
  Widget build(BuildContext context) {
    Color bg;
    Color fg;

    switch (level.toLowerCase()) {
      case 'resistant':
        bg = const Color(0xFFE8F5E8); fg = const Color(0xFF2D7A2D);
      case 'moderately resistant':
        bg = const Color(0xFFFFF8E1); fg = const Color(0xFF8A6200);
      case 'tolerant':
        bg = const Color(0xFFE3F2FD); fg = const Color(0xFF0D47A1);
      case 'susceptible':
        bg = const Color(0xFFFCE8E8); fg = const Color(0xFFA32D2D);
      default:
        bg = KakaWiseTheme.surface; fg = KakaWiseTheme.textSecondary;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
          color: bg, borderRadius: BorderRadius.circular(20)),
      child: Text(level,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: fg)),
    );
  }
}

// ─── Characteristics bullet list ──────────────────────────────────────────────

class _CharacteristicsCard extends StatelessWidget {
  final CacaoVariety variety;
  final Color color;
  const _CharacteristicsCard({required this.variety, required this.color});

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: variety.characteristics.map((c) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 7),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(
                margin: const EdgeInsets.only(top: 5),
                width: 6,
                height: 6,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(c,
                    style: GoogleFonts.inter(
                        fontSize: 13,
                        color: KakaWiseTheme.textPrimary,
                        height: 1.5)),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Confidence scores ────────────────────────────────────────────────────────

class _ConfidenceCard extends StatelessWidget {
  final Map<String, double> allConfidences;
  final String topClassId;
  const _ConfidenceCard(
      {required this.allConfidences, required this.topClassId});

  @override
  Widget build(BuildContext context) {
    final sorted = allConfidences.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return _InfoCard(
      child: Column(
        children: sorted.map((e) {
          final v = getVarietyById(e.key);
          final barColor =
          v != null ? Color(v.colorHex) : KakaWiseTheme.primary;
          final isTop = e.key == topClassId;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  if (isTop)
                    Container(
                      margin: const EdgeInsets.only(right: 6),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 5, vertical: 1),
                      decoration: BoxDecoration(
                          color: barColor,
                          borderRadius: BorderRadius.circular(4)),
                      child: Text('TOP',
                          style: GoogleFonts.inter(
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              color: Colors.white)),
                    ),
                  Text(v?.name ?? e.key,
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight:
                          isTop ? FontWeight.w700 : FontWeight.w400,
                          color: KakaWiseTheme.textPrimary)),
                  const Spacer(),
                  Text('${(e.value * 100).toStringAsFixed(1)}%',
                      style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: isTop
                              ? barColor
                              : KakaWiseTheme.textSecondary)),
                ]),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: e.value,
                    minHeight: 6,
                    backgroundColor: KakaWiseTheme.border,
                    valueColor: AlwaysStoppedAnimation<Color>(
                        isTop ? barColor : barColor.withValues(alpha: 0.35)),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ─── Shared primitives ────────────────────────────────────────────────────────

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

class _Badge extends StatelessWidget {
  final String label;
  final Color? color;
  final bool dark;
  const _Badge({required this.label, this.color, this.dark = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
      decoration: BoxDecoration(
        color: dark ? Colors.black54 : color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: dark ? Colors.white70 : Colors.white)),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11, fontWeight: FontWeight.w600, color: color)),
    );
  }
}