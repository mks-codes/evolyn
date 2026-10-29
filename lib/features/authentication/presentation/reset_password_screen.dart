import 'package:evolyn/features/authentication/providers/auth_state.dart';
import 'package:evolyn/features/authentication/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:evolyn/core/widgets/top_message.dart';
class ResetPasswordScreen extends ConsumerStatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  ConsumerState<ResetPasswordScreen> createState() =>
      _ResetPasswordScreenState();
}

class _ResetPasswordScreenState
    extends ConsumerState<ResetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _isSubmitting = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String _friendlyAuthError(Object? error) {
  final errorText = (error ?? '').toString().toLowerCase();

  bool containsAny(List<String> patterns) {
    return patterns.any((pattern) => errorText.contains(pattern));
  }

  // Internet and network failures.
  if (containsAny([
    'network-request-failed',
    'socketexception',
    'failed host lookup',
    'network is unreachable',
    'no internet',
    'connection timed out',
    'connection timeout',
    'connection reset',
    'connection refused',
    'failed to fetch',
    'httpexception',
    'clientexception',
    'handshakeexception',
    'timeout exception',
    'timed out',
    'deadline exceeded',
  ])) {
    return 'Unable to connect to the server. Please check your internet '
        'connection and try again.';
  }

  // Password does not meet authentication requirements.
  if (containsAny([
    'weak-password',
    'weak_password',
    'password is too weak',
    'password should be at least',
    'password must be at least',
    'password policy',
  ])) {
    return 'Your password does not meet the security requirements. '
        'Please choose a stronger password.';
  }

  // New password cannot match the current password.
  if (containsAny([
    'same_password',
    'same password',
    'password should be different',
    'password must be different',
    'new password cannot be the same',
  ])) {
    return 'Please choose a password different from your current password.';
  }

  // Expired or invalid reset links/codes.
  if (containsAny([
    'expired-action-code',
    'invalid-action-code',
    'expired reset link',
    'invalid reset link',
    'password reset token has expired',
    'invalid or expired token',
    'invalid token',
    'otp_expired',
    'otp expired',
  ])) {
    return 'Your password reset link may have expired or is invalid. '
        'Please request a new password reset link.';
  }

  // Expired authentication sessions.
  if (containsAny([
    'requires-recent-login',
    'user-token-expired',
    'invalid-user-token',
    'session expired',
    'session_expired',
    'auth_session_missing',
    'refresh token expired',
  ])) {
    return 'Your session has expired. Please sign in again and restart '
        'the password reset process.';
  }

  // Account no longer exists.
  if (containsAny([
    'user-not-found',
    'user_not_found',
    'account not found',
    'user does not exist',
  ])) {
    return 'We could not find your account. Please sign in again or '
        'restart the password reset process.';
  }

  // Too many requests.
  if (containsAny([
    'too-many-requests',
    'too many requests',
    'too many attempts',
    'rate limit exceeded',
    'over_email_send_rate_limit',
  ])) {
    return 'Too many attempts have been made. Please wait a while '
        'before trying again.';
  }

  // Account disabled.
  if (containsAny([
    'user-disabled',
    'user_disabled',
    'account disabled',
  ])) {
    return 'Your account is currently unavailable. Please contact support '
        'for assistance.';
  }

  // Authentication configuration or operation errors.
  if (containsAny([
    'operation-not-allowed',
    'operation_not_allowed',
    'signup_disabled',
    'invalid-api-key',
    'app-not-authorized',
    'unauthorized-domain',
    'configuration-not-found',
  ])) {
    return 'Password updates are currently unavailable. Please try again '
        'later or contact support.';
  }

  // Permission and authorization errors.
  if (containsAny([
    'permission-denied',
    'permission_denied',
    'unauthorized',
    'forbidden',
    'insufficient permissions',
  ])) {
    return 'You are not authorized to update this password. '
        'Please sign in again and try once more.';
  }

  // Server and service failures.
  if (containsAny([
    'internal-error',
    'internal error',
    'server error',
    'service unavailable',
    'database error',
    'status code: 500',
    'status code: 502',
    'status code: 503',
    'status code: 504',
  ])) {
    return 'Our service is temporarily unavailable. Please try again '
        'in a few minutes.';
  }

  // Never display raw technical exceptions.
  return 'We couldn’t update your password right now. Please try again. '
      'If the problem continues, contact support.';
}

Future<void> _updatePassword() async {
  if (_isSubmitting) return;

  if (!_formKey.currentState!.validate()) return;

  FocusScope.of(context).unfocus();

  setState(() => _isSubmitting = true);

  try {
    // Step 1: Update the password.
    try {
      await ref.read(authNotifierProvider.notifier).updatePassword(
            newPassword: _passwordController.text,
          );
    } catch (error) {
      if (!mounted) return;

      final providerError =
          ref.read(authNotifierProvider).errorMessage;

      _showMessage(
        _friendlyAuthError(providerError ?? error),
      );
      return;
    }

    if (!mounted) return;

    final authState = ref.read(authNotifierProvider);

    if (authState.status == AuthStatus.error) {
      _showMessage(
        _friendlyAuthError(authState.errorMessage),
      );
      return;
    }

    // Step 2: Sign out so the user can sign in with the new password.
    try {
      await ref.read(authNotifierProvider.notifier).signOut();
    } catch (_) {
      if (!mounted) return;

      _showMessage(
        'Your password was changed, but we couldn’t sign you out. '
        'Please sign out manually.',
      );
      return;
    }

    if (!mounted) return;

    final signOutState = ref.read(authNotifierProvider);

    if (signOutState.status == AuthStatus.error) {
      _showMessage(
        'Your password was changed, but we couldn’t sign you out. '
        'Please sign out manually.',
      );
      return;
    }

    // Step 3: Clear the form and navigate to sign-in.
    _passwordController.clear();
    _confirmPasswordController.clear();

    _showMessage('Password updated successfully.');

    context.go('/signin');
  } catch (error) {
    if (!mounted) return;

    _showMessage(_friendlyAuthError(error));
  } finally {
    if (mounted) {
      setState(() => _isSubmitting = false);
    }
  }
}

  void _showMessage(String message) {
   TopMessage.show(context, message);
  }

  InputDecoration _inputDecoration({
    required String hint,
    required bool obscure,
    required VoidCallback onToggleVisibility,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF77788A),
        fontSize: 15,
      ),
      prefixIcon: const Icon(
        Icons.lock_outline_rounded,
        color: Color(0xFF8B7CFF),
        size: 20,
      ),
      suffixIcon: IconButton(
        onPressed: onToggleVisibility,
        icon: Icon(
          obscure
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: const Color(0xFF9293A5),
          size: 20,
        ),
      ),
      filled: true,
      fillColor: const Color(0xFF0D0E20),
      contentPadding: const EdgeInsets.symmetric(
        horizontal: 18,
        vertical: 17,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF20213A),
        ),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(
          color: Color(0xFF7565FF),
          width: 1.2,
        ),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: const BorderSide(color: Colors.redAccent),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050614),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/sign-in');
                    }
                  },
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0D0E20),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF20213A),
                      ),
                    ),
                    child: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 18,
                      color: Colors.white,
                    ),
                  ),
                ),

                const SizedBox(height: 48),

                Center(
                  child: Container(
                    width: 76,
                    height: 76,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF7565FF).withOpacity(0.12),
                      border: Border.all(
                        color: const Color(0xFF7565FF).withOpacity(0.2),
                      ),
                    ),
                    child: const Icon(
                      Icons.lock_reset_rounded,
                      color: Color(0xFFA78BFA),
                      size: 34,
                    ),
                  ),
                ),

                const SizedBox(height: 28),

                const Center(
                  child: Text(
                    'Create a new password',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 27,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                const Center(
                  child: Text(
                    'Choose a strong new password for your account.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Color(0xFF9293A5),
                      fontSize: 15,
                      height: 1.5,
                    ),
                  ),
                ),

                const SizedBox(height: 42),

                const Text(
                  'New password',
                  style: TextStyle(
                    color: Color(0xFFD9D9E5),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 9),

                TextFormField(
                  controller: _passwordController,
                  obscureText: _obscurePassword,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.next,
                  enabled: !_isSubmitting,
                  autofillHints: const [AutofillHints.newPassword],
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                  decoration: _inputDecoration(
                    hint: 'Enter new password',
                    obscure: _obscurePassword,
                    onToggleVisibility: () {
                      setState(() {
                        _obscurePassword = !_obscurePassword;
                      });
                    },
                  ),
                  validator: (value) {
                    final password = value ?? '';

                    if (password.isEmpty) {
                      return 'Please enter a new password';
                    }

                    if (password.length < 8) {
                      return 'Password must be at least 8 characters';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 22),

                const Text(
                  'Confirm new password',
                  style: TextStyle(
                    color: Color(0xFFD9D9E5),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 9),

                TextFormField(
                  controller: _confirmPasswordController,
                  obscureText: _obscureConfirmPassword,
                  keyboardType: TextInputType.visiblePassword,
                  textInputAction: TextInputAction.done,
                  enabled: !_isSubmitting,
                  autofillHints: const [AutofillHints.newPassword],
                  onFieldSubmitted: (_) => _updatePassword(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                  decoration: _inputDecoration(
                    hint: 'Confirm new password',
                    obscure: _obscureConfirmPassword,
                    onToggleVisibility: () {
                      setState(() {
                        _obscureConfirmPassword =
                            !_obscureConfirmPassword;
                      });
                    },
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Please confirm your password';
                    }

                    if (value != _passwordController.text) {
                      return 'Passwords do not match';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 12),

                const Text(
                  'Use at least 8 characters.',
                  style: TextStyle(
                    color: Color(0xFF77788A),
                    fontSize: 12,
                  ),
                ),

                const SizedBox(height: 28),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed:
                        _isSubmitting ? null : _updatePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF7565FF),
                      disabledBackgroundColor:
                          const Color(0xFF7565FF).withOpacity(0.5),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(17),
                      ),
                    ),
                    child: _isSubmitting
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor:
                                  AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                            ),
                          )
                        : const Text(
                            'Update password',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 30),

                Center(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.shield_outlined,
                        size: 15,
                        color: Colors.white.withOpacity(0.28),
                      ),
                      const SizedBox(width: 7),
                      Text(
                        'Your account stays secure with Evolyn',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.28),
                          fontSize: 11.5,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}