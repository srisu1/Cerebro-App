/// 4 cute animated slides with thick borders, warm colors, bouncy icons.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cerebro_app/config/constants.dart';
import 'package:cerebro_app/config/theme.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  final List<_OnboardingSlide> _slides = const [
    _OnboardingSlide(
      icon: Icons.psychology_rounded,
      title: 'Welcome to\nCEREBRO',
      subtitle: 'Your Smart Student Companion',
      description:
          'The smart app that connects your studies, health, and daily life into one seamless experience.',
      color: CerebroTheme.pinkPop,
      bgAccent: CerebroTheme.pinkSoft,
    ),
    _OnboardingSlide(
      icon: Icons.auto_stories_rounded,
      title: 'Master Your\nStudies',
      subtitle: 'Smart Study Sessions & Flashcards',
      description:
          'Track your study time, create flashcards with spaced repetition, and watch your knowledge grow.',
      color: CerebroTheme.sky,
      bgAccent: Color(0xFFD6EFFE),
    ),
    _OnboardingSlide(
      icon: Icons.favorite_rounded,
      title: 'Track Your\nWellbeing',
      subtitle: 'Sleep, Mood & Health Insights',
      description:
          'Log your sleep, track moods, manage medications, and discover how your health affects your studies.',
      color: CerebroTheme.sage,
      bgAccent: Color(0xFFD4F0E0),
    ),
    _OnboardingSlide(
      icon: Icons.face_rounded,
      title: 'Meet Your\nCompanion',
      subtitle: 'Create Your Personal Avatar',
      description:
          'Customize a unique avatar that grows and evolves with you. Earn XP, unlock items, and level up!',
      color: CerebroTheme.gold,
      bgAccent: Color(0xFFFFF0C9),
    ),
  ];

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingCompleteKey, true);
    if (mounted) context.go('/register');
  }

  void _nextPage() {
    if (_currentPage < _slides.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    } else {
      _completeOnboarding();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final slide = _slides[_currentPage];

    return Scaffold(
      backgroundColor: CerebroTheme.cream,
      body: Stack(
        children: [
          PageView.builder(
            controller: _pageController,
            itemCount: _slides.length,
            onPageChanged: (index) => setState(() => _currentPage = index),
            itemBuilder: (context, index) => _buildSlide(_slides[index]),
          ),

          if (_currentPage < _slides.length - 1)
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              right: 24,
              child: GestureDetector(
                onTap: _completeOnboarding,
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border:
                        Border.all(color: CerebroTheme.outline, width: 2),
                    boxShadow: [CerebroTheme.shadow3DSmall],
                  ),
                  child: Text(
                    'Skip',
                    style: GoogleFonts.nunito(
                      color: CerebroTheme.brown,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ),

          Positioned(
            bottom: 60,
            left: 24,
            right: 24,
            child: Column(
              children: [
                // Dot indicators (cute chunky style)
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _slides.length,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      width: _currentPage == index ? 32 : 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: _currentPage == index
                            ? slide.color
                            : CerebroTheme.creamDark,
                        borderRadius: BorderRadius.circular(5),
                        border: Border.all(
                          color: _currentPage == index
                              ? CerebroTheme.outline
                              : CerebroTheme.creamDark,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),

                // Action button (Toca Boca chunky)
                _ChunkyButton(
                  onTap: _nextPage,
                  color: slide.color,
                  label: _currentPage == _slides.length - 1
                      ? 'Get Started'
                      : 'Next',
                ),

                // Login link on last slide
                if (_currentPage == _slides.length - 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: GestureDetector(
                      onTap: () async {
                        final prefs = await SharedPreferences.getInstance();
                        await prefs.setBool(
                            AppConstants.onboardingCompleteKey, true);
                        if (mounted) context.go('/login');
                      },
                      child: Text(
                        'Already have an account? Sign In',
                        style: GoogleFonts.nunito(
                          color: CerebroTheme.pinkPop,
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlide(_OnboardingSlide slide) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(height: 80),

          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: 1.0),
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
            builder: (context, value, child) {
              return Transform.scale(scale: value, child: child);
            },
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                color: slide.bgAccent,
                borderRadius: BorderRadius.circular(36),
                border: Border.all(color: CerebroTheme.outline, width: 5),
                boxShadow: [CerebroTheme.shadow3DLarge],
              ),
              child: Icon(slide.icon, size: 72, color: slide.color),
            ),
          ),

          const SizedBox(height: 40),

          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 32,
              fontWeight: FontWeight.w900,
              color: CerebroTheme.outline,
              height: 1.2,
            ),
          ),

          const SizedBox(height: 10),

          Text(
            slide.subtitle,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: slide.color,
            ),
          ),

          const SizedBox(height: 16),

          Text(
            slide.description,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 15,
              color: CerebroTheme.brown,
              height: 1.6,
              fontWeight: FontWeight.w600,
            ),
          ),

          const Spacer(),
        ],
      ),
    );
  }
}

class _OnboardingSlide {
  final IconData icon;
  final String title;
  final String subtitle;
  final String description;
  final Color color;
  final Color bgAccent;

  const _OnboardingSlide({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.color,
    required this.bgAccent,
  });
}

class _ChunkyButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color color;
  final String label;

  const _ChunkyButton({
    required this.onTap,
    required this.color,
    required this.label,
  });

  @override
  State<_ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<_ChunkyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: double.infinity,
        height: 56,
        transform: Matrix4.translationValues(0, _pressed ? 4 : 0, 0),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CerebroTheme.outline, width: 4),
          boxShadow: [
            if (!_pressed) CerebroTheme.shadow3D,
          ],
        ),
        child: Center(
          child: Text(
            widget.label,
            style: GoogleFonts.nunito(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
      ),
    );
  }
}
