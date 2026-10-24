import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/data/local_data_storage.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/data/word_list_store.dart';
import 'package:zankurd_mobile/src/data/word_drill.dart';

/// Kişisel kelime listesi ve Leitner tekrarı (2026-10-24).
///
/// ## Kusur
///
/// Sözlükte bir kelimeyi "sonra çalışırım" diye kaydetmenin yolu yoktu; öğrenen
/// aynı sözcüğü her seferinde yeniden aratıyor, bildiği ile bilmediğini
/// ayıramıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Liste kullanıcıya bağlı yerel bir kayıttır. Anahtarı kullanıcı kapsamına
/// bağlamayı unutmak ya da kutu geçişini yanlış yazmak hiçbir ekranı
/// bozmaz: yalnız bir hesabın kelimeleri ötekine karışır ya da tekrar
/// zamanları sessizce kayar.
///
/// ## Kural
///
/// * Liste kullanıcı başına ayrı anahtarda durur ve yeniden açılınca döner.
/// * Leitner: kutu 1..5, aralıklar 1/2/4/8/16 gün; doğru -> bir üst kutu
///   (en çok 5), yanlış -> 1. kutu.
/// * Bugünkü tekrar sayısı yalnız vadesi gelmiş kelimeleri sayar; bir oturum
///   en çok 10 kelimedir.
void main() {
  late InMemoryDataStorage storage;
  final t0 = DateTime(2026, 10, 24, 9);

  setUp(() {
    storage = InMemoryDataStorage();
    WordListStore.resetInstance();
    LocalProgressScope.debugReset();
  });

  tearDown(() {
    WordListStore.resetInstance();
    LocalProgressScope.debugReset();
  });

  group('kullanıcı başına saklama', () {
    test('liste kullanıcıya bağlıdır; hesap değişince karışmaz', () async {
      LocalProgressScope.bind('kullanici-1');
      final first = await WordListStore.load(storage: storage);
      await first.add('rojbas', now: t0);
      expect(first.physicalKey, contains('kullanici-1'));

      LocalProgressScope.bind('kullanici-2');
      final second = await WordListStore.load(storage: storage);
      expect(second.contains('rojbas'), isFalse);
      expect(second.count, 0);
      await second.add('evarbas', now: t0);

      LocalProgressScope.bind('kullanici-1');
      final back = await WordListStore.load(storage: storage);
      expect(back.contains('rojbas'), isTrue);
      expect(back.contains('evarbas'), isFalse);
    });

    test('liste yeniden açılınca kutu ve vade ile birlikte döner', () async {
      LocalProgressScope.bind('kullanici-1');
      final store = await WordListStore.load(storage: storage);
      await store.add('rojbas', now: t0);
      await store.recordReview('rojbas', correct: true, now: t0);

      WordListStore.resetInstance();
      final restored = await WordListStore.load(storage: storage);
      final word = restored.wordFor('rojbas')!;
      expect(word.box, 2);
      expect(word.reviews, 1);
      expect(word.dueAtMs, addCalendarDays(t0, 2).millisecondsSinceEpoch);
    });

    test(
      'sözlükte olmayan kimlik eklenmez, eski kayıt sessizce atlanır',
      () async {
        LocalProgressScope.bind('kullanici-1');
        final store = await WordListStore.load(storage: storage);
        expect(await store.add('yok-boyle-bir-madde'), isFalse);
        expect(store.count, 0);

        await storage.setString(
          store.physicalKey,
          '{"yok-boyle-bir-madde":{"box":1,"due":0,"added":1,"n":0},'
          '"rojbas":{"box":1,"due":0,"added":2,"n":0}}',
        );
        WordListStore.resetInstance();
        final restored = await WordListStore.load(storage: storage);
        expect(restored.words.map((w) => w.entryId), ['rojbas']);
        expect(restored.dueCount(now: t0), 1);
      },
    );

    test(
      'toggle ekler, ikinci çağrı çıkarır; dinleyiciler haber alır',
      () async {
        final store = await WordListStore.load(storage: storage);
        var notified = 0;
        store.addListener(() => notified++);

        expect(await store.toggle('rojbas', now: t0), isTrue);
        expect(store.contains('rojbas'), isTrue);
        expect(await store.toggle('rojbas', now: t0), isFalse);
        expect(store.contains('rojbas'), isFalse);
        expect(notified, 2);
      },
    );
  });

  group('Leitner geçişleri', () {
    test('aralıklar 1, 2, 4, 8, 16 gündür', () {
      expect(LeitnerSchedule.boxCount, 5);
      expect(
        [
          for (var box = 1; box <= 5; box++)
            LeitnerSchedule.intervalForBox(box),
        ],
        [1, 2, 4, 8, 16],
      );
    });

    test('doğru bir üst kutuya çıkar, 5te kalır; yanlış 1e döner', () {
      expect(LeitnerSchedule.boxAfter(1, correct: true), 2);
      expect(LeitnerSchedule.boxAfter(4, correct: true), 5);
      expect(LeitnerSchedule.boxAfter(5, correct: true), 5);
      expect(LeitnerSchedule.boxAfter(5, correct: false), 1);
      expect(LeitnerSchedule.boxAfter(3, correct: false), 1);
    });

    test('yeni kelime 1. kutuda ve hemen vadesindedir', () async {
      final store = await WordListStore.load(storage: storage);
      await store.add('rojbas', now: t0);
      final word = store.wordFor('rojbas')!;
      expect(word.box, 1);
      expect(word.isDue(t0), isTrue);
    });

    test(
      'doğru cevap kutuyu artırır ve vadeyi kutu aralığı kadar öteler',
      () async {
        final store = await WordListStore.load(storage: storage);
        await store.add('rojbas', now: t0);

        var at = t0;
        for (final (box, days) in [(2, 2), (3, 4), (4, 8), (5, 16), (5, 16)]) {
          await store.recordReview('rojbas', correct: true, now: at);
          final word = store.wordFor('rojbas')!;
          expect(word.box, box);
          expect(
            word.dueAtMs,
            addCalendarDays(at, days).millisecondsSinceEpoch,
          );
          at = addCalendarDays(at, days);
        }
      },
    );

    test('yanlış cevap 1. kutuya döndürür ve yarına bırakır', () async {
      final store = await WordListStore.load(storage: storage);
      await store.add('rojbas', now: t0);
      for (var i = 0; i < 3; i++) {
        await store.recordReview('rojbas', correct: true, now: t0);
      }
      expect(store.wordFor('rojbas')!.box, 4);

      await store.recordReview('rojbas', correct: false, now: t0);
      final word = store.wordFor('rojbas')!;
      expect(word.box, 1);
      expect(word.dueAtMs, addCalendarDays(t0, 1).millisecondsSinceEpoch);
    });

    test('listede olmayan kelime için tekrar kaydı yok sayılır', () async {
      final store = await WordListStore.load(storage: storage);
      expect(await store.recordReview('rojbas', correct: true), isFalse);
    });
  });

  group('bugünkü tekrar sayısı', () {
    test('yalnız vadesi gelenleri sayar ve vade geldikçe artar', () async {
      final store = await WordListStore.load(storage: storage);
      await store.add('rojbas', now: t0);
      await store.add('evarbas', now: t0);
      await store.add('sevbas', now: t0);
      expect(store.dueCount(now: t0), 3);

      await store.recordReview('rojbas', correct: true, now: t0); // +2 gün
      await store.recordReview('evarbas', correct: false, now: t0); // +1 gün
      expect(store.dueCount(now: t0), 1);
      expect(store.dueCount(now: addCalendarDays(t0, 1)), 2);
      expect(store.dueCount(now: addCalendarDays(t0, 2)), 3);
    });

    test('oturum en çok 10 kelime, en çok geciken başta', () async {
      final store = await WordListStore.load(storage: storage);
      final ids = LearnerLexicon.entries.take(14).map((e) => e.id).toList();
      for (var i = 0; i < ids.length; i++) {
        await store.add(ids[i], now: t0.add(Duration(minutes: i)));
      }
      final session = store.sessionWords(now: addCalendarDays(t0, 1));
      expect(WordListStore.sessionCap, 10);
      expect(session.length, 10);
      expect(session.first.entryId, ids.first);
      expect(store.dueCount(now: addCalendarDays(t0, 1)), 14);
    });
  });

  group('tekrar sorusu', () {
    test('dört farklı şık, tam bir doğru, belirlenimli', () {
      final entry = LearnerLexicon.byId('rojbas')!;
      final a = WordReviewQuestion.build(entry, random: math.Random(7));
      final b = WordReviewQuestion.build(entry, random: math.Random(7));
      expect(a.options, b.options);
      expect(a.options.length, 4);
      expect(a.options.toSet().length, 4);
      expect(a.options.where(a.isCorrect).length, 1);
      expect(a.correctMeaning, entry.meaningTr);
    });

    test('çeldirici doğru anlamın bir parçasını paylaşmaz', () {
      // `Günaydın / İyi günler` doğruyken `İyi günler` şıkkı iki doğru üretirdi.
      final entry = LearnerLexicon.byId('rojbas')!;
      for (var seed = 0; seed < 40; seed++) {
        final q = WordReviewQuestion.build(entry, random: math.Random(seed));
        for (final option in q.options.where((o) => !q.isCorrect(o))) {
          final folded = LearnerLexicon.foldForSearch(option);
          expect(folded, isNot('gunaydin'), reason: 'seed $seed');
          expect(folded, isNot('iyi gunler'), reason: 'seed $seed');
        }
      }
    });
  });

  group('yazma sırası ve takvim günü (dış inceleme 2026-10-24)', () {
    // ## Kusur
    //
    // `_persist()` beklenmiyordu ve yazmalar örtüşebiliyordu: yavaş bir ilk
    // yazma (yalnız "a" var) ikincisinden SONRA bitince diskte eski JSON
    // kalıyor, kullanıcı "b"yi ve ilerlemesini kaybediyordu.
    //
    // ## Niçin sessiz kalırdı
    //
    // Bellekteki durum doğrudur; kayıp yalnız uygulama kapanıp açılınca
    // görünür.
    //
    // ## Kural
    //
    // Yazmalar tek kuyrukta sırayla yapılır; son durum her zaman diskte kalır.
    test('örtüşen yazmalar sıraya girer, son durum diskte kalır', () async {
      final slow = _SlowFirstWriteStorage();
      final store = await WordListStore.load(storage: slow);
      await Future.wait([
        store.add('rojbas', now: t0),
        store.add('evarbas', now: t0),
        store.recordReview('rojbas', correct: true, now: t0),
      ]);
      WordListStore.resetInstance();
      final restored = await WordListStore.load(storage: slow);
      expect(restored.contains('rojbas'), isTrue);
      expect(restored.contains('evarbas'), isTrue);
      expect(restored.wordFor('rojbas')!.box, 2);
    });

    test('vade yerel TAKVİM gününe göre hesaplanır (24 saat değil)', () async {
      final store = await WordListStore.load(storage: storage);
      // Avrupa'da 2026-03-29 yaz saatine geçiş günü; TZ=Europe/Berlin ile
      // koşunca 24 saatlik toplama duvar saatini bir saat kaydırır.
      final at = DateTime(2026, 3, 28, 9);
      await store.add('rojbas', now: at);
      await store.recordReview('rojbas', correct: true, now: at); // 2 gün
      expect(
        store.wordFor('rojbas')!.dueAtMs,
        DateTime(2026, 3, 30, 9).millisecondsSinceEpoch,
      );
    });
  });
}

/// İlk yazma yavaş, sonrakiler hızlı: sıraya alınmazsa ilk yazma en son biter.
class _SlowFirstWriteStorage extends InMemoryDataStorage {
  var _calls = 0;

  @override
  Future<bool> setString(String key, String value) async {
    final slow = _calls++ == 0;
    if (slow) await Future<void>.delayed(const Duration(milliseconds: 60));
    return super.setString(key, value);
  }
}
