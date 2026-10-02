/// Yarış sekmesinin (`PlayHubScreen`) SAHNE bekçisi.
///
/// ## Kusur
///
/// Sahip oyun merkezini "renksiz" buldu: ekran sakin, tek düzeyli bir menü
/// gibi duruyordu ve hiçbir kart "burası oyun" demiyordu. Oda kur/kodla
/// katıl kartlarının alt satırı yalnız ekran okuyucuya duyuruluyordu,
/// GÖREN kullanıcı hiç göremiyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Var olan testler yalnız DÜZLÜĞÜ sabitliyordu, renkliliği değil; oda
/// kartının alt satırı hiçbir yerde `find.text` ile aranmıyordu; kontrast
/// hiçbir yerde ölçülmüyordu.
///
/// ## 2026-09-29 Şahnê:
///
/// 2026-09-27'deki yeşil degrade + ışık hüzmesi/konfeti sahnesi Şahnê'ye
/// taşındı: hızlı düello bir DÜELLO SAHNE KARTIDIR (Boyax sahne degradesi,
/// kilim göz şeridi, VS amblemi — oyuncu elması altın halkalı, rakip "?");
/// tek birincil düğme "Rakip bul" (Agir, koyu metin). Günün etkinliği
/// liste satırıdır: yarış rolü + "BUGÜN" rozeti (ton + söz, dolu kırmızı
/// değil). Bu dosya sahneyi, görünür alt satırları ve okunabilirliği
/// (WCAG ≥ 4.5:1) birlikte sabitler.
///
/// ## 2026-09-29 doğallık:
///
/// VS amblemi kalktı (K5): yerine somut bilgi satırı ("10 soru · ~2
/// dakika"). Üst etiket büyük harf değil, kalın açıklama (K8). Oda
/// eylemleri yan yana iki ikincil düğme; iki alt satır yerine bölümün tek
/// açıklama satırı (K7) — kilitliyken o satır sunucu durumunu söyler.
/// Günün etkinliğinin "Bugün" rozeti kalktı: satırın adıyla aynı sözdü.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/providers/remote_availability.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

/// Her dil/tema/kilit kombinasyonu farklı bir anahtarla SIFIRDAN kurulur:
/// `testShell`in `create:` ile kurulan sağlayıcıları ikinci pump'ta
/// güncellenmez.
Widget _shell({required bool isKu, required bool isDark, bool locked = false}) {
  return KeyedSubtree(
    key: ValueKey('stage-$isKu-$isDark-$locked'),
    child: testShell(
      languageProvider: isKu ? kurmanciLang() : turkishLang(),
      themeProvider: ThemeProvider(
        initialMode: isDark ? ThemeMode.dark : ThemeMode.light,
      ),
      remoteAvailability: RemoteAvailability(reachable: !locked),
      child: PlayHubScreen(repository: MockZanKurdRepository()),
    ),
  );
}

double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  testWidgets(
    'sahne: düello kartı, bilgi satırı ve üst etiket her dilde ve temada durur',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final isKu in [false, true]) {
        for (final isDark in [false, true]) {
          await tester.pumpWidget(_shell(isKu: isKu, isDark: isDark));
          await tester.pumpAndSettle();
          final why = 'ku=$isKu dark=$isDark';

          final hero = find.byKey(const ValueKey('play-hub-quick-duel'));
          expect(hero, findsOneWidget, reason: why);
          final card = tester.widget<SahneStageCard>(
            find.descendant(of: hero, matching: find.byType(SahneStageCard)),
          );
          expect(card.role, SahneRole.race, reason: why);
          expect(
            find.descendant(of: hero, matching: find.byType(SahneVsEmblem)),
            findsNothing,
            reason: why,
          );
          expect(
            find.descendant(
              of: hero,
              matching: find.text(
                isKu ? '10 pirs · ~2 deqe' : '10 soru · ~2 dakika',
              ),
            ),
            findsOneWidget,
            reason: why,
          );
          // Üst etiket cümle düzeninde (büyük harf yalnız soru künyesinde).
          expect(
            find.descendant(
              of: hero,
              matching: find.text(isKu ? 'Pêşbirka bilez' : 'Hızlı düello'),
            ),
            findsOneWidget,
            reason: why,
          );
          expect(tester.takeException(), isNull, reason: why);
        }
      }
    },
  );

  testWidgets(
    'CTA erişilebilirken etkin ve ≥48dp; kilitliyken pasif ve semantik olarak kapalı',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final isDark in [false, true]) {
        await tester.pumpWidget(_shell(isKu: false, isDark: isDark));
        await tester.pumpAndSettle();

        final ctaKey = find.byKey(const ValueKey('play-hub-quick-duel-cta'));
        final button = find.descendant(
          of: ctaKey,
          matching: find.byType(SahneButton),
        );
        expect(tester.widget<SahneButton>(button).onPressed, isNotNull);
        expect(
          tester.getSize(ctaKey).height,
          greaterThanOrEqualTo(48),
          reason: 'dark=$isDark',
        );
        final enabledSemantics = tester
            .getSemantics(find.byKey(const ValueKey('play-hub-quick-duel')))
            .getSemanticsData();
        expect(
          enabledSemantics.flagsCollection.isEnabled,
          ui.Tristate.isTrue,
          reason: 'dark=$isDark: erişilebilirken düğme etkin duyurulmalı',
        );

        // Kilitli durum: sunucuya hiç ulaşılamıyor. Düğme bileşenin pasif
        // hâline geçer (Perde + üçüncül metin; turuncu değil).
        await tester.pumpWidget(
          _shell(isKu: false, isDark: isDark, locked: true),
        );
        await tester.pumpAndSettle();
        expect(tester.widget<SahneButton>(button).onPressed, isNull);
        final lockedSemantics = tester
            .getSemantics(find.byKey(const ValueKey('play-hub-quick-duel')))
            .getSemanticsData();
        expect(
          lockedSemantics.flagsCollection.isEnabled,
          ui.Tristate.isFalse,
          reason: 'dark=$isDark: kilitliyken düğme kapalı duyurulmalı',
        );
      }
      handle.dispose();
    },
  );

  testWidgets('oda eylemlerinin açıklaması görünür (TR, Kurmancî, kilitli)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final isKu in [false, true]) {
      await tester.pumpWidget(_shell(isKu: isKu, isDark: false));
      await tester.pumpAndSettle();

      final note = isKu
          ? 'Hevalên xwe bi kodê vexwîne'
          : 'Arkadaşlarını kodla çağır';
      expect(find.text(note), findsOneWidget, reason: 'ku=$isKu');
    }

    // 2026-09-30 simülatör: kilitliyken açıklama satırları normal kalır;
    // "Sunucuya ulaşılamadı" Yarış ekranında dört kez yazılıyordu. Sunucu
    // durumunu üstteki şerit (kabuk) söyler, ekran bu metni HİÇ yazmaz.
    for (final isKu in [false, true]) {
      await tester.pumpWidget(_shell(isKu: isKu, isDark: false, locked: true));
      await tester.pumpAndSettle();
      expect(
        find.text(
          isKu ? 'Hevalên xwe bi kodê vexwîne' : 'Arkadaşlarını kodla çağır',
        ),
        findsOneWidget,
      );
      expect(
        find.text(isKu ? 'Pêşkêşkar negihîştbar e' : 'Sunucuya ulaşılamadı'),
        findsNothing,
        reason: 'kilitli Yarış ekranı sunucu durumunu tekrarlamaz (ku=$isKu)',
      );
    }
  });

  // 2026-09-30 simülatör: kilitliyken "Rakip bul", "Oda kur", "Kodla katıl" ve
  // "Günün soruları" dokunulunca hiçbir şey yapmıyordu (sessiz ölü düğme).
  // Bekçi: dördü de pasif kalır (tıklanabilir bildirilmez) ve dokunulunca
  // kısa bir SnackBar "Sunucuya ulaşılamadı" der.
  for (final key in [
    'play-hub-quick-duel-cta',
    'play-hub-create-room',
    'play-hub-join-room',
    'play-hub-daily-contest',
  ]) {
    testWidgets('kilitliyken $key dokunulunca geri bildirim verir', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      // Gerçekte ekran kabuğun Scaffold'unun içindedir (SnackBar oraya çıkar).
      await tester.pumpWidget(
        testShell(
          languageProvider: turkishLang(),
          themeProvider: ThemeProvider(initialMode: ThemeMode.light),
          remoteAvailability: RemoteAvailability(reachable: false),
          child: Scaffold(
            body: PlayHubScreen(repository: MockZanKurdRepository()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(SnackBar), findsNothing);
      await tester.tap(find.byKey(ValueKey(key)), warnIfMissed: false);
      await tester.pump();
      expect(find.byType(SnackBar), findsOneWidget, reason: key);
      expect(
        find.descendant(
          of: find.byType(SnackBar),
          matching: find.text('Sunucuya ulaşılamadı'),
        ),
        findsOneWidget,
      );
    });
  }

  testWidgets('erişilebilirken dokunuş SnackBar göstermez', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(_shell(isKu: false, isDark: false));
    await tester.pumpAndSettle();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('günün etkinliği yarış rolünde; adını tekrarlayan rozet yok', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final isDark in [false, true]) {
      await tester.pumpWidget(_shell(isKu: false, isDark: isDark));
      await tester.pumpAndSettle();

      final key = find.byKey(const ValueKey('play-hub-daily-contest'));
      expect(tester.widget<SahneListRow>(key).role, SahneRole.race);
      expect(
        find.descendant(of: key, matching: find.byType(SahneBadge)),
        findsNothing,
        reason: 'dark=$isDark',
      );
      expect(find.text('Bugün'), findsNothing, reason: 'dark=$isDark');
    }
  });

  test('WCAG kontrastı: düello sahnesi ve yarış rozeti ≥ 4.5:1', () {
    const night = SahneTokens.night;
    // Düello sahnesi gündüzde de gecedir: birincil metin ve yumuşak lal
    // (üst etiket, süre) sahne degradesinin açık (üst) ucunda okunmalı.
    expect(
      _contrast(night.tx, SahneStageColors.race1),
      greaterThanOrEqualTo(4.5),
    );
    expect(
      _contrast(SahneStageColors.raceSoft, SahneStageColors.race1),
      greaterThanOrEqualTo(4.5),
    );
    // "BUGÜN" rozeti: yarış tonu zemin + yarış metni, iki temada.
    for (final t in [SahneTokens.night, SahneTokens.day]) {
      expect(_contrast(t.raceTx, t.raceTint), greaterThanOrEqualTo(4.5));
    }
  });
}
