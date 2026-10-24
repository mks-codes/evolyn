import 'dart:async';

import 'package:evolyn/core/widgets/page_auto_refresh.dart';
import 'package:evolyn/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:evolyn/app/router/route_names.dart';
import 'package:evolyn/features/roadmap/providers/roadmap_cache_provider.dart';

class ProgressScreen extends ConsumerStatefulWidget {
  const ProgressScreen({super.key, this.isActive = true});
  final bool isActive;

  @override
  ConsumerState<ProgressScreen> createState() => _ProgressScreenState();
}

class _ProgressScreenState extends ConsumerState<ProgressScreen> {
  static const Color _background = Color(0xFF050614);
  static const Color _panel = Color(0xFF101126);
  static const Color _border = Color(0xFF292A46);
  static const Color _purple = Color(0xFFA78BFA);
  static const Color _cyan = Color(0xFF63D9DD);
  static const Color _green = Color(0xFF83D6A9);
  static const Color _gold = Color(0xFFFFC857);

  Timer? _ticker;

  @override
  void initState() {
    super.initState();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted && widget.isActive) setState(() {});
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  bool _isMilestoneCompleted(Map<String, dynamic> milestone) {
    bool isTrue(dynamic value) {
      if (value == true) return true;
      if (value is num) return value == 1;

      final text = value?.toString().trim().toLowerCase();
      return text == 'true' || text == 'yes' || text == '1';
    }

    if (isTrue(milestone['is_completed']) ||
        isTrue(milestone['completed']) ||
        isTrue(milestone['isComplete'])) {
      return true;
    }

    final completedAt = milestone['completed_at'] ?? milestone['completedAt'];

    if (completedAt != null && completedAt.toString().trim().isNotEmpty) {
      return true;
    }

    final status =
        (milestone['status'] ??
                milestone['completion_status'] ??
                milestone['completionStatus'])
            ?.toString()
            .trim()
            .toLowerCase();

    return const {'completed', 'complete', 'done', 'finished'}.contains(status);
  }

  bool _milestoneHasCompletionState(Map<String, dynamic> milestone) {
    return [
      'is_completed',
      'completed',
      'isComplete',
      'completed_at',
      'completedAt',
      'status',
      'completion_status',
      'completionStatus',
    ].any((key) => milestone[key] != null);
  }

  @override
  Widget build(BuildContext context) {
    return PageAutoRefresh(
      isActive: widget.isActive,
      onRefresh: () async {
        final userId = Supabase.instance.client.auth.currentUser?.id;

        if (userId == null) return;

        // Refresh the same shared roadmap cache used by LearnScreen.
        await ref.read(roadmapCacheRepositoryProvider).refresh(userId);
      },
      child: _buildProgressContext(context),
    );
  }

  Widget _buildProgressContext(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      return Scaffold(
        backgroundColor: _background,
        body: SafeArea(
          child: Center(
            child: Text(
              l10n.signInPrompt,
              style: const TextStyle(color: Colors.white70),
            ),
          ),
        ),
      );
    }

    final dashboardAsync = ref.watch(progressDashboardProvider(userId));

    return Scaffold(
      backgroundColor: _background,
      body: SafeArea(
        child: dashboardAsync.when(
          loading: () => const Center(
            child: CircularProgressIndicator(color: _purple),
          ),
          error: (error, stackTrace) => _FeedbackState(
            icon: Icons.cloud_off_outlined,
            title: l10n.loadProgressError,
            message: l10n.connectionRetry,
            buttonLabel: l10n.retry,
            onPressed: () async {
              await ref.read(roadmapCacheRepositoryProvider).refresh(userId);
            },
          ),
          data: (dashboard) => RefreshIndicator(
            color: _purple,
            backgroundColor: _panel,
            onRefresh: () async {
              await ref.read(roadmapCacheRepositoryProvider).refresh(userId);
            },
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(
                parent: BouncingScrollPhysics(),
              ),
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 30),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context),
                  const SizedBox(height: 22),
                  if (!dashboard.hasRoadmap) ...[
                    _buildNoRoadmap(),
                  ] else ...[
                    _buildGoalOverview(context, dashboard),
                    const SizedBox(height: 16),
                    _buildSummaryStats(context, dashboard),
                    const SizedBox(height: 26),
                    _buildSectionTitle(
                      l10n.timeSpentTitle,
                      l10n.timeSpentSubtitle,
                    ),
                    const SizedBox(height: 13),
                    _buildTaskTimeCard(context, dashboard),
                    const SizedBox(height: 27),
                    _buildSectionTitle(
                      l10n.roadmapMilestonesTitle,
                      l10n.roadmapMilestonesSubtitle,
                    ),
                    const SizedBox(height: 13),
                    _buildMilestonesCard(context, dashboard),
                    const SizedBox(height: 27),
                    _buildSectionTitle(
                      l10n.completedTasksTitle,
                      l10n.completedTasksSubtitle,
                    ),
                    const SizedBox(height: 13),
                    _buildCompletedTasks(context, dashboard),
                  ],
                  const SizedBox(height: 17),
                  _buildTrackingNote(context, dashboard),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final now = DateTime.now();
    const weekdays = <String>[
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = <String>[
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.progressEyebrow,
                style: const TextStyle(
                  color: _purple,
                  fontSize: 9,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.1,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                l10n.progressTitle,
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
                '${weekdays[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.45),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        InkWell(
          onTap: () {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(l10n.comingSoon),
                duration: const Duration(seconds: 2),
                behavior: SnackBarBehavior.floating,
              ),
            );
          },
          borderRadius: BorderRadius.circular(14),
          child: Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: const Color(0xFF17152F),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFF37305D)),
            ),
            child: const Icon(
              Icons.insights_rounded,
              color: Color(0xFFB8A4FF),
              size: 20,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNoRoadmap() {
    final l10n = AppLocalizations.of(context)!;
    return _panelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.13),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.route_rounded, color: _purple, size: 24),
          ),
          const SizedBox(height: 14),
          Text(
            l10n.noRoadmapTitle,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            l10n.noRoadmapDescription,
            style: TextStyle(
              color: Colors.white.withOpacity(0.55),
              fontSize: 11,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGoalOverview(BuildContext context, ProgressDashboard dashboard) {
    final l10n = AppLocalizations.of(context)!;
    final canShowCompletion = dashboard.allTasksHaveCompletionState;
    final progress = canShowCompletion && dashboard.tasks.isNotEmpty
        ? dashboard.completedTaskCount / dashboard.tasks.length
        : null;

    return Container(
      padding: const EdgeInsets.all(17),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF211B43), Color(0xFF11152B), Color(0xFF101126)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF40366A)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: _purple.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.rocket_launch_rounded,
                  color: _purple,
                  size: 19,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.currentRoadmap,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.46),
                        fontSize: 9,
                        letterSpacing: 0.9,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      dashboard.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Text(
                progress == null ? '—' : '${(progress * 100).round()}%',
                style: const TextStyle(
                  color: _purple,
                  fontSize: 21,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
            ],
          ),
          if (dashboard.overview.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              dashboard.overview,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white.withOpacity(0.58),
                fontSize: 10.5,
                height: 1.45,
              ),
            ),
          ],
          const SizedBox(height: 16),
          if (progress != null) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 7,
                backgroundColor: Colors.white.withOpacity(0.09),
                valueColor: const AlwaysStoppedAnimation<Color>(_purple),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              l10n.tasksCompleted(
                dashboard.completedTaskCount,
                dashboard.tasks.length,
              ),
              style: TextStyle(
                color: Colors.white.withOpacity(0.62),
                fontSize: 10,
              ),
            ),
          ] else ...[
            Text(
              dashboard.tasks.isEmpty
                  ? l10n.noTasksSaved
                  : l10n.taskCompletionUnavailable,
              style: TextStyle(
                color: Colors.white.withOpacity(0.62),
                fontSize: 10,
                height: 1.4,
              ),
            ),
          ],
          const SizedBox(height: 12),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            children: [
              _smallTag(l10n.phasesCount(dashboard.phases.length)),
              _smallTag(l10n.tasksCount(dashboard.tasks.length)),
              _smallTag(l10n.milestonesCount(dashboard.milestones.length)),
            ],
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _openRoadmap(context, dashboard),
              style: TextButton.styleFrom(
                foregroundColor: _cyan,
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              icon: const Icon(Icons.open_in_new_rounded, size: 14),
              label: Text(l10n.openRoadmap, style: const TextStyle(fontSize: 11)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryStats(
    BuildContext context,
    ProgressDashboard dashboard,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final completedValue = dashboard.allTasksHaveCompletionState
        ? '${dashboard.completedTaskCount}/${dashboard.tasks.length}'
        : (dashboard.hasAnyTaskCompletionState
              ? '${dashboard.completedTaskCount}'
              : '—');
    final effortValue = dashboard.estimatedHours == null
        ? '—'
        : '${dashboard.estimatedHours}h';

    return Row(
      children: [
        Expanded(
          child: _metricCard(
            icon: Icons.check_circle_outline_rounded,
            value: completedValue,
            label: 'Tasks completed',
            caption: dashboard.allTasksHaveCompletionState
                ? l10n.savedCompletionStates
                : l10n.completionTracking,
            color: _green,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _metricCard(
            icon: Icons.schedule_rounded,
            value: effortValue,
            label: l10n.plannedEffort,
            caption: l10n.estimatedTaskHours,
            color: _cyan,
          ),
        ),
        const SizedBox(width: 9),
        Expanded(
          child: _metricCard(
            icon: Icons.flag_outlined,
            value: '${dashboard.milestones.length}',
            label: l10n.milestonesLabel,
            caption: l10n.inSavedRoadmap,
            color: _gold,
          ),
        ),
      ],
    );
  }

  Widget _metricCard({
    required IconData icon,
    required String value,
    required String label,
    required String caption,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 112),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 13),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: _border),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 17),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.72),
              fontSize: 9,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 2,
            textAlign: TextAlign.center,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: Colors.white.withOpacity(0.35),
              fontSize: 8,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 17,
            fontWeight: FontWeight.w600,
            letterSpacing: -0.3,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          subtitle,
          style: TextStyle(color: Colors.white.withOpacity(0.42), fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildTaskTimeCard(
    BuildContext context,
    ProgressDashboard dashboard,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (dashboard.tasks.isEmpty) {
      return _emptyCard(
        icon: Icons.timer_outlined,
        title: l10n.noTasksAvailable,
        subtitle: 'Task sessions will appear when tasks are saved in your roadmap.',
      );
    }

    // Use session records when available. For older tasks without session
    // records, retain their saved task-level duration as a fallback.
    int taskTotalSeconds(Map<String, dynamic> task) {
      final sessions = _taskSessions(task);

      // LearnScreen persists cumulative time in actual_duration_seconds and
      // stores the active session's started_at/deadline_at on the roadmap task.
      // Use saved session history when it exists; otherwise use the task total.
      final legacySeconds = _taskLegacyTrackedSeconds(task);
      final sessionHistorySeconds = sessions.fold<int>(
        0,
        (total, session) => total + _sessionDurationSeconds(session),
      );
      // Once individual sessions are saved, sum those records instead of
      // adding actual_duration_seconds again. Preserve pre-history time in
      // legacy_tracked_seconds so older work is not lost or double-counted.
      final persistedTotal = sessions.isNotEmpty
          ? sessionHistorySeconds + legacySeconds
          : (_taskTrackedSeconds(task) ?? 0) + legacySeconds;

      return persistedTotal + _taskCurrentSessionSeconds(task);
    }

    final totalTrackedSeconds = dashboard.tasks.fold<int>(
      0,
      (total, task) => total + taskTotalSeconds(task),
    );

    final tasksWithTime = dashboard.tasks
        .where((task) =>
            _taskSessions(task).isNotEmpty ||
            _taskTrackedSeconds(task) != null ||
            _taskLegacyTrackedSeconds(task) > 0 ||
            _taskHasActiveSession(task))
        .length;

    return _panelCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Overall total for all roadmap tasks.
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.09),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: _purple.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined, color: _purple, size: 24),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.totalTrackedTime,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.5),
                          fontSize: 9,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.8,
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text(
                        tasksWithTime == 0
                            ? l10n.notRecordedYet
                            : _formatTaskDuration(totalTrackedSeconds),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                Text(
                  l10n.trackedCount(tasksWithTime, dashboard.tasks.length),
                  style: const TextStyle(
                    color: _cyan,
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            l10n.sessionHistory,
            style: TextStyle(
              color: Colors.white.withOpacity(0.42),
              fontSize: 9,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 5),

          // Each task includes its total time and individual sessions.
          for (var i = 0; i < dashboard.tasks.length; i++) ...[
            _taskSessionCard(
              context,
              dashboard.tasks[i],
              totalSeconds: taskTotalSeconds(dashboard.tasks[i]),
            ),
            if (i != dashboard.tasks.length - 1)
              Divider(height: 17, color: Colors.white.withOpacity(0.07)),
          ],
          const SizedBox(height: 8),
          Text(
            l10n.sessionTotalExplanation,
            style: TextStyle(
              color: Colors.white.withOpacity(0.38),
              fontSize: 9,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _taskSessionCard(
    BuildContext context,
    Map<String, dynamic> task, {
    required int totalSeconds,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final sessions = _taskSessions(task);
    final completed = _isCompleted(task);
    final status = (task['status'] ?? '').toString().trim().toLowerCase();
    final inProgress = const {'in_progress', 'in progress', 'running'}
        .contains(status);
    final hasActiveSession = _taskHasActiveSession(task);
    final currentSessionSeconds = _taskCurrentSessionSeconds(task);

    final title = _stringValue(
      task['title'] ?? task['task_title'],
      l10n.roadmapTaskFallback,
    );

    final phaseTitle = _stringValue(
      task['phase_title'],
      _intValue(task['phase_number']) != null
          ? 'Phase ${task['phase_number']}'
          : l10n.roadmapTaskFallback,
    );

    final color = completed
        ? _green
        : inProgress
            ? _purple
            : _cyan;

    final sessionCountLabel = sessions.length == 1
        ? '1 session'
        : '${sessions.length} sessions';

    final statusLabel = completed
        ? '${l10n.completed} · $sessionCountLabel'
        : hasActiveSession
            ? '${l10n.inProgress} · ${_formatClockDuration(currentSessionSeconds)}'
            : inProgress
                ? '${l10n.inProgress} · $sessionCountLabel'
                : sessionCountLabel;

    final hasAnySavedTime = sessions.isNotEmpty ||
        _taskTrackedSeconds(task) != null ||
        _taskLegacyTrackedSeconds(task) > 0 ||
        hasActiveSession;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 37,
                height: 37,
                decoration: BoxDecoration(
                  color: color.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  completed
                      ? Icons.task_alt_rounded
                      : inProgress
                          ? Icons.play_circle_outline_rounded
                          : Icons.timer_outlined,
                  color: color,
                  size: 20,
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.35,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      phaseTitle,
                      style: TextStyle(
                        color: Colors.white.withOpacity(0.43),
                        fontSize: 9,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        color: color,
                        fontSize: 8.5,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    hasAnySavedTime
                        ? _formatTaskDuration(totalSeconds)
                        : l10n.noTime,
                    style: TextStyle(
                      color: hasAnySavedTime ? color : Colors.white38,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    l10n.taskTotal,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.38),
                      fontSize: 7.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          if (hasActiveSession) ...[
            _activeSessionTimeline(
              context,
              task,
              elapsedSeconds: currentSessionSeconds,
            ),
            const SizedBox(height: 10),
          ],
          if (sessions.isNotEmpty) ...[
            Row(
              children: [
                const Icon(Icons.history_rounded, color: _cyan, size: 14),
                const SizedBox(width: 6),
                Text(
                  l10n.savedSessionTimeline(sessions.length),
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.48),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < sessions.length; i++) ...[
              _sessionRow(context, sessions[i], i + 1),
              if (i != sessions.length - 1) const SizedBox(height: 8),
            ],
          ] else if (!hasActiveSession) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.035),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(color: Colors.white.withOpacity(0.06)),
              ),
              child: Text(
                (_taskTrackedSeconds(task) != null ||
                        _taskLegacyTrackedSeconds(task) > 0)
                    ? l10n.taskTimeFallback
                    : l10n.sessionHistoryEmpty,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.48),
                  fontSize: 9.5,
                  height: 1.5,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _activeSessionTimeline(
    BuildContext context,
    Map<String, dynamic> task, {
    required int elapsedSeconds,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final startedAt = DateTime.tryParse(
      (task['started_at'] ?? '').toString(),
    )?.toLocal();
    final deadlineAt = DateTime.tryParse(
      (task['deadline_at'] ?? '').toString(),
    )?.toLocal();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: _purple.withOpacity(0.07),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _purple.withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.play_circle_fill_rounded,
                color: _purple,
                size: 15,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  l10n.currentSessionTimeline,
                  style: const TextStyle(
                    color: _purple,
                    fontSize: 8.5,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.45,
                  ),
                ),
              ),
              Text(
                _formatClockDuration(elapsedSeconds),
                style: const TextStyle(
                  color: _purple,
                  fontSize: 9.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          _sessionTimelinePoint(
            icon: Icons.play_arrow_rounded,
            label: l10n.started,
            value: startedAt == null
                ? l10n.startTimeNotSaved
                : _formatSessionDateTime(startedAt),
            color: _purple,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Container(
              width: 1,
              height: 12,
              color: _purple.withOpacity(0.45),
            ),
          ),
          _sessionTimelinePoint(
            icon: Icons.flag_outlined,
            label: l10n.targetEnd,
            value: deadlineAt == null
                ? l10n.targetEndNotSaved
                : _formatSessionDateTime(deadlineAt),
            color: _purple,
          ),
          const SizedBox(height: 5),
          Text(
            l10n.activeElapsedExplanation,
            style: TextStyle(
              color: Colors.white.withOpacity(0.45),
              fontSize: 8.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionRow(BuildContext context, Map<String, dynamic> session, int sessionNumber) {
    final l10n = AppLocalizations.of(context)!;
    final startedAt = _sessionStartedAt(session);
    final endedAt = _sessionEndedAt(session);
    final isRunning = endedAt == null && startedAt != null;
    final seconds = _sessionDurationSeconds(session);
    final sessionDate = startedAt ?? endedAt;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(
        color: const Color(0xFF0B0C1D),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: _border.withOpacity(0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                isRunning
                    ? Icons.play_circle_outline_rounded
                    : Icons.history_rounded,
                size: 15,
                color: isRunning ? _purple : _cyan,
              ),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  l10n.sessionLabel(sessionNumber),
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                isRunning
                    ? l10n.liveDuration(_formatClockDuration(seconds))
                    : _formatTaskDuration(seconds),
                style: TextStyle(
                  color: isRunning ? _purple : _cyan,
                  fontSize: 9,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          if (sessionDate != null) ...[
            const SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.only(left: 22),
              child: Text(
                '${l10n.dateLabel} · ${_formatSessionDate(sessionDate)}',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.48),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          _sessionTimelinePoint(
            icon: Icons.play_arrow_rounded,
            label: l10n.started,
            value: startedAt == null
                ? l10n.startTimeNotSaved
                : _formatSessionDateTime(startedAt),
            color: isRunning ? _purple : _cyan,
          ),
          Padding(
            padding: const EdgeInsets.only(left: 6),
            child: Container(
              width: 1,
              height: 12,
              color: (isRunning ? _purple : _cyan).withOpacity(0.42),
            ),
          ),
          _sessionTimelinePoint(
            icon: Icons.stop_rounded,
            label: l10n.ended,
            value: isRunning
                ? l10n.inProgressValue
                : endedAt == null
                    ? l10n.endTimeNotSaved
                    : _formatSessionDateTime(endedAt),
            color: isRunning ? _purple : _cyan,
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.only(left: 22),
            child: Text(
              '${l10n.sessionDuration} · ${_formatTaskDuration(seconds)}',
              style: TextStyle(
                color: Colors.white.withOpacity(0.52),
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sessionTimelinePoint({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: color, size: 13),
        const SizedBox(width: 7),
        SizedBox(
          width: 62,
          child: Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.42),
              fontSize: 9,
            ),
          ),
        ),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              color: Colors.white.withOpacity(0.76),
              fontSize: 9,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }

  // Supports common nested session-list field names. Adjust these aliases
  // if your database uses a different session field.
  List<Map<String, dynamic>> _taskSessions(Map<String, dynamic> task) {
    const sessionKeys = [
      'sessions',
      'time_sessions',
      'task_sessions',
      'session_logs',
      'study_sessions',
    ];

    for (final key in sessionKeys) {
      final value = task[key];
      if (value is List) {
        final sessions = value
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList();

        sessions.sort((a, b) {
          final aStart = _sessionStartedAt(a);
          final bStart = _sessionStartedAt(b);
          if (aStart == null && bStart == null) return 0;
          if (aStart == null) return 1;
          if (bStart == null) return -1;
          return aStart.compareTo(bStart);
        });

        return sessions;
      }
    }

    return [];
  }

  DateTime? _sessionStartedAt(Map<String, dynamic> session) {
    const keys = [
      'started_at',
      'start_time',
      'startedAt',
      'startTime',
      'session_started_at',
    ];

    for (final key in keys) {
      final value = session[key];
      if (value != null) {
        final parsed = DateTime.tryParse(value.toString());
        if (parsed != null) return parsed.toLocal();
      }
    }

    return null;
  }

  DateTime? _sessionEndedAt(Map<String, dynamic> session) {
    const keys = [
      'ended_at',
      'end_time',
      'endedAt',
      'endTime',
      'session_ended_at',
    ];

    for (final key in keys) {
      final value = session[key];
      if (value != null) {
        final parsed = DateTime.tryParse(value.toString());
        if (parsed != null) return parsed.toLocal();
      }
    }

    return null;
  }

  int _sessionDurationSeconds(Map<String, dynamic> session) {
    const secondKeys = [
      'duration_seconds',
      'actual_duration_seconds',
      'elapsed_seconds',
      'tracked_seconds',
      'durationSeconds',
    ];

    for (final key in secondKeys) {
      final seconds = _intValue(session[key]);
      if (seconds != null && seconds >= 0) return seconds;
    }

    const minuteKeys = [
      'duration_minutes',
      'actual_duration_minutes',
      'tracked_minutes',
      'durationMinutes',
    ];

    for (final key in minuteKeys) {
      final minutes = _intValue(session[key]);
      if (minutes != null && minutes >= 0) return minutes * 60;
    }

    final startedAt = _sessionStartedAt(session);
    final endedAt = _sessionEndedAt(session);

    if (startedAt != null) {
      final end = endedAt ?? DateTime.now();
      final difference = end.difference(startedAt).inSeconds;
      return difference < 0 ? 0 : difference;
    }

    return 0;
  }

  String _formatSessionDateTime(DateTime dateTime) {
    final local = dateTime.toLocal();
    final hour = local.hour % 12 == 0 ? 12 : local.hour % 12;
    final minute = local.minute.toString().padLeft(2, '0');
    final period = local.hour >= 12 ? 'PM' : 'AM';
    final day = local.day.toString().padLeft(2, '0');
    final month = local.month.toString().padLeft(2, '0');

    return '$day/$month/${local.year} · $hour:$minute $period';
  }

  String _formatSessionDate(DateTime dateTime) {
    final local = dateTime.toLocal();
    const months = <String>[
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final day = local.day.toString().padLeft(2, '0');
    return '$day ${months[local.month - 1]} ${local.year}';
  }

  int _taskLegacyTrackedSeconds(Map<String, dynamic> task) {
    final seconds = _intValue(task['legacy_tracked_seconds']);
    return seconds == null || seconds < 0 ? 0 : seconds;
  }

  int? _taskTrackedSeconds(Map<String, dynamic> task) {
    // These fields contain the cumulative time already persisted by LearnScreen.
    // Keep the live session separate so it is not counted twice.
    final savedSeconds = _intValue(task['actual_duration_seconds']);
    if (savedSeconds != null && savedSeconds >= 0) return savedSeconds;

    final savedMinutes = _intValue(task['actual_duration_minutes']);
    if (savedMinutes != null && savedMinutes >= 0) return savedMinutes * 60;

    return null;
  }

  bool _taskHasActiveSession(Map<String, dynamic> task) {
    final status = (task['status'] ?? '').toString().trim().toLowerCase();
    if (status != 'in_progress' &&
        status != 'in progress' &&
        status != 'running') {
      return false;
    }

    final startedAt = DateTime.tryParse((task['started_at'] ?? '').toString());
    final deadlineAt = DateTime.tryParse((task['deadline_at'] ?? '').toString());
    return startedAt != null && deadlineAt != null;
  }

  int _taskCurrentSessionSeconds(Map<String, dynamic> task) {
    if (!_taskHasActiveSession(task)) return 0;

    final startedAt = DateTime.parse(task['started_at'].toString());
    final deadlineAt = DateTime.parse(task['deadline_at'].toString());
    final elapsed = DateTime.now().difference(startedAt).inSeconds;
    final savedPlannedSeconds = _intValue(task['planned_duration_seconds']);
    final savedPlannedHours = _intValue(task['planned_duration_hours']);
    final plannedSeconds = savedPlannedSeconds != null && savedPlannedSeconds > 0
        ? savedPlannedSeconds
        : (savedPlannedHours != null && savedPlannedHours > 0
            ? savedPlannedHours * 3600
            : deadlineAt.difference(startedAt).inSeconds);
    final cap = plannedSeconds > 0
        ? plannedSeconds
        : deadlineAt.difference(startedAt).inSeconds;

    return elapsed.clamp(0, cap > 0 ? cap : 0).toInt();
  }

  String _formatClockDuration(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    final remainingSeconds = safeSeconds % 60;
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${remainingSeconds.toString().padLeft(2, '0')}';
  }

  String _formatTaskDuration(int seconds) {
    final safeSeconds = seconds < 0 ? 0 : seconds;
    final hours = safeSeconds ~/ 3600;
    final minutes = (safeSeconds % 3600) ~/ 60;
    final remainingSeconds = safeSeconds % 60;

    if (hours > 0 && minutes > 0) {
      return '${hours}h ${minutes}m';
    }

    if (hours > 0) return '${hours}h';
    if (minutes > 0) return '${minutes}m';

    return '${remainingSeconds}s';
  }

  Widget _buildMilestonesCard(
    BuildContext context,
    ProgressDashboard dashboard,
  ) {
    final l10n = AppLocalizations.of(context)!;
    if (dashboard.milestones.isEmpty) {
      return _emptyCard(
        icon: Icons.flag_outlined,
        title: l10n.noMilestonesSaved,
        subtitle: l10n.noMilestonesDescription,
      );
    }

    return _panelCard(
      child: Column(
        children: [
          for (var i = 0; i < dashboard.milestones.length; i++) ...[
            _milestoneRow(context, dashboard.milestones[i]),
            if (i != dashboard.milestones.length - 1)
              Divider(height: 20, color: Colors.white.withOpacity(0.055)),
          ],
        ],
      ),
    );
  }

  Widget _milestoneRow(BuildContext context, Map<String, dynamic> milestone) {
    final l10n = AppLocalizations.of(context)!;
    final completed = _isMilestoneCompleted(milestone);
    final stateKnown = _milestoneHasCompletionState(milestone);

    final title = _stringValue(milestone['title'], l10n.roadmapMilestoneFallback);

    final week = _intValue(milestone['target_week']);
    final criteria = _stringValue(milestone['success_criteria'], '');

    final color = completed ? _green : _cyan;

    final detailParts = <String>[];
    if (week != null) detailParts.add('Target: week $week');
    if (criteria.isNotEmpty) detailParts.add(criteria);

    final statusLabel = completed
        ? l10n.completed
        : stateKnown
            ? l10n.inProgress
            : l10n.planned;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 37,
          height: 37,
          decoration: BoxDecoration(
            color: color.withOpacity(0.12),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            completed ? Icons.check_circle_rounded : Icons.flag_outlined,
            color: color,
            size: 18,
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    statusLabel,
                    style: TextStyle(
                      color: completed
                          ? _green
                          : stateKnown
                              ? _cyan
                              : _purple,
                      fontSize: 8,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 5),
              Text(
                detailParts.isEmpty
                    ? 'Milestone in your saved roadmap'
                    : detailParts.join(' · '),
                style: TextStyle(
                  color: Colors.white.withOpacity(0.42),
                  fontSize: 9,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildCompletedTasks(
    BuildContext context,
    ProgressDashboard dashboard,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final completed = dashboard.completedTasks;
    if (completed.isEmpty) {
      return _emptyCard(
        icon: Icons.task_alt_rounded,
        title: dashboard.hasAnyTaskCompletionState
            ? l10n.noCompletedTasks
            : l10n.completionNotTracked,
        subtitle: dashboard.hasAnyTaskCompletionState
            ? l10n.completionSavedDescription
            : l10n.completionMissingDescription,
      );
    }

    return _panelCard(
      child: Column(
        children: [
          for (var i = 0; i < completed.length; i++) ...[
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: _green.withOpacity(0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_rounded,
                    color: _green,
                    size: 17,
                  ),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _stringValue(
                          completed[i]['title'] ?? completed[i]['task_title'],
                          'Completed task',
                        ),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _completedDetail(completed[i], l10n),
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.40),
                          fontSize: 9,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (i != completed.length - 1)
              Divider(height: 20, color: Colors.white.withOpacity(0.055)),
          ],
        ],
      ),
    );
  }

  Widget _buildTrackingNote(
    BuildContext context,
    ProgressDashboard dashboard,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final text = !dashboard.hasRoadmap
        ? l10n.progressDataNote
        : dashboard.allTasksHaveCompletionState
            ? l10n.taskCompletionNote
            : l10n.trackingUnavailableNote;

    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: const Color(0xFF11132A),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF302D56)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 35,
            height: 35,
            decoration: BoxDecoration(
              color: _purple.withOpacity(0.14),
              borderRadius: BorderRadius.circular(11),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: _purple,
              size: 18,
            ),
          ),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.aaryaNote,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.57),
                    fontSize: 10,
                    height: 1.55,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _smallTag(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.06),
        borderRadius: BorderRadius.circular(9),
        border: Border.all(color: Colors.white.withOpacity(0.08)),
      ),
      child: Text(
        label,
        style: TextStyle(color: Colors.white.withOpacity(0.70), fontSize: 9),
      ),
    );
  }

  Widget _panelCard({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: _panel,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: _border),
      ),
      child: child,
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return _panelCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: _purple, size: 23),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.45),
                    fontSize: 10.5,
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openRoadmap(BuildContext context, ProgressDashboard dashboard) {
    final response = dashboard.response;
    if (response == null) return;

    context.pushNamed(
      RouteNames.roadmapScreen,
      extra: <String, dynamic>{
        'roadmapData': response,
        'roadmapId': dashboard.roadmapId,
        'selectedCareers': dashboard.selectedCareers,
        'requestId': dashboard.requestId,
        'generationRequestId': dashboard.generationRequestId,
        'selectedCareerIds': dashboard.selectedCareerIds,
      },
    );
  }
}

/// Maps the shared local-cache/realtime roadmap feed into ProgressScreen data.
/// This provider deliberately remains alive while the app is open, so changing
/// tabs does not issue another SELECT query.
final progressDashboardProvider =
    StreamProvider.family<ProgressDashboard, String>((ref, userId) {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null || user.id != userId) {
        return Stream<ProgressDashboard>.error(
          StateError('You must be signed in to load progress.'),
        );
      }

      return ref
          .watch(roadmapCacheRepositoryProvider)
          .watch(userId)
          .map(_buildProgressDashboard);
    });

ProgressDashboard _buildProgressDashboard(Map<String, dynamic>? row) {
  if (row == null) return const ProgressDashboard.empty();

  final roadmapData = _asMap(row['roadmap_data']);
  final dbPhases = _asMapList(row['phases']);
  final phases = dbPhases.isNotEmpty
      ? dbPhases
      : _asMapList(roadmapData['phases']);

  final dbTasks = _asMapList(row['tasks']);
  final tasks = dbTasks.isNotEmpty
      ? dbTasks
      : _flattenPhaseItems(phases, 'tasks');
  final dbMilestones = _asMapList(row['milestones']);
  final milestones = dbMilestones.isNotEmpty
      ? dbMilestones
      : _flattenPhaseItems(phases, 'milestones');

  tasks.sort((a, b) {
    final weekCompare = (_intValue(a['due_week']) ?? 999999).compareTo(
      _intValue(b['due_week']) ?? 999999,
    );
    if (weekCompare != 0) return weekCompare;
    return (_intValue(a['phase_number']) ?? 999999).compareTo(
      _intValue(b['phase_number']) ?? 999999,
    );
  });
  milestones.sort(
    (a, b) => (_intValue(a['target_week']) ?? 999999).compareTo(
      _intValue(b['target_week']) ?? 999999,
    ),
  );

  final rowCareers = _asMapList(row['selected_careers']);
  final selectedCareers = rowCareers.isNotEmpty
      ? rowCareers
      : _asMapList(roadmapData['selected_careers']);
  final selectedCareerIds = row['selected_career_ids'] is List
      ? (row['selected_career_ids'] as List)
            .map((item) => item.toString())
            .toList()
      : <String>[];

  final roadmapId = row['id']?.toString();
  final requestId = row['career_request_id']?.toString();
  final generationRequestId = row['generation_request_id']?.toString();
  final normalizedRoadmap = <String, dynamic>{
    ...roadmapData,
    'success': true,
    'persisted': true,
    'roadmap_data': roadmapData,
    'roadmap_id': roadmapId,
    'request_id': requestId,
    'generation_request_id': generationRequestId,
    'status': row['status'] ?? 'draft',
    'generated_at': row['created_at'],
    'title': row['title'] ?? roadmapData['title'],
    'overview': row['overview'] ?? roadmapData['overview'],
    'planning_horizon_months':
        row['planning_horizon_months'] ??
        roadmapData['planning_horizon_months'],
    'phases': phases,
    'tasks': tasks,
    'milestones': milestones,
    'selected_careers': selectedCareers,
  };

  final planningHours = tasks.fold<int>(0, (total, task) {
    final hours = _intValue(task['estimated_hours']);
    return total + (hours != null && hours > 0 ? hours : 0);
  });
  final hasEstimatedHours = tasks.any((task) {
    final hours = _intValue(task['estimated_hours']);
    return hours != null && hours > 0;
  });

  return ProgressDashboard(
    roadmapId: roadmapId,
    requestId: requestId,
    generationRequestId: generationRequestId,
    selectedCareerIds: selectedCareerIds,
    title: _stringValue(
      row['title'] ?? roadmapData['title'],
      'Your career roadmap',
    ),
    overview: _stringValue(row['overview'] ?? roadmapData['overview'], ''),
    phases: phases,
    tasks: tasks,
    milestones: milestones,
    selectedCareers: selectedCareers,
    response: normalizedRoadmap,
    estimatedHours: hasEstimatedHours ? planningHours : null,
  );
}

class ProgressDashboard {
  const ProgressDashboard({
    this.roadmapId,
    this.requestId,
    this.generationRequestId,
    this.selectedCareerIds = const <String>[],
    this.title = 'Your career roadmap',
    this.overview = '',
    this.phases = const <Map<String, dynamic>>[],
    this.tasks = const <Map<String, dynamic>>[],
    this.milestones = const <Map<String, dynamic>>[],
    this.selectedCareers = const <Map<String, dynamic>>[],
    this.response,
    this.estimatedHours,
  });

  const ProgressDashboard.empty() : this();

  final String? roadmapId;
  final String? requestId;
  final String? generationRequestId;
  final List<String> selectedCareerIds;
  final String title;
  final String overview;
  final List<Map<String, dynamic>> phases;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> milestones;
  final List<Map<String, dynamic>> selectedCareers;
  final Map<String, dynamic>? response;
  final int? estimatedHours;

  bool get hasRoadmap => roadmapId != null && roadmapId!.isNotEmpty;

  bool get hasAnyTaskCompletionState => tasks.any(_hasCompletionState);

  bool get allTasksHaveCompletionState =>
      tasks.isNotEmpty && tasks.every(_hasCompletionState);

  int get completedTaskCount => tasks.where(_isCompleted).length;

  List<Map<String, dynamic>> get completedTasks =>
      tasks.where(_isCompleted).take(5).toList();
}

class _FeedbackState extends StatelessWidget {
  const _FeedbackState({
    required this.icon,
    required this.title,
    required this.message,
    required this.buttonLabel,
    required this.onPressed,
  });

  final IconData icon;
  final String title;
  final String message;
  final String buttonLabel;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: const Color(0xFFA78BFA), size: 36),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.55),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}

Map<String, dynamic> _asMap(dynamic value) {
  if (value is Map) return Map<String, dynamic>.from(value);
  return <String, dynamic>{};
}

List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList();
}

List<Map<String, dynamic>> _flattenPhaseItems(
  List<Map<String, dynamic>> phases,
  String key,
) {
  final result = <Map<String, dynamic>>[];
  for (final phase in phases) {
    final values = phase[key];
    if (values is! List) continue;
    for (final value in values) {
      if (value is Map) {
        result.add(<String, dynamic>{
          ...Map<String, dynamic>.from(value),
          'phase_number': phase['phase_number'],
          'phase_title': phase['title'],
        });
      }
    }
  }
  return result;
}

String _stringValue(dynamic value, String fallback) {
  if (value == null) return fallback;
  final text = value.toString().trim();
  return text.isEmpty ? fallback : text;
}

int? _intValue(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

bool _hasCompletionState(Map<String, dynamic> item) {
  return item.containsKey('is_completed') ||
      item.containsKey('completed') ||
      item.containsKey('status') ||
      item.containsKey('completed_at');
}

bool _isCompleted(Map<String, dynamic> item) {
  if (item['is_completed'] == true || item['completed'] == true) return true;
  if (item['completed_at'] != null &&
      item['completed_at'].toString().isNotEmpty) {
    return true;
  }
  final status = item['status']?.toString().trim().toLowerCase();
  return status == 'completed' || status == 'done' || status == 'finished';
}

String _completedDetail(
  Map<String, dynamic> task,
  AppLocalizations l10n,
) {
  final phase = _stringValue(task['phase_title'], '');
  final completedAt = task['completed_at']?.toString();
  final parts = <String>[l10n.taskCompletedDetail];
  if (completedAt != null && completedAt.isNotEmpty) {
    final parsed = DateTime.tryParse(completedAt)?.toLocal();
    if (parsed != null) {
      parts.add('${parsed.day}/${parsed.month}/${parsed.year}');
    }
  }
  if (phase.isNotEmpty) parts.add(phase);
  return parts.join(' · ');
}
