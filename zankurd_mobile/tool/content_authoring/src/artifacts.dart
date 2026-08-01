import 'dart:convert';
import 'dart:io';

import 'promotion.dart';

void writePromotionArtifacts(
  PromotionResult result,
  Directory output, {
  String sourcePath = 'unknown',
}) {
  output.createSync(recursive: true);
  final manifest = <String, Object?>{
    ...result.manifest,
    'source_path': sourcePath,
    'generated_at_utc': DateTime.now().toUtc().toIso8601String(),
    'quality_gate': 'content_promotion_v1',
    'runtime_loader_changed': false,
    'runtime_fallback':
        'No expanded bank was produced; existing bank remains unchanged.',
  };
  File('${output.path}/promotion_manifest.json').writeAsStringSync(
    '${const JsonEncoder.withIndent('  ').convert(manifest)}\n',
  );
  File(
    '${output.path}/promotion_report.md',
  ).writeAsStringSync(_markdown(result, sourcePath));
  final rejectedRows = _rejectedRows(result);
  File('${output.path}/rejected_rows.csv').writeAsStringSync(rejectedRows);
  // Keep the earlier audit artifact name stable for existing reviewers.
  File(
    '${output.path}/promotion_rejections.csv',
  ).writeAsStringSync(rejectedRows);
  if (result.shouldWriteExpandedBank) {
    File('${output.path}/expanded_questions.json').writeAsStringSync(
      '${const JsonEncoder.withIndent('  ').convert(result.accepted.map((item) => item.toRuntimeJson()).toList())}\n',
    );
  }
}

String _markdown(PromotionResult result, String sourcePath) {
  final buffer = StringBuffer()
    ..writeln('# Content Promotion Report')
    ..writeln()
    ..writeln('- Source: `$sourcePath`')
    ..writeln('- Quality gate: `content_promotion_v1`')
    ..writeln('- Active canonical questions: ${result.activeCount}')
    ..writeln('- Accepted candidates: ${result.accepted.length}')
    ..writeln('- Total after promotion: ${result.totalAfterPromotion}')
    ..writeln('- Target: ${result.targetCount}')
    ..writeln('- Remaining to target: ${result.remainingToTarget}')
    ..writeln('- Expanded bank written: `${result.shouldWriteExpandedBank}`')
    ..writeln()
    ..writeln('## Rejection reasons')
    ..writeln()
    ..writeln('| Reason | Count | Sample rows |')
    ..writeln('|---|---:|---|');
  for (final entry in result.rejectedByReason.entries) {
    final rows = result.rejectionRows[entry.key]?.take(8).join(', ') ?? '';
    buffer.writeln('| `${entry.key}` | ${entry.value} | $rows |');
  }
  buffer
    ..writeln()
    ..writeln('## Accepted distribution')
    ..writeln()
    ..writeln('### Category')
    ..writeln()
    ..writeln('| Category | Count |')
    ..writeln('|---|---:|');
  for (final entry in result.categoryDistribution.entries) {
    buffer.writeln('| ${entry.key} | ${entry.value} |');
  }
  buffer
    ..writeln()
    ..writeln('### Difficulty')
    ..writeln()
    ..writeln('| Difficulty | Count |')
    ..writeln('|---|---:|');
  for (final entry in result.difficultyDistribution.entries) {
    buffer.writeln('| ${entry.key} | ${entry.value} |');
  }
  buffer
    ..writeln()
    ..writeln(
      'No candidate is invented, auto-translated, or silently promoted.',
    );
  if (!result.shouldWriteExpandedBank) {
    buffer.writeln(
      'Because no candidate passed every gate, `expanded_questions.json` was not created and the current runtime bank is unchanged.',
    );
  }
  return buffer.toString();
}

String _rejectedRows(PromotionResult result) {
  final rows = <List<Object?>>[
    ['reason', 'row'],
  ];
  for (final entry in result.rejectionRows.entries) {
    for (final row in entry.value) {
      rows.add([entry.key, row]);
    }
  }
  return '${rows.map(_csvRow).join('\n')}\n';
}

String _csvRow(List<Object?> values) => values.map(_csvCell).join(',');

String _csvCell(Object? value) {
  final text = '${value ?? ''}';
  final escaped = text.replaceAll('"', '""');
  return RegExp(r'[,"\n\r]').hasMatch(text) ? '"$escaped"' : escaped;
}
