import 'package:evolyn/features/authentication/providers/auth_providers.dart';
import 'package:evolyn/features/authentication/providers/auth_state.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers/supabase_provider.dart';
import '../data/profile_repository.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final supabase = ref.read(supabaseClientProvider);

  return ProfileRepository(supabase);
});

final profileProvider = FutureProvider<Map<String, dynamic>?>((ref) async {
  final authState = ref.watch(authNotifierProvider);
  if(authState.status != AuthStatus.authenticated){
    return null;
  }

  final repository = ref.read(profileRepositoryProvider);

  return repository.getMyProfile();
 
});