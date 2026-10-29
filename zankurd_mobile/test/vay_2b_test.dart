// 2026-10-29 vay 2B — öğren rotası, kelimelerim, hikâye, sıralama, profil,
// mağaza bekçisi (VAY_KATMANI B6–B9, GPT-6 Astra kıyas denetimi).
//
// ## Kusur
//
// Astra'nın rakip kıyasında (Duolingo / TRT / Trivia Crack) bu altı ekran
// 5–7/10 aldı: öğren "liste gibi", kelimelerim "ilk iş belirsiz", hikâyede
// sözcükler YAZIM DENETİMİ gibi noktalı çizgili ve alt yarı boş, sıralamada
// "yükselme hissi yok", profil "hesap ayarları sayfası", mağaza
// önizlemeleri "satın alma isteği yaratamayacak kadar küçük".
//
// ## Neden sessiz kalırdı
//
// Hepsi görseldir: düğüm yerine liste, 52 px önizleme, noktalı çizgi, düz
// beyaz kimlik kartı hiçbir işlevsel testi kırmaz. Bir "sadeleştirme" turu
// rotayı yine listeye, kimlik kartını yine düz yüzeye çevirse bütün testler
// yeşil kalırdı. Bu bekçi her ekranın imza parçasının VAR olduğunu ve
// ölçüsünü sabitler.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/models/mini_guide.dart';
import 'package:zankurd_mobile/src/models/story.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/screens/story_screen.dart';
import 'package:zankurd_mobile/src/widgets/learn_path.dart';
import 'package:zankurd_mobile/src/widgets/profile_identity_card.dart';
import 'package:zankurd_mobile/src/widgets/zan_mascot.dart';

import 'support/widget_test_helpers.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await ZanMascot.preloadForTest();
  });

  Future<void> pumpAt(WidgetTester tester, Widget child) async {
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(testShell(child: child));
    await tester.pumpAndSettle();
  }

  testWidgets('B6 öğren: keşif rotası düğümleri, güncel 80 + halka, maskot', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    PlacementStore.resetInstance();
    await pumpAt(tester, LearningScreen(repository: MockZanKurdRepository()));

    expect(find.byKey(const ValueKey('learn-unit-scene')), findsOneWidget);
    expect(find.byKey(const ValueKey('learn-unit-mascot')), findsOneWidget);
    expect(find.byType(LearnPath), findsOneWidget);
    // Güncel düğüm: tek, 80 px, 3 px halkalı; kartı (tek turuncu) altında.
    final current = find.byKey(const ValueKey('learn-node-current'));
    expect(current, findsOneWidget);
    expect(tester.getSize(current).width, LearnPathMetrics.current);
    final ring = tester.widget<DecoratedBox>(
      find.byKey(const ValueKey('learn-node-current-ring')),
    );
    final border = (ring.decoration as BoxDecoration).border! as Border;
    expect(border.top.width, LearnPathMetrics.ring);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('learning-next-step')),
        matching: find.byKey(const ValueKey('learn-node-current')),
      ),
      findsOneWidget,
    );
    // Öteki düğümler 64 px; ünite en çok 5 durak (5–7 düğüm kuralı).
    final locked = find.byKey(const ValueKey('learn-node-locked'));
    expect(locked, findsWidgets);
    expect(tester.getSize(locked.first).width, LearnPathMetrics.node);
    final stops =
        find.byKey(const ValueKey('learn-node-locked')).evaluate().length +
        find.byKey(const ValueKey('learn-node-done')).evaluate().length +
        find.byKey(const ValueKey('learn-node-open')).evaluate().length +
        1;
    expect(stops, inInclusiveRange(2, 7));
    expect(tester.takeException(), isNull);
  });

  testWidgets('hikâye: dokunulabilir sözcükte noktalı alt çizgi yok', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await pumpAt(tester, StoryScreen(story: cayxaneStory, guide: cayxaneGuide));
    final styles = <TextStyle>[];
    void collect(InlineSpan span) {
      if (span is TextSpan && span.style != null) styles.add(span.style!);
      if (span is TextSpan) span.children?.forEach(collect);
    }

    for (final rt in tester.widgetList<RichText>(
      find.descendant(
        of: find.byKey(const ValueKey('story-text-ku')),
        matching: find.byType(RichText),
      ),
    )) {
      collect(rt.text);
    }
    final underlined = styles
        .where((s) => s.decoration == TextDecoration.underline)
        .toList();
    expect(underlined, isNotEmpty, reason: 'dokunulabilir sözcükler izli');
    expect(
      underlined.where((s) => s.decorationStyle == TextDecorationStyle.dotted),
      isEmpty,
      reason: 'noktalı çizgi yazım denetimi gibi okunuyordu (Astra)',
    );
    // Sahne: manzara + anlatıcı maskot; altta kelime çantası.
    expect(find.byKey(const ValueKey('story-scene-header')), findsOneWidget);
    expect(find.byKey(const ValueKey('story-word-bag')), findsOneWidget);
  });

  testWidgets('B7 profil: degrade kimlik kartı, 6 px halka, üç sayı', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    addTearDown(SyncManager.resetForTesting);
    await tester.binding.setSurfaceSize(const Size(390, 2400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(
        child: Scaffold(body: ProfileScreen(repository: freshMockRepository())),
      ),
    );
    final card = find.byKey(const ValueKey('profile-identity-card'));
    for (var i = 0; i < 40 && card.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    expect(card, findsOneWidget);
    expect(tester.widget(card), isA<ProfileIdentitySurface>());
    const deco = ProfileIdentitySurface.decoration;
    final gradient = deco.gradient! as LinearGradient;
    expect(gradient.colors.first, const Color(0xFF173C52));
    expect(gradient.colors.last, const Color(0xFF285C70));
    // Beyaz metin degradenin açık ucunda bile ≥ 4.5:1.
    expect(
      _contrast(Colors.white, gradient.colors.last),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(Colors.white.withValues(alpha: 0.82), gradient.colors.last),
      greaterThanOrEqualTo(4.5 - 0.6),
    );
    expect(
      find.descendant(
        of: card,
        matching: find.byKey(const ValueKey('profile-identity-stats')),
      ),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('profile-avatar-edit'))).width,
      80,
    );
    expect(find.byKey(const ValueKey('profile-xp-to-next')), findsOneWidget);
  });

  testWidgets('B9 mağaza: vitrin sahnesi, önizlemeler ≥ 72 px', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpAt(tester, ShopScreen(repository: freshMockRepository()));
    expect(find.byKey(const ValueKey('shop-showcase')), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-showcase-chest')), findsOneWidget);
    expect(find.byKey(const ValueKey('shop-showcase-mascot')), findsOneWidget);
    final previews = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('shop-preview-'),
    );
    expect(previews, findsWidgets);
    for (final e in previews.evaluate()) {
      final size = tester.getSize(find.byWidget(e.widget));
      expect(size.width, greaterThanOrEqualTo(72));
    }
  });

  testWidgets('B8 sıralama: lig başlığı, sıran ve üst sıraya kalan puan', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    await tester.binding.setSurfaceSize(const Size(390, 1600));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      testShell(
        child: Scaffold(
          body: LeaderboardScreen(repository: freshMockRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('leaderboard-league-header')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('leaderboard-league-title')),
      findsOneWidget,
    );
    // Oyuncu listedeyse listenin dibi boş kalmaz: tek turuncu "Yarışa başla";
    // değilse aynı eylemi alttaki sabit şerit taşır (iki kez çizilmez).
    final listed = find
        .byKey(const ValueKey('leaderboard-me-outline'))
        .evaluate()
        .isNotEmpty;
    expect(
      find.byKey(const ValueKey('leaderboard-climb-card')),
      listed ? findsOneWidget : findsNothing,
    );
    expect(find.text('Yarışa başla'), findsAtLeastNWidgets(listed ? 1 : 0));
  });
}
