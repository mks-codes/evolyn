import 'dart:async';
import 'dart:math' as math;

import 'package:evolyn/features/profile/providers/profile_provider.dart';
import 'package:evolyn/features/session/providers/session_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/onboarding_provider.dart';
import '../../../app/router/route_names.dart';

// Stores the selected category and all dynamic answers in the structured
// career questionnaire model exposed by onboarding_provider.dart.
class OnboardingScreen extends ConsumerStatefulWidget {
  final String? initialLanguage;
  const OnboardingScreen({super.key, this.initialLanguage});
  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const bg = Color(0xFF050614),
      surface = Color(0xFF101126),
      accent = Color(0xFF8B5CF6);
  static const groupCount = 5;
  final PageController _pages = PageController();
  final Map<String, String> _answers = {};
  final Map<int, int> _categoryProgress = {};
  Timer? _autosave;
  Future<void> _saveQueue = Future<void>.value();
  String _languageOverride = '';
  int? _category;
  int _page = 0; // 0 = choose category; 1..5 = questionnaire groups.
  bool _loading = true, _saving = false;
  bool _categoryIntroShown = false;
  void _applyRouteLanguage() {
    final String? routeLanguage = widget.initialLanguage?.trim().toLowerCase();

    if (routeLanguage != null && ['en', 'hi', 'mr'].contains(routeLanguage)) {
      _languageOverride = routeLanguage;
    }
  }

  String get _language {
    final stored = _languageOverride.trim().isNotEmpty
        ? _languageOverride
        : ref.read(onboardingProvider).preferredLanguage;
    final p = stored.trim().toLowerCase();
    if (p == 'mr' ||
        p.startsWith('mr-') ||
        p.contains('marathi') ||
        p.contains('मराठी'))
      return 'mr';
    if (p == 'hi' ||
        p.startsWith('hi-') ||
        p.contains('hindi') ||
        p.contains('हिन्दी') ||
        p.contains('हिंदी'))
      return 'hi';
    return 'en';
  }

  String t(String en, [String? hi, String? mr]) => _language == 'hi'
      ? (hi ?? en)
      : _language == 'mr'
      ? (mr ?? en)
      : en;

  // Main learning content is always English first, then the selected language.
  // Navigation controls can continue using t() so the UI does not become cluttered.
  Widget _bilingualText(
    String en,
    String hi,
    String mr, {
    required TextStyle englishStyle,
    TextStyle? localizedStyle,
  }) {
    final localized = _language == 'hi'
        ? hi
        : _language == 'mr'
        ? mr
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(en, style: englishStyle),
        if (localized != null && localized.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              localized,
              style:
                  localizedStyle ??
                  englishStyle.copyWith(
                    color: const Color(0xFFB9B5D3),
                    fontSize: (englishStyle.fontSize ?? 14) * .92,
                  ),
            ),
          ),
      ],
    );
  }

  String _key(int c, int g, int q) => 'c${c + 1}_g${g + 1}_q${q + 1}';

  @override
  void initState() {
    super.initState();
    _restore();
  }

  @override
  void dispose() {
    _autosave?.cancel();
    _pages.dispose();
    super.dispose();
  }

  Widget _dialogBilingualText(
    String en,
    String hi,
    String mr, {
    required TextStyle englishStyle,
    TextStyle? localizedStyle,
  }) {
    final localized = _language == 'hi'
        ? hi
        : _language == 'mr'
        ? mr
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(en, style: englishStyle),
        if (localized != null && localized.trim().isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(
            localized,
            style:
                localizedStyle ??
                englishStyle.copyWith(color: const Color(0xFFD4CCF7)),
          ),
        ],
      ],
    );
  }

  void _scheduleEntryIntro() {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      if (_pages.hasClients) {
        _pages.jumpToPage(_page);
      }

      // Show the dialog matching the page where progress was restored.
      if (_page == 0) {
        await _showCategorySelectionIntro();
      } else {
        await _showQuestionnaireIntro();
      }
    });
  }

  Future<void> _showCategorySelectionIntro() async {
    if (!mounted || _categoryIntroShown) return;

    _categoryIntroShown = true;

    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF15162D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF393258)),
        ),
        title: _dialogBilingualText(
          'Before you choose a category',
          'श्रेणी चुनने से पहले',
          'श्रेणी निवडण्यापूर्वी',
          englishStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          localizedStyle: const TextStyle(
            color: Color(0xFFD4CCF7),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SingleChildScrollView(
          child: _dialogBilingualText(
            'This screen contains six career-goal categories. Before selecting one, carefully read the title, description, and examples of every category. Choose the category that best matches your current situation and goal. The right choice helps AI understand what you need and recommend more relevant career options.',
            'इस स्क्रीन पर करियर लक्ष्यों की छह श्रेणियाँ हैं। किसी एक को चुनने से पहले हर श्रेणी का शीर्षक, विवरण और उदाहरण ध्यान से पढ़ें। अपनी वर्तमान स्थिति और लक्ष्य से सबसे अच्छी तरह मेल खाने वाली श्रेणी चुनें। सही चुनाव से AI आपकी ज़रूरत को बेहतर ढंग से समझकर अधिक उपयुक्त करियर विकल्प सुझा सकेगा।',
            'या स्क्रीनवर करिअरच्या ध्येयांसाठी सहा श्रेणी आहेत. एखादी श्रेणी निवडण्यापूर्वी प्रत्येक श्रेणीचे शीर्षक, वर्णन आणि उदाहरणे काळजीपूर्वक वाचा. तुमची सध्याची परिस्थिती आणि ध्येय यांच्याशी सर्वाधिक जुळणारी श्रेणी निवडा. योग्य निवडीमुळे AI तुमच्या गरजा चांगल्या प्रकारे समजून अधिक योग्य करिअर पर्याय सुचवू शकेल.',
            englishStyle: const TextStyle(
              color: Color(0xFFD0D1E2),
              fontSize: 13,
              height: 1.5,
            ),
            localizedStyle: const TextStyle(
              color: Color(0xFFBDB5E0),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              minimumSize: const Size(100, 42),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(t('I understand', 'मैं समझ गया/गई', 'मला समजले')),
          ),
        ],
      ),
    );
  }

  Future<bool> _showQuestionnaireIntro() async {
    if (!mounted) return false;

    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: const Color(0xFF15162D),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: const BorderSide(color: Color(0xFF393258)),
        ),
        title: _dialogBilingualText(
          'Before you answer',
          'उत्तर देने से पहले',
          'उत्तरे देण्यापूर्वी',
          englishStyle: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
          localizedStyle: const TextStyle(
            color: Color(0xFFD4CCF7),
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        content: SingleChildScrollView(
          child: _dialogBilingualText(
            'Your selected category has 5 groups, with 4 questions in each group. Your answers help AI understand your background, interests, skills, goals, and practical circumstances. This information helps us recommend career options suited to you and create a personalized, relatable roadmap for your chosen career. Please answer every question truthfully and carefully. If you are unsure, say so rather than guessing. The more accurate your answers are, the more relevant your recommendations can be.',
            'आपकी चुनी हुई श्रेणी में 5 समूह हैं और हर समूह में 4 प्रश्न हैं। आपके उत्तर AI को आपकी पृष्ठभूमि, रुचियों, कौशल, लक्ष्यों और व्यावहारिक परिस्थितियों को समझने में मदद करते हैं। इससे आपके लिए उपयुक्त करियर विकल्प सुझाने और आपके चुने हुए करियर के लिए व्यक्तिगत और आपकी परिस्थितियों से जुड़ा रोडमैप बनाने में मदद मिलती है। कृपया हर प्रश्न का उत्तर ईमानदारी और ध्यान से दें। यदि आपको उत्तर नहीं पता है, तो अनुमान लगाने के बजाय ऐसा लिखें। आपके उत्तर जितने सटीक होंगे, सुझाव उतने ही उपयोगी हो सकते हैं।',
            'तुम्ही निवडलेल्या श्रेणीत 5 गट आहेत आणि प्रत्येक गटात 4 प्रश्न आहेत. तुमची उत्तरे AI ला तुमची पार्श्वभूमी, आवडी, कौशल्ये, उद्दिष्टे आणि व्यावहारिक परिस्थिती समजून घेण्यास मदत करतात. यामुळे तुमच्यासाठी योग्य करिअर पर्याय सुचवता येतात आणि तुम्ही निवडलेल्या करिअरसाठी तुमच्या गरजांशी जुळणारा वैयक्तिक रोडमॅप तयार करता येतो. कृपया प्रत्येक प्रश्नाचे उत्तर प्रामाणिकपणे आणि काळजीपूर्वक द्या. उत्तर माहीत नसेल, तर अंदाज लावण्याऐवजी तसे सांगा. तुमची उत्तरे जितकी अचूक असतील, तितक्या अधिक उपयुक्त शिफारसी मिळू शकतात.',
            englishStyle: const TextStyle(
              color: Color(0xFFD0D1E2),
              fontSize: 13,
              height: 1.5,
            ),
            localizedStyle: const TextStyle(
              color: Color(0xFFBDB5E0),
              fontSize: 13,
              height: 1.5,
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(
              t('Not now', 'अभी नहीं', 'आत्ता नाही'),
              style: const TextStyle(color: Color(0xFFBDB5E0)),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(11),
              ),
            ),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(t('Continue', 'आगे बढ़ें', 'पुढे चला')),
          ),
        ],
      ),
    );

    return result == true;
  }

  Future<void> _restore() async {
    debugPrint('[ONBOARDING] Restore started');
    try {
      final profile = await ref
          .read(profileRepositoryProvider)
          .getOnboardingState();
      debugPrint('[ONBOARDING] Profile loaded: ${profile != null}');
      if (!mounted) return;
      if (profile != null) {
        final raw = profile['onboarding_data'];
        final data = raw is Map
            ? OnboardingData.fromJson(Map<String, dynamic>.from(raw))
            : const OnboardingData();
        ref.read(onboardingProvider.notifier).restore(data);
        final preferredRootLanguage =
            profile['preferred_language'] ?? profile['preferredLanguage'];
        final languageValue =
            preferredRootLanguage ??
            (data.preferredLanguage.trim().isEmpty
                ? profile['language']
                : null);
        if (languageValue is String) _languageOverride = languageValue;
        _restorePayload(data.careerOnboardingPayload);
        final saved = profile['onboarding_step'];
        final savedPage = saved is int ? saved : int.tryParse('$saved') ?? 0;
        _page = _category == null
            ? 0
            : math.max(0, math.min(groupCount, savedPage)).toInt();
      } else {
        _restorePayload(ref.read(onboardingProvider).careerOnboardingPayload);
        _page = _category == null ? 0 : (_categoryProgress[_category!] ?? 1);
      }
      _applyRouteLanguage();
      setState(() => _loading = false);
      _scheduleEntryIntro();
    } catch (_) {
      if (!mounted) return;

      _applyRouteLanguage();
      setState(() => _loading = false);

      _message(
        t(
          'Could not restore progress. You can continue from the beginning.',
          'प्रगति वापस नहीं लाई जा सकी। आप शुरुआत से जारी रख सकते हैं।',
          'प्रगती पुनर्संचयित करता आली नाही. तुम्ही सुरुवातीपासून सुरू करू शकता.',
        ),
      );

      _scheduleEntryIntro();
    }
  }

  void _restorePayload(Map<String, dynamic> p) {
    _answers.clear();
    _categoryProgress.clear();
    final c = p['category'];
    if (c is int && c >= 0 && c < _careerCategories.length) _category = c;
    if (p['answers'] is Map) {
      (p['answers'] as Map).forEach((k, v) {
        if (v != null) _answers[k.toString()] = v.toString();
      });
    }
    if (p['progress'] is Map) {
      (p['progress'] as Map).forEach((k, v) {
        final ci = int.tryParse('$k'), pg = v is int ? v : int.tryParse('$v');
        if (ci != null &&
            pg != null &&
            ci >= 0 &&
            ci < _careerCategories.length)
          _categoryProgress[ci] = pg.clamp(1, groupCount).toInt();
      });
    }
  }

  Map<String, dynamic> _payload() {
    // Keep all six categories' answers. Every item is keyed by a stable field
    // id (c1_g1_q1 ... c6_g5_q4), and readable response rows accompany answers
    // so the generation backend can understand the user's exact questions.
    final responses = <Map<String, String>>[];
    for (var c = 0; c < _careerCategories.length; c++) {
      for (var g = 0; g < _careerCategories[c].groups.length; g++) {
        final questions = _careerCategories[c].groups[g];
        for (var q = 0; q < questions.length; q++) {
          final answer = _answers[_key(c, g, q)];
          if (answer != null && answer.trim().isNotEmpty) {
            responses.add({
              'category': _careerCategories[c].en,
              'group': _careerCategories[c].titlesEn[g],
              'question': questions[q].en,
              'answer': answer.trim(),
              'field': _key(c, g, q),
            });
          }
        }
      }
    }

    return <String, dynamic>{
      'version': 2,
      'language': _language,
      'category': _category,
      'selectedCategoryTitle': _category == null
          ? null
          : _careerCategories[_category!].en,
      'answers': Map<String, String>.from(_answers),
      'responses': responses,
      'progress': _categoryProgress.map(
        (key, value) => MapEntry(key.toString(), value),
      ),
    };
  }

  void _sync() {
    ref
        .read(onboardingProvider.notifier)
        .update(
          ref
              .read(onboardingProvider)
              .copyWithCareerOnboardingPayload(_payload()),
        );
  }

  Future<void> _persist(int pageToSave) {
    _autosave?.cancel();
    if (_category != null && pageToSave > 0)
      _categoryProgress[_category!] = pageToSave.clamp(1, groupCount).toInt();
    _sync();
    final done = Completer<void>();
    _saveQueue = _saveQueue.catchError((Object _) {}).then((_) async {
      try {
        await ref.read(onboardingProvider.notifier).saveStep(pageToSave);
        done.complete();
      } catch (e, st) {
        done.completeError(e, st);
      }
    });
    return done.future;
  }

  void _autosaveSoon() {
    _autosave?.cancel();
    _autosave = Timer(const Duration(milliseconds: 650), () {
      _persist(_page).catchError((_) {});
    });
  }

  void _chooseCategory(int c) {
    setState(() => _category = c);
    _sync();
    _autosaveSoon();
  }

  void _answerChanged(int c, int g, int q, String value) {
    _answers[_key(c, g, q)] = value;
    _sync();
    _autosaveSoon();
  }

  Future<void> _move(int page) async {
    if (!mounted) return;
    setState(() => _page = page.clamp(0, groupCount).toInt());
    await _pages.animateToPage(
      _page,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
    );
  }

  Future<void> _next() async {
    if (_page == 0) {
      if (_category == null) {
        _message(
          t(
            'Choose the option that best matches your situation.',
            'अपनी स्थिति के अनुसार एक विकल्प चुनें।',
            'तुमच्या परिस्थितीला योग्य पर्याय निवडा.',
          ),
        );
        return;
      }
      final shouldContinue = await _showQuestionnaireIntro();

      if (!shouldContinue || !mounted) return;

      setState(() => _saving = true);
      setState(() => _saving = true);
      try {
        final target = _categoryProgress[_category!] ?? 1;
        await _persist(target);
        if (mounted) await _move(target);
      } catch (_) {
        if (mounted)
          _message(
            t(
              'Could not save your choice. Please try again.',
              'चयन सेव नहीं हुआ। कृपया फिर से प्रयास करें।',
              'निवड जतन झाली नाही. कृपया पुन्हा प्रयत्न करा.',
            ),
          );
      } finally {
        if (mounted) setState(() => _saving = false);
      }
      return;
    }

    final c = _category!;
    final group = _page - 1;
    final qs = _careerCategories[c].groups[group];
    for (var i = 0; i < qs.length; i++) {
      if ((_answers[_key(c, group, i)] ?? '').trim().isEmpty) {
        _message(
          t(
            'Please answer all four questions. You can write “None” or “Not sure” when appropriate.',
            'कृपया चारों प्रश्नों के उत्तर दें। जहाँ उचित हो, “कोई नहीं” या “पता नहीं” लिखें।',
            'कृपया चारही प्रश्नांची उत्तरे द्या. लागू असल्यास “काही नाही” किंवा “माहित नाही” लिहा.',
          ),
        );
        return;
      }
    }

    setState(() => _saving = true);
    try {
      final next = _page + 1;
      await _persist(next);
      if (!mounted) return;
      if (_page < groupCount) {
        await _move(next);
      } else {
        await ref.read(profileRepositoryProvider).completeOnboarding();
        await ref.read(sessionProvider.notifier).refresh();
        if (mounted) context.go('/journey-generation');
      }
    } catch (_) {
      if (mounted)
        _message(
          t(
            'Could not save progress. Please try again.',
            'प्रगति सेव नहीं हुई। कृपया फिर से प्रयास करें।',
            'प्रगती जतन झाली नाही. कृपया पुन्हा प्रयत्न करा.',
          ),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _back() async {
    if (_saving) return;
    if (_page == 0) {
      context.goNamed(
        RouteNames.languageSelection,
        queryParameters: {'changeLanguage': 'true'},
      );
      return;
    }
    if (_page > 1) {
      final target = _page - 1;
      try {
        await _persist(target);
      } catch (_) {}
      if (mounted) await _move(target);
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF15162D),
        title: Text(
          t(
            'Return to career options?',
            'करियर विकल्पों पर लौटें?',
            'करिअर पर्यायांकडे परत जायचे?',
          ),
          style: const TextStyle(color: Colors.white),
        ),
        content: Text(
          t(
            'You’ll return to the six options and can choose another path. Your answers are saved, so you can return to this questionnaire later.',
            'आप छह विकल्पों पर लौटकर दूसरा रास्ता चुन सकते हैं। आपके उत्तर सेव रहेंगे और आप बाद में इस प्रश्नावली पर लौट सकते हैं।',
            'तुम सहा पर्यायांकडे परत जाऊन दुसरा मार्ग निवडू शकता. तुमची उत्तरे जतन राहतील आणि नंतर या प्रश्नावलीत परत येऊ शकता.',
          ),
          style: const TextStyle(color: Color(0xFFC8C9D8), height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(t('Stay here', 'यहीं रहें', 'इथेच रहा')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: accent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(
              t(
                'Choose another option',
                'दूसरा विकल्प चुनें',
                'दुसरा पर्याय निवडा',
              ),
            ),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await _persist(0);
      } catch (_) {}
      await _move(0);
    }
  }

  void _message(String text) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(text), behavior: SnackBarBehavior.floating),
  );

  @override
  Widget build(BuildContext context) {
    ref.watch(
      onboardingProvider,
    ); // Preferred language is set on the previous screen.
    if (_loading)
      return const Scaffold(
        backgroundColor: bg,
        body: Center(child: CircularProgressIndicator(color: accent)),
      );
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop) _back();
      },
      child: Scaffold(
        backgroundColor: bg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          child: Column(
            children: [
              _top(),
              Expanded(
                child: PageView(
                  controller: _pages,
                  physics: const NeverScrollableScrollPhysics(),
                  children: [
                    _categoryPicker(),
                    for (var g = 0; g < groupCount; g++) _questionGroup(g),
                  ],
                ),
              ),
              _bottom(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _top() {
    final progress = _page == 0 ? 0.0 : _page / groupCount;
    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 0),
      child: Column(
        children: [
          Row(
            children: [
              InkWell(
                onTap: _saving ? null : _back,
                borderRadius: BorderRadius.circular(24),
                child: Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: surface,
                    shape: BoxShape.circle,
                    border: Border.all(color: const Color(0xFF292A46)),
                  ),
                  child: IconButton(
                    onPressed: _back,
                    icon: const Icon(Icons.chevron_left_rounded),
                    color: Colors.white,
                    iconSize: 20,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                    tooltip: t('Back', 'वापस', 'मागे'),
                  ),
                ),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  _page == 0
                      ? t(
                          'Choose your starting point',
                          'अपनी शुरुआत चुनें',
                          'तुमची सुरुवात निवडा',
                        )
                      : t(
                          'Your career profile',
                          'आपकी करियर प्रोफ़ाइल',
                          'तुमची करिअर प्रोफाइल',
                        ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text(
                _page == 0
                    ? t('6 OPTIONS', '6 विकल्प', '6 पर्याय')
                    : t(
                        'GROUP $_page OF $groupCount',
                        'समूह $_page / $groupCount',
                        'गट $_page / $groupCount',
                      ),
                style: const TextStyle(
                  color: Color(0xFFB6A4FF),
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 3,
              backgroundColor: const Color(0xFF1A1B30),
              valueColor: const AlwaysStoppedAnimation(accent),
            ),
          ),
        ],
      ),
    );
  }

  Widget _categoryPicker() => SingleChildScrollView(
    physics: const BouncingScrollPhysics(),
    padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _bilingualText(
          'What would you like help with right now?',
          'आप अभी किस चीज़ में मदद चाहते हैं?',
          'तुम्हाला सध्या कोणत्या गोष्टीसाठी मदत हवी आहे?',
          englishStyle: const TextStyle(
            color: Colors.white,
            fontSize: 23,
            height: 1.12,
            fontWeight: FontWeight.w700,
            letterSpacing: -0.4,
          ),
          localizedStyle: const TextStyle(
            color: Color(0xFFD4CCF7),
            fontSize: 19,
            height: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 6),
        _bilingualText(
          'Choose the option that best matches your situation. We’ll ask relevant questions and use your answers to recommend career paths and guide your next steps.',
          'अपनी स्थिति के अनुसार सबसे सही विकल्प चुनें। आपके उत्तरों के आधार पर हम करियर विकल्प सुझाएँगे और आगे का मार्ग दिखाएँगे।',
          'तुमच्या परिस्थितीला योग्य पर्याय निवडा. तुमच्या उत्तरांवरून आम्ही करिअर पर्याय सुचवू आणि पुढील दिशा देऊ.',
          englishStyle: const TextStyle(
            color: Color(0xFF9A9BB5),
            fontSize: 11.5,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 11),
        for (var i = 0; i < _careerCategories.length; i++) _categoryCard(i),
      ],
    ),
  );

  Widget _categoryCard(int i) {
    final c = _careerCategories[i];
    final selected = _category == i;
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Material(
        color: selected ? const Color(0xFF211A43) : surface,
        borderRadius: BorderRadius.circular(13),
        child: InkWell(
          borderRadius: BorderRadius.circular(13),
          onTap: () => _chooseCategory(i),
          child: Container(
            padding: const EdgeInsets.fromLTRB(10, 8, 9, 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: selected ? accent : const Color(0xFF292A46),
                width: selected ? 1.3 : 1,
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: selected
                        ? accent.withOpacity(.2)
                        : const Color(0xFF1C1D37),
                    borderRadius: BorderRadius.circular(9),
                  ),
                  child: Icon(
                    c.icon,
                    color: selected
                        ? const Color(0xFFD7CAFF)
                        : const Color(0xFFAAA0DA),
                    size: 18,
                  ),
                ),
                const SizedBox(width: 9),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _bilingualText(
                        c.en,
                        c.hi,
                        c.mr,
                        englishStyle: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          height: 1.22,
                        ),
                        localizedStyle: const TextStyle(
                          color: Color(0xFFD4CCF7),
                          fontWeight: FontWeight.w500,
                          fontSize: 11,
                          height: 1.22,
                        ),
                      ),
                      const SizedBox(height: 3),
                      _bilingualText(
                        c.descEn,
                        c.descHi,
                        c.descMr,
                        englishStyle: const TextStyle(
                          color: Color(0xFFB0B1C5),
                          fontSize: 10,
                          height: 1.26,
                        ),
                        localizedStyle: const TextStyle(
                          color: Color(0xFF9697B6),
                          fontSize: 9.5,
                          height: 1.26,
                        ),
                      ),
                      const SizedBox(height: 2),
                      _bilingualText(
                        c.exampleEn,
                        c.exampleHi,
                        c.exampleMr,
                        englishStyle: const TextStyle(
                          color: Color(0xFF827F9E),
                          fontSize: 9,
                          height: 1.2,
                          fontStyle: FontStyle.italic,
                        ),
                        localizedStyle: const TextStyle(
                          color: Color(0xFF827F9E),
                          fontSize: 8.5,
                          height: 1.2,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 5),
                Icon(
                  selected
                      ? Icons.radio_button_checked_rounded
                      : Icons.radio_button_off_rounded,
                  color: selected
                      ? const Color(0xFFBBA8FF)
                      : const Color(0xFF62647F),
                  size: 18,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _questionGroup(int groupIndex) {
    final ci = _category ?? 0;
    final category = _careerCategories[ci];
    final questions = category.groups[groupIndex];
    return SingleChildScrollView(
      key: ValueKey('group-${ci + 1}-${groupIndex + 1}'),
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(18, 14, 18, 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _bilingualText(
            category.en,
            category.hi,
            category.mr,
            englishStyle: const TextStyle(
              color: Color(0xFFB7A7FF),
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: .35,
            ),
            localizedStyle: const TextStyle(
              color: Color(0xFF9B8BE0),
              fontSize: 9.5,
              fontWeight: FontWeight.w600,
              letterSpacing: .2,
            ),
          ),
          const SizedBox(height: 4),
          _bilingualText(
            category.titlesEn[groupIndex],
            category.titlesHi[groupIndex],
            category.titlesMr[groupIndex],
            englishStyle: const TextStyle(
              color: Colors.white,
              fontSize: 21,
              height: 1.14,
              fontWeight: FontWeight.w700,
              letterSpacing: -.3,
            ),
            localizedStyle: const TextStyle(
              color: Color(0xFFE0DAF8),
              fontSize: 18,
              height: 1.16,
              fontWeight: FontWeight.w600,
              letterSpacing: -.2,
            ),
          ),
          const SizedBox(height: 4),
          _bilingualText(
            category.purposesEn[groupIndex],
            category.purposesHi[groupIndex],
            category.purposesMr[groupIndex],
            englishStyle: const TextStyle(
              color: Color(0xFF9A9BB5),
              fontSize: 11,
              height: 1.32,
            ),
            localizedStyle: const TextStyle(
              color: Color(0xFF8E90AC),
              fontSize: 10.5,
              height: 1.32,
            ),
          ),
          const SizedBox(height: 11),
          for (var q = 0; q < questions.length; q++)
            _questionInput(ci, groupIndex, q, questions[q]),
        ],
      ),
    );
  }

  Widget _questionInput(int ci, int gi, int qi, CareerQuestion q) {
    final k = _key(ci, gi, qi);
    final answer = _answers[k] ?? '';
    return Container(
      margin: const EdgeInsets.only(bottom: 9),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 7),
      decoration: BoxDecoration(
        color: surface,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF292A46)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 21,
                height: 21,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0xFF29204D),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '${qi + 1}',
                  style: const TextStyle(
                    color: Color(0xFFD0C2FF),
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(width: 7),
              Expanded(
                child: _bilingualText(
                  q.en,
                  q.hi,
                  q.mr,
                  englishStyle: const TextStyle(
                    color: Color(0xFFE4E3EF),
                    fontSize: 11.2,
                    height: 1.28,
                    fontWeight: FontWeight.w600,
                  ),
                  localizedStyle: const TextStyle(
                    color: Color(0xFFB9B4D4),
                    fontSize: 10.8,
                    height: 1.3,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          TextFormField(
            key: ValueKey(k),
            initialValue: answer,
            onChanged: (v) => _answerChanged(ci, gi, qi, v),
            minLines: 1,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              height: 1.25,
            ),
            decoration: InputDecoration(
              hintText: t(
                'Type your answer… (“None” or “Not sure” is okay)',
                'अपना उत्तर लिखें… (“कोई नहीं” या “पता नहीं” लिख सकते हैं)',
                'तुमचे उत्तर लिहा… (“काही नाही” किंवा “माहित नाही” चालेल)',
              ),
              hintStyle: const TextStyle(
                color: Color(0xFF777991),
                fontSize: 10,
              ),
              filled: true,
              fillColor: const Color(0xFF090A19),
              isDense: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 9,
                vertical: 8,
              ),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: Color(0xFF24253E)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(9),
                borderSide: const BorderSide(color: accent, width: 1.1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _bottom() {
    final categoryPage = _page == 0, lastGroup = _page == groupCount;
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 7, 18, 11),
      color: bg,
      child: Row(
        children: [
          if (!categoryPage)
            OutlinedButton.icon(
              onPressed: _saving ? null : _back,
              icon: const Icon(Icons.arrow_back_rounded, size: 15),
              label: Text(t('Back', 'वापस', 'मागे')),
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFFD2D0E4),
                side: const BorderSide(color: Color(0xFF30314C)),
                minimumSize: const Size(84, 46),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          if (!categoryPage) const SizedBox(width: 8),
          Expanded(
            child: SizedBox(
              height: 47,
              child: ElevatedButton(
                onPressed: _saving ? null : _next,
                style: ElevatedButton.styleFrom(
                  backgroundColor: accent,
                  foregroundColor: Colors.white,
                  disabledBackgroundColor: accent.withOpacity(.45),
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Flexible(
                            child: Text(
                              categoryPage
                                  ? t(
                                      'Continue to questions',
                                      'प्रश्नों पर जाएँ',
                                      'प्रश्नांकडे चला',
                                    )
                                  : lastGroup
                                  ? t(
                                      'Finish and find my career options',
                                      'पूरा करें और विकल्प देखें',
                                      'पूर्ण करा आणि पर्याय पाहा',
                                    )
                                  : t(
                                      'Save and continue',
                                      'सेव करें और आगे बढ़ें',
                                      'जतन करा आणि पुढे जा',
                                    ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Icon(Icons.arrow_forward_rounded, size: 16),
                        ],
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CareerQuestion {
  final String en, hi, mr;
  const CareerQuestion(this.en, this.hi, this.mr);
  String text(String lang) => lang == 'hi'
      ? hi
      : lang == 'mr'
      ? mr
      : en;
}

class CareerQuestionCategory {
  final String en,
      hi,
      mr,
      descEn,
      descHi,
      descMr,
      exampleEn,
      exampleHi,
      exampleMr;
  final IconData icon;
  final List<List<CareerQuestion>> groups;
  final List<String> titlesEn,
      titlesHi,
      titlesMr,
      purposesEn,
      purposesHi,
      purposesMr;
  const CareerQuestionCategory({
    required this.en,
    required this.hi,
    required this.mr,
    required this.descEn,
    required this.descHi,
    required this.descMr,
    required this.exampleEn,
    required this.exampleHi,
    required this.exampleMr,
    required this.icon,
    required this.groups,
    required this.titlesEn,
    required this.titlesHi,
    required this.titlesMr,
    required this.purposesEn,
    required this.purposesHi,
    required this.purposesMr,
  });
  String title(String l) => l == 'hi'
      ? hi
      : l == 'mr'
      ? mr
      : en;
  String description(String l) => l == 'hi'
      ? descHi
      : l == 'mr'
      ? descMr
      : descEn;
  String example(String l) => l == 'hi'
      ? exampleHi
      : l == 'mr'
      ? exampleMr
      : exampleEn;
  String groupTitle(int i, String l) => l == 'hi'
      ? titlesHi[i]
      : l == 'mr'
      ? titlesMr[i]
      : titlesEn[i];
  String groupPurpose(int i, String l) => l == 'hi'
      ? purposesHi[i]
      : l == 'mr'
      ? purposesMr[i]
      : purposesEn[i];
}

const List<CareerQuestionCategory> _careerCategories = [
  CareerQuestionCategory(
    en: '1. Discover Career Options That Suit Me',
    hi: '1. मेरे लिए सही करियर विकल्प खोजें',
    mr: '1. माझ्यासाठी योग्य करिअर पर्याय शोधा',
    descEn:
        'Unsure which career to choose? Explore options matched to your interests, strengths, education, goals, and circumstances.',
    descHi:
        'कौन-सा करियर चुनें, यह तय नहीं? रुचियों, खूबियों, शिक्षा, लक्ष्यों और परिस्थितियों के अनुसार विकल्प खोजें।',
    descMr:
        'कोणते करिअर निवडावे हे ठरलेले नाही? आवडी, ताकदी, शिक्षण, उद्दिष्टे आणि परिस्थितीनुसार पर्याय शोधा.',
    exampleEn:
        'Example: choosing between technology, business, healthcare, government jobs, or another field.',
    exampleHi:
        'उदाहरण: तकनीक, व्यवसाय, स्वास्थ्य सेवा, सरकारी नौकरी या अन्य क्षेत्र में से चुनना।',
    exampleMr:
        'उदाहरण: तंत्रज्ञान, व्यवसाय, आरोग्यसेवा, सरकारी नोकरी किंवा दुसरे क्षेत्र निवडणे.',
    icon: Icons.explore_rounded,
    titlesEn: [
      'Background and Current Situation',
      'Interests and Work Preferences',
      'Skills, Strengths, and Learning',
      'Career Goals and Priorities',
      'Practical Constraints and Readiness',
    ],
    titlesHi: [
      'शिक्षा और वर्तमान स्थिति',
      'रुचियाँ और काम की पसंद',
      'कौशल, खूबियाँ और सीखना',
      'करियर लक्ष्य और प्राथमिकताएँ',
      'व्यावहारिक सीमाएँ और तैयारी',
    ],
    titlesMr: [
      'शिक्षण आणि सध्याची स्थिती',
      'आवडी आणि कामाच्या पसंती',
      'कौशल्ये, ताकदी आणि शिकणे',
      'करिअरची उद्दिष्टे आणि प्राधान्ये',
      'व्यावहारिक मर्यादा आणि तयारी',
    ],
    purposesEn: [
      'Understand your starting point.',
      'Find work you may enjoy.',
      'Identify abilities and areas to grow.',
      'Match options to your ambitions.',
      'Keep recommendations realistic.',
    ],
    purposesHi: [
      'आपकी शुरुआती स्थिति समझें।',
      'पसंद आने वाले काम पहचानें।',
      'क्षमताएँ और सुधार के क्षेत्र जानें।',
      'विकल्पों को आपके लक्ष्यों से जोड़ें।',
      'व्यावहारिक विकल्प चुनें।',
    ],
    purposesMr: [
      'सुरुवातीची स्थिती समजून घ्या.',
      'आवडू शकणारी कामे शोधा.',
      'कौशल्ये आणि सुधारणा क्षेत्रे ओळखा.',
      'पर्याय उद्दिष्टांशी जुळवा.',
      'व्यवहार्य पर्याय निवडा.',
    ],
    groups: [
      [
        CareerQuestion(
          'What is your highest education, what did you study, and do you have relevant qualifications or certifications?',
          'तुमची सर्वोच्च शैक्षणिक पात्रता काय आहे, काय शिकलात आणि संबंधित प्रमाणपत्रे आहेत का?',
          'तुमची सर्वोच्च शैक्षणिक पात्रता काय आहे, काय शिकलात आणि संबंधित प्रमाणपत्रे आहेत का?',
        ),
        CareerQuestion(
          'What is your current situation: studying, employed, self-employed, unemployed, or seeking your first job? If not working, write “None”.',
          'आपकी स्थिति क्या है—पढ़ाई, नौकरी, स्वरोज़गार, बेरोज़गारी या पहली नौकरी की तलाश? काम नहीं करते तो “कोई नहीं” लिखें।',
          'सध्याची स्थिती काय आहे—शिक्षण, नोकरी, स्वयंरोजगार, बेरोजगार की पहिली नोकरी शोधत आहात? काम नसल्यास “काही नाही” लिहा.',
        ),
        CareerQuestion(
          'What work experience, internships, projects, volunteering, or practical experience do you have? If none, write “None”.',
          'नौकरी, इंटर्नशिप, परियोजना, स्वयंसेवा या व्यावहारिक अनुभव क्या है? नहीं है तो “कोई नहीं” लिखें।',
          'नोकरी, इंटर्नशिप, प्रकल्प, स्वयंसेवा किंवा प्रत्यक्ष अनुभव कोणता आहे? नसल्यास “काही नाही” लिहा.',
        ),
        CareerQuestion(
          'Which country and city do you live in, and are you willing to relocate or work remotely?',
          'आप किस देश और शहर में रहते हैं? क्या आप स्थान बदलने या दूर से काम करने को तैयार हैं?',
          'तुम्ही कोणत्या देशात आणि शहरात राहता? स्थलांतर किंवा दूरस्थ कामाची तयारी आहे का?',
        ),
      ],
      [
        CareerQuestion(
          'What subjects, topics, or activities genuinely interest you, and what do you enjoy learning about?',
          'किन विषयों या गतिविधियों में आपकी वास्तविक रुचि है, और क्या सीखना पसंद है?',
          'कोणते विषय किंवा उपक्रम तुम्हाला खरोखर आवडतात आणि काय शिकायला आवडते?',
        ),
        CareerQuestion(
          'Which activities do you enjoy most? Choose up to three: problem-solving, people, data, design, technology, hands-on work, organizing, teaching/helping, sales, or research.',
          'सबसे पसंदीदा तीन चुनें: समस्या हल करना, लोगों से काम, डेटा, डिज़ाइन, तकनीक, व्यावहारिक काम, आयोजन, पढ़ाना/मदद, बिक्री या शोध।',
          'आवडणारे जास्तीत जास्त तीन निवडा: समस्या सोडवणे, लोकांसोबत काम, डेटा, डिझाइन, तंत्रज्ञान, प्रत्यक्ष काम, नियोजन, शिकवणे/मदत, विक्री किंवा संशोधन.',
        ),
        CareerQuestion(
          'Do you prefer working independently, with a team, with customers, or leading others? Briefly explain.',
          'आप स्वतंत्र काम, टीम, ग्राहकों या नेतृत्व में से क्या पसंद करते हैं? संक्षेप में बताएँ।',
          'स्वतंत्र काम, संघासोबत, ग्राहकांशी किंवा नेतृत्व करणे—काय पसंत आहे? थोडक्यात सांगा.',
        ),
        CareerQuestion(
          'What work environment do you prefer: remote, office, hybrid, outdoor/fieldwork, or hands-on work?',
          'कैसा कार्य वातावरण पसंद है—रिमोट, कार्यालय, हाइब्रिड, बाहरी/फील्ड या व्यावहारिक काम?',
          'कोणते कामाचे वातावरण आवडते—दूरस्थ, कार्यालय, संमिश्र, बाहेरील/क्षेत्रीय की प्रत्यक्ष काम?',
        ),
      ],
      [
        CareerQuestion(
          'What skills do you have: technical, digital, communication, analytical, creative, practical, or language skills? Mention your English level.',
          'आपके पास कौन-से तकनीकी, डिजिटल, संवाद, विश्लेषण, रचनात्मक, व्यावहारिक या भाषा कौशल हैं? अंग्रेज़ी स्तर भी बताएँ।',
          'तुमच्याकडे कोणती तांत्रिक, डिजिटल, संवाद, विश्लेषणात्मक, सर्जनशील, व्यावहारिक किंवा भाषिक कौशल्ये आहेत? इंग्रजीची पातळी सांगा.',
        ),
        CareerQuestion(
          'What are you naturally good at? Give a real example that demonstrates your strengths.',
          'आप स्वाभाविक रूप से किसमें अच्छे हैं? अपनी क्षमता दिखाने वाला वास्तविक उदाहरण दें।',
          'तुम्ही नैसर्गिकपणे कशात चांगले आहात? ताकद दाखवणारे खरे उदाहरण द्या.',
        ),
        CareerQuestion(
          'Which software, digital tools, equipment, or other tools can you use confidently? If none, write “None”.',
          'कौन-से सॉफ्टवेयर, डिजिटल टूल या उपकरण आत्मविश्वास से इस्तेमाल कर सकते हैं? नहीं हैं तो “कोई नहीं” लिखें।',
          'कोणते सॉफ्टवेअर, डिजिटल साधने किंवा उपकरणे आत्मविश्वासाने वापरता? नसल्यास “काही नाही” लिहा.',
        ),
        CareerQuestion(
          'What are you currently learning, and which new skills would you like to develop?',
          'अभी क्या सीख रहे हैं और कौन-से नए कौशल विकसित करना चाहते हैं?',
          'सध्या काय शिकत आहात आणि कोणती नवीन कौशल्ये विकसित करू इच्छिता?',
        ),
      ],
      [
        CareerQuestion(
          'What are your main career goals for the next 1–3 years?',
          'अगले 1–3 वर्षों के लिए आपके मुख्य करियर लक्ष्य क्या हैं?',
          'पुढील 1–3 वर्षांसाठी तुमची मुख्य करिअर उद्दिष्टे कोणती?',
        ),
        CareerQuestion(
          'Which three career factors matter most: income, security, flexibility, creativity, helping people, growth, independence, prestige, or balance?',
          'करियर में तीन सबसे महत्वपूर्ण बातें चुनें: आय, सुरक्षा, लचीलापन, रचनात्मकता, मदद, विकास, स्वतंत्रता, प्रतिष्ठा या संतुलन।',
          'करिअरमधील तीन महत्त्वाच्या गोष्टी निवडा: उत्पन्न, स्थिरता, लवचिकता, सर्जनशीलता, मदत, प्रगती, स्वातंत्र्य, प्रतिष्ठा किंवा संतुलन.',
        ),
        CareerQuestion(
          'Which careers have you considered, and which would you prefer to avoid? Why?',
          'किन करियर पर विचार किया है और किनसे बचना चाहेंगे? क्यों?',
          'कोणत्या करिअरचा विचार केला आहे आणि कोणती टाळाल? का?',
        ),
        CareerQuestion(
          'What minimum monthly income do you need, and how soon must you start earning?',
          'न्यूनतम मासिक आय कितनी चाहिए और कितनी जल्दी कमाना शुरू करना है?',
          'किमान मासिक उत्पन्न किती हवे आणि किती लवकर कमाई सुरू करायची आहे?',
        ),
      ],
      [
        CareerQuestion(
          'How many hours per week can you dedicate to career learning, training, or job searching?',
          'करियर सीखने, प्रशिक्षण या नौकरी खोजने को प्रति सप्ताह कितने घंटे दे सकते हैं?',
          'करिअर शिकणे, प्रशिक्षण किंवा नोकरी शोधण्यासाठी आठवड्याला किती तास देऊ शकता?',
        ),
        CareerQuestion(
          'Are you willing to study or learn new skills? How much time and money can you invest?',
          'क्या आगे पढ़ाई या नए कौशल सीखने को तैयार हैं? कितना समय और पैसा दे सकते हैं?',
          'पुढील शिक्षण किंवा नवीन कौशल्ये शिकण्याची तयारी आहे का? किती वेळ आणि पैसा देऊ शकता?',
        ),
        CareerQuestion(
          'What resources do you have for work or learning: phone, computer, internet, transport, workspace, or equipment?',
          'काम या सीखने के लिए फोन, कंप्यूटर, इंटरनेट, परिवहन, जगह या उपकरण में से क्या उपलब्ध है?',
          'काम किंवा शिकण्यासाठी फोन, संगणक, इंटरनेट, प्रवास, जागा किंवा उपकरणांपैकी काय उपलब्ध आहे?',
        ),
        CareerQuestion(
          'What practical limitations or non-negotiable requirements should AI consider when recommending careers?',
          'करियर सुझाते समय AI को किन व्यावहारिक सीमाओं या अनिवार्य शर्तों का ध्यान रखना चाहिए?',
          'करिअर सुचवताना AI ने कोणत्या व्यावहारिक मर्यादा किंवा अनिवार्य अटी लक्षात घ्याव्यात?',
        ),
      ],
    ],
  ),
  CareerQuestionCategory(
    en: '2. Explore a Specific Field or Career',
    hi: '2. किसी खास क्षेत्र या करियर को समझें',
    mr: '2. विशिष्ट क्षेत्र किंवा करिअर समजून घ्या',
    descEn:
        'You have a field in mind and want to compare roles or specializations to find a good fit.',
    descHi:
        'आपके मन में एक क्षेत्र है और आप उसमें अलग-अलग भूमिकाओं की तुलना करना चाहते हैं।',
    descMr:
        'तुमच्या मनात एखादे क्षेत्र आहे आणि त्यातील विविध भूमिकांची तुलना करायची आहे.',
    exampleEn:
        'Examples: AI, software, data, cybersecurity, engineering, healthcare, finance, design, or research.',
    exampleHi:
        'उदाहरण: AI, सॉफ्टवेयर, डेटा, साइबर सुरक्षा, इंजीनियरिंग, स्वास्थ्य, वित्त, डिज़ाइन या शोध।',
    exampleMr:
        'उदाहरणे: AI, सॉफ्टवेअर, डेटा, सायबर सुरक्षा, अभियांत्रिकी, आरोग्यसेवा, वित्त, डिझाइन किंवा संशोधन.',
    icon: Icons.travel_explore_rounded,
    titlesEn: [
      'Understand Your Target Field',
      'Education and Experience',
      'Interests and Preferred Work',
      'Strengths and Development',
      'Career Priorities and Practical Fit',
    ],
    titlesHi: [
      'अपना क्षेत्र समझें',
      'शिक्षा और अनुभव',
      'रुचियाँ और पसंदीदा काम',
      'क्षमताएँ और विकास',
      'करियर प्राथमिकताएँ और व्यावहारिक उपयुक्तता',
    ],
    titlesMr: [
      'निवडलेले क्षेत्र समजून घ्या',
      'शिक्षण आणि अनुभव',
      'आवडी आणि पसंतीचे काम',
      'ताकदी आणि विकास',
      'करिअर प्राधान्ये आणि व्यवहार्यता',
    ],
    purposesEn: [
      'Clarify the field and your questions.',
      'Understand your starting point.',
      'Identify tasks and settings you prefer.',
      'Compare strengths with role requirements.',
      'Find realistic roles that match your priorities.',
    ],
    purposesHi: [
      'क्षेत्र और अपेक्षाएँ स्पष्ट करें।',
      'अपनी शुरुआती स्थिति समझें।',
      'पसंदीदा काम और माहौल पहचानें।',
      'खूबियों की भूमिका की ज़रूरतों से तुलना करें।',
      'प्राथमिकताओं के अनुसार व्यावहारिक भूमिकाएँ खोजें।',
    ],
    purposesMr: [
      'क्षेत्र आणि अपेक्षा स्पष्ट करा.',
      'सुरुवातीची स्थिती समजून घ्या.',
      'पसंतीचे काम आणि वातावरण शोधा.',
      'ताकदींची भूमिकेच्या गरजांशी तुलना करा.',
      'प्राधान्यांनुसार व्यवहार्य भूमिका शोधा.',
    ],
    groups: [
      [
        CareerQuestion(
          'Which field or career area would you like to explore?',
          'आप किस क्षेत्र या करियर को समझना चाहते हैं?',
          'तुम्हाला कोणते क्षेत्र किंवा करिअर समजून घ्यायचे आहे?',
        ),
        CareerQuestion(
          'Which roles or specializations have you considered? If unsure, write “Not sure”.',
          'किन भूमिकाओं या विशेषज्ञताओं पर विचार किया है? तय नहीं हैं तो “पता नहीं” लिखें।',
          'कोणत्या भूमिका किंवा विशेषज्ञता विचारात घेतल्या आहेत? खात्री नसल्यास “माहित नाही” लिहा.',
        ),
        CareerQuestion(
          'What attracts you to this field?',
          'इस क्षेत्र की ओर क्या आकर्षित करता है?',
          'या क्षेत्राकडे तुम्हाला काय आकर्षित करते?',
        ),
        CareerQuestion(
          'What do you most want to discover: roles, specializations, qualifications, or opportunities?',
          'सबसे अधिक क्या जानना चाहते हैं—भूमिकाएँ, विशेषज्ञता, योग्यता या अवसर?',
          'काय जाणून घ्यायचे आहे—भूमिका, विशेषज्ञता, पात्रता की संधी?',
        ),
      ],
      [
        CareerQuestion(
          'What is your current situation: student, graduate, employed, unemployed, or changing careers?',
          'आपकी स्थिति क्या है—विद्यार्थी, स्नातक, नौकरी में, बेरोज़गार या करियर बदल रहे हैं?',
          'तुमची स्थिती काय आहे—विद्यार्थी, पदवीधर, नोकरीत, बेरोजगार की करिअर बदलत आहात?',
        ),
        CareerQuestion(
          'What is your highest qualification, what did you study, and which relevant certificates or licenses do you hold?',
          'उच्चतम योग्यता, पढ़ाई और संबंधित प्रमाणपत्र या लाइसेंस बताएँ।',
          'सर्वोच्च पात्रता, शिक्षण आणि संबंधित प्रमाणपत्रे किंवा परवाने सांगा.',
        ),
        CareerQuestion(
          'What do you already know about this field, and how would you rate your level?',
          'इस क्षेत्र के बारे में क्या जानते हैं और अपना स्तर कैसे बताएँगे?',
          'या क्षेत्राबद्दल काय माहिती आहे आणि तुमची पातळी काय आहे?',
        ),
        CareerQuestion(
          'What relevant jobs, internships, projects, research, or training have you completed? If none, write “None”.',
          'इस क्षेत्र में नौकरी, इंटर्नशिप, परियोजना, शोध या प्रशिक्षण क्या किया है? नहीं किया तो “कोई नहीं” लिखें।',
          'या क्षेत्रात नोकरी, इंटर्नशिप, प्रकल्प, संशोधन किंवा प्रशिक्षण केले आहे का? नसेल तर “काही नाही” लिहा.',
        ),
      ],
      [
        CareerQuestion(
          'Which tasks in this field would you find most interesting?',
          'इस क्षेत्र में कौन-से काम सबसे रोचक लगेंगे?',
          'या क्षेत्रातील कोणती कामे सर्वाधिक रोचक वाटतील?',
        ),
        CareerQuestion(
          'Which tasks would you avoid or enjoy least, and why?',
          'किन कामों से बचना चाहेंगे या कौन-से काम कम पसंद हैं, और क्यों?',
          'कोणती कामे टाळाल किंवा कमी आवडतात, आणि का?',
        ),
        CareerQuestion(
          'Would you rather work with people, data, ideas/research, technology/tools, physical materials, or a mix?',
          'लोगों, डेटा, शोध-विचार, तकनीक, भौतिक सामग्री या इनके मिश्रण में से क्या पसंद है?',
          'लोक, डेटा, संशोधन-विचार, तंत्रज्ञान, भौतिक वस्तू की मिश्रण—काय पसंत आहे?',
        ),
        CareerQuestion(
          'Which setting do you prefer: office, remote, lab, clinic, research site, industrial site, fieldwork, or workshop?',
          'कौन-सा कार्यस्थल पसंद है—ऑफिस, रिमोट, लैब, क्लिनिक, शोध केंद्र, औद्योगिक स्थल, फील्ड या वर्कशॉप?',
          'कोणते कामाचे ठिकाण पसंत आहे—कार्यालय, दूरस्थ, प्रयोगशाळा, क्लिनिक, संशोधन केंद्र, उद्योग, क्षेत्रीय काम की कार्यशाळा?',
        ),
      ],
      [
        CareerQuestion(
          'Which skills do you already have that could be useful in this field? Include your level.',
          'इस क्षेत्र में उपयोगी आपके कौन-से कौशल हैं? स्तर भी बताएँ।',
          'या क्षेत्रात उपयोगी कोणती कौशल्ये आहेत? पातळीही सांगा.',
        ),
        CareerQuestion(
          'What are your strongest abilities? Give a real example.',
          'आपकी सबसे मजबूत क्षमताएँ क्या हैं? वास्तविक उदाहरण दें।',
          'तुमच्या सर्वात मजबूत क्षमता कोणत्या? खरे उदाहरण द्या.',
        ),
        CareerQuestion(
          'Which subjects or problems do you learn or solve easily, and which are difficult?',
          'कौन-से विषय या समस्याएँ आसानी से सीखते/हल करते हैं, और कौन-सी कठिन हैं?',
          'कोणते विषय किंवा प्रश्न सहज शिकता/सोडवता आणि कोणते कठीण वाटतात?',
        ),
        CareerQuestion(
          'Which new skills, technologies, subjects, or specializations would you like to learn?',
          'कौन-से नए कौशल, तकनीक, विषय या विशेषज्ञता सीखना चाहेंगे?',
          'कोणती नवीन कौशल्ये, तंत्रज्ञान, विषय किंवा विशेषज्ञता शिकायला आवडेल?',
        ),
      ],
      [
        CareerQuestion(
          'What are your three most important priorities in a future role?',
          'भविष्य की भूमिका में तीन सबसे महत्वपूर्ण प्राथमिकताएँ क्या हैं?',
          'भविष्यातील भूमिकेत तीन सर्वात महत्त्वाची प्राधान्ये कोणती?',
        ),
        CareerQuestion(
          'What income do you expect, and how soon would you like to start earning?',
          'आय की अपेक्षा क्या है और कितनी जल्दी कमाना शुरू करना चाहेंगे?',
          'उत्पन्नाची अपेक्षा काय आहे आणि किती लवकर कमाई सुरू करायची आहे?',
        ),
        CareerQuestion(
          'How much time and money can you invest in education, training, or certificates?',
          'शिक्षा, प्रशिक्षण या प्रमाणपत्रों में कितना समय और पैसा लगा सकते हैं?',
          'शिक्षण, प्रशिक्षण किंवा प्रमाणपत्रांसाठी किती वेळ आणि पैसा देऊ शकता?',
        ),
        CareerQuestion(
          'What constraints must be considered: location, hours, family responsibilities, budget, or accessibility?',
          'स्थान, समय, परिवार, बजट या सुलभता जैसी किन सीमाओं का ध्यान रखें?',
          'ठिकाण, वेळ, कुटुंब, बजेट किंवा सुलभतेसारख्या कोणत्या मर्यादा लक्षात घ्याव्यात?',
        ),
      ],
    ],
  ),
  CareerQuestionCategory(
    en: '3. Prepare for a Specific Exam to Reach My Career Goal',
    hi: '3. करियर लक्ष्य के लिए किसी परीक्षा की तैयारी करें',
    mr: '3. करिअरच्या ध्येयासाठी विशिष्ट परीक्षेची तयारी करा',
    descEn:
        'You have a target competitive, entrance, or recruitment exam and want to assess the career path it leads to.',
    descHi:
        'आपने प्रतियोगी, प्रवेश या भर्ती परीक्षा चुनी है और उससे जुड़े करियर मार्ग को समझना चाहते हैं।',
    descMr:
        'तुम्ही स्पर्धा, प्रवेश किंवा भरती परीक्षा निवडली आहे आणि त्यातून मिळणारा करिअर मार्ग समजून घ्यायचा आहे.',
    exampleEn:
        'Examples: UPSC/MPSC, SSC/banking, NEET, JEE, GATE, CUET, CLAT, or another exam.',
    exampleHi:
        'उदाहरण: UPSC/MPSC, SSC/बैंकिंग, NEET, JEE, GATE, CUET, CLAT या अन्य परीक्षा।',
    exampleMr:
        'उदाहरणे: UPSC/MPSC, SSC/बँकिंग, NEET, JEE, GATE, CUET, CLAT किंवा इतर परीक्षा.',
    icon: Icons.menu_book_rounded,
    titlesEn: [
      'Target Exam and Career Goal',
      'Education and Eligibility',
      'Preparation and Current Progress',
      'Strengths, Interests, and Alternatives',
      'Priorities and Practical Constraints',
    ],
    titlesHi: [
      'लक्षित परीक्षा और करियर लक्ष्य',
      'शिक्षा और पात्रता',
      'तैयारी और वर्तमान प्रगति',
      'क्षमताएँ, रुचियाँ और विकल्प',
      'प्राथमिकताएँ और व्यावहारिक सीमाएँ',
    ],
    titlesMr: [
      'लक्षित परीक्षा आणि करिअर ध्येय',
      'शिक्षण आणि पात्रता',
      'तयारी आणि सध्याची प्रगती',
      'ताकदी, आवडी आणि पर्याय',
      'प्राधान्ये आणि व्यावहारिक मर्यादा',
    ],
    purposesEn: [
      'Clarify the exam and intended outcome.',
      'Understand education and eligibility.',
      'Understand preparation stage and evidence.',
      'Check career fit and related pathways.',
      'Account for real-world priorities and constraints.',
    ],
    purposesHi: [
      'परीक्षा और इच्छित परिणाम स्पष्ट करें।',
      'शिक्षा और पात्रता समझें।',
      'तैयारी का चरण और प्रदर्शन जानें।',
      'करियर उपयुक्तता और संबंधित रास्ते देखें।',
      'वास्तविक प्राथमिकताओं और सीमाओं का ध्यान रखें।',
    ],
    purposesMr: [
      'परीक्षा आणि अपेक्षित परिणाम स्पष्ट करा.',
      'शिक्षण आणि पात्रता समजून घ्या.',
      'तयारीचा टप्पा आणि कामगिरी समजून घ्या.',
      'करिअरची जुळवणूक आणि संबंधित मार्ग पाहा.',
      'वास्तविक प्राधान्ये आणि मर्यादा लक्षात घ्या.',
    ],
    groups: [
      [
        CareerQuestion(
          'Which competitive, entrance, or recruitment exam are you preparing for or planning to take? Name your primary exam if there are several.',
          'किस प्रतियोगी, प्रवेश या भर्ती परीक्षा की तैयारी कर रहे हैं या देने की योजना है? कई हों तो मुख्य परीक्षा बताएँ।',
          'कोणत्या स्पर्धा, प्रवेश किंवा भरती परीक्षेची तयारी करत आहात किंवा देणार आहात? अनेक असल्यास मुख्य परीक्षा सांगा.',
        ),
        CareerQuestion(
          'What career, job, course, or outcome do you want through this exam? If unsure, write “Not sure”.',
          'इस परीक्षा से कौन-सा करियर, नौकरी, कोर्स या परिणाम चाहते हैं? तय नहीं है तो “पता नहीं” लिखें।',
          'या परीक्षेद्वारे कोणते करिअर, नोकरी, अभ्यासक्रम किंवा परिणाम हवे आहेत? खात्री नसल्यास “माहित नाही” लिहा.',
        ),
        CareerQuestion(
          'Why do you want this exam and the career associated with it?',
          'यह परीक्षा और इससे जुड़ा करियर क्यों चाहते हैं?',
          'ही परीक्षा आणि संबंधित करिअर का हवे आहे?',
        ),
        CareerQuestion(
          'Are you focused only on this exam, or open to related exams and other routes to similar opportunities?',
          'क्या केवल इसी परीक्षा पर ध्यान है, या समान अवसरों वाली अन्य परीक्षाओं और रास्तों के लिए भी तैयार हैं?',
          'फक्त याच परीक्षेवर लक्ष आहे का, की समान संधी देणाऱ्या इतर परीक्षा व मार्गांसाठीही तयार आहात?',
        ),
      ],
      [
        CareerQuestion(
          'What is your current educational stage: school, undergraduate, final year, graduate, postgraduate, or working?',
          'आपकी शैक्षिक स्थिति क्या है—स्कूल, स्नातक, अंतिम वर्ष, स्नातक पूरा, स्नातकोत्तर या नौकरी?',
          'तुमची शैक्षणिक स्थिती काय आहे—शाळा, पदवी शिक्षण, अंतिम वर्ष, पदवीधर, पदव्युत्तर की नोकरी?',
        ),
        CareerQuestion(
          'What is your highest completed qualification, and what subjects, stream, degree, or specialization did you study?',
          'पूरी की गई उच्चतम योग्यता क्या है, और कौन-से विषय, स्ट्रीम या डिग्री पढ़ी है?',
          'पूर्ण झालेली सर्वोच्च पात्रता काय आहे आणि कोणते विषय, शाखा किंवा पदवी शिकला आहात?',
        ),
        CareerQuestion(
          'What will your age be on the exam’s relevant eligibility date, if an age limit applies? If unsure, write “Not sure”.',
          'आयु सीमा लागू हो तो निर्धारित पात्रता तारीख पर आपकी उम्र कितनी होगी? पता न हो तो “पता नहीं” लिखें।',
          'वयोमर्यादा लागू असल्यास पात्रतेच्या तारखेला तुमचे वय किती असेल? माहीत नसल्यास “माहित नाही” लिहा.',
        ),
        CareerQuestion(
          'Have you checked qualification, subject, age, attempt, nationality/residency, and physical or medical requirements? What still needs checking?',
          'शैक्षणिक, विषय, आयु, प्रयास, राष्ट्रीयता/निवास और शारीरिक/चिकित्सा शर्तें जाँची हैं? क्या जाँचना बाकी है?',
          'शैक्षणिक, विषय, वय, प्रयत्न, नागरिकत्व/रहिवास आणि शारीरिक/वैद्यकीय अटी तपासल्या आहेत का? अजून काय तपासायचे आहे?',
        ),
      ],
      [
        CareerQuestion(
          'Which exam year, cycle, or attempt are you targeting?',
          'किस परीक्षा वर्ष, चक्र या प्रयास को लक्ष्य बना रहे हैं?',
          'कोणते परीक्षा वर्ष, चक्र किंवा प्रयत्न लक्ष्य करत आहात?',
        ),
        CareerQuestion(
          'How long have you prepared, and which methods do you use: self-study, coaching, courses, books, or practice platforms?',
          'कब से तैयारी कर रहे हैं और कौन-से तरीके अपनाते हैं—स्व-अध्ययन, कोचिंग, कोर्स, किताबें या अभ्यास मंच?',
          'किती काळापासून तयारी करता आणि कोणत्या पद्धती वापरता—स्व-अभ्यास, कोचिंग, अभ्यासक्रम, पुस्तके किंवा सराव मंच?',
        ),
        CareerQuestion(
          'What stage are you at: syllabus exploration, fundamentals, syllabus completion, revision, mock tests, interview, or awaiting results?',
          'कौन-सा चरण है—सिलेबस देखना, मूलभूत अध्ययन, सिलेबस पूरा, दोहराव, मॉक टेस्ट, साक्षात्कार या परिणाम की प्रतीक्षा?',
          'कोणता टप्पा आहे—अभ्यासक्रम पाहणे, मूलभूत अभ्यास, अभ्यासक्रम पूर्ण, उजळणी, मॉक टेस्ट, मुलाखत की निकालाची प्रतीक्षा?',
        ),
        CareerQuestion(
          'What shows your current level: mock scores, subject marks, percentile, previous results, rank, or other assessments? If none, write “Not taken yet”.',
          'वर्तमान स्तर क्या दर्शाता है—मॉक अंक, विषय अंक, पर्सेंटाइल, पुराने परिणाम, रैंक या अन्य मूल्यांकन? नहीं दिया तो “अभी नहीं” लिखें।',
          'सध्याची पातळी काय दर्शवते—मॉक गुण, विषयवार गुण, पर्सेंटाइल, मागील निकाल, रँक किंवा इतर मूल्यांकन? नसेल तर “अजून दिले नाही” लिहा.',
        ),
      ],
      [
        CareerQuestion(
          'Which exam subjects or sections are strongest and weakest for you? Use your study or test performance where possible.',
          'कौन-से विषय या भाग मजबूत और कमजोर हैं? संभव हो तो पढ़ाई या टेस्ट के प्रदर्शन से बताएँ।',
          'कोणते विषय किंवा विभाग मजबूत आणि कमकुवत आहेत? शक्य असल्यास अभ्यास किंवा चाचणीच्या कामगिरीवरून सांगा.',
        ),
        CareerQuestion(
          'Which aspects of the intended career appeal to you most?',
          'इच्छित करियर के कौन-से पहलू सबसे अधिक आकर्षित करते हैं?',
          'इच्छित करिअरमधील कोणत्या गोष्टी सर्वाधिक आकर्षित करतात?',
        ),
        CareerQuestion(
          'Which aspects of the career or working conditions might not suit you?',
          'करियर या कार्य स्थितियों के कौन-से पहलू आपके अनुकूल नहीं हो सकते?',
          'करिअर किंवा कामाच्या परिस्थितीतील कोणत्या गोष्टी तुमच्यासाठी योग्य नसतील?',
        ),
        CareerQuestion(
          'Which related careers, courses, specializations, or exams would you consider if they fit your abilities and circumstances?',
          'क्षमता और परिस्थितियों के अनुकूल होने पर किन संबंधित करियर, कोर्स, विशेषज्ञताओं या परीक्षाओं पर विचार करेंगे?',
          'क्षमता आणि परिस्थितीला योग्य असल्यास कोणती संबंधित करिअर, अभ्यासक्रम, विशेषज्ञता किंवा परीक्षा विचारात घ्याल?',
        ),
      ],
      [
        CareerQuestion(
          'What are your top three career priorities: security, income, public service, growth, prestige, work-life balance, independence, or specialization?',
          'करियर की तीन प्रमुख प्राथमिकताएँ चुनें: सुरक्षा, आय, जनसेवा, विकास, प्रतिष्ठा, संतुलन, स्वतंत्रता या विशेषज्ञता।',
          'करिअरमधील तीन प्रमुख प्राधान्ये निवडा: स्थिरता, उत्पन्न, जनसेवा, प्रगती, प्रतिष्ठा, संतुलन, स्वातंत्र्य किंवा विशेषज्ञता.',
        ),
        CareerQuestion(
          'Where would you prefer to study or work, and can you relocate or accept postings in different locations?',
          'कहाँ पढ़ना या काम करना पसंद करेंगे? क्या स्थान बदलना या अलग-अलग पोस्टिंग स्वीकारना संभव है?',
          'कुठे शिकायला किंवा काम करायला आवडेल? स्थलांतर किंवा वेगवेगळ्या ठिकाणी नियुक्ती स्वीकारू शकता का?',
        ),
        CareerQuestion(
          'How soon do you need to earn, and can you prepare without regular income until your target date?',
          'कितनी जल्दी कमाना ज़रूरी है, और क्या लक्ष्य तारीख तक नियमित आय के बिना तैयारी कर सकते हैं?',
          'किती लवकर कमाई आवश्यक आहे आणि लक्ष्य तारखेपर्यंत नियमित उत्पन्नाशिवाय तयारी करू शकता का?',
        ),
        CareerQuestion(
          'What practical constraints or non-negotiable requirements should be considered for your target career and related options?',
          'लक्षित करियर और संबंधित विकल्पों के लिए किन व्यावहारिक सीमाओं या अनिवार्य शर्तों का ध्यान रखें?',
          'लक्षित करिअर आणि संबंधित पर्यायांसाठी कोणत्या व्यावहारिक मर्यादा किंवा अनिवार्य अटी लक्षात घ्याव्यात?',
        ),
      ],
    ],
  ),
  CareerQuestionCategory(
    en: '4. Find Backup Career Options While Preparing for an Exam',
    hi: '4. परीक्षा की तैयारी के साथ वैकल्पिक करियर खोजें',
    mr: '4. परीक्षेच्या तयारीसोबत पर्यायी करिअर शोधा',
    descEn:
        'Find alternatives that fit your qualifications, interests, study schedule, and financial needs without assuming you should abandon your exam goal.',
    descHi:
        'परीक्षा लक्ष्य छोड़े बिना योग्यता, रुचि, समय और आर्थिक ज़रूरतों के अनुसार विकल्प खोजें।',
    descMr:
        'परीक्षेचे ध्येय सोडल्याचे गृहीत न धरता पात्रता, आवडी, वेळ आणि आर्थिक गरजांनुसार पर्याय शोधा.',
    exampleEn:
        'Example: I’m preparing for UPSC/MPSC or NEET, but also want a backup job or career path.',
    exampleHi:
        'उदाहरण: UPSC/MPSC या NEET की तैयारी के साथ नौकरी या वैकल्पिक करियर भी चाहिए।',
    exampleMr:
        'उदाहरण: UPSC/MPSC किंवा NEET च्या तयारीसोबत नोकरी किंवा पर्यायी करिअर हवे आहे.',
    icon: Icons.alt_route_rounded,
    titlesEn: [
      'Exam Goal and Backup Needs',
      'Education and Experience',
      'Skills, Interests, and Career Fit',
      'Time and Practical Circumstances',
      'Backup Priorities and Readiness',
    ],
    titlesHi: [
      'परीक्षा लक्ष्य और बैकअप की ज़रूरत',
      'शिक्षा और अनुभव',
      'कौशल, रुचियाँ और करियर उपयुक्तता',
      'समय और व्यावहारिक परिस्थितियाँ',
      'बैकअप प्राथमिकताएँ और तैयारी',
    ],
    titlesMr: [
      'परीक्षेचे ध्येय आणि पर्यायाची गरज',
      'शिक्षण आणि अनुभव',
      'कौशल्ये, आवडी आणि करिअर जुळवणूक',
      'वेळ आणि व्यावहारिक परिस्थिती',
      'पर्यायाची प्राधान्ये आणि तयारी',
    ],
    purposesEn: [
      'Understand why and when a backup is needed.',
      'Identify options supported by your background.',
      'Match alternatives to skills and interests.',
      'Respect study time and financial realities.',
      'Select a realistic backup strategy.',
    ],
    purposesHi: [
      'जानें कि बैकअप क्यों और कब चाहिए।',
      'पृष्ठभूमि के अनुसार विकल्प खोजें।',
      'विकल्पों को कौशल और रुचियों से मिलाएँ।',
      'पढ़ाई का समय और आर्थिक स्थिति ध्यान में रखें।',
      'व्यावहारिक रणनीति चुनें।',
    ],
    purposesMr: [
      'पर्याय का आणि कधी हवा ते समजून घ्या.',
      'पार्श्वभूमीनुसार पर्याय शोधा.',
      'पर्याय कौशल्ये आणि आवडींशी जुळवा.',
      'अभ्यासाचा वेळ आणि आर्थिक स्थिती लक्षात घ्या.',
      'व्यवहार्य रणनीती निवडा.',
    ],
    groups: [
      [
        CareerQuestion(
          'Which exam are you preparing for, and what career or outcome do you want from it?',
          'किस परीक्षा की तैयारी कर रहे हैं, और उससे क्या करियर या परिणाम चाहते हैं?',
          'कोणत्या परीक्षेची तयारी करता आणि त्यातून कोणते करिअर किंवा परिणाम हवे आहेत?',
        ),
        CareerQuestion(
          'Why do you want a backup: income while studying, financial pressure, alternatives if plans change, or exploring interests?',
          'बैकअप क्यों चाहते हैं—पढ़ाई के साथ आय, आर्थिक दबाव, योजना बदलने पर विकल्प या रुचियाँ तलाशना?',
          'पर्याय का हवा—अभ्यासासोबत उत्पन्न, आर्थिक दबाव, योजना बदलल्यास पर्याय की आवडी शोधणे?',
        ),
        CareerQuestion(
          'What preparation stage are you at, and when is your next target exam or attempt?',
          'तैयारी का कौन-सा चरण है और अगली लक्षित परीक्षा या प्रयास कब है?',
          'तयारीचा टप्पा कोणता आणि पुढील लक्षित परीक्षा किंवा प्रयत्न कधी आहे?',
        ),
        CareerQuestion(
          'When should the backup become useful: now, within 3–6 months, 6–12 months, after your next attempt, or longer term?',
          'बैकअप कब उपयोगी होना चाहिए—अभी, 3–6 महीने, 6–12 महीने, अगले प्रयास के बाद या लंबे समय में?',
          'पर्याय कधी उपयोगी हवा—आत्ता, 3–6 महिन्यांत, 6–12 महिन्यांत, पुढील प्रयत्नानंतर की दीर्घकाळात?',
        ),
      ],
      [
        CareerQuestion(
          'What is your current educational stage, highest completed qualification, and field of study?',
          'वर्तमान शैक्षिक स्थिति, पूरी की गई उच्चतम योग्यता और अध्ययन क्षेत्र क्या है?',
          'सध्याची शैक्षणिक स्थिती, पूर्ण पात्रता आणि अभ्यासाचे क्षेत्र काय आहे?',
        ),
        CareerQuestion(
          'Which subjects, professional qualifications, certificates, licences, or formal training have you completed?',
          'कौन-से विषय, पेशेवर योग्यता, प्रमाणपत्र, लाइसेंस या प्रशिक्षण पूरा किया है?',
          'कोणते विषय, व्यावसायिक पात्रता, प्रमाणपत्रे, परवाने किंवा प्रशिक्षण पूर्ण केले आहे?',
        ),
        CareerQuestion(
          'What work, internship, project, tutoring, volunteer, freelance, or business experience do you have?',
          'नौकरी, इंटर्नशिप, परियोजना, ट्यूशन, स्वयंसेवा, फ्रीलांसिंग या व्यवसाय का अनुभव क्या है?',
          'नोकरी, इंटर्नशिप, प्रकल्प, शिकवणी, स्वयंसेवा, फ्रीलान्सिंग किंवा व्यवसायाचा अनुभव कोणता आहे?',
        ),
        CareerQuestion(
          'Are you completing any qualification soon? Include its expected completion date.',
          'क्या कोई योग्यता जल्द पूरी होगी? संभावित तारीख बताएँ।',
          'लवकर कोणती पात्रता पूर्ण होणार आहे का? अपेक्षित तारीख सांगा.',
        ),
      ],
      [
        CareerQuestion(
          'Which skills do you have: academic, technical, digital, communication, analytical, teaching, or practical skills?',
          'कौन-से कौशल हैं—शैक्षणिक, तकनीकी, डिजिटल, संवाद, विश्लेषण, पढ़ाने या व्यावहारिक कौशल?',
          'कोणती कौशल्ये आहेत—शैक्षणिक, तांत्रिक, डिजिटल, संवाद, विश्लेषण, शिकवणे किंवा व्यावहारिक?',
        ),
        CareerQuestion(
          'What are you good at? Give a real example from study, work, a project, or an activity.',
          'आप किस काम में अच्छे हैं? पढ़ाई, नौकरी, परियोजना या गतिविधि का वास्तविक उदाहरण दें।',
          'तुम्ही कशात चांगले आहात? अभ्यास, नोकरी, प्रकल्प किंवा उपक्रमाचे खरे उदाहरण द्या.',
        ),
        CareerQuestion(
          'What work might you enjoy alongside or apart from exam preparation, and what work would you avoid?',
          'परीक्षा तैयारी के साथ या अलग कौन-सा काम पसंद करेंगे, और कौन-सा टालेंगे?',
          'परीक्षेच्या तयारीसोबत किंवा वेगळे कोणते काम आवडेल आणि कोणते टाळाल?',
        ),
        CareerQuestion(
          'Which skills or interests would you be willing to develop into employment or income?',
          'कौन-से कौशल या रुचियों को नौकरी या आय में बदलना चाहेंगे?',
          'कोणती कौशल्ये किंवा आवडी रोजगार किंवा उत्पन्नात रूपांतरित करायला तयार आहात?',
        ),
      ],
      [
        CareerQuestion(
          'How many hours per day or week can you spend on backup work or training without seriously disrupting exam preparation?',
          'परीक्षा तैयारी प्रभावित किए बिना बैकअप काम या प्रशिक्षण को कितना समय दे सकते हैं?',
          'परीक्षेच्या तयारीवर मोठा परिणाम न होता पर्यायी काम किंवा प्रशिक्षणासाठी किती वेळ देऊ शकता?',
        ),
        CareerQuestion(
          'How much monthly income do you need, and how soon must you start earning?',
          'मासिक आय कितनी चाहिए, और कितनी जल्दी कमाना शुरू करना है?',
          'मासिक उत्पन्न किती हवे आणि किती लवकर कमाई सुरू करावी लागेल?',
        ),
        CareerQuestion(
          'Where can you work: from home, online, locally, in a specific city, or elsewhere? Can you relocate?',
          'कहाँ काम कर सकते हैं—घर से, ऑनलाइन, स्थानीय, किसी शहर या अन्य जगह? क्या स्थान बदल सकते हैं?',
          'कुठे काम करू शकता—घरून, ऑनलाइन, स्थानिक, विशिष्ट शहरात किंवा अन्यत्र? स्थलांतर शक्य आहे का?',
        ),
        CareerQuestion(
          'What resources are available: phone, computer, internet, transport, workspace, software, or equipment?',
          'कौन-से साधन उपलब्ध हैं—फोन, कंप्यूटर, इंटरनेट, परिवहन, जगह, सॉफ्टवेयर या उपकरण?',
          'कोणती साधने उपलब्ध आहेत—फोन, संगणक, इंटरनेट, प्रवास, जागा, सॉफ्टवेअर किंवा उपकरणे?',
        ),
      ],
      [
        CareerQuestion(
          'Which backup would help most: part-time, freelancing, remote work, full-time job, long-term career, or another course?',
          'कौन-सा बैकअप उपयोगी होगा—पार्ट-टाइम, फ्रीलांसिंग, रिमोट, पूर्णकालिक नौकरी, दीर्घकालिक करियर या कोर्स?',
          'कोणता पर्याय उपयुक्त—अर्धवेळ, फ्रीलान्सिंग, दूरस्थ, पूर्णवेळ नोकरी, दीर्घकालीन करिअर की अभ्यासक्रम?',
        ),
        CareerQuestion(
          'What are your top three priorities: quick income, flexible hours, low training cost, stability, growth, remote work, or experience?',
          'तीन प्राथमिकताएँ चुनें: जल्दी आय, लचीला समय, कम प्रशिक्षण खर्च, स्थिरता, विकास, रिमोट काम या अनुभव।',
          'तीन प्राधान्ये निवडा: लवकर उत्पन्न, लवचिक वेळ, कमी प्रशिक्षण खर्च, स्थिरता, प्रगती, दूरस्थ काम किंवा अनुभव.',
        ),
        CareerQuestion(
          'How much time and money can you invest in skills or certificates? Do you need to earn using existing skills immediately?',
          'कौशल या प्रमाणपत्रों में कितना समय और पैसा लगा सकते हैं? क्या मौजूदा कौशल से तुरंत कमाना है?',
          'कौशल्ये किंवा प्रमाणपत्रांसाठी किती वेळ आणि पैसा देऊ शकता? सध्याच्या कौशल्यांनी त्वरित कमाई करावी लागेल का?',
        ),
        CareerQuestion(
          'Which jobs, industries, conditions, or other limits should AI avoid when recommending backup options?',
          'बैकअप विकल्प सुझाते समय AI को किन नौकरियों, उद्योगों, परिस्थितियों या सीमाओं से बचना चाहिए?',
          'पर्याय सुचवताना AI ने कोणत्या नोकऱ्या, उद्योग, अटी किंवा मर्यादा टाळाव्यात?',
        ),
      ],
    ],
  ),
  CareerQuestionCategory(
    en: '5. Grow and Advance in My Current Career',
    hi: '5. अपने मौजूदा करियर में आगे बढ़ें',
    mr: '5. सध्याच्या करिअरमध्ये प्रगती करा',
    descEn:
        'Progress in your current field through promotion, specialization, leadership, better pay, or professional development.',
    descHi:
        'पदोन्नति, विशेषज्ञता, नेतृत्व, बेहतर वेतन या विकास के ज़रिए मौजूदा क्षेत्र में आगे बढ़ें।',
    descMr:
        'पदोन्नती, विशेषज्ञता, नेतृत्व, चांगले वेतन किंवा विकासाद्वारे सध्याच्या क्षेत्रात पुढे जा.',
    exampleEn:
        'Example: I want a senior role, management, an AI specialization, or better pay.',
    exampleHi: 'उदाहरण: वरिष्ठ पद, प्रबंधन, AI विशेषज्ञता या बेहतर वेतन चाहिए।',
    exampleMr:
        'उदाहरण: वरिष्ठ पद, व्यवस्थापन, AI विशेषज्ञता किंवा चांगले वेतन हवे आहे.',
    icon: Icons.trending_up_rounded,
    titlesEn: [
      'Your Current Career',
      'Career Goals and Aspirations',
      'Skills, Performance, and Strengths',
      'Skill Gaps and Development',
      'Opportunities and Practical Constraints',
    ],
    titlesHi: [
      'आपका वर्तमान करियर',
      'करियर लक्ष्य और आकांक्षाएँ',
      'कौशल, प्रदर्शन और खूबियाँ',
      'कौशल की कमी और विकास',
      'अवसर और व्यावहारिक सीमाएँ',
    ],
    titlesMr: [
      'तुमचे सध्याचे करिअर',
      'करिअरची उद्दिष्टे आणि आकांक्षा',
      'कौशल्ये, कामगिरी आणि ताकदी',
      'कौशल्यातील उणिवा आणि विकास',
      'संधी आणि व्यावहारिक मर्यादा',
    ],
    purposesEn: [
      'Understand your current role.',
      'Define the next milestone.',
      'Identify demonstrated strengths.',
      'Find skills needed for the next step.',
      'Build a realistic advancement plan.',
    ],
    purposesHi: [
      'वर्तमान भूमिका समझें।',
      'अगला लक्ष्य तय करें।',
      'सिद्ध खूबियाँ पहचानें।',
      'अगले कदम के कौशल पहचानें।',
      'व्यावहारिक विकास योजना बनाएँ।',
    ],
    purposesMr: [
      'सध्याची भूमिका समजून घ्या.',
      'पुढील टप्पा ठरवा.',
      'सिद्ध ताकदी ओळखा.',
      'पुढील टप्प्यासाठी कौशल्ये शोधा.',
      'व्यवहार्य प्रगती योजना बनवा.',
    ],
    groups: [
      [
        CareerQuestion(
          'What is your current job title or role, industry, and type of organization?',
          'आपका वर्तमान पद, उद्योग और संस्था का प्रकार क्या है?',
          'तुमचे सध्याचे पद, उद्योग आणि संस्थेचा प्रकार काय आहे?',
        ),
        CareerQuestion(
          'How many years of experience do you have in this role and overall field?',
          'इस भूमिका और क्षेत्र में कितने वर्षों का अनुभव है?',
          'या भूमिका आणि क्षेत्रात किती वर्षांचा अनुभव आहे?',
        ),
        CareerQuestion(
          'What are your main responsibilities, and what does a typical working day look like?',
          'मुख्य ज़िम्मेदारियाँ क्या हैं और सामान्य कार्यदिवस कैसा होता है?',
          'मुख्य जबाबदाऱ्या कोणत्या आणि सामान्य कामाचा दिवस कसा असतो?',
        ),
        CareerQuestion(
          'What is your highest education, and which relevant professional certificates, licenses, or training do you hold?',
          'उच्चतम शिक्षा और संबंधित पेशेवर प्रमाणपत्र, लाइसेंस या प्रशिक्षण क्या हैं?',
          'सर्वोच्च शिक्षण आणि संबंधित व्यावसायिक प्रमाणपत्रे, परवाने किंवा प्रशिक्षण कोणते आहे?',
        ),
      ],
      [
        CareerQuestion(
          'What would you most like to achieve in your career over the next 1–3 years?',
          'अगले 1–3 वर्षों में करियर में क्या हासिल करना चाहेंगे?',
          'पुढील 1–3 वर्षांत करिअरमध्ये काय साध्य करायचे आहे?',
        ),
        CareerQuestion(
          'Which next job title, seniority level, or professional milestone would you like to reach?',
          'अगला कौन-सा पद, वरिष्ठता स्तर या पेशेवर लक्ष्य पाना चाहते हैं?',
          'पुढील कोणते पद, वरिष्ठता स्तर किंवा व्यावसायिक टप्पा गाठायचा आहे?',
        ),
        CareerQuestion(
          'What are your top three priorities: income, promotion, security, expertise, leadership, independence, recognition, meaning, or flexibility?',
          'तीन प्राथमिकताएँ चुनें: आय, पदोन्नति, सुरक्षा, विशेषज्ञता, नेतृत्व, स्वतंत्रता, पहचान, सार्थक काम या लचीलापन।',
          'तीन प्राधान्ये निवडा: उत्पन्न, पदोन्नती, स्थिरता, विशेषज्ञता, नेतृत्व, स्वातंत्र्य, मान्यता, अर्थपूर्ण काम किंवा लवचिकता.',
        ),
        CareerQuestion(
          'Why do you want to advance now, and what would meaningful progress look like?',
          'अभी आगे क्यों बढ़ना चाहते हैं, और सार्थक प्रगति कैसी होगी?',
          'आत्ताच प्रगती का करायची आहे आणि अर्थपूर्ण प्रगती कशी असेल?',
        ),
      ],
      [
        CareerQuestion(
          'Which professional, technical, analytical, communication, leadership, or other skills do you use at work?',
          'काम में कौन-से पेशेवर, तकनीकी, विश्लेषण, संवाद, नेतृत्व या अन्य कौशल इस्तेमाल करते हैं?',
          'कामात कोणती व्यावसायिक, तांत्रिक, विश्लेषणात्मक, संवाद, नेतृत्व किंवा इतर कौशल्ये वापरता?',
        ),
        CareerQuestion(
          'What are your most significant professional achievements? Include measurable results if possible.',
          'सबसे महत्वपूर्ण पेशेवर उपलब्धियाँ क्या हैं? संभव हो तो मापने योग्य परिणाम बताएँ।',
          'महत्त्वाच्या व्यावसायिक उपलब्धी कोणत्या? शक्य असल्यास मोजता येणारे परिणाम सांगा.',
        ),
        CareerQuestion(
          'What feedback have managers, colleagues, customers, mentors, or clients given about your strengths and improvement areas?',
          'प्रबंधक, सहकर्मी, ग्राहक या मार्गदर्शकों ने आपकी खूबियों और सुधार के क्षेत्रों पर क्या प्रतिक्रिया दी?',
          'व्यवस्थापक, सहकारी, ग्राहक किंवा मार्गदर्शकांनी ताकदी आणि सुधारणा क्षेत्रांबद्दल काय अभिप्राय दिला?',
        ),
        CareerQuestion(
          'Which tasks do you enjoy most, and which feel difficult, frustrating, or less fulfilling?',
          'कौन-से काम सबसे पसंद हैं, और कौन-से कठिन, परेशान करने वाले या कम संतोषजनक हैं?',
          'कोणती कामे सर्वाधिक आवडतात आणि कोणती कठीण, त्रासदायक किंवा कमी समाधानकारक वाटतात?',
        ),
      ],
      [
        CareerQuestion(
          'Which skills, qualifications, experience, or responsibilities do you need for the role you want next?',
          'अगली भूमिका के लिए किन कौशलों, योग्यताओं, अनुभव या ज़िम्मेदारियों की ज़रूरत है?',
          'पुढील भूमिकेसाठी कोणती कौशल्ये, पात्रता, अनुभव किंवा जबाबदाऱ्या आवश्यक आहेत?',
        ),
        CareerQuestion(
          'What challenges currently prevent your career progress?',
          'करियर प्रगति में कौन-सी चुनौतियाँ बाधा बनती हैं?',
          'करिअरच्या प्रगतीत कोणती आव्हाने अडथळा ठरतात?',
        ),
        CareerQuestion(
          'What professional development have you completed or are pursuing: courses, certificates, mentoring, projects, or leadership?',
          'कौन-सा पेशेवर विकास किया है या कर रहे हैं—कोर्स, प्रमाणपत्र, मार्गदर्शन, परियोजना या नेतृत्व?',
          'कोणता व्यावसायिक विकास केला आहे किंवा करत आहात—अभ्यासक्रम, प्रमाणपत्रे, मार्गदर्शन, प्रकल्प किंवा नेतृत्व?',
        ),
        CareerQuestion(
          'Which direction do you prefer: specialist, senior role, manager, new specialization, consultant, business owner, or unsure?',
          'कौन-सी दिशा पसंद है—विशेषज्ञ, वरिष्ठ पद, प्रबंधक, नई विशेषज्ञता, सलाहकार, व्यवसाय या तय नहीं?',
          'कोणती दिशा पसंत आहे—तज्ज्ञ, वरिष्ठ भूमिका, व्यवस्थापक, नवीन विशेषज्ञता, सल्लागार, व्यवसाय की अजून ठरलेले नाही?',
        ),
      ],
      [
        CareerQuestion(
          'What is your current monthly income range, desired income, and target timeline?',
          'वर्तमान मासिक आय सीमा, इच्छित आय और समयसीमा क्या है?',
          'सध्याची मासिक उत्पन्न श्रेणी, अपेक्षित उत्पन्न आणि कालमर्यादा काय आहे?',
        ),
        CareerQuestion(
          'How much time per week and budget can you invest in development while keeping current responsibilities?',
          'वर्तमान ज़िम्मेदारियों के साथ विकास के लिए प्रति सप्ताह कितना समय और बजट दे सकते हैं?',
          'सध्याच्या जबाबदाऱ्या सांभाळून विकासासाठी आठवड्याला किती वेळ आणि बजेट देऊ शकता?',
        ),
        CareerQuestion(
          'What opportunities exist: promotion, projects, mentoring, networking, changing employer, or further study?',
          'कौन-से अवसर हैं—पदोन्नति, परियोजना, मार्गदर्शन, नेटवर्किंग, नौकरी बदलना या आगे की पढ़ाई?',
          'कोणत्या संधी आहेत—पदोन्नती, प्रकल्प, मार्गदर्शन, नेटवर्किंग, नोकरी बदलणे किंवा पुढील शिक्षण?',
        ),
        CareerQuestion(
          'What constraints must be considered: family, hours, location, finances, accessibility, or work authorization?',
          'परिवार, समय, स्थान, पैसा, सुलभता या कार्य अनुमति जैसी किन सीमाओं का ध्यान रखें?',
          'कुटुंब, वेळ, ठिकाण, आर्थिक स्थिती, सुलभता किंवा कामाच्या परवानगीसारख्या कोणत्या मर्यादा लक्षात घ्याव्यात?',
        ),
      ],
    ],
  ),
  CareerQuestionCategory(
    en: '6. Change My Career or Move into a New Field',
    hi: '6. करियर बदलें या नए क्षेत्र में जाएँ',
    mr: '6. करिअर बदला किंवा नवीन क्षेत्रात जा',
    descEn:
        'You want a different professional direction. We’ll assess transferable skills, interests, qualifications, priorities, and transition constraints.',
    descHi:
        'आप नया पेशेवर रास्ता चाहते हैं। हम उपयोगी कौशल, रुचियों, योग्यता, प्राथमिकताओं और बदलाव की सीमाओं को समझेंगे।',
    descMr:
        'तुम्हाला वेगळी व्यावसायिक दिशा हवी आहे. उपयोगी कौशल्ये, आवडी, पात्रता, प्राधान्ये आणि बदलाच्या मर्यादा पाहू.',
    exampleEn:
        'Example: I work in sales and want data analytics, or I want to move from a non-technical role into technology.',
    exampleHi:
        'उदाहरण: बिक्री से डेटा विश्लेषण में या गैर-तकनीकी भूमिका से तकनीक में जाना।',
    exampleMr:
        'उदाहरण: विक्रीतून डेटा विश्लेषणात किंवा गैर-तांत्रिक भूमिकेतून तंत्रज्ञानात जायचे आहे.',
    icon: Icons.swap_horiz_rounded,
    titlesEn: [
      'Current Career and Reasons for Changing',
      'Desired Career and Future Priorities',
      'Transferable Skills and Strengths',
      'Career Gaps and Readiness to Learn',
      'Financial Needs and Transition Constraints',
    ],
    titlesHi: [
      'वर्तमान करियर और बदलाव के कारण',
      'इच्छित करियर और भविष्य की प्राथमिकताएँ',
      'काम आने वाले कौशल और खूबियाँ',
      'कौशल की कमी और सीखने की तैयारी',
      'आर्थिक ज़रूरतें और बदलाव की सीमाएँ',
    ],
    titlesMr: [
      'सध्याचे करिअर आणि बदलाची कारणे',
      'इच्छित करिअर आणि भविष्यातील प्राधान्ये',
      'उपयोगी कौशल्ये आणि ताकदी',
      'कौशल्यातील उणिवा आणि शिकण्याची तयारी',
      'आर्थिक गरजा आणि बदलाच्या मर्यादा',
    ],
    purposesEn: [
      'Understand your current situation and reasons to change.',
      'Define what you want instead.',
      'Find strengths that transfer to a new field.',
      'Identify learning needs and readiness.',
      'Choose a feasible transition approach.',
    ],
    purposesHi: [
      'वर्तमान स्थिति और बदलाव के कारण समझें।',
      'जानें कि आगे क्या चाहिए।',
      'नए क्षेत्र में काम आने वाली खूबियाँ पहचानें।',
      'सीखने की ज़रूरत और तैयारी जानें।',
      'व्यावहारिक बदलाव का रास्ता चुनें।',
    ],
    purposesMr: [
      'सध्याची स्थिती आणि बदलाची कारणे समजून घ्या.',
      'पुढे काय हवे ते ठरवा.',
      'नवीन क्षेत्रात उपयोगी ताकदी ओळखा.',
      'शिकण्याची गरज आणि तयारी समजून घ्या.',
      'व्यवहार्य बदलाचा मार्ग निवडा.',
    ],
    groups: [
      [
        CareerQuestion(
          'What is your current situation? If working, include your job title, field, and main responsibilities.',
          'वर्तमान स्थिति क्या है? नौकरी में हैं तो पद, क्षेत्र और मुख्य ज़िम्मेदारियाँ बताएँ।',
          'सध्याची स्थिती काय आहे? नोकरीत असल्यास पद, क्षेत्र आणि मुख्य जबाबदाऱ्या सांगा.',
        ),
        CareerQuestion(
          'How much experience do you have in your current or most recent career, and what are your main responsibilities or achievements?',
          'वर्तमान या पिछली नौकरी में कितना अनुभव है, और मुख्य ज़िम्मेदारियाँ या उपलब्धियाँ क्या हैं?',
          'सध्याच्या किंवा मागील करिअरमध्ये किती अनुभव आहे आणि मुख्य जबाबदाऱ्या किंवा उपलब्धी कोणत्या?',
        ),
        CareerQuestion(
          'Why change careers: interest, growth, income, security, burnout, changing priorities, or limited opportunities?',
          'करियर क्यों बदलना चाहते हैं—रुचि, विकास, आय, सुरक्षा, थकान, बदली प्राथमिकताएँ या सीमित अवसर?',
          'करिअर का बदलायचे—आवड, प्रगती, उत्पन्न, स्थिरता, थकवा, बदलती प्राधान्ये की मर्यादित संधी?',
        ),
        CareerQuestion(
          'What do you dislike about your current career, and what would you want to be different next time?',
          'वर्तमान करियर में क्या पसंद नहीं है, और अगले करियर में क्या अलग चाहिए?',
          'सध्याच्या करिअरमध्ये काय आवडत नाही आणि पुढील करिअरमध्ये काय वेगळे हवे?',
        ),
      ],
      [
        CareerQuestion(
          'Which fields or work types interest you for your next career? If unsure, write “Not sure”.',
          'अगले करियर के लिए किन क्षेत्रों या कामों में रुचि है? तय नहीं है तो “पता नहीं” लिखें।',
          'पुढील करिअरसाठी कोणती क्षेत्रे किंवा कामे आवडतात? खात्री नसल्यास “माहित नाही” लिहा.',
        ),
        CareerQuestion(
          'Which activities would you most enjoy in your next career?',
          'अगले करियर में कौन-सी गतिविधियाँ सबसे पसंद करेंगे?',
          'पुढील करिअरमध्ये कोणते उपक्रम सर्वाधिक आवडतील?',
        ),
        CareerQuestion(
          'What are your top three priorities: income, security, growth, work-life balance, flexibility, creativity, impact, independence, or remote work?',
          'तीन प्राथमिकताएँ चुनें: आय, सुरक्षा, विकास, संतुलन, लचीलापन, रचनात्मकता, प्रभाव, स्वतंत्रता या रिमोट काम।',
          'तीन प्राधान्ये निवडा: उत्पन्न, स्थिरता, प्रगती, काम-जीवन संतुलन, लवचिकता, सर्जनशीलता, प्रभाव, स्वातंत्र्य किंवा दूरस्थ काम.',
        ),
        CareerQuestion(
          'What would your ideal working life look like in 3–5 years, and what would success mean to you?',
          '3–5 वर्षों में आदर्श कामकाजी जीवन कैसा होगा, और सफलता का क्या अर्थ होगा?',
          '3–5 वर्षांत आदर्श कामाचे जीवन कसे असेल आणि यशाचा अर्थ काय असेल?',
        ),
      ],
      [
        CareerQuestion(
          'Which skills could transfer to another career? Include technical, analytical, communication, leadership, creative, or organizational skills.',
          'दूसरे करियर में कौन-से कौशल काम आ सकते हैं—तकनीकी, विश्लेषण, संवाद, नेतृत्व, रचनात्मक या संगठनात्मक?',
          'दुसऱ्या करिअरमध्ये कोणती कौशल्ये उपयोगी पडतील—तांत्रिक, विश्लेषण, संवाद, नेतृत्व, सर्जनशील किंवा संघटनात्मक?',
        ),
        CareerQuestion(
          'What are your strongest abilities? Give specific examples.',
          'आपकी सबसे मजबूत क्षमताएँ क्या हैं? ठोस उदाहरण दें।',
          'तुमच्या सर्वात मजबूत क्षमता कोणत्या? ठोस उदाहरणे द्या.',
        ),
        CareerQuestion(
          'Which degrees, qualifications, certificates, tools, software, or specialist knowledge do you already have?',
          'आपके पास कौन-सी डिग्री, योग्यता, प्रमाणपत्र, टूल, सॉफ्टवेयर या विशेष ज्ञान है?',
          'तुमच्याकडे कोणती पदवी, पात्रता, प्रमाणपत्रे, साधने, सॉफ्टवेअर किंवा विशेष ज्ञान आहे?',
        ),
        CareerQuestion(
          'Which achievements are you proud of, and what did they teach you about the work you do well?',
          'किन उपलब्धियों पर गर्व है, और उनसे आपके अच्छे काम के बारे में क्या पता चला?',
          'कोणत्या उपलब्धींचा अभिमान आहे आणि त्यातून तुम्ही कोणते काम चांगले करता हे काय समजले?',
        ),
      ],
      [
        CareerQuestion(
          'Have you considered specific careers or roles for the transition? What attracts you to them?',
          'बदल के लिए किन करियर या भूमिकाओं पर विचार किया है? वे क्यों आकर्षित करती हैं?',
          'बदलासाठी कोणत्या करिअर किंवा भूमिकांचा विचार केला आहे? त्या का आकर्षित करतात?',
        ),
        CareerQuestion(
          'Which skills, qualifications, or experience do you think you need for the new career? If unsure, write “Not sure”.',
          'नए करियर के लिए किन कौशलों, योग्यताओं या अनुभव की ज़रूरत है? पता न हो तो “पता नहीं” लिखें।',
          'नवीन करिअरसाठी कोणती कौशल्ये, पात्रता किंवा अनुभव आवश्यक वाटतात? खात्री नसल्यास “माहित नाही” लिहा.',
        ),
        CareerQuestion(
          'Would you consider courses, certificates, projects, internships, or entry-level roles to transition?',
          'बदल के लिए कोर्स, प्रमाणपत्र, परियोजना, इंटर्नशिप या शुरुआती पद स्वीकारेंगे?',
          'बदलासाठी अभ्यासक्रम, प्रमाणपत्रे, प्रकल्प, इंटर्नशिप किंवा सुरुवातीची भूमिका स्वीकाराल का?',
        ),
        CareerQuestion(
          'How much time and money can you invest, and when would you like to transition?',
          'कितना समय और पैसा लगा सकते हैं, और बदलाव कब करना चाहेंगे?',
          'किती वेळ आणि पैसा देऊ शकता आणि बदल कधी करायचा आहे?',
        ),
      ],
      [
        CareerQuestion(
          'What is your current income situation and the minimum monthly income needed during the transition?',
          'वर्तमान आय की स्थिति क्या है और बदलाव के दौरान न्यूनतम मासिक आय कितनी चाहिए?',
          'सध्याची उत्पन्न स्थिती काय आहे आणि बदलाच्या काळात किमान मासिक उत्पन्न किती हवे?',
        ),
        CareerQuestion(
          'How would you prefer to transition: change jobs, learn while employed, freelance part-time, retrain first, start entry-level, or start a business?',
          'बदल कैसे करेंगे—नौकरी बदलकर, नौकरी के साथ सीखकर, पार्ट-टाइम फ्रीलांसिंग, पहले प्रशिक्षण, शुरुआती पद या व्यवसाय?',
          'बदल कसा कराल—नोकरी बदलून, नोकरीसोबत शिकून, अर्धवेळ फ्रीलान्सिंग, आधी प्रशिक्षण, सुरुवातीची भूमिका की व्यवसाय?',
        ),
        CareerQuestion(
          'What practical constraints affect the transition: family, money, time, location, relocation, accessibility, or work authorization?',
          'परिवार, पैसा, समय, स्थान, स्थानांतरण, सुलभता या कार्य अनुमति में से क्या बदलाव को प्रभावित करता है?',
          'कुटुंब, पैसा, वेळ, ठिकाण, स्थलांतर, सुलभता किंवा कामाची परवानगी यापैकी काय बदलावर परिणाम करते?',
        ),
        CareerQuestion(
          'What conditions are non-negotiable, and which trade-offs would you consider for a better-fitting career?',
          'कौन-सी शर्तें अनिवार्य हैं, और बेहतर करियर के लिए किन समझौतों पर विचार करेंगे?',
          'कोणत्या अटी बदलता येणार नाहीत आणि योग्य करिअरसाठी कोणत्या तडजोडी स्वीकाराल?',
        ),
      ],
    ],
  ),
];
