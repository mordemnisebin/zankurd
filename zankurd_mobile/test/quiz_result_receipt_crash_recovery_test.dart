import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/quiz_result_progress_receipt_store.dart';

/// Sonuç makbuzu, süreç ÖLDÜĞÜNDE ne olduğunu anlatabilmeli.
///
/// Eski tasarımda tek bir belirsiz `processing` durumu vardı ve o durum
/// "aşağıdaki adımların hangisi çalıştı bilmiyorum" demenin tek yoluydu:
///
///   1. dondurma teklifi diyaloğu açıldı (kullanıcı girdisi bekleniyor)
///   2. kullanıcı "dondur" dedi
///   3. `spend_coins` isteği gönderildi
///   4. coin harcandı, dondurma uygulandı
///   5. XP / rozet / ustalık / görev yazıldı
///   6. oda sonucu acknowledge edildi
///
/// Altı adımın hepsi aynı `processing` kelimesinin arkasındaydı. En kötüsü
/// 1. adımdı: SINIRSIZ bir kullanıcı girdisi beklemesi kritik bölümün
/// içindeydi. Oyuncu diyaloğu cevaplamadan uygulamayı kapatırsa anahtar
/// sonsuza dek `processing` kalıyordu — `lib/` içinde bu ön eki temizleyen
/// tek bir satır bile yok.
///
/// Sonucu bu dosya kanıtlar: makbuz kalıcı olarak kilitlenir, ilerleme bir
/// daha asla yazılamaz ve `acknowledgeRoomResult` hiç çağrılamaz. Sunucu
/// odayı "görülmedi" saymaya devam ettiği için kurtarma ekranı her soğuk
/// açılışta yeniden gelir.
///
/// `SharedPreferences.setMockInitialValues` ile kalıcı değeri doğrudan
/// yazmak, süreç ölümünü test içinde taklit etmenin dürüst yoludur: yeniden
/// açılan uygulama diskte tam olarak bunu görür.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const key = 'zankurd.quiz_result_progress_receipt.user-crash:room-crash';

  setUp(() {
    SharedPreferences.resetStatic();
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() => SharedPreferences.setMockInitialValues({}));

  test('diyalog açıkken ölen süreç makbuzu kalıcı olarak kilitler', () async {
    // Süreç, `_persist(processing)` ile `_persist(completed)` arasında öldü.
    SharedPreferences.setMockInitialValues({key: 'processing'});
    final preferences = await SharedPreferences.getInstance();

    var actionCount = 0;
    // Uygulama üst üste üç kez açılıyor.
    for (var launch = 0; launch < 3; launch++) {
      final store = QuizResultProgressReceiptStore(preferences);
      final outcome = await store.runOnce(
        userId: 'user-crash',
        roomId: 'room-crash',
        action: () async => actionCount++,
      );
      expect(
        outcome,
        QuizResultProgressReceiptOutcome.blockedProcessing,
        reason: '$launch. açılışta hâlâ kilitli',
      );
    }

    // İlerleme bir daha asla uygulanmıyor: o maçın XP'si, serisi ve rozeti
    // kalıcı olarak kayıp.
    expect(actionCount, 0);

    // Ve durum kendi kendine iyileşmiyor — disk hâlâ aynı.
    expect(preferences.getString(key), 'processing');
  });

  test('kilitli makbuz acknowledge yolunu da kapatır', () async {
    // `quiz_result_screen._deliverResult` bu sonucu görünce `return` eder ve
    // `acknowledgeRoomResult`a hiç ulaşmaz. Sunucudaki oda "beklemede"
    // kaldığı için `app_shell` kurtarma ekranını her açılışta yeniden iter.
    SharedPreferences.setMockInitialValues({key: 'processing'});
    final preferences = await SharedPreferences.getInstance();
    final store = QuizResultProgressReceiptStore(preferences);

    final outcome = await store.runOnce(
      userId: 'user-crash',
      roomId: 'room-crash',
      action: () async {},
    );

    // Bu satır bugünkü sözleşmedir ve tam olarak düzeltilmesi gereken şeydir:
    // "tamamlığı belirsiz" ile "sonsuza dek kilitli" aynı şeye indirgenmiş.
    expect(outcome, QuizResultProgressReceiptOutcome.blockedProcessing);
  });
}
