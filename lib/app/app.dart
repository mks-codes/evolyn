
import 'dart:async';

import 'package:evolyn/l10n/app_localizations.dart';
import 'package:evolyn/providers/app_locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import 'router/app_router.dart';

class EvolynApp extends ConsumerStatefulWidget {
  const EvolynApp({super.key});

  @override
  ConsumerState<EvolynApp> createState() => _EvolynAppState();
}

class _EvolynAppState extends ConsumerState<EvolynApp> {
  late final StreamSubscription<supabase.AuthState>
      _authSubscription;

  @override
  void initState() {
    super.initState();

    // Listen for Supabase authentication events.
    _authSubscription = supabase
        .Supabase.instance.client.auth.onAuthStateChange
        .listen(
      (data) {
        if (!mounted) return;

        // Navigate to the in-app password reset screen.
        if (data.event ==
            supabase.AuthChangeEvent.passwordRecovery) {
          ref.read(appRouterProvider).go('/reset-password');
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Supabase auth stream error: $error');
      },
    );
  }

  @override
  void dispose() {
    _authSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(appRouterProvider);
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Evolyn',
      routerConfig: router,
      locale: locale,
      localizationsDelegates:
          AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
    );
  }
}