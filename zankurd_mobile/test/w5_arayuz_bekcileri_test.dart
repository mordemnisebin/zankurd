import 'dart:async';
import 'dart:math' as math;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/services/tts_service.dart';
import 'support/widget_test_helpers.dart';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/leaderboard_podium.dart';
import 'package:zankurd_mobile/src/widgets/lobby_chat_hud.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

/// 2.1.2 W5 arayüz bekçileri (ChatGPT Pro denetimi 2026-11-05, alan 5).
///
/// Her test, denetimde bulunan kusurun NİÇİN sessiz kaldığını da yazar:
/// ortak neden, bu kusurların görsel olarak "çalışıyor" görünmesi ve yalnız
/// ekran okuyucu / büyük yazı / dar ekranda ortaya çıkmasıdır.
double _ratio(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  return (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);
}

Widget _host(Widget child, {ThemeData? theme, double textScale = 1.0}) =>
    MaterialApp(
      theme: theme ?? AppTheme.dark(),
      home: MediaQuery(
        data: MediaQueryData(
          size: const Size(390, 844),
          textScaler: TextScaler.linear(textScale),
        ),
        child: Scaffold(body: Center(child: child)),
      ),
    );

void main() {
  group('1.9 SahneButton yüklenirken ekran okuyucuya pasif', () {
    // Kusur: yükleme sırasında dokunuş boş işleve gidiyor ama Material
    // düğmesi "etkin düğme" kalıyordu. Görsel olarak göstergenin dönmesi
    // yeterli görünür; yalnız VoiceOver "etkin" okurdu.
    testWidgets('loading: true → semantics enabled=false', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _host(
          SahneButton.primary(
            label: 'Bidomîne',
            loading: true,
            onPressed: () {},
          ),
        ),
      );
      expect(
        tester.getSemantics(find.byType(SahneButton)),
        matchesSemantics(
          label: 'Bidomîne',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      handle.dispose();
    });
  });

  group('1.3 sonuç alt perdesi yüklenirken pasif', () {
    testWidgets('birincil eylem loading → semantics pasif ve dokunuşsuz', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      var taps = 0;
      await tester.pumpWidget(
        _host(
          SahneResultDock(
            primary: SahneResultAction(
              label: 'Parve bike',
              loading: true,
              onPressed: () => taps++,
            ),
          ),
        ),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Parve bike')),
        matchesSemantics(
          label: 'Parve bike',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
        reason: 'VoiceOver "etkin düğme" okuyup hiçbir şey olmamalı',
      );
      await tester.tap(find.byType(SahneResultDock), warnIfMissed: false);
      expect(taps, 0);
      handle.dispose();
    });
  });

  group('2.2 simgeli alt perde büyük yazıda dikeye geçer', () {
    // Kusur: geçiş yalnız simgesiz ikincil içindi; simgeli dal 56'lık
    // simgeleri satırda tutup birincil etiketi dar sütuna sıkıştırıyordu.
    // Normal ölçekte düzen aynı göründüğü için fark edilmedi.
    testWidgets('ölçek 2,0: simge düğmesi birincilin ALTINDA', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(320, 640);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          SahneResultDock(
            primary: SahneResultAction(
              key: const ValueKey('p'),
              label: 'Dîsa bilîze',
              onPressed: () {},
            ),
            secondary: SahneResultAction(
              key: const ValueKey('s'),
              label: 'Parve bike',
              icon: Icons.share,
              iconOnly: true,
              onPressed: () {},
            ),
          ),
          textScale: 2.0,
        ),
      );
      expect(tester.takeException(), isNull);
      expect(
        tester.getTopLeft(find.byKey(const ValueKey('s'))).dy,
        greaterThanOrEqualTo(
          tester.getBottomLeft(find.byKey(const ValueKey('p'))).dy,
        ),
      );
    });
  });

  group('1.5 alınamayan joker metni AA kontrastında', () {
    // Kusur: alfa %40 metin pasif dolgu üstünde karanlıkta 3,35:1,
    // aydınlıkta 2,47:1 veriyordu. Görsel "soluk = pasif" niyetine uyduğu
    // için kimse ölçmedi; `contrast_policy_test` bu durumu kapsamıyordu.
    for (final dark in [true, false]) {
      testWidgets('${dark ? 'karanlık' : 'aydınlık'} tema', (tester) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(390, 844);
        addTearDown(tester.view.reset);
        late SahneTokens tokens;
        await tester.pumpWidget(
          MaterialApp(
            theme: dark ? AppTheme.dark() : AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) {
                  tokens = SahneTokens.of(context);
                  return Center(
                    child: SahneJokerButton(
                      icon: Icons.star,
                      label: 'Nîv bi Nîv',
                      price: 50,
                      unaffordable: true,
                      onPressed: () {},
                    ),
                  );
                },
              ),
            ),
          ),
        );
        final name = tester.widget<Text>(
          find.byKey(const ValueKey('joker-name')),
        );
        final color = name.style!.color!;
        expect(color.a, 1.0, reason: 'alfa ile soluklaştırma geri gelmesin');
        expect(
          _ratio(color, tokens.disabledFill),
          greaterThanOrEqualTo(4.5),
          reason: 'etiket pasif dolgu üstünde okunmalı',
        );
      });
    }
  });

  group('1.4 joker adı büyük yazıda büyür (sınırlı)', () {
    // Kusur: ad `TextScaler.noScaling` ile 14 pt'e sabitti; yazıyı
    // %200-300 büyüten oyuncu jokerlerin adını hiç büyümeden görüyordu.
    testWidgets('ölçek 2,0: ad ölçeği 1,0 değil, 1,3 tavanlı', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          SahneJokerButton(
            icon: Icons.star,
            label: 'Nîv bi Nîv',
            price: 50,
            onPressed: () {},
          ),
          textScale: 2.0,
        ),
      );
      final name = tester.widget<Text>(
        find.byKey(const ValueKey('joker-name')),
      );
      expect(name.textScaler, isNot(TextScaler.noScaling));
      expect(name.textScaler!.scale(14), closeTo(14 * 1.3, 0.01));
    });
  });

  group('1.7 podyum ekran okuyucu sırası 1 · 2 · 3', () {
    // Kusur: görsel sıra 2·1·3, anlam sırası yalnız yorumdaydı; `sortKey`
    // yoktu, VoiceOver ikinciyi birinciden önce okurdu.
    testWidgets('rank sırasına göre OrdinalSortKey', (tester) async {
      LeaderboardEntry e(int r) => LeaderboardEntry(
        rank: r,
        playerId: 'p$r',
        displayName: 'Oyuncu $r',
        totalScore: 100 - r,
        bestStreak: 1,
        roomsPlayed: 1,
      );
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        _host(
          LeaderboardPodium(
            entries: [e(1), e(2), e(3)],
            isKu: false,
            selfId: null,
            colorOverrides: const {},
            onReport: (_) {},
          ),
        ),
      );
      final order = <int, double>{};
      for (final r in [1, 2, 3]) {
        final sem = tester.widget<Semantics>(
          find.byKey(ValueKey('leaderboard-rank-row-$r')),
        );
        order[r] = (sem.properties.sortKey! as OrdinalSortKey).order;
      }
      expect(order[1]!, lessThan(order[2]!));
      expect(order[2]!, lessThan(order[3]!));
    });
  });

  group('1.10 tema anahtarı görünen durumu söyler', () {
    // Kusur: kayıtlı tercih `system` + cihaz koyu iken uygulama koyu çizilir
    // ama anahtar "kapalı" gösterirdi. Yeni kurulum `dark` ile açıldığı için
    // yalnız eski kayıtlarda görülürdü.
    test('system modunda platform parlaklığı esas alınır', () {
      final p = ThemeProvider(initialMode: ThemeMode.system);
      expect(p.isDarkFor(Brightness.dark), isTrue);
      expect(p.isDarkFor(Brightness.light), isFalse);
      expect(
        ThemeProvider(initialMode: ThemeMode.dark).isDarkFor(Brightness.light),
        isTrue,
      );
      expect(
        ThemeProvider(initialMode: ThemeMode.light).isDarkFor(Brightness.dark),
        isFalse,
      );
    });
  });

  group('1.6 hızlı tepki sırası dar görünümde taşmaz', () {
    // Kusur: beş düğme 56 px sabit (280); ≈300 px bölünmüş ekranda taşardı.
    testWidgets('260 px genişlikte yatay taşma yok', (tester) async {
      await tester.pumpWidget(
        ChangeNotifierProvider<LanguageProvider>.value(
          value: LanguageProvider()..setLang('tr'),
          child: MaterialApp(
            theme: AppTheme.dark(),
            home: Scaffold(
              body: Center(
                child: SizedBox(
                  width: 260,
                  child: QuickReactionBar(onReaction: (_, _) {}),
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
      final box = tester.getSize(
        find.byKey(const ValueKey('room-reaction-🔥')).first,
      );
      expect(box.width, greaterThanOrEqualTo(44));
    });
  });

  group('H1 AppShell kapanınca bağlantı aboneliği kurulmaz', () {
    // Kusur: `_initConnectivity` ilk okumayı beklerken ekran kapanırsa
    // `dispose` henüz null olan aboneliği iptal edemezdi, ardından kurulan
    // dinleyici sızardı. Yalnız yavaş ilk okumada (ağ yokken) olur.
    testWidgets('ilk okuma sürerken dispose → dinleyici eklenmez', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final monitor = _SlowMonitor();
      await tester.pumpWidget(
        testShell(
          child: AppShell(
            repository: freshMockRepository(),
            connectivityMonitor: monitor,
          ),
        ),
      );
      await tester.pump();
      await tester.pumpWidget(const SizedBox.shrink());
      monitor.firstRead.complete(const [ConnectivityResult.wifi]);
      await tester.pump();
      expect(monitor.listenCount, 0);
    });
  });

  group('H4 TtsService.load eşzamanlı çağrıda tek örnek', () {
    // Kusur: devam eden başlatma paylaşılmıyordu; iki eşzamanlı çağrı iki
    // `FlutterTts` kurup ilkini sahipsiz bırakıyordu (çifte konuşma).
    // Yalnız iki ekranın aynı anda yüklemesinde (ağır cihaz) tetiklenirdi.
    testWidgets('iki eşzamanlı load() aynı örneği döndürür', (tester) async {
      SharedPreferences.setMockInitialValues({});
      const channel = MethodChannel('flutter_tts');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, (call) async {
            return call.method == 'getLanguages' ? <String>['tr-TR'] : 1;
          });
      addTearDown(() {
        TtsService.resetInstance();
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(channel, null);
      });
      final results = await tester.runAsync(
        () => Future.wait([TtsService.load(), TtsService.load()]),
      );
      expect(identical(results![0], results[1]), isTrue);
    });
  });
}

class _SlowMonitor implements ConnectivityMonitor {
  final firstRead = Completer<List<ConnectivityResult>>();
  int listenCount = 0;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged =>
      Stream<List<ConnectivityResult>>.multi((c) {
        listenCount++;
      });

  @override
  Future<List<ConnectivityResult>> checkConnectivity() => firstRead.future;
}
