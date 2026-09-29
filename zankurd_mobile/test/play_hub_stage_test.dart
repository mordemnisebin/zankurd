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
    'sahne: düello kartı, VS amblemi ve üst etiket her dilde ve temada durur',
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
            findsOneWidget,
            reason: why,
          );
          // Üst etiket yerele duyarlı büyük harf: Türkçede "HIZLI DÜELLO".
          expect(
            find.descendant(
              of: hero,
              matching: find.text(isKu ? 'PÊŞBIRKA BILEZ' : 'HIZLI DÜELLO'),
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

  testWidgets('oda satırlarının alt satırı görünür (TR ve Kurmancî)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final isKu in [false, true]) {
      await tester.pumpWidget(_shell(isKu: isKu, isDark: false));
      await tester.pumpAndSettle();

      final createSub = isKu
          ? 'Hevalên xwe bi kodê vexwîne'
          : 'Arkadaşlarını kodla çağır';
      final joinSub = isKu
          ? 'Koda odeyê, mînak: ZK-ABCDEF0123'
          : 'Oda kodu, örnek: ZK-ABCDEF0123';

      expect(find.text(createSub), findsOneWidget, reason: 'ku=$isKu');
      expect(find.text(joinSub), findsOneWidget, reason: 'ku=$isKu');
    }
  });

  testWidgets('günün etkinliği yarış rolü + "BUGÜN" rozeti taşır', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final isDark in [false, true]) {
      await tester.pumpWidget(_shell(isKu: false, isDark: isDark));
      await tester.pumpAndSettle();

      final key = find.byKey(const ValueKey('play-hub-daily-contest'));
      expect(tester.widget<SahneListRow>(key).role, SahneRole.race);
      final badge = tester.widget<SahneBadge>(
        find.descendant(of: key, matching: find.byType(SahneBadge)),
      );
      expect(badge.tone, SahneBadgeTone.race, reason: 'dark=$isDark');
      // 2026-09-29 doğallık: rozet artık cümle düzeninde (K8, `SahneBadge` captionStrong); bu bekçi eskiden büyük harfi bekliyordu.
      expect(find.text('Bugün'), findsOneWidget, reason: 'dark=$isDark');
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
