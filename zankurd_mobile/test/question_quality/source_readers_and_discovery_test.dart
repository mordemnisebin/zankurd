import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tool/question_quality/src/discovery.dart';
import '../../tool/question_quality/src/models.dart';
import '../../tool/question_quality/src/source_readers.dart';

SourceDefinition source({
  required String id,
  required String parser,
  Map<String, String> columns = const {},
}) => SourceDefinition(
  id: id,
  description: id,
  path: '$id.data',
  role: SourceRole.importCandidate,
  parser: parser,
  canonicalGroup: 'test',
  reportIncluded: true,
  gateIncluded: true,
  productionLike: true,
  precedence: 100,
  expectedRecordCount: null,
  notes: '',
  columns: columns,
);

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('question-quality-'));
  tearDown(() => temp.deleteSync(recursive: true));

  test('CSV reader supports quoted multiline values and answer letters', () {
    final file = File('${temp.path}/bank.csv')
      ..writeAsStringSync(
        'id,prompt,a,b,c,d,correct,category,difficulty,explanation\n'
        'q1,"Rêza\nduyem",A,B,C,D,C,Ziman,2,"Ravekirin"\n',
      );
    final result = readSource(
      source(
        id: 'csv',
        parser: 'csv',
        columns: const {
          'id': 'id',
          'prompt': 'prompt',
          'optionA': 'a',
          'optionB': 'b',
          'optionC': 'c',
          'optionD': 'd',
          'correct': 'correct',
          'category': 'category',
          'difficulty': 'difficulty',
          'explanation': 'explanation',
        },
      ),
      file,
      repositoryRelativePath: 'bank.csv',
    );
    expect(result.stats.read, 1);
    expect(result.stats.headers, 1);
    expect(result.stats.parseErrors, 0);
    expect(result.records.single.prompt, 'Rêza\nduyem');
    expect(result.records.single.correctOptionIndex, 2);
    expect(result.records.single.correctOptionText, 'C');
  });

  test('Dart reader extracts QuizQuestion blocks without executing code', () {
    final file = File('${temp.path}/bank.dart')
      ..writeAsStringSync('''
const bank = <QuizQuestion>[
  QuizQuestion(
    id: 'q1',
    category: 'Ziman',
    prompt: 'Pirs?',
    answers: ['A', 'B'],
    correctAnswer: 'B',
    explanation: 'Ravekirin.',
    difficulty: 1,
  ),
];
''');
    final result = readSource(
      source(id: 'dart', parser: 'dart_quiz_question'),
      file,
      repositoryRelativePath: 'lib/bank.dart',
    );
    expect(result.stats.read, 1);
    expect(result.records.single.sourceRecordId, 'q1');
    expect(result.records.single.options, ['A', 'B']);
    expect(result.records.single.correctOptionIndex, 1);
  });

  test('JSON reader maps configured fields', () {
    final file = File('${temp.path}/bank.json')
      ..writeAsStringSync(
        '[{"qid":"q1","question":"Pirs?","answers":["A","B"],"answer":"B"}]',
      );
    final result = readSource(
      source(
        id: 'json',
        parser: 'json',
        columns: const {
          'id': 'qid',
          'prompt': 'question',
          'options': 'answers',
          'correct': 'answer',
        },
      ),
      file,
      repositoryRelativePath: 'bank.json',
    );
    expect(result.records.single.correctOptionIndex, 1);
  });

  test('parse error is counted and never silently discarded', () {
    final file = File('${temp.path}/broken.json')..writeAsStringSync('{broken');
    final result = readSource(
      source(id: 'broken', parser: 'json'),
      file,
      repositoryRelativePath: 'broken.json',
    );
    expect(result.stats.parseErrors, 1);
    expect(result.errors, isNotEmpty);
  });

  test(
    'discovery excludes documentation and reports but finds unknown data',
    () {
      Directory(
        '${temp.path}/docs/audit/question_quality/2026-07-15',
      ).createSync(recursive: true);
      File(
        '${temp.path}/docs/audit/question_quality/2026-07-15/summary.json',
      ).writeAsStringSync('{}');
      File('${temp.path}/docs/question_quality_report.csv')
        ..createSync(recursive: true)
        ..writeAsStringSync('id,prompt,correct_option\n');
      Directory('${temp.path}/reports').createSync();
      File(
        '${temp.path}/reports/question_review.json',
      ).writeAsStringSync('[{"prompt":"Pirs?"}]');
      Directory('${temp.path}/test/fixtures').createSync(recursive: true);
      File(
        '${temp.path}/test/fixtures/question_bank.csv',
      ).writeAsStringSync('id,prompt,correct_option\n');
      File(
        '${temp.path}/README.md',
      ).writeAsStringSync('# Question audit report');
      Directory('${temp.path}/data').createSync();
      File(
        '${temp.path}/data/new_questions.csv',
      ).writeAsStringSync('id,prompt,correct_option\n');
      final discovered = discoverPotentialQuestionSources(
        temp,
      ).map((item) => item.path).toList();
      expect(discovered, contains('data/new_questions.csv'));
      for (final ignored in <String>[
        'docs/audit/question_quality/2026-07-15/summary.json',
        'docs/question_quality_report.csv',
        'reports/question_review.json',
        'test/fixtures/question_bank.csv',
        'README.md',
      ]) {
        expect(discovered, isNot(contains(ignored)));
      }
    },
  );
}
