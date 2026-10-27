import 'package:evolyn/features/authentication/presentation/reset_password_screen.dart';
import 'package:evolyn/features/onboarding/presentation/language_selection_page.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../features/authentication/presentation/forgot_password_screen.dart';
import '../../features/authentication/presentation/sign_in_screen.dart';
import '../../features/authentication/presentation/sign_up_screen.dart';
import '../../features/home/presentation/home_screen.dart';
import '../../features/onboarding/presentation/career_recommendations.dart';
import '../../features/onboarding/presentation/journey_generation_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen..dart';
import '../../features/onboarding/presentation/welcome_screen.dart';
import '../../features/roadmap/presentation/roadmap_generation_screen.dart';
import '../../features/roadmap/presentation/roadmap_screen.dart';
import '../../features/session/providers/session_provider.dart';
import '../../features/session/providers/session_state.dart';
import '../../features/splash/presentation/splash_screen.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'route_names.dart';
import 'router_refresh.dart';

Map<String, dynamic> _asStringDynamicMap(dynamic value) {
  if (value is Map) {
    return Map<String, dynamic>.from(value);
  }
  return <String, dynamic>{};
}

/// Converts a list of map-like extras into a typed list.
List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

final appRouterProvider = Provider<GoRouter>((ref) {
  final routerRefresh = ref.watch(
    routerRefreshProvider.select((notifier) => notifier),
  );
  return GoRouter(
    initialLocation: RoutePaths.splash,
    refreshListenable: routerRefresh,

    redirect: (context, state) {
      final session = ref.read(sessionProvider);
      final location = state.matchedLocation;

      // The locally persisted session can exist even when the
      // internet connection or the profile API is unavailable.
      final hasCachedSession =
          Supabase.instance.client.auth.currentSession != null;
      // ------------------------------------------------------------
      // ROUTE GROUPS
      // ------------------------------------------------------------

      final isSplash = location == RoutePaths.splash;

      final isPublicRoute =
          location == RoutePaths.welcome ||
          location == RoutePaths.signin ||
          location == RoutePaths.signup ||
          location == RoutePaths.forgotPassword;
      final isLanguageSelectionRoute = location == RoutePaths.languageSelection;
      final isOnboardingRoute = location == RoutePaths.onboarding;
      final isJourneyGenerationRoute = location == RoutePaths.journeyGeneration;
      final isCareerRecommendationRoute =
          location == RoutePaths.careerRecommendations;
      final isRoadmapGenerationRoute = location == RoutePaths.roadmapGeneration;
      final isRoadmapScreenRoute = location == RoutePaths.roadmapScreen;

      // ------------------------------------------------------------
      // 1. SESSION IS BEING CHECKED
      // ------------------------------------------------------------

      if (session.status == SessionStatus.checking) {
        // Keep the splash visible until session/profile state is resolved.
        if (hasCachedSession) {
          if (isSplash || isPublicRoute) {
            return RoutePaths.home;
          }

          return null;
        }
        return isSplash ? null : RoutePaths.splash;
      }

      // ------------------------------------------------------------
      // 2. USER IS SIGNED OUT
      // ------------------------------------------------------------

      if (session.status == SessionStatus.signedOut) {
        if (hasCachedSession) {
          if (isSplash || isPublicRoute) {
            return RoutePaths.home;
          }

          return null;
        }

        if (isPublicRoute) return null;
        return RoutePaths.welcome;
      }

      // ------------------------------------------------------------
      // 3. USER NEEDS ONBOARDING
      // ------------------------------------------------------------

      // 3. USER NEEDS ONBOARDING
      // 3. USER NEEDS ONBOARDING

      if (session.status == SessionStatus.needsOnboarding) {
        if (session.hasSelectedLanguage) {
          // Allow language selection only when the user
          // explicitly chooses to change their language.
          if (isLanguageSelectionRoute) {
            if (state.uri.queryParameters['changeLanguage'] == 'true') {
              return null;
            }

            // Otherwise, skip language selection.
            return RoutePaths.onboarding;
          }

          // Allow onboarding to open directly and resume after restart.
          if (isOnboardingRoute) {
            return null;
          }

          return RoutePaths.onboarding;
        }

        // First-time users must select a language.
        if (isLanguageSelectionRoute) {
          return null;
        }

        // Allow navigation immediately after the language is saved.
        if (isOnboardingRoute &&
            state.uri.queryParameters['languageSelected'] == 'true') {
          return null;
        }

        return RoutePaths.languageSelection;
      }

      // ------------------------------------------------------------
      // 4. JOURNEY GENERATION IS IN PROGRESS
      // ------------------------------------------------------------

      if (session.status == SessionStatus.generatingJourney) {
        // Allow the whole onboarding-to-roadmap flow. In particular, the
        // roadmap screen must remain reachable after a successful save.
        if (isJourneyGenerationRoute ||
            isCareerRecommendationRoute ||
            isRoadmapGenerationRoute ||
            isRoadmapScreenRoute) {
          return null;
        }

        return RoutePaths.journeyGeneration;
      }

      // ------------------------------------------------------------
      // 5. SESSION IS READY
      // ------------------------------------------------------------

      if (session.status == SessionStatus.ready) {
        // Redirect only obsolete auth/onboarding routes. Do not redirect the
        // career recommendations, roadmap-generation, or roadmap screens to
        // Home; they are valid destinations in the normal user workflow.
        if (isSplash ||
            isPublicRoute ||
            isLanguageSelectionRoute ||
            isOnboardingRoute ||
            isJourneyGenerationRoute) {
          return RoutePaths.home;
        }

        return null;
      }

      // ------------------------------------------------------------
      // 6. SESSION ERROR
      // ------------------------------------------------------------

      if (session.status == SessionStatus.error) {
        if (hasCachedSession) {
          if (isSplash || isPublicRoute) {
            return RoutePaths.home;
          }

          return null;
        }
        return RoutePaths.welcome;
      }

      return null;
    },

    routes: [
      // SPLASH
      GoRoute(
        name: RouteNames.splash,
        path: RoutePaths.splash,
        builder: (context, state) => const SplashScreen(),
      ),

      // WELCOME
      GoRoute(
        name: RouteNames.welcome,
        path: RoutePaths.welcome,
        builder: (context, state) => const WelcomeScreen(),
      ),

      // SIGN IN
      GoRoute(
        name: RouteNames.signin,
        path: RoutePaths.signin,
        builder: (context, state) => const SignInScreen(),
      ),

      // SIGN UP
      GoRoute(
        name: RouteNames.signup,
        path: RoutePaths.signup,
        builder: (context, state) => const SignUpScreen(),
      ),

      // FORGOT PASSWORD
      GoRoute(
        name: RouteNames.forgotPassword,
        path: RoutePaths.forgotPassword,
        builder: (context, state) => const ForgotPasswordScreen(),
      ),

      GoRoute(
        name: RouteNames.resetPassword,
        path: RoutePaths.resetPassword,
        builder: (context, state) => const ResetPasswordScreen(),
      ),

      GoRoute(
        name: RouteNames.languageSelection,
        path: RoutePaths.languageSelection,
        builder: (context, state) => const LanguageSelectionPage(),
      ),

      // ONBOARDING
      GoRoute(
        name: RouteNames.onboarding,
        path: RoutePaths.onboarding,
        builder: (context, state) => OnboardingScreen(
          initialLanguage: state.uri.queryParameters['language'],
        ),
      ),

      // JOURNEY GENERATION
      GoRoute(
        name: RouteNames.journeyGeneration,
        path: RoutePaths.journeyGeneration,
        builder: (context, state) => const JourneyGenerationScreen(),
      ),

      // CAREER RECOMMENDATIONS
      GoRoute(
        name: RouteNames.careerRecommendations,
        path: RoutePaths.careerRecommendations,
        builder: (context, state) {
          final extra = _asStringDynamicMap(state.extra);

          return CareerRecommendationsScreen(
            careerOptions: _asMapList(extra['careerOptions']),
            requestId: extra['requestId']?.toString(),
          );
        },
      ),

      // ROADMAP GENERATION
      GoRoute(
        name: RouteNames.roadmapGeneration,
        path: RoutePaths.roadmapGeneration,
        builder: (context, state) {
          final extra = _asStringDynamicMap(state.extra);

          return RoadmapGenerationScreen(
            requestId: extra['requestId']?.toString(),
            selectedCareers: _asMapList(extra['selectedCareers']),
          );
        },
      ),

      // ROADMAP SCREEN
      GoRoute(
        name: RouteNames.roadmapScreen,
        path: RoutePaths.roadmapScreen,
        builder: (context, state) {
          final extra = _asStringDynamicMap(state.extra);
          final roadmapData = _asStringDynamicMap(extra['roadmapData']);
          final selectedCareers = _asMapList(extra['selectedCareers']);

          // This screen currently depends on data passed through GoRouter
          // extras. If the route is opened directly without that data, send
          // the user to Home instead of throwing a cast exception.
          if (roadmapData.isEmpty || selectedCareers.isEmpty) {
            return const HomeScreen();
          }

          return RoadmapScreen(
            roadmapData: roadmapData,
            selectedCareers: selectedCareers,
            roadmapId:
                extra['roadmapId']?.toString() ??
                roadmapData['roadmap_id']?.toString(),
            requestId:
                extra['requestId']?.toString() ??
                roadmapData['request_id']?.toString(),
            generationRequestId:
                extra['generationRequestId']?.toString() ??
                roadmapData['generation_request_id']?.toString(),
          );
        },
      ),

      // HOME
      GoRoute(
        name: RouteNames.home,
        path: RoutePaths.home,
        builder: (context, state) => const HomeScreen(),
      ),
    ],
  );
});
