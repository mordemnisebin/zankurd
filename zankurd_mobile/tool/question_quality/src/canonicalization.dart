import 'models.dart';
import 'normalization.dart';

class CanonicalGroup {
  const CanonicalGroup({required this.canonicalId, required this.records});
  final String canonicalId;
  final List<QuestionRecord> records;
}

class CanonicalizationResult {
  const CanonicalizationResult({
    required this.groups,
    required this.physicalCount,
  });
  final List<CanonicalGroup> groups;
  final int physicalCount;
  int get canonicalCount => groups.length;
}

CanonicalizationResult canonicalize(List<QuestionRecord> records) {
  final idFingerprints = <String, Set<String>>{};
  for (final record in records) {
    final id = _stableId(record);
    if (id == null) continue;
    idFingerprints
        .putIfAbsent(id, () => <String>{})
        .add(_contentFingerprint(record));
  }
  final grouped = <String, List<QuestionRecord>>{};
  for (final record in records) {
    final id = _stableId(record);
    final content = _contentFingerprint(record);
    final key = id != null
        ? (idFingerprints[id]!.length == 1
              ? 'id:$id'
              : 'id:$id|content:$content')
        : 'content:$content';
    grouped.putIfAbsent('${record.canonicalGroup}|$key', () => []).add(record);
  }
  final groups =
      grouped.entries
          .map(
            (entry) =>
                CanonicalGroup(canonicalId: entry.key, records: entry.value),
          )
          .toList()
        ..sort((a, b) => a.canonicalId.compareTo(b.canonicalId));
  return CanonicalizationResult(groups: groups, physicalCount: records.length);
}

String? _stableId(QuestionRecord record) {
  final id = record.sourceRecordId?.trim();
  if (id != null && id.isNotEmpty) return id;
  final runtime = record.runtimeId?.trim();
  return runtime == null || runtime.isEmpty ? null : runtime;
}

String _contentFingerprint(QuestionRecord record) =>
    normalizedQuestionFingerprint(
      prompt: record.prompt,
      options: record.options,
      category: record.category,
    );
