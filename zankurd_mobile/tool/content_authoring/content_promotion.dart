import 'dart:io';

import '../question_quality/src/audit_engine.dart';
import '../question_quality/src/manifest.dart';
import '../question_quality/src/models.dart';
import 'src/artifacts.dart';
import 'src/csv_source.dart';
import 'src/promotion.dart';

void main(List<String> args) {
  final options = _parseArgs(args);
  final root = Directory.current;
  final sourcePath =
      options['source'] ?? 'supabase/wave2_quarantine_for_further_review.csv';
  final sourceFile = File(sourcePath);
  if (!sourceFile.existsSync()) {
    stderr.writeln('Content promotion source not found: $sourcePath');
    exitCode = 2;
    return;
  }

  final targetCount = int.tryParse(options['target'] ?? '') ?? 15000;
  final output = Directory(
    options['output'] ??
        'docs/audit/question_quality/content_promotion_2026-08-01',
  );
  final candidates = loadPromotionCandidates(sourceFile);
  final active = _loadActiveCandidates(root);
  final result = promoteCandidates(
    candidates: candidates,
    active: active,
    targetCount: targetCount,
    maxTemplatePerShape:
        int.tryParse(options['max-template-per-shape'] ?? '') ?? 3,
    maxPerCategory: int.tryParse(options['max-per-category'] ?? '') ?? 2000,
    maxPerDifficulty: int.tryParse(options['max-per-difficulty'] ?? '') ?? 6000,
  );
  writePromotionArtifacts(result, output, sourcePath: sourcePath);
  stdout.writeln(
    'content-promotion: candidates=${candidates.length} '
    'active=${result.activeCount} accepted=${result.accepted.length} '
    'remaining=${result.remainingToTarget} output=${output.path}',
  );
}

Map<String, String> _parseArgs(List<String> args) {
  final values = <String, String>{};
  for (final arg in args) {
    if (!arg.startsWith('--')) continue;
    final separator = arg.indexOf('=');
    if (separator < 0) continue;
    values[arg.substring(2, separator)] = arg.substring(separator + 1);
  }
  return values;
}

List<PromotionCandidate> _loadActiveCandidates(Directory root) {
  final manifest = SourceManifest.fromJsonString(
    File(
      '${root.path}/tool/question_quality/source_manifest.json',
    ).readAsStringSync(),
  );
  final audit = AuditEngine(
    root: root,
    manifest: manifest,
    gateOnly: true,
  ).run();
  final records = audit.gateCanonical.groups.map(
    (group) => group.records.first,
  );
  return records.map(_activeCandidate).toList(growable: false);
}

PromotionCandidate _activeCandidate(QuestionRecord record) {
  final correct =
      record.correctOptionIndex != null &&
          record.correctOptionIndex! >= 0 &&
          record.correctOptionIndex! < 4
      ? 'ABCD'[record.correctOptionIndex!]
      : record.correctOptionText ?? '';
  return PromotionCandidate(
    row: record.sourceRow,
    id: record.sourceRecordId ?? record.runtimeId ?? '',
    locale: record.locale ?? 'ku-kmr',
    category: record.category ?? '',
    prompt: record.prompt,
    options: record.options,
    correctOption: correct,
    explanation: record.explanation ?? '',
    difficulty: record.difficulty,
    sourceVerified: 'verified',
    sourceUrl: record.sourceUrl ?? 'https://runtime.local',
    publicationStatus: 'approved',
    issueType: '',
  );
}
