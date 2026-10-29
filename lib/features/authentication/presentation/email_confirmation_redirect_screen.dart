
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/widgets/top_message.dart';

class EmailConfirmationRedirectScreen extends StatefulWidget {
  const EmailConfirmationRedirectScreen({super.key});

  @override
  State<EmailConfirmationRedirectScreen> createState() =>
      _EmailConfirmationRedirectScreenState();
}

class _EmailConfirmationRedirectScreenState
    extends State<EmailConfirmationRedirectScreen> {
  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _finishConfirmation();
    });
  }

  Future<void> _finishConfirmation() async {
    final auth = Supabase.instance.client.auth;

    String message =
        'Email confirmed successfully! Please sign in to continue.';

    try {
      // Sign out if email confirmation created an authenticated session.
      if (auth.currentSession != null) {
        await auth.signOut();
      }
    } catch (error) {
      debugPrint('Could not clear confirmation session: $error');

      message =
          'Your email confirmation is complete. '
          'Please sign in to continue.';
    }

    if (!mounted) return;

    // Display the message using your existing TopMessage widget.
    TopMessage.show(context, message);

    // Open the Sign In screen.
    context.go('/signin?emailConfirmed=true');
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF050614),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(
              color: Color(0xFF7565FF),
            ),
            SizedBox(height: 20),
            Text(
              'Verifying your email...',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white,
                fontSize: 15,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
