
import 'dart:async';
import 'dart:convert';
import 'package:android_intent_plus/android_intent.dart';
import 'package:android_intent_plus/flag.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

class EvolynTaskOverlay extends StatefulWidget {
  const EvolynTaskOverlay({super.key});

  @override
  State<EvolynTaskOverlay> createState() =>
      _EvolynTaskOverlayState();
}

class _EvolynTaskOverlayState extends State<EvolynTaskOverlay> {
  static const Color purple = Color(0xFF7C3AED);
  static const Color lavender = Color(0xFFC4B5FD);

  StreamSubscription<dynamic>? _subscription;
  Timer? _ticker;
  Timer? _closeTimer;

  String _title = 'Task in progress';
  DateTime? _deadline;
  bool _expiryScheduled = false;
  bool _openingLearn = false;

  @override
  void initState() {
    super.initState();

    _subscription =
        FlutterOverlayWindow.overlayListener.listen(_onMessage);

    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) {
        if (!mounted) return;
        setState(() {});
        _checkExpiry();
      },
    );

    unawaited(_sendReady());
  }

  Future<void> _sendReady() async {
    try {
      await FlutterOverlayWindow.shareData(
        'evolyn_overlay_ready',
      );
    } catch (e) {
      debugPrint('Overlay ready signal failed: $e');
    }
  }

Future<void> _openLearn() async {
  debugPrint('EVOLYN: Bubble tapped');

  if (_openingLearn) return;
  _openingLearn = true;

  try {
    // Keep the existing message for main-app communication.
    try {
      await FlutterOverlayWindow.shareData(
        'evolyn_open_learn',
      );
    } catch (e) {
      debugPrint('Overlay message failed: $e');
    }

    // Launch or bring the Evolyn Android app to the foreground.
    const intent = AndroidIntent(
      action: 'android.intent.action.MAIN',
      category: 'android.intent.category.LAUNCHER',

      // IMPORTANT: Replace with your actual Android applicationId.
      package: 'com.example.evolyn',

      flags: <int>[
        Flag.FLAG_ACTIVITY_NEW_TASK,
        Flag.FLAG_ACTIVITY_CLEAR_TOP,
        Flag.FLAG_ACTIVITY_SINGLE_TOP,
      ],
    );

    await intent.launch();

    debugPrint('EVOLYN: App launch requested');

    // Close the large overlay so it does not cover the opened app.
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      debugPrint('Could not close overlay: $e');
    }
  } catch (e, stackTrace) {
    debugPrint('Could not open Evolyn: $e');
    debugPrintStack(stackTrace: stackTrace);
  } finally {
    _openingLearn = false;
  }
}


void _onMessage(dynamic event) {
  if (event is! String) return;

  // Ignore plain-text control messages.
  // These are not JSON task-timer payloads.
  if (event == 'evolyn_overlay_ready' ||
      event == 'evolyn_open_learn') {
    return;
  }

  // Only parse JSON messages.
  if (!event.trimLeft().startsWith('{')) {
    return;
  }

  try {
    final decoded = jsonDecode(event);

    if (decoded is! Map ||
        decoded['type'] != 'task_timer') {
      return;
    }

    final rawDeadline = decoded['deadlineAt']?.toString();

    final parsedDeadline = rawDeadline == null
        ? null
        : DateTime.tryParse(rawDeadline)?.toUtc();

    if (!mounted) return;

    setState(() {
      _title = decoded['title']?.toString() ??
          'Task in progress';
      _deadline = parsedDeadline;
      _expiryScheduled = false;
    });

    _closeTimer?.cancel();
  } catch (e) {
    debugPrint('Invalid overlay data: $e');
  }
}


  Duration get _remaining {
    if (_deadline == null) return Duration.zero;

    final value =
        _deadline!.difference(DateTime.now().toUtc());

    return value.isNegative ? Duration.zero : value;
  }

  String get _countdown {
    if (_deadline == null) return '--:--:--';

    final seconds = _remaining.inSeconds;
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;

    return '${h.toString().padLeft(2, '0')}:'
        '${m.toString().padLeft(2, '0')}:'
        '${s.toString().padLeft(2, '0')}';
  }

  void _checkExpiry() {
    if (_deadline == null ||
        _remaining.inSeconds > 0 ||
        _expiryScheduled) {
      return;
    }

    _expiryScheduled = true;

    _closeTimer = Timer(
      const Duration(seconds: 15),
      () => unawaited(_closeOverlay()),
    );
  }

  Future<void> _closeOverlay() async {
    try {
      await FlutterOverlayWindow.closeOverlay();
    } catch (e) {
      debugPrint('Close overlay failed: $e');
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _ticker?.cancel();
    _closeTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expired =
        _deadline != null && _remaining.inSeconds == 0;

    return Material(
      color: Colors.transparent,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final width =
              constraints.maxWidth.isFinite &&
                      constraints.maxWidth > 0
                  ? constraints.maxWidth
                  : 320.0;

          final height =
              constraints.maxHeight.isFinite &&
                      constraints.maxHeight > 0
                  ? constraints.maxHeight
                  : 150.0;

          final tiny = height < 70;
          final compact = height < 110 || width < 270;

          final horizontalPadding = width < 270 ? 8.0 : 14.0;

          final verticalPadding = tiny
              ? 3.0
              : compact
                  ? 6.0
                  : (height * 0.07)
                      .clamp(8.0, 12.0)
                      .toDouble();

          final logoSize = tiny
              ? 24.0
              : compact
                  ? 34.0
                  : 54.0;

          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _openLearn,
            child: Container(
              width: width,
              height: height,
              padding: EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              decoration: BoxDecoration(
                color: purple,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(
                  color: lavender,
                  width: 1,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0x55000000),
                    blurRadius: 12,
                    offset: Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: logoSize,
                    height: logoSize,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.16),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Text(
                      'E',
                      style: TextStyle(
                        fontSize: compact ? 20 : 30,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  SizedBox(width: compact ? 7 : 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (!tiny) ...[
                          Text(
                            expired
                                ? "TIME'S UP"
                                : 'EVOLYN • TASK IN PROGRESS',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: lavender,
                              fontSize: compact ? 8 : 10,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          SizedBox(height: compact ? 2 : 5),
                        ],
                        Text(
                          _title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: compact ? 10 : 13,
                            height: 1.15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(height: compact ? 2 : 5),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            _countdown,
                            maxLines: 1,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: tiny
                                  ? 13
                                  : compact
                                      ? 16
                                      : 23,
                              height: 1.1,
                              fontWeight: FontWeight.w900,
                              letterSpacing: compact ? 0.5 : 1.2,
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
        },
      ),
    );
  }
}
