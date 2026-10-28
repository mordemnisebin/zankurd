// 2026-10-20 "AZ SÖZ" turu, ikinci grup.
//
// ## Kusur
//
// Kullanıcı "uygulama çok metin odaklı" dedi; dört modelli tarama (Opus,
// Codex, ChatGPT, Grok) şu satırlarda uyuştu: başlığın ya da bölüm adının
// zaten söylediğini yineleyen alt satırlar (alt konu açıklamaları, "Kolaydan
// zora…", "Seninle arkadaş olmak istiyor", "Ödül doğrudan jetonlarına…",
// "Şampiyon kupayı alır.", "Konu seçmeden…"), "Bu cevaplara yeniden bak."
// ikinci cümlesi ve boş durumların ikinci cümleleri.
//
// ## Niçin sessiz kalırdı
//
// Her satır tek başına zararsız görünür; birikince ekran okunacak şey olur
// ve kimse "bu satır gerekli mi" diye geri dönüp bakmaz. Bu test satırların
// geri gelmediğini sabitler; geri ekleyen bunu bilerek bozmalıdır.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';
import 'package:zankurd_mobile/src/screens/subcategory_screen.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

Widget _wrap(Widget child, String lang) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang(lang)),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

void main() {
  test('kaldırılan metinler defterde ve kaynakta yok', () {
    final src = File('lib/src/l10n/strings.dart').readAsStringSync();
    for (final gone in [
      'Bir alt alan seçerek',
      'Kolaydan zora doğru ilerle',
      'Farklı konulardan karışık',
      'Seninle arkadaş olmak istiyor',
      'Ödül doğrudan jetonlarına',
      'Şampiyon kupayı alır',
      'Konu seçmeden doğrudan',
      'Bu cevaplara yeniden bak',
      'Li van bersivan careke din binêre',
      'Daha sonra tekrar gel',
      'Botla düello ve günün soruları',
    ]) {
      expect(src, isNot(contains(gone)), reason: gone);
    }
  });

  test('sonuç kartı şablonları tek cümle (tekil ve çoğul, iki dil)', () {
    for (final ku in [true, false]) {
      for (final key in [K.outcomeReviewOne, K.outcomeReview]) {
        final s = Tr.forKu(key, ku, {
          'name': 'Dil',
          'answered': '3',
          'wrong': '2',
        });
        expect(s.trim().endsWith('.'), isTrue);
        expect('.'.allMatches(s).length, 1, reason: s);
      }
    }
  });

  // 2026-10-29 (X1): `K.startRaceHint` iki cümle oldu ("Canlı düello ve oda
  // puanları burada sayılır. Günün turu kendi sıralamasında."): sıralamanın
  // neyi saydığı ve Günün turunun nerede olduğu ayrı iki bilgidir.
  test('boş durum metinleri tek cümle', () {
    for (final key in [K.contestNoneToday]) {
      for (final ku in [true, false]) {
        final s = Tr.forKu(key, ku);
        expect('.'.allMatches(s).length, 1, reason: s);
      }
    }
  });

  for (final lang in ['tr', 'ku']) {
    testWidgets('alt konu ve seviye ekranında açıklama satırı yok ($lang)', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          SubcategoryScreen(
            repository: MockZanKurdRepository(),
            category: 'Ziman',
          ),
          lang,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Bir alt alan seçerek yarışmaya başla.'), findsNothing);
      expect(find.text('Cümle ve kelime kuralları'), findsNothing);
      expect(find.textContaining('kategorisindeki tüm sorular'), findsNothing);

      await tester.pumpWidget(
        _wrap(
          LevelScreen(
            repository: MockZanKurdRepository(),
            category: 'Ziman',
            subCategory: 'reziman',
          ),
          lang,
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Cümle ve kelime kuralları'), findsNothing);
      expect(
        find.text('Kolaydan zora doğru ilerle, puan topla.'),
        findsNothing,
      );
    });
  }
}
