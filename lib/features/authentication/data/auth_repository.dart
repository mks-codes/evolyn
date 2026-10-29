import 'package:supabase_flutter/supabase_flutter.dart';

class AuthRepository {
  final SupabaseClient _supabase;

  AuthRepository(this._supabase);

  static const String passwordResetRedirect = 'evolyn://reset-password';

  /// Create a new account

  /// Create a new account
  Future<AuthResponse> signUp({
    required String firstName,
    required String email,
    required String password,
  }) async {
    return _supabase.auth
        .signUp(
          email: email,
          password: password,
          emailRedirectTo: 'evolyn://auth-callback/email-confirmed',
          data: {'first_name': firstName},
        )
        .timeout(const Duration(seconds: 30));
  }

  /// Sign in an existing user
  /// Sign in an existing user
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) {
    return _supabase.auth
        .signInWithPassword(email: email, password: password)
        .timeout(const Duration(seconds: 30));
  }

  Future<Session?> validateSession() async {
    final cachedSession = _supabase.auth.currentSession;

    if (cachedSession == null) {
      return null;
    }

    if (!cachedSession.isExpired) {
      return cachedSession;
    }

    try {
      final response = await _supabase.auth.refreshSession();

      return response.session;
    } on AuthRetryableFetchException {
      // Network failure, timeout, or retryable server error.
      // Do not interpret this as a logged-out user.
      rethrow;
    } on AuthException {
      // A non-retryable authentication error occurred.
      // Let the session provider handle this as an invalid session.
      return null;
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    await _supabase.auth.signOut();
  }

  /// Send password reset email
  Future<void> resetPassword({required String email}) async {
    await _supabase.auth.resetPasswordForEmail(
      email.trim(),
      redirectTo: 'evolyn://reset-password',
    );
  }

  Future<void> updatePassword({required String newPassword}) async {
    await _supabase.auth.updateUser(UserAttributes(password: newPassword));
  }

  /// Get currently logged-in user
  User? get currentUser {
    return _supabase.auth.currentUser;
  }

  /// Get current session
  Session? get currentSession {
    return _supabase.auth.currentSession;
  }

  /// Listen for authentication changes
  Stream<AuthState> get authStateChanges {
    return _supabase.auth.onAuthStateChange;
  }
}
