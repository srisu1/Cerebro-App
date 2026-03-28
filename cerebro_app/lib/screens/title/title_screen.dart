// Title screen with animated loader and time-of-day greeting.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cerebro_app/config/constants.dart';
import 'package:cerebro_app/config/theme.dart';

//  TIME-OF-DAY GREETINGS (matches HTML script)
class _TimeGreeting {
  final String greeting;
  final String tag;
  const _TimeGreeting(this.greeting, this.tag);
}

_TimeGreeting _getGreeting() {
  final h = DateTime.now().hour;
  if (h >= 5 && h < 12) return const _TimeGreeting('Rise & shine!', 'New quest available');
  if (h >= 12 && h < 17) return const _TimeGreeting('Hey there!', 'Side quest time');
  if (h >= 17 && h < 21) return const _TimeGreeting('Welcome back!', 'Reviewing quest log');
  return const _TimeGreeting('Hey night owl!', 'Night mode: +2X XP');
}

const _loaderMessages = [
  'Loading your quest...',
  'XP boost ready...',
  'Inventory check...',
  'Almost there!',
  'Here we go!',
];

//  TITLE SCREEN
class TitleScreen extends ConsumerStatefulWidget {
  const TitleScreen({super.key});
  @override
  ConsumerState<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends ConsumerState<TitleScreen>
    with TickerProviderStateMixin {
  late final _TimeGreeting _greet;

  late final AnimationController _cardAc;
  late final Animation<double> _cardScale, _cardFade, _cardSlide;

  late final AnimationController _contentAc;
  late final Animation<double> _titleFade, _titleSlide;
  late final Animation<double> _greetFade, _tagFade;
  late final Animation<double> _loaderFade;

  late final AnimationController _barAc;
  int _msgIdx = 0;

  late final AnimationController _btnAc;
  late final Animation<double> _btnFade;

  @override
  void initState() {
    super.initState();
    _greet = _getGreeting();

    // Card pop-in (matches CSS: cardPop .6s cubic-bezier(.34,1.4,.64,1))
    _cardAc = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 600))
      ..forward();
    _cardScale = Tween(begin: 0.96, end: 1.0).animate(
        CurvedAnimation(parent: _cardAc, curve: Curves.elasticOut));
    _cardFade = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _cardAc, curve: const Interval(0.0, 0.5)));
    _cardSlide = Tween(begin: 16.0, end: 0.0).animate(
        CurvedAnimation(parent: _cardAc, curve: Curves.easeOut));

    // Content fade-ins (staggered, matches CSS fadeIn delays)
    _contentAc = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800))
      ..forward();
    _titleFade = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _contentAc, curve: const Interval(0.25, 0.55)));
    _titleSlide = Tween(begin: 8.0, end: 0.0).animate(
        CurvedAnimation(parent: _contentAc, curve: const Interval(0.25, 0.55)));
    _greetFade = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _contentAc, curve: const Interval(0.35, 0.65)));
    _tagFade = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _contentAc, curve: const Interval(0.40, 0.70)));
    _loaderFade = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _contentAc, curve: const Interval(0.50, 0.80)));

    // Loading bar (matches CSS: fillBar 2s ease .6s forwards)
    _barAc = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000));
    _barAc.addListener(() {
      final i = (_barAc.value * (_loaderMessages.length - 1))
          .floor().clamp(0, _loaderMessages.length - 1);
      if (i != _msgIdx && mounted) setState(() => _msgIdx = i);
    });
    _barAc.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted) {
        _btnAc.forward();
      }
    });

    // Button fade-in after loader completes (matches CSS: btnShow .4s ease 2.6s)
    _btnAc = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 400));
    _btnFade = Tween(begin: 0.0, end: 1.0).animate(
        CurvedAnimation(parent: _btnAc, curve: Curves.easeOut));

    // Start loading bar after a short delay (matches CSS .6s delay)
    Future.delayed(const Duration(milliseconds: 600), () {
      if (mounted) _barAc.forward();
    });
  }

  @override
  void dispose() {
    _cardAc.dispose();
    _contentAc.dispose();
    _barAc.dispose();
    _btnAc.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final pr = await SharedPreferences.getInstance();
    if (!mounted) return;
    // The onboarding carousel, setup wizard, and avatar-setup gate are
    // currently turned off. Stamp every wizard completion flag "done" so
    // downstream guards stay green, then route straight to /home if we're
    // authenticated, otherwise to /login.
    await pr.setBool(AppConstants.onboardingCompleteKey, true);
    await pr.setBool(AppConstants.setupCompleteKey, true);
    await pr.setBool(AppConstants.avatarCreatedKey, true);
    if (!mounted) return;
    final tk    = pr.getString(AppConstants.accessTokenKey);
    final hasTk = tk != null && tk.isNotEmpty;
    if (!mounted) return;
    context.go(hasTk ? '/home' : '/login');
  }

  @override
  Widget build(BuildContext context) {
    // Rebuild on theme flip so the game-card + inner surfaces swap
    // from cream → dark brown without needing a remount.
    return ValueListenableBuilder<Brightness>(
      valueListenable: CerebroTheme.brightnessNotifier,
      builder: (context, _, __) => _buildScaffold(context),
    );
  }

  Widget _buildScaffold(BuildContext context) {
    return Scaffold(
      backgroundColor: CerebroTheme.olive,
      body: Stack(
        children: [
          Positioned.fill(child: _DiamondPattern()),

          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 48, 36, 28),
              child: AnimatedBuilder(
                animation: Listenable.merge([_cardAc, _contentAc, _barAc, _btnAc]),
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
                            // Game-card surface — swaps to BROWN-1 in dark mode.
                            color: CerebroTheme.cream,
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
                            child: Column(
                              children: [
                                Expanded(child: _illustrationArea()),

                                Container(
                                    height: 3,
                                    color: CerebroTheme.text1),

                                _contentSection(),
                              ],
                            ),
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

  //  ILLUSTRATION AREA (top, with gradient background)
  Widget _illustrationArea() {
    return Stack(
      children: [
        // Gradient background (matches CSS: linear-gradient(160deg, cream, green-pale, pink-light))
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
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

        // SVG illustration (centered, 70% width, min 650px)
        Center(
          child: OverflowBox(
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: SizedBox(
              width: 900,
              height: 680,
              child: SvgPicture.asset(
                'assets/illustrations/title_illustration.svg',
                fit: BoxFit.contain,
              ),
            ),
          ),
        ),

        // Version label (top-right, matches HTML .version)
        Positioned(
          top: 14,
          right: 16,
          child: Text('v1.0',
              style: GoogleFonts.nunito(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: CerebroTheme.text1.withOpacity(0.35),
              )),
        ),
      ],
    );
  }

  //  CONTENT SECTION (bottom)
  Widget _contentSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Transform.translate(
            offset: Offset(0, _titleSlide.value),
            child: Opacity(
              opacity: _titleFade.value.clamp(0.0, 1.0),
              child: Text('Cerebro.',
                  style: TextStyle(
                    fontFamily: 'Bitroad',
                    fontSize: 56,
                    color: CerebroTheme.text1,
                    height: 1,
                  )),
            ),
          ),
          const SizedBox(height: 6),

          Opacity(
            opacity: _greetFade.value.clamp(0.0, 1.0),
            child: Text(_greet.greeting,
                style: GoogleFonts.gaegu(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: CerebroTheme.text2,
                )),
          ),
          const SizedBox(height: 3),

          Opacity(
            opacity: _tagFade.value.clamp(0.0, 1.0),
            child: Text(_greet.tag,
                style: GoogleFonts.gaegu(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: CerebroTheme.text3.withOpacity(0.6),
                )),
          ),
          const SizedBox(height: 22),

          Opacity(
            opacity: _loaderFade.value.clamp(0.0, 1.0),
            child: _loaderWidget(),
          ),
          const SizedBox(height: 22),

          Opacity(
            opacity: _btnFade.value.clamp(0.0, 1.0),
            child: _goButton(),
          ),
        ],
      ),
    );
  }

  //  LOADER BAR
  Widget _loaderWidget() {
    return SizedBox(
      width: 260,
      child: Column(
        children: [
          // Bar container
          Container(
            height: 14,
            decoration: BoxDecoration(
              color: CerebroTheme.greenPale,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: CerebroTheme.text1, width: 2.5),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(7),
              child: Align(
                alignment: Alignment.centerLeft,
                child: FractionallySizedBox(
                  widthFactor: _barAc.value.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.all(Radius.circular(7)),
                      gradient: LinearGradient(
                        colors: [CerebroTheme.olive, CerebroTheme.pinkAccent],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),

          // Message
          SizedBox(
            height: 16,
            child: Text(
              _loaderMessages[_msgIdx.clamp(0, _loaderMessages.length - 1)],
              style: GoogleFonts.gaegu(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: CerebroTheme.text3.withOpacity(0.55),
              ),
            ),
          ),
        ],
      ),
    );
  }

  //  "LET'S GO!" BUTTON
  Widget _goButton() {
    return _GameBtn(
      label: "Let's Go!",
      icon: Icons.play_arrow_rounded,
      color: CerebroTheme.pinkAccent,
      textColor: CerebroTheme.text1,
      width: 260,
      onTap: _go,
    );
  }
}

//  DIAMOND CHECKERBOARD PATTERN (matches HTML body background)
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
    // Matches CSS:
    // linear-gradient(45deg, #fdefdb22 25%, transparent 25%, transparent 75%, #fdefdb22 75%)
    // background-size: 30px 30px
    final paint = Paint()..color = const Color(0x22FDEFDB);
    const s = 30.0;
    final half = s / 2;

    for (double y = -s; y < size.height + s; y += s) {
      for (double x = -s; x < size.width + s; x += s) {
        // First layer
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
        final p3 = Path()
          ..moveTo(x + s * 0.75, y)
          ..lineTo(x + s, y)
          ..lineTo(x + s, y + s * 0.25)
          ..close();
        final p4 = Path()
          ..moveTo(x, y + s * 0.75)
          ..lineTo(x + s * 0.25, y + s)
          ..lineTo(x, y + s)
          ..close();
        canvas.drawPath(p1, paint);
        canvas.drawPath(p2, paint);

        // Second layer (offset by half)
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

//  GAME BUTTON (matches login screen style)
class _GameBtn extends StatefulWidget {
  final String label;
  final IconData? icon;
  final Color color;
  final Color textColor;
  final double width;
  final VoidCallback? onTap;
  const _GameBtn({
    required this.label,
    this.icon,
    required this.color,
    this.textColor = Colors.white,
    this.width = double.infinity,
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
        width: widget.width,
        height: 58,
        transform: Matrix4.translationValues(
            _p ? 3 : 0, _p ? 3 : 0, 0),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: CerebroTheme.text1, width: 2.5),
          boxShadow: [
            if (!_p)
              BoxShadow(
                  color: CerebroTheme.text1,
                  offset: const Offset(5, 5),
                  blurRadius: 0),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (widget.icon != null) ...[
              Icon(widget.icon, color: widget.textColor, size: 22),
              const SizedBox(width: 8),
            ],
            Text(widget.label,
                style: TextStyle(
                  fontFamily: 'Bitroad',
                  fontSize: 18,
                  color: widget.textColor,
                )),
          ],
        ),
      ),
    );
  }
}
