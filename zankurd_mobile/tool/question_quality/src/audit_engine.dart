import 'dart:io';

import 'baseline.dart';
import 'canonicalization.dart';
import 'checks.dart';
import 'discovery.dart';
import 'manifest.dart';
import 'models.dart';
import 'normalization.dart';
import 'reconciliation.dart';
import 'source_readers.dart';

class AuditResult {
  const AuditResult({
    required this.manifest,
    required this.sourceResults,
    required this.unknownSources,
    required this.missingProductionSources,
    required this.reportRecords,
    required this.gateRecords,
    required this.reportCanonical,
    required this.gateCanonical,
    required this.reportReconciliation,
    required this.gateReconciliation,
    required this.reportIssues,
    required this.gateIssues,
    required this.snapshot,
  });

  final SourceManifest manifest;
  final List<SourceReadResult> sourceResults;
  final List<DiscoveredSource> unknownSources;
  final List<String> missingProductionSources;
  final List<QuestionRecord> reportRecords;
  final List<QuestionRecord> gateRecords;
  final CanonicalizationResult reportCanonical;
  final CanonicalizationResult gateCanonical;
  final ReconciliationResult reportReconciliation;
  final ReconciliationResult gateReconciliation;
  final List<AuditIssue> reportIssues;
  final List<AuditIssue> gateIssues;
  final AuditSnapshot snapshot;

  int get reportPhysicalCount => sourceResults
      .where((result) => result.source.reportIncluded)
      .fold(0, (sum, result) => sum + result.stats.read);
  int get gatePhysicalCount => sourceResults
      .where((result) => result.source.gateIncluded)
      .fold(0, (sum, result) => sum + result.stats.read);
  int countSeverity(Severity severity, {bool gateOnly = false}) =>
      (gateOnly ? gateIssues : reportIssues)
          .where((issue) => issue.severity == severity)
          .length;
}

class AuditEngine {
  const AuditEngine({
    required this.root,
    required this.manifest,
    this.onProfile,
  });
  final Directory root;
  final SourceManifest manifest;
  final void Function(String stage, Duration elapsed)? onProfile;

  AuditResult run() {
    final stopwatch = Stopwatch()..start();
    void mark(String stage) {
      onProfile?.call(stage, stopwatch.elapsed);
      stopwatch.reset();
    }

    final discovered = discoverPotentialQuestionSources(root);
    mark('discovery');
    final unknown = <DiscoveredSource>[];
    final selected = <String, SourceDefinition>{};
    for (final item in discovered) {
      final resolution = manifest.resolve(item.path);
      if (resolution.isUnknown) {
        unknown.add(item);
      } else {
        selected[item.path] = resolution.source!;
      }
    }

    final missingProduction = <String>[];
    for (final source in manifest.sources.where((item) => item.path != null)) {
      final path = source.path!.replaceAll('\\', '/');
      final file = File(_absolute(path));
      if (file.existsSync()) {
        if (source.reportIncluded ||
            source.gateIncluded ||
            source.parser == 'none') {
          selected[path] = source;
        }
      } else if (source.productionLike || source.gateIncluded) {
        missingProduction.add(path);
      }
    }

    final sourceResults = <SourceReadResult>[];
    final sourceFingerprints = <String, String>{};
    final paths = selected.keys.toList()..sort();
    for (final path in paths) {
      final source = selected[path]!;
      if (!source.reportIncluded && !source.gateIncluded) continue;
      final file = File(_absolute(path));
      if (!file.existsSync()) continue;
      if (source.gateIncluded) {
        sourceFingerprints[path] = sha256Hex(file.readAsStringSync());
      }
      sourceResults.add(readSource(source, file, repositoryRelativePath: path));
    }
    mark('readers');

    final reportRecords = sourceResults
        .where((result) => result.source.reportIncluded)
        .expand((result) => result.records)
        .toList();
    final gateRecords = sourceResults
        .where((result) => result.source.gateIncluded)
        .expand((result) => result.records)
        .toList();
    final reportCanonical = canonicalize(reportRecords);
    final gateCanonical = canonicalize(gateRecords);
    mark('canonicalization');
    final reportReconciliation = reconcile(reportRecords);
    final gateReconciliation = reconcile(gateRecords);
    mark('reconciliation');
    final reportIssues = runChecks(
      reportRecords,
      onProfile: onProfile == null
          ? null
          : (stage, elapsed) => onProfile!('report_checks_$stage', elapsed),
    );
    mark('report_checks');
    final gateIssues = runChecks(
      gateRecords,
      onProfile: onProfile == null
          ? null
          : (stage, elapsed) => onProfile!('gate_checks_$stage', elapsed),
    );
    mark('gate_checks');

    for (final result in sourceResults.where(
      (item) => item.stats.parseErrors > 0,
    )) {
      if (!result.source.productionLike) continue;
      final synthetic = QuestionRecord(
        sourceId: result.source.id,
        sourceRole: result.source.role,
        sourcePath: result.source.path ?? result.source.glob ?? '',
        sourceFormat: result.source.parser,
        sourceRow: 0,
        canonicalGroup: result.source.canonicalGroup,
        prompt: '',
        options: const [],
      );
      gateIssues.add(
        AuditIssue(
          checkId: 'production_parse_error',
          severity: Severity.blocker,
          record: synthetic,
          message: 'Production-like source could not be parsed completely.',
          fingerprint: stableFingerprint(
            'production_parse_error|${result.source.id}',
          ),
        ),
      );
    }
    for (final path in missingProduction) {
      final source =
          selected[path] ??
          manifest.sources.firstWhere((item) => item.path == path);
      final synthetic = QuestionRecord(
        sourceId: source.id,
        sourceRole: source.role,
        sourcePath: path,
        sourceFormat: source.parser,
        sourceRow: 0,
        canonicalGroup: source.canonicalGroup,
        prompt: '',
        options: const [],
      );
      gateIssues.add(
        AuditIssue(
          checkId: 'missing_production_source',
          severity: Severity.blocker,
          record: synthetic,
          message: 'Production-like manifest source is missing.',
          fingerprint: stableFingerprint('missing_production_source|$path'),
        ),
      );
    }
    for (final divergence in gateReconciliation.divergences) {
      gateIssues.add(
        AuditIssue(
          checkId: 'cross_source_divergence',
          severity: divergence.severity,
          record: divergence.right,
          message:
              'Cross-source fields differ: ${divergence.fields.join(', ')}',
          fingerprint: stableFingerprint(
            'cross_source_divergence|${divergence.canonicalKey}|${divergence.fields.join(',')}',
          ),
        ),
      );
    }
    gateIssues.sort(
      (
        a,
        b,
      ) => '${a.severity.rank}|${a.record.sourcePath}|${a.record.sourceRow}|${a.checkId}'
          .compareTo(
            '${b.severity.rank}|${b.record.sourcePath}|${b.record.sourceRow}|${b.checkId}',
          ),
    );
    final blockers = gateIssues
        .where((issue) => issue.severity == Severity.blocker)
        .length;
    final criticals = gateIssues
        .where((issue) => issue.severity == Severity.critical)
        .length;
    final snapshot = AuditSnapshot(
      issueFingerprints: gateIssues.map((issue) => issue.fingerprint).toSet(),
      blockerCount: blockers,
      criticalCount: criticals,
      unknownSourceCount: unknown.length,
      sourceFingerprints: sourceFingerprints,
    );
    return AuditResult(
      manifest: manifest,
      sourceResults: sourceResults,
      unknownSources: unknown,
      missingProductionSources: missingProduction,
      reportRecords: reportRecords,
      gateRecords: gateRecords,
      reportCanonical: reportCanonical,
      gateCanonical: gateCanonical,
      reportReconciliation: reportReconciliation,
      gateReconciliation: gateReconciliation,
      reportIssues: reportIssues,
      gateIssues: gateIssues,
      snapshot: snapshot,
    );
  }

  String _absolute(String relative) =>
      '${root.absolute.path}${Platform.pathSeparator}${relative.replaceAll('/', Platform.pathSeparator)}';
}
