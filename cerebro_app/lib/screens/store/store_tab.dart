/// Fixes from v8 feedback:
///  1. Removed nav arrows
///  2. Close button matches warm theme (not grey)
///  3. Scallop tabs flush from top, alternating colors
///  4. Tab icons redesigned: shirt, scissors, glasses, hat, sparkle, bolt
///  5. Added eye-color items to Extras category
///  6. Hand illustration PNG replaces emoji on FREE button
///  7. Card item images smaller, tilted ~15°, 3D feel
///  8. Green color matches avatar page cutesy green (#A8D5A3)
///  9. Pawprint ombré background (not diamond checkerboard)
/// 10. Kept: dark-brown outlines (#6E5848) + Gaegu fonts

import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:cerebro_app/screens/home/home_screen.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/providers/dashboard_provider.dart';

// Background ombré (from avatar page)
const _ombre1    = Color(0xFFFFFBF7);  // top – airy cream (lighter!)
const _ombre2    = Color(0xFFFFF8F3);  // warm blush
const _ombre3    = Color(0xFFFFF3EF);  // soft peach
const _ombre4    = Color(0xFFFEEDE9);  // bottom – gentle pink
const _pawClr    = Color(0xFFF8BCD0);  // softer pawprint tint

// Outlines & text — USER LIKES THESE, keep exactly
const _outline   = Color(0xFF6E5848);
const _brown     = Color(0xFF4E3828);
const _brownLt   = Color(0xFF7A5840);

// Scallop tabs — white & pink alternating like reference
const _scWhite   = Color(0xFFFFF8F4);  // inactive white (even)
const _scPink    = Color(0xFFE8B0A8);  // inactive pink (odd)
const _scAct     = Color(0xFFFFF6F0);  // active fill
const _scBdr     = Color(0xFFAA8078);  // scallop border

// Cards & panel
const _purpleHdr = Color(0xFFCDA8D8);
const _white     = Color(0xFFFFF8F4);
const _panelBg   = Color(0xFFFFF6EE);
const _panelBdr  = Color(0xFF8A7060);

// Currency greens — MATCHED to avatar page cutesy green
const _greenLt   = Color(0xFFC2E8BC);  // lighter version of avatar green
const _green     = Color(0xFFA8D5A3);  // avatar page _okGreen
const _greenDk   = Color(0xFF88B883);  // darker complement
const _billFill  = Color(0xFF6DA568);
const _billTx    = Color(0xFFD0F0CC);

// Misc UI
const _closeBg   = Color(0xFFE8B8B0);  // warm pink-beige (matches theme!)
const _adBg      = Color(0xFF7878A8);
const _adBdr     = Color(0xFF5C5C88);
const _goldGlow  = Color(0xFFF8E080);
const _bagPurp   = Color(0xFFD8B0E0);

enum _TabIcon { shirt, scissors, glasses, hat, sparkle, bolt }
const _tabDefs = <_TabDef>[
  _TabDef('Clothing', _TabIcon.shirt),
  _TabDef('Hair',     _TabIcon.scissors),
  _TabDef('Glasses',  _TabIcon.glasses),
  _TabDef('Hats',     _TabIcon.hat),
  _TabDef('Extras',   _TabIcon.sparkle),
  _TabDef('Boosts',   _TabIcon.bolt),
];

class _TabDef {
  final String label;
  final _TabIcon icon;
  const _TabDef(this.label, this.icon);
}

class StoreTab extends ConsumerStatefulWidget {
  const StoreTab({super.key});
  @override
  ConsumerState<StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends ConsumerState<StoreTab>
    with TickerProviderStateMixin {
  int _sel = 0;
  final Set<String> _owned = {};  // tracks purchased item names
  final Set<String> _ownedBackendIds = {};  // backend item IDs

  late final AnimationController _ac;
  late final Animation<double> _fade;
  late final AnimationController _bobAc;   // bag bobbing
  late final AnimationController _pulseAc; // FREE button glow pulse

  @override
  void initState() {
    super.initState();
    _ac = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 500));
    _fade = CurvedAnimation(parent: _ac, curve: Curves.easeOut);
    _ac.forward();
    _bobAc = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 2200))
      ..repeat(reverse: true);
    _pulseAc = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1400))
      ..repeat(reverse: true);
    _loadOwnedItems();
  }

  /// Load owned items from backend inventory + local cache
  Future<void> _loadOwnedItems() async {
    // Load from local cache first (instant UI)
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getStringList('store_owned') ?? [];
    if (cached.isNotEmpty) {
      setState(() => _owned.addAll(cached));
    }

    // Then sync from backend
    try {
      final api = ref.read(apiServiceProvider);
      final res = await api.get('/gamification/store/inventory');
      if (res.statusCode == 200) {
        final items = (res.data['items'] as List?) ?? [];
        for (final item in items) {
          final id = item['id'] as String? ?? '';
          if (id.isNotEmpty) {
            _owned.add(id);
            _ownedBackendIds.add(id);
          }
        }
        setState(() {});
        await prefs.setStringList('store_owned', _owned.toList());
      }
    } catch (_) {
      // Offline — local cache is fine
    }
  }

  @override
  void dispose() { _bobAc.dispose(); _pulseAc.dispose(); _ac.dispose(); super.dispose(); }

  static final _cats = <_Cat>[
    _Cat(n: 'Clothing', items: [
      _It(id: 'clothes_sweater_babypink', n: 'Pink Sweater', a: 'assets/store/Store_items/sweater-babypink.png', p: 15, rarity: 'uncommon'),
      _It(id: 'clothes_sweater_brown', n: 'Brown Sweater', a: 'assets/store/Store_items/sweater-brown.png', p: 12, rarity: 'common'),
      _It(id: 'clothes_cneck_brown', n: 'Brown C-Neck', a: 'assets/store/Store_items/c-neck-brown.png', p: 10, rarity: 'common'),
      _It(id: 'clothes_cneck_olive', n: 'Olive C-Neck', a: 'assets/store/Store_items/c-neck-olive.png', p: 12, rarity: 'common'),
      _It(id: 'clothes_nightdress_babypink', n: 'Pink Night Dress', a: 'assets/store/Store_items/night-dress-babypink.png', p: 18, rarity: 'uncommon'),
      _It(id: 'clothes_nightdress_brown', n: 'Brown Night Dress', a: 'assets/store/Store_items/night-dress-brown.png', p: 15, rarity: 'common'),
      _It(id: 'clothes_offshoulder_olive', n: 'Olive Off-Shoulder', a: 'assets/store/Store_items/offshoulder-olive.png', p: 18, rarity: 'uncommon'),
      _It(id: 'clothes_tanktop_babypink', n: 'Pink Tank Top', a: 'assets/store/Store_items/tank-top-babypink.png', p: 10, rarity: 'common'),
      _It(id: 'clothes_tanktop_brown', n: 'Brown Tank Top', a: 'assets/store/Store_items/tank-top-brown.png', p: 8, rarity: 'common'),
      _It(id: 'clothes_vneck_brown', n: 'Brown V-Neck', a: 'assets/store/Store_items/v-neck-sweater-brown.png', p: 12, rarity: 'common'),
      _It(id: 'clothes_vneck_olive', n: 'Olive V-Neck', a: 'assets/store/Store_items/v-neck-sweater-olive.png', p: 15, rarity: 'uncommon'),
    ]),
    _Cat(n: 'Hair', items: [
      _It(id: 'hair_pink', n: 'Pink Hair Dye', a: 'assets/avatar/female/hair/anime-hair-pink.png', p: 25, rarity: 'rare'),
      _It(id: 'hair_silver', n: 'Silver Hair Dye', a: 'assets/avatar/female/hair/granny-hair-silver.png', p: 25, rarity: 'rare'),
      _It(id: 'hair_darkblue', n: 'Blue Hair Dye', a: 'assets/avatar/female/hair/to-the-side-darkblue.png', p: 30, rarity: 'rare'),
    ]),
    _Cat(n: 'Glasses', items: [
      _It(id: 'glasses_star', n: 'Star Glasses', a: 'assets/avatar/female/accessories/star-glasses.png', p: 20, rarity: 'rare'),
      _It(id: 'glasses_heart', n: 'Heart Glasses', a: 'assets/avatar/female/accessories/heart-glasses.png', p: 20, rarity: 'rare'),
      _It(id: 'sunglasses', n: 'Cool Sunglasses', a: 'assets/avatar/female/accessories/sunglasses.png', p: 25, rarity: 'rare'),
    ]),
    _Cat(n: 'Hats', items: [
      _It(id: 'hat_magician', n: 'Magician Hat', a: 'assets/avatar/female/accessories/magician-hat-blue.png', p: 40, rarity: 'epic'),
      _It(id: 'hat_french', n: 'French Beret', a: 'assets/avatar/female/accessories/french-cap-blue.png', p: 30, rarity: 'rare'),
      _It(id: 'winter_cap', n: 'Winter Cap', a: 'assets/avatar/female/accessories/winter-cap-red.png', p: 15, rarity: 'uncommon'),
    ]),
    _Cat(n: 'Extras', items: [
      _It(id: 'tie_bowtie', n: 'Bow Tie', a: 'assets/avatar/female/accessories/boy-tie-green.png', p: 10, rarity: 'common'),
      _It(id: 'flower_red', n: 'Red Flower', a: 'assets/avatar/female/accessories/flower-red.png', p: 8, rarity: 'common'),
      _It(id: 'hairband_blue', n: 'Blue Hairband', a: 'assets/avatar/female/accessories/hairband1-blue.png', p: 12, rarity: 'common'),
      _It(id: 'eyes_20', n: 'Blue Eyes', a: 'assets/avatar/female/eyes/eyes20.png', p: 8, rarity: 'common'),
      _It(id: 'eyes_25', n: 'Green Eyes', a: 'assets/avatar/female/eyes/eyes25.png', p: 8, rarity: 'common'),
      _It(id: 'eyes_30', n: 'Ruby Eyes', a: 'assets/avatar/female/eyes/eyes30.png', p: 12, rarity: 'uncommon'),
      _It(id: 'eyes_35', n: 'Rose Eyes', a: 'assets/avatar/female/eyes/eyes35.png', p: 12, rarity: 'uncommon'),
      _It(id: 'eyes_40', n: 'Cat Eyes', a: 'assets/avatar/female/eyes/eyes40.png', p: 15, rarity: 'rare'),
    ]),
    _Cat(n: 'Boosts', items: [
      _It(id: 'boost_2x_xp', n: '2x XP', a: '', p: 30, ic: Icons.bolt_rounded, rarity: 'epic'),
      _It(id: 'boost_focus', n: 'Focus Boost', a: '', p: 20, ic: Icons.psychology_rounded, rarity: 'rare'),
      _It(id: 'boost_streak', n: 'Streak Shield', a: '', p: 35, ic: Icons.shield_rounded, rarity: 'epic'),
    ]),
  ];

  @override
  Widget build(BuildContext context) {
    final cat = _cats[_sel];
    return Stack(children: [
      Positioned.fill(child: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [_ombre1, _ombre2, _ombre3, _ombre4],
            stops: [0.0, 0.3, 0.6, 1.0],
          ),
        ),
      )),
      // Radial vignette for depth
      Positioned.fill(child: Container(
        decoration: BoxDecoration(
          gradient: RadialGradient(
            center: Alignment.center, radius: 0.9,
            colors: [
              Colors.transparent,
              const Color(0xFFFEEDE9).withOpacity(0.12),
            ],
          ),
        ),
      )),
      // Pawprint pattern overlay
      Positioned.fill(child: CustomPaint(
        painter: _PawPrintBg(),
      )),
      SafeArea(child: FadeTransition(
        opacity: _fade,
        child: Column(children: [
          // Scallop tabs FLUSH from top (no gap)
          _scallTabs(),
          const Spacer(flex: 1),
          // Main content: grid + side panel
          Expanded(flex: 5, child: Padding(
            padding: const EdgeInsets.fromLTRB(56, 0, 56, 14),
            child: LayoutBuilder(builder: (ctx, outerBox) {
              // Calculate card size so panel matches exactly 2 rows
              const sp = 12.0;
              const cols = 5;
              const panelW = 185.0;
              const gapW = 14.0;
              final gridW = outerBox.maxWidth - panelW - gapW;
              final cw = (gridW - (cols - 1) * sp) / cols;
              final ch = cw * 1.2;
              final panelH = ch * 2 + sp + 2; // exactly 2 card rows
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _grid(cat)),
                  const SizedBox(width: gapW),
                  SizedBox(width: panelW, height: panelH,
                    child: _panel(cat)),
                ],
              );
            }),
          )),
        ]),
      )),
      // Close button (warm themed)
      Positioned(top: 18, left: 18, child: _closeBtn()),
      // Currency
      Positioned(top: 14, right: 14, child: _currency()),
    ]);
  }

  Widget _scallTabs() {
    return SizedBox(
      height: 100,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,  // flush from TOP
        children: List.generate(_tabDefs.length, (i) {
          final active = _sel == i;
          final tab = _tabDefs[i];
          // Alternating colors: even = white, odd = pink (like reference)
          final fill = active ? _scAct : (i.isEven ? _scWhite : _scPink);
          return GestureDetector(
            onTap: () => setState(() => _sel = i),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOutCubic,
              width: active ? 210.0 : 95.0,
              height: active ? 100 : 82,
              child: CustomPaint(
                painter: _ScallopP(fill: fill, bdr: _scBdr),
                child: Padding(
                  padding: EdgeInsets.only(top: active ? 18 : 14, bottom: 10),
                  child: active
                    ? Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(width: 34, height: 34,
                            child: CustomPaint(painter: _TabIconP(tab.icon))),
                          const SizedBox(width: 8),
                          Flexible(child: Text(tab.label,
                            style: GoogleFonts.gaegu(
                              fontSize: 24, fontWeight: FontWeight.w700,
                              color: _brown),
                            overflow: TextOverflow.ellipsis)),
                        ],
                      )
                    : Center(child: SizedBox(width: 26, height: 26,
                        child: CustomPaint(painter: _TabIconP(tab.icon)))),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }

  Widget _closeBtn() {
    return GestureDetector(
      onTap: () => ref.read(selectedTabProvider.notifier).state = 0,
      child: Container(
        width: 50, height: 50,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFFF0CCC4), _closeBg], // 3D highlight
          ),
          shape: BoxShape.circle,
          border: Border.all(color: _outline, width: 3),
          boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
              offset: const Offset(0, 5), blurRadius: 0)],
        ),
        child: Center(
          child: Text('X', style: GoogleFonts.gaegu(
            fontSize: 26, fontWeight: FontWeight.w900, color: _outline)),
        ),
      ),
    );
  }

  Widget _currency() {
    final dash = ref.watch(dashboardProvider);
    return _CurPill(amt: dash.cash, isCoin: false, onPlusTap: () {
      // Close store, go to profile tab (index 5) where the cash converter is
      ref.read(selectedTabProvider.notifier).state = 5;
    });
  }

  Widget _grid(_Cat cat) {
    return LayoutBuilder(builder: (ctx, box) {
      const sp = 12.0;
      const cols = 5;
      final cw = (box.maxWidth - (cols - 1) * sp) / cols;
      final ch = cw * 1.2;  // compact cards
      return SingleChildScrollView(child: Wrap(
        spacing: sp, runSpacing: sp,
        children: List.generate(cat.items.length, (i) => SizedBox(
          width: cw, height: ch,
          // Staggered pop-in animation per card
          child: TweenAnimationBuilder<double>(
            key: ValueKey('${cat.n}_$i'),
            tween: Tween(begin: 0.0, end: 1.0),
            duration: Duration(milliseconds: 280 + i * 55),
            curve: Curves.easeOutBack,
            builder: (ctx, v, child) => Opacity(
              opacity: v.clamp(0.0, 1.0),
              child: Transform.translate(
                offset: Offset(0, 16 * (1 - v)),
                child: Transform.scale(scale: 0.85 + 0.15 * v, child: child),
              ),
            ),
            child: _Card(item: cat.items[i], sold: _owned.contains(cat.items[i].id),
                onBuy: () => _buy(cat.items[i])),
          ),
        )),
      ));
    });
  }

  Widget _panel(_Cat cat) {
    return Container(
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
          colors: [Color(0xFFFFFAF4), _panelBg], // 3D highlight at top
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _panelBdr, width: 3),
        boxShadow: [
          BoxShadow(color: _panelBdr.withOpacity(0.15),
              offset: const Offset(5, 8), blurRadius: 0), // side shadow
          BoxShadow(color: _outline.withOpacity(0.35),
              offset: const Offset(0, 8), blurRadius: 0), // main shadow — CHUNKY
        ],
      ),
      padding: const EdgeInsets.fromLTRB(10, 14, 10, 14),
      child: Column(children: [
        Text(cat.n, style: GoogleFonts.gaegu(
          fontSize: 22, fontWeight: FontWeight.w700, color: _brown)),
        const SizedBox(height: 2),
        Text('Random Vanity\nItem', textAlign: TextAlign.center,
          style: GoogleFonts.gaegu(
            fontSize: 17, fontWeight: FontWeight.w700,
            color: _brownLt, height: 1.2)),
        const SizedBox(height: 6),
        // Kawaii bag with golden glow — bobbing float for life!
        Expanded(child: AnimatedBuilder(
          animation: _bobAc,
          builder: (ctx, child) => Transform.translate(
            offset: Offset(0, 5 * math.sin(_bobAc.value * math.pi * 2)),
            child: child,
          ),
          child: Center(child: SizedBox(
            height: 145, width: 145,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Golden sunburst
                Container(width: 125, height: 125, decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(colors: [
                    _goldGlow.withOpacity(0.5), _goldGlow.withOpacity(0.15),
                    Colors.transparent,
                  ], stops: const [0.0, 0.5, 1.0]),
                )),
                // Painted kawaii bag
                SizedBox(width: 105, height: 125,
                  child: CustomPaint(painter: const _KawaiiP())),
              ],
            ),
          )),
        )),
        const SizedBox(height: 4),
        // FREE button + hand-drawn pointing finger
        Stack(
          clipBehavior: Clip.none,
          alignment: Alignment.center,
          children: [
            GestureDetector(
              onTap: () => _freeTap(),
              child: AnimatedBuilder(
                animation: _pulseAc,
                builder: (ctx, child) {
                  final glow = 4 + 8 * _pulseAc.value;
                  return Container(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 28),
                    decoration: BoxDecoration(
                      color: _adBg,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: _adBdr, width: 3),
                      boxShadow: [
                        BoxShadow(color: _adBdr.withOpacity(0.4),
                            offset: const Offset(0, 6), blurRadius: 0),
                        // Pulsing glow
                        BoxShadow(
                            color: const Color(0xFF9898D8).withOpacity(0.25 + 0.2 * _pulseAc.value),
                            blurRadius: glow, spreadRadius: glow * 0.3),
                      ],
                    ),
                    child: child,
                  );
                },
                child: Text('FREE!', style: GoogleFonts.gaegu(
                  fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white)),
              ),
            ),
            // Hand-drawn pointing finger — rotated to point LEFT at button
            Positioned(
              right: -32,
              bottom: -8,
              child: Transform(
                alignment: Alignment.center,
                transform: Matrix4.identity()..scale(-1.0, 1.0),  // flip horizontally
                child: Image.asset('assets/store/hand_tap.png',
                  width: 44, height: 44,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink()),
              ),
            ),
          ],
        ),
      ]),
    );
  }

  bool _freeUsedThisSession = false;

  void _freeTap() async {
    // Check if already used this week
    final prefs = await SharedPreferences.getInstance();
    final lastFreeStr = prefs.getString('last_free_item_date');
    if (lastFreeStr != null) {
      final lastFree = DateTime.tryParse(lastFreeStr);
      if (lastFree != null && DateTime.now().difference(lastFree).inDays < 7) {
        final daysLeft = 7 - DateTime.now().difference(lastFree).inDays;
        _showPurchasePopup('Weekly Gift', 'assets/store/gift_box.png',
            'Come back in $daysLeft day${daysLeft == 1 ? '' : 's'} for another free item!', canWear: false);
        return;
      }
    }

    // Pick a random clothing item from the store's exclusive clothing
    final clothingItems = _cats.first.items.where((i) => !_owned.contains(i.id)).toList();
    if (clothingItems.isEmpty) {
      _showPurchasePopup('All Collected!', 'assets/store/gift_box.png',
          'You already own all the clothing! Amazing!', canWear: false);
      return;
    }
    final random = clothingItems[math.Random().nextInt(clothingItems.length)];

    // Save the timestamp
    await prefs.setString('last_free_item_date', DateTime.now().toIso8601String());

    // Add to owned
    setState(() {
      _owned.add(random.id);
      _ownedBackendIds.add(random.id);
    });
    await prefs.setStringList('store_owned', _owned.toList());

    _showPurchasePopup(random.n, random.a,
        'Surprise! You got ${random.n}!', itemId: random.id);
  }

  void _buy(_It item) {
    if (_owned.contains(item.id)) return; // already owned
    final cash = ref.read(dashboardProvider).cash;
    if (cash >= item.p) {
      // Deduct coins — syncs to backend with item ID
      ref.read(dashboardProvider.notifier).spendCash(item.p, itemId: item.id);
      setState(() {
        _owned.add(item.id);
        _ownedBackendIds.add(item.id);
      });

      // Persist to local cache
      SharedPreferences.getInstance().then((prefs) {
        prefs.setStringList('store_owned', _owned.toList());
      });

      // Check achievements after purchase
      ref.read(dashboardProvider.notifier).checkAchievements();

      _showPurchasePopup(item.n, item.a,
          _purchaseQuotes[(item.n.hashCode % _purchaseQuotes.length).abs()], itemId: item.id);
    } else {
      _showPurchasePopup(item.n, item.a,
          'Need ${item.p - cash} more coins!', canWear: false);
    }
  }

  static const _purchaseQuotes = [
    'So cute, it feels disrespectful stepping on it!',
    'Looking absolutely adorable!',
    'Your avatar is going to LOVE this!',
    'Wow, what a great pick!',
    'Fashion icon in the making!',
    'This one is chef\'s kiss!',
    'Your friends will be so jealous!',
    'Style level: maximum cuteness!',
  ];

  /// Maps store item IDs to clothes style+color for avatar pre-selection
  static const _storeIdToClothes = <String, Map<String, String>>{
    'clothes_sweater_babypink': {'style': 'sweater', 'color': 'babypink'},
    'clothes_sweater_brown': {'style': 'sweater', 'color': 'brown'},
    'clothes_cneck_brown': {'style': 'c-neck', 'color': 'brown'},
    'clothes_cneck_olive': {'style': 'c-neck', 'color': 'olive'},
    'clothes_nightdress_babypink': {'style': 'night-dress', 'color': 'babypink'},
    'clothes_nightdress_brown': {'style': 'night-dress', 'color': 'brown'},
    'clothes_offshoulder_olive': {'style': 'off-shoulder', 'color': 'olive'},
    'clothes_tanktop_babypink': {'style': 'tank-top', 'color': 'babypink'},
    'clothes_tanktop_brown': {'style': 'tank-top', 'color': 'brown'},
    'clothes_vneck_brown': {'style': 'v-neck-sweater', 'color': 'brown'},
    'clothes_vneck_olive': {'style': 'v-neck-sweater', 'color': 'olive'},
  };

  void _showPurchasePopup(String name, String asset, String quote, {bool canWear = true, String? itemId}) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'close',
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 400),
      transitionBuilder: (ctx, a1, a2, child) {
        return Transform.scale(
          scale: Curves.easeOutBack.transform(a1.value),
          child: Opacity(opacity: a1.value, child: child),
        );
      },
      pageBuilder: (ctx, a1, a2) {
        return Center(child: Material(
          color: Colors.transparent,
          child: SizedBox(
            width: 380, height: 420,
            child: Stack(
              clipBehavior: Clip.none,
              alignment: Alignment.topCenter,
              children: [
                Positioned(
                  top: 130, left: 0, right: 0, bottom: 0,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFFFFF8E8),
                      borderRadius: BorderRadius.circular(28),
                      border: Border.all(color: _outline, width: 3.5),
                      boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
                          offset: const Offset(0, 8), blurRadius: 0)],
                    ),
                    padding: const EdgeInsets.fromLTRB(24, 60, 24, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Quote text
                        Text(quote, textAlign: TextAlign.center,
                          style: GoogleFonts.gaegu(
                            fontSize: 24, fontWeight: FontWeight.w700,
                            color: _brown, height: 1.3)),
                        const SizedBox(height: 20),
                        // "Wear" button → navigate to avatar customization with item pre-selected
                        if (canWear)
                          GestureDetector(
                            onTap: () {
                              Navigator.of(ctx).pop();
                              final clothesInfo = itemId != null ? _storeIdToClothes[itemId] : null;
                              if (clothesInfo != null) {
                                context.push('/avatar?style=${clothesInfo['style']}&color=${clothesInfo['color']}');
                              } else {
                                context.push('/avatar');
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 48),
                              decoration: BoxDecoration(
                                gradient: const LinearGradient(
                                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                                  colors: [Color(0xFFD0F0CA), _green]),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: _greenDk, width: 3),
                                boxShadow: [BoxShadow(color: _greenDk.withOpacity(0.4),
                                    offset: const Offset(0, 5), blurRadius: 0)],
                              ),
                              child: Text('Wear', style: GoogleFonts.gaegu(
                                fontSize: 26, fontWeight: FontWeight.w700,
                                color: Colors.white,
                                shadows: [Shadow(color: Colors.black.withOpacity(0.15),
                                    offset: const Offset(0, 1), blurRadius: 0)])),
                            ),
                          )
                        else
                          GestureDetector(
                            onTap: () => Navigator.of(ctx).pop(),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 40),
                              decoration: BoxDecoration(
                                color: const Color(0xFFD0A0A0),
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(color: _outline, width: 3),
                                boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
                                    offset: const Offset(0, 5), blurRadius: 0)],
                              ),
                              child: Text('Oh no!', style: GoogleFonts.gaegu(
                                fontSize: 24, fontWeight: FontWeight.w700,
                                color: Colors.white)),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                Positioned(
                  top: 0, left: 0, right: 0, height: 200,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Sunburst glow
                      Container(width: 200, height: 200, decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          _goldGlow.withOpacity(0.7),
                          _goldGlow.withOpacity(0.25),
                          Colors.transparent,
                        ], stops: const [0.0, 0.45, 1.0]),
                      )),
                      // Sparkle dots
                      Positioned(top: 30, left: 140, child: _sparkle(8)),
                      Positioned(top: 50, right: 130, child: _sparkle(6)),
                      Positioned(top: 10, right: 160, child: _sparkle(5)),
                      // Item image — tilted for playfulness
                      Transform.rotate(angle: -0.15,
                        child: asset.isNotEmpty
                          ? Image.asset(asset, width: 110, height: 110,
                              fit: BoxFit.contain, filterQuality: FilterQuality.medium,
                              errorBuilder: (_, __, ___) => Icon(Icons.auto_awesome,
                                size: 70, color: _goldGlow))
                          : Icon(Icons.auto_awesome, size: 70, color: _goldGlow)),
                    ],
                  ),
                ),
                Positioned(
                  top: 115, left: -8,
                  child: GestureDetector(
                    onTap: () => Navigator.of(ctx).pop(),
                    child: Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topCenter, end: Alignment.bottomCenter,
                          colors: [Color(0xFFF0CCC4), _closeBg]),
                        shape: BoxShape.circle,
                        border: Border.all(color: _outline, width: 3),
                        boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
                            offset: const Offset(0, 4), blurRadius: 0)],
                      ),
                      child: Center(child: Text('X', style: GoogleFonts.gaegu(
                        fontSize: 22, fontWeight: FontWeight.w900, color: _outline))),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ));
      },
    );
  }

  static Widget _sparkle(double r) {
    return Container(width: r * 2, height: r * 2, decoration: const BoxDecoration(
      color: Colors.white, shape: BoxShape.circle,
      boxShadow: [BoxShadow(color: Colors.white54, blurRadius: 4, spreadRadius: 1)],
    ));
  }
}

// PAWPRINT OMBRÉ BACKGROUND (from avatar page)
class _PawPrintBg extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    const spacing = 90.0;   // wider spacing for bigger paws
    const rowShift = 45.0;
    const pawR = 10.0;      // MUCH bigger main pad
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

  /// Draws a recognizable cat paw: big oval main pad + 4 rounded toe beans
  void _drawCatPaw(Canvas c, Paint p, double cx, double cy, double r, double a) {
    c.save();
    c.translate(cx, cy);
    c.rotate(a);
    // Main pad — oval (wider than tall, like a real cat pad)
    c.drawOval(Rect.fromCenter(
      center: Offset.zero, width: r * 2.2, height: r * 1.8), p);
    // 4 toe beans — round, spread in an arc above the main pad
    final tr = r * 0.52;  // toe bean radius
    // Outer left toe
    c.drawCircle(Offset(-r * 1.0, -r * 1.35), tr, p);
    // Inner left toe
    c.drawCircle(Offset(-r * 0.38, -r * 1.65), tr, p);
    // Inner right toe
    c.drawCircle(Offset(r * 0.38, -r * 1.65), tr, p);
    // Outer right toe
    c.drawCircle(Offset(r * 1.0, -r * 1.35), tr, p);
    c.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

// SCALLOP PAINTER — hangs from top
class _ScallopP extends CustomPainter {
  final Color fill, bdr;
  const _ScallopP({required this.fill, required this.bdr});
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    // Scallop path: flat top, rounded bottom
    final fp = Path()
      ..moveTo(0, 0)..lineTo(w, 0)..lineTo(w, h * 0.38)
      ..quadraticBezierTo(w, h, w / 2, h)
      ..quadraticBezierTo(0, h, 0, h * 0.38)..close();
    // Drop shadow — thick for 3D pop
    c.drawPath(fp.shift(const Offset(0, 5)),
        Paint()..color = bdr.withOpacity(0.3));
    // Fill
    c.drawPath(fp, Paint()..color = fill);
    // Border (only sides + bottom, not top edge)
    final bp = Path()
      ..moveTo(0, 0)..lineTo(0, h * 0.38)
      ..quadraticBezierTo(0, h, w / 2, h)
      ..quadraticBezierTo(w, h, w, h * 0.38)..lineTo(w, 0);
    c.drawPath(bp, Paint()..color = bdr
      ..style = PaintingStyle.stroke..strokeWidth = 2.5);
  }
  @override
  bool shouldRepaint(_ScallopP o) => o.fill != fill || o.bdr != bdr;
}

// TAB ICON PAINTER — proper category icons
class _TabIconP extends CustomPainter {
  final _TabIcon type;
  const _TabIconP(this.type);
  @override
  void paint(Canvas c, Size s) {
    final cx = s.width / 2, cy = s.height / 2;
    final r = s.width * 0.38;
    final stroke = Paint()..color = _outline..style = PaintingStyle.stroke..strokeWidth = 2;
    final fill = Paint()..style = PaintingStyle.fill;
    switch (type) {
      case _TabIcon.shirt:
        final sw = r * 2.0, sh = r * 1.8;
        final sl = cx - sw / 2, st = cy - sh / 2 + 1;
        // Body
        final body = Path()
          ..moveTo(sl + sw * 0.2, st)           // left shoulder
          ..lineTo(sl + sw * 0.35, st + sh * 0.15) // left neckline
          ..lineTo(sl + sw * 0.5, st + sh * 0.05)  // center neck dip
          ..lineTo(sl + sw * 0.65, st + sh * 0.15) // right neckline
          ..lineTo(sl + sw * 0.8, st)           // right shoulder
          ..lineTo(sl + sw, st + sh * 0.2)      // right sleeve out
          ..lineTo(sl + sw * 0.82, st + sh * 0.35) // right sleeve in
          ..lineTo(sl + sw * 0.78, st + sh * 0.35)
          ..lineTo(sl + sw * 0.78, st + sh)     // right hem
          ..lineTo(sl + sw * 0.22, st + sh)     // left hem
          ..lineTo(sl + sw * 0.22, st + sh * 0.35)
          ..lineTo(sl + sw * 0.18, st + sh * 0.35) // left sleeve in
          ..lineTo(sl, st + sh * 0.2)            // left sleeve out
          ..close();
        fill.color = const Color(0xFFB8E0F0);
        c.drawPath(body, fill);
        c.drawPath(body, stroke);
        break;

      case _TabIcon.scissors:
        // Cute hair dryer — round body + nozzle + handle
        final dr = r * 0.7;
        // Dryer body (circle)
        c.drawCircle(Offset(cx - r * 0.1, cy - r * 0.2), dr,
          Paint()..color = const Color(0xFFF8C0D0));
        c.drawCircle(Offset(cx - r * 0.1, cy - r * 0.2), dr, stroke);
        // Nozzle (rectangle sticking out right)
        final nz = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx + dr * 0.4, cy - r * 0.45, r * 0.8, r * 0.5),
          const Radius.circular(3));
        c.drawRRect(nz, Paint()..color = const Color(0xFFE8A8B8));
        c.drawRRect(nz, stroke);
        // Handle (rectangle going down)
        final hd = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - r * 0.35, cy + r * 0.2, r * 0.5, r * 0.9),
          const Radius.circular(4));
        c.drawRRect(hd, Paint()..color = const Color(0xFFF8C0D0));
        c.drawRRect(hd, stroke);
        // Wind lines from nozzle
        final windP = Paint()..color = _outline.withOpacity(0.4)
          ..style = PaintingStyle.stroke..strokeWidth = 1.2..strokeCap = StrokeCap.round;
        c.drawLine(Offset(cx + r * 1.25, cy - r * 0.35), Offset(cx + r * 1.55, cy - r * 0.35), windP);
        c.drawLine(Offset(cx + r * 1.25, cy - r * 0.2), Offset(cx + r * 1.6, cy - r * 0.2), windP);
        c.drawLine(Offset(cx + r * 1.25, cy - r * 0.05), Offset(cx + r * 1.55, cy - r * 0.05), windP);
        break;

      case _TabIcon.glasses:
        final gr = r * 0.72;
        // Left lens
        c.drawCircle(Offset(cx - gr * 0.82, cy + r * 0.05), gr,
          Paint()..color = const Color(0xFFB8D8F0));
        c.drawCircle(Offset(cx - gr * 0.82, cy + r * 0.05), gr, stroke);
        // Right lens
        c.drawCircle(Offset(cx + gr * 0.82, cy + r * 0.05), gr,
          Paint()..color = const Color(0xFFB8D8F0));
        c.drawCircle(Offset(cx + gr * 0.82, cy + r * 0.05), gr, stroke);
        // Bridge (arc)
        final bridge = Path()
          ..moveTo(cx - gr * 0.15, cy - gr * 0.3)
          ..quadraticBezierTo(cx, cy - gr * 0.6, cx + gr * 0.15, cy - gr * 0.3);
        c.drawPath(bridge, Paint()..color = _outline..style = PaintingStyle.stroke
          ..strokeWidth = 2.5..strokeCap = StrokeCap.round);
        // Lens shine (tiny highlight)
        c.drawCircle(Offset(cx - gr * 1.0, cy - gr * 0.2), gr * 0.18,
          Paint()..color = Colors.white.withOpacity(0.6));
        c.drawCircle(Offset(cx + gr * 0.65, cy - gr * 0.2), gr * 0.18,
          Paint()..color = Colors.white.withOpacity(0.6));
        break;

      case _TabIcon.hat:
        // Brim
        final brimY = cy + r * 0.25;
        c.drawOval(
          Rect.fromCenter(center: Offset(cx, brimY),
            width: r * 2.6, height: r * 0.7),
          Paint()..color = const Color(0xFFE8C878));
        c.drawOval(
          Rect.fromCenter(center: Offset(cx, brimY),
            width: r * 2.6, height: r * 0.7), stroke);
        // Crown
        final crown = RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - r * 0.75, cy - r * 0.8, r * 1.5, r * 1.15),
          const Radius.circular(6));
        c.drawRRect(crown, Paint()..color = const Color(0xFFE8C878));
        c.drawRRect(crown, stroke);
        // Band
        c.drawRect(
          Rect.fromLTWH(cx - r * 0.75, brimY - r * 0.15, r * 1.5, r * 0.25),
          Paint()..color = const Color(0xFFC8A058));
        break;

      case _TabIcon.sparkle:
        // 4-point sparkle
        final sp = Path();
        sp.moveTo(cx, cy - r * 1.1);
        sp.quadraticBezierTo(cx + r * 0.15, cy - r * 0.15, cx + r * 1.1, cy);
        sp.quadraticBezierTo(cx + r * 0.15, cy + r * 0.15, cx, cy + r * 1.1);
        sp.quadraticBezierTo(cx - r * 0.15, cy + r * 0.15, cx - r * 1.1, cy);
        sp.quadraticBezierTo(cx - r * 0.15, cy - r * 0.15, cx, cy - r * 1.1);
        sp.close();
        fill.color = const Color(0xFFF8E080);
        c.drawPath(sp, fill);
        c.drawPath(sp, stroke);
        // Center dot
        c.drawCircle(Offset(cx, cy), 2, Paint()..color = _outline);
        break;

      case _TabIcon.bolt:
        final bp = Path()
          ..moveTo(cx + r * 0.1, cy - r * 1.2)
          ..lineTo(cx - r * 0.5, cy - r * 0.05)
          ..lineTo(cx + r * 0.05, cy - r * 0.05)
          ..lineTo(cx - r * 0.1, cy + r * 1.2)
          ..lineTo(cx + r * 0.5, cy + r * 0.05)
          ..lineTo(cx - r * 0.05, cy + r * 0.05)
          ..close();
        fill.color = const Color(0xFFF8D048);
        c.drawPath(bp, fill);
        c.drawPath(bp, stroke);
        break;
    }
  }

  @override
  bool shouldRepaint(_TabIconP o) => o.type != type;
}

// KAWAII SHOPPING BAG PAINTER — cute face, handles
class _KawaiiP extends CustomPainter {
  const _KawaiiP();
  @override
  void paint(Canvas c, Size s) {
    final w = s.width, h = s.height;
    final bx = w * 0.1, by = h * 0.25, bw = w * 0.8, bh = h * 0.7;
    // Bag body
    final body = RRect.fromRectAndRadius(
      Rect.fromLTWH(bx, by, bw, bh), const Radius.circular(8));
    c.drawRRect(body, Paint()..color = _bagPurp);
    c.drawRRect(body, Paint()..color = _outline
      ..style = PaintingStyle.stroke..strokeWidth = 2.5);
    // Handles
    final lh = Path()
      ..moveTo(bx + bw * 0.25, by + 2)
      ..quadraticBezierTo(bx + bw * 0.25, h * 0.08, w * 0.42, h * 0.08)
      ..quadraticBezierTo(w * 0.58, h * 0.08, bx + bw * 0.55, by + 2);
    c.drawPath(lh, Paint()..color = _outline..style = PaintingStyle.stroke
      ..strokeWidth = 3..strokeCap = StrokeCap.round);
    final rh = Path()
      ..moveTo(bx + bw * 0.45, by + 2)
      ..quadraticBezierTo(bx + bw * 0.45, h * 0.12, w * 0.62, h * 0.12)
      ..quadraticBezierTo(bx + bw * 0.8, h * 0.12, bx + bw * 0.75, by + 2);
    c.drawPath(rh, Paint()..color = _outline..style = PaintingStyle.stroke
      ..strokeWidth = 3..strokeCap = StrokeCap.round);
    // Cute face
    final ey = by + bh * 0.4;
    c.drawCircle(Offset(w * 0.38, ey), 3, Paint()..color = _outline);
    c.drawCircle(Offset(w * 0.62, ey), 3, Paint()..color = _outline);
    c.drawCircle(Offset(w * 0.39, ey - 1), 1, Paint()..color = Colors.white);
    c.drawCircle(Offset(w * 0.63, ey - 1), 1, Paint()..color = Colors.white);
    // Cat mouth
    final mp = Path()
      ..moveTo(w * 0.35, ey + 8)
      ..quadraticBezierTo(w * 0.42, ey + 14, w * 0.5, ey + 8)
      ..quadraticBezierTo(w * 0.58, ey + 14, w * 0.65, ey + 8);
    c.drawPath(mp, Paint()..color = _outline..style = PaintingStyle.stroke
      ..strokeWidth = 1.5..strokeCap = StrokeCap.round);
    // Blush
    c.drawCircle(Offset(w * 0.28, ey + 6), 5,
      Paint()..color = const Color(0xFFF0A8A0).withOpacity(0.5));
    c.drawCircle(Offset(w * 0.72, ey + 6), 5,
      Paint()..color = const Color(0xFFF0A8A0).withOpacity(0.5));
  }
  @override
  bool shouldRepaint(covariant CustomPainter o) => false;
}

// CURRENCY PILL — cutesy green from avatar page
class _CurPill extends StatelessWidget {
  final int amt;
  final bool isCoin;
  final bool isXp;
  final VoidCallback? onPlusTap;
  const _CurPill({required this.amt, required this.isCoin, this.isXp = false, this.onPlusTap});
  @override
  Widget build(BuildContext ctx) {
    // Pill colors based on type
    final List<Color> pillGrad;
    final Color pillBorder;
    if (isXp) {
      pillGrad = const [Color(0xFFFFE888), Color(0xFFE8C840)];
      pillBorder = const Color(0xFFD0B048);
    } else {
      pillGrad = const [Color(0xFFD0F0CA), _green];
      pillBorder = _greenDk;
    }

    return SizedBox(height: 38, width: 145, child: Stack(
      clipBehavior: Clip.none,
      children: [
        // Pill body
        Positioned(left: 16, top: 3, child: Container(
          width: 100, height: 32,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter, end: Alignment.bottomCenter,
              colors: pillGrad),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: pillBorder, width: 2.5),
            boxShadow: [BoxShadow(color: pillBorder.withOpacity(0.35),
                offset: const Offset(0, 3), blurRadius: 0)],
          ),
          alignment: Alignment.center,
          child: Text('$amt', style: GoogleFonts.gaegu(
            fontSize: 20, fontWeight: FontWeight.w700, color: Colors.white,
            shadows: [Shadow(color: Colors.black.withOpacity(0.2),
                offset: const Offset(0, 1), blurRadius: 0)])),
        )),
        // Icon: XP star, coin, or bill
        Positioned(left: -2, top: -1, child: isXp
          ? Container(
              width: 38, height: 38,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFFFFE888), Color(0xFFE8C840)]),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFD0B048), width: 2.5),
              ),
              child: const Icon(Icons.star_rounded, size: 20, color: Colors.white),
            )
          : isCoin
            ? Image.asset('assets/store/coin.png', width: 40, height: 40,
                filterQuality: FilterQuality.medium,
                errorBuilder: (_, __, ___) => _fallbackCoin())
            : _billIcon()),
        // "+" button — tappable, navigates to cash converter
        Positioned(right: 0, top: 4, child: GestureDetector(
          onTap: onPlusTap,
          child: Container(
            width: 28, height: 28,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Color(0xFFFFF0A0), _goldGlow],
              ),
              shape: BoxShape.circle,
              border: Border.all(color: const Color(0xFFD0B050), width: 2),
              boxShadow: [BoxShadow(color: const Color(0xFFD0B050).withOpacity(0.3),
                  offset: const Offset(0, 2), blurRadius: 0)],
            ),
            child: const Center(child: Icon(Icons.add_rounded, size: 16,
                color: Color(0xFF8A6820))),
          ),
        )),
      ],
    ));
  }

  static Widget _fallbackCoin() {
    return Container(width: 38, height: 38, decoration: BoxDecoration(
      shape: BoxShape.circle, color: const Color(0xFFE8D060),
      border: Border.all(color: const Color(0xFFC8A840), width: 2.5),
    ), child: Center(child: Text('\$', style: GoogleFonts.gaegu(
      fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFFA08020)))));
  }

  Widget _billIcon() {
    return SizedBox(width: 38, height: 38, child: Center(child: Transform.rotate(
      angle: -0.15,
      child: Container(width: 30, height: 20, decoration: BoxDecoration(
        color: _billFill, borderRadius: BorderRadius.circular(3),
        border: Border.all(color: const Color(0xFF4D8D48), width: 2.5),
      ), child: Center(child: Text('\$', style: GoogleFonts.gaegu(
        fontSize: 12, fontWeight: FontWeight.w700, color: _billTx)))),
    )));
  }
}

// ITEM CARD — tilted images, smaller, 3D feel
class _Card extends StatefulWidget {
  final _It item;
  final bool sold;
  final VoidCallback onBuy;
  const _Card({required this.item, required this.onBuy, this.sold = false});
  @override
  State<_Card> createState() => _CardS();
}

class _CardS extends State<_Card> {
  bool _p = false;
  @override
  Widget build(BuildContext ctx) {
    final it = widget.item;
    // Alternate tilt direction for variety
    final tiltAngle = (it.n.hashCode % 2 == 0) ? 0.12 : -0.12;  // ~7° subtle tilt like reference
    return GestureDetector(
      onTapDown: (_) => setState(() => _p = true),
      onTapUp: (_) { setState(() => _p = false); widget.onBuy(); },
      onTapCancel: () => setState(() => _p = false),
      child: AnimatedScale(
        scale: _p ? 0.93 : 1.0,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          transform: Matrix4.translationValues(0, _p ? 4 : 0, 0),
          decoration: BoxDecoration(
            color: _white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: _outline, width: 3),
            boxShadow: _p
              ? [BoxShadow(color: _outline.withOpacity(0.2),
                  offset: const Offset(0, 2), blurRadius: 0)]
              : [
                  // Side shadow for 3D depth
                  BoxShadow(color: _outline.withOpacity(0.15),
                      offset: const Offset(4, 7), blurRadius: 0),
                  // Main hard drop shadow — CHUNKY
                  BoxShadow(color: _outline.withOpacity(0.4),
                      offset: const Offset(0, 8), blurRadius: 0),
                ],
          ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(9),
          child: Stack(children: [
            Column(children: [
              // Purple header
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 5, horizontal: 6),
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: [Color(0xFFDDBDE8), _purpleHdr],
                  ),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(9), topRight: Radius.circular(9)),
                ),
                alignment: Alignment.center,
                child: Text(it.n, style: GoogleFonts.gaegu(
                  fontSize: 15, fontWeight: FontWeight.w700,
                  color: _brown, height: 1.15),
                  textAlign: TextAlign.center, maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              ),
              // Item image
              Expanded(child: LayoutBuilder(
                builder: (ctx, box) {
                  final imgSize = box.maxWidth * 0.80;
                  return Center(child: it.a.isNotEmpty
                    ? Transform.rotate(angle: tiltAngle,
                        child: Image.asset(it.a,
                          width: imgSize, height: imgSize,
                          fit: BoxFit.contain, filterQuality: FilterQuality.medium,
                          errorBuilder: (_, __, ___) => Icon(it.ic ?? Icons.checkroom,
                            size: imgSize * 0.6, color: _purpleHdr.withOpacity(0.5))))
                    : Icon(it.ic ?? Icons.auto_awesome, size: imgSize * 0.55,
                        color: _purpleHdr.withOpacity(0.7)));
                },
              )),
              // Price pill
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                child: Container(
                  height: 30,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter, end: Alignment.bottomCenter,
                      colors: [Color(0xFFD0F0CA), _green]),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _greenDk, width: 3),
                    boxShadow: [BoxShadow(color: _greenDk.withOpacity(0.45),
                        offset: const Offset(0, 4), blurRadius: 0)],
                  ),
                  child: Row(children: [
                    const SizedBox(width: 4),
                    Transform.rotate(angle: -15 * math.pi / 180,
                      child: Container(width: 24, height: 16,
                        decoration: BoxDecoration(
                          color: _billFill, borderRadius: BorderRadius.circular(2),
                          border: Border.all(color: const Color(0xFF4D8D48), width: 1.5)),
                        child: Center(child: Text('\$', style: GoogleFonts.gaegu(
                          fontSize: 9, fontWeight: FontWeight.w700, color: _billTx))))),
                    Expanded(child: Center(child: Text(
                      it.p == 0 ? '?' : '${it.p}',
                      style: GoogleFonts.gaegu(
                        fontSize: 20, fontWeight: FontWeight.w700,
                        color: Colors.white,
                        shadows: [Shadow(color: Colors.black.withOpacity(0.2),
                            offset: const Offset(0, 1), blurRadius: 0)])))),
                  ]),
                ),
              ),
            ]),
            if (widget.sold) ...[
              // White dimmer
              Positioned.fill(child: Container(
                color: Colors.white.withOpacity(0.45),
              )),
              // Tilted pink SOLD banner
              Positioned.fill(child: Center(
                child: Transform.rotate(angle: -0.3,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0A0B0),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: _outline, width: 2.5),
                      boxShadow: [BoxShadow(color: _outline.withOpacity(0.3),
                          offset: const Offset(0, 3), blurRadius: 0)],
                    ),
                    child: Text('SOLD', style: GoogleFonts.gaegu(
                      fontSize: 20, fontWeight: FontWeight.w900,
                      color: Colors.white, letterSpacing: 2,
                      shadows: [Shadow(color: Colors.black.withOpacity(0.15),
                          offset: const Offset(0, 1), blurRadius: 0)])),
                  ),
                ),
              )),
            ],
          ]),
        ),
      ),
    ));  // close AnimatedScale + GestureDetector
  }
}

class _Cat {
  final String n;
  final List<_It> items;
  const _Cat({required this.n, required this.items});
}

class _It {
  final String id; // backend item ID
  final String n, a;
  final int p;
  final IconData? ic;
  final String? rarity; // common, uncommon, rare, epic
  const _It({required this.id, required this.n, required this.a, required this.p, this.ic, this.rarity});
}
