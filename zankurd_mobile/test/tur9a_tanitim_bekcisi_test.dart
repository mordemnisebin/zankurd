// Tasarım kurulu tur 8, tanıtım ekranı:
//
// * İlerleme çubuğu yeşildi; uygulamanın geri kalanında yol ilerlemesi
//   turuncu eylem rengindedir (Opus).
// * Yaş kutusu "13 yaşından büyüğüm" (TR) ve "Ez ji 13 salî mezintir im"
//   (KU) diyordu: katı karşılaştırma, yaş sınırı 13+ iken tam 13 yaşındakini
//   dışlıyordu (ChatGPT). Etiket artık "13 yaşında veya daha büyüğüm" /
//   "Ez 13 salî an jî mezintir im".
//
// Niçin sessiz kaldı: testler metni kendi kopyasından okuyup aynı kusurlu
// sözü sabitliyordu; çubuk rengi ise yalnız ekran görüntüsünde fark edilir.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

void main() {
  Future<void> pump(WidgetTester tester, String lang) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      ChangeNotifierProvider(
        create: (_) => LanguageProvider()..setLang(lang),
        child: MaterialApp(home: OnboardingScreen(onComplete: () {})),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('ilerleme çubuğu turuncu eylem tonunda', (tester) async {
    await pump(tester, 'tr');
    final bar = tester.widget<SahneProgressBar>(
      find.byKey(const ValueKey('onboarding-progress')),
    );
    expect(bar.tone, SahneProgressTone.action);
  });

  testWidgets('yaş etiketi tam 13 yaşındakini içerir', (tester) async {
    await pump(tester, 'tr');
    expect(find.text('13 yaşında veya daha büyüğüm'), findsOneWidget);
    expect(find.textContaining('yaşından büyük'), findsNothing);
  });

  testWidgets('Kurmancî yaş etiketi tam 13 yaşındakini içerir', (tester) async {
    await pump(tester, 'ku');
    expect(find.text('Ez 13 salî an jî mezintir im'), findsOneWidget);
  });
}
