import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/main.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/providers/child_safety_provider.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';

import 'support/widget_test_helpers.dart';

/// 2026-08-14 denetimi: `ChildSafetyProvider` yazılmıştı ama hiçbir yere
/// bağlanmamıştı.
///
/// ## Kusur
///
/// 1. Widget ağacında hiç `ChangeNotifierProvider<ChildSafetyProvider>`
///    yoktu — `ZanKurdApp`in `MultiProvider` listesi onu içermiyordu.
/// 2. Hiçbir ekran `allowFriendSearch`/`allowExternalShare`i okumuyordu —
///    anahtar açık ya da kapalı, davranış birebir aynıydı.
/// 3. `settings_screen.dart`ta "Çocuk modunu değiştirir..." diye başlayan
///    bir doc yorumu duruyordu ama altındaki gövde hiç yazılmamıştı;
///    yorum bir sonraki fonksiyonun (`_openPlacement`) üstünde asılı
///    kalmıştı.
Future<void> _scrollToChildSafetySwitch(WidgetTester tester) async {
  await tester.scrollUntilVisible(
    find.byKey(const ValueKey('child-safety-switch')),
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await tester.pumpAndSettle();
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets(
    'ZanKurdApp gerçek sağlayıcı ağacında ChildSafetyProvider taşır',
    (tester) async {
      // Sağlayıcı gerçekten ağaçtaysa, onu okuyan herhangi bir alt widget
      // `ProviderNotFoundException` fırlatmadan çalışır. Doğrudan
      // `main.dart` giriş widget'ı (`ZanKurdApp`) kullanılıyor — sahte bir
      // alt küme değil, üretimdeki gerçek sağlayıcı ağacı.
      await tester.pumpWidget(
        ZanKurdApp(repository: MockZanKurdRepository()),
      );
      await tester.pump(const Duration(milliseconds: 50));

      final context = tester.element(find.byType(MaterialApp));
      expect(
        () => Provider.of<ChildSafetyProvider>(context, listen: false),
        returnsNormally,
      );
    },
  );

  group('Ayarlar — çocuk modu anahtarı', () {
    testWidgets('anahtar mevcuttur ve varsayılan kapalıdır', (tester) async {
      final repository = freshMockRepository();
      await tester.pumpWidget(
        testShell(child: SettingsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await _scrollToChildSafetySwitch(tester);

      final toggle = tester.widget<Switch>(
        find.byKey(const ValueKey('child-safety-switch')),
      );
      expect(toggle.value, isFalse);
    });

    testWidgets('açmak onay ister; vazgeçilirse kapalı kalır', (
      tester,
    ) async {
      final repository = freshMockRepository();
      await tester.pumpWidget(
        testShell(child: SettingsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await _scrollToChildSafetySwitch(tester);

      await tester.tap(find.byKey(const ValueKey('child-safety-switch')));
      await tester.pumpAndSettle();

      expect(find.text('Çocuk modu açılsın mı?'), findsOneWidget);

      await tester.tap(find.text('Vazgeç'));
      await tester.pumpAndSettle();

      final toggle = tester.widget<Switch>(
        find.byKey(const ValueKey('child-safety-switch')),
      );
      expect(toggle.value, isFalse);
    });

    testWidgets('onaylanınca sağlayıcı güncellenir', (tester) async {
      final repository = freshMockRepository();
      await tester.pumpWidget(
        testShell(child: SettingsScreen(repository: repository)),
      );
      await tester.pumpAndSettle();
      await _scrollToChildSafetySwitch(tester);

      await tester.tap(find.byKey(const ValueKey('child-safety-switch')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Devam Et'));
      await tester.pumpAndSettle();

      final toggle = tester.widget<Switch>(
        find.byKey(const ValueKey('child-safety-switch')),
      );
      expect(toggle.value, isTrue);

      final context = tester.element(find.byType(SettingsScreen));
      expect(
        Provider.of<ChildSafetyProvider>(context, listen: false).enabled,
        isTrue,
      );
    });

    testWidgets('kapatmak onay istemez', (tester) async {
      final repository = freshMockRepository();
      final provider = ChildSafetyProvider(initialEnabled: true);
      await tester.pumpWidget(
        testShell(
          child: SettingsScreen(repository: repository),
          childSafetyProvider: provider,
        ),
      );
      await tester.pumpAndSettle();
      await _scrollToChildSafetySwitch(tester);

      await tester.tap(find.byKey(const ValueKey('child-safety-switch')));
      await tester.pumpAndSettle();

      expect(find.text('Çocuk modu açılsın mı?'), findsNothing);
      expect(provider.enabled, isFalse);
    });
  });

  group('Arkadaşlar — arama kapısı', () {
    testWidgets('çocuk modu kapalıyken arama kutusu görünür', (tester) async {
      await tester.pumpWidget(
        testShell(
          child: FriendsScreen(repository: MockZanKurdRepository()),
          childSafetyProvider: ChildSafetyProvider(),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('friends-search-panel')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('friends-search-blocked')),
        findsNothing,
      );
    });

    testWidgets('çocuk modu açıkken arama kutusu gizlenir', (tester) async {
      await tester.pumpWidget(
        testShell(
          child: FriendsScreen(repository: MockZanKurdRepository()),
          childSafetyProvider: ChildSafetyProvider(initialEnabled: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('friends-search-panel')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('friends-search-blocked')),
        findsOneWidget,
      );
    });
  });

  group('Sonuç ekranı — dışa paylaşım kapısı', () {
    QuizResultScreen buildScreen(MockZanKurdRepository repository) {
      return QuizResultScreen(
        repository: repository,
        room: repository.createRoom(),
        score: 500,
        correctCount: 5,
        wrongCount: 0,
        totalQuestions: 5,
        bestStreak: 5,
        coinsAwarded: 50,
        answerRecords: const [
          AnswerRecord(
            id: 'q1',
            category: 'Ziman',
            prompt: 'p',
            answers: ['a', 'b'],
            correctAnswer: 'a',
            selectedAnswer: 'a',
            explanation: 'e',
          ),
        ],
      );
    }

    testWidgets('çocuk modu kapalıyken paylaş düğmesi görünür', (
      tester,
    ) async {
      await tester.pumpWidget(
        testShell(
          child: buildScreen(MockZanKurdRepository()),
          childSafetyProvider: ChildSafetyProvider(),
        ),
      );
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('result-share-button')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('result-share-button')),
        findsOneWidget,
      );
    });

    testWidgets('çocuk modu açıkken paylaş düğmesi hiç çizilmez', (
      tester,
    ) async {
      await tester.pumpWidget(
        testShell(
          child: buildScreen(MockZanKurdRepository()),
          childSafetyProvider: ChildSafetyProvider(initialEnabled: true),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('result-share-button')), findsNothing);
    });
  });
}
