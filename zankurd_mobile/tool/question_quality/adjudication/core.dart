import '../src/models.dart';
import '../src/normalization.dart';
import 'models.dart';

CorrectInterpretation interpretCorrectValue(
  String raw,
  List<String> options, {
  NumericBase numericBase = NumericBase.zeroBased,
}) {
  final value = raw.trim();
  final letter = 'ABCD'.indexOf(value.toUpperCase());
  if (letter >= 0) {
    return CorrectInterpretation(
      raw: raw,
      index: letter,
      text: letter < options.length ? options[letter] : null,
      rule: 'letter_A_to_D',
    );
  }
  final numeric = int.tryParse(value);
  if (numeric != null) {
    final index = numericBase == NumericBase.oneBased ? numeric - 1 : numeric;
    return CorrectInterpretation(
      raw: raw,
      index: index,
      text: index >= 0 && index < options.length ? options[index] : null,
      rule: numericBase == NumericBase.oneBased
          ? 'numeric_one_based'
          : 'numeric_zero_based',
    );
  }
  final index = options.indexOf(value);
  return CorrectInterpretation(
    raw: raw,
    index: index >= 0 ? index : null,
    text: value.isEmpty ? null : value,
    rule: 'exact_option_text',
  );
}

LocateResult locateOriginalRecord(
  IssueReference issue,
  Iterable<QuestionRecord> records,
) {
  final matches = records
      .where(
        (record) =>
            record.sourcePath == issue.sourcePath &&
            record.sourceRow == issue.sourceRow &&
            (issue.recordId == null ||
                record.sourceRecordId == issue.recordId ||
                record.runtimeId == issue.recordId),
      )
      .toList();
  if (matches.isEmpty) return const LocateResult(LocateStatus.notFound, null);
  if (matches.length > 1) {
    return const LocateResult(LocateStatus.ambiguous, null);
  }
  return LocateResult(LocateStatus.located, matches.single);
}

List<SampleCandidate> deterministicSample(
  Iterable<SampleCandidate> candidates,
  Map<String, int> quotas,
) {
  final sorted = candidates.toList()
    ..sort((a, b) {
      final role = a.role.compareTo(b.role);
      if (role != 0) return role;
      final source = a.sourceId.compareTo(b.sourceId);
      if (source != 0) return source;
      final row = a.sourceRow.compareTo(b.sourceRow);
      return row != 0 ? row : a.fingerprint.compareTo(b.fingerprint);
    });
  final counts = <String, int>{};
  return sorted.where((candidate) {
    final limit = quotas[candidate.role] ?? 0;
    final count = counts[candidate.role] ?? 0;
    if (count >= limit) return false;
    counts[candidate.role] = count + 1;
    return true;
  }).toList();
}

RuntimeReachability classifyRuntimeReachability(String sourceId) =>
    switch (sourceId) {
      'offline_runtime_bank' ||
      'curated_runtime_bank' => RuntimeReachability.runtimeActive,
      'active_import_ready' => RuntimeReachability.importActiveNotRuntime,
      'wave2_publish_candidates' =>
        RuntimeReachability.publishCandidateNotRuntime,
      'wave2_quarantine' => RuntimeReachability.quarantineOnly,
      'rich_v2_csv_snapshot' ||
      'wave2_reviewed' ||
      'generated_master_csv' => RuntimeReachability.historicalOnly,
      _ => RuntimeReachability.unknown,
    };

Adjudication classifyAnswerLeak({
  required String prompt,
  required String correctText,
}) {
  final question = normalizeText(prompt);
  final answer = normalizeText(correctText);
  if (answer.length < 4 || !question.contains(answer)) {
    return Adjudication.parserFalsePositive;
  }
  if (answer == 'doğru' &&
      (question.contains('doğru anlam') || question.contains('doğru cevap'))) {
    return Adjudication.parserFalsePositive;
  }
  final quoted =
      question.contains('"$answer"') || question.contains("'$answer'");
  const exposedPatterns = <String>[
    'görsel etiketi',
    'bu görseldeki',
    'görseli',
    'hatırlatır',
  ];
  if (quoted && exposedPatterns.any(question.contains)) {
    return Adjudication.confirmedDataDefect;
  }
  const factualPatterns = <String>[
    'capital city of',
    'official or national language',
    'hangi şehir merkezliydi',
  ];
  if (factualPatterns.any(question.contains)) {
    return Adjudication.factualVerificationRequired;
  }
  const tautologyPatterns = <String>[
    'main character in',
    'carcassonne is based',
    'europa universalis is',
  ];
  if (tautologyPatterns.any(question.contains)) {
    return Adjudication.confirmedDataDefect;
  }
  const naturalPatterns = <String>['based on which', 'di hevoka'];
  if (naturalPatterns.any(question.contains)) {
    return Adjudication.parserFalsePositive;
  }
  return exposedPatterns.any(question.contains)
      ? Adjudication.confirmedDataDefect
      : Adjudication.ambiguousNeedsEditor;
}

Adjudication classifyInvalidCorrectAnswer({
  required String rawCorrect,
  required QuestionRecord record,
}) {
  final interpretation = interpretCorrectValue(rawCorrect, record.options);
  if (interpretation.index != null &&
      interpretation.index == record.correctOptionIndex &&
      interpretation.index! >= 0 &&
      interpretation.index! < record.options.length) {
    return Adjudication.parserFalsePositive;
  }
  if (int.tryParse(rawCorrect.trim()) != null) {
    final oneBased = interpretCorrectValue(
      rawCorrect,
      record.options,
      numericBase: NumericBase.oneBased,
    );
    if (oneBased.index != null &&
        oneBased.index! >= 0 &&
        oneBased.index! < record.options.length) {
      return Adjudication.sourceSchemaMismatch;
    }
  }
  return Adjudication.confirmedDataDefect;
}

String duplicateOptionForm(List<String> options) {
  bool duplicated(Iterable<String> values) {
    final list = values.toList();
    return list.toSet().length != list.length;
  }

  if (duplicated(options)) return 'exact_duplicate';
  if (duplicated(options.map((value) => value.trim()))) {
    return 'whitespace_duplicate';
  }
  if (duplicated(options.map((value) => value.trim().toLowerCase()))) {
    return 'case_only_duplicate';
  }
  if (duplicated(options.map((value) => normalizeUnicode(value).trim()))) {
    return 'unicode_composition_duplicate';
  }
  if (duplicated(options.map(normalizeText))) {
    return 'punctuation_normalization_collision';
  }
  return 'semantic_or_unknown';
}

String adjudicationCopyIdentity(QuestionRecord record) {
  final id = record.sourceRecordId?.trim();
  final prompt = normalizeText(record.prompt);
  return id != null && id.isNotEmpty
      ? 'id:$id|prompt:$prompt'
      : 'prompt:$prompt';
}
