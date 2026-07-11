import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/sound_provider.dart';
import 'package:zankurd_mobile/src/screens/matchmaking_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Eşleştirme iptalinin gerçekten çağrıldığını izleyen sahte depo.
class _TrackingRepository extends MockZanKurdRepository {
  int cancelCalls = 0;

  @override
  Future<void> cancelMatchmaking() async {
    cancelCalls += 1;
  }
}

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
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    XPStore.resetInstance();
  });

  testWidgets('seçim menüsü 1vs1 girişini ve rastgele eşleşmeyi gösterir', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(480, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      _shell(MatchmakingScreen(repository: MockZanKurdRepository())),
    );
    await tester.pumpAndSettle();

    expect(find.text('1vs1 Düello'), findsOneWidget);
    expect(find.text('Rastgele eşleşme'), findsOneWidget);
    final duelCard = tester.widget<Container>(
      find.byKey(const ValueKey('matchmaking-duel-card')),
    );
    final decoration = duelCard.decoration! as BoxDecoration;
    expect(decoration.border, isNotNull);
    expect(decoration.gradient, isNotNull);
    expect(tester.takeException(), isNull);
  });

  testWidgets('ekrandan çıkınca eşleştirme kuyruğu iptal edilir', (
    tester,
  ) async {
    final repository = _TrackingRepository();
    await tester.pumpWidget(_shell(MatchmakingScreen(repository: repository)));
    await tester.pumpAndSettle();

    // Ekranı kaldır: dispose, kuyruğu sunucuda da temizlemeli ki oyuncu
    // hayalet kayıt olarak eşleşme kuyruğunda kalmasın.
    await tester.pumpWidget(_shell(const SizedBox()));
    await tester.pumpAndSettle();

    expect(repository.cancelCalls, 1);
    expect(tester.takeException(), isNull);
  });
}
