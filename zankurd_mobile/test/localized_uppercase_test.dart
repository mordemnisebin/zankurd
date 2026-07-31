import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/screen_identity_header.dart';

/// Büyük harfe çevirme dile bağlıdır.
///
/// 2026-07-27: bölüm başlıkları `String.toUpperCase()` ile çiziliyordu.
/// Dart'ın bu çağrısı yereli tanımaz ve Türkçede 'i' → 'I' verir; ayarlar
/// ekranı "GÜVENLIK", "SES & BILDIRIM", "SESLENDIRME" yazıyordu. Kusur
/// sessizdi: sözlükteki metinler doğruydu, yalnız büyütme yanlıştı —
/// ve yalnız içinde 'i' geçen başlıklarda görünüyordu, o yüzden ekrana
/// bakarken kolayca gözden kaçıyordu.
///
/// Kurmancîde aynı eşleme **doğrudur**: alfabede i ve î ayrı harflerdir,
/// 'i'nin büyüğü 'I'dır. Bu yüzden test iki dili de ölçer — tek yönlü bir
/// düzeltme öbür dili bozardı.
void main() {
  test('Türkçede noktalı i büyürken noktasını korur', () {
    expect(upperForLanguage('Güvenlik', ku: false), 'GÜVENLİK');
    expect(upperForLanguage('Ses & Bildirim', ku: false), 'SES & BİLDİRİM');
    expect(upperForLanguage('Seslendirme', ku: false), 'SESLENDİRME');
    // Noktasız ı, noktasız I olur — ters yön de bozulmamalı.
    expect(upperForLanguage('Sıralama', ku: false), 'SIRALAMA');
  });

  test('Kurmancîde i noktasız I olur', () {
    expect(upperForLanguage('Ewlekarî', ku: true), 'EWLEKARÎ');
    expect(upperForLanguage('Deng û Agahdarî', ku: true), 'DENG Û AGAHDARÎ');
    expect(upperForLanguage('Hînbûn', ku: true), 'HÎNBÛN');
    expect(upperForLanguage('Hesabi', ku: true), 'HESABI');
  });

  testWidgets('bölüm başlığı ekranda doğru büyütülür', (tester) async {
    for (final (lang, expected) in [('tr', 'GÜVENLİK'), ('ku', 'EWLEKARÎ')]) {
      await tester.pumpWidget(
        ChangeNotifierProvider<LanguageProvider>(
          // Anahtar şart: anahtarsız ikinci `pumpWidget` aynı sağlayıcı
          // öğesini yeniden kullanır, `create` bir daha koşmaz ve
          // Kurmancî turu sessizce Türkçeyi ölçer.
          key: ValueKey(lang),
          create: (_) => LanguageProvider()..setLang(lang),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: Scaffold(
              body: Builder(
                builder: (context) => ScreenSectionLabel(
                  label: context.t(K.secSafety),
                  accent: AppTheme.brand,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(expected), findsOneWidget, reason: '$lang başlığı');
    }
  });
}
