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

class AvatarTab extends ConsumerStatefulWidget {
  const AvatarTab({super.key});

  @override
  ConsumerState<AvatarTab> createState() => _AvatarTabState();
}

class _AvatarTabState extends ConsumerState<AvatarTab> {
  AvatarConfig? _config;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadAvatar();
  }

  Future<void> _loadAvatar() async {
    final prefs = await SharedPreferences.getInstance();
    final json = prefs.getString(AppConstants.avatarConfigKey);
    if (json != null) {
      setState(() {
        _config = AvatarConfig.fromJson(jsonDecode(json));
        _loading = false;
      });
    } else {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 12),

            // title
            Text(
              'My Avatar',
              style: GoogleFonts.nunito(
                fontSize: 24,
                fontWeight: FontWeight.w900,
                color: CerebroTheme.outline,
              ),
            ),
            const SizedBox(height: 20),

            // avatar display
            if (_loading)
              const SizedBox(
                height: 220,
                child: Center(
                  child: CircularProgressIndicator(
                    color: CerebroTheme.pinkPop,
                  ),
                ),
              )
            else if (_config != null)
              Container(
                decoration: BoxDecoration(
                  color: CerebroTheme.pinkSoft.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(44),
                  border: Border.all(color: CerebroTheme.outline, width: 4),
                  boxShadow: [CerebroTheme.shadow3DLarge],
                ),
                child: AvatarDisplay(
                  config: _config!,
                  size: 220,
                  backgroundColor: CerebroTheme.pinkSoft.withOpacity(0.2),
                ),
              )
            else
              Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  color: CerebroTheme.creamMid,
                  borderRadius: BorderRadius.circular(44),
                  border: Border.all(color: CerebroTheme.outline, width: 4),
                  boxShadow: [CerebroTheme.shadow3DLarge],
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.face_outlined,
                        size: 64, color: CerebroTheme.creamDark),
                    const SizedBox(height: 8),
                    Text(
                      'No avatar yet',
                      style: GoogleFonts.nunito(
                        color: CerebroTheme.brown,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // customize button
            _ChunkyButton(
              onTap: () => context.go('/avatar'),
              color: CerebroTheme.pinkPop,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.brush_rounded,
                      size: 20, color: Colors.white),
                  const SizedBox(width: 10),
                  Text(
                    _config != null ? 'Customize Avatar' : 'Create Avatar',
                    style: GoogleFonts.nunito(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // avatar stats
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(18),
              decoration: CerebroTheme.cuteCard(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Avatar Stats',
                    style: GoogleFonts.nunito(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: CerebroTheme.outline,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _statRow(
                    Icons.star_rounded,
                    CerebroTheme.gold,
                    'Level',
                    '1 — Novice Scholar',
                  ),
                  _divider(),
                  _statRow(
                    Icons.bolt_rounded,
                    CerebroTheme.coral,
                    'Total XP',
                    '0 XP',
                  ),
                  _divider(),
                  _statRow(
                    Icons.local_fire_department_rounded,
                    CerebroTheme.pinkPop,
                    'Study Streak',
                    '0 days',
                  ),
                  _divider(),
                  _statRow(
                    Icons.checkroom_rounded,
                    CerebroTheme.lavender,
                    'Items Unlocked',
                    '0 / 50',
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // tip card
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: CerebroTheme.gold.withOpacity(0.15),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: CerebroTheme.gold, width: 2),
              ),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome,
                      color: CerebroTheme.goldDark),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Complete study sessions and log your health to earn XP and unlock new avatar items!',
                      style: GoogleFonts.nunito(
                        color: CerebroTheme.goldDark,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
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

  Widget _divider() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Divider(color: CerebroTheme.creamDark, height: 1, thickness: 2),
    );
  }

  Widget _statRow(IconData icon, Color color, String label, String value) {
    return Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withOpacity(0.3), width: 2),
          ),
          child: Icon(icon, color: color, size: 22),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: GoogleFonts.nunito(
                  color: CerebroTheme.brown,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                value,
                style: GoogleFonts.nunito(
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
                  color: CerebroTheme.outline,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// chunky 3D button with press animation
class _ChunkyButton extends StatefulWidget {
  final VoidCallback onTap;
  final Color color;
  final Widget child;

  const _ChunkyButton({
    required this.onTap,
    required this.color,
    required this.child,
  });

  @override
  State<_ChunkyButton> createState() => _ChunkyButtonState();
}

class _ChunkyButtonState extends State<_ChunkyButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _pressed = true),
      onTapUp: (_) {
        setState(() => _pressed = false);
        widget.onTap();
      },
      onTapCancel: () => setState(() => _pressed = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        width: double.infinity,
        height: 52,
        transform: Matrix4.translationValues(0, _pressed ? 3 : 0, 0),
        decoration: BoxDecoration(
          color: widget.color,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: CerebroTheme.outline, width: 4),
          boxShadow: [
            if (!_pressed) CerebroTheme.shadow3D,
          ],
        ),
        child: Center(child: widget.child),
      ),
    );
  }
}
