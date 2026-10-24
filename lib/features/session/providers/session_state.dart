
import 'package:supabase_flutter/supabase_flutter.dart';

enum SessionStatus {
  checking,
  signedOut,
  needsOnboarding,
  generatingJourney,
  ready,
  error,
}

class SessionState {
  final SessionStatus status;
  final User? user;
  final bool? onboardingCompleted;
  final bool? journeyReady;
  final bool hasSelectedLanguage;
  final String? errorMessage;

  const SessionState({
    required this.status,
    this.user,
    this.onboardingCompleted,
    this.journeyReady,
    this.hasSelectedLanguage = false,
    this.errorMessage,
  });

  const SessionState.checking({
    User? user,
  }) : this(
          status: SessionStatus.checking,
          user: user,
        );

  const SessionState.signedOut()
      : this(
          status: SessionStatus.signedOut,
        );

  const SessionState.needsOnboarding(
    User user, {
    bool hasSelectedLanguage = false,
  }) : this(
          status: SessionStatus.needsOnboarding,
          user: user,
          onboardingCompleted: false,
          journeyReady: false,
          hasSelectedLanguage: hasSelectedLanguage,
        );

  const SessionState.generatingJourney(
    User user,
  ) : this(
          status: SessionStatus.generatingJourney,
          user: user,
          onboardingCompleted: true,
          journeyReady: false,
        );

  const SessionState.ready(
    User user,
  ) : this(
          status: SessionStatus.ready,
          user: user,
          onboardingCompleted: true,
          journeyReady: true,
        );
}
