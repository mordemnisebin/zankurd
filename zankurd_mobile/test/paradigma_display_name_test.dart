import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';
import 'package:zankurd_mobile/src/config/subcategory_config.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/subcategory_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// "Paradigma" kategorisi oyuncuya "Bilim ve Düşünce / Zanist û Raman" diye
/// görünür; iç kimlik 'Paradigma' kalır.
///
/// ## Kusur
///
/// 2026-09-30'da tek bir siyasi hareketin öğretisini doğru cevap diye sunan
/// sorular emekli edildi. Kalan içerik nötr toplum bilimi, felsefe (feminizm,
/// liberalizm, sivil toplum, ütopya, güçler ayrılığı) ve genel bilimdir.
/// "Paradigma" adı artık bu içeriğin vaadi değildi ve alt konular (Demokratik
/// Konfederalizm, Ekoloji, Jineoloji) tek bir hareketin başlıklarıydı.
///
/// ## Niçin sessiz kalır
///
/// Görünen ad tek yerde ([CategoryNames] / `K.catParadigma`) tutulur, ama
/// kimlik soru bankasında, sunucuda (`categories.name/slug`), görsel
/// tablolarında ve ilerleme anahtarlarında 'Paradigma'dır. Biri adı değiştirirken
/// kimliği de değiştirirse (ya da tersine eski adı geri koyarsa) hiçbir ekran
/// hata vermez: yalnız oyuncu yanlış adı görür ya da ilerlemesi kaybolur. Bu
/// dosya ikisini birlikte kilitler.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('Paradigma oyuncuya iki dilde yeni adıyla görünür', () {
    expect(CategoryNames.localized('Paradigma', false), 'Bilim ve Düşünce');
    expect(CategoryNames.localized('Paradigma', true), 'Zanist û Raman');
    expect(CategoryNames.tr('Paradigma'), 'Bilim ve Düşünce');
  });

  test('eski ad hiçbir dilde görünmez', () {
    for (final isKu in [false, true]) {
      final shown = CategoryNames.localized('Paradigma', isKu);
      expect(shown, isNot(contains('Paradigma')));
      expect(shown, isNot(contains('Paradîgma')));
    }
  });

  test('kimlik değişmez: görünen adlar da aynı kategoriye çözülür', () {
    expect(CategoryVisuals.canonicalName('Paradigma'), 'Paradigma');
    expect(CategoryVisuals.canonicalName('Paradîgma'), 'Paradigma');
    expect(CategoryVisuals.canonicalName('Bilim ve Düşünce'), 'Paradigma');
    expect(CategoryVisuals.canonicalName('Zanist û Raman'), 'Paradigma');
    expect(
      SubcategoryConfig.forCategory('Bilim ve Düşünce'),
      SubcategoryConfig.forCategory('Paradigma'),
    );
  });

  test(
    'üç alt konu tanımlı, adları yeni kimliği taşır ve hepsinde soru var',
    () {
      final subs = SubcategoryConfig.forCategory('Paradigma');
      expect(subs.map((s) => s.id), [
        'civak_maf',
        'raman_felsefe',
        'zanist_jiyan',
      ]);
      // Eski tek-hareket başlıkları geri gelmesin.
      for (final sub in subs) {
        for (final text in [
          sub.nameKu,
          sub.nameTr,
          sub.descriptionKu,
          sub.descriptionTr,
        ]) {
          expect(text, isNot(contains('Konfederal')), reason: sub.id);
          expect(text, isNot(contains('Jineoloj')), reason: sub.id);
        }
      }

      final playable = MockZanKurdRepository().playableQuestions
          .where((q) => q.category == 'Paradigma')
          .toList();
      final counts = <String, int>{
        for (final sub in subs)
          sub.id: playable
              .where((q) => SubcategoryConfig.getSubcategoryId(q) == sub.id)
              .length,
      };
      for (final sub in subs) {
        expect(
          counts[sub.id],
          greaterThan(0),
          reason:
              '${sub.id} boş: anahtar kelimeler bankayla örtüşmüyor ($counts)',
        );
      }
      // Hiçbir konu her şeyi yutmasın (tek kova = konu sözü sahte).
      final matched = counts.values.fold<int>(0, (a, b) => a + b);
      for (final sub in subs) {
        expect(counts[sub.id]!, lessThan(matched * 0.7), reason: '$counts');
      }
    },
  );

  for (final lang in ['tr', 'ku']) {
    testWidgets('alt konu ekranı eski adı yazmaz ($lang)', (tester) async {
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => LanguageProvider()..setLang(lang),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: SubcategoryScreen(
              repository: MockZanKurdRepository(),
              category: 'Paradigma',
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.text(lang == 'ku' ? 'Zanist û Raman' : 'Bilim ve Düşünce'),
        findsOneWidget,
      );
      expect(find.textContaining('Paradigma'), findsNothing);
      expect(find.textContaining('Paradîgma'), findsNothing);
    });
  }
}
