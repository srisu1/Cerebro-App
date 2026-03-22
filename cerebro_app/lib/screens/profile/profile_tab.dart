/// Layout matched to profile.html:
///   • Hero: back+title (left), pills (right), avatar (center), info (right of avatar)
///   • XP divider bar (same as dashboard)
///   • Two-column content: left (42%) stats+exchange+achievements+tip,
///     right (58%) settings card with groups & toggles
///   • All existing functionality preserved (exchange, achievements, logout, about, etc.)

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cerebro_app/config/constants.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:cerebro_app/widgets/alive_avatar.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/config/router.dart';
import 'package:cerebro_app/providers/dashboard_provider.dart';
import 'package:cerebro_app/screens/home/home_screen.dart';
import 'package:cerebro_app/services/api_service.dart';

const _ombre1    = Color(0xFFFFFBF7);
const _ombre2    = Color(0xFFFFF8F3);
const _ombre3    = Color(0xFFFFF3EF);
const _ombre4    = Color(0xFFFEEDE9);
const _pawClr    = Color(0xFFF8BCD0);
const _outline   = Color(0xFF6E5848);
const _brown     = Color(0xFF4E3828);
const _brownLt   = Color(0xFF7A5840);
const _brownSoft = Color(0xFF9A8070);
const _cardFill  = Color(0xFFFFF8F4);
const _cream     = Color(0xFFFDEFDB);
const _olive     = Color(0xFF98A869);
const _oliveDk   = Color(0xFF58772F);
const _pinkLt    = Color(0xFFFFD5F5);
const _pink      = Color(0xFFFEA9D3);
const _pinkDk    = Color(0xFFE890B8);
const _coral     = Color(0xFFF7AEAE);
const _gold      = Color(0xFFE4BC83);
const _goldGlow  = Color(0xFFF8E080);
const _goldDk    = Color(0xFFD0B048);
const _orange    = Color(0xFFFFBC5C);
const _red       = Color(0xFFEF6262);
const _blueLt    = Color(0xFFDDF6FF);
const _green     = Color(0xFFA8D5A3);
const _greenDk   = Color(0xFF88B883);
const _greenLt   = Color(0xFFC2E8BC);
const _purpleLt  = Color(0xFFCDA8D8);
// Soft sage tint — used as the cash-pill / cash-stat background
// so the sage dollar-bill sticker reads as part of the surface
// instead of clashing with a warm gold/cream fill.
const _cashTint  = Color(0xFFDCE8C9);

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});
  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab>
    with TickerProviderStateMixin {
  String? _email;
  String? _university;
  String? _course;
  List<Map<String, dynamic>> _achievements = [];
  late AnimationController _enterCtrl;
  int _exchangeAmount = 1;

  bool _notificationsOn = true;
  bool _dailyRemindersOn = true;

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
        _email = r.data['email'] as String?;
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

  //  BUILD — mirrors dashboard spaceBetween layout exactly
  @override
  Widget build(BuildContext context) {
    final ds = ref.watch(dashboardProvider);
    return Stack(children: [
      // Ombré background
      Positioned.fill(child: Container(decoration: const BoxDecoration(
        gradient: LinearGradient(begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [_ombre1, _ombre2, _ombre3, _ombre4],
          stops: [0, .3, .6, 1])))),
      Positioned.fill(child: CustomPaint(painter: _PawBg())),

      SafeArea(
        child: LayoutBuilder(builder: (context, constraints) {
          final isWide  = constraints.maxWidth > 800;
          final sidePad = isWide ? 80.0 : 24.0;
          final contentW = constraints.maxWidth - sidePad * 2;
          const navH = 80.0;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(sidePad, 28, sidePad, 0),
                    child: _stag(0.0, _buildTopRow(ds)),
                  ),

                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Avatar section (full-width like dashboard)
                      _stag(0.04, _buildAvatarArea(ds, contentW, sidePad)),

                      // XP divider
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: sidePad),
                        child: _stag(0.08, _buildXpDivider(ds)),
                      ),
                      const SizedBox(height: 10),

                      // Content
                      Padding(
                        padding: EdgeInsets.fromLTRB(sidePad, 0, sidePad, navH),
                        child: isWide
                          ? _stag(0.12, _buildTwoColumnContent(ds))
                          : Column(children: [
                              _stag(0.12, _buildStatsGrid(ds)),
                              const SizedBox(height: 14),
                              _stag(0.16, _buildExchangeCard(ds)),
                              const SizedBox(height: 14),
                              _stag(0.20, _buildAchievementsCard()),
                              const SizedBox(height: 14),
                              _stag(0.24, _buildSettingsCard()),
                              const SizedBox(height: 14),
                              _stag(0.28, _buildTip(ds)),
                            ]),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        }),
      ),
    ]);
  }

  //  TOP ROW — back button + title + pills (same as dashboard top bar)
  Widget _buildTopRow(DashboardState ds) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: () => ref.read(selectedTabProvider.notifier).state = 0,
          child: Container(
            width: 34, height: 34,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _outline, width: 2),
              boxShadow: [BoxShadow(color: _outline.withOpacity(0.45),
                offset: const Offset(2, 2), blurRadius: 0)]),
            child: const Icon(Icons.chevron_left_rounded, size: 20, color: _outline),
          ),
        ),
        const SizedBox(width: 10),
        const Text('Profile', style: TextStyle(
          fontFamily: 'Bitroad', fontSize: 22, color: _brown)),
        const Spacer(),
        _ProfilePill(icon: Icons.star_rounded,
          label: 'Lv. ${ds.level}', color: _gold),
        const SizedBox(width: 7),
        _ProfilePill(iconWidget: const _CashBill(size: 18),
          label: '${ds.cash}', color: _cashTint),
        const SizedBox(width: 7),
        _ProfilePill(icon: Icons.local_fire_department_rounded,
          label: '${ds.streak}', color: _orange),
      ],
    );
  }

  //  AVATAR AREA — matches dashboard _buildAvatarSection sizing EXACTLY
  //  Avatar is full-width (no side-pad on the SizedBox, same as dashboard).
  //  Badge + info are offset using sidePad + contentW/2 so they sit within
  //  the padded content region.
  Widget _buildAvatarArea(DashboardState ds, double contentW, double sidePad) {
    final isSmall  = contentW < 400;
    final isMedium = contentW < 700;

    final double avatarScale  = isSmall ? 0.35 : (isMedium ? 0.40 : 0.45);
    final double avatarSize   = isSmall ? 260.0 : (isMedium ? 280.0 : 310.0);
    final double sectionH     = isSmall ? 130.0 : (isMedium ? 150.0 : 165.0);
    final double avatarTop    = isSmall ? -65.0  : (isMedium ? -80.0  : -100.0);
    const double avatarBottom = 20.0;

    // Visual half-width of the scaled avatar
    final double avHalfW = avatarSize * avatarScale / 2;

    // Avatar visual center Y inside the SizedBox:
    //   Positioned spans from avatarTop to (sectionH - avatarBottom)
    //   Center widget places the content at the midpoint of that range.
    final double avatarCenterY = (avatarTop + sectionH - avatarBottom) / 2.0;

    // Edit badge: right of avatar, just past the clothes/body edge.
    // avHalfW is the hair-width estimate; clothes are wider so we add a buffer.
    final double edgeBuffer = isSmall ? 10.0 : (isMedium ? 15.0 : 20.0);
    final double badgeLeft  = sidePad + contentW / 2 + avHalfW + edgeBuffer;
    // Move badge to hair level — subtract extra offset from visual top
    final double badgeTop   = avatarCenterY - avHalfW - 10.0;

    // Info panel: clear gap to the right of avatar body
    final double infoGap  = isSmall ? 55.0 : (isMedium ? 65.0 : 75.0);
    final double infoLeft = sidePad + contentW / 2 + avHalfW + infoGap;

    return SizedBox(
      height: sectionH,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // Avatar — full width, centered (same as dashboard)
          Positioned(
            left: 0, right: 0,
            top: avatarTop, bottom: avatarBottom,
            child: Center(
              child: GestureDetector(
                onTap: () => context.go('/avatar'),
                child: ds.avatarConfig != null
                  ? OverflowBox(
                      maxWidth: 560, maxHeight: 560,
                      child: Transform.scale(
                        scale: avatarScale,
                        child: AliveAvatar(
                          config: ds.avatarConfig!,
                          size: avatarSize,
                        ),
                      ),
                    )
                  : _placeholderAvatar(),
              ),
            ),
          ),

          // Edit badge — near hair top-right of avatar
          Positioned(
            left: badgeLeft,
            top: badgeTop,
            child: GestureDetector(
              onTap: () => context.go('/avatar'),
              child: _editBadge(),
            ),
          ),

          // Info panel — right of avatar (only if wide enough for side-by-side)
          if (contentW >= 380)
            Positioned(
              left: infoLeft,
              top: 0, bottom: 0,
              child: Center(child: _buildHeroInfo(ds)),
            ),
        ],
      ),
    );
  }

  Widget _buildHeroInfo(DashboardState ds) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(ds.displayName, style: const TextStyle(
          fontFamily: 'Bitroad', fontSize: 26, color: _brown, height: 1.1)),
        const SizedBox(height: 2),
        Text(_email ?? '', style: GoogleFonts.gaegu(
          fontSize: 14, fontWeight: FontWeight.w700, color: _brownSoft)),
        if (_university != null || _course != null) ...[
          const SizedBox(height: 2),
          Text([_university, _course].whereType<String>().join(' · '),
            style: GoogleFonts.nunito(fontSize: 11,
              fontWeight: FontWeight.w600, color: _brownLt)),
        ],
        const SizedBox(height: 8),
        // Level badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(colors: [_goldGlow, _goldDk]),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: _outline, width: 2),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.35),
              offset: const Offset(2, 2), blurRadius: 0)]),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text('Lv.${ds.level}', style: GoogleFonts.gaegu(
              fontSize: 14, fontWeight: FontWeight.w900, color: _brown)),
            Container(width: 1.5, height: 12, color: _brown.withOpacity(0.25),
              margin: const EdgeInsets.symmetric(horizontal: 7)),
            Text(_title(ds.level), style: GoogleFonts.gaegu(
              fontSize: 13, fontWeight: FontWeight.w700, color: _brownSoft)),
          ]),
        ),
      ],
    );
  }

  Widget _editBadge() => Container(
    width: 30, height: 30,
    decoration: BoxDecoration(
      color: _pink,
      shape: BoxShape.circle,
      border: Border.all(color: _outline, width: 2),
      boxShadow: [BoxShadow(color: _outline.withOpacity(0.35),
        offset: const Offset(2, 2), blurRadius: 0)]),
    child: const Icon(Icons.edit_rounded, size: 13, color: Colors.white),
  );

  Widget _placeholderAvatar() => Container(
    width: 120, height: 130,
    decoration: BoxDecoration(
      color: const Color(0xFFFFF0E8),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: _outline, width: 3)),
    child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
      const Icon(Icons.face_rounded, size: 36, color: CerebroTheme.pinkPop),
      const SizedBox(height: 4),
      Text('Create avatar!', textAlign: TextAlign.center,
        style: GoogleFonts.gaegu(fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
    ]),
  );

  //  XP DIVIDER — same as dashboard
  Widget _buildXpDivider(DashboardState ds) {
    final xpPerLevel = 500;
    final currentXp = ds.totalXp;
    final levelXp = ds.level * xpPerLevel;
    final prevLevelXp = (ds.level - 1) * xpPerLevel;
    final progress = levelXp > prevLevelXp
        ? ((currentXp - prevLevelXp) / (levelXp - prevLevelXp)).clamp(0.0, 1.0)
        : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Text('Lv. ${ds.level}',
          style: const TextStyle(fontFamily: 'Bitroad', fontSize: 12, color: _brownLt)),
        const SizedBox(width: 14),
        SizedBox(
          width: MediaQuery.of(context).size.width * 0.22,
          height: 8,
          child: Container(
            decoration: BoxDecoration(
              color: _olive.withOpacity(0.15),
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _outline.withOpacity(0.25), width: 1)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress,
              child: Container(decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [_olive, _oliveDk]),
                borderRadius: BorderRadius.circular(999))),
            ),
          ),
        ),
        const SizedBox(width: 14),
        Text('${currentXp - prevLevelXp} / ${levelXp - prevLevelXp} XP',
          style: GoogleFonts.nunito(fontSize: 11, fontWeight: FontWeight.w700, color: _brownSoft)),
      ]),
    );
  }

  //  TWO-COLUMN (wide)
  Widget _buildTwoColumnContent(DashboardState ds) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // LEFT — 42%
          Expanded(flex: 42, child: Column(children: [
            _buildStatsGrid(ds),
            const SizedBox(height: 14),
            _buildExchangeCard(ds),
            const SizedBox(height: 14),
            _buildAchievementsCard(),
            const SizedBox(height: 14),
            _buildTip(ds),
          ])),
          const SizedBox(width: 30),
          // RIGHT — 58%
          Expanded(flex: 58, child: _buildSettingsCard()),
        ],
      ),
    );
  }

  //  STATS GRID — 3 columns matching HTML .stats
  Widget _buildStatsGrid(DashboardState ds) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.show_chart_rounded, 'Your Stats'),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _statCell(Icons.local_fire_department_rounded, '${ds.streak}', 'Streak', _coral, Colors.white)),
          const SizedBox(width: 8),
          Expanded(child: _statCell(Icons.star_rounded, '${ds.totalXp}', 'XP', _gold, Colors.white.withOpacity(0.7))),
          const SizedBox(width: 8),
          Expanded(child: _statCell(Icons.monetization_on_rounded, '${ds.cash}', 'Cash', _cashTint, Colors.white, iconWidget: const _CashBill(size: 16))),
        ]),
      ],
    );
  }

  Widget _statCell(IconData ic, String val, String label, Color bg, Color iconBg,
      {Widget? iconWidget}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _outline.withOpacity(0.3), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.15),
          offset: const Offset(2, 2), blurRadius: 0)]),
      child: Row(children: [
        Container(
          width: 28, height: 28,
          decoration: BoxDecoration(
            color: iconBg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _outline.withOpacity(0.2), width: 1.5)),
          child: Center(child: iconWidget ?? Icon(ic, size: 13, color: _brownSoft)),
        ),
        const SizedBox(width: 8),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(val, style: const TextStyle(
              fontFamily: 'Bitroad', fontSize: 16, color: _brown, height: 1)),
            Text(label, style: GoogleFonts.nunito(
              fontSize: 9, fontWeight: FontWeight.w700,
              color: _brownSoft, letterSpacing: 0.5)),
          ],
        )),
      ]),
    );
  }

  //  EXCHANGE CARD — XP → Cash (all existing logic)
  Widget _buildExchangeCard(DashboardState ds) {
    final maxEx = ds.exchangeableCash;
    final canEx = maxEx > 0 && _exchangeAmount <= maxEx;
    final xpCost = _exchangeAmount * xpPerCash;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _sectionTitle(Icons.swap_vert_rounded, 'XP → Cash'),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
            decoration: BoxDecoration(
              color: _olive,
              borderRadius: BorderRadius.circular(999),
              border: Border.all(color: _oliveDk, width: 1.5),
              boxShadow: [BoxShadow(color: _oliveDk.withOpacity(0.5),
                offset: const Offset(1, 1), blurRadius: 0)]),
            child: Text('20:1', style: GoogleFonts.nunito(
              fontSize: 10, fontWeight: FontWeight.w700, color: Colors.white)),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _outline, width: 2),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.4),
              offset: const Offset(3, 3), blurRadius: 0)]),
          child: Row(children: [
            // Controls
            Expanded(child: Row(children: [
              _exBtn(Icons.remove_rounded, _exchangeAmount > 1, () {
                if (_exchangeAmount > 1) setState(() => _exchangeAmount--);
              }),
              Expanded(child: Column(children: [
                Text('$_exchangeAmount', style: const TextStyle(
                  fontFamily: 'Bitroad', fontSize: 24, color: _brown, height: 1)),
                Text('Cash ($xpCost XP)', style: GoogleFonts.nunito(
                  fontSize: 10, fontWeight: FontWeight.w700, color: _brownSoft)),
              ])),
              _exBtn(Icons.add_rounded, _exchangeAmount < maxEx, () {
                if (_exchangeAmount < maxEx) setState(() => _exchangeAmount++);
              }),
            ])),
            const SizedBox(width: 10),
            // Exchange button
            GestureDetector(
              onTap: canEx ? () async {
                final amt = _exchangeAmount;
                final ok = await ref.read(dashboardProvider.notifier).exchangeXpToCash(amt);
                if (ok && mounted) {
                  setState(() => _exchangeAmount = 1);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                    content: Text('+$amt Cash!', style: GoogleFonts.gaegu(
                      fontSize: 16, fontWeight: FontWeight.w700)),
                    backgroundColor: _green));
                }
              } : null,
              child: Container(
                height: 34,
                padding: const EdgeInsets.symmetric(horizontal: 18),
                decoration: BoxDecoration(
                  color: canEx ? _olive : _outline.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: canEx ? _oliveDk : _outline.withOpacity(0.1), width: 2),
                  boxShadow: canEx ? [BoxShadow(color: _oliveDk.withOpacity(0.5),
                    offset: const Offset(2, 2), blurRadius: 0)] : []),
                child: Center(child: Text(
                  canEx ? 'Exchange!' : 'No XP',
                  style: GoogleFonts.gaegu(fontSize: 14, fontWeight: FontWeight.w700,
                    color: canEx ? Colors.white : _brownSoft))),
              ),
            ),
            if (maxEx > 1) ...[
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => setState(() => _exchangeAmount = maxEx),
                child: Text('Max: $maxEx', style: GoogleFonts.nunito(
                  fontSize: 9, fontWeight: FontWeight.w700,
                  color: _oliveDk, decoration: TextDecoration.underline)),
              ),
            ],
          ]),
        ),
      ],
    );
  }

  Widget _exBtn(IconData ic, bool on, VoidCallback fn) => GestureDetector(
    onTap: on ? fn : null,
    child: Container(
      width: 30, height: 30,
      decoration: BoxDecoration(
        color: on ? _cream : _outline.withOpacity(0.04),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _outline, width: 2),
        boxShadow: on ? [BoxShadow(color: _outline.withOpacity(0.3),
          offset: const Offset(2, 2), blurRadius: 0)] : []),
      child: Icon(ic, size: 12,
        color: on ? _outline : _outline.withOpacity(0.25)),
    ),
  );

  //  ACHIEVEMENTS — 4×2 grid matching HTML .ach-grid
  Widget _buildAchievementsCard() {
    final sorted = List<Map<String, dynamic>>.from(_achievements)
      ..sort((a, b) {
        final au = a['is_unlocked'] == true ? 0 : 1;
        final bu = b['is_unlocked'] == true ? 0 : 1;
        if (au != bu) return au.compareTo(bu);
        return ((b['progress_pct'] as num?) ?? 0)
            .compareTo((a['progress_pct'] as num?) ?? 0);
      });
    final display = sorted.take(8).toList();

    // Achievement circle colors rotating
    const achColors = [_cream, _coral, _blueLt, _gold, _pinkLt];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          _sectionTitle(Icons.emoji_events_rounded, 'Achievements'),
          const Spacer(),
          GestureDetector(
            onTap: () => context.push(Routes.achievements),
            child: Text('See All →', style: GoogleFonts.nunito(
              fontSize: 11, fontWeight: FontWeight.w700, color: _brown)),
          ),
        ]),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _outline, width: 2),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.4),
              offset: const Offset(3, 3), blurRadius: 0)]),
          child: display.isEmpty
            ? Center(child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text('Complete tasks to earn badges!',
                  style: GoogleFonts.nunito(fontSize: 13,
                    color: _brownLt.withOpacity(0.5))),
              ))
            : Wrap(
                spacing: 6, runSpacing: 6,
                children: List.generate(display.length, (i) {
                  final a = display[i];
                  final u = a['is_unlocked'] == true;
                  return SizedBox(
                    width: 58,
                    child: Column(children: [
                      Container(
                        width: 36, height: 36,
                        decoration: BoxDecoration(
                          color: u ? achColors[i % achColors.length] : _outline.withOpacity(0.04),
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: u ? _outline : _outline.withOpacity(0.1),
                            width: u ? 2 : 1.5),
                          boxShadow: u ? [BoxShadow(color: _outline.withOpacity(0.2),
                            offset: const Offset(2, 2), blurRadius: 0)] : []),
                        child: Icon(_achIcon(a['icon'] as String?), size: 15,
                          color: u ? _outline : _outline.withOpacity(0.12)),
                      ),
                      const SizedBox(height: 3),
                      Text(a['name'] as String? ?? '', maxLines: 1,
                        overflow: TextOverflow.ellipsis, textAlign: TextAlign.center,
                        style: GoogleFonts.nunito(fontSize: 9, fontWeight: FontWeight.w600,
                          color: u ? _brown : _outline.withOpacity(0.25))),
                    ]),
                  );
                }),
              ),
        ),
      ],
    );
  }

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

  //  TIP — same as dashboard daily insight
  Widget _buildTip(DashboardState ds) {
    final xpToNext = ds.xpForNext - ds.totalXp;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _pinkLt.withOpacity(0.35),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _outline.withOpacity(0.25), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.1),
          offset: const Offset(2, 2), blurRadius: 0)]),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Container(
          width: 24, height: 24,
          decoration: BoxDecoration(
            color: Colors.white,
            shape: BoxShape.circle,
            border: Border.all(color: _outline.withOpacity(0.3), width: 1.5)),
          child: const Icon(Icons.lightbulb_rounded, size: 12, color: _pinkDk),
        ),
        const SizedBox(width: 9),
        Expanded(child: Text(
          'You\'re a ${_title(ds.level)} now! $xpToNext XP to Level ${ds.level + 1} — keep going~',
          style: GoogleFonts.gaegu(fontSize: 14, fontWeight: FontWeight.w700,
            color: _brown, height: 1.4))),
      ]),
    );
  }

  //  SETTINGS CARD — grouped rows with toggles (from HTML)
  Widget _buildSettingsCard() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionTitle(Icons.settings_rounded, 'Settings'),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _outline, width: 2),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.4),
              offset: const Offset(3, 3), blurRadius: 0)]),
          child: Column(children: [
            _groupLabel('Account'),
            _settingsRow(Icons.face_rounded, 'Edit Avatar', _pinkLt,
              onTap: () => context.go('/avatar')),
            _settingsDivider(),
            _settingsRow(Icons.lock_rounded, 'Change Password', _purpleLt.withOpacity(0.35),
              onTap: () => _showChangePassword()),

            _groupLabel('Preferences'),
            _settingsRow(Icons.wb_sunny_rounded, 'Dark Mode', _cream,
              trailing: _toggle(false, null)),  // read-only for now
            _settingsDivider(),
            _settingsRow(Icons.menu_book_rounded, 'Study Preferences', _blueLt,
              onTap: () => _snack('Coming soon!', _blueLt)),
            _settingsDivider(),
            _settingsRow(Icons.notifications_rounded, 'Notifications', _gold,
              trailing: _toggle(_notificationsOn, (v) => setState(() => _notificationsOn = v))),
            _settingsDivider(),
            _settingsRow(Icons.edit_rounded, 'Daily Reminders', _olive.withOpacity(0.35),
              trailing: _toggle(_dailyRemindersOn, (v) => setState(() => _dailyRemindersOn = v))),

            _groupLabel('Danger Zone'),
            _settingsRow(Icons.logout_rounded, 'Sign Out', _coral,
              destructive: true,
              onTap: () => _confirmLogout(context)),
            const SizedBox(height: 4),
          ]),
        ),
      ],
    );
  }

  Widget _groupLabel(String label) => Padding(
    padding: const EdgeInsets.fromLTRB(14, 10, 14, 3),
    child: Text(label, style: GoogleFonts.nunito(
      fontSize: 9, fontWeight: FontWeight.w700,
      color: _brownSoft, letterSpacing: 0.8)),
  );

  Widget _settingsRow(IconData ic, String label, Color iconBg,
      {VoidCallback? onTap, Widget? trailing, bool destructive = false}) {
    return GestureDetector(
      onTap: trailing == null ? onTap : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(children: [
          Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              color: iconBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: _outline.withOpacity(0.15), width: 1.5)),
            child: Icon(ic, size: 13, color: _outline),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label, style: GoogleFonts.nunito(
            fontSize: 13.5, fontWeight: FontWeight.w700,
            color: destructive ? _red : _brown))),
          if (trailing != null) trailing
          else Icon(Icons.chevron_right_rounded, size: 14,
            color: _outline.withOpacity(0.18)),
        ]),
      ),
    );
  }

  Widget _settingsDivider() => Divider(height: 1, indent: 52,
    color: _outline.withOpacity(0.06));

  Widget _toggle(bool on, void Function(bool)? onChanged) {
    return GestureDetector(
      onTap: onChanged != null ? () => onChanged(!on) : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: 36, height: 20,
        decoration: BoxDecoration(
          color: on ? _olive : _outline.withOpacity(0.12),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: on ? _oliveDk : _outline.withOpacity(0.2), width: 1.5)),
        child: AnimatedAlign(
          duration: const Duration(milliseconds: 200),
          alignment: on ? Alignment.centerRight : Alignment.centerLeft,
          child: Container(
            width: 14, height: 14,
            margin: const EdgeInsets.all(1),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.circle,
              border: Border.all(
                color: on ? _oliveDk : _outline.withOpacity(0.15), width: 1),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1),
                offset: const Offset(0, 1), blurRadius: 2)]),
          ),
        ),
      ),
    );
  }

  //  HELPERS
  Widget _sectionTitle(IconData ic, String label) => Row(
    children: [
      Icon(ic, size: 15, color: _oliveDk),
      const SizedBox(width: 7),
      Text(label, style: const TextStyle(
        fontFamily: 'Bitroad', fontSize: 15, color: _brown)),
    ],
  );

  void _snack(String msg, Color c) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg, style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
      backgroundColor: c));

  //  DIALOGS (preserved exactly)
  void _showChangePassword() {
    showDialog(
      context: context,
      builder: (ctx) => _ChangePasswordDialog(
        api: ref.read(apiServiceProvider),
        prefillEmail: _email,
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(context: context, builder: (ctx) => Dialog(
      backgroundColor: _cardFill,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: _outline, width: 2.5)),
      child: Padding(padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(width: 50, height: 50,
            decoration: BoxDecoration(color: _coral,
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
            Expanded(child: _dBtn('Sign Out', true, _coral, () async {
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
                colors: [CerebroTheme.pinkPop, _coral]),
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

//  PILL — matching dashboard pill style
class _ProfilePill extends StatelessWidget {
  final IconData? icon;
  final Widget? iconWidget;        // overrides `icon` when provided
  final String label;
  final Color color;
  const _ProfilePill({this.icon, this.iconWidget, required this.label, required this.color})
      : assert(icon != null || iconWidget != null,
               'Provide either icon or iconWidget');

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _outline.withOpacity(0.35), width: 1.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.28),
          offset: const Offset(2, 2), blurRadius: 0)]),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        iconWidget ?? Icon(icon, size: 14, color: _outline),
        const SizedBox(width: 5),
        Text(label, style: GoogleFonts.gaegu(
          fontSize: 15, fontWeight: FontWeight.w700, color: _brown)),
      ]),
    );
  }
}

//  CASH BILL STICKER — tilted sage dollar-bill, matches store
class _CashBill extends StatelessWidget {
  final double size;
  final Color fill;
  final Color border;
  final Color glyphColor;
  const _CashBill({
    this.size = 16,
    this.fill      = const Color(0xFF98A869),  // palette sage
    this.border    = const Color(0xFF58772F),  // palette olive-dk
    this.glyphColor = const Color(0xFFF9FDEC), // palette cream-yellow
  });

  @override
  Widget build(BuildContext context) {
    final double w = size;
    final double h = size * 0.66;
    return Transform.rotate(
      angle: -0.15,
      child: Container(
        width: w, height: h,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(size * 0.15),
          border: Border.all(color: border, width: size * 0.09),
        ),
        child: Center(child: Text('\$',
          style: GoogleFonts.gaegu(
            fontSize: size * 0.58, fontWeight: FontWeight.w700,
            color: glyphColor, height: 1))),
      ),
    );
  }
}

//  CHANGE PASSWORD DIALOG (same 3-step flow as login forgot-password)
//  Step 0 → send reset code to email
//  Step 1 → enter code + new password + confirm
//  Step 2 → success
class _ChangePasswordDialog extends StatefulWidget {
  final ApiService api;
  final String? prefillEmail;
  const _ChangePasswordDialog({required this.api, this.prefillEmail});
  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  int _step = 0;
  bool _loading = false;
  String? _error;
  String _email = '';
  bool _hidePass = true;

  late final TextEditingController _emailC;
  final _codeC     = TextEditingController();
  final _newPassC  = TextEditingController();
  final _confPassC = TextEditingController();

  @override
  void initState() {
    super.initState();
    _emailC = TextEditingController(text: widget.prefillEmail ?? '');
  }

  @override
  void dispose() {
    _emailC.dispose(); _codeC.dispose();
    _newPassC.dispose(); _confPassC.dispose();
    super.dispose();
  }

  Future<void> _sendCode() async {
    // Use pre-filled (locked) email when available; fall back to typed value
    final email = (widget.prefillEmail != null && widget.prefillEmail!.isNotEmpty)
        ? widget.prefillEmail!
        : _emailC.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Please enter a valid email address');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.api.post('/auth/forgot-password', data: {'email': email});
      _email = email;
      setState(() { _step = 1; _loading = false; });
    } catch (_) {
      setState(() { _loading = false; _error = 'Could not send code. Try again.'; });
    }
  }

  Future<void> _resetPassword() async {
    final code = _codeC.text.trim();
    final np   = _newPassC.text;
    final cp   = _confPassC.text;
    if (code.length != 6) { setState(() => _error = 'Enter the 6-digit code'); return; }
    if (np.length < 8)    { setState(() => _error = 'Password must be at least 8 characters'); return; }
    if (np != cp)         { setState(() => _error = "Passwords don't match"); return; }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.api.post('/auth/reset-password', data: {
        'email': _email,
        'reset_code': code,
        'new_password': np,
      });
      setState(() { _step = 2; _loading = false; });
    } catch (e) {
      setState(() {
        _loading = false;
        _error = 'Reset failed — check your code and try again.';
      });
    }
  }

  InputDecoration _inp(String hint, IconData ic, {Widget? suffix}) =>
    InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.nunito(fontSize: 13, color: _brownSoft.withOpacity(0.5)),
      prefixIcon: Icon(ic, size: 18, color: _brownSoft),
      suffixIcon: suffix,
      filled: true, fillColor: _ombre2,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _outline, width: 2)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _outline.withOpacity(0.3), width: 1.5)),
      focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _pink, width: 2)),
    );

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 420),
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: _outline, width: 2.5),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.45),
            offset: const Offset(5, 5), blurRadius: 0)]),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            padding: const EdgeInsets.fromLTRB(20, 14, 12, 14),
            decoration: BoxDecoration(
              color: _step == 2 ? _olive : _purpleLt,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19))),
            child: Row(children: [
              Expanded(child: Text(
                _step == 0 ? 'Change Password'
                  : _step == 1 ? 'Enter Reset Code'
                  : 'Password Changed!',
                style: const TextStyle(fontFamily: 'Bitroad',
                  fontSize: 20, color: _brown))),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.25),
                    shape: BoxShape.circle),
                  child: const Icon(Icons.close_rounded, size: 16, color: _brown),
                ),
              ),
            ]),
          ),

          Padding(
            padding: const EdgeInsets.all(20),
            child: _step == 0 ? _stepEmail()
              : _step == 1 ? _stepCode()
              : _stepSuccess(),
          ),
        ]),
      ),
    );
  }

  Widget _stepEmail() {
    final hasEmail = widget.prefillEmail != null && widget.prefillEmail!.isNotEmpty;
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Text("We'll send a 6-digit reset code to your registered email.",
        style: GoogleFonts.gaegu(fontSize: 15, fontWeight: FontWeight.w700,
          color: _brownLt, height: 1.4)),
      const SizedBox(height: 14),
      // Email: locked if pre-filled (user is logged in), editable only if unknown
      if (hasEmail) ...[
        // Read-only locked display — prevents anyone else hijacking the flow
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: _ombre2,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _outline.withOpacity(0.2), width: 1.5)),
          child: Row(children: [
            Icon(Icons.email_outlined, size: 18, color: _brownSoft),
            const SizedBox(width: 10),
            Expanded(child: Text(widget.prefillEmail!,
              style: GoogleFonts.nunito(fontSize: 14, color: _brown,
                fontWeight: FontWeight.w600))),
            Icon(Icons.lock_rounded, size: 14, color: _brownSoft.withOpacity(0.5)),
          ]),
        ),
      ] else ...[
        TextField(
          controller: _emailC,
          keyboardType: TextInputType.emailAddress,
          style: GoogleFonts.nunito(fontSize: 14, color: _brown),
          decoration: _inp('your@email.com', Icons.email_outlined)),
      ],
      if (_error != null) ...[
        const SizedBox(height: 8),
        Text(_error!, style: GoogleFonts.nunito(fontSize: 12,
          fontWeight: FontWeight.w700, color: _red)),
      ],
      const SizedBox(height: 16),
      Row(children: [
        Expanded(child: _cpBtn('Cancel', false, null, () => Navigator.pop(context))),
        const SizedBox(width: 10),
        Expanded(child: _cpBtn('Send Code', true, _pink, _loading ? null : _sendCode)),
      ]),
    ]);
  }

  Widget _stepCode() => Column(mainAxisSize: MainAxisSize.min, children: [
    Text("A 6-digit code was sent to $_email. Enter it with your new password.",
      style: GoogleFonts.gaegu(fontSize: 14, fontWeight: FontWeight.w700,
        color: _brownLt, height: 1.4)),
    const SizedBox(height: 14),
    // Code field
    TextField(
      controller: _codeC,
      keyboardType: TextInputType.number,
      maxLength: 6,
      textAlign: TextAlign.center,
      style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w800,
        letterSpacing: 8, color: _brown),
      decoration: InputDecoration(
        hintText: '000000', counterText: '',
        hintStyle: GoogleFonts.nunito(fontSize: 22, letterSpacing: 8,
          color: _brownSoft.withOpacity(0.3)),
        filled: true, fillColor: _ombre2,
        contentPadding: const EdgeInsets.symmetric(vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _outline, width: 2)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _outline.withOpacity(0.3), width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: _pink, width: 2)),
      )),
    const SizedBox(height: 12),
    // New password
    TextField(
      controller: _newPassC,
      obscureText: _hidePass,
      style: GoogleFonts.nunito(fontSize: 14, color: _brown),
      decoration: _inp('New password (min 8 chars)', Icons.lock_outline,
        suffix: GestureDetector(
          onTap: () => setState(() => _hidePass = !_hidePass),
          child: Icon(_hidePass ? Icons.visibility_off_outlined
            : Icons.visibility_outlined,
            size: 18, color: _brownSoft)))),
    const SizedBox(height: 10),
    // Confirm password
    TextField(
      controller: _confPassC,
      obscureText: true,
      style: GoogleFonts.nunito(fontSize: 14, color: _brown),
      decoration: _inp('Confirm new password', Icons.lock_outline)),
    if (_error != null) ...[
      const SizedBox(height: 8),
      Text(_error!, style: GoogleFonts.nunito(fontSize: 12,
        fontWeight: FontWeight.w700, color: _red)),
    ],
    const SizedBox(height: 16),
    Row(children: [
      Expanded(child: _cpBtn('Back', false, null,
        () => setState(() { _step = 0; _error = null; }))),
      const SizedBox(width: 10),
      Expanded(child: _cpBtn('Reset', true, _pink,
        _loading ? null : _resetPassword)),
    ]),
  ]);

  Widget _stepSuccess() => Column(mainAxisSize: MainAxisSize.min, children: [
    Container(
      width: 54, height: 54,
      decoration: BoxDecoration(
        color: _olive, shape: BoxShape.circle,
        border: Border.all(color: _outline, width: 2.5),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
          offset: const Offset(3, 3), blurRadius: 0)]),
      child: const Icon(Icons.check_rounded, size: 28, color: Colors.white)),
    const SizedBox(height: 12),
    Text('All done!', style: GoogleFonts.gaegu(fontSize: 22,
      fontWeight: FontWeight.w700, color: _brown)),
    const SizedBox(height: 6),
    Text('Your password has been updated.\nLog in again next time with your new password.',
      textAlign: TextAlign.center,
      style: GoogleFonts.nunito(fontSize: 13, color: _brownLt, height: 1.4)),
    const SizedBox(height: 18),
    _cpBtn('Done', true, _olive, () => Navigator.pop(context)),
  ]);

  Widget _cpBtn(String label, bool filled, Color? color, VoidCallback? onTap) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        height: 40,
        decoration: BoxDecoration(
          color: filled ? (color ?? _olive) : Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: filled ? _outline : _outline.withOpacity(0.2), width: 2),
          boxShadow: filled ? [BoxShadow(color: _outline.withOpacity(0.3),
            offset: const Offset(2, 2), blurRadius: 0)] : []),
        child: Center(child: _loading && filled
          ? const SizedBox(width: 18, height: 18,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
          : Text(label, style: GoogleFonts.gaegu(fontSize: 15,
              fontWeight: FontWeight.w700,
              color: filled ? Colors.white : _brown))),
      ),
    );
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
