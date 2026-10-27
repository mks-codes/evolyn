import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:evolyn/app/router/route_names.dart';
import 'package:evolyn/features/onboarding/data/career_options_local_storage.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';


class RoadmapGenerationScreen extends StatefulWidget {
  const RoadmapGenerationScreen({
    super.key,
    required this.selectedCareers,
    this.requestId,
  });

  final List<Map<String, dynamic>> selectedCareers;
  final String? requestId;

  @override
  State<RoadmapGenerationScreen> createState() =>
      _RoadmapGenerationScreenState();
}

class _RoadmapGenerationScreenState extends State<RoadmapGenerationScreen>
    with SingleTickerProviderStateMixin {
  static const String _roadmapFunctionName = 'generate-roadmap';

  int _completedSteps = 0;
  bool _isGenerating = true;
  String? _errorMessage;
  bool _requestInFlight = false;
  String? _generationRequestId;

  late final AnimationController _pulseController;
  Timer? _progressTimer;
  // cooldowntimer
  static const Duration _generationCooldown = Duration(minutes: 2);
  static const String _cooldownStorageKey =
      'roadmap_generation_cooldown_until_v2';
  DateTime? _cooldownUntil;
  Duration _cooldownRemaining = Duration.zero;
  Timer? _cooldownTimer;

  final List<_RoadmapStep> _steps = const [
    _RoadmapStep(
      title: 'Organizing your selected careers',
      subtitle: 'Preparing the direction you chose',
      icon: Icons.flag_outlined,
    ),
    _RoadmapStep(
      title: 'Reviewing your starting point',
      subtitle: 'Using the selected career details as context',
      icon: Icons.layers_outlined,
    ),
    _RoadmapStep(
      title: 'Building milestones',
      subtitle: 'Structuring the roadmap into meaningful stages',
      icon: Icons.auto_graph_rounded,
    ),
    _RoadmapStep(
      title: 'Creating practical tasks',
      subtitle: 'Preparing actions and deliverables',
      icon: Icons.task_alt_rounded,
    ),
    _RoadmapStep(
      title: 'Finalizing your roadmap',
      subtitle: 'Validating the generated response',
      icon: Icons.tune_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    unawaited(_restoreCooldownOrGenerate());
  }

  Future<void> _restoreCooldownOrGenerate() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUntilMs = prefs.getInt(_cooldownStorageKey);

      if (savedUntilMs != null) {
        final remaining = DateTime.fromMillisecondsSinceEpoch(
          savedUntilMs,
        ).difference(DateTime.now());

        if (remaining > Duration.zero) {
          if (!mounted) return;

          setState(() {
            _isGenerating = false;
            _completedSteps = 0;
            _errorMessage =
                'Roadmap generation failed. Please wait before trying again.';
            _cooldownUntil = DateTime.fromMillisecondsSinceEpoch(savedUntilMs);
            _cooldownRemaining = remaining;
          });

          _startCooldownTimer();
          return;
        }

        await prefs.remove(_cooldownStorageKey);
      }
    } catch (error) {
      debugPrint('[ROADMAP COOLDOWN] Restore failed: $error');
    }

    if (!mounted) return;

    // Preserve the current behavior when no cooldown is active.
    _startProgressAnimation();
    unawaited(_generateRoadmap());
  }

  Future<void> _beginCooldown({Duration? duration}) async {
    final requestedDuration = duration ?? _generationCooldown;
    final effectiveDuration = requestedDuration > Duration.zero
        ? requestedDuration
        : _generationCooldown;

    final until = DateTime.now().add(effectiveDuration);

    _cooldownTimer?.cancel();

    // Update the UI immediately so a retry button is never shown after failure.
    if (mounted) {
      setState(() {
        _cooldownUntil = until;
        _cooldownRemaining = effectiveDuration;
      });
    }

    _startCooldownTimer();

    try {
      final prefs = await SharedPreferences.getInstance();

      await prefs.setInt(_cooldownStorageKey, until.millisecondsSinceEpoch);
    } catch (error) {
      debugPrint('[ROADMAP COOLDOWN] Could not persist timer: $error');
    }
  }

  void _startCooldownTimer() {
    _cooldownTimer?.cancel();

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final until = _cooldownUntil;

      if (!mounted || until == null) {
        timer.cancel();
        return;
      }

      final remaining = until.difference(DateTime.now());

      if (remaining <= Duration.zero) {
        timer.cancel();
        _cooldownTimer = null;

        setState(() {
          _cooldownRemaining = Duration.zero;
          _cooldownUntil = null;
        });

        unawaited(_clearPersistedCooldown());
        return;
      }

      setState(() {
        _cooldownRemaining = remaining;
      });
    });
  }

  Future<void> _clearPersistedCooldown() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_cooldownStorageKey);
    } catch (error) {
      debugPrint('[ROADMAP COOLDOWN] Could not clear timer: $error');
    }
  }

  String _formatCooldown(Duration duration) {
    final seconds = math.max(0, duration.inSeconds);
    final minutesText = (seconds ~/ 60).toString().padLeft(2, '0');
    final secondsText = (seconds % 60).toString().padLeft(2, '0');

    return '$minutesText:$secondsText';
  }

  void _startProgressAnimation() {
    _progressTimer?.cancel();
    _progressTimer = Timer.periodic(const Duration(milliseconds: 1400), (
      timer,
    ) {
      if (!mounted || !_isGenerating) {
        timer.cancel();
        return;
      }

      // This is a visual estimate only. The Edge Function does not send
      // progress events, so do not show 100% before validating its response.
      if (_completedSteps < _steps.length - 1) {
        setState(() => _completedSteps++);
      }
    });
  }

  String? get _effectiveRequestId {
    final fromWidget = widget.requestId?.trim();
    if (fromWidget != null && fromWidget.isNotEmpty) return fromWidget;

    for (final career in widget.selectedCareers) {
      final value = career['request_id']?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }

    return null;
  }

  String _newUuidV4() {
    final random = math.Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final hex = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }

  String _getActualErrorMessage(Object error) {
    if (error is FunctionException) {
      final details = error.details;
      String? serverMessage;
      String? serverCode;

      dynamic decoded = details;

      if (details is String) {
        try {
          decoded = jsonDecode(details);
        } catch (_) {
          // Keep the original response text.
        }
      }

      if (decoded is Map) {
        serverMessage = decoded['message']?.toString();
        serverCode = decoded['error']?.toString();
      }

      final parts = <String>[
        'Edge Function failed (HTTP ${error.status}).',
        if (serverCode != null && serverCode.isNotEmpty) 'Code: $serverCode.',
        if (serverMessage != null && serverMessage.isNotEmpty)
          serverMessage
        else if (details != null)
          'Server response: $details',
      ];

      return parts.join('\n');
    }

    if (error is PostgrestException) {
      return [
        'Database error.',
        if (error.code != null) 'Code: ${error.code}',
        'Message: ${error.message}',
        if (error.details != null) 'Details: ${error.details}',
        if (error.hint != null) 'Hint: ${error.hint}',
      ].join('\n');
    }

    if (error is TimeoutException) {
      return 'Request timed out: ${error.message ?? 'The operation took too long.'}';
    }

    if (error is FormatException) {
      return 'Response/data format error: ${error.message}';
    }

    if (error is StateError) {
      return 'State error: ${error.message}';
    }

    return '${error.runtimeType}: $error';
  }

  int _rankOf(Map<String, dynamic> career, int fallbackRank) {
    final value = career['rank'];
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallbackRank;
  }

  /// Whitelist fields passed to the Edge Function.
  ///
  /// Do not send a client/AI-supplied `id` as if it were a database ID. These
  /// careers have intentionally not been saved to career_recommendations yet.
  Map<String, dynamic> _careerForRoadmap(
    Map<String, dynamic> career,
    int fallbackRank,
  ) {
    const allowedFields = <String>{
      'career_title',
      'career_category',
      'match_score',
      'match_level',
      'match_summary',
      'why_it_matches',
      'supporting_evidence',
      'existing_skill_alignment',
      'skills_to_develop',
      'entry_requirements',
      'accessibility_considerations',
      'potential_challenges',
      'typical_work',
      'confidence',
    };

    return <String, dynamic>{
      'rank': _rankOf(career, fallbackRank),
      for (final entry in career.entries)
        if (allowedFields.contains(entry.key)) entry.key: entry.value,
    };
  }

  Future<void> _markProfileCompletionFlags({required String userId}) async {
    final supabase = Supabase.instance.client;

    final updatedProfile = await supabase
        .from('profiles')
        .update({'journey_ready': true, 'roadmap_completed': true})
        .eq('id', userId)
        .select('id')
        .maybeSingle()
        .timeout(const Duration(seconds: 20));

    if (updatedProfile == null) {
      throw StateError(
        'The roadmap was saved, but the profile completion flags '
        'could not be updated. Check the profiles table and RLS policies.',
      );
    }

    debugPrint('[PROFILE] journey_completed=true; roadmap_completed=true');
  }

  Future<void> _navigateToRoadmap({
    required Map<String, dynamic> roadmapResult,
    required String requestId,
    required String generationRequestId,
    required List<Map<String, dynamic>> savedCareers,
    required List<String> selectedIds,
  }) async {
    final roadmapId = roadmapResult['roadmap_id']?.toString();
    if (roadmapId == null || roadmapId.isEmpty) {
      throw const FormatException(
        'The saved roadmap ID is missing from the response.',
      );
    }

    if (!mounted) return;

    _progressTimer?.cancel();
    setState(() {
      _completedSteps = _steps.length;
      _isGenerating = false;
      _errorMessage = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 350));
    if (!mounted) return;

    debugPrint(
      '[roadmap-navigation] Opening ${RouteNames.roadmapScreen}; '
      'roadmapId=$roadmapId; '
      'reused=${roadmapResult['idempotent_replay'] == true}; ',
    );

    context.goNamed(
      RouteNames.home,
      extra: <String, dynamic>{
        'roadmapData': roadmapResult,
        'roadmapId': roadmapId,
        'requestId': requestId,
        'generationRequestId': generationRequestId,
      },
    );
  }

  Future<void> _generateRoadmap() async {
    if (_requestInFlight) return;

    if (widget.selectedCareers.isEmpty) {
      _setFailure(
        'No careers were selected. Return and select at least one career.',
      );
      return;
    }

    if (widget.selectedCareers.length > 3) {
      _setFailure('A maximum of 3 careers can be included in a roadmap.');
      return;
    }

    final supabase = Supabase.instance.client;
    final session = supabase.auth.currentSession;

    if (session == null) {
      _setFailure('Please sign in before generating your roadmap.');
      return;
    }

    final requestId = _effectiveRequestId;
    if (requestId == null || requestId.trim().isEmpty) {
      _setFailure(
        'The career request ID is missing. Return and select your careers again.',
      );
      return;
    }

    // Keep the same generation ID across retries on this screen. The Edge
    // Function should use it as an idempotency key and return the same saved
    // roadmap if the first response was lost after a successful save.
    final generationRequestId = _generationRequestId ??= _newUuidV4();

    setState(() {
      _requestInFlight = true;
      _isGenerating = true;
      _completedSteps = 0;
      _errorMessage = null;
    });
    _startProgressAnimation();

    try {
      final careersForFunction = <Map<String, dynamic>>[
        for (var index = 0; index < widget.selectedCareers.length; index++)
          _careerForRoadmap(widget.selectedCareers[index], index + 1),
      ];

      debugPrint(
        '[generate-roadmap] Sending ${careersForFunction.length} unsaved '
        'career options; requestId=$requestId; '
        'generationRequestId=$generationRequestId',
      );

      final response = await supabase.functions
          .invoke(
            _roadmapFunctionName,
            headers: <String, String>{
              'Authorization': 'Bearer ${session.accessToken}',
              'Idempotency-Key': generationRequestId,
            },
            body: <String, dynamic>{
              'request_id': requestId,
              'generation_request_id': generationRequestId,
              'selected_careers': careersForFunction,
            },
          )
          .timeout(const Duration(seconds: 120));

      dynamic responseData = response.data;
      if (responseData is String) {
        try {
          responseData = jsonDecode(responseData);
        } on FormatException {
          throw const FormatException(
            'The roadmap function returned invalid JSON.',
          );
        }
      }

      if (responseData is! Map) {
        throw const FormatException(
          'The roadmap function returned an unexpected response format.',
        );
      }

      final roadmapResult = Map<String, dynamic>.from(responseData);

      if (roadmapResult['success'] != true) {
        final message =
            roadmapResult['message'] ??
            roadmapResult['error'] ??
            'Roadmap generation failed.';
        throw Exception(message.toString());
      }

      if (roadmapResult['persisted'] != true) {
        throw const FormatException(
          'The roadmap was generated but was not confirmed as saved.',
        );
      }

      final roadmapId = roadmapResult['roadmap_id'];
      if (roadmapId is! String || roadmapId.trim().isEmpty) {
        throw const FormatException(
          'The saved roadmap ID is missing from the response.',
        );
      }

      final roadmapCareerIdsValue = roadmapResult['roadmap_career_ids'];
      if (roadmapCareerIdsValue is! List) {
        throw const FormatException(
          'The roadmap response is missing roadmap career identifiers.',
        );
      }

      final selectedIds = roadmapCareerIdsValue
          .whereType<String>()
          .map((id) => id.trim())
          .where((id) => id.isNotEmpty)
          .toList();

      if (selectedIds.length != widget.selectedCareers.length ||
          selectedIds.toSet().length != selectedIds.length) {
        throw const FormatException(
          'The roadmap response does not contain a unique identifier for every selected career.',
        );
      }

      // Update profile completion flags only after the roadmap
      // has been confirmed as successfully persisted.
      await _markProfileCompletionFlags(userId: session.user.id);

      // Cache cleanup is secondary. A cache-cleanup failure must not block
      // navigation after the roadmap and career rows have been saved.
      try {
        await CareerOptionsLocalStorage().clear(userId: session.user.id);
        debugPrint('[CAREER CACHE] Cleared after successful persistence.');
      } catch (cacheError, cacheStack) {
        debugPrint('[CAREER CACHE] Could not clear local cache: $cacheError');
        debugPrintStack(stackTrace: cacheStack);
      }

      await _navigateToRoadmap(
        roadmapResult: roadmapResult,
        requestId: requestId,
        generationRequestId: generationRequestId,
        savedCareers: widget.selectedCareers,
        selectedIds: selectedIds,
      );
    } on FunctionException catch (error, stackTrace) {
      final dynamic details = error.details;
      Map<String, dynamic>? errorBody;

      if (details is Map) {
        errorBody = Map<String, dynamic>.from(details);
      } else if (details is String) {
        try {
          final decoded = jsonDecode(details);
          if (decoded is Map) {
            errorBody = Map<String, dynamic>.from(decoded);
          }
        } on FormatException {
          // The Edge Function response was not JSON.
        }
      }

      final errorCode = errorBody?['error']?.toString();
      final serverMessage = errorBody?['message']?.toString();
      final retryAfterValue = errorBody?['retry_after_seconds'];

      final Duration? serverCooldownDuration =
          errorCode == 'ROADMAP_COOLDOWN_ACTIVE' &&
              retryAfterValue is num &&
              retryAfterValue > 0
          ? Duration(seconds: retryAfterValue.toInt())
          : null;
      debugPrint(
        '[generate-roadmap] HTTP ${error.status}; '
        'code=$errorCode; message=${serverMessage ?? details}',
      );
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;
      _setFailure(
        serverMessage != null && serverMessage.isNotEmpty
            ? serverMessage
            : 'Roadmap request failed (HTTP ${error.status}).',
        cooldownDuration: serverCooldownDuration,
      );
    } on PostgrestException catch (error, stackTrace) {
      debugPrint('========== PROFILE UPDATE ERROR ==========');
      debugPrint('Code: ${error.code}');
      debugPrint('Message: ${error.message}');
      debugPrint('Details: ${error.details}');
      debugPrint('Hint: ${error.hint}');
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('===========================================');

      if (!mounted) return;

      _setFailure(
        'Your roadmap was saved, but updating your profile completion '
        'status failed. Please retry.',
      );
    } catch (error, stackTrace) {
      final actualError = _getActualErrorMessage(error);

      debugPrint('========== ROADMAP GENERATION ERROR ==========');
      debugPrint('Type: ${error.runtimeType}');
      debugPrint('Error: $error');
      debugPrint('Actual message:\n$actualError');
      debugPrintStack(stackTrace: stackTrace);
      debugPrint('==============================================');

      if (!mounted) return;

      _setFailure(actualError);
    } finally {
      _requestInFlight = false;
    }
  }

  void _setFailure(String message, {Duration? cooldownDuration}) {
    _progressTimer?.cancel();

    if (!mounted) return;

    setState(() {
      _isGenerating = false;
      _errorMessage = message;
    });

    unawaited(_beginCooldown(duration: cooldownDuration));
  }

  @override
  void dispose() {
    _progressTimer?.cancel();
    _cooldownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050614),
      body: SafeArea(
        child: Stack(
          children: [
            _buildBackground(),
            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 110),
              child: Column(
                children: [
                  _buildTopBadge(),
                  const SizedBox(height: 28),
                  _buildRoadmapOrb(),
                  const SizedBox(height: 28),
                  _buildHeading(),
                  const SizedBox(height: 10),
                  _buildSubtitle(),
                  const SizedBox(height: 28),
                  _buildSelectedCareers(),
                  const SizedBox(height: 20),
                  _buildProgress(),
                  const SizedBox(height: 20),
                  _buildGenerationSteps(),
                  const SizedBox(height: 22),
                  _buildStatusMessage(),
                ],
              ),
            ),
            _buildBottomButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildBackground() {
    return Stack(
      children: [
        Positioned(
          top: -190,
          left: -140,
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF8B5CF6).withOpacity(0.16),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -200,
          right: -130,
          child: Container(
            width: 420,
            height: 420,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF4F46E5).withOpacity(0.11),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTopBadge() {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF181333),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0xFF39305D)),
          ),
          child: const Row(
            children: [
              Icon(
                Icons.auto_awesome_rounded,
                color: Color(0xFFA78BFA),
                size: 13,
              ),
              SizedBox(width: 6),
              Text(
                'AARYA',
                style: TextStyle(
                  color: Color(0xFFC2B6FF),
                  fontSize: 9,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ),
        const Spacer(),
        Text(
          'ROADMAP',
          style: TextStyle(
            color: Colors.white.withOpacity(0.25),
            fontSize: 9,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.7,
          ),
        ),
      ],
    );
  }

  Widget _buildRoadmapOrb() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glow = 20 + (_pulseController.value * 12);
        return Container(
          width: 82,
          height: 82,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFFA78BFA), Color(0xFF6D28D9)],
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF8B5CF6).withOpacity(0.30),
                blurRadius: glow,
                spreadRadius: 3,
              ),
            ],
          ),
          child: const Center(
            child: Icon(Icons.route_rounded, color: Colors.white, size: 38),
          ),
        );
      },
    );
  }

  Widget _buildHeading() {
    return const Text(
      'Building your roadmap.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white,
        fontSize: 29,
        fontWeight: FontWeight.w600,
        letterSpacing: -0.8,
      ),
    );
  }

  Widget _buildSubtitle() {
    return Text(
      'AARYA is turning your selected career${widget.selectedCareers.length == 1 ? '' : 's'} into a practical path\n'
      'you can follow at your own pace.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withOpacity(0.46),
        fontSize: 13,
        height: 1.5,
      ),
    );
  }

  Widget _buildSelectedCareers() {
    final careers = widget.selectedCareers;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0E20),
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFF292A46)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.work_outline_rounded,
                color: Color(0xFFA78BFA),
                size: 15,
              ),
              const SizedBox(width: 7),
              const Text(
                'SELECTED CAREERS',
                style: TextStyle(
                  color: Color(0xFFAFA2D9),
                  fontSize: 8.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.6,
                ),
              ),
              const Spacer(),
              Text(
                '${careers.length}',
                style: const TextStyle(
                  color: Color(0xFF68DCE2),
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ...careers
              .take(3)
              .map(
                (career) => Padding(
                  padding: const EdgeInsets.only(bottom: 7),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 5),
                        child: Icon(
                          Icons.circle,
                          size: 4,
                          color: Color(0xFF8B5CF6),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          career['career_title']?.toString() ?? 'Career option',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.70),
                            fontSize: 10.5,
                            height: 1.35,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildProgress() {
    final progress = _completedSteps / _steps.length;
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: LinearProgressIndicator(
            value: progress,
            minHeight: 4,
            backgroundColor: const Color(0xFF18192D),
            valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Text(
              _isGenerating
                  ? 'Creating your path...'
                  : (_errorMessage == null
                        ? 'Roadmap ready'
                        : 'Generation stopped'),
              style: TextStyle(
                color: Colors.white.withOpacity(0.30),
                fontSize: 9.5,
              ),
            ),
            const Spacer(),
            Text(
              '${(progress * 100).round()}%',
              style: const TextStyle(
                color: Color(0xFFA78BFA),
                fontSize: 9.5,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildGenerationSteps() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0E20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF252640)),
      ),
      child: Column(
        children: List.generate(
          _steps.length,
          (index) => _buildStep(step: _steps[index], index: index),
        ),
      ),
    );
  }

  Widget _buildStep({required _RoadmapStep step, required int index}) {
    final completed = index < _completedSteps;
    final current = index == _completedSteps && _isGenerating;
    final last = index == _steps.length - 1;

    return Column(
      children: [
        Row(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 35,
              height: 35,
              decoration: BoxDecoration(
                color: completed
                    ? const Color(0xFF123528)
                    : current
                    ? const Color(0xFF291C52)
                    : const Color(0xFF17182B),
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: completed
                      ? const Color(0xFF3F9E79)
                      : current
                      ? const Color(0xFF8B5CF6)
                      : const Color(0xFF282940),
                ),
              ),
              child: Icon(
                step.icon,
                size: 16,
                color: completed
                    ? const Color(0xFF68E3B0)
                    : current
                    ? const Color(0xFFB79AFF)
                    : const Color(0xFF5F6176),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      color: completed || current
                          ? Colors.white
                          : const Color(0xFF707185),
                      fontSize: 12,
                      fontWeight: completed || current
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    step.subtitle,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: completed || current
                          ? Colors.white.withOpacity(0.33)
                          : Colors.white.withOpacity(0.18),
                      fontSize: 9,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
            if (completed)
              const Icon(
                Icons.check_rounded,
                color: Color(0xFF59E1A8),
                size: 19,
              ),
            if (current)
              const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFA78BFA)),
                ),
              ),
          ],
        ),
        if (!last)
          Padding(
            padding: const EdgeInsets.only(left: 17, top: 7, bottom: 7),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 1,
                height: 13,
                color: completed
                    ? const Color(0xFF4B4672)
                    : const Color(0xFF202137),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatusMessage() {
    if (_isGenerating) {
      return Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const SizedBox(
            width: 13,
            height: 13,
            child: CircularProgressIndicator(
              strokeWidth: 1.7,
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF8B5CF6)),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            'AARYA is connecting the pieces...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.34),
              fontSize: 9.5,
            ),
          ),
        ],
      );
    }

    if (_errorMessage != null) {
      return Text(
        _errorMessage!,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFFFF8A8A), fontSize: 12),
      );
    }

    return const Column(
      children: [
        Icon(
          Icons.check_circle_outline_rounded,
          color: Color(0xFF5CE0A8),
          size: 23,
        ),
        SizedBox(height: 7),
        Text(
          'Your roadmap is ready.',
          style: TextStyle(
            color: Colors.white,
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

Widget _buildBottomButton() {
  return Positioned(
    left: 20,
    right: 20,
    bottom: 12,
    child: SafeArea(
      top: false,
      child: SizedBox(
        height: 53,
        child: _cooldownRemaining > Duration.zero
            ? Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF302947),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: const Color(0xFF484064),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.lock_clock_rounded,
                      size: 18,
                      color: Color(0xFFA78BFA),
                    ),
                    const SizedBox(width: 9),
                    Text(
                      'Try again in ${_formatCooldown(_cooldownRemaining)}',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: Colors.white70,
                      ),
                    ),
                  ],
                ),
              )
            : ElevatedButton(
                onPressed: _isGenerating
                    ? null
                    : (_errorMessage != null
                        ? _generateRoadmap
                        : null),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                  disabledBackgroundColor: const Color(0xFF302947),
                  foregroundColor: Colors.white,
                  disabledForegroundColor:
                      Colors.white.withOpacity(0.28),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      _isGenerating
                          ? 'Building your roadmap...'
                          : 'Retry generation',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      _isGenerating
                          ? Icons.hourglass_empty_rounded
                          : Icons.refresh_rounded,
                      size: 18,
                    ),
                  ],
                ),
              ),
      ),
    ),
  );
}
}

class _RoadmapStep {
  final String title;
  final String subtitle;
  final IconData icon;

  const _RoadmapStep({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}
