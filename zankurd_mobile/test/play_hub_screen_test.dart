import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
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
    expect(label.style?.color, Colors.white);
  });

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
    expect(find.text('Özel oda kur ya da bir odaya katıl.'), findsOneWidget);
    expect(find.text('Etkinlikler'), findsOneWidget);
    expect(find.text('Her gün yenilenir.'), findsOneWidget);
    expect(find.byKey(const ValueKey('play-hub-quick-duel')), findsOneWidget);
    expect(find.byKey(const ValueKey('play-hub-create-room')), findsOneWidget);
    expect(find.byKey(const ValueKey('play-hub-join-room')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('play-hub-daily-contest')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('play-hub-tournament')), findsOneWidget);
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
}
