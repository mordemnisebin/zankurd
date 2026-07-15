import 'package:flutter_test/flutter_test.dart';

import '../../tool/question_quality/adjudication/core.dart';
import '../../tool/question_quality/adjudication/models.dart';
import '../../tool/question_quality/adjudication/source_loader.dart';
import '../../tool/question_quality/src/models.dart';

QuestionRecord record({
  String path = 'source.csv',
  int row = 2,
  String? id = 'q1',
  List<String> options = const ['A', 'B', 'C', 'D'],
  int? correctIndex = 0,
  String? correctText = 'A',
}) => QuestionRecord(
  sourceId: 'source',
  sourceRole: SourceRole.importCandidate,
  sourcePath: path,
  sourceFormat: 'csv',
  sourceRow: row,
  sourceRecordId: id,
  canonicalGroup: 'questions',
  prompt: 'Prompt',
  options: options,
  correctOptionIndex: correctIndex,
  correctOptionText: correctText,
);

void main() {
  group('correct-value evidence', () {
    test('parses answer letters', () {
      final result = interpretCorrectValue('C', const ['a', 'b', 'c', 'd']);
      expect(result.index, 2);
      expect(result.text, 'c');
      expect(result.rule, 'letter_A_to_D');
    });

    test('supports explicit zero-based numeric indexes', () {
      final result = interpretCorrectValue('2', const [
        'a',
        'b',
        'c',
        'd',
      ], numericBase: NumericBase.zeroBased);
      expect(result.index, 2);
      expect(result.text, 'c');
    });

    test('supports explicit one-based numeric indexes', () {
      final result = interpretCorrectValue('2', const [
        'a',
        'b',
        'c',
        'd',
      ], numericBase: NumericBase.oneBased);
      expect(result.index, 1);
      expect(result.text, 'b');
    });

    test('parses exact option text', () {
      final result = interpretCorrectValue('Bersiva rast', const [
        'şaş',
        'Bersiva rast',
        'din',
        'tune',
      ]);
      expect(result.index, 1);
      expect(result.rule, 'exact_option_text');
    });
  });

  group('source matching', () {
    test('locates a unique record by path row and id', () {
      final result = locateOriginalRecord(
        const IssueReference(
          fingerprint: 'fp',
          sourcePath: 'source.csv',
          sourceRow: 2,
          recordId: 'q1',
        ),
        [record()],
      );
      expect(result.status, LocateStatus.located);
      expect(result.record?.sourceRecordId, 'q1');
    });

    test('reports ambiguity when two records match', () {
      final result = locateOriginalRecord(
        const IssueReference(
          fingerprint: 'fp',
          sourcePath: 'source.csv',
          sourceRow: 2,
          recordId: 'q1',
        ),
        [record(), record()],
      );
      expect(result.status, LocateStatus.ambiguous);
    });

    test('reports a missing source explicitly', () {
      final result = locateOriginalRecord(
        const IssueReference(
          fingerprint: 'fp',
          sourcePath: 'missing.csv',
          sourceRow: 2,
          recordId: 'q1',
        ),
        [record()],
      );
      expect(result.status, LocateStatus.notFound);
    });
  });

  test('sampling is stable and ordered by role source row fingerprint', () {
    final candidates = <SampleCandidate>[
      const SampleCandidate('runtime_primary', 'b', 2, 'z'),
      const SampleCandidate('import_candidate', 'a', 4, 'b'),
      const SampleCandidate('import_candidate', 'a', 3, 'c'),
      const SampleCandidate('import_candidate', 'a', 3, 'a'),
    ];
    final first = deterministicSample(candidates, {'import_candidate': 2});
    final second = deterministicSample(candidates.reversed, {
      'import_candidate': 2,
    });
    expect(first.map((item) => item.fingerprint), ['a', 'c']);
    expect(second.map((item) => item.fingerprint), ['a', 'c']);
  });

  test('runtime reachability is explicit and conservative', () {
    expect(
      classifyRuntimeReachability('offline_runtime_bank'),
      RuntimeReachability.runtimeActive,
    );
    expect(
      classifyRuntimeReachability('active_import_ready'),
      RuntimeReachability.importActiveNotRuntime,
    );
    expect(
      classifyRuntimeReachability('wave2_publish_candidates'),
      RuntimeReachability.publishCandidateNotRuntime,
    );
    expect(
      classifyRuntimeReachability('unmapped'),
      RuntimeReachability.unknown,
    );
  });

  test(
    'answer leak distinguishes natural entity context from exposed answer',
    () {
      expect(
        classifyAnswerLeak(
          prompt: 'What is the capital city of Monaco?',
          correctText: 'Monaco',
        ),
        Adjudication.factualVerificationRequired,
      );
      expect(
        classifyAnswerLeak(
          prompt: 'Görsel etiketi "rast" kavramını gösteriyor.',
          correctText: 'rast',
        ),
        Adjudication.confirmedDataDefect,
      );
      expect(
        classifyAnswerLeak(
          prompt: 'Who is the main character in "The Stanley Parable"?',
          correctText: 'Stanley',
        ),
        Adjudication.confirmedDataDefect,
      );
      expect(
        classifyAnswerLeak(
          prompt: 'Di hevoka "Ez diçim malê" de lêker kîjan e?',
          correctText: 'diçim',
        ),
        Adjudication.parserFalsePositive,
      );
      expect(
        classifyAnswerLeak(
          prompt:
              'Görsel etiketi "rast" kavramını gösteriyor. Doğru anlam hangisidir?',
          correctText: 'doğru',
        ),
        Adjudication.parserFalsePositive,
      );
    },
  );

  test('valid answer letter is not relabeled invalid by duplicate options', () {
    final result = classifyInvalidCorrectAnswer(
      rawCorrect: 'C',
      record: record(
        options: const ['Su', 'ev', 'su', 'te'],
        correctIndex: 2,
        correctText: 'su',
      ),
    );
    expect(result, Adjudication.parserFalsePositive);
  });

  test('terminal punctuation collisions are parser false positives', () {
    final result = classifyInvalidCorrectAnswer(
      rawCorrect: 'A',
      record: record(
        options: const ['?:', '??', 'if then', '?'],
        correctIndex: 0,
        correctText: '?:',
      ),
    );
    expect(result, Adjudication.parserFalsePositive);
    expect(
      duplicateOptionForm(const ['?:', '??', 'if then', '?']),
      'punctuation_normalization_collision',
    );
  });

  test('duplicate option form distinguishes exact and case-only copies', () {
    expect(
      duplicateOptionForm(const ['Rast', 'Şaş', '-', '-']),
      'exact_duplicate',
    );
    expect(
      duplicateOptionForm(const ['Şiir', 'roman', 'şiir', 'fıkra']),
      'case_only_duplicate',
    );
  });

  test('adjudication CSV parser preserves quoted commas and newlines', () {
    final rows = parseAdjudicationCsv(
      'id,prompt,correct\r\nq1,"Rêz, yek\nRêz du",B\r\n',
    );
    expect(rows, [
      ['id', 'prompt', 'correct'],
      ['q1', 'Rêz, yek\nRêz du', 'B'],
    ]);
  });

  test('raw CSV evidence uses physical source row and named column', () {
    final rows = parseAdjudicationCsv(
      'id,prompt,correct\nq1,Pirs,A\nq2,Pirs din,C\n',
    );
    expect(rawCsvValue(rows, sourceRow: 3, column: 'correct'), 'C');
    expect(rawCsvValue(rows, sourceRow: 8, column: 'correct'), isNull);
  });

  test(
    'copy identity crosses manifest canonical groups when id and prompt match',
    () {
      final first = record();
      final second = QuestionRecord(
        sourceId: 'copy',
        sourceRole: SourceRole.candidatePool,
        sourcePath: 'copy.csv',
        sourceFormat: 'csv',
        sourceRow: 8,
        sourceRecordId: 'q1',
        canonicalGroup: 'different_group',
        prompt: 'Prompt',
        options: const ['A', 'B', 'C', 'D'],
        correctOptionIndex: 0,
        correctOptionText: 'A',
      );
      expect(adjudicationCopyIdentity(first), adjudicationCopyIdentity(second));
    },
  );
}
