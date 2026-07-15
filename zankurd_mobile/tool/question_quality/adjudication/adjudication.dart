import 'dart:io';

import 'generator.dart';

void main(List<String> args) {
  if (args.length != 1 || args.single != 'report') {
    stderr.writeln(
      'Usage: dart run tool/question_quality/adjudication/adjudication.dart report',
    );
    exitCode = 64;
    return;
  }
  final root = Directory.current;
  final run = generateAdjudication(
    root: root,
    issueDirectory: Directory('docs/audit/question_quality/2026-07-15'),
  );
  writeAdjudication(
    run,
    Directory('docs/audit/question_quality/adjudication_2026-07-15'),
  );
  stdout.writeln(
    'question-adjudication: invalid=${run.invalidReviews.length} '
    'leaks=${run.answerLeakReviews.length} '
    'duplicateSample=${run.duplicateOptionSample.length} '
    'correctDivergences=${run.crossSourceCorrectAnswerRows.length}',
  );
}
