// lib/screens/variety_detail_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/cacao_variety.dart';
import '../theme.dart';
import '../widgets/pod_image_gallery.dart';

class VarietyDetailScreen extends StatelessWidget {
  final CacaoVariety variety;
  const VarietyDetailScreen({super.key, required this.variety});

  @override
  Widget build(BuildContext context) {
    final color = variety.colorHex;

    return Scaffold(
      backgroundColor: KakaWiseTheme.surface,
      body: CustomScrollView(
        slivers: [
          // ── App bar ───────────────────────────────────────────────────
          SliverAppBar(
            pinned: true,
            expandedHeight: 170,
            backgroundColor: color.withValues(alpha: 0.12),
            leading: Padding(
              padding: const EdgeInsets.all(8),
              child: GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  decoration: BoxDecoration(
                      color: KakaWiseTheme.cardBg,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: KakaWiseTheme.border)),
                  child: const Icon(Icons.arrow_back_ios_new_rounded,
                      color: KakaWiseTheme.primary, size: 16),
                ),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: color.withValues(alpha: 0.1),
                padding: const EdgeInsets.fromLTRB(20, 80, 20, 16),
                child: Align(
                  alignment: Alignment.bottomLeft,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        width: 52,
                        height: 52,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: color.withValues(alpha: 0.4)),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.all(6),
                          child: Image.asset(
                            'assets/images/pods.png',
                            fit: BoxFit.contain,
                            errorBuilder: (_, __, ___) => Icon(
                              Icons.eco_rounded,
                              color: color,
                              size: 22,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(variety.name,
                              style: GoogleFonts.inter(fontWeight: FontWeight.w700,
                                  fontSize: 26,
                                  color: KakaWiseTheme.textPrimary)),
                          Text(variety.registrationNo,
                              style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: KakaWiseTheme.textSecondary)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── Body ─────────────────────────────────────────────────────
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([

                // Tags
                if (variety.tags.isNotEmpty) ...[
                  Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: variety.tags.map((t) {
                      return Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: color.withValues(alpha: 0.3), width: 0.5),
                        ),
                        child: Text(t,
                            style: GoogleFonts.inter(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: color)),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // ── NSIC STATUS ─────────────────────────────────────
                _label('NSIC STATUS'),
                const SizedBox(height: 6),
                _Card(child: _NsicRow(variety: variety, color: color)),
                const SizedBox(height: 14),

                // ── ABOUT ────────────────────────────────────────────
                _label('ABOUT'),
                const SizedBox(height: 6),
                _Card(
                  child: Text(variety.description,
                      style: GoogleFonts.inter(
                          fontSize: 13,
                          color: KakaWiseTheme.textPrimary,
                          height: 1.6)),
                ),
                const SizedBox(height: 14),

                // ── CHARACTERISTICS ─────────────────────────────────
                if (variety.characteristics.isNotEmpty) ...[
                  _label('CHARACTERISTICS'),
                  const SizedBox(height: 6),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: variety.characteristics.map((c) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 7),
                          child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  margin: const EdgeInsets.only(top: 5),
                                  width: 6,
                                  height: 6,
                                  decoration: BoxDecoration(
                                      color: color, shape: BoxShape.circle),
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
                  ),
                  const SizedBox(height: 14),
                ],

                // ── POD PHOTOS ─────────────────────────────────────
                _label('POD PHOTOS'),
                const SizedBox(height: 6),
                PodImageGallery(
                  varietyId: variety.id,
                  accentColor: color,
                ),
                const SizedBox(height: 14),

                // ── AVERAGE POD INDEX ───────────────────────────────
                _label('AVERAGE POD INDEX (API)'),
                const SizedBox(height: 6),
                _Card(child: _ApiRow(variety: variety, color: color)),
                const SizedBox(height: 14),

                // ── POD MEASUREMENTS ────────────────────────────────
                _label('POD MEASUREMENTS'),
                const SizedBox(height: 6),
                _Card(child: _PodMeasRow(variety: variety, color: color)),
                const SizedBox(height: 14),

                // ── LEAF MORPHOLOGY ─────────────────────────────────
                _label('LEAF MORPHOLOGY'),
                const SizedBox(height: 6),
                _Card(
                  child: Row(children: [
                    Expanded(child: _Stat('Leaf Shape', variety.leafShape)),
                    Container(width: 0.5, height: 36, color: KakaWiseTheme.border,
                        margin: const EdgeInsets.symmetric(horizontal: 8)),
                    Expanded(child: _Stat('Leaf Margin', variety.leafMargin)),
                  ]),
                ),
                const SizedBox(height: 14),

                // ── DISEASE & PEST RESISTANCE ───────────────────────
                _label('DISEASE & PEST RESISTANCE'),
                const SizedBox(height: 6),
                _Card(child: _ResistanceTable(variety: variety, color: color)),
                const SizedBox(height: 14),

                // ── OWNER ─────────────────────────────────────────────
                _Card(
                  child: Row(children: [
                    const Icon(Icons.account_balance_outlined,
                        size: 16, color: KakaWiseTheme.textSecondary),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Owner / Institution',
                                style: GoogleFonts.inter(
                                    fontSize: 10,
                                    color: KakaWiseTheme.textSecondary)),
                            Text(variety.owner,
                                style: GoogleFonts.inter(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: KakaWiseTheme.textPrimary)),
                          ]),
                    ),
                  ]),
                ),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _label(String text) => Text(text,
      style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: KakaWiseTheme.textSecondary,
          letterSpacing: 0.9));
}

// ─── NSIC row ─────────────────────────────────────────────────────────────────

class _NsicRow extends StatelessWidget {
  final CacaoVariety variety;
  final Color color;
  const _NsicRow({required this.variety, required this.color});

  @override
  Widget build(BuildContext context) {
    final approved = variety.isApproved;
    final statusColor = approved ? const Color(0xFF2D7A2D) : const Color(0xFFA0522D);
    final statusBg   = approved ? const Color(0xFFE8F5E8) : const Color(0xFFFAEDE6);

    return Row(children: [
      Icon(
        approved ? Icons.verified_rounded : Icons.cancel_outlined,
        size: 18, color: statusColor,
      ),
      const SizedBox(width: 8),
      Expanded(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(variety.registrationNo,
              style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: KakaWiseTheme.textPrimary)),
          Text('${variety.nsicStatus} · ${variety.owner}',
              style: GoogleFonts.inter(
                  fontSize: 11, color: KakaWiseTheme.textSecondary)),
        ]),
      ),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
        decoration: BoxDecoration(
            color: statusBg, borderRadius: BorderRadius.circular(20)),
        child: Text(variety.nsicStatus,
            style: GoogleFonts.inter(
                fontSize: 10, fontWeight: FontWeight.w700, color: statusColor)),
      ),
    ]);
  }
}

// ─── API row ──────────────────────────────────────────────────────────────────

class _ApiRow extends StatelessWidget {
  final CacaoVariety variety;
  final Color color;
  const _ApiRow({required this.variety, required this.color});

  @override
  Widget build(BuildContext context) {
    final hasData = variety.averagePodIndex > 0;
    return Row(children: [
      Text(
        hasData ? variety.averagePodIndex.toStringAsFixed(2) : 'N.A.',
        style: GoogleFonts.inter(fontWeight: FontWeight.w700,
            fontSize: 28, color: KakaWiseTheme.textPrimary),
      ),
      if (hasData) ...[
        const SizedBox(width: 10),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('pods / kg dry beans',
              style: GoogleFonts.inter(
                  fontSize: 11, color: KakaWiseTheme.textSecondary)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
            decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(20)),
            child: Text(variety.podIndexRating,
                style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: color)),
          ),
        ]),
      ] else
        Padding(
          padding: const EdgeInsets.only(left: 8),
          child: Text('No data available',
              style: GoogleFonts.inter(
                  fontSize: 12, color: KakaWiseTheme.textSecondary)),
        ),
    ]);
  }
}

// ─── Pod measurements row ─────────────────────────────────────────────────────

class _PodMeasRow extends StatelessWidget {
  final CacaoVariety variety;
  final Color color;
  const _PodMeasRow({required this.variety, required this.color});

  @override
  Widget build(BuildContext context) {
    final hasData = variety.averagePodLength > 0;
    return Column(children: [
      Row(children: [
        Expanded(child: _Stat('Avg. Length',
            hasData ? '${variety.averagePodLength.toStringAsFixed(2)} cm' : 'N.A.')),
        Container(width: 0.5, height: 36, color: KakaWiseTheme.border,
            margin: const EdgeInsets.symmetric(horizontal: 8)),
        Expanded(child: _Stat('Avg. Width',
            hasData ? '${variety.averagePodWidth.toStringAsFixed(2)} cm' : 'N.A.')),
      ]),
      const SizedBox(height: 10),
      const Divider(height: 1, thickness: 0.5, color: KakaWiseTheme.border),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: _Stat('Young Pod Color', variety.youngPodColor)),
        Container(width: 0.5, height: 36, color: KakaWiseTheme.border,
            margin: const EdgeInsets.symmetric(horizontal: 8)),
        Expanded(child: _Stat('Mature Pod Color', variety.maturePodColor)),
      ]),
    ]);
  }
}

// ─── Resistance table ─────────────────────────────────────────────────────────

class _ResistanceTable extends StatelessWidget {
  final CacaoVariety variety;
  final Color color;
  const _ResistanceTable({required this.variety, required this.color});

  @override
  Widget build(BuildContext context) {
    final rows = [
      ('Pod Borer', variety.podBorerResistance),
      ('Dieback', variety.diebackResistance),
      ('Pod Rot', variety.podRotResistance),
    ];
    return Column(
      children: rows.map((r) {
        final isLast = r == rows.last;
        return Column(children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text(r.$1,
                style: GoogleFonts.inter(
                    fontSize: 13, color: KakaWiseTheme.textPrimary)),
            _Pill(level: r.$2),
          ]),
          if (!isLast) ...[
            const SizedBox(height: 8),
            const Divider(height: 1, thickness: 0.5, color: KakaWiseTheme.border),
            const SizedBox(height: 8),
          ],
        ]);
      }).toList(),
    );
  }
}

class _Pill extends StatelessWidget {
  final String level;
  const _Pill({required this.level});

  @override
  Widget build(BuildContext context) {
    Color bg; Color fg;
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

// ─── Shared primitives ────────────────────────────────────────────────────────

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

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

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(label,
          style: GoogleFonts.inter(
              fontSize: 10, color: KakaWiseTheme.textSecondary)),
      const SizedBox(height: 2),
      Text(value,
          style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: KakaWiseTheme.textPrimary),
          maxLines: 2,
          overflow: TextOverflow.ellipsis),
    ]);
  }
}