/// Cozy study room, 3/4 corner perspective.
/// Big window (orb clipped inside). 3D bookshelf. Chair.
/// Desk with depth + items. No sparkles/pennant clutter.
/// 4 time-of-day themes · chunky game title · quest vibes.
/// _testMode = true → theme picker pills at bottom.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cerebro_app/config/constants.dart';

const _testMode = false;
const _ol = Color(0xFF3A3230);

// PALETTE
class _Pal {
  final Color skyA, skyB, skyC;
  final Color orb, orbGlow;
  final Color cloud;
  final Color wallA, wallB;   // side wall, back wall
  final Color floorCol, floorH; // floor and floor highlight
  final Color trim;
  final Color desk, deskTop, deskSide;
  final Color bookA, bookB, bookC, bookD;
  final Color plant, mug, lampCol, screenGlow;
  final Color title, titleGlow, sub;
  final Color bar, spark;
  final Color pillBg, pillAct;
  final bool showStars, isMoon;
  final String greet, tag;
  final List<String> msgs;
  const _Pal({
    required this.skyA, required this.skyB, required this.skyC,
    required this.orb, required this.orbGlow, required this.cloud,
    required this.wallA, required this.wallB,
    required this.floorCol, required this.floorH, required this.trim,
    required this.desk, required this.deskTop, required this.deskSide,
    required this.bookA, required this.bookB,
    required this.bookC, required this.bookD,
    required this.plant, required this.mug,
    required this.lampCol, required this.screenGlow,
    required this.title, required this.titleGlow, required this.sub,
    required this.bar, required this.spark,
    required this.pillBg, required this.pillAct,
    required this.showStars, required this.isMoon,
    required this.greet, required this.tag, required this.msgs,
  });
}

const _themes = [_morning, _afternoon, _evening, _nightPal];
const _labels = ['Morning', 'Afternoon', 'Evening', 'Night'];

const _morning = _Pal(
  skyA: Color(0xFFFFE0C0), skyB: Color(0xFFFFCA90), skyC: Color(0xFF90C8F0),
  orb: Color(0xFFFFB830), orbGlow: Color(0x45FFB830),
  cloud: Color(0xDDFFFFFF),
  wallA: Color(0xFFA88068), wallB: Color(0xFFBE9878),
  floorCol: Color(0xFF6A4428), floorH: Color(0xFF7A5438),
  trim: Color(0xFF4A2818),
  desk: Color(0xFF5A3018), deskTop: Color(0xFF7A4828), deskSide: Color(0xFF4A2010),
  bookA: Color(0xFFE85050), bookB: Color(0xFF40C0A8),
  bookC: Color(0xFFECA020), bookD: Color(0xFFA080D8),
  plant: Color(0xFF48A860), mug: Color(0xFFF0E8E0),
  lampCol: Color(0xFFFFD050), screenGlow: Color(0xFF80C0F0),
  title: Color(0xFFFFF0C0), titleGlow: Color(0x50FFB830), sub: Color(0xFFE8D0B0),
  bar: Color(0xFFFF7860), spark: Color(0xFFFFB830),
  pillBg: Color(0x12000000), pillAct: Color(0x40FF7860),
  showStars: false, isMoon: false,
  greet: 'Rise & shine!', tag: 'New quest available',
  msgs: ['Loading your quest...', 'XP boost ready...', 'Inventory check...', 'Almost there!', 'Here we go!'],
);

const _afternoon = _Pal(
  skyA: Color(0xFF80C0F0), skyB: Color(0xFFB0D8FF), skyC: Color(0xFFFFE8C0),
  orb: Color(0xFFFFD048), orbGlow: Color(0x40FFD048),
  cloud: Color(0xDDFFFFFF),
  wallA: Color(0xFF9A7850), wallB: Color(0xFFAC8A68),
  floorCol: Color(0xFF5A3820), floorH: Color(0xFF6A4828),
  trim: Color(0xFF402818),
  desk: Color(0xFF503018), deskTop: Color(0xFF684020), deskSide: Color(0xFF402010),
  bookA: Color(0xFFE85050), bookB: Color(0xFF40C0A8),
  bookC: Color(0xFFECA020), bookD: Color(0xFFA080D8),
  plant: Color(0xFF48A860), mug: Color(0xFFF0E0C8),
  lampCol: Color(0xFFFFE060), screenGlow: Color(0xFF70B0E8),
  title: Color(0xFFFFF8D0), titleGlow: Color(0x45FFD048), sub: Color(0xFFE0C8A0),
  bar: Color(0xFF50B890), spark: Color(0xFFFFD048),
  pillBg: Color(0x12000000), pillAct: Color(0x3850B890),
  showStars: false, isMoon: false,
  greet: 'Hey there!', tag: 'Side quest time',
  msgs: ['Combo streak active...', 'Power-up loading...', 'Skill check...', 'Almost ready!', "Let's go!"],
);

const _evening = _Pal(
  skyA: Color(0xFFE0C8F0), skyB: Color(0xFFFFC8A0), skyC: Color(0xFFD09060),
  orb: Color(0xFFFF9040), orbGlow: Color(0x40FF9040),
  cloud: Color(0x66FFD8C0),
  wallA: Color(0xFF4A2848), wallB: Color(0xFF583050),
  floorCol: Color(0xFF281020), floorH: Color(0xFF381830),
  trim: Color(0xFF200818),
  desk: Color(0xFF3A1818), deskTop: Color(0xFF4A2828), deskSide: Color(0xFF2A1010),
  bookA: Color(0xFFFF6B5A), bookB: Color(0xFF58C8B8),
  bookC: Color(0xFFFFD060), bookD: Color(0xFFB8A0E8),
  plant: Color(0xFF388858), mug: Color(0xFFD0B898),
  lampCol: Color(0xFFFFE088), screenGlow: Color(0xFF70B0E8),
  title: Color(0xFFFFFFFF), titleGlow: Color(0x55B8A9E8), sub: Color(0xDDFFE0C8),
  bar: Color(0xFFB8A9E8), spark: Color(0xFFFFB080),
  pillBg: Color(0x15FFFFFF), pillAct: Color(0x40B8A9E8),
  showStars: false, isMoon: false,
  greet: 'Welcome back!', tag: 'Reviewing quest log',
  msgs: ['Saving progress...', 'Achievement check...', 'Cozy mode on...', 'Almost ready!', 'Here we go!'],
);

const _nightPal = _Pal(
  skyA: Color(0xFF0A0818), skyB: Color(0xFF101028), skyC: Color(0xFF081020),
  orb: Color(0xFFFFCA4E), orbGlow: Color(0x30FFCA4E),
  cloud: Color(0x18FFFFFF),
  wallA: Color(0xFF1A1838), wallB: Color(0xFF222048),
  floorCol: Color(0xFF100E20), floorH: Color(0xFF181430),
  trim: Color(0xFF0C0A18),
  desk: Color(0xFF2A1818), deskTop: Color(0xFF3A2828), deskSide: Color(0xFF1A0C0C),
  bookA: Color(0xFFFF6B5A), bookB: Color(0xFF58C8B8),
  bookC: Color(0xFFFFD060), bookD: Color(0xFFB8A0E8),
  plant: Color(0xFF3A8860), mug: Color(0xFFC8B898),
  lampCol: Color(0xFFFFE070), screenGlow: Color(0xFF5898D8),
  title: Color(0xFFFFE8C0), titleGlow: Color(0x55B8A9E8), sub: Color(0xAAB8A9E8),
  bar: Color(0xFFB8A9E8), spark: Color(0xFFFFCA4E),
  pillBg: Color(0x12FFFFFF), pillAct: Color(0x40B8A9E8),
  showStars: true, isMoon: true,
  greet: 'Hey night owl!', tag: 'Night mode: +2X XP',
  msgs: ['Secret quest loading...', 'Moon power active...', 'Quiet focus...', 'Almost ready!', "Let's do this!"],
);

int _timeIdx() {
  final h = DateTime.now().hour;
  if (h >= 5 && h < 12) return 0;
  if (h >= 12 && h < 17) return 1;
  if (h >= 17 && h < 21) return 2;
  return 3;
}

// WIDGET
class TitleScreen extends ConsumerStatefulWidget {
  const TitleScreen({super.key});
  @override
  ConsumerState<TitleScreen> createState() => _TitleScreenState();
}

class _TitleScreenState extends ConsumerState<TitleScreen>
    with TickerProviderStateMixin {
  late _Pal _p;
  int _ai = 0;
  final _rng = math.Random(42);
  late final List<_Star> _stars;

  late final AnimationController _enterAc;
  late final Animation<double> _sceneFade;
  late final Animation<double> _titleSlide, _titleFade;
  late final Animation<double> _loadFade;
  late final AnimationController _loadAc;
  late final AnimationController _bobAc;
  late final AnimationController _starAc;
  int _msgIdx = 0;

  @override
  void initState() {
    super.initState();
    _ai = _timeIdx();
    _p = _themes[_ai];

    _stars = List.generate(65, (_) => _Star(
      x: _rng.nextDouble(), y: _rng.nextDouble(),
      r: 0.5 + _rng.nextDouble() * 2.2,
      ph: _rng.nextDouble() * math.pi * 2,
      sp: 1.5 + _rng.nextDouble() * 2.5,
      op: 0.2 + _rng.nextDouble() * 0.65,
    ));

    _enterAc = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..forward();
    _sceneFade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _enterAc,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOut)));
    _titleSlide = Tween(begin: 20.0, end: 0.0).animate(CurvedAnimation(
        parent: _enterAc,
        curve: const Interval(0.18, 0.48, curve: Curves.easeOut)));
    _titleFade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _enterAc,
        curve: const Interval(0.18, 0.42, curve: Curves.easeOut)));
    _loadFade = Tween(begin: 0.0, end: 1.0).animate(CurvedAnimation(
        parent: _enterAc,
        curve: const Interval(0.5, 0.8, curve: Curves.easeOut)));
    _enterAc.addStatusListener((s) {
      if (s == AnimationStatus.completed) _loadAc.forward();
    });

    _loadAc = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1600));
    _loadAc.addListener(() {
      final i = (_loadAc.value * (_p.msgs.length - 1))
          .floor().clamp(0, _p.msgs.length - 1);
      if (i != _msgIdx && mounted) setState(() => _msgIdx = i);
    });
    _loadAc.addStatusListener((s) {
      if (s == AnimationStatus.completed && mounted && !_testMode) {
        Future.delayed(const Duration(milliseconds: 350), () {
          if (mounted) _go();
        });
      }
    });

    _bobAc = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 3500))
      ..repeat();
    _starAc = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2000))
      ..repeat();
  }

  @override
  void dispose() {
    _enterAc.dispose(); _loadAc.dispose();
    _bobAc.dispose(); _starAc.dispose();
    super.dispose();
  }

  void _switchTo(int i) {
    if (i == _ai) return;
    setState(() { _ai = i; _p = _themes[i]; _msgIdx = 0; });
    _loadAc.reset(); _enterAc.reset(); _enterAc.forward();
  }

  Future<void> _go() async {
    final pr = await SharedPreferences.getInstance();
    if (!mounted) return;
    final on = pr.getBool(AppConstants.onboardingCompleteKey) ?? false;
    final tk = pr.getString(AppConstants.accessTokenKey);
    final hasTk = tk != null && tk.isNotEmpty;
    final su = pr.getBool(AppConstants.setupCompleteKey) ?? false;
    final av = pr.getBool(AppConstants.avatarCreatedKey) ?? false;
    if (!mounted) return;
    if (!on)   { context.go('/onboarding'); return; }
    if (!hasTk){ context.go('/login'); return; }
    if (!su)   { context.go('/setup'); return; }
    if (!av)   { context.go('/avatar-setup'); return; }
    context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: Listenable.merge([_enterAc, _loadAc, _bobAc, _starAc]),
        builder: (ctx, _) => Stack(children: [
          // Sky gradient (behind everything, visible through window)
          Positioned.fill(child: Container(
            decoration: BoxDecoration(gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: [_p.skyA, _p.skyB, _p.skyC],
              stops: const [0.0, 0.5, 1.0],
            )),
          )),

          if (_p.showStars)
            Positioned.fill(child: CustomPaint(
                painter: _StarFieldP(_stars, _starAc.value))),

          Positioned.fill(child: CustomPaint(
              painter: _CloudP(_p.cloud, _bobAc.value, _p.showStars))),

          // Room scene
          Positioned.fill(child: Opacity(
            opacity: _sceneFade.value.clamp(0.0, 1.0),
            child: CustomPaint(painter: _RoomP(_p, _bobAc.value, _starAc.value)),
          )),

          // Content – pushed DOWN so title sits on wall below window
          SafeArea(child: Column(children: [
            const Spacer(flex: 7),
            Transform.translate(offset: Offset(0, _titleSlide.value),
              child: Opacity(opacity: _titleFade.value.clamp(0.0, 1.0),
                child: _titleW())),
            const SizedBox(height: 4),
            Opacity(opacity: _titleFade.value.clamp(0.0, 1.0),
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text(_p.greet, style: GoogleFonts.gaegu(
                  fontSize: 20, fontWeight: FontWeight.w700,
                  color: _p.sub, letterSpacing: 2)),
                const SizedBox(height: 2),
                Text(_p.tag, style: GoogleFonts.gaegu(
                  fontSize: 14, fontWeight: FontWeight.w600,
                  color: _p.sub.withOpacity(0.55), letterSpacing: 1)),
              ])),
            const Spacer(flex: 6),
            Opacity(opacity: _loadFade.value.clamp(0.0, 1.0),
              child: _loaderW()),
            const SizedBox(height: 14),
            if (_testMode) _pickerW(),
            if (_testMode) const SizedBox(height: 14),
            if (!_testMode) const Spacer(flex: 1),
          ])),

        ]),
      ),
    );
  }

  Widget _titleW() => SizedBox(height: 80, child: Center(
    child: CustomPaint(size: const Size(380, 80), painter: _TitleP(_p))));

  Widget _loaderW() => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(width: 180, height: 12,
      decoration: BoxDecoration(
        color: _p.bar.withOpacity(0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _p.bar.withOpacity(0.3), width: 2.5)),
      child: ClipRRect(borderRadius: BorderRadius.circular(4),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: _loadAc.value.clamp(0.0, 1.0),
          child: Container(decoration: BoxDecoration(gradient: LinearGradient(
            colors: [_p.bar, _p.bar.withOpacity(0.5), _p.bar])))))),
    const SizedBox(height: 8),
    Text(_p.msgs[_msgIdx.clamp(0, _p.msgs.length - 1)],
      style: GoogleFonts.gaegu(fontSize: 13, fontWeight: FontWeight.w700,
        color: _p.sub.withOpacity(0.6), letterSpacing: 1)),
  ]);

  Widget _pickerW() {
    final dk = _p.showStars;
    return Padding(padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(padding: const EdgeInsets.all(5),
        decoration: BoxDecoration(
          color: _p.pillBg, borderRadius: BorderRadius.circular(20),
          border: Border.all(color: _ol.withOpacity(dk ? 0.12 : 0.06), width: 2.5)),
        child: Row(children: List.generate(4, (i) {
          final on = i == _ai;
          return Expanded(child: GestureDetector(onTap: () => _switchTo(i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: on ? _themes[i].pillAct : Colors.transparent,
                borderRadius: BorderRadius.circular(14),
                border: on ? Border.all(
                  color: _themes[i].orb.withOpacity(0.35), width: 2) : null),
              child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 10, height: 10, decoration: BoxDecoration(
                  shape: BoxShape.circle, color: _themes[i].orb,
                  border: Border.all(color: _ol.withOpacity(0.25), width: 1.5))),
                const SizedBox(width: 5),
                Text(_labels[i], style: GoogleFonts.gaegu(
                  fontSize: 12, fontWeight: FontWeight.w700,
                  color: on ? (dk ? Colors.white : _ol)
                    : (dk ? Colors.white.withOpacity(0.4) : _ol.withOpacity(0.4)))),
              ]))));
        }))));
  }

}

class _Star {
  final double x, y, r, ph, sp, op;
  const _Star({required this.x, required this.y, required this.r,
    required this.ph, required this.sp, required this.op});
}

// STAR FIELD
class _StarFieldP extends CustomPainter {
  final List<_Star> stars; final double t;
  const _StarFieldP(this.stars, this.t);
  @override
  void paint(Canvas c, Size s) {
    for (final st in stars) {
      final w = (math.sin(t * math.pi * 2 * st.sp + st.ph) + 1) / 2;
      final o = (st.op * (0.3 + 0.7 * w)).clamp(0.0, 1.0);
      final pos = Offset(st.x * s.width, st.y * s.height);
      c.drawCircle(pos, st.r, Paint()..color = Colors.white.withOpacity(o));
      if (st.r > 1.5)
        c.drawCircle(pos, st.r * 2.5,
            Paint()..color = Colors.white.withOpacity(o * 0.12));
    }
  }
  @override bool shouldRepaint(_StarFieldP o) => true;
}

// CLOUDS
class _CloudP extends CustomPainter {
  final Color tint; final double t; final bool isNight;
  const _CloudP(this.tint, this.t, this.isNight);
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height, d = t * 18;
    final p = Paint()..color = tint;
    _big(c, p, w * 0.10 + d, h * 0.06, 80, 38);
    _big(c, p, w * 0.80 - d * 0.6, h * 0.04, 70, 34);
    _big(c, p, w * 0.45 + d * 0.3, h * 0.10, 60, 30);
    if (!isNight) {
      _big(c, p, w * 0.25 - d * 0.4, h * 0.08, 72, 36);
      _sm(c, p, w * 0.65 - d * 0.2, h * 0.14, 50, 24);
    }
    if (isNight) {
      _big(c, p, w * 0.60 + d * 0.2, h * 0.08, 65, 32);
    }
  }
  void _big(Canvas c, Paint p, double x, double y, double w, double h) {
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: w, height: h), p);
    c.drawOval(Rect.fromCenter(center: Offset(x - w * 0.3, y + h * 0.1), width: w * 0.7, height: h * 0.8), p);
    c.drawOval(Rect.fromCenter(center: Offset(x + w * 0.3, y), width: w * 0.65, height: h * 0.75), p);
    c.drawOval(Rect.fromCenter(center: Offset(x + w * 0.1, y - h * 0.2), width: w * 0.5, height: h * 0.6), p);
  }
  void _sm(Canvas c, Paint p, double x, double y, double w, double h) {
    c.drawOval(Rect.fromCenter(center: Offset(x, y), width: w, height: h), p);
    c.drawOval(Rect.fromCenter(center: Offset(x - w * 0.3, y), width: w * 0.6, height: h * 0.7), p);
    c.drawOval(Rect.fromCenter(center: Offset(x + w * 0.3, y), width: w * 0.6, height: h * 0.7), p);
  }
  @override bool shouldRepaint(_CloudP o) => true;
}

// 3/4 CORNER ROOM  (v8.2 – polished)
class _RoomP extends CustomPainter {
  final _Pal p; final double sway; final double tick;
  const _RoomP(this.p, this.sway, this.tick);

  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;

    final cx = w * 0.35;
    final cL = h * 0.04, cC = h * 0.008, cR = h * 0.025;
    final fL = h * 0.68, fC = h * 0.62, fR = h * 0.65;

    final ceil = Path()
      ..moveTo(0, 0)..lineTo(w, 0)
      ..lineTo(w, cR)..lineTo(cx, cC)..lineTo(0, cL)..close();
    c.drawPath(ceil, Paint()..color = Color.lerp(p.trim, p.wallA, 0.35)!);

    final sideW = Path()
      ..moveTo(0, cL)..lineTo(cx, cC)
      ..lineTo(cx, fC)..lineTo(0, fL)..close();
    c.drawPath(sideW, Paint()..color = p.wallA);

    final backW = Path()
      ..moveTo(cx, cC)..lineTo(w, cR)
      ..lineTo(w, fR)..lineTo(cx, fC)..close();

    double bx(double t) => cx + t * (w - cx);
    double bTop(double t) => cC + t * (cR - cC);
    double bBot(double t) => fC + t * (fR - fC);

    // Window
    final wL = bx(0.18), wR = bx(0.72);
    final wTL = bTop(0.18) + (bBot(0.18) - bTop(0.18)) * 0.10;
    final wTR = bTop(0.72) + (bBot(0.72) - bTop(0.72)) * 0.10;
    final wBL = bTop(0.18) + (bBot(0.18) - bTop(0.18)) * 0.55;
    final wBR = bTop(0.72) + (bBot(0.72) - bTop(0.72)) * 0.55;

    final win = Path()
      ..moveTo(wL, wTL)..lineTo(wR, wTR)
      ..lineTo(wR, wBR)..lineTo(wL, wBL)..close();
    final wallHole = Path.combine(PathOperation.difference, backW, win);
    c.drawPath(wallHole, Paint()..color = p.wallB);

    c.save();
    c.clipPath(win);
    _drawOrb(c, wL, wR, wTL, wTR, wBL, wBR);
    c.restore();

    c.drawPath(win, Paint()..color = p.trim..style = PaintingStyle.stroke
      ..strokeWidth = 5..strokeJoin = StrokeJoin.round);
    // Cross bars
    final cbP = Paint()..color = p.trim..strokeWidth = 3;
    c.drawLine(Offset(wL, (wTL + wBL) / 2), Offset(wR, (wTR + wBR) / 2), cbP);
    c.drawLine(Offset((wL + wR) / 2, (wTL + wTR) / 2),
        Offset((wL + wR) / 2, (wBL + wBR) / 2), cbP);
    // Sill
    c.drawLine(Offset(wL - 4, wBL + 3), Offset(wR + 4, wBR + 3),
        Paint()..color = p.trim..strokeWidth = 7..strokeCap = StrokeCap.round);

    _drawSillPlant(c, wL, wR, wBL, wBR);

    _drawFairyLights(c, wL, wR, wTL, wTR, wBL, wBR);

    final floor = Path()
      ..moveTo(0, fL)..lineTo(cx, fC)..lineTo(w, fR)
      ..lineTo(w, h)..lineTo(0, h)..close();
    c.drawPath(floor, Paint()..color = p.floorCol);
    // Subtle plank lines
    for (int i = 1; i <= 4; i++) {
      final t = i / 5;
      c.drawLine(Offset(0, fL + (h - fL) * t), Offset(w, fR + (h - fR) * t),
          Paint()..color = p.floorH..strokeWidth = 1);
    }

    _drawRug(c, w, h, cx, fC, fR);

    if (!p.showStars) {
      // Light falls mostly straight down from window, spreading slightly
      final bSpread = (wR - wL) * 0.12;
      final beam = Path()
        ..moveTo(wL + 6, wBL + 6)..lineTo(wR - 6, wBR + 6)
        ..lineTo(wR + bSpread, h)
        ..lineTo(wL - bSpread, h)..close();
      c.drawPath(beam, Paint()..color = p.orb.withOpacity(0.06));
    }

    c.drawLine(Offset(cx, cC), Offset(cx, fC),
        Paint()..color = p.trim..strokeWidth = 3.5);
    final bsP = Paint()..color = p.trim..strokeWidth = 4.5;
    c.drawLine(Offset(0, fL), Offset(cx, fC), bsP);
    c.drawLine(Offset(cx, fC), Offset(w, fR), bsP);
    c.drawLine(Offset(0, cL), Offset(cx, cC),
        Paint()..color = p.trim..strokeWidth = 3);
    c.drawLine(Offset(cx, cC), Offset(w, cR),
        Paint()..color = p.trim..strokeWidth = 3);

    _drawShelf(c, w, h, cx, cL, cC, fL, fC);

    _drawDesk(c, w, h, cx, fC, fL, fR);
  }

  void _drawSillPlant(Canvas c, double wL, double wR,
      double wBL, double wBR) {
    final px = wL + (wR - wL) * 0.15;
    final py = wBL + (wBR - wBL) * 0.15;
    // Tiny pot
    final pot = Path()
      ..moveTo(px - 5, py)..lineTo(px - 4, py - 9)
      ..lineTo(px + 4, py - 9)..lineTo(px + 5, py)..close();
    c.drawPath(pot, Paint()..color = Color.lerp(p.trim, p.bookA, 0.3)!);
    c.drawPath(pot, Paint()..color = _ol.withOpacity(0.2)
      ..style = PaintingStyle.stroke..strokeWidth = 1);
    // Little cactus / succulent
    c.drawOval(Rect.fromCenter(center: Offset(px, py - 13),
        width: 7, height: 9), Paint()..color = p.plant);
    c.drawOval(Rect.fromCenter(center: Offset(px - 4, py - 16),
        width: 5, height: 6), Paint()..color = Color.lerp(p.plant, _ol, 0.1)!);
    c.drawOval(Rect.fromCenter(center: Offset(px + 3, py - 17),
        width: 5, height: 5), Paint()..color = p.plant);
  }

  void _drawOrb(Canvas c, double wL, double wR,
      double wTL, double wTR, double wBL, double wBR) {
    final ox = wL + (wR - wL) * 0.62;
    final oy = (wTL + wTR) / 2 + ((wBL + wBR) / 2 - (wTL + wTR) / 2) * 0.32
        + 2 * math.sin(sway * math.pi * 2);
    final winH = ((wBL - wTL) + (wBR - wTR)) / 2;
    final r = winH * 0.18;

    c.drawCircle(Offset(ox, oy), r * 3.0, Paint()..color = p.orbGlow);
    c.drawCircle(Offset(ox, oy), r * 2.0,
        Paint()..color = p.orbGlow.withOpacity(0.15));
    c.drawCircle(Offset(ox, oy + 1), r, Paint()..color = _ol.withOpacity(0.12));
    final grad = RadialGradient(center: const Alignment(-0.3, -0.3),
      colors: [Color.lerp(p.orb, Colors.white, 0.4)!, p.orb],
    ).createShader(Rect.fromCircle(center: Offset(ox, oy), radius: r));
    c.drawCircle(Offset(ox, oy), r, Paint()..shader = grad);
    c.drawCircle(Offset(ox, oy), r, Paint()..color = _ol
      ..style = PaintingStyle.stroke..strokeWidth = 2.5);

    if (p.isMoon) {
      _crater(c, ox - r * 0.3, oy - r * 0.2, r * 0.2);
      _crater(c, ox + r * 0.25, oy + r * 0.3, r * 0.13);
      _crater(c, ox + r * 0.1, oy - r * 0.35, r * 0.1);
    } else {
      final rp = Paint()..color = p.orb.withOpacity(0.35)
        ..style = PaintingStyle.stroke..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round;
      for (int i = 0; i < 8; i++) {
        final a = i * math.pi / 4;
        c.drawLine(Offset(ox + (r + 4) * math.cos(a), oy + (r + 4) * math.sin(a)),
            Offset(ox + (r + 11) * math.cos(a), oy + (r + 11) * math.sin(a)), rp);
      }
    }
    c.drawCircle(Offset(ox - r * 0.25, oy - r * 0.2), r * 0.22,
        Paint()..color = Colors.white.withOpacity(0.3));
  }

  void _crater(Canvas c, double x, double y, double r) {
    c.drawCircle(Offset(x, y), r,
        Paint()..color = Color.fromRGBO(160, 140, 40, 0.18));
    c.drawCircle(Offset(x, y), r, Paint()
      ..color = Color.fromRGBO(160, 140, 40, 0.25)
      ..style = PaintingStyle.stroke..strokeWidth = 1.2);
  }

  void _drawFairyLights(Canvas c, double wL, double wR,
      double wTL, double wTR, double wBL, double wBR) {
    const nLights = 11;
    final wireP = Paint()..color = _ol.withOpacity(0.12)
      ..strokeWidth = 1..strokeCap = StrokeCap.round;
    // Lights drape from just past window edges with a catenary sag
    for (int i = 0; i <= nLights; i++) {
      final t = i / nLights;
      final x = wL - 6 + (wR - wL + 12) * t;
      final baseY = wTL + (wTR - wTL) * t;
      final sag = 10 * math.sin(t * math.pi); // hangs in middle
      final y = baseY - 5 + sag;
      // Wire to next bulb
      if (i < nLights) {
        final nt = (i + 1) / nLights;
        final nx = wL - 6 + (wR - wL + 12) * nt;
        final nBaseY = wTL + (wTR - wTL) * nt;
        final ny = nBaseY - 5 + 10 * math.sin(nt * math.pi);
        c.drawLine(Offset(x, y), Offset(nx, ny), wireP);
      }
      // Animated twinkle
      final blink = (math.sin(tick * math.pi * 2 + i * 1.1) + 1) / 2;
      final op = 0.35 + blink * 0.30;
      // Warm glow halo
      c.drawCircle(Offset(x, y), 7,
          Paint()..color = p.lampCol.withOpacity(op * 0.10));
      // Bulb
      c.drawCircle(Offset(x, y), 3.0,
          Paint()..color = p.lampCol.withOpacity(op));
      // Bright center
      c.drawCircle(Offset(x, y), 1.4,
          Paint()..color = Colors.white.withOpacity(op * 0.5));
    }
  }

  void _drawRug(Canvas c, double w, double h, double cx,
      double fC, double fR) {
    // Big circular rug on the floor, in front of desk
    final rx = cx + (w - cx) * 0.45;
    final ry = fC + (h - fC) * 0.58;
    final rSize = (w - cx) * 0.26; // radius
    final rY = rSize * 0.45; // squished for perspective
    // Body
    c.drawOval(Rect.fromCenter(center: Offset(rx, ry),
        width: rSize * 2, height: rY * 2),
        Paint()..color = p.bookD.withOpacity(0.14));
    // Outer border ring
    c.drawOval(Rect.fromCenter(center: Offset(rx, ry),
        width: rSize * 2, height: rY * 2),
        Paint()..color = p.bookA.withOpacity(0.18)
          ..style = PaintingStyle.stroke..strokeWidth = 4);
    // Second ring
    c.drawOval(Rect.fromCenter(center: Offset(rx, ry),
        width: rSize * 1.55, height: rY * 1.55),
        Paint()..color = p.bookB.withOpacity(0.12)
          ..style = PaintingStyle.stroke..strokeWidth = 2.5);
    // Third ring
    c.drawOval(Rect.fromCenter(center: Offset(rx, ry),
        width: rSize * 1.10, height: rY * 1.10),
        Paint()..color = p.bookC.withOpacity(0.10)
          ..style = PaintingStyle.stroke..strokeWidth = 2);
    // Inner ring
    c.drawOval(Rect.fromCenter(center: Offset(rx, ry),
        width: rSize * 0.65, height: rY * 0.65),
        Paint()..color = p.bookA.withOpacity(0.08)
          ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // Center medallion
    c.drawOval(Rect.fromCenter(center: Offset(rx, ry),
        width: rSize * 0.30, height: rY * 0.30),
        Paint()..color = p.bookC.withOpacity(0.10));
  }

  void _drawCornerPlant(Canvas c, double cx, double fC, double fL, double h) {
    // Position on side wall floor, between bookshelf right edge and corner
    final px = cx * 0.82;
    final floorY = fL + (fC - fL) * (px / cx);
    final py = floorY;
    // Big terracotta pot
    final potH = 34.0;
    final pot = Path()
      ..moveTo(px - 16, py)..lineTo(px - 12, py - potH)
      ..lineTo(px + 12, py - potH)..lineTo(px + 16, py)..close();
    c.drawPath(pot, Paint()..color = Color.lerp(p.bookA, p.trim, 0.35)!);
    c.drawPath(pot, Paint()..color = _ol.withOpacity(0.20)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // Pot rim
    c.drawLine(Offset(px - 13, py - potH + 3), Offset(px + 13, py - potH + 3),
        Paint()..color = Color.lerp(p.bookA, p.trim, 0.2)!..strokeWidth = 4);
    // Soil
    c.drawOval(Rect.fromCenter(center: Offset(px, py - potH + 6),
        width: 20, height: 6), Paint()..color = Color.lerp(p.trim, _ol, 0.25)!);
    // Tall lush leaves
    final la = math.sin(sway * math.pi * 2) * 0.04;
    _leaf(c, px, py - potH + 2, -0.30 + la, 38, p.plant);
    _leaf(c, px, py - potH + 2, 0.20 + la, 42, p.plant);
    _leaf(c, px, py - potH + 2, -0.65 + la, 28, Color.lerp(p.plant, _ol, 0.12)!);
    _leaf(c, px, py - potH + 2, 0.55 + la, 30, Color.lerp(p.plant, _ol, 0.12)!);
    _leaf(c, px, py - potH + 2, 0.0 + la * 0.5, 48, p.plant);
    _leaf(c, px, py - potH + 2, -0.12 + la, 40, Color.lerp(p.plant, Colors.green, 0.12)!);
    _leaf(c, px, py - potH + 2, 0.42 + la, 34, p.plant);
  }

  void _drawShelf(Canvas c, double w, double h, double cx,
      double cL, double cC, double fL, double fC) {
    // Position shelf on the side wall — a rectangular unit with perspective
    // Left/right x positions on the side wall
    final shL = cx * 0.10;
    final shR = cx * 0.70;

    // Interpolate wall top/bottom at each x position
    double wallTop(double x) => cL + (cC - cL) * (x / cx);
    double wallBot(double x) => fL + (fC - fL) * (x / cx);

    // Shelf unit occupies 18%–72% of wall height at each x
    final topL = wallTop(shL) + (wallBot(shL) - wallTop(shL)) * 0.18;
    final topR = wallTop(shR) + (wallBot(shR) - wallTop(shR)) * 0.18;
    final botL = wallTop(shL) + (wallBot(shL) - wallTop(shL)) * 0.72;
    final botR = wallTop(shR) + (wallBot(shR) - wallTop(shR)) * 0.72;

    final woodD = Color.lerp(p.trim, _ol, 0.1)!;
    final woodL = Color.lerp(p.trim, p.wallA, 0.25)!;
    final backC = Color.lerp(p.wallA, p.trim, 0.40)!;

    final back = Path()
      ..moveTo(shL, topL)..lineTo(shR, topR)
      ..lineTo(shR, botR)..lineTo(shL, botL)..close();
    c.drawPath(back, Paint()..color = backC);

    final fP = Paint()..color = woodD..strokeWidth = 5
      ..strokeCap = StrokeCap.round..strokeJoin = StrokeJoin.round;
    c.drawLine(Offset(shL, topL), Offset(shL, botL), fP); // left
    c.drawLine(Offset(shR, topR), Offset(shR, botR), fP); // right
    c.drawLine(Offset(shL, topL), Offset(shR, topR), fP); // top
    c.drawLine(Offset(shL, botL), Offset(shR, botR), fP); // bottom

    const nS = 3;
    final cols = [p.bookA, p.bookB, p.bookC, p.bookD];
    final rng = math.Random(42);

    for (int i = 0; i < nS; i++) {
      // Shelf plank at bottom of each compartment
      final pt = (i + 1) / nS;
      final plankL = topL + (botL - topL) * pt;
      final plankR = topR + (botR - topR) * pt;
      // Thick wooden plank
      c.drawLine(Offset(shL, plankL), Offset(shR, plankR),
          Paint()..color = woodD..strokeWidth = 6);
      c.drawLine(Offset(shL, plankL - 2.5), Offset(shR, plankR - 2.5),
          Paint()..color = woodL..strokeWidth = 1.2);

      // Compartment top
      final ct = i / nS;
      final compTopL = topL + (botL - topL) * ct + 5;
      final compTopR = topR + (botR - topR) * ct + 5;
      final compBotL = plankL - 5;
      final compBotR = plankR - 5;

      // Pack books tightly across the shelf
      double curX = shL + 4;
      final endX = shR - 3;
      int bIdx = 0;
      while (curX < endX - 4) {
        final bookW = 10.0 + rng.nextDouble() * 12.0; // 10-22px wide
        if (curX + bookW > endX) break;

        // Interpolate Y at this book's center x
        final t = (curX + bookW / 2 - shL) / (shR - shL);
        final localTop = compTopL + (compTopR - compTopL) * t;
        final localBot = compBotL + (compBotR - compBotL) * t;
        final shelfH = localBot - localTop;

        final hFrac = 0.55 + rng.nextDouble() * 0.40;
        final bookH = shelfH * hFrac;
        final col = cols[(i * 5 + bIdx) % 4];

        // Book spine (rectangle sitting on shelf)
        final bRect = Rect.fromLTWH(curX, localBot - bookH, bookW, bookH);
        c.drawRRect(RRect.fromRectAndRadius(bRect, const Radius.circular(1.2)),
            Paint()..color = col);
        c.drawRRect(RRect.fromRectAndRadius(bRect, const Radius.circular(1.2)),
            Paint()..color = _ol.withOpacity(0.22)
              ..style = PaintingStyle.stroke..strokeWidth = 1.2);

        // Spine highlight (left edge bright line)
        c.drawLine(Offset(curX + 1.5, localBot - bookH + 3),
            Offset(curX + 1.5, localBot - 3),
            Paint()..color = Colors.white.withOpacity(0.15)..strokeWidth = 1);

        // Title line (horizontal mark on spine)
        if (bookW > 12) {
          c.drawLine(Offset(curX + 3, localBot - bookH * 0.45),
              Offset(curX + bookW - 3, localBot - bookH * 0.45),
              Paint()..color = Colors.white.withOpacity(0.10)..strokeWidth = 1);
          // Second title line
          c.drawLine(Offset(curX + 4, localBot - bookH * 0.38),
              Offset(curX + bookW - 4, localBot - bookH * 0.38),
              Paint()..color = Colors.white.withOpacity(0.06)..strokeWidth = 0.8);
        }

        // Darker right edge for depth
        c.drawLine(Offset(curX + bookW - 1, localBot - bookH + 2),
            Offset(curX + bookW - 1, localBot - 2),
            Paint()..color = _ol.withOpacity(0.10)..strokeWidth = 1);

        curX += bookW + 1.5; // small gap between books
        bIdx++;
      }
    }

    final sideDepth = 12.0;
    // Shadow behind shelf
    c.drawPath(Path()
      ..moveTo(shR + 3, topR + 3)..lineTo(shR + sideDepth + 3, topR + sideDepth * 0.5 + 3)
      ..lineTo(shR + sideDepth + 3, botR + sideDepth * 0.5 + 3)
      ..lineTo(shR + 3, botR + 3)..close(),
      Paint()..color = _ol.withOpacity(0.08));
    // Side face (right edge, toward viewer)
    final sideFace = Path()
      ..moveTo(shR, topR)..lineTo(shR + sideDepth, topR + sideDepth * 0.5)
      ..lineTo(shR + sideDepth, botR + sideDepth * 0.5)
      ..lineTo(shR, botR)..close();
    c.drawPath(sideFace, Paint()..color = woodD);
    c.drawPath(sideFace, Paint()..color = _ol.withOpacity(0.15)
      ..style = PaintingStyle.stroke..strokeWidth = 1.2);
    // Side shelf plank edges
    for (int i = 0; i < nS; i++) {
      final pt = (i + 1) / nS;
      final plankR2 = topR + (botR - topR) * pt;
      c.drawLine(Offset(shR, plankR2),
          Offset(shR + sideDepth, plankR2 + sideDepth * 0.5),
          Paint()..color = woodL..strokeWidth = 2.5);
    }
  }

  void _drawDesk(Canvas c, double w, double h, double cx,
      double fC, double fL, double fR) {
    // Desk fully in back wall area, under the window
    final dw = w * 0.44;
    final dx = w * 0.36;
    final dy = fC + (h - fC) * 0.06;
    final dDepth = 30.0;
    final dFrontH = h * 0.14;
    final tilt = -4.0;

    final surf = Path()
      ..moveTo(dx, dy)
      ..lineTo(dx + dw, dy + tilt)
      ..lineTo(dx + dw + dDepth, dy + dDepth + tilt)
      ..lineTo(dx + dDepth, dy + dDepth + 4)
      ..close();
    c.drawPath(surf, Paint()..color = p.deskTop);
    // Wood grain
    for (int i = 1; i <= 4; i++) {
      final t = i / 5;
      final gx = dx + dw * t;
      final yOff = tilt * t;
      c.drawLine(Offset(gx + 3, dy + yOff + 3),
          Offset(gx + dDepth - 3, dy + dDepth + yOff),
          Paint()..color = _ol.withOpacity(0.04)..strokeWidth = 0.5);
    }
    c.drawPath(surf, Paint()..color = _ol.withOpacity(0.22)
      ..style = PaintingStyle.stroke..strokeWidth = 2.5);

    final fY1L = dy + dDepth + 4;
    final fY1R = dy + dDepth + tilt;
    final front = Path()
      ..moveTo(dx + dDepth, fY1L)
      ..lineTo(dx + dw + dDepth, fY1R)
      ..lineTo(dx + dw + dDepth, fY1R + dFrontH)
      ..lineTo(dx + dDepth, fY1L + dFrontH)
      ..close();
    c.drawPath(front, Paint()..color = p.desk);
    c.drawPath(front, Paint()..color = _ol.withOpacity(0.18)
      ..style = PaintingStyle.stroke..strokeWidth = 2);
    // Drawer panel
    final dPanelL = dx + dDepth + 14;
    final dPanelR = dx + dw + dDepth - 14;
    final dPanelT = fY1L + dFrontH * 0.10;
    final dPanelB = fY1L + dFrontH * 0.90;
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(dPanelL, dPanelT, dPanelR, dPanelB),
        const Radius.circular(2)),
        Paint()..color = _ol.withOpacity(0.06));
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTRB(dPanelL, dPanelT, dPanelR, dPanelB),
        const Radius.circular(2)),
        Paint()..color = _ol.withOpacity(0.10)
          ..style = PaintingStyle.stroke..strokeWidth = 1);
    // Two drawer knobs
    final knobY = (dPanelT + dPanelB) / 2;
    c.drawCircle(Offset(dPanelL + (dPanelR - dPanelL) * 0.35, knobY), 3,
        Paint()..color = Color.lerp(p.trim, _ol, 0.15)!);
    c.drawCircle(Offset(dPanelL + (dPanelR - dPanelL) * 0.65, knobY), 3,
        Paint()..color = Color.lerp(p.trim, _ol, 0.15)!);

    final side = Path()
      ..moveTo(dx, dy)
      ..lineTo(dx + dDepth, fY1L)
      ..lineTo(dx + dDepth, fY1L + dFrontH)
      ..lineTo(dx, dy + dFrontH)
      ..close();
    c.drawPath(side, Paint()..color = p.deskSide);
    c.drawPath(side, Paint()..color = _ol.withOpacity(0.15)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5);

    final legP = Paint()..color = Color.lerp(p.desk, _ol, 0.35)!
      ..strokeWidth = 5..strokeCap = StrokeCap.round;
    c.drawLine(Offset(dx + dDepth + 16, fY1L + dFrontH),
        Offset(dx + dDepth + 14, h - 4), legP);
    c.drawLine(Offset(dx + dw + dDepth - 10, fY1R + dFrontH),
        Offset(dx + dw + dDepth - 8, h - 4), legP);

    final iy = dy + (dDepth / 2) + 3;

    final lampX = dx + dw * 0.05 + dDepth;
    c.drawOval(Rect.fromCenter(center: Offset(lampX, iy + 1),
        width: 22, height: 9), Paint()..color = p.trim);
    c.drawLine(Offset(lampX, iy - 3), Offset(lampX + 8, iy - 50),
        Paint()..color = p.trim..strokeWidth = 3..strokeCap = StrokeCap.round);
    // Shade
    final shade = Path()
      ..moveTo(lampX - 5, iy - 44)
      ..lineTo(lampX + 8, iy - 56)
      ..lineTo(lampX + 21, iy - 44)
      ..close();
    c.drawPath(shade, Paint()..color = p.trim);
    c.drawPath(shade, Paint()..color = _ol.withOpacity(0.15)
      ..style = PaintingStyle.stroke..strokeWidth = 1);
    // Warm glow cone
    final glow = Path()
      ..moveTo(lampX - 3, iy - 43)
      ..lineTo(lampX + 19, iy - 43)
      ..lineTo(lampX + 30, iy + 6)
      ..lineTo(lampX - 14, iy + 6)
      ..close();
    c.drawPath(glow, Paint()..color = p.lampCol.withOpacity(0.12));
    c.drawCircle(Offset(lampX + 8, iy - 42), 4,
        Paint()..color = p.lampCol.withOpacity(0.45));
    // Desk surface glow from lamp
    c.drawOval(Rect.fromCenter(center: Offset(lampX + 8, iy + 2),
        width: 44, height: 12), Paint()..color = p.lampCol.withOpacity(0.06));

    final lapX = dx + dw * 0.40 + dDepth;
    // Screen frame (bezel)
    final scr = Path()
      ..moveTo(lapX - 48, iy + 2)
      ..lineTo(lapX - 40, iy - 58)
      ..lineTo(lapX + 40, iy - 58)
      ..lineTo(lapX + 48, iy + 2)
      ..close();
    c.drawPath(scr, Paint()..color = Color.lerp(p.trim, _ol, 0.3)!);
    // Screen display area
    final scrFace = Path()
      ..moveTo(lapX - 44, iy - 1)
      ..lineTo(lapX - 37, iy - 55)
      ..lineTo(lapX + 37, iy - 55)
      ..lineTo(lapX + 44, iy - 1)
      ..close();
    c.drawPath(scrFace, Paint()..color = p.screenGlow.withOpacity(0.25));
    // Webcam dot
    c.drawCircle(Offset(lapX, iy - 57), 1.5, Paint()..color = _ol.withOpacity(0.4));
    c.drawCircle(Offset(lapX, iy - 57), 0.8,
        Paint()..color = const Color(0xFF40E060).withOpacity(0.6));
    c.drawPath(scr, Paint()..color = _ol.withOpacity(0.30)
      ..style = PaintingStyle.stroke..strokeWidth = 2.5);
    // Screen ambient glow
    c.drawCircle(Offset(lapX, iy - 28), 42,
        Paint()..color = p.screenGlow.withOpacity(0.10));
    // Desk surface glow from screen
    c.drawOval(Rect.fromCenter(center: Offset(lapX, iy + 3),
        width: 90, height: 16), Paint()..color = p.screenGlow.withOpacity(0.06));
    // Screen content lines (code / text)
    for (int li = 0; li < 5; li++) {
      final ly = iy - 48 + li * 9;
      final lx1 = lapX - 28 + li * 3.5;
      final lw = 20.0 + (li % 2 == 0 ? 16 : 10);
      c.drawLine(Offset(lx1, ly), Offset(lx1 + lw, ly),
          Paint()..color = Colors.white.withOpacity(0.10)..strokeWidth = 1.5);
    }
    // Small logo/icon on screen
    c.drawCircle(Offset(lapX, iy - 22), 5,
        Paint()..color = p.screenGlow.withOpacity(0.15));
    c.drawCircle(Offset(lapX, iy - 22), 3,
        Paint()..color = Colors.white.withOpacity(0.08));
    // Keyboard base
    final kb = Path()
      ..moveTo(lapX - 50, iy + 2)
      ..lineTo(lapX - 46, iy - 6)
      ..lineTo(lapX + 46, iy - 6)
      ..lineTo(lapX + 50, iy + 2)
      ..close();
    c.drawPath(kb, Paint()..color = Color.lerp(p.trim, _ol, 0.3)!);
    c.drawPath(kb, Paint()..color = _ol.withOpacity(0.2)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // Key dots
    for (int r = 0; r < 3; r++) {
      for (int k = 0; k < 11; k++) {
        c.drawCircle(
          Offset(lapX - 33 + k * 6.2, iy - 4 + r * 2.2),
          0.7, Paint()..color = _ol.withOpacity(0.14));
      }
    }
    // Trackpad
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(lapX, iy + 0.5), width: 24, height: 4),
        const Radius.circular(1)),
        Paint()..color = _ol.withOpacity(0.06));

    final plX = dx + dw * 0.72 + dDepth;
    final plY = iy;
    final pot = Path()
      ..moveTo(plX - 9, plY)..lineTo(plX - 7, plY - 16)
      ..lineTo(plX + 7, plY - 16)..lineTo(plX + 9, plY)..close();
    c.drawPath(pot, Paint()..color = Color.lerp(p.desk, p.bookA, 0.3)!);
    c.drawPath(pot, Paint()..color = _ol.withOpacity(0.22)
      ..style = PaintingStyle.stroke..strokeWidth = 1.5);
    // Soil
    c.drawLine(Offset(plX - 6, plY - 15), Offset(plX + 6, plY - 15),
        Paint()..color = Color.lerp(p.trim, _ol, 0.2)!..strokeWidth = 2);
    final la = math.sin(sway * math.pi * 2) * 0.05;
    _leaf(c, plX, plY - 16, -0.45 + la, 18, p.plant);
    _leaf(c, plX, plY - 16, 0.35 + la, 20, p.plant);
    _leaf(c, plX, plY - 16, -0.85 + la, 13, Color.lerp(p.plant, _ol, 0.15)!);
    _leaf(c, plX, plY - 16, 0.75 + la, 14, Color.lerp(p.plant, _ol, 0.15)!);
    _leaf(c, plX, plY - 16, 0.0 + la * 0.5, 22, p.plant);
    _leaf(c, plX, plY - 16, -0.15 + la, 19, Color.lerp(p.plant, Colors.green, 0.15)!);

    final mx = dx + dw * 0.88 + dDepth;
    final my = iy;
    final mug = Path()
      ..moveTo(mx - 8, my)..lineTo(mx - 7, my - 20)
      ..quadraticBezierTo(mx, my - 23, mx + 7, my - 20)
      ..lineTo(mx + 8, my)..close();
    c.drawPath(mug, Paint()..color = p.mug);
    c.drawPath(mug, Paint()..color = _ol.withOpacity(0.22)
      ..style = PaintingStyle.stroke..strokeWidth = 1.8);
    // Handle
    c.drawArc(Rect.fromLTWH(mx + 6, my - 18, 8, 12),
        -math.pi / 2, math.pi, false,
        Paint()..color = p.mug..style = PaintingStyle.stroke
          ..strokeWidth = 2.5..strokeCap = StrokeCap.round);
    // Steam wisps
    final sd = math.sin(sway * math.pi * 2) * 3;
    final stmP = Paint()..color = Colors.white.withOpacity(0.14)
      ..strokeWidth = 1.5..strokeCap = StrokeCap.round;
    c.drawLine(Offset(mx - 2, my - 23), Offset(mx - 2 + sd, my - 35), stmP);
    c.drawLine(Offset(mx + 3, my - 24), Offset(mx + 3 + sd * 0.6, my - 38), stmP);
    c.drawLine(Offset(mx + 0.5, my - 22), Offset(mx + 0.5 - sd * 0.4, my - 32),
        Paint()..color = Colors.white.withOpacity(0.08)..strokeWidth = 1..strokeCap = StrokeCap.round);

    final sbx = dx + dw * 0.20 + dDepth;
    _stackBook(c, sbx, iy, 34, 8, p.bookD, -0.03);
    _stackBook(c, sbx + 1, iy - 8, 30, 7, p.bookB.withOpacity(0.9), 0.02);
    _stackBook(c, sbx - 1, iy - 15, 32, 7, p.bookA.withOpacity(0.85), -0.01);
    _stackBook(c, sbx + 2, iy - 22, 28, 6, p.bookC.withOpacity(0.8), 0.015);
  }

  void _stackBook(Canvas c, double x, double y, double bw, double bh,
      Color col, double tilt) {
    c.save();
    c.translate(x, y);
    c.rotate(tilt);
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(-bw / 2, -bh, bw, bh), const Radius.circular(1.5)),
        Paint()..color = col);
    c.drawRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(-bw / 2, -bh, bw, bh), const Radius.circular(1.5)),
        Paint()..color = _ol.withOpacity(0.18)
          ..style = PaintingStyle.stroke..strokeWidth = 1.2);
    // Page edge highlight
    c.drawLine(Offset(-bw / 2 + 2, -1), Offset(bw / 2 - 2, -1),
        Paint()..color = Colors.white.withOpacity(0.1)..strokeWidth = 0.8);
    c.restore();
  }

  void _leaf(Canvas c, double x, double y, double a, double len, Color col) {
    c.save();
    c.translate(x, y);
    c.rotate(a);
    c.drawLine(Offset.zero, Offset(0, -len),
        Paint()..color = col..strokeWidth = 1.8..strokeCap = StrokeCap.round);
    c.drawOval(Rect.fromCenter(center: Offset(0, -len),
        width: 10, height: 6), Paint()..color = col);
    // Leaf vein
    c.drawLine(Offset(0, -len - 2), Offset(0, -len + 2),
        Paint()..color = Colors.white.withOpacity(0.08)..strokeWidth = 0.5);
    c.restore();
  }

  @override bool shouldRepaint(_RoomP o) => true;
}

class _TitleP extends CustomPainter {
  final _Pal p;
  const _TitleP(this.p);
  @override
  void paint(Canvas c, Size s) {
    final cx = s.width / 2, cy = s.height / 2;
    final st = GoogleFonts.gaegu(fontSize: 56, fontWeight: FontWeight.w700, letterSpacing: 10);
    final shTP = TextPainter(text: TextSpan(text: 'CEREBRO', style: st.copyWith(
        foreground: Paint()..color = _ol.withOpacity(0.3))),
        textDirection: TextDirection.ltr)..layout();
    final glTP = TextPainter(text: TextSpan(text: 'CEREBRO', style: st.copyWith(
        foreground: Paint()..color = p.titleGlow
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 20))),
        textDirection: TextDirection.ltr)..layout();
    final olTP = TextPainter(text: TextSpan(text: 'CEREBRO', style: st.copyWith(
        foreground: Paint()..style = PaintingStyle.stroke..strokeWidth = 9..color = _ol)),
        textDirection: TextDirection.ltr)..layout();
    final fiTP = TextPainter(text: TextSpan(text: 'CEREBRO', style: st.copyWith(
        color: p.title)), textDirection: TextDirection.ltr)..layout();
    final tx = cx - fiTP.width / 2, ty = cy - fiTP.height / 2;
    shTP.paint(c, Offset(tx + 3, ty + 3));
    glTP.paint(c, Offset(tx, ty));
    olTP.paint(c, Offset(tx, ty));
    fiTP.paint(c, Offset(tx, ty));
  }
  @override bool shouldRepaint(_TitleP o) => false;
}

