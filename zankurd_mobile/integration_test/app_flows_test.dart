// Uçtan uca akış senaryoları (integration_test).
//
// Gerçek cihazda/emülatörde çalıştırma:
//   flutter test integration_test/app_flows_test.dart
//   flutter drive --driver=test_driver/integration_test.dart \
//       --target=integration_test/app_flows_test.dart -d <device>
//
// Bu senaryolar auth gerektirmeyen, cihazdan bağımsız uçtan uca yolları
// (store + servis + ekran) sürer; böylece CI'da ve gerçek cihazda aynı şekilde
// çalışır. Tam onboarding→auth akışı gerçek cihaz smoke testi için README'ye
// bakınız.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/child_safety_provider.dart';
import 'package:zankurd_mobile/src/providers/reduced_motion_provider.dart';
import 'package:zankurd_mobile/src/screens/level_placement_screen.dart';
import 'package:zankurd_mobile/src/services/placement_scoring.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Widget host(Widget child) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
    ],
    child: MaterialApp(theme: AppTheme.dark(), home: child),
  );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlacementStore.resetInstance();
    MistakeStore.resetInstance();
  });

  testWidgets('Senaryo: seviye belirleme sınavı → sonuç → kayıt', (
    tester,
  ) async {
    await tester.pumpWidget(
      host(
        LevelPlacementScreen(
          repository: MockZanKurdRepository(),
          questionCount: 6,
        ),
      ),
    );
    await tester.pumpAndSettle();

    for (var i = 0; i < 6; i++) {
      final state = tester.state(find.byType(LevelPlacementScreen)) as dynamic;
      // ignore: avoid_dynamic_calls
      final current = state.currentQuestionForTest;
      await tester.tap(find.text(current.correctAnswer).last);
      await tester.pumpAndSettle();
    }
    expect(
      find.byKey(const ValueKey('placement-result-level')),
      findsOneWidget,
    );

    final store = await PlacementStore.load();
    expect(store.completed, isTrue);
  });

  testWidgets('Senaryo: akıllı tekrar — yanlış → hazır kuyruk → SM-2 çözüm', (
    tester,
  ) async {
    final store = await MistakeStore.load();
    await store.markMistake('offline_0005', category: 'Ziman');
    // Yeni yanlış +1 gün sonrasına planlanır (henüz hazır değil).
    expect(store.readyCount, 0);

    // Zamanı gelmiş bir yanlışı taklit et (legacy: metadata yok → hazır).
    SharedPreferences.setMockInitialValues({
      'zankurd.mistakeQuestionIds': ['offline_0005'],
    });
    MistakeStore.resetInstance();
    final ready = await MistakeStore.load();
    expect(ready.readyCount, 1);

    // Kolay (5) ile çöz — SM-2 ilerler.
    await ready.markResolvedSM2('offline_0005', 5);
    expect(ready.count, 1); // tek çözümde mastered olmaz
  });

  testWidgets('Senaryo: çocuk modu sosyal/paylaşım kapılarını kilitler', (
    tester,
  ) async {
    final child = await ChildSafetyProvider.load();
    expect(child.allowFriendSearch, isTrue);
    await child.setEnabled(true);
    expect(child.allowFriendSearch, isFalse);
    expect(child.allowRoomChat, isFalse);
    expect(child.allowExternalShare, isFalse);
    // Kapatınca geri gelir (veri kaybı yok).
    await child.setEnabled(false);
    expect(child.allowFriendSearch, isTrue);
  });

  testWidgets('Senaryo: hareket azaltma tercihi kalıcı', (tester) async {
    final motion = await ReducedMotionProvider.load();
    await motion.setUserReduce(true);
    final reloaded = await ReducedMotionProvider.load();
    expect(reloaded.reduceMotion, isTrue);
  });

  testWidgets('Senaryo: çevrimdışı temel öğrenme — soru havuzu erişilir', (
    tester,
  ) async {
    final repo = MockZanKurdRepository();
    final selected = PlacementScoring.selectQuestions(repo.questions, count: 5);
    expect(selected, isNotEmpty);
  });
}
