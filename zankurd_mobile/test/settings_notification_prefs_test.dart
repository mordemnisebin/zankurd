/// Ayarlar › Ses ve bildirim: tür tercihleri ekranı.
///
/// ## Kusur
///
/// Tek anahtar ("Günlük hatırlatıcı") bütün bildirimleri yönetiyordu; seri
/// uyarısı, günün yarışması, düello ve arkadaş bildirimleri ayrı
/// kapatılamıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Ekran yalnız servisin alıcılarını çağırır; anahtarın servise, düello ve
/// arkadaş tercihinin ayrıca sunucuya ulaştığı hiçbir testte görünmezdi.
///
/// ## Kural
///
/// * Ana anahtar kapalıyken tür satırları gösterilmez; açıkken beşi de
///   görünür ve varsayılan AÇIKTIR.
/// * Her satır yalnız kendi tercihini değiştirir.
/// * Düello ve arkadaş satırları sunucuya yazılır.
/// * 320 px ve %200 yazıda taşma yok.
library;

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/services/notification_service.dart';
import 'support/widget_test_helpers.dart';

class _Resolver implements TimeZoneResolver {
  const _Resolver();

  @override
  Future<String?> resolve() async => 'Europe/Berlin';
}

class _Gateway implements LocalNotificationGateway {
  final cancelled = <int>[];
  final scheduledIds = <int>[];

  @override
  Future<void> initialize(
    InitializationSettings settings,
    void Function(String? payload) onTap,
  ) async {}

  @override
  Future<String?> launchPayload() async => null;

  @override
  Future<void> zonedSchedule({
    required int id,
    required String title,
    required String body,
    required DateTime at,
    required NotificationDetails details,
    String? payload,
    bool repeatDaily = true,
  }) async => scheduledIds.add(id);

  @override
  Future<void> cancel(int id) async => cancelled.add(id);

  @override
  Future<void> cancelAll() async => cancelled.add(-1);
}

const _master = ValueKey('settings-notif-master');
const _keys = {
  'daily': ValueKey('settings-notif-daily'),
  'contest': ValueKey('settings-notif-contest'),
  'streak': ValueKey('settings-notif-streak'),
  'duel': ValueKey('settings-notif-duel'),
  'social': ValueKey('settings-notif-social'),
};

Future<void> _reveal(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    200,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

bool _on(WidgetTester tester, ValueKey<String> key) =>
    tester.widget<Switch>(find.byKey(key)).value;

void main() {
  late MockZanKurdRepository repository;
  late _Gateway gateway;

  setUp(() async {
    SharedPreferences.setMockInitialValues({'zankurd.language': 'tr'});
    NotificationService.resetInstance();
    repository = freshMockRepository();
    gateway = _Gateway();
  });
  tearDown(NotificationService.resetInstance);

  Future<NotificationService> pumpSettings(
    WidgetTester tester, {
    required bool enabled,
    Size size = const Size(390, 844),
    double textScale = 1.0,
  }) async {
    await tester.binding.setSurfaceSize(size);
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final service = await NotificationService.load(
      timeZoneResolver: const _Resolver(),
      gateway: gateway,
    );
    await service.setEnabled(enabled);
    await tester.pumpWidget(
      MediaQuery(
        data: MediaQueryData(
          size: size,
          textScaler: TextScaler.linear(textScale),
        ),
        child: testShell(child: SettingsScreen(repository: repository)),
      ),
    );
    await tester.pumpAndSettle();
    await _reveal(tester, find.byKey(_master));
    return service;
  }

  testWidgets('ana anahtar kapalıyken tür satırları görünmez', (tester) async {
    await pumpSettings(tester, enabled: false);
    expect(find.byKey(_master), findsOneWidget);
    for (final key in _keys.values) {
      expect(find.byKey(key), findsNothing);
    }
  });

  testWidgets('ana anahtar açıkken beş tür de görünür ve varsayılan AÇIK', (
    tester,
  ) async {
    await pumpSettings(tester, enabled: true);
    for (final entry in _keys.entries) {
      await _reveal(tester, find.byKey(entry.value));
      expect(_on(tester, entry.value), isTrue, reason: entry.key);
    }
  });

  testWidgets('seri uyarısını kapatmak yalnız onu iptal eder', (tester) async {
    final service = await pumpSettings(tester, enabled: true);
    await _reveal(tester, find.byKey(_keys['streak']!));
    gateway.cancelled.clear();

    await tester.tap(find.byKey(_keys['streak']!));
    await tester.pumpAndSettle();

    expect(service.streakOn, isFalse);
    expect(service.dailyOn, isTrue);
    expect(service.contestOn, isTrue);
    expect(gateway.cancelled, contains(2));
    expect(gateway.cancelled, isNot(contains(0)));
    expect(_on(tester, _keys['streak']!), isFalse);
  });

  testWidgets('günlük hatırlatmayı kapatmak saat satırını gizler', (
    tester,
  ) async {
    final service = await pumpSettings(tester, enabled: true);
    await _reveal(tester, find.byKey(_keys['daily']!));
    expect(find.text('Saati değiştir: 19:00'), findsOneWidget);

    await tester.tap(find.byKey(_keys['daily']!));
    await tester.pumpAndSettle();

    expect(service.dailyOn, isFalse);
    expect(find.text('Saati değiştir: 19:00'), findsNothing);
    expect(gateway.cancelled, contains(0));
  });

  testWidgets('düello ve arkadaş tercihi sunucuya yazılır', (tester) async {
    final service = await pumpSettings(tester, enabled: true);

    await _reveal(tester, find.byKey(_keys['duel']!));
    await tester.tap(find.byKey(_keys['duel']!));
    await tester.pumpAndSettle();
    await _reveal(tester, find.byKey(_keys['social']!));
    await tester.tap(find.byKey(_keys['social']!));
    await tester.pumpAndSettle();

    expect(service.duelOn, isFalse);
    expect(service.socialOn, isFalse);
    final flags = (await repository.loadAccountFlags())!;
    expect(flags.pushDuel, isFalse);
    expect(flags.pushSocial, isFalse);
    expect(service.serverPrefsDirty, isFalse);
  });

  testWidgets('kapalı kaydedilmiş tercih ekranda kapalı görünür', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.language': 'tr',
      'zankurd.notifications.pref.contest': false,
    });
    await pumpSettings(tester, enabled: true);
    await _reveal(tester, find.byKey(_keys['contest']!));
    expect(_on(tester, _keys['contest']!), isFalse);
    expect(_on(tester, _keys['duel']!), isTrue);
  });

  for (final width in [320.0, 360.0]) {
    testWidgets('$width px ve %200 yazıda taşma yok', (tester) async {
      await pumpSettings(
        tester,
        enabled: true,
        size: Size(width, 800),
        textScale: 2.0,
      );
      for (final key in _keys.values) {
        await _reveal(tester, find.byKey(key));
      }
      expect(tester.takeException(), isNull);
    });
  }
}
