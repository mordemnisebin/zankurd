import 'package:flutter_test/flutter_test.dart';

import '../../tool/question_quality/src/canonicalization.dart';
import '../../tool/question_quality/src/checks.dart';
import '../../tool/question_quality/src/models.dart';
import '../../tool/question_quality/src/reconciliation.dart';

QuestionRecord question({
  required String sourceId,
  required String sourcePath,
  required int row,
  String id = 'q1',
  String prompt = 'Paytexta Fransa kîjan e?',
  List<String> options = const ['Parîs', 'London', 'Roma', 'Berlin'],
  int? correctIndex = 0,
  String? correctText = 'Parîs',
  String category = 'Cografya',
  String? explanation = 'Parîs paytexta Fransa ye.',
  SourceRole role = SourceRole.runtimePrimary,
}) => QuestionRecord(
  sourceId: sourceId,
  sourceRole: role,
  sourcePath: sourcePath,
  sourceFormat: 'synthetic',
  sourceRow: row,
  sourceRecordId: id,
  runtimeId: id,
  canonicalGroup: 'questions',
  locale: 'ku-kmr',
  category: category,
  difficulty: 2,
  prompt: prompt,
  options: options,
  correctOptionIndex: correctIndex,
  correctOptionText: correctText,
  explanation: explanation,
);

void main() {
  test('physical copies collapse to one canonical record', () {
    final records = [
      question(sourceId: 'runtime', sourcePath: 'runtime.dart', row: 1),
      question(sourceId: 'import', sourcePath: 'import.csv', row: 2),
    ];
    final result = canonicalize(records);
    expect(result.physicalCount, 2);
    expect(result.canonicalCount, 1);
    expect(result.groups.single.records, hasLength(2));
  });

  test('same id with a different answer is not silently merged', () {
    final records = [
      question(sourceId: 'runtime', sourcePath: 'runtime.dart', row: 1),
      question(
        sourceId: 'publish',
        sourcePath: 'publish.csv',
        row: 2,
        correctIndex: 1,
        correctText: 'London',
      ),
    ];
    final reconciliation = reconcile(records);
    expect(
      reconciliation.divergences,
      contains(
        isA<CrossSourceDivergence>()
            .having((item) => item.severity, 'severity', Severity.blocker)
            .having((item) => item.fields, 'fields', contains('correctAnswer')),
      ),
    );
  });

  test('structural checks find invalid answer and duplicate option', () {
    final record = question(
      sourceId: 'runtime',
      sourcePath: 'runtime.dart',
      row: 1,
      options: const ['A', 'A', 'C'],
      correctIndex: 8,
      correctText: 'X',
    );
    final ids = runChecks([record]).map((issue) => issue.checkId).toSet();
    expect(ids, containsAll({'duplicate_option', 'invalid_correct_answer'}));
  });

  test('answer leak ignores short answers but catches meaningful answer', () {
    final short = question(
      sourceId: 'a',
      sourcePath: 'a.csv',
      row: 1,
      prompt: 'A kîjan e?',
      options: const ['A', 'B'],
      correctText: 'A',
    );
    final leak = question(
      sourceId: 'b',
      sourcePath: 'b.csv',
      row: 2,
      prompt: 'Parîs paytexta kîjan welatî ye?',
    );
    expect(
      runChecks([short]).where((i) => i.checkId == 'answer_leak'),
      isEmpty,
    );
    expect(runChecks([leak]).map((i) => i.checkId), contains('answer_leak'));
  });

  test('Turkish template is marked heuristic critical', () {
    final record = question(
      sourceId: 'runtime',
      sourcePath: 'runtime.dart',
      row: 1,
      prompt: 'Aşağıdakilerden hangisidir?',
    );
    expect(
      runChecks([record]),
      contains(
        isA<AuditIssue>()
            .having((issue) => issue.checkId, 'check', 'turkish_template')
            .having((issue) => issue.severity, 'severity', Severity.critical),
      ),
    );
  });

  test('near duplicate is an explicit candidate, not exact duplicate', () {
    final a = question(sourceId: 'a', sourcePath: 'a.csv', row: 1);
    final b = question(
      sourceId: 'b',
      sourcePath: 'b.csv',
      row: 2,
      id: 'q2',
      prompt: 'Paytexta welatê Fransa kîjan bajar e?',
    );
    final issues = runDuplicateChecks([a, b]);
    expect(issues.map((i) => i.checkId), contains('near_duplicate_candidate'));
    expect(issues.map((i) => i.checkId), isNot(contains('exact_duplicate')));
  });

  test('near duplicate tokenization happens once per record', () {
    final records = List.generate(
      600,
      (index) => question(
        sourceId: 'batch',
        sourcePath: 'batch.csv',
        row: index + 1,
        id: 'q$index',
        prompt: 'Paytexta welatê test $index kîjan bajar e?',
      ),
    );
    final diagnostics = DuplicateDiagnostics();
    runDuplicateChecks(records, diagnostics: diagnostics);
    expect(diagnostics.tokenizationCount, records.length);
  });

  test('same near-duplicate candidate is emitted once', () {
    final records = [
      question(sourceId: 'a', sourcePath: 'a.csv', row: 1, id: 'q1'),
      question(
        sourceId: 'b',
        sourcePath: 'b.csv',
        row: 2,
        id: 'q2',
        prompt: 'Paytexta welatê Fransa kîjan bajar e?',
      ),
      question(
        sourceId: 'c',
        sourcePath: 'c.csv',
        row: 3,
        id: 'q3',
        prompt: 'Paytexta dewleta Fransa kîjan bajar e?',
      ),
    ];
    final near = runDuplicateChecks(
      records,
    ).where((issue) => issue.checkId == 'near_duplicate_candidate').toList();
    expect(
      near.map((issue) => issue.fingerprint).toSet(),
      hasLength(near.length),
    );
  });
}
