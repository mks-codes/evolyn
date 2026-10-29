
import 'dart:async';

import 'package:evolyn/l10n/app_localizations.dart';
import 'package:evolyn/providers/app_locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'package:showcaseview/showcaseview.dart';
import 'router/app_router.dart';
import 'router/route_names.dart';

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

    _authSubscription = supabase
        .Supabase.instance.client.auth.onAuthStateChange
        .listen(
      (authState) {
        debugPrint(
          'Supabase auth event: ${authState.event}',
        );

        if (authState.event ==
            supabase.AuthChangeEvent.passwordRecovery) {
          // Wait until the current frame has completed before navigating.
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (!mounted) return;

            ref
                .read(appRouterProvider)
                .goNamed(RouteNames.resetPassword);
          });
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

            builder: (context, child) {
        return ShowCaseWidget(
          enableAutoScroll: true,
          disableBarrierInteraction: true,
          builder: (showcaseContext) {
            return child ?? const SizedBox.shrink();
          },
        );
      },
      
      theme: ThemeData(
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      
    );
  }
}
