import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/providers/profile_provider.dart';

/// State for the category-based career onboarding flow.
///
/// The previous generic questions (name, wake time, fears, etc.) are not part
/// of this model. The active questionnaire is represented by six categories,
/// each with twenty stable answer keys such as `c1_g1_q1` through `c6_g5_q4`.
/// This lets each category retain its own answers and resume position.
class OnboardingData {
  static const int categoryCount = 6;
  static const int questionsPerCategory = 20;
  static const int groupsPerCategory = 5;
  static const int questionsPerGroup = 4;
  static const int payloadVersion = 2;

  /// Language selected on the screen before category selection (en, hi, mr).
  final String preferredLanguage;

  /// Structured, versioned questionnaire state. Its canonical format is:
  /// {
  ///   version, language, category, selectedCategoryTitle, answers,
  ///   responses, progress
  /// }
  final Map<String, dynamic> careerOnboardingPayload;

  const OnboardingData({
    this.preferredLanguage = 'en',
    this.careerOnboardingPayload = const <String, dynamic>{},
  });

  bool get hasCareerOnboardingPayload =>
      careerOnboardingPayload['version'] == payloadVersion;

  /// Selected category index (0-5), or null until the user chooses one.
  int? get selectedCareerCategoryIndex {
    final raw = careerOnboardingPayload['category'];
    final value = raw is int ? raw : int.tryParse(raw?.toString() ?? '');
    if (value == null || value < 0 || value >= categoryCount) return null;
    return value;
  }

  String get selectedCareerCategoryTitle =>
      careerOnboardingPayload['selectedCategoryTitle']?.toString() ?? '';

  String get onboardingLanguage {
    final fromPayload = careerOnboardingPayload['language']?.toString().trim();
    if (fromPayload != null && fromPayload.isNotEmpty) return fromPayload;
    return preferredLanguage;
  }

  /// All answered question fields, e.g. `c1_g1_q1` -> user's answer.
  Map<String, String> get careerQuestionAnswers {
    final raw = careerOnboardingPayload['answers'];
    if (raw is! Map) return const <String, String>{};
    return raw.map(
      (key, value) => MapEntry(key.toString(), value?.toString() ?? ''),
    );
  }

  /// Answers organized per category. Each category always exposes all 20
  /// question fields (`g1_q1` ... `g5_q4`); unanswered fields are empty strings.
  /// This gives downstream systems a stable 6 x 20 schema.
  Map<int, Map<String, String>> get answersByCategory {
    final answers = careerQuestionAnswers;
    final result = <int, Map<String, String>>{};
    for (var category = 0; category < categoryCount; category++) {
      final fields = <String, String>{};
      for (var group = 1; group <= groupsPerCategory; group++) {
        for (var question = 1; question <= questionsPerGroup; question++) {
          final field = 'g${group}_q$question';
          final answerKey = 'c${category + 1}_g${group}_q$question';
          fields[field] = answers[answerKey] ?? '';
        }
      }
      result[category] = fields;
    }
    return result;
  }

  /// Complete question/answer rows, including readable question text for AI.
  List<Map<String, String>> get careerResponses {
    final raw = careerOnboardingPayload['responses'];
    if (raw is! List) return const <Map<String, String>>[];

    final result = <Map<String, String>>[];
    for (final item in raw) {
      if (item is! Map) continue;
      final row = <String, String>{};
      for (final key in const <String>[
        'category',
        'group',
        'question',
        'answer',
        'field',
      ]) {
        final value = item[key];
        if (value != null) row[key] = value.toString();
      }
      if (row['question']?.trim().isNotEmpty == true &&
          row['answer']?.trim().isNotEmpty == true) {
        result.add(row);
      }
    }
    return result;
  }

  /// Current/resume group for each category. Progress values are 1-5;
  /// onboarding_step in the profile row stores the currently visible page.
  Map<int, int> get careerCategoryProgress {
    final raw = careerOnboardingPayload['progress'];
    if (raw is! Map) return const <int, int>{};

    final result = <int, int>{};
    raw.forEach((key, value) {
      final category = int.tryParse(key.toString());
      final page = value is int ? value : int.tryParse(value.toString());
      if (category == null ||
          category < 0 ||
          category >= categoryCount ||
          page == null) {
        return;
      }
      result[category] = page.clamp(1, groupsPerCategory).toInt();
    });
    return result;
  }

  /// Answers for one selected category, returned as group/question fields.
  Map<String, String> answersForCategory(int categoryIndex) {
    if (categoryIndex < 0 || categoryIndex >= categoryCount) {
      return const <String, String>{};
    }
    return answersByCategory[categoryIndex] ?? const <String, String>{};
  }

  /// Build a new model with the supplied questionnaire payload.
  OnboardingData copyWithCareerOnboardingPayload(
    Map<String, dynamic> payload,
  ) {
    final normalized = <String, dynamic>{
      'version': payloadVersion,
      'language': onboardingLanguage,
      ...payload,
    };
    return copyWith(careerOnboardingPayload: normalized);
  }

  factory OnboardingData.fromJson(Map<String, dynamic> json) {
    final parsedLanguage = _asString(
      json['preferred_language'] ??
          json['onboarding_language'] ??
          json['preferredLanguage'],
    ).trim();

    Map<String, dynamic> payload = <String, dynamic>{};

    // Current schema: an object stored directly in onboarding_data.
    final structuredPayload = json['career_onboarding'];
    if (structuredPayload is Map) {
      payload = Map<String, dynamic>.from(structuredPayload);
    }

    // Also accept a nested `careerOnboardingPayload` key for local/test data.
    if (payload.isEmpty && json['careerOnboardingPayload'] is Map) {
      payload = Map<String, dynamic>.from(
        json['careerOnboardingPayload'] as Map,
      );
    }

    // Migration support for progress saved by the immediately previous screen
    // version, which encoded the new questionnaire in `anything_else`.
    if (payload.isEmpty) {
      final legacyContainer = _asString(json['anything_else']);
      const oldPrefix = '__EVOLYN_CAREER_ONBOARDING_V2__:';
      if (legacyContainer.startsWith(oldPrefix)) {
        try {
          final decoded = jsonDecode(legacyContainer.substring(oldPrefix.length));
          if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
        } on FormatException {
          // Ignore malformed questionnaire metadata; allow a fresh start.
        }
      }
    }

    if (payload.isNotEmpty) {
      payload['version'] = payload['version'] ?? payloadVersion;
      if (_asString(payload['language']).trim().isEmpty &&
          parsedLanguage.isNotEmpty) {
        payload['language'] = parsedLanguage;
      }
    }

    return OnboardingData(
      preferredLanguage: parsedLanguage.isNotEmpty
          ? parsedLanguage
          : _asString(payload['language']).trim().isNotEmpty
              ? _asString(payload['language'])
              : 'en',
      careerOnboardingPayload: payload,
    );
  }

  static String _asString(dynamic value) => value?.toString() ?? '';

  OnboardingData copyWith({
    String? preferredLanguage,
    Map<String, dynamic>? careerOnboardingPayload,
  }) {
    return OnboardingData(
      preferredLanguage: preferredLanguage ?? this.preferredLanguage,
      careerOnboardingPayload:
          careerOnboardingPayload ?? this.careerOnboardingPayload,
    );
  }

  Map<String, dynamic> toJson() {
    final payload = <String, dynamic>{
      'version': payloadVersion,
      'language': onboardingLanguage,
      ...careerOnboardingPayload,
    };
    final hasPayload = payload['category'] != null ||
        (payload['answers'] is Map &&
            (payload['answers'] as Map).isNotEmpty);

    final responses = careerResponses;
    return <String, dynamic>{
      'preferred_language': preferredLanguage,
      'onboarding_language': onboardingLanguage,
      if (hasPayload) ...<String, dynamic>{
        'career_onboarding': payload,
        'career_responses': responses,
        'selected_career_category': selectedCareerCategoryTitle,
        'career_category_index': selectedCareerCategoryIndex,
        'career_question_answers': careerQuestionAnswers,
        'career_answers_by_category': answersByCategory.map(
          (key, value) => MapEntry(key.toString(), value),
        ),
      },
    };
  }
}

final onboardingProvider =
    NotifierProvider<OnboardingNotifier, OnboardingData>(
  OnboardingNotifier.new,
);

class OnboardingNotifier extends Notifier<OnboardingData> {
  @override
  OnboardingData build() => const OnboardingData();

  void update(OnboardingData data) {
    state = data;
  }

  void restore(OnboardingData data) {
    state = data;
  }

  /// Saves the current questionnaire state and active screen/page index.
  /// Step 0 means category selection; steps 1-5 are question groups.
  Future<void> saveStep(int step) async {
    final repository = ref.read(profileRepositoryProvider);
    await repository.saveOnboardingStep(
      data: state.toJson(),
      step: step,
    );
  }

  void updateCareerOnboardingPayload(Map<String, dynamic> payload) {
    state = state.copyWithCareerOnboardingPayload(payload);
  }

  void updatePreferredLanguage(String language) {
    final updatedPayload = <String, dynamic>{
      ...state.careerOnboardingPayload,
      'language': language,
    };
    state = state.copyWith(
      preferredLanguage: language,
      careerOnboardingPayload: updatedPayload,
    );
  }
}
