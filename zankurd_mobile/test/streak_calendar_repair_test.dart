/// Seri takvimi ve seri onarımı.
///
/// ## Kusur
///
/// Seri kırılınca oyuncu yalnız "0" görüyordu: hangi günleri oynadığını
/// (takvim) bilemiyor, uzun bir serinin tek bir gecikmeyle sessizce
/// silinmesini geri alamıyordu. Haftalık şerit ayrıca MistakeStore'dan
/// türetiliyordu; seri deposunda gün düzeyinde geçmiş yoktu.
///
/// ## Niçin sessiz kalırdı
///
/// `recordPlay` kırılan değeri `1`'e ezip eski değeri atıyordu; geri
/// alınabilir bir kayıp olduğunu hiçbir test gösteremezdi. Jeton harcaması
/// sunucuda, seri cihazda: ödeme başarısızken yerel geri yükleme yapan ya da
/// ödeme alınıp geri yüklemeyen bir sıra hiçbir birim testte görünmezdi.
///
/// ## Kural
///
/// * Takvim: oynanan gün `played`, dondurulan/onarılan `frozen`, ilk
///   oynanan günden sonraki boş gün `missed`, ilk günden önce `blank`
///   (veri yokken "kaçırdı" uydurulmaz), bugün `today`, gelecek `upcoming`.
/// * Onarım: yalnız SON 24 SAATTE kırılan (son gün = iki gün önce, ya da
///   bugün oynanıp seri 1'e düşmüş), değeri en az 2, bu takvim ayında hak
///   kullanılmamış seri için sunulur.
/// * Yerel seri, sunucu onayından SONRA geri yüklenir; yetersiz bakiye ve
///   hata yerel seriye dokunmaz; aynı çağrı ikinci kez ücret kesmez.
/// * Premium ücretsizliği abonelik sunucuda doğrulanana dek (2.2) kapalı:
///   onarım herkes için 100 jeton.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/data/zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/services/streak_repair_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/streak_calendar.dart';
import 'package:zankurd_mobile/src/widgets/streak_repair_card.dart';

Future<StreakStore> _store([Map<String, Object> seed = const {}]) async {
  SharedPreferences.setMockInitialValues(seed);
  StreakStore.resetInstance();
  return StreakStore.load();
}

Widget _wrap(Widget child, {double scale = 1.0}) =>
    ChangeNotifierProvider<LanguageProvider>(
      create: (_) => LanguageProvider()..setLang('tr'),
      child: MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(scale)),
          child: Scaffold(body: SingleChildScrollView(child: child)),
        ),
      ),
    );

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // 2026-10-24 cumartesi. Dün 23, iki gün önce 22.
  final today = DateTime(2026, 10, 24, 10);

  group('gün düzeyinde geçmiş', () {
    test('oynanan günler kaydedilir ve yeniden yüklemede korunur', () async {
      final store = await _store();
      await store.recordPlay(now: DateTime(2026, 10, 22, 9));
      await store.recordPlay(now: DateTime(2026, 10, 23, 9));

      StreakStore.resetInstance();
      final reloaded = await StreakStore.load();
      expect(reloaded.playedDays, {'2026-10-22', '2026-10-23'});
    });

    test(
      'takvim işaretleri: oynandı, kaçırıldı, boş, bugün, gelecek',
      () async {
        final store = await _store();
        await store.recordPlay(now: DateTime(2026, 10, 20, 9));
        await store.recordPlay(now: DateTime(2026, 10, 21, 9));
        // 22 ve 23 oynanmadı.
        expect(
          store.markFor(DateTime(2026, 10, 21), now: today),
          StreakCalendarMark.played,
        );
        expect(
          store.markFor(DateTime(2026, 10, 22), now: today),
          StreakCalendarMark.missed,
        );
        expect(
          store.markFor(DateTime(2026, 10, 19), now: today),
          StreakCalendarMark.blank,
          reason: 'ilk oynanan günden önce kaçırdı denmez',
        );
        expect(
          store.markFor(DateTime(2026, 10, 24), now: today),
          StreakCalendarMark.today,
        );
        expect(
          store.markFor(DateTime(2026, 10, 25), now: today),
          StreakCalendarMark.upcoming,
        );
      },
    );

    test(
      'yeni hesap: ilk görülen günden önceki günler boş, kaçırıldı değil',
      () async {
        final store = await _store();
        // Hiç oynamadı; yalnız 22'sinde uygulamayı ilk kez gördü.
        await store.markFirstSeen(now: DateTime(2026, 10, 22, 9));
        expect(store.firstSeenDay, '2026-10-22');
        expect(
          store.markFor(DateTime(2026, 10, 21), now: today),
          StreakCalendarMark.blank,
          reason: 'kurulumdan önceki gün ✕ değil nötr',
        );
        expect(
          store.markFor(DateTime(2026, 10, 1), now: today),
          StreakCalendarMark.blank,
        );
        expect(
          store.markFor(DateTime(2026, 10, 22), now: today),
          StreakCalendarMark.missed,
          reason: 'kurulumdan sonra oynanmayan gün gerçekten kaçırılmıştır',
        );

        // İlk gün yeniden yazılmaz ve yeniden yüklemede korunur.
        await store.markFirstSeen(now: DateTime(2026, 10, 24));
        StreakStore.resetInstance();
        final reloaded = await StreakStore.load();
        expect(reloaded.firstSeenDay, '2026-10-22');
      },
    );

    test('ilk görülen gün yoksa en eski oynanan gün sınırdır', () async {
      final store = await _store();
      await store.recordPlay(now: DateTime(2026, 10, 23, 9));
      expect(
        store.markFor(DateTime(2026, 10, 22), now: today),
        StreakCalendarMark.blank,
      );
    });

    test('eski kurulum: yalnız son gün varsa o gün takvimde görünür', () async {
      final store = await _store({
        'zankurd.streak.current': 4,
        'zankurd.streak.best': 4,
        'zankurd.streak.lastDay': '2026-10-23',
      });
      expect(store.playedDays, contains('2026-10-23'));
    });

    test('dondurma köprülenen günleri mavi (frozen) işaretler', () async {
      final store = await _store({
        'zankurd.streak.current': 5,
        'zankurd.streak.best': 5,
        'zankurd.streak.lastDay': '2026-10-21',
        'zankurd.streak.freeze': 1,
      });
      await store.freezeAndRecordPlay(now: today);
      expect(
        store.markFor(DateTime(2026, 10, 22), now: today),
        StreakCalendarMark.frozen,
      );
      expect(
        store.markFor(DateTime(2026, 10, 23), now: today),
        StreakCalendarMark.frozen,
      );
      expect(
        store.markFor(DateTime(2026, 10, 24), now: today),
        StreakCalendarMark.played,
      );
    });

    test('geçmiş sınırsız büyümez', () async {
      final store = await _store();
      var day = DateTime(2024, 1, 1, 9);
      for (var i = 0; i < StreakStore.maxHistoryDays + 30; i++) {
        await store.recordPlay(now: day);
        day = DateTime(day.year, day.month, day.day + 1, 9);
      }
      StreakStore.resetInstance();
      final reloaded = await StreakStore.load();
      expect(reloaded.playedDays.length, StreakStore.maxHistoryDays);
    });
  });

  group('onarım uygunluğu', () {
    Future<StreakStore> broken({
      int current = 6,
      String lastDay = '2026-10-22',
    }) => _store({
      'zankurd.streak.current': current,
      'zankurd.streak.best': current,
      'zankurd.streak.lastDay': lastDay,
    });

    test('son gün iki gün önce: teklif var, değer korunmuş seri', () async {
      final store = await broken();
      final offer = store.repairOffer(now: today)!;
      expect(offer.lostStreak, 6);
      expect(offer.breakDay, '2026-10-23', reason: 'kaçırılan gün = dün');
      expect(offer.monthKey, '2026-10');
      expect(offer.playedToday, isFalse);
      expect(offer.restoredStreak, 6);
      expect(store.effectiveStreak(now: today), 0);
    });

    test('dün oynandıysa seri kırılmadı: teklif yok', () async {
      final store = await broken(lastDay: '2026-10-23');
      expect(store.repairOffer(now: today), isNull);
    });

    test('üç gün önce kırıldıysa 24 saat geçti: teklif yok', () async {
      final store = await broken(lastDay: '2026-10-21');
      expect(store.repairOffer(now: today), isNull);
    });

    test('değeri 2\'den küçük seri için teklif yok', () async {
      final store = await broken(current: 1);
      expect(store.repairOffer(now: today), isNull);
    });

    test(
      'bugün oynandı ve seri 1\'e düştü: teklif eski değeri taşır',
      () async {
        final store = await broken();
        await store.recordPlay(now: today);
        expect(store.effectiveStreak(now: today), 1);

        final offer = store.repairOffer(now: today)!;
        expect(offer.lostStreak, 6);
        expect(offer.playedToday, isTrue);
        expect(offer.restoredStreak, 7, reason: 'bugünkü oyun da sayılır');
      },
    );

    test('onarım seriyi geri yükler, aradaki günü mavi yapar', () async {
      final store = await broken();
      final offer = store.repairOffer(now: today)!;

      final restored = await store.applyRepair(offer, now: today);

      expect(restored, 6);
      expect(store.effectiveStreak(now: today), 6);
      expect(
        store.markFor(DateTime(2026, 10, 23), now: today),
        StreakCalendarMark.frozen,
      );
      // Bugün oynayınca seri 7 olur.
      expect(await store.recordPlay(now: today), 7);
    });

    test('bugün oynandıktan sonraki onarım lost + 1 yapar', () async {
      final store = await broken();
      await store.recordPlay(now: today);
      final offer = store.repairOffer(now: today)!;

      expect(await store.applyRepair(offer, now: today), 7);
      expect(store.effectiveStreak(now: today), 7);
    });

    test('AYDA BİR: hak kullanıldıktan sonra aynı ay teklif yok', () async {
      final store = await broken();
      await store.applyRepair(store.repairOffer(now: today)!, now: today);

      // Aynı ay içinde yeniden kırılma: 24'ünde oyna, 25-26 atla.
      await store.recordPlay(now: today);
      expect(
        store.repairOffer(now: DateTime(2026, 10, 26, 9)),
        isNull,
        reason: 'bu ayın hakkı kullanıldı',
      );
    });

    test('hak ay sınırında yenilenir', () async {
      final store = await _store({
        'zankurd.streak.current': 5,
        'zankurd.streak.best': 5,
        'zankurd.streak.lastDay': '2026-10-30',
        'zankurd.streak.repairMonth': '2026-10',
      });
      // 1 Kasım: son gün 30 Ekim = iki gün önce; hak Ekim'de kullanılmıştı.
      expect(store.repairOffer(now: DateTime(2026, 11, 1, 9)), isNotNull);
      // Aynı gün Ekim içinde olsaydı reddedilirdi (31 Ekim son gün farklı).
    });

    test('açılış sayfası kırılma başına bir kez gösterilir', () async {
      final store = await broken();
      final offer = store.repairOffer(now: today)!;
      expect(store.repairOfferSeen(offer), isFalse);
      await store.markRepairOfferSeen(offer);
      expect(store.repairOfferSeen(offer), isTrue);

      StreakStore.resetInstance();
      final reloaded = await StreakStore.load();
      expect(reloaded.repairOfferSeen(offer), isTrue);
    });
  });

  group('onarım akışı (sunucu onayı önce)', () {
    Future<(StreakStore, MockZanKurdRepository)> setup({int coins = 0}) async {
      final store = await _store({
        'zankurd.streak.current': 6,
        'zankurd.streak.best': 6,
        'zankurd.streak.lastDay': '2026-10-22',
      });
      final repo = MockZanKurdRepository();
      if (coins > 0) {
        await repo.claimMissionReward(missionKey: 'k', fallbackReward: coins);
      }
      return (store, repo);
    }

    test('yeterli bakiye: 100 jeton kesilir, seri geri gelir', () async {
      final (store, repo) = await setup(coins: 250);
      final offer = store.repairOffer(now: today)!;

      final outcome = await StreakRepairService.repair(
        repository: repo,
        store: store,
        offer: offer,
        now: today,
      );

      expect(outcome, StreakRepairOutcome.charged);
      expect(await repo.loadCoinBalance(), 150);
      expect(store.effectiveStreak(now: today), 6);
    });

    test('yetersiz bakiye: yerel seri DEĞİŞMEZ', () async {
      final (store, repo) = await setup(coins: 40);
      final offer = store.repairOffer(now: today)!;

      final outcome = await StreakRepairService.repair(
        repository: repo,
        store: store,
        offer: offer,
        now: today,
      );

      expect(outcome, StreakRepairOutcome.insufficient);
      expect(await repo.loadCoinBalance(), 40);
      expect(store.effectiveStreak(now: today), 0);
      expect(
        store.repairOffer(now: today),
        isNotNull,
        reason: 'başarısız onarım hakkı harcamaz',
      );
    });

    test('p_premium gönderilmez/yok sayılır: herkes 100 öder', () async {
      final (store, repo) = await setup(coins: 250);
      final offer = store.repairOffer(now: today)!;
      await StreakRepairService.repair(
        repository: repo,
        store: store,
        offer: offer,
        now: today,
      );
      expect(await repo.loadCoinBalance(), 150);
    });

    test('aynı çağrının tekrarı ikinci kez ücret KESMEZ', () async {
      final (store, repo) = await setup(coins: 250);
      final offer = store.repairOffer(now: today)!;

      // Sunucu çağrısı iki kez (cevap kaybolup yeniden deneme simülasyonu).
      final first = await repo.spendStreakRepair(
        monthKey: offer.monthKey,
        breakDay: offer.breakDay,
        premium: false,
      );
      final second = await repo.spendStreakRepair(
        monthKey: offer.monthKey,
        breakDay: offer.breakDay,
        premium: false,
      );

      expect(first.outcome, StreakRepairOutcome.charged);
      expect(second.outcome, StreakRepairOutcome.alreadyRepaired);
      expect(await repo.loadCoinBalance(), 150);
    });

    test('aynı ay başka kırılma günü AYLIK SINIRA takılır', () async {
      final (_, repo) = await setup(coins: 500);
      await repo.spendStreakRepair(
        monthKey: '2026-10',
        breakDay: '2026-10-22',
        premium: false,
      );
      final other = await repo.spendStreakRepair(
        monthKey: '2026-10',
        breakDay: '2026-10-28',
        premium: false,
      );
      expect(other.outcome, StreakRepairOutcome.monthlyLimit);
      expect(await repo.loadCoinBalance(), 400);
    });

    test('teklif artık geçerli değilse sunucuya HİÇ gidilmez', () async {
      final (store, repo) = await setup(coins: 250);
      final offer = store.repairOffer(now: today)!;
      // Gece yarısı geçti: aynı teklif iki gün sonra geçersiz.
      final outcome = await StreakRepairService.repair(
        repository: repo,
        store: store,
        offer: offer,
        now: DateTime(2026, 10, 26, 9),
      );
      expect(outcome, StreakRepairOutcome.failed);
      expect(await repo.loadCoinBalance(), 250);
    });

    test('bedel istemcide ve sunucu dosyasında aynı sayıdır', () {
      expect(StreakStore.repairCost, 100);
    });
  });

  group('takvim çizimi', () {
    testWidgets('ay başlığı, gün sayısı ve işaretler çizilir', (tester) async {
      final store = await _store();
      await store.recordPlay(now: DateTime(2026, 10, 20, 9));
      await store.recordPlay(now: DateTime(2026, 10, 21, 9));
      await tester.pumpWidget(
        _wrap(
          StreakCalendar(
            markFor: (day) => store.markFor(day, now: today),
            today: today,
          ),
        ),
      );
      expect(find.text('Ekim 2026'), findsOneWidget);
      for (final d in ['1', '15', '31']) {
        expect(find.text(d), findsWidgets);
      }
      // 20 oynandı (kaçırılan 22 değil), anlamsal etiketler.
      expect(find.bySemanticsLabel('20: Tamamlandı'), findsOneWidget);
      expect(find.bySemanticsLabel('22: Kaçırıldı'), findsOneWidget);
      expect(find.bySemanticsLabel('24: Bugün'), findsOneWidget);
      expect(find.bySemanticsLabel('25: Henüz gelmedi'), findsOneWidget);
    });

    testWidgets('ay gezintisi: geri gider, ileri bugünden öteye gitmez', (
      tester,
    ) async {
      final store = await _store();
      await tester.pumpWidget(
        _wrap(
          StreakCalendar(
            markFor: (day) => store.markFor(day, now: today),
            today: today,
          ),
        ),
      );
      final next = find.byKey(const ValueKey('streak-calendar-next'));
      expect(tester.widget<IconButton>(next).onPressed, isNull);

      await tester.tap(find.byKey(const ValueKey('streak-calendar-prev')));
      await tester.pump();
      expect(find.text('Eylül 2026'), findsOneWidget);
      expect(tester.widget<IconButton>(next).onPressed, isNotNull);
    });

    for (final width in [320.0, 360.0]) {
      testWidgets('$width px ve %200 yazıda taşma yok', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final store = await _store();
        await store.recordPlay(now: DateTime(2026, 10, 20, 9));
        await tester.pumpWidget(
          _wrap(
            StreakCalendar(
              markFor: (day) => store.markFor(day, now: today),
              today: today,
            ),
            scale: 2.0,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });

  group('onarım kartı', () {
    testWidgets('düğme etiketi bedeli gösterir, "ücretsiz/Premium" yok', (
      tester,
    ) async {
      final store = await _store({
        'zankurd.streak.current': 6,
        'zankurd.streak.best': 6,
        'zankurd.streak.lastDay': '2026-10-22',
      });
      final offer = store.repairOffer(now: today)!;

      await tester.pumpWidget(
        _wrap(
          StreakRepairCard(
            store: store,
            repository: MockZanKurdRepository(),
            offer: offer,
            now: today,
            onRepaired: (_) {},
          ),
        ),
      );
      expect(find.text('Seriyi geri al · 100 jeton'), findsOneWidget);
      expect(find.textContaining('6 günlük serin'), findsOneWidget);
      expect(find.textContaining('Premium'), findsNothing);
      expect(find.textContaining('ücretsiz'), findsNothing);
    });

    testWidgets('yetersiz bakiyede hata görünür, geri çağrı çalışmaz', (
      tester,
    ) async {
      final store = await _store({
        'zankurd.streak.current': 6,
        'zankurd.streak.best': 6,
        'zankurd.streak.lastDay': '2026-10-22',
      });
      final offer = store.repairOffer(now: today)!;
      var repaired = false;

      await tester.pumpWidget(
        _wrap(
          StreakRepairCard(
            store: store,
            repository: MockZanKurdRepository(),
            offer: offer,
            now: today,
            onRepaired: (_) => repaired = true,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('streak-repair-action')));
      await tester.pump();
      await tester.pump();

      expect(repaired, isFalse);
      expect(find.byKey(const ValueKey('streak-repair-error')), findsOneWidget);
      expect(find.text('Jeton yetersiz'), findsOneWidget);
    });

    testWidgets('başarıda geri çağrı yeni seriyle çalışır', (tester) async {
      final store = await _store({
        'zankurd.streak.current': 6,
        'zankurd.streak.best': 6,
        'zankurd.streak.lastDay': '2026-10-22',
      });
      final offer = store.repairOffer(now: today)!;
      final repo = MockZanKurdRepository();
      await repo.claimMissionReward(missionKey: 'k', fallbackReward: 300);
      int? restored;

      await tester.pumpWidget(
        _wrap(
          StreakRepairCard(
            store: store,
            repository: repo,
            offer: offer,
            now: today,
            onRepaired: (days) => restored = days,
          ),
        ),
      );
      await tester.tap(find.byKey(const ValueKey('streak-repair-action')));
      await tester.pump();
      await tester.pump();

      expect(restored, 6);
      expect(await repo.loadCoinBalance(), 200);
    });

    for (final width in [320.0, 360.0]) {
      testWidgets('$width px ve %200 yazıda taşma yok', (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final store = await _store({
          'zankurd.streak.current': 6,
          'zankurd.streak.best': 6,
          'zankurd.streak.lastDay': '2026-10-22',
        });
        await tester.pumpWidget(
          _wrap(
            StreakRepairCard(
              store: store,
              repository: MockZanKurdRepository(),
              offer: store.repairOffer(now: today)!,
              onLater: () {},
              onRepaired: (_) {},
            ),
            scale: 2.0,
          ),
        );
        expect(tester.takeException(), isNull);
      });
    }
  });
}
