import 'push_tap_router.dart';

/// Yerel (zamanlanmış) bildirimlerin `payload` dizeleri.
///
/// Günlük hatırlatıcı ve seri uyarısı `payload`sız kuruluyordu ve dokunuşu
/// dinleyen kod yoktu: bildirime dokunan oyuncu uygulamanın son bıraktığı
/// ekranına düşüyordu (FCM dokunuşları [PushTapRouter] ile yönlenirken).
abstract final class LocalNotificationPayload {
  /// Günlük hatırlatıcı: "Günün dersi hazır".
  static const dailyReminder = 'zankurd.local.daily_reminder';

  /// Akşam seri uyarısı: "Bugün hiç oynamadın".
  static const streakWarning = 'zankurd.local.streak_warning';

  /// Günün yarışması: "Bugünkü tur seni bekliyor" (19:00, oynanmadıysa).
  static const contestReminder = 'zankurd.local.contest_reminder';
}

/// Yerel bildirim dokunuşunu [PushTapRouter]in bekleyen-hedef kanalına çevirir.
///
/// Böylece FCM dokunuşlarıyla AYNI yol izlenir: hedef [PushTapRouter.pending]de
/// bekler, [AppShell] kabuk hazır ve en üst sayfa olduğunda (canlı bir oda
/// maçının üstüne binmeden) tüketir. Soğuk açılışta da (bildirim uygulamayı
/// başlattıysa) aynı kanal kullanılır.
abstract final class LocalNotificationTapRouter {
  /// [payload] bilinen bir yerel bildirime aitse hedef, değilse `null`.
  /// Günlük hatırlatıcı ve seri uyarısı bugünün dersinin durduğu ana sayfaya
  /// (Öğren sekmesi), yarışma hatırlatması Yarış sekmesine gider.
  static PushTapTarget? targetForPayload(String? payload) {
    return switch (payload) {
      LocalNotificationPayload.dailyReminder ||
      LocalNotificationPayload.streakWarning => PushTapTarget.home,
      // Günün yarışması Yarış sekmesindedir.
      LocalNotificationPayload.contestReminder => PushTapTarget.playTab,
      _ => null,
    };
  }

  /// Dokunuşu kanala yazar; bilinmeyen payload yok sayılır (`false`).
  static bool offer(String? payload) {
    final target = targetForPayload(payload);
    if (target == null) return false;
    PushTapRouter.offerTarget(target);
    return true;
  }
}
