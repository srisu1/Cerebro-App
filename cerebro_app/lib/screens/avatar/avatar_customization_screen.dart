/// EXACT 1:1 port of .NET Avatar.razor + Avatar.css
/// Avatar: OverflowBox + Transform.scale on native image sizes (matches CSS)

import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cerebro_app/config/constants.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:cerebro_app/models/avatar_config.dart';
import 'package:cerebro_app/models/avatar_positions.dart';
import 'package:cerebro_app/providers/dashboard_provider.dart';
import 'package:cerebro_app/providers/auth_provider.dart';
import 'package:cerebro_app/services/api_service.dart';

// .NET CSS constants
const _panelPink = Color(0xFFF4A9C1);
const _panelBodyPink = Color(0xFFF9E5EF);
const _tabBg = Color(0xFFF6E0E9);
const _genderActive = Color(0xFFF490AF);
const _okGreen = Color(0xFFA8D5A3);

class AvatarCustomizationScreen extends ConsumerStatefulWidget {
  final bool isSetup;
  final String? preSelectStyle;
  final String? preSelectColor;
  const AvatarCustomizationScreen({super.key, this.isSetup = false, this.preSelectStyle, this.preSelectColor});
  @override
  ConsumerState<AvatarCustomizationScreen> createState() =>
      _AvatarCustomizationScreenState();
}

class _AvatarCustomizationScreenState
    extends ConsumerState<AvatarCustomizationScreen>
    with TickerProviderStateMixin {
  late final AnimationController _enterCtrl;
  late final AnimationController _floatCtrl;
  late final Animation<double> _panelSlide;
  late final Animation<double> _avatarScale;
  late final Animation<double> _bottomFade;
  late final Animation<double> _floatAnim;

  String _gender = 'female';
  int _baseIndex = 1;
  int _eyesIndex = 1;
  int _noseIndex = 1;
  int _mouthIndex = 1;
  String _hairStyle = 'medium-curl';
  String _hairColor = 'black';
  String _clothesStyle = 'off-shoulder';
  String _clothesColor = 'blue';
  String? _facialHairStyle;
  String? _glassesStyle;
  String? _headwearStyle;
  String? _headwearColor;
  String? _neckwearStyle;
  String? _neckwearColor;
  String? _extrasStyle;
  String? _extrasColor;
  String _currentCategory = 'skin';
  final _nameCtrl = TextEditingController();

  /// Store-owned item IDs (loaded from SharedPreferences)
  Set<String> _ownedStoreItems = {};

  /// No color-level locks — only individual items are locked
  static const _lockedHairColors = <String>{}; // none locked
  static const _lockedGlasses = {'star-glasses'}; // only star glasses locked
  static const _lockedHeadwear = {'magician-hat'}; // only magician hat locked
  static const _lockedNeckwear = <String>{}; // none locked
  static const _lockedExtras = <String>{}; // none locked
  // Eye indices that require store purchase (the fancy/special ones)
  static const _lockedEyeIndices = {20, 25, 30, 35, 40};

  /// Lock checks — returns true if item needs store purchase
  bool _isHairColorLocked(String color) =>
      _lockedHairColors.contains(color) && !_ownedStoreItems.contains('hair_$color');

  bool _isGlassesLocked(String style) {
    const idMap = {'star-glasses': 'glasses_star', 'heart-glasses': 'glasses_heart', 'sunglasses': 'sunglasses'};
    return _lockedGlasses.contains(style) && !_ownedStoreItems.contains(idMap[style] ?? '');
  }

  bool _isHeadwearLocked(String style) {
    const idMap = {'magician-hat': 'hat_magician', 'french-cap': 'hat_french', 'winter-cap': 'winter_cap'};
    return _lockedHeadwear.contains(style) && !_ownedStoreItems.contains(idMap[style] ?? '');
  }

  bool _isNeckwearLocked(String style) =>
      _lockedNeckwear.contains(style) && !_ownedStoreItems.contains('tie_bowtie');

  bool _isExtrasLocked(String style) =>
      _lockedExtras.contains(style) && !_ownedStoreItems.contains('flower_red');

  bool _isEyeLocked(int idx) =>
      _lockedEyeIndices.contains(idx) && !_ownedStoreItems.contains('eyes_$idx');

  /// Store clothing colors — locked per style+color combo
  static const _storeClothesColors = {'babypink', 'brown', 'olive'};

  /// Maps a style+color to the store item ID that unlocks it
  static String? _storeClothingId(String style, String color) {
    const map = {
      'sweater-babypink': 'clothes_sweater_babypink',
      'sweater-brown': 'clothes_sweater_brown',
      'c-neck-brown': 'clothes_cneck_brown',
      'c-neck-olive': 'clothes_cneck_olive',
      'night-dress-babypink': 'clothes_nightdress_babypink',
      'night-dress-brown': 'clothes_nightdress_brown',
      'off-shoulder-olive': 'clothes_offshoulder_olive',
      'tank-top-babypink': 'clothes_tanktop_babypink',
      'tank-top-brown': 'clothes_tanktop_brown',
      'v-neck-sweater-brown': 'clothes_vneck_brown',
      'v-neck-sweater-olive': 'clothes_vneck_olive',
    };
    return map['$style-$color'];
  }

  /// Returns true if a specific clothes style+color combo is locked.
  /// Base colors (green, red, blue, black) are NEVER locked.
  /// Store colors (babypink, brown, olive) are locked per-item until purchased.
  bool _isClothesItemLocked(String style, String color) {
    if (!_storeClothesColors.contains(color)) return false; // base colors always free
    final storeId = _storeClothingId(style, color);
    if (storeId == null) return true; // no store item exists for this combo
    return !_ownedStoreItems.contains(storeId);
  }

  /// Get the correct asset path for a clothes style+color combo.
  /// Store colors (babypink, brown, olive) use assets/store/Store_items/
  /// Base colors (green, red, blue, black) use assets/avatar/{gender}/clothes/
  String _clothesAssetPath(String style, String color) {
    if (_storeClothesColors.contains(color)) {
      // Map to store item filename (handle naming differences)
      final fileName = style == 'off-shoulder' ? 'offshoulder-$color' : '$style-$color';
      return 'assets/store/Store_items/$fileName.png';
    }
    return 'assets/avatar/$_gender/clothes/$style-$color.png';
  }

  /// Store clothing items — maps store ID to asset path + style+color for avatar
  static const _storeClothingMap = <String, Map<String, String>>{
    'clothes_sweater_babypink': {'asset': 'assets/store/Store_items/sweater-babypink.png', 'style': 'sweater', 'color': 'babypink', 'label': 'Pink Sweater'},
    'clothes_sweater_brown': {'asset': 'assets/store/Store_items/sweater-brown.png', 'style': 'sweater', 'color': 'brown', 'label': 'Brown Sweater'},
    'clothes_cneck_brown': {'asset': 'assets/store/Store_items/c-neck-brown.png', 'style': 'c-neck', 'color': 'brown', 'label': 'Brown C-Neck'},
    'clothes_cneck_olive': {'asset': 'assets/store/Store_items/c-neck-olive.png', 'style': 'c-neck', 'color': 'olive', 'label': 'Olive C-Neck'},
    'clothes_nightdress_babypink': {'asset': 'assets/store/Store_items/night-dress-babypink.png', 'style': 'night-dress', 'color': 'babypink', 'label': 'Pink Night Dress'},
    'clothes_nightdress_brown': {'asset': 'assets/store/Store_items/night-dress-brown.png', 'style': 'night-dress', 'color': 'brown', 'label': 'Brown Night Dress'},
    'clothes_offshoulder_olive': {'asset': 'assets/store/Store_items/offshoulder-olive.png', 'style': 'off-shoulder', 'color': 'olive', 'label': 'Olive Off-Shoulder'},
    'clothes_tanktop_babypink': {'asset': 'assets/store/Store_items/tank-top-babypink.png', 'style': 'tank-top', 'color': 'babypink', 'label': 'Pink Tank Top'},
    'clothes_tanktop_brown': {'asset': 'assets/store/Store_items/tank-top-brown.png', 'style': 'tank-top', 'color': 'brown', 'label': 'Brown Tank Top'},
    'clothes_vneck_brown': {'asset': 'assets/store/Store_items/v-neck-sweater-brown.png', 'style': 'v-neck-sweater', 'color': 'brown', 'label': 'Brown V-Neck'},
    'clothes_vneck_olive': {'asset': 'assets/store/Store_items/v-neck-sweater-olive.png', 'style': 'v-neck-sweater', 'color': 'olive', 'label': 'Olive V-Neck'},
  };

  /// Get list of owned store clothing items
  List<MapEntry<String, Map<String, String>>> get _ownedStoreClothing =>
      _storeClothingMap.entries.where((e) => _ownedStoreItems.contains(e.key)).toList();

  final _femaleHairStyles = [
    'medium-curl','bangs','to-the-side','boys-cut','granny-hair',
    'anime-hair','bangs-short','side-pony','pigtails','bun'];
  final _maleHairStyles = [
    'curly-short','straight-short','ceo-hair','flat-hair','90s-hair',
    'bangs','pointed-pony','spiky-hair','dad-hair','edgy-hair'];
  final _hairColors = [
    'blonde','black','brown','red','orange','silver','pink','darkblue'];
  final _femaleClothesStyles = [
    'off-shoulder','night-dress','sweater','tank-top','c-neck','v-neck-sweater'];
  final _maleClothesStyles = [
    'uniform','button-up-shirt','sweater','c-neck','v-neck-sweater','tank-top'];
  final _femaleClothesColors = ['green','red','blue','babypink','brown','olive'];
  final _maleClothesColors = ['black','blue','red','green','brown','olive'];
  final _glassesOptions = [
    'circular-glasses','sunglasses','square-glasses','heart-glasses',
    'stripped-glasses','star-glasses','bottomless-glasses'];
  final _headwearOptions = [
    'basketball-cap','french-cap','hat','winter-cap','magician-hat',
    'sideways-baseball-cap','hairband1','hairband2'];
  final _neckwearOptions = ['boy-tie','straight-tie'];
  final _extrasOptions = ['lady-hat','side-bow','flower'];
  final _accessoryColors = ['red','green','yellow','black'];
  final _colorMap = <String, Color>{
    'blonde': const Color(0xFFFEE484), 'black': const Color(0xFF606060),
    'brown': const Color(0xFFCC7E2A), 'red': const Color(0xFFE05E5F),
    'orange': const Color(0xFFF37634), 'silver': const Color(0xFFD1D1D2),
    'pink': const Color(0xFFF38385), 'darkblue': const Color(0xFF727BBB),
    'green': const Color(0xFF70C4A1), 'blue': const Color(0xFF73ADC3),
    'yellow': const Color(0xFFFFEB3B),
    'babypink': const Color(0xFFF8A4B8), 'olive': const Color(0xFF9BB870),
  };

  bool _showUnlockGlow = false;

  @override
  void initState() {
    super.initState();
    _loadSaved().then((_) {
      // If navigated from store Wear button, pre-select the item
      if (widget.preSelectStyle != null && widget.preSelectColor != null) {
        setState(() {
          _currentCategory = 'clothes';
          _clothesStyle = widget.preSelectStyle!;
          _clothesColor = widget.preSelectColor!;
          _showUnlockGlow = true;
        });
        // Clear glow after animation
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) setState(() => _showUnlockGlow = false);
        });
      }
    });

    // Entrance animation — 800ms staggered
    _enterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900));
    _panelSlide = Tween<double>(begin: -60.0, end: 0.0).animate(
      CurvedAnimation(parent: _enterCtrl, curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic)));
    _avatarScale = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _enterCtrl, curve: const Interval(0.15, 0.65, curve: Curves.elasticOut)));
    _bottomFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _enterCtrl, curve: const Interval(0.4, 1.0, curve: Curves.easeOut)));
    _enterCtrl.forward();

    // Idle floating animation — gentle breathing loop
    _floatCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 3000));
    _floatAnim = Tween<double>(begin: -4.0, end: 4.0).animate(
      CurvedAnimation(parent: _floatCtrl, curve: Curves.easeInOut));
    _floatCtrl.repeat(reverse: true);
  }

  @override
  void dispose() {
    _enterCtrl.dispose();
    _floatCtrl.dispose();
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSaved() async {
    final prefs = await SharedPreferences.getInstance();

    // Load store-owned items
    final owned = prefs.getStringList('store_owned') ?? [];
    setState(() => _ownedStoreItems = owned.toSet());

    final json = prefs.getString(AppConstants.avatarConfigKey);
    if (json != null) {
      final config = AvatarConfig.fromJson(jsonDecode(json));
      setState(() {
        _gender = config.gender;
        final bn = int.tryParse(config.baseSkin.replaceAll('Base', ''));
        if (bn != null) _baseIndex = bn;
        _eyesIndex = int.tryParse(config.eyes.replaceAll('eyes', '')) ?? 1;
        _noseIndex = int.tryParse(config.nose.replaceAll('nose', '')) ?? 1;
        _mouthIndex = int.tryParse(config.mouth.replaceAll('mouth', '')) ?? 1;
        _hairStyle = config.hairStyle;
        _hairColor = config.hairColor;
        final cp = config.clothes.split('-');
        if (cp.length >= 2) {
          _clothesColor = cp.last;
          _clothesStyle = cp.sublist(0, cp.length - 1).join('-');
        }
        _facialHairStyle = config.facialHair;
        _glassesStyle = config.glasses;
        if (config.headwear != null) {
          final p = config.headwear!.split('-');
          if (p.length >= 2) { _headwearColor = p.last; _headwearStyle = p.sublist(0, p.length - 1).join('-'); }
        }
        if (config.neckwear != null) {
          final p = config.neckwear!.split('-');
          if (p.length >= 2) { _neckwearColor = p.last; _neckwearStyle = p.sublist(0, p.length - 1).join('-'); }
        }
        if (config.extras != null) {
          final p = config.extras!.split('-');
          if (p.length >= 2) { _extrasColor = p.last; _extrasStyle = p.sublist(0, p.length - 1).join('-'); }
        }
      });
    }
  }

  AvatarConfig _buildConfig() => AvatarConfig(
    gender: _gender,
    baseSkin: 'Base${_baseIndex.toString().padLeft(2, '0')}',
    eyes: 'eyes${_eyesIndex.toString().padLeft(2, '0')}',
    nose: 'nose${_noseIndex.toString().padLeft(2, '0')}',
    mouth: 'mouth${_mouthIndex.toString().padLeft(2, '0')}',
    hairStyle: _hairStyle, hairColor: _hairColor,
    clothes: '$_clothesStyle-$_clothesColor',
    facialHair: _facialHairStyle, glasses: _glassesStyle,
    headwear: _headwearStyle != null && _headwearColor != null ? '$_headwearStyle-$_headwearColor' : null,
    neckwear: _neckwearStyle != null && _neckwearColor != null ? '$_neckwearStyle-$_neckwearColor' : null,
    extras: _extrasStyle != null && _extrasColor != null ? '$_extrasStyle-$_extrasColor' : null,
  );

  Future<void> _saveAvatar() async {
    final config = _buildConfig();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.avatarConfigKey, jsonEncode(config.toJson()));
    await prefs.setBool(AppConstants.avatarCreatedKey, true);

    // Notify all providers so avatar updates everywhere instantly
    ref.read(dashboardProvider.notifier).updateAvatarConfig(config);

    // Sync avatar config to backend
    try {
      final api = ref.read(apiServiceProvider);
      await api.post('/gamification/avatar', data: {
        'gender': config.gender,
        'skin_tone': config.baseSkin,
        'hair': config.hairStyle,
        'hair_color': config.hairColor,
        'eyes': config.eyes,
        'nose': config.nose,
        'mouth': config.mouth,
        'clothes': config.clothes,
        'facial_hair': config.facialHair,
        'glasses': config.glasses,
        'headwear': config.headwear,
        'neckwear': config.neckwear,
        'extras': config.extras,
      });
    } catch (_) {
      // Backend sync failed — local save already done
    }

    if (mounted) context.go('/home');
  }

  void _switchGender(String g) {
    setState(() {
      _gender = g;
      if (g == 'male') { _clothesStyle = 'uniform'; _clothesColor = 'black'; _hairStyle = 'curly-short'; }
      else { _clothesStyle = 'off-shoulder'; _clothesColor = 'blue'; _hairStyle = 'medium-curl'; _facialHairStyle = null; }
    });
  }

  String _panelTitle() => switch (_currentCategory) {
    'skin' => 'Skin Tone', 'eyes' => 'Eyes', 'nose' => 'Nose',
    'mouth' => 'Mouth', 'hair' => 'Hair', 'clothes' => 'Clothes',
    'facialHair' => 'Facial Hair', 'accessories' => 'Accessories', _ => ''
  };

  bool _showColorSelector() {
    if (_currentCategory == 'hair' || _currentCategory == 'clothes') return true;
    if (_currentCategory == 'accessories' &&
        (_headwearStyle != null || _neckwearStyle != null || _extrasStyle != null)) return true;
    return false;
  }

  void _randomize() {
    final r = Random();
    final g = r.nextBool() ? 'male' : 'female';
    final hs = g == 'male' ? _maleHairStyles : _femaleHairStyles;
    final cs = g == 'male' ? _maleClothesStyles : _femaleClothesStyles;
    final cc = g == 'male' ? _maleClothesColors : _femaleClothesColors;
    setState(() {
      _gender = g; _baseIndex = r.nextInt(3) + 1; _eyesIndex = r.nextInt(42) + 1;
      _noseIndex = r.nextInt(10) + 1; _mouthIndex = r.nextInt(10) + 1;
      _hairStyle = hs[r.nextInt(hs.length)]; _hairColor = _hairColors[r.nextInt(_hairColors.length)];
      _clothesStyle = cs[r.nextInt(cs.length)]; _clothesColor = cc[r.nextInt(cc.length)];
      _facialHairStyle = (g == 'male' && r.nextBool()) ? 'style${r.nextInt(20) + 1}' : null;
      _glassesStyle = r.nextBool() ? _glassesOptions[r.nextInt(_glassesOptions.length)] : null;
      _headwearStyle = null; _headwearColor = null;
      _neckwearStyle = null; _neckwearColor = null;
      _extrasStyle = null; _extrasColor = null;
    });
  }

  List<_Tab> get _tabs {
    final t = <_Tab>[
      _Tab('skin', Icons.face_outlined),
      _Tab('eyes', Icons.remove_red_eye_outlined),
      _Tab('nose', Icons.air),
      _Tab('mouth', Icons.mood),
      _Tab('hair', Icons.content_cut),
      _Tab('clothes', Icons.checkroom),
    ];
    if (_gender == 'male') t.add(_Tab('facialHair', Icons.face_retouching_natural));
    t.add(_Tab('accessories', Icons.auto_awesome));
    return t;
  }

  // BUILD
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayoutBuilder(builder: (context, box) {
        final w = box.maxWidth;
        final h = box.maxHeight;
        final isWide = w > 1199;
        final tabW = 78.0;
        final panelW = isWide ? 490.0 : 440.0;
        final gap = isWide ? 40.0 : 28.0;
        final hPad = isWide ? 50.0 : 28.0;
        final vTop = isWide ? 30.0 : 20.0;
        final vBot = isWide ? 40.0 : 28.0;

        // Available height after padding
        final availH = h - vTop - vBot;

        // Left section — clamp to available height, clip overflow
        final leftH = (isWide ? 720.0 : 560.0).clamp(0.0, availH);
        final panelH = (isWide ? 720.0 : 560.0).clamp(0.0, leftH);

        // Right section — fit everything on screen, NO scrolling
        // Fixed: toggle(~56) + avatarPad(16) + name(~56) + colorSel(~54) + buttons(~56) = ~238
        final fixedRightH = 258.0;
        final idealPv = isWide ? 600.0 : 500.0;

        // Try ideal gaps; shrink then avatar if needed
        // Gaps: 1×(vGap*0.7) above avatar + 3×(vGap*0.55) below
        double pvSize, rightGap;
        if (availH >= fixedRightH + idealPv + 68) {
          pvSize = idealPv;
          rightGap = 20.0;
        } else {
          rightGap = ((availH - fixedRightH - idealPv) / 3.5).clamp(6.0, 20.0);
          pvSize = (availH - fixedRightH - rightGap * 3.5).clamp(200.0, idealPv);
        }

        // Dynamic tab gap — shrink gaps so tabs fit in leftH
        final numTabs = _tabs.length;
        final tabH = 78.0;
        final tabGap = ((leftH - numTabs * tabH) / (numTabs - 1)).clamp(2.0, 8.0);

        return Stack(children: [
          // Background: cream → pink vertical ombre
          Positioned.fill(
            child: Container(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFFEF5E8), // cream top
                    Color(0xFFFEF0E4), // warm mid
                    Color(0xFFFCE8E0), // peach
                    Color(0xFFF9DDD8), // soft pink bottom
                  ],
                  stops: [0.0, 0.4, 0.7, 1.0],
                ),
              ),
            ),
          ),
          // Inner vignette — darkens edges for 3D depth
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 0.95,
                  colors: [
                    Colors.transparent,
                    Colors.transparent,
                    Colors.black.withOpacity(0.04),
                    Colors.black.withOpacity(0.09),
                  ],
                  stops: const [0.0, 0.5, 0.8, 1.0],
                ),
              ),
            ),
          ),
          // Paw print pattern overlay
          Positioned.fill(
            child: CustomPaint(painter: _PawPrintPainter(w, h)),
          ),
          Padding(
            padding: EdgeInsets.fromLTRB(hPad, vTop, hPad, vBot),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // LEFT: tabs + panel — slide in from left
                AnimatedBuilder(
                  animation: _panelSlide,
                  builder: (context, child) => Transform.translate(
                    offset: Offset(_panelSlide.value, 0),
                    child: child,
                  ),
                  child: SizedBox(
                    width: tabW + panelW - 3,
                    height: leftH,
                    child: ClipRect(
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          // Panel (behind) — overlaps tabs by 3px
                          Positioned(
                            left: tabW - 3,
                            top: 0,
                            child: _buildPanel(panelW, panelH),
                          ),
                          // Tabs (on top)
                          Positioned(
                            left: 0,
                            top: 0,
                            child: _buildTabs(tabW, tabGap),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                SizedBox(width: gap),
                // RIGHT: everything fits — no scroll
                Expanded(child: _buildRight(pvSize, rightGap)),
              ],
            ),
          ),
          // Close button — animated Toca Boca circle
          Positioned(
            top: 16, right: 16,
            child: _AnimatedCloseBtn(onTap: () => context.go('/home')),
          ),
        ]);
      }),
    );
  }

  Widget _buildTabs(double tabW, double tabGap) {
    final tabs = _tabs;
    return Column(
      children: List.generate(tabs.length, (i) {
        final tab = tabs[i];
        final active = _currentCategory == tab.key;
        final bgColor = active ? Colors.white : _tabBg;
        return Padding(
          padding: EdgeInsets.only(bottom: i < tabs.length - 1 ? tabGap : 0),
          child: GestureDetector(
            onTap: () => setState(() => _currentCategory = tab.key),
            child: SizedBox(
              width: tabW, height: 78,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: tabW, height: 78,
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: bgColor,
                      border: Border.all(color: CerebroTheme.outline, width: 3),
                      borderRadius: const BorderRadius.only(
                        topLeft: Radius.circular(40), bottomLeft: Radius.circular(40)),
                      boxShadow: active ? [
                        BoxShadow(color: Colors.white.withOpacity(0.6), offset: const Offset(-1, -1), blurRadius: 2),
                      ] : [
                        BoxShadow(color: Colors.black.withOpacity(0.1), offset: const Offset(2, 2), blurRadius: 0),
                      ],
                    ),
                    child: Icon(tab.icon, size: 32,
                      color: active ? CerebroTheme.outline : CerebroTheme.outline.withOpacity(0.5)),
                  ),
                  // Cover right border for seamless panel join
                  Positioned(
                    right: -3, top: 3, bottom: 3,
                    child: Container(width: 6, color: bgColor),
                  ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildPanel(double panelW, double panelH) {
    return Container(
      width: panelW, height: panelH,
      decoration: BoxDecoration(
        color: _panelBodyPink,
        border: Border.all(color: CerebroTheme.outline, width: 3),
        borderRadius: const BorderRadius.only(
          topRight: Radius.circular(32), bottomRight: Radius.circular(32),
          bottomLeft: Radius.circular(8)),
        boxShadow: [
          // 3D layered shadow — hard edge + soft spread + top-left highlight
          BoxShadow(color: Colors.white.withOpacity(0.5), offset: const Offset(-2, -2), blurRadius: 3),
          BoxShadow(color: Colors.black.withOpacity(0.18), offset: const Offset(5, 5), blurRadius: 0),
          BoxShadow(color: Colors.black.withOpacity(0.07), offset: const Offset(10, 10), blurRadius: 8),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(children: [
        // Header — gradient for 3D raised look
        Container(
          width: double.infinity, height: 56,
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [Color(0xFFF7B8CD), Color(0xFFF4A9C1), Color(0xFFEF97B3)],
              stops: [0.0, 0.5, 1.0],
            ),
          ),
          alignment: Alignment.center,
          child: Text(_panelTitle(),
            style: GoogleFonts.nunito(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white,
              shadows: [Shadow(color: Colors.black.withOpacity(0.15), offset: const Offset(1, 1), blurRadius: 2)])),
        ),
        // Scrollable content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
            child: _buildOptions(panelW),
          ),
        ),
      ]),
    );
  }

  Widget _buildRight(double pvSize, double vGap) {
    final btmGap = (vGap * 0.55).clamp(6.0, 14.0);
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Gender tabs — pill toggle with 3D shadow
        FadeTransition(
          opacity: _bottomFade,
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(35),
              border: Border.all(color: CerebroTheme.outline, width: 3),
              boxShadow: [
                BoxShadow(color: Colors.black.withOpacity(0.14), offset: const Offset(3, 3), blurRadius: 0),
                BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(6, 6), blurRadius: 4),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: IntrinsicHeight(child: Row(mainAxisSize: MainAxisSize.min, children: [
              _genderBtn('Girl', 'female', isLeft: true),
              Container(width: 3, color: CerebroTheme.outline),
              _genderBtn('Boy', 'male', isLeft: false),
            ])),
          ),
        ),
        SizedBox(height: vGap * 0.7),
        // Avatar preview — floating idle animation, entrance scale bounce
        AnimatedBuilder(
          animation: Listenable.merge([_avatarScale, _floatAnim]),
          builder: (context, child) {
            return Transform.translate(
              offset: Offset(0, _floatAnim.value),
              child: Transform.scale(
                scale: _avatarScale.value,
                child: child,
              ),
            );
          },
          child: ClipRect(
            child: SizedBox(
              width: pvSize, height: pvSize,
              child: _buildAvatar(pvSize),
            ),
          ),
        ),
        SizedBox(height: btmGap),
        // Bottom controls — fade in
        FadeTransition(
          opacity: _bottomFade,
          child: Column(children: [
            // Name input — with 3D inset shadow
            Container(
              width: 380,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(40),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.08), offset: const Offset(2, 2), blurRadius: 4),
                  BoxShadow(color: Colors.white.withOpacity(0.7), offset: const Offset(-1, -1), blurRadius: 3),
                ],
              ),
              child: TextField(
                controller: _nameCtrl, textAlign: TextAlign.center, maxLength: 20,
                style: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w500, color: CerebroTheme.outline),
                decoration: InputDecoration(
                  counterText: '', hintText: 'NAME',
                  hintStyle: GoogleFonts.nunito(fontSize: 18, fontWeight: FontWeight.w500, color: const Color(0xFFBBBBBB)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(40), borderSide: const BorderSide(color: Color(0xFF4A3F35), width: 3)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(40), borderSide: const BorderSide(color: Color(0xFF4A3F35), width: 3)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(40), borderSide: BorderSide(color: _genderActive, width: 3)),
                ),
              ),
            ),
            SizedBox(height: btmGap),
            // Color selector
            SizedBox(height: 54, child: Center(child: _showColorSelector() ? _buildColorPill() : const SizedBox.shrink())),
            SizedBox(height: btmGap),
            // Buttons row: randomize + OK — bouncy tap
            Row(mainAxisSize: MainAxisSize.min, children: [
              _BounceBtn(
                onTap: _randomize,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  decoration: BoxDecoration(
                    color: CerebroTheme.gold, borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: CerebroTheme.outline, width: 3),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.15), offset: const Offset(3, 3), blurRadius: 0),
                      BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(5, 5), blurRadius: 3),
                    ],
                  ),
                  child: const Icon(Icons.casino_rounded, color: Colors.white, size: 22),
                ),
              ),
              const SizedBox(width: 16),
              _BounceBtn(
                onTap: _saveAvatar,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 14),
                  decoration: BoxDecoration(
                    color: _okGreen, borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: CerebroTheme.outline, width: 3),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withOpacity(0.15), offset: const Offset(3, 3), blurRadius: 0),
                      BoxShadow(color: Colors.black.withOpacity(0.05), offset: const Offset(5, 5), blurRadius: 3),
                    ],
                  ),
                  child: Text('OK', style: GoogleFonts.nunito(fontSize: 22, fontWeight: FontWeight.w700, color: Colors.white, letterSpacing: 1.5)),
                ),
              ),
            ]),
          ]),
        ),
      ],
    );
  }

  Widget _genderBtn(String label, String value, {required bool isLeft}) {
    final active = _gender == value;
    // Inner radius = outer(35) - border(3) = 32
    final radius = isLeft
      ? const BorderRadius.only(topLeft: Radius.circular(32), bottomLeft: Radius.circular(32))
      : const BorderRadius.only(topRight: Radius.circular(32), bottomRight: Radius.circular(32));
    return GestureDetector(
      onTap: () => _switchGender(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 14),
        decoration: BoxDecoration(
          color: active ? _genderActive : CerebroTheme.cream,
          borderRadius: radius,
        ),
        child: Text(label, style: GoogleFonts.nunito(
          fontSize: 20, fontWeight: FontWeight.w600,
          color: active ? Colors.white : const Color(0xFF666666))),
      ),
    );
  }

  // AVATAR PREVIEW — EXACT .NET RENDERING
  // Uses native image sizes + Transform.scale (like CSS)
  // CSS: .avatarContainer { transform: scale(0.6) }
  //      .avatarLayer { top:50%; left:50%;
  //        transform: translate(calc(-50%+X),calc(-50%+Y)) scale(S) }
  // Flutter: OverflowBox(center) → translate(dx,dy) → scale(s)
  //   where s = layerScale * containerScale
  //   and dx/dy = X/Y * containerScale
  Widget _buildAvatar(double pvSize) {
    final containerScale = pvSize / 1000.0;
    final layers = <_Layer>[];

    // Base → eyes → nose → mouth (use defaults from AvatarPositions)
    final basePos = AvatarPositions.defaults['base']!;
    layers.add(_Layer('assets/avatar/$_gender/base/Base${_baseIndex.toString().padLeft(2, '0')}.png', basePos.x, basePos.y, basePos.scale));
    final eyePos = AvatarPositions.defaults['eyes']!;
    layers.add(_Layer('assets/avatar/$_gender/eyes/eyes${_eyesIndex.toString().padLeft(2, '0')}.png', eyePos.x, eyePos.y, eyePos.scale));
    final nosePos = AvatarPositions.defaults['nose']!;
    layers.add(_Layer('assets/avatar/$_gender/nose/nose${_noseIndex.toString().padLeft(2, '0')}.png', nosePos.x, nosePos.y, nosePos.scale));
    final mouthPos = AvatarPositions.defaults['mouth']!;
    layers.add(_Layer('assets/avatar/$_gender/mouth/mouth${_mouthIndex.toString().padLeft(2, '0')}.png', mouthPos.x, mouthPos.y, mouthPos.scale));

    // Clothes — use helper to route store colors to Store_items/
    final clothesPos = AvatarPositions.getClothesPosition(_gender, _clothesStyle);
    layers.add(_Layer(_clothesAssetPath(_clothesStyle, _clothesColor), clothesPos.x, clothesPos.y, clothesPos.scale));

    // Hair
    final hairPos = AvatarPositions.getHairPosition(_gender, _hairStyle);
    layers.add(_Layer('assets/avatar/$_gender/hair/$_hairStyle-$_hairColor.png', hairPos.x, hairPos.y, hairPos.scale));

    // Facial hair
    if (_facialHairStyle != null && _gender == 'male') {
      final p = AvatarPositions.getFacialHairPosition(_facialHairStyle!);
      layers.add(_Layer('assets/avatar/male/facialhair/$_facialHairStyle.png', p.x, p.y, p.scale));
    }
    // Glasses
    if (_glassesStyle != null) {
      final p = AvatarPositions.getGlassesPosition(_glassesStyle!);
      layers.add(_Layer('assets/avatar/$_gender/accessories/$_glassesStyle.png', p.x, p.y, p.scale));
    }
    // Headwear
    if (_headwearStyle != null && _headwearColor != null) {
      final p = AvatarPositions.getHeadwearPosition(_headwearStyle!);
      layers.add(_Layer('assets/avatar/$_gender/accessories/$_headwearStyle-$_headwearColor.png', p.x, p.y, p.scale));
    }
    // Neckwear
    if (_neckwearStyle != null && _neckwearColor != null) {
      final p = AvatarPositions.getNeckwearPosition(_neckwearStyle!);
      layers.add(_Layer('assets/avatar/$_gender/accessories/$_neckwearStyle-$_neckwearColor.png', p.x, p.y, p.scale));
    }
    // Extras
    if (_extrasStyle != null && _extrasColor != null) {
      final p = AvatarPositions.getExtrasPosition(_extrasStyle!);
      layers.add(_Layer('assets/avatar/$_gender/accessories/$_extrasStyle-$_extrasColor.png', p.x, p.y, p.scale));
    }

    return Stack(
      clipBehavior: Clip.hardEdge,
      children: [
        SizedBox(width: pvSize, height: pvSize),
        ...layers.map((l) {
          // Combined scale = layerScale × containerScale
          // Combined offset = (X, Y) × containerScale
          final s = l.scale * containerScale;
          final dx = l.x * containerScale;
          final dy = l.y * containerScale;
          return Positioned.fill(
            child: OverflowBox(
              alignment: Alignment.center,
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              child: Transform.translate(
                offset: Offset(dx, dy),
                child: Transform.scale(
                  scale: s,
                  child: Image.asset(l.src,
                    filterQuality: FilterQuality.medium,
                    errorBuilder: (_, __, ___) => const SizedBox.shrink()),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildColorPill() {
    return Row(mainAxisSize: MainAxisSize.min, children: _buildDots());
  }

  List<Widget> _buildDots() {
    if (_currentCategory == 'hair') {
      return _hairColors.map((c) => _dot(c, _hairColor == c, () => setState(() => _hairColor = c), locked: _isHairColorLocked(c))).toList();
    }
    if (_currentCategory == 'clothes') {
      final cols = _gender == 'male' ? _maleClothesColors : _femaleClothesColors;
      return cols.map((c) => _dot(c, _clothesColor == c, () => setState(() => _clothesColor = c))).toList();
    }
    if (_currentCategory == 'accessories') {
      return _accessoryColors.map((c) {
        final sel = (_headwearStyle != null && _headwearColor == c) ||
            (_neckwearStyle != null && _neckwearColor == c) ||
            (_extrasStyle != null && _extrasColor == c);
        return _dot(c, sel, () => setState(() {
          if (_headwearStyle != null) _headwearColor = c;
          if (_neckwearStyle != null) _neckwearColor = c;
          if (_extrasStyle != null) _extrasColor = c;
        }));
      }).toList();
    }
    return [];
  }

  Widget _dot(String key, bool sel, VoidCallback onTap, {bool locked = false}) {
    final color = _colorMap[key] ?? Colors.grey;
    return GestureDetector(
      onTap: locked ? () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Unlock this color from the Store!',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF6E5848),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      } : onTap,
      child: Container(
        width: 44, height: 44,
        margin: const EdgeInsets.symmetric(horizontal: 5),
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: 44, height: 44,
              decoration: BoxDecoration(
                color: color, shape: BoxShape.circle,
                border: Border.all(color: CerebroTheme.outline, width: 3),
              ),
            ),
            if (locked)
              Positioned(
                right: -3, top: -3,
                child: Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8A7060), shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                  child: const Icon(Icons.lock_rounded, size: 11, color: Colors.white),
                ),
              )
            else if (sel)
              Positioned(
                right: -3, top: -3,
                child: Container(
                  width: 20, height: 20,
                  decoration: BoxDecoration(
                    color: _okGreen, shape: BoxShape.circle,
                    border: Border.all(color: CerebroTheme.outline, width: 2),
                  ),
                  child: const Icon(Icons.check, size: 12, color: Colors.white),
                ),
              ),
          ],
        ),
      ),
    );
  }

  // OPTIONS GRID
  Widget _buildOptions(double panelW) {
    switch (_currentCategory) {
      case 'skin':
        return _grid(List.generate(3, (i) {
          final idx = i + 1;
          return _optBox(
            selected: _baseIndex == idx,
            onTap: () => setState(() => _baseIndex = idx),
            child: Image.asset('assets/avatar/$_gender/base/Base${idx.toString().padLeft(2, '0')}.png',
              fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image)),
          );
        }));
      case 'eyes':
        return _grid(List.generate(42, (i) {
          final idx = i + 1;
          final eyeLocked = _isEyeLocked(idx);
          return _optBox(
            selected: _eyesIndex == idx,
            locked: eyeLocked,
            onTap: () => setState(() => _eyesIndex = idx),
            child: Image.asset('assets/avatar/$_gender/eyes/eyes${idx.toString().padLeft(2, '0')}.png',
              fit: BoxFit.contain, errorBuilder: (_, __, ___) => Text('$idx', style: GoogleFonts.nunito(fontWeight: FontWeight.w800))),
          );
        }));
      case 'nose':
        return _grid(List.generate(10, (i) {
          final idx = i + 1;
          return _optBox(
            selected: _noseIndex == idx,
            onTap: () => setState(() => _noseIndex = idx),
            child: Image.asset('assets/avatar/$_gender/nose/nose${idx.toString().padLeft(2, '0')}.png',
              fit: BoxFit.contain, errorBuilder: (_, __, ___) => Text('$idx', style: GoogleFonts.nunito(fontWeight: FontWeight.w800))),
          );
        }));
      case 'mouth':
        return _grid(List.generate(10, (i) {
          final idx = i + 1;
          return _optBox(
            selected: _mouthIndex == idx,
            onTap: () => setState(() => _mouthIndex = idx),
            child: Image.asset('assets/avatar/$_gender/mouth/mouth${idx.toString().padLeft(2, '0')}.png',
              fit: BoxFit.contain, errorBuilder: (_, __, ___) => Text('$idx', style: GoogleFonts.nunito(fontWeight: FontWeight.w800))),
          );
        }));
      case 'hair':
        final styles = _gender == 'male' ? _maleHairStyles : _femaleHairStyles;
        return _grid(styles.map((s) => _optBox(
          selected: _hairStyle == s,
          onTap: () => setState(() => _hairStyle = s),
          child: Image.asset('assets/avatar/$_gender/hair/$s-$_hairColor.png',
            fit: BoxFit.contain, errorBuilder: (_, __, ___) => Text(s.split('-').first, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700))),
        )).toList());
      case 'clothes':
        final styles = _gender == 'male' ? _maleClothesStyles : _femaleClothesStyles;
        return _grid(styles.map((s) {
          // Lock if this is a store color AND user hasn't bought this specific combo
          final isLocked = _isClothesItemLocked(s, _clothesColor);
          return _optBox(
            selected: _clothesStyle == s,
            locked: isLocked,
            onTap: () => setState(() => _clothesStyle = s),
            child: Image.asset(_clothesAssetPath(s, _clothesColor),
              fit: BoxFit.contain, errorBuilder: (_, __, ___) => Text(s.split('-').first, style: GoogleFonts.nunito(fontSize: 10, fontWeight: FontWeight.w700))),
          );
        }).toList());
      case 'facialHair':
        return _grid([
          _optBox(selected: _facialHairStyle == null, onTap: () => setState(() => _facialHairStyle = null),
            child: Text('None', style: GoogleFonts.nunito(fontWeight: FontWeight.w800, fontSize: 12))),
          for (int i = 1; i <= 20; i++)
            _optBox(selected: _facialHairStyle == 'style$i', onTap: () => setState(() => _facialHairStyle = 'style$i'),
              child: Image.asset('assets/avatar/male/facialhair/style$i.png',
                fit: BoxFit.contain, errorBuilder: (_, __, ___) => Text('$i', style: GoogleFonts.nunito(fontWeight: FontWeight.w800)))),
        ]);
      case 'accessories':
        return _buildAccessories();
      default:
        return const SizedBox.shrink();
    }
  }

  Widget _buildAccessories() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Glasses
      _grid([
        _optBox(selected: _glassesStyle == null, onTap: () => setState(() => _glassesStyle = null),
          child: Text('None', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 11))),
        for (final g in _glassesOptions)
          _optBox(selected: _glassesStyle == g, locked: _isGlassesLocked(g),
            onTap: () => setState(() => _glassesStyle = g),
            child: Image.asset('assets/avatar/$_gender/accessories/$g.png',
              fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.visibility, size: 20))),
      ]),
      const SizedBox(height: 8),
      // Headwear
      _grid([
        _optBox(selected: _headwearStyle == null, onTap: () => setState(() { _headwearStyle = null; _headwearColor = null; }),
          child: Text('None', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 11))),
        for (final h in _headwearOptions)
          _optBox(selected: _headwearStyle == h, locked: _isHeadwearLocked(h),
            onTap: () => setState(() { _headwearStyle = h; _headwearColor ??= 'red'; }),
            child: Image.asset('assets/avatar/$_gender/accessories/$h-red.png',
              fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.hdr_strong, size: 20))),
      ]),
      const SizedBox(height: 8),
      // Neckwear
      _grid([
        _optBox(selected: _neckwearStyle == null, onTap: () => setState(() { _neckwearStyle = null; _neckwearColor = null; }),
          child: Text('None', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 11))),
        for (final n in _neckwearOptions)
          _optBox(selected: _neckwearStyle == n, locked: _isNeckwearLocked(n),
            onTap: () => setState(() { _neckwearStyle = n; _neckwearColor ??= 'red'; }),
            child: Image.asset('assets/avatar/$_gender/accessories/$n-red.png',
              fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.tab, size: 20))),
      ]),
      const SizedBox(height: 8),
      // Extras (female only in .NET)
      if (_gender == 'female')
        _grid([
          _optBox(selected: _extrasStyle == null, onTap: () => setState(() { _extrasStyle = null; _extrasColor = null; }),
            child: Text('None', style: GoogleFonts.nunito(fontWeight: FontWeight.w700, fontSize: 11))),
          for (final e in _extrasOptions)
            _optBox(selected: _extrasStyle == e, locked: _isExtrasLocked(e),
              onTap: () => setState(() { _extrasStyle = e; _extrasColor ??= 'red'; }),
              child: Image.asset('assets/avatar/$_gender/accessories/$e-red.png',
                fit: BoxFit.contain, errorBuilder: (_, __, ___) => const Icon(Icons.star, size: 20))),
        ]),
    ]);
  }

  Widget _grid(List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Wrap(spacing: 10, runSpacing: 10, children: children),
    );
  }

  Widget _optBox({required bool selected, required VoidCallback onTap, required Widget child, bool locked = false}) {
    final isGlowing = selected && _showUnlockGlow;
    return GestureDetector(
      onTap: locked ? () {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Buy this item from the Store first!',
            style: GoogleFonts.nunito(fontWeight: FontWeight.w600)),
          backgroundColor: const Color(0xFF6E5848),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
        ));
      } : onTap,
      child: AnimatedScale(
        scale: selected ? 1.05 : 1.0,
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOutBack,
        child: SizedBox(
          width: 106, height: 106,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                left: 4, top: 4, right: 4, bottom: 4,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 600),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: selected ? Colors.white : CerebroTheme.cream,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isGlowing ? const Color(0xFFF8E080) : CerebroTheme.outline,
                      width: selected ? 3 : 2.5,
                    ),
                    boxShadow: isGlowing
                      ? [
                          BoxShadow(color: const Color(0xFFF8E080).withOpacity(0.6), spreadRadius: 6, blurRadius: 12),
                          BoxShadow(color: const Color(0xFFF8E080).withOpacity(0.3), spreadRadius: 12, blurRadius: 20),
                        ]
                      : selected
                        ? [BoxShadow(color: _genderActive.withOpacity(0.35), spreadRadius: 3, blurRadius: 0)]
                        : [BoxShadow(color: Colors.black.withOpacity(0.08), offset: const Offset(2, 2), blurRadius: 0)],
                  ),
                  child: Center(child: child),
                ),
              ),
              if (locked)
                Positioned(top: 0, right: 0,
                  child: Container(width: 26, height: 26,
                    decoration: BoxDecoration(
                      color: const Color(0xFF8A7060),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: const Icon(Icons.lock_rounded, size: 14, color: Colors.white),
                  ),
                ),
              if (selected && !locked)
                Positioned(top: 0, right: 0,
                  child: Container(width: 26, height: 26,
                    decoration: BoxDecoration(color: _genderActive, shape: BoxShape.circle,
                      border: Border.all(color: CerebroTheme.outline, width: 2.5)),
                    child: const Icon(Icons.check, size: 14, color: Colors.white))),
            ],
          ),
        ),
      ),
    );
  }
}

class _Tab { final String key; final IconData icon; _Tab(this.key, this.icon); }
class _Layer { final String src; final double x, y, scale; _Layer(this.src, this.x, this.y, this.scale); }

class _PawPrintPainter extends CustomPainter {
  final double width, height;
  _PawPrintPainter(this.width, this.height);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;

    // Grid spacing — like a dotted notebook
    const spacing = 62.0;
    // Slight offset every other row for organic feel
    const rowShift = 31.0;
    // Tiny paw radius (like a dot but shaped as a paw)
    const pawR = 4.0;

    // Use a seeded pattern for subtle rotation variety
    int idx = 0;
    for (double y = 20; y < size.height; y += spacing) {
      final isOddRow = ((y / spacing).floor() % 2) == 1;
      final xOffset = isOddRow ? rowShift : 0.0;
      for (double x = xOffset + 20; x < size.width; x += spacing) {
        // Vary opacity slightly per paw for organic look
        final opFactor = 0.10 + (idx % 5) * 0.02;
        paint.color = const Color(0xFFF4A9C1).withOpacity(opFactor);
        // Tiny rotation per paw — alternate angles
        final angle = (idx % 4) * 0.35 - 0.35;
        _drawTinyPaw(canvas, paint, x, y, pawR, angle);
        idx++;
      }
    }
  }

  void _drawTinyPaw(Canvas canvas, Paint paint, double cx, double cy, double r, double angle) {
    canvas.save();
    canvas.translate(cx, cy);
    canvas.rotate(angle);
    // Main pad — small circle
    canvas.drawCircle(Offset.zero, r, paint);
    // Four tiny toe beans — arranged in an arc above the main pad
    final toeR = r * 0.48;
    final spread = r * 0.85;
    canvas.drawCircle(Offset(-spread * 1.1, -r * 1.1), toeR, paint);
    canvas.drawCircle(Offset(-spread * 0.35, -r * 1.45), toeR, paint);
    canvas.drawCircle(Offset(spread * 0.35, -r * 1.45), toeR, paint);
    canvas.drawCircle(Offset(spread * 1.1, -r * 1.1), toeR, paint);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _AnimatedCloseBtn extends StatefulWidget {
  final VoidCallback onTap;
  const _AnimatedCloseBtn({required this.onTap});
  @override
  State<_AnimatedCloseBtn> createState() => _AnimatedCloseBtnState();
}

class _AnimatedCloseBtnState extends State<_AnimatedCloseBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scaleAnim;
  late final Animation<double> _rotateAnim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
    _scaleAnim = Tween<double>(begin: 1.0, end: 0.82).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
    _rotateAnim = Tween<double>(begin: 0.0, end: 0.15).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _onTapDown(_) => _ctrl.forward();
  void _onTapUp(_) {
    _ctrl.reverse().then((_) => widget.onTap());
  }

  void _onTapCancel() => _ctrl.reverse();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: _onTapDown,
      onTapUp: _onTapUp,
      onTapCancel: _onTapCancel,
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) {
          return Transform.scale(
            scale: _scaleAnim.value,
            child: Transform.rotate(
              angle: _rotateAnim.value,
              child: child,
            ),
          );
        },
        child: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(
            color: _panelPink,
            shape: BoxShape.circle,
            border: Border.all(color: CerebroTheme.outline, width: 3),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.18),
                offset: const Offset(3, 3),
                blurRadius: 0,
              ),
              BoxShadow(
                color: Colors.black.withOpacity(0.06),
                offset: const Offset(5, 5),
                blurRadius: 4,
              ),
            ],
          ),
          child: const Icon(Icons.close_rounded, color: Colors.white, size: 24),
        ),
      ),
    );
  }
}

class _BounceBtn extends StatefulWidget {
  final VoidCallback onTap;
  final Widget child;
  const _BounceBtn({required this.onTap, required this.child});
  @override
  State<_BounceBtn> createState() => _BounceBtnState();
}

class _BounceBtnState extends State<_BounceBtn>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 120));
    _scale = Tween<double>(begin: 1.0, end: 0.88).animate(
      CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut));
  }

  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _ctrl.forward(),
      onTapUp: (_) => _ctrl.reverse().then((_) => widget.onTap()),
      onTapCancel: () => _ctrl.reverse(),
      child: AnimatedBuilder(
        animation: _scale,
        builder: (context, child) => Transform.scale(scale: _scale.value, child: child),
        child: widget.child,
      ),
    );
  }
}
