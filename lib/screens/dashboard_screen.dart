// lib/screens/dashboard_screen.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/cacao_variety.dart';
import '../theme.dart';
import 'variety_detail_screen.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // No header here — it lives in _MainShell in main.dart (sticky, always visible)
    return Scaffold(
      backgroundColor: KakaWiseTheme.surface,
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Subtitle — item 3: removed "Philippine NSIC Registered Clones"
          Text('Cacao clone varieties detectable by KakaWise',
              style: GoogleFonts.inter(
                  fontSize: 13, color: KakaWiseTheme.textSecondary)),
          const SizedBox(height: 14),

          // Stats row
          Row(children: [
            _StatChip(
                label: 'Clones',
                value: '${cacaoVarieties.length}',
                icon: Icons.eco_outlined),
            const SizedBox(width: 8),
            _StatChip(
                label: 'Detectable',
                value: '${cacaoVarieties.length}',
                icon: Icons.document_scanner_outlined),
            const SizedBox(width: 8),
            const _StatChip(
                label: 'On-device AI',
                value: 'Active',
                icon: Icons.offline_bolt_outlined),
          ]),
          const SizedBox(height: 20),

          Text('CACAO CLONES',
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: KakaWiseTheme.textSecondary,
                  letterSpacing: 1.0)),
          const SizedBox(height: 10),

          ...cacaoVarieties.map((v) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _VarietyCard(variety: v),
          )),

          const SizedBox(height: 16),
          const _PoweredByStrip(),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ─── Powered-by strip ─────────────────────────────────────────────────────────

class _PoweredByStrip extends StatelessWidget {
  const _PoweredByStrip();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: KakaWiseTheme.cardBg,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: KakaWiseTheme.border, width: 0.5),
      ),
      child: Row(children: [
        Container(
          width: 30, height: 30,
          decoration: BoxDecoration(
              color: const Color(0xFF1F2937),
              borderRadius: BorderRadius.circular(8)),
          child: const Icon(Icons.memory_rounded, color: Colors.white, size: 16),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Powered by Ultralytics YOLOv12',
                style: GoogleFonts.inter(
                    fontSize: 12, fontWeight: FontWeight.w600,
                    color: KakaWiseTheme.textPrimary)),
            Text('On-device segmentation · No internet required',
                style: GoogleFonts.inter(
                    fontSize: 10, color: KakaWiseTheme.textSecondary)),
          ]),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
              color: KakaWiseTheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(20)),
          child: Text('v12',
              style: GoogleFonts.inter(
                  fontSize: 10, fontWeight: FontWeight.w700,
                  color: KakaWiseTheme.primary)),
        ),
      ]),
    );
  }
}

// ─── Stat chip ────────────────────────────────────────────────────────────────

class _StatChip extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  const _StatChip({required this.label, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 10),
        decoration: BoxDecoration(
          color: KakaWiseTheme.cardBg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: KakaWiseTheme.border, width: 0.5),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Icon(icon, size: 16, color: KakaWiseTheme.primary),
          const SizedBox(height: 6),
          Text(value,
              style: GoogleFonts.inter(
                  fontSize: 16, fontWeight: FontWeight.w700,
                  color: KakaWiseTheme.textPrimary)),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 10, color: KakaWiseTheme.textSecondary)),
        ]),
      ),
    );
  }
}

// ─── Variety card ─────────────────────────────────────────────────────────────

class _VarietyCard extends StatelessWidget {
  final CacaoVariety variety;
  const _VarietyCard({required this.variety});

  @override
  Widget build(BuildContext context) {
    final color = Color(variety.colorHex);

    return GestureDetector(
      onTap: () => Navigator.push(context,
          MaterialPageRoute(builder: (_) => VarietyDetailScreen(variety: variety))),
      child: Container(
        decoration: BoxDecoration(
          color: KakaWiseTheme.cardBg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: KakaWiseTheme.border, width: 0.5),
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Banner
          Container(
            height: 76,
            color: color.withValues(alpha: 0.12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            child: Row(children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: color.withValues(alpha: 0.4), width: 1),
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
              Expanded(
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(variety.name,
                          style: GoogleFonts.inter(
                              fontSize: 18, fontWeight: FontWeight.w700,
                              color: KakaWiseTheme.textPrimary)),
                      Text(variety.registrationNo,
                          style: GoogleFonts.inter(
                              fontSize: 10, color: KakaWiseTheme.textSecondary)),
                    ]),
              ),
              _NsicBadge(approved: variety.isApproved),
              const SizedBox(width: 4),
              const Icon(Icons.chevron_right_rounded, color: KakaWiseTheme.textSecondary),
            ]),
          ),

          // Body
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(variety.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                      fontSize: 12, color: KakaWiseTheme.textSecondary, height: 1.5)),
              const SizedBox(height: 8),
              Row(children: [
                _QuickStat(
                    icon: Icons.straighten_rounded,
                    label: 'Length',
                    value: variety.averagePodLength > 0
                        ? '${variety.averagePodLength.toStringAsFixed(1)} cm'
                        : 'N.A.'),
                const SizedBox(width: 12),
                _QuickStat(
                    icon: Icons.swap_horiz_rounded,
                    label: 'Width',
                    value: variety.averagePodWidth > 0
                        ? '${variety.averagePodWidth.toStringAsFixed(1)} cm'
                        : 'N.A.'),
                const SizedBox(width: 12),
                _QuickStat(
                    icon: Icons.bar_chart_rounded,
                    label: 'API',
                    value: variety.averagePodIndex > 0
                        ? variety.averagePodIndex.toStringAsFixed(1)
                        : 'N.A.'),
              ]),
              const SizedBox(height: 8),
              if (variety.tags.isNotEmpty)
                Wrap(
                  spacing: 6, runSpacing: 4,
                  children: variety.tags.map((tag) => Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: color.withValues(alpha: 0.3), width: 0.5),
                    ),
                    child: Text(tag,
                        style: GoogleFonts.inter(
                            fontSize: 10, fontWeight: FontWeight.w600,
                            color: color.withValues(alpha: 0.9))),
                  )).toList(),
                ),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _NsicBadge extends StatelessWidget {
  final bool approved;
  const _NsicBadge({required this.approved});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: approved ? const Color(0xFFE8F5E8) : const Color(0xFFFAEDE6),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(
          approved ? Icons.verified_rounded : Icons.cancel_outlined,
          size: 11,
          color: approved ? const Color(0xFF2D7A2D) : const Color(0xFFA0522D),
        ),
        const SizedBox(width: 3),
        Text(
          approved ? 'NSIC' : 'Unregistered',
          style: GoogleFonts.inter(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: approved ? const Color(0xFF2D7A2D) : const Color(0xFFA0522D)),
        ),
      ]),
    );
  }
}

class _QuickStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _QuickStat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(icon, size: 12, color: KakaWiseTheme.textSecondary),
      const SizedBox(width: 4),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: GoogleFonts.inter(fontSize: 8, color: KakaWiseTheme.textSecondary)),
        Text(value, style: GoogleFonts.inter(
            fontSize: 11, fontWeight: FontWeight.w600, color: KakaWiseTheme.textPrimary)),
      ]),
    ]);
  }
}