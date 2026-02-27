import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cerebro_app/config/theme.dart';

class DailyTab extends StatelessWidget {
  const DailyTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CerebroTheme.cream,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.today_rounded, size: 56, color: const Color(0xFFFF8C6B)),
              const SizedBox(height: 16),
              Text(
                'Daily',
                style: GoogleFonts.nunito(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: CerebroTheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Habits and daily tasks coming soon.',
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
