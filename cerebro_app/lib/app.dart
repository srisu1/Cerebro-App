// Root app widget — theme, routing, and dark mode support.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cerebro_app/config/router.dart';
import 'package:cerebro_app/config/theme.dart';
import 'package:cerebro_app/providers/theme_mode_provider.dart';

class CerebroApp extends ConsumerStatefulWidget {
  const CerebroApp({super.key});

  @override
  ConsumerState<CerebroApp> createState() => _CerebroAppState();
}

class _CerebroAppState extends ConsumerState<CerebroApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangePlatformBrightness() {
    // If the user has picked "system", follow the OS.
    ref.read(themeModeProvider.notifier).onPlatformBrightnessChanged();
    super.didChangePlatformBrightness();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(themeModeProvider);

    // Rebuild on brightness change so theme stays in sync.
    return ValueListenableBuilder<Brightness>(
      valueListenable: CerebroTheme.brightnessNotifier,
      builder: (context, _, __) => MaterialApp.router(
        title: 'CEREBRO',
        debugShowCheckedModeBanner: false,

        theme: CerebroTheme.lightTheme,
        darkTheme: CerebroTheme.darkTheme,
        themeMode: themeMode,

        routerConfig: router,
      ),
    );
  }
}
