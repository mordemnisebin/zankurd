// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
// 2026-09-29 doğallık (K5, K7): düello kartında VS amblemi yok (yerine
// "10 soru · ~2 dakika"); "Oda kur" ve "Kodla katıl" liste grubu değil yan
// yana iki ikincil düğme. Bekçiler yeni düzeni ve TEK Agir kuralını sorar.
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
    final card = tester.widget<SahneStageCard>(
      find.descendant(of: hero, matching: find.byType(SahneStageCard)),
    );
    expect(card.role, SahneRole.race);
    expect(
      find.descendant(of: hero, matching: find.byType(SahneVsEmblem)),
      findsNothing,
    );
    expect(
      find.descendant(of: hero, matching: find.text('10 soru · ~2 dakika')),
      findsOneWidget,
    );
    // Tek Agir düğme kartta; ekrandaki öteki dolgulu düğmeler (oda
    // eylemleri) ikincildir: Kulis tonu.
    expect(
      find.descendant(of: hero, matching: find.byType(FilledButton)),
      findsOneWidget,
    );
    final night = SahneTokens.of(tester.element(hero));
    final outside = find.byWidgetPredicate(
      (w) =>
          w is FilledButton &&
          w.style?.backgroundColor?.resolve(<WidgetState>{}) == night.s2,
    );
    expect(outside, findsNWidgets(2));
    final ctx = tester.element(find.text('Rakip bul'));
    final label = tester.widget<Text>(find.text('Rakip bul'));
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
    expect(heroData.label, 'Hızlı düello. Rakip bul');
    final action = find.byKey(const ValueKey('play-hub-quick-duel-cta'));
    expect(action, findsOneWidget);
    expect(tester.getSize(action).height, greaterThanOrEqualTo(48));
    semantics.dispose();
  });

  // "Daha fazla" yalnız turnuva bayrağı açıkken çizilir (kTournamentEnabled).
  testWidgets(
    'daha fazla eylemi ekran okuyucuda tek kez duyurulur',
    skip: !kTournamentEnabled,
    (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await tester.pumpWidget(
        _shell(PlayHubScreen(repository: MockZanKurdRepository())),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(find.byKey(const ValueKey('play-hub-more')));
      await tester.pumpAndSettle();

      expect(find.bySemanticsLabel(RegExp(r'^Daha fazla')), findsOneWidget);
      semantics.dispose();
    },
  );

  testWidgets('oyun merkezi Pirs kapsamındaki ana yolları görünür kılar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(PlayHubScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Oda kur'), findsOneWidget);
    expect(find.text('Kodla katıl'), findsOneWidget);
    // 2026-09-29 Şahnê: bölümler tek bölüm başlığıyla (`SahneSectionHeader`)
    // açılır; başlık altı açıklama satırı yok (maket).
    expect(find.text('Arkadaşlarınla'), findsOneWidget);
    expect(find.text('Her gün'), findsOneWidget);
    expect(find.byType(SahneSectionHeader), findsNWidgets(2));
    expect(find.byKey(const ValueKey('play-hub-quick-duel')), findsOneWidget);
    expect(find.byKey(const ValueKey('play-hub-create-room')), findsOneWidget);
    expect(find.byKey(const ValueKey('play-hub-join-room')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('play-hub-daily-contest')),
      findsOneWidget,
    );
    // Turnuva kalabalık bir kitle bekliyor; 2026-09-27'den beri bayrakla
    // kapalı. Kapalıyken onu açan "Daha fazla" katmanı da çizilmez.
    expect(find.byKey(const ValueKey('play-hub-tournament')), findsNothing);
    if (kTournamentEnabled) {
      expect(find.byKey(const ValueKey('play-hub-more')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('play-hub-more')));
      await tester.tap(find.byKey(const ValueKey('play-hub-more')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('play-hub-tournament')), findsOneWidget);
    } else {
      expect(find.byKey(const ValueKey('play-hub-more')), findsNothing);
    }
    expect(find.byKey(const ValueKey('play-hub-shop-card')), findsNothing);
    expect(find.text('Turnuva ve sıralama'), findsNothing);
    final quickDuelTop = tester
        .getTopLeft(find.byKey(const ValueKey('play-hub-quick-duel')))
        .dy;
    final roomTop = tester
        .getTopLeft(find.byKey(const ValueKey('play-hub-create-room')))
        .dy;
    final eventTop = tester
        .getTopLeft(find.byKey(const ValueKey('play-hub-daily-contest')))
        .dy;
    expect(quickDuelTop, lessThan(roomTop));
    expect(roomTop, lessThan(eventTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets('oda kur ve kodla katıl yan yana iki ikincil düğme', (
    tester,
  ) async {
    // 2026-09-29 doğallık (K7): iki satırlık liste grubu (ikon karosu +
    // alt satır + ok) yerine tek açıklama satırı ve yan yana iki ikincil
    // düğme; ikisi de ≥ 48 dokunma hedefi ve aynı yükseklikte.
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(PlayHubScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final createFinder = find.byKey(const ValueKey('play-hub-create-room'));
    final joinFinder = find.byKey(const ValueKey('play-hub-join-room'));
    final create = tester.getRect(createFinder);
    final join = tester.getRect(joinFinder);
    expect(create.top, join.top);
    expect(join.left, greaterThan(create.right));
    expect(create.height, greaterThanOrEqualTo(48));
    expect(create.height, join.height);
    expect(
      find.ancestor(of: createFinder, matching: find.byType(SahneListGroup)),
      findsNothing,
    );
    expect(find.text('Arkadaşlarını kodla çağır'), findsOneWidget);
  });

  testWidgets('%200 metinde oda eylemleri güvenli biçimde alt alta döner', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(
        MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: PlayHubScreen(repository: MockZanKurdRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // %200 metinde üst hero daha uzun olduğu için ListView bu çocukları
    // ilk karede henüz kurmayabilir; gerçek kullanıcı gibi aşağı kaydır.
    // Sabit bir mesafe değil "görünene dek": hero'nun altına bir kart
    // (ör. sırayla düello) eklenince sabit -600 oda eylemlerini hiç
    // kurmuyordu ve test, düzenden değil mesafeden kırılıyordu.
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('play-hub-join-room')),
      200,
      scrollable: find
          .descendant(
            of: find.byType(SahneTabPage),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.pumpAndSettle();

    final create = tester.getRect(
      find.byKey(const ValueKey('play-hub-create-room')),
    );
    final join = tester.getRect(
      find.byKey(const ValueKey('play-hub-join-room')),
    );
    expect(join.top, greaterThan(create.bottom));
    expect(tester.takeException(), isNull);
  });
}
