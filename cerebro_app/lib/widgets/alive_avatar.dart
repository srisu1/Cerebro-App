/// Avatar that feels alive with:
///  • Gentle breathing (float up/down)
///  • Periodic blinking (opacity fade on eyes — no asset needed)
///  • Expression overlays based on mood / time / activity
///  • Time-based outfit changes
///
/// Blink approach: Instead of loading blink/eyes.png (which may not exist),
/// we FADE OUT the eyes layer briefly to simulate a blink. Much more reliable.

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:cerebro_app/models/avatar_config.dart';
import 'package:cerebro_app/models/avatar_positions.dart';
import 'package:cerebro_app/models/expression_state.dart';

class AliveAvatar extends StatefulWidget {
  final AvatarConfig config;
  final double size;
  final ExpressionState expression;
  final bool autoOutfit;
  final Color? backgroundColor;

  /// When true, only renders head/bust (no breathing, smaller).
  /// Used for status bar mini avatar.
  final bool mini;

  const AliveAvatar({
    super.key,
    required this.config,
    this.size = 240,
    this.expression = ExpressionState.neutral,
    this.autoOutfit = true,
    this.backgroundColor,
    this.mini = false,
  });

  @override
  State<AliveAvatar> createState() => _AliveAvatarState();
}

class _AliveAvatarState extends State<AliveAvatar>
    with SingleTickerProviderStateMixin {
  late AnimationController _breatheCtrl;
  late Animation<double> _breatheAnim;

  Timer? _blinkTimer;
  double _eyeOpacity = 1.0;

  @override
  void initState() {
    super.initState();

    _breatheCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    )..repeat(reverse: true);

    final amplitude = widget.mini ? 0.0 : 5.0;
    _breatheAnim = Tween<double>(begin: -amplitude, end: amplitude).animate(
      CurvedAnimation(parent: _breatheCtrl, curve: Curves.easeInOut),
    );

    if (!widget.mini) _scheduleBlink();
  }

  @override
  void dispose() {
    _breatheCtrl.dispose();
    _blinkTimer?.cancel();
    super.dispose();
  }

  void _scheduleBlink() {
    final ms = 2500 + (DateTime.now().microsecond % 3000);
    _blinkTimer = Timer(Duration(milliseconds: ms), () {
      if (!mounted) return;
      // Close eyes
      setState(() => _eyeOpacity = 0.0);
      // Open eyes after 150ms
      Future.delayed(const Duration(milliseconds: 150), () {
        if (mounted) setState(() => _eyeOpacity = 1.0);
        _scheduleBlink();
      });
    });
  }

  String _getClothesPath() {
    if (!widget.autoOutfit) return widget.config.clothesPath;
    final parts = widget.config.clothes.split('-');
    final color = parts.isNotEmpty ? parts.last : 'blue';
    final style = ExpressionEngine.clothesForTimeOfDay(widget.config.gender);
    // Store-exclusive colors use Store_items path
    const storeColors = {'babypink', 'brown', 'olive'};
    if (storeColors.contains(color)) {
      final fileName = style == 'off-shoulder' ? 'offshoulder-$color' : '$style-$color';
      return 'assets/store/Store_items/$fileName.png';
    }
    return 'assets/avatar/${widget.config.gender}/clothes/$style-$color.png';
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final dScale = size / 280.0;

    return AnimatedBuilder(
      animation: _breatheAnim,
      builder: (_, child) => Transform.translate(
        offset: Offset(0, _breatheAnim.value),
        child: child,
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: widget.backgroundColor ?? Colors.transparent,
          borderRadius: BorderRadius.circular(size * 0.15),
        ),
        clipBehavior: widget.backgroundColor != null ? Clip.hardEdge : Clip.none,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: (size - 600 * dScale) / 2,
              top: size * 1.4 - 550 * dScale,
              width: 600 * dScale,
              height: 550 * dScale,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(width: 600 * dScale, height: 550 * dScale),
                  ..._buildLayers(dScale),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildLayers(double dScale) {
    final layers = <Widget>[];
    final config = widget.config;
    final expr = widget.expression;

    void addLayer(String path, LayerPosition pos, {double opacity = 1.0}) {
      final s = pos.scale * dScale;
      final dx = pos.x * dScale;
      final dy = pos.y * dScale;

      Widget img = Image.asset(
        path,
        filterQuality: FilterQuality.medium,
        errorBuilder: (_, __, ___) => const SizedBox.shrink(),
      );

      if (opacity < 1.0) {
        img = Opacity(opacity: opacity, child: img);
      }

      layers.add(
        Positioned.fill(
          child: OverflowBox(
            alignment: Alignment.center,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: Transform.translate(
              offset: Offset(dx, dy),
              child: Transform.scale(scale: s, child: img),
            ),
          ),
        ),
      );
    }

    // 1. Base skin
    addLayer(config.basePath, AvatarPositions.defaults['base']!);

    // 2. Eyes — use expression overlay ONLY if real assets exist
    //    Apply blink opacity (fades eyes out briefly)
    final useExprOverlay = expr != ExpressionState.neutral
        && expr != ExpressionState.blink
        && ExpressionEngine.hasAssets(expr);

    if (useExprOverlay) {
      addLayer(ExpressionEngine.eyesPath(expr)!,
          AvatarPositions.defaults['eyes']!, opacity: _eyeOpacity);
    } else {
      addLayer(config.eyesPath, AvatarPositions.defaults['eyes']!,
          opacity: _eyeOpacity);
    }

    // 3. Nose
    if (useExprOverlay) {
      addLayer(ExpressionEngine.nosePath(expr)!,
          AvatarPositions.defaults['nose']!);
    } else {
      addLayer(config.nosePath, AvatarPositions.defaults['nose']!);
    }

    // 4. Mouth
    if (useExprOverlay) {
      addLayer(ExpressionEngine.mouthPath(expr)!,
          AvatarPositions.defaults['mouth']!);
    } else {
      addLayer(config.mouthPath, AvatarPositions.defaults['mouth']!);
    }

    // 5. Clothes
    final clothesParts = config.clothes.split('-');
    final clothesStyle = clothesParts.length >= 2
        ? clothesParts.sublist(0, clothesParts.length - 1).join('-')
        : config.clothes;
    addLayer(
      _getClothesPath(),
      AvatarPositions.getClothesPosition(config.gender, clothesStyle),
    );

    // 6. Hair
    addLayer(
      config.hairPath,
      AvatarPositions.getHairPosition(config.gender, config.hairStyle),
    );

    // 7. Facial hair
    if (config.facialHairPath != null && config.facialHair != null) {
      addLayer(config.facialHairPath!,
          AvatarPositions.getFacialHairPosition(config.facialHair!));
    }

    // 8. Glasses
    if (config.glassesPath != null && config.glasses != null) {
      addLayer(config.glassesPath!,
          AvatarPositions.getGlassesPosition(config.glasses!));
    }

    // 9. Headwear
    if (config.headwearPath != null && config.headwear != null) {
      final hw = config.headwear!.split('-');
      final hwStyle = hw.length >= 2 ? hw.sublist(0, hw.length - 1).join('-') : config.headwear!;
      addLayer(config.headwearPath!, AvatarPositions.getHeadwearPosition(hwStyle));
    }

    // 10. Neckwear
    if (config.neckwearPath != null && config.neckwear != null) {
      final nw = config.neckwear!.split('-');
      final nwStyle = nw.length >= 2 ? nw.sublist(0, nw.length - 1).join('-') : config.neckwear!;
      addLayer(config.neckwearPath!, AvatarPositions.getNeckwearPosition(nwStyle));
    }

    // 11. Extras
    if (config.extrasPath != null && config.extras != null) {
      final ex = config.extras!.split('-');
      final exStyle = ex.length >= 2 ? ex.sublist(0, ex.length - 1).join('-') : config.extras!;
      addLayer(config.extrasPath!, AvatarPositions.getExtrasPosition(exStyle));
    }

    return layers;
  }
}
