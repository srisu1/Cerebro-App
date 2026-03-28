// Theme mode provider — persists light/dark/system preference.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cerebro_app/config/constants.dart';
import 'package:cerebro_app/config/theme.dart';

/// Persists and applies the app-wide ThemeMode.
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _load();
  }

  /// Load the saved mode from prefs (key: `cerebro_theme_mode`).
  /// Values stored as 'light' / 'dark' / 'system'.
  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(AppConstants.themeKey);
    final mode = switch (raw) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    state = mode;
    _syncCerebroBrightness(mode);
  }

  /// Set the mode, persist it, and push the new brightness into
  /// CerebroTheme so custom painted widgets rebuild.
  Future<void> setMode(ThemeMode mode) async {
    if (mode == state) return;
    state = mode;
    _syncCerebroBrightness(mode);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.themeKey, switch (mode) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      ThemeMode.system => 'system',
    });
  }

  /// Convenience: flip between light/dark from a switch widget. If
  /// currently on system, picks whichever is opposite of the platform.
  Future<void> toggle() async {
    final current = resolvedBrightness(
      CerebroTheme.brightnessNotifier.value,
    );
    await setMode(current == Brightness.dark ? ThemeMode.light : ThemeMode.dark);
  }

  // Resolve ThemeMode to Brightness; reads platform brightness directly.
  static Brightness resolvedBrightness(Brightness currentFallback) {
    final bindingInstance = WidgetsBinding.instance;
    // ignore: deprecated_member_use
    final platform = bindingInstance.platformDispatcher.platformBrightness;
    return platform;
  }

  void _syncCerebroBrightness(ThemeMode mode) {
    // For light/dark we're explicit; for system we defer to the OS.
    // The MaterialApp wrapper in app.dart also listens to the
    // platform brightness via MediaQuery and updates us if it flips.
    final brightness = switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => _platformBrightness(),
    };
    CerebroTheme.brightnessNotifier.value = brightness;
  }

  Brightness _platformBrightness() {
    final binding = WidgetsBinding.instance;
    return binding.platformDispatcher.platformBrightness;
  }

  /// Called by app.dart when the OS brightness changes AND we're in
  /// system mode, so the palette follows along.
  void onPlatformBrightnessChanged() {
    if (state == ThemeMode.system) {
      _syncCerebroBrightness(ThemeMode.system);
    }
  }
}

final themeModeProvider =
    StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});
