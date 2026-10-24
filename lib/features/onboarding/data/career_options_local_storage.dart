
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class CachedCareerOptions {
final String requestId;
final List<Map<String, dynamic>> careerOptions;

const CachedCareerOptions({
  required this.requestId,
  required this.careerOptions,
});
}

class CareerOptionsLocalStorage {
String _key(String userId) =>
    'evolyn_pending_career_options_v1_$userId';

Future<void> save({
  required String userId,
  required String requestId,
  required List<Map<String, dynamic>> careerOptions,
}) async {
  final prefs = await SharedPreferences.getInstance();

  await prefs.setString(
    _key(userId),
    jsonEncode({
      'requestId': requestId,
      'careerOptions': careerOptions,
      'savedAt': DateTime.now().toIso8601String(),
    }),
  );
}

Future<CachedCareerOptions?> load({
  required String userId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  final key = _key(userId);
  final stored = prefs.getString(key);

  if (stored == null || stored.isEmpty) {
    return null;
  }

  try {
    final decoded = jsonDecode(stored);

    if (decoded is! Map) {
      throw const FormatException('Invalid cached data.');
    }

    final data = Map<String, dynamic>.from(decoded);
    final rawOptions = data['careerOptions'];
    final requestId = data['requestId']?.toString();

    if (rawOptions is! List ||
        rawOptions.isEmpty ||
        requestId == null ||
        requestId.isEmpty) {
      throw const FormatException('Incomplete cached data.');
    }

    final options = <Map<String, dynamic>>[];

    for (final item in rawOptions) {
      if (item is! Map) {
        throw const FormatException(
          'Invalid cached career option.',
        );
      }

      options.add(Map<String, dynamic>.from(item));
    }

    return CachedCareerOptions(
      requestId: requestId,
      careerOptions: options,
    );
  } catch (_) {
    // Remove only invalid or unreadable cached data.
    await prefs.remove(key);
    return null;
  }
}

Future<void> clear({
  required String userId,
}) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove(_key(userId));
}
}
