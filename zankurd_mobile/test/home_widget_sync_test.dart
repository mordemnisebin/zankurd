import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
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

  // U13 (2026-10-28 tur 4, Android emülatör turu): widget "Günün sorusu"
  // olarak "Görselde …" sorusunu gösteriyordu; widget'ta görsel yok, soru
  // cevaplanamaz. Sessizdi: metin geçerli bir soru, yalnız şablonu görsel.
  group('pickDailyPrompt', () {
    QuizQuestion q(
      String id,
      String prompt, {
      String? promptTr,
      QuestionType type = QuestionType.multipleChoice,
      String? imageUrl,
    }) => QuizQuestion(
      id: id,
      category: 'Ziman',
      prompt: prompt,
      promptTr: promptTr,
      answers: const ['a', 'b'],
      correctAnswer: 'a',
      explanation: '',
      type: type,
      imageUrl: imageUrl,
    );

    test('görsele dayanan soruları atlar, ilk metin sorusunu seçer', () {
      final picked = HomeWidgetSync.pickDailyPrompt([
        q('1', 'Di wêneyê de çi heye?', promptTr: 'Görselde ne var?'),
        q('2', 'Navê wêneyê?', promptTr: 'Fotoğraftaki yer?'),
        q('3', 'Kîjan bajar?', type: QuestionType.visual),
        q('4', 'Kîjan çem?', imageUrl: 'https://x/y.png'),
        q('5', 'Paytexta Tirkiyê çi ye?', promptTr: 'Türkiye\'nin başkenti?'),
        q('6', 'Ya din', promptTr: 'Bir başka soru'),
      ], isKu: false);
      expect(picked, 'Türkiye\'nin başkenti?');
    });

    test('Kurmancî metin görsele gönderiyorsa Türkçede de atlanır', () {
      final picked = HomeWidgetSync.pickDailyPrompt([
        q('1', 'Di wêneyê de çi heye?', promptTr: 'Bu nedir?'),
        q('2', 'Kîjan çiya?', promptTr: 'Hangi dağ?'),
      ], isKu: false);
      expect(picked, 'Hangi dağ?');
    });

    test('uygun soru yoksa null (widget boş/marka durumu)', () {
      expect(
        HomeWidgetSync.pickDailyPrompt([
          q('1', 'Görselde ne var?', promptTr: 'Görselde ne var?'),
        ], isKu: false),
        isNull,
      );
      expect(HomeWidgetSync.pickDailyPrompt(const [], isKu: true), isNull);
    });
  });

  // U14 (2026-10-28 tur 4): widget seçicisinde önizleme boş "ZanKurd" yazısıydı
  // ve açıklama yalnız "ZanKurd" idi. Sessizdi: kaynak dosyaları derlenir,
  // yalnız emülatörde seçici açılınca görünür.
  test('Android widget önizlemesi gerçek örnek içerir, açıklama anlamlı', () {
    const res = 'android/app/src/main/res';
    final info = File('$res/xml/zankurd_widget_info.xml').readAsStringSync();
    expect(
      info,
      contains('android:previewLayout="@layout/zankurd_widget_preview"'),
    );
    final preview = File(
      '$res/layout/zankurd_widget_preview.xml',
    ).readAsStringSync();
    for (final key in const [
      'zk_widget_sample_streak',
      'zk_widget_sample_streak_label',
      'zk_widget_sample_daily_label',
      'zk_widget_sample_prompt',
    ]) {
      expect(preview, contains('@string/$key'));
    }
    // Örnek metinler kaynakta; düzende sabit yazı yok.
    expect(preview, isNot(contains('android:text="ZanKurd"')));
    for (final values in const ['values', 'values-ku']) {
      final strings = File(
        '$res/$values/zk_widget_strings.xml',
      ).readAsStringSync();
      expect(
        strings,
        contains('name="zk_widget_sample_prompt"'),
        reason: values,
      );
      expect(
        strings,
        contains('name="zk_widget_sample_streak_label"'),
        reason: values,
      );
      expect(
        RegExp(
          r'name="zk_widget_description"[^>]*>([^<]+)<',
        ).firstMatch(strings)!.group(1)!.length,
        greaterThan(20),
        reason: '$values: açıklama marka adından ibaret olamaz',
      );
    }
    final swift = File(
      'ios/ZanKurdWidget/ZanKurdWidget.swift',
    ).readAsStringSync();
    expect(
      swift,
      isNot(contains('dailyPrompt: "ZanKurd"')),
      reason: 'iOS galeri örneği',
    );
  });
}
