/// CEREBRO - Profile Tab (Dashboard Style – Soft, Cozy, Warm)
/// User profile with real data binding, avatar display, stats, settings, and logout.
/// EXACT style match to dashboard_tab.dart: thin 2px borders, soft shadows, pawprint ombré background.

import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cerebro_app/config/constants.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:cerebro_app/models/avatar_config.dart';
import 'package:cerebro_app/widgets/avatar_display.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
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

class ProfileTab extends ConsumerStatefulWidget {
  const ProfileTab({super.key});

  @override
  ConsumerState<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends ConsumerState<ProfileTab>
    with TickerProviderStateMixin {
  String? _university;
  String? _course;
  String? _email;
  bool _loadingExtended = false;
  late AnimationController _enterCtrl;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..forward();
    _loadExtendedProfile();
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadExtendedProfile() async {
    setState(() => _loadingExtended = true);
    try {
      final apiService = ref.read(apiServiceProvider);
      final response = await apiService.get('/auth/me');
      if (response.statusCode == 200) {
        final data = response.data;
        setState(() {
          _university = data['university'] as String?;
          _course = data['course'] as String?;
          _email = data['email'] as String?;
        });
      }
    } catch (_) {
      // Silent fail - use default values
    } finally {
      setState(() => _loadingExtended = false);
    }
  }

  String _getLevelTitle(int level) {
    if (level <= 5) return 'Novice';
    if (level <= 10) return 'Apprentice';
    if (level <= 20) return 'Scholar';
    return 'Master';
  }

  Widget _stagger(double delay, Widget child) {
    return AnimatedBuilder(
      animation: _enterCtrl,
      builder: (_, __) {
        final t = Curves.easeOutCubic.transform(
          ((_enterCtrl.value - delay) / (1.0 - delay)).clamp(0.0, 1.0));
        return Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 18 * (1 - t)),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final dashboard = ref.watch(dashboardProvider);

    return Stack(
      children: [
        Positioned.fill(
          child: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [_ombre1, _ombre2, _ombre3, _ombre4],
                stops: [0.0, 0.3, 0.6, 1.0],
              ),
            ),
          ),
        ),
        Positioned.fill(
          child: CustomPaint(
            painter: _PawPrintBg(),
          ),
        ),
        Positioned(
          top: -120,
          left: 0,
          right: 0,
          child: Container(
            height: 300,
            decoration: BoxDecoration(
              gradient: RadialGradient(
                center: Alignment.topCenter,
                radius: 1.0,
                colors: [
                  _goldGlow.withOpacity(0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            child: Column(
              children: [
                _stagger(0.0, _buildProfileHeader(dashboard)),

                const SizedBox(height: 18),

                _stagger(0.06, _buildXpProgressCard(dashboard)),

                const SizedBox(height: 18),

                _stagger(0.09, _buildExchangeCard(dashboard)),

                const SizedBox(height: 18),

                _stagger(0.12, _buildStatsRow(dashboard)),

                const SizedBox(height: 18),

                _stagger(0.18, _buildAchievementsSection()),

                const SizedBox(height: 18),

                _stagger(0.24, _buildSettingsSection()),

                const SizedBox(height: 18),

                _stagger(0.30, _buildSignOutButton()),

                const SizedBox(height: 12),

                Text(
                  'CEREBRO v1.0 • Made with love',
                  style: GoogleFonts.nunito(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _brown.withOpacity(0.7),
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildProfileHeader(DashboardState dashboard) {
    return Container(
      width: double.infinity,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            // Pink header strip
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF0C0B8), _pinkHdr],
                ),
              ),
              child: Text(
                'My Profile',
                style: GoogleFonts.gaegu(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _brown,
                ),
              ),
            ),
            // Content
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  // Avatar with edit badge
                  GestureDetector(
                    onTap: () => context.go('/avatar'),
                    child: Stack(
                      alignment: Alignment.bottomRight,
                      children: [
                        Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(60),
                            border: Border.all(
                              color: _outline.withOpacity(0.25),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _outline.withOpacity(0.06),
                                offset: const Offset(0, 4),
                                blurRadius: 12,
                              ),
                            ],
                            color: _cardFill,
                          ),
                          child: dashboard.avatarConfig != null
                              ? ClipRRect(
                                  borderRadius: BorderRadius.circular(58),
                                  child: AvatarDisplay(
                                    config: dashboard.avatarConfig!,
                                    size: 120,
                                    backgroundColor: _cardFill,
                                  ),
                                )
                              : Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: _ombre2,
                                    borderRadius: BorderRadius.circular(58),
                                  ),
                                  child: const Icon(
                                    Icons.face_rounded,
                                    size: 64,
                                    color: CerebroTheme.pinkPop,
                                  ),
                                ),
                        ),
                        // Edit badge (small pink circle with brush icon)
                        Container(
                          width: 38,
                          height: 38,
                          decoration: BoxDecoration(
                            color: CerebroTheme.pinkPop,
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: _outline.withOpacity(0.25),
                              width: 2,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: _outline.withOpacity(0.06),
                                offset: const Offset(0, 2),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.brush_rounded,
                            size: 18,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Display name
                  Text(
                    dashboard.displayName,
                    style: GoogleFonts.gaegu(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: _brown,
                    ),
                  ),

                  const SizedBox(height: 6),

                  // Level & title
                  Text(
                    'Lv. ${dashboard.level} • ${_getLevelTitle(dashboard.level)}',
                    style: GoogleFonts.nunito(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: _brownLt,
                    ),
                  ),

                  // University & course (if available)
                  if (_university != null || _course != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      [_university, _course].whereType<String>().join(' • '),
                      style: GoogleFonts.nunito(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: _brownLt,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildXpProgressCard(DashboardState dashboard) {
    final nextLevelXp = dashboard.xpForNext;

    return Container(
      width: double.infinity,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            // Gold header strip
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [_goldGlow, _goldDk],
                ),
              ),
              child: Text(
                'Level & XP',
                style: GoogleFonts.gaegu(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _brown,
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Level circle
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: _goldGlow.withOpacity(0.2),
                      border: Border.all(
                        color: _outline.withOpacity(0.25),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _outline.withOpacity(0.06),
                          offset: const Offset(0, 2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        '${dashboard.level}',
                        style: GoogleFonts.gaegu(
                          fontSize: 36,
                          fontWeight: FontWeight.w700,
                          color: _brown,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Coins pill
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _goldGlow.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: _outline.withOpacity(0.25),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _outline.withOpacity(0.06),
                          offset: const Offset(0, 2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.monetization_on_rounded,
                          size: 18,
                          color: _brown,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${dashboard.cash}',
                          style: GoogleFonts.nunito(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: _brown,
                          ),
                        ),
                        Text(
                          ' Cash',
                          style: GoogleFonts.nunito(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: _brownLt,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 14),

                  // XP progress bar (soft thin style)
                  Container(
                    height: 16,
                    decoration: BoxDecoration(
                      color: _ombre3,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: _outline.withOpacity(0.25),
                        width: 2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _outline.withOpacity(0.06),
                          offset: const Offset(0, 2),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: FractionallySizedBox(
                        alignment: Alignment.centerLeft,
                        widthFactor: dashboard.xpProgress,
                        child: Container(
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [_greenLt, _green],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 10),

                  // XP text
                  Text(
                    '${dashboard.totalXp} / $nextLevelXp XP to Level ${dashboard.level + 1}',
                    style: GoogleFonts.nunito(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: _brownLt,
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

  int _exchangeAmount = 1; // how many cash to exchange

  Widget _buildExchangeCard(DashboardState dashboard) {
    final maxExchangeable = dashboard.exchangeableCash;
    final xpCost = _exchangeAmount * xpPerCash;
    final canExchange = maxExchangeable > 0 && _exchangeAmount <= maxExchangeable;

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft, end: Alignment.bottomRight,
          colors: [Color(0xFFF0FFF0), Color(0xFFFFF8F4)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _outline, width: 3),
        boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
            offset: const Offset(0, 4), blurRadius: 0)],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(17),
        child: Column(children: [
          // Header strip
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
            decoration: const BoxDecoration(
              gradient: LinearGradient(colors: [_greenLt, _green]),
            ),
            child: Row(children: [
              const Icon(Icons.swap_horiz_rounded, size: 20, color: Colors.white),
              const SizedBox(width: 8),
              Text('XP → Cash Exchange', style: GoogleFonts.gaegu(
                fontSize: 20, fontWeight: FontWeight.w700, color: _brown)),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              // Current balances
              Row(children: [
                Expanded(child: _balancePill(
                  icon: Icons.star_rounded,
                  label: 'XP',
                  value: '${dashboard.totalXp}',
                  color: const Color(0xFFE8C840),
                )),
                const SizedBox(width: 12),
                Expanded(child: _balancePill(
                  icon: Icons.monetization_on_rounded,
                  label: 'Cash',
                  value: '${dashboard.cash}',
                  color: _green,
                )),
              ]),
              const SizedBox(height: 16),

              // Exchange rate label
              Text('20 XP = 1 Cash', style: GoogleFonts.gaegu(
                fontSize: 16, fontWeight: FontWeight.w700, color: _brownLt)),
              const SizedBox(height: 12),

              // Amount selector
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Minus button
                  GestureDetector(
                    onTap: () {
                      if (_exchangeAmount > 1) {
                        setState(() => _exchangeAmount--);
                      }
                    },
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _exchangeAmount > 1
                            ? _pinkHdr.withOpacity(0.3)
                            : _outline.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _outline.withOpacity(0.3), width: 2),
                      ),
                      child: Icon(Icons.remove_rounded, size: 18,
                          color: _exchangeAmount > 1 ? _brown : _brownLt.withOpacity(0.4)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Amount display
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                    decoration: BoxDecoration(
                      color: _goldGlow.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _outline.withOpacity(0.2), width: 2),
                    ),
                    child: Column(children: [
                      Text('$_exchangeAmount', style: GoogleFonts.gaegu(
                        fontSize: 28, fontWeight: FontWeight.w700, color: _brown)),
                      Text('Cash', style: GoogleFonts.nunito(
                        fontSize: 11, fontWeight: FontWeight.w600, color: _brownLt)),
                    ]),
                  ),
                  const SizedBox(width: 16),
                  // Plus button
                  GestureDetector(
                    onTap: () {
                      if (_exchangeAmount < maxExchangeable) {
                        setState(() => _exchangeAmount++);
                      }
                    },
                    child: Container(
                      width: 36, height: 36,
                      decoration: BoxDecoration(
                        color: _exchangeAmount < maxExchangeable
                            ? _greenLt.withOpacity(0.5)
                            : _outline.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _outline.withOpacity(0.3), width: 2),
                      ),
                      child: Icon(Icons.add_rounded, size: 18,
                          color: _exchangeAmount < maxExchangeable ? _brown : _brownLt.withOpacity(0.4)),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text('Costs $xpCost XP', style: GoogleFonts.nunito(
                fontSize: 12, fontWeight: FontWeight.w600, color: _brownLt)),
              const SizedBox(height: 14),

              // Exchange button
              GestureDetector(
                onTap: canExchange
                    ? () async {
                        final success = await ref.read(dashboardProvider.notifier)
                            .exchangeXpToCash(_exchangeAmount);
                        if (success && mounted) {
                          setState(() => _exchangeAmount = 1);
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Exchanged! +$_exchangeAmount Cash',
                                style: GoogleFonts.gaegu(fontSize: 16, fontWeight: FontWeight.w700)),
                            backgroundColor: _green,
                            duration: const Duration(seconds: 2),
                          ));
                        }
                      }
                    : null,
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    gradient: canExchange
                        ? const LinearGradient(colors: [Color(0xFFD0F0CA), _green])
                        : null,
                    color: canExchange ? null : _outline.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: canExchange ? _greenDk : _outline.withOpacity(0.15),
                      width: 3,
                    ),
                    boxShadow: canExchange
                        ? [BoxShadow(color: _greenDk.withOpacity(0.3),
                            offset: const Offset(0, 4), blurRadius: 0)]
                        : [],
                  ),
                  child: Center(
                    child: Text(
                      canExchange ? 'Exchange Now' : 'Not enough XP',
                      style: GoogleFonts.gaegu(
                        fontSize: 18, fontWeight: FontWeight.w700,
                        color: canExchange ? Colors.white : _brownLt.withOpacity(0.4)),
                    ),
                  ),
                ),
              ),
              if (maxExchangeable > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _exchangeAmount = maxExchangeable),
                    child: Text('Max: $maxExchangeable Cash', style: GoogleFonts.nunito(
                      fontSize: 12, fontWeight: FontWeight.w700,
                      color: _green, decoration: TextDecoration.underline)),
                  ),
                ),
            ]),
          ),
        ]),
      ),
    );
  }

  Widget _balancePill({
    required IconData icon, required String label,
    required String value, required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _outline.withOpacity(0.15), width: 2),
      ),
      child: Row(children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(value, style: GoogleFonts.gaegu(
            fontSize: 20, fontWeight: FontWeight.w700, color: _brown)),
          Text(label, style: GoogleFonts.nunito(
            fontSize: 11, fontWeight: FontWeight.w600, color: _brownLt)),
        ]),
      ]),
    );
  }

  Widget _buildStatsRow(DashboardState dashboard) {
    return Row(
      children: [
        Expanded(
          child: _StatTile(
            icon: Icons.local_fire_department_rounded,
            value: '${dashboard.streak}',
            label: 'Streak',
            color: _coralHdr,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.star_rounded,
            value: '${dashboard.totalXp}',
            label: 'Total XP',
            color: _skyHdr,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _StatTile(
            icon: Icons.monetization_on_rounded,
            value: '${dashboard.cash}',
            label: 'Cash',
            color: _goldGlow,
          ),
        ),
      ],
    );
  }

  Widget _buildAchievementsSection() {
    final achievements = [
      {
        'name': 'First Login',
        'icon': Icons.celebration_rounded,
        'unlocked': true
      },
      {
        'name': 'Streak 7',
        'icon': Icons.local_fire_department_rounded,
        'unlocked': false
      },
      {
        'name': 'Health Pro',
        'icon': Icons.favorite_rounded,
        'unlocked': false
      },
      {
        'name': 'Quiz Master',
        'icon': Icons.emoji_events_rounded,
        'unlocked': false
      },
      {
        'name': 'Level 10',
        'icon': Icons.star_rounded,
        'unlocked': false
      },
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            'Achievements',
            style: GoogleFonts.gaegu(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _brown,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: achievements.length,
            separatorBuilder: (_, __) => const SizedBox(width: 10),
            itemBuilder: (context, index) {
              final achievement = achievements[index];
              final unlocked = achievement['unlocked'] as bool;
              return _AchievementBadge(
                name: achievement['name'] as String,
                icon: achievement['icon'] as IconData,
                unlocked: unlocked,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsSection() {
    return Container(
      width: double.infinity,
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
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Column(
          children: [
            // Coral/warm header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFFF0C0B8), _coralHdr],
                ),
              ),
              child: Text(
                'Settings',
                style: GoogleFonts.gaegu(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: _brown,
                ),
              ),
            ),
            Column(
              children: [
                _SettingsTile(
                  icon: Icons.face_rounded,
                  label: 'Edit Avatar',
                  color: CerebroTheme.pinkPop,
                  onTap: () => context.go('/avatar'),
                ),
                Divider(
                  height: 1,
                  color: _outline.withOpacity(0.08),
                ),
                _SettingsTile(
                  icon: Icons.school_rounded,
                  label: 'Study Preferences',
                  color: _skyHdr,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Coming soon!',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                        ),
                        backgroundColor: _skyHdr,
                      ),
                    );
                  },
                ),
                Divider(
                  height: 1,
                  color: _outline.withOpacity(0.08),
                ),
                _SettingsTile(
                  icon: Icons.notifications_rounded,
                  label: 'Notifications',
                  color: _goldGlow,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Coming soon!',
                          style: GoogleFonts.nunito(fontWeight: FontWeight.w700),
                        ),
                        backgroundColor: _goldGlow,
                      ),
                    );
                  },
                ),
                Divider(
                  height: 1,
                  color: _outline.withOpacity(0.08),
                ),
                _SettingsTile(
                  icon: Icons.palette_rounded,
                  label: 'Theme',
                  color: CerebroTheme.lavender,
                  trailing: Text(
                    'Toca Boca',
                    style: GoogleFonts.nunito(
                      color: _brown,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onTap: () {},
                ),
                Divider(
                  height: 1,
                  color: _outline.withOpacity(0.08),
                ),
                _SettingsTile(
                  icon: Icons.info_rounded,
                  label: 'About CEREBRO',
                  color: _green,
                  onTap: () => _showAbout(context),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSignOutButton() {
    return GestureDetector(
      onTap: () => _confirmLogout(context),
      child: Container(
        width: double.infinity,
        height: 48,
        decoration: BoxDecoration(
          color: _coralHdr,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: _outline.withOpacity(0.25),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: _outline.withOpacity(0.06),
              offset: const Offset(0, 2),
              blurRadius: 8,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, size: 20, color: Colors.white),
            const SizedBox(width: 10),
            Text(
              'Sign Out',
              style: GoogleFonts.nunito(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _cardFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: _outline.withOpacity(0.25),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: _coralHdr,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _outline.withOpacity(0.25),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _outline.withOpacity(0.06),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.logout_rounded,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Sign Out?',
                style: GoogleFonts.gaegu(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  color: _brown,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Your progress is saved. You can sign back in anytime!',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _brownLt,
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.pop(ctx),
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _outline.withOpacity(0.25),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _outline.withOpacity(0.06),
                              offset: const Offset(0, 2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'Stay',
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: _brown,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: GestureDetector(
                      onTap: () async {
                        Navigator.pop(ctx);
                        await ref.read(authProvider.notifier).logout();
                        if (mounted) context.go('/login');
                      },
                      child: Container(
                        height: 44,
                        decoration: BoxDecoration(
                          color: _coralHdr,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: _outline.withOpacity(0.25),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: _outline.withOpacity(0.06),
                              offset: const Offset(0, 2),
                              blurRadius: 8,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            'Sign Out',
                            style: GoogleFonts.nunito(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showAbout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: _cardFill,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: _outline.withOpacity(0.25),
            width: 2,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 64,
                height: 64,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [CerebroTheme.pinkPop, _coralHdr],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _outline.withOpacity(0.25),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _outline.withOpacity(0.06),
                      offset: const Offset(0, 2),
                      blurRadius: 8,
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    'C',
                    style: GoogleFonts.nunito(
                      fontSize: 32,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'CEREBRO',
                style: GoogleFonts.gaegu(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: _brown,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                style: GoogleFonts.nunito(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _brownLt,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Version 1.0\nFinal Year Project\nLondon Metropolitan University',
                textAlign: TextAlign.center,
                style: GoogleFonts.nunito(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _brownLt,
                ),
              ),
              const SizedBox(height: 18),
              GestureDetector(
                onTap: () => Navigator.pop(ctx),
                child: Container(
                  width: double.infinity,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [CerebroTheme.pinkPop, _coralHdr],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: _outline.withOpacity(0.25),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _outline.withOpacity(0.06),
                        offset: const Offset(0, 2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      'Cool!',
                      style: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatTile extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _StatTile({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.gaegu(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: _brown,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: GoogleFonts.nunito(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: _brownLt,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Soft colored icon circle
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.nunito(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: _brown,
                ),
              ),
            ),
            if (trailing != null) ...[
              trailing!,
              const SizedBox(width: 8),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: _outline.withOpacity(0.3),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

class _AchievementBadge extends StatelessWidget {
  final String name;
  final IconData icon;
  final bool unlocked;

  const _AchievementBadge({
    required this.name,
    required this.icon,
    required this.unlocked,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 88,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: unlocked ? _cardFill : _ombre3,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unlocked
              ? _goldGlow.withOpacity(0.5)
              : _outline.withOpacity(0.15),
          width: 2,
        ),
        boxShadow: unlocked
            ? [
                BoxShadow(
                  color: _outline.withOpacity(0.06),
                  offset: const Offset(0, 2),
                  blurRadius: 8,
                ),
              ]
            : [],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            icon,
            size: 32,
            color: unlocked ? _goldGlow : _brownLt.withOpacity(0.4),
          ),
          const SizedBox(height: 6),
          Text(
            name,
            textAlign: TextAlign.center,
            style: GoogleFonts.nunito(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: unlocked ? _brown : _brownLt.withOpacity(0.5),
            ),
          ),
        ],
      ),
    );
  }
}

//  PAWPRINT BACKGROUND (exact match to dashboard_tab.dart)
class _PawPrintBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const spacing = 90.0;
    const rowShift = 45.0;
    const pawR = 10.0;
    int idx = 0;
    for (double y = 30; y < size.height; y += spacing) {
      final isOddRow = ((y / spacing).floor() % 2) == 1;
      final xOffset = isOddRow ? rowShift : 0.0;
      for (double x = xOffset + 30; x < size.width; x += spacing) {
        final opFactor = 0.06 + (idx % 5) * 0.018;
        paint.color = _pawClr.withOpacity(opFactor);
        final angle = (idx % 4) * 0.3 - 0.3;
        _drawCatPaw(canvas, paint, x, y, pawR, angle);
        idx++;
      }
    }
  }

  void _drawCatPaw(Canvas c, Paint p, double cx, double cy, double r, double a) {
    c.save();
    c.translate(cx, cy);
    c.rotate(a);
    c.drawOval(
      Rect.fromCenter(center: Offset.zero, width: r * 2.2, height: r * 1.8),
      p,
    );
    final tr = r * 0.52;
    c.drawCircle(Offset(-r * 1.0, -r * 1.35), tr, p);
    c.drawCircle(Offset(-r * 0.38, -r * 1.65), tr, p);
    c.drawCircle(Offset(r * 0.38, -r * 1.65), tr, p);
    c.drawCircle(Offset(r * 1.0, -r * 1.35), tr, p);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
