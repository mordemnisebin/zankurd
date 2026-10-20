import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/level_placement_screen.dart';
import 'package:zankurd_mobile/src/services/placement_scoring.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'support/realistic_device.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

/// Öğren ekranındaki "Seviyeni bul" daveti.
///
/// ## Kusur
///
/// `PlacementStore.shouldPrompt` hiçbir yerden çağrılmıyordu; seviye sınavına
/// yalnız Ayarlar'dan gidiliyordu. Yeni kullanıcı sınavın var olduğunu hiç
/// öğrenmiyor, ders önerisi yerine hep ilk dersten başlıyordu.
///
/// ## Niçin sessizdi
///
/// Sınav ekranı ve depo ayrı ayrı testliydi ve çalışıyordu; eksik olan iki
/// ucun birbirine bağlanmasıydı ve eksik bir bağlantıyı hiçbir test aramaz.
Widget _app({String lang = 'tr', double scale = 1}) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang(lang)),
  ],
  child: MaterialApp(
    theme: AppTheme.light(),
    builder: (context, child) => MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(scale)),
      child: child!,
    ),
    home: LearningScreen(repository: MockZanKurdRepository()),
  ),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(loadAppFonts);

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlacementStore.resetInstance();
  });

  const card = ValueKey('learning-placement-prompt');

  testWidgets('hiç sınav alınmamışsa davet görünür ve sınavı açar', (
    tester,
  ) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    expect(find.byKey(card), findsOneWidget);
    expect(find.text('Seviyeni bul'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('learning-placement-start')));
    await tester.pumpAndSettle();
    expect(find.byType(LevelPlacementScreen), findsOneWidget);
  });

  testWidgets('"Şimdilik geç" daveti kapatır ve kalıcı geçer', (tester) async {
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('learning-placement-dismiss')));
    await tester.pumpAndSettle();
    expect(find.byKey(card), findsNothing);

    PlacementStore.resetInstance();
    expect((await PlacementStore.load()).shouldPrompt, isFalse);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byKey(card), findsNothing);
  });

  testWidgets('seviyesi belli kullanıcıya davet gösterilmez', (tester) async {
    final store = await PlacementStore.load();
    await store.saveResult(PlacementLevel.navin);
    await tester.pumpWidget(_app());
    await tester.pumpAndSettle();
    expect(find.byKey(card), findsNothing);
  });

  testWidgets('Kurmancî metin ve dar ekran/büyük yazıda taşma yok', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 640));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_app(lang: 'ku', scale: 2));
    await tester.pumpAndSettle();

    expect(find.text('Asta xwe bibîne'), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(card),
        matching: find.text('Dest bi azmûnê bike'),
      ),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  // Kusur: 320 pt + 2x yazıda başlık "Sevi…" diye kesiliyor, "Teste başla ›"
  // harf harf alt alta kırılıyordu. Tek satır düzeni dar alanda sessizce
  // bozulur; testler yalnız 390 pt/1x'te bakıyordu.
  for (final lang in ['tr', 'ku']) {
    testWidgets('320 pt + 2x yazı ($lang): metin kesilmez, eylem tek satır', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_app(lang: lang, scale: 2));
      await tester.pumpAndSettle();

      expect(find.byKey(card), findsOneWidget);
      final texts = tester.widgetList<Text>(
        find.descendant(of: find.byKey(card), matching: find.byType(Text)),
      );
      for (final t in texts) {
        expect(t.overflow, isNot(TextOverflow.ellipsis));
      }
      final start = find.byKey(const ValueKey('learning-placement-start'));
      final textBox = tester.getSize(
        find.descendant(of: start, matching: find.byType(Text)).first,
      );
      // Etiket tek satır: kutu yüksekliği captionStrong'un tek satırını
      // (2x ölçekte) aşmaz.
      final oneLine = const TextScaler.linear(2).scale(
        (SahneType.captionStrong.fontSize ?? 14) *
            (SahneType.captionStrong.height ?? 1.4),
      );
      // Kurmancî etiket ("Dest bi azmûnê bike") 2x yazıda 272 pt'ye
      // doğal olarak sığmaz; en çok iki satır ve sözcük ortadan bölünmez.
      expect(
        textBox.height,
        lessThanOrEqualTo(oneLine * (lang == 'ku' ? 2 : 1) + 2),
      );
      final words = tester
          .widget<Text>(
            find.descendant(of: start, matching: find.byType(Text)).first,
          )
          .data!
          .split(' ');
      for (final w in words) {
        final p = TextPainter(
          text: TextSpan(text: w, style: SahneType.captionStrong),
          textDirection: TextDirection.ltr,
          textScaler: const TextScaler.linear(2),
        )..layout();
        expect(textBox.width, greaterThanOrEqualTo(p.width - 1), reason: w);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
