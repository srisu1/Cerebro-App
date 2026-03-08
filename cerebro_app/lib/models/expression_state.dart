enum ExpressionState {
  neutral,

  // existing
  angry,
  anxious,
  calm,
  excited,
  grateful,
  happy,
  sad,
  tired,

  // new
  blink,     // closed eyes — for periodic blink animation
  focused,   // narrowed determined eyes — study time
  playful,   // wink + cheeky grin — good streak / idle fun
  sleepy,    // half-closed + yawn — early morning / late night
  surprised, // wide eyes + O mouth — achievement / level up
}

const _validExpressions = {
  ExpressionState.angry,
  ExpressionState.anxious,
  ExpressionState.calm,
  ExpressionState.excited,
  ExpressionState.grateful,
  ExpressionState.happy,
  ExpressionState.sad,
  ExpressionState.tired,
};

class ExpressionEngine {
  ExpressionEngine._();

  static bool hasAssets(ExpressionState state) =>
      _validExpressions.contains(state);

  static String? folderName(ExpressionState state) {
    if (state == ExpressionState.neutral) return null;
    return state.name; // enum name matches folder name exactly
  }

  static String? eyesPath(ExpressionState state) {
    final folder = folderName(state);
    return folder == null ? null : 'assets/avatar/expressions/$folder/eyes.png';
  }

  static String? nosePath(ExpressionState state) {
    final folder = folderName(state);
    return folder == null ? null : 'assets/avatar/expressions/$folder/nose.png';
  }

  static String? mouthPath(ExpressionState state) {
    final folder = folderName(state);
    return folder == null ? null : 'assets/avatar/expressions/$folder/mouth.png';
  }

  // context mapping

  static ExpressionState fromTimeOfDay([DateTime? now]) {
    final h = (now ?? DateTime.now()).hour;
    if (h >= 0 && h < 7)   return ExpressionState.sleepy;   // late night / very early
    if (h >= 7 && h < 9)   return ExpressionState.sleepy;   // morning wakeup
    if (h >= 9 && h < 12)  return ExpressionState.happy;    // morning energy
    if (h >= 12 && h < 14) return ExpressionState.calm;     // lunch / midday
    if (h >= 14 && h < 17) return ExpressionState.focused;  // afternoon study
    if (h >= 17 && h < 20) return ExpressionState.calm;     // evening wind-down
    if (h >= 20 && h < 23) return ExpressionState.tired;    // getting late
    return ExpressionState.sleepy;                            // very late night
  }

  static ExpressionState fromMood(String? moodKey) {
    if (moodKey == null) return ExpressionState.neutral;
    switch (moodKey.toLowerCase()) {
      case 'happy':
      case 'joy':
        return ExpressionState.happy;
      case 'sad':
      case 'down':
        return ExpressionState.sad;
      case 'angry':
      case 'frustrated':
        return ExpressionState.angry;
      case 'anxious':
      case 'worried':
      case 'stressed':
        return ExpressionState.anxious;
      case 'calm':
      case 'peaceful':
      case 'relaxed':
        return ExpressionState.calm;
      case 'excited':
      case 'energetic':
      case 'motivated':
        return ExpressionState.excited;
      case 'grateful':
      case 'loved':
      case 'content':
        return ExpressionState.grateful;
      case 'tired':
      case 'exhausted':
      case 'sleepy':
        return ExpressionState.tired;
      default:
        return ExpressionState.neutral;
    }
  }

  static ExpressionState fromActivity(AvatarActivity activity) {
    switch (activity) {
      case AvatarActivity.idle:
        return fromTimeOfDay();
      case AvatarActivity.studying:
        return ExpressionState.focused;
      case AvatarActivity.workout:
        return ExpressionState.excited;
      case AvatarActivity.sleeping:
        return ExpressionState.sleepy;
      case AvatarActivity.taskCompleted:
        return ExpressionState.happy;
      case AvatarActivity.levelUp:
        return ExpressionState.surprised;
      case AvatarActivity.streakMilestone:
        return ExpressionState.playful;
      case AvatarActivity.moodLogged:
        return ExpressionState.grateful;
    }
  }

  static String clothesForTimeOfDay(String gender, [DateTime? now]) {
    final h = (now ?? DateTime.now()).hour;
    final isMale = gender.toLowerCase() == 'male';

    if (h >= 0 && h < 7) {
      // Late night → pajamas / night dress
      return isMale ? 'sweater' : 'night-dress';
    }
    if (h >= 7 && h < 9) {
      // Morning → casual
      return isMale ? 'c-neck' : 'off-shoulder';
    }
    if (h >= 9 && h < 17) {
      // Study hours → uniform
      return 'uniform';
    }
    if (h >= 17 && h < 20) {
      // Evening → casual
      return isMale ? 'v-neck-sweater' : 'sweater';
    }
    if (h >= 20 && h < 23) {
      // Late evening → cozy
      return isMale ? 'sweater' : 'v-neck-sweater';
    }
    // Very late → night clothes
    return isMale ? 'sweater' : 'night-dress';
  }

  static String speechMessage(ExpressionState state, String name, {int streak = 0}) {
    final h = DateTime.now().hour;
    switch (state) {
      case ExpressionState.sleepy:
        if (h < 9) {
          return _pick([
            'Good morning, $name! *yaaawn*\nReady to start the day?',
            'Rise and shine, $name!\nLet\'s ease into today...',
            'Morning, $name!\nA good breakfast powers a good brain!',
          ]);
        }
        return _pick([
          'Getting sleepy, $name?\nMaybe it\'s time for bed...',
          'It\'s getting late!\nDon\'t forget to rest up.',
        ]);

      case ExpressionState.happy:
        return _pick([
          'You\'re doing great today, $name!',
          'What an awesome day! Keep it up!',
          'Look at you go! You\'re a star!',
          if (streak > 3) '$streak day streak! You\'re on fire!',
        ].whereType<String>().toList());

      case ExpressionState.focused:
        return _pick([
          'Focus time! You\'ve got this, $name!',
          'Deep work mode activated!',
          'Let\'s lock in and study!',
        ]);

      case ExpressionState.calm:
        return _pick([
          'Feeling peaceful, $name?',
          'Take a breath. You\'re doing well.',
          'A calm mind learns best!',
        ]);

      case ExpressionState.excited:
        return _pick([
          'Let\'s goooo, $name!!',
          'Energy levels: MAX! Let\'s crush it!',
          'You\'re radiating good vibes today!',
        ]);

      case ExpressionState.sad:
        return _pick([
          'Hey $name, it\'s okay to feel this way.',
          'I\'m here for you. Want to talk about it?',
          'Even tough days end. You\'ve got this.',
        ]);

      case ExpressionState.anxious:
        return _pick([
          'Take a deep breath, $name.',
          'One step at a time. You\'re stronger than you think.',
          'It\'s okay to pause. I\'m right here.',
        ]);

      case ExpressionState.angry:
        return _pick([
          'I see you\'re frustrated, $name.',
          'Take a moment. Then tackle it fresh.',
          'Channeling anger into action? Let\'s go!',
        ]);

      case ExpressionState.tired:
        return _pick([
          'Looks like you need some rest, $name.',
          'You\'ve worked hard! Maybe a break?',
          'Don\'t push too hard. Rest is productive too!',
        ]);

      case ExpressionState.grateful:
        return _pick([
          'Gratitude looks good on you, $name!',
          'What a wonderful mindset today!',
          'Counting blessings? That\'s the spirit!',
        ]);

      case ExpressionState.surprised:
        return _pick([
          'Whoa!! Did that just happen?!',
          'AMAZING! Look at that achievement!',
          'No way! You did it, $name!!',
        ]);

      case ExpressionState.playful:
        return _pick([
          'Hehe! Feeling cheeky today, $name?',
          'Your streak is looking mighty fine!',
          'Having fun? That\'s what it\'s all about!',
        ]);

      case ExpressionState.neutral:
        return _pick([
          'Hey $name! What shall we do today?',
          'Ready for a productive session?',
          'Welcome back! Let\'s make today count!',
        ]);

      case ExpressionState.blink:
        // Blink is transient — shouldn't show messages.
        return '';
    }
  }

  static String _pick(List<String> options) {
    return options[DateTime.now().microsecond % options.length];
  }
}

enum AvatarActivity {
  idle,
  studying,
  workout,
  sleeping,
  taskCompleted,
  levelUp,
  streakMilestone,
  moodLogged,
}
