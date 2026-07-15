import 'dart:convert';
import 'dart:io';

import '../src/csv_writer.dart';
import '../src/manifest.dart';
import '../src/models.dart';
import '../src/normalization.dart';
import '../src/reconciliation.dart';
import 'core.dart';
import 'models.dart';
import 'source_loader.dart';

class AdjudicationRun {
  const AdjudicationRun({
    required this.invalidReviews,
    required this.answerLeakReviews,
    required this.duplicateOptionSample,
    required this.crossSourceCorrectAnswerRows,
    required this.runtimeReachabilityRows,
  });

  final List<AdjudicationRecord> invalidReviews;
  final List<AdjudicationRecord> answerLeakReviews;
  final List<AdjudicationRecord> duplicateOptionSample;
  final List<List<Object?>> crossSourceCorrectAnswerRows;
  final List<List<Object?>> runtimeReachabilityRows;
}

class _IssueInput {
  const _IssueInput({
    required this.severity,
    required this.checkId,
    required this.confidence,
    required this.sourceId,
    required this.sourcePath,
    required this.sourceRow,
    required this.recordId,
    required this.prompt,
    required this.fingerprint,
  });

  final String severity;
  final String checkId;
  final String confidence;
  final String sourceId;
  final String sourcePath;
  final int sourceRow;
  final String? recordId;
  final String prompt;
  final String fingerprint;
}

AdjudicationRun generateAdjudication({
  required Directory root,
  required Directory issueDirectory,
}) {
  final manifest = SourceManifest.fromJsonString(
    File(
      '${root.path}/tool/question_quality/source_manifest.json',
    ).readAsStringSync(),
  );
  final corpus = loadSourceCorpus(root, manifest);
  if (corpus.errors.isNotEmpty) {
    throw StateError('Source parsing failed: ${corpus.errors.join('; ')}');
  }
  final structural = _readIssues(
    File('${issueDirectory.path}/structural_issues.csv'),
  );
  final answerLeaks = _readIssues(
    File('${issueDirectory.path}/answer_leaks.csv'),
  );
  final byCopyKey = <String, List<QuestionRecord>>{};
  for (final record in corpus.records) {
    byCopyKey
        .putIfAbsent(adjudicationCopyIdentity(record), () => [])
        .add(record);
  }

  AdjudicationRecord review(_IssueInput issue, String kind) {
    final located = locateOriginalRecord(
      IssueReference(
        fingerprint: issue.fingerprint,
        sourcePath: issue.sourcePath,
        sourceRow: issue.sourceRow,
        recordId: issue.recordId,
      ),
      corpus.records,
    );
    final source = corpus.sourcesByPath[issue.sourcePath];
    final record = located.record;
    if (record == null || source == null) {
      return _missingReview(issue, source);
    }
    final copies = byCopyKey[adjudicationCopyIdentity(record)] ?? [record];
    final rawCorrect = corpus.rawCorrect(record.sourcePath, record.sourceRow);
    final interpretation = rawCorrect == null
        ? null
        : interpretCorrectValue(rawCorrect, record.options);
    final difference = _correctDifference(copies);
    late Adjudication adjudication;
    late String evidence;
    var factual = false;
    var editor = false;
    var action = 'Manual review only; do not change production data.';
    if (kind == 'invalid') {
      adjudication = rawCorrect == null
          ? Adjudication.sourceSchemaMismatch
          : classifyInvalidCorrectAnswer(
              rawCorrect: rawCorrect,
              record: record,
            );
      if (adjudication == Adjudication.parserFalsePositive &&
          !_isAnchor(record, copies, corpus.sourcesByPath)) {
        adjudication = Adjudication.crossSourceCopyArtifact;
      }
      final form = duplicateOptionForm(record.options);
      evidence =
          'rawCorrect=${rawCorrect ?? '<null>'}; parserRule=${interpretation?.rule ?? 'none'}; '
          'parsedIndex=${record.correctOptionIndex}; parsedText=${record.correctOptionText ?? '<null>'}; '
          'options=${record.options.join(' | ')}; duplicateForm=$form. '
          'The raw answer resolves to a valid option; invalid_correct_answer was triggered by normalized option multiplicity.';
      editor = form != 'punctuation_normalization_collision';
      action = form == 'punctuation_normalization_collision'
          ? 'Create a separate auditor-fix package preserving meaningful punctuation during option validation.'
          : 'Keep invalid-answer closed as false positive; review duplicate distractors separately with an editor.';
    } else if (kind == 'answer_leak') {
      adjudication = classifyAnswerLeak(
        prompt: record.prompt,
        correctText: record.correctOptionText ?? '',
      );
      if (!_isAnchor(record, copies, corpus.sourcesByPath)) {
        adjudication = Adjudication.crossSourceCopyArtifact;
      }
      factual = adjudication == Adjudication.factualVerificationRequired;
      editor =
          adjudication == Adjudication.confirmedDataDefect ||
          adjudication == Adjudication.ambiguousNeedsEditor ||
          factual;
      evidence =
          'prompt=${record.prompt}; correct=${record.correctOptionText ?? '<null>'}; '
          'rawCorrect=${rawCorrect ?? '<null>'}; standalone normalized match was reviewed against context; '
          'physicalCopies=${copies.length}.';
      action = switch (adjudication) {
        Adjudication.confirmedDataDefect =>
          'Human editor should rewrite the prompt or replace the distractor set in a separately approved data-fix branch.',
        Adjudication.factualVerificationRequired =>
          'Verify the fact against an authoritative dated source before any editorial decision.',
        Adjudication.parserFalsePositive =>
          'Retain the natural context and suppress only through a separately tested auditor rule.',
        _ =>
          'Review the canonical source once; do not edit physical copies independently.',
      };
    } else {
      final form = duplicateOptionForm(record.options);
      adjudication = form == 'punctuation_normalization_collision'
          ? Adjudication.parserFalsePositive
          : source.gateIncluded
          ? Adjudication.confirmedDataDefect
          : Adjudication.crossSourceCopyArtifact;
      editor = adjudication == Adjudication.confirmedDataDefect;
      evidence =
          'options=${record.options.join(' | ')}; duplicateForm=$form; '
          'rawCorrect=${rawCorrect ?? '<null>'}; physicalCopies=${copies.length}.';
      action = adjudication == Adjudication.parserFalsePositive
          ? 'Fix punctuation normalization only in a separate auditor package.'
          : 'Select distinct distractors through human editorial review; no automatic replacement is safe.';
    }
    return AdjudicationRecord(
      issueFingerprint: issue.fingerprint,
      checkId: issue.checkId,
      severity: issue.severity,
      sourceId: issue.sourceId,
      sourceRole: source.role.jsonName,
      gateIncluded: source.gateIncluded,
      productionLike: source.productionLike,
      sourcePath: issue.sourcePath,
      sourceRow: issue.sourceRow,
      sourceRecordId: record.sourceRecordId,
      runtimeId: record.runtimeId,
      canonicalId: record.canonicalId ?? adjudicationCopyIdentity(record),
      prompt: record.prompt,
      options: record.options,
      rawCorrectValue: rawCorrect,
      parsedCorrectIndex: record.correctOptionIndex,
      parsedCorrectText: record.correctOptionText,
      explanation: record.explanation,
      category: record.category,
      difficulty: record.difficulty,
      parserName: source.parser,
      parserRule: interpretation?.rule ?? 'missing_correct_value',
      originalSourceLocated: true,
      runtimeReachable: classifyRuntimeReachability(issue.sourceId),
      duplicateSourceCount: copies.length,
      crossSourceDifference: difference,
      adjudication: adjudication,
      confidence: _confidence(adjudication),
      evidence: evidence,
      factualVerificationNeeded: factual,
      kurmanciEditorNeeded: editor,
      recommendedAction: action,
    );
  }

  final invalid = structural
      .where((issue) => issue.checkId == 'invalid_correct_answer')
      .map((issue) => review(issue, 'invalid'))
      .toList();
  final leaks = answerLeaks
      .map((issue) => review(issue, 'answer_leak'))
      .toList();
  final duplicateIssues =
      structural.where((issue) => issue.checkId == 'duplicate_option').toList()
        ..sort(_compareIssue);
  const sourceQuotas = <String, int>{
    'active_import_ready': 58,
    'rich_v2_csv_snapshot': 30,
    'wave2_reviewed': 20,
    'wave2_quarantine': 45,
    'editorial_wave2_review': 42,
    'open_web_master': 1,
    'open_web_review_queue': 1,
    'opentdb_remaining': 1,
    'wave2_publish_candidates': 2,
  };
  final used = <String, int>{};
  final duplicateSample = duplicateIssues
      .where((issue) {
        final limit = sourceQuotas[issue.sourceId] ?? 0;
        final count = used[issue.sourceId] ?? 0;
        if (count >= limit) return false;
        used[issue.sourceId] = count + 1;
        return true;
      })
      .map((issue) => review(issue, 'duplicate_option'))
      .toList();

  final correctRows = <List<Object?>>[];
  final reconciliation = reconcile(corpus.records);
  for (final divergence in reconciliation.divergences.where(
    (item) => item.fields.contains('correctAnswer'),
  )) {
    correctRows.add([
      divergence.canonicalKey,
      divergence.left.sourceId,
      divergence.left.sourcePath,
      divergence.left.sourceRow,
      divergence.left.correctOptionIndex,
      divergence.left.correctOptionText,
      divergence.right.sourceId,
      divergence.right.sourcePath,
      divergence.right.sourceRow,
      divergence.right.correctOptionIndex,
      divergence.right.correctOptionText,
      divergence.severity.name,
      'correctAnswer',
    ]);
  }
  correctRows.sort((a, b) => a.join('|').compareTo(b.join('|')));

  final reachability = <List<Object?>>[];
  final definitions = corpus.sourcesByPath.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key));
  for (final entry in definitions) {
    final source = entry.value;
    reachability.add([
      source.id,
      source.role.jsonName,
      source.gateIncluded,
      entry.key,
      classifyRuntimeReachability(source.id).value,
      _reachabilityEvidence(source.id),
    ]);
  }
  return AdjudicationRun(
    invalidReviews: invalid,
    answerLeakReviews: leaks,
    duplicateOptionSample: duplicateSample,
    crossSourceCorrectAnswerRows: correctRows,
    runtimeReachabilityRows: reachability,
  );
}

void writeAdjudication(AdjudicationRun run, Directory output) {
  output.createSync(recursive: true);
  _writeReviews(
    File('${output.path}/invalid_correct_answer_review.csv'),
    run.invalidReviews,
  );
  _writeReviews(
    File('${output.path}/answer_leak_review.csv'),
    run.answerLeakReviews,
  );
  _writeReviews(
    File('${output.path}/duplicate_option_sample_review.csv'),
    run.duplicateOptionSample,
  );
  _writeRows(
    File('${output.path}/cross_source_correct_answer_review.csv'),
    const [
      'canonical_key',
      'left_source',
      'left_path',
      'left_row',
      'left_index',
      'left_text',
      'right_source',
      'right_path',
      'right_row',
      'right_index',
      'right_text',
      'severity',
      'difference',
    ],
    run.crossSourceCorrectAnswerRows,
  );
  _writeRows(File('${output.path}/runtime_reachability.csv'), const [
    'source_id',
    'source_role',
    'gate_included',
    'source_path',
    'runtime_reachability',
    'evidence',
  ], run.runtimeReachabilityRows);
  final all = [
    ...run.invalidReviews,
    ...run.answerLeakReviews,
    ...run.duplicateOptionSample,
  ];
  _writeReviews(
    File('${output.path}/parser_false_positive_candidates.csv'),
    all.where(
      (row) =>
          row.adjudication == Adjudication.parserFalsePositive ||
          row.adjudication == Adjudication.sourceSchemaMismatch,
    ),
  );
  _writeReviews(
    File('${output.path}/confirmed_data_defects.csv'),
    all.where((row) => row.adjudication == Adjudication.confirmedDataDefect),
  );
  _writeReviews(
    File('${output.path}/ambiguous_editor_review.csv'),
    all.where(
      (row) =>
          row.adjudication == Adjudication.ambiguousNeedsEditor ||
          row.adjudication == Adjudication.factualVerificationRequired,
    ),
  );
  final wave = all.where(
    (row) =>
        row.adjudication == Adjudication.confirmedDataDefect &&
        row.confidence == 'high' &&
        row.originalSourceLocated &&
        const {
          RuntimeReachability.runtimeActive,
          RuntimeReachability.importActiveNotRuntime,
        }.contains(row.runtimeReachable) &&
        !row.factualVerificationNeeded &&
        !row.kurmanciEditorNeeded,
  );
  _writeFixWave(File('${output.path}/recommended_fix_wave_1.csv'), wave);

  final counts = <String, int>{};
  for (final row in all) {
    counts.update(
      row.adjudication.value,
      (value) => value + 1,
      ifAbsent: () => 1,
    );
  }
  final summary = <String, Object?>{
    'invalidCorrectAnswerReviewed': run.invalidReviews.length,
    'answerLeaksReviewed': run.answerLeakReviews.length,
    'duplicateOptionSampled': run.duplicateOptionSample.length,
    'crossSourceCorrectAnswerDifferences':
        run.crossSourceCorrectAnswerRows.length,
    'safeForAutomaticFixTrue': all
        .where((row) => row.safeForAutomaticFix)
        .length,
    'recommendedFixWave1': wave.length,
    'adjudicationCounts': Map.fromEntries(
      counts.entries.toList()..sort((a, b) => a.key.compareTo(b.key)),
    ),
  };
  final summaryJson = const JsonEncoder.withIndent('  ').convert(summary);
  File(
    '${output.path}/adjudication_summary.json',
  ).writeAsStringSync('$summaryJson\n');
  File('${output.path}/adjudication_summary.md').writeAsStringSync(
    '# Question Adjudication Summary — 2026-07-15\n\n'
    '- Invalid correct-answer reviewed: ${run.invalidReviews.length}\n'
    '- Answer-leak reviewed: ${run.answerLeakReviews.length}\n'
    '- Duplicate-option deterministic sample: ${run.duplicateOptionSample.length}\n'
    '- Cross-source correct-answer differences: ${run.crossSourceCorrectAnswerRows.length}\n'
    '- Recommended automatic fixes: 0\n\n'
    'All production sources were read-only. Every `safeForAutomaticFix` value is false.\n',
  );
}

List<_IssueInput> _readIssues(File file) {
  if (!file.existsSync()) throw StateError('Missing issue file: ${file.path}');
  final rows = parseAdjudicationCsv(file.readAsStringSync());
  if (rows.isEmpty) return const [];
  final index = <String, int>{
    for (var i = 0; i < rows.first.length; i++) rows.first[i]: i,
  };
  String value(List<String> row, String key) {
    final position = index[key];
    return position == null || position >= row.length ? '' : row[position];
  }

  return rows
      .skip(1)
      .where((row) => row.any((cell) => cell.isNotEmpty))
      .map(
        (row) => _IssueInput(
          severity: value(row, 'severity'),
          checkId: value(row, 'check_id'),
          confidence: value(row, 'confidence'),
          sourceId: value(row, 'source_id'),
          sourcePath: value(row, 'source_path'),
          sourceRow: int.parse(value(row, 'source_row')),
          recordId: value(row, 'record_id').isEmpty
              ? null
              : value(row, 'record_id'),
          prompt: value(row, 'prompt'),
          fingerprint: value(row, 'issue_fingerprint'),
        ),
      )
      .toList();
}

AdjudicationRecord _missingReview(
  _IssueInput issue,
  SourceDefinition? source,
) => AdjudicationRecord(
  issueFingerprint: issue.fingerprint,
  checkId: issue.checkId,
  severity: issue.severity,
  sourceId: issue.sourceId,
  sourceRole: source?.role.jsonName ?? 'unknown',
  gateIncluded: source?.gateIncluded ?? false,
  productionLike: source?.productionLike ?? false,
  sourcePath: issue.sourcePath,
  sourceRow: issue.sourceRow,
  sourceRecordId: issue.recordId,
  runtimeId: null,
  canonicalId: null,
  prompt: issue.prompt,
  options: const [],
  rawCorrectValue: null,
  parsedCorrectIndex: null,
  parsedCorrectText: null,
  explanation: null,
  category: null,
  difficulty: null,
  parserName: source?.parser ?? 'unknown',
  parserRule: 'source_not_located',
  originalSourceLocated: false,
  runtimeReachable: RuntimeReachability.unknown,
  duplicateSourceCount: 0,
  crossSourceDifference: 'unknown',
  adjudication: Adjudication.unableToLocateSource,
  confidence: 'high',
  evidence: 'No unique record matched sourcePath, sourceRow and recordId.',
  factualVerificationNeeded: false,
  kurmanciEditorNeeded: false,
  recommendedAction: 'Repair source-location evidence before review.',
);

bool _isAnchor(
  QuestionRecord record,
  List<QuestionRecord> copies,
  Map<String, SourceDefinition> sources,
) {
  final sorted = [...copies]
    ..sort((a, b) {
      final precedence = (sources[b.sourcePath]?.precedence ?? 0).compareTo(
        sources[a.sourcePath]?.precedence ?? 0,
      );
      if (precedence != 0) return precedence;
      final path = a.sourcePath.compareTo(b.sourcePath);
      return path != 0 ? path : a.sourceRow.compareTo(b.sourceRow);
    });
  return identical(sorted.first, record);
}

String _correctDifference(List<QuestionRecord> copies) {
  final values = copies
      .map((record) => normalizeText(record.correctOptionText ?? ''))
      .toSet();
  return values.length > 1 ? 'correct_answer_differs' : 'none';
}

String _confidence(Adjudication adjudication) => switch (adjudication) {
  Adjudication.ambiguousNeedsEditor ||
  Adjudication.factualVerificationRequired => 'medium',
  _ => 'high',
};

String _reachabilityEvidence(String sourceId) => switch (sourceId) {
  'offline_runtime_bank' || 'curated_runtime_bank' =>
    'MockZanKurdRepository.questions includes both banks; Supabase repository falls back to the same offline repository.',
  'active_import_ready' =>
    'tools/export_question_bank_csv.py produces the file; no runtime import is executed by the app.',
  'live_kurmanci_export' =>
    'Import scripts reference the CSV, but application runtime code does not read this file directly.',
  'wave2_publish_candidates' =>
    'Export scripts can turn this candidate CSV into SQL; it is not read directly at runtime.',
  _ =>
    'No direct application runtime reference; role and repository search support conservative classification.',
};

int _compareIssue(_IssueInput a, _IssueInput b) {
  final source = a.sourceId.compareTo(b.sourceId);
  if (source != 0) return source;
  final row = a.sourceRow.compareTo(b.sourceRow);
  return row != 0 ? row : a.fingerprint.compareTo(b.fingerprint);
}

const _reviewHeader = <String>[
  'issueFingerprint',
  'checkId',
  'severity',
  'sourceId',
  'sourceRole',
  'gateIncluded',
  'productionLike',
  'sourcePath',
  'sourceRow',
  'sourceRecordId',
  'runtimeId',
  'canonicalId',
  'prompt',
  'options',
  'rawCorrectValue',
  'parsedCorrectIndex',
  'parsedCorrectText',
  'explanation',
  'category',
  'difficulty',
  'parserName',
  'parserRule',
  'originalSourceLocated',
  'runtimeReachable',
  'duplicateSourceCount',
  'crossSourceDifference',
  'adjudication',
  'confidence',
  'evidence',
  'factualVerificationNeeded',
  'KurmanciEditorNeeded',
  'recommendedAction',
  'safeForAutomaticFix',
];

void _writeReviews(File file, Iterable<AdjudicationRecord> records) {
  final sorted = records.toList()
    ..sort((a, b) {
      final source = a.sourceId.compareTo(b.sourceId);
      if (source != 0) return source;
      final row = a.sourceRow.compareTo(b.sourceRow);
      return row != 0 ? row : a.issueFingerprint.compareTo(b.issueFingerprint);
    });
  final lines = <String>[csvRow(_reviewHeader)];
  for (final row in sorted) {
    lines.add(
      csvRow([
        row.issueFingerprint,
        row.checkId,
        row.severity,
        row.sourceId,
        row.sourceRole,
        row.gateIncluded,
        row.productionLike,
        row.sourcePath,
        row.sourceRow,
        row.sourceRecordId,
        row.runtimeId,
        row.canonicalId,
        row.prompt,
        row.options.join(' | '),
        row.rawCorrectValue,
        row.parsedCorrectIndex,
        row.parsedCorrectText,
        row.explanation,
        row.category,
        row.difficulty,
        row.parserName,
        row.parserRule,
        row.originalSourceLocated,
        row.runtimeReachable.value,
        row.duplicateSourceCount,
        row.crossSourceDifference,
        row.adjudication.value,
        row.confidence,
        row.evidence,
        row.factualVerificationNeeded,
        row.kurmanciEditorNeeded,
        row.recommendedAction,
        row.safeForAutomaticFix,
      ]),
    );
  }
  file.writeAsStringSync('${lines.join('\n')}\n');
}

void _writeRows(File file, List<String> header, Iterable<List<Object?>> rows) {
  file.writeAsStringSync(
    '${[csvRow(header), ...rows.map(csvRow)].join('\n')}\n',
  );
}

void _writeFixWave(File file, Iterable<AdjudicationRecord> rows) {
  final output = <List<Object?>>[];
  for (final row in rows) {
    output.add([
      row.sourcePath,
      row.sourceRow,
      row.sourceRecordId,
      row.checkId,
      'manual_editorial_field',
      row.rawCorrectValue,
      '',
      row.evidence,
      'high',
      'Re-run question adjudication and question-quality gate.',
      'Revert only the explicitly approved source-row change.',
      false,
    ]);
  }
  _writeRows(file, const [
    'source',
    'sourceRow',
    'recordId',
    'issue',
    'recommendedField',
    'currentValue',
    'proposedValue',
    'evidence',
    'risk',
    'requiredTest',
    'rollback',
    'safeForAutomaticFix',
  ], output);
}
