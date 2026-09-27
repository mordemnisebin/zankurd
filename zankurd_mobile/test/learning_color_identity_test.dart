import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/roj_mascot.dart';

/// Öğrenme ekranının renk kimliği: orman gradyanlı başlık kartı, dolu
/// playGreen sekme/eylem ve tonal altın "Flaş kart".
///
/// ## Kusur
///
/// Ekranın başlığı soluk bir ikon karosu + düz metindi; konu sekmeleri
/// `AppTheme.playGreen`in yalnız %14'ü kadar soluk bir zemin taşıyordu;
/// "Soru çöz" ve "Flaş kart" ikisi de aynı soluk çerçeveli (outlined)
/// yeşildi. Uygulamanın geri kalanı (ayarlar, oturum açma, kayıt ekranları)
/// `AppTheme.identityHeaderGradient` ile orman kimliğini taşırken öğrenme
/// ekranı — Kurmancî öğrenmenin asıl kapısı — ondan tamamen kopuktu. Sahip
/// ekranı "renksiz" buldu (2026-09-27).
///
/// ## Niçin sessiz kalırdı
///
/// Hiçbir bekçi rengi ÖLÇMÜYORDU. `test/learning_screen_test.dart`deki eski
/// bekçiler tam tersini doğruluyordu: başlığın "ayrı bir kart yüzeyi
/// oluşturmaması" ve seçili sekmenin "düşük yoğunluklu" (soluk) kalması
/// birer geçen testti — yani soluk renk kasıtlı bir tasarım kararı gibi
/// korunuyordu. Widget ağacı, anahtarlar, semantics ve dokunma hedefleri
/// hep doğruydu; eksik olan tek şey renkti ve onu doğrulayan hiçbir ölçüm
/// yoktu. Bu dosya o boşluğu kapatır: gradyan, dolu renk ve kontrast
/// doğrudan çalışan koddan okunur (sabit bir beklenti tekrarı değil).
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

  for (final isKu in [false, true]) {
    for (final dark in [false, true]) {
      final combo = 'ku=$isKu dark=$dark';

      testWidgets(
        'kimlik başlığı orman gradyanı ve beyaz başlık taşır ($combo)',
        (tester) async {
          await tester.pumpWidget(pump(isKu: isKu, dark: dark));
          await tester.pumpAndSettle();

          final header = find.byKey(const ValueKey('learning-scene-header'));
          expect(header, findsOneWidget);

          // Kartın kendisi: gradyanlı `Container` — ikon karosu da bir
          // `Container` olduğu için tip yerine "gradyanı olan" ile ayırt
          // edilir (sıralamaya bağımlı olmasın diye).
          final gradientCard = find.descendant(
            of: header,
            matching: find.byWidgetPredicate((widget) {
              if (widget is! Container) return false;
              final decoration = widget.decoration;
              return decoration is BoxDecoration && decoration.gradient != null;
            }),
          );
          expect(gradientCard, findsOneWidget);
          final decoration =
              tester.widget<Container>(gradientCard).decoration
                  as BoxDecoration;
          expect(decoration.gradient, AppTheme.identityHeaderGradient);

          // Zana tek başına eşlik eder, ikinci bir semantics düğümü açmaz.
          expect(find.byType(RojMascot), findsOneWidget);
          expect(
            find.ancestor(
              of: find.byType(RojMascot),
              matching: find.byType(ExcludeSemantics),
            ),
            findsOneWidget,
          );

          final titleText = isKu ? 'Kurmancî hîn bibe' : 'Kurmancî öğren';
          final title = tester.widget<Text>(
            find.descendant(of: header, matching: find.text(titleText)),
          );
          expect(title.style?.color, Colors.white);
        },
      );

      testWidgets(
        'seçili sekme dolu playGreen, seçili olmayan değil ($combo)',
        (tester) async {
          await tester.pumpWidget(pump(isKu: isKu, dark: dark));
          await tester.pumpAndSettle();

          // Varsayılan seçili kategori 'everyday'dir (bkz.
          // `_kLearningCategoryIds.first` learning_screen.dart).
          final selected = tester.widget<AnimatedContainer>(
            find.descendant(
              of: find.byKey(const ValueKey('learning-tab-everyday')),
              matching: find.byType(AnimatedContainer),
            ),
          );
          final selectedDecoration = selected.decoration as BoxDecoration;
          expect(selectedDecoration.color, AppTheme.playGreen);

          final selectedLabel = isKu ? 'Rojane' : 'Günlük';
          final selectedText = tester.widget<Text>(
            find.descendant(
              of: find.byKey(const ValueKey('learning-tab-everyday')),
              matching: find.text(selectedLabel),
            ),
          );
          expect(selectedText.style?.color, Colors.white);

          final unselected = tester.widget<AnimatedContainer>(
            find.descendant(
              of: find.byKey(const ValueKey('learning-tab-grammar')),
              matching: find.byType(AnimatedContainer),
            ),
          );
          final unselectedDecoration = unselected.decoration as BoxDecoration;
          expect(unselectedDecoration.color, isNot(AppTheme.playGreen));
        },
      );

      testWidgets(
        'Soru çöz playGreen dolu, Flaş kart altın harmanlı zemin taşır ($combo)',
        (tester) async {
          await tester.pumpWidget(pump(isKu: isKu, dark: dark));
          await tester.pumpAndSettle();
          final context = tester.element(find.byType(LearningScreen));

          final practice = tester.widget<FilledButton>(
            find.descendant(
              of: find.byKey(const ValueKey('learning-topic-practice')),
              matching: find.byType(FilledButton),
            ),
          );
          expect(
            practice.style?.backgroundColor?.resolve(<WidgetState>{}),
            AppTheme.playGreen,
          );
          expect(
            practice.style?.foregroundColor?.resolve(<WidgetState>{}),
            Colors.white,
          );

          final flashcards = tester.widget<FilledButton>(
            find.descendant(
              of: find.byKey(const ValueKey('learning-topic-flashcards')),
              matching: find.byType(FilledButton),
            ),
          );
          final plainSurface = AppTheme.surfaceColor(context);
          final flashcardsBg = flashcards.style?.backgroundColor?.resolve(
            <WidgetState>{},
          );
          // "Flaş kart" düz yüzey rengiyle karışmamalı — aksi hâlde
          // ikinci eylem birincil eylemden ayrışmaz (eski soluk hâlin
          // hatası buydu).
          expect(flashcardsBg, isNot(plainSurface));
          expect(
            flashcardsBg,
            Color.alphaBlend(
              AppTheme.gold.withValues(
                alpha: AppTheme.isLight(context) ? 0.22 : 0.26,
              ),
              plainSurface,
            ),
          );
          expect(
            flashcards.style?.foregroundColor?.resolve(<WidgetState>{}),
            AppTheme.textPrimaryColor(context),
          );
        },
      );
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

  test('beyaz metin gradyanın iki ucunda (culturalBrandBg, playGreen) WCAG AA '
      '(4.5:1) geçer', () {
    for (final (name, background) in [
      ('culturalBrandBg (gradyan başı)', AppTheme.culturalBrandBg),
      (
        'playGreen (gradyan sonu, seçili sekme, Soru çöz zemini)',
        AppTheme.playGreen,
      ),
    ]) {
      expect(
        _contrast(Colors.white, background),
        greaterThanOrEqualTo(4.5),
        reason: '$name üzerinde beyaz metin okunmuyor',
      );
    }
  });

  test('Flaş kart altın harmanlı zemininde ink/cream metin açık ve karanlık '
      'temada WCAG AA (4.5:1) geçer', () {
    final lightBg = Color.alphaBlend(
      AppTheme.gold.withValues(alpha: 0.22),
      AppTheme.lightSurface,
    );
    expect(
      _contrast(AppTheme.lightTextPrimary, lightBg),
      greaterThanOrEqualTo(4.5),
      reason: 'açık temada Flaş kart etiketi okunmuyor',
    );

    final darkBg = Color.alphaBlend(
      AppTheme.gold.withValues(alpha: 0.26),
      AppTheme.surface,
    );
    expect(
      _contrast(AppTheme.textPrimary, darkBg),
      greaterThanOrEqualTo(4.5),
      reason: 'karanlık temada Flaş kart etiketi okunmuyor',
    );
  });
}

double _contrast(Color a, Color b) {
  final hi = math.max(a.computeLuminance(), b.computeLuminance());
  final lo = math.min(a.computeLuminance(), b.computeLuminance());
  return (hi + 0.05) / (lo + 0.05);
}
