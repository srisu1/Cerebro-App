import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'dart:math' as math;

// color palette
const _ombre1 = Color(0xFFFFFBF7);
const _ombre2 = Color(0xFFFFF8F3);
const _ombre3 = Color(0xFFFFF3EF);
const _ombre4 = Color(0xFFFEEDE9);
const _pawClr = Color(0xFFF8BCD0);
const _outline = Color(0xFF6E5848);
const _brown = Color(0xFF4E3828);
const _brownLt = Color(0xFF7A5840);
const _cardFill = Color(0xFFFFF8F4);
const _coralHdr = Color(0xFFF0A898);
const _coralLt = Color(0xFFF8C0B0);
const _greenHdr = Color(0xFFA8D5A3);
const _greenDk = Color(0xFF88B883);
const _goldHdr = Color(0xFFF0D878);
const _goldDk = Color(0xFFD0B048);
const _purpleHdr = Color(0xFFCDA8D8);
const _purpleLt = Color(0xFFD8C0E8);
const _skyHdr = Color(0xFF9DD4F0);

// background painter
class _PawPrintBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _pawClr.withOpacity(0.08)
      ..isAntiAlias = true;

    const pawPositions = [
      (50.0, 100.0),
      (200.0, 250.0),
      (150.0, 400.0),
      (300.0, 150.0),
      (100.0, 500.0),
    ];

    for (final (x, y) in pawPositions) {
      _drawPawprint(canvas, Offset(x, y), paint);
    }
  }

  void _drawPawprint(Canvas canvas, Offset center, Paint paint) {
    const padSize = 18.0;
    const toeSize = 8.0;

    // Main pad
    canvas.drawCircle(center, padSize, paint);

    // Toes
    const toeDistance = 35.0;
    canvas.drawCircle(center + Offset(0, -toeDistance), toeSize, paint);
    canvas.drawCircle(center + Offset(toeDistance * 0.707, -toeDistance * 0.5), toeSize, paint);
    canvas.drawCircle(center + Offset(toeDistance * 0.707, toeDistance * 0.5), toeSize, paint);
    canvas.drawCircle(center + Offset(0, toeDistance), toeSize, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class SleepScreen extends ConsumerStatefulWidget {
  const SleepScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SleepScreen> createState() => _SleepScreenState();
}

class _SleepScreenState extends ConsumerState<SleepScreen> with TickerProviderStateMixin {
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _bedtime = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 0);
  int _qualityRating = 0;
  final TextEditingController _notesController = TextEditingController();
  bool _isLoading = false;

  List<dynamic> _sleepHistory = [];
  bool _historyLoading = true;

  late AnimationController _cardAnimController;
  late Animation<Offset> _cardSlideAnimation;

  @override
  void initState() {
    super.initState();
    _cardAnimController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _cardSlideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _cardAnimController, curve: Curves.easeOutCubic));
    _cardAnimController.forward();

    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSleepHistory());
  }

  @override
  void dispose() {
    _cardAnimController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _loadSleepHistory() async {
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get('/health/sleep', queryParams: {'limit': '30'});

      if (mounted) {
        setState(() {
          final data = response.data;
          _sleepHistory = data is List ? List<Map<String, dynamic>>.from(data) : [];
          _historyLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _historyLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error loading sleep history: $e')),
        );
      }
    }
  }

  Future<void> _logSleep() async {
    if (_qualityRating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a quality rating')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final bedtimeDateTime =
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _bedtime.hour, _bedtime.minute);
      final wakeTimeDateTime =
          DateTime(_selectedDate.year, _selectedDate.month, _selectedDate.day, _wakeTime.hour, _wakeTime.minute);

      final bedtimeIso = bedtimeDateTime.toUtc().toIso8601String();
      final wakeTimeIso = wakeTimeDateTime.toUtc().toIso8601String();

      final payload = {
        'date': dateStr,
        'bedtime': bedtimeIso,
        'wake_time': wakeTimeIso,
        'quality_rating': _qualityRating,
        'notes': _notesController.text.isEmpty ? null : _notesController.text,
      };

      await apiService.post('/health/sleep', data: payload);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Sleep logged successfully!')),
        );
        _selectedDate = DateTime.now();
        _bedtime = const TimeOfDay(hour: 23, minute: 0);
        _wakeTime = const TimeOfDay(hour: 7, minute: 0);
        _qualityRating = 0;
        _notesController.clear();
        await _loadSleepHistory();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging sleep: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now(),
    );
    if (picked != null && mounted) {
      setState(() => _selectedDate = picked);
    }
  }

  Future<void> _pickBedtime() async {
    final picked = await showTimePicker(context: context, initialTime: _bedtime);
    if (picked != null && mounted) {
      setState(() => _bedtime = picked);
    }
  }

  Future<void> _pickWakeTime() async {
    final picked = await showTimePicker(context: context, initialTime: _wakeTime);
    if (picked != null && mounted) {
      setState(() => _wakeTime = picked);
    }
  }

  Color _hoursColor(double hours) {
    if (hours < 6) return Colors.red.shade300;
    if (hours >= 6 && hours < 7) return _goldHdr;
    if (hours >= 7 && hours <= 9) return _greenHdr;
    return Colors.red.shade300;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [_ombre1, _ombre2, _ombre3],
              ),
            ),
            child: CustomPaint(
              painter: _PawPrintBg(),
              child: Container(),
            ),
          ),
          // Content
          SafeArea(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back, color: _brown),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          'Sleep Tracker',
                          style: GoogleFonts.gaegu(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: _brown,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Icon(Icons.nightlight_round, color: _coralHdr, size: 28),
                      ],
                    ),
                    const SizedBox(height: 28),

                    // Log Sleep Card
                    SlideTransition(
                      position: _cardSlideAnimation,
                      child: _buildLogSleepCard(),
                    ),
                    const SizedBox(height: 24),

                    // Stats Card
                    _buildStatsCard(),
                    const SizedBox(height: 24),

                    // Sleep History
                    Text(
                      'Sleep History',
                      style: GoogleFonts.gaegu(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: _brown,
                      ),
                    ),
                    const SizedBox(height: 12),
                    _historyLoading
                        ? const SizedBox(
                            height: 200,
                            child: Center(child: CircularProgressIndicator(color: _coralHdr)),
                          )
                        : _sleepHistory.isEmpty
                            ? _buildEmptyHistoryPlaceholder()
                            : ListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _sleepHistory.length,
                                itemBuilder: (context, index) => _buildHistoryCard(_sleepHistory[index], index),
                              ),
                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogSleepCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardFill,
        border: Border.all(color: _outline, width: 2),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: _outline,
            offset: const Offset(0, 4),
            blurRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Log Tonight\'s Sleep',
            style: GoogleFonts.gaegu(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _brown,
            ),
          ),
          const SizedBox(height: 20),

          // Date Picker
          _buildPickerRow(
            label: 'Date',
            value: DateFormat('MMM dd, yyyy').format(_selectedDate),
            onTap: _pickDate,
            icon: Icons.calendar_today,
          ),
          const SizedBox(height: 16),

          // Bedtime Picker
          _buildPickerRow(
            label: 'Bedtime',
            value: _bedtime.format(context),
            onTap: _pickBedtime,
            icon: Icons.bedtime,
          ),
          const SizedBox(height: 16),

          // Wake Time Picker
          _buildPickerRow(
            label: 'Wake Time',
            value: _wakeTime.format(context),
            onTap: _pickWakeTime,
            icon: Icons.wb_sunny,
          ),
          const SizedBox(height: 20),

          // Quality Rating
          Text(
            'Sleep Quality',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: _brownLt,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              final isSelected = index < _qualityRating;
              return GestureDetector(
                onTap: () => setState(() => _qualityRating = index + 1),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    Icons.star,
                    size: 28,
                    color: isSelected ? _goldHdr : _brownLt.withOpacity(0.2),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),

          // Notes
          TextField(
            controller: _notesController,
            maxLines: 3,
            style: GoogleFonts.nunito(color: _brown, fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Notes (optional)',
              hintStyle: GoogleFonts.nunito(color: _brownLt.withOpacity(0.5)),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _outline, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _outline, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _coralHdr, width: 2),
              ),
              filled: true,
              fillColor: _ombre1,
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 24),

          // Log Sleep Button
          SizedBox(
            width: double.infinity,
            child: _build3DButton(
              label: 'Log Sleep',
              onPressed: _isLoading ? null : _logSleep,
              bgColor: _coralHdr,
              isLoading: _isLoading,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPickerRow({
    required String label,
    required String value,
    required VoidCallback onTap,
    required IconData icon,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: _ombre2,
          border: Border.all(color: _outline, width: 1.5),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            Icon(icon, color: _coralHdr, size: 18),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _brownLt,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    value,
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _brown,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: _brownLt, size: 20),
          ],
        ),
      ),
    );
  }

  Widget _build3DButton({
    required String label,
    required VoidCallback? onPressed,
    required Color bgColor,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Stack(
        children: [
          // shadow (3D effect)
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: _outline,
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          // button
          Container(
            height: 44,
            decoration: BoxDecoration(
              color: isLoading ? bgColor.withOpacity(0.6) : bgColor,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(_brown),
                      ),
                    )
                  : Text(
                      label,
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _brown,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    if (_sleepHistory.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _cardFill,
          border: Border.all(color: _outline, width: 2),
          borderRadius: BorderRadius.circular(22),
          boxShadow: [BoxShadow(color: _outline, offset: const Offset(0, 4), blurRadius: 0)],
        ),
        child: Center(
          child: Text(
            'Log your first sleep to see stats',
            style: GoogleFonts.nunito(color: _brownLt, fontSize: 14),
          ),
        ),
      );
    }

    double totalHours = 0;
    int totalRating = 0;
    for (final entry in _sleepHistory) {
      totalHours += double.tryParse(entry['total_hours']?.toString() ?? '0') ?? 0;
      totalRating += (entry['quality_rating'] as int?) ?? 0;
    }
    final avgHours = _sleepHistory.isNotEmpty ? totalHours / _sleepHistory.length : 0.0;
    final avgQuality = _sleepHistory.isNotEmpty ? (totalRating / _sleepHistory.length).round() : 0;

    final lastSevenDays =
        _sleepHistory.take(7).where((e) => DateTime.parse(e['date'] as String).isAfter(
              DateTime.now().subtract(const Duration(days: 7)),
            ));
    final consistencyScore = lastSevenDays.isNotEmpty ? ((lastSevenDays.length / 7) * 100).toStringAsFixed(0) : '0';

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cardFill,
        border: Border.all(color: _outline, width: 2),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [BoxShadow(color: _outline, offset: const Offset(0, 4), blurRadius: 0)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Sleep Stats',
            style: GoogleFonts.gaegu(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: _brown,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem(
                label: 'Avg Sleep',
                value: avgHours.toStringAsFixed(1),
                unit: 'hrs',
                color: _greenHdr,
              ),
              _buildStatItem(
                label: 'Avg Quality',
                value: avgQuality.toString(),
                unit: '/ 5',
                color: _goldHdr,
              ),
              _buildStatItem(
                label: 'Consistency',
                value: consistencyScore,
                unit: '%',
                color: _skyHdr,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Column(
      children: [
        Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _brownLt,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.nunito(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          unit,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _brownLt,
          ),
        ),
      ],
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> entry, int index) {
    final date = DateTime.parse(entry['date'] as String);
    final totalHours = double.tryParse(entry['total_hours']?.toString() ?? '0') ?? 0;
    final quality = entry['quality_rating'] as int? ?? 0;
    final notes = entry['notes'] as String?;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _cardFill,
          border: Border.all(color: _outline, width: 1.5),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: _outline, offset: const Offset(0, 3), blurRadius: 0)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              DateFormat('EEE, MMM dd, yyyy').format(date),
              style: GoogleFonts.nunito(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: _brown,
              ),
            ),
            const SizedBox(height: 10),

            // time range
            Row(
              children: [
                Icon(Icons.bedtime, size: 16, color: _coralHdr),
                const SizedBox(width: 6),
                Text(
                  '${entry['bedtime'] != null ? TimeOfDay.fromDateTime(DateTime.parse(entry['bedtime'] as String)).format(context) : 'N/A'} → '
                  '${entry['wake_time'] != null ? TimeOfDay.fromDateTime(DateTime.parse(entry['wake_time'] as String)).format(context) : 'N/A'}',
                  style: GoogleFonts.nunito(fontSize: 13, color: _brownLt),
                ),
              ],
            ),
            const SizedBox(height: 10),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: _hoursColor(totalHours),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${totalHours.toStringAsFixed(1)} hrs',
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: _brown,
                    ),
                  ),
                ),
                Row(
                  children: List.generate(5, (i) {
                    return Icon(
                      Icons.star,
                      size: 14,
                      color: i < quality ? _goldHdr : _brownLt.withOpacity(0.2),
                    );
                  }),
                ),
              ],
            ),

            if (notes != null && notes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Text(
                  'Notes: $notes',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    color: _brownLt,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyHistoryPlaceholder() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _ombre2,
        border: Border.all(color: _outline, width: 1.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Center(
        child: Column(
          children: [
            Icon(Icons.nightlight_round, size: 48, color: _pawClr),
            const SizedBox(height: 12),
            Text(
              'No sleep logged yet',
              style: GoogleFonts.nunito(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _brownLt,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Log your first sleep above to see history',
              style: GoogleFonts.nunito(
                fontSize: 13,
                color: _brownLt.withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
