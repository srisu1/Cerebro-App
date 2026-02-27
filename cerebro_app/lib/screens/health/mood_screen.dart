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
const _greenLt = Color(0xFFC2E8BC);
const _greenDk = Color(0xFF88B883);
const _goldHdr = Color(0xFFF0D878);
const _goldLt = Color(0xFFFFF0C0);
const _goldDk = Color(0xFFD0B048);
const _purpleHdr = Color(0xFFCDA8D8);
const _purpleLt = Color(0xFFD8C0E8);
const _skyHdr = Color(0xFF9DD4F0);
const _skyLt = Color(0xFFB8E0F8);

// mood emojis
const _moodEmojis = {
  'Happy': '😊',
  'Sad': '😢',
  'Anxious': '😰',
  'Calm': '😌',
  'Energetic': '⚡',
  'Tired': '😴',
  'Stressed': '😤',
  'Focused': '🎯',
};

const _moodColors = {
  'Happy': _goldHdr,
  'Sad': _skyHdr,
  'Anxious': _coralHdr,
  'Calm': _greenHdr,
  'Energetic': Color(0xFFFFB347),
  'Tired': _purpleHdr,
  'Stressed': Color(0xFFE07070),
  'Focused': _skyHdr,
};

const _contextTags = ['Study', 'Exercise', 'Social', 'Work', 'Relax', 'Outdoors'];

// state notifiers

class MoodDefinition {
  final String id;
  final String name;
  final int displayOrder;
  final String color;

  MoodDefinition({
    required this.id,
    required this.name,
    required this.displayOrder,
    required this.color,
  });

  factory MoodDefinition.fromJson(Map<String, dynamic> json) {
    return MoodDefinition(
      id: json['id'] as String,
      name: json['name'] as String,
      displayOrder: json['display_order'] as int,
      color: json['color'] as String? ?? '',
    );
  }
}

class MoodEntry {
  final String id;
  final String moodId;
  final String moodName;
  final DateTime timestamp;
  final String note;
  final int energyLevel;
  final List<String> contextTags;
  final DateTime createdAt;

  MoodEntry({
    required this.id,
    required this.moodId,
    required this.moodName,
    required this.timestamp,
    required this.note,
    required this.energyLevel,
    required this.contextTags,
    required this.createdAt,
  });

  factory MoodEntry.fromJson(Map<String, dynamic> json) {
    return MoodEntry(
      id: json['id'] as String,
      moodId: json['mood_id'] as String,
      moodName: json['mood_name'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      note: json['note'] as String? ?? '',
      energyLevel: json['energy_level'] as int? ?? 3,
      contextTags: List<String>.from(json['context_tags'] as List? ?? []),
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class MoodHistoryNotifier extends StateNotifier<AsyncValue<List<MoodEntry>>> {
  final dynamic apiService;

  MoodHistoryNotifier(this.apiService) : super(const AsyncValue.loading());

  Future<void> fetchHistory() async {
    state = const AsyncValue.loading();
    try {
      final response = await apiService.get('/health/moods', queryParams: {'limit': '30'});
      final entries = (response.data as List).map((e) => MoodEntry.fromJson(e as Map<String, dynamic>)).toList();
      state = AsyncValue.data(entries);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

class MoodDefinitionsNotifier extends StateNotifier<AsyncValue<List<MoodDefinition>>> {
  final dynamic apiService;

  MoodDefinitionsNotifier(this.apiService) : super(const AsyncValue.loading());

  Future<void> fetchDefinitions() async {
    state = const AsyncValue.loading();
    try {
      final response = await apiService.get('/health/moods/definitions');
      final defs = (response.data as List).map((e) => MoodDefinition.fromJson(e as Map<String, dynamic>)).toList();
      state = AsyncValue.data(defs);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }
}

final moodHistoryProvider =
    StateNotifierProvider<MoodHistoryNotifier, AsyncValue<List<MoodEntry>>>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final notifier = MoodHistoryNotifier(apiService);
  notifier.fetchHistory();
  return notifier;
});

final moodDefinitionsProvider =
    StateNotifierProvider<MoodDefinitionsNotifier, AsyncValue<List<MoodDefinition>>>((ref) {
  final apiService = ref.watch(apiServiceProvider);
  final notifier = MoodDefinitionsNotifier(apiService);
  notifier.fetchDefinitions();
  return notifier;
});

class MoodScreen extends ConsumerStatefulWidget {
  const MoodScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<MoodScreen> createState() => _MoodScreenState();
}

class _MoodScreenState extends ConsumerState<MoodScreen> with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  String? _selectedMoodId;
  int _selectedEnergyLevel = 3;
  Set<String> _selectedContextTags = {};
  final _noteController = TextEditingController();
  bool _isLogging = false;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _logMood() async {
    if (_selectedMoodId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a mood')),
      );
      return;
    }

    setState(() => _isLogging = true);

    try {
      final apiService = ref.read(apiServiceProvider);
      await apiService.post('/health/moods', data: {
        'mood_id': _selectedMoodId,
        'note': _noteController.text,
        'energy_level': _selectedEnergyLevel,
        'context_tags': _selectedContextTags.toList(),
      });

      // refresh history
      ref.read(moodHistoryProvider.notifier).fetchHistory();

      setState(() {
        _selectedMoodId = null;
        _selectedEnergyLevel = 3;
        _selectedContextTags.clear();
        _noteController.clear();
        _isLogging = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Mood logged successfully!')),
        );
      }
    } catch (e) {
      setState(() => _isLogging = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error logging mood: $e')),
        );
      }
    }
  }

  String _getRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);

    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    } else if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    } else if (diff.inDays == 1) {
      return 'Yesterday';
    } else if (diff.inDays < 7) {
      return '${diff.inDays}d ago';
    } else {
      return DateFormat('MMM d').format(dateTime);
    }
  }

  @override
  Widget build(BuildContext context) {
    final moodDefs = ref.watch(moodDefinitionsProvider);
    final moodHistory = ref.watch(moodHistoryProvider);

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [_ombre1, _ombre2],
          ),
        ),
        child: CustomPaint(
          painter: _PawPrintBg(),
          child: SingleChildScrollView(
            child: Column(
              children: [
                // header
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 24, 16, 16),
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.arrow_back, color: _brown),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      Expanded(
                        child: Text(
                          'Mood Tracker',
                          style: GoogleFonts.gaegu(
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                            color: _brown,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                // how are you feeling card
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: moodDefs.when(
                    data: (definitions) {
                      return _HowAreYouCard(
                        definitions: definitions,
                        selectedMoodId: _selectedMoodId,
                        selectedEnergyLevel: _selectedEnergyLevel,
                        selectedContextTags: _selectedContextTags,
                        noteController: _noteController,
                        onMoodSelected: (moodId) => setState(() => _selectedMoodId = moodId),
                        onEnergyChanged: (level) => setState(() => _selectedEnergyLevel = level),
                        onTagToggled: (tag) {
                          setState(() {
                            if (_selectedContextTags.contains(tag)) {
                              _selectedContextTags.remove(tag);
                            } else {
                              _selectedContextTags.add(tag);
                            }
                          });
                        },
                        onLogMood: _logMood,
                        isLogging: _isLogging,
                      );
                    },
                    loading: () => const _LoadingCard(),
                    error: (e, st) => _ErrorCard(error: e.toString()),
                  ),
                ),
                const SizedBox(height: 24),
                // mood stats
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: moodHistory.when(
                    data: (entries) => _MoodStatsCard(entries: entries),
                    loading: () => const SizedBox.shrink(),
                    error: (e, st) => const SizedBox.shrink(),
                  ),
                ),
                const SizedBox(height: 24),
                // recent moods header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text(
                    'Recent Moods',
                    style: GoogleFonts.gaegu(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: _brown,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // recent moods list
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: moodHistory.when(
                    data: (entries) {
                      if (entries.isEmpty) {
                        return Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No moods logged yet. Start by selecting a mood above!',
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              color: _outline,
                              fontStyle: FontStyle.italic,
                            ),
                            textAlign: TextAlign.center,
                          ),
                        );
                      }
                      return Column(
                        children: List.generate(
                          entries.length,
                          (index) => _MoodEntryCard(
                            entry: entries[index],
                            relativeTime: _getRelativeTime(entries[index].timestamp),
                          ),
                        ),
                      );
                    },
                    loading: () => const Padding(
                      padding: EdgeInsets.all(16),
                      child: CircularProgressIndicator(color: _coralHdr),
                    ),
                    error: (e, st) => Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text('Error loading history: $e'),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// widgets

class _HowAreYouCard extends StatelessWidget {
  final List<MoodDefinition> definitions;
  final String? selectedMoodId;
  final int selectedEnergyLevel;
  final Set<String> selectedContextTags;
  final TextEditingController noteController;
  final Function(String) onMoodSelected;
  final Function(int) onEnergyChanged;
  final Function(String) onTagToggled;
  final VoidCallback onLogMood;
  final bool isLogging;

  const _HowAreYouCard({
    required this.definitions,
    required this.selectedMoodId,
    required this.selectedEnergyLevel,
    required this.selectedContextTags,
    required this.noteController,
    required this.onMoodSelected,
    required this.onEnergyChanged,
    required this.onTagToggled,
    required this.onLogMood,
    required this.isLogging,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardFill,
        border: Border.all(color: _outline, width: 2),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: _outline, offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'How are you feeling?',
            style: GoogleFonts.gaegu(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: _brown,
            ),
          ),
          const SizedBox(height: 16),
          // mood grid
          GridView.count(
            crossAxisCount: 2,
            childAspectRatio: 1.1,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            children: definitions.map((def) {
              final emoji = _moodEmojis[def.name] ?? '😐';
              final color = _moodColors[def.name] ?? _coralHdr;
              final isSelected = selectedMoodId == def.id;

              return _MoodButton(
                emoji: emoji,
                moodName: def.name,
                color: color,
                isSelected: isSelected,
                onTap: () => onMoodSelected(def.id),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          // energy level
          Text(
            'Energy Level',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _brown,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: List.generate(5, (index) {
              final level = index + 1;
              final isActive = selectedEnergyLevel >= level;
              return Expanded(
                child: GestureDetector(
                  onTap: () => onEnergyChanged(level),
                  child: Container(
                    height: 24,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      color: isActive ? _pawClr : _ombre4,
                      border: Border.all(
                        color: isActive ? _outline : _outline.withOpacity(0.3),
                        width: 1.5,
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: 20),
          // context tags
          Text(
            'Context',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _brown,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _contextTags.map((tag) {
              final isSelected = selectedContextTags.contains(tag);
              return GestureDetector(
                onTap: () => onTagToggled(tag),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: isSelected ? _pawClr : _ombre4,
                    border: Border.all(
                      color: isSelected ? _outline : _outline.withOpacity(0.3),
                      width: 1.5,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.nunito(
                      fontSize: 12,
                      color: _brown,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          // note field
          Text(
            'Notes (optional)',
            style: GoogleFonts.nunito(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: _brown,
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: noteController,
            maxLines: 3,
            style: GoogleFonts.nunito(fontSize: 13, color: _brown),
            decoration: InputDecoration(
              hintText: 'What\'s on your mind?',
              hintStyle: GoogleFonts.nunito(fontSize: 13, color: _outline.withOpacity(0.5)),
              filled: true,
              fillColor: _ombre3,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _outline, width: 1.5),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _outline, width: 1.5),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: _coralHdr, width: 2),
              ),
              contentPadding: const EdgeInsets.all(12),
            ),
          ),
          const SizedBox(height: 24),
          // log mood button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: isLogging ? null : onLogMood,
              style: ElevatedButton.styleFrom(
                backgroundColor: _coralHdr,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                elevation: 0,
              ),
              child: isLogging
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                      ),
                    )
                  : Text(
                      'Log Mood',
                      style: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MoodButton extends StatefulWidget {
  final String emoji;
  final String moodName;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _MoodButton({
    required this.emoji,
    required this.moodName,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  State<_MoodButton> createState() => _MoodButtonState();
}

class _MoodButtonState extends State<_MoodButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 150));
    _scaleAnimation = Tween<double>(begin: 1.0, end: 0.95).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onTapDown(TapDownDetails details) => _controller.forward();

  void _onTapUp(TapUpDetails details) {
    _controller.reverse();
    widget.onTap();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: () => _controller.reverse(),
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            color: _cardFill,
            border: Border.all(
              color: widget.isSelected ? widget.color : _outline.withOpacity(0.3),
              width: widget.isSelected ? 3 : 1.5,
            ),
            borderRadius: BorderRadius.circular(16),
            boxShadow: widget.isSelected
                ? [
                    BoxShadow(
                      color: widget.color.withOpacity(0.4),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                : [],
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(widget.emoji, style: const TextStyle(fontSize: 40)),
              const SizedBox(height: 6),
              Text(
                widget.moodName,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: _brown,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodEntryCard extends StatelessWidget {
  final MoodEntry entry;
  final String relativeTime;

  const _MoodEntryCard({
    required this.entry,
    required this.relativeTime,
  });

  @override
  Widget build(BuildContext context) {
    final moodColor = _moodColors[entry.moodName] ?? _coralHdr;
    final emoji = _moodEmojis[entry.moodName] ?? '😐';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _cardFill,
        border: Border(
          left: BorderSide(color: moodColor, width: 4),
          top: BorderSide(color: _outline.withOpacity(0.2), width: 1),
          right: BorderSide(color: _outline.withOpacity(0.2), width: 1),
          bottom: BorderSide(color: _outline.withOpacity(0.2), width: 1),
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.moodName,
                      style: GoogleFonts.nunito(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: _brown,
                      ),
                    ),
                    Text(
                      relativeTime,
                      style: GoogleFonts.nunito(
                        fontSize: 12,
                        color: _outline.withOpacity(0.6),
                      ),
                    ),
                  ],
                ),
              ),
              // energy dots
              Row(
                children: List.generate(
                  5,
                  (index) => Container(
                    width: 6,
                    height: 6,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: index < entry.energyLevel ? _pawClr : _ombre4,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (entry.contextTags.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              children: entry.contextTags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: moodColor.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    tag,
                    style: GoogleFonts.nunito(fontSize: 11, color: _brown),
                  ),
                );
              }).toList(),
            ),
          ],
          if (entry.note.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              entry.note,
              style: GoogleFonts.nunito(
                fontSize: 12,
                color: _outline,
                fontStyle: FontStyle.italic,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ],
      ),
    );
  }
}

class _MoodStatsCard extends StatelessWidget {
  final List<MoodEntry> entries;

  const _MoodStatsCard({required this.entries});

  @override
  Widget build(BuildContext context) {
    if (entries.isEmpty) return const SizedBox.shrink();

    final moodCounts = <String, int>{};
    for (final entry in entries) {
      moodCounts[entry.moodName] = (moodCounts[entry.moodName] ?? 0) + 1;
    }
    final mostFrequent = moodCounts.entries.reduce((a, b) => a.value > b.value ? a : b);
    final avgEnergy = entries.map((e) => e.energyLevel).reduce((a, b) => a + b) / entries.length;

    return Container(
      decoration: BoxDecoration(
        color: _cardFill,
        border: Border.all(color: _outline, width: 2),
        borderRadius: BorderRadius.circular(22),
        boxShadow: const [
          BoxShadow(color: _outline, offset: Offset(0, 4), blurRadius: 0),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your Mood Stats',
            style: GoogleFonts.gaegu(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: _brown,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              Column(
                children: [
                  Text('${_moodEmojis[mostFrequent.key] ?? '😐'}', style: const TextStyle(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text('Most Frequent', style: GoogleFonts.nunito(fontSize: 11, color: _outline)),
                  Text(
                    mostFrequent.key,
                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold, color: _brown),
                  ),
                ],
              ),
              Column(
                children: [
                  const Text('⚡', style: TextStyle(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text('Avg Energy', style: GoogleFonts.nunito(fontSize: 11, color: _outline)),
                  Text(
                    '${avgEnergy.toStringAsFixed(1)}/5',
                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold, color: _brown),
                  ),
                ],
              ),
              Column(
                children: [
                  const Text('📊', style: TextStyle(fontSize: 28)),
                  const SizedBox(height: 4),
                  Text('Total Logged', style: GoogleFonts.nunito(fontSize: 11, color: _outline)),
                  Text(
                    '${entries.length}',
                    style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.bold, color: _brown),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardFill,
        border: Border.all(color: _outline, width: 2),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(20),
      child: const Center(child: CircularProgressIndicator(color: _coralHdr)),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String error;

  const _ErrorCard({required this.error});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: _cardFill,
        border: Border.all(color: _outline, width: 2),
        borderRadius: BorderRadius.circular(22),
      ),
      padding: const EdgeInsets.all(20),
      child: Text('Error: $error'),
    );
  }
}

// background painter

class _PawPrintBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = _pawClr.withOpacity(0.05)
      ..style = PaintingStyle.fill;

    final random = math.Random(42);
    for (int i = 0; i < 30; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      _drawPawprint(canvas, Offset(x, y), 30, paint);
    }
  }

  void _drawPawprint(Canvas canvas, Offset center, double size, Paint paint) {
    canvas.drawCircle(center, size * 0.3, paint);
    canvas.drawCircle(center + Offset(-size * 0.4, -size * 0.5), size * 0.15, paint);
    canvas.drawCircle(center + Offset(0, -size * 0.6), size * 0.15, paint);
    canvas.drawCircle(center + Offset(size * 0.4, -size * 0.5), size * 0.15, paint);
    canvas.drawCircle(center + Offset(size * 0.5, -size * 0.15), size * 0.12, paint);
  }

  @override
  bool shouldRepaint(_PawPrintBg oldDelegate) => false;
}
