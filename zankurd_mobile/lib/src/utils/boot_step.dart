import 'dart:async';

import 'error_reporter.dart';

/// `runApp`'tan önce beklenen bir başlatma adımını SINIRLI süreyle bekler.
///
/// ## Kusur
///
/// 2026-08-10'da temiz bir simülatöre kurulan uygulama açılış ekranında
/// takıldı ve orada kaldı — üç dakika, sonra yeniden başlatınca yine.
/// Ekranda görünen Flutter'ın kendi splash'ı bile değildi; iOS'un yerel
/// `LaunchScreen.storyboard`'uydu. Yani `main()` daha `runApp`'a varamamıştı
/// ve kullanıcıya hiçbir şey söylenmiyordu: ne yükleniyor göstergesi, ne
/// hata, ne çıkış yolu.
///
/// Sebep, `main()` içindeki beş `await`ti — Firebase, RevenueCat, Supabase,
/// SyncManager ve tercih yüklemeleri. Hiçbirinde zaman sınırı yoktu.
/// Firebase'inki bir `try/catch` içindeydi ama **catch fırlatmayı yakalar,
/// ASILI KALMAYI yakalamaz**: ağ yavaşsa ya da bir SDK yanıt vermezse
/// `Future` hiç tamamlanmaz ve `runApp` hiç çağrılmaz.
///
/// Bağımlılık yönü tersti. ZanKurd çevrimdışı-öncelikli bir uygulama:
/// 2173 soru cihazda duruyor ve ilk kareyi çizmek için tek bir ağ çağrısı
/// gerekmiyor. Uzak servisler uygulamayı açmalı değil, açıldıktan sonra
/// bağlanmalıydı.
///
/// ## Sözleşme
///
/// Bu yardımcı üç durumda da **daima tamamlanır**: başarı, hata, zaman aşımı.
/// Hata ve zaman aşımı bildirilir ama yutulmuş sayılmaz — ikisi de
/// [ErrorReporter]'a gider. Dönüş her hâlükârda kullanılabilir bir değerdir.
///
/// `timeout` bir `Future`'ı iptal ETMEZ; iş arka planda sürer. Amaç işi
/// durdurmak değil, ilk karenin ona bağlı kalmamasıdır.
Future<T> bootStep<T>(
  Future<T> future, {
  required String reason,
  required T Function() fallback,
  Duration timeout = const Duration(seconds: 4),
}) async {
  try {
    return await future.timeout(timeout);
  } on TimeoutException catch (error, stack) {
    ErrorReporter.record(error, stack, reason: 'boot timeout: $reason');
    return fallback();
  } catch (error, stack) {
    ErrorReporter.record(error, stack, reason: 'boot failed: $reason');
    return fallback();
  }
}

/// Değer döndürmeyen adımlar için [bootStep] kısayolu.
Future<void> bootStepVoid(
  Future<void> future, {
  required String reason,
  Duration timeout = const Duration(seconds: 4),
}) => bootStep<void>(future, reason: reason, fallback: () {}, timeout: timeout);
