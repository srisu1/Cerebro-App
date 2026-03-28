// Home screen — 6-tab shell with olive bottom nav bar.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:cerebro_app/providers/study_session_provider.dart';
import 'package:cerebro_app/screens/home/dashboard_tab.dart';
import 'package:cerebro_app/screens/daily/daily_tab.dart';
import 'package:cerebro_app/screens/study/study_tab.dart';
import 'package:cerebro_app/screens/store/store_tab.dart';
import 'package:cerebro_app/screens/health/health_tab.dart';
import 'package:cerebro_app/screens/profile/profile_tab.dart';
import 'package:cerebro_app/widgets/mini_session_bar.dart';


bool get _darkMode =>
    CerebroTheme.brightnessNotifier.value == Brightness.dark;

Color get _olive => const Color(0xFF98A869);
Color get _oliveDk => const Color(0xFF58772F);
Color get _brown => _darkMode ? const Color(0xFFF2E1CA) : const Color(0xFF4E3828);
final selectedTabProvider = StateProvider<int>((ref) => 0);

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedTabProvider);

    final tabs = const [
      DashboardTab(),
      DailyTab(),
      StudyTab(),
      StoreTab(),
      HealthTab(),
      ProfileTab(),
    ];

    final tabItems = [
      _TabDef(Icons.home_rounded,          'Home'),
      _TabDef(Icons.today_rounded,         'Daily'),
      _TabDef(Icons.menu_book_rounded,     'Study'),
      _TabDef(Icons.storefront_rounded,    'Shop'),
      _TabDef(Icons.favorite_rounded,      'Health'),
      _TabDef(Icons.person_rounded,        'Profile'),
    ];

    final isStoreOpen = selectedTab == 3;
    final sessionLive = ref.watch(isSessionLiveProvider);
    final isStudyTab = selectedTab == 2;

    return Scaffold(
      backgroundColor: CerebroTheme.cream,
      body: Stack(
        children: [
          IndexedStack(index: selectedTab, children: tabs),
          if (!isStoreOpen)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Mini session bar — floats above the olive nav bar
                  // whenever a session is live. Hidden on the Study tab
                  // itself because the Study Hub already renders a full
                  // timer+controls hero (showing both would be noisy).
                  if (sessionLive && !isStudyTab) const MiniSessionBar(),
                  _OliveNavBar(
                    items: tabItems,
                    selected: selectedTab,
                    // Tab switches route through a guard that pops up the
                    // End Session sheet when a session is live and the
                    // user tries to leave the Study tab. Guard implemented
                    // in a later pass — for now, a direct assignment.
                    onTap: (i) => _handleTabTap(context, ref,
                        fromTab: selectedTab, toTab: i),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  // Handle tab tap — tracks distractions when leaving Study during a live session.
  void _handleTabTap(BuildContext context, WidgetRef ref,
      {required int fromTab, required int toTab}) {
    final live = ref.read(isSessionLiveProvider);
    final leavingStudy = fromTab == 2 && toTab != 2;

    // Switch tabs immediately — navigation always feels instant.
    ref.read(selectedTabProvider.notifier).state = toTab;

    // If a session is live and the user just wandered away from Study,
    // log it as a distraction and nudge them with a friendly reminder.
    // The mini-player and the distraction counter do the rest.
    if (live && leavingStudy) {
      // ignore: discarded_futures
      ref.read(studySessionProvider.notifier).addDistraction();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(
            "Distraction noted — your session's still running.",
            style: GoogleFonts.gaegu(
                fontSize: 14, fontWeight: FontWeight.w600, color: _brown),
          ),
          backgroundColor: const Color(0xFFFFE8C9),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(milliseconds: 1800),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12)),
        ));
    }
  }

  // _showLeaveStudyGuard / _guardBtn were removed when the "blocking sheet
  // on tab-leave" UX was replaced with the silent distraction counter above.
  // See the comment on _handleTabTap.
}

//  OLIVE NAV BAR — matches .bnav-bar in dashboard-v9.html
//  Olive pill-shaped bar, active tab = white bg + label
class _OliveNavBar extends StatelessWidget {
  final List<_TabDef> items;
  final int selected;
  final void Function(int) onTap;

  const _OliveNavBar({
    required this.items,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final sw = MediaQuery.of(context).size.width;
    // Responsive side padding — shrinks on narrow phones to prevent overflow
    final sidePad = (sw * 0.12).clamp(12.0, 80.0);
    return Padding(
      padding: EdgeInsets.fromLTRB(sidePad, 0, sidePad, 14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        decoration: BoxDecoration(
          color: _olive,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: _oliveDk, width: 1.5),
          boxShadow: [
            BoxShadow(
              color: _oliveDk.withOpacity(0.3),
              offset: const Offset(3, 3),
              blurRadius: 0,
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: List.generate(items.length, (i) {
            return _OliveNavItem(
              item: items[i],
              active: selected == i,
              onTap: () => onTap(i),
            );
          }),
        ),
      ),
    );
  }
}

class _OliveNavItem extends StatelessWidget {
  final _TabDef item;
  final bool active;
  final VoidCallback onTap;

  const _OliveNavItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        padding: EdgeInsets.symmetric(
          horizontal: active ? 14 : 12,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: active
              ? [BoxShadow(color: Colors.black.withOpacity(0.06),
                  offset: const Offset(0, 2), blurRadius: 4)]
              : [],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              item.icon,
              size: 20,
              color: active
                  ? _oliveDk
                  : Colors.white.withOpacity(0.5),
            ),
            // Animated label only on active
            AnimatedSize(
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOut,
              child: active
                  ? Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: Text(
                        item.label,
                        style: GoogleFonts.gaegu(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: _oliveDk,
                        ),
                      ),
                    )
                  : const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabDef {
  final IconData icon;
  final String label;
  const _TabDef(this.icon, this.label);
}
