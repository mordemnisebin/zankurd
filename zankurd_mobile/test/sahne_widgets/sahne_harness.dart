import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Şahnê bileşen testlerinin ortak kurulumu.
///
/// Bileşenler en zor koşulda ölçülür: 320 × 640 (en dar desteklenen
/// telefon) ve metin ölçeği 2.0 (erişilebilirlik ayarlarının üst ucu).
/// Taşma Flutter'da bir istisna olarak raporlanır; her test pompadan sonra
/// `tester.takeException()`in `null` olduğunu doğrular. Gerçek yazı tipi
/// (`loadAppFonts`) `setUpAll`da yüklenmelidir: ölçü fontu Onest ve
/// Bricolage'ın genişliğini taşımaz ve taşmayı gizler ya da uydurur.
const kNarrow = Size(320, 640);

/// İki tema: gece ve gündüz.
const kThemes = {'gece': true, 'gündüz': false};

void noop() {}

Future<void> pumpSahne(
  WidgetTester tester,
  Widget child, {
  required bool dark,
  Size size = kNarrow,
  double textScale = 2,
  bool page = false,
  bool reduceMotion = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: dark ? AppTheme.dark() : AppTheme.light(),
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: reduceMotion,
          ),
          child: page
              ? child
              : Scaffold(
                  body: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: child,
                  ),
                ),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}
