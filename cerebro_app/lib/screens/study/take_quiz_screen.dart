//  CEREBRO — Take Quiz Screen
//  Interactive quiz-taking with MCQ, T/F, Fill-in-blank
//  Pre-quiz → Question-by-question → Results

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cerebro_app/providers/auth_provider.dart';

const _ombre1   = Color(0xFFFFFBF7);
const _cardFill = Color(0xFFFFF8F4);
const _outline  = Color(0xFF6E5848);
const _brown    = Color(0xFF4E3828);
const _brownLt  = Color(0xFF7A5840);
const _coralHdr = Color(0xFFF0A898);
const _coralLt  = Color(0xFFF8C0B0);
const _coralDk  = Color(0xFFD08878);
const _greenHdr = Color(0xFFA8D5A3);
const _greenLt  = Color(0xFFC2E8BC);
const _greenDk  = Color(0xFF88B883);
const _goldHdr  = Color(0xFFF0D878);
const _goldLt   = Color(0xFFFFF0C0);
const _purpleHdr = Color(0xFFCDA8D8);
const _purpleLt = Color(0xFFD8C0E8);
const _skyHdr   = Color(0xFF9DD4F0);
const _skyLt    = Color(0xFFB8E0F8);
const _pawClr   = Color(0xFFF8BCD0);

enum _Phase { preQuiz, taking, results }

class TakeQuizScreen extends ConsumerStatefulWidget {
  final Map<String, dynamic> quizData;
  const TakeQuizScreen({super.key, required this.quizData});
  @override ConsumerState<TakeQuizScreen> createState() => _TakeQuizScreenState();
}

class _TakeQuizScreenState extends ConsumerState<TakeQuizScreen>
    with SingleTickerProviderStateMixin {
  _Phase _phase = _Phase.preQuiz;
  Map<String, dynamic> _quiz = {};
  List<Map<String, dynamic>> _questions = [];
  int _currentIdx = 0;
  String? _selectedAnswer;
  bool _answered = false;
  bool _loading = false;

  // Results
  int _correct = 0;
  int _total = 0;
  int _xpEarned = 0;
  List<Map<String, dynamic>> _answeredQuestions = [];

  late AnimationController _animCtrl;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _quiz = widget.quizData;
    _questions = ((widget.quizData['questions'] as List?) ?? [])
        .map((e) => Map<String, dynamic>.from(e))
        .toList();

    // If questions are missing (came from list view), fetch full detail
    if (_questions.isEmpty && _quiz['id'] != null) {
      _fetchQuizDetail();
    } else {
      _applyPhase();
    }
  }

  void _applyPhase() {
    if (_quiz['status'] == 'completed') {
      _phase = _Phase.results;
      _correct = _quiz['correct_count'] ?? 0;
      _total = _quiz['total_questions'] ?? _questions.length;
      _xpEarned = _quiz['xp_earned'] ?? 0;
      _answeredQuestions = _questions;
    } else if (_quiz['status'] == 'in_progress') {
      _phase = _Phase.taking;
      _currentIdx = _questions.indexWhere((q) => q['user_answer'] == null);
      if (_currentIdx < 0) _currentIdx = _questions.length - 1;
    }
  }

  Future<void> _fetchQuizDetail() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.get('/study/generated-quizzes/${_quiz['id']}');
      final data = Map<String, dynamic>.from(resp.data);
      _quiz = data;
      _questions = ((data['questions'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _applyPhase();
    } catch (e) {
      debugPrint('Fetch quiz detail error: $e');
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  void dispose() {
    _animCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ombre1,
      body: Stack(children: [
        Positioned.fill(child: CustomPaint(painter: _PawBgPainter())),
        SafeArea(child: switch (_phase) {
          _Phase.preQuiz => _preQuizView(),
          _Phase.taking => _takingView(),
          _Phase.results => _resultsView(),
        }),
      ]),
    );
  }

  //  PRE-QUIZ
  Widget _preQuizView() {
    final topics = (_quiz['topic_focus'] as List?)?.cast<String>() ?? [];
    final totalQ = _quiz['total_questions'] ?? _questions.length;

    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const Spacer(),
        // Quiz icon
        Container(
          width: 80, height: 80,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(colors: [_coralLt, _coralHdr]),
            border: Border.all(color: _coralDk.withOpacity(0.3), width: 3)),
          child: const Icon(Icons.quiz_rounded, size: 36, color: Colors.white),
        ),
        const SizedBox(height: 20),
        Text(_quiz['title'] ?? 'Quiz', style: GoogleFonts.gaegu(
          fontSize: 28, fontWeight: FontWeight.w700, color: _brown),
          textAlign: TextAlign.center),
        const SizedBox(height: 8),
        // Stats row
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _infoPill(Icons.help_outline_rounded, '$totalQ questions', _skyHdr),
          const SizedBox(width: 8),
          _infoPill(Icons.auto_awesome, _quiz['source'] == 'ai' ? 'AI Generated' : 'Auto Generated',
            _quiz['source'] == 'ai' ? _purpleHdr : _skyHdr),
        ]),
        if (_quiz['time_limit_minutes'] != null) ...[
          const SizedBox(height: 6),
          _infoPill(Icons.timer_outlined, '${_quiz['time_limit_minutes']} min limit', _goldHdr),
        ],
        if (topics.isNotEmpty) ...[
          const SizedBox(height: 16),
          Text('Topics', style: GoogleFonts.nunito(fontSize: 12, fontWeight: FontWeight.w700, color: _brownLt)),
          const SizedBox(height: 6),
          Wrap(spacing: 6, runSpacing: 4, alignment: WrapAlignment.center,
            children: topics.take(6).map((t) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: _purpleLt.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8)),
              child: Text(t, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: _purpleHdr)),
            )).toList()),
        ],
        const Spacer(),
        // Start button
        GestureDetector(
          onTap: _loading ? null : _startQuiz,
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [_greenLt, _greenHdr]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _greenDk.withOpacity(0.4), width: 2),
              boxShadow: [BoxShadow(color: _greenDk.withOpacity(0.3),
                offset: const Offset(0, 4), blurRadius: 0)]),
            child: Center(child: _loading
              ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
              : Text('Start Quiz', style: GoogleFonts.gaegu(
                  fontSize: 26, fontWeight: FontWeight.w700, color: Colors.white))),
          ),
        ),
        const SizedBox(height: 12),
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Back', style: GoogleFonts.nunito(color: _brownLt, fontWeight: FontWeight.w600)),
        ),
      ]),
    );
  }

  Widget _infoPill(IconData icon, String text, Color c) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withOpacity(0.12),
        borderRadius: BorderRadius.circular(10)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 14, color: c),
        const SizedBox(width: 4),
        Text(text, style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: c)),
      ]),
    );
  }

  Future<void> _startQuiz() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.post('/study/generated-quizzes/${_quiz['id']}/start');
      final data = resp.data as Map<String, dynamic>;
      _questions = ((data['questions'] as List?) ?? [])
          .map((e) => Map<String, dynamic>.from(e))
          .toList();
      _currentIdx = 0;
      _selectedAnswer = null;
      _answered = false;
      _correct = 0;
      _answeredQuestions = [];
      setState(() { _phase = _Phase.taking; _loading = false; });
      _animCtrl.forward(from: 0);
    } catch (e) {
      debugPrint('Start quiz error: $e');
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Error starting quiz: $e', style: GoogleFonts.nunito()),
          backgroundColor: _coralHdr));
      }
    }
  }

  //  QUIZ TAKING
  Widget _takingView() {
    if (_questions.isEmpty) return const Center(child: Text('No questions'));
    final q = _questions[_currentIdx];
    final progress = (_currentIdx + 1) / _questions.length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      child: Column(children: [
        // Progress bar + counter
        Row(children: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: _brownLt, size: 22),
            onPressed: () => _confirmExit(),
          ),
          Expanded(child: Column(children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
                backgroundColor: _outline.withOpacity(0.08),
                color: _greenHdr,
              ),
            ),
            const SizedBox(height: 4),
            Text('Question ${_currentIdx + 1} of ${_questions.length}',
              style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w600, color: _brownLt)),
          ])),
          const SizedBox(width: 40),
        ]),
        const SizedBox(height: 20),
        // Question type badge
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _typeColor(q['question_type']).withOpacity(0.15),
              borderRadius: BorderRadius.circular(8)),
            child: Text(_typeLabel(q['question_type']),
              style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700,
                color: _typeColor(q['question_type']))),
          ),
          if (q['topic'] != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _purpleLt.withOpacity(0.3),
                borderRadius: BorderRadius.circular(8)),
              child: Text(q['topic'], style: GoogleFonts.nunito(fontSize: 10, color: _purpleHdr),
                maxLines: 1, overflow: TextOverflow.ellipsis),
            ),
          ],
        ]),
        const SizedBox(height: 16),
        // Question text
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _cardFill,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: _outline.withOpacity(0.08))),
          child: Text(q['question_text'] ?? '',
            style: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w600,
              height: 1.5, color: _brown),
            textAlign: TextAlign.center),
        ),
        const SizedBox(height: 16),
        // Answer area
        Expanded(child: _buildAnswerArea(q)),
        // Feedback + Next
        if (_answered) _feedbackBar(q),
        const SizedBox(height: 8),
        // Next / Submit button
        SizedBox(width: double.infinity, child: GestureDetector(
          onTap: _loading ? null : (_answered ? _nextQuestion : _submitAnswer),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: _answered
                ? [_greenLt, _greenHdr]
                : [_coralLt, _coralHdr]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: (_answered ? _greenDk : _coralDk).withOpacity(0.4), width: 2),
              boxShadow: [BoxShadow(color: (_answered ? _greenDk : _coralDk).withOpacity(0.25),
                offset: const Offset(0, 3), blurRadius: 0)]),
            child: Center(child: Text(
              _answered
                ? (_currentIdx < _questions.length - 1 ? 'Next Question' : 'See Results')
                : 'Check Answer',
              style: GoogleFonts.gaegu(fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white))),
          ),
        )),
      ]),
    );
  }

  Widget _buildAnswerArea(Map<String, dynamic> q) {
    final type = q['question_type'] ?? 'mcq';
    switch (type) {
      case 'true_false':
        return _trueFalseOptions(q);
      case 'fill_blank':
        return _fillBlankField(q);
      default:
        return _mcqOptions(q);
    }
  }

  Widget _mcqOptions(Map<String, dynamic> q) {
    final options = (q['options'] as List?)?.cast<String>() ?? [];
    return ListView(
      children: options.map((opt) {
        final isSelected = _selectedAnswer == opt;
        final isCorrect = _answered && opt.toLowerCase() == (q['correct_answer'] ?? '').toString().toLowerCase();
        final isWrong = _answered && isSelected && !isCorrect;

        Color bg = Colors.white;
        Color border = _outline.withOpacity(0.1);
        if (_answered) {
          if (isCorrect) { bg = _greenLt.withOpacity(0.3); border = _greenHdr; }
          else if (isWrong) { bg = _coralLt.withOpacity(0.3); border = _coralHdr; }
        } else if (isSelected) {
          bg = _skyLt.withOpacity(0.3); border = _skyHdr;
        }

        return GestureDetector(
          onTap: _answered ? null : () => setState(() => _selectedAnswer = opt),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: border, width: 2)),
            child: Row(children: [
              // Radio circle
              Container(
                width: 22, height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? (isWrong ? _coralHdr : isCorrect ? _greenHdr : _skyHdr) : Colors.white,
                  border: Border.all(
                    color: isSelected ? Colors.transparent : _outline.withOpacity(0.2), width: 2)),
                child: isSelected ? Icon(
                  _answered ? (isCorrect ? Icons.check_rounded : Icons.close_rounded) : Icons.circle,
                  size: 14, color: Colors.white) : null,
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(opt, style: GoogleFonts.nunito(fontSize: 14,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500, color: _brown))),
              if (_answered && isCorrect)
                const Icon(Icons.check_circle_rounded, size: 20, color: _greenHdr),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _trueFalseOptions(Map<String, dynamic> q) {
    return Row(children: ['True', 'False'].map((opt) {
      final isSelected = _selectedAnswer == opt;
      final isCorrect = _answered && opt.toLowerCase() == (q['correct_answer'] ?? '').toString().toLowerCase();
      final isWrong = _answered && isSelected && !isCorrect;

      Color bg = Colors.white;
      if (_answered) {
        if (isCorrect) bg = _greenLt.withOpacity(0.3);
        else if (isWrong) bg = _coralLt.withOpacity(0.3);
      } else if (isSelected) bg = _skyLt.withOpacity(0.3);

      return Expanded(child: Padding(
        padding: EdgeInsets.only(right: opt == 'True' ? 6 : 0, left: opt == 'False' ? 6 : 0),
        child: GestureDetector(
          onTap: _answered ? null : () => setState(() => _selectedAnswer = opt),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 24),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: _answered
                  ? (isCorrect ? _greenHdr : isWrong ? _coralHdr : _outline.withOpacity(0.1))
                  : (isSelected ? _skyHdr : _outline.withOpacity(0.1)),
                width: 2)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Icon(opt == 'True' ? Icons.check_circle_outline_rounded : Icons.cancel_outlined,
                size: 32, color: opt == 'True' ? _greenHdr : _coralHdr),
              const SizedBox(height: 6),
              Text(opt, style: GoogleFonts.gaegu(fontSize: 22, fontWeight: FontWeight.w700,
                color: opt == 'True' ? _greenHdr : _coralHdr)),
            ]),
          ),
        ),
      ));
    }).toList());
  }

  final _fillCtrl = TextEditingController();

  Widget _fillBlankField(Map<String, dynamic> q) {
    return Column(children: [
      const Spacer(),
      TextField(
        controller: _fillCtrl,
        enabled: !_answered,
        style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w600),
        textAlign: TextAlign.center,
        onChanged: (v) => setState(() => _selectedAnswer = v),
        decoration: InputDecoration(
          hintText: 'Type your answer...',
          hintStyle: GoogleFonts.nunito(fontSize: 16, color: _brownLt.withOpacity(0.4)),
          filled: true, fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _outline.withOpacity(0.12))),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(color: _outline.withOpacity(0.12))),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: const BorderSide(color: _skyHdr, width: 2)),
        ),
      ),
      if (_answered) ...[
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: q['is_correct'] == true ? _greenLt.withOpacity(0.2) : _coralLt.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12)),
          child: Row(children: [
            Icon(q['is_correct'] == true ? Icons.check_circle_rounded : Icons.cancel_rounded,
              color: q['is_correct'] == true ? _greenHdr : _coralHdr, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(
              q['is_correct'] == true
                ? 'Correct!'
                : 'Answer: ${q['correct_answer']}',
              style: GoogleFonts.nunito(fontSize: 14, fontWeight: FontWeight.w700,
                color: q['is_correct'] == true ? _greenDk : _coralDk))),
          ]),
        ),
      ],
      const Spacer(),
    ]);
  }

  Widget _feedbackBar(Map<String, dynamic> q) {
    final isCorrect = q['is_correct'] == true;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isCorrect ? _greenLt.withOpacity(0.15) : _coralLt.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(isCorrect ? Icons.check_circle_rounded : Icons.info_outline_rounded,
          size: 18, color: isCorrect ? _greenHdr : _coralHdr),
        const SizedBox(width: 8),
        Expanded(child: Text(
          q['explanation'] ?? (isCorrect ? 'Correct!' : 'Incorrect'),
          style: GoogleFonts.nunito(fontSize: 12, height: 1.4,
            color: isCorrect ? _greenDk : _coralDk),
          maxLines: 3, overflow: TextOverflow.ellipsis)),
      ]),
    );
  }

  Future<void> _submitAnswer() async {
    if (_selectedAnswer == null || _selectedAnswer!.isEmpty) return;
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final q = _questions[_currentIdx];
      final resp = await api.post('/study/generated-quizzes/${_quiz['id']}/answer', data: {
        'question_id': q['id'],
        'user_answer': _selectedAnswer,
      });
      final result = resp.data as Map<String, dynamic>;
      _questions[_currentIdx]['user_answer'] = _selectedAnswer;
      _questions[_currentIdx]['is_correct'] = result['is_correct'];
      _questions[_currentIdx]['correct_answer'] = result['correct_answer'];
      _questions[_currentIdx]['explanation'] = result['explanation'];
      if (result['is_correct'] == true) _correct++;
      setState(() { _answered = true; _loading = false; });
    } catch (e) {
      debugPrint('Answer error: $e');
      setState(() => _loading = false);
    }
  }

  void _nextQuestion() {
    if (_currentIdx < _questions.length - 1) {
      setState(() {
        _currentIdx++;
        _selectedAnswer = null;
        _answered = false;
        _fillCtrl.clear();
      });
      _animCtrl.forward(from: 0);
    } else {
      _completeQuiz();
    }
  }

  Future<void> _completeQuiz() async {
    setState(() => _loading = true);
    try {
      final api = ref.read(apiServiceProvider);
      final resp = await api.post('/study/generated-quizzes/${_quiz['id']}/complete');
      final data = resp.data as Map<String, dynamic>;
      _total = _questions.length;
      _xpEarned = data['xp_earned'] ?? 0;
      _answeredQuestions = _questions;
      setState(() { _phase = _Phase.results; _loading = false; });
    } catch (e) {
      debugPrint('Complete quiz error: $e');
      setState(() => _loading = false);
    }
  }

  void _confirmExit() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: _cardFill,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: Text('Leave Quiz?', style: GoogleFonts.gaegu(fontSize: 22, fontWeight: FontWeight.w700, color: _brown)),
        content: Text('Your progress will be saved and you can resume later.',
          style: GoogleFonts.nunito(fontSize: 14, color: _brownLt)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Keep Going', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, color: _greenHdr))),
          TextButton(
            onPressed: () { Navigator.pop(ctx); Navigator.pop(context); },
            child: Text('Leave', style: GoogleFonts.nunito(fontWeight: FontWeight.w600, color: _coralHdr))),
        ],
      ),
    );
  }

  Color _typeColor(String? type) {
    switch (type) {
      case 'mcq': return _skyHdr;
      case 'true_false': return _purpleHdr;
      case 'fill_blank': return _goldHdr;
      default: return _skyHdr;
    }
  }

  String _typeLabel(String? type) {
    switch (type) {
      case 'mcq': return 'Multiple Choice';
      case 'true_false': return 'True / False';
      case 'fill_blank': return 'Fill in the Blank';
      default: return 'Question';
    }
  }

  //  RESULTS
  Widget _resultsView() {
    final pct = _total > 0 ? (_correct / _total * 100) : 0.0;
    final grade = _gradeLabel(pct);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(children: [
        const SizedBox(height: 20),
        // Grade circle
        Container(
          width: 100, height: 100,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _gradeColor(pct).withOpacity(0.15),
            border: Border.all(color: _gradeColor(pct), width: 4)),
          child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
            Text(grade, style: GoogleFonts.gaegu(fontSize: 32, fontWeight: FontWeight.w700,
              color: _gradeColor(pct))),
            Text('${pct.toStringAsFixed(0)}%', style: GoogleFonts.nunito(fontSize: 14,
              fontWeight: FontWeight.w800, color: _gradeColor(pct))),
          ])),
        ),
        const SizedBox(height: 16),
        Text(_quiz['title'] ?? 'Quiz Complete!', style: GoogleFonts.gaegu(
          fontSize: 24, fontWeight: FontWeight.w700, color: _brown),
          textAlign: TextAlign.center),
        const SizedBox(height: 8),
        // Stats row
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          _resultStat('Correct', '$_correct', _greenHdr),
          const SizedBox(width: 16),
          _resultStat('Wrong', '${_total - _correct}', _coralHdr),
          const SizedBox(width: 16),
          _resultStat('XP', '+$_xpEarned', _goldHdr),
        ]),
        const SizedBox(height: 20),
        // Review answers
        Text('Review Answers', style: GoogleFonts.gaegu(
          fontSize: 20, fontWeight: FontWeight.w700, color: _brown)),
        const SizedBox(height: 8),
        ..._answeredQuestions.asMap().entries.map((e) {
          final i = e.key;
          final q = e.value;
          final isCorrect = q['is_correct'] == true;
          return Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: _cardFill,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isCorrect ? _greenHdr.withOpacity(0.3) : _coralHdr.withOpacity(0.3))),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 24, height: 24,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isCorrect ? _greenHdr : _coralHdr),
                  child: Center(child: Icon(
                    isCorrect ? Icons.check_rounded : Icons.close_rounded,
                    size: 14, color: Colors.white)),
                ),
                const SizedBox(width: 8),
                Text('Q${i + 1}', style: GoogleFonts.nunito(fontSize: 12,
                  fontWeight: FontWeight.w800, color: _brownLt)),
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: _typeColor(q['question_type']).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(4)),
                  child: Text(_typeLabel(q['question_type']),
                    style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w700,
                      color: _typeColor(q['question_type']))),
                ),
              ]),
              const SizedBox(height: 6),
              Text(q['question_text'] ?? '', style: GoogleFonts.nunito(
                fontSize: 13, fontWeight: FontWeight.w600, color: _brown)),
              const SizedBox(height: 4),
              if (q['user_answer'] != null)
                Text('Your answer: ${q['user_answer']}',
                  style: GoogleFonts.nunito(fontSize: 12,
                    color: isCorrect ? _greenDk : _coralDk,
                    fontWeight: FontWeight.w600)),
              if (!isCorrect && q['correct_answer'] != null)
                Text('Correct: ${q['correct_answer']}',
                  style: GoogleFonts.nunito(fontSize: 12, color: _greenDk, fontWeight: FontWeight.w600)),
              if (q['explanation'] != null) ...[
                const SizedBox(height: 4),
                Text(q['explanation'], style: GoogleFonts.nunito(
                  fontSize: 11, color: _brownLt, fontStyle: FontStyle.italic)),
              ],
            ]),
          );
        }),
        const SizedBox(height: 16),
        // Buttons
        Row(children: [
          Expanded(child: GestureDetector(
            onTap: () => Navigator.pop(context),
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _outline.withOpacity(0.15))),
              child: Center(child: Text('Back to Quizzes',
                style: GoogleFonts.gaegu(fontSize: 18, fontWeight: FontWeight.w700, color: _brownLt))),
            ),
          )),
          const SizedBox(width: 10),
          Expanded(child: GestureDetector(
            onTap: () {
              setState(() {
                _phase = _Phase.preQuiz;
                _currentIdx = 0;
                _selectedAnswer = null;
                _answered = false;
                _correct = 0;
                _fillCtrl.clear();
              });
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_coralLt, _coralHdr]),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: _coralDk.withOpacity(0.3))),
              child: Center(child: Text('Retake',
                style: GoogleFonts.gaegu(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white))),
            ),
          )),
        ]),
      ]),
    );
  }

  Widget _resultStat(String label, String value, Color c) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: c.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10)),
        child: Text(value, style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w800, color: c)),
      ),
      const SizedBox(height: 2),
      Text(label, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w600, color: _brownLt)),
    ]);
  }

  Color _gradeColor(double pct) {
    if (pct >= 90) return _greenHdr;
    if (pct >= 75) return _greenLt;
    if (pct >= 60) return _goldHdr;
    if (pct >= 40) return _coralLt;
    return _coralHdr;
  }

  String _gradeLabel(double pct) {
    if (pct >= 90) return 'A';
    if (pct >= 80) return 'B+';
    if (pct >= 70) return 'B';
    if (pct >= 60) return 'C';
    if (pct >= 50) return 'D';
    return 'F';
  }
}

//  PAWPRINT BACKGROUND
class _PawBgPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const sp = 90.0, rs = 45.0, r = 10.0;
    int idx = 0;
    for (double y = 30; y < size.height; y += sp) {
      final odd = ((y / sp).floor() % 2) == 1;
      for (double x = (odd ? rs : 0) + 30; x < size.width; x += sp) {
        paint.color = _pawClr.withOpacity(0.06 + (idx % 5) * 0.018);
        final a = (idx % 4) * 0.3 - 0.3;
        canvas.save(); canvas.translate(x, y); canvas.rotate(a);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero, width: r * 2.2, height: r * 1.8), paint);
        for (final o in [const Offset(-8, -10), const Offset(0, -13), const Offset(8, -10)]) {
          canvas.drawCircle(o, r * 0.55, paint);
        }
        canvas.restore();
        idx++;
      }
    }
  }
  @override bool shouldRepaint(_) => false;
}
