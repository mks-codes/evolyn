import 'dart:async';
import 'dart:convert';
import 'package:evolyn/core/widgets/top_message.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, kIsWeb, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:url_launcher/url_launcher.dart';
import 'package:evolyn/core/widgets/page_auto_refresh.dart';
import 'package:evolyn/features/learn/providers/learn_cache_provider.dart';
import 'package:evolyn/features/roadmap/providers/roadmap_cache_provider.dart';
import 'package:evolyn/l10n/app_localizations.dart';
import '../../learn/widgets/overlay_permission_disclosure.dart';
import 'package:showcaseview/showcaseview.dart';
import 'package:evolyn/core/services/guided_tour_service.dart';

class LearnScreen extends ConsumerStatefulWidget {
  const LearnScreen({super.key, this.isActive = true});

  final bool isActive;

  @override
  ConsumerState<LearnScreen> createState() => _LearnScreenState();
}

class _LearnScreenState extends ConsumerState<LearnScreen>
    with WidgetsBindingObserver {
  static const Color _background = Color(0xFF050614);
  static const Color _panel = Color(0xFF101126);
  static const Color _border = Color(0xFF292A46);
  static const Color _purple = Color(0xFFA78BFA);
  static const Color _cyan = Color(0xFF63D9DD);
  static const Color _green = Color(0xFF59D9A7);
  static const Color _gold = Color(0xFFFFC857);

  static final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  static bool _notificationsInitialized = false;
  static final Stream<dynamic> _overlayEvents = FlutterOverlayWindow
      .overlayListener
      .asBroadcastStream();
  final TextEditingController _searchController = TextEditingController();
  final AudioPlayer _startSoundPlayer = AudioPlayer();
  final AudioPlayer _finishedSoundPlayer = AudioPlayer();
  final Set<String> _busyTaskKeys = <String>{};

  Timer? _ticker;
  StreamSubscription<dynamic>? _overlaySubscription;
  bool _checkingExpiredTasks = false;
  bool _appInForeground = true;
  bool _showingPendingOverlay = false;
  String? _pendingOverlayPayload;
  String? _pendingOverlayTitle;
  // Keep stable, non-localized values in state and translate only their labels.
  String _selectedStatus = 'All';
  String _selectedCategory = 'All';
  String? _activeTaskIdentity;
  String? _startingTaskIdentity;
  static const List<String> _statusFilters = <String>[
    'All',
    'To do',
    'In progress',
    'Completed',
    'Saved',
  ];

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  bool get _supportsFloatingOverlay =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

final GlobalKey _tourPrimaryActionKey = GlobalKey();
final GlobalKey _tourSearchKey = GlobalKey();
final GlobalKey _tourSecondaryActionKey = GlobalKey();

bool _tourStartInProgress = false;
bool _tourStartedThisMount = false;
bool _tourAlreadySeenThisMount = false;
bool _tourAutoStartScheduled = false;

String? _tourStateUserId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _appInForeground = true;

    if (_supportsFloatingOverlay) {
      _overlaySubscription = _overlayEvents.listen((event) async {
        // The overlay uses this handshake when its Flutter engine is ready.
        if (event != 'evolyn_overlay_ready' || _appInForeground) return;
        final payload = _pendingOverlayPayload;
        if (payload == null) return;
        try {
          // Recheck in case the app resumed while this callback was waiting.
          if (!_appInForeground) {
            await FlutterOverlayWindow.shareData(payload);
          }
        } catch (e) {
          debugPrint('[LearnScreen] Overlay data delivery failed: $e');
        }
      });
    }

    _ticker = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(_handleTimerTick()),
    );
    unawaited(_initializeTaskNotifications());
  }


void _scheduleLearnTour(String userId) {
  // Keep completion state separate when the authenticated user changes.
  if (_tourStateUserId != userId) {
    _tourStateUserId = userId;
    _tourStartedThisMount = false;
    _tourAlreadySeenThisMount = false;
  }

  if (_tourAutoStartScheduled ||
      _tourStartInProgress ||
      _tourStartedThisMount ||
      _tourAlreadySeenThisMount) {
    return;
  }

  _tourAutoStartScheduled = true;

  // Wait until the Showcase widgets have been laid out.
  WidgetsBinding.instance.addPostFrameCallback((_) {
    _tourAutoStartScheduled = false;

    if (!mounted) return;

    unawaited(
      _maybeStartTour(
        screenId: 'learn',
        targetKeys: <GlobalKey>[
          _tourPrimaryActionKey,
          _tourSearchKey,
          _tourSecondaryActionKey,
        ],
      ),
    );
  });
}

Future<void> _maybeStartTour({
  required String screenId,
  required List<GlobalKey> targetKeys,
  bool force = false,
}) async {
  if (!mounted || _tourStartInProgress) return;

  if (!force &&
      (_tourStartedThisMount || _tourAlreadySeenThisMount)) {
    return;
  }

  _tourStartInProgress = true;

  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;

    if (userId == null) return;

    _tourStateUserId = userId;

    if (!force) {
      final hasSeen = await GuidedTourService.hasSeen(
        userId: userId,
        screenId: screenId,
      );

      if (hasSeen) {
        _tourAlreadySeenThisMount = true;
        return;
      }
    }

    // Allow the interface and its animations to settle.
    await Future<void>.delayed(
      const Duration(milliseconds: 350),
    );

    if (!mounted ||
        Supabase.instance.client.auth.currentUser?.id != userId) {
      return;
    }

    // Do not mark completion if any target is missing.
    if (targetKeys.any((key) => key.currentContext == null)) {
      return;
    }

    // Persist completion before starting to avoid automatic reopening
    // after rebuilds.
    await GuidedTourService.markSeen(
      userId: userId,
      screenId: screenId,
    );

    if (!mounted ||
        Supabase.instance.client.auth.currentUser?.id != userId) {
      return;
    }

    _tourStartedThisMount = true;

    ShowCaseWidget.of(context).startShowCase(targetKeys);
  } catch (error, stackTrace) {
    debugPrint('Guided tour ($screenId) failed: $error');
    debugPrintStack(stackTrace: stackTrace);
  } finally {
    _tourStartInProgress = false;
  }
}

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Hide the bubble inside Evolyn, but retain its payload so it can return
      // when the user leaves the app again.
      _appInForeground = true;
      unawaited(_closeFloatingTimer());
      unawaited(_handleTimerTick());
    } else if (state == AppLifecycleState.paused) {
      // Only create/show the bubble after the app moves into the background.
      _appInForeground = false;
      unawaited(_showPendingFloatingTimer());
    }
  }

  Map<String, dynamic>? _updatedTaskFromRow(
    Map<String, dynamic> row,
    _LearningTask task,
  ) {
    final roadmapData = _asMap(row['roadmap_data']);
    var phases = _asMapList(roadmapData['phases']);
    if (phases.isEmpty) phases = _asMapList(row['phases']);

    if (task.phaseIndex < 0 || task.phaseIndex >= phases.length) {
      return null;
    }

    final phaseTasks = _asMapList(phases[task.phaseIndex]['tasks']);
    if (task.taskIndex < 0 || task.taskIndex >= phaseTasks.length) {
      return null;
    }

    return phaseTasks[task.taskIndex];
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _ticker?.cancel();
    _searchController.dispose();
    unawaited(_startSoundPlayer.dispose());
    unawaited(_finishedSoundPlayer.dispose());
    unawaited(_overlaySubscription?.cancel());
    super.dispose();
  }

  /// Stores/updates the active task timer. It deliberately does not show the
  /// overlay while the main Evolyn app is foregrounded.
  Future<void> _showOrUpdateFloatingTimer(
    _LearningTask task,
    DateTime deadline,
    int durationSeconds,
  ) async {
    if (!_supportsFloatingOverlay) return;

    try {
    // 1. Explain the overlay permission before checking/requesting it.
    final mayContinue =
        await OverlayPermissionDisclosure.showIfNeeded(context);

    // "Not now" means: keep the study timer, but skip the floating overlay.
    if (!mayContinue || !mounted) return;

      var permitted = await FlutterOverlayWindow.isPermissionGranted();
      if (!permitted) {
        final requested = await FlutterOverlayWindow.requestPermission();
        if (requested == true) {
          permitted = await FlutterOverlayWindow.isPermissionGranted();
        }
      }

      if (!permitted) {
        if (_appInForeground) {
          _showMessage(_l10n.learnTimerPermissionMessage);
        }
        return;
      }

      _pendingOverlayPayload = jsonEncode(<String, dynamic>{
        'type': 'task_timer',
        'title': task.title,
        'deadlineAt': deadline.toUtc().toIso8601String(),
        'plannedHours': (durationSeconds / 3600).ceil(),
        'plannedDurationSeconds': durationSeconds,
        'taskIdentity': _taskIdentity(task),
      });
      _pendingOverlayTitle = task.title;

      // A task may be started while Evolyn is open, but its bubble must remain
      // hidden until lifecycle state changes to paused.
      if (_appInForeground) {
        await _closeFloatingTimer();
        return;
      }

      await _showPendingFloatingTimer();
    } catch (e) {
      debugPrint('[LearnScreen] Floating timer failed: $e');
      if (_appInForeground) {
        _showMessage(_l10n.learnOverlayPrepareError);
      }
    }
  }

  /// Shows the pending bubble only when Evolyn is backgrounded.
  Future<void> _showPendingFloatingTimer() async {
    if (!_supportsFloatingOverlay ||
        _appInForeground ||
        !mounted ||
        _showingPendingOverlay) {
      return;
    }

    final payload = _pendingOverlayPayload;
    final title = _pendingOverlayTitle;
    if (payload == null || title == null) return;

    _showingPendingOverlay = true;
    try {
      if (_appInForeground) return;

      final alreadyActive = await FlutterOverlayWindow.isActive();
      if (_appInForeground) {
        if (alreadyActive) await _closeFloatingTimer();
        return;
      }

      // Reuse the current overlay rather than creating a second one.
      if (alreadyActive) {
        await FlutterOverlayWindow.shareData(payload);
        return;
      }

      if (!mounted || _appInForeground) return;
      final screenSize = MediaQuery.of(context).size;
      final overlayWidth = (screenSize.width * 0.92)
          .clamp(240.0, 360.0)
          .round();
      final overlayHeight = (screenSize.height * 0.18)
          .clamp(140.0, 185.0)
          .round();

      await FlutterOverlayWindow.showOverlay(
        width: overlayWidth,
        height: overlayHeight,
        alignment: OverlayAlignment.centerRight,
        enableDrag: true,
        positionGravity: PositionGravity.none,
        overlayTitle: 'Evolyn task timer',
        overlayContent: title,
      );

      // Give the overlay engine time to attach its listener before sending data.
      await Future<void>.delayed(const Duration(milliseconds: 500));

      // The user may have returned to Evolyn while the overlay was starting.
      if (_appInForeground) {
        await _closeFloatingTimer();
        return;
      }

      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.shareData(payload);
      }
    } catch (e) {
      debugPrint('[LearnScreen] Could not show floating timer: $e');
    } finally {
      _showingPendingOverlay = false;
    }
  }

  /// Hides the overlay without clearing the timer data.
  Future<void> _closeFloatingTimer() async {
    if (!_supportsFloatingOverlay) return;
    try {
      if (await FlutterOverlayWindow.isActive()) {
        await FlutterOverlayWindow.closeOverlay();
      }
    } catch (e) {
      debugPrint('[LearnScreen] Close timer failed: $e');
    }
  }

  /// Clears both the active overlay and its stored task data.
  Future<void> _clearFloatingTimer() async {
    _pendingOverlayPayload = null;
    _pendingOverlayTitle = null;
    await _closeFloatingTimer();
  }

  @override
  Widget build(BuildContext context) {
    return PageAutoRefresh(
      isActive: widget.isActive,
      onRefresh: _refreshVisiblePage,
      child: _buildScreenContent(context),
    );
  }

  Widget _buildScreenContent(BuildContext context) {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      return Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Center(
            child: Text(
              _l10n.learnSignInPrompt,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    final roadmapAsync = ref.watch(userRoadmapProvider(userId));
    final learnAsync = ref.watch(userLearnRowsProvider(userId));
    final roadmapRow = roadmapAsync.asData?.value;
    final learnRows = learnAsync.asData?.value ?? <LearnRow>[];

    if (roadmapRow == null && roadmapAsync.isLoading) {
      return const Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Center(child: CircularProgressIndicator(color: _purple)),
        ),
      );
    }

    if (roadmapRow == null && roadmapAsync.hasError) {
      return Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: _feedbackState(
            icon: Icons.cloud_off_outlined,
            title: _l10n.learnLoadingErrorTitle,
            message: _l10n.learnLoadingErrorMessage,
            buttonLabel: _l10n.learnRetry,
            onPressed: () => _refresh(userId),
          ),
        ),
      );
    }

    final tasks = _tasksFromRoadmap(roadmapRow, learnRows);
    final categories =
        <String>{'All', ...tasks.map((task) => task.category)}.toList()
          ..sort((a, b) {
            if (a == 'All') return -1;
            if (b == 'All') return 1;
            return a.toLowerCase().compareTo(b.toLowerCase());
          });
    final filteredTasks = _filterTasks(tasks);

    _LearningTask? activeSessionTask;

    for (final task in tasks) {
      if (task.status == 'in_progress' &&
          task.startedAt != null &&
          task.deadlineAt != null) {
        activeSessionTask = task;
        break;
      }
    }

    _LearningTask? nextTask;
    for (final task in tasks) {
      if (task.status == 'in_progress') {
        nextTask = task;
        break;
      }
    }
    if (nextTask == null) {
      for (final task in tasks) {
        if (task.status != 'completed') {
          nextTask = task;
          break;
        }
      }
    }

    // Only start the Learn tour when a task action and the other targets
// can be rendered.
if (nextTask != null && tasks.isNotEmpty) {
  _scheduleLearnTour(userId);
}

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: RefreshIndicator(
          color: _purple,
          backgroundColor: _panel,
          onRefresh: () => _refresh(userId),
          child: SingleChildScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(roadmapRow),
                const SizedBox(height: 20),
                if (learnAsync.hasError)
                  _buildNotice(
                    _l10n.learnPreferencesSyncWarning,
                    onRetry: () => _refresh(userId),
                  ),
                if (roadmapRow == null) ...[
                  const SizedBox(height: 4),
                  _buildNoRoadmapState(),
                ] else if (tasks.isEmpty) ...[
                  _buildNoTasksState(),
                ] else ...[
                  _buildSummary(tasks),
                  const SizedBox(height: 16),

                  if (activeSessionTask != null) ...[
                    _buildActiveTaskCard(activeSessionTask),
                    const SizedBox(height: 20),
                  ] else ...[
                    const SizedBox(height: 4),
                  ],

                  if (nextTask != null)
                    _buildContinueCard(
                      nextTask,
                      userId: userId,
                      roadmapRow: roadmapRow,
                    )
                  else
                    _buildAllCompleteCard(),
                  const SizedBox(height: 24),
                  _buildSearchField(),
                  const SizedBox(height: 12),
                  _buildFilters(categories),
                  const SizedBox(height: 22),
                  _buildTaskListHeader(filteredTasks.length, tasks.length),
                  const SizedBox(height: 12),
                  if (filteredTasks.isEmpty)
                    _buildNoMatchingTasks()
                  else
                    ...filteredTasks.map(
                      (task) => _buildTaskCard(
                        task,
                        userId: userId,
                        roadmapRow: roadmapRow,
                      ),
                    ),
                  const SizedBox(height: 15),
                  _buildAaryaTip(),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _refreshVisiblePage() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final succeeded = await _refreshData(userId);

    // Let PageAutoRefresh know that the attempt failed, so it can retry later.
    if (!succeeded) {
      throw StateError('One or more learning data sources failed to refresh.');
    }
  }

  Future<void> _refresh(String userId) async {
    // Used by your existing pull-to-refresh and Retry buttons.
    // Preserve their current behavior without throwing on a network failure.
    await _refreshData(userId);
  }

  Future<bool> _refreshData(String userId) async {
    var succeeded = true;

    try {
      await ref.read(roadmapCacheRepositoryProvider).refresh(userId);
    } catch (error) {
      succeeded = false;
      debugPrint('[LearnScreen] Roadmap refresh failed: $error');
    }

    try {
      await ref.read(learnCacheRepositoryProvider).refresh(userId);
    } catch (error) {
      succeeded = false;
      debugPrint('[LearnScreen] Learn refresh failed: $error');
    }

    if (mounted) {
      // Reload the providers after the repositories have updated their caches.
      // The watched providers then rebuild the visible learning screen.
      ref.invalidate(userRoadmapProvider(userId));
      ref.invalidate(userLearnRowsProvider(userId));
    }

    return succeeded;
  }

  List<_LearningTask> _tasksFromRoadmap(
    Map<String, dynamic>? row,
    List<LearnRow> learnRows,
  ) {
    if (row == null) return <_LearningTask>[];
    final roadmapId = row['id']?.toString() ?? '';
    final roadmapData = _asMap(row['roadmap_data']);
    var rawPhases = roadmapData['phases'];
    if (rawPhases is! List || rawPhases.isEmpty) rawPhases = row['phases'];
    if (rawPhases is! List) return <_LearningTask>[];

    final states = <String, LearnRow>{};
    for (final learnRow in learnRows) {
      if (learnRow['roadmap_id']?.toString() == roadmapId) {
        final key = learnRow['task_key']?.toString();
        if (key != null) states[key] = learnRow;
      }
    }

    final result = <_LearningTask>[];
    for (var phaseIndex = 0; phaseIndex < rawPhases.length; phaseIndex++) {
      final rawPhase = rawPhases[phaseIndex];
      if (rawPhase is! Map) continue;
      final phase = Map<String, dynamic>.from(rawPhase);
      final phaseNumber = _int(phase['phase_number'], fallback: phaseIndex + 1);
      final phaseTitle = phase['title']?.toString().trim().isNotEmpty == true
          ? phase['title'].toString()
          : _l10n.learnTaskPhaseFallback(phaseNumber);
      final rawTasks = phase['tasks'];
      if (rawTasks is! List) continue;

      for (var taskIndex = 0; taskIndex < rawTasks.length; taskIndex++) {
        final rawTask = rawTasks[taskIndex];
        if (rawTask is! Map) continue;
        final task = Map<String, dynamic>.from(rawTask);
        final taskId = task['id']?.toString();
        final taskKey = taskId != null && taskId.trim().isNotEmpty
            ? taskId
            : 'phase_${phaseNumber}_task_${taskIndex + 1}';
        final learnRow = states[taskKey];
        final roadmapStatus = task['status']?.toString().trim().toLowerCase();
        final learnStatus = learnRow?['status']
            ?.toString()
            .trim()
            .toLowerCase();
        final taskCompleted =
            task['completed'] == true ||
            roadmapStatus == 'completed' ||
            roadmapStatus == 'done' ||
            roadmapStatus == 'finished' ||
            (roadmapStatus == null && learnStatus == 'completed');
        final rawStatus = roadmapStatus ?? learnStatus ?? 'not_started';
        final status = taskCompleted
            ? 'completed'
            : (rawStatus == 'in_progress' ? 'in_progress' : 'not_started');
        final taskTrackedSeconds =
            _nullableInt(task['actual_duration_seconds']) ??
            ((_nullableInt(task['actual_duration_minutes']) ?? 0) * 60);
        final estimateSeconds =
            (_double(learnRow?['estimated_hours'] ?? task['estimated_hours']) *
                    3600)
                .round();
        final liveSessionSeconds =
            status == 'in_progress' &&
                _parseDateTime(task['deadline_at']) != null &&
                _parseDateTime(task['started_at']) != null
            ? DateTime.now()
                  .difference(_parseDateTime(task['started_at'])!)
                  .inSeconds
                  .clamp(
                    0,
                    _nullableInt(task['planned_duration_seconds']) ??
                        ((_nullableInt(task['planned_duration_hours']) ?? 0) *
                            3600),
                  )
            : 0;
        final trackedWithLiveSession = taskTrackedSeconds + liveSessionSeconds;
        final calculatedProgress = estimateSeconds > 0
            ? ((trackedWithLiveSession / estimateSeconds) * 100)
                  .floor()
                  .clamp(0, taskCompleted ? 100 : 99)
                  .toInt()
            : 0;
        final savedProgress = _int(
          learnRow?['progress_percent'] ?? task['progress_percent'],
        );
        final progress = taskCompleted
            ? 100
            : (savedProgress > calculatedProgress
                      ? savedProgress
                      : calculatedProgress)
                  .clamp(0, 99)
                  .toInt();

        final category = _prettyCategory(
          learnRow?['category'] ?? task['category'],
        );

        final plannedDurationHours = _nullableInt(
          task['planned_duration_hours'],
        );

        final plannedDurationSeconds =
            _nullableInt(task['planned_duration_seconds']) ??
            (plannedDurationHours != null ? plannedDurationHours * 3600 : null);

        result.add(
          _LearningTask(
            plannedDurationSeconds: plannedDurationSeconds,
            roadmapId: roadmapId,
            taskKey: taskKey,
            phaseIndex: phaseIndex,
            taskIndex: taskIndex,
            phaseNumber: phaseNumber,
            phaseTitle: phaseTitle,
            title: task['title']?.toString().trim().isNotEmpty == true
                ? task['title'].toString()
                : _l10n.learnTaskFallback(taskIndex + 1),
            description:
                (learnRow?['task_description'] ?? task['description'] ?? '')
                    .toString(),
            category: category,
            rawCategory:
                (learnRow?['category'] ?? task['category'] ?? 'general')
                    .toString(),
            priority: (learnRow?['priority'] ?? task['priority'] ?? 'medium')
                .toString(),
            estimatedHours: _double(
              learnRow?['estimated_hours'] ?? task['estimated_hours'],
            ),
            dueWeek: _int(learnRow?['due_week'] ?? task['due_week']),
            deliverable: (learnRow?['deliverable'] ?? task['deliverable'] ?? '')
                .toString(),
            successCriteria:
                (learnRow?['success_criteria'] ??
                        task['success_criteria'] ??
                        '')
                    .toString(),
            status: status,
            progressPercent: progress,
            isBookmarked: learnRow?['is_bookmarked'] == true,
            resourceTitle: learnRow?['resource_title']?.toString(),
            resourceType:
                learnRow?['resource_type']?.toString() ?? 'roadmap_task',
            resourceUrl: learnRow?['resource_url']?.toString(),
            resourceProvider: learnRow?['resource_provider']?.toString(),
            notes: learnRow?['notes']?.toString(),
            startedAt: _parseDateTime(task['started_at']),
            deadlineAt: _parseDateTime(task['deadline_at']),
            plannedDurationHours: _nullableInt(task['planned_duration_hours']),
            actualDurationSeconds: taskTrackedSeconds,
            learnRow: learnRow,
          ),
        );
      }
    }

    result.sort((a, b) {
      if (a.status == 'in_progress' && b.status != 'in_progress') return -1;
      if (b.status == 'in_progress' && a.status != 'in_progress') return 1;
      if (a.status == 'completed' && b.status != 'completed') return 1;
      if (b.status == 'completed' && a.status != 'completed') return -1;
      if (a.phaseNumber != b.phaseNumber) {
        return a.phaseNumber.compareTo(b.phaseNumber);
      }
      return a.taskIndex.compareTo(b.taskIndex);
    });
    return result;
  }

  _LearningTask? _findInProgressTask(
    String userId,
    Map<String, dynamic> fallbackRoadmapRow,
  ) {
    final roadmapRow =
        ref.read(userRoadmapProvider(userId)).asData?.value ??
        fallbackRoadmapRow;
    final learnRows =
        ref.read(userLearnRowsProvider(userId)).asData?.value ?? <LearnRow>[];

    for (final task in _tasksFromRoadmap(roadmapRow, learnRows)) {
      // An expired timer still counts as the active session until its final
      // elapsed time has been persisted by _handleTimerTick().
      if (task.status == 'in_progress' &&
          task.startedAt != null &&
          task.deadlineAt != null) {
        return task;
      }
    }
    return null;
  }

  List<_LearningTask> _filterTasks(List<_LearningTask> tasks) {
    final query = _searchController.text.trim().toLowerCase();
    return tasks.where((task) {
      final matchesStatus = switch (_selectedStatus) {
        'To do' => task.status == 'not_started',
        'In progress' => task.status == 'in_progress',
        'Completed' => task.status == 'completed',
        'Saved' => task.isBookmarked,
        _ => true,
      };
      final matchesCategory =
          _selectedCategory == 'All' || task.category == _selectedCategory;
      final matchesQuery =
          query.isEmpty ||
          task.title.toLowerCase().contains(query) ||
          task.description.toLowerCase().contains(query) ||
          task.phaseTitle.toLowerCase().contains(query) ||
          task.category.toLowerCase().contains(query) ||
          task.deliverable.toLowerCase().contains(query);
      return matchesStatus && matchesCategory && matchesQuery;
    }).toList();
  }

  String _statusFilterLabel(String filter) => switch (filter) {
    'All' => _l10n.learnFilterAll,
    'To do' => _l10n.learnFilterToDo,
    'In progress' => _l10n.learnFilterInProgress,
    'Completed' => _l10n.learnFilterCompleted,
    'Saved' => _l10n.learnFilterSaved,
    _ => filter,
  };

  Widget _buildHeader(Map<String, dynamic>? roadmapRow) {
    final roadmapData = _asMap(roadmapRow?['roadmap_data']);
    final title =
        (roadmapData['title'] ?? roadmapRow?['title'] ?? 'your roadmap')
            .toString();
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _l10n.learnHeaderEyebrow,
                style: const TextStyle(
                  color: _purple,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                _l10n.learnHeaderTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                _l10n.learnHeaderSubtitle(title),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.43),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildSummary(List<_LearningTask> tasks) {
    final completed = tasks.where((task) => task.status == 'completed').length;
    final inProgress = tasks
        .where((task) => task.status == 'in_progress')
        .length;
    final saved = tasks.where((task) => task.isBookmarked).length;
    final remainingHours = tasks
        .where((task) => task.status != 'completed')
        .fold<double>(0, (sum, task) => sum + task.estimatedHours);
    final completion = tasks.isEmpty
        ? 0
        : (completed / tasks.length * 100).round();

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Row(
            children: [
              _metric(
                icon: Icons.check_circle_outline_rounded,
                value: '$completed/${tasks.length}',
                label: _l10n.learnTasksDone,
                color: _green,
              ),
              _summaryDivider(),
              _metric(
                icon: Icons.schedule_rounded,
                value: _formatHours(remainingHours),
                label: _l10n.learnTimeRemaining,
                color: _cyan,
              ),
              _summaryDivider(),
              _metric(
                icon: Icons.bookmark_outline_rounded,
                value: '$saved',
                label: _l10n.learnSavedTasks,
                color: _gold,
              ),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: tasks.isEmpty ? 0 : completed / tasks.length,
                    minHeight: 5,
                    backgroundColor: Colors.white.withOpacity(0.07),
                    valueColor: const AlwaysStoppedAnimation<Color>(_green),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$completion%',
                style: const TextStyle(
                  color: _green,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 7),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              _l10n.learnProgressFootnote(inProgress),
              style: TextStyle(
                color: Colors.white.withOpacity(0.35),
                fontSize: 9,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _metric({
    required IconData icon,
    required String value,
    required String label,
    required Color color,
  }) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(height: 7),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.38),
              fontSize: 8,
            ),
          ),
        ],
      ),
    );
  }

  Widget _summaryDivider() => Container(
    width: 1,
    height: 43,
    margin: const EdgeInsets.symmetric(horizontal: 7),
    color: Colors.white.withOpacity(0.08),
  );

  Widget _buildActiveTaskCard(_LearningTask task) {
    final color = _purple;
    final timerText = _timerLabel(task) ?? _l10n.learnSessionTimeUp;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF211946), Color(0xFF11152B), Color(0xFF101126)],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF4D477F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withOpacity(0.13),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: _BlinkingActiveIndicator(color: color, size: 12),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    _BlinkingActiveIndicator(color: color, size: 8),
                    const SizedBox(width: 6),
                    Text(
                      _l10n.learnStatusInProgress.toUpperCase(),
                      style: const TextStyle(
                        color: _purple,
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                Text(
                  task.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  task.phaseTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 9,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 7,
                  runSpacing: 7,
                  children: [
                    _metaPill(
                      Icons.schedule_rounded,
                      _l10n.learnEstimatedHours(
                        _formatHours(task.estimatedHours),
                      ),
                      _cyan,
                    ),
                    _metaPill(Icons.timer_outlined, timerText, _gold),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContinueCard(
    _LearningTask task, {
    required String userId,
    required Map<String, dynamic> roadmapRow,
  }) {
    final isInProgress = task.status == 'in_progress';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF211946), Color(0xFF111E2C)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF4D477F)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.play_circle_outline_rounded,
                color: Color(0xFFC0B0FF),
                size: 16,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  task.deadlineAt != null && task.startedAt != null
                      ? _l10n.learnContinueCurrentSession
                      : isInProgress
                      ? _l10n.learnContinueCurrentTask
                      : _l10n.learnNextRoadmapTask,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFFC0B0FF),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
              ),
              _statusPill(task.status),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _taskIcon(task, size: 48),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      task.title,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      '${task.phaseTitle} · ${_l10n.learnEstimatedHours(_formatHours(task.estimatedHours))}',
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.48),
                        fontSize: 10,
                      ),
                    ),
                    if (task.description.trim().isNotEmpty) ...[
                      const SizedBox(height: 7),
                      Text(
                        task.description,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.57),
                          fontSize: 10.5,
                          height: 1.45,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          if (_timerLabel(task) != null) ...[
            const SizedBox(height: 10),
            _metaPill(
              Icons.timer_outlined,
              _timerLabel(task)!,
              task.status == 'completed' ? _green : _gold,
            ),
          ],
          const SizedBox(height: 15),
          SizedBox(
            width: double.infinity,
            height: 43,
              child: Showcase(
                key: _tourPrimaryActionKey,
                title: 'Start or resume a task',
                description:
                    'Open your next learning task here. Review its details and start '
                    'a focused study session or resume your current session.',
                child: ElevatedButton.icon(
                  onPressed: _busyTaskKeys.contains(_taskIdentity(task))
                      ? null
                      : () => _openTask(
                task,
                userId: userId,
                roadmapRow: roadmapRow,
              ),
                  icon: const Icon(
                    Icons.play_arrow_rounded,
                    size: 19,
                  ),
                  label: Text(
                    task.deadlineAt != null && task.startedAt != null
                        ? _l10n.learnResumeSession
                        : isInProgress
                ? _l10n.learnStartNextSession
                : _l10n.learnOpenTaskDetails,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAllCompleteCard() => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFF10271F),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFF285441)),
    ),
    child: Row(
      children: [
        const Icon(Icons.check_circle_rounded, color: _green, size: 28),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _l10n.learnAllTasksCompleteTitle,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                _l10n.learnAllTasksCompleteMessage,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 10.5,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

Widget _buildSearchField() => Showcase(
  key: _tourSearchKey,
  title: 'Search learning tasks',
  description:
      'Type a keyword to find tasks by title, phase, category, '
      'description, or deliverable.',
  child: TextField(
    controller: _searchController,
    onChanged: (_) => setState(() {}),
    style: const TextStyle(
      color: Colors.white,
      fontSize: 12.5,
    ),
    decoration: InputDecoration(
      hintText: _l10n.learnSearchHint,
      hintStyle: TextStyle(
        color: Colors.white.withOpacity(0.29),
        fontSize: 11.5,
      ),
      prefixIcon: Icon(
        Icons.search_rounded,
        color: Colors.white.withOpacity(0.4),
        size: 20,
      ),
      suffixIcon: _searchController.text.isEmpty
          ? null
          : IconButton(
              onPressed: () {
                _searchController.clear();
                setState(() {});
              },
              icon: const Icon(
                Icons.close_rounded,
                size: 17,
              ),
              color: Colors.white54,
            ),
      filled: true,
      fillColor: _panel,
      contentPadding: const EdgeInsets.symmetric(
        vertical: 14,
      ),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(color: _border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(15),
        borderSide: const BorderSide(
          color: _purple,
          width: 1.1,
        ),
      ),
    ),
  ),
);

Widget _buildFilters(List<String> categories) => Showcase(
  key: _tourSecondaryActionKey,
  title: 'Filter your tasks',
  description:
      'Use the status filters to show tasks that are to do, in progress, '
      'completed, or saved. Use the category filters to narrow the list '
      'further.',
  child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        height: 36,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _statusFilters.length,
          separatorBuilder: (_, __) => const SizedBox(width: 7),
          itemBuilder: (context, index) {
            final filter = _statusFilters[index];
            final selected = filter == _selectedStatus;

            return ChoiceChip(
              label: Text(_statusFilterLabel(filter)),
              selected: selected,
              onSelected: (_) {
                setState(() => _selectedStatus = filter);
              },
              backgroundColor: _panel,
              selectedColor: const Color(0xFF2A1F4F),
              side: BorderSide(
                color: selected ? _purple : _border,
              ),
              labelStyle: TextStyle(
                color: selected
                    ? const Color(0xFFC5B7FF)
                    : const Color(0xFF88899F),
                fontSize: 10,
                fontWeight:
                    selected ? FontWeight.w600 : FontWeight.w400,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18),
              ),
              showCheckmark: false,
              padding: const EdgeInsets.symmetric(horizontal: 6),
            );
          },
        ),
      ),
      const SizedBox(height: 10),
      SizedBox(
        height: 34,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: categories.length,
          separatorBuilder: (_, __) => const SizedBox(width: 7),
          itemBuilder: (context, index) {
            final category = categories[index];
            final selected = category == _selectedCategory;

            return ChoiceChip(
              label: Text(
                category == 'All'
                    ? _l10n.learnFilterAll
                    : category,
              ),
              selected: selected,
              onSelected: (_) {
                setState(() => _selectedCategory = category);
              },
              backgroundColor: const Color(0xFF0D0E20),
              selectedColor: const Color(0xFF173035),
              side: BorderSide(
                color: selected ? _cyan : _border,
              ),
              labelStyle: TextStyle(
                color: selected
                    ? _cyan
                    : const Color(0xFF88899F),
                fontSize: 9.5,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              showCheckmark: false,
            );
          },
        ),
      ),
    ],
  ),
);

  Widget _buildTaskListHeader(int visibleCount, int totalCount) => Row(
    crossAxisAlignment: CrossAxisAlignment.end,
    children: [
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _l10n.learnTaskListTitle,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _l10n.learnTaskListSubtitle,
              style: const TextStyle(color: Color(0xFF77788E), fontSize: 10.5),
            ),
          ],
        ),
      ),
      Text(
        _l10n.learnVisibleTaskCount(visibleCount, totalCount),
        style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 9),
      ),
    ],
  );

  Widget _buildTaskCard(
    _LearningTask task, {
    required String userId,
    required Map<String, dynamic> roadmapRow,
  }) {
    final busy = _busyTaskKeys.contains(_taskIdentity(task));
    final color = _statusColor(task.status);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1022),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(
          color: task.status == 'completed' ? const Color(0xFF285441) : _border,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(17),
        onTap: busy
            ? null
            : () => _openTask(task, userId: userId, roadmapRow: roadmapRow),
        child: Padding(
          padding: const EdgeInsets.all(13),
          child: Column(
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _taskIcon(task, size: 45),
                  const SizedBox(width: 11),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${task.phaseTitle.toUpperCase()} · ${_l10n.learnPriority(task.priority).toUpperCase()}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: _priorityColor(task.priority),
                            fontSize: 7.8,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.35,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          task.title,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12.5,
                            fontWeight: FontWeight.w600,
                            height: 1.3,
                          ),
                        ),
                        if (task.description.trim().isNotEmpty) ...[
                          const SizedBox(height: 5),
                          Text(
                            task.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.40),
                              fontSize: 10,
                              height: 1.4,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(
                      minWidth: 32,
                      minHeight: 32,
                    ),
                    tooltip: task.isBookmarked
                        ? _l10n.learnRemoveSavedTask
                        : _l10n.learnSaveTask,
                    onPressed: busy
                        ? null
                        : () => _toggleBookmark(task, userId),
                    icon: busy
                        ? const SizedBox(
                            width: 15,
                            height: 15,
                            child: CircularProgressIndicator(
                              strokeWidth: 1.7,
                              color: _purple,
                            ),
                          )
                        : Icon(
                            task.isBookmarked
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: task.isBookmarked
                                ? _purple
                                : const Color(0xFF77788A),
                            size: 19,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 11),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _metaPill(
                    Icons.schedule_rounded,
                    _l10n.learnEstimatedHours(
                      _formatHours(task.estimatedHours),
                    ),
                    _cyan,
                  ),
                  if (_timerLabel(task) != null)
                    _metaPill(
                      Icons.timer_outlined,
                      _timerLabel(task)!,
                      task.status == 'completed' ? _green : _gold,
                    ),
                  if (task.dueWeek > 0)
                    _metaPill(
                      Icons.calendar_today_outlined,
                      _l10n.learnDueWeek(task.dueWeek),
                      const Color(0xFF8ACFD3),
                    ),
                  if (task.status == 'in_progress' &&
                      task.startedAt != null &&
                      task.deadlineAt != null)
                    _activeStatusPill(task)
                  else
                    _metaPill(
                      _statusIcon(task.status),
                      _statusLabel(task.status),
                      color,
                    ),
                  if (task.resourceUrl?.trim().isNotEmpty == true)
                    _metaPill(
                      Icons.link_rounded,
                      _l10n.learnResourceAvailable,
                      _purple,
                    ),
                ],
              ),
              if (task.progressPercent > 0 && task.status != 'completed') ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: task.progressPercent / 100,
                    minHeight: 4,
                    backgroundColor: Colors.white.withOpacity(0.07),
                    valueColor: const AlwaysStoppedAnimation<Color>(_purple),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _activeStatusPill(_LearningTask task) {
    final color = _statusColor(task.status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.09),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _BlinkingActiveIndicator(color: color, size: 10),
          const SizedBox(width: 5),
          Text(
            _statusLabel(task.status),
            style: TextStyle(
              color: color,
              fontSize: 8.5,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaPill(IconData icon, String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: color.withOpacity(0.09),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.18)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 11, color: color),
        const SizedBox(width: 4),
        Text(
          label,
          style: TextStyle(
            color: color,
            fontSize: 8.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    ),
  );

  Widget _taskIcon(_LearningTask task, {required double size}) {
    final color = _categoryColor(task.category);
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(size * 0.25),
        border: Border.all(color: color.withOpacity(0.25)),
      ),
      child: Icon(
        _categoryIcon(task.category),
        color: color,
        size: size * 0.43,
      ),
    );
  }

  Widget _buildNoRoadmapState() => _stateCard(
    icon: Icons.route_rounded,
    title: _l10n.learnNoRoadmapTitle,
    message: _l10n.learnNoRoadmapMessage,
  );

  Widget _buildNoTasksState() => _stateCard(
    icon: Icons.menu_book_outlined,
    title: _l10n.learnNoTasksTitle,
    message: _l10n.learnNoTasksMessage,
  );

  Widget _buildNoMatchingTasks() => _stateCard(
    icon: Icons.search_off_rounded,
    title: _l10n.learnNoMatchingTasksTitle,
    message: _l10n.learnNoMatchingTasksMessage,
  );

  Widget _stateCard({
    required IconData icon,
    required String title,
    required String message,
  }) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
    decoration: BoxDecoration(
      color: _panel,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: _border),
    ),
    child: Column(
      children: [
        Icon(icon, color: _purple, size: 30),
        const SizedBox(height: 11),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white.withOpacity(0.42),
            fontSize: 10.5,
            height: 1.5,
          ),
        ),
      ],
    ),
  );

  Widget _buildNotice(String text, {required VoidCallback onRetry}) =>
      Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(
          color: const Color(0xFF2B2418),
          borderRadius: BorderRadius.circular(11),
          border: Border.all(color: const Color(0xFF6B5428)),
        ),
        child: Row(
          children: [
            const Icon(Icons.sync_problem_outlined, color: _gold, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: const TextStyle(
                  color: Color(0xFFFFDDA0),
                  fontSize: 10,
                  height: 1.4,
                ),
              ),
            ),
            IconButton(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, color: _gold, size: 18),
              tooltip: _l10n.learnSyncNoticeRetry,
            ),
          ],
        ),
      );

  Widget _feedbackState({
    required IconData icon,
    required String title,
    required String message,
    required String buttonLabel,
    required VoidCallback onPressed,
  }) => Center(
    child: Padding(
      padding: const EdgeInsets.all(26),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: _purple, size: 38),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white70, height: 1.45),
          ),
          const SizedBox(height: 15),
          OutlinedButton(onPressed: onPressed, child: Text(buttonLabel)),
        ],
      ),
    ),
  );

  Widget _buildAaryaTip() => Container(
    padding: const EdgeInsets.all(13),
    decoration: BoxDecoration(
      color: const Color(0xFF0C1020),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFF26344A)),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Icon(Icons.auto_awesome_rounded, color: _cyan, size: 17),
        const SizedBox(width: 9),
        Expanded(
          child: Text(
            _l10n.learnAaryaTip,
            style: TextStyle(
              color: Colors.white.withOpacity(0.43),
              fontSize: 10,
              height: 1.45,
            ),
          ),
        ),
      ],
    ),
  );

  Future<int?> _selectTaskDuration(_LearningTask task) {
    final estimatedSeconds = task.estimatedHours > 0
        ? (task.estimatedHours * 3600).round()
        : 0;

    // Reopening a completed task starts a new tracking cycle.
    final alreadyTrackedSeconds = task.status == 'completed'
        ? 0
        : (task.actualDurationSeconds ?? 0);

    final remainingSeconds = estimatedSeconds > 0
        ? (estimatedSeconds - alreadyTrackedSeconds)
              .clamp(1, estimatedSeconds)
              .toInt()
        : 4 * 3600;

    final options = <int>[
      2 * 3600,
      3 * 3600,
      4 * 3600,
    ].where((seconds) => seconds <= remainingSeconds).toList();
    if (options.isEmpty) options.add(remainingSeconds);

    var selectedSeconds = options.first;

    return showDialog<int>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          backgroundColor: const Color(0xFF15162C),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: const BorderSide(color: _border),
          ),
          title: Text(
            _l10n.learnDurationDialogTitle,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                task.estimatedHours > 0
                    ? _l10n.learnDurationEstimatedTotal(
                        _formatHours(task.estimatedHours),
                        _formatElapsed(alreadyTrackedSeconds),
                      )
                    : _l10n.learnDurationNoEstimate,
                style: const TextStyle(color: Colors.white70, height: 1.45),
              ),
              const SizedBox(height: 12),
              ...options.map(
                (seconds) => RadioListTile<int>(
                  value: seconds,
                  groupValue: selectedSeconds,
                  activeColor: _purple,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    _formatSessionDuration(seconds),
                    style: const TextStyle(color: Colors.white),
                  ),
                  onChanged: (value) {
                    if (value != null) {
                      setDialogState(() => selectedSeconds = value);
                    }
                  },
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(_l10n.learnCancel),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF8B5CF6),
                foregroundColor: Colors.white,
              ),
              onPressed: () => Navigator.of(dialogContext).pop(selectedSeconds),
              child: Text(
                _l10n.learnStartDuration(
                  _formatSessionDuration(selectedSeconds),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatSessionDuration(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    final remainingSeconds = safeSeconds % 60;

    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    if (minutes > 0) return '${minutes}m';
    return '${remainingSeconds}s';
  }

  Future<void> _openTask(
    _LearningTask task, {
    required String userId,
    required Map<String, dynamic> roadmapRow,
  }) async {
    final currentTask = _findInProgressTask(userId, roadmapRow);

    final currentIdentity = currentTask != null
        ? _taskIdentity(currentTask)
        : (_activeTaskIdentity ?? _startingTaskIdentity);

    final hasOtherTaskInProgress =
        currentIdentity != null && currentIdentity != _taskIdentity(task);

    final currentTaskTitle = currentTask?.title ?? 'Another task';
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF101124),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 38,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white24,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _taskIcon(task, size: 48),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          task.phaseTitle,
                          style: const TextStyle(
                            color: _purple,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          task.title,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            height: 1.3,
                          ),
                        ),
                        const SizedBox(height: 7),
                        _statusPill(task.status),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 17),
              _detailSection(_l10n.learnTaskDetailsWhatToDo, task.description),
              _detailSection(
                _l10n.learnTaskDetailsDeliverable,
                task.deliverable,
              ),
              _detailSection(
                _l10n.learnTaskDetailsSuccessCriteria,
                task.successCriteria,
              ),
              const SizedBox(height: 4),
              Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  _metaPill(
                    Icons.schedule_rounded,
                    _l10n.learnEstimatedHours(
                      _formatHours(task.estimatedHours),
                    ),
                    _cyan,
                  ),
                  if (_timerLabel(task) != null)
                    _metaPill(
                      Icons.timer_outlined,
                      _timerLabel(task)!,
                      task.status == 'completed' ? _green : _gold,
                    ),
                  if (task.dueWeek > 0)
                    _metaPill(
                      Icons.calendar_today_outlined,
                      _l10n.learnDueWeek(task.dueWeek),
                      const Color(0xFF8ACFD3),
                    ),
                  _metaPill(
                    Icons.flag_outlined,
                    _l10n.learnPriority(task.priority),
                    _priorityColor(task.priority),
                  ),
                ],
              ),
              if (task.resourceUrl?.trim().isNotEmpty == true) ...[
                const SizedBox(height: 15),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF17182D),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: _border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        task.resourceTitle?.trim().isNotEmpty == true
                            ? task.resourceTitle!
                            : _l10n.learnLearningResource,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                      if (task.resourceProvider?.trim().isNotEmpty == true) ...[
                        const SizedBox(height: 4),
                        Text(
                          task.resourceProvider!,
                          style: const TextStyle(
                            color: Colors.white60,
                            fontSize: 10,
                          ),
                        ),
                      ],
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                        onPressed: () => _openResource(task.resourceUrl!),
                        icon: const Icon(Icons.open_in_new_rounded, size: 16),
                        label: Text(_l10n.learnOpenLearningResource),
                      ),
                    ],
                  ),
                ),
              ],
              if (hasOtherTaskInProgress) ...[
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2B2418),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF6B5428)),
                  ),
                  child: Text(
                    _l10n.learnAnotherTaskInProgress(currentTaskTitle),
                    style: const TextStyle(
                      color: Color(0xFFFFDDA0),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],
              if (task.notes?.trim().isNotEmpty == true)
                _detailSection('Your notes', task.notes!),
              const SizedBox(height: 19),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: hasOtherTaskInProgress
                      ? null
                      : () async {
                          final needsTimer =
                              task.status != 'in_progress' ||
                              task.deadlineAt == null;

                          final durationSeconds = needsTimer
                              ? await _selectTaskDuration(task)
                              : null;

                          if (needsTimer && durationSeconds == null) return;
                          if (!sheetContext.mounted) return;

                          Navigator.of(sheetContext).pop();

                          await _saveTaskStatus(
                            task,
                            userId: userId,
                            roadmapRow: roadmapRow,
                            newStatus: 'in_progress',
                            durationSeconds: durationSeconds,
                          );
                        },
                  icon: Icon(
                    task.status == 'in_progress'
                        ? Icons.play_arrow_rounded
                        : Icons.rocket_launch_outlined,
                  ),
                  label: Text(
                    hasOtherTaskInProgress
                        ? _l10n.learnFinishCurrentSessionFirst
                        : task.status == 'completed'
                        ? _l10n.learnReopenTask
                        : task.status == 'in_progress' &&
                              task.deadlineAt != null &&
                              task.startedAt != null
                        ? _l10n.learnContinueCurrentSessionButton
                        : task.status == 'in_progress'
                        ? _l10n.learnStartNextSession
                        : _l10n.learnStartTask,
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B5CF6),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 13),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              if (task.status == 'in_progress' &&
                  task.deadlineAt != null &&
                  task.startedAt != null) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await _saveTaskStatus(
                        task,
                        userId: userId,
                        roadmapRow: roadmapRow,
                        newStatus: 'session_finished',
                      );
                    },
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(_l10n.learnFinishSessionEarly),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: Color(0xFF285441)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
              if (task.estimatedHours <= 0 && task.status != 'completed') ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      Navigator.of(sheetContext).pop();
                      await _saveTaskStatus(
                        task,
                        userId: userId,
                        roadmapRow: roadmapRow,
                        newStatus: 'completed',
                      );
                    },
                    icon: const Icon(Icons.check_circle_outline_rounded),
                    label: Text(_l10n.learnMarkTaskCompleted),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: _green,
                      side: const BorderSide(color: Color(0xFF285441)),
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _initializeTaskNotifications() async {
    if (kIsWeb || _notificationsInitialized) return;
    try {
      tz_data.initializeTimeZones();
      final timezoneInfo = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(timezoneInfo.identifier));
      const settings = InitializationSettings(
        android: AndroidInitializationSettings('ic_notification'),
        iOS: DarwinInitializationSettings(
          requestAlertPermission: false,
          requestBadgePermission: false,
          requestSoundPermission: false,
        ),
      );
      await _notifications.initialize(settings: settings);
      _notificationsInitialized = true;
    } catch (error) {
      debugPrint('[LearnScreen] Notification initialization failed: $error');
    }
  }

  Future<void> _scheduleDeadlineNotification(
    _LearningTask task,
    DateTime deadline,
    int durationSeconds,
  ) async {
    if (kIsWeb) return;
    try {
      if (!_notificationsInitialized) await _initializeTaskNotifications();
      if (!_notificationsInitialized) return;

      final android = _notifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      final ios = _notifications
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      await ios?.requestPermissions(alert: true, badge: true, sound: true);

      var scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
      try {
        final exactPermission = await android?.requestExactAlarmsPermission();
        if (exactPermission == false) {
          scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
        }
      } catch (_) {
        scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      }

      final timerId = _notificationId(task);
      final finishId = _finishNotificationId(task);
      await _notifications.cancel(id: timerId);
      await _notifications.cancel(id: finishId);

      final remaining = deadline.difference(DateTime.now());
      if (android != null && remaining.inMilliseconds > 0) {
        await _notifications.show(
          id: timerId,
          title: _l10n.learnNotificationTimerTitle,
          body: task.title,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              'evolyn_task_timer_ongoing',
              _l10n.learnNotificationTimerChannel,
              channelDescription:
                  _l10n.learnNotificationTimerChannelDescription,
              importance: Importance.low,
              priority: Priority.low,
              ongoing: true,
              autoCancel: false,
              onlyAlertOnce: true,
              playSound: false,
              enableVibration: false,
              color: const Color(0xFFA78BFA),
              colorized: true,
              showWhen: true,
              when: deadline.millisecondsSinceEpoch,
              usesChronometer: true,
              chronometerCountDown: true,
              timeoutAfter: remaining.inMilliseconds,
            ),
          ),
          payload: _taskIdentity(task),
        );
      }

      final finishDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          'evolyn_task_timer_finished',
          _l10n.learnNotificationFinishedChannel,
          channelDescription: _l10n.learnNotificationFinishedChannelDescription,
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          color: const Color(0xFFA78BFA),
        ),
        iOS: const DarwinNotificationDetails(
          presentAlert: true,
          presentBadge: true,
          presentSound: true,
        ),
      );
      final scheduledDate = tz.TZDateTime.from(deadline.toLocal(), tz.local);
      await _notifications.zonedSchedule(
        id: finishId,
        title: _l10n.learnNotificationFinishedTitle,
        body: _l10n.learnNotificationFinishedBody(
          task.title,
          _formatSessionDuration(durationSeconds),
        ),
        scheduledDate: scheduledDate,
        notificationDetails: finishDetails,
        androidScheduleMode: scheduleMode,
        payload: _taskIdentity(task),
      );
    } catch (error) {
      debugPrint('[LearnScreen] Could not schedule task timer: $error');
      _showMessage(_l10n.learnNotificationPermissionError);
    }
  }

  Future<void> _cancelDeadlineNotification(_LearningTask task) async {
    if (kIsWeb || !_notificationsInitialized) return;
    try {
      await _notifications.cancel(id: _notificationId(task));
      await _notifications.cancel(id: _finishNotificationId(task));
    } catch (error) {
      debugPrint('[LearnScreen] Could not cancel timer notifications: $error');
    }
  }

  int _notificationId(_LearningTask task) {
    var hash = 0x811c9dc5;
    for (final unit in _taskIdentity(task).codeUnits) {
      hash = ((hash ^ unit) * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }

  int _finishNotificationId(_LearningTask task) =>
      (_notificationId(task) ^ 0x40000000) & 0x7fffffff;

  Future<void> _playStartSound() async {
    try {
      await _startSoundPlayer.play(AssetSource('sounds/task_start.wav'));
    } catch (error) {
      debugPrint('Start sound failed: $error');
    }
  }

  Future<void> _playFinishedSound() async {
    try {
      await _finishedSoundPlayer.play(AssetSource('sounds/task_finished.wav'));
    } catch (error) {
      debugPrint('Finished sound failed: $error');
    }
  }

  Future<void> _handleTimerTick() async {
    if (!mounted) return;

    // Repaint the countdown every second.
    setState(() {});
    if (_checkingExpiredTasks) return;

    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    _checkingExpiredTasks = true;
    try {
      final roadmapRow = ref.read(userRoadmapProvider(userId)).asData?.value;
      if (roadmapRow == null) return;

      final learnRows =
          ref.read(userLearnRowsProvider(userId)).asData?.value ?? <LearnRow>[];
      final tasks = _tasksFromRoadmap(roadmapRow, learnRows);
      final now = DateTime.now();

      for (final task in tasks) {
        final deadline = task.deadlineAt;
        if (task.status == 'in_progress' &&
            task.startedAt != null &&
            deadline != null &&
            !deadline.isAfter(now) &&
            !_busyTaskKeys.contains(_taskIdentity(task))) {
          await _saveTaskStatus(
            task,
            userId: userId,
            roadmapRow: roadmapRow,
            newStatus: 'session_finished',
          );
        }
      }
    } catch (error, stackTrace) {
      debugPrint('[LearnScreen] Expired task check failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    } finally {
      _checkingExpiredTasks = false;
    }
  }

  String? _timerLabel(_LearningTask task) {
    if (task.status == 'in_progress') {
      final deadline = task.deadlineAt;
      final startedAt = task.startedAt;

      if (deadline != null && startedAt != null) {
        final seconds = deadline.difference(DateTime.now()).inSeconds;
        if (seconds <= 0) return _l10n.learnSessionTimeUp;

        final hours = seconds ~/ 3600;
        final minutes = (seconds % 3600) ~/ 60;
        final remainingSeconds = seconds % 60;
        final countdown =
            '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
        return _l10n.learnSessionTimeLeft(countdown);
      }

      final tracked = task.actualDurationSeconds ?? 0;
      final estimateSeconds = task.estimatedHours > 0
          ? (task.estimatedHours * 3600).round()
          : 0;
      if (estimateSeconds > 0) {
        final remaining = estimateSeconds - tracked;
        return _l10n.learnTrackedEstimatedLeft(
          _formatElapsed(tracked),
          _formatElapsed(remaining > 0 ? remaining : 0),
        );
      }
      return tracked > 0
          ? _l10n.learnTrackedStartAnother(_formatElapsed(tracked))
          : _l10n.learnReadyToStartSession;
    }

    if (task.status == 'completed' && task.actualDurationSeconds != null) {
      return _l10n.learnTotalTime(_formatElapsed(task.actualDurationSeconds!));
    }
    if ((task.actualDurationSeconds ?? 0) > 0) {
      return _l10n.learnTrackedSoFar(
        _formatElapsed(task.actualDurationSeconds!),
      );
    }
    return null;
  }

  String _formatElapsed(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    final remainingSeconds = safeSeconds % 60;
    if (hours > 0 && minutes > 0) return '${hours}h ${minutes}m';
    if (hours > 0) return '${hours}h';
    if (minutes > 0) return '${minutes}m';
    return '${remainingSeconds}s';
  }

  DateTime? _parseDateTime(dynamic value) =>
      value == null ? null : DateTime.tryParse(value.toString());

  int? _nullableInt(dynamic value) {
    if (value == null) return null;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  Widget _detailSection(String title, String body) {
    if (body.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFFC6B8FF),
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openResource(String rawUrl) async {
    final uri = Uri.tryParse(rawUrl.trim());
    if (uri == null ||
        !(uri.scheme == 'https' || uri.scheme == 'http') ||
        uri.host.isEmpty) {
      _showMessage(_l10n.learnInvalidResourceUrl);
      return;
    }
    try {
      final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!opened) _showMessage(_l10n.learnCouldNotOpenResource);
    } catch (error) {
      debugPrint('[LearnScreen] Resource launch failed: $error');
      _showMessage(_l10n.learnCouldNotOpenResource);
    }
  }

  Future<void> _toggleBookmark(_LearningTask task, String userId) async {
    final identity = _taskIdentity(task);
    if (_busyTaskKeys.contains(identity)) return;
    setState(() => _busyTaskKeys.add(identity));
    try {
      final payload = _learnPayload(
        task,
        userId: userId,
        status: task.status,
        isBookmarked: !task.isBookmarked,
      );
      await ref
          .read(learnCacheRepositoryProvider)
          .upsertTaskState(userId, payload);
      _showMessage(
        task.isBookmarked
            ? _l10n.learnTaskRemovedFromSaved
            : _l10n.learnTaskSavedForLater,
      );
    } catch (error, stackTrace) {
      debugPrint('[LearnScreen] Bookmark save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage(_l10n.learnBookmarkSaveError);
    } finally {
      if (mounted) setState(() => _busyTaskKeys.remove(identity));
    }
  }

  Future<void> _saveTaskStatus(
    _LearningTask task, {
    required String userId,
    required Map<String, dynamic> roadmapRow,
    required String newStatus,
    int? durationSeconds,
  }) async {
    final identity = _taskIdentity(task);
    if (_busyTaskKeys.contains(identity)) return;

    final isStartingSession = newStatus == 'in_progress';
    final isEndingSession = newStatus == 'session_finished';
    final isManualCompletion = newStatus == 'completed';
    if (!isStartingSession && !isEndingSession && !isManualCompletion) {
      throw ArgumentError.value(
        newStatus,
        'newStatus',
        _l10n.learnUnsupportedTaskAction,
      );
    }

    var lockedTaskStart = false;
    if (isStartingSession && durationSeconds != null) {
      if (_startingTaskIdentity != null && _startingTaskIdentity != identity) {
        _showMessage(_l10n.learnAnotherTaskStarting);
        return;
      }

      final activeTask = _findInProgressTask(userId, roadmapRow);
      final activeIdentity = activeTask != null
          ? _taskIdentity(activeTask)
          : _startingTaskIdentity;
      if (activeIdentity != null && activeIdentity != identity) {
        _showMessage(
          _l10n.learnFinishTaskBeforeStartingAnother(
            activeTask?.title ?? 'your current task',
          ),
        );
        return;
      }

      _startingTaskIdentity = identity;
      lockedTaskStart = true;
    }

    setState(() => _busyTaskKeys.add(identity));

    try {
      final taskStartAt = isStartingSession && durationSeconds != null
          ? DateTime.now().toUtc()
          : null;

      final updatedRoadmapRow = await _updateRoadmapTask(
        task,
        userId: userId,
        roadmapRow: roadmapRow,
        newStatus: newStatus,
        durationSeconds: durationSeconds,
        startAt: taskStartAt,
      );

      final updatedTaskData = _updatedTaskFromRow(updatedRoadmapRow, task);
      final effectiveStatus =
          updatedTaskData?['status']?.toString() ?? newStatus;
      final progressPercentOverride = _nullableInt(
        updatedTaskData?['progress_percent'],
      );
      final totalTrackedSeconds =
          _nullableInt(updatedTaskData?['actual_duration_seconds']) ?? 0;

      // Publish immediately to the shared local-first roadmap feed, so Progress
      // and other screens watching the repository can repaint without a refresh.
      await ref
          .read(roadmapCacheRepositoryProvider)
          .storeLocal(userId, updatedRoadmapRow);

      if (isStartingSession) {
        final savedDeadline = _parseDateTime(updatedTaskData?['deadline_at']);
        final savedDurationSeconds =
            _nullableInt(updatedTaskData?['planned_duration_seconds']) ??
            durationSeconds ??
            ((_nullableInt(updatedTaskData?['planned_duration_hours']) ?? 0) *
                3600);

        if (savedDeadline != null && savedDeadline.isAfter(DateTime.now())) {
          _activeTaskIdentity = identity;
          if (taskStartAt != null) await _playStartSound();
          await _scheduleDeadlineNotification(
            task,
            savedDeadline,
            savedDurationSeconds,
          );
          await _showOrUpdateFloatingTimer(
            task,
            savedDeadline,
            savedDurationSeconds,
          );
        } else {
          _activeTaskIdentity = null;
        }
      } else {
        // Both natural expiry and early stop finish only this session. The
        // task remains in progress unless cumulative time meets its estimate.
        if (_activeTaskIdentity == identity) _activeTaskIdentity = null;
        await _clearFloatingTimer();
        await _cancelDeadlineNotification(task);
        await _playFinishedSound();
      }

      try {
        await ref
            .read(learnCacheRepositoryProvider)
            .upsertTaskState(
              userId,
              _learnPayload(
                task,
                userId: userId,
                status: effectiveStatus,
                isBookmarked: task.isBookmarked,
                progressPercentOverride: progressPercentOverride,
              ),
            );
      } catch (error, stackTrace) {
        debugPrint('[LearnScreen] Learn state mirror failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        _showMessage(_l10n.learnRoadmapTimeSavedLearnSyncError);
      }

      if (isEndingSession) {
        if (effectiveStatus == 'completed') {
          _showMessage(_l10n.learnTaskCompletedEstimateReached);
        } else if (task.estimatedHours > 0) {
          _showMessage(
            _l10n.learnSessionSavedTrackedOfEstimate(
              _formatElapsed(totalTrackedSeconds),
              _formatHours(task.estimatedHours),
            ),
          );
        } else {
          _showMessage(
            _l10n.learnSessionSavedNoEstimate(
              _formatElapsed(totalTrackedSeconds),
            ),
          );
        }
      } else if (isManualCompletion || effectiveStatus == 'completed') {
        _showMessage(_l10n.learnTaskMarkedCompleted);
      } else if (task.status == 'completed') {
        _showMessage(_l10n.learnTaskReopened);
      } else if (taskStartAt != null) {
        _showMessage(
          _l10n.learnSessionStarted(
            _formatSessionDuration(
              _nullableInt(updatedTaskData?['planned_duration_seconds']) ??
                  durationSeconds ??
                  0,
            ),
          ),
        );
      } else {
        _showMessage(_l10n.learnSessionResumed);
      }
    } catch (error, stackTrace) {
      debugPrint('[LearnScreen] Task status save failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      _showMessage(_l10n.learnTaskSessionSaveError);
    } finally {
      if (lockedTaskStart && _startingTaskIdentity == identity) {
        _startingTaskIdentity = null;
      }
      if (mounted) setState(() => _busyTaskKeys.remove(identity));
    }
  }

  Future<Map<String, dynamic>> _updateRoadmapTask(
    _LearningTask task, {
    required String userId,
    required Map<String, dynamic> roadmapRow,
    required String newStatus,
    int? durationSeconds,
    DateTime? startAt,
  }) async {
    final roadmapId = roadmapRow['id']?.toString();
    if (roadmapId == null || roadmapId.isEmpty) {
      throw StateError(_l10n.learnInvalidRoadmapId);
    }

    final roadmapData = _deepCopyMap(roadmapRow['roadmap_data']);
    var phases = _asMapList(roadmapData['phases']);
    if (phases.isEmpty) phases = _asMapList(roadmapRow['phases']);
    if (task.phaseIndex < 0 || task.phaseIndex >= phases.length) {
      throw StateError(_l10n.learnRoadmapPhaseChanged);
    }

    final phase = phases[task.phaseIndex];
    final phaseTasks = _asMapList(phase['tasks']);
    if (task.taskIndex < 0 || task.taskIndex >= phaseTasks.length) {
      throw StateError(_l10n.learnRoadmapTaskChanged);
    }

    final nowDateTime = DateTime.now().toUtc();
    final now = nowDateTime.toIso8601String();
    final updatedTask = Map<String, dynamic>.from(phaseTasks[task.taskIndex]);

    final estimatedSeconds = task.estimatedHours > 0
        ? (task.estimatedHours * 3600).round()
        : 0;
    var previousTrackedSeconds =
        _nullableInt(updatedTask['actual_duration_seconds']) ??
        ((_nullableInt(updatedTask['actual_duration_minutes']) ?? 0) * 60);

    if (newStatus == 'in_progress') {
      final wasCompleted =
          updatedTask['completed'] == true ||
          updatedTask['status']?.toString() == 'completed' ||
          task.status == 'completed';

      if (wasCompleted) {
        // Older versions kept only a cumulative total and then reset it when a
        // completed task was reopened. Preserve that total if no dated session
        // records exist yet; those old sessions cannot be reconstructed precisely.
        final hasSessionHistory =
            [
              'sessions',
              'time_sessions',
              'task_sessions',
              'session_logs',
              'study_sessions',
            ].any((key) {
              final value = updatedTask[key];
              return value is List && value.isNotEmpty;
            });

        if (!hasSessionHistory && previousTrackedSeconds > 0) {
          final legacySeconds =
              _nullableInt(updatedTask['legacy_tracked_seconds']) ?? 0;
          updatedTask['legacy_tracked_seconds'] =
              legacySeconds + previousTrackedSeconds;
        }

        previousTrackedSeconds = 0;
        updatedTask['actual_duration_seconds'] = 0;
        updatedTask['actual_duration_minutes'] = 0;
      }

      updatedTask['completed'] = false;
      updatedTask['status'] = 'in_progress';
      updatedTask['completed_at'] = null;
      updatedTask['finished_at'] = null;

      updatedTask['progress_percent'] = estimatedSeconds > 0
          ? ((previousTrackedSeconds / estimatedSeconds) * 100)
                .floor()
                .clamp(0, 99)
                .toInt()
          : 0;

      if (durationSeconds != null) {
        if (durationSeconds <= 0) {
          throw ArgumentError.value(
            durationSeconds,
            'durationSeconds',
            _l10n.learnDurationMustBePositive,
          );
        }

        final actualStart = (startAt ?? nowDateTime).toUtc();
        final remainingSeconds = estimatedSeconds > 0
            ? estimatedSeconds - previousTrackedSeconds
            : durationSeconds;
        if (estimatedSeconds > 0 && remainingSeconds <= 0) {
          // Safety check for stale task objects: normalize a task that has
          // already accumulated its estimated time rather than running another timer.
          updatedTask['completed'] = true;
          updatedTask['status'] = 'completed';
          updatedTask['progress_percent'] = 100;
          updatedTask['completed_at'] = now;
          updatedTask['finished_at'] = now;
          updatedTask['started_at'] = null;
          updatedTask['deadline_at'] = null;
        } else {
          final effectiveDurationSeconds =
              estimatedSeconds > 0 && remainingSeconds < durationSeconds
              ? remainingSeconds
              : durationSeconds;
          final deadline = actualStart.add(
            Duration(seconds: effectiveDurationSeconds),
          );

          updatedTask['planned_duration_seconds'] = effectiveDurationSeconds;
          // Retain compatibility with older rows that store duration in hours.
          updatedTask['planned_duration_hours'] =
              (effectiveDurationSeconds + 3599) ~/ 3600;
          updatedTask['started_at'] = actualStart.toIso8601String();
          updatedTask['deadline_at'] = deadline.toIso8601String();
        }
      }
    } else if (newStatus == 'session_finished' || newStatus == 'completed') {
      final startedAt = _parseDateTime(updatedTask['started_at']);
      final deadlineAt = _parseDateTime(updatedTask['deadline_at']);
      final plannedSessionSeconds =
          _nullableInt(updatedTask['planned_duration_seconds']) ??
          ((_nullableInt(updatedTask['planned_duration_hours']) ?? 0) * 3600);

      var sessionSeconds = startedAt == null
          ? 0
          : nowDateTime.difference(startedAt.toUtc()).inSeconds;
      if (sessionSeconds < 0) sessionSeconds = 0;

      // If the timer deadline elapsed, save the full selected session duration
      // so a one-second scheduling delay cannot leave a task at 99% forever.
      final deadlineElapsed =
          deadlineAt != null && !deadlineAt.toUtc().isAfter(nowDateTime);
      if (deadlineElapsed && plannedSessionSeconds > 0) {
        sessionSeconds = plannedSessionSeconds;
      } else if (plannedSessionSeconds > 0 &&
          sessionSeconds > plannedSessionSeconds) {
        sessionSeconds = plannedSessionSeconds;
      }

      // Save each session before started_at/deadline_at are cleared below.
      // Existing aliases are supported so older saved history is retained.
      if (startedAt != null && sessionSeconds > 0) {
        dynamic rawSessions = updatedTask['sessions'];
        rawSessions ??= updatedTask['time_sessions'];
        rawSessions ??= updatedTask['task_sessions'];
        rawSessions ??= updatedTask['session_logs'];
        rawSessions ??= updatedTask['study_sessions'];

        final savedSessions = _asMapList(rawSessions);

        // On the first session-history record, preserve any earlier cumulative
        // tracked time as a total only. Do not invent dates for that older time.
        if (savedSessions.isEmpty && previousTrackedSeconds > 0) {
          final legacySeconds =
              _nullableInt(updatedTask['legacy_tracked_seconds']) ?? 0;
          updatedTask['legacy_tracked_seconds'] =
              legacySeconds + previousTrackedSeconds;
        }

        final sessionStartUtc = startedAt.toUtc();
        // For a timer that expires, this records the scheduled end; for a session
        // stopped early, sessionSeconds reflects the actual elapsed duration.
        final sessionEndUtc = deadlineElapsed && plannedSessionSeconds > 0
            ? sessionStartUtc.add(Duration(seconds: plannedSessionSeconds))
            : nowDateTime;

        savedSessions.add(<String, dynamic>{
          'session_number': savedSessions.length + 1,
          'started_at': sessionStartUtc.toIso8601String(),
          'ended_at': sessionEndUtc.toIso8601String(),
          'duration_seconds': sessionSeconds,
          'duration_minutes': (sessionSeconds / 60).ceil(),
          'status': 'completed',
        });

        updatedTask['sessions'] = savedSessions;
      }

      final totalTrackedSeconds = previousTrackedSeconds + sessionSeconds;
      final forceComplete = newStatus == 'completed';
      final taskIsComplete =
          forceComplete ||
          (estimatedSeconds > 0 && totalTrackedSeconds >= estimatedSeconds);

      updatedTask['actual_duration_seconds'] = totalTrackedSeconds;
      updatedTask['actual_duration_minutes'] = (totalTrackedSeconds / 60)
          .ceil();
      updatedTask['completed'] = taskIsComplete;
      updatedTask['status'] = taskIsComplete ? 'completed' : 'in_progress';
      updatedTask['progress_percent'] = taskIsComplete
          ? 100
          : estimatedSeconds > 0
          ? ((totalTrackedSeconds / estimatedSeconds) * 100)
                .floor()
                .clamp(0, 99)
                .toInt()
          : 0;
      updatedTask['completed_at'] = taskIsComplete ? now : null;
      updatedTask['finished_at'] = taskIsComplete ? now : null;
      updatedTask['last_session_finished_at'] = now;
      updatedTask['started_at'] = null;
      updatedTask['deadline_at'] = null;
    } else {
      throw ArgumentError.value(
        newStatus,
        'newStatus',
        _l10n.learnUnsupportedTaskAction,
      );
    }

    phaseTasks[task.taskIndex] = updatedTask;
    phase['tasks'] = phaseTasks;
    phases[task.phaseIndex] = phase;
    roadmapData['phases'] = phases;

    final flattenedTasks = <Map<String, dynamic>>[];
    for (var phaseIndex = 0; phaseIndex < phases.length; phaseIndex++) {
      final item = phases[phaseIndex];
      final number = _int(item['phase_number'], fallback: phaseIndex + 1);
      for (final rawTask in _asMapList(item['tasks'])) {
        flattenedTasks.add(<String, dynamic>{
          ...rawTask,
          'phase_number': number,
          'phase_title': item['title']?.toString() ?? 'Phase $number',
        });
      }
    }

    final saved = await Supabase.instance.client
        .from('roadmaps')
        .update(<String, dynamic>{
          'roadmap_data': roadmapData,
          'phases': phases,
          'tasks': flattenedTasks,
          'updated_at': now,
        })
        .eq('id', roadmapId)
        .eq('user_id', userId)
        .select('*')
        .maybeSingle();

    if (saved == null) {
      throw StateError(_l10n.learnRoadmapUpdateFailed);
    }
    return Map<String, dynamic>.from(saved);
  }

  LearnRow _learnPayload(
    _LearningTask task, {
    required String userId,
    required String status,
    required bool isBookmarked,
    int? progressPercentOverride,
  }) {
    final now = DateTime.now().toUtc().toIso8601String();
    final safeProgress = progressPercentOverride ?? task.progressPercent;

    return <String, dynamic>{
      'user_id': userId,
      'roadmap_id': task.roadmapId,
      'task_key': task.taskKey,
      'phase_number': task.phaseNumber,
      'task_title': task.title,
      'task_description': task.description,
      'category': task.rawCategory,
      'priority': task.priority,
      'estimated_hours': task.estimatedHours > 0 ? task.estimatedHours : null,
      'due_week': task.dueWeek > 0 ? task.dueWeek : null,
      'deliverable': task.deliverable,
      'success_criteria': task.successCriteria,
      'resource_title': task.resourceTitle,
      'resource_type': task.resourceType.isEmpty
          ? 'roadmap_task'
          : task.resourceType,
      'resource_url': task.resourceUrl,
      'resource_provider': task.resourceProvider,
      'status': status,
      'progress_percent': status == 'completed'
          ? 100
          : safeProgress.clamp(0, 99).toInt(),
      'is_bookmarked': isBookmarked,
      'notes': task.notes,
      'last_opened_at': status == 'in_progress'
          ? now
          : task.learnRow?['last_opened_at'],
      'completed_at': status == 'completed' ? now : null,
      'updated_at': now,
    };
  }

  String _taskIdentity(_LearningTask task) =>
      '${task.roadmapId}/${task.taskKey}';

  void _showMessage(String text) {
    if (!mounted) return;
    TopMessage.show(context, text);
  }

  Widget _statusPill(String status) {
    final color = _statusColor(status);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withOpacity(0.10),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.24)),
      ),
      child: Text(
        _statusLabel(status).toUpperCase(),
        style: TextStyle(
          color: color,
          fontSize: 8,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.4,
        ),
      ),
    );
  }

  Color _statusColor(String status) => switch (status) {
    'completed' => _green,
    'in_progress' => _purple,
    _ => const Color(0xFF8D90A9),
  };

  String _statusLabel(String status) => switch (status) {
    'completed' => _l10n.learnStatusCompleted,
    'in_progress' => _l10n.learnStatusInProgress,
    _ => _l10n.learnStatusToDo,
  };

  IconData _statusIcon(String status) => switch (status) {
    'completed' => Icons.check_circle_outline_rounded,
    'in_progress' => Icons.play_circle_outline_rounded,
    _ => Icons.circle_outlined,
  };

  Color _priorityColor(String priority) => switch (priority.toLowerCase()) {
    'high' => const Color(0xFFFF9A9A),
    'low' => const Color(0xFF8ACFD3),
    _ => const Color(0xFFC6B8FF),
  };

  Color _categoryColor(String category) {
    final value = category.toLowerCase();
    if (value.contains('api') ||
        value.contains('code') ||
        value.contains('program')) {
      return _purple;
    }
    if (value.contains('data') ||
        value.contains('database') ||
        value.contains('sql')) {
      return _cyan;
    }
    if (value.contains('project') || value.contains('build')) return _gold;
    if (value.contains('career') || value.contains('interview')) return _green;
    return const Color(0xFF9FA5FF);
  }

  IconData _categoryIcon(String category) {
    final value = category.toLowerCase();
    if (value.contains('api') ||
        value.contains('code') ||
        value.contains('program')) {
      return Icons.code_rounded;
    }
    if (value.contains('data') ||
        value.contains('database') ||
        value.contains('sql')) {
      return Icons.storage_rounded;
    }
    if (value.contains('project') || value.contains('build')) {
      return Icons.rocket_launch_rounded;
    }
    if (value.contains('career') || value.contains('interview')) {
      return Icons.work_outline_rounded;
    }
    if (value.contains('read') || value.contains('document')) {
      return Icons.menu_book_rounded;
    }
    return Icons.school_outlined;
  }

  String _prettyCategory(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return _l10n.learnGeneralCategory;
    return raw
        .replaceAll('_', ' ')
        .split(RegExp(r'\s+'))
        .where((part) => part.isNotEmpty)
        .map((part) => '${part[0].toUpperCase()}${part.substring(1)}')
        .join(' ');
  }

  String _formatHours(double hours) {
    if (hours <= 0) return 'Unestimated';
    final rounded = hours * 10;
    final normalized = rounded.roundToDouble() / 10;
    return '${normalized == normalized.roundToDouble() ? normalized.toInt() : normalized}h';
  }

  int _int(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _double(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList();
  }

  Map<String, dynamic> _deepCopyMap(dynamic source) {
    if (source is! Map) return <String, dynamic>{};
    return Map<String, dynamic>.from(jsonDecode(jsonEncode(source)) as Map);
  }
}

class _LearningTask {
  const _LearningTask({
    required this.roadmapId,
    required this.taskKey,
    required this.phaseIndex,
    required this.taskIndex,
    required this.phaseNumber,
    required this.phaseTitle,
    required this.title,
    required this.description,
    required this.category,
    required this.rawCategory,
    required this.priority,
    required this.estimatedHours,
    required this.dueWeek,
    required this.deliverable,
    required this.successCriteria,
    required this.status,
    required this.progressPercent,
    required this.isBookmarked,
    required this.resourceTitle,
    required this.resourceType,
    required this.resourceUrl,
    required this.resourceProvider,
    required this.notes,
    required this.startedAt,
    required this.deadlineAt,
    required this.plannedDurationHours,
    required this.plannedDurationSeconds,
    required this.actualDurationSeconds,
    required this.learnRow,
  });

  final String roadmapId;
  final String taskKey;
  final int phaseIndex;
  final int taskIndex;
  final int phaseNumber;
  final String phaseTitle;
  final String title;
  final String description;
  final String category;
  final String rawCategory;
  final String priority;
  final double estimatedHours;
  final int dueWeek;
  final String deliverable;
  final String successCriteria;
  final String status;
  final int progressPercent;
  final bool isBookmarked;
  final String? resourceTitle;
  final String resourceType;
  final String? resourceUrl;
  final String? resourceProvider;
  final String? notes;
  final DateTime? startedAt;
  final DateTime? deadlineAt;
  final int? plannedDurationHours;
  final int? plannedDurationSeconds;
  final int? actualDurationSeconds;
  final LearnRow? learnRow;
}

class _BlinkingActiveIndicator extends StatefulWidget {
  const _BlinkingActiveIndicator({required this.color, this.size = 10});

  final Color color;
  final double size;

  @override
  State<_BlinkingActiveIndicator> createState() =>
      _BlinkingActiveIndicatorState();
}

class _BlinkingActiveIndicatorState extends State<_BlinkingActiveIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 650),
    )..repeat(reverse: true);

    _opacity = Tween<double>(
      begin: 0.2,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: Icon(Icons.circle, color: widget.color, size: widget.size),
    );
  }
}
