import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/supabase_provider.dart';
import '../data/auth_repository.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as supabase;
import 'auth_state.dart';

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  final supabase = ref.read(supabaseClientProvider);

  return AuthRepository(supabase);
});

final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(
  AuthNotifier.new,
);

class AuthNotifier extends Notifier<AuthState> {
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

  void _listenToAuthChanges() {
    _authSubscription = _authRepository.authStateChanges.listen(
      (authState) {
        final event = authState.event;
        final user = authState.session?.user;

        // Only treat explicit sign-out or user deletion as logged out.
        if (event == supabase.AuthChangeEvent.signedOut ||
            event == supabase.AuthChangeEvent.userDeleted) {
          state = const AuthState(status: AuthStatus.unauthenticated);
          return;
        }

        // A profile update should update the user without logging them out.
        if (user != null) {
          state = AuthState(status: AuthStatus.authenticated, user: user);
          return;
        }

        // Determine the initial auth status when the app starts.
        if (event == supabase.AuthChangeEvent.initialSession) {
          state = const AuthState(status: AuthStatus.unauthenticated);
        }

        // For other events with no user, preserve the current auth state.
      },
      onError: (Object error, StackTrace stackTrace) {
        // Avoid an unhandled stream error crashing the app.
        print('[AuthNotifier] Auth stream error: $error');
        print(stackTrace);
      },
    );
  }

  Future<void> signUp({
    required String firstName,
    required String email,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      final response = await _authRepository.signUp(
        firstName: firstName,
        email: email,
        password: password,
      );

      final user = response.user;

      if (user == null) {
        state = const AuthState(
          status: AuthStatus.error,
          errorMessage: 'Unable to create account.',
        );
        return;
      }

      /*
       * If email confirmation is enabled in Supabase,
       * session may be null until the user verifies their email.
       */

      if (response.session != null) {
        state = AuthState(status: AuthStatus.authenticated, user: user);
      } else {
        state = AuthState(status: AuthStatus.unauthenticated, user: user);
      }
    } on supabase.AuthException catch (e) {
      state = AuthState(status: AuthStatus.error, errorMessage: e.message);
    } catch (e) {
      state = AuthState(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> signIn({required String email, required String password}) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      final response = await _authRepository.signIn(
        email: email,
        password: password,
      );

      final user = response.user;

      if (user == null) {
        state = const AuthState(
          status: AuthStatus.error,
          errorMessage: 'Unable to sign in.',
        );
        return;
      }

      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on supabase.AuthException catch (e) {
      state = AuthState(status: AuthStatus.error, errorMessage: e.message);
    } catch (e) {
      state = AuthState(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> signOut() async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      await _authRepository.signOut();

      state = const AuthState(status: AuthStatus.unauthenticated);
    } on supabase.AuthException catch (e) {
      state = AuthState(status: AuthStatus.error, errorMessage: e.message);
    } catch (e) {
      state = AuthState(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> resetPassword({required String email}) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      await _authRepository.resetPassword(email: email);

      state = state.copyWith(status: AuthStatus.unauthenticated);
    } on supabase.AuthException catch (e) {
      state = AuthState(status: AuthStatus.error, errorMessage: e.message);
    } catch (e) {
      state = AuthState(status: AuthStatus.error, errorMessage: e.toString());
    }
  }

  Future<void> updatePassword({required String newPassword}) async {
    state = state.copyWith(status: AuthStatus.loading, clearError: true);

    try {
      await _authRepository.updatePassword(newPassword: newPassword);

      final user = _authRepository.currentUser;

      if (user == null) {
        state = const AuthState(
          status: AuthStatus.error,
          errorMessage: 'Password changed, but no user session was found.',
        );
        return;
      }

      state = AuthState(status: AuthStatus.authenticated, user: user);
    } on supabase.AuthException catch (e) {
      state = AuthState(status: AuthStatus.error, errorMessage: e.message);
    } catch (e) {
      state = AuthState(status: AuthStatus.error, errorMessage: e.toString());
    }
  }
}
