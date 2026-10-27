import 'package:evolyn/features/authentication/providers/auth_state.dart';
import 'package:evolyn/features/authentication/providers/auth_providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:evolyn/core/widgets/top_message.dart';
class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState
    extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  bool _isSending = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }


  void _showMessage(String message) {
  TopMessage.show(context, message);
}

String _friendlyResetError(Object? error) {
  final errorText = (error ?? '').toString().toLowerCase();

  bool containsAny(List<String> patterns) {
    return patterns.any((pattern) => errorText.contains(pattern));
  }

  // Network and internet connection failures.
  if (containsAny([
    'network-request-failed',
    'network error',
    'no internet',
    'socketexception',
    'failed host lookup',
    'connection timed out',
    'connection timeout',
    'connection reset',
    'connection refused',
    'connection aborted',
    'network is unreachable',
    'unable to resolve host',
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

  // Invalid email.
  if (containsAny([
    'invalid-email',
    'invalid email',
    'email address is invalid',
    'validation_failed',
  ])) {
    return 'Please check your email address and try again.';
  }

  // Rate limiting.
  if (containsAny([
    'too-many-requests',
    'too many requests',
    'too many attempts',
    'rate limit exceeded',
    'over_email_send_rate_limit',
    'over_request_rate_limit',
  ])) {
    return 'Too many attempts have been made. Please wait a while '
        'before requesting another reset link.';
  }

  // Reset emails or password-reset operations are disabled.
  if (containsAny([
    'operation-not-allowed',
    'operation_not_allowed',
    'email_provider_disabled',
    'email provider is disabled',
    'password reset is disabled',
    'password_reset_disabled',
  ])) {
    return 'Password reset is temporarily unavailable. '
        'Please try again later.';
  }

  // Authentication configuration errors.
  if (containsAny([
    'invalid-api-key',
    'app-not-authorized',
    'unauthorized-domain',
    'configuration-not-found',
  ])) {
    return 'Password reset is temporarily unavailable. '
        'Please try again later or contact support.';
  }

  // Server or service failures.
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
    return 'Our service is temporarily unavailable. '
        'Please try again in a few minutes.';
  }

  // Avoid exposing technical details to users.
  return 'We couldn’t process your password reset request. '
      'Please try again. If the problem continues, contact support.';
}

Future<void> _sendResetEmail() async {
  if (_isSending) return;

  if (!_formKey.currentState!.validate()) return;

  FocusScope.of(context).unfocus();

  setState(() => _isSending = true);

  try {
    await ref.read(authNotifierProvider.notifier).resetPassword(
          email: _emailController.text.trim(),
        );

    if (!mounted) return;

    final authState = ref.read(authNotifierProvider);

    if (authState.status == AuthStatus.error) {
      final error = authState.errorMessage ?? '';

      final errorText = error.toLowerCase();

      // Keep account existence private.
      // Some authentication providers return user-not-found errors.
      if (errorText.contains('user-not-found') ||
          errorText.contains('user_not_found') ||
          errorText.contains('user does not exist') ||
          errorText.contains('email not found')) {
        _showMessage(
          'If an account exists for this email, check your inbox '
          'for the password reset link.',
        );
        return;
      }

      _showMessage(_friendlyResetError(error));
      return;
    }

    _showMessage(
      'If an account exists for this email, check your inbox '
      'for the password reset link.',
    );
  } catch (error) {
    if (!mounted) return;

    final providerError =
        ref.read(authNotifierProvider).errorMessage;

    final effectiveError = providerError ?? error;
    final errorText = effectiveError.toString().toLowerCase();

    // Do not disclose whether the email is registered.
    if (errorText.contains('user-not-found') ||
        errorText.contains('user_not_found') ||
        errorText.contains('user does not exist') ||
        errorText.contains('email not found')) {
      _showMessage(
        'If an account exists for this email, check your inbox '
        'for the password reset link.',
      );
      return;
    }

    _showMessage(_friendlyResetError(effectiveError));
  } finally {
    if (mounted) {
      setState(() => _isSending = false);
    }
  }
}

  InputDecoration _inputDecoration({
    required String hint,
    required IconData icon,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: const TextStyle(
        color: Color(0xFF77788A),
        fontSize: 15,
      ),
      prefixIcon: Icon(
        icon,
        color: const Color(0xFF8B7CFF),
        size: 20,
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
                  onTap: () => context.pop(),
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
                    'Forgot your password?',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.6,
                    ),
                  ),
                ),

                const SizedBox(height: 12),

                const Center(
                  child: Text(
                    'Enter your email and we will send you a secure '
                    'link to reset your password in the app.',
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
                  'Email',
                  style: TextStyle(
                    color: Color(0xFFD9D9E5),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),

                const SizedBox(height: 9),

                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.done,
                  autocorrect: false,
                  enabled: !_isSending,
                  onFieldSubmitted: (_) => _sendResetEmail(),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                  ),
                  decoration: _inputDecoration(
                    hint: 'Enter your email',
                    icon: Icons.mail_outline_rounded,
                  ),
                  validator: (value) {
                    final email = value?.trim() ?? '';

                    if (email.isEmpty) {
                      return 'Please enter your email';
                    }

                    if (!RegExp(
                      r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
                    ).hasMatch(email)) {
                      return 'Please enter a valid email';
                    }

                    return null;
                  },
                ),

                const SizedBox(height: 26),

                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: _isSending ? null : _sendResetEmail,
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
                    child: _isSending
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
                            'Send reset link',
                            style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                  ),
                ),

                const SizedBox(height: 24),

                Center(
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    children: [
                      Text(
                        'Remember your password? ',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 13,
                        ),
                      ),
                      GestureDetector(
                        onTap: () => context.pop(),
                        child: const Text(
                          'Sign In',
                          style: TextStyle(
                            color: Color(0xFFA78BFA),
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 35),

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