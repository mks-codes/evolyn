// now we can access the supabase client anywhere in the app using this provider
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabaseClientProvider = Provider<SupabaseClient>((ref) {
  return Supabase.instance.client;
});
// for example
// final supabaseClient = ref.read(supabaseClientProvider);
