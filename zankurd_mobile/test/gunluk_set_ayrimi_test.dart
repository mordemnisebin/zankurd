import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/data/seen_question_store.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';

import 'support/widget_test_helpers.dart';

/// Günlük setler ve görsel karışımı (2026-10-15).
///
/// ## Kusur
///
/// "Günün etkinliği" ile "Günün dersi" aynı `loadDailyQuestions` çağrısını
/// ve aynı gün tohumunu kullanıyordu: aynı kullanıcı iki girişte aynı 10
/// soruyu görüyordu. "Tekrar oyna" da görülen-soru deposuna bakmadan aynı
/// tohumdan aynı seti veriyordu. `_withVisualBlend` ise görselli soruları
/// banka sırasıyla ekliyordu: görselli soru gereken her tur aynı iki
/// fotoğrafı getiriyordu.
///
/// ## Niçin sessiz kaldı
///
/// Testler yalnız "yalnız oynanabilir sorular" ve "en az iki görselli"
/// diyordu; iki girişin ya da iki turun birbirinden FARKLI olduğunu hiçbir
/// şey ölçmüyordu — aynı set de bu koşulları sağlıyordu.
///
/// ## Bekçi
///
/// Ders ve etkinlik setleri ayrık; ilk oyun aynı gün sabit; tekrar turu
/// görülmüş soruları öne almaz; görsel karışımı adayları karıştırır,
/// görülmemişi seçer, turdaki soruyu iki kez eklemez.
QuizQuestion _q(String id, {bool image = false}) => QuizQuestion(
  id: id,
  category: 'Ziman',
  prompt: 'Pirsa $id çi ye?',
  answers: const ['a', 'b', 'c', 'd'],
  correctAnswer: 'a',
  explanation: 'Şîrove $id.',
  imageUrl: image ? 'https://example.test/$id.jpg' : null,
);

void main() {
  late MockZanKurdRepository repo;

  setUp(() {
    repo = freshMockRepository();
    SeenQuestionStore.resetInstance();
    QuestionBankLoader.instance.setQuestionsForTest([
      for (var i = 0; i < 80; i++) _q('p$i'),
    ]);
  });

  test('etkinlik seti ders setiyle kesişmez', () async {
    final lesson = await repo.loadDailyQuestions(limit: 10);
    final event = await repo.loadDailyEventQuestions(limit: 10);
    expect(lesson, hasLength(10));
    expect(event, hasLength(10));
    expect(
      lesson
          .map((q) => q.id)
          .toSet()
          .intersection(event.map((q) => q.id).toSet()),
      isEmpty,
    );
  });

  test('ilk oyunda günün dersi ve etkinliği aynı gün sabit kalır', () async {
    final a = await repo.loadDailyQuestions(limit: 10);
    final b = await repo.loadDailyQuestions(limit: 10);
    expect(a.map((q) => q.id), b.map((q) => q.id));
    final e1 = await repo.loadDailyEventQuestions(limit: 10);
    final e2 = await repo.loadDailyEventQuestions(limit: 10);
    expect(e1.map((q) => q.id), e2.map((q) => q.id));
  });

  test('tekrar turu görülmüş soruları öne almaz', () async {
    final first = await repo.loadDailyQuestions(limit: 10);
    final store = await SeenQuestionStore.load();
    await store.markSeen(first.map((q) => q.id));
    final again = await repo.loadDailyQuestions(limit: 10, replay: true);
    expect(again, hasLength(10));
    expect(
      again
          .map((q) => q.id)
          .toSet()
          .intersection(first.map((q) => q.id).toSet()),
      isEmpty,
    );
  });

  group('görsel karışımı', () {
    final plain = [for (var i = 0; i < 8; i++) _q('d$i')];
    final images = [for (var i = 0; i < 10; i++) _q('g$i', image: true)];

    test('adayları banka sırasıyla değil karıştırarak seçer', () {
      final used = <String>{};
      for (var seed = 0; seed < 20; seed++) {
        final round = repo.withVisualBlendForTesting(
          plain,
          [...plain, ...images],
          8,
          Random(seed),
        );
        used.addAll(round.where((q) => q.hasImage).map((q) => q.id));
        expect(round.map((q) => q.id).toSet(), hasLength(round.length));
        expect(round.where((q) => q.hasImage).length, 2);
      }
      expect(used.length, greaterThan(4));
    });

    test('görülmemiş fotoğraflar öne alınır', () async {
      final store = await SeenQuestionStore.load();
      await store.markSeen(images.take(8).map((q) => q.id));
      for (var seed = 0; seed < 10; seed++) {
        final round = repo.withVisualBlendForTesting(
          plain,
          [...plain, ...images],
          8,
          Random(seed),
          store,
        );
        expect(round.where((q) => q.hasImage).map((q) => q.id).toSet(), {
          'g8',
          'g9',
        });
      }
    });

    test('turda zaten olan görselli soru bir daha eklenmez', () {
      final inRound = [...plain.take(6), images[0]];
      final round = repo.withVisualBlendForTesting(
        inRound,
        images,
        8,
        Random(1),
      );
      expect(round.map((q) => q.id).toSet(), hasLength(round.length));
    });
  });
}
