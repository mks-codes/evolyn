
import 'package:evolyn/app/router/app_router.dart';
import 'package:evolyn/core/services/notification_service.dart';
import 'package:evolyn/core/widgets/account_deletion_recovery.dart';
import 'package:evolyn/firebase_options.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app/app.dart';
import 'core/config/supabase_config.dart';
import 'features/learn/presentation/learn_screen.dart';
import 'features/learn/widgets/evolyn_task_overlay.dart';
import 'l10n/app_localizations.dart';
import 'providers/app_locale_provider.dart';
import 'app/router/route_names.dart';
@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();

  runApp(
    const ProviderScope(
      child: EvolynOverlayApp(),
    ),
  );
}

/// Separate application entry point for the task overlay.
class EvolynOverlayApp extends ConsumerWidget {
  const EvolynOverlayApp({super.key});

  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locale = ref.watch(appLocaleProvider);

    return MaterialApp(
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      routes: {
        '/learn': (context) => const LearnScreen(),
      },
      home: EvolynTaskOverlay(),
    );
  }
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.publishableKey,
  );

  FirebaseMessaging.onBackgroundMessage(
    firebaseMessagingBackgroundHandler,
  );

  // Build the application container before accessing Riverpod providers.
  final container = ProviderContainer();

  // Read the same router provider used by the main application.
  final router = container.read(appRouterProvider);

  await NotificationService.instance.initialize(
    onNotificationTap: (data) {
      final route = data['route'];

      // Use only routes registered by your GoRouter configuration.
      const allowedRoutes = {
        RoutePaths.home,
        RoutePaths.languageSelection,
        RoutePaths.roadmapScreen,
      };

      if (route is String && allowedRoutes.contains(route)) {
        router.go(route);
      }
    },
  );

  AccountDeletionRecovery.initialize(
    Supabase.instance.client,
  );

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const EvolynApp(),
    ),
  );
}
