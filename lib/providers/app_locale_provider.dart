
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

const supportedLanguageCodes = <String>{
  'en',
  'hi',
  'mr',
};

final appLocaleProvider =
    StateNotifierProvider<AppLocaleNotifier, Locale>(
  (ref) => AppLocaleNotifier(),
);

class AppLocaleNotifier extends StateNotifier<Locale> {
  AppLocaleNotifier() : super(const Locale('en')) {
    _loadSavedLocale();
  }

  static const _storageKey = 'evolyn.app_locale';

  bool _userChangedLocale = false;

  Future<void> _loadSavedLocale() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (_userChangedLocale) return;

      final code = prefs.getString(_storageKey) ?? 'en';

      if (supportedLanguageCodes.contains(code)) {
        state = Locale(code);
      }
    } catch (error) {
      debugPrint('Could not restore app language: $error');
    }
  }

  Future<void> setLanguageCode(String code) async {
    if (!supportedLanguageCodes.contains(code)) return;

    // Update the UI immediately.
    _userChangedLocale = true;
    state = Locale(code);

    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, code);
    } catch (error) {
      debugPrint('Could not save app language: $error');
    }
  }
}
