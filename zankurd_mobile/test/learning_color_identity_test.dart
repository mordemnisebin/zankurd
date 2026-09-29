import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

/// Öğrenme ekranının renk kimliği.
///
/// ## Kusur
///
/// Ekranın başlığı soluk bir ikon karosu + düz metindi; konu sekmeleri
/// yeşilin yalnız %14'ü kadar soluk bir zemin taşıyordu; "Soru çöz" ve
/// "Flaş kart" ikisi de aynı soluk çerçeveli yeşildi. Sahip ekranı "renksiz"
/// buldu (2026-09-27).
///
/// ## Niçin sessiz kalırdı
///
/// Hiçbir bekçi rengi ÖLÇMÜYORDU: widget ağacı, anahtarlar, semantics ve
/// dokunma hedefleri hep doğruydu; eksik olan tek şey renkti. Bu dosya o
/// boşluğu kapatır: renk ve kontrast doğrudan çalışan koddan okunur.
///
/// 2026-09-29 Şahnê: renk artık rol taşır. Eski bekçiler orman gradyanlı
/// başlık kartını, dolu yeşil sekmeyi ve altın harmanlı "Flaş kart"ı
/// ölçüyordu; üçü de Şahnê'de kalktı (B iskeleti başlık kartı taşımaz, palet
/// dışı renk yok, Agir yalnız TEK birincil eylemde). Ölçülen kurallar:
///
/// * sayfa adı B çubuğunda, birincil metin renginde; maskot yok;
/// * seçili konu çipi öğrenme rolünü (Zimrût tonu + Zimrût metni) taşır,
///   seçili olmayan ikincil metinde kalır;
/// * "Soru çöz" / "Flaş kart" ikincildir (Kulis), Agir değildir;
/// * etkin dersin sahne kartında TEK Agir düğme vardır, metni koyu `onAct`;
/// * bu çiftlerin hepsi iki temada WCAG AA (4.5:1) geçer.
void main() {
  Widget pump({required bool isKu, required bool dark}) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => LanguageProvider()..setLang(isKu ? 'ku' : 'tr'),
        ),
      ],
      child: MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: LearningScreen(repository: MockZanKurdRepository()),
      ),
    );
  }

  Color materialColorIn(WidgetTester tester, Finder button) => tester
      .widget<Material>(
        find.descendant(of: button, matching: find.byType(Material)).first,
      )
      .color!;

  for (final isKu in [false, true]) {
    for (final dark in [false, true]) {
      final combo = 'ku=$isKu dark=$dark';
      final t = dark ? SahneTokens.night : SahneTokens.day;

      testWidgets(
        'sayfa adı B çubuğunda, başlık kartı ve maskot yok ($combo)',
        (tester) async {
          await tester.pumpWidget(pump(isKu: isKu, dark: dark));
          await tester.pumpAndSettle();

          expect(find.byType(RojMascot), findsNothing, reason: combo);
          final titleText = isKu ? 'Kurmancî hîn bibe' : 'Kurmancî öğren';
          final title = find.descendant(
            of: find.byType(AppBar),
            matching: find.text(titleText),
          );
          expect(title, findsOneWidget, reason: combo);
          expect(
            DefaultTextStyle.of(tester.element(title)).style.color,
            t.tx,
            reason: combo,
          );
        },
      );

      testWidgets('seçili konu çipi öğrenme rolünde, öteki değil ($combo)', (
        tester,
      ) async {
        await tester.pumpWidget(pump(isKu: isKu, dark: dark));
        await tester.pumpAndSettle();

        // Varsayılan seçili kategori 'everyday'dir (bkz.
        // `_kLearningCategoryIds.first` learning_screen.dart).
        final selectedText = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('learning-tab-everyday')),
            matching: find.text(isKu ? 'Rojane' : 'Günlük'),
          ),
        );
        expect(selectedText.style?.color, t.learnTx, reason: combo);
        expect(
          materialColorIn(
            tester,
            find.byKey(const ValueKey('learning-tab-everyday')),
          ),
          t.learnTint,
          reason: combo,
        );

        final unselectedText = tester.widget<Text>(
          find.descendant(
            of: find.byKey(const ValueKey('learning-tab-grammar')),
            matching: find.text(isKu ? 'Rêziman' : 'Dilbilgisi'),
          ),
        );
        expect(unselectedText.style?.color, t.tx2, reason: combo);
        expect(
          materialColorIn(
            tester,
            find.byKey(const ValueKey('learning-tab-grammar')),
          ),
          isNot(t.learnTint),
          reason: combo,
        );
      });

      testWidgets('konu eylemleri ikincil (Kulis), Agir tek birincilde '
          '($combo)', (tester) async {
        await tester.pumpWidget(pump(isKu: isKu, dark: dark));
        await tester.pumpAndSettle();

        for (final key in [
          'learning-topic-practice',
          'learning-topic-flashcards',
        ]) {
          final button = find.descendant(
            of: find.byKey(ValueKey(key)),
            matching: find.byType(FilledButton),
          );
          expect(materialColorIn(tester, button), t.s2, reason: '$combo $key');
        }

        final primary = find.descendant(
          of: find.byKey(const ValueKey('learning-next-step')),
          matching: find.byType(FilledButton),
        );
        expect(materialColorIn(tester, primary), t.act, reason: combo);
      });
    }
  }

  testWidgets('%200 yazıda 390×844 öğrenme ekranı overflow yapmaz', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(390, 844),
          textScaler: TextScaler.linear(2),
        ),
        child: pump(isKu: false, dark: false),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
  });

  test('öğrenme ekranının renk çiftleri iki temada WCAG AA (4.5:1) geçer', () {
    for (final (theme, t) in [
      ('gündüz', SahneTokens.day),
      ('gece', SahneTokens.night),
    ]) {
      for (final (name, fg, bg) in [
        ('seçili çip: Zimrût metni / Zimrût tonu', t.learnTx, t.learnTint),
        ('seçili olmayan çip: ikincil metin / Perde', t.tx2, t.s1),
        ('ikincil düğme: birincil metin / Kulis', t.tx, t.s2),
        ('yol satırı: birincil metin / Perde', t.tx, t.s1),
        ('kilitli satır: ikincil metin / Perde', t.tx2, t.s1),
        ('birincil düğme: onAct / Agir', t.onAct, t.act),
      ]) {
        expect(
          _contrast(fg, bg),
          greaterThanOrEqualTo(4.5),
          reason: '$theme — $name',
        );
      }
    }
    // Sahne kartı her temada gece çizilir.
    const n = SahneTokens.night;
    for (final bg in [SahneStageColors.top, SahneStageColors.bottom]) {
      expect(_contrast(n.tx, bg), greaterThanOrEqualTo(4.5));
      expect(_contrast(n.tx2, bg), greaterThanOrEqualTo(4.5));
    }
    expect(_contrast(n.learnTx, n.learnTint), greaterThanOrEqualTo(4.5));
  });
}

double _contrast(Color a, Color b) {
  final hi = math.max(a.computeLuminance(), b.computeLuminance());
  final lo = math.min(a.computeLuminance(), b.computeLuminance());
  return (hi + 0.05) / (lo + 0.05);
}
