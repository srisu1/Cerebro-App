/// Uses GoRouter for declarative navigation.
/// Title screen shows first, then navigates via TitleScreen._go()
/// Flow: title → onboarding → register → setup → avatar → home

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cerebro_app/config/constants.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:cerebro_app/screens/auth/login_screen.dart';
import 'package:cerebro_app/screens/auth/register_screen.dart';
import 'package:cerebro_app/screens/auth/set_password_screen.dart';
import 'package:cerebro_app/screens/home/home_screen.dart';
// ignore: unused_import — keep importable while the wizard is bypassed; restore by swapping the /onboarding builder.
import 'package:cerebro_app/screens/onboarding/onboarding_screen.dart';
// ignore: unused_import — keep importable while the wizard is bypassed; restore by swapping the /setup builder.
import 'package:cerebro_app/screens/onboarding/setup_flow_screen.dart';
import 'package:cerebro_app/screens/study/subjects_screen.dart';
import 'package:cerebro_app/screens/study/study_session_screen.dart';
import 'package:cerebro_app/screens/study/study_analytics_screen.dart';
import 'package:cerebro_app/screens/study/quiz_screen.dart';
import 'package:cerebro_app/screens/study/take_quiz_screen.dart';
import 'package:cerebro_app/screens/study/flashcard_screen.dart';
import 'package:cerebro_app/screens/study/resource_screen.dart';
import 'package:cerebro_app/screens/study/study_calendar_screen.dart';
import 'package:cerebro_app/screens/health/sleep_screen.dart';
import 'package:cerebro_app/screens/health/mood_screen.dart';
import 'package:cerebro_app/screens/health/medication_screen.dart';
import 'package:cerebro_app/screens/health/symptom_screen.dart';
import 'package:cerebro_app/screens/health/water_screen.dart';
import 'package:cerebro_app/screens/avatar/avatar_customization_screen.dart';
import 'package:cerebro_app/screens/insights/insights_screen.dart';
import 'package:cerebro_app/screens/gamification/achievements_screen.dart';
import 'package:cerebro_app/screens/title/title_screen.dart';

/// Route paths as constants to avoid typos
class Routes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String setup = '/setup';
  static const String avatarSetup = '/avatar-setup';
  static const String home = '/home';
  static const String subjects = '/study/subjects';
  static const String studySession = '/study/session';
  static const String pastSessions = '/study/past-sessions';
  static const String studyAnalytics = '/study/analytics';
  static const String quizzes = '/study/quizzes';
  static const String takeQuiz = '/study/take-quiz';
  static const String flashcards = '/study/flashcards';
  static const String resources = '/study/resources';
  static const String calendar = '/study/calendar';
  static const String sleep = '/health/sleep';
  static const String mood = '/health/mood';
  static const String medications = '/health/medications';
  static const String symptoms = '/health/symptoms';
  static const String water = '/health/water';
  static const String avatar = '/avatar';
  static const String insights = '/insights';
  static const String achievements = '/achievements';
  static const String setPassword = '/set-password';
}

/// GoRouter provider for Riverpod
final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,

    routes: [
      // Navigation logic lives inside TitleScreen._go()
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const TitleScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        // Onboarding disabled — auto-bypass to login (or home if logged in).
        // Swap back to `const OnboardingScreen()` to re-enable the carousel.
        builder: (context, state) => const _WizardBypassScreen(target: _BypassTarget.auto),
      ),
      // The original onboarding screen is still importable if you need
      // to re-enable it; leave the import and route builder above, flip
      // the builder back to `const OnboardingScreen()`.
      GoRoute(
        path: Routes.login,
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: Routes.register,
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: Routes.setPassword,
        builder: (context, state) => const SetPasswordScreen(),
      ),
      GoRoute(
        path: Routes.setup,
        // Setup wizard disabled — auto-bypass to home. Restore by
        // replacing the builder with `const SetupFlowScreen()`.
        builder: (context, state) => const _WizardBypassScreen(target: _BypassTarget.home),
      ),
      GoRoute(
        path: Routes.avatarSetup,
        // Avatar setup gate disabled — auto-bypass to home. Restore by
        // replacing the builder with
        // `const AvatarCustomizationScreen(isSetup: true)`.
        builder: (context, state) => const _WizardBypassScreen(target: _BypassTarget.home),
      ),
      GoRoute(
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.subjects,
        builder: (context, state) => const SubjectsScreen(),
      ),
      GoRoute(
        path: Routes.studySession,
        builder: (context, state) => const StudySessionScreen(),
      ),
      // Dedicated entry point that opens the Study Session screen with the
      // Past Sessions sheet pre-opened. Kept as a separate path (rather
      // than a query param on /study/session) so the Study Hub can link to
      // it directly without clashing with live-session adoption logic.
      GoRoute(
        path: Routes.pastSessions,
        builder: (context, state) =>
            const StudySessionScreen(showPastOnOpen: true),
      ),
      GoRoute(
        path: Routes.studyAnalytics,
        builder: (context, state) => const StudyAnalyticsScreen(),
      ),
      GoRoute(
        path: Routes.quizzes,
        builder: (context, state) => const QuizScreen(),
      ),
      GoRoute(
        path: Routes.takeQuiz,
        builder: (context, state) {
          final quiz = state.extra as Map<String, dynamic>? ?? {};
          return TakeQuizScreen(quizData: quiz);
        },
      ),
      GoRoute(
        path: Routes.flashcards,
        builder: (context, state) => const FlashcardScreen(),
      ),
      GoRoute(
        path: Routes.resources,
        builder: (context, state) => const ResourceScreen(),
      ),
      GoRoute(
        path: Routes.calendar,
        builder: (context, state) => const StudyCalendarScreen(),
      ),
      GoRoute(
        path: Routes.sleep,
        builder: (context, state) => const SleepScreen(),
      ),
      GoRoute(
        path: Routes.mood,
        builder: (context, state) => const MoodScreen(),
      ),
      GoRoute(
        path: Routes.medications,
        builder: (context, state) => const MedicationScreen(),
      ),
      GoRoute(
        path: Routes.symptoms,
        builder: (context, state) => const SymptomScreen(),
      ),
      GoRoute(
        path: Routes.water,
        builder: (context, state) => const WaterScreen(),
      ),
      GoRoute(
        path: Routes.avatar,
        builder: (context, state) => AvatarCustomizationScreen(
          isSetup: false,
          preSelectStyle: state.uri.queryParameters['style'],
          preSelectColor: state.uri.queryParameters['color'],
        ),
      ),
      GoRoute(
        path: Routes.insights,
        builder: (context, state) => const InsightsScreen(),
      ),
      GoRoute(
        path: Routes.achievements,
        builder: (context, state) => const AchievementsScreen(),
      ),
    ],

    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('Page not found: ${state.uri}'),
      ),
    ),
  );
});

//  WIZARD BYPASS SCREEN
//  Temporary replacement for the onboarding carousel, setup wizard,
//  and avatar-setup gate while those flows are turned off. It:
//    1. Marks every wizard completion flag as `true` in prefs so
//       downstream guards (HomeScreen, login redirects, title
//       screen routing) don't bounce the user back.
//    2. Immediately redirects — to /home if we have a token,
//       otherwise to /login.
//  Shows a brief cream splash so the switch isn't jarring.
enum _BypassTarget {
  /// Always go to /home (we know we're authenticated).
  home,
  /// Pick /home if a token exists, else /login.
  auto,
}

class _WizardBypassScreen extends StatefulWidget {
  final _BypassTarget target;
  const _WizardBypassScreen({required this.target});
  @override
  State<_WizardBypassScreen> createState() => _WizardBypassScreenState();
}

class _WizardBypassScreenState extends State<_WizardBypassScreen> {
  @override
  void initState() {
    super.initState();
    // Defer navigation to the next frame so GoRouter has finished
    // building this screen before we push it off the stack.
    WidgetsBinding.instance.addPostFrameCallback((_) => _bypass());
  }

  Future<void> _bypass() async {
    final prefs = await SharedPreferences.getInstance();
    // Stamp all wizard steps "done" so nothing downstream re-opens them.
    await prefs.setBool(AppConstants.onboardingCompleteKey, true);
    await prefs.setBool(AppConstants.setupCompleteKey, true);
    await prefs.setBool(AppConstants.avatarCreatedKey, true);
    if (!mounted) return;

    String dest;
    switch (widget.target) {
      case _BypassTarget.home:
        dest = Routes.home;
        break;
      case _BypassTarget.auto:
        final tk = prefs.getString(AppConstants.accessTokenKey);
        dest = (tk != null && tk.isNotEmpty) ? Routes.home : Routes.login;
        break;
    }
    if (!mounted) return;
    context.go(dest);
  }

  @override
  Widget build(BuildContext context) {
    // Minimal splash — the user only sees this for one frame.
    return const Scaffold(
      backgroundColor: CerebroTheme.creamWarm,
      body: Center(
        child: CircularProgressIndicator(
          color: CerebroTheme.olive,
          strokeWidth: 3,
        ),
      ),
    );
  }
}
