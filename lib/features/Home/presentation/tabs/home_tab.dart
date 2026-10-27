import 'package:evolyn/app/router/route_names.dart';
import 'package:evolyn/core/widgets/page_auto_refresh.dart';
import 'package:evolyn/features/profile/presentation/profile_screen.dart';
import 'package:evolyn/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:evolyn/features/profile/providers/user_display_name_provider.dart';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
class HomeTab extends ConsumerWidget {
  const HomeTab({super.key, this.isActive = true});

  final bool isActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PageAutoRefresh(
      isActive: isActive,
      onRefresh: () async => ref.invalidate(homeDashboardProvider),
      child: _buildHomeContent(context, ref),
    );
  }

  Widget _buildHomeContent(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final dashboardAsync = ref.watch(homeDashboardProvider);

    return dashboardAsync.when(
      loading: () => const _HomeDashboardSkeleton(),
      error: (error, stackTrace) => _DashboardMessage(
        icon: Icons.cloud_off_outlined,
        title: l10n.dashboardLoadErrorTitle,
        message: l10n.dashboardLoadErrorMessage,
        buttonLabel: l10n.retry,
        onPressed: () => ref.invalidate(homeDashboardProvider),
      ),
      data: (dashboard) => RefreshIndicator(
        color: const Color(0xFFA78BFA),
        backgroundColor: const Color(0xFF111226),
        onRefresh: () async {
          ref.invalidate(homeDashboardProvider);
          await ref.read(homeDashboardProvider.future);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(
            parent: BouncingScrollPhysics(),
          ),
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, dashboard.displayName),
              const SizedBox(height: 20),
              _buildFocusCard(context, dashboard),
              const SizedBox(height: 22),
              _buildTodayHeader(context, dashboard),
              const SizedBox(height: 10),
              _buildNextTasks(context, dashboard),
              if (dashboard.hasRoadmap) ...[
                const SizedBox(height: 14),
                _buildStats(context, dashboard),
                if (dashboard.nextMilestone != null) ...[
                  const SizedBox(height: 14),
                  _buildNextMilestone(context, dashboard),
                ],
              ],
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String displayName) {
    final l10n = AppLocalizations.of(context)!;
    final locale = Localizations.localeOf(context).toString();
    final now = DateTime.now();
    final dateLabel = DateFormat('EEEE, MMMM d', locale).format(now);
    final greeting = now.hour < 12
        ? l10n.goodMorning
        : now.hour < 17
            ? l10n.goodAfternoon
            : l10n.goodEvening;
    final name = displayName.trim().isEmpty
        ? l10n.fallbackDisplayName
        : displayName.trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateLabel,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.48),
                  fontSize: 11,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '$greeting, $name',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),
        Material(
          color: Colors.transparent,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ProfileScreen(),
                ),
              );
            },
            child: Container(
              width: 40,
              height: 40,
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: const Color(0xFF806CFF),
                  width: 1.5,
                ),
              ),
              child: const CircleAvatar(
                backgroundColor: Color(0xFF17182C),
                child: Icon(
                  Icons.person_rounded,
                  color: Color(0xFFB8B1FF),
                  size: 21,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildFocusCard(BuildContext context, HomeDashboard dashboard) {
    final l10n = AppLocalizations.of(context)!;
    final hasTitle = dashboard.roadmapTitle.trim().isNotEmpty;
    final title = dashboard.hasRoadmap
        ? (hasTitle ? dashboard.roadmapTitle : l10n.fallbackRoadmapTitle)
        : l10n.noSavedRoadmap;
    final description = dashboard.hasRoadmap
        ? dashboard.roadmapOverview
        : l10n.chooseCareersDescription;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF171A3B), Color(0xFF102A35)],
        ),
        border: Border.all(color: const Color(0xFF4D477F)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6).withOpacity(0.16),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: const Color(0xFF9B83FF)),
            ),
            child: const Icon(
              Icons.route_rounded,
              color: Color(0xFFB7AFFF),
              size: 25,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  l10n.roadmapFocus,
                  style: const TextStyle(
                    color: Color(0xFFB7AFFF),
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
                ),
                const SizedBox(height: 7),
                Text(
                  title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.3,
                  ),
                ),
                if (description.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    description,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.62),
                      fontSize: 11,
                      height: 1.45,
                    ),
                  ),
                ],
                if (dashboard.hasRoadmap) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => _openRoadmap(context, dashboard),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF63D9DD),
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 30),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      icon: const Icon(Icons.open_in_new_rounded, size: 14),
                      label: Text(
                        l10n.openRoadmap,
                        style: const TextStyle(fontSize: 11),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTodayHeader(BuildContext context, HomeDashboard dashboard) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: Text(
            l10n.nextActions,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 15,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        if (dashboard.hasRoadmap)
          Text(
            l10n.plannedTasks(dashboard.tasks.length),
            style: const TextStyle(
              color: Color(0xFFA78BFA),
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
      ],
    );
  }

  Widget _buildNextTasks(BuildContext context, HomeDashboard dashboard) {
    final l10n = AppLocalizations.of(context)!;
    if (!dashboard.hasRoadmap) {
      return _emptyCard(
        icon: Icons.checklist_rounded,
        title: l10n.nextStepsTitle,
        subtitle: l10n.nextStepsSubtitle,
      );
    }

    if (dashboard.tasks.isEmpty) {
      return _emptyCard(
        icon: Icons.task_alt_rounded,
        title: l10n.noTasksTitle,
        subtitle: l10n.noTasksSubtitle,
      );
    }

    final pendingTasks = dashboard.tasks
        .where((task) => !_isTaskCompleted(task))
        .toList();

    if (pendingTasks.isEmpty) {
      return _emptyCard(
        icon: Icons.check_circle_rounded,
        title: l10n.allTasksCompletedTitle,
        subtitle: l10n.allTasksCompletedSubtitle,
      );
    }

    final tasks = pendingTasks.take(3).toList();
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF111226),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF292A46)),
      ),
      child: Column(
        children: [
          for (var i = 0; i < tasks.length; i++) ...[
            _taskTile(context: context, dashboard: dashboard, task: tasks[i]),
            if (i < tasks.length - 1)
              Divider(
                height: 1,
                thickness: 1,
                color: Colors.white.withOpacity(0.055),
              ),
          ],
        ],
      ),
    );
  }

  Widget _taskTile({
    required BuildContext context,
    required HomeDashboard dashboard,
    required Map<String, dynamic> task,
  }) {
    final l10n = AppLocalizations.of(context)!;
    final title = _stringValue(task['title'] ?? task['task_title'], l10n.fallbackTaskTitle);
    final rawCategory = _stringValue(task['category'], '');
    final category = _localizedCategory(l10n, rawCategory);
    final rawPhaseTitle = _stringValue(task['phase_title'], '');
    final phaseTitle = rawPhaseTitle.isEmpty || rawPhaseTitle == 'Roadmap'
        ? l10n.fallbackPhaseTitle
        : rawPhaseTitle;
    final dueWeek = _intValue(task['due_week']);
    final hours = _intValue(task['estimated_hours']);
    final isCompleted = _isTaskCompleted(task);
    final isInProgress = !isCompleted && _isTaskInProgress(task);
    final isLiveSession = isInProgress && _hasActiveTaskSession(task);
    final isResumeMode = !isCompleted && _isTaskResumeReady(task);
    final iconAndColor = _taskStyle(rawCategory, isCompleted);

    final detailParts = <String>[];
    if (hours != null && hours > 0) {
      detailParts.add(hours == 1 ? l10n.oneHour : l10n.hours(hours));
    }
    if (dueWeek != null && dueWeek > 0) {
      detailParts.add(l10n.weekNumber(dueWeek));
    }
    if (rawPhaseTitle.isNotEmpty && rawPhaseTitle != 'Roadmap') {
      detailParts.add(phaseTitle);
    }
    if (detailParts.isEmpty) {
      detailParts.add(category);
    }

    return InkWell(
      onTap: () => _openRoadmap(context, dashboard),
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 12),
        child: Row(
          children: [
            Container(
              width: 29,
              height: 29,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: iconAndColor.$2.withOpacity(0.10),
                border: Border.all(color: iconAndColor.$2.withOpacity(0.55)),
              ),
              child: Icon(iconAndColor.$1, size: 15, color: iconAndColor.$2),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isCompleted
                          ? const Color(0xFF8C8DA0)
                          : Colors.white.withOpacity(0.90),
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    detailParts.join(' · '),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.40),
                      fontSize: 9.5,
                      height: 1.35,
                    ),
                  ),
                  if (isInProgress || isResumeMode) ...[
                    const SizedBox(height: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                      decoration: BoxDecoration(
                        color: isLiveSession
                            ? const Color(0xFF63D9DD).withOpacity(0.10)
                            : isResumeMode
                                ? const Color(0xFFA88AFF).withOpacity(0.12)
                                : const Color(0xFFFFC857).withOpacity(0.10),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: isLiveSession
                              ? const Color(0xFF63D9DD).withOpacity(0.30)
                              : isResumeMode
                                  ? const Color(0xFFA88AFF).withOpacity(0.35)
                                  : const Color(0xFFFFC857).withOpacity(0.30),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (isLiveSession)
                            const _BlinkingPlayIcon()
                          else
                            Icon(
                              isResumeMode ? Icons.play_arrow_rounded : Icons.hourglass_top_rounded,
                              color: isResumeMode ? const Color(0xFFA88AFF) : const Color(0xFFFFC857),
                              size: 12,
                            ),
                          const SizedBox(width: 4),
                          Text(
                            isLiveSession
                                ? l10n.liveInProgress
                                : isResumeMode
                                    ? l10n.sessionFinishedResume
                                    : l10n.inProgress,
                            style: TextStyle(
                              color: isLiveSession
                                  ? const Color(0xFF63D9DD)
                                  : isResumeMode
                                      ? const Color(0xFFA88AFF)
                                      : const Color(0xFFFFC857),
                              fontSize: 8,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isCompleted ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              color: isCompleted ? const Color(0xFF55E5A5) : Colors.white.withOpacity(0.38),
              size: 19,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(BuildContext context, HomeDashboard dashboard) {
    final l10n = AppLocalizations.of(context)!;
    return Row(
      children: [
        Expanded(
          child: _statCard(
            label: l10n.roadmapPhases,
            value: '${dashboard.phases.length}',
            caption: l10n.stagesInPlan,
            icon: Icons.account_tree_outlined,
            color: const Color(0xFF63D9DD),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _statCard(
            label: l10n.timeHorizon,
            value: dashboard.horizonMonths == null
                ? '—'
                : l10n.monthsShort(dashboard.horizonMonths!),
            caption: l10n.plannedLearningPeriod,
            icon: Icons.calendar_month_rounded,
            color: const Color(0xFFA88AFF),
          ),
        ),
      ],
    );
  }

  Widget _statCard({
    required String label,
    required String value,
    required String caption,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      constraints: const BoxConstraints(minHeight: 104),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF111226),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF292A46)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 15),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.48),
                    fontSize: 8.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: Colors.white.withOpacity(0.36), fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildNextMilestone(BuildContext context, HomeDashboard dashboard) {
    final l10n = AppLocalizations.of(context)!;
    final milestone = dashboard.nextMilestone!;
    final title = _stringValue(milestone['title'], l10n.nextMilestoneFallback);
    final week = _intValue(milestone['target_week']);
    final criteria = _stringValue(milestone['success_criteria'], '');

    return InkWell(
      onTap: () => _openRoadmap(context, dashboard),
      borderRadius: BorderRadius.circular(15),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFF111226),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: const Color(0xFF594C91)),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: const Color(0xFF7C4DFF), borderRadius: BorderRadius.circular(10)),
              child: const Icon(Icons.flag_rounded, color: Colors.white, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    week == null ? l10n.nextMilestone : l10n.nextMilestoneWeek(week),
                    style: const TextStyle(
                      color: Color(0xFFA99DDB),
                      fontSize: 8.5,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(title, maxLines: 2, overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontSize: 11.5)),
                  if (criteria.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      criteria,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white.withOpacity(0.38), fontSize: 9.5, height: 1.3),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFB7A7FF), size: 20),
          ],
        ),
      ),
    );
  }

  Widget _emptyCard({
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF111226),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: const Color(0xFF292A46)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: const Color(0xFFA78BFA)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 5),
                Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.45), fontSize: 10.5, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _openRoadmap(BuildContext context, HomeDashboard dashboard) {
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

Future<void> _saveHomeDashboard(
  String cacheKey,
  HomeDashboard dashboard,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();

    final data = <String, dynamic>{
      'displayName': dashboard.displayName,
      'roadmapId': dashboard.roadmapId,
      'requestId': dashboard.requestId,
      'generationRequestId': dashboard.generationRequestId,
      'selectedCareerIds': dashboard.selectedCareerIds,
      'roadmapTitle': dashboard.roadmapTitle,
      'roadmapOverview': dashboard.roadmapOverview,
      'horizonMonths': dashboard.horizonMonths,
      'phases': dashboard.phases,
      'tasks': dashboard.tasks,
      'milestones': dashboard.milestones,
      'selectedCareers': dashboard.selectedCareers,
      'response': dashboard.response,
    };

    await prefs.setString(cacheKey, jsonEncode(data));
  } catch (error) {
    // A cache-write failure should not prevent online data from displaying.
    debugPrint('Failed to save dashboard cache: $error');
  }
}

Future<HomeDashboard?> _loadHomeDashboard(
  String cacheKey,
) async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final cachedJson = prefs.getString(cacheKey);

    if (cachedJson == null || cachedJson.isEmpty) {
      return null;
    }

    final decoded = jsonDecode(cachedJson);

    if (decoded is! Map) {
      return null;
    }

    final data = Map<String, dynamic>.from(decoded);

    final rawResponse = data['response'];

    return HomeDashboard(
      displayName: _stringValue(data['displayName'], ''),
      roadmapId: data['roadmapId']?.toString(),
      requestId: data['requestId']?.toString(),
      generationRequestId:
          data['generationRequestId']?.toString(),
      selectedCareerIds: data['selectedCareerIds'] is List
          ? (data['selectedCareerIds'] as List)
              .map((value) => value.toString())
              .toList()
          : <String>[],
      roadmapTitle: _stringValue(data['roadmapTitle'], ''),
      roadmapOverview: _stringValue(data['roadmapOverview'], ''),
      horizonMonths: _intValue(data['horizonMonths']),
      phases: _asMapList(data['phases']),
      tasks: _asMapList(data['tasks']),
      milestones: _asMapList(data['milestones']),
      selectedCareers: _asMapList(data['selectedCareers']),
      response: rawResponse is Map
          ? Map<String, dynamic>.from(rawResponse)
          : null,
    );
  } catch (error) {
    debugPrint('Failed to load dashboard cache: $error');
    return null;
  }
}

String _localizedCategory(AppLocalizations l10n, String rawCategory) {
  switch (rawCategory.trim().toLowerCase().replaceAll(' ', '_')) {
    case 'project':
      return l10n.categoryProject;
    case 'review':
      return l10n.categoryReview;
    case 'practice':
      return l10n.categoryPractice;
    case 'foundation':
      return l10n.categoryFoundation;
    case 'career_skill':
    case 'career_specific':
    case 'careerskill':
      return l10n.categoryCareerSkill;
    case '':
    case 'task':
      return l10n.fallbackTaskCategory;
    default:
      return rawCategory.replaceAll('_', ' ');
  }
}

/// Loads the signed-in user's profile and their latest saved roadmap.
final homeDashboardProvider =
    FutureProvider.autoDispose<HomeDashboard>((ref) async {
  final client = Supabase.instance.client;
  final user = client.auth.currentUser;

  if (user == null) {
    throw StateError('You must be signed in to load this dashboard.');
  }

  // Each signed-in user gets a separate local dashboard cache.
  final cacheKey = 'home_dashboard_${user.id}';

  try {
    final displayName =
        await ref.watch(userDisplayNameProvider.future);

    final rows = await client
        .from('roadmaps')
        .select('*')
        .eq('user_id', user.id)
        .order('created_at', ascending: false)
        .limit(1);

    if (rows.isEmpty) {
      final dashboard = HomeDashboard(
        displayName: displayName,
      );

      await _saveHomeDashboard(cacheKey, dashboard);
      return dashboard;
    }

    final row = Map<String, dynamic>.from(rows.first as Map);

    final rawRoadmapData = row['roadmap_data'];
    final roadmapData = rawRoadmapData is Map
        ? Map<String, dynamic>.from(rawRoadmapData)
        : <String, dynamic>{};

    final rowPhases = _asMapList(row['phases']);
    final phases = rowPhases.isNotEmpty
        ? rowPhases
        : _asMapList(roadmapData['phases']);

    final rowTasks = _asMapList(row['tasks']);
    final tasks = rowTasks.isNotEmpty
        ? rowTasks
        : _flattenPhaseList(phases, 'tasks');

    final rowMilestones = _asMapList(row['milestones']);
    final milestones = rowMilestones.isNotEmpty
        ? rowMilestones
        : _flattenPhaseList(phases, 'milestones');

    final rowCareers = _asMapList(row['selected_careers']);
    final selectedCareers = rowCareers.isNotEmpty
        ? rowCareers
        : _asMapList(roadmapData['selected_careers']);

    tasks.sort((a, b) {
      final weekCompare = (_intValue(a['due_week']) ?? 999999)
          .compareTo(_intValue(b['due_week']) ?? 999999);

      if (weekCompare != 0) return weekCompare;

      final phaseCompare = (_intValue(a['phase_number']) ?? 999999)
          .compareTo(_intValue(b['phase_number']) ?? 999999);

      if (phaseCompare != 0) return phaseCompare;

      return _priorityRank(a['priority'])
          .compareTo(_priorityRank(b['priority']));
    });

    milestones.sort(
      (a, b) => (_intValue(a['target_week']) ?? 999999)
          .compareTo(_intValue(b['target_week']) ?? 999999),
    );

    final roadmapId = row['id']?.toString();
    final requestId = row['career_request_id']?.toString();
    final generationRequestId =
        row['generation_request_id']?.toString();

    final selectedCareerIds = row['selected_career_ids'] is List
        ? (row['selected_career_ids'] as List)
            .map((value) => value.toString())
            .toList()
        : <String>[];

    final response = <String, dynamic>{
      ...roadmapData,
      'success': true,
      'persisted': true,
      'roadmap_data': roadmapData,
      'roadmap_id': roadmapId,
      'request_id': requestId,
      'generation_request_id': generationRequestId,
      'status': row['status'] ?? 'draft',
      'generated_at': row['created_at'],
    };

    final horizon = _intValue(
      row['planning_horizon_months'] ??
          roadmapData['planning_horizon_months'],
    );

    final dashboard = HomeDashboard(
      displayName: displayName,
      roadmapId: roadmapId,
      requestId: requestId,
      generationRequestId: generationRequestId,
      selectedCareerIds: selectedCareerIds,
      roadmapTitle: _stringValue(
        row['title'] ?? roadmapData['title'],
        '',
      ),
      roadmapOverview: _stringValue(
        row['overview'] ?? roadmapData['overview'],
        '',
      ),
      horizonMonths: horizon,
      phases: phases,
      tasks: tasks,
      milestones: milestones,
      selectedCareers: selectedCareers,
      response: response,
    );

    // Save the latest successful dashboard for offline use.
    await _saveHomeDashboard(cacheKey, dashboard);

    return dashboard;
  } catch (error, stackTrace) {
    debugPrint('Online dashboard load failed: $error');

    // If online loading fails, use the saved dashboard.
    final cachedDashboard = await _loadHomeDashboard(cacheKey);

    if (cachedDashboard != null) {
      debugPrint('Loading dashboard from local cache.');
      return cachedDashboard;
    }

    // No saved dashboard exists, so let the UI show its error state.
    Error.throwWithStackTrace(error, stackTrace);
  }
});

class HomeDashboard {
  const HomeDashboard({
    required this.displayName,
    this.roadmapId,
    this.requestId,
    this.generationRequestId,
    this.selectedCareerIds = const <String>[],
    this.roadmapTitle = '',
    this.roadmapOverview = '',
    this.horizonMonths,
    this.phases = const <Map<String, dynamic>>[],
    this.tasks = const <Map<String, dynamic>>[],
    this.milestones = const <Map<String, dynamic>>[],
    this.selectedCareers = const <Map<String, dynamic>>[],
    this.response,
  });

  final String displayName;
  final String? roadmapId;
  final String? requestId;
  final String? generationRequestId;
  final List<String> selectedCareerIds;
  final String roadmapTitle;
  final String roadmapOverview;
  final int? horizonMonths;
  final List<Map<String, dynamic>> phases;
  final List<Map<String, dynamic>> tasks;
  final List<Map<String, dynamic>> milestones;
  final List<Map<String, dynamic>> selectedCareers;
  final Map<String, dynamic>? response;

  bool get hasRoadmap => roadmapId != null && roadmapId!.isNotEmpty;

  Map<String, dynamic>? get nextMilestone {
    for (final milestone in milestones) {
      if (!_isTaskCompleted(milestone)) return milestone;
    }
    return milestones.isEmpty ? null : milestones.first;
  }
}

class _DashboardMessage extends StatelessWidget {
  const _DashboardMessage({
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
            Icon(icon, color: const Color(0xFFA78BFA), size: 34),
            const SizedBox(height: 12),
            Text(title, textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 11)),
            const SizedBox(height: 12),
            TextButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}


List<Map<String, dynamic>> _asMapList(dynamic value) {
  if (value is! List) return <Map<String, dynamic>>[];
  return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
}

List<Map<String, dynamic>> _flattenPhaseList(List<Map<String, dynamic>> phases, String key) {
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

int _priorityRank(dynamic value) {
  switch (value?.toString().toLowerCase()) {
    case 'high': return 0;
    case 'medium': return 1;
    case 'low': return 2;
    default: return 3;
  }
}

bool _isTaskCompleted(Map<String, dynamic> task) {
  if (task['is_completed'] == true || task['completed'] == true) return true;
  final status = task['status']?.toString().toLowerCase().trim();
  if (status == 'completed' || status == 'complete' || status == 'done') return true;
  final progress = _intValue(task['progress_percent']);
  return progress != null && progress >= 100;
}

bool _isTaskInProgress(Map<String, dynamic> task) {
  final status = task['status']?.toString().trim().toLowerCase();
  return status == 'in_progress' || status == 'in progress' || status == 'running';
}

bool _hasActiveTaskSession(Map<String, dynamic> task) {
  final status = task['status']?.toString().trim().toLowerCase();
  final isInProgressStatus = status == 'in_progress' || status == 'in progress' || status == 'running';
  final startedAt = task['started_at']?.toString().trim();
  final deadlineAt = task['deadline_at']?.toString().trim();
  return isInProgressStatus && startedAt != null && startedAt.isNotEmpty && deadlineAt != null && deadlineAt.isNotEmpty;
}

bool _isTaskResumeReady(Map<String, dynamic> task) {
  if (_isTaskCompleted(task)) return false;
  final status = task['status']?.toString().trim().toLowerCase();
  const resumeStatuses = {
    'session_finished', 'session finished', 'paused', 'ready_to_resume', 'ready to resume',
  };
  if (resumeStatuses.contains(status) || task['resume_mode'] == true || task['is_resume_mode'] == true || task['can_resume'] == true) {
    return true;
  }
  if (!_isTaskInProgress(task) || _hasActiveTaskSession(task)) return false;
  final trackedSeconds = _intValue(task['actual_duration_seconds']) ?? ((_intValue(task['actual_duration_minutes']) ?? 0) * 60);
  final legacySeconds = _intValue(task['legacy_tracked_seconds']) ?? 0;
  final savedSessions = task['sessions'] ?? task['time_sessions'] ?? task['task_sessions'] ?? task['session_logs'] ?? task['study_sessions'];
  final hasSavedSessions = savedSessions is List && savedSessions.isNotEmpty;
  return trackedSeconds > 0 || legacySeconds > 0 || hasSavedSessions || task['last_session_finished_at'] != null;
}

(IconData, Color) _taskStyle(String category, bool completed) {
  if (completed) return (Icons.check_rounded, const Color(0xFF55E5A5));
  switch (category.toLowerCase()) {
    case 'project': return (Icons.code_rounded, const Color(0xFFA88AFF));
    case 'review': return (Icons.quiz_outlined, const Color(0xFF63D9DD));
    case 'practice': return (Icons.fitness_center_rounded, const Color(0xFFFFC857));
    case 'foundation': return (Icons.menu_book_rounded, const Color(0xFF8B91FF));
    case 'career_skill':
    case 'career_specific': return (Icons.work_outline_rounded, const Color(0xFF63D9DD));
    default: return (Icons.task_alt_rounded, const Color(0xFFA88AFF));
  }
}

class _BlinkingPlayIcon extends StatefulWidget {
  const _BlinkingPlayIcon();
  @override
  State<_BlinkingPlayIcon> createState() => _BlinkingPlayIconState();
}

class _BlinkingPlayIconState extends State<_BlinkingPlayIcon> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))..repeat(reverse: true);
    _opacity = Tween<double>(begin: 0.2, end: 1.0).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
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
      child: const Icon(Icons.play_circle_fill_rounded, color: Color(0xFF63D9DD), size: 12),
    );
  }
}

class _HomeDashboardSkeleton extends StatefulWidget {
  const _HomeDashboardSkeleton();

  @override
  State<_HomeDashboardSkeleton> createState() => _HomeDashboardSkeletonState();
}

class _HomeDashboardSkeletonState extends State<_HomeDashboardSkeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
    _animation = Tween<double>(begin: -1.5, end: 2.5).animate(
      CurvedAnimation(parent: _controller, curve: Curves.linear),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: AnimatedBuilder(
        animation: _animation,
        builder: (context, child) => Stack(
          fit: StackFit.passthrough,
          children: [
            child!,
            Positioned.fill(
              child: IgnorePointer(
                child: FractionalTranslation(
                  translation: Offset(
                    _animation.value * 0.35,
                    -_animation.value * 0.35,
                  ),
                  child: Transform.rotate(
                    angle: -0.35,
                    child: Align(
                      alignment: Alignment.bottomLeft,
                      child: FractionallySizedBox(
                        widthFactor: 0.42,
                        heightFactor: 1.8,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.centerLeft,
                              end: Alignment.centerRight,
                              colors: [
                                Colors.white.withOpacity(0.0),
                                Colors.white.withOpacity(0.025),
                                Colors.white.withOpacity(0.075),
                                Colors.white.withOpacity(0.025),
                                Colors.white.withOpacity(0.0),
                              ],
                              stops: const [0.0, 0.25, 0.5, 0.75, 1.0],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        child: const _HomeDashboardSkeletonContent(),
      ),
    );
  }
}

class _HomeDashboardSkeletonContent extends StatelessWidget {
  const _HomeDashboardSkeletonContent();

  static const Color _surface = Color(0xFF111226);
  static const Color _placeholder = Color(0xFF292A46);
  static const Color _border = Color(0xFF292A46);

  Widget _block({double? width, double height = 10, double radius = 6}) => Container(
    width: width,
    height: height,
    decoration: BoxDecoration(color: _placeholder, borderRadius: BorderRadius.circular(radius)),
  );

  Widget _taskRow() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 13),
    child: Row(
      children: [
        Container(width: 29, height: 29, decoration: const BoxDecoration(color: _placeholder, shape: BoxShape.circle)),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _block(width: 155), const SizedBox(height: 7), _block(width: 105, height: 8),
        ])),
        const SizedBox(width: 8), _block(width: 13, height: 13, radius: 20),
      ],
    ),
  );

  Widget _sectionCard({required Widget child, EdgeInsets padding = const EdgeInsets.all(12), double radius = 15, Color background = _surface, Color borderColor = _border}) => Container(
    width: double.infinity,
    padding: padding,
    decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(radius), border: Border.all(color: borderColor)),
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _block(width: 125, height: 9), const SizedBox(height: 9), _block(width: 185, height: 17),
          ])),
          Container(width: 40, height: 40, padding: const EdgeInsets.all(3), decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0xFF4D477F), width: 1.5)), child: Container(decoration: const BoxDecoration(color: _placeholder, shape: BoxShape.circle))),
        ]),
        const SizedBox(height: 20),
        _sectionCard(background: const Color(0xFF171A3B), borderColor: const Color(0xFF4D477F), radius: 18, padding: const EdgeInsets.all(15), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Container(width: 48, height: 48, decoration: BoxDecoration(color: const Color(0xFF29284B), borderRadius: BorderRadius.circular(15))),
          const SizedBox(width: 12), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _block(width: 115, height: 8), const SizedBox(height: 11), _block(width: 175, height: 13), const SizedBox(height: 7), _block(width: 145, height: 13), const SizedBox(height: 12), _block(height: 8), const SizedBox(height: 6), _block(width: 155, height: 8), const SizedBox(height: 6), _block(width: 115, height: 8), const SizedBox(height: 14), _block(width: 95, height: 10),
          ])),
        ])),
        const SizedBox(height: 22),
        Row(children: [Expanded(child: _block(width: 110, height: 15)), _block(width: 80, height: 9)]),
        const SizedBox(height: 10),
        _sectionCard(padding: EdgeInsets.zero, child: Column(children: [
          _taskRow(), Divider(height: 1, thickness: 1, color: Colors.white.withOpacity(0.055)), _taskRow(), Divider(height: 1, thickness: 1, color: Colors.white.withOpacity(0.055)), _taskRow(),
        ])),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _sectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_block(width: 105, height: 9), const SizedBox(height: 13), _block(width: 45, height: 23), const SizedBox(height: 9), _block(width: 105, height: 8)]))),
          const SizedBox(width: 10),
          Expanded(child: _sectionCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_block(width: 95, height: 9), const SizedBox(height: 13), _block(width: 65, height: 23), const SizedBox(height: 9), _block(width: 105, height: 8)]))),
        ]),
        const SizedBox(height: 14),
        _sectionCard(child: Row(children: [
          Container(width: 34, height: 34, decoration: BoxDecoration(color: _placeholder, borderRadius: BorderRadius.circular(10))),
          const SizedBox(width: 10), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [_block(width: 130, height: 8), const SizedBox(height: 8), _block(width: 155, height: 11), const SizedBox(height: 7), _block(width: 115, height: 8)])),
          const SizedBox(width: 8), _block(width: 14, height: 14, radius: 20),
        ])),
        const SizedBox(height: 20),
      ]),
    );
  }
}
