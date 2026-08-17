// Gerçek cihazda yerel bildirim çizelgelemesi (integration_test).
//
// Çalıştırma:
//   xcrun simctl privacy <udid> grant notifications com.zankurd.app
//   flutter test integration_test/notification_real_schedule_test.dart \
//     -d <simulator>
//
// Doğruladığı şey (2026-08-17 turu): Ayarlar'dan günlük hatırlatıcı açılınca
// işletim sistemi tarafında GERÇEKTEN bir zamanlanmış bildirim oluşur;
// saat değişince eski iptal edilip yenisi kurulur; kapatılınca kuyruk boşalır.
// Widget testleri bu süreci sahte eklentiyle doğruluyordu — burada iOS'un
// kendi bildirim kuyruğu okunur.
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zankurd_mobile/src/services/notification_service.dart';

Future<List<PendingNotificationRequest>> pending() =>
    FlutterLocalNotificationsPlugin().pendingNotificationRequests();

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('hatırlatıcı aç→saat kur→kapat gerçek kuyrukta görünür', (
    tester,
  ) async {
    NotificationService.resetInstance();
    final service = await NotificationService.load();

    await service.setEnabled(true);
    await service.setTime(9, 30);

    final requests = await pending();
    // ignore: avoid_print
    print('ZK_NOTIF_PENDING=${requests.length}');
    expect(requests, isNotEmpty, reason: 'izin verildi ama kuyruk boş');
    expect(requests.first.id, 0);

    final expected = service.nextFireAt!;
    final tomorrow930 = service.nextFireTime();
    expect(
      expected.difference(tomorrow930).inMinutes.abs(),
      lessThan(1),
      reason: 'kalıcı nextFireAt hesaplanan anla uyuşmalı',
    );

    await service.setEnabled(false);
    final after = await pending();
    // ignore: avoid_print
    print('ZK_NOTIF_AFTER_OFF=${after.length}');
    expect(after, isEmpty, reason: 'kapatınca kuyruk boşalmalı');

    // Temizlik: sonraki koşular boş tercihlerle başlasın.
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('zankurd.notifications.enabled');
  });
}
