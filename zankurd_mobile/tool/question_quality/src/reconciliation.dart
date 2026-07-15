import 'models.dart';
import 'normalization.dart';

class ReconciliationResult {
  const ReconciliationResult({required this.copies, required this.divergences});
  final List<List<QuestionRecord>> copies;
  final List<CrossSourceDivergence> divergences;
}

ReconciliationResult reconcile(List<QuestionRecord> records) {
  final byId = <String, List<QuestionRecord>>{};
  final byContent = <String, List<QuestionRecord>>{};
  for (final record in records) {
    final id = record.sourceRecordId?.trim();
    if (id != null && id.isNotEmpty) {
      byId.putIfAbsent('${record.canonicalGroup}|$id', () => []).add(record);
    }
    final fingerprint = normalizedQuestionFingerprint(
      prompt: record.prompt,
      options: record.options,
      category: record.category,
    );
    byContent
        .putIfAbsent('${record.canonicalGroup}|$fingerprint', () => [])
        .add(record);
  }
  final divergences = <CrossSourceDivergence>[];
  for (final entry in byId.entries.where((entry) => entry.value.length > 1)) {
    final reference = entry.value.first;
    for (final other in entry.value.skip(1)) {
      final fields = _differentFields(reference, other);
      if (fields.isEmpty) continue;
      final blocker =
          fields.contains('correctAnswer') || fields.contains('prompt');
      divergences.add(
        CrossSourceDivergence(
          canonicalKey: entry.key,
          left: reference,
          right: other,
          fields: fields,
          severity: blocker ? Severity.blocker : Severity.warning,
        ),
      );
    }
  }
  final copies = byContent.values.where((group) => group.length > 1).toList()
    ..sort((a, b) => a.first.sourcePath.compareTo(b.first.sourcePath));
  divergences.sort((a, b) => a.canonicalKey.compareTo(b.canonicalKey));
  return ReconciliationResult(copies: copies, divergences: divergences);
}

List<String> _differentFields(QuestionRecord a, QuestionRecord b) {
  final fields = <String>[];
  if (normalizeText(a.prompt) != normalizeText(b.prompt)) fields.add('prompt');
  if (_listKey(a.options) != _listKey(b.options)) fields.add('options');
  if (normalizeText(a.correctOptionText ?? '') !=
      normalizeText(b.correctOptionText ?? '')) {
    fields.add('correctAnswer');
  }
  if (normalizeText(a.explanation ?? '') !=
      normalizeText(b.explanation ?? '')) {
    fields.add('explanation');
  }
  if (normalizeText(a.category ?? '') != normalizeText(b.category ?? '')) {
    fields.add('category');
  }
  if (a.difficulty != b.difficulty) fields.add('difficulty');
  if ((a.imagePath ?? '') != (b.imagePath ?? '')) fields.add('imagePath');
  if ((a.status ?? '') != (b.status ?? '')) fields.add('status');
  return fields;
}

String _listKey(List<String> values) =>
    values.map(normalizeText).join('\u001f');
