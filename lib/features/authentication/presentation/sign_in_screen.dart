import 'package:evolyn/core/services/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_providers.dart';
import '../providers/auth_state.dart';
import 'dart:async';
import '../../../core/widgets/top_message.dart';
import 'package:supabase_flutter/supabase_flutter.dart'
  show AuthException, AuthRetryableFetchException;

class SignInScreen extends ConsumerStatefulWidget {
  const SignInScreen({super.key});

  @override
  ConsumerState<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends ConsumerState<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

Future<void> _continue() async {
  final email = _emailController.text.trim();
  final password = _passwordController.text;

  // Validate empty fields.
  if (email.isEmpty) {
    _showError('Please enter your email address.');
    return;
  }

  if (password.isEmpty) {
    _showError('Please enter your password.');
    return;
  }

  // Basic email format validation.
  final emailRegex = RegExp(
    r'^[^@\s]+@[^@\s]+\.[^@\s]+$',
  );

  if (!emailRegex.hasMatch(email)) {
    _showError('Please enter a valid email address.');
    return;
  }

  try {
    await ref.read(authNotifierProvider.notifier).signIn(
          email: email,
          password: password,
        );
  } on AuthRetryableFetchException {
    if (!mounted) return;

    _showError(
      'Unable to connect to the server. '
      'Check your internet connection and try again.',
    );
    return;
 } on TimeoutException {
  if (!mounted) return;

  _showError(
    'Your internet connection seems slow. '
    'Please check your connection and try again.',
  );
  return;
} on AuthException catch (error) {
    if (!mounted) return;

    _showError(
      _friendlyAuthError(error),
    );
    return;
  } catch (error) {
    if (!mounted) return;

    _showError(
      _friendlyErrorMessage(error.toString()),
    );
    return;
  }

  if (!mounted) return;

  // Also handle exceptions converted into provider error state.
  final authState = ref.read(authNotifierProvider);

  if (authState.status == AuthStatus.error) {
    _showError(
      _friendlyErrorMessage(
        authState.errorMessage ?? 'Unable to sign in.',
      ),
    );
    return;
  }

  if (authState.status == AuthStatus.authenticated) {
    context.go('/language-selection');
    await NotificationService.instance.syncIfPermissionAlreadyGranted();
    return;
  }

  // Handles unexpected outcomes where authentication did not succeed.
  _showError(
    'Unable to sign in right now. Please try again.',
  );
}

String _friendlyAuthError(AuthException error) {
  final code = (error.code ?? '').toLowerCase();
  final statusCode = error.statusCode ?? '';

  if (code.contains('email_not_confirmed')) {
    return 'Please verify your email address before signing in.';
  }

  if (statusCode == '429' ||
      code.contains('over_request_rate_limit')) {
    return 'Too many attempts. Please wait a few minutes and try again.';
  }

  return _friendlyErrorMessage(
    '${error.code ?? ''} ${error.message} $statusCode',
  );
}

String _friendlyErrorMessage(String rawError) {
  final message = rawError.toLowerCase();

  // Incorrect email or password.
  if (message.contains('invalid login credentials') ||
      message.contains('invalid credentials') ||
      message.contains('invalid password')) {
    return 'Incorrect email or password. Please try again.';
  }

  // Email verification required.
  if (message.contains('email not confirmed') ||
      message.contains('email_not_confirmed')) {
    return 'Please verify your email address before signing in.';
  }

  // Rate limits.
  if (message.contains('too many requests') ||
      message.contains('over_request_rate_limit') ||
      message.contains('rate limit') ||
      message.contains('429')) {
    return 'Too many attempts. Please wait a few minutes and try again.';
  }

  // Offline or network-related failures.
  if (message.contains('authretryablefetchexception') ||
      message.contains('socketexception') ||
      message.contains('failed host lookup') ||
      message.contains('network is unreachable') ||
      message.contains('network request failed') ||
      message.contains('xmlhttprequest error') ||
      message.contains('failed to fetch') ||
      message.contains('connection refused') ||
      message.contains('connection reset') ||
      message.contains('clientexception') ||
      message.contains('no address associated with hostname') ||
      message.contains('network_error')) {
    return 'No internet connection or the server is unreachable. '
        'Check your connection and try again.';
  }

  // Slow network or request timeout.
if (message.contains('timeoutexception') ||
    message.contains('timeout') ||
    message.contains('timed out') ||
    message.contains('future not completed') ||
    message.contains('deadline exceeded')) {
  return 'Your internet connection seems slow. '
      'Please check your connection and try again.';
}

  // Supabase server errors.
  if (message.contains('502') ||
      message.contains('503') ||
      message.contains('504') ||
      message.contains('500') ||
      message.contains('internal server error')) {
    return 'The authentication service is temporarily unavailable. '
        'Please try again later.';
  }

  // Never expose raw server or exception details to users.
  return 'Unable to sign in right now. '
      'Please check your details and try again.';
}

void _showError(String message) {
  if (!mounted) return;

   TopMessage.show(context, message);
}

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    final isLoading = authState.status == AuthStatus.loading;

    return Scaffold(
      backgroundColor: const Color(0xFF050614),
      body: SafeArea(
        child: Stack(
          children: [
            // Top glow
            Positioned(
              top: -180,
              left: -120,
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF8B5CF6).withOpacity(0.16),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            // Bottom glow
            Positioned(
              bottom: -180,
              right: -120,
              child: Container(
                width: 420,
                height: 420,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6366F1).withOpacity(0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),

            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Back button
                  IconButton(
                    onPressed: isLoading
                        ? null
                        : () => context.pop(),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    icon: const Icon(
                      Icons.arrow_back_ios_new_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),

                  const SizedBox(height: 52),

                  // Logo
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(15),
                      gradient: const LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Color(0xFFA78BFA),
                          Color(0xFF7C3AED),
                        ],
                      ),
                      boxShadow: [
                        BoxShadow(
                          color:
                              const Color(0xFF8B5CF6).withOpacity(0.25),
                          blurRadius: 24,
                        ),
                      ],
                    ),
                    child: const Center(
                      child: Text(
                        'E',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  const Text(
                    'Start your journey.',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      letterSpacing: -1,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Text(
                    'Build the future you want.',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.55),
                      fontSize: 15,
                    ),
                  ),

                  const SizedBox(height: 42),

                  // Email
                  _buildLabel('Email'),

                  const SizedBox(height: 10),

                  _buildTextField(
                    controller: _emailController,
                    hintText: 'you@example.com',
                    keyboardType: TextInputType.emailAddress,
                  ),

                  const SizedBox(height: 22),

                  // Password
                  _buildLabel('Password'),

                  const SizedBox(height: 10),

                  _buildTextField(
                    controller: _passwordController,
                    hintText: 'Enter your password',
                    obscureText: _obscurePassword,
                    suffixIcon: IconButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              setState(() {
                                _obscurePassword =
                                    !_obscurePassword;
                              });
                            },
                      icon: Icon(
                        _obscurePassword
                            ? Icons.visibility_off_outlined
                            : Icons.visibility_outlined,
                        color: Colors.white.withOpacity(0.45),
                        size: 21,
                      ),
                    ),
                  ),

                  const SizedBox(height: 14),

                  // Forgot password
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: isLoading
                          ? null
                          : () {
                              context.push('/forgot-password');
                            },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                      ),
                      child: const Text(
                        'Forgot password?',
                        style: TextStyle(
                          color: Color(0xFFA78BFA),
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // Continue button
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: isLoading ? null : _continue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF7C3AED),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor:
                            const Color(0xFF7C3AED).withOpacity(0.45),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(17),
                        ),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 21,
                              height: 21,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Continue',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Sign Up
                  Center(
                    child: RichText(
                      text: TextSpan(
                        text: "doesn't have an account'? ",
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.45),
                          fontSize: 13,
                        ),
                        children: [
                          WidgetSpan(
                            alignment: PlaceholderAlignment.middle,
                            child: GestureDetector(
                              onTap: isLoading
                                  ? null
                                  : () {
                                      context.push('/signup');
                                    },
                              child: const Text(
                                'Sign Up',
                                style: TextStyle(
                                  color: Color(0xFFA78BFA),
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 42),

                  Center(
                    child: Text(
                      'By continuing, you agree to our Terms & Privacy Policy.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.28),
                        fontSize: 11,
                        height: 1.5,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLabel(String text) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.white.withOpacity(0.72),
        fontSize: 13,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String hintText,
    bool obscureText = false,
    TextInputType? keyboardType,
    Widget? suffixIcon,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: const TextStyle(
        color: Colors.white,
        fontSize: 15,
      ),
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: TextStyle(
          color: Colors.white.withOpacity(0.28),
          fontSize: 14,
        ),
        suffixIcon: suffixIcon,
        filled: true,
        fillColor: Colors.white.withOpacity(0.045),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 17,
          vertical: 17,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(
            color: Colors.white.withOpacity(0.08),
          ),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(
            color: Color(0xFF8B5CF6),
            width: 1.2,
          ),
        ),
      ),
    );
  }
}