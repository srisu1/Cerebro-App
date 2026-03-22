/// 6 tabs: Home, Daily, Study, Shop, Health, Profile
/// Bottom nav = olive rounded bar with white-pill active state.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:cerebro_app/screens/home/dashboard_tab.dart';
import 'package:cerebro_app/screens/daily/daily_tab.dart';
import 'package:cerebro_app/screens/study/study_tab.dart';
import 'package:cerebro_app/screens/store/store_tab.dart';
import 'package:cerebro_app/screens/health/health_tab.dart';
import 'package:cerebro_app/screens/profile/profile_tab.dart';

const _olive   = Color(0xFF98A869);
const _oliveDk = Color(0xFF58772F);
const _brown   = Color(0xFF4E3828);

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

    return Scaffold(
      backgroundColor: CerebroTheme.cream,
      body: Stack(
        children: [
          IndexedStack(index: selectedTab, children: tabs),
          if (!isStoreOpen)
            Positioned(
              left: 0, right: 0, bottom: 0,
              child: _OliveNavBar(
                items: tabItems,
                selected: selectedTab,
                onTap: (i) => ref.read(selectedTabProvider.notifier).state = i,
              ),
            ),
        ],
      ),
    );
  }
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
