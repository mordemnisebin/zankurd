import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/services/home_widget_sync.dart';

/// Ana ekran widget'ının veri sözleşmesini korur (HomeWidgetSync).
///
/// Niçin var: widget'ın yerel tarafı (Swift/Kotlin) çeviri bilmez; etiketlerin
/// ve sayıların Dart'tan, SEÇİLİ DİLDE ve belirli anahtar adlarıyla yazılması
/// bir sözleşmedir. Anahtar adı ya da dil kayarsa widget sessizce boş ya da
/// yanlış dilde kalır — derleme ve analiz bunu yakalamaz. Ayrıca widget
/// ana ekranın süsüdür: kanal hatası uygulamayı asla düşürmemelidir.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('home_widget');
  late List<MethodCall> calls;

  setUp(() {
    calls = [];
    HomeWidgetSync.supportedOverride = () => true;
  });

  tearDown(() {
    HomeWidgetSync.supportedOverride = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  void mock({Object? Function(MethodCall)? onCall}) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          calls.add(call);
          return onCall?.call(call) ?? true;
        });
  }

  Map<String, Object?> written() => {
    for (final c in calls.where((c) => c.method == 'saveWidgetData'))
      (c.arguments as Map)['id'] as String: (c.arguments as Map)['data'],
  };

  test('Türkçe: etiketler ve veri doğru anahtarlarla yazılır', () async {
    mock();
    await HomeWidgetSync.sync(
      streak: 7,
      isKu: false,
      dailyPrompt: '  Kürtçe\n"su" ne demek?  ',
      now: DateTime.utc(2026, 10, 28, 9),
    );
    final w = written();
    expect(w['streak'], 7);
    expect(w['dailyPrompt'], 'Kürtçe "su" ne demek?');
    expect(w['labelStreak'], 'Üst üste');
    expect(w['labelUnit'], 'gün');
    expect(w['labelDaily'], 'Günün sorusu');
    expect(
      w['updatedAt'],
      DateTime.utc(2026, 10, 28, 9).millisecondsSinceEpoch,
    );
    expect(calls.first.method, 'setAppGroupId');
    expect((calls.first.arguments as Map)['groupId'], 'group.com.zankurd.app');
    final update = calls.last;
    expect(update.method, 'updateWidget');
    expect((update.arguments as Map)['ios'], 'ZanKurdWidget');
    expect((update.arguments as Map)['android'], 'ZanKurdWidgetProvider');
  });

  test('Kurmancî: etiketler Kurmancî gelir', () async {
    mock();
    await HomeWidgetSync.sync(streak: 3, isKu: true);
    final w = written();
    expect(w['labelStreak'], 'Zincîr');
    expect(w['labelUnit'], 'roj');
    expect(w['labelDaily'], 'Pirsa rojê');
    expect(w['dailyPrompt'], '');
  });

  test('uzun soru kısaltılır, negatif seri 0 olur', () async {
    mock();
    await HomeWidgetSync.sync(streak: -2, isKu: false, dailyPrompt: 'a' * 400);
    final w = written();
    expect(w['streak'], 0);
    expect((w['dailyPrompt'] as String).length, HomeWidgetSync.maxPromptLength);
  });

  test('kanal hatası fırlatmaz', () async {
    mock(onCall: (_) => throw PlatformException(code: 'boom'));
    await HomeWidgetSync.sync(streak: 1, isKu: false);
  });

  test('eklenti yokken (MissingPluginException) fırlatmaz', () async {
    await HomeWidgetSync.sync(streak: 1, isKu: false);
  });

  test('desteklenmeyen platformda kanala hiç dokunmaz', () async {
    mock();
    HomeWidgetSync.supportedOverride = () => false;
    await HomeWidgetSync.sync(streak: 1, isKu: false);
    expect(calls, isEmpty);
  });
}
