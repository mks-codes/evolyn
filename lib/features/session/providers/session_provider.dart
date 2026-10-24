import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../authentication/providers/auth_providers.dart';
import '../../profile/providers/profile_provider.dart';
import 'session_state.dart';

final sessionProvider = NotifierProvider<SessionNotifier, SessionState>(
  SessionNotifier.new,
);

class SessionNotifier extends Notifier<SessionState> {
  StreamSubscription<supabase.AuthState>? _authSubscription;

  bool _initialized = false;

  @override
  SessionState build() {
    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    final authRepository = ref.read(authRepositoryProvider);

    // Listen for auth changes after the app is running.
    _authSubscription = authRepository.authStateChanges.listen(
      _handleAuthStateChange,
      onError: (error, stackTrace) {
        state = SessionState(
          status: SessionStatus.error,
          errorMessage: error.toString(),
        );
      },
    );

    // Do NOT trust currentSession as proof that the
    // account still exists on Supabase.
    //
    // Validate it asynchronously when the app starts.
    Future.microtask(() async {
      await initializeSession();
    });

    return const SessionState.checking();
  }

  // ---------------------------------------------------------------------------
  // AUTH STATE CHANGE
  // ---------------------------------------------------------------------------

  Future<void> _handleAuthStateChange(supabase.AuthState authState) async {
    final event = authState.event;
    final session = authState.session;

    // Initial session is handled by initializeSession().
    // We don't want to blindly trust the locally restored session here.
    if (event == supabase.AuthChangeEvent.initialSession) {
      return;
    }

    // User signed out or session became invalid.
    if (event == supabase.AuthChangeEvent.signedOut || session == null) {
      state = const SessionState.signedOut();
      return;
    }

    final preserveCurrentRoute =
        event == supabase.AuthChangeEvent.userUpdated ||
        event == supabase.AuthChangeEvent.tokenRefreshed;
    // For sign-in, token refresh, and user updates,
    // the session is considered authenticated and
    // we can now check the user's Evolyn profile.
    await _loadUserSession(session.user, showChecking: !preserveCurrentRoute);
  }

  // ---------------------------------------------------------------------------
  // INITIAL SESSION CHECK
  // ---------------------------------------------------------------------------

  Future<void> initializeSession() async {
    if (_initialized) {
      return;
    }

    _initialized = true;

    state = const SessionState.checking();

    try {
      final authRepository = ref.read(authRepositoryProvider);

      /*
       * This is the important part.
       *
       * currentSession may come from local storage.
       * validateSession() verifies/refreshes it with
       * Supabase.
       */
      final session = await authRepository.validateSession();

      // No valid server-side session.
      if (session == null) {
        await authRepository.signOut();

        state = const SessionState.signedOut();
        return;
      }

      // Session is valid. Now check the Evolyn profile.
      await _loadUserSession(session.user);
    } catch (e) {
      state = SessionState(
        status: SessionStatus.error,
        errorMessage: e.toString(),
      );
    }
  }

  bool _hasSavedLanguage(Map<String, dynamic> profile) {
    final raw = profile['onboarding_data'];

    if (raw is Map) {
      final data = Map<String, dynamic>.from(raw);
      final career = data['career_onboarding'];

      if (career is Map) {
        final language = career['language'];

        if (language is String &&
            ['en', 'hi', 'mr'].contains(language.trim().toLowerCase())) {
          return true;
        }
      }
    }

    // Optional fallback for profiles using root-level language fields.
    final rootLanguage =
        profile['preferred_language'] ??
        profile['preferredLanguage'] ??
        profile['language'];

    return rootLanguage is String &&
        ['en', 'hi', 'mr'].contains(rootLanguage.trim().toLowerCase());
  }

  // ---------------------------------------------------------------------------
  // PROFILE / ONBOARDING CHECK
  // ---------------------------------------------------------------------------

  Future<void> _loadUserSession(
    supabase.User user, {
    bool showChecking = true,
  }) async {
    if (showChecking) {
      state = SessionState.checking(user: user);
    }

    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .getSessionProfile();

      // Profile does not exist: new user.
      if (profile == null) {
        state = SessionState.needsOnboarding(user, hasSelectedLanguage: false);
        return;
      }

      debugPrint('[SESSION] Profile keys: ${profile.keys.toList()}');
      debugPrint('[SESSION] onboarding_data: ${profile['onboarding_data']}');

      final hasSelectedLanguage = _hasSavedLanguage(profile);

      debugPrint('[SESSION] hasSelectedLanguage: $hasSelectedLanguage');

      final onboardingCompleted = profile['onboarding_completed'] == true;

      final journeyReady = profile['journey_ready'] == true;

      if (!onboardingCompleted) {
        state = SessionState.needsOnboarding(
          user,
          hasSelectedLanguage: hasSelectedLanguage,
        );
        return;
      }

      if (!journeyReady) {
        state = SessionState.generatingJourney(user);
        return;
      }

      state = SessionState.ready(user);
    } catch (e) {
      state = SessionState(
        status: SessionStatus.error,
        user: user,
        errorMessage: e.toString(),
      );
    }
  }

  // ---------------------------------------------------------------------------
  // MANUAL REFRESH
  // ---------------------------------------------------------------------------

  Future<void> refresh() async {
    final authRepository = ref.read(authRepositoryProvider);

    try {
      final session = await authRepository.validateSession();

      if (session == null) {
        await authRepository.signOut();

        state = const SessionState.signedOut();
        return;
      }

      await _loadUserSession(session.user);
    } catch (e) {
      state = SessionState(
        status: SessionStatus.error,
        errorMessage: e.toString(),
      );
    }
  }
}
