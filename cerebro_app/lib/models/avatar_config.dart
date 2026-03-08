class AvatarConfig {
  final String gender;
  final String baseSkin;
  final String eyes;
  final String nose;
  final String mouth;
  final String hairStyle;
  final String hairColor;
  final String clothes;
  final String? facialHair;
  final String? glasses;
  final String? headwear;
  final String? neckwear;
  final String? extras;

  const AvatarConfig({
    this.gender = 'female',
    this.baseSkin = 'Base01',
    this.eyes = 'eyes01',
    this.nose = 'nose01',
    this.mouth = 'mouth01',
    this.hairStyle = 'bangs',
    this.hairColor = 'brown',
    this.clothes = 'sweater-blue',
    this.facialHair,
    this.glasses,
    this.headwear,
    this.neckwear,
    this.extras,
  });

  // asset paths
  String get basePath => 'assets/avatar/$gender/base/$baseSkin.png';
  String get eyesPath => 'assets/avatar/$gender/eyes/$eyes.png';
  String get nosePath => 'assets/avatar/$gender/nose/$nose.png';
  String get mouthPath => 'assets/avatar/$gender/mouth/$mouth.png';
  String get hairPath => 'assets/avatar/$gender/hair/$hairStyle-$hairColor.png';
  String get clothesPath => 'assets/avatar/$gender/clothes/$clothes.png';
  String? get facialHairPath =>
      facialHair != null ? 'assets/avatar/$gender/facialhair/$facialHair.png' : null;
  String? get glassesPath =>
      glasses != null ? 'assets/avatar/$gender/accessories/$glasses.png' : null;
  String? get headwearPath =>
      headwear != null ? 'assets/avatar/$gender/accessories/$headwear.png' : null;
  String? get neckwearPath =>
      neckwear != null ? 'assets/avatar/$gender/accessories/$neckwear.png' : null;
  String? get extrasPath =>
      extras != null ? 'assets/avatar/$gender/accessories/$extras.png' : null;

  List<String> get layerPaths {
    final layers = <String>[
      basePath, eyesPath, nosePath, mouthPath, clothesPath, hairPath,
    ];
    if (facialHairPath != null) layers.add(facialHairPath!);
    if (glassesPath != null) layers.add(glassesPath!);
    if (headwearPath != null) layers.add(headwearPath!);
    if (neckwearPath != null) layers.add(neckwearPath!);
    if (extrasPath != null) layers.add(extrasPath!);
    return layers;
  }

  AvatarConfig copyWith({
    String? gender,
    String? baseSkin,
    String? eyes,
    String? nose,
    String? mouth,
    String? hairStyle,
    String? hairColor,
    String? clothes,
    String? facialHair,
    String? glasses,
    String? headwear,
    String? neckwear,
    String? extras,
    bool clearFacialHair = false,
    bool clearGlasses = false,
    bool clearHeadwear = false,
    bool clearNeckwear = false,
    bool clearExtras = false,
  }) {
    return AvatarConfig(
      gender: gender ?? this.gender,
      baseSkin: baseSkin ?? this.baseSkin,
      eyes: eyes ?? this.eyes,
      nose: nose ?? this.nose,
      mouth: mouth ?? this.mouth,
      hairStyle: hairStyle ?? this.hairStyle,
      hairColor: hairColor ?? this.hairColor,
      clothes: clothes ?? this.clothes,
      facialHair: clearFacialHair ? null : (facialHair ?? this.facialHair),
      glasses: clearGlasses ? null : (glasses ?? this.glasses),
      headwear: clearHeadwear ? null : (headwear ?? this.headwear),
      neckwear: clearNeckwear ? null : (neckwear ?? this.neckwear),
      extras: clearExtras ? null : (extras ?? this.extras),
    );
  }

  Map<String, dynamic> toJson() => {
        'gender': gender,
        'base_skin': baseSkin,
        'eyes': eyes,
        'nose': nose,
        'mouth': mouth,
        'hair_style': hairStyle,
        'hair_color': hairColor,
        'clothes': clothes,
        'facial_hair': facialHair,
        'glasses': glasses,
        'headwear': headwear,
        'neckwear': neckwear,
        'extras': extras,
      };

  factory AvatarConfig.fromJson(Map<String, dynamic> json) => AvatarConfig(
        gender: json['gender'] ?? 'female',
        baseSkin: json['base_skin'] ?? 'Base01',
        eyes: json['eyes'] ?? 'eyes01',
        nose: json['nose'] ?? 'nose01',
        mouth: json['mouth'] ?? 'mouth01',
        hairStyle: json['hair_style'] ?? 'bangs',
        hairColor: json['hair_color'] ?? 'brown',
        clothes: json['clothes'] ?? 'sweater-blue',
        facialHair: json['facial_hair'],
        glasses: json['glasses'],
        headwear: json['headwear'],
        neckwear: json['neckwear'],
        extras: json['extras'],
      );

  // available options
  static const skinTones = ['Base01', 'Base02', 'Base03'];

  static const hairColors = [
    'black', 'blonde', 'brown', 'red', 'orange', 'silver', 'pink', 'darkblue'
  ];

  static const maleHairStyles = [
    'curly-short', 'straight-short', 'ceo-hair', 'flat-hair', '90s-hair',
    'bangs', 'pointed-pony', 'spiky-hair', 'dad-hair', 'edgy-hair',
  ];

  static const femaleHairStyles = [
    'medium-curl', 'bangs', 'to-the-side', 'boys-cut', 'granny-hair',
    'anime-hair', 'bangs-short', 'side-pony', 'pigtails', 'bun',
  ];

  static const maleClothes = [
    'uniform-blue', 'uniform-green', 'uniform-red', 'uniform-black',
    'button-up-shirt-blue', 'button-up-shirt-green', 'button-up-shirt-red', 'button-up-shirt-black',
    'sweater-blue', 'sweater-green', 'sweater-red', 'sweater-black',
    'c-neck-blue', 'c-neck-green', 'c-neck-red', 'c-neck-black',
    'v-neck-sweater-blue', 'v-neck-sweater-green', 'v-neck-sweater-red', 'v-neck-sweater-black',
    'tank-top-blue', 'tank-top-green', 'tank-top-red', 'tank-top-black',
  ];

  static const femaleClothes = [
    'off-shoulder-blue', 'off-shoulder-green', 'off-shoulder-red',
    'night-dress-blue', 'night-dress-green', 'night-dress-red',
    'sweater-blue', 'sweater-green', 'sweater-red',
    'tank-top-blue', 'tank-top-green', 'tank-top-red',
    'c-neck-blue', 'c-neck-green', 'c-neck-red',
    'v-neck-sweater-blue', 'v-neck-sweater-green', 'v-neck-sweater-red',
  ];

  static const glassesList = [
    'circular-glasses', 'square-glasses', 'star-glasses', 'heart-glasses',
    'bottomless-glasses', 'stripped-glasses', 'sunglasses',
  ];

  List<String> get availableHairStyles =>
      gender == 'male' ? maleHairStyles : femaleHairStyles;

  List<String> get availableClothes =>
      gender == 'male' ? maleClothes : femaleClothes;
}
