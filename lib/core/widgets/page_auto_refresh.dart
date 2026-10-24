import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

class PageAutoRefresh extends StatefulWidget {
  const PageAutoRefresh({
    super.key,
    required this.child,
    required this.isActive,
    required this.onRefresh,
  });

  final Widget child;

  /// True only while this page/tab is visible.
  final bool isActive;

  /// Must fetch or invalidate the data used by this page.
  final Future<void> Function() onRefresh;

  @override
  State<PageAutoRefresh> createState() => _PageAutoRefreshState();
}

class _PageAutoRefreshState extends State<PageAutoRefresh>
    with WidgetsBindingObserver {
  Future<void>? _inFlightRefresh;
  DateTime? _lastSuccessfulRefresh;

  // Only suppress duplicate lifecycle/tab events that occur almost together.
  static const Duration _duplicateWindow = Duration(seconds: 2);

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    // Refresh the first time this page is shown.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_refreshIfNeeded());
    });
  }

  @override
  void didUpdateWidget(covariant PageAutoRefresh oldWidget) {
    super.didUpdateWidget(oldWidget);

    // Covers tabs kept alive in an IndexedStack or similar layout.
    if (widget.isActive && !oldWidget.isActive) {
      unawaited(_refreshIfNeeded());
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && widget.isActive) {
      unawaited(_refreshIfNeeded());
    }
  }

  Future<void> _refreshIfNeeded() async {
    if (!mounted || !widget.isActive) return;

    // Do not launch duplicate requests for simultaneous events.
    final pending = _inFlightRefresh;
    if (pending != null) {
      await pending;
      return;
    }

    final lastSuccess = _lastSuccessfulRefresh;
    if (lastSuccess != null &&
        DateTime.now().difference(lastSuccess) < _duplicateWindow) {
      return;
    }

    final refresh = _runRefresh();
    _inFlightRefresh = refresh;

    try {
      await refresh;
      _lastSuccessfulRefresh = DateTime.now();
    } catch (error, stackTrace) {
      // Keep the existing cached UI visible. A later activation or resume
      // can retry because failed refreshes are not marked successful.
      debugPrint('[PageAutoRefresh] Refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      if (identical(_inFlightRefresh, refresh)) {
        _inFlightRefresh = null;
      }
    }
  }

  Future<void> _runRefresh() async {
    await widget.onRefresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}