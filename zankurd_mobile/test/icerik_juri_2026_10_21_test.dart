import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

import 'support/widget_test_helpers.dart';

/// Jüri onaylı içerik düzeltmeleri (2026-10-21).
///
/// ## Kusur
///
/// Slayt metinlerinde yanlış Kurmancî (guhdar dike, Lingê min, "Alfabe: Alfabe"),
/// yanlış genelleyen bir kural cümlesi (weather_1: "e hava için, im kişi için")
/// ve olgusal hata ("12 meslek", derste 7 var) duruyordu; questions_1 dersi de
/// çift boşluklu soruları havuzdan çıkınca boşluk doldurmasız kalmıştı.
///
/// ## Niçin sessiz kalıyordu
///
/// Slayt metnini hiçbir test okumaz; yanlış bir ek cümlesi derleme ve analizden
/// geçer, öğrenen yanlış kuralı ezberler.
///
/// ## Bekçi
///
/// Beş düzeltme yerel veride durur, eski metinler yoktur; questions_1'in altı
/// yeni boşluk doldurma sorusu oynanabilirdir.
Future<String> _slide(String lesson, int order) async {
  final repo = freshMockRepository();
  final s = (await repo.loadLessonSlides(
    lesson,
  )).firstWhere((x) => x.order == order);
  return '${s.contentKu}\n${s.contentTr}';
}

void main() {
  test('school_1 slayt 5: guhdarî dike', () async {
    final t = await _slide('school_1', 5);
    expect(t, contains('guhdarî dike'));
    expect(t, isNot(contains('guhdar dike')));
  });

  test('body_1 slayt 4: Linga min diêşe', () async {
    final t = await _slide('body_1', 4);
    expect(t, contains('Linga min diêşe'));
    expect(t, isNot(contains('Lingê min diêşe')));
  });

  test('weather_1 slayt 5: ek son sese göre seçilir', () async {
    final t = await _slide('weather_1', 5);
    expect(t, contains('ünsüzden sonra e / im, ünlüden sonra ye / me'));
    expect(t, isNot(contains('Hava için e, kişi için im')));
  });

  test('alphabet_1 slayt 1: Elîfbê', () async {
    final t = await _slide('alphabet_1', 1);
    expect(t, contains('• Elîfbê: Alfabe'));
    expect(t, isNot(contains('• Alfabe: Alfabe')));
  });

  test('jobs_1 slayt 1: 7 meslek', () async {
    final t = await _slide('jobs_1', 1);
    expect(t, contains('Bu derste 7 meslek öğreneceğiz.'));
    expect(t, isNot(contains('12 meslek')));
  });

  test('questions_1: altı yeni boşluk doldurma sorusu oynanabilir', () {
    const policy = QuestionContentPolicy();
    final ids = [for (var i = 137; i <= 142; i++) 'dersler2_2026_10_08_0$i'];
    final all = QuestionBankLoader.instance.allQuestions;
    for (final id in ids) {
      final q = all.firstWhere((x) => x.id == id);
      expect(q.type, QuestionType.fillInBlank, reason: id);
      expect(q.metadata?.learningLessonId, 'questions_1', reason: id);
      expect(policy.isPlayable(q), isTrue, reason: id);
    }
  });
}
