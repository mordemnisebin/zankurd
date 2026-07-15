import 'dart:convert';
import 'dart:io';

import 'audit_engine.dart';
import 'csv_writer.dart';
import 'models.dart';
import 'normalization.dart';

const stableReportFileNames = <String>[
  'summary.md',
  'summary.json',
  'source_inventory.csv',
  'unknown_sources.csv',
  'physical_vs_canonical_counts.csv',
  'source_role_distribution.csv',
  'blockers.csv',
  'critical_issues.csv',
  'warnings.csv',
  'structural_issues.csv',
  'exact_duplicates.csv',
  'near_duplicate_candidates.csv',
  'cross_source_copies.csv',
  'cross_source_divergences.csv',
  'language_mixing_candidates.csv',
  'answer_position_distribution.csv',
  'answer_leaks.csv',
  'explanation_quality_candidates.csv',
  'metadata_gaps.csv',
  'dynamic_fact_candidates.csv',
  'image_asset_issues.csv',
  'category_distribution.csv',
  'difficulty_distribution.csv',
  'generated_template_candidates.csv',
];

Map<String, Object?> summaryMetrics(AuditResult result) {
  final severity = <String, int>{
    for (final value in Severity.values)
      value.name: result.reportIssues
          .where((issue) => issue.severity == value)
          .length,
  };
  final gateSeverity = <String, int>{
    for (final value in Severity.values)
      value.name: result.gateIssues
          .where((issue) => issue.severity == value)
          .length,
  };
  final checkCounts = <String, int>{};
  for (final issue in result.reportIssues) {
    checkCounts[issue.checkId] = (checkCounts[issue.checkId] ?? 0) + 1;
  }
  final sortedChecks = <String, int>{
    for (final key in (checkCounts.keys.toList()..sort()))
      key: checkCounts[key]!,
  };
  return {
    'manifestVersion': result.manifest.version,
    'sourceCount': result.sourceResults.length,
    'unknownSourceCount': result.unknownSources.length,
    'missingProductionSourceCount': result.missingProductionSources.length,
    'reportPhysicalRecords': result.reportPhysicalCount,
    'reportParsedRecords': result.reportRecords.length,
    'reportCanonicalUniqueRecords': result.reportCanonical.canonicalCount,
    'gatePhysicalRecords': result.gatePhysicalCount,
    'gateParsedRecords': result.gateRecords.length,
    'gateCanonicalUniqueRecords': result.gateCanonical.canonicalCount,
    'crossSourceCopyGroups': result.reportReconciliation.copies.length,
    'crossSourceDivergences': result.reportReconciliation.divergences.length,
    'severity': severity,
    'gateSeverity': gateSeverity,
    'checks': sortedChecks,
  };
}

void writeAuditReports(AuditResult result, Directory output) {
  output.createSync(recursive: true);
  final metrics = summaryMetrics(result);
  _write(
    output,
    'summary.json',
    '${const JsonEncoder.withIndent('  ').convert(metrics)}\n',
  );
  _write(output, 'summary.md', _summaryMarkdown(metrics));
  _write(output, 'source_inventory.csv', _sourceInventory(result));
  _write(output, 'unknown_sources.csv', _unknownSources(result));
  _write(
    output,
    'physical_vs_canonical_counts.csv',
    _physicalCanonical(result),
  );
  _write(output, 'source_role_distribution.csv', _roleDistribution(result));
  _writeIssues(
    output,
    'blockers.csv',
    result.reportIssues.where((i) => i.severity == Severity.blocker),
  );
  _writeIssues(
    output,
    'critical_issues.csv',
    result.reportIssues.where((i) => i.severity == Severity.critical),
  );
  _writeIssues(
    output,
    'warnings.csv',
    result.reportIssues.where((i) => i.severity == Severity.warning),
  );
  _writeIssues(
    output,
    'structural_issues.csv',
    result.reportIssues.where(
      (i) => const {
        'empty_prompt',
        'insufficient_options',
        'empty_option',
        'duplicate_option',
        'invalid_correct_answer',
        'missing_category',
        'missing_difficulty',
        'missing_id',
        'duplicate_id',
        'production_parse_error',
      }.contains(i.checkId),
    ),
  );
  _writeIssues(
    output,
    'exact_duplicates.csv',
    result.reportIssues.where((i) => i.checkId == 'exact_duplicate'),
  );
  _writeIssues(
    output,
    'near_duplicate_candidates.csv',
    result.reportIssues.where((i) => i.checkId == 'near_duplicate_candidate'),
  );
  _write(output, 'cross_source_copies.csv', _copies(result));
  _write(output, 'cross_source_divergences.csv', _divergences(result));
  _writeIssues(
    output,
    'language_mixing_candidates.csv',
    result.reportIssues.where((i) => i.checkId == 'turkish_template'),
  );
  _write(
    output,
    'answer_position_distribution.csv',
    _answerDistribution(result),
  );
  _writeIssues(
    output,
    'answer_leaks.csv',
    result.reportIssues.where((i) => i.checkId == 'answer_leak'),
  );
  _writeIssues(
    output,
    'explanation_quality_candidates.csv',
    result.reportIssues.where((i) => i.checkId.contains('explanation')),
  );
  _writeIssues(
    output,
    'metadata_gaps.csv',
    result.reportIssues.where((i) => i.checkId.contains('metadata')),
  );
  _writeIssues(
    output,
    'dynamic_fact_candidates.csv',
    result.reportIssues.where((i) => i.checkId == 'dynamic_fact'),
  );
  _writeIssues(
    output,
    'image_asset_issues.csv',
    result.reportIssues.where((i) => i.checkId.contains('asset')),
  );
  _write(
    output,
    'category_distribution.csv',
    _distribution(result, (r) => r.category ?? 'unknown'),
  );
  _write(
    output,
    'difficulty_distribution.csv',
    _distribution(result, (r) => r.difficulty?.toString() ?? 'unknown'),
  );
  _writeIssues(
    output,
    'generated_template_candidates.csv',
    result.reportIssues.where((i) => i.checkId == 'generated_template'),
  );
  _write(
    output,
    'run_metadata.json',
    '${const JsonEncoder.withIndent('  ').convert({'generatedAtUtc': DateTime.now().toUtc().toIso8601String(), 'stableFiles': stableReportFileNames})}\n',
  );
}

void writeInventoryMarkdown(AuditResult result, File file) {
  final buffer = StringBuffer()
    ..writeln('# Question Source Inventory — 2026-07-15')
    ..writeln()
    ..writeln(
      'Physical records count every parsed or counted source row; parsed records are records mapped to the canonical audit model.',
    )
    ..writeln()
    ..writeln(
      '| Source | Role | Parser | Physical | Parsed | Gate | Production-like | Errors |',
    )
    ..writeln('|---|---|---:|---:|---:|---:|---:|---:|');
  final results = result.sourceResults.toList()
    ..sort((a, b) => a.source.id.compareTo(b.source.id));
  for (final item in results) {
    buffer.writeln(
      '| `${item.source.id}` | `${item.source.role.jsonName}` | `${item.source.parser}` | ${item.stats.read} | ${item.records.length} | ${item.source.gateIncluded} | ${item.source.productionLike} | ${item.stats.parseErrors} |',
    );
  }
  buffer
    ..writeln()
    ..writeln('Unknown sources: ${result.unknownSources.length}.')
    ..writeln(
      'Missing production-like sources: ${result.missingProductionSources.length}.',
    );
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(buffer.toString());
}

Map<String, String> stableReportHashes(Directory output) => {
  for (final name in stableReportFileNames)
    name: sha256Hex(
      File('${output.path}${Platform.pathSeparator}$name').readAsStringSync(),
    ),
};

String _summaryMarkdown(Map<String, Object?> metrics) =>
    '''
# Question Quality Summary — 2026-07-15

- Sources: ${metrics['sourceCount']}
- Unknown sources: ${metrics['unknownSourceCount']}
- Report physical records: ${metrics['reportPhysicalRecords']}
- Report parsed records: ${metrics['reportParsedRecords']}
- Report canonical unique records: ${metrics['reportCanonicalUniqueRecords']}
- Gate physical records: ${metrics['gatePhysicalRecords']}
- Gate canonical unique records: ${metrics['gateCanonicalUniqueRecords']}
- Cross-source copy groups: ${metrics['crossSourceCopyGroups']}
- Cross-source divergences: ${metrics['crossSourceDivergences']}
- Severity: `${jsonEncode(metrics['severity'])}`

Language checks are heuristic and do not claim grammatical certainty. SQL sources using `sql_count` contribute physical counts but not canonical records.
''';

String _sourceInventory(AuditResult result) {
  final rows = <List<Object?>>[
    [
      'source_id',
      'path',
      'role',
      'parser',
      'physical_records',
      'parsed_records',
      'read',
      'skipped',
      'parse_errors',
      'headers',
      'comments',
      'blank_lines',
      'report_included',
      'gate_included',
      'production_like',
      'expected_records',
    ],
  ];
  final results = result.sourceResults.toList()
    ..sort((a, b) => a.source.id.compareTo(b.source.id));
  for (final item in results) {
    rows.add([
      item.source.id,
      item.source.path ?? item.source.glob,
      item.source.role.jsonName,
      item.source.parser,
      item.stats.read,
      item.records.length,
      item.stats.read,
      item.stats.skipped,
      item.stats.parseErrors,
      item.stats.headers,
      item.stats.comments,
      item.stats.blankLines,
      item.source.reportIncluded,
      item.source.gateIncluded,
      item.source.productionLike,
      item.source.expectedRecordCount,
    ]);
  }
  return '${rows.map(csvRow).join('\n')}\n';
}

String _unknownSources(AuditResult result) {
  final rows = <List<Object?>>[
    ['path', 'format', 'discovery_signal'],
  ];
  for (final item in result.unknownSources) {
    rows.add([item.path, item.format, item.signal]);
  }
  return '${rows.map(csvRow).join('\n')}\n';
}

String _physicalCanonical(AuditResult result) =>
    '${[
      ['scope', 'physical_records', 'parsed_records', 'canonical_unique_records'],
      ['report', result.reportPhysicalCount, result.reportRecords.length, result.reportCanonical.canonicalCount],
      ['gate', result.gatePhysicalCount, result.gateRecords.length, result.gateCanonical.canonicalCount],
    ].map(csvRow).join('\n')}\n';

String _roleDistribution(AuditResult result) {
  final totals = <String, int>{};
  for (final item in result.sourceResults) {
    totals[item.source.role.jsonName] =
        (totals[item.source.role.jsonName] ?? 0) + item.stats.read;
  }
  final rows = <List<Object?>>[
    ['role', 'physical_records'],
  ];
  for (final key in totals.keys.toList()..sort()) {
    rows.add([key, totals[key]]);
  }
  return '${rows.map(csvRow).join('\n')}\n';
}

void _writeIssues(Directory output, String name, Iterable<AuditIssue> issues) {
  final rows = <List<Object?>>[
    [
      'severity',
      'check_id',
      'confidence',
      'source_id',
      'source_path',
      'source_row',
      'record_id',
      'prompt',
      'message',
      'issue_fingerprint',
    ],
  ];
  for (final issue in issues) {
    rows.add([
      issue.severity.name,
      issue.checkId,
      issue.confidence,
      issue.record.sourceId,
      issue.record.sourcePath,
      issue.record.sourceRow,
      issue.record.sourceRecordId,
      issue.record.prompt,
      issue.message,
      issue.fingerprint,
    ]);
  }
  _write(output, name, '${rows.map(csvRow).join('\n')}\n');
}

String _copies(AuditResult result) {
  final rows = <List<Object?>>[
    ['canonical_fingerprint', 'copy_count', 'source_paths', 'record_ids'],
  ];
  for (final group in result.reportReconciliation.copies) {
    final sources = group.map((r) => '${r.sourcePath}:${r.sourceRow}').toList()
      ..sort();
    final ids = group.map((r) => r.sourceRecordId ?? '').toList()..sort();
    rows.add([
      stableFingerprint(
        group.map((r) => normalizeText(r.prompt)).toSet().join('|'),
      ),
      group.length,
      sources.join('|'),
      ids.join('|'),
    ]);
  }
  return '${rows.map(csvRow).join('\n')}\n';
}

String _divergences(AuditResult result) {
  final rows = <List<Object?>>[
    [
      'severity',
      'canonical_key',
      'left_source',
      'left_row',
      'right_source',
      'right_row',
      'fields',
    ],
  ];
  for (final item in result.reportReconciliation.divergences) {
    rows.add([
      item.severity.name,
      item.canonicalKey,
      item.left.sourcePath,
      item.left.sourceRow,
      item.right.sourcePath,
      item.right.sourceRow,
      item.fields.join('|'),
    ]);
  }
  return '${rows.map(csvRow).join('\n')}\n';
}

String _answerDistribution(AuditResult result) {
  final counts = <String, int>{'A': 0, 'B': 0, 'C': 0, 'D': 0, 'unknown': 0};
  for (final record in result.reportRecords) {
    final index = record.correctOptionIndex;
    final key = index != null && index >= 0 && index < 4
        ? 'ABCD'[index]
        : 'unknown';
    counts[key] = counts[key]! + 1;
  }
  final total = result.reportRecords.length;
  final rows = <List<Object?>>[
    ['position', 'count', 'denominator', 'percent'],
  ];
  for (final key in ['A', 'B', 'C', 'D', 'unknown']) {
    rows.add([
      key,
      counts[key],
      total,
      total == 0 ? '0.00' : (counts[key]! * 100 / total).toStringAsFixed(2),
    ]);
  }
  return '${rows.map(csvRow).join('\n')}\n';
}

String _distribution(
  AuditResult result,
  String Function(QuestionRecord) keyOf,
) {
  final counts = <String, int>{};
  for (final record in result.reportRecords) {
    final key = keyOf(record);
    counts[key] = (counts[key] ?? 0) + 1;
  }
  final total = result.reportRecords.length;
  final rows = <List<Object?>>[
    ['value', 'count', 'denominator', 'percent'],
  ];
  for (final key in counts.keys.toList()..sort()) {
    rows.add([
      key,
      counts[key],
      total,
      total == 0 ? '0.00' : (counts[key]! * 100 / total).toStringAsFixed(2),
    ]);
  }
  return '${rows.map(csvRow).join('\n')}\n';
}

void _write(Directory output, String name, String content) => File(
  '${output.path}${Platform.pathSeparator}$name',
).writeAsStringSync(content);
