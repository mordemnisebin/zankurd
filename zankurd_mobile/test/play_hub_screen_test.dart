import 'dart:io';

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
    expect(find.text('Arkadaşınla veya grupla oyna'), findsOneWidget);
    expect(find.text('Bir yarış seç'), findsOneWidget);
    expect(find.text('Mağaza ve jokerler'), findsOneWidget);
    expect(
      find.text('Coin, çark ve joker hakların tek yerde.'),
      findsOneWidget,
    );
    expect(find.text('Turnuva ve sıralama'), findsNothing);
    final source = File(
      'lib/src/screens/play_hub_screen.dart',
    ).readAsStringSync();
    expect(
      source.indexOf('QuickPlayGrid('),
      lessThan(source.indexOf('_GroupPlayPanel(')),
    );
    final supportCard = tester.getSize(
      find.byKey(const ValueKey('play-hub-shop-card')),
    );
    expect(supportCard.height, lessThan(100));
    expect(tester.takeException(), isNull);
  });
}
