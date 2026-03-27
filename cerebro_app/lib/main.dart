// App entry point.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cerebro_app/app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    // ProviderScope wraps the entire app for Riverpod state management
    const ProviderScope(
      child: CerebroApp(),
    ),
  );
}
