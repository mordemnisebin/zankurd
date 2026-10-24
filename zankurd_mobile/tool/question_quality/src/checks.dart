import 'package:zankurd_mobile/src/config/retired_question_ids.dart';
import 'models.dart';
import 'near_duplicate_reviewed.dart';
import 'normalization.dart';

List<AuditIssue> runChecks(
  List<QuestionRecord> records, {
  void Function(String stage, Duration elapsed)? onProfile,
}) {
  final stopwatch = Stopwatch()..start();
  void mark(String stage) {
    onProfile?.call(stage, stopwatch.elapsed);
    stopwatch.reset();
  }

  final issues = <AuditIssue>[];
  final idsBySource = <String, Set<String>>{};
  for (final record in records) {
    void add(
      String check,
      Severity severity,
      String message, {
      String confidence = 'high',
    }) {
      issues.add(
        AuditIssue(
          checkId: check,
          severity: severity,
          record: record,
          message: message,
          confidence: confidence,
          fingerprint: stableFingerprint(
            '$check|${record.canonicalGroup}|${normalizeText(record.prompt)}|${record.sourceRecordId ?? ''}',
          ),
        ),
      );
    }

    if (record.prompt.trim().isEmpty) {
      add('empty_prompt', Severity.blocker, 'Question prompt is empty.');
    }
    if (record.questionType != 'fillInBlank' && record.options.length < 2) {
      add(
        'insufficient_options',
        Severity.blocker,
        'Question has fewer than two options.',
      );
    }
    // Boşluk doldurmada tam BİR `___` olmalı. Sıfır boşluk "neyi dolduruyorum"
    // dedirtir; ikiden fazlası (çeviri parantezine de `___` konunca olduğu
    // gibi) tek cevabın iki yere sığmasını bekler: 2026-10-21'de
    // dersler2_..._0104–0109 bu yüzden havuzdan çıkarıldı.
    // Emekli kimlik oynanmaz: kusuru zaten havuzdan çıkarılmış sorular
    // kapıyı yeniden kırmasın.
    if (record.questionType == 'fillInBlank' &&
        !isQuestionRetired(record.sourceRecordId ?? '')) {
      final blanks = fillInBlankCount(record.prompt);
      if (blanks != 1) {
        add(
          'fill_in_blank_blank_count',
          Severity.blocker,
          'fillInBlank prompt must contain exactly one ___ (found $blanks).',
        );
      }
    }
    if (record.options.any((value) => value.trim().isEmpty)) {
      add('empty_option', Severity.blocker, 'Question has an empty option.');
    }
    final normalizedOptions = record.options.map(normalizeOption).toList();
    if (normalizedOptions.toSet().length != normalizedOptions.length) {
      add(
        'duplicate_option',
        Severity.blocker,
        'Question has duplicate options.',
      );
    }
    final index = record.correctOptionIndex;
    final correct = normalizeOption(record.correctOptionText ?? '');
    final indexInvalid =
        index != null && (index < 0 || index >= record.options.length);
    final textMatches = normalizedOptions.where((value) => value == correct);
    final indexedTextMismatch =
        index != null &&
        !indexInvalid &&
        record.correctOptionText != null &&
        normalizedOptions[index] != correct;
    final unresolvedTextAnswer =
        index == null && (correct.isEmpty || textMatches.length != 1);
    final validWordOrderingAnswer =
        record.questionType == 'wordOrdering' &&
        normalizeText(record.options.join(' ')) ==
            normalizeText(record.correctOptionText ?? '');
    if (!validWordOrderingAnswer &&
        (indexInvalid || indexedTextMismatch || unresolvedTextAnswer)) {
      add(
        'invalid_correct_answer',
        Severity.blocker,
        'Correct answer does not resolve to exactly one option.',
      );
    }
    if ((record.category ?? '').trim().isEmpty) {
      add('missing_category', Severity.blocker, 'Category is missing.');
    }
    if (record.difficulty == null) {
      add('missing_difficulty', Severity.blocker, 'Difficulty is missing.');
    }
    final id = record.sourceRecordId?.trim();
    if (id == null || id.isEmpty) {
      add('missing_id', Severity.warning, 'Stable source ID is missing.');
    } else if (!idsBySource
        .putIfAbsent(record.sourceId, () => <String>{})
        .add(id)) {
      add('duplicate_id', Severity.blocker, 'Duplicate ID in the same source.');
    }
    final prompt = normalizeText(record.prompt);
    if (_hasAnswerLeak(prompt, correct)) {
      add(
        'answer_leak',
        Severity.critical,
        'Prompt contains the correct answer.',
        confidence: 'high',
      );
    }
    const turkishPatterns = <String>[
      'aşağıdakilerden',
      'hangisidir',
      'anlamına gelir',
      'görsel etiketi',
      "kurmancî'de",
      'doğru cevap',
      'ne demek',
    ];
    if (turkishPatterns.any(prompt.contains)) {
      add(
        'turkish_template',
        Severity.critical,
        'High-confidence Turkish template in Kurmancî content.',
      );
    }
    const dynamicPatterns = <String>[
      'şu anki',
      'şu anda',
      'halen',
      'bugün',
      'başkan',
      'nüfus',
      'seçim',
    ];
    final dynamicPrompt = _withoutQuotedText(prompt);
    if (dynamicPatterns.any(
      (pattern) => _containsWholeTerm(dynamicPrompt, pattern),
    )) {
      add(
        'dynamic_fact',
        Severity.warning,
        'Potentially time-sensitive fact requires source and review date.',
        confidence: 'medium',
      );
    }
    final combinedText = '$prompt ${normalizeText(record.explanation ?? '')}';
    const generatedPatterns = <String>[
      'todo',
      'placeholder',
      'lorem ipsum',
      'generated',
      'as an ai',
      '```json',
      '"correct_answer"',
      'internal prompt',
    ];
    if (generatedPatterns.any(combinedText.contains)) {
      add(
        'generated_template',
        Severity.warning,
        'Generated/template residue requires editorial review.',
        confidence: 'high',
      );
    }
    final explanation = normalizeText(record.explanation ?? '');
    if (correct.isNotEmpty && explanation == correct) {
      add(
        'explanation_answer_repeat',
        Severity.warning,
        'Explanation only repeats the correct answer.',
      );
    }
    if ((record.explanation ?? '').trim().length < 8) {
      add(
        'short_explanation',
        Severity.warning,
        'Explanation is missing or very short.',
      );
    }
    // Kaynak künyesi zorunlu değil. Varsa oyuncuya gösterilir; yoksa
    // uyarı üretilmez ve soru kaynaksız diye elenmez.
  }
  mark('structural');
  issues.addAll(
    runDuplicateChecks(
      records,
      onProfile: onProfile == null
          ? null
          : (stage, elapsed) => onProfile('duplicates_$stage', elapsed),
    ),
  );
  mark('duplicates');
  issues.sort(_compareIssues);
  mark('sort');
  return issues;
}

bool _containsWholeTerm(String text, String term) {
  final pattern = RegExp(
    r'(^|[^\p{L}\p{N}_])' + RegExp.escape(term) + r'($|[^\p{L}\p{N}_])',
    unicode: true,
  );
  return pattern.hasMatch(text);
}

String _withoutQuotedText(String text) => text
    .replaceAll(RegExp(r'"[^"]*"'), ' ')
    .replaceAll(RegExp(r'«[^»]*»'), ' ')
    .replaceAll(RegExp(r"'[^']*'"), ' ');

bool _hasAnswerLeak(String prompt, String correct) {
  if (const {'rast', 'şaş', 'rast e', 'şaş e'}.contains(correct)) return false;
  if (correct.length < 4) return false;
  final answerPattern = RegExp(r'(^|\s)' + RegExp.escape(correct) + r'($|\s)');
  if (!answerPattern.hasMatch(prompt)) return false;

  if (correct == 'doğru' &&
      (prompt.contains('doğru anlam') || prompt.contains('doğru cevap'))) {
    return false;
  }

  if (prompt.contains('di hevoka')) {
    final quotedExamples = RegExp(r'"[^"]*"').allMatches(prompt);
    if (quotedExamples.any(
      (match) => answerPattern.hasMatch(match.group(0)!),
    )) {
      return false;
    }
  }
  return true;
}

List<AuditIssue> runDuplicateChecks(
  List<QuestionRecord> records, {
  void Function(String stage, Duration elapsed)? onProfile,
  DuplicateDiagnostics? diagnostics,
}) {
  final stopwatch = Stopwatch()..start();
  void mark(String stage) {
    onProfile?.call(stage, stopwatch.elapsed);
    stopwatch.reset();
  }

  final issues = <AuditIssue>[];
  final exact = <String, List<QuestionRecord>>{};
  for (final record in records) {
    exact
        .putIfAbsent(
          '${record.sourceId}|${normalizeText(record.prompt)}',
          () => [],
        )
        .add(record);
  }
  for (final group in exact.values.where((items) => items.length > 1)) {
    for (final record in group.skip(1)) {
      issues.add(
        _duplicateIssue(
          record,
          'exact_duplicate',
          Severity.critical,
          'Exact normalized duplicate.',
        ),
      );
    }
  }
  mark('exact');
  final buckets = <String, List<QuestionRecord>>{};
  final normalizedPrompts = <QuestionRecord, String>{};
  final tokenSets = <QuestionRecord, Set<String>>{};
  final nearFingerprints = <String>{};
  for (final record in records) {
    final normalized = normalizeText(record.prompt);
    normalizedPrompts[record] = normalized;
    tokenSets[record] = _tokensFromNormalized(normalized);
    diagnostics?.tokenizationCount++;
    final tokens = normalized.split(' ');
    final firstToken = tokens.isEmpty ? '' : tokens.first;
    final lengthBucket = normalized.length ~/ 20;
    final key = records.length <= 16
        ? normalizeText(record.category ?? '')
        : '${normalizeText(record.category ?? '')}|$firstToken|$lengthBucket';
    buckets.putIfAbsent(key, () => []).add(record);
  }
  mark('buckets');
  for (final candidates in buckets.values) {
    candidates.sort(
      (a, b) => '${a.sourcePath}|${a.sourceRow}'.compareTo(
        '${b.sourcePath}|${b.sourceRow}',
      ),
    );
    final comparisonWindow = candidates.length > 500 ? 12 : candidates.length;
    for (var i = 0; i < candidates.length; i++) {
      final end = (i + comparisonWindow).clamp(0, candidates.length);
      for (var j = i + 1; j < end; j++) {
        final a = candidates[i];
        final b = candidates[j];
        if (normalizedPrompts[a] == normalizedPrompts[b]) continue;
        final lengthRatio =
            a.prompt.length / (b.prompt.isEmpty ? 1 : b.prompt.length);
        if (lengthRatio < 0.55 || lengthRatio > 1.8) continue;
        final aFocus = _firstQuotedFocus(a.prompt);
        final bFocus = _firstQuotedFocus(b.prompt);
        if (aFocus.isNotEmpty && bFocus.isNotEmpty && aFocus != bFocus) {
          continue;
        }
        if (a.questionType == 'trueFalse' && b.questionType == 'trueFalse') {
          final aCorrect = normalizeText(a.correctOptionText ?? '');
          final bCorrect = normalizeText(b.correctOptionText ?? '');
          if (aCorrect.isNotEmpty &&
              bCorrect.isNotEmpty &&
              aCorrect != bCorrect) {
            continue;
          }
        }
        final similarity = _jaccardSets(tokenSets[a]!, tokenSets[b]!);
        if (similarity >= 0.55) {
          final partnerId =
              a.sourceRecordId ?? a.runtimeId ?? a.canonicalId ?? 'unknown';
          final issue = _duplicateIssue(
            b,
            'near_duplicate_candidate',
            Severity.warning,
            'Near duplicate candidate; similar to '
                '${a.sourcePath}:${a.sourceRow} ($partnerId); '
                'jaccard=${similarity.toStringAsFixed(3)}.',
            confidence: 'medium',
            fingerprint: nearDuplicatePairFingerprint(a, b),
          );
          // Jüriyle incelenip "farklı bilgi" denen çift bir daha uyarı
          // üretmez; soru metni değişirse parmak izi değişir ve çift
          // yeniden incelemeye düşer (bkz. near_duplicate_reviewed.dart).
          if (reviewedNearDuplicates.containsKey(issue.fingerprint)) continue;
          if (nearFingerprints.add(issue.fingerprint)) {
            issues.add(issue);
          }
        }
      }
    }
  }
  mark('near');
  issues.sort(_compareIssues);
  mark('sort');
  return issues;
}

String nearDuplicateMemberSignature(QuestionRecord r) => [
  r.canonicalGroup,
  normalizeText(r.prompt),
  normalizeText(r.correctOptionText ?? ''),
  r.options.map(normalizeText).join('\x1f'),
  normalizeText(r.explanation ?? ''),
].join('|');

String nearDuplicatePairFingerprint(QuestionRecord a, QuestionRecord b) {
  final sigs = [
    nearDuplicateMemberSignature(a),
    nearDuplicateMemberSignature(b),
  ]..sort();
  return stableFingerprint('near_duplicate_candidate|${sigs.join('||')}');
}

AuditIssue _duplicateIssue(
  QuestionRecord record,
  String id,
  Severity severity,
  String message, {
  String confidence = 'high',
  String? fingerprint,
}) => AuditIssue(
  checkId: id,
  severity: severity,
  record: record,
  message: message,
  confidence: confidence,
  fingerprint:
      fingerprint ??
      stableFingerprint(
        '$id|${record.canonicalGroup}|${normalizeText(record.prompt)}',
      ),
);

class DuplicateDiagnostics {
  int tokenizationCount = 0;
}

Set<String> _tokensFromNormalized(String value) => value
    .split(RegExp(r'[^\p{L}\p{N}]+', unicode: true))
    .where((token) => token.isNotEmpty)
    .toSet();

String _firstQuotedFocus(String prompt) {
  final match = RegExp(r'"([^"]+)"|“([^”]+)”').firstMatch(prompt);
  return normalizeText(match?.group(1) ?? match?.group(2) ?? '');
}

double _jaccardSets(Set<String> a, Set<String> b) {
  if (a.isEmpty || b.isEmpty) return 0;
  return a.intersection(b).length / a.union(b).length;
}

int _compareIssues(AuditIssue a, AuditIssue b) {
  final severity = a.severity.rank.compareTo(b.severity.rank);
  if (severity != 0) return severity;
  final source = a.record.sourceId.compareTo(b.record.sourceId);
  if (source != 0) return source;
  final path = a.record.sourcePath.compareTo(b.record.sourcePath);
  if (path != 0) return path;
  final row = a.record.sourceRow.compareTo(b.record.sourceRow);
  return row != 0 ? row : a.checkId.compareTo(b.checkId);
}

/// `___` (üç ya da daha çok alt çizgi) boşluk sayısı.
int fillInBlankCount(String prompt) =>
    RegExp('_{3,}').allMatches(prompt).length;
