// Floating mini session bar — shows above nav when a study session is live.

import 'package:flutter/material.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:cerebro_app/config/router.dart';
import 'package:cerebro_app/providers/study_session_provider.dart';

// Palette — matches the Study tab's cream/outline tokens.

bool get _darkMode =>
    CerebroTheme.brightnessNotifier.value == Brightness.dark;

Color get _cardFill => _darkMode ? const Color(0xFF29221D) : const Color(0xFFFFF8F4);
Color get _outline => _darkMode ? const Color(0xFFAD7F58) : const Color(0xFF6E5848);
Color get _brown => _darkMode ? const Color(0xFFF2E1CA) : const Color(0xFF4E3828);
Color get _inkSoft => _darkMode ? const Color(0xFFBD926C) : const Color(0xFF9A8070);
Color get _olive => const Color(0xFF98A869);
Color get _oliveDk => const Color(0xFF58772F);
/// Render the mini bar directly. Caller is responsible for visibility logic
/// (typically: show only when `isSessionLiveProvider` is true).
class MiniSessionBar extends ConsumerWidget {
  const MiniSessionBar({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(studySessionProvider);
    if (!session.isLive) return const SizedBox.shrink();

    final notifier = ref.read(studySessionProvider.notifier);
    final isPaused = session.phase == SessionPhase.paused;

    // Title fallback chain: subjectName → user-set title → "<Type> session".
    // Pretty-cases the session type ("focused" → "Focused session") so the
    // label is never just lower-case raw enum text.
    final typeLabel = session.sessionType.isEmpty
        ? 'Focused'
        : session.sessionType[0].toUpperCase()
            + session.sessionType.substring(1);
    final label = session.subjectName
        ?? session.title
        ?? '$typeLabel session';

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => context.push(Routes.studySession),
          child: Container(
            height: 52,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: _cardFill,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _outline, width: 1.5),
              boxShadow: [
                BoxShadow(
                  color: _outline.withOpacity(0.25),
                  offset: const Offset(2, 3),
                  blurRadius: 0,
                ),
              ],
            ),
            child: Row(children: [
              // Live pulse dot — communicates "this is real-time".
              _LivePulse(active: !isPaused),
              const SizedBox(width: 10),
              // Elapsed timer — Gaegu, brown, mono-ish via fixed digit width.
              Text(
                _fmtTime(session.elapsedSeconds),
                style: GoogleFonts.gaegu(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _brown,
                  height: 1.0,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(width: 12),
              // Subject / title — fills remaining width, ellipsis on overflow.
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.gaegu(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isPaused ? _inkSoft : _brown,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              // Pause / Resume — same physical button, icon swaps.
              _MiniIconBtn(
                icon: isPaused ? Icons.play_arrow_rounded
                              : Icons.pause_rounded,
                bg: const Color(0xFFE4BC83),
                onTap: isPaused ? notifier.resume : notifier.pause,
              ),
              const SizedBox(width: 8),
              // Stop — navigates to the full Wrapped rating screen instead
              // of quietly killing the session via a bottom sheet. Users
              // should always land on the focus-slider / notes / topics UI
              // before their session is finalized.
              _MiniIconBtn(
                icon: Icons.stop_rounded,
                bg: const Color(0xFFF7AEAE),
                onTap: () => _requestWrapUp(context, ref),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  String _fmtTime(int sec) {
    final h = sec ~/ 3600;
    final m = (sec % 3600) ~/ 60;
    final s = sec % 60;
    String two(int n) => n.toString().padLeft(2, '0');
    if (h > 0) return '$h:${two(m)}:${two(s)}';
    return '${two(m)}:${two(s)}';
  }

  // Navigate to the full session wrap-up screen.
  Future<void> _requestWrapUp(BuildContext context, WidgetRef ref) async {
    // ignore: discarded_futures
    ref.read(studySessionProvider.notifier).requestEnd();
    if (!context.mounted) return;
    await context.push(Routes.studySession);
  }
}

class _LivePulse extends StatefulWidget {
  final bool active;
  const _LivePulse({required this.active});

  @override
  State<_LivePulse> createState() => _LivePulseState();
}

class _LivePulseState extends State<_LivePulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }

  @override
  void didUpdateWidget(covariant _LivePulse old) {
    super.didUpdateWidget(old);
    if (widget.active && !_c.isAnimating) {
      _c.repeat(reverse: true);
    } else if (!widget.active && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final t = widget.active ? (0.4 + _c.value * 0.6) : 0.4;
        return Container(
          width: 10, height: 10,
          decoration: BoxDecoration(
            color: (widget.active ? _olive : _inkSoft).withOpacity(t),
            shape: BoxShape.circle,
            border: Border.all(color: _oliveDk.withOpacity(0.5), width: 1),
          ),
        );
      },
    );
  }
}

class _MiniIconBtn extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final VoidCallback onTap;
  const _MiniIconBtn({required this.icon, required this.bg, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          color: bg,
          shape: BoxShape.circle,
          border: Border.all(color: _outline, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _outline.withOpacity(0.4),
              offset: const Offset(0, 2),
              blurRadius: 0,
            ),
          ],
        ),
        child: Icon(icon, size: 18, color: _brown),
      ),
    );
  }
}
