import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cerebro_app/screens/auth/login_screen.dart';
import 'package:cerebro_app/screens/auth/register_screen.dart';
import 'package:cerebro_app/screens/auth/set_password_screen.dart';
import 'package:cerebro_app/screens/home/home_screen.dart';
import 'package:cerebro_app/screens/onboarding/onboarding_screen.dart';
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

final routerProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: Routes.splash,

    routes: [
      GoRoute(
        path: Routes.splash,
        builder: (context, state) => const TitleScreen(),
      ),
      GoRoute(
        path: Routes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
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
        builder: (context, state) => const SetupFlowScreen(),
      ),
      GoRoute(
        path: Routes.avatarSetup,
        builder: (context, state) =>
            const AvatarCustomizationScreen(isSetup: true),
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
