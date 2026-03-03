import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cerebro_app/screens/auth/login_screen.dart';
import 'package:cerebro_app/screens/auth/register_screen.dart';
import 'package:cerebro_app/screens/home/home_screen.dart';
import 'package:cerebro_app/screens/onboarding/onboarding_screen.dart';
import 'package:cerebro_app/screens/health/medication_screen.dart';
import 'package:cerebro_app/screens/health/mood_screen.dart';
import 'package:cerebro_app/screens/health/sleep_screen.dart';
import 'package:cerebro_app/screens/health/symptom_screen.dart';
import 'package:cerebro_app/screens/health/water_screen.dart';
import 'package:cerebro_app/screens/study/subjects_screen.dart';
import 'package:cerebro_app/screens/title/title_screen.dart';

class Routes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String register = '/register';
  static const String home = '/home';
  static const String subjects = '/study/subjects';
  static const String healthSleep = '/health/sleep';
  static const String healthMood = '/health/mood';
  static const String healthWater = '/health/water';
  static const String healthMedications = '/health/medications';
  static const String healthSymptoms = '/health/symptoms';
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
        path: Routes.home,
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: Routes.subjects,
        builder: (context, state) => const SubjectsScreen(),
      ),
      GoRoute(
        path: Routes.healthSleep,
        builder: (context, state) => const SleepScreen(),
      ),
      GoRoute(
        path: Routes.healthMood,
        builder: (context, state) => const MoodScreen(),
      ),
      GoRoute(
        path: Routes.healthWater,
        builder: (context, state) => const WaterScreen(),
      ),
      GoRoute(
        path: Routes.healthMedications,
        builder: (context, state) => const MedicationScreen(),
      ),
      GoRoute(
        path: Routes.healthSymptoms,
        builder: (context, state) => const SymptomScreen(),
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      body: Center(child: Text('Page not found: ${state.uri}')),
    ),
  );
});
