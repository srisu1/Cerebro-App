/// Configures theme, routing, and global providers.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cerebro_app/config/router.dart';
import 'package:cerebro_app/config/theme.dart';

class CerebroApp extends ConsumerWidget {
  const CerebroApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return MaterialApp.router(
      title: 'CEREBRO',
      debugShowCheckedModeBanner: false,

      theme: CerebroTheme.lightTheme,
      darkTheme: CerebroTheme.darkTheme,
      themeMode: ThemeMode.system,

      routerConfig: router,
    );
  }
}
