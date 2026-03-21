/// Pixel-matched to ui-prototype/onboarding.html:
///   • Olive (#98a869) background with diamond checkerboard pattern
///   • White "game-card" with thick dark border + hard box-shadow
///   • 3 slides: Master Your Studies, Track Your Wellbeing, Meet Your Companion
///   • Each slide: gradient illustration area (top) + content area (bottom)
///   • Nav row: Skip button (green-pale), dots, Next/Get Started button (pink)
///   • Slide transition: slideIn (translateX 60→0), slideOut (translateX 0→-60)

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cerebro_app/config/constants.dart';
import 'package:cerebro_app/config/theme.dart';

//  SLIDE DATA
class _SlideData {
  final String svgAsset;
  final String title;
  final String description;
  const _SlideData({
    required this.svgAsset,
    required this.title,
    required this.description,
  });
}

const _slides = [
  _SlideData(
    svgAsset: 'assets/illustrations/onboarding_1.svg',
    title: 'Master Your Studies',
    description:
        'Team up with smart tools that adapt to your learning style. Flashcards, summaries, and study plans — all in one place.',
  ),
  _SlideData(
    svgAsset: 'assets/illustrations/onboarding_2.svg',
    title: 'Track Your Wellbeing',
    description:
        'Balance is everything. Log your mood, track your energy, and get gentle nudges to take care of yourself along the way.',
  ),
  _SlideData(
    svgAsset: 'assets/illustrations/onboarding_3.svg',
    title: 'Meet Your Companion',
    description:
        'Your personal AI buddy that learns with you, celebrates your wins, and keeps you company through late-night study sessions.',
  ),
];

//  ONBOARDING SCREEN
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});
  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  int _current = 0;
  int? _previous;
  bool _animating = false;

  // Card pop-in animation (matches CSS: cardPop .6s cubic-bezier(.34,1.4,.64,1))
  late final AnimationController _cardAc;
  late final Animation<double> _cardScale, _cardFade, _cardSlide;

  // Slide transition animation
  late final AnimationController _slideAc;

  @override
  void initState() {
    super.initState();

    _cardAc = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _cardScale = Tween(begin: 0.96, end: 1.0).animate(
        CurvedAnimation(parent: _cardAc, curve: Curves.elasticOut));
    _cardFade = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _cardAc, curve: const Interval(0.0, 0.5)));
    _cardSlide = Tween(begin: 16.0, end: 0.0).animate(
        CurvedAnimation(parent: _cardAc, curve: Curves.easeOut));

    _slideAc = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _slideAc.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        setState(() {
          _previous = null;
          _animating = false;
        });
        _slideAc.reset();
      }
    });
  }

  @override
  void dispose() {
    _cardAc.dispose();
    _slideAc.dispose();
    super.dispose();
  }

  void _goToSlide(int index) {
    if (_animating || index == _current) return;
    setState(() {
      _previous = _current;
      _current = index;
      _animating = true;
    });
    _slideAc.forward(from: 0);
  }

  void _next() {
    if (_current < _slides.length - 1) {
      _goToSlide(_current + 1);
    } else {
      _completeOnboarding();
    }
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(AppConstants.onboardingCompleteKey, true);
    if (mounted) context.go('/login');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CerebroTheme.olive,
      body: Stack(
        children: [
          Positioned.fill(child: _DiamondPattern()),

          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 48, 36, 28),
              child: AnimatedBuilder(
                animation: _cardAc,
                builder: (ctx, _) => Opacity(
                  opacity: _cardFade.value.clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(0, _cardSlide.value),
                    child: Transform.scale(
                      scale: _cardScale.value.clamp(0.96, 1.0),
                      child: Center(
                        child: Container(
                          width: double.infinity,
                          height: double.infinity,
                          constraints: const BoxConstraints(maxWidth: 1400),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(
                                color: CerebroTheme.text1, width: 3),
                            boxShadow: [
                              BoxShadow(
                                  color: CerebroTheme.text1.withOpacity(0.5),
                                  offset: const Offset(8, 8),
                                  blurRadius: 0),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(21),
                            child: _cardContent(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  //  CARD CONTENT (slides with animation)
  Widget _cardContent() {
    return AnimatedBuilder(
      animation: _slideAc,
      builder: (ctx, _) {
        return Stack(
          children: [
            // Previous slide (exiting: translateX 0 → -60)
            if (_previous != null)
              Positioned.fill(
                child: Opacity(
                  opacity: (1.0 - _slideAc.value).clamp(0.0, 1.0),
                  child: Transform.translate(
                    offset: Offset(-60 * _slideAc.value, 0),
                    child: _slideWidget(_slides[_previous!]),
                  ),
                ),
              ),

            // Current slide (entering: translateX 60 → 0)
            Positioned.fill(
              child: _previous != null
                  ? Opacity(
                      opacity: _slideAc.value.clamp(0.0, 1.0),
                      child: Transform.translate(
                        offset: Offset(60 * (1 - _slideAc.value), 0),
                        child: _slideWidget(_slides[_current]),
                      ),
                    )
                  : _slideWidget(_slides[_current]),
            ),
          ],
        );
      },
    );
  }

  //  SINGLE SLIDE
  Widget _slideWidget(_SlideData slide) {
    return Column(
      children: [
        Expanded(child: _illustrationArea(slide)),

        Container(height: 3, color: CerebroTheme.text1),

        _contentArea(slide),
      ],
    );
  }

  Widget _illustrationArea(_SlideData slide) {
    return Stack(
      children: [
        // Gradient background (matches CSS: linear-gradient(160deg, cream, green-pale, pink-light))
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment(-0.6, -0.8),
                end: Alignment(0.6, 0.8),
                stops: [0.0, 0.4, 1.0],
                colors: [
                  CerebroTheme.creamWarm,
                  CerebroTheme.greenPale,
                  CerebroTheme.pinkLight,
                ],
              ),
            ),
          ),
        ),

        // SVG illustration (centered, 82% width, min 720px)
        Center(
          child: OverflowBox(
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: SizedBox(
              width: 900,
              height: 680,
              child: SvgPicture.asset(
                slide.svgAsset,
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _contentArea(_SlideData slide) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(40, 26, 40, 26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            slide.title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontFamily: 'Bitroad',
              fontSize: 35,
              color: CerebroTheme.text1,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 6),

          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            child: Text(
              slide.description,
              textAlign: TextAlign.center,
              style: GoogleFonts.nunito(
                fontSize: 14,
                color: CerebroTheme.text2,
                height: 1.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 16),

          _navRow(),
        ],
      ),
    );
  }

  //  NAVIGATION ROW
  Widget _navRow() {
    final isLast = _current == _slides.length - 1;

    return SizedBox(
      width: double.infinity,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _GameBtn(
              label: 'Skip',
              color: CerebroTheme.greenPale,
              textColor: CerebroTheme.text1,
              onTap: _completeOnboarding,
            ),

            Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(_slides.length, (i) {
                final active = i == _current;
                return GestureDetector(
                  onTap: () => _goToSlide(i),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 250),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    width: active ? 28 : 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: active
                          ? CerebroTheme.pinkAccent
                          : CerebroTheme.greenPale,
                      borderRadius: BorderRadius.circular(active ? 8 : 5),
                      border: Border.all(
                          color: CerebroTheme.text1, width: 2.5),
                    ),
                  ),
                );
              }),
            ),

            _GameBtn(
              label: isLast ? 'Get Started' : 'Next',
              color: CerebroTheme.pinkAccent,
              textColor: CerebroTheme.text1,
              icon: Icons.play_arrow_rounded,
              onTap: _next,
            ),
          ],
        ),
      ),
    );
  }
}

//  DIAMOND CHECKERBOARD PATTERN (matches title screen)
class _DiamondPattern extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      painter: _DiamondPatternPainter(),
      size: Size.infinite,
    );
  }
}

class _DiamondPatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = const Color(0x22FDEFDB);
    const s = 30.0;
    final half = s / 2;

    for (double y = -s; y < size.height + s; y += s) {
      for (double x = -s; x < size.width + s; x += s) {
        final p1 = Path()
          ..moveTo(x, y + s * 0.25)
          ..lineTo(x + s * 0.25, y)
          ..lineTo(x, y)
          ..close();
        final p2 = Path()
          ..moveTo(x + s * 0.75, y + s)
          ..lineTo(x + s, y + s * 0.75)
          ..lineTo(x + s, y + s)
          ..close();
        canvas.drawPath(p1, paint);
        canvas.drawPath(p2, paint);

        final ox = x + half;
        final oy = y + half;
        final q1 = Path()
          ..moveTo(ox, oy + s * 0.25)
          ..lineTo(ox + s * 0.25, oy)
          ..lineTo(ox, oy)
          ..close();
        final q2 = Path()
          ..moveTo(ox + s * 0.75, oy + s)
          ..lineTo(ox + s, oy + s * 0.75)
          ..lineTo(ox + s, oy + s)
          ..close();
        canvas.drawPath(q1, paint);
        canvas.drawPath(q2, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

//  GAME BUTTON (matches HTML .btn with press-down effect)
class _GameBtn extends StatefulWidget {
  final String label;
  final Color color;
  final Color textColor;
  final IconData? icon;
  final VoidCallback? onTap;
  const _GameBtn({
    required this.label,
    required this.color,
    this.textColor = Colors.white,
    this.icon,
    this.onTap,
  });
  @override
  State<_GameBtn> createState() => _GameBtnState();
}

class _GameBtnState extends State<_GameBtn> {
  bool _p = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _p = true),
      onTapUp: (_) {
        setState(() => _p = false);
        widget.onTap?.call();
      },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 24),
        transform: Matrix4.translationValues(
            _p ? 2 : 0, _p ? 2 : 0, 0),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CerebroTheme.text1, width: 2.5),
          boxShadow: [
            if (!_p)
              const BoxShadow(
                  color: CerebroTheme.text1,
                  offset: Offset(3, 3),
                  blurRadius: 0),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.label,
                style: TextStyle(
                  fontFamily: 'Bitroad',
                  fontSize: 15,
                  color: widget.textColor,
                )),
            if (widget.icon != null) ...[
              const SizedBox(width: 6),
              Icon(widget.icon, color: widget.textColor, size: 20),
            ],
          ],
        ),
      ),
    );
  }
}
