// Read-only production inputs. Writes only beside this audit script.
import 'dart:convert';
import 'dart:io';
import '../../../../tool/question_quality/src/audit_engine.dart';
import '../../../../tool/question_quality/src/baseline.dart';
import '../../../../tool/question_quality/src/manifest.dart';
import '../../../../tool/question_quality/src/report_writer.dart';

void main() {
  final manifest = SourceManifest.fromJsonString(
    File('tool/question_quality/source_manifest.json').readAsStringSync(),
  );
  final result = AuditEngine(
    root: Directory.current,
    manifest: manifest,
    gateOnly: true,
  ).run();
  final baseline = AuditBaseline.fromJsonString(
    File('tool/question_quality/baseline.json').readAsStringSync(),
  );
  final comparison = compareBaseline(baseline, result.snapshot);
  final data = {
    'generatedAt': DateTime.now().toUtc().toIso8601String(),
    'scope': 'gateOnly',
    'baselinePasses': comparison.passes,
    'baselineReasons': comparison.reasons,
    'metrics': summaryMetrics(result),
    'issues': [
      for (final i in result.gateIssues)
        {
          'fingerprint': i.fingerprint,
          'severity': i.severity.name,
          'checkId': i.checkId,
          'confidence': i.confidence,
          'sourcePath': i.record.sourcePath,
          'sourceRow': i.record.sourceRow,
          'id': i.record.sourceRecordId,
          'category': i.record.category,
          'questionType': i.record.questionType,
          'prompt': i.record.prompt,
          'options': i.record.options,
          'correctAnswer': i.record.correctOptionText,
          'message': i.message,
        },
    ],
  };
  File(
    'docs/audit/followup_2026_10_21/content/gate_snapshot.json',
  ).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert(data)}\n');
  stdout.writeln(
    'gate issues=${result.gateIssues.length}; baselinePasses=${comparison.passes}',
  );
}
