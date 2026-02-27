import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cerebro_app/config/theme.dart';

class HealthTab extends StatelessWidget {
  const HealthTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CerebroTheme.cream,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.favorite_rounded, size: 56, color: const Color(0xFF6BBF7A)),
              const SizedBox(height: 16),
              Text(
                'Health',
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: CerebroTheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Sleep, mood, and wellness tracking coming soon.',
                style: GoogleFonts.nunito(
                  fontSize: 14,
                  color: CerebroTheme.brown,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
