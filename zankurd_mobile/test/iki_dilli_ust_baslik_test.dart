/// İki dilli etiketlerin bekçisi (2026-10-20 kimlik kararı "Tîp" + kullanıcı
/// geri bildirimi).
///
/// ## Karar
///
/// Sade arayüzde bile oyuncu bir şeyi bulmakta zorlanıyordu. Yön bulduran
/// etiketlerde — alt sekmeler, ekran ve bölüm başlıkları, konu kartları —
/// seçili dil büyük, öbür dil küçük ve ikincil renkte yazılır. İKİ arayüz
/// dilinde de: Türkçede Kurmancî küçük, Kurmancîde Türkçe küçük. Ayarlardan
/// kapatılınca her yer tek dile döner. Düğme, soru, şık, açıklama tek dildir.
///
/// ## Neyi korur, niçin sessiz kalırdı
///
/// * Küçük satır aynı anahtarın ÖBÜR dildeki değeridir. Birisi ekrana elle
///   bir Kurmancî söz yazsa (ya da yanlış anahtarı okusa) ekran yine "iki
///   dilli" görünür ve hiçbir test kırılmazdı. Bekçi görünen satırı
///   `Tr.counterpart(aynı anahtar)` ile karşılaştırır.
/// * Ayar kapalıyken hiçbir ikinci satır kalmamalı; açık/kapalı farkını
///   ekran görüntüsü testleri ölçmez.
/// * Öbür dildeki karşılık seçili dildekiyle aynıysa (ör. "Siyaset") satır
///   çizilmez: aynı sözü iki kez yazmak bilgi değildir.
/// * Dar ekran (320) ve %200 yazıda küçük satır sığmazsa gizlenir, düzen
///   taşmaz (taşma `flutter test`te hata olarak yakalanır).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/level_progress_store.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/providers/auth_provider.dart';
import 'package:zankurd_mobile/src/providers/bilingual_labels_provider.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

Widget _shell(
  Widget child, {
  required bool isKu,
  bool bilingual = true,
  double width = 390,
  double textScale = 1,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider(
        create: (_) => LanguageProvider(initialLang: isKu ? 'ku' : 'tr'),
      ),
      ChangeNotifierProvider(create: (_) => AuthProvider.test()),
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(
        create: (_) => BilingualLabelsProvider(initialEnabled: bilingual),
      ),
      ChangeNotifierProvider<PremiumService>(
        create: (_) => PremiumService.fallback(),
      ),
    ],
    child: MaterialApp(
      key: ValueKey('bi-$isKu-$bilingual-$width-$textScale'),
      theme: AppTheme.light(),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(
          context,
        ).copyWith(textScaler: TextScaler.linear(textScale)),
        child: child!,
      ),
      home: child,
    ),
  );
}

Widget _home() => HomeScreen(
  repository: MockZanKurdRepository(),
  onOpenLearning: () async {},
  onOpenPlay: () {},
);

List<String> _seconds(WidgetTester tester) => tester
    .widgetList<SahneBilingualLabel>(find.byType(SahneBilingualLabel))
    .map((w) => w.text)
    .toList();

Future<void> _size(WidgetTester tester, Size size) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  setUp(() {
    AchievementStore.resetInstance();
    SharedPreferences.setMockInitialValues({});
    MasteryStore.resetInstance();
    LevelProgressStore.resetInstance();
  });

  test('karşılık öbür dilin aynı anahtarıdır; aynıysa yoktur', () {
    expect(
      Tr.counterpart(K.playTitle, isKu: false),
      Tr.of(K.playTitle, AppLanguage.ku),
    );
    expect(
      Tr.counterpart(K.playTitle, isKu: true),
      Tr.of(K.playTitle, AppLanguage.tr),
    );
    expect(Tr.counterpart(K.homeTopicsTitle, isKu: false), 'Mijar');
    expect(Tr.counterpart(K.homeTopicsTitle, isKu: true), 'Konular');
    // "Siyaset" iki dilde aynı: ikinci satır bilgi taşımaz.
    expect(Tr.counterpart(K.catSiyaset, isKu: false), isNull);
  });

  for (final isKu in [false, true]) {
    final lang = isKu ? 'KU' : 'TR';

    testWidgets(
      '$lang ana sayfa: başlık, Konular ve konu kartlarında öbür dil',
      (tester) async {
        await _size(tester, const Size(390, 2400));
        await tester.pumpWidget(_shell(_home(), isKu: isKu));
        await tester.pumpAndSettle();

        final seconds = _seconds(tester);
        expect(
          seconds,
          contains(Tr.counterpart(K.homeGreetingAnon, isKu: isKu)),
        );
        expect(
          seconds,
          contains(Tr.counterpart(K.homeTopicsTitle, isKu: isKu)),
        );
        // "Günün dersi" kartının İÇİNDE öbür dil yok (AZ SÖZ 2026-10-20).
        expect(
          seconds,
          isNot(contains(Tr.counterpart(K.gununDersi, isKu: isKu))),
        );
        // Konu kartı: kategori adının öbür dildeki karşılığı, karonun İÇİNDE.
        final tile = find.byKey(const ValueKey('home-topic-Dîrok'));
        expect(
          find.descendant(
            of: tile,
            matching: find.text(Tr.counterpart(K.catDirok, isKu: isKu)!),
          ),
          findsOneWidget,
        );
        // Aynı adlı konuda ikinci satır yok.
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('home-topic-Siyaset')),
            matching: find.byType(SahneBilingualLabel),
          ),
          findsNothing,
        );
      },
    );

    testWidgets('$lang yarış merkezi: "Yarış" başlığında öbür dil', (
      tester,
    ) async {
      await tester.pumpWidget(
        _shell(PlayHubScreen(repository: MockZanKurdRepository()), isKu: isKu),
      );
      await tester.pumpAndSettle();
      expect(
        _seconds(tester),
        contains(Tr.counterpart(K.playTitle, isKu: isKu)),
      );
    });

    testWidgets('$lang ayar kapalıyken hiçbir ikinci satır yok', (
      tester,
    ) async {
      await _size(tester, const Size(390, 2400));
      await tester.pumpWidget(_shell(_home(), isKu: isKu, bilingual: false));
      await tester.pumpAndSettle();
      expect(find.byType(SahneBilingualLabel), findsNothing);

      await tester.pumpWidget(
        _shell(
          PlayHubScreen(repository: MockZanKurdRepository()),
          isKu: isKu,
          bilingual: false,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(SahneBilingualLabel), findsNothing);
    });

    testWidgets('$lang alt sekmelerde öbür dil; ayar kapalıyken yok', (
      tester,
    ) async {
      // Dar telefon: geniş ekranda alt çubuk yerine yan ray çizilir.
      await _size(tester, const Size(390, 844));
      for (final bilingual in [true, false]) {
        final repo = freshMockRepository();
        await tester.pumpWidget(
          KeyedSubtree(
            key: ValueKey('nav-$bilingual'),
            child: MultiProvider(
              providers: [
                ChangeNotifierProvider(
                  create: (_) =>
                      BilingualLabelsProvider(initialEnabled: bilingual),
                ),
              ],
              child: testShell(
                languageProvider: isKu ? kurmanciLang() : turkishLang(),
                child: AppShell(repository: repo),
              ),
            ),
          ),
        );
        // Kabukta sürekli dönen bir yükleyici var; sayılı pump.
        for (var i = 0; i < 6; i++) {
          await tester.pump(const Duration(milliseconds: 120));
        }
        final row = find.byKey(const ValueKey('nav-second-labels'));
        if (!bilingual) {
          expect(row, findsNothing);
          continue;
        }
        for (final key in [
          K.navLearn,
          K.navPlay,
          K.navLeaderboard,
          K.navProfile,
        ]) {
          // "Rûpela sereke" (13 harf) Ahem'in kare harfleriyle 97 px'lik
          // sekmeye sığmaz ve satır kuralı gereği gizlenir; gerçek yazı
          // tipinde sığar. Ana etiket home_daily_tour_test'te sınanır.
          if (key == K.navLearn && !isKu) continue;
          final other = Tr.counterpart(key, isKu: isKu);
          if (other == null) continue;
          expect(
            find.descendant(of: row, matching: find.text(other)),
            findsOneWidget,
            reason: key,
          );
        }
      }
    });
  }

  testWidgets('320 genişlik + %200 yazı: taşma yok, sığmayan satır gizli', (
    tester,
  ) async {
    await _size(tester, const Size(320, 3200));
    await tester.pumpWidget(_shell(_home(), isKu: true, textScale: 2));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
    // Görünen her küçük satır gerçekten kutusuna sığıyor (kesik söz yok).
    for (final element in find.byKey(SahneBilingualLabel.valueKey).evaluate()) {
      final box = element.renderObject! as RenderBox;
      final parent = element.findAncestorRenderObjectOfType<RenderBox>()!;
      expect(box.size.width, lessThanOrEqualTo(parent.size.width + 0.5));
    }

    await tester.pumpWidget(
      _shell(
        PlayHubScreen(repository: MockZanKurdRepository()),
        isKu: false,
        textScale: 2,
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Ayarlar: iki dilli etiketler anahtarı kapatır', (tester) async {
    final provider = BilingualLabelsProvider();
    await _size(tester, const Size(390, 3000));
    await tester.pumpWidget(
      MultiProvider(
        providers: [ChangeNotifierProvider.value(value: provider)],
        child: testShell(
          child: SettingsScreen(repository: freshMockRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final toggle = find.byKey(const ValueKey('bilingual-labels-switch'));
    expect(toggle, findsOneWidget);
    expect(find.text(Tr.of(K.bilingualLabels, AppLanguage.tr)), findsOneWidget);
    await tester.ensureVisible(toggle);
    await tester.tap(toggle);
    await tester.pumpAndSettle();
    expect(provider.enabled, isFalse);
  });
}
