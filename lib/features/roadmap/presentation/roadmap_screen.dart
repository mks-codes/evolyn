import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:evolyn/core/widgets/page_auto_refresh.dart';
import 'package:evolyn/features/roadmap/providers/roadmap_cache_provider.dart';
import 'package:evolyn/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class RoadmapScreen extends ConsumerStatefulWidget {
  const RoadmapScreen({
    super.key,
    this.isActive = true,
    this.roadmapData,
    this.selectedCareers = const [],
    this.roadmapId,
    this.requestId,
    this.generationRequestId,
  });

  final bool isActive;
  final Map<String, dynamic>? roadmapData;
  final List<Map<String, dynamic>> selectedCareers;
  final String? roadmapId;
  final String? requestId;
  final String? generationRequestId;

  @override
  ConsumerState<RoadmapScreen> createState() => _RoadmapScreenState();
}

class _RoadmapScreenState extends ConsumerState<RoadmapScreen> {
  static const Color _background = Color(0xFF050614);
  static const Color _panel = Color(0xFF101124);
  static const Color _panelLight = Color(0xFF17182D);
  static const Color _purple = Color(0xFFA78BFA);
  static const Color _teal = Color(0xFF65D9DC);
  static const Color _green = Color(0xFF59D9A7);

  AppLocalizations get _l10n => AppLocalizations.of(context)!;

  late Map<String, dynamic> _response;
  late Map<String, dynamic> _roadmap;
  late String _generationRequestId;
  String? _roadmapId;
  String? _careerRequestId;
  String _roadmapStatus = 'draft';

  final Map<String, TextEditingController> _editors = {};
  final Set<int> _expandedPhases = {0};
  final ScrollController _roadmapScrollController = ScrollController();
  final GlobalKey _activeTaskScrollKey = GlobalKey();

  bool _isEditing = false;
  bool _hasUnsavedChanges = false;
  bool _isSaving = false;
  String? _saveError;
  OverlayEntry? _topMessageEntry;
  Timer? _topMessageTimer;

  bool get _hasRoadmap => _asMapList(_roadmap['phases']).isNotEmpty;
  List<Map<String, dynamic>> get _phases => _asMapList(_roadmap['phases']);

  int get _totalTasks => _phases.fold<int>(
        0,
        (sum, phase) => sum + _asMapList(phase['tasks']).length,
      );

  int get _completedTasks => _phases.fold<int>(
        0,
        (sum, phase) => sum +
            _asMapList(phase['tasks'])
                .where((task) => task['completed'] == true)
                .length,
      );

  double get _progress => _totalTasks == 0 ? 0 : _completedTasks / _totalTasks;

  @override
  void initState() {
    super.initState();
    _response = Map<String, dynamic>.from(widget.roadmapData ?? const {});
    final nested = _response['roadmap_data'] ?? _response['roadmap'];
    _roadmap = _deepCopyMap(nested is Map ? nested : _response);
    _roadmap['title'] ??= '';
    _roadmap['overview'] ??= '';
    _roadmap['phases'] ??= <dynamic>[];

    _roadmapId = widget.roadmapId ?? _response['roadmap_id']?.toString();
    _careerRequestId = widget.requestId ?? _response['request_id']?.toString();
    _generationRequestId = widget.generationRequestId ??
        _response['generation_request_id']?.toString() ??
        _newUuidV4();
    _roadmapStatus = _response['status']?.toString() ?? 'draft';
    _createEditors();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !widget.isActive) return;
      _openAndCenterActiveTask();
      _refreshRoadmap();
    });
  }

  @override
  void didUpdateWidget(covariant RoadmapScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!oldWidget.isActive && widget.isActive) _refreshRoadmap();
  }

  Map<String, int>? _findActiveTaskLocation() {
    Map<String, int>? firstInProgress;
    for (var phaseIndex = 0; phaseIndex < _phases.length; phaseIndex++) {
      final tasks = _asMapList(_phases[phaseIndex]['tasks']);
      for (var taskIndex = 0; taskIndex < tasks.length; taskIndex++) {
        final task = tasks[taskIndex];
        final status = (task['status'] ?? '').toString().trim().toLowerCase();
        if (status != 'in_progress' && status != 'in progress' && status != 'running') {
          continue;
        }
        final location = <String, int>{
          'phaseIndex': phaseIndex,
          'taskIndex': taskIndex,
        };
        final startedAt = DateTime.tryParse((task['started_at'] ?? '').toString());
        final deadlineAt = DateTime.tryParse((task['deadline_at'] ?? '').toString());
        if (startedAt != null && deadlineAt != null) return location;
        firstInProgress ??= location;
      }
    }
    return firstInProgress;
  }

  void _openAndCenterActiveTask() {
    if (!mounted || !_hasRoadmap) return;
    final location = _findActiveTaskLocation();
    if (location == null) return;
    final phaseIndex = location['phaseIndex']!;
    if (!_expandedPhases.contains(phaseIndex) || _expandedPhases.length != 1) {
      setState(() => _expandedPhases..clear()..add(phaseIndex));
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _centerActiveTask());
  }

  void _centerActiveTask() {
    if (!mounted) return;
    final taskContext = _activeTaskScrollKey.currentContext;
    if (taskContext == null) return;
    Scrollable.ensureVisible(
      taskContext,
      alignment: 0.5,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _refreshRoadmap() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    if (userId == null) {
      _showMessage(_l10n.signInToRefresh);
      return;
    }
    if (_isSaving) {
      _showMessage(_l10n.waitUntilSavingFinishes);
      return;
    }
    if (_isEditing && _hasUnsavedChanges) {
      _showMessage(_l10n.saveOrCancelBeforeRefreshing);
      return;
    }

    try {
      final Map<String, dynamic>? row;
      if (_roadmapId != null && _roadmapId!.isNotEmpty) {
        final result = await supabase
            .from('roadmaps')
            .select('*')
            .eq('user_id', userId)
            .eq('id', _roadmapId!)
            .maybeSingle();
        row = result == null ? null : Map<String, dynamic>.from(result);
      } else {
        final result = await supabase
            .from('roadmaps')
            .select('*')
            .eq('user_id', userId)
            .order('updated_at', ascending: false)
            .limit(1)
            .maybeSingle();
        row = result == null ? null : Map<String, dynamic>.from(result);
      }

      if (row == null) {
        _showMessage(_l10n.noSavedRoadmapFound);
        return;
      }
      try {
        await ref.read(roadmapCacheRepositoryProvider).storeLocal(userId, row);
      } catch (error) {
        debugPrint('[RoadmapScreen] Cache update failed: $error');
      }
      if (!mounted) return;
      setState(() {
        _loadRoadmapFromSavedRow(row!);
        _isEditing = false;
        _hasUnsavedChanges = false;
        _saveError = null;
        final activeLocation = _findActiveTaskLocation();
        _expandedPhases..clear()..add(activeLocation?['phaseIndex'] ?? 0);
      });
      WidgetsBinding.instance.addPostFrameCallback((_) => _openAndCenterActiveTask());
    } catch (error, stackTrace) {
      debugPrint('[RoadmapScreen] Refresh failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      if (mounted) _showMessage(_l10n.refreshRoadmapError);
    }
  }

  void _loadRoadmapFromSavedRow(Map<String, dynamic> row) {
    final savedData = row['roadmap_data'];
    final freshRoadmap = _deepCopyMap(savedData is Map ? savedData : row);
    for (final key in [
      'title', 'overview', 'planning_horizon_months', 'timeline_summary',
      'phases', 'assumptions', 'weekly_rhythm', 'risks_and_adjustments',
      'progress_tracking',
    ]) {
      if (freshRoadmap[key] == null ||
          (key == 'phases' && _asMapList(freshRoadmap[key]).isEmpty)) {
        if (row[key] != null) freshRoadmap[key] = row[key];
      }
    }
    freshRoadmap['title'] ??= '';
    freshRoadmap['overview'] ??= '';
    freshRoadmap['phases'] ??= <dynamic>[];
    _response = Map<String, dynamic>.from(row)
      ..['roadmap_id'] = row['id']
      ..['generation_request_id'] = row['generation_request_id'];
    _roadmap = freshRoadmap;
    _roadmapId = row['id']?.toString();
    _careerRequestId = row['career_request_id']?.toString();
    _generationRequestId = row['generation_request_id']?.toString() ?? _generationRequestId;
    _roadmapStatus = row['status']?.toString() ?? 'draft';
    _createEditors();
  }

  Map<String, dynamic> _deepCopyMap(dynamic source) {
    if (source is! Map) return <String, dynamic>{};
    final decoded = jsonDecode(jsonEncode(source));
    return Map<String, dynamic>.from(decoded as Map);
  }

  List<Map<String, dynamic>> _asMapList(dynamic value) {
    if (value is! List) return <Map<String, dynamic>>[];
    return value.whereType<Map>().map((item) => Map<String, dynamic>.from(item)).toList();
  }

  Map<String, dynamic> _asMap(dynamic value) =>
      value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

  String _newUuidV4() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20, 32)}';
  }

  void _addEditor(String path, dynamic value) {
    if (value is String || value is num) {
      _editors[path] = TextEditingController(text: value.toString());
    }
  }

  void _createEditors() {
    _disposeEditors();
    _addEditor('title', _roadmap['title']);
    _addEditor('overview', _roadmap['overview']);
    _addEditor('planning_horizon_months', _roadmap['planning_horizon_months']);
    _addEditor('timeline_summary', _roadmap['timeline_summary']);

    final phases = _roadmap['phases'];
    if (phases is List) {
      for (var i = 0; i < phases.length; i++) {
        final phase = phases[i];
        if (phase is! Map) continue;
        final p = Map<String, dynamic>.from(phase);
        for (final key in ['title', 'objective', 'start_week', 'end_week', 'duration_weeks', 'review_checkpoint']) {
          _addEditor('phases.$i.$key', p[key]);
        }
        final outcomes = p['outcomes'];
        if (outcomes is List) {
          for (var j = 0; j < outcomes.length; j++) {
            _addEditor('phases.$i.outcomes.$j', outcomes[j]);
          }
        }
        final milestones = p['milestones'];
        if (milestones is List) {
          for (var j = 0; j < milestones.length; j++) {
            if (milestones[j] is! Map) continue;
            final m = Map<String, dynamic>.from(milestones[j] as Map);
            for (final key in ['title', 'target_week', 'success_criteria']) {
              _addEditor('phases.$i.milestones.$j.$key', m[key]);
            }
          }
        }
        final tasks = p['tasks'];
        if (tasks is List) {
          for (var j = 0; j < tasks.length; j++) {
            if (tasks[j] is! Map) continue;
            final t = Map<String, dynamic>.from(tasks[j] as Map);
            for (final key in ['title', 'description', 'category', 'estimated_hours', 'due_week', 'priority', 'deliverable', 'success_criteria']) {
              _addEditor('phases.$i.tasks.$j.$key', t[key]);
            }
          }
        }
        final alignment = p['career_alignment'];
        if (alignment is List) {
          for (var j = 0; j < alignment.length; j++) {
            if (alignment[j] is! Map) continue;
            _addEditor('phases.$i.career_alignment.$j.how_this_phase_supports_career',
                (alignment[j] as Map)['how_this_phase_supports_career']);
          }
        }
      }
    }

    final rhythm = _asMap(_roadmap['weekly_rhythm']);
    _addEditor('weekly_rhythm.hours_per_week', rhythm['hours_per_week']);
    final schedule = rhythm['suggested_schedule'];
    if (schedule is List) {
      for (var i = 0; i < schedule.length; i++) {
        if (schedule[i] is! Map) continue;
        final item = Map<String, dynamic>.from(schedule[i] as Map);
        for (final key in ['time_block', 'hours', 'activity']) {
          _addEditor('weekly_rhythm.suggested_schedule.$i.$key', item[key]);
        }
      }
    }
    final assumptions = _roadmap['assumptions'];
    if (assumptions is List) {
      for (var i = 0; i < assumptions.length; i++) _addEditor('assumptions.$i', assumptions[i]);
    }
    final risks = _roadmap['risks_and_adjustments'];
    if (risks is List) {
      for (var i = 0; i < risks.length; i++) {
        if (risks[i] is! Map) continue;
        final risk = Map<String, dynamic>.from(risks[i] as Map);
        for (final key in ['risk', 'mitigation', 'trigger_to_adjust']) {
          _addEditor('risks_and_adjustments.$i.$key', risk[key]);
        }
      }
    }
    final tracking = _asMap(_roadmap['progress_tracking']);
    _addEditor('progress_tracking.review_frequency', tracking['review_frequency']);
    _addEditor('progress_tracking.next_action', tracking['next_action']);
    final metrics = tracking['metrics'];
    if (metrics is List) {
      for (var i = 0; i < metrics.length; i++) _addEditor('progress_tracking.metrics.$i', metrics[i]);
    }
  }

  dynamic _readPath(String path) {
    dynamic current = _roadmap;
    for (final part in path.split('.')) {
      if (current is Map) {
        current = current[part];
      } else if (current is List) {
        final index = int.tryParse(part);
        if (index == null || index < 0 || index >= current.length) return null;
        current = current[index];
      } else {
        return null;
      }
    }
    return current;
  }

  void _writePath(String path, dynamic value) {
    final parts = path.split('.');
    dynamic current = _roadmap;
    for (var i = 0; i < parts.length - 1; i++) {
      final part = parts[i];
      if (current is Map) {
        current = current[part];
      } else if (current is List) {
        current = current[int.parse(part)];
      }
    }
    final last = parts.last;
    if (current is Map) {
      current[last] = value;
    } else if (current is List) {
      current[int.parse(last)] = value;
    }
  }

  void _syncEditorsToRoadmap() {
    for (final entry in _editors.entries) {
      final oldValue = _readPath(entry.key);
      final text = entry.value.text.trim();
      if (oldValue is int) {
        final parsed = int.tryParse(text);
        if (parsed != null) _writePath(entry.key, parsed);
      } else if (oldValue is double) {
        final parsed = double.tryParse(text);
        if (parsed != null) _writePath(entry.key, parsed);
      } else {
        _writePath(entry.key, text);
      }
    }
  }

  void _markDirty() {
    if (!_hasUnsavedChanges && mounted) {
      setState(() {
        _hasUnsavedChanges = true;
        _saveError = null;
      });
    }
  }

  Widget _field(String path, String label, {String? fallback, int maxLines = 1, bool prominent = false}) {
    final controller = _editors[path];
    final value = controller?.text ?? _readPath(path)?.toString() ?? fallback ?? '';
    if (_isEditing && controller != null) {
      return Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label.toUpperCase(), style: const TextStyle(color: _purple, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 0.7)),
            const SizedBox(height: 5),
            TextField(
              controller: controller,
              maxLines: maxLines,
              keyboardType: path.endsWith('_week') || path.endsWith('_weeks') || path.endsWith('_hours') || path.endsWith('months')
                  ? TextInputType.number
                  : (maxLines > 1 ? TextInputType.multiline : TextInputType.text),
              onChanged: (_) => _markDirty(),
              style: TextStyle(color: Colors.white, fontSize: prominent ? 19 : 12, height: 1.4, fontWeight: prominent ? FontWeight.w700 : FontWeight.w400),
              decoration: InputDecoration(
                isDense: true,
                filled: true,
                fillColor: const Color(0xFF0A0B19),
                hintText: label,
                hintStyle: const TextStyle(color: Colors.white30),
                contentPadding: const EdgeInsets.all(11),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: Color(0xFF343450))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(11), borderSide: const BorderSide(color: _purple)),
              ),
            ),
          ],
        ),
      );
    }
    if (value.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 5, bottom: 3),
      child: Text(value, style: TextStyle(color: prominent ? Colors.white : Colors.white.withOpacity(0.72), fontSize: prominent ? 21 : 11.5, height: 1.45, fontWeight: prominent ? FontWeight.w700 : FontWeight.w400)),
    );
  }

  @override
  Widget build(BuildContext context) => PageAutoRefresh(
        isActive: widget.isActive,
        onRefresh: _refreshRoadmap,
        child: _buildRoadmapContext(context),
      );

  Widget _buildRoadmapContext(BuildContext context) {
    final l10n = _l10n;
    if (!_hasRoadmap) return _buildEmptyState();
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(
        backgroundColor: _background,
        foregroundColor: Colors.white,
        elevation: 0,
        title: Text(l10n.roadmapScreenTitle, style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (!_isEditing)
            IconButton(
              tooltip: l10n.editRoadmap,
              onPressed: _isSaving ? null : () => setState(() {
                _isEditing = true;
                _hasUnsavedChanges = false;
                _saveError = null;
              }),
              icon: const Icon(Icons.edit_outlined, color: _purple),
            ),
          const SizedBox(width: 6),
        ],
      ),
      body: Column(
        children: [
          if (_saveError != null)
            Container(
              width: double.infinity,
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(color: const Color(0xFF351A2A), borderRadius: BorderRadius.circular(10), border: Border.all(color: const Color(0xFF78354E))),
              child: Text(_saveError!, style: const TextStyle(color: Color(0xFFFFB4C2), fontSize: 12)),
            ),
          Expanded(
            child: RefreshIndicator(
              color: _purple,
              backgroundColor: _panel,
              onRefresh: _refreshRoadmap,
              child: SingleChildScrollView(
                controller: _roadmapScrollController,
                physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildHero(),
                    const SizedBox(height: 14),
                    _buildStats(),
                    const SizedBox(height: 22),
                    _sectionTitle(l10n.yourTimeline, l10n.phaseCount(_phases.length)),
                    const SizedBox(height: 10),
                    ...List.generate(_phases.length, (index) => _buildPhaseCard(index, _phases[index])),
                    const SizedBox(height: 12),
                    _buildWeeklyRhythm(),
                    const SizedBox(height: 12),
                    _buildProgressTracking(),
                    const SizedBox(height: 12),
                    _buildRisks(),
                    const SizedBox(height: 12),
                    _buildAssumptions(),
                    const SizedBox(height: 16),
                    _buildEditHint(),
                  ],
                ),
              ),
            ),
          ),
          _buildBottomActions(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    final l10n = _l10n;
    return Scaffold(
      backgroundColor: _background,
      appBar: AppBar(backgroundColor: _background, foregroundColor: Colors.white, title: Text(l10n.roadmapScreenTitle)),
      body: SafeArea(
        child: RefreshIndicator(
          color: _purple,
          backgroundColor: _panel,
          onRefresh: _refreshRoadmap,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            padding: const EdgeInsets.all(28),
            children: [
              SizedBox(height: MediaQuery.sizeOf(context).height * 0.12),
              Icon(Icons.map_outlined, color: _purple.withOpacity(0.9), size: 44),
              const SizedBox(height: 16),
              Text(l10n.noSavedRoadmapFound, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text(l10n.viewRoadmapHint, textAlign: TextAlign.center, style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 11, height: 1.5)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHero() {
    final l10n = _l10n;
    final horizon = _int(_roadmap['planning_horizon_months']);
    final selectedTitles = widget.selectedCareers
        .map((career) => career['career_title']?.toString() ?? '')
        .where((title) => title.isNotEmpty)
        .toList();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: const LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [Color(0xFF251B4B), Color(0xFF101A2D)]),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF55477F)),
        boxShadow: [BoxShadow(color: const Color(0xFF7C3AED).withOpacity(0.09), blurRadius: 24, offset: const Offset(0, 8))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
                decoration: BoxDecoration(color: _purple.withOpacity(0.16), borderRadius: BorderRadius.circular(9)),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.auto_awesome_rounded, color: Color(0xFFC6B8FF), size: 13),
                  const SizedBox(width: 5),
                  Text(l10n.personalizedRoadmap, style: const TextStyle(color: Color(0xFFC6B8FF), fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.6)),
                ]),
              ),
              const Spacer(),
              if (_isEditing) const Icon(Icons.edit_note_rounded, color: _purple),
            ],
          ),
          const SizedBox(height: 12),
          _field('title', l10n.roadmapTitleLabel, fallback: l10n.roadmapScreenTitle, maxLines: 2, prominent: true),
          _field('overview', l10n.overviewLabel, fallback: '', maxLines: 4),
          if (selectedTitles.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(spacing: 7, runSpacing: 7, children: selectedTitles.map((title) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.white.withOpacity(0.07), borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.white.withOpacity(0.10))),
              child: Text(title, style: const TextStyle(color: Colors.white70, fontSize: 10)),
            )).toList()),
          ],
          const SizedBox(height: 15),
          Row(
            children: [
              const Icon(Icons.calendar_month_outlined, color: _teal, size: 16),
              const SizedBox(width: 7),
              Expanded(child: Text(horizon > 0 ? l10n.planningHorizonMonths(horizon) : l10n.weeksPlanned(_maxWeek), style: const TextStyle(color: Color(0xFF8CE5E3), fontSize: 11, fontWeight: FontWeight.w600))),
              const SizedBox(width: 6),
              Text(l10n.tasksChecked((_progress * 100).round()), style: TextStyle(color: Colors.white.withOpacity(0.55), fontSize: 10)),
            ],
          ),
          const SizedBox(height: 9),
          ClipRRect(borderRadius: BorderRadius.circular(12), child: LinearProgressIndicator(value: _progress, minHeight: 5, backgroundColor: Colors.white.withOpacity(0.09), valueColor: const AlwaysStoppedAnimation<Color>(_teal))),
          if (_isEditing) ...[
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Expanded(child: _field('planning_horizon_months', l10n.planningHorizonMonths(math.max(1, horizon)))),
              const SizedBox(width: 10),
              Expanded(flex: 2, child: _field('timeline_summary', l10n.overviewLabel, maxLines: 3)),
            ]),
          ] else if (_roadmap['timeline_summary'] is String && (_roadmap['timeline_summary'] as String).trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(_roadmap['timeline_summary'].toString(), style: TextStyle(color: Colors.white.withOpacity(0.48), fontSize: 10.5, height: 1.4)),
          ],
        ],
      ),
    );
  }

  int get _maxWeek {
    var maxWeek = 0;
    for (final phase in _phases) {
      maxWeek = math.max(maxWeek, _int(phase['end_week']));
    }
    return maxWeek;
  }

  Widget _buildStats() {
    final l10n = _l10n;
    final milestones = _phases.fold<int>(0, (sum, phase) => sum + _asMapList(phase['milestones']).length);
    return Row(children: [
      Expanded(child: _statCard(Icons.layers_outlined, l10n.phasesLabel, '${_phases.length}', l10n.timelineStages, _purple)),
      const SizedBox(width: 9),
      Expanded(child: _statCard(Icons.flag_outlined, l10n.milestonesLabel, '$milestones', l10n.targetOutcomes, _green)),
      const SizedBox(width: 9),
      Expanded(child: _statCard(Icons.task_alt_rounded, l10n.tasksLabel, '$_totalTasks', l10n.plannedActions, _teal)),
    ]);
  }

  Widget _statCard(IconData icon, String label, String value, String detail, Color color) {
    return Container(
      padding: const EdgeInsets.fromLTRB(11, 12, 8, 11),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(15), border: Border.all(color: const Color(0xFF282943))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Icon(icon, color: color, size: 16),
        const SizedBox(height: 9),
        Text(value, style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w700)),
        const SizedBox(height: 3),
        Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.44), fontSize: 7.5, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
        const SizedBox(height: 2),
        Text(detail, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.white.withOpacity(0.28), fontSize: 8)),
      ]),
    );
  }

  Widget _sectionTitle(String title, String trailing) => Row(children: [
    Expanded(child: Text(title, style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w700))),
    Text(trailing, style: TextStyle(color: Colors.white.withOpacity(0.40), fontSize: 10)),
  ]);

  Widget _buildPhaseCard(int index, Map<String, dynamic> phase) {
    final l10n = _l10n;
    final expanded = _expandedPhases.contains(index);
    final number = _int(phase['phase_number'], fallback: index + 1);
    final start = _int(phase['start_week'], fallback: 1);
    final end = _int(phase['end_week'], fallback: start);
    final tasks = _asMapList(phase['tasks']);
    final activeLocation = _findActiveTaskLocation();
    final milestones = _asMapList(phase['milestones']);
    final outcomes = phase['outcomes'] is List ? List<dynamic>.from(phase['outcomes'] as List) : <dynamic>[];
    final completeCount = tasks.where((task) => task['completed'] == true).length;
    final phaseColor = index == 0 ? _purple : index == 1 ? _teal : const Color(0xFF8797FF);

    return Container(
      margin: const EdgeInsets.only(bottom: 11),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(18), border: Border.all(color: expanded ? phaseColor.withOpacity(0.62) : const Color(0xFF292A46))),
      child: Column(children: [
        InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: _isEditing ? null : () => setState(() {
            if (expanded) { _expandedPhases.remove(index); } else { _expandedPhases.add(index); }
          }),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Container(width: 37, height: 37, alignment: Alignment.center, decoration: BoxDecoration(color: phaseColor.withOpacity(0.14), borderRadius: BorderRadius.circular(12), border: Border.all(color: phaseColor.withOpacity(0.35))), child: Text(number.toString().padLeft(2, '0'), style: TextStyle(color: phaseColor, fontSize: 12, fontWeight: FontWeight.w800))),
              const SizedBox(width: 11),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Wrap(spacing: 6, runSpacing: 5, crossAxisAlignment: WrapCrossAlignment.center, children: [
                  Text(l10n.phaseNumber(number), style: TextStyle(color: phaseColor, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.7)),
                  if (!_isEditing) _pill(l10n.weekRange(start, end), const Color(0xFF8ACFD3)),
                ]),
                const SizedBox(height: 7),
                _field('phases.$index.title', l10n.phaseTitleLabel, fallback: l10n.phaseFallbackTitle(number), maxLines: 2),
                _field('phases.$index.objective', l10n.objectiveLabel, maxLines: 3),
                if (_isEditing) ...[
                  const SizedBox(height: 5),
                  Row(children: [
                    Expanded(child: _field('phases.$index.start_week', l10n.startWeekLabel)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('phases.$index.end_week', l10n.endWeekLabel)),
                    const SizedBox(width: 8),
                    Expanded(child: _field('phases.$index.duration_weeks', l10n.durationWeeksLabel)),
                  ]),
                ],
                const SizedBox(height: 7),
                Row(children: [
                  Icon(Icons.checklist_rounded, color: Colors.white.withOpacity(0.36), size: 13),
                  const SizedBox(width: 4),
                  Expanded(child: Text(l10n.taskCountSummary(tasks.length, completeCount), style: TextStyle(color: Colors.white.withOpacity(0.42), fontSize: 9))),
                  Text(l10n.durationWeeks(_int(phase['duration_weeks'], fallback: math.max(1, end - start + 1).toInt())), style: TextStyle(color: Colors.white.withOpacity(0.42), fontSize: 9)),
                ]),
              ])),
              const SizedBox(width: 4),
              Icon(expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, color: Colors.white54),
            ]),
          ),
        ),
        if (expanded) Padding(
          padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Divider(color: Color(0xFF282943), height: 1),
            const SizedBox(height: 11),
            if (outcomes.isNotEmpty) ...[
              _subheading(l10n.expectedOutcomes),
              const SizedBox(height: 5),
              ...List.generate(outcomes.length, (i) => Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.check_circle_outline, color: _green, size: 14),
                  const SizedBox(width: 7),
                  Expanded(child: _field('phases.$index.outcomes.$i', l10n.outcomeNumber(i + 1), maxLines: 3)),
                ]),
              )),
              const SizedBox(height: 9),
            ],
            if (milestones.isNotEmpty) ...[
              _subheading(l10n.milestones),
              const SizedBox(height: 6),
              ...List.generate(milestones.length, (i) => Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: _panelLight, borderRadius: BorderRadius.circular(12)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.flag_outlined, color: _purple, size: 14),
                    const SizedBox(width: 6),
                    Expanded(child: _field('phases.$index.milestones.$i.title', l10n.milestoneLabel, fallback: l10n.milestoneNumber(i + 1))),
                    if (!_isEditing) _pill(l10n.dueWeekValue(_int(milestones[i]['target_week'])), const Color(0xFF8ACFD3)),
                  ]),
                  if (_isEditing) _field('phases.$index.milestones.$i.target_week', l10n.targetWeekLabel),
                  _field('phases.$index.milestones.$i.success_criteria', l10n.successCriteriaLabel, maxLines: 3),
                ]),
              )),
              const SizedBox(height: 8),
            ],
            if (tasks.isNotEmpty) ...[
              _subheading(l10n.tasksAndDeliverables),
              const SizedBox(height: 6),
              ...List.generate(tasks.length, (i) => _buildTask(index, i, tasks[i], isActiveTask: activeLocation?['phaseIndex'] == index && activeLocation?['taskIndex'] == i)),
              const SizedBox(height: 8),
            ],
            _finalReviewField(index, phase),
            _buildCareerAlignment(index, phase),
          ]),
        ),
      ]),
    );
  }

  Widget _finalReviewField(int index, Map<String, dynamic> phase) {
    final l10n = _l10n;
    if (phase['review_checkpoint'] == null) return const SizedBox.shrink();
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: const Color(0xFF102329), borderRadius: BorderRadius.circular(12), border: Border.all(color: const Color(0xFF24474C))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.rate_review_outlined, color: _teal, size: 16),
        const SizedBox(width: 8),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l10n.reviewCheckpoint, style: const TextStyle(color: _teal, fontSize: 8, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
          _field('phases.$index.review_checkpoint', l10n.reviewCheckpointLabel, maxLines: 3),
        ])),
      ]),
    );
  }

  Widget _buildCareerAlignment(int phaseIndex, Map<String, dynamic> phase) {
    final l10n = _l10n;
    final alignments = _asMapList(phase['career_alignment']);
    if (alignments.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _subheading(l10n.careerAlignment),
        const SizedBox(height: 6),
        ...List.generate(alignments.length, (i) {
          final item = alignments[i];
          return Padding(padding: const EdgeInsets.only(bottom: 7), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(item['career_title']?.toString() ?? l10n.selectedCareer, style: const TextStyle(color: Color(0xFFC6B8FF), fontSize: 10, fontWeight: FontWeight.w700)),
            _field('phases.$phaseIndex.career_alignment.$i.how_this_phase_supports_career', l10n.careerAlignmentDescription, maxLines: 3),
          ]));
        }),
      ]),
    );
  }

  Widget _buildTask(int phaseIndex, int taskIndex, Map<String, dynamic> task, {bool isActiveTask = false}) {
    final l10n = _l10n;
    final completed = task['completed'] == true;
    final path = 'phases.$phaseIndex.tasks.$taskIndex';
    return Container(
      key: isActiveTask ? _activeTaskScrollKey : null,
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(11),
      decoration: BoxDecoration(color: const Color(0xFF0B0C1C), borderRadius: BorderRadius.circular(13), border: Border.all(color: completed ? const Color(0xFF285441) : const Color(0xFF252640))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          if (!_isEditing) Container(width: 22, height: 22, decoration: BoxDecoration(color: completed ? const Color(0xFF174331) : const Color(0xFF17182D), shape: BoxShape.circle, border: Border.all(color: completed ? _green : const Color(0xFF45465F))), child: completed ? const Icon(Icons.check_rounded, color: _green, size: 14) : null),
          if (!_isEditing) const SizedBox(width: 9),
          Expanded(child: _field('$path.title', l10n.taskTitleLabel, fallback: l10n.taskNumber(taskIndex + 1), maxLines: 3)),
          const SizedBox(width: 7),
          _pill((task['priority']?.toString() ?? 'medium').toUpperCase(), _priorityColor(task['priority']?.toString())),
        ]),
        _field('$path.description', l10n.descriptionLabel, maxLines: 3),
        const SizedBox(height: 5),
        if (_isEditing) Row(children: [
          Expanded(child: _field('$path.estimated_hours', l10n.estimatedHoursLabel)),
          const SizedBox(width: 8),
          Expanded(child: _field('$path.due_week', l10n.dueWeekLabel)),
        ]) else Wrap(spacing: 7, runSpacing: 6, children: [
          _pill(l10n.hoursUnit(_int(task['estimated_hours'])), _teal),
          _pill(l10n.dueWeekValue(_int(task['due_week'])), const Color(0xFF8ACFD3)),
          if (task['category'] != null) _pill(task['category'].toString().replaceAll('_', ' ').toUpperCase(), _purple),
        ]),
        _field('$path.deliverable', l10n.deliverableLabel, maxLines: 2),
        _field('$path.success_criteria', l10n.successCriteriaLabel, maxLines: 3),
      ]),
    );
  }

  Widget _buildWeeklyRhythm() {
    final l10n = _l10n;
    final rhythm = _asMap(_roadmap['weekly_rhythm']);
    final schedule = _asMapList(rhythm['suggested_schedule']);
    if (rhythm.isEmpty && !_isEditing) return const SizedBox.shrink();
    return _sectionCard(
      icon: Icons.calendar_view_week_rounded,
      title: l10n.weeklyRhythm,
      subtitle: l10n.weeklyRhythmSubtitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _field('weekly_rhythm.hours_per_week', l10n.hoursPerWeekLabel),
        ...List.generate(schedule.length, (i) => Container(
          margin: const EdgeInsets.only(top: 8),
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: _panelLight, borderRadius: BorderRadius.circular(11)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _field('weekly_rhythm.suggested_schedule.$i.time_block', l10n.timeBlockLabel, fallback: l10n.blockNumber(i + 1)),
            _field('weekly_rhythm.suggested_schedule.$i.activity', l10n.activityLabel, maxLines: 3),
            _field('weekly_rhythm.suggested_schedule.$i.hours', l10n.hoursLabel),
          ]),
        )),
      ]),
    );
  }

  Widget _buildProgressTracking() {
    final l10n = _l10n;
    final tracking = _asMap(_roadmap['progress_tracking']);
    if (tracking.isEmpty && !_isEditing) return const SizedBox.shrink();
    final metrics = tracking['metrics'] is List ? List<dynamic>.from(tracking['metrics'] as List) : <dynamic>[];
    return _sectionCard(
      icon: Icons.query_stats_rounded,
      title: l10n.progressTracking,
      subtitle: l10n.progressTrackingSubtitle,
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _field('progress_tracking.review_frequency', l10n.reviewFrequencyLabel),
        ...List.generate(metrics.length, (i) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Padding(padding: EdgeInsets.only(top: 10), child: Icon(Icons.check_circle_outline, color: _green, size: 14)),
          const SizedBox(width: 7),
          Expanded(child: _field('progress_tracking.metrics.$i', l10n.metricNumber(i + 1), maxLines: 2)),
        ])),
        _field('progress_tracking.next_action', l10n.nextActionLabel, maxLines: 3),
      ]),
    );
  }

  Widget _buildRisks() {
    final l10n = _l10n;
    final risks = _asMapList(_roadmap['risks_and_adjustments']);
    if (risks.isEmpty && !_isEditing) return const SizedBox.shrink();
    return _sectionCard(
      icon: Icons.shield_outlined,
      title: l10n.risksAndAdjustments,
      subtitle: l10n.risksAndAdjustmentsSubtitle,
      child: Column(children: List.generate(risks.length, (i) => Container(
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.all(11),
        decoration: BoxDecoration(color: _panelLight, borderRadius: BorderRadius.circular(12)),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _field('risks_and_adjustments.$i.risk', l10n.riskLabel, maxLines: 2),
          _field('risks_and_adjustments.$i.mitigation', l10n.mitigationLabel, maxLines: 3),
          _field('risks_and_adjustments.$i.trigger_to_adjust', l10n.whenToAdjustLabel, maxLines: 2),
        ]),
      ))),
    );
  }

  Widget _buildAssumptions() {
    final l10n = _l10n;
    final assumptions = _roadmap['assumptions'] is List ? List<dynamic>.from(_roadmap['assumptions'] as List) : <dynamic>[];
    if (assumptions.isEmpty && !_isEditing) return const SizedBox.shrink();
    return _sectionCard(
      icon: Icons.info_outline_rounded,
      title: l10n.assumptions,
      subtitle: l10n.assumptionsSubtitle,
      child: Column(children: List.generate(assumptions.length, (i) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Padding(padding: EdgeInsets.only(top: 10), child: Icon(Icons.circle, color: _purple, size: 5)),
        const SizedBox(width: 8),
        Expanded(child: _field('assumptions.$i', l10n.assumptionNumber(i + 1), maxLines: 3)),
      ]))),
    );
  }

  Widget _sectionCard({required IconData icon, required String title, required String subtitle, required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: _panel, borderRadius: BorderRadius.circular(17), border: Border.all(color: const Color(0xFF292A46))),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Container(width: 32, height: 32, decoration: BoxDecoration(color: _purple.withOpacity(0.13), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: _purple, size: 16)),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
            const SizedBox(height: 3),
            Text(subtitle, style: TextStyle(color: Colors.white.withOpacity(0.37), fontSize: 9.5)),
          ])),
        ]),
        const SizedBox(height: 8),
        child,
      ]),
    );
  }

  Widget _subheading(String text) => Text(text, style: const TextStyle(color: Color(0xFFE1D9FF), fontSize: 11, fontWeight: FontWeight.w700));

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
        decoration: BoxDecoration(color: color.withOpacity(0.11), borderRadius: BorderRadius.circular(7), border: Border.all(color: color.withOpacity(0.18))),
        child: Text(text, style: TextStyle(color: color, fontSize: 7.5, fontWeight: FontWeight.w800, letterSpacing: 0.25)),
      );

  Color _priorityColor(String? priority) => switch (priority?.toLowerCase()) {
        'high' => const Color(0xFFFF9A9A),
        'low' => const Color(0xFF8ACFD3),
        _ => const Color(0xFFC6B8FF),
      };

  int _int(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.round();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  Widget _buildEditHint() {
    final l10n = _l10n;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: const Color(0xFF101827), borderRadius: BorderRadius.circular(13), border: Border.all(color: const Color(0xFF26394B))),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Icon(Icons.lightbulb_outline_rounded, color: _teal, size: 17),
        const SizedBox(width: 9),
        Expanded(child: Text(_isEditing ? l10n.editRoadmapHint : l10n.viewRoadmapHint, style: TextStyle(color: Colors.white.withOpacity(0.54), fontSize: 10, height: 1.45))),
      ]),
    );
  }

  Widget _buildBottomActions() {
    final l10n = _l10n;
    if (!_isEditing && !_hasUnsavedChanges) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      decoration: BoxDecoration(color: _background.withOpacity(0.98), border: const Border(top: BorderSide(color: Color(0xFF252640)))),
      child: SafeArea(
        top: false,
        child: Row(children: [
          if (_isEditing) ...[
            Expanded(child: OutlinedButton(onPressed: _isSaving ? null : _cancelEditing, style: OutlinedButton.styleFrom(foregroundColor: Colors.white70, side: const BorderSide(color: Color(0xFF393A56)), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))), child: Text(l10n.cancel))),
            const SizedBox(width: 10),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                onPressed: _isSaving ? null : _saveChanges,
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF8B5CF6), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                child: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.save_outlined, size: 17), const SizedBox(width: 7), Text(l10n.saveChanges)]),
              ),
            ),
          ] else if (_hasUnsavedChanges)
            Expanded(
              child: OutlinedButton(
                onPressed: _isSaving ? null : _persistProgressOnly,
                style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFC6B8FF), side: const BorderSide(color: Color(0xFF55477F)), padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(13))),
                child: _isSaving ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : Row(mainAxisAlignment: MainAxisAlignment.center, children: [const Icon(Icons.save_outlined, size: 17), const SizedBox(width: 7), Text(l10n.saveProgress)]),
              ),
            ),
        ]),
      ),
    );
  }

  void _cancelEditing() {
    _createEditors();
    setState(() {
      _isEditing = false;
      _hasUnsavedChanges = false;
      _saveError = null;
    });
  }

  Future<void> _persistProgressOnly() async {
    final saved = await _persistRoadmap(activate: false);
    if (!mounted || !saved) return;
    setState(() {
      _hasUnsavedChanges = false;
      _saveError = null;
    });
    _showMessage(_l10n.roadmapProgressSaved);
  }

  Future<void> _saveChanges() async {
    _syncEditorsToRoadmap();
    final saved = await _persistRoadmap(activate: false);
    if (!mounted || !saved) return;
    setState(() {
      _isEditing = false;
      _hasUnsavedChanges = false;
      _saveError = null;
    });
    _createEditors();
    _showMessage(_l10n.roadmapChangesSaved);
  }

  Future<bool> _persistRoadmap({required bool activate}) async {
    if (_isSaving) return false;
    final supabase = Supabase.instance.client;
    final user = supabase.auth.currentUser;
    if (user == null) {
      _showMessage(_l10n.signInBeforeSaving);
      return false;
    }
    setState(() {
      _isSaving = true;
      _saveError = null;
    });
    try {
      final phases = _asMapList(_roadmap['phases']);
      if (phases.isEmpty) throw FormatException(_l10n.noPhasesToSave);
      for (var i = 0; i < phases.length; i++) {
        final phase = phases[i];
        final startWeek = _int(phase['start_week']);
        final endWeek = _int(phase['end_week']);
        final durationWeeks = _int(phase['duration_weeks']);
        if (startWeek < 1 || endWeek < startWeek || durationWeeks < 1) {
          throw FormatException(_l10n.invalidPhaseWeekRange(i + 1));
        }
        for (final task in _asMapList(phase['tasks'])) {
          if (_int(task['due_week']) < 1 || _int(task['estimated_hours']) < 1) {
            throw FormatException(_l10n.invalidTaskSchedule(i + 1));
          }
        }
      }
      final milestones = <Map<String, dynamic>>[];
      final tasks = <Map<String, dynamic>>[];
      for (var i = 0; i < phases.length; i++) {
        final phase = phases[i];
        final phaseNumber = _int(phase['phase_number'], fallback: i + 1);
        for (final milestone in _asMapList(phase['milestones'])) {
          milestones.add(<String, dynamic>{...milestone, 'phase_number': phaseNumber, 'phase_title': phase['title']});
        }
        for (final task in _asMapList(phase['tasks'])) {
          tasks.add(<String, dynamic>{...task, 'phase_number': phaseNumber, 'phase_title': phase['title']});
        }
      }
      final selectedIds = widget.selectedCareers.map((career) => career['id']?.toString()).whereType<String>().where((id) => id.isNotEmpty).toSet().toList();
      final payload = <String, dynamic>{
        'user_id': user.id,
        'career_request_id': _careerRequestId,
        'generation_request_id': _generationRequestId,
        'selected_career_ids': selectedIds,
        'selected_careers': widget.selectedCareers,
        'title': _roadmap['title']?.toString() ?? _l10n.roadmapScreenTitle,
        'overview': _roadmap['overview']?.toString() ?? '',
        'planning_horizon_months': _int(_roadmap['planning_horizon_months'], fallback: 1).clamp(1, 24),
        'phases': phases,
        'milestones': milestones,
        'tasks': tasks,
        'weekly_rhythm': _asMap(_roadmap['weekly_rhythm']),
        'risks_and_adjustments': _roadmap['risks_and_adjustments'] is List ? _roadmap['risks_and_adjustments'] : <dynamic>[],
        'progress_tracking': _asMap(_roadmap['progress_tracking']),
        'roadmap_data': _roadmap,
        'status': activate ? 'active' : _roadmapStatus,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };

      Map<String, dynamic> savedRow;
      if (_roadmapId != null && _roadmapId!.isNotEmpty) {
        final result = await supabase.from('roadmaps').update(payload).eq('id', _roadmapId!).eq('user_id', user.id).select('id, status').maybeSingle();
        if (result == null) throw FormatException(_l10n.roadmapNotUpdated);
        savedRow = Map<String, dynamic>.from(result);
      } else {
        final result = await supabase.from('roadmaps').upsert(payload, onConflict: 'user_id,generation_request_id').select('id, status').single();
        savedRow = Map<String, dynamic>.from(result);
      }
      _roadmapId = savedRow['id']?.toString() ?? _roadmapId;
      _roadmapStatus = savedRow['status']?.toString() ?? (activate ? 'active' : _roadmapStatus);
      _response['roadmap_id'] = _roadmapId;
      _response['generation_request_id'] = _generationRequestId;
      _response['status'] = _roadmapStatus;
      _response['persisted'] = true;
      return true;
    } catch (error) {
      debugPrint('Saving roadmap failed: ${error.runtimeType}');
      if (mounted) {
        setState(() {
          _saveError =  _l10n.saveRoadmapError;
         
        });
      }
      return false;
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showMessage(String text) {
    if (!mounted) return;
    _topMessageTimer?.cancel();
    _topMessageEntry?.remove();
    _topMessageEntry = null;
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;
    late final OverlayEntry entry;
    entry = OverlayEntry(builder: (overlayContext) {
      final topInset = MediaQuery.of(overlayContext).padding.top;
      return Positioned(
        top: topInset + 12,
        left: 16,
        right: 16,
        child: Material(
          color: Colors.transparent,
          child: GestureDetector(
            onTap: () {
              _topMessageTimer?.cancel();
              if (_topMessageEntry == entry) {
                entry.remove();
                _topMessageEntry = null;
                _topMessageTimer = null;
              }
            },
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(color: const Color(0xFF251B4B), borderRadius: BorderRadius.circular(16), border: Border.all(color: const Color(0xFFA78BFA).withOpacity(0.65)), boxShadow: [BoxShadow(color: const Color(0xFF8B5CF6).withOpacity(0.22), blurRadius: 22, offset: const Offset(0, 7))]),
              child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                const Icon(Icons.info_outline_rounded, color: Color(0xFFC6B8FF), size: 22),
                const SizedBox(width: 12),
                Expanded(child: Text(text, style: const TextStyle(color: Color(0xFFF4F0FF), fontSize: 12.5, fontWeight: FontWeight.w500, height: 1.45))),
                const SizedBox(width: 8),
                const Icon(Icons.close_rounded, color: Color(0xFFB9ACDE), size: 18),
              ]),
            ),
          ),
        ),
      );
    });
    _topMessageEntry = entry;
    overlay.insert(entry);
    _topMessageTimer = Timer(const Duration(seconds: 3), () {
      if (_topMessageEntry == entry) {
        entry.remove();
        _topMessageEntry = null;
        _topMessageTimer = null;
      }
    });
  }

  @override
  void dispose() {
    _topMessageTimer?.cancel();
    _topMessageEntry?.remove();
    _topMessageEntry = null;
    _roadmapScrollController.dispose();
    _disposeEditors();
    super.dispose();
  }

  void _disposeEditors() {
    for (final controller in _editors.values) {
      controller.dispose();
    }
    _editors.clear();
  }
}
