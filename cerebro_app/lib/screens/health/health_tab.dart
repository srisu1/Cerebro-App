import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cerebro_app/config/theme.dart';

class HealthTab extends StatelessWidget {
  const HealthTab({super.key});

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
                'Health',
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: CerebroTheme.outline,
                ),
              ),
              const SizedBox(height: 24),

              // sleep tracking
              _HealthAction(
                icon: Icons.bedtime_rounded,
                label: 'Sleep',
                subtitle: 'Track your sleep patterns',
                color: const Color(0xFF7C83FD),
                onTap: () => context.push('/health/sleep'),
              ),
              const SizedBox(height: 12),

              // mood
              _HealthAction(
                icon: Icons.emoji_emotions_rounded,
                label: 'Mood',
                subtitle: 'Log how you feel',
                color: const Color(0xFFFFB347),
                onTap: () {},
              ),
              const SizedBox(height: 12),

              // water intake
              _HealthAction(
                icon: Icons.water_drop_rounded,
                label: 'Water',
                subtitle: 'Stay hydrated',
                color: const Color(0xFF5BADF0),
                onTap: () {},
              ),
              const SizedBox(height: 12),

              // medications
              _HealthAction(
                icon: Icons.medication_rounded,
                label: 'Medications',
                subtitle: 'Track your meds',
                color: const Color(0xFF6BBF7A),
                onTap: () {},
              ),
              const SizedBox(height: 12),

              // symptoms
              _HealthAction(
                icon: Icons.monitor_heart_rounded,
                label: 'Symptoms',
                subtitle: 'Log symptoms and triggers',
                color: const Color(0xFFFF8C6B),
                onTap: () {},
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HealthAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _HealthAction({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CerebroTheme.outline, width: 2.5),
          boxShadow: [CerebroTheme.shadow3DSmall],
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: CerebroTheme.outline,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: CerebroTheme.brown,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded,
              color: CerebroTheme.brown.withOpacity(0.3)),
          ],
        ),
      ),
    );
  }
}
