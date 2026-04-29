// lib/main.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:kakawise/screens/intro_loading_screen.dart';

import 'screens/dashboard_screen.dart';
import 'screens/scan_screen.dart';
import 'screens/tutorial_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
  ));

  runApp(const KakaWiseApp());
}

class KakaWiseApp extends StatelessWidget {
  const KakaWiseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KakaWise',
      debugShowCheckedModeBanner: false,
      theme: KakaWiseTheme.theme,
      home: const IntroLoadingScreen(),
    );
  }
}

class TutorialGate extends StatefulWidget {
  const TutorialGate({super.key});
  @override
  State<TutorialGate> createState() => TutorialGateState();
}

class TutorialGateState extends State<TutorialGate> {
  bool _done = false;
  @override
  Widget build(BuildContext context) {
    if (_done) return const MainShell();
    return TutorialScreen(onDone: () => setState(() => _done = true));
  }
}

// ── Main shell ────────────────────────────────────────────────────────────────

class MainShell extends StatefulWidget {
  const MainShell({super.key});
  @override
  State<MainShell> createState() => MainShellState();
}

class MainShellState extends State<MainShell> {
  int _idx = 0;

  static const _screens = <Widget>[
    DashboardScreen(),
    ScanScreen(),
  ];

  void _showTutorial() {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => TutorialScreen(
          onDone: () => Navigator.pop(context),
        ),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
        transitionDuration: const Duration(milliseconds: 260),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KakaWiseTheme.surface,
      body: Column(
        children: [
          // ── Persistent green header ─────────────────────────────────────
          _AppHeader(onHelpTap: _showTutorial),
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

// ── App header ────────────────────────────────────────────────────────────────

class _AppHeader extends StatelessWidget {
  final VoidCallback onHelpTap;
  const _AppHeader({required this.onHelpTap});

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.of(context).padding.top;
    return Container(
      color: KakaWiseTheme.headerBg,
      padding: EdgeInsets.fromLTRB(16, topPad + 10, 12, 12),
      child: Row(children: [
        // Logo icon
        Container(
          width: 34,
          height: 34,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(9),
          ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 1,
                  vertical: 3,
                ),
                child: Image.asset(
                  'assets/images/kakawiselogo.png',
                  fit: BoxFit.contain,
                  errorBuilder: (_, __, ___) => const Icon(
                    Icons.eco_rounded,
                    color: Colors.white,
                    size: 19,
                  ),
                ),
              ),
            ),
        ),
        const SizedBox(width: 10),
        // App name
        Text(
          'KakaWise',
          style: GoogleFonts.dmSerifDisplay(
              fontSize: 24,
              color: KakaWiseTheme.headerText,
              letterSpacing: -0.2),
        ),
        const Spacer(),
        // ? help button — opens tutorial
        GestureDetector(
          onTap: onHelpTap,
          child: Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.info_outline_rounded,
              color: KakaWiseTheme.headerSub,
              size: 19,
            ),
          ),
        ),
      ]),
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
              color: Colors.black.withValues(alpha: 0.06),
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