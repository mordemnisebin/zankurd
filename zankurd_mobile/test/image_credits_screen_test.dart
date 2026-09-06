import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/screens/image_credits_screen.dart';

import 'support/widget_test_helpers.dart';

/// Künye ekranı yüklenir; boş/hata metinleri defterdedir.
///
/// CC BY atıf yükümlülüğü bu ekrandadır. Bekçi yokken ekran kırılsa
/// veya JSON boşalsa testler yeşil kalırdı.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('künye ekranı başlık ve giriş metnini çizer', (tester) async {
    await tester.pumpWidget(testShell(child: const ImageCreditsScreen()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text(Tr.of(K.imageCredits, AppLanguage.tr)), findsOneWidget);
  });

  test('boş ve hata metinleri tabloda durur', () {
    expect(Tr.keys, contains(K.imageCreditsEmpty));
    expect(Tr.keys, contains(K.imageCreditsFailed));
  });
}
