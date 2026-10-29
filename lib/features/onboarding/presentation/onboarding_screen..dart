
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
          'आपकी सबसे ऊँची शैक्षिक योग्यता क्या है? आपने क्या पढ़ाई की है? क्या आपके पास इससे जुड़े प्रमाणपत्र हैं?  ',
          'तुमची सर्वात उच्च शैक्षणिक पात्रता काय आहे? तुम्ही काय शिकलात? या क्षेत्राशी संबंधित प्रमाणपत्रे आहेत का?',
        ),
        CareerQuestion(
          'What is your current situation: studying, employed, self-employed, unemployed, or seeking your first job? If not working, write “None”.',
          'अभी आप क्या कर रहे हैं—पढ़ाई, नौकरी, अपना काम, नौकरी की तलाश या पहली नौकरी की तलाश? काम नहीं कर रहे हैं, तो “कोई नहीं” लिखें।  ',
          'सध्या तुम्ही काय करता—शिक्षण, नोकरी, स्वतःचा व्यवसाय, नोकरीचा शोध की पहिल्या नोकरीचा शोध? काम करत नसाल, तर “काही नाही” लिहा.',
        ),
        CareerQuestion(
          'What work experience, internships, projects, volunteering, or practical experience do you have? If none, write “None”.',
          'क्या आपने नौकरी, इंटर्नशिप, प्रोजेक्ट, स्वयंसेवा या कोई व्यावहारिक काम किया है? नहीं किया है, तो “कोई नहीं” लिखें।  ',
          'तुम्ही नोकरी, इंटर्नशिप, प्रकल्प, स्वयंसेवा किंवा इतर प्रत्यक्ष काम केले आहे का? नसेल, तर “काही नाही” लिहा.',
        ),
        CareerQuestion(
          'Which country and city do you live in, and are you willing to relocate or work remotely?',
          'आप किस देश और शहर में रहते हैं? क्या आप काम के लिए दूसरे शहर जा सकते हैं या घर से काम करना पसंद करेंगे?  ',
          'तुम्ही कोणत्या देशात आणि शहरात राहता? कामासाठी दुसऱ्या शहरात जाऊ शकता का, की घरून काम करणे पसंत आहे?',
        ),
      ],
      [
        CareerQuestion(
          'What subjects, topics, or activities genuinely interest you, and what do you enjoy learning about?',
          'आपको किन विषयों या कामों में सच में रुचि है? आप क्या सीखना पसंद करते हैं?  ',
          'तुम्हाला कोणते विषय किंवा काम खरोखर आवडतात? तुम्हाला काय शिकायला आवडते?',
        ),
        CareerQuestion(
          'Which activities do you enjoy most? Choose up to three: problem-solving, people, data, design, technology, hands-on work, organizing, teaching/helping, sales, or research.',
          'इनमें से आपको सबसे ज़्यादा पसंद आने वाले कोई तीन काम चुनें: समस्याएँ हल करना, लोगों से काम करना, डेटा, डिज़ाइन, तकनीक, हाथ से काम करना, योजना बनाना, पढ़ाना या मदद करना, बिक्री या शोध।  ',
          'यांपैकी तुम्हाला सर्वाधिक आवडणारी कोणतीही तीन कामे निवडा: समस्या सोडवणे, लोकांसोबत काम, डेटा, डिझाइन, तंत्रज्ञान, हाताने काम, नियोजन, शिकवणे किंवा मदत करणे, विक्री किंवा संशोधन.',
        ),
        CareerQuestion(
          'Do you prefer working independently, with a team, with customers, or leading others? Briefly explain.',
          'आप अकेले काम करना पसंद करते हैं, टीम के साथ, ग्राहकों के साथ या दूसरों का नेतृत्व करना? थोड़ा समझाएँ।  ',
          'तुम्हाला एकट्याने काम करायला आवडते, संघासोबत, ग्राहकांसोबत की इतरांचे नेतृत्व करायला? थोडक्यात सांगा.',
        ),
        CareerQuestion(
          'What work environment do you prefer: remote, office, hybrid, outdoor/fieldwork, or hands-on work?',
          'आप कहाँ काम करना पसंद करेंगे—घर से, ऑफिस में, घर और ऑफिस दोनों जगह, बाहर/मैदान में या हाथ से काम करके?  ',
          'तुम्हाला कुठे काम करायला आवडेल—घरून, कार्यालयात, घरून आणि कार्यालयात दोन्ही ठिकाणी, बाहेर/मैदानी ठिकाणी की हाताने प्रत्यक्ष काम करून?',
        ),
      ],
      [
        CareerQuestion(
          'What skills do you have: technical, digital, communication, analytical, creative, practical, or language skills? Mention your English level.',
          'आपके पास कौन-कौन से कौशल हैं—तकनीकी, डिजिटल, बातचीत, विश्लेषण, रचनात्मक या व्यावहारिक कौशल? आपकी अंग्रेज़ी कैसी है?  ',
          'तुमच्याकडे कोणती कौशल्ये आहेत—तांत्रिक, डिजिटल, संवाद, विश्लेषण, सर्जनशील किंवा प्रत्यक्ष कामाची? तुमचे इंग्रजी कितपत चांगले आहे?',
        ),
        CareerQuestion(
          'What are you naturally good at? Give a real example that demonstrates your strengths.',
          'आप किस काम में स्वाभाविक रूप से अच्छे हैं? अपनी क्षमता दिखाने वाला कोई असली उदाहरण दें।  ',
          'तुम्ही कोणते काम सहज चांगले करता? तुमची क्षमता दाखवणारे एखादे खरे उदाहरण द्या.',
        ),
        CareerQuestion(
          'Which software, digital tools, equipment, or other tools can you use confidently? If none, write “None”.',
          'आप कौन-से सॉफ्टवेयर, डिजिटल साधन, मशीन या दूसरे उपकरण अच्छी तरह चला सकते हैं? कुछ भी नहीं, तो “कोई नहीं” लिखें।  ',
          'तुम्हाला कोणते सॉफ्टवेअर, डिजिटल साधन, मशीन किंवा इतर उपकरणे चांगल्या प्रकारे वापरता येतात? काहीही येत नसेल, तर “काही नाही” लिहा.',
        ),
        CareerQuestion(
          'What are you currently learning, and which new skills would you like to develop?',
          'आप अभी क्या सीख रहे हैं? आगे कौन-से नए कौशल सीखना चाहते हैं?  ',
          'तुम्ही सध्या काय शिकत आहात? पुढे कोणती नवीन कौशल्ये शिकू इच्छिता?',
        ),
      ],
      [
        CareerQuestion(
          'What are your main career goals for the next 1–3 years?',
          'अगले 1–3 साल में आप अपने करियर में क्या हासिल करना चाहते हैं?  ',
          'पुढील 1–3 वर्षांत तुम्हाला करिअरमध्ये काय साध्य करायचे आहे?',
        ),
        CareerQuestion(
          'Which three career factors matter most: income, security, flexibility, creativity, helping people, growth, independence, prestige, or balance?',
          'करियर में आपके लिए सबसे ज़रूरी तीन बातें चुनें: अच्छी कमाई, नौकरी की सुरक्षा, समय की छूट, रचनात्मक काम, लोगों की मदद, तरक्की, आज़ादी, प्रतिष्ठा या काम-जीवन में संतुलन।  ',
          'करिअरमध्ये तुमच्यासाठी सर्वात महत्त्वाच्या तीन गोष्टी निवडा: चांगले उत्पन्न, नोकरीची सुरक्षितता, वेळेची मोकळीक, सर्जनशील काम, लोकांना मदत, प्रगती, स्वातंत्र्य, प्रतिष्ठा किंवा काम आणि वैयक्तिक आयुष्यात समतोल.',
        ),
        CareerQuestion(
          'Which careers have you considered, and which would you prefer to avoid? Why?',
          'आपने किन करियर के बारे में सोचा है? किन करियर में जाना नहीं चाहेंगे और क्यों?  ',
          'तुम्ही कोणत्या करिअरचा विचार केला आहे? कोणत्या करिअरमध्ये जायला आवडणार नाही आणि का?',
        ),
        CareerQuestion(
          'What minimum monthly income do you need, and how soon must you start earning?',
          'आपको हर महीने कम से कम कितनी कमाई चाहिए? आपको कमाना कब तक शुरू करना ज़रूरी है?  ',
          'तुम्हाला दरमहा किमान किती उत्पन्न हवे आहे? तुम्हाला कमाई कधीपर्यंत सुरू करणे गरजेचे आहे?',
        ),
      ],
      [
        CareerQuestion(
          'How many hours per week can you dedicate to career learning, training, or job searching?',
          'करियर सीखने, प्रशिक्षण लेने या नौकरी खोजने के लिए आप हर हफ्ते कितने घंटे दे सकते हैं?  ',
          'करिअर शिकण्यासाठी, प्रशिक्षण घेण्यासाठी किंवा नोकरी शोधण्यासाठी तुम्ही दर आठवड्याला किती तास देऊ शकता?',
        ),
        CareerQuestion(
          'Are you willing to study or learn new skills? How much time and money can you invest?',
          'क्या आप आगे पढ़ाई करने या नए कौशल सीखने के लिए तैयार हैं? इसके लिए कितना समय और पैसा दे सकते हैं?  ',
          'तुम्ही पुढील शिक्षण घेण्यासाठी किंवा नवीन कौशल्ये शिकण्यासाठी तयार आहात का? यासाठी किती वेळ आणि पैसा देऊ शकता?',
        ),
        CareerQuestion(
          'What resources do you have for work or learning: phone, computer, internet, transport, workspace, or equipment?',
          'काम या पढ़ाई के लिए आपके पास क्या-क्या है—फोन, कंप्यूटर, इंटरनेट, आने-जाने की सुविधा, काम करने की जगह या उपकरण?  ',
          'कामासाठी किंवा शिकण्यासाठी तुमच्याकडे काय उपलब्ध आहे—फोन, संगणक, इंटरनेट, प्रवासाची सोय, कामाची जागा किंवा उपकरणे?',
        ),
        CareerQuestion(
          'What practical limitations or non-negotiable requirements should AI consider when recommending careers?',
          'करियर सुझाते समय AI को किन मुश्किलों, सीमाओं या ज़रूरी शर्तों का ध्यान रखना चाहिए?  ',
          'करिअर सुचवताना AI ने कोणत्या अडचणी, मर्यादा किंवा आवश्यक अटी लक्षात घ्याव्यात?',
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
          'आप किस क्षेत्र या करियर के बारे में जानना चाहते हैं?  ',
          'तुम्हाला कोणत्या क्षेत्राबद्दल किंवा करिअरबद्दल जाणून घ्यायचे आहे?',
        ),
        CareerQuestion(
          'Which roles or specializations have you considered? If unsure, write “Not sure”.',
          'आपने किन नौकरियों या खास क्षेत्रों के बारे में सोचा है? तय नहीं है, तो “अभी तय नहीं” लिखें।  ',
          'तुम्ही कोणत्या नोकऱ्या किंवा विशेष क्षेत्रांचा विचार केला आहे? ठरले नसेल, तर “अजून ठरलेले नाही” लिहा.',
        ),
        CareerQuestion(
          'What attracts you to this field?',
          'इस क्षेत्र में आपको क्या अच्छा लगता है या आपकी रुचि क्यों है?  ',
          'या क्षेत्रात तुम्हाला काय आवडते किंवा या क्षेत्रात रस का आहे?',
        ),
        CareerQuestion(
          'What do you most want to discover: roles, specializations, qualifications, or opportunities?',
          'आप इस क्षेत्र के बारे में सबसे पहले क्या जानना चाहते हैं—नौकरियाँ, खास क्षेत्र, ज़रूरी योग्यताएँ या उपलब्ध अवसर?  ',
          'या क्षेत्राबद्दल तुम्हाला आधी काय जाणून घ्यायचे आहे—नोकऱ्या, विशेष क्षेत्रे, आवश्यक पात्रता की उपलब्ध संधी?',
        ),
      ],
      [
        CareerQuestion(
          'What is your current situation: student, graduate, employed, unemployed, or changing careers?',
          'अभी आपकी स्थिति क्या है—पढ़ाई कर रहे हैं, पढ़ाई पूरी की है, नौकरी करते हैं, नौकरी ढूँढ रहे हैं या करियर बदलना चाहते हैं?  ',
          'सध्या तुमची स्थिती काय आहे—शिकत आहात, शिक्षण पूर्ण केले आहे, नोकरी करता, नोकरी शोधत आहात की करिअर बदलू इच्छिता?',
        ),
        CareerQuestion(
          'What is your highest qualification, what did you study, and which relevant certificates or licenses do you hold?',
          'आपकी सबसे ऊँची शैक्षिक योग्यता क्या है? आपने कौन-से विषय पढ़े हैं? क्या आपके पास इससे जुड़े प्रमाणपत्र या लाइसेंस हैं?  ',
          'तुमची सर्वात उच्च शैक्षणिक पात्रता काय आहे? तुम्ही कोणते विषय शिकलात? संबंधित प्रमाणपत्रे किंवा परवाने आहेत का?',
        ),
        CareerQuestion(
          'What do you already know about this field, and how would you rate your level?',
          'इस क्षेत्र के बारे में आपको पहले से क्या पता है? आप अपने ज्ञान का स्तर क्या मानते हैं?  ',
          'या क्षेत्राबद्दल तुम्हाला आधीपासून काय माहिती आहे? तुमच्या ज्ञानाची पातळी काय आहे?',
        ),
        CareerQuestion(
          'What relevant jobs, internships, projects, research, or training have you completed? If none, write “None”.',
          'क्या आपने इस क्षेत्र में नौकरी, इंटर्नशिप, प्रोजेक्ट, शोध या प्रशिक्षण किया है? नहीं किया है, तो “कोई नहीं” लिखें।  ',
          'तुम्ही या क्षेत्रात नोकरी, इंटर्नशिप, प्रकल्प, संशोधन किंवा प्रशिक्षण केले आहे का? नसेल, तर “काही नाही” लिहा.',
        ),
      ],
      [
        CareerQuestion(
          'Which tasks in this field would you find most interesting?',
          'इस क्षेत्र में कौन-से काम आपको सबसे दिलचस्प लगते हैं?  ',
          'या क्षेत्रातील कोणती कामे तुम्हाला सर्वात रोचक वाटतात?',
        ),
        CareerQuestion(
          'Which tasks would you avoid or enjoy least, and why?',
          'इस क्षेत्र में कौन-से काम आपको कम पसंद हैं या आप नहीं करना चाहेंगे? क्यों?  ',
          'या क्षेत्रातील कोणती कामे तुम्हाला कमी आवडतात किंवा करायची नाहीत? का?',
        ),
        CareerQuestion(
          'Would you rather work with people, data, ideas/research, technology/tools, physical materials, or a mix?',
          'आप किसके साथ काम करना पसंद करेंगे—लोगों, डेटा, विचारों/शोध, तकनीक/औज़ार, चीज़ों को हाथ से बनाने या इनके मिले-जुले काम के साथ?  ',
          'तुम्हाला कशासोबत काम करायला आवडेल—लोक, डेटा, कल्पना/संशोधन, तंत्रज्ञान/साधने, वस्तू हाताने तयार करणे की या कामांचे मिश्रण?',
        ),
        CareerQuestion(
          'Which setting do you prefer: office, remote, lab, clinic, research site, industrial site, fieldwork, or workshop?',
          'आप किस जगह काम करना पसंद करेंगे—ऑफिस, घर से, लैब, क्लिनिक, शोध केंद्र, कारखाना, बाहर/मैदान में या वर्कशॉप में?  ',
          'तुम्हाला कुठे काम करायला आवडेल—कार्यालयात, घरून, प्रयोगशाळेत, क्लिनिकमध्ये, संशोधन केंद्रात, कारखान्यात, बाहेर/मैदानी ठिकाणी की कार्यशाळेत?',
        ),
      ],
      [
        CareerQuestion(
          'Which skills do you already have that could be useful in this field? Include your level.',
          'इस क्षेत्र में आपके कौन-से कौशल काम आ सकते हैं? अपने कौशल का स्तर भी बताएँ।  ',
          'या क्षेत्रात तुमची कोणती कौशल्ये उपयोगी पडू शकतात? त्या कौशल्यांची पातळीही सांगा.',
        ),
        CareerQuestion(
          'What are your strongest abilities? Give a real example.',
          'आपकी सबसे मज़बूत क्षमताएँ कौन-सी हैं? कोई असली उदाहरण दें।  ',
          'तुमच्या सर्वात मजबूत क्षमता कोणत्या आहेत? एखादे खरे उदाहरण द्या.',
        ),
        CareerQuestion(
          'Which subjects or problems do you learn or solve easily, and which are difficult?',
          'कौन-से विषय या समस्याएँ आप आसानी से सीखते या हल करते हैं? कौन-से कठिन लगते हैं?  ',
          'कोणते विषय किंवा समस्या तुम्ही सहज शिकता किंवा सोडवता? कोणते कठीण वाटतात?',
        ),
        CareerQuestion(
          'Which new skills, technologies, subjects, or specializations would you like to learn?',
          'आप आगे कौन-से नए कौशल, तकनीक, विषय या किसी खास क्षेत्र की जानकारी सीखना चाहते हैं?  ',
          'पुढे कोणती नवीन कौशल्ये, तंत्रज्ञान, विषय किंवा एखाद्या खास क्षेत्राचे ज्ञान शिकू इच्छिता?',
        ),
      ],
      [
        CareerQuestion(
          'What are your three most important priorities in a future role?',
          'आगे की नौकरी में आपके लिए सबसे ज़रूरी तीन बातें क्या हैं?  ',
          'पुढील नोकरीत तुमच्यासाठी सर्वात महत्त्वाच्या तीन गोष्टी कोणत्या आहेत?',
        ),
        CareerQuestion(
          'What income do you expect, and how soon would you like to start earning?',
          'आप कितनी कमाई की उम्मीद करते हैं? आप कमाना कब तक शुरू करना चाहते हैं?  ',
          'तुम्हाला किती उत्पन्न अपेक्षित आहे? तुम्हाला कमाई कधीपर्यंत सुरू करायची आहे?',
        ),
        CareerQuestion(
          'How much time and money can you invest in education, training, or certificates?',
          'पढ़ाई, प्रशिक्षण या प्रमाणपत्रों के लिए आप कितना समय और पैसा दे सकते हैं?  ',
          'शिक्षण, प्रशिक्षण किंवा प्रमाणपत्रांसाठी तुम्ही किती वेळ आणि पैसा देऊ शकता?',
        ),
        CareerQuestion(
          'What constraints must be considered: location, hours, family responsibilities, budget, or accessibility?',
          'जगह, काम के घंटे, परिवार की ज़िम्मेदारियाँ, बजट या काम करने की सुविधा जैसी किन बातों का ध्यान रखना ज़रूरी है?  ',
          'ठिकाण, कामाचे तास, कौटुंबिक जबाबदाऱ्या, बजेट किंवा कामाच्या सोयीबाबत कोणत्या गोष्टी लक्षात घेणे गरजेचे आहे?',
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
          'आप किस प्रतियोगी, प्रवेश या भर्ती परीक्षा की तैयारी कर रहे हैं या देना चाहते हैं? कई परीक्षाएँ हों, तो मुख्य परीक्षा का नाम बताएँ।  ',
          'तुम्ही कोणत्या स्पर्धा, प्रवेश किंवा भरती परीक्षेची तयारी करत आहात किंवा परीक्षा देऊ इच्छिता? अनेक परीक्षा असतील, तर मुख्य परीक्षेचे नाव सांगा.',
        ),
        CareerQuestion(
          'What career, job, course, or outcome do you want through this exam? If unsure, write “Not sure”.',
          'इस परीक्षा से आप कौन-सा करियर, नौकरी, कोर्स या नतीजा पाना चाहते हैं? तय नहीं है, तो “अभी तय नहीं” लिखें।  ',
          'या परीक्षेतून तुम्हाला कोणते करिअर, नोकरी, अभ्यासक्रम किंवा परिणाम हवा आहे? ठरले नसेल, तर “अजून ठरलेले नाही” लिहा.',
        ),
        CareerQuestion(
          'Why do you want this exam and the career associated with it?',
          'आप यह परीक्षा क्यों देना चाहते हैं? इससे जुड़े करियर में आपकी रुचि क्यों है?  ',
          'तुम्हाला ही परीक्षा का द्यायची आहे? या परीक्षेशी संबंधित करिअरमध्ये रस का आहे?',
        ),
        CareerQuestion(
          'Are you focused only on this exam, or open to related exams and other routes to similar opportunities?',
          'क्या आप सिर्फ इसी परीक्षा पर ध्यान देना चाहते हैं, या इसी तरह के अवसर देने वाली दूसरी परीक्षाओं और रास्तों पर भी विचार करेंगे?  ',
          'तुम्हाला फक्त याच परीक्षेवर लक्ष द्यायचे आहे, की अशाच संधी देणाऱ्या इतर परीक्षा आणि मार्गांचाही विचार कराल?',
        ),
      ],
      [
        CareerQuestion(
          'What is your current educational stage: school, undergraduate, final year, graduate, postgraduate, or working?',
          'अभी आप किस शैक्षिक स्तर पर हैं—स्कूल, कॉलेज में, अंतिम वर्ष, स्नातक, स्नातकोत्तर या नौकरी में?  ',
          'सध्या तुम्ही कोणत्या शैक्षणिक टप्प्यावर आहात—शाळा, महाविद्यालय, शेवटचे वर्ष, पदवीधर, पदव्युत्तर की नोकरीत?',
        ),
        CareerQuestion(
          'What is your highest completed qualification, and what subjects, stream, degree, or specialization did you study?',
          'आपने कौन-सी सबसे ऊँची पढ़ाई पूरी की है? आपने कौन-से विषय या शाखा पढ़ी है?  ',
          'तुम्ही कोणते सर्वोच्च शिक्षण पूर्ण केले आहे? कोणते विषय किंवा शाखा शिकला आहात?',
        ),
        CareerQuestion(
          'What will your age be on the exam’s relevant eligibility date, if an age limit applies? If unsure, write “Not sure”.',
          'परीक्षा की उम्र-सीमा लागू होती है, तो तय तारीख पर आपकी उम्र कितनी होगी? पता न हो, तो “अभी पता नहीं” लिखें।  ',
          'परीक्षेसाठी वयोमर्यादा असल्यास, ठरवलेल्या तारखेला तुमचे वय किती असेल? माहीत नसेल, तर “अजून माहीत नाही” लिहा.',
        ),
        CareerQuestion(
          'Have you checked qualification, subject, age, attempt, nationality/residency, and physical or medical requirements? What still needs checking?',
          'क्या आपने पढ़ाई, विषय, उम्र, परीक्षा के प्रयासों की सीमा, नागरिकता/निवास और शारीरिक या मेडिकल शर्तें जाँची हैं? क्या जाँचना बाकी है?  ',
          'शिक्षण, विषय, वय, परीक्षेच्या प्रयत्नांची मर्यादा, नागरिकत्व/रहिवास आणि शारीरिक किंवा वैद्यकीय अटी तपासल्या आहेत का? अजून काय तपासायचे आहे?',
        ),
      ],
      [
        CareerQuestion(
          'Which exam year, cycle, or attempt are you targeting?',
          'आप किस साल या किस प्रयास में परीक्षा देना चाहते हैं?  ',
          'तुम्हाला कोणत्या वर्षी किंवा कोणत्या प्रयत्नात परीक्षा द्यायची आहे?',
        ),
        CareerQuestion(
          'How long have you prepared, and which methods do you use: self-study, coaching, courses, books, or practice platforms?',
          'आप कितने समय से तैयारी कर रहे हैं? तैयारी के लिए क्या इस्तेमाल करते हैं—खुद पढ़ना, कोचिंग, कोर्स, किताबें या ऑनलाइन अभ्यास?  ',
          'तुम्ही किती काळापासून तयारी करत आहात? तयारीसाठी काय वापरता—स्वतः अभ्यास, कोचिंग, अभ्यासक्रम, पुस्तके की ऑनलाइन सराव?',
        ),
        CareerQuestion(
          'What stage are you at: syllabus exploration, fundamentals, syllabus completion, revision, mock tests, interview, or awaiting results?',
          'तैयारी अभी किस स्तर पर है—सिलेबस समझना, बुनियादी पढ़ाई, सिलेबस पूरा करना, दोहराना, मॉक टेस्ट, इंटरव्यू या नतीजे का इंतज़ार?  ',
          'तुमची तयारी सध्या कोणत्या टप्प्यावर आहे—अभ्यासक्रम समजून घेणे, मूलभूत अभ्यास, अभ्यासक्रम पूर्ण करणे, उजळणी, सराव परीक्षा, मुलाखत की निकालाची वाट पाहणे?',
        ),
        CareerQuestion(
          'What shows your current level: mock scores, subject marks, percentile, previous results, rank, or other assessments? If none, write “Not taken yet”.',
          'आपके स्तर का पता किससे चलता है—मॉक टेस्ट के अंक, विषयों के अंक, पर्सेंटाइल, पिछले नतीजे या रैंक? कुछ नहीं दिया है, तो “अभी परीक्षा नहीं दी” लिखें।  ',
          'तुमची पातळी कशावरून समजते—सराव परीक्षेतील गुण, विषयांचे गुण, पर्सेंटाइल, मागील निकाल की रँक? अजून परीक्षा दिली नसेल, तर “अजून परीक्षा दिली नाही” लिहा.',
        ),
      ],
      [
        CareerQuestion(
          'Which exam subjects or sections are strongest and weakest for you? Use your study or test performance where possible.',
          'किन विषयों या हिस्सों में आप अच्छे हैं और किनमें मुश्किल होती है? हो सके, तो अपने टेस्ट या पढ़ाई के नतीजों से बताएँ।  ',
          'कोणते विषय किंवा भाग तुम्हाला चांगले जमतात आणि कोणते कठीण जातात? शक्य असल्यास चाचणी किंवा अभ्यासातील निकालांवरून सांगा.',
        ),
        CareerQuestion(
          'Which aspects of the intended career appeal to you most?',
          'इस करियर की कौन-सी बातें आपको सबसे ज़्यादा पसंद हैं?  ',
          'या करिअरमधील कोणत्या गोष्टी तुम्हाला सर्वात जास्त आवडतात?',
        ),
        CareerQuestion(
          'Which aspects of the career or working conditions might not suit you?',
          'इस करियर या इसके काम करने के तरीके की कौन-सी बातें आपको शायद पसंद न आएँ?  ',
          'या करिअरमधील किंवा कामाच्या पद्धतीतील कोणत्या गोष्टी तुम्हाला कदाचित आवडणार नाहीत?',
        ),
        CareerQuestion(
          'Which related careers, courses, specializations, or exams would you consider if they fit your abilities and circumstances?',
          'आपकी क्षमता और परिस्थिति के अनुसार आप किन मिलते-जुलते करियर, कोर्स, विशेष क्षेत्रों या परीक्षाओं पर भी विचार करेंगे?  ',
          'तुमच्या क्षमता आणि परिस्थितीनुसार कोणती संबंधित करिअर, अभ्यासक्रम, विशेष क्षेत्रे किंवा परीक्षा विचारात घ्याल?',
        ),
      ],
      [
        CareerQuestion(
          'What are your top three career priorities: security, income, public service, growth, prestige, work-life balance, independence, or specialization?',
          'करियर में आपकी सबसे ज़रूरी तीन प्राथमिकताएँ क्या हैं—नौकरी की सुरक्षा, कमाई, लोगों की सेवा, तरक्की, प्रतिष्ठा, काम-जीवन संतुलन, आज़ादी या किसी विषय में विशेषज्ञ बनना?  ',
          'करिअरमध्ये तुमची सर्वात महत्त्वाची तीन प्राधान्ये कोणती—नोकरीची सुरक्षितता, उत्पन्न, लोकांची सेवा, प्रगती, प्रतिष्ठा, काम-जीवन समतोल, स्वातंत्र्य की एखाद्या विषयात तज्ज्ञ होणे?',
        ),
        CareerQuestion(
          'Where would you prefer to study or work, and can you relocate or accept postings in different locations?',
          'आप कहाँ पढ़ना या काम करना चाहेंगे? क्या आप दूसरे शहर जा सकते हैं या अलग-अलग जगह नौकरी करना स्वीकार करेंगे?  ',
          'तुम्हाला कुठे शिकायला किंवा काम करायला आवडेल? तुम्ही दुसऱ्या शहरात जाऊ शकता का किंवा वेगवेगळ्या ठिकाणी नोकरी स्वीकाराल का?',
        ),
        CareerQuestion(
          'How soon do you need to earn, and can you prepare without regular income until your target date?',
          'आपको कमाना कब से शुरू करना ज़रूरी है? क्या आप परीक्षा की तय तारीख तक नियमित कमाई के बिना तैयारी कर सकते हैं?  ',
          'तुम्हाला कमाई कधीपासून सुरू करणे गरजेचे आहे? परीक्षेच्या ठरलेल्या तारखेपर्यंत नियमित उत्पन्नाशिवाय तयारी करू शकता का?',
        ),
        CareerQuestion(
          'What practical constraints or non-negotiable requirements should be considered for your target career and related options?',
          'आपके लक्ष्य वाले करियर और दूसरे विकल्पों के लिए किन सीमाओं या ज़रूरी शर्तों का ध्यान रखना चाहिए?  ',
          'तुमच्या लक्ष्याच्या करिअरसाठी आणि इतर पर्यायांसाठी कोणत्या मर्यादा किंवा आवश्यक अटी लक्षात घ्याव्यात?',
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
          'आप किस परीक्षा की तैयारी कर रहे हैं? उस परीक्षा से आप कौन-सा करियर या नतीजा पाना चाहते हैं?  ',
          'तुम्ही कोणत्या परीक्षेची तयारी करत आहात? त्या परीक्षेतून कोणते करिअर किंवा परिणाम मिळवायचे आहेत?',
        ),
        CareerQuestion(
          'Why do you want a backup: income while studying, financial pressure, alternatives if plans change, or exploring interests?',
          'आपको दूसरा विकल्प क्यों चाहिए—पढ़ाई के साथ कमाई, पैसों की ज़रूरत, योजना बदलने पर दूसरा रास्ता या अपनी रुचि जानने के लिए?  ',
          'तुम्हाला पर्यायी मार्ग का हवा आहे—अभ्यासासोबत कमाई, पैशांची गरज, योजना बदलल्यास दुसरा मार्ग की स्वतःची आवड जाणून घेण्यासाठी?',
        ),
        CareerQuestion(
          'What preparation stage are you at, and when is your next target exam or attempt?',
          'आपकी तैयारी अभी किस स्तर पर है? अगली परीक्षा या प्रयास कब है?  ',
          'तुमची तयारी सध्या कोणत्या टप्प्यावर आहे? पुढील परीक्षा किंवा प्रयत्न कधी आहे?',
        ),
        CareerQuestion(
          'When should the backup become useful: now, within 3–6 months, 6–12 months, after your next attempt, or longer term?',
          'आपको दूसरा विकल्प कब तक काम आने लगे—अभी, 3–6 महीने में, 6–12 महीने में, अगले प्रयास के बाद या बाद में?  ',
          'तुम्हाला पर्यायी मार्ग कधीपर्यंत उपयोगी व्हायला हवा—आत्ताच, 3–6 महिन्यांत, 6–12 महिन्यांत, पुढील प्रयत्नानंतर की त्यानंतर?',
        ),
      ],
      [
        CareerQuestion(
          'What is your current educational stage, highest completed qualification, and field of study?',
          'आप अभी किस स्तर पर पढ़ रहे हैं? आपकी सबसे ऊँची पूरी की हुई योग्यता और पढ़ाई का क्षेत्र क्या है?  ',
          'तुम्ही सध्या कोणत्या शैक्षणिक टप्प्यावर आहात? तुमची पूर्ण झालेली सर्वोच्च पात्रता आणि शिक्षणाचे क्षेत्र कोणते?',
        ),
        CareerQuestion(
          'Which subjects, professional qualifications, certificates, licences, or formal training have you completed?',
          'आपने कौन-से विषय, पेशेवर योग्यताएँ, प्रमाणपत्र, लाइसेंस या प्रशिक्षण पूरा किया है?  ',
          'तुम्ही कोणते विषय, व्यावसायिक पात्रता, प्रमाणपत्रे, परवाने किंवा प्रशिक्षण पूर्ण केले आहे?',
        ),
        CareerQuestion(
          'What work, internship, project, tutoring, volunteer, freelance, or business experience do you have?',
          'आपको नौकरी, इंटर्नशिप, प्रोजेक्ट, ट्यूशन, स्वयंसेवा, फ्रीलांस काम या व्यवसाय का क्या अनुभव है?  ',
          'तुम्हाला नोकरी, इंटर्नशिप, प्रकल्प, शिकवणी, स्वयंसेवा, फ्रीलान्स काम किंवा व्यवसायाचा काय अनुभव आहे?',
        ),
        CareerQuestion(
          'Are you completing any qualification soon? Include its expected completion date.',
          'क्या आपकी कोई पढ़ाई या योग्यता जल्द पूरी होने वाली है? कब तक पूरी होगी?  ',
          'तुमचे कोणते शिक्षण किंवा पात्रता लवकरच पूर्ण होणार आहे का? ते कधीपर्यंत पूर्ण होईल?',
        ),
      ],
      [
        CareerQuestion(
          'Which skills do you have: academic, technical, digital, communication, analytical, teaching, or practical skills?',
          'आपके पास कौन-से कौशल हैं—पढ़ाई से जुड़े, तकनीकी, डिजिटल, बातचीत, विश्लेषण, पढ़ाने या व्यावहारिक काम के कौशल?  ',
          'तुमच्याकडे कोणती कौशल्ये आहेत—अभ्यासाशी संबंधित, तांत्रिक, डिजिटल, संवाद, विश्लेषण, शिकवणे किंवा प्रत्यक्ष कामाची?',
        ),
        CareerQuestion(
          'What are you good at? Give a real example from study, work, a project, or an activity.',
          'आप किस काम में अच्छे हैं? पढ़ाई, नौकरी, प्रोजेक्ट या किसी गतिविधि का असली उदाहरण दें।  ',
          'तुम्ही कोणते काम चांगले करता? अभ्यास, नोकरी, प्रकल्प किंवा एखाद्या उपक्रमाचे खरे उदाहरण द्या.',
        ),
        CareerQuestion(
          'What work might you enjoy alongside or apart from exam preparation, and what work would you avoid?',
          'परीक्षा की तैयारी के साथ या उसके अलावा आप कौन-सा काम करना पसंद करेंगे? कौन-सा काम नहीं करना चाहेंगे?  ',
          'परीक्षेच्या तयारीसोबत किंवा त्याव्यतिरिक्त कोणते काम करायला आवडेल? कोणते काम करायला आवडणार नाही?',
        ),
        CareerQuestion(
          'Which skills or interests would you be willing to develop into employment or income?',
          'आप किन कौशलों या रुचियों को नौकरी या कमाई का ज़रिया बनाना चाहेंगे?  ',
          'कोणती कौशल्ये किंवा आवडी तुम्हाला नोकरी किंवा कमाईचे साधन बनवायला आवडेल?',
        ),
      ],
      [
        CareerQuestion(
          'How many hours per day or week can you spend on backup work or training without seriously disrupting exam preparation?',
          'परीक्षा की तैयारी पर ज़्यादा असर डाले बिना, दूसरे काम या प्रशिक्षण के लिए आप रोज़ या हर हफ्ते कितना समय दे सकते हैं?  ',
          'परीक्षेच्या तयारीवर जास्त परिणाम न होऊ देता, दुसऱ्या कामासाठी किंवा प्रशिक्षणासाठी तुम्ही दररोज किंवा दर आठवड्याला किती वेळ देऊ शकता?',
        ),
        CareerQuestion(
          'How much monthly income do you need, and how soon must you start earning?',
          'आपको हर महीने कितनी कमाई चाहिए? आपको कमाना कब तक शुरू करना ज़रूरी है?  ',
          'तुम्हाला दरमहा किती उत्पन्न हवे आहे? तुम्हाला कमाई कधीपर्यंत सुरू करणे गरजेचे आहे?',
        ),
        CareerQuestion(
          'Where can you work: from home, online, locally, in a specific city, or elsewhere? Can you relocate?',
          'आप कहाँ काम कर सकते हैं—घर से, ऑनलाइन, अपने इलाके में, किसी खास शहर में या कहीं और? क्या आप दूसरे शहर जा सकते हैं?  ',
          'तुम्ही कुठे काम करू शकता—घरून, ऑनलाइन, आपल्या परिसरात, एखाद्या ठराविक शहरात की इतरत्र? तुम्ही दुसऱ्या शहरात जाऊ शकता का?',
        ),
        CareerQuestion(
          'What resources are available: phone, computer, internet, transport, workspace, software, or equipment?',
          'आपके पास कौन-कौन सी चीज़ें हैं—फोन, कंप्यूटर, इंटरनेट, आने-जाने की सुविधा, काम की जगह, सॉफ्टवेयर या उपकरण?  ',
          'तुमच्याकडे काय उपलब्ध आहे—फोन, संगणक, इंटरनेट, प्रवासाची सोय, कामाची जागा, सॉफ्टवेअर किंवा उपकरणे?',
        ),
      ],
      [
        CareerQuestion(
          'Which backup would help most: part-time, freelancing, remote work, full-time job, long-term career, or another course?',
          'आपके लिए कौन-सा विकल्प सबसे उपयोगी होगा—पार्ट-टाइम काम, फ्रीलांस काम, घर से काम, पूरी नौकरी, लंबे समय का करियर या कोई कोर्स?  ',
          'तुमच्यासाठी कोणता पर्याय सर्वात उपयोगी असेल—अर्धवेळ काम, फ्रीलान्स काम, घरून काम, पूर्णवेळ नोकरी, दीर्घकालीन करिअर की एखादा अभ्यासक्रम?',
        ),
        CareerQuestion(
          'What are your top three priorities: quick income, flexible hours, low training cost, stability, growth, remote work, or experience?',
          'आपकी सबसे ज़रूरी तीन बातें क्या हैं—जल्दी कमाई, समय की छूट, कम प्रशिक्षण खर्च, स्थिरता, तरक्की, घर से काम या अनुभव?  ',
          'तुमच्यासाठी सर्वात महत्त्वाच्या तीन गोष्टी कोणत्या—लवकर कमाई, वेळेची मोकळीक, कमी प्रशिक्षण खर्च, स्थिरता, प्रगती, घरून काम की अनुभव?',
        ),
        CareerQuestion(
          'How much time and money can you invest in skills or certificates? Do you need to earn using existing skills immediately?',
          'नए कौशल या प्रमाणपत्र सीखने के लिए कितना समय और पैसा दे सकते हैं? क्या आपको अपने मौजूदा कौशल से तुरंत कमाना है?  ',
          'नवीन कौशल्ये किंवा प्रमाणपत्रे शिकण्यासाठी किती वेळ आणि पैसा देऊ शकता? सध्याच्या कौशल्यांतून लगेच कमाई करणे गरजेचे आहे का?',
        ),
        CareerQuestion(
          'Which jobs, industries, conditions, or other limits should AI avoid when recommending backup options?',
          'दूसरे करियर विकल्प सुझाते समय AI को किन नौकरियों, क्षेत्रों या काम की स्थितियों से बचना चाहिए?  ',
          'पर्यायी करिअर सुचवताना AI ने कोणत्या नोकऱ्या, क्षेत्रे किंवा कामाच्या परिस्थिती टाळाव्यात?',
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
          'आपकी अभी की नौकरी या भूमिका क्या है? आप किस उद्योग और किस तरह की संस्था में काम करते हैं?  ',
          'तुमची सध्याची नोकरी किंवा भूमिका काय आहे? तुम्ही कोणत्या उद्योगात आणि कोणत्या प्रकारच्या संस्थेत काम करता?',
        ),
        CareerQuestion(
          'How many years of experience do you have in this role and overall field?',
          'आपको इस भूमिका में और अपने पूरे क्षेत्र में कितने साल का अनुभव है?  ',
          'या भूमिकेत आणि एकूण क्षेत्रात तुम्हाला किती वर्षांचा अनुभव आहे?',
        ),
        CareerQuestion(
          'What are your main responsibilities, and what does a typical working day look like?',
          'आपके मुख्य काम क्या हैं? आपका सामान्य कामकाजी दिन कैसा होता है?  ',
          'तुमची मुख्य कामे कोणती आहेत? तुमचा नेहमीचा कामाचा दिवस कसा असतो?',
        ),
        CareerQuestion(
          'What is your highest education, and which relevant professional certificates, licenses, or training do you hold?',
          'आपकी सबसे ऊँची शैक्षिक योग्यता क्या है? आपके पास कौन-से संबंधित प्रमाणपत्र, लाइसेंस या प्रशिक्षण हैं?  ',
          'तुमची सर्वात उच्च शैक्षणिक पात्रता काय आहे? तुमच्याकडे कोणती संबंधित प्रमाणपत्रे, परवाने किंवा प्रशिक्षण आहे?',
        ),
      ],
      [
        CareerQuestion(
          'What would you most like to achieve in your career over the next 1–3 years?',
          'अगले 1–3 साल में आप अपने करियर में क्या हासिल करना चाहते हैं?  ',
          'पुढील 1–3 वर्षांत तुम्हाला करिअरमध्ये काय साध्य करायचे आहे?',
        ),
        CareerQuestion(
          'Which next job title, seniority level, or professional milestone would you like to reach?',
          'आप आगे कौन-सा पद, ज़िम्मेदारी का स्तर या पेशेवर लक्ष्य पाना चाहते हैं?  ',
          'पुढे कोणते पद, जबाबदारीची पातळी किंवा व्यावसायिक ध्येय गाठायचे आहे?',
        ),
        CareerQuestion(
          'What are your top three priorities: income, promotion, security, expertise, leadership, independence, recognition, meaning, or flexibility?',
          'आपके लिए सबसे ज़रूरी तीन बातें क्या हैं—कमाई, पदोन्नति, नौकरी की सुरक्षा, विशेषज्ञता, नेतृत्व, आज़ादी, पहचान, अर्थपूर्ण काम या समय की छूट?  ',
          'तुमच्यासाठी सर्वात महत्त्वाच्या तीन गोष्टी कोणत्या—उत्पन्न, पदोन्नती, नोकरीची सुरक्षितता, तज्ज्ञता, नेतृत्व, स्वातंत्र्य, ओळख, अर्थपूर्ण काम की वेळेची मोकळीक?',
        ),
        CareerQuestion(
          'Why do you want to advance now, and what would meaningful progress look like?',
          'आप अभी करियर में आगे क्यों बढ़ना चाहते हैं? आपके लिए अच्छी प्रगति कैसी होगी?  ',
          'तुम्हाला आत्ताच करिअरमध्ये पुढे का जायचे आहे? तुमच्यासाठी चांगली प्रगती म्हणजे काय?',
        ),
      ],
      [
        CareerQuestion(
          'Which professional, technical, analytical, communication, leadership, or other skills do you use at work?',
          'काम में आप कौन-से पेशेवर, तकनीकी, विश्लेषण, बातचीत, नेतृत्व या दूसरे कौशल इस्तेमाल करते हैं?  ',
          'कामात तुम्ही कोणती व्यावसायिक, तांत्रिक, विश्लेषण, संवाद, नेतृत्व किंवा इतर कौशल्ये वापरता?',
        ),
        CareerQuestion(
          'What are your most significant professional achievements? Include measurable results if possible.',
          'काम में आपकी सबसे बड़ी उपलब्धियाँ क्या हैं? हो सके, तो नतीजे आँकड़ों में बताएँ।  ',
          'कामातील तुमच्या सर्वात मोठ्या उपलब्धी कोणत्या आहेत? शक्य असल्यास परिणाम आकड्यांमध्ये सांगा.',
        ),
        CareerQuestion(
          'What feedback have managers, colleagues, customers, mentors, or clients given about your strengths and improvement areas?',
          'आपके मैनेजर, सहकर्मियों, ग्राहकों या मार्गदर्शकों ने आपकी खूबियों और सुधार की ज़रूरतों के बारे में क्या कहा है?  ',
          'तुमच्या व्यवस्थापकांनी, सहकाऱ्यांनी, ग्राहकांनी किंवा मार्गदर्शकांनी तुमच्या चांगल्या गुणांबद्दल आणि सुधारणेबद्दल काय सांगितले आहे?',
        ),
        CareerQuestion(
          'Which tasks do you enjoy most, and which feel difficult, frustrating, or less fulfilling?',
          'आपको कौन-से काम सबसे ज़्यादा पसंद हैं? कौन-से काम कठिन, परेशान करने वाले या कम संतोष देने वाले लगते हैं?  ',
          'तुम्हाला कोणती कामे सर्वात जास्त आवडतात? कोणती कामे कठीण, त्रासदायक किंवा कमी समाधान देणारी वाटतात?',
        ),
      ],
      [
        CareerQuestion(
          'Which skills, qualifications, experience, or responsibilities do you need for the role you want next?',
          'अगली भूमिका पाने के लिए आपको कौन-से कौशल, योग्यताएँ, अनुभव या ज़िम्मेदारियाँ चाहिए?  ',
          'पुढील भूमिका मिळवण्यासाठी तुम्हाला कोणती कौशल्ये, पात्रता, अनुभव किंवा जबाबदाऱ्या आवश्यक आहेत?',
        ),
        CareerQuestion(
          'What challenges currently prevent your career progress?',
          'अभी कौन-सी मुश्किलें आपके करियर में आगे बढ़ने से रोक रही हैं?  ',
          'सध्या कोणत्या अडचणींमुळे तुमच्या करिअरमधील प्रगती थांबत आहे?',
        ),
        CareerQuestion(
          'What professional development have you completed or are pursuing: courses, certificates, mentoring, projects, or leadership?',
          'आपने या अभी कौन-सी चीज़ें सीख रहे हैं—कोर्स, प्रमाणपत्र, मार्गदर्शन, प्रोजेक्ट या नेतृत्व का अनुभव?  ',
          'तुम्ही कोणते प्रशिक्षण घेतले आहे किंवा सध्या काय शिकत आहात—अभ्यासक्रम, प्रमाणपत्र, मार्गदर्शन, प्रकल्प की नेतृत्वाचा अनुभव?',
        ),
        CareerQuestion(
          'Which direction do you prefer: specialist, senior role, manager, new specialization, consultant, business owner, or unsure?',
          'आप आगे किस दिशा में जाना चाहते हैं—किसी विषय के विशेषज्ञ, वरिष्ठ पद, मैनेजर, नया विशेषज्ञ क्षेत्र, सलाहकार, अपना व्यवसाय या अभी तय नहीं है?  ',
          'तुम्हाला पुढे कोणत्या दिशेने जायचे आहे—एखाद्या विषयाचे तज्ज्ञ, वरिष्ठ पद, व्यवस्थापक, नवीन विशेष क्षेत्र, सल्लागार, स्वतःचा व्यवसाय की अजून ठरलेले नाही?',
        ),
      ],
      [
        CareerQuestion(
          'What is your current monthly income range, desired income, and target timeline?',
          'अभी आपकी मासिक कमाई कितनी है? आप कितनी कमाई चाहते हैं और कब तक?  ',
          'सध्या तुमचे मासिक उत्पन्न किती आहे? तुम्हाला किती उत्पन्न हवे आहे आणि कधीपर्यंत?',
        ),
        CareerQuestion(
          'How much time per week and budget can you invest in development while keeping current responsibilities?',
          'मौजूदा ज़िम्मेदारियाँ निभाते हुए, हर हफ्ते कितना समय और कितना बजट आप अपने विकास पर लगा सकते हैं?  ',
          'सध्याच्या जबाबदाऱ्या सांभाळून, दर आठवड्याला किती वेळ आणि किती बजेट स्वतःच्या विकासासाठी देऊ शकता?',
        ),
        CareerQuestion(
          'What opportunities exist: promotion, projects, mentoring, networking, changing employer, or further study?',
          'आपके पास आगे बढ़ने के कौन-से मौके हैं—पदोन्नति, नए प्रोजेक्ट, मार्गदर्शन, संपर्क बढ़ाना, नौकरी बदलना या आगे पढ़ाई?  ',
          'पुढे जाण्यासाठी कोणत्या संधी आहेत—पदोन्नती, नवीन प्रकल्प, मार्गदर्शन, संपर्क वाढवणे, नोकरी बदलणे की पुढील शिक्षण?',
        ),
        CareerQuestion(
          'What constraints must be considered: family, hours, location, finances, accessibility, or work authorization?',
          'परिवार, काम के घंटे, जगह, पैसे, काम करने की सुविधा या काम की अनुमति जैसी किन बातों का ध्यान रखना ज़रूरी है?  ',
          'कुटुंब, कामाचे तास, ठिकाण, पैसा, कामाच्या सोयी किंवा काम करण्याची परवानगी यांसारख्या कोणत्या गोष्टी लक्षात घ्याव्या लागतील?',
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
          'अभी आपकी स्थिति क्या है? नौकरी करते हैं, तो अपना पद, क्षेत्र और मुख्य काम बताएँ।  ',
          'सध्या तुमची स्थिती काय आहे? नोकरी करत असल्यास तुमचे पद, क्षेत्र आणि मुख्य कामे सांगा.',
        ),
        CareerQuestion(
          'How much experience do you have in your current or most recent career, and what are your main responsibilities or achievements?',
          'अभी के या पिछले करियर में आपको कितना अनुभव है? आपके मुख्य काम या उपलब्धियाँ क्या हैं?  ',
          'सध्याच्या किंवा मागील करिअरमध्ये तुम्हाला किती अनुभव आहे? तुमची मुख्य कामे किंवा उपलब्धी कोणत्या आहेत?',
        ),
        CareerQuestion(
          'Why change careers: interest, growth, income, security, burnout, changing priorities, or limited opportunities?',
          'आप करियर क्यों बदलना चाहते हैं—रुचि, तरक्की, कमाई, सुरक्षा, काम से थकान, बदली प्राथमिकताएँ या कम अवसर?  ',
          'तुम्हाला करिअर का बदलायचे आहे—आवड, प्रगती, उत्पन्न, सुरक्षितता, कामाचा थकवा, बदललेली प्राधान्ये की कमी संधी?',
        ),
        CareerQuestion(
          'What do you dislike about your current career, and what would you want to be different next time?',
          'अभी के करियर में आपको क्या पसंद नहीं है? अगले करियर में आप क्या अलग चाहते हैं?  ',
          'सध्याच्या करिअरमध्ये तुम्हाला काय आवडत नाही? पुढील करिअरमध्ये काय वेगळे हवे आहे?',
        ),
      ],
      [
        CareerQuestion(
          'Which fields or work types interest you for your next career? If unsure, write “Not sure”.',
          'अगले करियर के लिए किन क्षेत्रों या तरह के कामों में रुचि है? तय नहीं है, तो “अभी तय नहीं” लिखें।  ',
          'पुढील करिअरसाठी कोणत्या क्षेत्रांत किंवा प्रकारच्या कामांत रस आहे? ठरले नसेल, तर “अजून ठरलेले नाही” लिहा.',
        ),
        CareerQuestion(
          'Which activities would you most enjoy in your next career?',
          'अगले करियर में आप कौन-से काम सबसे ज़्यादा करना चाहेंगे?  ',
          'पुढील करिअरमध्ये तुम्हाला कोणती कामे सर्वात जास्त करायला आवडतील?',
        ),
        CareerQuestion(
          'What are your top three priorities: income, security, growth, work-life balance, flexibility, creativity, impact, independence, or remote work?',
          'आपके लिए सबसे ज़रूरी तीन बातें क्या हैं—कमाई, सुरक्षा, तरक्की, काम-जीवन संतुलन, समय की छूट, रचनात्मकता, लोगों पर अच्छा असर, आज़ादी या घर से काम?  ',
          'तुमच्यासाठी सर्वात महत्त्वाच्या तीन गोष्टी कोणत्या—उत्पन्न, सुरक्षितता, प्रगती, काम-जीवन समतोल, वेळेची मोकळीक, सर्जनशीलता, लोकांवर चांगला परिणाम, स्वातंत्र्य की घरून काम?',
        ),
        CareerQuestion(
          'What would your ideal working life look like in 3–5 years, and what would success mean to you?',
          'अगले 3–5 साल में आप कैसी कामकाजी ज़िंदगी चाहते हैं? आपके लिए सफलता का क्या मतलब है?  ',
          'पुढील 3–5 वर्षांत तुम्हाला कसे कामाचे आयुष्य हवे आहे? तुमच्यासाठी यशाचा अर्थ काय आहे?',
        ),
      ],
      [
        CareerQuestion(
          'Which skills could transfer to another career? Include technical, analytical, communication, leadership, creative, or organizational skills.',
          'आपके कौन-से कौशल दूसरे करियर में भी काम आ सकते हैं—तकनीकी, विश्लेषण, बातचीत, नेतृत्व, रचनात्मक या योजना बनाने के कौशल?  ',
          'तुमची कोणती कौशल्ये दुसऱ्या करिअरमध्येही उपयोगी पडू शकतात—तांत्रिक, विश्लेषण, संवाद, नेतृत्व, सर्जनशील किंवा नियोजनाची कौशल्ये?',
        ),
        CareerQuestion(
          'What are your strongest abilities? Give specific examples.',
          'आपकी सबसे मज़बूत क्षमताएँ कौन-सी हैं? ठोस उदाहरण दें।  ',
          'तुमच्या सर्वात मजबूत क्षमता कोणत्या आहेत? ठोस उदाहरणे द्या.',
        ),
        CareerQuestion(
          'Which degrees, qualifications, certificates, tools, software, or specialist knowledge do you already have?',
          'आपके पास कौन-सी डिग्री, योग्यता, प्रमाणपत्र, औज़ार चलाने का कौशल, सॉफ्टवेयर का ज्ञान या खास जानकारी है?  ',
          'तुमच्याकडे कोणती पदवी, पात्रता, प्रमाणपत्रे, साधने वापरण्याचे कौशल्य, सॉफ्टवेअरचे ज्ञान किंवा विशेष माहिती आहे?',
        ),
        CareerQuestion(
          'Which achievements are you proud of, and what did they teach you about the work you do well?',
          'आपको अपनी किन उपलब्धियों पर गर्व है? उनसे आपको अपने अच्छे कौशलों के बारे में क्या पता चला?  ',
          'तुम्हाला कोणत्या उपलब्धींचा अभिमान आहे? त्यातून तुमच्या चांगल्या कौशल्यांबद्दल काय समजले?',
        ),
      ],
      [
        CareerQuestion(
          'Have you considered specific careers or roles for the transition? What attracts you to them?',
          'क्या आपने नए करियर की कुछ नौकरियों या भूमिकाओं के बारे में सोचा है? वे आपको क्यों पसंद हैं?  ',
          'नवीन करिअरमधील काही नोकऱ्या किंवा भूमिकांचा तुम्ही विचार केला आहे का? त्या तुम्हाला का आवडतात?',
        ),
        CareerQuestion(
          'Which skills, qualifications, or experience do you think you need for the new career? If unsure, write “Not sure”.',
          'नए करियर के लिए आपको कौन-से कौशल, योग्यता या अनुभव चाहिए? पता न हो, तो “अभी पता नहीं” लिखें।  ',
          'नवीन करिअरसाठी तुम्हाला कोणती कौशल्ये, पात्रता किंवा अनुभव आवश्यक आहेत? माहीत नसेल, तर “अजून माहीत नाही” लिहा.',
        ),
        CareerQuestion(
          'Would you consider courses, certificates, projects, internships, or entry-level roles to transition?',
          'क्या आप करियर बदलने के लिए कोर्स, प्रमाणपत्र, प्रोजेक्ट, इंटर्नशिप या शुरुआती स्तर की नौकरी करने को तैयार हैं?  ',
          'करिअर बदलण्यासाठी तुम्ही अभ्यासक्रम, प्रमाणपत्र, प्रकल्प, इंटर्नशिप किंवा सुरुवातीच्या स्तरावरील नोकरी करण्यास तयार आहात का?',
        ),
        CareerQuestion(
          'How much time and money can you invest, and when would you like to transition?',
          'आप सीखने या प्रशिक्षण पर कितना समय और पैसा लगा सकते हैं? आप कब तक नया करियर शुरू करना चाहते हैं?  ',
          'शिकण्यासाठी किंवा प्रशिक्षणासाठी तुम्ही किती वेळ आणि पैसा देऊ शकता? तुम्हाला नवीन करिअर कधीपर्यंत सुरू करायचे आहे?',
        ),
      ],
      [
        CareerQuestion(
          'What is your current income situation and the minimum monthly income needed during the transition?',
          'अभी आपकी कमाई की स्थिति क्या है? करियर बदलते समय हर महीने कम से कम कितनी कमाई चाहिए?  ',
          'सध्या तुमची उत्पन्नाची स्थिती काय आहे? करिअर बदलताना दरमहा किमान किती उत्पन्न हवे आहे?',
        ),
        CareerQuestion(
          'How would you prefer to transition: change jobs, learn while employed, freelance part-time, retrain first, start entry-level, or start a business?',
          'आप करियर कैसे बदलना चाहेंगे—नौकरी बदलकर, नौकरी के साथ सीखकर, पार्ट-टाइम फ्रीलांस काम करके, पहले प्रशिक्षण लेकर, शुरुआती नौकरी करके या अपना व्यवसाय शुरू करके?  ',
          'तुम्हाला करिअर कसे बदलायचे आहे—नोकरी बदलून, नोकरीसोबत शिकून, अर्धवेळ फ्रीलान्स काम करून, आधी प्रशिक्षण घेऊन, सुरुवातीची नोकरी करून की स्वतःचा व्यवसाय सुरू करून?',
        ),
        CareerQuestion(
          'What practical constraints affect the transition: family, money, time, location, relocation, accessibility, or work authorization?',
          'करियर बदलने में परिवार, पैसे, समय, जगह, दूसरे शहर जाना, काम करने की सुविधा या काम की अनुमति जैसी कौन-सी बातें असर डालती हैं?  ',
          'करिअर बदलताना कुटुंब, पैसा, वेळ, ठिकाण, दुसऱ्या शहरात जाणे, कामाच्या सोयी किंवा कामाची परवानगी यांपैकी कोणत्या गोष्टींचा परिणाम होतो?',
        ),
        CareerQuestion(
          'What conditions are non-negotiable, and which trade-offs would you consider for a better-fitting career?',
          'कौन-सी शर्तें आपके लिए ज़रूरी हैं और जिनसे समझौता नहीं कर सकते? बेहतर करियर के लिए किन बातों में बदलाव करने को तैयार हैं?  ',
          'कोणत्या अटी तुमच्यासाठी आवश्यक आहेत आणि त्यात तडजोड करू शकत नाही? अधिक योग्य करिअरसाठी कोणत्या गोष्टी बदलायला तयार आहात?',
        ),
      ],
    ],
  ),
];
