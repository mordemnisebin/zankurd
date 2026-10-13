import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/story_progress_store.dart';
import 'package:zankurd_mobile/src/models/story.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/story_catalog.dart';

// 2026-09-29 doğallık (K7): satırlardaki kitap ikonu karosu, "Başla" durum
// sözü ve chevron kalktı; sağda yalnız ilerleme (bitti ✓, yarım "Devam et").
// "Başla"yı ve chevron rengini sabitleyen beklentiler buna göre değişti;
// ekran okuyucu etiketi ("…. Başla") aynı kalır.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    StoryProgressStore.resetInstance();
  });

  testWidgets('katalog dört hikâyeyi gösterir; başlanmamışta söz ve ok yok', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StoryCatalog(isKu: false, onOpen: (_, _) async {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('story-catalog')), findsOneWidget);
    for (final story in everydayStories) {
      expect(find.byKey(ValueKey('story-card-${story.id}')), findsOneWidget);
    }
    expect(find.text('Başla'), findsNothing);
    expect(find.byIcon(AppIcons.chevronRight), findsNothing);
    expect(find.byIcon(AppIcons.bookOpenReader), findsNothing);
  });

  testWidgets('hikâye kartı ekran okuyucuda tek kez duyurulur', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StoryCatalog(isKu: false, onOpen: (_, _) async {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstStory = everydayStories.first;
    final card = find.byKey(ValueKey('story-card-${firstStory.id}'));
    expect(
      tester.getSemantics(card).getSemanticsData().label,
      '${firstStory.titleTr}. Başla',
    );
    expect(
      find.bySemanticsLabel(RegExp('^${RegExp.escape(firstStory.titleTr)}')),
      findsOneWidget,
    );
    semantics.dispose();
  });

  testWidgets('katalog kayıtlı hikâyeyi devam, bitişi tamamlandı gösterir', (
    tester,
  ) async {
    final store = await StoryProgressStore.load();
    await store.saveNode('cayxane', 'tea');
    await store.saveNode('xwe-nasandin', 'end_friend');

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StoryCatalog(isKu: false, onOpen: (_, _) async {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Devam et'), findsOneWidget);
    // Biten hikâye ✓ ile işaretlenir; söz ekran okuyucu etiketinde kalır.
    expect(find.text('Tamamlandı'), findsNothing);
    final done = find.byKey(const ValueKey('story-card-xwe-nasandin'));
    expect(
      find.descendant(of: done, matching: find.byIcon(AppIcons.check)),
      findsOneWidget,
    );
    expect(tester.getSemantics(done).label, endsWith('. Tamamlandı'));
    expect(find.text('Başla'), findsNothing);
  });

  // 2026-09-29 Şahnê: aksan rengi hesaplanmıyor, belirteçten geliyor —
  // ilerleme sözü ve ✓ öğrenme rolünün okunur metni (`learnTx`); iki
  // temada AA geçer.
  testWidgets('koyu temada hikâye aksanları okunabilir tona uyarlanır', (
    tester,
  ) async {
    final store = await StoryProgressStore.load();
    await store.saveNode('cayxane', 'tea');
    await store.saveNode('xwe-nasandin', 'end_friend');
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: Scaffold(
          body: StoryCatalog(isKu: false, onOpen: (_, _) async {}),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final statusFinder = find.text('Devam et');
    final status = tester.widget<Text>(statusFinder);
    final t = SahneTokens.of(tester.element(statusFinder));
    expect(status.style?.color, t.learnTx);

    final check = tester.widget<Icon>(find.byIcon(AppIcons.check));
    expect(check.color, t.learnTx);
  });

  testWidgets('kompakt hikâyeler kart değil sahne şeridi olarak çizilir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StoryCatalog(
            isKu: false,
            compact: true,
            onOpen: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final firstStory = everydayStories.first;
    final strip = find.byKey(ValueKey('story-scene-strip-${firstStory.id}'));
    expect(strip, findsOneWidget);
    final material = tester.widget<Material>(strip);
    expect(material.color, Colors.transparent);
    expect(material.shape, isNull);
  });

  testWidgets('kompakt katalog yüzde 200 metinde taşmaz', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: MediaQuery(
          data: const MediaQueryData(textScaler: TextScaler.linear(2)),
          child: Scaffold(
            body: StoryCatalog(
              isKu: false,
              compact: true,
              onOpen: (_, _) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('story-card-cayxane'))).height,
      lessThanOrEqualTo(72),
    );
  });
}
