import 'package:shared_preferences/shared_preferences.dart';

/// Stores per-screen guided-tour state on this device, separated by Supabase
/// user ID so one user's completion does not suppress another user's tours.
///
/// This is a convenience preference, not security-critical storage. Tours can
/// be replayed by calling [resetForScreen] before starting the relevant tour.
class GuidedTourService {
  GuidedTourService._();

  static const String _prefix = 'evolyn.guided_tour.v1';

  static String _key({
    required String userId,
    required String screenId,
  }) {
    final safeScreenId = screenId.trim().toLowerCase();
    if (safeScreenId.isEmpty) {
      throw ArgumentError.value(screenId, 'screenId', 'Must not be empty.');
    }
    return '$_prefix.$userId.$safeScreenId';
  }

  static Future<bool> hasSeen({
    required String userId,
    required String screenId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(
          _key(userId: userId, screenId: screenId),
        ) ??
        false;
  }

  static Future<void> markSeen({
    required String userId,
    required String screenId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(
      _key(userId: userId, screenId: screenId),
      true,
    );
  }

  static Future<void> resetForScreen({
    required String userId,
    required String screenId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(userId: userId, screenId: screenId));
  }

  static Future<void> resetAllForUser({required String userId}) async {
    final prefs = await SharedPreferences.getInstance();
    for (final screenId in const <String>[
      'home',
      'roadmap',
      'mentor',
      'learn',
      'progress',
    ]) {
      await prefs.remove(_key(userId: userId, screenId: screenId));
    }
  }
}
