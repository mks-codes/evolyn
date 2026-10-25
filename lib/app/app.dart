import 'dart:async';

import 'package:evolyn/l10n/app_localizations.dart';
import 'package:evolyn/providers/app_locale_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:internet_connection_checker_plus/internet_connection_checker_plus.dart';
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

      // Show the internet warning across the entire app.
      builder: (context, child) {
        return InternetStatusBanner(
          child: child ?? const SizedBox.shrink(),
        );
      },

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

/// Displays a warning whenever internet access is unavailable.
class InternetStatusBanner extends StatefulWidget {
  const InternetStatusBanner({
    super.key,
    required this.child,
  });

  final Widget child;

  @override
  State<InternetStatusBanner> createState() =>
      _InternetStatusBannerState();
}

class _InternetStatusBannerState
    extends State<InternetStatusBanner> {
  bool? _hasInternet;

  late final StreamSubscription<InternetStatus>
      _internetSubscription;

  @override
  void initState() {
    super.initState();

    // Listen for internet connectivity changes.
    _internetSubscription =
        InternetConnection().onStatusChange.listen(
      _updateInternetStatus,
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('Internet status error: $error');
      },
    );

    // Check internet access when the app starts.
    _checkInitialInternet();
  }

  Future<void> _checkInitialInternet() async {
    try {
      final hasInternet =
          await InternetConnection().hasInternetAccess;

      if (!mounted) return;

      setState(() {
        _hasInternet = hasInternet;
      });
    } catch (error) {
      debugPrint('Initial internet check failed: $error');

      if (!mounted) return;

      setState(() {
        _hasInternet = false;
      });
    }
  }

  void _updateInternetStatus(InternetStatus status) {
    if (!mounted) return;

    setState(() {
      _hasInternet = status == InternetStatus.connected;
    });
  }

  @override
  void dispose() {
    _internetSubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        if (_hasInternet == false)
          Material(
            color: Colors.red.shade700,
            child: SafeArea(
              bottom: false,
              child: SizedBox(
                width: double.infinity,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.wifi_off_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      const Flexible(
                        child: Text(
                          'No internet connection. '
                          'Please connect to the internet.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

        // Keep the existing routed app visible.
        Expanded(child: widget.child),
      ],
    );
  }
}