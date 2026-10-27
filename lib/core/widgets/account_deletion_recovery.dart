import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountDeletionRecovery {
  AccountDeletionRecovery._();

  static StreamSubscription<AuthState>? _subscription;

  static void initialize(SupabaseClient supabase) {
    if (_subscription != null) return;

    _subscription = supabase.auth.onAuthStateChange.listen(
      (authState) {
        final event = authState.event;

        if (event != AuthChangeEvent.signedIn &&
            event != AuthChangeEvent.initialSession) {
          return;
        }

        if (authState.session?.user == null) return;

        // Defer the network call until after the auth callback returns.
        unawaited(
          Future<void>(() async {
            try {
              final response = await supabase.functions.invoke(
                'delete-account',
                body: {'action': 'cancel'},
              );

              if (response.status < 200 || response.status >= 300) {
                debugPrint(
                  '[AccountDeletionRecovery] Cancellation returned '
                  'HTTP ${response.status}.',
                );
              } else {
                debugPrint(
                  '[AccountDeletionRecovery] '
                  'Deletion recovery check completed.',
                );
              }
            } catch (error, stackTrace) {
              debugPrint(
                '[AccountDeletionRecovery] Cancellation failed: $error',
              );
              debugPrintStack(stackTrace: stackTrace);
            }
          }),
        );
      },
      onError: (Object error, StackTrace stackTrace) {
        debugPrint('[AccountDeletionRecovery] Auth stream error: $error');
        debugPrintStack(stackTrace: stackTrace);
      },
    );
  }

  static Future<void> dispose() async {
    await _subscription?.cancel();
    _subscription = null;
  }
}