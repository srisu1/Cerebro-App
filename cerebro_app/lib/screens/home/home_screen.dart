import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:cerebro_app/screens/home/dashboard_tab.dart';
import 'package:cerebro_app/screens/daily/daily_tab.dart';
import 'package:cerebro_app/screens/study/study_tab.dart';
import 'package:cerebro_app/screens/store/store_tab.dart';
import 'package:cerebro_app/screens/health/health_tab.dart';
import 'package:cerebro_app/screens/profile/profile_tab.dart';

const _brownLt = Color(0xFF7A5840);

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
      _TabDef(Icons.home_rounded, 'Home', const Color(0xFFFF6B9D)),
      _TabDef(Icons.today_rounded, 'Daily', const Color(0xFFFF8C6B)),
      _TabDef(Icons.menu_book_rounded, 'Study', const Color(0xFF5BADF0)),
      _TabDef(Icons.storefront_rounded, 'Shop', const Color(0xFFE8B840)),
      _TabDef(Icons.favorite_rounded, 'Health', const Color(0xFF6BBF7A)),
      _TabDef(Icons.face_rounded, 'Avatar', const Color(0xFF9D8AD4)),
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
              child: _SlimNav(
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

// bottom nav bar
class _SlimNav extends StatelessWidget {
  final List<_TabDef> items;
  final int selected;
  final void Function(int) onTap;

  const _SlimNav({
    required this.items,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBF8),
        border: Border(
          top: BorderSide(
            color: _brownLt.withOpacity(0.10),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 52,
          child: Row(
            children: List.generate(items.length, (i) {
              return Expanded(
                child: _SlimNavItem(
                  item: items[i],
                  active: selected == i,
                  onTap: () => onTap(i),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _SlimNavItem extends StatelessWidget {
  final _TabDef item;
  final bool active;
  final VoidCallback onTap;

  const _SlimNavItem({
    required this.item,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = item.color;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            item.icon,
            size: active ? 24 : 22,
            color: active ? color : _brownLt.withOpacity(0.35),
          ),
          const SizedBox(height: 4),
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: active ? 5 : 0,
            height: active ? 5 : 0,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _TabDef {
  final IconData icon;
  final String label;
  final Color color;
  const _TabDef(this.icon, this.label, this.color);
}
