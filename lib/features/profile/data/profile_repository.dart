import 'package:supabase_flutter/supabase_flutter.dart';

class ProfileRepository {
  final SupabaseClient _supabase;

  ProfileRepository(this._supabase);

  Future<void> saveOnboardingStep({
  required Map<String, dynamic> data,
  required int step,
}) async {
  final user = _supabase.auth.currentUser;

  if (user == null) {
    throw Exception('User is not authenticated.');
  }

  await _supabase
      .from('profiles')
      .update({
        'onboarding_data': data,
        'onboarding_step': step,
        'updated_at': DateTime.now().toIso8601String(),
      })
      .eq('id', user.id);
}

Future<Map<String, dynamic>?> getOnboardingState() async {
  final user = _supabase.auth.currentUser;

  if (user == null) {
    throw Exception(
      'User is not authenticated.',
    );
  }

  return await _supabase
      .from('profiles')
      .select(
        'onboarding_data, onboarding_step, onboarding_completed',
      )
      .eq('id', user.id)
      .maybeSingle();
}

Future<void> completeOnboarding() async {
  final user = _supabase.auth.currentUser;

  if (user == null) {
    throw Exception('User is not authenticated.');
  }

  await _supabase
      .from('profiles')
      .update({
        'onboarding_completed': true,
        'onboarding_step': 9,
        'updated_at': DateTime.now().toIso8601String(),
      })
      .eq('id', user.id);
}

Future<Map<String, dynamic>?> getSessionProfile() async {
  final user = _supabase.auth.currentUser;

  if (user == null) {
    throw Exception('User is not authenticated.');
  }

  return await _supabase
      .from('profiles')
      .select(
        'onboarding_completed, journey_ready, onboarding_data',
      )
      .eq('id', user.id)
      .maybeSingle();
}

Future<void> completeJourney() async {
  final user = _supabase.auth.currentUser;

  if (user == null) {
    throw Exception('User is not authenticated.');
  }

  await _supabase
      .from('profiles')
      .update({
        'journey_ready': true,
        'updated_at': DateTime.now().toIso8601String(),
      })
      .eq('id', user.id);
}

  Future<Map<String, dynamic>?> getMyProfile() async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    final response = await _supabase
        .from('profiles')
        .select()
        .eq('id', user.id)
        .maybeSingle();

    return response;
  }

  Future<void> updateProfile({
    String? firstName,
    String? username,
    String? bio,
    bool? onboardingCompleted,
  }) async {
    final user = _supabase.auth.currentUser;

    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    final data = <String, dynamic>{
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (firstName != null) {
      data['first_name'] = firstName;
    }

    if (username != null) {
      data['username'] = username;
    }

    if (bio != null) {
      data['bio'] = bio;
    }

    if (onboardingCompleted != null) {
      data['onboarding_completed'] = onboardingCompleted;
    }

    await _supabase
        .from('profiles')
        .update(data)
        .eq('id', user.id);
  }

}
