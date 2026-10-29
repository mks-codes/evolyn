import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;

import '../../../core/providers/supabase_provider.dart';
import '../data/auth_repository.dart';
import 'auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final client = ref.read(supabaseClientProvider);
  return AuthRepository(client);
});

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
  static const Duration _requestTimeout = Duration(seconds: 30);

  late final AuthRepository _authRepository;

  StreamSubscription<supabase.AuthState>? _authSubscription;

  @override
  AuthState build() {
    _authRepository = ref.read(authRepositoryProvider);

    ref.onDispose(() {
      _authSubscription?.cancel();
    });

    _listenToAuthChanges();

    final currentUser = _authRepository.currentUser;

    if (currentUser != null) {
      return AuthState(status: AuthStatus.authenticated, user: currentUser);
    }

    return const AuthState(status: AuthStatus.unauthenticated);
  }

  // Convert exceptions to recognizable messages so the screens can
  // display their existing user-friendly messages.
  String _errorMessageForState(Object error) {
    final message = error.toString().toLowerCase();

    if (error is TimeoutException) {
      return 'Request timed out';
    }

    if (error is supabase.AuthRetryableFetchException) {
      final errorMessage = error.message.toLowerCase();

      if (errorMessage.contains('timeout') ||
          errorMessage.contains('timed out')) {
        return 'Request timed out';
      }

      // Network failure or unreachable authentication service.
      return 'Network error: ${error.message}';
    }

    if (message.contains('timeout') ||
        message.contains('timed out') ||
        message.contains('deadline exceeded')) {
      return 'Request timed out';
    }

    if (error is supabase.AuthException) {
      return error.message;
    }

    return error.toString();
  }

  // Every failed request must leave the loading state.
  void _setError(Object error) {
    state = AuthState(
      status: AuthStatus.error,
      errorMessage: _errorMessageForState(error),
    );
  }

  void _listenToAuthChanges() {
    _authSubscription = _authRepository.authStateChanges.listen(
      (authState) {
        final event = authState.event;
        final user = authState.session?.user;

        if (event == supabase.AuthChangeEvent.signedOut ||
            event == supabase.AuthChangeEvent.userDeleted) {
          state = const AuthState(status: AuthStatus.unauthenticated);
          return;
        }

        // A session with a user means authentication succeeded.
        if (user != null) {
          state = AuthState(status: AuthStatus.authenticated, user: user);
          return;
        }

        // Do not let a delayed initial event overwrite an active request
        // or its error state.
        if (event == supabase.AuthChangeEvent.initialSession &&
            state.status != AuthStatus.loading &&
            state.status != AuthStatus.error) {
          state = const AuthState(status: AuthStatus.unauthenticated);
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        // Keep stream errors from becoming unhandled exceptions.
        // Do not change the UI state just because token refresh had a
        // temporary network error.
        print('[AuthNotifier] Auth stream error: $error');
      },
    );
  }

  /// Create a new account.
  Future<void> signUp({
    required String firstName,
    required String email,
    required String password,
  }) async {
    if (state.status == AuthStatus.loading) return;

    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      final response = await _authRepository
          .signUp(firstName: firstName, email: email, password: password)
          .timeout(_requestTimeout);

      final user = response.user;

      if (user == null) {
        state = const AuthState(
          status: AuthStatus.error,
          errorMessage: 'Unable to create account.',
        );
        return;
      }

      if (response.session != null) {
        state = AuthState(status: AuthStatus.authenticated, user: user);
      } else {
        // Email confirmation may be required before sign-in.
        state = AuthState(status: AuthStatus.unauthenticated, user: user);
      }
    } catch (error) {
      _setError(error);
    }
  }

  /// Sign in an existing user.
  Future<void> signIn({required String email, required String password}) async {
    if (state.status == AuthStatus.loading) return;

    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      final response = await _authRepository
          .signIn(email: email, password: password)
          .timeout(_requestTimeout);

      final user = response.user;

      if (user == null) {
        state = const AuthState(
          status: AuthStatus.error,
          errorMessage: 'Unable to sign in.',
        );
        return;
      }

      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (error) {
      _setError(error);
    }
  }

  /// Sign out the current user.
  Future<void> signOut() async {
    if (state.status == AuthStatus.loading) return;

    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      await _authRepository.signOut().timeout(_requestTimeout);

      state = const AuthState(status: AuthStatus.unauthenticated);
    } catch (error) {
      _setError(error);
    }
  }

  /// Send a password reset email.
  Future<void> resetPassword({required String email}) async {
    if (state.status == AuthStatus.loading) return;

    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      await _authRepository
          .resetPassword(email: email)
          .timeout(_requestTimeout);

      state = state.copyWith(
        status: AuthStatus.unauthenticated,
        clearError: true,
      );
    } catch (error) {
      _setError(error);
    }
  }

  /// Update the user's password.
  Future<void> updatePassword({required String newPassword}) async {
    if (state.status == AuthStatus.loading) return;

    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      await _authRepository
          .updatePassword(newPassword: newPassword)
          .timeout(_requestTimeout);

      final user = _authRepository.currentUser;

      if (user == null) {
        state = const AuthState(
          status: AuthStatus.error,
          errorMessage: 'Password changed, but no user session was found.',
        );
        return;
      }

      state = AuthState(status: AuthStatus.authenticated, user: user);
    } catch (error) {
      _setError(error);
    }
  }
}
