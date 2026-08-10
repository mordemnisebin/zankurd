import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/utils/boot_step.dart';

/// Açılış adımı hiçbir koşulda ilk kareyi rehin alamaz.
///
/// ## Kusur
///
/// 2026-08-10: temiz bir simülatöre kurulan uygulama açılış ekranında kaldı
/// ve orada kaldı — üç dakika, yeniden başlatınca yine. Ekrandaki Flutter'ın
/// splash'ı bile değildi, iOS'un yerel `LaunchScreen.storyboard`'uydu; yani
/// `main()` daha `runApp`'a varmamıştı.
///
/// `main()` beş şeyi zaman sınırı olmadan bekliyordu: Firebase, RevenueCat,
/// Supabase, SyncManager ve tercih yüklemeleri. Firebase'inki bir `try/catch`
/// içindeydi ama **catch fırlatmayı yakalar, asılı kalmayı yakalamaz** —
/// tamamlanmayan bir `Future` sonsuza kadar bekletir.
///
/// Bu bekçi [bootStep]'in sözleşmesini sabitler: üç durumda da tamamlanır
/// (başarı, hata, zaman aşımı) ve hiçbirinde çağıranı asılı bırakmaz.
void main() {
  test('başarılı adım değerini döndürür', () async {
    final value = await bootStep(
      Future.value(42),
      reason: 'test',
      fallback: () => -1,
    );
    expect(value, 42);
  });

  test('hata veren adım fallback döndürür, fırlatmaz', () async {
    final value = await bootStep(
      Future<int>.error(StateError('patladı')),
      reason: 'test',
      fallback: () => -1,
    );
    expect(value, -1);
  });

  test('asılı kalan adım zaman aşımıyla fallback döndürür', () async {
    final sw = Stopwatch()..start();
    final value = await bootStep(
      // Hiç tamamlanmayan Future — açılışı kilitleyen durumun ta kendisi.
      Completer<int>().future,
      reason: 'test',
      fallback: () => -1,
      timeout: const Duration(milliseconds: 120),
    );
    sw.stop();

    expect(value, -1);
    expect(
      sw.elapsedMilliseconds,
      lessThan(2000),
      reason:
          'Zaman aşımı işlemedi; asılı bir adım çağıranı süresiz bekletiyor',
    );
  });

  test('zaman aşımı işi İPTAL etmez, yalnız beklemeyi bırakır', () async {
    // `timeout` bir Future'ı iptal edemez. Amaç işi durdurmak değil, ilk
    // karenin ona bağlı kalmaması. Geç gelen sonuç sessizce tamamlanmalı,
    // "unhandled error" üretmemeli.
    var completed = false;
    final slow = Future<int>.delayed(const Duration(milliseconds: 150), () {
      completed = true;
      return 7;
    });

    final value = await bootStep(
      slow,
      reason: 'test',
      fallback: () => -1,
      timeout: const Duration(milliseconds: 30),
    );
    expect(value, -1);
    expect(completed, isFalse);

    await slow;
    expect(completed, isTrue, reason: 'Arka plandaki iş sürmeliydi');
  });

  test('bootStepVoid asılı adımda da tamamlanır', () async {
    var reached = false;
    await bootStepVoid(
      Completer<void>().future,
      reason: 'test',
      timeout: const Duration(milliseconds: 80),
    );
    reached = true;
    expect(reached, isTrue);
  });
}
