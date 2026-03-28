// Profile tab — avatar hero, stats, XP exchange, achievements, settings.

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
import 'package:cerebro_app/providers/theme_mode_provider.dart';
import 'package:cerebro_app/screens/home/home_screen.dart';
import 'package:cerebro_app/services/api_service.dart';

// Every entry is now a mode-aware getter backed by
// CerebroTheme.brightnessNotifier. Call sites keep using
// `_cream`, `_outline`, `_brown`, etc. unchanged — when the
// user flips dark mode, MaterialApp rebuilds, these getters
// re-evaluate, and the profile screen repaints with the dark
// palette automatically.
//
// Accent hues (pink, sage, olive, coral, gold) stay identical
// across modes — shade-9 rule from CRUMBS-UI — so cerebro's
// character (stickers, achievement chips) looks the same in
// both themes. Surfaces, borders, and body text tiers are the
// ones that flip.
bool get _darkMode => CerebroTheme.brightnessNotifier.value == Brightness.dark;

// Ombre gradient tiers (hero background)
Color get _ombre1    => _darkMode ? const Color(0xFF191513) : const Color(0xFFFFFBF7);
Color get _ombre2    => _darkMode ? const Color(0xFF1E1A17) : const Color(0xFFFFF8F3);
Color get _ombre3    => _darkMode ? const Color(0xFF29221D) : const Color(0xFFFFF3EF);
Color get _ombre4    => _darkMode ? const Color(0xFF312821) : const Color(0xFFFEEDE9);

// Borders, body copy, card surfaces — these MUST flip
Color get _outline   => _darkMode ? const Color(0xFFAD7F58) : const Color(0xFF6E5848);
Color get _brown     => _darkMode ? const Color(0xFFF2E1CA) : const Color(0xFF4E3828);
Color get _brownLt   => _darkMode ? const Color(0xFFDBB594) : const Color(0xFF7A5840);
Color get _brownSoft => _darkMode ? const Color(0xFFBD926C) : const Color(0xFF9A8070);
Color get _cardFill  => _darkMode ? const Color(0xFF29221D) : const Color(0xFFFFF8F4);
Color get _cream     => _darkMode ? const Color(0xFF1E1A17) : const Color(0xFFFDEFDB);

// Soft tinted backgrounds — flip to dark-tinted versions
Color get _pinkLt    => _darkMode ? const Color(0xFF411C35) : const Color(0xFFFFD5F5);
Color get _blueLt    => _darkMode ? const Color(0xFF102A4C) : const Color(0xFFDDF6FF);
Color get _greenLt   => _darkMode ? const Color(0xFF143125) : const Color(0xFFC2E8BC);
// Soft sage tint — used as the cash-pill / cash-stat background
// so the sage dollar-bill sticker reads as part of the surface
// instead of clashing with a warm gold/cream fill.
Color get _cashTint  => _darkMode ? const Color(0xFF29331B) : const Color(0xFFDCE8C9);

// Accent hues — same in both modes (CRUMBS-UI shade-9 rule)
Color get _pawClr => _darkMode ? const Color(0xFF231D18) : const Color(0xFFF8BCD0);
Color get _olive     => const Color(0xFF98A869);
Color get _oliveDk   => const Color(0xFF58772F);
Color get _pink      => const Color(0xFFFEA9D3);
Color get _pinkDk    => const Color(0xFFE890B8);
Color get _coral     => const Color(0xFFF7AEAE);
Color get _gold      => const Color(0xFFE4BC83);
Color get _goldGlow  => const Color(0xFFF8E080);
Color get _goldDk    => const Color(0xFFD0B048);
Color get _orange    => const Color(0xFFFFBC5C);
Color get _red       => const Color(0xFFEF6262);
Color get _green     => const Color(0xFFA8D5A3);
Color get _greenDk   => const Color(0xFF88B883);
Color get _purpleLt  => const Color(0xFFCDA8D8);

// Pill-only background flips — the sticker hues (_gold / _orange) stay
// identical across modes, but when they serve as a *pill* background with
// `_brown` (light cream in dark mode) layered on top, the text becomes
// illegible. These pill-bg getters return a dark CRUMBS shade-4 tint in
// dark mode so the cream text pops, while keeping the light pastel look
// in light mode where `_brown` (dark cocoa) already has enough contrast.
Color get _goldPillBg   => _darkMode ? const Color(0xFF3E2F15) : const Color(0xFFE4BC83);
Color get _orangePillBg => _darkMode ? const Color(0xFF402A15) : const Color(0xFFFFBC5C);

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
        // Hydrate the notification toggles from persisted prefs so the
        // Settings card reflects what the backend actually has. Defaults
        // are TRUE on the server for any row predating the columns, which
        // matches the current local default — so the UI doesn't flicker.
        _notificationsOn = (r.data['notifications_enabled'] as bool?) ?? true;
        _dailyRemindersOn = (r.data['daily_reminders_enabled'] as bool?) ?? true;
      });
    } catch (_) {}
  }

  // Optimistic toggle — flips locally, rolls back on server error.
  Future<void> _saveNotifPref({
    bool? notifications,
    bool? dailyReminders,
  }) async {
    final api = ref.read(apiServiceProvider);
    final payload = <String, dynamic>{};
    if (notifications != null) payload['notifications_enabled'] = notifications;
    if (dailyReminders != null) payload['daily_reminders_enabled'] = dailyReminders;
    if (payload.isEmpty) return;
    try {
      await api.put('/auth/me', data: payload);
    } catch (e) {
      // Roll back on failure so the UI stays truthful.
      if (!mounted) return;
      setState(() {
        if (notifications != null) _notificationsOn = !notifications;
        if (dailyReminders != null) _dailyRemindersOn = !dailyReminders;
      });
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text("Couldn't save preference — check your connection."),
      ));
    }
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
      Positioned.fill(child: Container(decoration: BoxDecoration(
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
          // Bottom nav reserved headroom. Narrow screens need ~120pt
          // because the sign-out row gets uncomfortably close to the nav
          // otherwise. Wide screens don't have the same crunch — the
          // settings card reaches a natural floor well above the nav —
          // so we trim the reserved space to cut the dead zone below
          // the card.
          final navH = isWide ? 40.0 : 120.0;

          return SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.fromLTRB(sidePad, 28, sidePad, 0),
                    child: _stag(0.0, _buildTopRow(ds)),
                  ),
                  // Generous gap between the top bar and the content row.
                  // ~80pt on wide / ~32pt on narrow gives the page a
                  // clear "header zone" before the cards start, and
                  // pushes the content down enough to balance the extra
                  // empty vertical space that used to live at the bottom.
                  SizedBox(height: isWide ? 80 : 32),

                  // WIDE: two-column layout where the avatar + XP bar
                  // anchor the top of the LEFT column (not the full-width
                  // hero we used to render). This lets the Settings card
                  // fill the RIGHT column from the very top, so the long
                  // settings list stops getting pushed below the fold.
                  // NARROW: stack everything; the full-width hero avatar
                  // still reads great when there's only one column.
                  if (isWide)
                    Padding(
                      padding: EdgeInsets.fromLTRB(sidePad, 0, sidePad, navH),
                      child: _stag(0.08, _buildTwoColumnContent(ds)),
                    )
                  else ...[
                    _stag(0.04, _buildAvatarArea(ds, contentW, sidePad)),
                    Padding(
                      padding: EdgeInsets.symmetric(horizontal: sidePad),
                      child: _stag(0.08, _buildXpDivider(ds)),
                    ),
                    const SizedBox(height: 10),
                    Padding(
                      padding: EdgeInsets.fromLTRB(sidePad, 0, sidePad, navH),
                      child: Column(children: [
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
              color: _cardFill,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: _outline, width: 2),
              boxShadow: [BoxShadow(color: _outline.withOpacity(0.45),
                offset: const Offset(2, 2), blurRadius: 0)]),
            child: Icon(Icons.chevron_left_rounded, size: 20, color: _outline),
          ),
        ),
        const SizedBox(width: 10),
        Text('Profile', style: TextStyle(
          fontFamily: 'Bitroad', fontSize: 22, color: _brown)),
        const Spacer(),
        _ProfilePill(icon: Icons.star_rounded,
          label: 'Lv. ${ds.level}', color: _goldPillBg),
        const SizedBox(width: 7),
        _ProfilePill(iconWidget: const _CashBill(size: 18),
          label: '${ds.cash}', color: _cashTint),
        const SizedBox(width: 7),
        _ProfilePill(icon: Icons.local_fire_department_rounded,
          label: '${ds.streak}', color: _orangePillBg),
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
        Text(ds.displayName, style: TextStyle(
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
        // Level badge — gradient flips to a dark amber sweep in dark mode
        // so the cream `_brown` text stays legible. Light mode keeps the
        // original glow→deep-gold feel.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: _darkMode
                ? [const Color(0xFF3E2F15), const Color(0xFF5C451F)]
                : [_goldGlow, _goldDk]),
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
              fontSize: 13, fontWeight: FontWeight.w700,
              // In dark mode `_brownSoft` (#BD926C) reads as "burnt tan"
              // which is too close to the amber gradient. Lift to `_brown`
              // (cream) so the title doesn't blur into the pill.
              color: _darkMode ? _brown : _brownSoft)),
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
      Icon(Icons.face_rounded, size: 36, color: CerebroTheme.pinkPop),
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
          style: TextStyle(fontFamily: 'Bitroad', fontSize: 12, color: _brownLt)),
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
                gradient: LinearGradient(colors: [_olive, _oliveDk]),
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
  //  LEFT column: hero avatar / identity / XP bar, then generous
  //  breathing space before Stats · Exchange · Tip. No more stuffing
  //  everything against the top edge — the avatar sits on its own
  //  "shelf" and the rest of the stack drops below.
  //  RIGHT column: Achievements sits on top of the Settings card, so
  //  the long settings list starts lower on the page and the hero +
  //  achievements hold the top half of the row as a matched pair.
  Widget _buildTwoColumnContent(DashboardState ds) {
    // NOTE: no IntrinsicHeight. Settings column is still taller than the
    // left column on long-list screens; forcing both to match would
    // balloon the scroll distance for no reason. Top-aligning the Row
    // and letting each column size itself keeps the layout compact.
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // LEFT — 42%
        Expanded(flex: 42, child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildCompactHero(ds),
            const SizedBox(height: 8),
            _buildXpDivider(ds),
            // Was 28 — eased to 22. Tighter than the original but still
            // leaves real breathing room above the stats so nothing looks
            // stacked on top of the XP bar.
            const SizedBox(height: 22),
            _buildStatsGrid(ds),
            const SizedBox(height: 16),
            _buildExchangeCard(ds),
            const SizedBox(height: 16),
            _buildTip(ds),
          ],
        )),
        const SizedBox(width: 30),
        // RIGHT — 58%
        Expanded(flex: 58, child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildAchievementsCard(),
            const SizedBox(height: 18),
            _buildSettingsCard(),
          ],
        )),
      ],
    );
  }

  //  COMPACT HERO (wide-mode left column)
  //  Stacks avatar → name/email/affiliation → level badge vertically so
  //  it lives inside the 42% left column. The full-width Stack hero (see
  //  _buildAvatarArea) is reserved for narrow mode where it has the
  //  whole content row to breathe in.
  Widget _buildCompactHero(DashboardState ds) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Avatar + edit badge.
        // Approach: a fixed-width inner SizedBox (wraps just the avatar's
        // visible footprint) is centered in the column. The edit badge is
        // Positioned relative to that inner box — not the full column —
        // so it sits right by the avatar's hair instead of floating at
        // the column's right edge.
        Center(
          child: SizedBox(
            width: 300,
            // Was 280 — trimmed to 245 so the name/email/affiliation/level
            // badge sit a bit higher in the left column without the column
            // feeling cramped. The avatar stays centered in the box.
            height: 245,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: () => context.go('/avatar'),
                  child: ds.avatarConfig != null
                    ? OverflowBox(
                        maxWidth: 560, maxHeight: 560,
                        // Bumped from 0.40 → 0.50 so the avatar fills more
                        // of the hero slot (user asked for it a bit bigger).
                        child: Transform.scale(
                          scale: 0.50,
                          child: AliveAvatar(
                            config: ds.avatarConfig!,
                            size: 290,
                          ),
                        ),
                      )
                    : _placeholderAvatar(),
                ),
                // Edit badge — hugs the avatar's head. Tapping it routes
                // to /avatar (AvatarCustomizationScreen), same as tapping
                // the avatar body itself.
                Positioned(
                  top: 20,
                  right: 18,
                  child: GestureDetector(
                    onTap: () => context.go('/avatar'),
                    child: _editBadge(),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 14),
        Text(ds.displayName,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Bitroad', fontSize: 22, color: _brown, height: 1.1)),
        const SizedBox(height: 2),
        Text(_email ?? '',
          textAlign: TextAlign.center,
          style: GoogleFonts.gaegu(
            fontSize: 13, fontWeight: FontWeight.w700, color: _brownSoft)),
        if (_university != null || _course != null) ...[
          const SizedBox(height: 2),
          Text([_university, _course].whereType<String>().join(' · '),
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(fontSize: 11,
              fontWeight: FontWeight.w600, color: _brownLt)),
        ],
        const SizedBox(height: 8),
        // Level badge — dark-amber gradient in dark mode (same treatment
        // as the narrow-layout badge above) so cream text stays legible.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: _darkMode
                ? [const Color(0xFF3E2F15), const Color(0xFF5C451F)]
                : [_goldGlow, _goldDk]),
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
              fontSize: 13, fontWeight: FontWeight.w700,
              color: _darkMode ? _brown : _brownSoft)),
          ]),
        ),
      ],
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
            Text(val, style: TextStyle(
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
            color: _cardFill.withOpacity(0.88),
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
                Text('$_exchangeAmount', style: TextStyle(
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
    // Runtime list: _cream/_blueLt/_pinkLt are mode-aware getters now.
    final achColors = [_cream, _coral, _blueLt, _gold, _pinkLt];

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
        // width: double.infinity so the card stretches to match the
        // Settings card beneath it — the inner Wrap otherwise collapses
        // the container to the chip row's intrinsic width (which on wide
        // screens leaves ~400pt of empty space to the right).
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _cardFill.withOpacity(0.88),
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
    // xpForNext / totalXp are now in different units (per-level bar vs
    // cumulative total), so we use the dedicated xpToNextLevel getter.
    final xpToNext = ds.xpToNextLevel;
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
            color: _cardFill,
            shape: BoxShape.circle,
            border: Border.all(color: _outline.withOpacity(0.3), width: 1.5)),
          child: Icon(Icons.lightbulb_rounded, size: 12, color: _pinkDk),
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
            color: _cardFill.withOpacity(0.88),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: _outline, width: 2),
            boxShadow: [BoxShadow(color: _outline.withOpacity(0.4),
              offset: const Offset(3, 3), blurRadius: 0)]),
          child: Column(
            // Left-align group labels ("Account", "Setup", …). Without
            // this, Column defaults to centered, and the tiny caps labels
            // float to the middle of the card while the wider setting
            // rows fill the full width — it reads as "misaligned".
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
            _groupLabel('Account'),
            _settingsRow(Icons.face_rounded, 'Edit Avatar', _pinkLt,
              onTap: () => context.go('/avatar')),
            _settingsDivider(),
            _settingsRow(Icons.lock_rounded, 'Change Password', _purpleLt.withOpacity(0.35),
              onTap: () => _showChangePassword()),

            // Only the "slow-changing" wizard fields live here. Daily
            // Goals and Medications were pulled on purpose — users
            // change those frequently from the dashboard quest card and
            // the Health → Medications tab respectively, so surfacing
            // them under "Setup" just invites drift. Every row below
            // opens a focused edit sheet that round-trips the matching
            // wizard data to /auth/me.
            _groupLabel('Setup'),
            _settingsRow(Icons.school_rounded, 'Academic Info', _blueLt,
              onTap: () => _openEditSheet(SettingsSection.academic)),
            _settingsDivider(),
            _settingsRow(Icons.timer_rounded, 'Study Time', _greenLt,
              onTap: () => _openEditSheet(SettingsSection.studyTime)),
            _settingsDivider(),
            _settingsRow(Icons.bedtime_rounded, 'Sleep Schedule', _purpleLt.withOpacity(0.35),
              onTap: () => _openEditSheet(SettingsSection.sleep)),
            _settingsDivider(),
            _settingsRow(Icons.favorite_rounded, 'Medical Conditions', _pink,
              onTap: () => _openEditSheet(SettingsSection.conditions)),

            _groupLabel('Preferences'),
            // Dark Mode — reads/writes the themeModeProvider. Flipping
            // this runs through ThemeModeNotifier.setMode() which
            // persists the choice and updates CerebroTheme's brightness
            // notifier, so every cream/olive/brown in the app re-renders
            // into its dark sibling on the next frame.
            Builder(builder: (_) {
              final mode = ref.watch(themeModeProvider);
              final isDark = mode == ThemeMode.dark
                  || (mode == ThemeMode.system
                      && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
              return _settingsRow(
                isDark ? Icons.dark_mode_rounded : Icons.wb_sunny_rounded,
                'Dark Mode',
                _cream,
                trailing: _toggle(isDark, (v) {
                  ref.read(themeModeProvider.notifier)
                    .setMode(v ? ThemeMode.dark : ThemeMode.light);
                }),
              );
            }),
            _settingsDivider(),
            _settingsRow(Icons.notifications_rounded, 'Notifications', _gold,
              trailing: _toggle(_notificationsOn, (v) {
                setState(() => _notificationsOn = v);
                _saveNotifPref(notifications: v);
              })),
            _settingsDivider(),
            _settingsRow(Icons.edit_rounded, 'Daily Reminders', _olive.withOpacity(0.35),
              trailing: _toggle(_dailyRemindersOn, (v) {
                setState(() => _dailyRemindersOn = v);
                _saveNotifPref(dailyReminders: v);
              })),

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

  //  SETUP EDIT SHEET LAUNCHER
  //  Opens a bottom sheet dedicated to one wizard section. Each sheet
  //  fetches current /auth/me values on open and PUTs back on save, so
  //  changes flow through the same pipeline as the initial wizard.
  void _openEditSheet(SettingsSection section) async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _SetupEditSheet(
        section: section,
        api: ref.read(apiServiceProvider),
      ),
    );
    // On successful save, refresh the surfaces that read this data.
    // Profile pills/headers pull from /auth/me; the dashboard + quest
    // card pull from dashboardProvider.loadAll(). Without this refresh
    // the user sees stale data until the next full app boot.
    if (saved == true && mounted) {
      _loadProfile();
      try {
        await ref.read(dashboardProvider.notifier).loadAll();
      } catch (_) {}
    }
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
        // Slightly tighter vertical padding (was 9) — settings card is
        // tall enough to clip behind the nav bar on short screens; this
        // trims a few tens of pixels off the total height without losing
        // tap-target size (still ~46pt with the 28pt icon + padding).
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
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
              color: _cardFill,
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
      Text(label, style: TextStyle(
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

  // Every settings-surface dialog (Change Password, Sign Out, About)
  // uses this wrapper so they all share the same rounded card, outline,
  // header strip, and close button. This matches the _SetupEditSheet
  // bottom-sheet shell in spirit so the whole Settings surface reads as
  // one family of modals.
  Widget _settingsDialogShell({
    required BuildContext ctx,
    required String title,
    required Color headerColor,
    required Widget body,
    double maxWidth = 420,
  }) {
    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        constraints: BoxConstraints(maxWidth: maxWidth),
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
              color: headerColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(19))),
            child: Row(children: [
              Expanded(child: Text(title,
                style: TextStyle(fontFamily: 'Bitroad',
                  fontSize: 20, color: _brown))),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: _cardFill.withOpacity(0.25),
                    shape: BoxShape.circle),
                  child: Icon(Icons.close_rounded, size: 16, color: _brown),
                ),
              ),
            ]),
          ),
          Padding(padding: const EdgeInsets.all(20), child: body),
        ]),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(context: context, builder: (ctx) => _settingsDialogShell(
      ctx: ctx,
      title: 'Sign Out?',
      headerColor: _coral,
      body: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 50, height: 50,
          decoration: BoxDecoration(color: _coral,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: _outline, width: 2)),
          child: const Icon(Icons.logout_rounded, size: 24,
            color: Colors.white)),
        const SizedBox(height: 12),
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
      ]),
    ));
  }

  void _showAbout(BuildContext context) {
    showDialog(context: context, builder: (ctx) => _settingsDialogShell(
      ctx: ctx,
      title: 'About CEREBRO',
      headerColor: CerebroTheme.pinkPop,
      body: Column(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 52, height: 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
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
      ]),
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
                style: TextStyle(fontFamily: 'Bitroad',
                  fontSize: 20, color: _brown))),
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: Container(
                  width: 30, height: 30,
                  decoration: BoxDecoration(
                    color: _cardFill.withOpacity(0.25),
                    shape: BoxShape.circle),
                  child: Icon(Icons.close_rounded, size: 16, color: _brown),
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

//  SETUP EDIT SHEET — shared bottom-sheet for per-section edits.
//  One enum value per row in the Setup group. Each section shows a
//  different body, but all share the loading shell + save button.
enum SettingsSection {
  academic,    // institution / university / course / year / degree_level
  studyTime,   // daily_study_hours
  sleep,       // bedtime / wake_time
  dailyGoals,  // initial_habits (capped at 4, reseeds today's quests)
  conditions,  // medical_conditions
}

class _SetupEditSheet extends StatefulWidget {
  final SettingsSection section;
  final dynamic api;
  const _SetupEditSheet({required this.section, required this.api});
  @override
  State<_SetupEditSheet> createState() => _SetupEditSheetState();
}

class _SetupEditSheetState extends State<_SetupEditSheet> {
  bool _loading = true;
  bool _saving = false;
  Map<String, dynamic> _me = {};

  // Scratch state — only the fields relevant to the current section
  // actually get populated. Kept as loose maps so the sheet body can
  // mutate whatever it needs.
  final _uniCtrl      = TextEditingController();
  final _courseCtrl   = TextEditingController();
  int _yearOfStudy    = 1;
  String? _degreeLevel;
  String? _institutionType;
  double _dailyStudyHours = 3.0;
  TimeOfDay _bedtime  = const TimeOfDay(hour: 23, minute: 0);
  TimeOfDay _wakeTime = const TimeOfDay(hour: 7, minute: 30);
  final Set<String> _habits = {};
  final Set<String> _conditions = {};
  final _customConditionCtrl = TextEditingController();

  static const _habitLabels = [
    'Drink Water', 'Exercise', 'Read', 'Meditate', 'No Junk Food',
    'Walk 10k Steps', 'No Social Media', 'Study 2+ Hours', 'Sleep Before 12',
  ];
  static const _conditionPresets = [
    'Migraine', 'ADHD', 'Anxiety', 'Depression', 'PCOS', 'Asthma',
    'Diabetes', 'IBS', 'Insomnia', 'Hypertension', 'Dyslexia', 'Eczema',
  ];
  static const _maxDailyGoals = 4;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _uniCtrl.dispose();
    _courseCtrl.dispose();
    _customConditionCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final r = await widget.api.get('/auth/me');
      if (r.statusCode == 200 && r.data is Map) {
        _me = Map<String, dynamic>.from(r.data);
        _uniCtrl.text    = (_me['university']   ?? '').toString();
        _courseCtrl.text = (_me['course']       ?? '').toString();
        _yearOfStudy     = (_me['year_of_study'] as int?) ?? 1;
        _degreeLevel     = _me['degree_level']  as String?;
        _institutionType = _me['institution_type'] as String?;
        _dailyStudyHours = ((_me['daily_study_hours'] ?? 3.0) as num).toDouble();
        _bedtime  = _parseTime(_me['bedtime']  as String?) ?? _bedtime;
        _wakeTime = _parseTime(_me['wake_time'] as String?) ?? _wakeTime;
        _habits
          ..clear()
          ..addAll(((_me['initial_habits'] as List?) ?? []).map((e) => e.toString()));
        _conditions
          ..clear()
          ..addAll(((_me['medical_conditions'] as List?) ?? []).map((e) => e.toString()));
      }
    } catch (_) {}
    if (mounted) setState(() => _loading = false);
  }

  TimeOfDay? _parseTime(String? s) {
    if (s == null || s.isEmpty) return null;
    final parts = s.split(':');
    if (parts.length < 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    return TimeOfDay(hour: h, minute: m);
  }

  String _fmtTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _save() async {
    setState(() => _saving = true);
    Map<String, dynamic> payload = {};
    switch (widget.section) {
      case SettingsSection.academic:
        payload = {
          'institution_type': _institutionType,
          'university': _uniCtrl.text.trim(),
          'course': _courseCtrl.text.trim(),
          'year_of_study': _yearOfStudy,
          if (_degreeLevel != null) 'degree_level': _degreeLevel,
        };
        break;
      case SettingsSection.studyTime:
        payload = {'daily_study_hours': _dailyStudyHours};
        break;
      case SettingsSection.sleep:
        final bed = _bedtime.hour * 60 + _bedtime.minute;
        final wake = _wakeTime.hour * 60 + _wakeTime.minute;
        var diff = wake - bed; if (diff <= 0) diff += 24 * 60;
        payload = {
          'bedtime': _fmtTime(_bedtime),
          'wake_time': _fmtTime(_wakeTime),
          'sleep_hours_target': diff / 60.0,
        };
        break;
      case SettingsSection.dailyGoals:
        payload = {'initial_habits': _habits.toList()};
        break;
      case SettingsSection.conditions:
        payload = {'medical_conditions': _conditions.toList()};
        break;
    }
    try {
      await widget.api.put('/auth/me', data: payload);

      // When the user updates their Daily Goals picks we also need to
      // regenerate the `/daily/habits` table rows so the Today's Quest
      // card reflects the new choices. Without this the user row's
      // `initial_habits` array moves but the actual quest list stays the
      // same and the change feels like it "didn't save".
      if (widget.section == SettingsSection.dailyGoals) {
        try {
          final listRes = await widget.api.get('/daily/habits');
          if (listRes.statusCode == 200) {
            for (final h in ((listRes.data as List?) ?? [])) {
              final hid = h['id'];
              if (hid == null) continue;
              try {
                await widget.api.delete('/daily/habits/$hid');
              } catch (_) {}
            }
          }
        } catch (_) {}
        // Re-seed from the updated initial_habits (or 4-default fallback
        // if the user cleared their picks entirely).
        try {
          await widget.api.post('/daily/habits/seed-defaults');
        } catch (_) {}
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Saved!',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          backgroundColor: _olive,
          duration: const Duration(seconds: 1),
        ));
        Navigator.pop(context, true); // signal "saved" to the caller
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Save failed — check your connection.',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w700)),
          backgroundColor: _coral,
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String get _title {
    switch (widget.section) {
      case SettingsSection.academic:   return 'Academic Info';
      case SettingsSection.studyTime:  return 'Study Time';
      case SettingsSection.sleep:      return 'Sleep Schedule';
      case SettingsSection.dailyGoals: return 'Daily Goals';
      case SettingsSection.conditions: return 'Medical Conditions';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: Container(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.86,
        ),
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
          border: Border(
            top:   BorderSide(color: _outline, width: 3),
            left:  BorderSide(color: _outline, width: 3),
            right: BorderSide(color: _outline, width: 3),
          ),
        ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Grab handle
          Padding(padding: const EdgeInsets.only(top: 10, bottom: 6),
            child: Container(width: 40, height: 4,
              decoration: BoxDecoration(
                color: _outline.withOpacity(0.2),
                borderRadius: BorderRadius.circular(2),
              ))),
          // Title row
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 4, 14, 10),
            child: Row(children: [
              Expanded(child: Text(_title,
                style: TextStyle(
                  fontFamily: 'Bitroad', fontSize: 22, color: _brown))),
              IconButton(
                icon: Icon(Icons.close_rounded, color: _brownLt),
                onPressed: () => Navigator.pop(context),
              ),
            ]),
          ),
          // Body
          Flexible(child: _loading
            ? const Padding(padding: EdgeInsets.all(40),
                child: Center(child: CircularProgressIndicator()))
            : SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(22, 4, 22, 14),
                child: _body(),
              )),
          // Save footer
          if (!_loading) Padding(
            padding: const EdgeInsets.fromLTRB(22, 6, 22, 22),
            child: GestureDetector(
              onTap: _saving ? null : _save,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                height: 48,
                decoration: BoxDecoration(
                  color: _saving ? _outline.withOpacity(0.2) : _olive,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: _outline, width: 2),
                  boxShadow: _saving ? [] : [BoxShadow(
                    color: _outline.withOpacity(0.2),
                    offset: const Offset(0, 3), blurRadius: 0)],
                ),
                child: Center(child: _saving
                  ? const SizedBox(width: 20, height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                  : Text('SAVE', style: GoogleFonts.nunito(
                      fontSize: 16, fontWeight: FontWeight.w800,
                      color: Colors.white, letterSpacing: 1.0))),
              ),
            ),
          ),
        ]),
      ),
    );
  }

  Widget _body() {
    switch (widget.section) {
      case SettingsSection.academic:   return _academicBody();
      case SettingsSection.studyTime:  return _studyTimeBody();
      case SettingsSection.sleep:      return _sleepBody();
      case SettingsSection.dailyGoals: return _goalsBody();
      case SettingsSection.conditions: return _conditionsBody();
    }
  }

  Widget _academicBody() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _label('Institution type'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final t in ['school', 'sixth_form', 'college', 'university'])
          _selectChip(
            label: t.replaceAll('_', ' ').toUpperCase(),
            selected: _institutionType == t,
            onTap: () => setState(() => _institutionType = t),
          ),
      ]),
      const SizedBox(height: 14),
      _label('Institution name'),
      _input(_uniCtrl, 'e.g. London Metropolitan University'),
      const SizedBox(height: 14),
      _label('Course / Programme'),
      _input(_courseCtrl, 'e.g. BSc Computer Science'),
      const SizedBox(height: 14),
      _label('Year of study'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (int i = 1; i <= 6; i++)
          _selectChip(
            label: 'Year $i',
            selected: _yearOfStudy == i,
            onTap: () => setState(() => _yearOfStudy = i),
          ),
      ]),
      const SizedBox(height: 14),
      _label('Degree level'),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final d in ['undergraduate', 'masters', 'phd'])
          _selectChip(
            label: d.toUpperCase(),
            selected: _degreeLevel == d,
            onTap: () => setState(() => _degreeLevel = d),
          ),
      ]),
    ]);
  }

  Widget _studyTimeBody() {
    return Column(crossAxisAlignment: CrossAxisAlignment.center, children: [
      const SizedBox(height: 10),
      Text('${_dailyStudyHours.toStringAsFixed(_dailyStudyHours % 1 == 0 ? 0 : 1)} hours / day',
        style: TextStyle(fontFamily: 'Bitroad', fontSize: 32, color: _brown)),
      const SizedBox(height: 8),
      Slider(
        value: _dailyStudyHours,
        min: 0.5, max: 8, divisions: 15,
        activeColor: _olive,
        inactiveColor: _outline.withOpacity(0.2),
        onChanged: (v) => setState(() => _dailyStudyHours = v),
      ),
      const SizedBox(height: 8),
      Text('Drives the study coach\'s session suggestions + smart scheduler.',
        textAlign: TextAlign.center,
        style: GoogleFonts.gaegu(fontSize: 14,
          fontWeight: FontWeight.w700, color: _brownLt)),
    ]);
  }

  Widget _sleepBody() {
    final bed = _bedtime.hour * 60 + _bedtime.minute;
    final wake = _wakeTime.hour * 60 + _wakeTime.minute;
    var diff = wake - bed; if (diff <= 0) diff += 24 * 60;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Expanded(child: _timeTile('Bedtime', _bedtime, () async {
          final t = await showTimePicker(context: context, initialTime: _bedtime);
          if (t != null) setState(() => _bedtime = t);
        })),
        const SizedBox(width: 10),
        Expanded(child: _timeTile('Wake Up', _wakeTime, () async {
          final t = await showTimePicker(context: context, initialTime: _wakeTime);
          if (t != null) setState(() => _wakeTime = t);
        })),
      ]),
      const SizedBox(height: 14),
      Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: _greenLt.withOpacity(0.4),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _greenDk, width: 2),
        ),
        child: Text('${(diff / 60).toStringAsFixed(1)} hours of sleep',
          textAlign: TextAlign.center,
          style: GoogleFonts.gaegu(fontSize: 17,
            fontWeight: FontWeight.w700, color: _brown)),
      ),
    ]);
  }

  Widget _goalsBody() {
    final atCap = _habits.length >= _maxDailyGoals;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('${_habits.length} / $_maxDailyGoals picked',
        style: GoogleFonts.nunito(
          fontSize: 13, fontWeight: FontWeight.w700,
          color: atCap ? _oliveDk : _brownLt)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final h in _habitLabels)
          Opacity(
            opacity: (!_habits.contains(h) && atCap) ? 0.5 : 1.0,
            child: _selectChip(
              label: h,
              selected: _habits.contains(h),
              onTap: () {
                if (_habits.contains(h)) {
                  setState(() => _habits.remove(h));
                } else if (!atCap) {
                  setState(() => _habits.add(h));
                }
              },
            ),
          ),
      ]),
      const SizedBox(height: 12),
      Text('Changes reseed tomorrow\'s quest list.',
        style: GoogleFonts.gaegu(fontSize: 14,
          fontWeight: FontWeight.w700, color: _brownLt)),
    ]);
  }

  Widget _conditionsBody() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text('Tap any that apply, or add your own',
        style: GoogleFonts.gaegu(fontSize: 15,
          fontWeight: FontWeight.w700, color: _brownLt)),
      const SizedBox(height: 10),
      Wrap(spacing: 8, runSpacing: 8, children: [
        for (final c in _conditionPresets)
          _selectChip(
            label: c,
            selected: _conditions.contains(c),
            onTap: () => setState(() {
              if (_conditions.contains(c)) _conditions.remove(c);
              else _conditions.add(c);
            }),
          ),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        Expanded(child: _input(_customConditionCtrl, 'Add another…')),
        const SizedBox(width: 10),
        GestureDetector(
          onTap: () {
            final raw = _customConditionCtrl.text.trim();
            if (raw.isEmpty) return;
            final norm = raw.split(RegExp(r'\s+'))
                .where((s) => s.isNotEmpty)
                .map((w) => w[0].toUpperCase() + w.substring(1).toLowerCase())
                .join(' ');
            setState(() {
              _conditions.add(norm);
              _customConditionCtrl.clear();
            });
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: _pink,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: _outline, width: 2),
            ),
            child: const Text('ADD',
              style: TextStyle(fontFamily: 'Bitroad', fontSize: 14,
                color: Colors.white)),
          ),
        ),
      ]),
      if (_conditions.any((c) => !_conditionPresets.contains(c))) ...[
        const SizedBox(height: 12),
        Text('Your additions', style: GoogleFonts.nunito(
          fontSize: 12, fontWeight: FontWeight.w700, color: _brownLt)),
        const SizedBox(height: 8),
        Wrap(spacing: 8, runSpacing: 8, children: [
          for (final c in _conditions.where((c) => !_conditionPresets.contains(c)))
            GestureDetector(
              onTap: () => setState(() => _conditions.remove(c)),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: _pinkLt,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: _outline, width: 2),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(c, style: GoogleFonts.gaegu(
                    fontSize: 14, fontWeight: FontWeight.w700, color: _brown)),
                  const SizedBox(width: 6),
                  Icon(Icons.close_rounded, size: 14, color: _brown),
                ]),
              ),
            ),
        ]),
      ],
    ]);
  }

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(t, style: GoogleFonts.nunito(
      fontSize: 13, fontWeight: FontWeight.w700, color: _brownLt)));

  Widget _input(TextEditingController c, String hint) => TextField(
    controller: c,
    style: GoogleFonts.nunito(fontSize: 15,
      fontWeight: FontWeight.w600, color: _brown),
    decoration: InputDecoration(
      hintText: hint,
      hintStyle: GoogleFonts.nunito(fontSize: 14, color: _brownLt),
      filled: true,
      fillColor: _cardFill,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _outline, width: 2)),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _outline, width: 2)),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: _pinkDk, width: 2)),
    ),
  );

  Widget _selectChip({required String label, required bool selected, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? _pinkLt : _cardFill,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: _outline, width: 2),
          boxShadow: selected ? [BoxShadow(
            color: _outline.withOpacity(0.3),
            offset: const Offset(2, 2), blurRadius: 0)] : [],
        ),
        child: Text(label, style: GoogleFonts.gaegu(
          fontSize: 14, fontWeight: FontWeight.w700,
          color: selected ? _brown : _brownLt)),
      ),
    );
  }

  Widget _timeTile(String label, TimeOfDay t, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: _cardFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: _outline, width: 2),
        ),
        child: Column(children: [
          Text(label.toUpperCase(),
            style: GoogleFonts.nunito(
              fontSize: 10, fontWeight: FontWeight.w700,
              letterSpacing: 0.8, color: _brownLt)),
          const SizedBox(height: 3),
          Text('${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontFamily: 'Bitroad', fontSize: 22, color: _brown)),
        ]),
      ),
    );
  }
}
