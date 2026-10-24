import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared display-name source for HomeTab and ProfileScreen.
///
/// Auth metadata has priority because profile editing updates it.
/// The profiles table and email are fallbacks for existing accounts.
final userDisplayNameProvider =
    FutureProvider.autoDispose<String>((ref) async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;

  if (user == null) return '';

  String firstNonEmpty(
    Map<String, dynamic> values,
    List<String> keys,
  ) {
    for (final key in keys) {
      final value = values[key]?.toString().trim();

      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return '';
  }

  const nameKeys = [
    'full_name',
    'display_name',
    'name',
    'first_name',
    'username',
  ];

  // 1. Use Supabase Auth metadata first.
  final metadata = user.userMetadata ?? <String, dynamic>{};
  final authName = firstNonEmpty(metadata, nameKeys);

  if (authName.isNotEmpty) {
    return authName;
  }

  // 2. Fall back to the existing profiles record.
  try {
    final profile = await supabase
        .from('profiles')
        .select('*')
        .eq('id', user.id)
        .maybeSingle();

    if (profile != null) {
      final profileName = firstNonEmpty(
        Map<String, dynamic>.from(profile),
        nameKeys,
      );

      if (profileName.isNotEmpty) {
        return profileName;
      }
    }
  } catch (error) {
    debugPrint(
      '[UserDisplayNameProvider] Profile lookup failed: $error',
    );
  }

  // 3. Final fallback: email prefix.
  final email = user.email?.trim();

  if (email != null && email.contains('@')) {
    final prefix = email.split('@').first.trim();

    if (prefix.isNotEmpty) return prefix;
  }

  return '';
});