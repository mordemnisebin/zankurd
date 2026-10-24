// Bekçi: Android bildirim kanalı adları uygulama dilini izler (E1).
//
// ## Kusur
// `AndroidNotificationDetails` kanal adı ve açıklaması Kurmancî sabitti
// ('ZanKurd Bîrxistina Rojane', 'Daxwazên Hevaltiyê'...). Gövde ve başlık
// [Tr.forKu] ile dile göre seçilirken Android sistem ayarlarında görünen
// kanal adı Türkçe kullanıcıya hep Kurmancî görünüyordu.
//
// ## Niçin sessiz kalırdı
// Kanal adı yalnız Android "Bildirimler" ayar ekranında görünür; uygulama
// içi hiçbir ekran ve test onu okumaz.
//
// ## Kural
// Kanal adı/açıklaması metin kayıt defterinden ([K]) gelir ve zamanlama
// anındaki uygulama diliyle seçilir.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/services/notification_service.dart';

class _FakeTimeZoneResolver implements TimeZoneResolver {
  const _FakeTimeZoneResolver();

  @override
  Future<String?> resolve() async => 'Europe/Istanbul';
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final calls = <MethodCall>[];

  setUpAll(() {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    // Dart eklenti kaydı testte çalışmaz; Android uygulamasını elle kur.
    FlutterLocalNotificationsPlatform.instance =
        AndroidFlutterLocalNotificationsPlugin();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          (call) async {
            calls.add(call);
            return null;
          },
        );
  });

  tearDownAll(() {
    debugDefaultTargetPlatformOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dexterous.com/flutter/local_notifications'),
          null,
        );
  });

  Future<NotificationService> service(String lang) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.language': lang,
      'zankurd.notifications.enabled': true,
    });
    NotificationService.resetInstance();
    calls.clear();
    final s = await NotificationService.load(
      timeZoneResolver: const _FakeTimeZoneResolver(),
    );
    await s.setEnabled(true);
    return s;
  }

  /// Gönderilen bildirimlerin (kanal adı, kanal açıklaması) çiftleri.
  List<(String, String)> channels() {
    final out = <(String, String)>[];
    void walk(Object? node) {
      if (node is Map) {
        final name = node['channelName'];
        final desc = node['channelDescription'];
        if (name is String && desc is String) out.add((name, desc));
        node.values.forEach(walk);
      } else if (node is Iterable) {
        node.forEach(walk);
      }
    }

    for (final call in calls) {
      walk(call.arguments);
    }
    return out;
  }

  test('Türkçe dilde günlük ve zincir kanalları Türkçe adlanır', () async {
    final s = await service('tr');
    await s.scheduleStreakWarning(isKu: false);
    await s.showFriendRequest('Berfin', isKu: false);

    final found = channels();
    expect(found, isNotEmpty, reason: 'hiç kanal bilgisi yakalanmadı');
    for (final (name, desc) in found) {
      expect(name, isNot(contains('Bîranîn')), reason: name);
      expect(desc, isNot(contains('Bîranîn')), reason: desc);
    }
    expect(found.any((c) => c.$1 == 'ZanKurd Günlük Hatırlatıcı'), isTrue);
    expect(found.any((c) => c.$1 == 'ZanKurd Seri Hatırlatıcısı'), isTrue);
    expect(found.any((c) => c.$1 == 'ZanKurd Arkadaşlık İstekleri'), isTrue);
  });

  test('Kurmancî dilde kanallar Kurmancî kalır', () async {
    final s = await service('ku');
    await s.scheduleStreakWarning(isKu: true);
    await s.showFriendRequest('Berfin', isKu: true);

    final found = channels();
    expect(found.any((c) => c.$1 == 'ZanKurd Bîrxistina Rojane'), isTrue);
    expect(found.any((c) => c.$1 == 'ZanKurd Bîrxistina Zincîrê'), isTrue);
    expect(found.any((c) => c.$1 == 'ZanKurd Daxwazên Hevaltiyê'), isTrue);
  });
}
