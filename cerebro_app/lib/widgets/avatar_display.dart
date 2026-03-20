/// EXACT port of .NET AvatarDisplay.razor rendering:
///   Canvas: 600×550, scale(Size/280), anchor: bottom center
///   Each layer: centered, translate(X,Y), scale(S) on NATIVE image size
///   Shows "chest up" view — ideal for dashboard, profile, navbar, etc.

import 'package:flutter/material.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:cerebro_app/models/avatar_config.dart';
import 'package:cerebro_app/models/avatar_positions.dart';

class AvatarDisplay extends StatelessWidget {
  final AvatarConfig config;
  final double size;
  final bool showBorder;
  final Color? backgroundColor;

  const AvatarDisplay({
    super.key,
    required this.config,
    this.size = 200,
    this.showBorder = false,
    this.backgroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // .NET AvatarDisplay.razor:
    //   inner div: 600×550, transform-origin: bottom center,
    //   transform: translateX(-50%) scale(Size / 280.0)
    //   bottom: -(Size * 0.4)
    final dScale = size / 280.0;

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: backgroundColor ?? CerebroTheme.cream,
        borderRadius: BorderRadius.circular(size * 0.2),
        border: showBorder
            ? Border.all(color: CerebroTheme.outline, width: 4)
            : null,
        boxShadow: showBorder
            ? [CerebroTheme.shadow3D]
            : [
                BoxShadow(
                  color: CerebroTheme.pinkPop.withOpacity(0.15),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      clipBehavior: Clip.hardEdge,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          // .NET: bottom: -(Size * 0.4), left: 50%, translateX(-50%)
          //       width: 600, height: 550
          //       transform-origin: bottom center, scale(Size/280)
          //
          // After scaling from bottom-center by dScale:
          //   scaled width = 600 * dScale, scaled height = 550 * dScale
          //   bottom of canvas = size + size * 0.4 = size * 1.4 from top
          //   top of canvas = size * 1.4 - 550 * dScale
          //   left = (size - 600 * dScale) / 2
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
    );
  }

  List<Widget> _buildLayers(double dScale) {
    final layers = <Widget>[];

    void addLayer(String path, LayerPosition pos) {
      // .NET: position: absolute; top: 50%; left: 50%;
      //       transform: translate(-50%, -50%) translate(X, Y) scale(S);
      // Flutter: OverflowBox(center) → translate(dx,dy) → scale(s)
      //   Combined: s = layerScale × dScale
      //             dx = X × dScale, dy = Y × dScale
      final s = pos.scale * dScale;
      final dx = pos.x * dScale;
      final dy = pos.y * dScale;

      layers.add(
        Positioned.fill(
          child: OverflowBox(
            alignment: Alignment.center,
            maxWidth: double.infinity,
            maxHeight: double.infinity,
            child: Transform.translate(
              offset: Offset(dx, dy),
              child: Transform.scale(
                scale: s,
                child: Image.asset(
                  path,
                  filterQuality: FilterQuality.medium,
                  errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                ),
              ),
            ),
          ),
        ),
      );
    }

    // Base
    addLayer(config.basePath, AvatarPositions.defaults['base']!);
    // Eyes
    addLayer(config.eyesPath, AvatarPositions.defaults['eyes']!);
    // Nose
    addLayer(config.nosePath, AvatarPositions.defaults['nose']!);
    // Mouth
    addLayer(config.mouthPath, AvatarPositions.defaults['mouth']!);

    // Clothes — extract style from 'style-color' format
    final clothesParts = config.clothes.split('-');
    String clothesStyle;
    if (clothesParts.length >= 2) {
      clothesStyle = clothesParts.sublist(0, clothesParts.length - 1).join('-');
    } else {
      clothesStyle = config.clothes;
    }
    addLayer(config.clothesPath,
        AvatarPositions.getClothesPosition(config.gender, clothesStyle));

    // Hair
    addLayer(config.hairPath,
        AvatarPositions.getHairPosition(config.gender, config.hairStyle));

    // Facial hair
    if (config.facialHairPath != null && config.facialHair != null) {
      addLayer(config.facialHairPath!,
          AvatarPositions.getFacialHairPosition(config.facialHair!));
    }
    // Glasses
    if (config.glassesPath != null && config.glasses != null) {
      addLayer(config.glassesPath!,
          AvatarPositions.getGlassesPosition(config.glasses!));
    }
    // Headwear
    if (config.headwearPath != null && config.headwear != null) {
      final hwParts = config.headwear!.split('-');
      final hwStyle = hwParts.length >= 2
          ? hwParts.sublist(0, hwParts.length - 1).join('-')
          : config.headwear!;
      addLayer(config.headwearPath!,
          AvatarPositions.getHeadwearPosition(hwStyle));
    }
    // Neckwear
    if (config.neckwearPath != null && config.neckwear != null) {
      final nwParts = config.neckwear!.split('-');
      final nwStyle = nwParts.length >= 2
          ? nwParts.sublist(0, nwParts.length - 1).join('-')
          : config.neckwear!;
      addLayer(config.neckwearPath!,
          AvatarPositions.getNeckwearPosition(nwStyle));
    }
    // Extras
    if (config.extrasPath != null && config.extras != null) {
      final exParts = config.extras!.split('-');
      final exStyle = exParts.length >= 2
          ? exParts.sublist(0, exParts.length - 1).join('-')
          : config.extras!;
      addLayer(config.extrasPath!,
          AvatarPositions.getExtrasPosition(exStyle));
    }

    return layers;
  }
}
