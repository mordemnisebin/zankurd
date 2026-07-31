import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/seen_question_store.dart';

/// Açılış yolu, ilk kareyi bekletmeyen işleri beklemez.
///
/// ## Kusur
///
/// `main()` `runApp`tan önce seri bir zincir yürütüyordu ve zincirin içinde
/// gerçek bir ağ isteği vardı: `PremiumService.load()` →
/// `Purchases.configure()` → `await Purchases.getCustomerInfo()`. Bu çağrı
/// tamamlanmadan Flutter tek bir kare bile çizmiyordu; kullanıcı o süre
/// boyunca sistemin açılış ekranına bakıyordu. Yavaş bir ağda bekleme
/// RevenueCat SDK'sının kendi zaman aşımına kadar uzayabiliyordu.
///
/// Aynı zincirde `NotificationService.load()` de vardı ve o, bildirimler
/// kapalı olsa bile bütün saat dilimi veritabanını okuyup platform
/// kanalına iniyordu. `AnalyticsService.initialize()` de öyle.
///
/// Üçü de ilk karenin ne çizileceğini etkilemiyor (2026-07-31 denetimi).
void main() {
  late String mainSource;

  setUpAll(() {
    mainSource = File('lib/main.dart').readAsStringSync();
  });

  test('ilk kare ağ çağrısını beklemiyor', () {
    // `warmUp` ağ kısmını taşır; `load` yalnız yerel SDK kurulumu yapar.
    final premium = File(
      'lib/src/services/premium_service.dart',
    ).readAsStringSync();
    expect(
      premium,
      contains('Future<void> warmUp()'),
      reason: 'getCustomerInfo bloklayan yoldan çıkarılmalı.',
    );

    final configure = premium.substring(
      premium.indexOf('Future<void> _configure()'),
      premium.indexOf('Future<void> warmUp()'),
    );
    expect(
      configure,
      isNot(contains('getCustomerInfo')),
      reason: 'Kurulum ağ beklerse ilk kare yine bloklanır.',
    );
  });

  test('ilk kareyi etkilemeyen işler runApp sonrasına alınmış', () {
    final beforeRunApp = mainSource.substring(0, mainSource.indexOf('runApp('));
    for (final deferred in [
      'premiumService.warmUp()',
      'AnalyticsService.instance.initialize()',
      'NotificationService.load()',
    ]) {
      expect(
        mainSource,
        contains(deferred),
        reason: '$deferred hiç çağrılmıyor.',
      );
    }
    // Bunların hiçbiri `await` ile bloklamamalı.
    expect(beforeRunApp, isNot(contains('await NotificationService.load()')));
    expect(
      beforeRunApp,
      isNot(contains('await AnalyticsService.instance.initialize()')),
    );
    expect(mainSource, contains('startInBackground'));
  });

  test('splash süreye değil hazır olmaya bağlı', () {
    final splash = File(
      'lib/src/screens/splash_screen.dart',
    ).readAsStringSync();
    expect(splash, contains('Future<void>? readiness'));
    expect(
      splash,
      isNot(contains('milliseconds: 1800')),
      reason:
          '1800 ms bir yükleme penceresi değil saf gecikmeydi: runApp zaten '
          'bütün başlatma zincirinden sonra çağrılıyor.',
    );
    // Zamanlayıcı iptal edilebilir olmalı — ekran erken sökülürse onunla
    // birlikte ölmeli.
    expect(splash, contains('_minimumTimer?.cancel()'));
    expect(mainSource, contains('readiness: _warmUpShell(repository)'));
  });

  test('soru bankası JSON çözme arka isolate te', () {
    final loader = File(
      'lib/src/data/question_bank_loader.dart',
    ).readAsStringSync();
    expect(
      loader,
      contains('compute(_decodeJsonList'),
      reason:
          'Dört asset ~1,4 MB; en büyüğü tek başına 1,1 MB. UI isolate inde '
          'çözmek ilk kareyi o süre boyunca bloklar.',
    );
  });

  test('liderlik zamanlayıcısı arka planda duruyor', () {
    final leaderboard = File(
      'lib/src/screens/leaderboard_screen.dart',
    ).readAsStringSync();
    expect(leaderboard, contains('WidgetsBindingObserver'));
    expect(leaderboard, contains('didChangeAppLifecycleState'));
    expect(
      leaderboard,
      contains('WidgetsBinding.instance.removeObserver(this)'),
      reason: 'Gözlemci sökülmezse sızıntı olur.',
    );
  });

  test('quiz sayacı arka planda duruyor', () {
    final quiz = File('lib/src/screens/quiz_screen.dart').readAsStringSync();
    expect(quiz, contains('WidgetsBindingObserver'));
    expect(quiz, contains('didChangeAppLifecycleState'));
    // Çevrimiçi turda süreyi sunucu ve rakip belirler; istemcinin tek
    // taraflı durması iki oyuncuyu birbirinden ayırır.
    expect(quiz, contains('_isMultiplayer'));
  });

  test('ağ görselleri sınırlı çözünürlükte belleğe açılıyor', () {
    for (final path in [
      'lib/src/screens/quiz/quiz_widgets.dart',
      'lib/src/screens/review_screen.dart',
      'lib/src/screens/learning_screen.dart',
    ]) {
      expect(
        File(path).readAsStringSync(),
        contains('memCacheWidth'),
        reason:
            '$path tam çözünürlükte açıyor: 2000 px lik bir JPEG ekranda '
            '350 px görünse bile ~16 MB RGBA tutar.',
      );
    }
  });

  group('görülen soru kümesi', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
      SeenQuestionStore.resetInstance();
    });

    test('tavanı aşmaz ve en eskiyi düşürür', () async {
      final store = await SeenQuestionStore.load();
      // Tavanın üstüne çık: 3.500 kimlik.
      await store.markSeen(List.generate(3500, (i) => 'q$i'));

      expect(store.seenCount, lessThanOrEqualTo(3000));
      // En eskiler düşer, en yeniler kalır.
      expect(store.isSeen('q3499'), isTrue);
      expect(
        store.isSeen('q0'),
        isFalse,
        reason: 'FIFO: en eski görülen, tekrar gösterilmesi en zararsız olan.',
      );
    });

    test('tavanın altında hiçbir şey düşmez', () async {
      final store = await SeenQuestionStore.load();
      await store.markSeen(List.generate(100, (i) => 'k$i'));
      expect(store.seenCount, 100);
      expect(store.isSeen('k0'), isTrue);
    });
  });
}
