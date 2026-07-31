import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/learn_home_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';

import 'support/widget_test_helpers.dart';

/// AppShell açılış sekmesi ve lazy-mount bekçisi.
///
/// Niçin var: 2026-07-31 yayın denetiminde (ZKR-P0-001) commit edilmemiş bir
/// değişiklik açılış sekmesini Öğren(0)'den Yarış(1)'e çekmiş, `_visitedTabs`
/// de `{0, 1}` yapılmıştı. Sonuç iki katmanlıydı:
///
///   1. Kullanıcı yanlış sekmede karşılanıyordu.
///   2. PlayHubScreen, kullanıcı Yarış'a hiç dokunmadan kuruluyordu — yani
///      "pahalı sekmeyi ilk ziyarete ertele" kazancı sessizce kayboluyordu.
///      Bu ikincisi hiçbir ekranda görünmez; yalnız bir testle yakalanır.
///
/// O sırada bu değişikliği yakalayan altı testin beşi, açılışta `HomeScreen`
/// ya da Türkçe bir karşılama metni arayan *dolaylı* testlerdi; altıncısı ise
/// `app_shell.dart` kaynağında birebir `final Set<int> _visitedTabs = {0};`
/// dizesini arıyordu. İkisi de niyeti değil, niyetin izini ölçüyor: biri dile,
/// diğeri kaynak biçimlendirmesine bağlı. Bu dosya aynı sözleşmeyi doğrudan
/// davranışla — seçili sekme indeksi, hangi ekranın ağaçta olduğu ve sekme
/// dokunuşunun ne yaptığıyla — ölçer ve çevrilmiş metne hiç bakmaz.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Sekme hedefleri dile bağımlı etiketle değil, `app_shell.dart` içinde
  /// tanımlı sabit anahtarlarla bulunur.
  const learnTabKey = ValueKey('nav-learn');
  const playTabKey = ValueKey('nav-play');

  Future<void> pumpShell(WidgetTester tester) async {
    final repository = freshMockRepository();
    await tester.pumpWidget(
      testShell(
        child: AppShell(
          repository: repository,
          // Gerçek eklenti yerine sabit monitör: bu testin konusu bağlantı
          // değil, sekme davranışı.
          connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  /// Kullanıcıya o an hangi sekmenin gösterildiği. `IndexedStack.index`
  /// ekranın gerçekten çizilen çocuğudur — seçili sekmenin tek doğru kaynağı.
  int? visibleTabIndex(WidgetTester tester) =>
      tester.widget<IndexedStack>(find.byType(IndexedStack)).index;

  group('dar ekran (alt gezinme çubuğu)', () {
    Future<void> pumpPhone(WidgetTester tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpShell(tester);
    }

    testWidgets('açılışta seçili sekme Öğren (index 0)', (tester) async {
      await pumpPhone(tester);

      expect(visibleTabIndex(tester), 0);
      expect(
        tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
        0,
      );
    });

    testWidgets('açılışta Öğren ekranı kullanıcıya görünür', (tester) async {
      await pumpPhone(tester);

      expect(find.byType(LearnHomeScreen), findsOneWidget);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('açılışta PlayHubScreen hiç kurulmaz (lazy mount)', (
      tester,
    ) async {
      await pumpPhone(tester);

      // `skipOffstage: false`: "çizilmiyor" ile "hiç kurulmamış" farkını
      // ayırt etmek şart. Ziyaret edilmemiş sekme için `_buildTab`
      // `SizedBox.shrink()` döndürdüğü için widget ağaçta HİÇ olmamalı.
      expect(find.byType(PlayHubScreen, skipOffstage: false), findsNothing);
    });

    testWidgets('Yarış sekmesine dokununca PlayHubScreen açılır', (
      tester,
    ) async {
      await pumpPhone(tester);

      await tester.tap(find.byKey(playTabKey));
      await tester.pumpAndSettle();

      expect(visibleTabIndex(tester), 1);
      expect(find.byType(PlayHubScreen), findsOneWidget);
    });

    testWidgets('Öğren sekmesine geri dönülebilir', (tester) async {
      await pumpPhone(tester);

      await tester.tap(find.byKey(playTabKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(learnTabKey));
      await tester.pumpAndSettle();

      expect(visibleTabIndex(tester), 0);
      expect(find.byType(HomeScreen), findsOneWidget);
    });

    testWidgets('ziyaret edilen Yarış sekmesi geri dönüşte ağaçta kalır', (
      tester,
    ) async {
      await pumpPhone(tester);

      await tester.tap(find.byKey(playTabKey));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(learnTabKey));
      await tester.pumpAndSettle();

      // Lazy-mount'ın diğer yarısı: bir kez ziyaret edilen sekme yeniden
      // kurulmaz, IndexedStack içinde durumuyla birlikte saklanır. Aksi
      // halde her sekme geçişi ekranı baştan kurar ve durum kaybolur.
      expect(visibleTabIndex(tester), 0);
      expect(find.byType(PlayHubScreen, skipOffstage: false), findsOneWidget);
    });
  });

  group('geniş ekran (navigation rail)', () {
    testWidgets('açılışta rail seçili indeksi 0 ve PlayHub kurulmaz', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(1024, 768));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pumpShell(tester);

      expect(find.byType(NavigationRail), findsOneWidget);
      expect(
        tester
            .widget<NavigationRail>(find.byType(NavigationRail))
            .selectedIndex,
        0,
      );
      expect(visibleTabIndex(tester), 0);
      expect(find.byType(HomeScreen), findsOneWidget);
      expect(find.byType(PlayHubScreen, skipOffstage: false), findsNothing);
    });
  });
}
