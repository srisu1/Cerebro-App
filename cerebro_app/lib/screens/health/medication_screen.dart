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
const _sageHdr = Color(0xFF90C8A0);
const _sageLt = Color(0xFFB0D8B8);
const _sageDk = Color(0xFF70A880);

class MedicationScreen extends ConsumerStatefulWidget {
  const MedicationScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MedicationScreen> createState() => _MedicationScreenState();
}

class _MedicationScreenState extends ConsumerState<MedicationScreen>
    with TickerProviderStateMixin {
  late AnimationController _animationController;
  List<Map<String, dynamic>> _medications = [];
  List<Map<String, dynamic>> _recentLogs = [];
  List<Map<String, dynamic>> _adherenceStats = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _loadData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);
    try {
      final api = ref.read(apiServiceProvider);

      final medsResponse = await api.get('/health/medications');
      final logsResponse = await api.get('/health/medications/logs');
      final adherenceResponse = await api.get('/health/medications/adherence');

      setState(() {
        _medications = List<Map<String, dynamic>>.from(medsResponse.data ?? []);
        _recentLogs = List<Map<String, dynamic>>.from(logsResponse.data ?? [])
            .take(5)
            .toList();
        _adherenceStats = List<Map<String, dynamic>>.from(adherenceResponse.data ?? []);
        _isLoading = false;
      });

      _animationController.forward();
    } catch (e) {
      setState(() => _isLoading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load medications: $e')),
        );
      }
    }
  }

  void _showAddMedicationDialog() {
    String name = '';
    String dosage = '';
    String frequency = 'daily';
    bool enableReminder = true;

    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: _cardFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: _outline.withOpacity(0.25), width: 2),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add Medication',
                  style: GoogleFonts.gaegu(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: _brown,
                  ),
                ),
                const SizedBox(height: 20),
                TextField(
                  onChanged: (val) => name = val,
                  decoration: InputDecoration(
                    labelText: 'Medication Name',
                    labelStyle: GoogleFonts.nunito(
                      color: _brownLt,
                      fontWeight: FontWeight.w600,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: _outline.withOpacity(0.25), width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _coralHdr, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  style: GoogleFonts.nunito(
                    color: _brown,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  onChanged: (val) => dosage = val,
                  decoration: InputDecoration(
                    labelText: 'Dosage (e.g., 500mg)',
                    labelStyle: GoogleFonts.nunito(
                      color: _brownLt,
                      fontWeight: FontWeight.w600,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide:
                          BorderSide(color: _outline.withOpacity(0.25), width: 2),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _coralHdr, width: 2),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                  ),
                  style: GoogleFonts.nunito(
                    color: _brown,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Frequency',
                  style: GoogleFonts.nunito(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: _brown,
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _outline.withOpacity(0.25),
                      width: 2,
                    ),
                  ),
                  child: StatefulBuilder(
                    builder: (context, setDialogState) => DropdownButton<String>(
                      value: frequency,
                      isExpanded: true,
                      underline: const SizedBox(),
                      borderRadius: BorderRadius.circular(12),
                      items: ['daily', 'weekly', 'as_needed']
                          .map((f) => DropdownMenuItem(
                                value: f,
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 12,
                                  ),
                                  child: Text(
                                    f.replaceAll('_', ' ').toUpperCase(),
                                    style: GoogleFonts.nunito(
                                      color: _brown,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ))
                          .toList(),
                      onChanged: (val) => setDialogState(
                        () => frequency = val ?? 'daily',
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    StatefulBuilder(
                      builder: (context, setDialogState) => Checkbox(
                        value: enableReminder,
                        onChanged: (val) => setDialogState(
                          () => enableReminder = val ?? true,
                        ),
                        fillColor: MaterialStateProperty.all(_coralHdr),
                        side: BorderSide(
                          color: _outline.withOpacity(0.25),
                          width: 2,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Enable reminders',
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _brown,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: Text(
                        'Cancel',
                        style: GoogleFonts.nunito(
                          color: _brownLt,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _coralHdr,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                      ),
                      onPressed: () => _addMedication(name, dosage, frequency,
                          enableReminder, context),
                      child: Text(
                        'Add',
                        style: GoogleFonts.nunito(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _addMedication(
    String name,
    String dosage,
    String frequency,
    bool enableReminder,
    BuildContext context,
  ) async {
    if (name.isEmpty || dosage.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    try {
      final api = ref.read(apiServiceProvider);
      await api.post('/health/medications', data: {
        'name': name,
        'dosage': dosage,
        'frequency': frequency,
        'reminder_enabled': enableReminder,
      });

      if (mounted) {
        Navigator.pop(context);
        _loadData();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to add medication: $e')),
        );
      }
    }
  }

  Future<void> _logMedicationAction(
    String medicationId,
    String action,
  ) async {
    try {
      final api = ref.read(apiServiceProvider);
      await api.post('/health/medications/log', data: {
        'medication_id': medicationId,
        'scheduled_time': DateTime.now().toIso8601String(),
        'status': action,
        'taken_at': action == 'taken' ? DateTime.now().toIso8601String() : null,
      });

      _loadData();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to log action: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        Navigator.pop(context);
        return false;
      },
      child: Scaffold(
        backgroundColor: Colors.transparent,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: _brown),
            onPressed: () => Navigator.pop(context),
          ),
          title: Text(
            'Medications',
            style: GoogleFonts.gaegu(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _brown,
            ),
          ),
          centerTitle: true,
        ),
        floatingActionButton: FloatingActionButton(
          backgroundColor: _coralHdr,
          onPressed: _showAddMedicationDialog,
          child: const Icon(Icons.add, color: Colors.white),
        ),
        body: Stack(
          children: [
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [_ombre1, _ombre2, _ombre3, _ombre4],
                  ),
                ),
              ),
            ),
            Positioned.fill(
              child: CustomPaint(painter: _PawPrintBg()),
            ),
            RefreshIndicator(
              onRefresh: _loadData,
              backgroundColor: _cardFill,
              color: _coralHdr,
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        color: _coralHdr,
                      ),
                    )
                  : SingleChildScrollView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Column(
                        children: [
                          // Adherence Stats Card
                          if (_adherenceStats.isNotEmpty)
                            _buildAdherenceCard(),
                          const SizedBox(height: 20),

                          // Active Medications
                          if (_medications.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text(
                                    'Active Medications',
                                    style: GoogleFonts.gaegu(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: _brown,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ..._medications.asMap().entries.map(
                                      (entry) => _buildMedicationCard(
                                        entry.value,
                                        entry.key,
                                      ),
                                    ),
                              ],
                            ),
                          const SizedBox(height: 20),

                          // Recent Logs
                          if (_recentLogs.isNotEmpty)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Text(
                                    'Recent Logs',
                                    style: GoogleFonts.gaegu(
                                      fontSize: 20,
                                      fontWeight: FontWeight.w700,
                                      color: _brown,
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                ..._recentLogs.map(
                                  (log) => _buildLogItem(log),
                                ),
                              ],
                            ),
                          const SizedBox(height: 20),

                          if (_medications.isEmpty && _recentLogs.isEmpty)
                            Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const SizedBox(height: 40),
                                  Icon(
                                    Icons.medication,
                                    size: 64,
                                    color: _pawClr.withOpacity(0.3),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    'No medications yet',
                                    style: GoogleFonts.nunito(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: _brownLt,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    'Add your first medication to get started',
                                    style: GoogleFonts.nunito(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: _brownLt,
                                    ),
                                  ),
                                  const SizedBox(height: 40),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAdherenceCard() {
    // Aggregate from list of per-medication adherence stats
    int taken = 0, skipped = 0, delayed = 0, totalLogs = 0;
    for (final stat in _adherenceStats) {
      taken += (stat['taken_count'] as int?) ?? 0;
      skipped += (stat['skipped_count'] as int?) ?? 0;
      delayed += (stat['delayed_count'] as int?) ?? 0;
      totalLogs += (stat['total_logs'] as int?) ?? 0;
    }
    final overallAdherence = totalLogs > 0 ? (taken / totalLogs * 100) : 0.0;

    return _animateChild(
      0,
      Container(
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
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_greenHdr, _greenLt],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  Text(
                    'Adherence Rate',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _brownLt,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${overallAdherence.toStringAsFixed(1)}%',
                    style: GoogleFonts.gaegu(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: _brown,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      Column(
                        children: [
                          Text(
                            '$taken',
                            style: GoogleFonts.gaegu(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: _greenDk,
                            ),
                          ),
                          Text(
                            'Taken',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _brownLt,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '$skipped',
                            style: GoogleFonts.gaegu(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: _coralHdr,
                            ),
                          ),
                          Text(
                            'Skipped',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _brownLt,
                            ),
                          ),
                        ],
                      ),
                      Column(
                        children: [
                          Text(
                            '$delayed',
                            style: GoogleFonts.gaegu(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: _goldHdr,
                            ),
                          ),
                          Text(
                            'Delayed',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _brownLt,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMedicationCard(Map<String, dynamic> med, int index) {
    final name = med['name'] as String? ?? 'Unknown';
    final dosage = med['dosage'] as String? ?? '';
    final frequency = med['frequency'] as String? ?? 'daily';
    final streak = med['streak'] as int? ?? 0;

    return _animateChild(
      index + 1,
      Container(
        margin: const EdgeInsets.only(bottom: 12),
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
          children: [
            ClipRRect(
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(18),
              ),
              child: Container(
                height: 6,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_coralHdr, _coralLt],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: GoogleFonts.gaegu(
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                                color: _brown,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              dosage,
                              style: GoogleFonts.nunito(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: _brownLt,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: _coralLt.withOpacity(0.4),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _coralHdr.withOpacity(0.5),
                            width: 1.5,
                          ),
                        ),
                        child: Text(
                          frequency.replaceAll('_', ' ').toUpperCase(),
                          style: GoogleFonts.nunito(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _brown,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.local_fire_department,
                        size: 16,
                        color: _goldHdr,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '$streak day streak',
                        style: GoogleFonts.nunito(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: _brownLt,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildActionButton('Take', _greenHdr, () {
                        _logMedicationAction(med['id'] as String? ?? '', 'taken');
                      }),
                      _buildActionButton('Skip', _coralHdr, () {
                        _logMedicationAction(med['id'] as String? ?? '', 'skipped');
                      }),
                      _buildActionButton('Delay', _goldHdr, () {
                        _logMedicationAction(med['id'] as String? ?? '', 'delayed');
                      }),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.2),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: color.withOpacity(0.4),
            width: 1.5,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.nunito(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: _brown,
          ),
        ),
      ),
    );
  }

  Widget _buildLogItem(Map<String, dynamic> log) {
    final medName = log['medicationName'] as String? ?? 'Unknown';
    final action = log['action'] as String? ?? 'unknown';
    final timestamp = log['timestamp'] as String? ?? '';
    final sideEffects = log['sideEffects'] as String?;

    IconData actionIcon = Icons.help;
    Color actionColor = _brownLt;

    if (action == 'taken') {
      actionIcon = Icons.check_circle;
      actionColor = _greenDk;
    } else if (action == 'skipped') {
      actionIcon = Icons.cancel;
      actionColor = _coralHdr;
    } else if (action == 'delayed') {
      actionIcon = Icons.schedule;
      actionColor = _goldHdr;
    }

    String formattedTime = '';
    if (timestamp.isNotEmpty) {
      try {
        final dt = DateTime.parse(timestamp);
        formattedTime = DateFormat('h:mm a').format(dt);
      } catch (e) {
        formattedTime = timestamp;
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outline.withOpacity(0.15), width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                actionIcon,
                size: 20,
                color: actionColor,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      medName,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: _brown,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          action.replaceAll('_', ' ').toUpperCase(),
                          style: GoogleFonts.nunito(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: actionColor,
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (formattedTime.isNotEmpty)
                          Text(
                            '• $formattedTime',
                            style: GoogleFonts.nunito(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: _brownLt,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (sideEffects != null && sideEffects.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Side effects: $sideEffects',
              style: GoogleFonts.nunito(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: _brownLt,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _animateChild(int index, Widget child) {
    final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Interval(
          (index * 80) / 600,
          ((index * 80) + 300) / 600,
          curve: Curves.easeOut,
        ),
      ),
    );

    return AnimatedBuilder(
      animation: animation,
      builder: (context, child) {
        return Opacity(
          opacity: animation.value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - animation.value)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}

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
