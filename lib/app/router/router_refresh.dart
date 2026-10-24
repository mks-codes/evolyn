import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import '../../features/session/providers/session_provider.dart';
import '../../features/session/providers/session_state.dart';

class RouterRefreshNotifier
    extends ChangeNotifier {
  RouterRefreshNotifier(this.ref) {
    ref.listen<SessionState>(
      sessionProvider,
      (_, __) {
        notifyListeners();
      },
    );
  }

  final Ref ref;
}

final routerRefreshProvider = Provider<RouterRefreshNotifier>((ref) {
  final notifier = RouterRefreshNotifier(ref);

  ref.onDispose(notifier.dispose);

  return notifier;
});