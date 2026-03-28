/// API URLs, asset paths, and configuration values.

class AppConstants {
  static const String apiBaseUrl = 'http://localhost:8000/api/v1';
  static const int apiTimeout = 30000; // 30 seconds

  // Set this to your Google OAuth 2.0 Client ID from Google Cloud Console.
  // For macOS, use the iOS client ID type.
  static const String googleClientId = String.fromEnvironment('GOOGLE_CLIENT_ID');
  static const String googleClientSecret = String.fromEnvironment('GOOGLE_CLIENT_SECRET');

  static const String accessTokenKey = 'cerebro_access_token';
  static const String refreshTokenKey = 'cerebro_refresh_token';
  static const String userIdKey = 'cerebro_user_id';
  static const String themeKey = 'cerebro_theme_mode';
  static const String onboardingCompleteKey = 'cerebro_onboarding_done';
  static const String setupCompleteKey = 'cerebro_setup_done';
  static const String avatarCreatedKey = 'cerebro_avatar_created';
  static const String avatarConfigKey = 'cerebro_avatar_config';

  static const int xpPerStudySession = 25;   // per 30 min
  static const int xpPerQuizPass = 15;       // score >= 70%
  static const int xpPerQuizFail = 5;        // score < 70%
  static const int xpPerFlashcardReview = 5;
  static const int xpPerSleepLog = 10;
  static const int xpPerMoodLog = 5;
  static const int xpPerMedication = 5;
  static const int xpPerHabitComplete = 10;
  static const int xpPerLevel = 500;

  static const String avatarBasePath = 'assets/avatar';
  static const String maleBasePath = '$avatarBasePath/male';
  static const String femaleBasePath = '$avatarBasePath/female';
  static const String expressionsPath = '$avatarBasePath/expressions';

  static const Duration pageTransition = Duration(milliseconds: 300);
  static const Duration cardAnimation = Duration(milliseconds: 200);
  static const Duration avatarExpression = Duration(milliseconds: 500);
}
