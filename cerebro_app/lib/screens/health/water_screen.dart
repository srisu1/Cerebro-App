import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cerebro_app/providers/auth_provider.dart';

// =============================================================================
// COLOR PALETTE (Pocket Love Aesthetic)
// =============================================================================
const _ombre1 = Color(0xFFFFFBF7);
const _ombre2 = Color(0xFFFFF8F3);
const _ombre3 = Color(0xFFFFF3EF);
const _ombre4 = Color(0xFFFEEDE9);
const _pawClr = Color(0xFFF8BCD0);
const _outline = Color(0xFF6E5848);
const _brown = Color(0xFF4E3828);
const _brownLt = Color(0xFF7A5840);
const _cardFill = Color(0xFFFFF8F4);
const _skyHdr = Color(0xFF9DD4F0);
const _skyLt = Color(0xFFB8E0F8);
const _greenHdr = Color(0xFFA8D5A3);
const _greenLt = Color(0xFFC2E8BC);
const _greenDk = Color(0xFF88B883);
const _goldHdr = Color(0xFFF0D878);
const _goldLt = Color(0xFFFFF0C0);
const _coralHdr = Color(0xFFF0A898);
const _coralLt = Color(0xFFF8C0B0);

// =============================================================================
// PAWPRINT BACKGROUND PAINTER
// =============================================================================
class _PawPrintBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _pawClr.withOpacity(0.08)
      ..isAntiAlias = true;
    const sp = 90.0;
    const rowShift = 45.0;
    const pawR = 10.0;
    const toeR = 4.0;
    const toeD = 9.0;

    for (double y = -sp; y < size.height + sp; y += sp) {
      final shift = ((y / sp).round() % 2 == 0) ? 0.0 : rowShift;
      for (double x = -sp + shift; x < size.width + sp; x += sp) {
        canvas.drawCircle(Offset(x, y), pawR, paint);
        for (double a = -0.7; a <= 0.7; a += 0.47) {
          canvas.drawCircle(
            Offset(x + toeD * math.cos(a - 1.1), y + toeD * math.sin(a - 1.1)),
            toeR,
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter old) => false;
}

// =============================================================================
// WATER DROP PAINTER
// =============================================================================
class _WaterDropPainter extends CustomPainter {
  final double fillLevel;
  final Color fillColor;
  final Color outlineColor;

  _WaterDropPainter({
    required this.fillLevel,
    required this.fillColor,
    required this.outlineColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const padding = 8.0;
    final w = size.width - (padding * 2);
    final h = size.height - (padding * 2);
    final cx = size.width / 2;
    final cy = size.height / 2;

    // Draw teardrop outline
    final outlinePath = _createTearDrop(cx, cy, w, h);
    canvas.drawPath(
      outlinePath,
      Paint()
        ..color = outlineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0,
    );

    // Draw filled water
    if (fillLevel > 0) {
      final fillPath = _createTearDropFill(cx, cy, w, h, fillLevel);
      canvas.drawPath(
        fillPath,
        Paint()
          ..color = fillColor
          ..style = PaintingStyle.fill,
      );
    }
  }

  Path _createTearDrop(double cx, double cy, double w, double h) {
    final path = Path();
    final topY = cy - (h / 2);
    final bottomY = cy + (h * 0.35);

    // Curve from top
    path.moveTo(cx, topY);
    path.cubicTo(cx - (w * 0.35), cy - (h * 0.15), cx - (w * 0.4), cy + (h * 0.1),
        cx - (w * 0.25), bottomY);
    // Bottom point
    path.lineTo(cx, cy + (h * 0.5));
    // Curve back to top
    path.cubicTo(cx + (w * 0.25), bottomY, cx + (w * 0.4), cy + (h * 0.1),
        cx + (w * 0.35), cy - (h * 0.15));
    path.close();

    return path;
  }

  Path _createTearDropFill(
      double cx, double cy, double w, double h, double fillLevel) {
    final path = Path();
    final topY = cy - (h / 2);
    final bottomY = cy + (h * 0.35);
    final maxHeight = cy + (h * 0.5);
    final fillHeight = topY + ((maxHeight - topY) * fillLevel);

    if (fillLevel >= 1.0) {
      return _createTearDrop(cx, cy, w, h);
    }

    // Simple fill rect clipped to teardrop
    final fillRect = Rect.fromLTRB(
      cx - (w * 0.4),
      fillHeight,
      cx + (w * 0.4),
      maxHeight,
    );

    path.moveTo(cx, fillHeight);
    path.cubicTo(cx - (w * 0.25), fillHeight + (bottomY - fillHeight) * 0.3,
        cx - (w * 0.4), cy + (h * 0.1), cx - (w * 0.25), bottomY);
    path.lineTo(cx, maxHeight);
    path.cubicTo(cx + (w * 0.25), bottomY, cx + (w * 0.4), cy + (h * 0.1),
        cx + (w * 0.25), fillHeight + (bottomY - fillHeight) * 0.3);
    path.close();

    return path;
  }

  @override
  bool shouldRepaint(_WaterDropPainter oldDelegate) {
    return oldDelegate.fillLevel != fillLevel;
  }
}

// =============================================================================
// WATER SCREEN WIDGET
// =============================================================================
class WaterScreen extends ConsumerStatefulWidget {
  const WaterScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<WaterScreen> createState() => _WaterScreenState();
}

class _WaterScreenState extends ConsumerState<WaterScreen>
    with TickerProviderStateMixin {
  late AnimationController _fillAnimController;
  late AnimationController _staggerAnimController;
  late Animation<double> _fillAnim;
  late Animation<double> _staggerAnim;

  int _todayGlasses = 0;
  final int _goal = 8;
  List<int> _history = [];
  bool _isLoading = true;
  String _currentTip = '';

  final List<String> _hydrationTips = [
    'Drinking water before meals aids digestion and reduces overeating',
    'Set a reminder every hour to stay consistently hydrated',
    'Warm water in the morning jumpstarts your metabolism',
    'Drink water before, during, and after exercise',
    'Infuse water with lemon for added vitamin C and flavor',
    'Staying hydrated improves skin elasticity and natural glow',
  ];

  @override
  void initState() {
    super.initState();

    _fillAnimController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fillAnim = Tween<double>(begin: 0, end: 0).animate(_fillAnimController);

    _staggerAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _staggerAnim = Tween<double>(begin: 0, end: 1).animate(_staggerAnimController);

    _pickRandomTip();
    _loadData();
  }

  @override
  void dispose() {
    _fillAnimController.dispose();
    _staggerAnimController.dispose();
    super.dispose();
  }

  void _pickRandomTip() {
    setState(() {
      _currentTip = _hydrationTips[math.Random().nextInt(_hydrationTips.length)];
    });
  }

  Future<void> _loadData() async {
    try {
      final apiService = ref.read(apiServiceProvider);

      // Fetch today's intake
      final todayResp = await apiService.get('/health/water/today');
      final todayData = todayResp.data as Map<String, dynamic>;
      final glasses = todayData['glasses'] ?? 0;

      // Fetch 7-day history
      final historyResp =
          await apiService.get('/health/water', queryParams: {'days': '7'});
      final historyData = historyResp.data as List<dynamic>;
      final hist = historyData.map((e) => (e as Map<String, dynamic>)['glasses'] as int).toList();

      setState(() {
        _todayGlasses = glasses;
        _history = hist;
        _isLoading = false;
      });

      _fillAnimController.forward();
      _staggerAnimController.forward();
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load water data: $e')),
        );
      }
    }
  }

  Future<void> _incrementGlass() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final newCount = _todayGlasses + 1;

      await apiService.post('/health/water', data: {'glasses': newCount});

      setState(() {
        _todayGlasses = newCount;
      });

      _fillAnimController.reset();
      _fillAnimController.forward();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  Future<void> _decrementGlass() async {
    if (_todayGlasses <= 0) return;

    try {
      final apiService = ref.read(apiServiceProvider);
      final newCount = _todayGlasses - 1;

      await apiService.post('/health/water', data: {'glasses': newCount});

      setState(() {
        _todayGlasses = newCount;
      });

      _fillAnimController.reset();
      _fillAnimController.forward();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = MediaQuery.of(context).size;
    final fillPercent = (_todayGlasses / _goal).clamp(0.0, 1.0);

    return Scaffold(
      backgroundColor: _ombre1,
      body: CustomPaint(
        painter: _PawPrintBg(),
        child: SafeArea(
          child: Stack(
            children: [
              // Scrollable content
              SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // AppBar
                    Row(
                      children: [
                        GestureDetector(
                          onTap: () => Navigator.pop(context),
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: _cardFill,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                  color: _outline.withOpacity(0.25), width: 2),
                            ),
                            child: const Icon(Icons.arrow_back_ios_new,
                                color: _outline, size: 18),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Text(
                          'Hydration',
                          style: GoogleFonts.gaegu(
                            fontSize: 26,
                            fontWeight: FontWeight.w700,
                            color: _brown,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Today's Intake Card
                    if (!_isLoading)
                      _buildTodayCard(context, fillPercent)
                    else
                      Container(
                        height: 280,
                        decoration: BoxDecoration(
                          color: _cardFill,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                              color: _outline.withOpacity(0.25), width: 2),
                        ),
                        child: const Center(
                          child: CircularProgressIndicator(color: _skyHdr),
                        ),
                      ),
                    const SizedBox(height: 20),

                    // Weekly Overview Card
                    if (!_isLoading) _buildWeeklyCard(),
                    const SizedBox(height: 20),

                    // Streak & Stats Card
                    if (!_isLoading) _buildStreakCard(),
                    const SizedBox(height: 20),

                    // Hydration Tips Banner
                    _buildTipsCard(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTodayCard(BuildContext context, double fillPercent) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline.withOpacity(0.25), width: 2),
        boxShadow: [
          BoxShadow(
            color: _outline.withOpacity(0.06),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Sky blue header strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _skyLt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Today\'s Intake',
              textAlign: TextAlign.center,
              style: GoogleFonts.gaegu(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _brown,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Water drop with fill animation
          SizedBox(
            width: 100,
            height: 140,
            child: AnimatedBuilder(
              animation: _fillAnim,
              builder: (context, child) {
                return CustomPaint(
                  painter: _WaterDropPainter(
                    fillLevel: fillPercent,
                    fillColor: _skyLt,
                    outlineColor: _outline,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),

          // Text: X / 8 glasses
          Text(
            '$_todayGlasses / $_goal glasses',
            style: GoogleFonts.gaegu(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: _brown,
            ),
          ),
          const SizedBox(height: 4),

          // Progress ring and percentage
          Text(
            '${(fillPercent * 100).toStringAsFixed(0)}% of daily goal',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _brownLt,
            ),
          ),
          const SizedBox(height: 20),

          // 8 glass icons row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(
              _goal,
              (i) {
                final isFilled = i < _todayGlasses;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Container(
                    width: 28,
                    height: 40,
                    decoration: BoxDecoration(
                      color: isFilled ? _skyLt : Colors.transparent,
                      border: Border.all(
                        color: _outline.withOpacity(0.4),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(6),
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 24),

          // +/- buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Minus button
              GestureDetector(
                onTap: _decrementGlass,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _skyLt,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _outline.withOpacity(0.08),
                        offset: const Offset(0, 2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.remove, color: Colors.white, size: 24),
                ),
              ),
              const SizedBox(width: 32),
              // Plus button
              GestureDetector(
                onTap: _incrementGlass,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: _skyHdr,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: _outline.withOpacity(0.08),
                        offset: const Offset(0, 2),
                        blurRadius: 6,
                      ),
                    ],
                  ),
                  child: const Icon(Icons.add, color: Colors.white, size: 24),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyCard() {
    final days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
    final maxGlasses = (_history.isEmpty ? 8 : _history.reduce((a, b) => a > b ? a : b)).toDouble();

    // Pad history to 7 days if needed
    final paddedHistory = List<int>.from(_history);
    while (paddedHistory.length < 7) {
      paddedHistory.insert(0, 0);
    }
    if (paddedHistory.length > 7) {
      paddedHistory.removeRange(0, paddedHistory.length - 7);
    }

    final avgGlasses = paddedHistory.isEmpty
        ? 0.0
        : paddedHistory.reduce((a, b) => a + b) / paddedHistory.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline.withOpacity(0.25), width: 2),
        boxShadow: [
          BoxShadow(
            color: _outline.withOpacity(0.06),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Green header strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _greenLt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Weekly Overview',
              textAlign: TextAlign.center,
              style: GoogleFonts.gaegu(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _brown,
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Bar chart
          SizedBox(
            height: 160,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(
                7,
                (i) {
                  final glasses = paddedHistory[i];
                  final height =
                      (glasses / (maxGlasses > 0 ? maxGlasses : 1)) * 120;
                  final metGoal = glasses >= _goal;

                  return Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Container(
                        width: 28,
                        height: height,
                        decoration: BoxDecoration(
                          color: metGoal ? _greenHdr : _coralHdr,
                          borderRadius: const BorderRadius.only(
                            topLeft: Radius.circular(8),
                            topRight: Radius.circular(8),
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: (metGoal ? _greenHdr : _coralHdr)
                                  .withOpacity(0.2),
                              offset: const Offset(0, 2),
                              blurRadius: 4,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        days[i][0],
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _brownLt,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Average text
          Center(
            child: Text(
              'Average: ${avgGlasses.toStringAsFixed(1)} glasses/day',
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _brownLt,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStreakCard() {
    // Calculate streak (simplified: count consecutive days at end of history)
    int streak = 0;
    for (int i = _history.length - 1; i >= 0; i--) {
      if (_history[i] >= _goal) {
        streak++;
      } else {
        break;
      }
    }

    final weekGoalsMet =
        _history.where((g) => g >= _goal).length;
    // Compute longest consecutive run of goal-met days from actual
    // history instead of a hardcoded 14 — nothing in this app should
    // be static. Returns 0 when there's no history yet.
    int bestStreak = 0;
    int running = 0;
    for (final g in _history) {
      if (g >= _goal) {
        running++;
        if (running > bestStreak) bestStreak = running;
      } else {
        running = 0;
      }
    }
    final avgDaily = _history.isEmpty
        ? 0.0
        : _history.reduce((a, b) => a + b) / _history.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline.withOpacity(0.25), width: 2),
        boxShadow: [
          BoxShadow(
            color: _outline.withOpacity(0.06),
            offset: const Offset(0, 4),
            blurRadius: 12,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Gold header strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              color: _goldLt,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'Achievements',
              textAlign: TextAlign.center,
              style: GoogleFonts.gaegu(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: _brown,
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Streak stat
          _buildStatRow('Current Streak', '$streak days', _goldHdr),
          const SizedBox(height: 12),

          _buildStatRow('Goal Met This Week', '$weekGoalsMet / 7 days', _greenHdr),
          const SizedBox(height: 12),

          _buildStatRow('Best Streak Ever', '$bestStreak days', _coralHdr),
          const SizedBox(height: 12),

          _buildStatRow('Average Daily', '${avgDaily.toStringAsFixed(1)} glasses', _skyHdr),
        ],
      ),
    );
  }

  Widget _buildStatRow(String label, String value, Color bgColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: _brownLt,
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: bgColor.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: _brown,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTipsCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _greenLt,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _outline.withOpacity(0.06),
            offset: const Offset(0, 2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Hydration Tip',
                style: GoogleFonts.gaegu(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: _brown,
                ),
              ),
              GestureDetector(
                onTap: _pickRandomTip,
                child: Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child:
                      const Icon(Icons.refresh, color: _brown, size: 16),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            _currentTip,
            style: GoogleFonts.nunito(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _brown,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}
