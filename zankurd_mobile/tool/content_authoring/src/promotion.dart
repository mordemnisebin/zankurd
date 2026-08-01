import '../../question_quality/src/normalization.dart';

class PromotionCandidate {
  const PromotionCandidate({
    required this.row,
    required this.id,
    required this.locale,
    required this.category,
    required this.prompt,
    required this.options,
    required this.correctOption,
    required this.explanation,
    required this.difficulty,
    required this.sourceVerified,
    required this.sourceUrl,
    required this.publicationStatus,
    required this.issueType,
    this.confidence,
    this.reviewNotes = '',
  });

  final int row;
  final String id;
  final String locale;
  final String category;
  final String prompt;
  final List<String> options;
  final String correctOption;
  final String explanation;
  final int? difficulty;
  final String sourceVerified;
  final String sourceUrl;
  final String publicationStatus;
  final String issueType;
  final double? confidence;
  final String reviewNotes;

  String get canonicalKey => stableFingerprint(normalizeText(prompt));

  String get templateKey {
    final withoutQuotedTerms = prompt
        .replaceAll(RegExp(r'"[^"]*"'), ' TERM ')
        .replaceAll(RegExp("'[^']*'"), ' TERM ')
        .replaceAll(RegExp(r'[«“][^»”]+[»”]'), ' TERM ');
    final withoutNumbers = withoutQuotedTerms.replaceAll(
      RegExp(r'\b\d+\b'),
      ' NUM ',
    );
    return normalizeText(withoutNumbers);
  }

  String get explanationKey => normalizeText(explanation);

  Map<String, Object?> toRuntimeJson() => {
    'id': id.trim(),
    'category': category.trim(),
    'prompt': prompt.trim(),
    'answers': options.map((option) => option.trim()).toList(growable: false),
    'correctAnswer': _correctText(),
    'explanation': explanation.trim(),
    'type': 'multipleChoice',
    'difficulty': difficulty,
    'metadata': {
      'reviewStatus': 'approved',
      'dialect': 'Kurmancî',
      'sourceReference': sourceUrl.trim(),
      'qualityVersion': 1,
    },
  };

  String _correctText() {
    final letter = 'ABCD'.indexOf(correctOption.trim().toUpperCase());
    if (letter >= 0 && letter < options.length) return options[letter].trim();
    return correctOption.trim();
  }
}

class PromotionResult {
  const PromotionResult({
    required this.targetCount,
    required this.activeCount,
    required this.accepted,
    required this.rejectedByReason,
    required this.rejectionRows,
    required this.categoryDistribution,
    required this.difficultyDistribution,
  });

  final int targetCount;
  final int activeCount;
  final List<PromotionCandidate> accepted;
  final Map<String, int> rejectedByReason;
  final Map<String, List<int>> rejectionRows;
  final Map<String, int> categoryDistribution;
  final Map<String, int> difficultyDistribution;

  int get totalAfterPromotion => activeCount + accepted.length;

  int get remainingToTarget =>
      (targetCount - totalAfterPromotion).clamp(0, targetCount);

  bool get shouldWriteExpandedBank => accepted.isNotEmpty;

  Map<String, Object?> get manifest => {
    'target_count': targetCount,
    'active_count': activeCount,
    'accepted_count': accepted.length,
    'total_after_promotion': totalAfterPromotion,
    'remaining_to_target': remainingToTarget,
    'expanded_questions': shouldWriteExpandedBank,
    'rejected_by_reason': rejectedByReason,
    'rejection_row_samples': {
      for (final entry in rejectionRows.entries)
        entry.key: entry.value.take(8).toList(growable: false),
    },
    'category_distribution': categoryDistribution,
    'difficulty_distribution': difficultyDistribution,
  };
}

PromotionResult promoteCandidates({
  required List<PromotionCandidate> candidates,
  required List<PromotionCandidate> active,
  required int targetCount,
  int maxTemplatePerShape = 3,
  int maxPerCategory = 2000,
  int maxPerDifficulty = 6000,
}) {
  final activeCanonical = active
      .map((candidate) => candidate.canonicalKey)
      .toSet();
  final activeIds = active.map((candidate) => candidate.id.trim()).toSet();
  final activeTemplates = _counts(
    active.map((candidate) => candidate.templateKey),
  );
  final activeExplanations = _counts(
    active.map((candidate) => candidate.explanationKey),
  );
  final seenIds = <String>{...activeIds};
  final seenCanonical = <String>{...activeCanonical};
  final templateCounts = <String, int>{...activeTemplates};
  final explanationCounts = <String, int>{...activeExplanations};
  final categoryCounts = <String, int>{};
  final difficultyCounts = <String, int>{};
  final accepted = <PromotionCandidate>[];
  final rejectedByReason = <String, int>{};
  final rejectionRows = <String, List<int>>{};

  for (final candidate in candidates) {
    final reasons = _rejectionReasons(
      candidate,
      seenIds: seenIds,
      seenCanonical: seenCanonical,
      templateCounts: templateCounts,
      explanationCounts: explanationCounts,
      categoryCounts: categoryCounts,
      difficultyCounts: difficultyCounts,
      maxTemplatePerShape: maxTemplatePerShape,
      maxPerCategory: maxPerCategory,
      maxPerDifficulty: maxPerDifficulty,
    );
    if (reasons.isNotEmpty) {
      for (final reason in reasons) {
        rejectedByReason[reason] = (rejectedByReason[reason] ?? 0) + 1;
        rejectionRows.putIfAbsent(reason, () => []).add(candidate.row);
      }
      continue;
    }

    accepted.add(candidate);
    seenIds.add(candidate.id.trim());
    seenCanonical.add(candidate.canonicalKey);
    _increment(templateCounts, candidate.templateKey);
    _increment(explanationCounts, candidate.explanationKey);
    _increment(categoryCounts, candidate.category.trim());
    _increment(difficultyCounts, '${candidate.difficulty}');
  }

  return PromotionResult(
    targetCount: targetCount,
    activeCount: activeCanonical.length,
    accepted: List.unmodifiable(accepted),
    rejectedByReason: Map.unmodifiable(rejectedByReason),
    rejectionRows: Map<String, List<int>>.unmodifiable({
      for (final entry in rejectionRows.entries)
        entry.key: List<int>.unmodifiable(entry.value),
    }),
    categoryDistribution: _sortedCounts(categoryCounts),
    difficultyDistribution: _sortedCounts(difficultyCounts),
  );
}

List<String> _rejectionReasons(
  PromotionCandidate candidate, {
  required Set<String> seenIds,
  required Set<String> seenCanonical,
  required Map<String, int> templateCounts,
  required Map<String, int> explanationCounts,
  required Map<String, int> categoryCounts,
  required Map<String, int> difficultyCounts,
  required int maxTemplatePerShape,
  required int maxPerCategory,
  required int maxPerDifficulty,
}) {
  final reasons = <String>[];
  final id = candidate.id.trim();
  final category = candidate.category.trim();
  final explanation = candidate.explanation.trim();
  final options = candidate.options.map(normalizeOption).toList();

  if (id.isEmpty) reasons.add('missing_id');
  if (id.isNotEmpty && seenIds.contains(id)) reasons.add('duplicate_id');
  if (candidate.prompt.trim().isEmpty) reasons.add('empty_prompt');
  if (candidate.prompt.trim().isNotEmpty && _wordCount(candidate.prompt) < 5) {
    reasons.add('prompt_too_simple');
  }
  if (candidate.prompt.trim().isNotEmpty &&
      seenCanonical.contains(candidate.canonicalKey)) {
    reasons.add('canonical_duplicate');
  }
  if (options.length != 4 || options.any((option) => option.isEmpty)) {
    reasons.add('invalid_options');
  } else if (options.toSet().length != options.length) {
    reasons.add('duplicate_option');
  }
  if (!_correctResolves(candidate, options)) {
    reasons.add('invalid_correct_answer');
  }
  if (explanation.isEmpty || explanation.length < 24) {
    reasons.add('short_explanation');
  }
  if (_explanationRepeatsAnswer(candidate, explanation)) {
    reasons.add('explanation_repeats_answer');
  }
  if (_templateExplanation(explanation)) reasons.add('explanation_template');
  if (explanation.isNotEmpty &&
      (explanationCounts[candidate.explanationKey] ?? 0) > 0) {
    reasons.add('explanation_duplicate');
  }
  if (candidate.locale.trim().toLowerCase() != 'ku-kmr') {
    reasons.add('unsupported_locale');
  }
  if (_answerLanguageMismatch(candidate)) {
    reasons.add('answer_language_mismatch');
  }
  if (candidate.difficulty == null) {
    reasons.add('missing_difficulty');
  } else if (candidate.difficulty! < 1 || candidate.difficulty! > 3) {
    reasons.add('invalid_difficulty');
  }
  if (candidate.confidence == null) {
    reasons.add('missing_confidence');
  } else if (candidate.confidence! < 0.9) {
    reasons.add('low_confidence');
  }
  if (!_verified(candidate.sourceVerified)) reasons.add('unverified_source');
  if (!_httpsUrl(candidate.sourceUrl)) reasons.add('missing_source_url');
  if (!_publishableStatus(candidate.publicationStatus)) {
    reasons.add('unpublishable_status');
  }
  if (_unresolvedIssue('${candidate.issueType} ${candidate.reviewNotes}')) {
    reasons.add('editorial_issue');
  }
  if ((templateCounts[candidate.templateKey] ?? 0) >= maxTemplatePerShape) {
    reasons.add('template_density');
  }
  if (category.isEmpty) {
    reasons.add('missing_category');
  } else if ((categoryCounts[category] ?? 0) >= maxPerCategory) {
    reasons.add('category_distribution');
  }
  final difficultyKey = '${candidate.difficulty}';
  if (candidate.difficulty != null &&
      (difficultyCounts[difficultyKey] ?? 0) >= maxPerDifficulty) {
    reasons.add('difficulty_distribution');
  }
  return reasons;
}

bool _correctResolves(PromotionCandidate candidate, List<String> options) {
  final raw = candidate.correctOption.trim();
  final letter = 'ABCD'.indexOf(raw.toUpperCase());
  if (letter >= 0) return letter < options.length;
  final normalized = normalizeOption(raw);
  return normalized.isNotEmpty &&
      options.where((option) => option == normalized).length == 1;
}

bool _explanationRepeatsAnswer(
  PromotionCandidate candidate,
  String explanation,
) {
  final answer = _correctText(candidate);
  if (answer.isEmpty) return false;
  final normalizedAnswer = normalizeText(answer);
  final normalizedExplanation = normalizeText(explanation);
  if (normalizedExplanation == normalizedAnswer) return true;
  return normalizedExplanation.startsWith('$normalizedAnswer ') &&
      normalizedExplanation.length <= normalizedAnswer.length + 18;
}

String _correctText(PromotionCandidate candidate) {
  final index = 'ABCD'.indexOf(candidate.correctOption.trim().toUpperCase());
  if (index >= 0 && index < candidate.options.length) {
    return candidate.options[index];
  }
  return candidate.correctOption;
}

bool _templateExplanation(String value) {
  final normalized = normalizeText(value);
  const patterns = <String>[
    'bu sorunun cevabi',
    'dogru cevap',
    'doğru cevap',
    'doğru yanıt',
    'cevap sudur',
    'the correct answer',
    'answer is',
    'as an ai',
    'lorem ipsum',
    'placeholder',
  ];
  return patterns.any(normalized.contains);
}

bool _answerLanguageMismatch(PromotionCandidate candidate) {
  final text = normalizeText(
    [candidate.prompt, ...candidate.options, candidate.explanation].join(' '),
  );
  const turkishWords = <String>[
    'aşağıdakilerden',
    'hangisidir',
    'anlamına gelir',
    'doğru cevap',
    'cevabı',
    'hangi',
    'nedir',
    'değil',
  ];
  if (turkishWords.any((word) => _wholeWord(text, word))) return true;
  return text.contains('ğ') || text.contains('ı');
}

bool _wholeWord(String text, String word) => RegExp(
  r'(^|[^\p{L}\p{N}_])' + RegExp.escape(word) + r'($|[^\p{L}\p{N}_])',
  unicode: true,
).hasMatch(text);

bool _verified(String value) => const {
  'verified',
  'doğrulandı',
  'dogrulandi',
  'evet',
  'yes',
  'true',
}.contains(normalizeText(value));

bool _httpsUrl(String value) =>
    RegExp(r'^https://[^\s]+$').hasMatch(value.trim());

bool _publishableStatus(String value) =>
    const {'reviewed', 'approved', 'published'}.contains(normalizeText(value));

bool _unresolvedIssue(String value) {
  final issue = normalizeText(value);
  if (issue.isEmpty) return false;
  const unresolved = <String>[
    'şablon',
    'tekrar',
    'doğrulanamadı',
    'belirsiz',
    'ideolojik',
    'genelleme',
    'aşırı',
    'güncelliğini',
    'kaynak',
  ];
  return unresolved.any(issue.contains);
}

Map<String, int> _counts(Iterable<String> values) {
  final result = <String, int>{};
  for (final value in values) {
    if (value.isEmpty) continue;
    _increment(result, value);
  }
  return result;
}

void _increment(Map<String, int> values, String key) {
  values[key] = (values[key] ?? 0) + 1;
}

Map<String, int> _sortedCounts(Map<String, int> values) => Map.unmodifiable({
  for (final key in values.keys.toList()..sort()) key: values[key]!,
});

int _wordCount(String value) =>
    value.trim().split(RegExp(r'\s+')).where((word) => word.isNotEmpty).length;
