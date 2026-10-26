// 2026-10-19 sadeleşme (ikinci tur): hızlı düello kartı gece sahne
// kartından sakin yüzey kartına (`SahneSurfaceCard`) döndü; "Arkadaşlarınla"
// bölüm başlığı, "Etkinlikler" başlığı ve oda eylemlerinin açıklama satırı
// kalktı (iki düğme kendini anlatıyor; Yarış sekmesi başlıksız, kısa
// liste). Bekçiler yeni sözleşmeyi sorar: kartın yarış kimliği üst etiket
// metnindedir, tek Agir düğme yine "Rakip bul".
// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
// 2026-09-29 doğallık (K5, K7): düello kartında VS amblemi yok (yerine
// "10 soru · ~2 dakika"); "Oda kur" ve "Kodla katıl" liste grubu değil yan
// yana iki ikincil düğme. Bekçiler yeni düzeni ve TEK Agir kuralını sorar.
import 'support/play_hub_nav.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/config/feature_flags.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'support/widget_test_helpers.dart'
    show testShell, kurmanciLang, turkishLang;

Widget _shell(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang('tr'),
      ),
      ChangeNotifierProvider<SoundProvider>(create: (_) => SoundProvider()),
    ],
    child: MaterialApp(theme: AppTheme.dark(), home: child),
  );
}

void main() {
  testWidgets('hızlı düello yarış sahne kartında tek Agir eylem taşır', (
    tester,
  ) async {
    // 2026-09-29 Şahnê: hero bir düello sahne kartıdır (Boyax sahne
    // degradesi bileşende); turuncu yalnız "Rakip bul" düğmesinde ve o
    // ekrandaki TEK birincil düğmedir. Agir üstünde metin koyu `onAct`.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(PlayHubScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final hero = find.byKey(const ValueKey('play-hub-quick-duel'));
    // 2026-10-20 renk ve canlılık: kahraman beyaz yüzey kartı değil, Boyax
    // gradyanlı DOLU karttır (bkz. renk_canlilik_test.dart).
    expect(
      find.descendant(of: hero, matching: find.byType(SahneSurfaceCard)),
      findsNothing,
    );
    expect(
      find.descendant(
        of: hero,
        matching: find.byWidgetPredicate(
          (w) =>
              w is DecoratedBox &&
              w.decoration is BoxDecoration &&
              (w.decoration as BoxDecoration).gradient is LinearGradient,
        ),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(of: hero, matching: find.byType(SahneStageCard)),
      findsNothing,
    );
    expect(
      find.descendant(of: hero, matching: find.byType(SahneVsEmblem)),
      findsNothing,
    );
    expect(
      find.descendant(of: hero, matching: find.text('10 soru · ~2 dakika')),
      findsOneWidget,
    );
    // Tek Agir düğme kartta; ekranda başka dolgulu düğme yoktur (oda
    // eylemleri artık alt sayfadadır).
    expect(
      find.descendant(of: hero, matching: find.byType(FilledButton)),
      findsOneWidget,
    );
    final ctx = tester.element(find.text('Rakip seç'));
    final label = tester.widget<Text>(find.text('Rakip seç'));
    expect(
      DefaultTextStyle.of(ctx).style.merge(label.style).color,
      SahneTokens.night.onAct,
    );
  });

  testWidgets('hızlı düello ana eylemi 48dp ve semantik düğmedir', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(PlayHubScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final hero = find.byKey(const ValueKey('play-hub-quick-duel'));
    final heroData = tester.getSemantics(hero).getSemanticsData();
    expect(heroData.flagsCollection.isButton, isTrue);
    expect(heroData.label, 'Canlı düello. Rakip seç');
    final action = find.byKey(const ValueKey('play-hub-quick-duel-cta'));
    expect(action, findsOneWidget);
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    semantics.dispose();
  });

  // 2026-10-27: turnuva "Daha fazla" ardından çıktı, doğrudan satır.
  testWidgets(
    'turnuva satırı ekran okuyucuda tek kez duyurulur',
    skip: !kTournamentEnabled,
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _shell(PlayHubScreen(repository: MockZanKurdRepository())),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('play-hub-tournament')),
      );
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(RegExp(r'^Turnuva\.')), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('oyun merkezi tam üç oyun seçimi ve günlük kartlar gösterir', (
    tester,
  ) async {
    // 2026-10-24 sahibin kararı: Canlı düello, Sırayla düello, Oda. Eski
    // "Arkadaşına meydan oku" kartı ve açıkta duran Oda kur / Kodla katıl
    // düğmeleri yoktur; işlevleri üç seçimin içindedir.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(
        PlayHubScreen(
          repository: MockZanKurdRepository(),
          asyncDuelEnabled: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SahneSectionHeader), findsNothing);
    expect(find.byKey(const ValueKey('play-hub-quick-duel')), findsOneWidget);
    expect(find.byKey(const ValueKey('play-hub-async-duel')), findsOneWidget);
    expect(find.byKey(const ValueKey('play-hub-room')), findsOneWidget);
    expect(find.text('Canlı düello'), findsOneWidget);
    expect(find.text('Sırayla düello'), findsOneWidget);
    expect(find.text('Oda'), findsOneWidget);
    // Eski girişler ekranda DEĞİL.
    expect(find.byKey(const ValueKey('play-hub-create-room')), findsNothing);
    expect(find.byKey(const ValueKey('play-hub-join-room')), findsNothing);
    expect(
      find.byKey(const ValueKey('play-hub-async-duel-challenge')),
      findsNothing,
    );
    expect(find.text('Arkadaşına meydan oku'), findsNothing);
    expect(find.text('Hızlı düello'), findsNothing);
    // Günün turu ve çarkı korunur.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('play-hub-spin-wheel')),
      200,
    );
    expect(
      find.byKey(const ValueKey('play-hub-daily-contest')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('play-hub-spin-wheel')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('play-hub-tournament')),
      kTournamentEnabled ? findsOneWidget : findsNothing,
    );
    expect(find.byKey(const ValueKey('play-hub-shop-card')), findsNothing);
    expect(find.text('Turnuva ve sıralama'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'sıra: canlı düello, sırayla düello ve oda, sonra günlük kartlar',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 1400));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _shell(
          PlayHubScreen(
            repository: MockZanKurdRepository(),
            asyncDuelEnabled: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      double top(String key) => tester.getTopLeft(find.byKey(ValueKey(key))).dy;
      expect(top('play-hub-quick-duel'), lessThan(top('play-hub-async-duel')));
      expect(top('play-hub-async-duel'), top('play-hub-room'));
      expect(top('play-hub-room'), lessThan(top('play-hub-daily-contest')));
      expect(top('play-hub-daily-contest'), lessThan(top('play-hub-friends')));
    },
  );

  testWidgets('Oda kartı oda kur ve kodla katıl satırlarını açar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _shell(PlayHubScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();
    await openRoomSheet(tester);
    expect(find.byKey(const ValueKey('play-hub-room-sheet')), findsOneWidget);
    for (final key in ['play-hub-create-room', 'play-hub-join-room']) {
      final r = tester.getRect(find.byKey(ValueKey(key)));
      expect(r.height, greaterThanOrEqualTo(48), reason: key);
    }
    expect(find.text('Oda kur'), findsOneWidget);
    expect(find.text('Kodla katıl'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 2.0]) {
    for (final lang in ['tr', 'ku']) {
      testWidgets(
        'rakip ve oda sayfaları 320 pt, yazı x$scale, $lang: taşma yok',
        (tester) async {
          await tester.binding.setSurfaceSize(const Size(320, 700));
          addTearDown(() => tester.binding.setSurfaceSize(null));
          await tester.pumpWidget(
            testShell(
              child: MediaQuery(
                data: MediaQueryData(textScaler: TextScaler.linear(scale)),
                child: PlayHubScreen(
                  repository: MockZanKurdRepository(),
                  asyncDuelEnabled: true,
                ),
              ),
              languageProvider: lang == 'ku' ? kurmanciLang() : turkishLang(),
            ),
          );
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);
          await openLiveOpponentSheet(tester);
          expect(
            find.byKey(const ValueKey('opponent-sheet-random')),
            findsOneWidget,
          );
          expect(
            find.byKey(const ValueKey('opponent-sheet-friend')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.tapAt(const Offset(160, 8));
          await tester.pumpAndSettle();
          await openAsyncOpponentSheet(tester);
          expect(
            find.byKey(const ValueKey('opponent-sheet-friend')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
          await tester.tapAt(const Offset(160, 8));
          await tester.pumpAndSettle();
          await openRoomSheet(tester);
          expect(
            find.byKey(const ValueKey('play-hub-create-room')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
