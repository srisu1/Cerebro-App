import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cerebro_app/config/theme.dart';

class DashboardTab extends StatelessWidget {
  const DashboardTab({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CerebroTheme.cream,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              Text(
                'Dashboard',
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: CerebroTheme.outline,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Welcome back!',
                style: GoogleFonts.nunito(
                  fontSize: 16,
                  color: CerebroTheme.brown,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 32),
              // TODO: xp bar, streak counter, today's stats
              Expanded(
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: CerebroTheme.outline, width: 3),
                      boxShadow: [CerebroTheme.shadow3D],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.construction_rounded,
                          size: 48,
                          color: CerebroTheme.gold,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Coming soon',
                          style: GoogleFonts.nunito(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: CerebroTheme.outline,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Stats, XP tracking, and daily overview\nwill live here.',
                          textAlign: TextAlign.center,
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
              ),
            ],
          ),
        ),
      ),
    );
  }
}
