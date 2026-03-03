import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:cerebro_app/providers/auth_provider.dart';

// Palette
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
const _greenLt = Color(0xFFC2E8BC);
const _greenDk = Color(0xFF88B883);
const _goldHdr = Color(0xFFF0D878);
const _goldLt = Color(0xFFFFF0C0);
const _purpleHdr = Color(0xFFCDA8D8);
const _purpleLt = Color(0xFFD8C0E8);
const _skyHdr = Color(0xFF9DD4F0);
const _skyLt = Color(0xFFB8E0F8);
const _redHdr = Color(0xFFE89090);
const _redLt = Color(0xFFF0B0B0);
const _sageHdr = Color(0xFF90C8A0);
const _sageLt = Color(0xFFB0D8B8);

const _symptomIcons = {
  'Headache': '🤕',
  'Fatigue': '😴',
  'Back Pain': '🔙',
  'Eye Strain': '👁',
  'Nausea': '🤢',
  'Dizziness': '💫',
  'Stomach Pain': '🤮',
  'Other': '🩹',
};

const _symptomTypes = [
  'Headache',
  'Fatigue',
  'Back Pain',
  'Eye Strain',
  'Nausea',
  'Dizziness',
  'Stomach Pain',
  'Other',
];

const _triggerOptions = [
  'Studying',
  'Lack of sleep',
  'Stress',
  'Caffeine',
  'Dehydration',
  'Screen time',
  'Poor posture',
  'Skipped meals',
];

const _reliefOptions = [
  'Rest',
  'Medication',
  'Water',
  'Stretching',
  'Break',
  'Fresh air',
  'Sleep',
  'Food',
];

class SymptomScreen extends ConsumerStatefulWidget {
  const SymptomScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<SymptomScreen> createState() => _SymptomScreenState();
}

class _SymptomScreenState extends ConsumerState<SymptomScreen>
    with TickerProviderStateMixin {
  late AnimationController _animController;
  late TextEditingController _notesCtrl;

  bool _isLoading = false;
  List<dynamic> _symptoms = [];
  Map<String, dynamic> _patterns = {};

  String? _selectedType;
  int _intensity = 5;
  int? _selectedDuration;
  final Set<String> _selectedTriggers = {};
  final Set<String> _selectedRelief = {};

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(duration: Duration(milliseconds: 600), vsync: this);
    _notesCtrl = TextEditingController();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadData());
  }

  @override
  void dispose() {
    _animController.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final historyRes = await api.get('/health/symptoms', queryParams: {'limit': '30'});
      final patternsRes = await api.get('/health/symptoms/patterns');

      if (mounted) {
        setState(() {
          _symptoms = List<Map<String, dynamic>>.from(historyRes.data ?? []);
          _patterns = Map<String, dynamic>.from(patternsRes.data ?? {});
          _isLoading = false;
        });
        _animController.forward();
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load symptoms: $e')),
      );
    }
  }

  Future<void> _logSymptom() async {
    if (_selectedType == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a symptom type')),
      );
      return;
    }

    final api = ref.read(apiServiceProvider);
    try {
      await api.post('/health/symptoms', data: {
        'symptom_type': _selectedType,
        'intensity': _intensity,
        'duration_minutes': _selectedDuration,
        'triggers': _selectedTriggers.toList(),
        'relief_methods': _selectedRelief.toList(),
        'notes': _notesCtrl.text.isNotEmpty ? _notesCtrl.text : null,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Symptom logged successfully!')),
        );
        _resetForm();
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log symptom: $e')),
        );
      }
    }
  }

  void _resetForm() {
    setState(() {
      _selectedType = null;
      _intensity = 5;
      _selectedDuration = null;
      _selectedTriggers.clear();
      _selectedRelief.clear();
      _notesCtrl.clear();
    });
  }

  Color _getIntensityColor(int intensity) {
    if (intensity <= 3) return _greenDk;
    if (intensity <= 6) return _goldHdr;
    if (intensity <= 8) return _coralHdr;
    return _redHdr;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ombre1,
      appBar: AppBar(
        backgroundColor: _ombre1,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: _brown),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Symptoms',
          style: GoogleFonts.gaegu(fontSize: 24, fontWeight: FontWeight.w700, color: _brown),
        ),
      ),
      body: Stack(
        children: [
          CustomPaint(
            painter: _PawPrintBg(),
            size: Size.infinite,
          ),
          RefreshIndicator(
            onRefresh: _loadData,
            color: _greenHdr,
            backgroundColor: _ombre2,
            child: _isLoading && _symptoms.isEmpty
                ? Center(
                    child: CircularProgressIndicator(
                      valueColor: AlwaysStoppedAnimation(_greenHdr),
                    ),
                  )
                : SingleChildScrollView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildQuickLogCard(),
                        const SizedBox(height: 20),
                        if (_symptoms.isNotEmpty) ...[
                          _buildStatsCard(),
                          const SizedBox(height: 20),
                          _buildPatternInsightsCard(),
                          const SizedBox(height: 20),
                          _buildRecentSymptoms(),
                        ] else
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 40),
                              child: Text(
                                'No symptoms logged yet.\nStart by logging your first symptom!',
                                textAlign: TextAlign.center,
                                style: GoogleFonts.nunito(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: _brownLt,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickLogCard() {
    return Card(
      elevation: 0,
      color: _cardFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _outline.withOpacity(0.25), width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.06), offset: const Offset(0, 4), blurRadius: 12)],
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_coralHdr, _coralLt],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.add_circle, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Quick Log',
                    style: GoogleFonts.gaegu(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Symptom Type',
                    style: GoogleFonts.gaegu(fontSize: 16, fontWeight: FontWeight.w700, color: _brown),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      border: Border.all(color: _outline.withOpacity(0.25), width: 1.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: _selectedType,
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      items: _symptomTypes.map((type) {
                        return DropdownMenuItem(
                          value: type,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            child: Text(
                              '${_symptomIcons[type]} $type',
                              style: GoogleFonts.nunito(fontSize: 14, color: _brown),
                            ),
                          ),
                        );
                      }).toList(),
                      onChanged: (val) => setState(() => _selectedType = val),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Intensity: $_intensity / 10',
                    style: GoogleFonts.gaegu(fontSize: 16, fontWeight: FontWeight.w700, color: _brown),
                  ),
                  const SizedBox(height: 8),
                  SliderTheme(
                    data: SliderThemeData(
                      trackHeight: 8,
                      thumbShape: RoundSliderThumbShape(enabledThumbRadius: 12),
                      activeTrackColor: _getIntensityColor(_intensity),
                      inactiveTrackColor: _getIntensityColor(_intensity).withOpacity(0.3),
                      thumbColor: _getIntensityColor(_intensity),
                    ),
                    child: Slider(
                      min: 1,
                      max: 10,
                      value: _intensity.toDouble(),
                      onChanged: (val) => setState(() => _intensity = val.toInt()),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Duration',
                    style: GoogleFonts.gaegu(fontSize: 16, fontWeight: FontWeight.w700, color: _brown),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [15, 30, 60, 120, 240].map((mins) {
                      final label = mins < 60 ? '${mins}min' : '${mins ~/ 60}hr';
                      final isSelected = _selectedDuration == mins;
                      return FilterChip(
                        selected: isSelected,
                        label: Text(
                          label,
                          style: GoogleFonts.nunito(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : _brown,
                          ),
                        ),
                        backgroundColor: Colors.transparent,
                        selectedColor: _greenHdr,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? _greenHdr : _outline.withOpacity(0.25),
                            width: 1.5,
                          ),
                        ),
                        onSelected: (_) => setState(() => _selectedDuration = isSelected ? null : mins),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Possible Triggers',
                    style: GoogleFonts.gaegu(fontSize: 16, fontWeight: FontWeight.w700, color: _brown),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _triggerOptions.map((trigger) {
                      final isSelected = _selectedTriggers.contains(trigger);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(
                          trigger,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : _brown,
                          ),
                        ),
                        backgroundColor: Colors.transparent,
                        selectedColor: _coralHdr,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? _coralHdr : _outline.withOpacity(0.25),
                            width: 1.5,
                          ),
                        ),
                        onSelected: (_) {
                          setState(() {
                            if (isSelected) {
                              _selectedTriggers.remove(trigger);
                            } else {
                              _selectedTriggers.add(trigger);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Relief Methods',
                    style: GoogleFonts.gaegu(fontSize: 16, fontWeight: FontWeight.w700, color: _brown),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _reliefOptions.map((relief) {
                      final isSelected = _selectedRelief.contains(relief);
                      return FilterChip(
                        selected: isSelected,
                        label: Text(
                          relief,
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : _brown,
                          ),
                        ),
                        backgroundColor: Colors.transparent,
                        selectedColor: _sageHdr,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: isSelected ? _sageHdr : _outline.withOpacity(0.25),
                            width: 1.5,
                          ),
                        ),
                        onSelected: (_) {
                          setState(() {
                            if (isSelected) {
                              _selectedRelief.remove(relief);
                            } else {
                              _selectedRelief.add(relief);
                            }
                          });
                        },
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Notes (optional)',
                    style: GoogleFonts.gaegu(fontSize: 16, fontWeight: FontWeight.w700, color: _brown),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _notesCtrl,
                    maxLines: 3,
                    decoration: InputDecoration(
                      hintText: 'Add any additional notes...',
                      hintStyle: GoogleFonts.nunito(color: _brownLt.withOpacity(0.6)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _outline.withOpacity(0.25)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: _greenHdr, width: 2),
                      ),
                      filled: true,
                      fillColor: _ombre2,
                    ),
                    style: GoogleFonts.nunito(color: _brown, fontSize: 14),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _logSymptom,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _greenHdr,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Log Symptom',
                        style: GoogleFonts.gaegu(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsCard() {
    final symptoms = List<dynamic>.from(_symptoms);
    if (symptoms.isEmpty) return const SizedBox.shrink();

    final typeCounts = <String, int>{};
    double totalIntensity = 0;

    for (var s in symptoms) {
      final type = s['symptom_type'] ?? 'Unknown';
      typeCounts[type] = (typeCounts[type] ?? 0) + 1;
      totalIntensity += (s['intensity'] ?? 5).toDouble();
    }

    final mostFrequent = typeCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
    final avgIntensity = (totalIntensity / symptoms.length).toStringAsFixed(1);

    return Card(
      elevation: 0,
      color: _cardFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _outline.withOpacity(0.25), width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.06), offset: const Offset(0, 4), blurRadius: 12)],
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_greenHdr, _greenLt],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.bar_chart, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Your Stats',
                    style: GoogleFonts.gaegu(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  _buildStatRow('Most Frequent', '${_symptomIcons[mostFrequent.key] ?? '📊'} ${mostFrequent.key} (${mostFrequent.value}x)'),
                  const SizedBox(height: 12),
                  _buildStatRow('Avg Intensity', '$avgIntensity / 10'),
                  const SizedBox(height: 12),
                  _buildStatRow('Total Logged', '${symptoms.length} symptoms'),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatRow(String label, String value) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w600, color: _brownLt)),
        Text(value, style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
      ],
    );
  }

  Widget _buildPatternInsightsCard() {
    final insights = _patterns['insights'] as List? ?? [];
    final topTriggers = _patterns['top_triggers'] as Map? ?? {};

    return Card(
      elevation: 0,
      color: _cardFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _outline.withOpacity(0.25), width: 2),
      ),
      child: Container(
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.06), offset: const Offset(0, 4), blurRadius: 12)],
        ),
        child: Column(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [_purpleHdr, _purpleLt],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
              child: Row(
                children: [
                  Icon(Icons.lightbulb, color: Colors.white, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Pattern Insights',
                    style: GoogleFonts.gaegu(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (insights.isNotEmpty) ...[
                    Text(
                      'Key Correlations',
                      style: GoogleFonts.gaegu(fontSize: 14, fontWeight: FontWeight.w700, color: _brown),
                    ),
                    const SizedBox(height: 8),
                    ...insights.asMap().entries.map((e) {
                      final idx = e.key;
                      final insight = e.value;
                      return Padding(
                        padding: EdgeInsets.only(bottom: idx < insights.length - 1 ? 8 : 12),
                        child: Row(
                          children: [
                            Icon(Icons.insights, size: 16, color: _purpleHdr),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                insight.toString(),
                                style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: _brown),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ] else
                    Text(
                      'Log more symptoms to see patterns.',
                      style: GoogleFonts.nunito(fontSize: 13, fontWeight: FontWeight.w600, color: _brownLt),
                    ),
                  if (topTriggers.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      'Top Triggers',
                      style: GoogleFonts.gaegu(fontSize: 14, fontWeight: FontWeight.w700, color: _brown),
                    ),
                    const SizedBox(height: 8),
                    ...topTriggers.entries.map((e) {
                      final trigger = e.key;
                      final percent = ((e.value as num).toDouble() * 100).toStringAsFixed(0);
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  trigger,
                                  style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w600, color: _brown),
                                ),
                                Text(
                                  '$percent%',
                                  style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: _brownLt),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(4),
                              child: LinearProgressIndicator(
                                value: (e.value as num).toDouble(),
                                minHeight: 6,
                                backgroundColor: _outline.withOpacity(0.1),
                                valueColor: AlwaysStoppedAnimation(_goldHdr),
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRecentSymptoms() {
    final symptoms = List<dynamic>.from(_symptoms).take(10);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Recent Symptoms',
          style: GoogleFonts.gaegu(fontSize: 18, fontWeight: FontWeight.w700, color: _brown),
        ),
        const SizedBox(height: 12),
        ...symptoms.map((symptom) {
          final type = symptom['symptom_type'] ?? 'Unknown';
          final intensity = symptom['intensity'] ?? 5;
          final triggers = List<String>.from(symptom['triggers'] ?? []);
          final timestamp = symptom['created_at'] ?? DateTime.now().toIso8601String();
          final dateTime = DateTime.tryParse(timestamp) ?? DateTime.now();
          final timeAgo = _getTimeAgo(dateTime);

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Card(
              elevation: 0,
              color: _cardFill,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: BorderSide(color: _outline.withOpacity(0.25), width: 1.5),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Text(
                          _symptomIcons[type] ?? '📊',
                          style: const TextStyle(fontSize: 24),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                type,
                                style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700, color: _brown),
                              ),
                              Text(
                                timeAgo,
                                style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: _brownLt),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          decoration: BoxDecoration(
                            color: _getIntensityColor(intensity).withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          child: Text(
                            '$intensity/10',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _getIntensityColor(intensity),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (triggers.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: triggers.map((trigger) {
                          return Container(
                            decoration: BoxDecoration(
                              color: _coralLt.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            child: Text(
                              trigger,
                              style: GoogleFonts.nunito(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _brown,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ],
    );
  }

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inSeconds < 60) return 'just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return DateFormat('MMM d').format(dateTime);
  }
}

class _PawPrintBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _pawClr.withOpacity(0.08)..isAntiAlias = true;
    const sp = 90.0, rowShift = 45.0, pawR = 10.0, toeR = 4.0, toeD = 9.0;

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
