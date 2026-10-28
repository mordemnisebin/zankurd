import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/story_progress_store.dart';
import 'package:zankurd_mobile/src/models/mini_guide.dart';
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

  testWidgets(
    'katalog bütün hikâyeleri gösterir; her satırda sağ ok, başlanmamışta söz yok',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SingleChildScrollView(
              child: StoryCatalog(isKu: false, onOpen: (_, _) async {}),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byKey(const ValueKey('story-catalog')), findsOneWidget);
      for (final story in everydayStories) {
        expect(find.byKey(ValueKey('story-card-${story.id}')), findsOneWidget);
      }
      expect(find.text('Başla'), findsNothing);
      // W3 (2026-10-28 tur 5): her hikâye satırı dokunulur olduğunu sağ okla
      // söyler (satırın sağı boştu); başlanmamışta "Başla" sözü yine yok.
      expect(
        find.byIcon(AppIcons.chevronRight),
        findsNWidgets(everydayStories.length),
      );
      expect(find.byIcon(AppIcons.bookOpenReader), findsNothing);
    },
  );

  testWidgets('hikâye kartı ekran okuyucuda tek kez duyurulur', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: StoryCatalog(isKu: false, onOpen: (_, _) async {}),
          ),
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
          body: SingleChildScrollView(
            child: StoryCatalog(isKu: false, onOpen: (_, _) async {}),
          ),
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
          body: SingleChildScrollView(
            child: StoryCatalog(isKu: false, onOpen: (_, _) async {}),
          ),
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

  // Yeniden oyna katalogdaki ✓'yi silmemeli (eskiden anahtar silinirdi);
  // yeniden başlatılmış ama hiç bitirilmemiş hikâye de "Devam et" dememeli.
  testWidgets('yeniden başlatma ✓ işaretini silmez, bitmemişte devam yazmaz', (
    tester,
  ) async {
    final first = everydayStories.first;
    final second = everydayStories[1];
    final store = await StoryProgressStore.load();
    await store.saveNode(first.id, 'x');
    await store.markCompleted(first.id);
    await store.restart(first.id, first.start.id);
    await store.saveNode(second.id, 'x');
    await store.restart(second.id, second.start.id);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: StoryCatalog(isKu: false, onOpen: (_, _) async {}),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.byKey(ValueKey('story-card-${first.id}')),
        matching: find.byIcon(AppIcons.check),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byKey(ValueKey('story-card-${second.id}')),
        matching: find.text('Devam et'),
      ),
      findsNothing,
    );
  });

  // 2026-10-27: hikâye sayısı artınca öğrenme sayfası en çok [limit] satır
  // gösterir (yarım kalan önce) ve "Tüm hikâyeler (N)" satırı açar.
  testWidgets('sınırlı katalog yarım kalanı öne alır ve tümünü açar', (
    tester,
  ) async {
    final last = everydayStories.last;
    final store = await StoryProgressStore.load();
    final firstChoice = last.start.choices.first.nextNodeId;
    await store.saveNode(last.id, firstChoice);
    var showAll = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StoryCatalog(
            isKu: false,
            limit: 2,
            onShowAll: () async => showAll++,
            onOpen: (_, _) async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final cards = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('story-card-'),
    );
    expect(cards, findsNWidgets(2));
    expect(find.byKey(ValueKey('story-card-${last.id}')), findsOneWidget);
    final all = find.byKey(const ValueKey('story-catalog-all'));
    expect(
      find.text('Tüm hikâyeler (${everydayStories.length})'),
      findsOneWidget,
    );
    await tester.tap(all);
    await tester.pumpAndSettle();
    expect(showAll, 1);
  });

  testWidgets('rehberi olmayan hikâye de açılır', (tester) async {
    final withoutGuide = everydayStories.firstWhere(
      (story) => everydayGuides[story.id] == null,
      orElse: () => everydayStories.first,
    );
    Story? opened;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: SingleChildScrollView(
            child: StoryCatalog(
              isKu: false,
              onOpen: (story, _) async => opened = story,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(ValueKey('story-card-${withoutGuide.id}')));
    await tester.pumpAndSettle();
    expect(opened?.id, withoutGuide.id);
  });
}
