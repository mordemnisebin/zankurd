import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/config/feature_flags.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

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
  testWidgets('hızlı düello yeşil kimlik içinde turuncu ana eylem kullanır', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(PlayHubScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final hero = find.byKey(const ValueKey('play-hub-quick-duel'));
    final heroInk = tester.widget<Ink>(
      find.descendant(of: hero, matching: find.byType(Ink)).first,
    );
    final heroDecoration = heroInk.decoration as BoxDecoration;
    expect(heroDecoration.gradient, isNull);
    expect(heroDecoration.color, AppTheme.culturalBrandBg);

    final action = tester.widget<Container>(
      find
          .ancestor(
            of: find.text('Rakip bul'),
            matching: find.byType(Container),
          )
          .first,
    );
    final decoration = action.decoration as BoxDecoration;
    expect(
      decoration.color,
      AppTheme.primaryCtaColor(tester.element(find.text('Rakip bul'))),
    );
    final label = tester.widget<Text>(find.text('Rakip bul'));
    expect(
      label.style?.color,
      AppColors.onSolid(
        AppTheme.primaryCtaColor(tester.element(find.text('Rakip bul'))),
      ),
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

    expect(find.text('Oda Kur'), findsOneWidget);
    expect(find.text('Kodla Katıl'), findsOneWidget);
    expect(find.text('Arkadaşlarınla'), findsOneWidget);
    expect(
      find.text('Oda kur, bağlantıyı arkadaşlarınla paylaş.'),
      findsOneWidget,
    );
    expect(find.text('Etkinlikler'), findsOneWidget);
    expect(find.text('Her gün yenilenir.'), findsOneWidget);
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

  testWidgets('oda kur ve kodla katıl normal telefonda aynı satırdadır', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      _shell(PlayHubScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    final create = tester.getRect(
      find.byKey(const ValueKey('play-hub-create-room')),
    );
    final join = tester.getRect(
      find.byKey(const ValueKey('play-hub-join-room')),
    );
    expect((create.center.dy - join.center.dy).abs(), lessThan(1));
    expect(join.left, greaterThan(create.right));
    expect(create.height, lessThanOrEqualTo(110));
    expect(join.height, lessThanOrEqualTo(110));
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
            of: find.byType(ListView),
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
