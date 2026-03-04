import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cerebro_app/config/theme.dart';

class StudyTab extends StatelessWidget {
  const StudyTab({super.key});

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
                'Study',
                style: GoogleFonts.nunito(
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  color: CerebroTheme.outline,
                ),
              ),
              const SizedBox(height: 24),

              // subjects button
              _StudyAction(
                icon: Icons.library_books_rounded,
                label: 'My Subjects',
                subtitle: 'Manage your courses',
                color: const Color(0xFF5BADF0),
                onTap: () => context.push('/study/subjects'),
              ),
              const SizedBox(height: 12),

              // study session
              _StudyAction(
                icon: Icons.timer_rounded,
                label: 'Study Session',
                subtitle: 'Focus timer with Pomodoro',
                color: const Color(0xFFFF8C6B),
                onTap: () => context.push('/study/session'),
              ),
              const SizedBox(height: 12),

              // flashcards
              _StudyAction(
                icon: Icons.style_rounded,
                label: 'Flashcards',
                subtitle: 'Review and create cards',
                color: const Color(0xFFA8D5A3),
                onTap: () => context.push('/study/flashcards'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StudyAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _StudyAction({
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
