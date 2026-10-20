import 'package:flutter_test/flutter_test.dart';

import '../../tool/question_quality/src/checks.dart';
import '../../tool/question_quality/src/models.dart';

/// Boşluk doldurma sorusu tam bir `___` taşır.
///
/// 2026-10-21: dersler2_2026_10_08_0104–0109'da çeviri parantezine de `___`
/// konmuştu (`("Sen ___sin? ...")`); soru iki boşluklu görünüyor ama tek
/// cevap alıyordu. Hiçbir denetim bunu saymıyordu, çünkü kusur cevabın
/// doğruluğunda değil metnin biçimindeydi.
QuestionRecord _fill(
  String prompt, {
  String type = 'fillInBlank',
  String id = 'q1',
}) => QuestionRecord(
  sourceId: 's',
  sourceRole: SourceRole.runtimePrimary,
  sourcePath: 's.json',
  sourceFormat: 'synthetic',
  sourceRow: 1,
  sourceRecordId: id,
  runtimeId: id,
  canonicalGroup: 'questions',
  locale: 'ku-kmr',
  category: 'Ziman',
  difficulty: 1,
  prompt: prompt,
  options: const ['kî'],
  correctOptionIndex: 0,
  correctOptionText: 'kî',
  explanation: 'x',
  questionType: type,
);

List<AuditIssue> _blankIssues(QuestionRecord r) => runChecks([
  r,
]).where((i) => i.checkId == 'fill_in_blank_blank_count').toList();

void main() {
  test('tek boşluklu soru geçer', () {
    expect(_blankIssues(_fill('Hevokê temam bike: "Tu ___ yî?"')), isEmpty);
  });

  test('çift boşluklu soru engellenir', () {
    final issues = _blankIssues(
      _fill('Hevokê temam bike: "Tu ___ yî?" ("Sen ___sin?")'),
    );
    expect(issues, hasLength(1));
    expect(issues.single.severity, Severity.blocker);
  });

  test('boşluksuz soru engellenir', () {
    expect(_blankIssues(_fill('Hevokê temam bike: "Tu kî yî?"')), hasLength(1));
  });

  test('emekli kimlik kapıyı yeniden kırmaz', () {
    expect(
      _blankIssues(
        _fill(
          'Hevokê temam bike: "Tu ___ yî?" ("Sen ___sin?")',
          id: 'dersler2_2026_10_08_0104',
        ),
      ),
      isEmpty,
    );
  });

  test('başka tür sorular boşluk sayılmaz', () {
    expect(_blankIssues(_fill('Tu kî yî?', type: 'multipleChoice')), isEmpty);
  });
}
