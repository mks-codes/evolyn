import 'dart:convert';
import 'dart:math' as math;

import 'package:evolyn/app/router/route_names.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

/// Displays AI-generated career options passed through GoRouter's extra.
///
/// The complete AI response remains in memory until the user selects up to
/// three careers and presses Generate roadmap.
///
/// Only the selected careers are saved to career_recommendations.
/// Navigation occurs after the selected rows are saved successfully.
class CareerRecommendationsScreen extends ConsumerStatefulWidget {
  const CareerRecommendationsScreen({
    super.key,
    required this.careerOptions,
    this.requestId,
  });

  final List<Map<String, dynamic>> careerOptions;
  final String? requestId;

  @override
  ConsumerState<CareerRecommendationsScreen> createState() =>
      _CareerRecommendationsScreenState();
}

class _CareerRecommendationsScreenState
    extends ConsumerState<CareerRecommendationsScreen> {
  static const int _maxSelections = 3;

  static const Color _backgroundColor = Color(0xFF050614);
  static const Color _cardColor = Color(0xFF111326);
  static const Color _accentColor = Color(0xFF8B5CF6);
  static const Color _accentLightColor = Color(0xFFA78BFA);
  static const Color _borderColor = Color(0xFF292A46);
  static const Color _errorColor = Color(0xFFFF8A8A);

  final Set<String> _selectedKeys = <String>{};

  bool _isWorking = false;
  String? _errorMessage;

  /// Stable fallback request ID for this screen instance.
  ///
  /// The generation screen should ideally pass the original request ID.
  /// This fallback is used when it does not.
  late final String _selectionRequestId;

  @override
  void initState() {
    super.initState();

    final incomingRequestId = widget.requestId?.trim();

    _selectionRequestId =
        incomingRequestId != null && incomingRequestId.isNotEmpty
        ? incomingRequestId
        : _newUuidV4();
  }

  // ---------------------------------------------------------------------------
  // UUID
  // ---------------------------------------------------------------------------

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

  // ---------------------------------------------------------------------------
  // CAREER HELPERS
  // ---------------------------------------------------------------------------

  String _careerKey(Map<String, dynamic> career) {
    final id = career['id']?.toString().trim();

    if (id != null && id.isNotEmpty) {
      return id;
    }

    return '${career['rank'] ?? ''}:${career['career_title'] ?? ''}';
  }

  List<Map<String, dynamic>> get _selectedCareers {
    final selected = widget.careerOptions
        .where((career) => _selectedKeys.contains(_careerKey(career)))
        .toList();

    selected.sort((a, b) => _rankOf(a).compareTo(_rankOf(b)));

    return selected;
  }

  int _rankOf(Map<String, dynamic> career) {
    final value = career['rank'];

    if (value is int) return value;
    if (value is num) return value.toInt();

    return 999999;
  }

  int _scoreOf(Map<String, dynamic> career) {
    final value = career['match_score'];

    if (value is int) return value;
    if (value is num) return value.toInt();

    return 0;
  }

  String _effectiveRequestId(List<Map<String, dynamic>> selected) {
    final fromWidget = widget.requestId?.trim();

    if (fromWidget != null && fromWidget.isNotEmpty) {
      return fromWidget;
    }

    for (final career in selected) {
      final value = career['request_id']?.toString().trim();

      if (value != null && value.isNotEmpty) {
        return value;
      }
    }

    return _selectionRequestId;
  }

  // ---------------------------------------------------------------------------
  // SELECTION
  // ---------------------------------------------------------------------------

  void _toggleCareer({
    required Map<String, dynamic> career,
    required bool selected,
  }) {
    if (_isWorking) return;

    final key = _careerKey(career);

    if (selected && !_selectedKeys.contains(key)) {
      if (_selectedKeys.length >= _maxSelections) {
        setState(() {
          _errorMessage =
              'You can select a maximum of $_maxSelections careers.';
        });
        return;
      }
    }

    setState(() {
      if (selected) {
        _selectedKeys.add(key);
      } else {
        _selectedKeys.remove(key);
      }

      _errorMessage = null;
    });
  }

  // ---------------------------------------------------------------------------
  // SAVE SELECTED CAREERS AND OPEN ROADMAP GENERATION
  // ---------------------------------------------------------------------------

  Future<void> _generateRoadmap() async {
    if (_isWorking) return;

    final selected = _selectedCareers;

    if (selected.isEmpty) {
      setState(() {
        _errorMessage = 'Select at least one career to continue.';
      });
      return;
    }

    if (selected.length > _maxSelections) {
      setState(() {
        _errorMessage = 'You can select a maximum of $_maxSelections careers.';
      });
      return;
    }

    final requestId = _effectiveRequestId(selected);

    setState(() {
      _isWorking = true;
      _errorMessage = null;
    });

    try {
      // Pass the selected AI-generated career options without saving them.
      await context.pushNamed(
        RouteNames.roadmapGeneration,
        extra: <String, dynamic>{
          'requestId': requestId,
          'selectedCareers': selected
              .map((career) => Map<String, dynamic>.from(career))
              .toList(),
        },
      );
    } catch (error, stackTrace) {
      debugPrint('[career-recommendations] Navigation error: $error');
      debugPrintStack(stackTrace: stackTrace);

      if (mounted) {
        setState(() {
          _errorMessage =
              'Could not open roadmap generation. Please try again.';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
        });
      }
    }
  }

  // ---------------------------------------------------------------------------
  // MAIN UI
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        backgroundColor: _backgroundColor,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Text('Career Recommendations'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(theme),
            Expanded(child: _buildCareerList()),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HEADER
  // ---------------------------------------------------------------------------

  Widget _buildHeader(ThemeData theme) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Choose up to 3 careers',
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Review all ${widget.careerOptions.length} options and select '
            'up to 3 careers to build your personalized roadmap.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: Colors.white70,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Text(
                '${_selectedKeys.length}/$_maxSelections selected',
                style: theme.textTheme.labelLarge?.copyWith(
                  color: _accentLightColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              if (_selectedKeys.isNotEmpty)
                TextButton(
                  onPressed: _isWorking
                      ? null
                      : () {
                          setState(() {
                            _selectedKeys.clear();
                            _errorMessage = null;
                          });
                        },
                  child: const Text(
                    'Clear selection',
                    style: TextStyle(color: _accentLightColor),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CAREER LIST
  // ---------------------------------------------------------------------------

  Widget _buildCareerList() {
    if (widget.careerOptions.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'No career options were passed to this screen. '
            'Return to generation and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white70),
          ),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      itemCount: widget.careerOptions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final career = widget.careerOptions[index];
        final key = _careerKey(career);
        final selected = _selectedKeys.contains(key);

        return _buildCareerCard(career: career, selected: selected);
      },
    );
  }

  // ---------------------------------------------------------------------------
  // CAREER CARD
  // ---------------------------------------------------------------------------

  Widget _buildCareerCard({
    required Map<String, dynamic> career,
    required bool selected,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: _cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: selected ? _accentColor : _borderColor,
          width: selected ? 1.5 : 1,
        ),
      ),
      child: Column(
        children: [
          CheckboxListTile(
            value: selected,
            onChanged: _isWorking
                ? null
                : (value) {
                    if (value == null) return;

                    _toggleCareer(career: career, selected: value);
                  },
            activeColor: _accentColor,
            checkColor: Colors.white,
            controlAffinity: ListTileControlAffinity.leading,
            contentPadding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            title: Text(
              '${career['career_title'] ?? 'Career option'}',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 5),
              child: Text(
                'Rank ${career['rank'] ?? '—'} · '
                '${_scoreOf(career)}% match · '
                '${career['match_level'] ?? 'Match level unavailable'}\n'
                '${career['career_category'] ?? ''}\n'
                '${career['match_summary'] ?? ''}',
                style: const TextStyle(color: Colors.white70, height: 1.45),
              ),
            ),
          ),
          Theme(
            data: Theme.of(context).copyWith(
              dividerColor: Colors.transparent,
              colorScheme: Theme.of(
                context,
              ).colorScheme.copyWith(onSurface: Colors.white),
            ),
            child: ExpansionTile(
              tilePadding: const EdgeInsets.symmetric(horizontal: 16),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              iconColor: _accentLightColor,
              collapsedIconColor: Colors.white60,
              title: const Text(
                'View full career details',
                style: TextStyle(
                  color: _accentLightColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
              children: [
                _detail('Typical work', career['typical_work']),
                _detail('Why it matches', career['why_it_matches']),
                _detail('Supporting evidence', career['supporting_evidence']),
                _detail(
                  'Existing skill alignment',
                  career['existing_skill_alignment'],
                ),
                _detail('Skills to develop', career['skills_to_develop']),
                _detail('Entry requirements', career['entry_requirements']),
                _detail(
                  'Accessibility considerations',
                  career['accessibility_considerations'],
                ),
                _detail('Potential challenges', career['potential_challenges']),
                _detail('Confidence', career['confidence']),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FOOTER
  // ---------------------------------------------------------------------------

  Widget _buildFooter() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_errorMessage != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(
              _errorMessage!,
              style: const TextStyle(color: _errorColor, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: SizedBox(
            width: double.infinity,
            height: 54,
            child: FilledButton.icon(
              onPressed:
                  _isWorking ||
                      widget.careerOptions.isEmpty ||
                      _selectedKeys.isEmpty
                  ? null
                  : _generateRoadmap,
              style: FilledButton.styleFrom(
                backgroundColor: _accentColor,
                disabledBackgroundColor: const Color(0xFF3C315E),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              icon: _isWorking
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.route_rounded),
              label: Text(
                _isWorking
                    ? 'Opening roadmap generation...'
                    : 'Generate roadmap '
                          '(${_selectedKeys.length}/$_maxSelections)',
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------------------
  // CAREER DETAIL ROW
  // ---------------------------------------------------------------------------

  Widget _detail(String title, dynamic value) {
    if (value == null) {
      return const SizedBox.shrink();
    }

    final String text;

    if (value is List) {
      text = value.map((item) => item.toString()).join('\n• ');
    } else if (value is Map) {
      text = const JsonEncoder.withIndent('  ').convert(value);
    } else {
      text = value.toString();
    }

    if (text.trim().isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              text,
              style: const TextStyle(color: Colors.white70, height: 1.45),
            ),
          ],
        ),
      ),
    );
  }
}
