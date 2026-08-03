import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/quiz_result_progress_receipt_store.dart';

/// Sonuç makbuzu, süreç ÖLDÜĞÜNDE ne yapılabileceğini söyleyebilmeli.
///
/// Eskiden tek bir belirsiz `processing` vardı ve altı ayrı adımı birden
/// temsil ediyordu: dondurma teklifi diyaloğu, kullanıcı kararı, coin
/// harcama, dondurmanın uygulanması, yerel ilerleme yazımı ve sunucu onayı.
/// Süreç ölünce hangisinin çalıştığı bilinemiyordu; bu yüzden hiçbiri bir
/// daha çalıştırılmıyor ve makbuz KALICI olarak kilitleniyordu. Sonuç: o
/// maçın XP'si kayıp, `acknowledgeRoomResult` hiç çağrılamıyor ve kurtarma
/// ekranı her soğuk açılışta geri geliyordu.
///
/// Yeni sözleşme iki ayrı garantiyi birbirinden ayırır:
///
/// * **Yan etkili adımlar asla tekrarlanmaz.** Yerel depolar (XP, rozet,
///   ustalık) ve `spend_coins` idempotent değildir. Kesilen bir yazım
///   yeniden çalıştırılmaz — çift XP ve çift coin bu kuralla önlenir.
/// * **Akış asla kilitlenmez.** Belirsizlik ileri çözülür, böylece onay
///   yapılabilir. Onay sunucuda idempotenttir
///   (`room_result_receipts` birincil anahtarı `(room_id, player_id)`),
///   bu yüzden tekrar denenmesi güvenlidir.
///
/// `SharedPreferences.setMockInitialValues` ile kalıcı değeri doğrudan
/// yazmak, süreç ölümünü taklit etmenin dürüst yoludur: yeniden açılan
/// uygulama diskte tam olarak bunu görür.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const userId = 'user-crash';
  const roomId = 'room-crash';
  final key = QuizResultProgressReceiptStore.keyFor(
    userId: userId,
    roomId: roomId,
  );

  setUp(() {
    QuizResultProgressReceiptStore.debugResetInFlight();
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => SharedPreferences.setMockInitialValues({}));

  Future<QuizResultProgressReceiptStore> storeWith(String? persisted) async {
    SharedPreferences.setMockInitialValues(
      persisted == null ? {} : {key: persisted},
    );
    return QuizResultProgressReceiptStore(
      await SharedPreferences.getInstance(),
    );
  }

  String encoded(QuizResultReceiptStage stage, {bool freeze = false}) =>
      '{"v":2,"stage":"${stage.name}"${freeze ? ',"freeze":true' : ''}}';

  // ── 1. Diyalog açıkken süreç ölüyor ────────────────────────────────
  test(
    'karar beklerken ölen süreç soruyu yeniden sorulabilir bırakır',
    () async {
      final store = await storeWith(
        encoded(QuizResultReceiptStage.pendingUserDecision),
      );
      final receipt = await store.read(userId: userId, roomId: roomId);

      // Bu aşamada HİÇBİR yan etki oluşmamıştır: coin harcanmamış, seri
      // değişmemiştir. Bu yüzden yeniden sormak güvenlidir — ve kullanıcının
      // kararı kaybolmaz, çünkü henüz karar verilmemiştir.
      expect(receipt!.stage, QuizResultReceiptStage.pendingUserDecision);
      expect(receipt.freezeRequested, isFalse);
    },
  );

  // ── 2. Karar verildikten hemen sonra süreç ölüyor ──────────────────
  test('kaydedilmiş karar süreç ölümünden sağ çıkar', () async {
    final store = await storeWith(
      encoded(QuizResultReceiptStage.decisionRecorded, freeze: true),
    );
    final receipt = await store.read(userId: userId, roomId: roomId);

    // Karar, UYGULANMADAN önce yazılır; aksi hâlde coin harcamasıyla
    // birlikte aynı kesintide kaybolurdu.
    expect(receipt!.stage, QuizResultReceiptStage.decisionRecorded);
    expect(receipt.freezeRequested, isTrue);
  });

  // ── 3. Coin isteği gönderildi, cevap alınamadan süreç ölüyor ───────
  test('belirsiz coin harcaması bir daha denenmez', () async {
    final store = await storeWith(
      encoded(QuizResultReceiptStage.freezeApplying, freeze: true),
    );
    final receipt = await store.read(userId: userId, roomId: roomId);

    // `spend_coins` sunucuda idempotent DEĞİL: `streak_freeze` için hiçbir
    // dedup anahtarı yok, her çağrı yeni bir `-50` satırı yazar. Bu aşama
    // görülünce harcama tekrarlanmaz; ekran bunu `freezeSkipped`e çözer.
    expect(receipt!.stage, QuizResultReceiptStage.freezeApplying);
    expect(receipt.freezeRequested, isTrue);
  });

  // ── 4/5. İlerleme yazımı yarıda kesiliyor ──────────────────────────
  test('kesilen ilerleme yazımı tekrarlanmaz ama akışı kilitlemez', () async {
    final store = await storeWith(
      encoded(QuizResultReceiptStage.progressApplying),
    );
    var actionCount = 0;

    final outcome = await store.runOnce(
      userId: userId,
      roomId: roomId,
      action: () async => actionCount++,
    );

    // Çift XP yok: depolar idempotent olmadığı için adım atlanır.
    expect(outcome, QuizResultProgressReceiptOutcome.blockedProcessing);
    expect(actionCount, 0);
    // Ama kilitlenme de yok: akış onay aşamasına taşınır.
    final receipt = await store.read(userId: userId, roomId: roomId);
    expect(receipt!.stage, QuizResultReceiptStage.acknowledgementPending);
  });

  // ── 6. Onay başarılı, completed yazılmadan süreç ölüyor ────────────
  test('onay aşaması yeniden denenebilir ve ilerlemeyi tekrarlamaz', () async {
    final store = await storeWith(
      encoded(QuizResultReceiptStage.acknowledgementPending),
    );
    var actionCount = 0;

    final outcome = await store.runOnce(
      userId: userId,
      roomId: roomId,
      action: () async => actionCount++,
    );

    // Yerel ilerleme zaten yazılmıştı; tekrarlanmaz.
    expect(outcome, QuizResultProgressReceiptOutcome.skippedCompleted);
    expect(actionCount, 0);
    // Onay sunucuda idempotent olduğu için tekrar denenmesi güvenlidir.
    final receipt = await store.read(userId: userId, roomId: roomId);
    expect(receipt!.stage, QuizResultReceiptStage.acknowledgementPending);
  });

  // ── 11. Uygulama art arda birkaç kez açılıyor ──────────────────────
  test('art arda açılışlar ilerlemeyi bir kez uygular', () async {
    var actionCount = 0;
    final store = await storeWith(null);

    for (var launch = 0; launch < 4; launch++) {
      QuizResultProgressReceiptStore.debugResetInFlight();
      await QuizResultProgressReceiptStore(
        await SharedPreferences.getInstance(),
      ).runOnce(
        userId: userId,
        roomId: roomId,
        action: () async => actionCount++,
      );
    }

    expect(actionCount, 1, reason: 'XP en fazla bir kez uygulanmalı');
    final receipt = await store.read(userId: userId, roomId: roomId);
    expect(receipt!.stage, QuizResultReceiptStage.acknowledgementPending);
  });

  // ── 12. Aynı kurtarma iki eşzamanlı çağrıyla tetikleniyor ──────────
  test('eşzamanlı iki kurtarma tek ilerleme uygular', () async {
    final store = await storeWith(null);
    var actionCount = 0;

    final results = await Future.wait([
      store.runOnce(
        userId: userId,
        roomId: roomId,
        action: () async => actionCount++,
      ),
      store.runOnce(
        userId: userId,
        roomId: roomId,
        action: () async => actionCount++,
      ),
    ]);

    expect(actionCount, 1);
    expect(results.first, QuizResultProgressReceiptOutcome.executed);
  });

  // ── Kalıcı `processing` artık oluşmuyor ────────────────────────────
  test('hiçbir yol kalıcı processing bırakmaz', () async {
    for (final stage in QuizResultReceiptStage.values) {
      QuizResultProgressReceiptStore.debugResetInFlight();
      final store = await storeWith(encoded(stage));
      await store.runOnce(userId: userId, roomId: roomId, action: () async {});
      final after = await store.read(userId: userId, roomId: roomId);
      // Asıl özellik: hiçbir "sürüyor" aşaması bir koşumdan sağ çıkmaz.
      // Eski `processing` tam olarak bunu yapıyordu ve kilit oradan
      // geliyordu.
      expect(
        after!.stage,
        isNot(
          anyOf(
            QuizResultReceiptStage.progressApplying,
            QuizResultReceiptStage.freezeApplying,
          ),
        ),
        reason: '$stage kilitli kalmamalı',
      );
      expect(
        after.stage,
        anyOf(
          QuizResultReceiptStage.progressApplied,
          QuizResultReceiptStage.acknowledgementPending,
          QuizResultReceiptStage.completed,
        ),
        reason: '$stage ileri çözülmeli',
      );
    }
  });

  // ── Eski sürüm kayıtlarının göçü ───────────────────────────────────
  group('v1 kayıtları', () {
    test('completed olduğu gibi korunur', () async {
      final store = await storeWith('completed');
      var actionCount = 0;
      final outcome = await store.runOnce(
        userId: userId,
        roomId: roomId,
        action: () async => actionCount++,
      );
      expect(outcome, QuizResultProgressReceiptOutcome.skippedCompleted);
      expect(actionCount, 0);
    });

    test(
      'kilitli processing kaydı onaya taşınır, ilerleme tekrarlanmaz',
      () async {
        // Sahadaki zehirlenmiş makbuzlar tam olarak bunlar. Hangi adımın
        // çalıştığı bilinemez, bu yüzden yan etkili hiçbir adım tekrarlanmaz;
        // fakat onay yapılabilsin diye ileri taşınır — kurtarma ekranının
        // sonsuz tekrarı ancak böyle biter.
        final store = await storeWith('processing');
        var actionCount = 0;
        final outcome = await store.runOnce(
          userId: userId,
          roomId: roomId,
          action: () async => actionCount++,
        );
        expect(outcome, QuizResultProgressReceiptOutcome.skippedCompleted);
        expect(actionCount, 0, reason: 'çift XP riski');
        final receipt = await store.read(userId: userId, roomId: roomId);
        expect(receipt!.stage, QuizResultReceiptStage.acknowledgementPending);
      },
    );

    test('bozuk kayıt hâlâ reddedilir', () async {
      final store = await storeWith('unknown-state');
      await expectLater(
        store.runOnce(userId: userId, roomId: roomId, action: () async {}),
        throwsFormatException,
      );
    });

    test('bozuk JSON reddedilir', () async {
      final store = await storeWith('{"v":2,"stage":"nonsense"}');
      await expectLater(
        store.read(userId: userId, roomId: roomId),
        throwsFormatException,
      );
    });
  });

  // ── 15. Başka kullanıcının makbuzu devralınamaz ────────────────────
  test('makbuz kullanıcıya bağlıdır', () async {
    final store = await storeWith(encoded(QuizResultReceiptStage.completed));

    expect(
      (await store.read(userId: userId, roomId: roomId))!.stage,
      QuizResultReceiptStage.completed,
    );
    // Aynı oda, başka kullanıcı: tamamlanmış sayılmaz.
    expect(await store.read(userId: 'other-user', roomId: roomId), isNull);
  });
}
