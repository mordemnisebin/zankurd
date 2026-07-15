import 'dart:convert';

class AuditBaseline {
  const AuditBaseline({
    required this.manifestVersion,
    required this.createdDate,
    required this.issueFingerprints,
    required this.blockerCount,
    required this.criticalCount,
    required this.sourceFingerprints,
    required this.metrics,
  });

  factory AuditBaseline.synthetic({
    required Set<String> issueFingerprints,
    int blockerCount = 0,
    int criticalCount = 0,
  }) => AuditBaseline(
    manifestVersion: 1,
    createdDate: '2026-07-15',
    issueFingerprints: issueFingerprints,
    blockerCount: blockerCount,
    criticalCount: criticalCount,
    sourceFingerprints: const {},
    metrics: const {},
  );

  factory AuditBaseline.fromJsonString(String value) {
    final json = jsonDecode(value) as Map<String, Object?>;
    return AuditBaseline(
      manifestVersion: (json['manifestVersion']! as num).toInt(),
      createdDate: json['createdDate']! as String,
      issueFingerprints: (json['issueFingerprints']! as List<Object?>)
          .map((item) => item! as String)
          .toSet(),
      blockerCount: (json['blockerCount']! as num).toInt(),
      criticalCount: (json['criticalCount']! as num).toInt(),
      sourceFingerprints: (json['sourceFingerprints']! as Map<String, Object?>)
          .map((key, value) => MapEntry(key, value! as String)),
      metrics: (json['metrics'] as Map<String, Object?>?) ?? const {},
    );
  }

  factory AuditBaseline.fromSnapshot({
    required AuditSnapshot snapshot,
    required int manifestVersion,
    required Map<String, Object?> metrics,
  }) => AuditBaseline(
    manifestVersion: manifestVersion,
    createdDate: '2026-07-15',
    issueFingerprints: snapshot.issueFingerprints,
    blockerCount: snapshot.blockerCount,
    criticalCount: snapshot.criticalCount,
    sourceFingerprints: snapshot.sourceFingerprints,
    metrics: metrics,
  );

  final int manifestVersion;
  final String createdDate;
  final Set<String> issueFingerprints;
  final int blockerCount;
  final int criticalCount;
  final Map<String, String> sourceFingerprints;
  final Map<String, Object?> metrics;

  String toJsonString() {
    final fingerprints = issueFingerprints.toList()..sort();
    final sourceKeys = sourceFingerprints.keys.toList()..sort();
    final sortedSources = <String, String>{
      for (final key in sourceKeys) key: sourceFingerprints[key]!,
    };
    return '${const JsonEncoder.withIndent('  ').convert({'version': 1, 'createdDate': createdDate, 'manifestVersion': manifestVersion, 'sourceFingerprints': sortedSources, 'blockerCount': blockerCount, 'criticalCount': criticalCount, 'issueFingerprints': fingerprints, 'metrics': metrics})}\n';
  }
}

class AuditSnapshot {
  const AuditSnapshot({
    required this.issueFingerprints,
    required this.blockerCount,
    required this.criticalCount,
    required this.unknownSourceCount,
    required this.sourceFingerprints,
  });

  factory AuditSnapshot.synthetic({
    required Set<String> issueFingerprints,
    int blockerCount = 0,
    int criticalCount = 0,
    int unknownSourceCount = 0,
  }) => AuditSnapshot(
    issueFingerprints: issueFingerprints,
    blockerCount: blockerCount,
    criticalCount: criticalCount,
    unknownSourceCount: unknownSourceCount,
    sourceFingerprints: const {},
  );

  final Set<String> issueFingerprints;
  final int blockerCount;
  final int criticalCount;
  final int unknownSourceCount;
  final Map<String, String> sourceFingerprints;
}

class GateComparison {
  const GateComparison(this.reasons);
  final List<String> reasons;
  bool get passes => reasons.isEmpty;
}

GateComparison compareBaseline(AuditBaseline baseline, AuditSnapshot current) {
  final reasons = <String>[];
  if (current.unknownSourceCount > 0) {
    reasons.add('Unclassified question source detected.');
  }
  if (current.blockerCount > baseline.blockerCount) {
    reasons.add(
      'BLOCKER count increased: ${baseline.blockerCount} -> ${current.blockerCount}',
    );
  }
  if (current.criticalCount > baseline.criticalCount) {
    reasons.add(
      'CRITICAL count increased: ${baseline.criticalCount} -> ${current.criticalCount}',
    );
  }
  if (!_sameMap(current.sourceFingerprints, baseline.sourceFingerprints)) {
    reasons.add(
      'Gate source fingerprint changed; baseline metrics were not accepted.',
    );
  }
  final newIssues =
      current.issueFingerprints.difference(baseline.issueFingerprints).toList()
        ..sort();
  for (final issue in newIssues) {
    reasons.add('New issue fingerprint: $issue');
  }
  return GateComparison(reasons);
}

bool _sameMap(Map<String, String> left, Map<String, String> right) {
  if (left.length != right.length) return false;
  for (final entry in left.entries) {
    if (right[entry.key] != entry.value) return false;
  }
  return true;
}
