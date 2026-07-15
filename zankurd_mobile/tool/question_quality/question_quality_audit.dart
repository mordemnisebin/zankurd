import 'dart:io';

import 'src/audit_engine.dart';
import 'src/baseline.dart';
import 'src/manifest.dart';
import 'src/report_writer.dart';

void main(List<String> args) {
  if (args.isEmpty ||
      !const {'report', 'gate', 'baseline'}.contains(args.first)) {
    stderr.writeln(
      'Usage: dart run tool/question_quality/question_quality_audit.dart '
      '<report|gate|baseline> [--accept-current-debt]',
    );
    exitCode = 64;
    return;
  }
  final root = Directory.current;
  final manifestFile = File('tool/question_quality/source_manifest.json');
  final baselineFile = File('tool/question_quality/baseline.json');
  final output = Directory('docs/audit/question_quality/2026-07-15');
  if (!manifestFile.existsSync()) {
    stderr.writeln('Source manifest not found: ${manifestFile.path}');
    exitCode = 2;
    return;
  }
  final manifest = SourceManifest.fromJsonString(
    manifestFile.readAsStringSync(),
  );
  final profiling = Platform.environment['QUESTION_AUDIT_PROFILE'] == '1';
  final result = AuditEngine(
    root: root,
    manifest: manifest,
    onProfile: profiling
        ? (stage, elapsed) =>
              stderr.writeln('profile $stage ${elapsed.inMilliseconds}ms')
        : null,
  ).run();
  writeAuditReports(result, output);
  writeInventoryMarkdown(
    result,
    File('docs/audit/question_quality/QUESTION_SOURCE_INVENTORY_2026-07-15.md'),
  );
  final metrics = summaryMetrics(result);
  stdout.writeln(
    'question-quality: sources=${result.sourceResults.length} '
    'reportPhysical=${result.reportPhysicalCount} '
    'reportCanonical=${result.reportCanonical.canonicalCount} '
    'gatePhysical=${result.gatePhysicalCount} '
    'gateCanonical=${result.gateCanonical.canonicalCount} '
    'unknown=${result.unknownSources.length}',
  );

  switch (args.first) {
    case 'report':
      final productionErrors = result.sourceResults
          .where(
            (item) => item.source.productionLike && item.stats.parseErrors > 0,
          )
          .length;
      if (productionErrors > 0 || result.missingProductionSources.isNotEmpty) {
        stderr.writeln('Production-like source parsing is incomplete.');
        exitCode = 1;
      }
      return;
    case 'baseline':
      if (!args.contains('--accept-current-debt')) {
        stderr.writeln(
          'Baseline was not changed. Re-run with --accept-current-debt after reviewing the report.',
        );
        exitCode = 64;
        return;
      }
      final next = AuditBaseline.fromSnapshot(
        snapshot: result.snapshot,
        manifestVersion: manifest.version,
        metrics: metrics,
      );
      if (baselineFile.existsSync()) {
        final previous = AuditBaseline.fromJsonString(
          baselineFile.readAsStringSync(),
        );
        stdout.writeln(
          'baseline delta: blockers ${previous.blockerCount}->${next.blockerCount}, '
          'criticals ${previous.criticalCount}->${next.criticalCount}, '
          'issues ${previous.issueFingerprints.length}->${next.issueFingerprints.length}',
        );
      } else {
        stdout.writeln(
          'baseline initial: blockers=${next.blockerCount}, '
          'criticals=${next.criticalCount}, issues=${next.issueFingerprints.length}',
        );
      }
      baselineFile.writeAsStringSync(next.toJsonString());
      return;
    case 'gate':
      if (!baselineFile.existsSync()) {
        stderr.writeln(
          'Baseline not found. Review report mode before explicitly accepting current debt.',
        );
        exitCode = 2;
        return;
      }
      final baseline = AuditBaseline.fromJsonString(
        baselineFile.readAsStringSync(),
      );
      if (baseline.manifestVersion != manifest.version) {
        stderr.writeln('Manifest version differs from baseline.');
        exitCode = 1;
        return;
      }
      final comparison = compareBaseline(baseline, result.snapshot);
      if (!comparison.passes) {
        for (final reason in comparison.reasons) {
          stderr.writeln(reason);
        }
        exitCode = 1;
      } else {
        stdout.writeln(
          'Question quality gate passed: no regression from baseline.',
        );
      }
      return;
  }
}
