import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'package:evolyn/app/router/route_names.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:evolyn/features/onboarding/data/career_options_local_storage.dart';

class JourneyGenerationScreen extends StatefulWidget {
  const JourneyGenerationScreen({super.key});

  @override
  State<JourneyGenerationScreen> createState() =>
      _JourneyGenerationScreenState();
}

class _JourneyGenerationScreenState extends State<JourneyGenerationScreen>
    with SingleTickerProviderStateMixin {
  int _completedSteps = 0;

  bool _isGenerating = true;

  late final AnimationController _pulseController;
  final CareerOptionsLocalStorage _careerOptionsStorage =
      CareerOptionsLocalStorage();

  static const Duration _generationCooldownDuration = Duration(minutes: 2);
  static const String _cooldownStorageKeyPrefix =
      'journey_generation_cooldown_until_';
  static const String _guestCooldownStorageKey =
      'journey_generation_cooldown_until_guest';

  Timer? _cooldownTimer;
  DateTime? _cooldownUntil;
  int _cooldownSecondsRemaining = 0;
  String? _activeCooldownStorageKey;

  static const String _geminiDisclosureConsentKeyPrefix =
      'evolyn.ai.gemini_disclosure_v1_accepted_';
  static const String _geminiDisclosureGuestConsentKey =
      'evolyn.ai.gemini_disclosure_v1_accepted_guest';

  bool _disclosureDeclined = false;

  String? _requestId;
  String? _errorMessage;

  int _receivedCharacters = 0;
  final List<_GenerationStep> _steps = const [
    _GenerationStep(
      title: 'Understanding your profile',
      subtitle: 'Reviewing your onboarding answers',
      icon: Icons.person_outline_rounded,
    ),
    _GenerationStep(
      title: 'Comparing career paths',
      subtitle: 'Finding careers aligned with your interests',
      icon: Icons.work_outline_rounded,
    ),
    _GenerationStep(
      title: 'Scoring career matches',
      subtitle: 'Evaluating skills, time and constraints',
      icon: Icons.analytics_outlined,
    ),
    _GenerationStep(
      title: 'Ranking recommendations',
      subtitle: 'Ordering career options by suitability',
      icon: Icons.auto_awesome_rounded,
    ),
    _GenerationStep(
      title: 'Finalizing recommendations',
      subtitle: 'Validating your personalized career options',
      icon: Icons.check_circle_outline_rounded,
    ),
  ];

  bool _shouldApplyAiCooldown(String? errorCode) {
    switch (errorCode?.trim().toUpperCase()) {
      case 'GEMINI_TIMEOUT':
      case 'UPSTREAM_TIMEOUT':
      case 'GEMINI_NETWORK_ERROR':
      case 'GEMINI_REQUEST_ABORTED':
      case 'REQUEST_ABORTED':
      case 'GEMINI_INVALID_API_RESPONSE':
      case 'GEMINI_EMPTY_RESPONSE':
      case 'GEMINI_OUTPUT_TRUNCATED':
      case 'GEMINI_OUTPUT_TOO_LARGE':
      case 'GEMINI_INVALID_JSON':
      case 'INVALID_MODEL_RESPONSE':
      case 'GEMINI_UNEXPECTED_FINISH_REASON':
      case 'GEMINI_BAD_REQUEST':
      case 'GEMINI_API_KEY_INVALID':
      case 'GEMINI_BILLING_REQUIRED':
      case 'GEMINI_PERMISSION_DENIED':
      case 'GEMINI_MODEL_NOT_FOUND':
      case 'GEMINI_RATE_LIMIT_OR_QUOTA':
      case 'GEMINI_SERVICE_UNAVAILABLE':
      case 'GEMINI_REQUEST_FAILED':
      case 'GEMINI_PROMPT_BLOCKED':
      case 'GEMINI_RESPONSE_BLOCKED':
      case 'CAREER_GENERATION_FAILED':
        return true;

      default:
        // Do not apply a cooldown to onboarding, profile, auth,
        // configuration, or other pre-model failures.
        return false;
    }
  }

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat(reverse: true);

    _requestId = _newUuidV4();

    _resumeCachedOptionsOrGenerate();
  }

  DateTime? _cooldownDeadlineFromError(Object error) {
    String? rawDeadline;

    if (error is _BackendGenerationException) {
      rawDeadline = error.cooldownUntil;
    } else if (error is FunctionException) {
      final details = _decodeJsonMap(error.details);
      final nestedError = _decodeJsonMap(details?['error']);
      final nestedData = _decodeJsonMap(details?['data']);
      final dataError = _decodeJsonMap(nestedData?['error']);

      final payload = nestedError ?? dataError ?? nestedData ?? details;

      rawDeadline =
          (payload?['cooldown_until'] ??
                  nestedData?['cooldown_until'] ??
                  details?['cooldown_until'])
              ?.toString();
    }

    if (rawDeadline == null || rawDeadline.trim().isEmpty) {
      return null;
    }

    return DateTime.tryParse(rawDeadline)?.toLocal();
  }

  Future<void> _resumeCachedOptionsOrGenerate() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;

      if (user != null) {
        final cached = await _careerOptionsStorage.load(userId: user.id);

        if (!mounted) return;

        if (cached != null) {
          _requestId = cached.requestId;

          debugPrint(
            '[CAREER CACHE] Restored '
            '${cached.careerOptions.length} career options.',
          );

          context.goNamed(
            RouteNames.careerRecommendations,
            extra: <String, dynamic>{
              'requestId': cached.requestId,
              'careerOptions': cached.careerOptions,
            },
          );

          return;
        }
      }
    } catch (error) {
      // If cache loading fails, still allow the normal generation flow.
      debugPrint('[CAREER CACHE] Restore failed: $error');
    }

    if (!mounted) return;

    final waitingForCooldown = await _restoreCooldownIfActive();
    if (!mounted || waitingForCooldown) return;

    await _startGeneration();
  }

  String _cooldownStorageKey(String? userId) {
    if (userId == null || userId.isEmpty) return _guestCooldownStorageKey;
    return '$_cooldownStorageKeyPrefix$userId';
  }

  Future<DateTime?> _readSavedCooldown(String key) async {
    try {
      final preferences = await SharedPreferences.getInstance();
      final saved = preferences.getString(key);
      if (saved == null || saved.trim().isEmpty) return null;

      final deadline = DateTime.tryParse(saved)?.toLocal();
      if (deadline == null || !deadline.isAfter(DateTime.now())) {
        await preferences.remove(key);
        return null;
      }
      return deadline;
    } catch (error) {
      debugPrint('[GENERATION COOLDOWN] Could not read saved timer: $error');
      return null;
    }
  }

  Future<void> _saveCooldown(DateTime deadline) async {
    final key =
        _activeCooldownStorageKey ??
        _cooldownStorageKey(Supabase.instance.client.auth.currentUser?.id);
    _activeCooldownStorageKey = key;
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.setString(key, deadline.toUtc().toIso8601String());
    } catch (error) {
      debugPrint('[GENERATION COOLDOWN] Could not persist timer: $error');
    }
  }

  Future<void> _clearCooldown() async {
    _cooldownTimer?.cancel();
    final key =
        _activeCooldownStorageKey ??
        _cooldownStorageKey(Supabase.instance.client.auth.currentUser?.id);
    try {
      final preferences = await SharedPreferences.getInstance();
      await preferences.remove(key);
    } catch (error) {
      debugPrint('[GENERATION COOLDOWN] Could not clear saved timer: $error');
    }

    if (!mounted) return;
    setState(() {
      _cooldownUntil = null;
      _cooldownSecondsRemaining = 0;
    });
  }

  Future<void> _beginCooldown(
    DateTime deadline, {
    bool setFailureState = false,
  }) async {
    _activeCooldownStorageKey = _cooldownStorageKey(
      Supabase.instance.client.auth.currentUser?.id,
    );
    await _saveCooldown(deadline);
    _cooldownTimer?.cancel();

    final initialSeconds = deadline.difference(DateTime.now()).inSeconds;
    if (!mounted) return;
    setState(() {
      _cooldownUntil = deadline;
      _cooldownSecondsRemaining = math.max(0, initialSeconds).toInt();
      if (setFailureState) {
        _isGenerating = false;
        _errorMessage ??=
            'Career recommendations could not be generated. Please wait before trying again.';
      }
    });

    if (initialSeconds <= 0) {
      await _clearCooldown();
      return;
    }

    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      final remaining = deadline.difference(DateTime.now()).inSeconds;
      if (!mounted) {
        timer.cancel();
        return;
      }

      if (remaining <= 0) {
        timer.cancel();
        final key = _activeCooldownStorageKey;
        if (key != null) {
          try {
            final preferences = await SharedPreferences.getInstance();
            await preferences.remove(key);
          } catch (error) {
            debugPrint(
              '[GENERATION COOLDOWN] Could not clear expired timer: $error',
            );
          }
        }
        if (!mounted) return;
        setState(() {
          _cooldownUntil = null;
          _cooldownSecondsRemaining = 0;
        });
      } else {
        setState(() {
          _cooldownSecondsRemaining = remaining;
        });
      }
    });
  }

  Future<bool> _restoreCooldownIfActive() async {
    final supabase = Supabase.instance.client;
    final userId = supabase.auth.currentUser?.id;
    _activeCooldownStorageKey = _cooldownStorageKey(userId);

    DateTime? deadline = await _readSavedCooldown(_activeCooldownStorageKey!);
    if (deadline != null && deadline.isAfter(DateTime.now())) {
      if (!mounted) return true;
      setState(() {
        _isGenerating = false;
        _errorMessage =
            'A generation attempt was not completed. Please wait for the cooldown to finish.';
      });
      await _beginCooldown(deadline);
      return true;
    }

    // If this device has no active local timer, ask the server as well. This
    // synchronizes cooldowns across devices and recovers after local data loss.
    if (userId != null) {
      try {
        final session = supabase.auth.currentSession;
        if (session != null) {
          final response = await supabase.functions.invoke(
            'generate-journey',
            body: const <String, dynamic>{'action': 'cooldown_status'},
            headers: {'Authorization': 'Bearer ${session.accessToken}'},
          );
          final data = _decodeJsonMap(response.data);
          final remoteUntil = data?['cooldown_until']?.toString();
          final remoteActive = data?['cooldown_active'] == true;
          final parsedUntil = remoteUntil == null
              ? null
              : DateTime.tryParse(remoteUntil)?.toLocal();

          if (remoteActive &&
              parsedUntil != null &&
              parsedUntil.isAfter(DateTime.now())) {
            if (!mounted) return true;
            setState(() {
              _isGenerating = false;
              _errorMessage =
                  'A generation attempt was already made. Please wait for the cooldown to finish.';
            });
            await _beginCooldown(parsedUntil);
            return true;
          }
        }
      } catch (error) {
        // The local deadline remains the fallback when the server is unreachable.
        debugPrint('[GENERATION COOLDOWN] Server status check failed: $error');
      }
    }

    return false;
  }

  String _formatCooldown(int seconds) {
    final safeSeconds = math.max(0, seconds).toInt();
    final minutes = (safeSeconds ~/ 60).toString().padLeft(2, '0');
    final remainder = (safeSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$remainder';
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

  String _customerFacingErrorMessage(Object error) {
    if (error is _BackendGenerationException) {
      return _messageForBackendError(error.code, error.message);
    }

    if (error is FunctionException) {
      final details = _decodeJsonMap(error.details);

      final nestedError = _decodeJsonMap(details?['error']);
      final nestedData = _decodeJsonMap(details?['data']);
      final dataError = _decodeJsonMap(nestedData?['error']);

      final payload = nestedError ?? dataError ?? nestedData ?? details;

      final code =
          (payload?['code'] ?? nestedError?['code'] ?? details?['code'])
              ?.toString();

      final message =
          (payload?['message'] ??
                  nestedError?['message'] ??
                  details?['message'])
              ?.toString();

      return _messageForBackendError(code, message, statusCode: error.status);
    }

    if (error is TimeoutException) {
      return 'The request timed out. Please try again.';
    }

    if (error is FormatException) {
      return 'The server returned an invalid response. Please try again.';
    }

    return 'We could not generate your career recommendations. Please try again.';
  }

  Map<String, dynamic>? _decodeJsonMap(Object? value) {
    Object? decoded = value;
    if (value is String) {
      try {
        decoded = jsonDecode(value);
      } catch (_) {
        return null;
      }
    }

    if (decoded is! Map) return null;
    return decoded.map((key, value) => MapEntry(key.toString(), value));
  }

  String _messageForBackendError(
    String? code,
    String? backendMessage, {
    int? statusCode,
  }) {
    // Prefer the exact message supplied by the Edge Function.
    // The backend must only send messages that are safe for users to see.
    final exactMessage = backendMessage?.trim();

    if (exactMessage != null && exactMessage.isNotEmpty) {
      return exactMessage;
    }

    // Use these messages only when the backend did not supply one.
    switch (code?.trim().toUpperCase()) {
      case 'UNAUTHENTICATED':
        return 'Your session has expired. Please sign in again.';

      case 'ONBOARDING_INCOMPLETE':
        return 'Please complete your onboarding before generating recommendations.';

      case 'ONBOARDING_DATA_INSUFFICIENT':
        return 'More career-related information is needed. Please update your onboarding answers.';

      case 'ONBOARDING_DATA_TOO_LARGE':
        return 'Your saved onboarding data is too large to process. Please review your onboarding answers.';

      case 'PROFILE_NOT_FOUND':
        return 'We could not find your profile. Please sign in again.';

      case 'PROFILE_LOOKUP_FAILED':
        return 'We could not load your profile. Please try again.';

      case 'GEMINI_CONFIGURATION_ERROR':
      case 'AI_CONFIGURATION_ERROR':
        return 'The recommendation service is not configured correctly. Please try again later.';

      case 'GEMINI_API_KEY_INVALID':
      case 'GEMINI_PERMISSION_DENIED':
      case 'UPSTREAM_AUTH_ERROR':
        return 'The recommendation service could not authenticate its request. Please try again later.';

      case 'GEMINI_BAD_REQUEST':
        return 'The recommendation request was rejected. Please try again.';

      case 'GEMINI_MODEL_NOT_FOUND':
      case 'MODEL_UNAVAILABLE':
        return 'The configured recommendation model is unavailable. Please try again later.';

      case 'GEMINI_RATE_LIMIT_OR_QUOTA':
      case 'UPSTREAM_RATE_LIMITED':
      case 'RATE_LIMITED':
        return 'The recommendation service has reached a usage limit. Please try again later.';

      case 'GEMINI_BILLING_REQUIRED':
        return 'The recommendation service is temporarily unavailable. Please try again later.';

      case 'GEMINI_TIMEOUT':
      case 'UPSTREAM_TIMEOUT':
      case 'MODEL_TIMEOUT':
        return 'Career generation timed out. Please try again.';

      case 'GEMINI_NETWORK_ERROR':
      case 'UPSTREAM_INTERRUPTED':
        return 'The connection was interrupted. Please check your connection and retry.';

      case 'GEMINI_PROMPT_BLOCKED':
      case 'GEMINI_RESPONSE_BLOCKED':
        return 'The request could not be completed. Please try again with different onboarding responses.';

      case 'GEMINI_INVALID_JSON':
      case 'INVALID_MODEL_RESPONSE':
        return 'The recommendation service returned an invalid response. Please try again.';

      case 'ALL_GEMINI_MODELS_FAILED':
      case 'ALL_MODELS_FAILED':
      case 'GENERATION_FAILED':
        return 'Career recommendations could not be generated. Please try again.';

      case 'GEMINI_RESPONSE_INVALID':
        return 'The recommendation service returned an invalid response. Please try again.';

      case 'INTERNAL_SERVER_ERROR':
      case 'SUPABASE_CONFIGURATION_ERROR':
      case 'UPSTREAM_UNAVAILABLE':
        return 'The recommendation service is temporarily unavailable. Please try again later.';
    }

    if (statusCode == 0) {
      return 'Unable to connect to the service. Check your internet connection.';
    }

    if (statusCode == 401 || statusCode == 403) {
      return 'Your session may have expired. Please sign in again.';
    }

    if (statusCode == 408 || statusCode == 504) {
      return 'Career generation timed out. Please try again.';
    }

    if (statusCode == 429) {
      return 'The recommendation service is busy. Please try again later.';
    }

    if (statusCode != null && statusCode >= 500) {
      return 'The recommendation service is temporarily unavailable. Please try again later.';
    }

    return 'We could not generate your career recommendations. Please try again.';
  }

  String _geminiDisclosureConsentKey() {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null || userId.isEmpty) {
      return _geminiDisclosureGuestConsentKey;
    }
    return '$_geminiDisclosureConsentKeyPrefix$userId';
  }

  Future<bool> _ensureGeminiDisclosureConsent() async {
    final key = _geminiDisclosureConsentKey();
    SharedPreferences? preferences;

    try {
      preferences = await SharedPreferences.getInstance();
      if (preferences.getBool(key) == true) return true;
    } catch (error) {
      // Consent can still be collected for this request if local storage fails.
      // It will be shown again next time because the acceptance could not persist.
      debugPrint('[GEMINI DISCLOSURE] Could not read saved consent: $error');
    }

    if (!mounted) return false;

    final accepted = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF101126),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF292A46)),
        ),
        title: const Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.auto_awesome_rounded, color: Color(0xFFA78BFA)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Before we generate your career matches',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        content: const SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'To create your career recommendations, Evolyn sends relevant '
                'answers from your onboarding questionnaire to Google Gemini. '
                'These answers can describe your interests, preferences, skills, '
                'and goals.',
                style: TextStyle(
                  color: Color(0xFFCACBDA),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Evolyn is designed not to include your sign-up name, email '
                'address, password, or internal Evolyn account ID in the AI '
                'prompt. Google’s handling of prompts can vary by Gemini API '
                'service tier and configuration.',
                style: TextStyle(
                  color: Color(0xFFCACBDA),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'Do not include sensitive, confidential, or identifying '
                'information in your onboarding answers. AI-generated career '
                'suggestions may be incomplete or inaccurate; review them using '
                'your own judgment.',
                style: TextStyle(
                  color: Color(0xFFCACBDA),
                  fontSize: 13,
                  height: 1.5,
                ),
              ),
              SizedBox(height: 12),
              Text(
                'By selecting “Agree & Generate”, you agree to send these '
                'onboarding answers to Gemini for this feature. You can read '
                'the Privacy Policy in Profile → Privacy & Security.',
                style: TextStyle(
                  color: Color(0xFFA78BFA),
                  fontSize: 12,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text(
              'Not now',
              style: TextStyle(color: Color(0xFF9294AD)),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA78BFA),
              foregroundColor: const Color(0xFF100D24),
            ),
            child: const Text(
              'Agree & Generate',
              style: TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );

    if (!mounted || accepted != true) return false;

    try {
      preferences ??= await SharedPreferences.getInstance();
      await preferences.setBool(key, true);
    } catch (error) {
      debugPrint('[GEMINI DISCLOSURE] Could not save consent: $error');
      // The user's explicit choice still applies to the request in this session.
      // The disclosure will be shown again if it could not be persisted.
    }

    return true;
  }

  Future<void> _startGeneration() async {
    if (_cooldownUntil != null && _cooldownUntil!.isAfter(DateTime.now())) {
      return;
    }
    if (!mounted) return;

    final consentGranted = await _ensureGeminiDisclosureConsent();
    if (!mounted) return;

    if (!consentGranted) {
      setState(() {
        _isGenerating = false;
        _errorMessage =
            'Generation was not started. Your onboarding answers were not sent to Gemini.';
        _disclosureDeclined = true;
      });
      return;
    }

    setState(() {
      _isGenerating = true;
      _completedSteps = 0;
      _receivedCharacters = 0;
      _errorMessage = null;
      _disclosureDeclined = false;
    });

    try {
      // Keep the rest of your existing _startGeneration() implementation here,
      // beginning with:
      // final supabase = Supabase.instance.client;
      final supabase = Supabase.instance.client;
      final session = supabase.auth.currentSession;

      if (session == null) {
        throw const _BackendGenerationException(
          'UNAUTHENTICATED',
          'Please sign in before generating recommendations.',
        );
      }

      // This ID is only used to correlate the current frontend flow.
      // It does not represent a saved recommendation batch.
      _requestId ??= _newUuidV4();

      final response = await supabase.functions.invoke(
        'generate-journey',
        body: const <String, dynamic>{},
        headers: {
          'Authorization': 'Bearer ${session.accessToken}',
          'Accept': 'text/event-stream',
        },
      );

      final rawStream = response.data;

      if (rawStream is! Stream) {
        throw const FormatException(
          'The function did not return a streaming response.',
        );
      }

      final Stream<String> textStream = rawStream.cast<List<int>>().transform(
        utf8.decoder,
      );

      String buffer = '';
      Map<String, dynamic>? completedPayload;

      void processFrame(String frame) {
        String event = 'message';
        final dataLines = <String>[];

        for (final line in frame.split(RegExp(r'\r\n|\r|\n'))) {
          if (line.startsWith('event:')) {
            event = line.substring(6).trim();
          } else if (line.startsWith('data:')) {
            dataLines.add(line.substring(5).trimLeft());
          }
        }

        if (dataLines.isEmpty) return;

        final rawData = dataLines.join('\n');

        if (rawData == '[DONE]') return;

        final decoded = jsonDecode(rawData);

        if (decoded is! Map) {
          throw const FormatException(
            'Invalid SSE event received from the server.',
          );
        }

        final payload = Map<String, dynamic>.from(decoded);

        if (event == 'progress') {
          final stage = payload['stage']?.toString();

          // Keep the progress indicator aligned with the backend stages.
          final stageSteps = <String, int>{
            'generating': 1,
            'validating': 4,
            'completed': _steps.length,
          };

          final stageStep = stageSteps[stage];

          if (mounted && stageStep != null) {
            setState(() {
              _completedSteps = math.max(_completedSteps, stageStep).toInt();
            });
          }
        } else if (event == 'token') {
          final tokenText = payload['text'];

          if (tokenText is String && mounted) {
            _receivedCharacters += tokenText.length;

            final estimatedStep = math
                .min(_steps.length - 1, 1 + (_receivedCharacters ~/ 1800))
                .toInt();

            if (estimatedStep > _completedSteps) {
              setState(() {
                _completedSteps = estimatedStep;
              });
            }
          }
        } else if (event == 'error') {
          final nestedError = _decodeJsonMap(payload['error']);
          final errorPayload = nestedError ?? payload;

          throw _BackendGenerationException(
            (errorPayload['code'] ?? payload['code'])?.toString(),
            (errorPayload['message'] ?? payload['message'])?.toString() ??
                payload['error']?.toString() ??
                'Career recommendation generation failed.',
            cooldownUntil: payload['cooldown_until']?.toString(),
          );
        } else if (event == 'complete') {
          // The backend may send the validated response directly:
          // { "career_options": [...] }
          //
          // If it also includes "success", require it to be true.
          if (payload.containsKey('success') && payload['success'] != true) {
            throw const FormatException(
              'The server reported that generation was unsuccessful.',
            );
          }

          if (payload['career_options'] is! List) {
            throw const FormatException(
              'The server returned no valid career options.',
            );
          }

          completedPayload = payload;
        }
      }

      // Parse SSE incrementally, because an individual network chunk may
      // contain part of an event or multiple events.
      final frameSeparator = RegExp(r'\r\n\r\n|\n\n|\r\r');

      await for (final chunk in textStream) {
        buffer += chunk;

        while (true) {
          final match = frameSeparator.firstMatch(buffer);

          if (match == null) break;

          final frame = buffer.substring(0, match.start);
          buffer = buffer.substring(match.end);

          processFrame(frame);
        }
      }

      // Process a final event if the stream ends without a frame separator.
      if (buffer.trim().isNotEmpty) {
        processFrame(buffer.trim());
      }

      final payload = completedPayload;

      if (payload == null) {
        throw const FormatException(
          'The stream ended before generation completed.',
        );
      }

      final rawOptions = payload['career_options'] as List;

      final careerOptions = rawOptions.map((item) {
        if (item is! Map) {
          throw const FormatException(
            'The server returned an invalid career recommendation.',
          );
        }

        return Map<String, dynamic>.from(item);
      }).toList();

      if (careerOptions.length != 5) {
        throw FormatException(
          'Expected 5 career recommendations, '
          'but the server returned ${careerOptions.length}.',
        );
      }

      final requestId = _requestId ??= _newUuidV4();

      // Persist the complete result before leaving this screen.
      await _careerOptionsStorage.save(
        userId: session.user.id,
        requestId: requestId,
        careerOptions: careerOptions,
      );
      await _clearCooldown();

      debugPrint(
        '[CAREER CACHE] Saved ${careerOptions.length} career options locally.',
      );

      if (!mounted) return;

      setState(() {
        _completedSteps = _steps.length;
        _isGenerating = false;
        _errorMessage = null;
      });

      debugPrint('Career recommendation generation completed.');
      debugPrint('Career options received: ${careerOptions.length}');

      // Navigate immediately with the generated options.
      // Nothing is inserted into career_recommendations here.
      context.goNamed(
        RouteNames.careerRecommendations,
        extra: <String, dynamic>{
          'requestId': _requestId,
          'careerOptions': careerOptions,
        },
      );
    } catch (error, stackTrace) {
      debugPrint('generate-journey failed: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (!mounted) return;

      final customerMessage = _customerFacingErrorMessage(error);

      setState(() {
        _isGenerating = false;
        _errorMessage = customerMessage;
      });

      final serverDeadline = _cooldownDeadlineFromError(error);

      if (serverDeadline != null && serverDeadline.isAfter(DateTime.now())) {
        // The backend deadline is authoritative.
        await _beginCooldown(serverDeadline);
      } else if (error is _BackendGenerationException &&
          _shouldApplyAiCooldown(error.code)) {
        // Fallback only if the backend could not return its deadline.
        await _beginCooldown(DateTime.now().add(_generationCooldownDuration));
      } else {
        // Normal validation/profile/auth/format errors do not start a timer.
        await _clearCooldown();
      }
    }
  }

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  // void _enterEvolyn() {
  //   context.go('/goal-recommendations');
  // }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF050614),
      body: SafeArea(
        child: Stack(
          children: [
            _buildBackgroundGlow(),

            SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
              child: Column(
                children: [
                  const SizedBox(height: 24),

                  _buildEvolynOrb(),

                  const SizedBox(height: 30),

                  _buildHeading(),

                  const SizedBox(height: 10),

                  _buildSubtitle(),

                  const SizedBox(height: 38),

                  _buildProgressIndicator(),

                  const SizedBox(height: 30),

                  _buildSteps(),

                  const SizedBox(height: 30),

                  _buildBottomMessage(),

                  const SizedBox(height: 24),

                  _buildButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // BACKGROUND
  // ---------------------------------------------------------------------------

  Widget _buildBackgroundGlow() {
    return Stack(
      children: [
        Positioned(
          top: -180,
          left: -100,
          child: Container(
            width: 400,
            height: 400,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF8B5CF6).withOpacity(0.18),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),

        Positioned(
          bottom: -220,
          right: -140,
          child: Container(
            width: 430,
            height: 430,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                colors: [
                  const Color(0xFF4F46E5).withOpacity(0.12),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // E ORB
  // ---------------------------------------------------------------------------

  Widget _buildEvolynOrb() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final glow = 18 + (_pulseController.value * 10);

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
                spreadRadius: 4,
              ),
            ],
          ),
          child: const Center(
            child: Text(
              'E',
              style: TextStyle(
                color: Colors.white,
                fontSize: 40,
                fontWeight: FontWeight.w600,
                letterSpacing: -1,
              ),
            ),
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // HEADING
  // ---------------------------------------------------------------------------

  Widget _buildHeading() {
    return const Text(
      'Finding your career matches.',
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
      'Matching career options to your interests, skills,\n'
      'experience and goals.',
      textAlign: TextAlign.center,
      style: TextStyle(
        color: Colors.white.withOpacity(0.48),
        fontSize: 13,
        height: 1.5,
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // TOP PROGRESS
  // ---------------------------------------------------------------------------

  Widget _buildProgressIndicator() {
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

        const SizedBox(height: 9),

        Row(
          children: [
            Text(
              _errorMessage != null
                  ? 'Generation failed'
                  : 'Finding careers that fit your profile...',
              style: TextStyle(
                color: Colors.white.withOpacity(0.32),
                fontSize: 9.5,
              ),
            ),
            const Spacer(),
            Text(
              '${(_completedSteps / _steps.length * 100).round()}%',
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

  // ---------------------------------------------------------------------------
  // STEPS
  // ---------------------------------------------------------------------------

  Widget _buildSteps() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0D0E20),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF252640)),
      ),
      child: Column(
        children: List.generate(_steps.length, (index) {
          return _buildStep(step: _steps[index], index: index);
        }),
      ),
    );
  }

  Widget _buildStep({required _GenerationStep step, required int index}) {
    final isCompleted = index < _completedSteps;

    final isCurrent = index == _completedSteps && _isGenerating;

    final isLast = index == _steps.length - 1;

    return Column(
      children: [
        Row(
          children: [
            _buildStepIcon(
              step: step,
              isCompleted: isCompleted,
              isCurrent: isCurrent,
            ),

            const SizedBox(width: 13),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    step.title,
                    style: TextStyle(
                      color: isCompleted || isCurrent
                          ? Colors.white
                          : const Color(0xFF77788A),
                      fontSize: 12.5,
                      fontWeight: isCompleted || isCurrent
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
                      color: isCompleted || isCurrent
                          ? Colors.white.withOpacity(0.35)
                          : Colors.white.withOpacity(0.20),
                      fontSize: 9.5,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),

            if (isCompleted)
              const Icon(
                Icons.check_rounded,
                color: Color(0xFF59E1A8),
                size: 19,
              ),

            if (isCurrent)
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

        if (!isLast)
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 8, bottom: 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                width: 1,
                height: 15,
                color: isCompleted
                    ? const Color(0xFF4B4672)
                    : const Color(0xFF202137),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStepIcon({
    required _GenerationStep step,
    required bool isCompleted,
    required bool isCurrent,
  }) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 250),
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: isCompleted
            ? const Color(0xFF123528)
            : isCurrent
            ? const Color(0xFF291C52)
            : const Color(0xFF17182B),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(
          color: isCompleted
              ? const Color(0xFF3F9E79)
              : isCurrent
              ? const Color(0xFF8B5CF6)
              : const Color(0xFF282940),
        ),
      ),
      child: Icon(
        step.icon,
        size: 16,
        color: isCompleted
            ? const Color(0xFF68E3B0)
            : isCurrent
            ? const Color(0xFFB79AFF)
            : const Color(0xFF5F6176),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // MESSAGE
  // ---------------------------------------------------------------------------

  Widget _buildBottomMessage() {
    if (_errorMessage != null) {
      final cooldownActive =
          _cooldownUntil != null && _cooldownUntil!.isAfter(DateTime.now());

      return Column(
        children: [
          const Icon(
            Icons.error_outline_rounded,
            color: Color(0xFFFF8A8A),
            size: 22,
          ),
          const SizedBox(height: 8),
          Text(
            _errorMessage!,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white.withOpacity(0.62),
              fontSize: 11,
              height: 1.4,
            ),
          ),
          if (cooldownActive) ...[
            const SizedBox(height: 18),
            Text(
              'Please wait before trying again',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.42),
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              _formatCooldown(_cooldownSecondsRemaining),
              textAlign: TextAlign.center,
              style: const TextStyle(
                color: Color(0xFFA78BFA),
                fontSize: 30,
                fontWeight: FontWeight.w600,
                fontFamily: 'monospace',
                letterSpacing: 1.2,
              ),
            ),
          ] else ...[
            const SizedBox(height: 14),
            Text(
              _disclosureDeclined
                  ? 'Review the disclosure if you want to continue.'
                  : 'You can try again now.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Colors.white.withOpacity(0.42),
                fontSize: 11,
              ),
            ),
          ],
        ],
      );
    }

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
            'AI is preparing your career options...',
            style: TextStyle(
              color: Colors.white.withOpacity(0.38),
              fontSize: 10,
            ),
          ),
        ],
      );
    }

    return const SizedBox.shrink();
  }

  // ---------------------------------------------------------------------------
  // BUTTON
  // ---------------------------------------------------------------------------

  Widget _buildButton() {
    final cooldownActive =
        _cooldownUntil != null && _cooldownUntil!.isAfter(DateTime.now());
    if (_errorMessage == null || _isGenerating || cooldownActive) {
      return const SizedBox.shrink();
    }

    return SizedBox(
      width: double.infinity,
      height: 54,
      child: ElevatedButton.icon(
        onPressed: _startGeneration,
        icon: Icon(
          _disclosureDeclined ? Icons.policy_outlined : Icons.refresh_rounded,
          size: 18,
        ),
        label: Text(
          _disclosureDeclined ? 'Review disclosure' : 'Try again',
          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: const Color(0xFF8B5CF6),
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }
}

class _GenerationStep {
  final String title;
  final String subtitle;
  final IconData icon;

  const _GenerationStep({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
}

/// Carries a sanitized backend error and optional server cooldown deadline.
class _BackendGenerationException implements Exception {
  final String? code;
  final String message;
  final String? cooldownUntil;

  const _BackendGenerationException(
    this.code,
    this.message, {
    this.cooldownUntil,
  });

  @override
  String toString() => message;
}
