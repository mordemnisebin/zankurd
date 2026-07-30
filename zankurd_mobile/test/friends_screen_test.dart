import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/providers/child_safety_provider.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MockZanKurdRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = MockZanKurdRepository();
  });

  Widget createTestWidget({bool childSafe = false}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider(initialLang: 'tr'),
        ),
        ChangeNotifierProvider<ChildSafetyProvider>(
          create: (_) => ChildSafetyProvider(initialEnabled: childSafe),
        ),
      ],
      child: MaterialApp(home: FriendsScreen(repository: repository)),
    );
  }

  group('FriendsScreen', () {
    testWidgets('arkadaslar ve bekleyen istekler listelenir', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('ZanînBot'), findsOneWidget);
      expect(find.text('KurdBot'), findsOneWidget);
      expect(find.text('Diyar'), findsOneWidget);
      expect(find.text('Kabul'), findsOneWidget);
      expect(find.byIcon(AppIcons.xmark), findsOneWidget);
      expect(
        find.byKey(const ValueKey('friends-search-panel')),
        findsOneWidget,
      );
      // Anahtar arkadaş adını taşır: tek bir sabit anahtar iki satırda da
      // yinelendiği için hangi satırın düğmesine bakıldığı belirsizdi.
      expect(
        find.byKey(const ValueKey('friend-action-ZanînBot')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('friend-action-KurdBot')),
        findsOneWidget,
      );
      // Düğmenin sözü ile işi aynı olmalı: oyun başlatmıyor, oda kurup
      // kodu paylaştırıyor.
      expect(find.text('Odaya çağır'), findsNWidgets(2));
      expect(find.text('Oyna'), findsNothing);
    });

    testWidgets('çocuk modu açıkken arkadaş arama paneli gizlenir', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget(childSafe: true));
      await tester.pumpAndSettle();

      // Arama/yeni istek kapalı.
      expect(find.byKey(const ValueKey('friends-search-panel')), findsNothing);
      // Mevcut arkadaşlar korunur (silinmez).
      expect(find.text('ZanînBot'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('oyuncu arama sonuclari ve ekleme akisi calisir', (
      tester,
    ) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'roj');
      await tester.tap(find.text('Ara'));
      await tester.pumpAndSettle();

      expect(find.text('Rojda'), findsOneWidget);
      expect(find.text('Rojhat'), findsOneWidget);
      expect(find.text('Ekle'), findsNWidgets(2));

      await tester.tap(find.text('Ekle').first);
      await tester.pumpAndSettle();

      // İstek gönderilen oyuncuda buton onay ikonuna dönüşür.
      expect(find.text('Ekle'), findsOneWidget);
      expect(find.byIcon(AppIcons.circleCheck), findsOneWidget);
      expect(find.text('İstek gönderildi'), findsOneWidget);
    });

    testWidgets('istek reddetme akisi calisir', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(AppIcons.xmark));
      await tester.pumpAndSettle();

      expect(find.text('İstek reddedildi'), findsOneWidget);
    });

    testWidgets('kisa aramada uyari gosterilir', (tester) async {
      await tester.pumpWidget(createTestWidget());
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'r');
      await tester.tap(find.text('Ara'));
      await tester.pumpAndSettle();

      expect(find.text('En az 2 harf yaz'), findsOneWidget);
    });
  });
}
