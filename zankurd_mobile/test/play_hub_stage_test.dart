/// Yarış sekmesinin (`PlayHubScreen`) SAHNE bekçisi.
///
/// ## Kusur
///
/// Sahip oyun merkezini "renksiz" buldu: ekran sakin, tek düzeyli bir menü
/// gibi duruyordu ve hiçbir kart "burası oyun" demiyordu. Hızlı düello
/// kartı düz tek renkli bir dikdörtgendi (bir "başla" düğmesinden farksız);
/// oda kur/kodla katıl kartlarının alt satırı yalnız ekran okuyucuya
/// duyuruluyordu, GÖREN kullanıcı hiç göremiyordu (parametre adı bile
/// bunu itiraf ediyordu: `semanticSubtitle`); günün etkinliği kartı diğer
/// sıradan kartlarla birebir aynı yüzeydeydi — rengi yalnız küçük, soluk bir
/// amblem taşıyordu.
///
/// ## Niçin sessiz kalırdı
///
/// Var olan testler yalnız DÜZLÜĞÜ sabitliyordu, renkliliği değil:
/// `play_hub_screen_test.dart` hero'nun `color == culturalBrandBg` VE
/// `gradient == null` olduğunu doğruluyordu — yani "düz kalsın" diye
/// bekçilik ediyordu. Oda kartının alt satırı hiçbir yerde `find.text` ile
/// aranmıyordu çünkü zaten hiçbir `Text` widget'ı yoktu, yalnız
/// `Semantics.label` içindeydi. Kontrast hiçbir yerde ölçülmüyordu. Bu dosya
/// yeni sahneyi (`StageBackdropPainter`, görünür alt satırlar, altın tonlu
/// etkinlik yüzeyi) VE bunların okunabilirliğini (WCAG ≥ 4.5:1) birlikte
/// sabitler.
///
/// İlk sürümde konfeti kart yüksekliğine oranla yerleşiyordu; tur
/// görüntüsünde bir elmas "Sen" dairesinin içine düştü. Bu yüzden konfetinin
/// hiçbir metin ve ikonla kesişmediği de burada ölçülür.
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/sahne.dart';

import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/providers/remote_availability.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/mode_card.dart';
import 'package:zankurd_mobile/src/widgets/stage_backdrop.dart';

import 'support/widget_test_helpers.dart';

/// `test/play_hub_screen_test.dart` / `test/home_play_hierarchy_test.dart`
/// ile aynı iskele: dil ve tema sağlayıcıları + (gerektiğinde) kilitli
/// `RemoteAvailability` (bkz. `test/offline_honesty_test.dart`).
Widget _shell({required bool isKu, required bool isDark, bool locked = false}) {
  return KeyedSubtree(
    // Aynı testte arka arkaya birden çok `pumpWidget` çağrısı gelir; ağacın
    // ŞEKLİ değişmezse Flutter altındaki `State`/`create:` sağlayıcılarını
    // YENİDEN KURMAZ, yalnız günceller — `testShell`in `LanguageProvider`ı
    // `create:` ile kurulduğu için ikinci pump'ta eski dilde takılı
    // kalıyordu. `home_play_hierarchy_test.dart`daki
    // `key: ValueKey('play-$isKu-$isDark')` ile aynı çare: her kombinasyon
    // farklı bir anahtarla gerçekten SIFIRDAN kurulur.
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

/// WCAG göreli kontrast oranı — `AppColors._contrast` ile aynı formül
/// (o yardımcı `app_theme.dart`ta private olduğu için burada yinelenir).
double _contrast(Color a, Color b) {
  final l1 = a.computeLuminance();
  final l2 = b.computeLuminance();
  final hi = l1 > l2 ? l1 : l2;
  final lo = l1 > l2 ? l2 : l1;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  testWidgets(
    'sahne: sen/rakip koltukları, VS rozeti ve ışık deseni her dilde ve temada durur',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final isKu in [false, true]) {
        for (final isDark in [false, true]) {
          await tester.pumpWidget(_shell(isKu: isKu, isDark: isDark));
          await tester.pumpAndSettle();

          final hero = find.byKey(const ValueKey('play-hub-quick-duel'));
          expect(hero, findsOneWidget, reason: 'ku=$isKu dark=$isDark');

          final youLabel = isKu ? 'Tu' : 'Sen';
          final opponentLabel = isKu ? 'Hevrik' : 'Rakip';
          expect(
            find.descendant(of: hero, matching: find.text(youLabel)),
            findsOneWidget,
            reason: 'ku=$isKu dark=$isDark: "$youLabel" koltuğu görünmeli',
          );
          expect(
            find.descendant(of: hero, matching: find.text(opponentLabel)),
            findsOneWidget,
            reason: 'ku=$isKu dark=$isDark: "$opponentLabel" koltuğu görünmeli',
          );
          expect(
            find.descendant(of: hero, matching: find.text('VS')),
            findsOneWidget,
            reason: 'ku=$isKu dark=$isDark: VS rozeti görünmeli',
          );

          final stage = find.descendant(
            of: hero,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is CustomPaint &&
                  widget.painter is StageBackdropPainter,
            ),
          );
          expect(
            stage,
            findsOneWidget,
            reason:
                'ku=$isKu dark=$isDark: hero sahne fonunu '
                '(ışın + parıltı + konfeti) çizmeli.',
          );

          // Konfeti hiçbir metnin ya da ikonun üstüne düşmez.
          final stageBox = tester.getRect(stage);
          final confetti = StageBackdropPainter.confettiRects(
            stageBox.size,
          ).map((rect) => rect.shift(stageBox.topLeft)).toList();
          final content = [
            ...find
                .descendant(of: hero, matching: find.byType(Text))
                .evaluate(),
            ...find
                .descendant(of: hero, matching: find.byType(Icon))
                .evaluate(),
          ].map((element) => tester.getRect(find.byWidget(element.widget)));
          for (final rect in content) {
            for (final piece in confetti) {
              expect(
                rect.overlaps(piece),
                isFalse,
                reason:
                    'ku=$isKu dark=$isDark: konfeti $piece, içerik $rect '
                    'ile kesişiyor.',
              );
            }
          }
        }
      }
    },
  );

  testWidgets(
    'CTA erişilebilirken turuncu ve ≥48dp; kilitliyken pasif ve semantik olarak kapalı',
    (tester) async {
      final handle = tester.ensureSemantics();
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final isDark in [false, true]) {
        // Erişilebilir durum: eski davranış korunur.
        await tester.pumpWidget(_shell(isKu: false, isDark: isDark));
        await tester.pumpAndSettle();

        final ctaKey = find.byKey(const ValueKey('play-hub-quick-duel-cta'));
        final cta = tester.widget<Container>(ctaKey);
        final decoration = cta.decoration! as BoxDecoration;
        final ctaContext = tester.element(ctaKey);
        expect(
          decoration.color,
          AppTheme.primaryCtaColor(ctaContext),
          reason: 'dark=$isDark: erişilebilirken CTA turuncu olmalı',
        );
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

        // Kilitli durum: sunucuya hiç ulaşılamıyor.
        await tester.pumpWidget(
          _shell(isKu: false, isDark: isDark, locked: true),
        );
        await tester.pumpAndSettle();

        final lockedCta = tester.widget<Container>(ctaKey);
        final lockedDecoration = lockedCta.decoration! as BoxDecoration;
        final lockedCtaContext = tester.element(ctaKey);
        // 2026-09-27 simülatör turu: `AppColors.disabledSurface` açık
        // zeminler içindir; koyu sahnede açık gri, dolu bir düğme gibi
        // parlıyordu. Sahnede pasif düğme soluk, yarı saydam beyazdır.
        expect(
          lockedDecoration.color,
          Colors.white.withValues(alpha: 0.12),
          reason: 'dark=$isDark: kilitliyken CTA sahnede soluklaşmalı',
        );
        expect(
          lockedDecoration.color,
          isNot(AppColors.disabledSurface(lockedCtaContext)),
          reason: 'dark=$isDark: açık zemin pasif rengi koyu sahnede parlar',
        );
        expect(
          lockedDecoration.color,
          isNot(AppTheme.primaryCtaColor(lockedCtaContext)),
          reason: 'dark=$isDark',
        );
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

  testWidgets('oda kartlarının alt satırı artık görünür (TR ve Kurmancî)', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    for (final isKu in [false, true]) {
      await tester.pumpWidget(_shell(isKu: isKu, isDark: false));
      await tester.pumpAndSettle();

      // `K.createRoomSub` / `K.joinByCodeSub` değerleri — eskiden yalnız
      // `Semantics.label` içindeydi (`semanticSubtitle`), şimdi görünür
      // `Text`.
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

  testWidgets(
    'günün etkinliği kartı altın tonuyla ısınır; amblemi dolu altın taşır',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final isDark in [false, true]) {
        await tester.pumpWidget(_shell(isKu: false, isDark: isDark));
        await tester.pumpAndSettle();

        final key = find.byKey(const ValueKey('play-hub-daily-contest'));
        final card = tester.widget<ModeCard>(key);
        expect(card.emphasis, ModeCardEmphasis.event, reason: 'dark=$isDark');

        // 2026-09-29 Şahnê: yüzey pahlıdır (`ShapeDecoration`); etkinlik
        // kartı Zêr rolünün ton zeminidir (`goldTint`), amblemi dolu Zêr
        // karo + koyu ikon (`onGold`).
        final ink = tester.widget<Ink>(
          find.descendant(of: key, matching: find.byType(Ink)).first,
        );
        final decoration = ink.decoration! as ShapeDecoration;
        final t = SahneTokens.of(tester.element(key));
        expect(
          decoration.color,
          isNot(t.s1),
          reason:
              'dark=$isDark: etkinlik yüzeyi düz kart rengiyle aynı '
              'olmamalı — altın tonu karışmalı',
        );
        expect(decoration.color, t.goldTint, reason: 'dark=$isDark');
        // Renk katılır ama gradyan/gölge eklenmez — bekçisi
        // `home_play_hierarchy_test.dart`.
        expect(decoration.gradient, isNull, reason: 'dark=$isDark');
        expect(
          decoration.shadows ?? const <BoxShadow>[],
          isEmpty,
          reason: 'dark=$isDark',
        );

        final iconTile = tester.widget<Container>(
          find.descendant(of: key, matching: find.byType(Container)).first,
        );
        final iconDecoration = iconTile.decoration! as ShapeDecoration;
        expect(
          iconDecoration.color,
          t.gold,
          reason: 'dark=$isDark: amblem dolu altın olmalı',
        );
      }
    },
  );

  test('WCAG kontrastı: sahne beyazı ve altın yüzeyler ≥ 4.5:1', () {
    // Sahne gradyanının iki ucu — beyaz metin (versus koltukları, CTA
    // altındaki başlık) ikisinde de okunmalı.
    expect(
      _contrast(Colors.white, AppTheme.culturalBrandBg),
      greaterThanOrEqualTo(4.5),
      reason: 'beyaz metin, sahne gradyanının kimlik (üst) ucunda okunmalı',
    );
    expect(
      _contrast(Colors.white, AppTheme.surface),
      greaterThanOrEqualTo(4.5),
      reason: 'beyaz metin, sahne gradyanının koyu (alt) ucunda okunmalı',
    );

    // VS rozeti: koyu ink metin, dolu altın zemin.
    expect(
      _contrast(AppTheme.lightTextPrimary, AppTheme.gold),
      greaterThanOrEqualTo(4.5),
      reason: 'VS rozetinin ink metni dolu altın zeminde okunmalı',
    );

    // Günün etkinliği kartının altın tonlu yüzeyi — hem açık hem koyu tema,
    // hem birincil hem ikincil metin rengiyle. `ModeCard` bunu
    // `Color.alphaBlend(accent.withValues(alpha: isLight ? 0.16 : 0.20),
    // surfaceColor)` ile üretir; aynı formül burada context'siz sabitlerle
    // yinelenir.
    final lightEventSurface = Color.alphaBlend(
      AppTheme.gold.withValues(alpha: 0.16),
      AppTheme.lightSurface,
    );
    final darkEventSurface = Color.alphaBlend(
      AppTheme.gold.withValues(alpha: 0.20),
      AppTheme.surface,
    );

    expect(
      _contrast(AppTheme.lightTextPrimary, lightEventSurface),
      greaterThanOrEqualTo(4.5),
      reason: 'açık temada birincil metin, altın tonlu yüzeyde okunmalı',
    );
    expect(
      _contrast(AppTheme.lightTextSub, lightEventSurface),
      greaterThanOrEqualTo(4.5),
      reason: 'açık temada ikincil metin, altın tonlu yüzeyde okunmalı',
    );
    expect(
      _contrast(AppTheme.textPrimary, darkEventSurface),
      greaterThanOrEqualTo(4.5),
      reason: 'koyu temada birincil metin, altın tonlu yüzeyde okunmalı',
    );
    expect(
      _contrast(AppTheme.textSub, darkEventSurface),
      greaterThanOrEqualTo(4.5),
      reason: 'koyu temada ikincil metin, altın tonlu yüzeyde okunmalı',
    );
  });
}
