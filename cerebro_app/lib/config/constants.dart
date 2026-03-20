class AppConstants {
  // api
  static const String apiBaseUrl = 'http://localhost:8000/api/v1';
  static const int apiTimeout = 30000;

  // google oauth (macOS uses iOS client type)
  static const String googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const String googleClientSecret = String.fromEnvironment('GOOGLE_CLIENT_SECRET');

  // shared prefs keys
  static const String accessTokenKey = 'cerebro_access_token';
  static const String refreshTokenKey = 'cerebro_refresh_token';
  static const String userIdKey = 'cerebro_user_id';
  static const String themeKey = 'cerebro_theme_mode';
  static const String onboardingCompleteKey = 'cerebro_onboarding_done';
  static const String setupCompleteKey = 'cerebro_setup_done';
  static const String avatarCreatedKey = 'cerebro_avatar_created';
  static const String avatarConfigKey = 'cerebro_avatar_config';

  // xp system
  static const int xpPerStudySession = 25;
  static const int xpPerQuizPass = 15;
  static const int xpPerQuizFail = 5;
  static const int xpPerFlashcardReview = 5;
  static const int xpPerSleepLog = 10;
  static const int xpPerMoodLog = 5;
  static const int xpPerMedication = 5;
  static const int xpPerHabitComplete = 10;
  static const int xpPerLevel = 500;

  // avatar assets
  static const String avatarBasePath = 'assets/avatar';
  static const String maleBasePath = '$avatarBasePath/male';
  static const String femaleBasePath = '$avatarBasePath/female';
  static const String expressionsPath = '$avatarBasePath/expressions';

  // animation durations
  static const Duration pageTransition = Duration(milliseconds: 300);
  static const Duration cardAnimation = Duration(milliseconds: 200);
  static const Duration avatarExpression = Duration(milliseconds: 500);
}
