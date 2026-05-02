import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme.dart';
import '../main.dart';

class IntroLoadingScreen extends StatefulWidget {
  const IntroLoadingScreen({super.key});

  @override
  State<IntroLoadingScreen> createState() => _IntroLoadingScreenState();
}

class _IntroLoadingScreenState extends State<IntroLoadingScreen> {
  @override
  void initState() {
    super.initState();
    _loadApp();
  }

  Future<void> _loadApp() async {
    final prefs = await SharedPreferences.getInstance();
    final tutorialDone = prefs.getBool('tutorial_done') ?? false;

    await Future.delayed(const Duration(milliseconds: 1800));

    if (!mounted) return;

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) =>
        tutorialDone ? const MainShell() : const TutorialGate(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: KakaWiseTheme.headerBg,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 92,
              height: 92,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Image.asset(
                'assets/images/kakawiselogo.png',
                fit: BoxFit.contain,
              ),
            ),

            const SizedBox(height: 24),

            Text(
              'KakaWise',
              style: GoogleFonts.dmSerifDisplay(
                fontSize: 38,
                color: Colors.white,
              ),
            ),

            const SizedBox(height: 8),

            Text(
              'The AI Innovation for Cacao Variety Classification',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: Colors.white.withValues(alpha: 0.72),
              ),
            ),

            const SizedBox(height: 34),

            const SizedBox(
              width: 28,
              height: 28,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                valueColor:
                AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
          ],
        ),
      ),
    );
  }
}