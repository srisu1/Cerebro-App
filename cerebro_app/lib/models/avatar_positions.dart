// Position offsets for each avatar layer (x, y, scale)

class LayerPosition {
  final double x;
  final double y;
  final double scale;
  const LayerPosition(this.x, this.y, this.scale);
}

class AvatarPositions {
  static const defaults = {
    'base': LayerPosition(0, 0, 0.30),
    'eyes': LayerPosition(0, -31, 0.30),
    'nose': LayerPosition(0, -15, 0.30),
    'mouth': LayerPosition(-2, 68, 0.30),
    'clothes': LayerPosition(0, 210, 0.30),
    'facialHair': LayerPosition(0, 34, 0.30),
    'glasses': LayerPosition(1, -25, 0.30),
    'headwear': LayerPosition(0, -100, 0.30),
    'neckwear': LayerPosition(0, 120, 0.30),
    'extras': LayerPosition(0, 50, 0.30),
  };

  static const hairFemale = {
    'bangs-short': LayerPosition(-3, -76, 0.30),
    'bangs': LayerPosition(-2, -22, 0.30),
    'medium-curl': LayerPosition(-8, -35, 0.30),
    'to-the-side': LayerPosition(-9, -19, 0.30),
    'granny-hair': LayerPosition(-1, -137, 0.30),
    'anime-hair': LayerPosition(-17, -30, 0.30),
    'side-pony': LayerPosition(-3, -40, 0.30),
    'pigtails': LayerPosition(-9, -119, 0.30),
    'bun': LayerPosition(-20, -148, 0.30),
    'boys-cut': LayerPosition(-4, -140, 0.30),
  };

  static const hairMale = {
    'curly-short': LayerPosition(2, -167, 0.30),
    'straight-short': LayerPosition(4, -138, 0.30),
    'ceo-hair': LayerPosition(7, -143, 0.30),
    'flat-hair': LayerPosition(-3, -143, 0.30),
    '90s-hair': LayerPosition(-1, -137, 0.30),
    'bangs': LayerPosition(-2, -159, 0.30),
    'pointed-pony': LayerPosition(-1, -200, 0.30),
    'spiky-hair': LayerPosition(9, -170, 0.30),
    'dad-hair': LayerPosition(1, -145, 0.30),
    'edgy-hair': LayerPosition(-2, -145, 0.30),
  };

  // NOTE: 'uniform' and 'button-up-shirt' are primarily male styles,
  // but included here as safety fallbacks matching c-neck dimensions
  // in case they're ever assigned to a female avatar.
  static const clothesFemale = {
    'off-shoulder': LayerPosition(-15, 221, 0.31),
    'night-dress': LayerPosition(-4, 214, 0.32),
    'sweater': LayerPosition(-4, 214, 0.32),
    'c-neck': LayerPosition(-4, 214, 0.32),
    'tank-top': LayerPosition(6, 214, 0.30),
    'v-neck-sweater': LayerPosition(-4, 214, 0.32),
    'uniform': LayerPosition(0, 210, 0.30),
    'button-up-shirt': LayerPosition(0, 210, 0.30),
  };

  static const clothesMale = {
    'uniform': LayerPosition(1, 230, 0.39),
    'button-up-shirt': LayerPosition(1, 230, 0.39),
    'sweater': LayerPosition(-3, 239, 0.40),
    'c-neck': LayerPosition(-3, 239, 0.40),
    'v-neck-sweater': LayerPosition(-3, 239, 0.40),
    'tank-top': LayerPosition(7, 212, 0.32),
  };

  static const facialHair = {
    'style1': LayerPosition(-3, 31, 0.30),
    'style2': LayerPosition(-7, 122, 0.30),
    'style3': LayerPosition(4, 70, 0.30),
    'style4': LayerPosition(3, 105, 0.30),
    'style5': LayerPosition(1, 120, 0.30),
    'style6': LayerPosition(-3, 100, 0.30),
    'style7': LayerPosition(-2, 118, 0.30),
    'style8': LayerPosition(-2, -13, 0.30),
    'style9': LayerPosition(0, 40, 0.30),
    'style10': LayerPosition(0, 18, 0.30),
    'style11': LayerPosition(-2, 35, 0.30),
    'style12': LayerPosition(-4, 109, 0.30),
    'style13': LayerPosition(-1, 33, 0.30),
    'style14': LayerPosition(-1, 111, 0.30),
    'style15': LayerPosition(-1, 6, 0.29),
    'style16': LayerPosition(-2, 86, 0.64),
    'style17': LayerPosition(-2, 86, 0.34),
    'style18': LayerPosition(-2, 97, 0.30),
    'style19': LayerPosition(-2, 29, 0.30),
    'style20': LayerPosition(-2, 44, 0.30),
  };

  static const glasses = {
    'default': LayerPosition(1, -25, 0.30),
  };

  static const headwear = {
    'hairband1': LayerPosition(-8, -150, 0.30),
    'hairband2': LayerPosition(-8, -150, 0.30),
    'basketball-cap': LayerPosition(0, -215, 0.30),
    'french-cap': LayerPosition(-24, -228, 0.30),
    'hat': LayerPosition(33, -225, 0.30),
    'winter-cap': LayerPosition(-3, -254, 0.30),
    'magician-hat': LayerPosition(-3, -254, 0.30),
    'sideways-baseball-cap': LayerPosition(77, -204, 0.29),
  };

  static const neckwear = {
    'boy-tie': LayerPosition(0, 160, 0.11),
    'straight-tie': LayerPosition(0, 241, 0.11),
  };

  static const extras = {
    'side-bow': LayerPosition(-141, -200, 0.30),
    'lady-hat': LayerPosition(0, -193, 0.30),
    'flower': LayerPosition(-170, -66, 0.30),
  };

  static LayerPosition getHairPosition(String gender, String style) {
    final positions = gender == 'male' ? hairMale : hairFemale;
    return positions[style] ?? defaults['clothes']!;
  }

  static LayerPosition getClothesPosition(String gender, String clothesName) {
    final positions = gender == 'male' ? clothesMale : clothesFemale;
    // clothesName is like "sweater-blue" — extract the base style
    final baseStyle = clothesName.replaceAll(RegExp(r'-(blue|green|red|black)$'), '');
    return positions[baseStyle] ?? defaults['clothes']!;
  }

  static LayerPosition getFacialHairPosition(String style) {
    return facialHair[style] ?? defaults['facialHair']!;
  }

  static LayerPosition getGlassesPosition(String style) {
    return glasses['default']!;
  }

  static LayerPosition getHeadwearPosition(String style) {
    return headwear[style] ?? defaults['headwear']!;
  }

  static LayerPosition getNeckwearPosition(String style) {
    return neckwear[style] ?? defaults['neckwear']!;
  }

  static LayerPosition getExtrasPosition(String style) {
    return extras[style] ?? defaults['extras']!;
  }
}
