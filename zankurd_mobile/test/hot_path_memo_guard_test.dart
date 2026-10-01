import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/subcategory_config.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/question_bank_loader.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/services/question_content_policy.dart';

/// Yeniden çizimde ve her çağrıda aynı işi baştan yapan üç sıcak yolun
/// bekçisi (2026-10-02 performans taraması).
///
/// Üçü de SESSİZ kusurdu: sonuç doğruydu, yalnız aynı hesap ya da aynı ağ
/// isteği her seferinde tekrarlanıyordu. Bu yüzden ne bir doğruluk testi
/// ne bir ekran görüntüsü kırmızıya döndü. Burada ölçü milisaniye değil
/// SAYIDIR (kaç kez hesaplandı / sorgulandı): koşucu makinesine bağlı
/// değildir, yani titremez.
class _CountingTagRepository extends MockZanKurdRepository {
  int tagCalls = 0;

  @override
  Future<String?> getPlayerTag() async {
    tagCalls++;
    return 'ABCD';
  }

  @override
  Future<List<Friend>> loadFriends() async => const [];

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async => const [];
}

class _SwappableSourceRepository extends MockZanKurdRepository {
  List<QuizQuestion> source = const [];

  @override
  List<QuizQuestion> get questions => source;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('playableQuestions önbelleği', () {
    test(
      'kaynak değişmedikçe AYNI liste döner (her çağrıda yeniden kurulmaz)',
      () {
        final repo = MockZanKurdRepository();
        expect(
          identical(repo.playableQuestions, repo.playableQuestions),
          isTrue,
        );
      },
    );

    test('içerik, önbelleksiz süzmeyle birebir aynıdır', () {
      final repo = MockZanKurdRepository();
      final expected = QuestionBankLoader.instance.allQuestions
          .where(const QuestionContentPolicy().isPlayable)
          .map((q) => q.id)
          .toList();
      expect(repo.playableQuestions.map((q) => q.id).toList(), expected);
      expect(expected.length, greaterThan(1000));
    });

    test('kaynak liste değişince önbellek düşer', () {
      final repo = _SwappableSourceRepository();
      final all = QuestionBankLoader.instance.allQuestions;
      repo.source = all.take(200).toList(growable: false);
      final first = repo.playableQuestions;
      repo.source = all.skip(200).take(300).toList(growable: false);
      final second = repo.playableQuestions;
      expect(identical(first, second), isFalse);
      expect(
        second.map((q) => q.id),
        repo.source
            .where(const QuestionContentPolicy().isPlayable)
            .map((q) => q.id),
      );
    });

    test('paylaşılan liste değiştirilemez (çağıran önbelleği bozamaz)', () {
      final list = MockZanKurdRepository().playableQuestions;
      expect(() => list.shuffle(), throwsUnsupportedError);
      expect(() => list.add(list.first), throwsUnsupportedError);
    });
  });

  group('alt kategori eşleşmesi', () {
    test('aynı soru için sonuç tekrarlanabilir (önbellekli = ilk hesap)', () {
      final questions = QuestionBankLoader.instance.allQuestions;
      final first = [
        for (final q in questions) SubcategoryConfig.getSubcategoryId(q),
      ];
      final second = [
        for (final q in questions) SubcategoryConfig.getSubcategoryId(q),
      ];
      expect(second, first);
      // Etiket de aynı eşleşmeden okunur; kimlikle çelişemez.
      for (final q in questions.take(400)) {
        final id = SubcategoryConfig.getSubcategoryId(q);
        final label = SubcategoryConfig.getSubcategoryLabel(q, true);
        expect(id.isEmpty, label.isEmpty, reason: q.id);
      }
    });

    test('visibleFor önbellek ısındıktan sonra tavan altında', () {
      final playable = MockZanKurdRepository().playableQuestions;
      for (final c in SubcategoryConfig.subcategories.keys) {
        SubcategoryConfig.visibleFor(c, playable); // ısıt
      }
      final watch = Stopwatch()..start();
      for (final c in SubcategoryConfig.subcategories.keys) {
        SubcategoryConfig.visibleFor(c, playable);
      }
      watch.stop();
      // Önbelleksiz ölçüm: 11 kategori 48-190 ms (JIT). Isınmış: 2-8 ms.
      // Tavan bilerek gevşek (40 ms); amaç gürültü değil sıçrama yakalamak.
      expect(
        watch.elapsedMilliseconds,
        lessThan(40),
        reason:
            'Isınmış visibleFor ${watch.elapsedMilliseconds} ms sürdü; '
            'alt kategori eşleşmesi yine her çağrıda hesaplanıyor olabilir.',
      );
    });
  });

  group('FriendsScreen', () {
    testWidgets('davet kodu yeniden çizimlerde tekrar sorgulanmaz', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final repo = _CountingTagRepository();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider<LanguageProvider>(
              create: (_) => LanguageProvider(initialLang: 'tr'),
            ),
          ],
          child: MaterialApp(home: FriendsScreen(repository: repo)),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.tagCalls, 1);

      // Arama kutusuna yazmak ekranın `setState`ini tetikler.
      final field = find.byType(TextField).first;
      await tester.enterText(field, 'ro');
      await tester.pump();
      await tester.enterText(field, 'roj');
      await tester.pumpAndSettle();

      expect(
        repo.tagCalls,
        1,
        reason:
            'Her yeniden çizimde getPlayerTag çağrılıyor: Supabase\'e her '
            'harfte bir profiles sorgusu gider.',
      );
    });
  });
}
