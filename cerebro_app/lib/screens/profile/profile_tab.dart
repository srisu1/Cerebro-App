/// Full-body alive avatar (exact dashboard pattern 160×230),
/// layered cards with depth, visual variety, warm palette.

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cerebro_app/config/constants.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:cerebro_app/models/avatar_config.dart';
import 'package:cerebro_app/widgets/alive_avatar.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/config/router.dart';
import 'package:cerebro_app/providers/dashboard_provider.dart';

const _ombre1   = Color(0xFFFFFBF7);
const _ombre2   = Color(0xFFFFF8F3);
const _ombre3   = Color(0xFFFFF3EF);
const _ombre4   = Color(0xFFFEEDE9);
const _pawClr   = Color(0xFFF8BCD0);
const _outline  = Color(0xFF6E5848);
const _brown    = Color(0xFF4E3828);
const _brownLt  = Color(0xFF7A5840);
const _cardFill = Color(0xFFFFF8F4);
const _greenLt  = Color(0xFFC2E8BC);
const _green    = Color(0xFFA8D5A3);
const _greenDk  = Color(0xFF88B883);
const _goldGlow = Color(0xFFF8E080);
const _goldDk   = Color(0xFFD0B048);
const _pinkHdr  = Color(0xFFE8B0A8);
const _coralHdr = Color(0xFFF0A898);
const _skyHdr   = Color(0xFF9DD4F0);
const _purpleHdr = Color(0xFFCDA8D8);
const _peach    = Color(0xFFFEE5D6);
const _lilac    = Color(0xFFE8D4F0);

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});
  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab>
    with TickerProviderStateMixin {
  String? _university;
  String? _course;
  List<Map<String, dynamic>> _achievements = [];
  late AnimationController _enterCtrl;
  int _exchangeAmount = 1;
  bool _showExchange = false;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))..forward();
    _loadProfile();
    _loadAchievements();
  }

  @override
  void dispose() { _enterCtrl.dispose(); super.dispose(); }

  Future<void> _loadProfile() async {
    try {
      final r = await ref.read(apiServiceProvider).get('/auth/me');
      if (r.statusCode == 200) setState(() {
        _university = r.data['university'] as String?;
        _course = r.data['course'] as String?;
      });
    } catch (_) {}
  }

  Future<void> _loadAchievements() async {
    try {
      final r = await ref.read(apiServiceProvider).get('/gamification/achievements');
      if (r.statusCode == 200)
        setState(() => _achievements = (r.data as List).cast<Map<String, dynamic>>());
    } catch (_) {}
  }

  String _title(int lv) =>
    lv <= 5 ? 'Novice' : lv <= 10 ? 'Apprentice' : lv <= 20 ? 'Scholar' : 'Master';

  Widget _stag(double d, Widget c) => AnimatedBuilder(
    animation: _enterCtrl, builder: (_, __) {
      final t = Curves.easeOutCubic.transform(
        ((_enterCtrl.value - d) / (1.0 - d)).clamp(0.0, 1.0));
      return Opacity(opacity: t,
        child: Transform.translate(offset: Offset(0, 18 * (1 - t)), child: c));
    });

  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dashboardProvider);
    return Stack(children: [
      // Ombre background
      Positioned.fill(child: Container(decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_ombre1, _ombre2, _ombre3, _ombre4],
          stops: [0, .3, .6, 1])))),
      Positioned.fill(child: CustomPaint(painter: _PawBg())),

      SafeArea(child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(34, 10, 34, 90),
        child: Column(children: [
          _stag(0.0, _avatarHeroCard(ds)),
          const SizedBox(height: 16),
          _stag(0.08, _statsCard(ds)),
          const SizedBox(height: 14),
          _stag(0.14, _exchangeSection(ds)),
          const SizedBox(height: 16),
          _stag(0.20, _achievementCard()),
          const SizedBox(height: 16),
          _stag(0.26, _menuSection()),
          const SizedBox(height: 20),
        ]),
      )),
    ]);
  }

  //  AVATAR HERO CARD — layered card with depth
  Widget _avatarHeroCard(DashboardState ds) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline, width: 3),
        boxShadow: [
          BoxShadow(color: _outline.withOpacity(0.3),
            offset: const Offset(0, 4), blurRadius: 0),
        ],
      ),
      child: Column(children: [
        // Avatar on a soft gradient pedestal
        Stack(clipBehavior: Clip.none, alignment: Alignment.center, children: [
          // Soft circular glow behind avatar
          Container(
            width: 170, height: 170,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(colors: [
                _peach.withOpacity(0.5), _peach.withOpacity(0.0),
              ]),
            ),
          ),

          // Full-body avatar — EXACT dashboard pattern
          GestureDetector(
            onTap: () => context.go('/avatar'),
            child: SizedBox(
              width: 160,
              height: 230,
              child: Stack(clipBehavior: Clip.none,
                alignment: Alignment.center, children: [
                  if (ds.avatarConfig != null)
                    OverflowBox(
                      maxWidth: 500,
                      maxHeight: 500,
                      child: Transform.scale(
                        scale: 0.50,
                        child: AliveAvatar(
                          config: ds.avatarConfig!,
                          size: 280,
                        ),
                      ),
                    )
                  else
                    Icon(Icons.face_rounded, size: 120,
                      color: CerebroTheme.pinkPop),
                  // Edit pencil badge
                  Positioned(top: 8, right: 0, child: Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: CerebroTheme.pinkPop, shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2.5),
                      boxShadow: [BoxShadow(color: _outline.withOpacity(0.2),
                        offset: const Offset(0, 2), blurRadius: 0)]),
                    child: const Icon(Icons.edit_rounded, size: 14,
                      color: Colors.white),
                  )),
                ],
              ),
            ),
          ),
        ]),

        const SizedBox(height: 6),

        // Name
        Text(ds.displayName, style: GoogleFonts.gaegu(
          fontSize: 28, fontWeight: FontWeight.w700, color: _brown)),

        const SizedBox(height: 4),

        // Level + title badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_goldGlow, _goldDk]),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: _outline, width: 2),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.2),
              offset: const Offset(0, 2), blurRadius: 0)]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Lv.${ds.level}', style: GoogleFonts.gaegu(
              fontSize: 15, fontWeight: FontWeight.w900, color: _brown)),
            Container(width: 1.5, height: 14, color: _brown.withOpacity(0.2),
              margin: const EdgeInsets.symmetric(horizontal: 8)),
            Text(_title(ds.level), style: GoogleFonts.gaegu(
              fontSize: 14, fontWeight: FontWeight.w700, color: _brownLt)),
          ]),
        ),

        if (_university != null || _course != null) ...[
          const SizedBox(height: 6),
          Text([_university, _course].whereType<String>().join(' · '),
            style: GoogleFonts.nunito(fontSize: 12,
              fontWeight: FontWeight.w600, color: _brownLt)),
        ],

        const SizedBox(height: 14),

        // XP progress bar inside the hero card for depth
        _xpBar(ds),
      ]),
    );
  }

  //  XP BAR — compact, chunky, gold
  Widget _xpBar(DashboardState ds) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text('${ds.totalXp} / ${ds.xpForNext} XP', style: GoogleFonts.nunito(
          fontSize: 11, fontWeight: FontWeight.w700, color: _brownLt)),
        const Spacer(),
        Text('Level ${ds.level + 1}', style: GoogleFonts.nunito(
          fontSize: 11, fontWeight: FontWeight.w700, color: _goldDk)),
      ]),
      const SizedBox(height: 4),
      Container(
        height: 14,
        decoration: BoxDecoration(
          color: _outline.withOpacity(0.06),
          borderRadius: BorderRadius.circular(7),
          border: Border.all(color: _outline, width: 2)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(5),
          child: Stack(children: [
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: ds.xpProgress,
              child: Container(decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [_goldGlow, Color(0xFFFFD040), _goldDk])))),
            // shine
            Positioned.fill(child: Container(decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.white.withOpacity(0.35), Colors.transparent],
                stops: const [0, 0.5])))),
          ]),
        ),
      ),
    ]);
  }

  //  STATS CARD — 3 colourful stat blocks in a card
  Widget _statsCard(DashboardState ds) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline, width: 3),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
          offset: const Offset(0, 4), blurRadius: 0)],
      ),
      child: Row(children: [
        _statBlock(Icons.local_fire_department_rounded, '${ds.streak}',
          'Streak', _coralHdr, const Color(0xFFFEECE5)),
        _statDivider(),
        _statBlock(Icons.star_rounded, '${ds.totalXp}',
          'XP', _goldDk, const Color(0xFFFFF6DC)),
        _statDivider(),
        _statBlock(Icons.monetization_on_rounded, '${ds.cash}',
          'Cash', _greenDk, const Color(0xFFE4F5E0)),
      ]),
    );
  }

  Widget _statBlock(IconData ic, String val, String label, Color accent, Color bg) {
    return Expanded(child: Column(children: [
      Container(
        width: 38, height: 38,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.3), width: 2)),
        child: Icon(ic, size: 19, color: accent),
      ),
      const SizedBox(height: 6),
      Text(val, style: GoogleFonts.gaegu(fontSize: 22,
        fontWeight: FontWeight.w700, color: _brown)),
      Text(label, style: GoogleFonts.nunito(fontSize: 10,
        fontWeight: FontWeight.w700, color: _brownLt)),
    ]));
  }

  Widget _statDivider() => Container(width: 1.5, height: 50,
    decoration: BoxDecoration(
      color: _outline.withOpacity(0.08),
      borderRadius: BorderRadius.circular(1)));

  //  EXCHANGE — collapsible XP→Cash
  Widget _exchangeSection(DashboardState ds) {
    final maxEx = ds.exchangeableCash;
    final canEx = maxEx > 0 && _exchangeAmount <= maxEx;
    final xpCost = _exchangeAmount * xpPerCash;

    return Column(children: [
      // Toggle bar
      GestureDetector(
        onTap: () => setState(() => _showExchange = !_showExchange),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _greenLt.withOpacity(0.18),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _greenDk.withOpacity(0.25), width: 2),
            boxShadow: [BoxShadow(color: _greenDk.withOpacity(0.08),
              offset: const Offset(0, 2), blurRadius: 0)]),
          child: Row(children: [
            Container(
              width: 26, height: 26,
              decoration: BoxDecoration(
                color: _green.withOpacity(0.25),
                borderRadius: BorderRadius.circular(8)),
              child: Icon(Icons.swap_horiz_rounded, size: 15, color: _greenDk),
            ),
            const SizedBox(width: 8),
            Text('XP → Cash', style: GoogleFonts.nunito(fontSize: 14,
              fontWeight: FontWeight.w700, color: _greenDk)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: _green.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)),
              child: Text('20:1', style: GoogleFonts.gaegu(fontSize: 13,
                fontWeight: FontWeight.w700, color: _greenDk)),
            ),
            const SizedBox(width: 6),
            AnimatedRotation(
              turns: _showExchange ? 0.5 : 0,
              duration: const Duration(milliseconds: 200),
              child: Icon(Icons.expand_more_rounded, size: 18, color: _greenDk)),
          ]),
        ),
      ),

      // Expandable panel
      AnimatedCrossFade(
        firstChild: const SizedBox.shrink(),
        secondChild: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Container(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
            decoration: BoxDecoration(
              color: _cardFill,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: _outline, width: 2.5),
              boxShadow: [BoxShadow(color: _outline.withOpacity(0.15),
                offset: const Offset(0, 3), blurRadius: 0)]),
            child: Column(children: [
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _tapBtn(Icons.remove_rounded, _exchangeAmount > 1,
                  () { if (_exchangeAmount > 1) setState(() => _exchangeAmount--); }),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(children: [
                    Text('$_exchangeAmount', style: GoogleFonts.gaegu(
                      fontSize: 34, fontWeight: FontWeight.w700, color: _brown)),
                    Text('Cash ($xpCost XP)', style: GoogleFonts.nunito(
                      fontSize: 11, fontWeight: FontWeight.w600, color: _brownLt)),
                  ]),
                ),
                _tapBtn(Icons.add_rounded, _exchangeAmount < maxEx,
                  () { if (_exchangeAmount < maxEx) setState(() => _exchangeAmount++); }),
              ]),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: canEx ? () async {
                  final amt = _exchangeAmount;
                  final ok = await ref.read(dashboardProvider.notifier)
                      .exchangeXpToCash(amt);
                  if (ok && mounted) {
                    setState(() { _exchangeAmount = 1; _showExchange = false; });
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('+$amt Cash!', style: GoogleFonts.gaegu(
                        fontSize: 16, fontWeight: FontWeight.w700)),
                      backgroundColor: _green));
                  }
                } : null,
                child: Container(
                  width: double.infinity, height: 42,
                  decoration: BoxDecoration(
                    gradient: canEx ? const LinearGradient(
                      colors: [Color(0xFFD0F0CA), _green]) : null,
                    color: canEx ? null : _outline.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: canEx ? _greenDk : _outline.withOpacity(0.1),
                      width: 2.5),
                    boxShadow: canEx ? [BoxShadow(
                      color: _greenDk.withOpacity(0.25),
                      offset: const Offset(0, 3), blurRadius: 0)] : []),
                  child: Center(child: Text(
                    canEx ? 'Exchange!' : 'Not enough XP',
                    style: GoogleFonts.gaegu(fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: canEx ? Colors.white : _brownLt.withOpacity(0.4))))),
              ),
              if (maxEx > 1) Padding(
                padding: const EdgeInsets.only(top: 6),
                child: GestureDetector(
                  onTap: () => setState(() => _exchangeAmount = maxEx),
                  child: Text('Max: $maxEx', style: GoogleFonts.nunito(
                    fontSize: 11, fontWeight: FontWeight.w700,
                    color: _green, decoration: TextDecoration.underline)))),
            ]),
          ),
        ),
        crossFadeState: _showExchange
            ? CrossFadeState.showSecond : CrossFadeState.showFirst,
        duration: const Duration(milliseconds: 250),
      ),
    ]);
  }

  Widget _tapBtn(IconData ic, bool on, VoidCallback fn) => GestureDetector(
    onTap: on ? fn : null, child: Container(
      width: 38, height: 38,
      decoration: BoxDecoration(
        color: on ? _pinkHdr.withOpacity(0.2) : _outline.withOpacity(0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _outline.withOpacity(on ? 0.2 : 0.08), width: 2),
        boxShadow: on ? [BoxShadow(color: _outline.withOpacity(0.08),
          offset: const Offset(0, 2), blurRadius: 0)] : []),
      child: Icon(ic, size: 18, color: on ? _brown : _brownLt.withOpacity(0.25))));

  //  ACHIEVEMENTS CARD — horizontal scroll in a card
  IconData _achIcon(String? ic) {
    const m = {'school': Icons.school_rounded, 'menu_book': Icons.menu_book_rounded,
      'timer': Icons.timer_rounded, 'workspace_premium': Icons.workspace_premium_rounded,
      'star': Icons.star_rounded, 'flash_on': Icons.flash_on_rounded,
      'bedtime': Icons.bedtime_rounded, 'mood': Icons.mood_rounded,
      'favorite': Icons.favorite_rounded, 'medication': Icons.medication_rounded,
      'repeat': Icons.repeat_rounded, 'emoji_events': Icons.emoji_events_rounded,
      'calendar_month': Icons.calendar_month_rounded, 'wb_sunny': Icons.wb_sunny_rounded};
    return m[ic] ?? Icons.emoji_events_rounded;
  }

  Widget _achievementCard() {
    final sorted = List<Map<String, dynamic>>.from(_achievements)
      ..sort((a, b) {
        final au = a['is_unlocked'] == true ? 0 : 1;
        final bu = b['is_unlocked'] == true ? 0 : 1;
        if (au != bu) return au.compareTo(bu);
        return ((b['progress_pct'] as num?) ?? 0)
            .compareTo((a['progress_pct'] as num?) ?? 0);
      });
    final display = sorted.take(8).toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline, width: 3),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
          offset: const Offset(0, 4), blurRadius: 0)],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Header
        GestureDetector(
          onTap: () => context.push(Routes.achievements),
          child: Row(children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                color: _goldGlow.withOpacity(0.2),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _goldDk.withOpacity(0.3), width: 1.5)),
              child: const Icon(Icons.emoji_events_rounded, size: 15, color: _goldDk),
            ),
            const SizedBox(width: 8),
            Text('Achievements', style: GoogleFonts.gaegu(fontSize: 18,
              fontWeight: FontWeight.w700, color: _brown)),
            const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: _goldGlow.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8)),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Text('All', style: GoogleFonts.nunito(fontSize: 11,
                  fontWeight: FontWeight.w700, color: _goldDk)),
                const SizedBox(width: 2),
                Icon(Icons.chevron_right_rounded, size: 14, color: _goldDk),
              ]),
            ),
          ]),
        ),
        const SizedBox(height: 12),

        // Badges
        if (display.isEmpty)
          Center(child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text('Complete tasks to earn badges!',
              style: GoogleFonts.nunito(fontSize: 13,
                color: _brownLt.withOpacity(0.5))),
          ))
        else
          SizedBox(
            height: 76,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: display.length,
              separatorBuilder: (_, __) => const SizedBox(width: 10),
              itemBuilder: (_, i) {
                final a = display[i];
                final u = a['is_unlocked'] == true;
                return _achBadge(
                  a['name'] as String? ?? '', _achIcon(a['icon'] as String?), u);
              },
            ),
          ),
      ]),
    );
  }

  Widget _achBadge(String name, IconData icon, bool unlocked) {
    return SizedBox(
      width: 58,
      child: Column(children: [
        Container(
          width: 46, height: 46,
          decoration: BoxDecoration(
            color: unlocked ? _goldGlow.withOpacity(0.18) : _outline.withOpacity(0.04),
            shape: BoxShape.circle,
            border: Border.all(
              color: unlocked ? _goldDk.withOpacity(0.5) : _outline.withOpacity(0.1),
              width: unlocked ? 2.5 : 1.5),
            boxShadow: unlocked ? [BoxShadow(
              color: _goldGlow.withOpacity(0.25),
              offset: const Offset(0, 2), blurRadius: 0)] : []),
          child: Icon(icon, size: 20,
            color: unlocked ? _goldDk : _brownLt.withOpacity(0.2)),
        ),
        const SizedBox(height: 4),
        Text(name, textAlign: TextAlign.center, maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.nunito(fontSize: 9,
            fontWeight: FontWeight.w600,
            color: unlocked ? _brown : _brownLt.withOpacity(0.4))),
      ]),
    );
  }

  //  MENU — settings + actions inside a card
  Widget _menuSection() {
    return Container(
      decoration: BoxDecoration(
        color: _cardFill,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline, width: 3),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
          offset: const Offset(0, 4), blurRadius: 0)],
      ),
      child: Column(children: [
        _menuRow(Icons.face_rounded, 'Edit Avatar', CerebroTheme.pinkPop,
          const Color(0xFFFDE8EC), () => context.go('/avatar')),
        _mDiv(),
        _menuRow(Icons.school_rounded, 'Study Preferences', _skyHdr,
          const Color(0xFFE2F1FC), () => _snack('Coming soon!', _skyHdr)),
        _mDiv(),
        _menuRow(Icons.notifications_rounded, 'Notifications', _goldDk,
          const Color(0xFFFFF6DC), () => _snack('Coming soon!', _goldGlow)),
        _mDiv(),
        _menuRow(Icons.info_rounded, 'About', _greenDk,
          const Color(0xFFE4F5E0), () => _showAbout(context)),
        _mDiv(),
        _menuRow(Icons.logout_rounded, 'Sign Out', _coralHdr,
          const Color(0xFFFEECE5), () => _confirmLogout(context), destructive: true),
      ]),
    );
  }

  Widget _menuRow(IconData ic, String label, Color accent, Color bg,
      VoidCallback onTap, {bool destructive = false}) {
    return GestureDetector(onTap: onTap, child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(children: [
        Container(width: 32, height: 32,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: accent.withOpacity(0.2), width: 1.5)),
          child: Icon(ic, size: 16, color: accent)),
        const SizedBox(width: 12),
        Expanded(child: Text(label, style: GoogleFonts.nunito(fontSize: 14,
          fontWeight: FontWeight.w700,
          color: destructive ? _coralHdr : _brown))),
        Icon(Icons.chevron_right_rounded, size: 18,
          color: _outline.withOpacity(0.2)),
      ])));
  }

  Widget _mDiv() => Divider(height: 1, indent: 58,
    color: _outline.withOpacity(0.06));

  void _snack(String msg, Color c) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
      backgroundColor: c));

  //  DIALOGS
  void _confirmLogout(BuildContext context) {
    showDialog(context: context, builder: (ctx) => Dialog(
      backgroundColor: _cardFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _outline, width: 2.5)),
      child: Padding(padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 50, height: 50,
            decoration: BoxDecoration(color: _coralHdr,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _outline, width: 2)),
            child: const Icon(Icons.logout_rounded, size: 24,
              color: Colors.white)),
          const SizedBox(height: 12),
          Text('Sign Out?', style: GoogleFonts.gaegu(fontSize: 22,
            fontWeight: FontWeight.w700, color: _brown)),
          const SizedBox(height: 6),
          Text('Your progress is saved!', textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 13,
              fontWeight: FontWeight.w600, color: _brownLt)),
          const SizedBox(height: 16),
          Row(children: [
            Expanded(child: _dBtn('Stay', false, null,
              () => Navigator.pop(ctx))),
            const SizedBox(width: 10),
            Expanded(child: _dBtn('Sign Out', true, _coralHdr, () async {
              Navigator.pop(ctx);
              await ref.read(authProvider.notifier).logout();
              if (mounted) context.go('/login');
            })),
          ]),
        ])),
    ));
  }

  void _showAbout(BuildContext context) {
    showDialog(context: context, builder: (ctx) => Dialog(
      backgroundColor: _cardFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _outline, width: 2.5)),
      child: Padding(padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 52, height: 52,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [CerebroTheme.pinkPop, _coralHdr]),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _outline, width: 2)),
            child: Center(child: Text('C', style: GoogleFonts.nunito(
              fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)))),
          const SizedBox(height: 12),
          Text('CEREBRO', style: GoogleFonts.gaegu(fontSize: 22,
            fontWeight: FontWeight.w700, color: _brown)),
          Text('Smart Student Companion', style: GoogleFonts.nunito(
            fontSize: 12, fontWeight: FontWeight.w600, color: _brownLt)),
          const SizedBox(height: 8),
          Text('v1.0 • FYP • London Met', textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 11,
              fontWeight: FontWeight.w600, color: _brownLt)),
          const SizedBox(height: 16),
          _dBtn('Cool!', true, CerebroTheme.pinkPop,
            () => Navigator.pop(ctx)),
        ])),
    ));
  }

  Widget _dBtn(String l, bool f, Color? c, VoidCallback fn) => GestureDetector(
    onTap: fn, child: Container(height: 40,
      decoration: BoxDecoration(
        color: f ? (c ?? _green) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: f ? _outline : _outline.withOpacity(0.15),
          width: 2),
        boxShadow: f ? [BoxShadow(color: _outline.withOpacity(0.15),
          offset: const Offset(0, 2), blurRadius: 0)] : []),
      child: Center(child: Text(l, style: GoogleFonts.nunito(fontSize: 14,
        fontWeight: FontWeight.w700, color: f ? Colors.white : _brown)))));
}

//  PAWPRINT BACKGROUND
class _PawBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..style = PaintingStyle.fill;
    const sp = 90.0;
    int i = 0;
    for (double y = 30; y < size.height; y += sp) {
      final odd = ((y / sp).floor() % 2) == 1;
      final xOff = odd ? 45.0 : 0.0;
      for (double x = xOff + 30; x < size.width; x += sp) {
        p.color = _pawClr.withOpacity(0.06 + (i % 5) * 0.018);
        final a = (i % 4) * 0.3 - 0.3;
        canvas.save(); canvas.translate(x, y); canvas.rotate(a);
        canvas.drawOval(Rect.fromCenter(center: Offset.zero,
          width: 22, height: 18), p);
        const t = 5.2;
        canvas.drawCircle(const Offset(-10, -13.5), t, p);
        canvas.drawCircle(const Offset(-3.8, -16.5), t, p);
        canvas.drawCircle(const Offset(3.8, -16.5), t, p);
        canvas.drawCircle(const Offset(10, -13.5), t, p);
        canvas.restore();
        i++;
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}
