
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router/route_names.dart';

/// Evolyn language picker.
/// Flow: successful login -> LanguageSelectionPage -> OnboardingScreen.
class LanguageSelectionPage extends StatefulWidget {
  const LanguageSelectionPage({super.key});

  @override
  State<LanguageSelectionPage> createState() =>
      _LanguageSelectionPageState();
}

class _LanguageSelectionPageState extends State<LanguageSelectionPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  String? _selectedLanguage;
  bool _saving = false;
  String? _error;

  // English is a permanent companion language in the questionnaire.
  // Users choose only the additional language: Hindi or Marathi.
  static const _languages = <_Language>[
    _Language(
      code: 'hi',
      name: 'हिन्दी',
      nativeSubtitle: 'हिन्दी में आगे बढ़ें',
      glyph: 'अ',
    ),
    _Language(
      code: 'mr',
      name: 'मराठी',
      nativeSubtitle: 'मराठीत पुढे चला',
      glyph: 'अ',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadSavedLanguage();
  }

  Future<void> _loadSavedLanguage() async {
    try {
      final user = _supabase.auth.currentUser;
      if (user == null) return;

      final row = await _supabase
          .from('profiles')
          .select('onboarding_data')
          .eq('id', user.id)
          .maybeSingle();

      final data = row?['onboarding_data'];
      if (data is! Map) return;

      final career = data['career_onboarding'];
      if (career is! Map) return;

      final language = career['language'];

      if (language is String &&
          _languages.any((item) => item.code == language) &&
          mounted) {
        setState(() => _selectedLanguage = language);
      }
    } catch (_) {
      // The user can still select a language if loading fails.
    }
  }

  Future<void> _saveAndContinue() async {
    final language = _selectedLanguage;
    if (language == null || _saving) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final user = _supabase.auth.currentUser;

      if (user == null) {
        throw const AuthException('Please sign in to continue.');
      }
      debugPrint('[LANGUAGE] Save started');
      // Preserve existing onboarding answers.
      final row = await _supabase
          .from('profiles')
          .select('onboarding_data')
          .eq('id', user.id)
          .maybeSingle();

      final onboarding = <String, dynamic>{};
      final existingData = row?['onboarding_data'];

      if (existingData is Map) {
        onboarding.addAll(
          Map<String, dynamic>.from(existingData),
        );
      }

      final career = <String, dynamic>{};
      final existingCareer = onboarding['career_onboarding'];

      if (existingCareer is Map) {
        career.addAll(
          Map<String, dynamic>.from(existingCareer),
        );
      }

      career['language'] = language;
      onboarding['career_onboarding'] = career;

      await _supabase.from('profiles').upsert({
        'id': user.id,
        'onboarding_data': onboarding,
      });
      debugPrint('[LANGUAGE] Supabase save completed');

      if (!mounted) return;
debugPrint('[LANGUAGE] Navigating to onboarding');
      context.goNamed(
        RouteNames.onboarding,
        queryParameters: {
          'languageSelected': 'true',
          'language': language,
        },
      );
      context.pop();
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _error = e is AuthException
            ? e.message
            : 'We could not save your language. Please try again.';
      });
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFF080D2B),
      body: Stack(
        children: [
          // Dark blue and purple gradient background.
          const Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFF080D2B),
                    Color(0xFF101A4C),
                    Color(0xFF21104A),
                  ],
                ),
              ),
            ),
          ),

          // Purple ambient glow.
          const Positioned(
            top: -90,
            right: -65,
            child: _GlowOrb(
              size: 250,
              color: Color(0x667C3AED),
            ),
          ),

          // Blue ambient glow.
          const Positioned(
            bottom: -100,
            left: -75,
            child: _GlowOrb(
              size: 270,
              color: Color(0x55406CFF),
            ),
          ),

          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final compact = constraints.maxHeight < 740;
                final contentWidth = constraints.maxWidth >= 506
                    ? 470.0
                    : constraints.maxWidth - 36.0;

                return Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 8,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Select Language',
                        textAlign: TextAlign.left,
                        style: TextStyle(
                          color: Color(0xFFE0E7FF),
                          fontSize: 27,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Center(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            child: SizedBox(
                              width: contentWidth,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                      // Main glass-style content card.
                      Container(
                        padding: EdgeInsets.all(compact ? 14 : 20),
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFF172554),
                              Color(0xFF211747),
                              Color(0xFF151D45),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(30),
                          border: Border.all(
                            color: const Color(0xFF414B91),
                            width: 1.4,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x443B32A0),
                              blurRadius: 35,
                              offset: Offset(0, 16),
                            ),
                          ],
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(24),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(
                              sigmaX: 8,
                              sigmaY: 8,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Language icon.

                                SizedBox(height: compact ? 2 : 8),

                                // Explain that English is always shown and
                                // the user selects only Hindi or Marathi.
                                Container(
                                  padding: EdgeInsets.all(compact ? 10 : 12),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF111B45),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(0xFF4B4B91),
                                    ),
                                  ),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Icon(
                                            Icons.info_outline_rounded,
                                            color: Color(0xFFB9A7FF),
                                            size: 20,
                                          ),
                                          SizedBox(width: 9),
                                          Expanded(
                                            child: Text(
                                              'Every question shows English plus your choice. Select Hindi or Marathi below.',
                                              style: TextStyle(
                                                color: Color(0xFFE0E7FF),
                                                fontSize: 12,
                                                height: 1.45,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      SizedBox(height: 9),
                                      Text(
                                        'हर प्रश्न अंग्रेज़ी और आपकी चुनी हुई भाषा में दिखेगा। हिंदी या मराठी चुनें।',
                                        style: TextStyle(
                                          color: Color(0xFFA5B4FC),
                                          fontSize: 12,
                                          height: 1.45,
                                        ),
                                      ),
                                      SizedBox(height: 5),
                                      Text(
                                        'प्रत्येक प्रश्न इंग्रजी आणि तुमच्या निवडलेल्या भाषेत दिसेल. हिंदी किंवा मराठी निवडा.',
                                        style: TextStyle(
                                          color: Color(0xFFA5B4FC),
                                          fontSize: 12,
                                          height: 1.45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                SizedBox(height: compact ? 10 : 16),

                                // English is visible but disabled because it
                                // is always shown alongside the chosen language.
                                Container(
                                  margin: EdgeInsets.only(bottom: compact ? 7 : 10),
                                  padding: EdgeInsets.symmetric(
                                    horizontal: compact ? 10 : 14,
                                    vertical: compact ? 8 : 11,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF111832),
                                    borderRadius: BorderRadius.circular(18),
                                    border: Border.all(
                                      color: const Color(0xFF303957),
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        width: compact ? 38 : 43,
                                        height: compact ? 38 : 43,
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: Color(0xFF202A48),
                                          borderRadius: BorderRadius.all(
                                            Radius.circular(14),
                                          ),
                                        ),
                                        child: Text(
                                          'A',
                                          style: TextStyle(
                                            color: Color(0xFF7E8BAF),
                                            fontSize: compact ? 20 : 22,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                      SizedBox(width: compact ? 10 : 12),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              'English',
                                              style: TextStyle(
                                                color: Color(0xFF8A96BA),
                                                fontSize: 16,
                                                fontWeight: FontWeight.w800,
                                              ),
                                            ),
                                            SizedBox(height: 2),
                                            Text(
                                              'Always included • Not selectable',
                                              style: TextStyle(
                                                color: Color(0xFF7E8BAF),
                                                fontSize: 12,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(
                                        Icons.lock_outline_rounded,
                                        color: Color(0xFF7E8BAF),
                                        size: 22,
                                      ),
                                    ],
                                  ),
                                ),

                                // Only Hindi and Marathi are selectable.
                                ..._languages.map(
                                  (language) => Padding(
                                    padding: EdgeInsets.only(
                                      bottom: compact ? 7 : 9,
                                    ),
                                    child: _LanguageOptionCard(
                                      language: language,
                                      selected:
                                          _selectedLanguage == language.code,
                                      onTap: () {
                                        setState(() {
                                          _selectedLanguage = language.code;
                                          _error = null;
                                        });
                                      },
                                    ),
                                  ),
                                ),

                                // Error message.
                                if (_error != null) ...[
                                  const SizedBox(height: 2),
                                  Text(
                                    _error!,
                                    style: const TextStyle(
                                      color: Color(0xFFFF8FA3),
                                      fontSize: 13,
                                    ),
                                  ),
                                  SizedBox(height: compact ? 6 : 10),
                                ],

                                SizedBox(height: compact ? 4 : 7),

                                // Continue button.
                                SizedBox(
                                  height: compact ? 48 : 53,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      gradient:
                                          _selectedLanguage == null || _saving
                                              ? const LinearGradient(
                                                  colors: [
                                                    Color(0xFF343A75),
                                                    Color(0xFF44316F),
                                                  ],
                                                )
                                              : const LinearGradient(
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                  colors: [
                                                    Color(0xFF3B82F6),
                                                    Color(0xFF6366F1),
                                                    Color(0xFF8B5CF6),
                                                  ],
                                                ),
                                      borderRadius: BorderRadius.circular(17),
                                      boxShadow:
                                          _selectedLanguage == null || _saving
                                              ? null
                                              : const [
                                                  BoxShadow(
                                                    color: Color(0x443B82F6),
                                                    blurRadius: 18,
                                                    offset: Offset(0, 6),
                                                  ),
                                                ],
                                    ),
                                    child: FilledButton(
                                      onPressed:
                                          _selectedLanguage == null || _saving
                                              ? null
                                              : _saveAndContinue,
                                      style: FilledButton.styleFrom(
                                        backgroundColor: Colors.transparent,
                                        disabledBackgroundColor:
                                            Colors.transparent,
                                        foregroundColor:
                                            const Color(0xFFE0E7FF),
                                        disabledForegroundColor:
                                            const Color(0xFF818FCB),
                                        elevation: 0,
                                        shadowColor: Colors.transparent,
                                        shape: RoundedRectangleBorder(
                                          borderRadius:
                                              BorderRadius.circular(17),
                                        ),
                                      ),
                                      child: _saving
                                          ? const SizedBox(
                                              width: 22,
                                              height: 22,
                                              child: CircularProgressIndicator(
                                                color: Color(0xFFE0E7FF),
                                                strokeWidth: 2,
                                              ),
                                            )
                                          : const Row(
                                              mainAxisAlignment:
                                                  MainAxisAlignment.center,
                                              children: [
                                                Text(
                                                  'Continue',
                                                  style: TextStyle(
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                                SizedBox(width: 9),
                                                Icon(
                                                  Icons.arrow_forward_rounded,
                                                  size: 20,
                                                ),
                                              ],
                                            ),
                                    ),
                                  ),
                                ),

                                SizedBox(height: compact ? 7 : 11),

                                const Text(
                                  'You can change your language later.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    color: Color(0xFF929FD9),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                                  if (!compact) ...[
                                    const SizedBox(height: 12),
                                    const Text(
                                      'SMALL STEPS. MEANINGFUL GROWTH.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: Color(0xFF818FCB),
                                        fontSize: 10,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.5,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// Language model.
class _Language {
  const _Language({
    required this.code,
    required this.name,
    required this.nativeSubtitle,
    required this.glyph,
  });

  final String code;
  final String name;
  final String nativeSubtitle;
  final String glyph;
}

// Reusable blue-purple language card.
class _LanguageOptionCard extends StatelessWidget {
  const _LanguageOptionCard({
    required this.language,
    required this.selected,
    required this.onTap,
  });

  final _Language language;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const ink = Color(0xFFE0E7FF);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 170),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          colors: selected
              ? const [
                  Color(0xFF303A80),
                  Color(0xFF3B246F),
                ]
              : const [
                  Color(0xFF172554),
                  Color(0xFF20204F),
                ],
        ),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: selected
              ? const Color(0xFF9B87FF)
              : const Color(0xFF354477),
          width: selected ? 1.7 : 1,
        ),
        boxShadow: selected
            ? const [
                BoxShadow(
                  color: Color(0x447C3AED),
                  blurRadius: 14,
                  offset: Offset(0, 5),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 10,
            ),
            child: Row(
              children: [
                // Language glyph.
                Container(
                  width: 42,
                  height: 42,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: selected
                          ? const [
                              Color(0xFF3B82F6),
                              Color(0xFF8B5CF6),
                            ]
                          : const [
                              Color(0xFF26366C),
                              Color(0xFF35265F),
                            ],
                    ),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    language.glyph,
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.w800,
                      color: selected
                          ? const Color(0xFFE0E7FF)
                          : const Color(0xFFA5B4FC),
                    ),
                  ),
                ),

                const SizedBox(width: 14),

                // Language name and subtitle.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        language.name,
                        style: const TextStyle(
                          color: ink,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        language.nativeSubtitle,
                        style: const TextStyle(
                          color: Color(0xFFA5B4FC),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),

                // Selection indicator.
                Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.circle_outlined,
                  color: selected
                      ? const Color(0xFFB9A7FF)
                      : const Color(0xFF6675B8),
                  size: 23,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// Decorative ambient glow.
class _GlowOrb extends StatelessWidget {
  const _GlowOrb({
    required this.size,
    required this.color,
  });

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color,
          boxShadow: [
            BoxShadow(
              color: color,
              blurRadius: 90,
              spreadRadius: 25,
            ),
          ],
        ),
      ),
    );
  }
}
