import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/data/seen_question_store.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/services/question_set_policy.dart';

/// 2.1.2 W6 — soru seçimi ve banka erişimi bekçileri (ChatGPT Pro alan 6
/// #4/#7, alan 9 #2/#14).
QuizQuestion _q(String id, String prompt, List<String> answers, int correct) =>
    QuizQuestion(
      id: id,
      category: 'Ziman',
      prompt: prompt,
      answers: answers,
      correctAnswer: answers[correct],
      explanation: 'a',
      difficulty: 1,
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    SeenQuestionStore.resetInstance();
  });

  group('alan 6 #4: tur doldurma elenenleri geri eklemez', () {
    // Hepsi aynı dört şıkkı paylaşır: her biri ötekilerin cevabını ele verir.
    const shared = ['hezkirin', 'dîtin', 'bihîstin', 'xwarin'];
    final leaky = [
      for (var i = 0; i < 24; i++)
        _q('leaky-$i', 'Ciht $i: fîla vê pirsê çi ye?', shared, i % 4),
    ];
    // Sızıntısız, birbirinden bağımsız altı soru.
    final clean = [
      for (var i = 0; i < 6; i++)
        _q(
          'clean-$i',
          'Pirsa ${['yekem', 'duyem', 'sisêyem', 'çarem', 'pêncem', 'şeşem'][i]} derbarê babeta ${String.fromCharCode(0x61 + i)}$i',
          ['Cihê${i}A', 'Cihê${i}B', 'Cihê${i}C', 'Cihê${i}D'],
          0,
        ),
    ];

    test('havuzda temiz soru varken tur sızıntısız kalır', () async {
      for (var i = 0; i < 60; i++) {
        SharedPreferences.setMockInitialValues({});
        SeenQuestionStore.resetInstance();
        final repo = MockZanKurdRepository();
        final turn = await repo.selectFreshForTesting([...leaky, ...clean], 3);
        expect(turn, hasLength(3));
        for (var a = 0; a < turn.length; a++) {
          for (var b = a + 1; b < turn.length; b++) {
            expect(
              QuestionSetPolicy.leaksBetween(turn[a], turn[b]),
              isFalse,
              reason:
                  'tur ${turn.map((q) => q.id)}: temiz soru havuzda varken '
                  'elenmiş sızıntılı soru geri eklendi',
            );
          }
        }
      }
    });

    test('temiz soru yoksa tur yine de tam uzunlukta gelir', () async {
      final repo = MockZanKurdRepository();
      final turn = await repo.selectFreshForTesting(leaky, 5);
      expect(turn, hasLength(5));
    });
  });

  group('alan 6 #7: görülmüş geçmiş tavanı banka büyüklüğüne bağlı', () {
    test('tavan en az 3.000, büyük bankada bankayı kapsar', () {
      expect(SeenQuestionStore.trackedCapFor(1000), 3000);
      expect(SeenQuestionStore.trackedCapFor(6800), greaterThanOrEqualTo(6800));
      expect(SeenQuestionStore.trackedCapFor(20000), greaterThan(20000));
    });

    test('3.000\'den fazla görülmüş soru büyük bankada unutulmaz', () async {
      SeenQuestionStore.debugBankSize = 6800;
      addTearDown(() => SeenQuestionStore.debugBankSize = null);
      final store = await SeenQuestionStore.load();
      await store.markSeen([for (var i = 0; i < 5000; i++) 'q$i']);
      expect(store.seenCount, 5000);
      expect(store.isSeen('q0'), isTrue, reason: 'eski sabit tavan 3.000 idi');
    });
  });

  group('alan 9 #14: findById haritası', () {
    test(
      'ilk eşleşme kazanır (eski doğrusal tarama gibi) ve liste değişince yenilenir',
      () {
        final loader = QuestionBankLoader.instance;
        final first = _q('dup', 'ilk', ['a1', 'b1', 'c1', 'd1'], 0);
        final second = _q('dup', 'ikinci', ['a2', 'b2', 'c2', 'd2'], 0);
        loader.setQuestionsForTest([first, second]);
        expect(loader.findById('dup')?.prompt, 'ilk');
        expect(loader.findById('yok'), isNull);
        loader.setQuestionsForTest([second]);
        expect(loader.findById('dup')?.prompt, 'ikinci');
      },
    );
  });

  test('alan 9 #2: ana ekran açılışta soru seçimi (bilet) çağırmaz', () {
    final source = File('lib/src/screens/home_screen.dart').readAsStringSync();
    expect(
      source.contains('repo.loadQuestions('),
      isFalse,
      reason:
          'çevrimiçi depoda loadQuestions = prepare_verified_solo_questions '
          'RPC\'si; her ana ekran açılışında gereksiz sunucu bileti yazar.',
    );
  });
}
