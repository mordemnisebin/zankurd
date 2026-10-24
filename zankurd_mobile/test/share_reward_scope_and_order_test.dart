// Bekçi: günlük paylaşım ödülü kullanıcıya özel ve ödül SONRA işaretlenir (B5).
//
// ## Kusur
// 1. `zankurd.shareReward.lastDate` genel bir anahtardı: aynı cihazda A hesabı
//    bugün paylaşım ödülünü aldıysa B hesabı da "bugün zaten aldın" sanılırdı.
// 2. Sonuç ekranı önce `claimDailyShareReward()` ile günü YAKIYOR, sonra
//    sunucudan ödülü istiyordu. Sunucu isteği başarısız olursa (ağ yok,
//    oturum düşmüş) oyuncu hem ödülü alamıyor hem de gün boyu yeniden
//    deneyemiyordu.
//
// ## Niçin sessiz kalırdı
// Mevcut test yalnız tek kullanıcıda "aynı gün ikinci talep reddedilir"i
// ölçüyordu; hesap değişimi ve sunucu hatası senaryosu yoktu. Hata yalnız
// "ödül gelmedi" diye görünürdü.
//
// ## Kural
// Anahtar `LocalProgressScope.physical` ile kullanıcıya göre ayrılır; gün
// ancak sunucu ödülü gerçekten verdikten sonra işaretlenir.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/local_progress_scope.dart';
import 'package:zankurd_mobile/src/utils/result_sharer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final now = DateTime(2026, 9, 2, 10);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    LocalProgressScope.debugReset();
  });
  tearDown(LocalProgressScope.debugReset);

  Future<bool> settle(int amount, {bool throws = false}) =>
      ResultSharer.settleDailyShareReward(
        awardCoins: () async {
          if (throws) throw StateError('ağ yok');
          return amount;
        },
        now: now,
      );

  test('A hesabının aldığı ödül B hesabını kilitlemez', () async {
    LocalProgressScope.bind('user-a');
    expect(await settle(10), isTrue);
    expect(await ResultSharer.canClaimDailyShareReward(now), isFalse);

    LocalProgressScope.bind('user-b');
    expect(
      await ResultSharer.canClaimDailyShareReward(now),
      isTrue,
      reason: 'B hesabı bugün hiç paylaşım ödülü almadı',
    );

    LocalProgressScope.bind('user-a');
    expect(await ResultSharer.canClaimDailyShareReward(now), isFalse);
  });

  test('sunucu ödülü başarısızsa gün yanmaz, sonra yeniden denenir', () async {
    LocalProgressScope.bind('user-a');
    expect(await settle(0, throws: true), isFalse);
    expect(await ResultSharer.canClaimDailyShareReward(now), isTrue);
    expect(await settle(0), isFalse, reason: 'sunucu 0 verdi: gün yanmaz');
    expect(await ResultSharer.canClaimDailyShareReward(now), isTrue);
    expect(await settle(10), isTrue);
    expect(await ResultSharer.canClaimDailyShareReward(now), isFalse);
  });

  test('eşzamanlı iki çağrı çift ödül almaz (tek uçuş)', () async {
    LocalProgressScope.bind('user-a');
    var awards = 0;
    final gate = Completer<void>();
    Future<bool> call() => ResultSharer.settleDailyShareReward(
      awardCoins: () async {
        awards++;
        await gate.future;
        return 10;
      },
      now: now,
    );
    final first = call();
    final second = call();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    gate.complete();
    final results = await Future.wait([first, second]);
    expect(awards, 1, reason: 'sunucuya tek ödül isteği gitmeli');
    expect(results.where((r) => r).length, 1);
  });

  test(
    'istek sürerken hesap değişirse işaret yanlış kullanıcıya yazılmaz',
    () async {
      LocalProgressScope.bind('user-a');
      final gate = Completer<void>();
      final pending = ResultSharer.settleDailyShareReward(
        awardCoins: () async {
          await gate.future;
          return 10;
        },
        now: now,
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      LocalProgressScope.bind('user-b');
      gate.complete();
      expect(await pending, isTrue);

      expect(
        await ResultSharer.canClaimDailyShareReward(now),
        isTrue,
        reason: 'B hiç ödül almadı; işaret A\'ya yazılmalıydı',
      );
      LocalProgressScope.bind('user-a');
      expect(await ResultSharer.canClaimDailyShareReward(now), isFalse);
    },
  );
}
