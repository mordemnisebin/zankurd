import 'dart:io';

import '../question_quality/src/audit_engine.dart';
import '../question_quality/src/manifest.dart';
import '../question_quality/src/models.dart';
import 'src/artifacts.dart';
import 'src/csv_source.dart';
import 'src/promotion.dart';

const _defaultSource = 'supabase/wave2_quarantine_for_further_review.csv';
const _defaultOutput =
    'docs/audit/question_quality/2026-08-01/content_promotion';

void main(List<String> args) {
  final sourcePath = _option(args, '--source') ?? _defaultSource;
  final outputPath = _option(args, '--output-dir') ?? _defaultOutput;
  final targetCount = int.tryParse(_option(args, '--target-count') ?? '15000');
  if (targetCount == null || targetCount <= 0) {
    stderr.writeln('--target-count must be a positive integer.');
    exitCode = 64;
    return;
  }

  final manifestFile = File('tool/question_quality/source_manifest.json');
  if (!manifestFile.existsSync()) {
    stderr.writeln('Source manifest not found: ${manifestFile.path}');
    exitCode = 2;
    return;
  }
  final manifest = SourceManifest.fromJsonString(
    manifestFile.readAsStringSync(),
  );
  if (!manifest.sources.any((source) => source.path == sourcePath)) {
    stderr.writeln(
      'Candidate source is not in the source manifest: $sourcePath',
    );
    exitCode = 2;
    return;
  }

  final candidateFile = File(sourcePath);
  if (!candidateFile.existsSync()) {
    stderr.writeln('Candidate source not found: $sourcePath');
    exitCode = 2;
    return;
  }
  final candidates = loadPromotionCandidates(candidateFile);

  final audit = AuditEngine(
    root: Directory.current,
    manifest: manifest,
    gateOnly: true,
  ).run();
  final active = audit.gateRecords
      .map(_activeCandidate)
      .toList(growable: false);
  final result = promoteCandidates(
    candidates: candidates,
    active: active,
    targetCount: targetCount,
  );
  final output = Directory(outputPath);
  writePromotionArtifacts(result, output, sourcePath: sourcePath);

  stdout.writeln('question-promotion:');
  stdout.writeln('  source=${candidates.length}');
  stdout.writeln('  active=${result.activeCount}');
  stdout.writeln('  accepted=${result.accepted.length}');
  stdout.writeln('  remainingToTarget=${result.remainingToTarget}');
  stdout.writeln('  output=${output.path}');
  if (args.contains('--fail-on-shortfall') && result.remainingToTarget > 0) {
    exitCode = 1;
  }
}

PromotionCandidate _activeCandidate(QuestionRecord record) =>
    PromotionCandidate(
      row: record.sourceRow,
      id: record.sourceRecordId ?? record.runtimeId ?? '',
      locale: record.locale ?? 'ku-kmr',
      category: record.category ?? '',
      prompt: record.prompt,
      options: record.options,
      correctOption: record.correctOptionText ?? '',
      explanation: record.explanation ?? '',
      difficulty: record.difficulty,
      sourceVerified: 'verified',
      sourceUrl: record.sourceUrl ?? '',
      publicationStatus: 'approved',
      issueType: '',
      confidence: 1,
    );

String? _option(List<String> args, String name) {
  final index = args.indexOf(name);
  if (index < 0 || index + 1 >= args.length) return null;
  return args[index + 1];
}
