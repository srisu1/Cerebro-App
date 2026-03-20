/// Renders a HEAD-ONLY mood sticker.
///
/// Approach (matching .NET SVG rendering):
///  1. Internal canvas of 500x500 (large enough for hair overflow)
///  2. Each layer: sized to (scale * canvas), centered + offset
///  3. Image fits within that box using BoxFit.contain
///  4. Stack clips to canvas bounds (Clip.hardEdge)
///  5. FittedBox scales everything to display size

import 'package:flutter/material.dart';
import 'package:cerebro_app/models/avatar_config.dart';
import 'package:cerebro_app/models/expression_state.dart';
import 'package:cerebro_app/models/mood_sticker_positions.dart';

class MoodSticker extends StatelessWidget {
  final AvatarConfig config;
  final String mood;
  final double size;

  /// Zoom factor for the face. 1.0 = default (face fills ~75% of box).
  /// Use 1.3–1.4 to make the face fill the box edge-to-edge.
  final double zoom;

  const MoodSticker({
    super.key,
    required this.config,
    required this.mood,
    this.size = 80,
    this.zoom = 1.0,
  });

  static const double _canvas = 500.0;
  static const double _yCenter = 80.0;

  @override
  Widget build(BuildContext context) {
    final inner = FittedBox(
      fit: BoxFit.contain,
      clipBehavior: Clip.hardEdge,
      child: SizedBox(
        width: _canvas,
        height: _canvas,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: _buildLayers(),
        ),
      ),
    );

    if (zoom != 1.0) {
      // Zoom into the face — clips the empty margins around the head
      return SizedBox(
        width: size,
        height: size,
        child: ClipRect(
          child: Transform.scale(
            scale: zoom,
            child: inner,
          ),
        ),
      );
    }

    return SizedBox(
      width: size,
      height: size,
      child: inner,
    );
  }

  List<Widget> _buildLayers() {
    final layers = <Widget>[];
    final gender = config.gender;

    void addLayer(String path, double x, double y, double scale) {
      final layerSize = scale * _canvas;
      layers.add(
        Positioned(
          left: (_canvas - layerSize) / 2 + x,
          top: (_canvas - layerSize) / 2 + y + _yCenter,
          width: layerSize,
          height: layerSize,
          child: Image.asset(
            path,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      );
    }

    final skinNum = config.baseSkin.replaceAll('Base', '');
    final headPath =
        'assets/avatar/$gender/justheadbase/justheadbase$skinNum.png';
    final basePos = MoodStickerPositions.justHeadBase;
    addLayer(headPath, basePos.x, basePos.y, basePos.scale);

    final exprState = ExpressionEngine.fromMood(mood);
    final hasReal = ExpressionEngine.hasAssets(exprState);
    final eyesPos = MoodStickerPositions.eyesPosition(gender);
    final nosePos = MoodStickerPositions.nosePosition(gender);
    final mouthPos = MoodStickerPositions.mouthPosition(gender);

    if (hasReal) {
      addLayer('assets/avatar/expressions/$mood/eyes.png',
          eyesPos.x, eyesPos.y, eyesPos.scale);
      addLayer('assets/avatar/expressions/$mood/nose.png',
          nosePos.x, nosePos.y, nosePos.scale);
      addLayer('assets/avatar/expressions/$mood/mouth.png',
          mouthPos.x, mouthPos.y, mouthPos.scale);
    } else {
      addLayer(config.eyesPath, eyesPos.x, eyesPos.y, eyesPos.scale);
      addLayer(config.nosePath, nosePos.x, nosePos.y, nosePos.scale);
      addLayer(config.mouthPath, mouthPos.x, mouthPos.y, mouthPos.scale);
    }

    final hairPos =
        MoodStickerPositions.getHairPosition(gender, config.hairStyle);
    addLayer(config.hairPath, hairPos.x, hairPos.y, hairPos.scale);

    if (config.facialHair != null) {
      final fhPos =
          MoodStickerPositions.getFacialHairPosition(config.facialHair);
      if (fhPos != null) {
        addLayer(config.facialHairPath!, fhPos.x, fhPos.y, fhPos.scale);
      }
    }

    return layers;
  }
}
