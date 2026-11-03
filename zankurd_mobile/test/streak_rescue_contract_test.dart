/// Ücretsiz "Seriyi kurtar" turu: kural ve çifte sayım bekçisi.
///
/// ## Kusur (önlenen)
///
/// Ücretli onarım aylık hak ve sunucu ledger'ıyla korunur; ücretsiz tur
/// yalnız cihazdadır. Korunmazsa (a) aynı kırılma hem turla hem jetonla
/// onarılıp seri iki kez sayılır, (b) tur sınırsız tekrarlanıp seri
/// bedavaya kalıcı korunur, (c) dondurma jetonu varken gereksiz teklif
/// çıkar, (d) başarısız tur teklifi yakar.
///
/// ## Niçin sessiz kalırdı
///
/// Hiçbir şey çökmez; yalnız seri sayısı yanlış (fazla) görünür. Bu yüzden
/// sayıları ve teklif kapanışlarını burada tek tek sabitliyoruz.
library;

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/services/streak_rescue_service.dart';

String _key(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

void main() {
  final now = DateTime(2026, 11, 10, 12);
  final twoAgo = DateTime(now.year, now.month, now.day - 2);

  Future<StreakStore> brokenStore({int freeze = 0, int current = 6}) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.streak.current': current,
      'zankurd.streak.best': current,
      'zankurd.streak.lastDay': _key(twoAgo),
      'zankurd.streak.freeze': freeze,
    });
    StreakStore.resetInstance();
    return StreakStore.load();
  }

  test('sabitler: 5 soru, en az 4 doğru, 7 gün', () {
    expect(StreakStore.rescueQuestions, 5);
    expect(StreakStore.rescueMinCorrect, 4);
    expect(StreakStore.rescueCooldownDays, 7);
  });

  test('son 24 saatte kırılan seri, jetonsuz: teklif var', () async {
    final store = await brokenStore();
    final offer = store.rescueOffer(now: now);
    expect(offer, isNotNull);
    expect(offer!.lostStreak, 6);
  });

  test('dondurma jetonu varsa teklif yok', () async {
    final store = await brokenStore(freeze: 1);
    expect(store.rescueOffer(now: now), isNull);
  });

  test(
    'kurtarma seriyi geri verir, çift sayım yok, ücretli onarım kapanır',
    () async {
      final store = await brokenStore();
      final offer = store.rescueOffer(now: now)!;
      expect(await store.applyRescue(offer, now: now), 6);
      // Aynı kırılma için ne ikinci kurtarma ne ücretli onarım.
      expect(store.rescueOffer(now: now), isNull);
      expect(store.repairOffer(now: now), isNull);
      // Eski teklifle ikinci uygulama hiçbir şey yazmaz.
      expect(await store.applyRescue(offer, now: now), isNull);
    },
  );

  test('ücretli onarım yapıldıysa kurtarma aynı kırılmada sunulmaz', () async {
    final store = await brokenStore();
    final offer = store.repairOffer(now: now)!;
    await store.applyRepair(offer, now: now);
    expect(store.rescueOffer(now: now), isNull);
  });

  test('kurtarma ücretli onarımın aylık hakkını harcamaz', () async {
    final store = await brokenStore();
    await store.applyRescue(store.rescueOffer(now: now)!, now: now);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('zankurd.streak.repairMonth'), isNull);
    expect(prefs.getString('zankurd.streak.rescueDay'), _key(now));
  });

  test('7 gün dolmadan yeni kırılmada teklif yok, dolunca var', () async {
    final store = await brokenStore();
    await store.applyRescue(store.rescueOffer(now: now)!, now: now);
    final prefs = await SharedPreferences.getInstance();
    // Sonraki kırılmayı kur: son oynanan gün = bugünden iki gün önce.
    for (final (days, expected) in [(3, false), (7, true)]) {
      final later = DateTime(now.year, now.month, now.day + days);
      SharedPreferences.setMockInitialValues({
        ...{for (final k in prefs.getKeys()) k: prefs.get(k)!},
        'zankurd.streak.current': 5,
        'zankurd.streak.lastDay': _key(
          DateTime(later.year, later.month, later.day - 2),
        ),
        'zankurd.streak.frozenDays': <String>[],
      });
      StreakStore.resetInstance();
      final fresh = await StreakStore.load();
      expect(fresh.rescueOffer(now: later) != null, expected, reason: '$days');
    }
  });

  group('tur soruları', () {
    final playable = MockZanKurdRepository().playableQuestions;

    test('tam 5 benzersiz soru; yanlış defteri yoksa bankadan', () async {
      SharedPreferences.setMockInitialValues({});
      MistakeStore.resetInstance();
      final picked = StreakRescueService.pickQuestions(
        mistakeStore: await MistakeStore.load(),
        playable: playable,
        random: Random(1),
      );
      expect(picked, hasLength(StreakStore.rescueQuestions));
      expect({for (final q in picked) q.id}, hasLength(5));
    });

    test('banka 5 sorudan azsa tur açılmaz', () async {
      SharedPreferences.setMockInitialValues({});
      MistakeStore.resetInstance();
      expect(
        StreakRescueService.pickQuestions(
          mistakeStore: await MistakeStore.load(),
          playable: playable.take(4).toList(),
        ),
        isEmpty,
      );
    });

    test('geçme: tamamlanmış ve en az 4 doğru', () {
      expect(StreakRescueService.passes(completed: true, correct: 4), isTrue);
      expect(StreakRescueService.passes(completed: true, correct: 3), isFalse);
      expect(StreakRescueService.passes(completed: false, correct: 5), isFalse);
    });
  });
}
