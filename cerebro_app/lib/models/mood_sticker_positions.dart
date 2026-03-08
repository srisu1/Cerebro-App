import 'package:cerebro_app/models/avatar_positions.dart';

class MoodStickerPositions {
  MoodStickerPositions._();

  // base head position
  static const LayerPosition justHeadBase = LayerPosition(0, 0, 0.75);

  // expression positions (gender-specific)
  // Eyes at 0.30, Nose at 0.10, Mouth at 0.12 — MATCHES .cs original
  static LayerPosition eyesPosition(String gender) =>
      gender.toLowerCase() == 'male'
          ? const LayerPosition(0, -26, 0.30)
          : const LayerPosition(0, -20, 0.30);

  static LayerPosition nosePosition(String gender) =>
      gender.toLowerCase() == 'male'
          ? const LayerPosition(0, -12, 0.10)
          : const LayerPosition(0, -6, 0.10);

  static LayerPosition mouthPosition(String gender) =>
      gender.toLowerCase() == 'male'
          ? const LayerPosition(1, 38, 0.12)
          : const LayerPosition(1, 38, 0.12);

  // hair positions (female)
  static const Map<String, LayerPosition> hairPositionsFemale = {
    'medium-curl':  LayerPosition(-8, -15, 0.66),
    'bangs':        LayerPosition(1, -11, 0.61),
    'to-the-side':  LayerPosition(-5, -11, 0.60),
    'boys-cut':     LayerPosition(-3, -80, 0.71),
    'granny-hair':  LayerPosition(-1, -75, 0.67),
    'anime-hair':   LayerPosition(-9, -18, 0.66),
    'bangs-short':  LayerPosition(-1, -42, 0.61),
    'side-pony':    LayerPosition(-1, -24, 0.59),
    'pigtails':     LayerPosition(-6, -74, 0.80),
    'bun':          LayerPosition(-12, -81, 0.62),
  };

  // hair positions (male)
  static const Map<String, LayerPosition> hairPositionsMale = {
    'curly-short':    LayerPosition(1, -90, 0.65),
    'straight-short': LayerPosition(4, -86, 0.63),
    'ceo-hair':       LayerPosition(7, -88, 0.63),
    'flat-hair':      LayerPosition(0, -78, 0.55),
    '90s-hair':       LayerPosition(0, -78, 0.55),
    'bangs':          LayerPosition(0, -91, 0.54),
    'pointed-pony':   LayerPosition(1, -117, 0.54),
    'spiky-hair':     LayerPosition(5, -94, 0.54),
    'dad-hair':       LayerPosition(-2, -80, 0.53),
    'edgy-hair':      LayerPosition(-2, -84, 0.38),
  };

  // facial hair positions (male only)
  static const Map<String, LayerPosition> facialHairPositions = {
    'style1':  LayerPosition(0, 15, 0.20),
    'style2':  LayerPosition(-5, 73, 0.20),
    'style3':  LayerPosition(1, 40, 0.28),
    'style4':  LayerPosition(1, 58, 0.40),
    'style5':  LayerPosition(1, 68, 0.40),
    'style6':  LayerPosition(0, 61, 0.43),
    'style7':  LayerPosition(0, 66, 0.20),
    'style8':  LayerPosition(0, -4, 0.51),
    'style9':  LayerPosition(0, 27, 0.23),
    'style10': LayerPosition(0, 11, 0.23),
    'style11': LayerPosition(0, 19, 0.52),
    'style12': LayerPosition(-3, 62, 0.48),
    'style13': LayerPosition(-1, 20, 0.20),
    'style14': LayerPosition(1, 65, 0.20),
    'style15': LayerPosition(-2, 5, 0.49),
    'style16': LayerPosition(5, 45, 0.52),
    'style17': LayerPosition(-2, 43, 0.36),
    'style18': LayerPosition(-2, 57, 0.20),
    'style19': LayerPosition(-2, 13, 0.20),
    'style20': LayerPosition(-1, 18, 0.24),
  };

  static LayerPosition getHairPosition(String gender, String style) {
    final map = gender.toLowerCase() == 'male'
        ? hairPositionsMale
        : hairPositionsFemale;
    return map[style] ?? const LayerPosition(0, -60, 0.60);
  }

  static LayerPosition? getFacialHairPosition(String? style) {
    if (style == null || style.isEmpty) return null;
    return facialHairPositions[style];
  }
}
