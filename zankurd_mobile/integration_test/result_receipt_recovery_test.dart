// Sonuç makbuzunun GERÇEK cihaz depolamasındaki davranışı
// (integration_test).
//
// Çalıştırma:
//   flutter test integration_test/result_receipt_recovery_test.dart -d <device>
//
// Widget testleri makbuzu `SharedPreferences.setMockInitialValues` ile
// sürer; bu dosya aynı durum makinesini cihazın GERÇEK kalıcı deposu
// üzerinde koşturur. Aradaki fark önemsiz değil: süreç ölümünden sonra
// hangi adımın yeniden çalıştırılabileceği sorusunun cevabı, değerin
// diske gerçekten yazılmış olmasına bağlı.
//
// "Süreç ölümü" burada yeni bir store örneğiyle ve bellek içi izin
// temizlenmesiyle taklit edilir — yeniden açılan uygulamanın gördüğü
// durum tam olarak budur.

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zankurd_mobile/src/data/quiz_result_progress_receipt_store.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const userId = 'itest-user';

  Future<SharedPreferences> freshPrefs(String roomId) async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(
      QuizResultProgressReceiptStore.keyFor(userId: userId, roomId: roomId),
    );
    QuizResultProgressReceiptStore.debugResetInFlight();
    return preferences;
  }

  testWidgets('Senaryo: ilerleme gerçek diskte tam bir kez uygulanır', (
    tester,
  ) async {
    const roomId = 'itest-room-once';
    var actionCount = 0;

    for (var launch = 0; launch < 3; launch++) {
      final preferences = launch == 0
          ? await freshPrefs(roomId)
          : await SharedPreferences.getInstance();
      // Her tur yeni bir store: süreç yeniden başlamış gibi.
      QuizResultProgressReceiptStore.debugResetInFlight();
      await preferences.reload();
      await QuizResultProgressReceiptStore(preferences).runOnce(
        userId: userId,
        roomId: roomId,
        action: () async => actionCount++,
      );
    }

    expect(actionCount, 1, reason: 'XP en fazla bir kez');

    final preferences = await SharedPreferences.getInstance();
    await preferences.reload();
    final receipt = await QuizResultProgressReceiptStore(
      preferences,
    ).read(userId: userId, roomId: roomId);
    expect(receipt!.stage, QuizResultReceiptStage.acknowledgementPending);
  });

  testWidgets('Senaryo: kesilen yazım diskte kilit bırakmaz', (tester) async {
    const roomId = 'itest-room-interrupted';
    final preferences = await freshPrefs(roomId);

    // İlk tur hata veriyor: disk `progressApplying` ile kalıyor.
    await expectLater(
      QuizResultProgressReceiptStore(preferences).runOnce(
        userId: userId,
        roomId: roomId,
        action: () async => throw StateError('itest: interrupted'),
      ),
      throwsStateError,
    );

    QuizResultProgressReceiptStore.debugResetInFlight();
    await preferences.reload();
    expect(
      (await QuizResultProgressReceiptStore(
        preferences,
      ).read(userId: userId, roomId: roomId))!.stage,
      QuizResultReceiptStage.progressApplying,
    );

    // Yeniden açılış: adım tekrarlanmaz ama akış ileri çözülür.
    var replayed = 0;
    final outcome = await QuizResultProgressReceiptStore(
      preferences,
    ).runOnce(userId: userId, roomId: roomId, action: () async => replayed++);

    expect(outcome, QuizResultProgressReceiptOutcome.blockedProcessing);
    expect(replayed, 0, reason: 'çift XP olmamalı');

    await preferences.reload();
    expect(
      (await QuizResultProgressReceiptStore(
        preferences,
      ).read(userId: userId, roomId: roomId))!.stage,
      QuizResultReceiptStage.acknowledgementPending,
      reason: 'kurtarma döngüsü bitmeli',
    );
  });

  testWidgets('Senaryo: sahadaki kilitli v1 makbuzu diskte çözülür', (
    tester,
  ) async {
    const roomId = 'itest-room-legacy';
    final preferences = await freshPrefs(roomId);
    // Bu sürümden önce zehirlenmiş makbuzların diskteki tam hâli.
    await preferences.setString(
      QuizResultProgressReceiptStore.keyFor(userId: userId, roomId: roomId),
      'processing',
    );
    QuizResultProgressReceiptStore.debugResetInFlight();

    var replayed = 0;
    final outcome = await QuizResultProgressReceiptStore(
      preferences,
    ).runOnce(userId: userId, roomId: roomId, action: () async => replayed++);

    expect(outcome, QuizResultProgressReceiptOutcome.skippedCompleted);
    expect(replayed, 0, reason: 'yan etkili adım tekrarlanmaz');
  });

  testWidgets('Senaryo: makbuz kullanıcıya bağlıdır', (tester) async {
    const roomId = 'itest-room-owner';
    final preferences = await freshPrefs(roomId);

    await QuizResultProgressReceiptStore(
      preferences,
    ).runOnce(userId: userId, roomId: roomId, action: () async {});

    QuizResultProgressReceiptStore.debugResetInFlight();
    await preferences.reload();
    // Hesap değişimi: aynı oda, başka kullanıcı devralamaz.
    expect(
      await QuizResultProgressReceiptStore(
        preferences,
      ).read(userId: 'itest-other-user', roomId: roomId),
      isNull,
    );
  });
}
