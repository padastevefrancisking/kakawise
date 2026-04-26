// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/dashboard_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/tutorial_screen.dart';
import 'services/yolo_service.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  // Set status-bar icons to light (white) to contrast with dark green header
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  // Uncomment once model is in assets/models/
  // await YoloService.loadModel();

  final prefs = await SharedPreferences.getInstance();
  final tutorialDone = prefs.getBool('tutorial_done') ?? false;

  runApp(KakaWiseApp(showTutorial: !tutorialDone));
}

class KakaWiseApp extends StatelessWidget {
  final bool showTutorial;
  const KakaWiseApp({super.key, required this.showTutorial});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KakaWise',
      debugShowCheckedModeBanner: false,
      theme: KakaWiseTheme.theme,
      home: showTutorial ? const _TutorialGate() : const _MainShell(),
    );
  }
}

class _TutorialGate extends StatefulWidget {
  const _TutorialGate();
  @override
  State<_TutorialGate> createState() => _TutorialGateState();
}

class _TutorialGateState extends State<_TutorialGate> {
  bool _done = false;
  @override
  Widget build(BuildContext context) {
    if (_done) return const _MainShell();
    return TutorialScreen(onDone: () => setState(() => _done = true));
  }
}

// ── Main shell — header lives HERE, shared across both tabs ──────────────────
// This is the fix for items 1 & 2: the header is part of the shell, not
// inside each screen, so it is always visible, always the same colour, and
// never moves when switching tabs or scrolling.

class _MainShell extends StatefulWidget {
  const _MainShell();
  @override
  State<_MainShell> createState() => _MainShellState();
}

class _MainShellState extends State<_MainShell> {
  int _idx = 0;

  static const _labels = ['Varieties', 'Scan Pod'];

  static const _screens = <Widget>[
    DashboardScreen(),
    ScanScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KakaWiseTheme.surface,
      body: Column(
        children: [
          // ── Persistent green header — never moves ───────────────────────
          _AppHeader(tabIndex: _idx),

          // ── Screen content ───────────────────────────────────────────────
          Expanded(
            child: IndexedStack(index: _idx, children: _screens),
          ),
        ],
      ),
      bottomNavigationBar: _NavBar(
        current: _idx,
        onTap: (i) => setState(() => _idx = i),
      ),
    );
  }
}

// ── App header (green, always pinned) ────────────────────────────────────────

class _AppHeader extends StatelessWidget {
  final int tabIndex;
  const _AppHeader({required this.tabIndex});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      color: KakaWiseTheme.headerBg,
      padding: EdgeInsets.fromLTRB(16, topPad + 10, 16, 12),
      child: Row(children: [
        // Logo icon
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(9),
          ),
          child: const Icon(Icons.eco_rounded, color: Colors.white, size: 19),
        ),
        const SizedBox(width: 10),
        // App name — always DM Serif Display per the original design intent
        Text('KakaWise',
            style: GoogleFonts.dmSerifDisplay(
                fontSize: 24,
                color: KakaWiseTheme.headerText,
                letterSpacing: -0.2)),
        const Spacer(),
        // Subtle tab indicator in header
        _HeaderTabPill(label: tabIndex == 0 ? 'Varieties' : 'Scan Pod'),
      ]),
    );
  }
}

class _HeaderTabPill extends StatelessWidget {
  final String label;
  const _HeaderTabPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: GoogleFonts.inter(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: KakaWiseTheme.headerSub)),
    );
  }
}

// ── Bottom nav bar ────────────────────────────────────────────────────────────

class _NavBar extends StatelessWidget {
  final int current;
  final ValueChanged<int> onTap;
  const _NavBar({required this.current, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: KakaWiseTheme.cardBg,
        border: const Border(
            top: BorderSide(color: KakaWiseTheme.border, width: 0.5)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 12,
              offset: const Offset(0, -2)),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(children: [
            _NavItem(
              icon: Icons.grid_view_rounded,
              label: 'Varieties',
              active: current == 0,
              onTap: () => onTap(0),
            ),
            _NavItem(
              icon: Icons.document_scanner_rounded,
              label: 'Scan Pod',
              active: current == 1,
              onTap: () => onTap(1),
              isPrimary: true,
            ),
          ]),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool active;
  final bool isPrimary;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? KakaWiseTheme.primary : const Color(0xFFADA8A0);

    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          isPrimary && active
              ? Container(
            width: 52,
            height: 34,
            decoration: BoxDecoration(
              color: KakaWiseTheme.primary,
              borderRadius: BorderRadius.circular(17),
            ),
            child: Icon(icon, color: Colors.white, size: 20),
          )
              : Icon(icon, color: color, size: 24),
          const SizedBox(height: 3),
          Text(label,
              style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                  color: color)),
        ]),
      ),
    );
  }
}