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

  test('satır başlığı oyuncunun dilindeki alt yazıdır', () {
    // Başlık eskiden İngilizce Wikimedia dosya adıydı ("Lake Van (East)
    // 01"); dosya adı artık altta küçük satırda, eserin adı olarak durur.
    final credit = ImageCredit.fromJson(const {
      'title': 'Lake_Van_(East)_01.jpg',
      'artist': 'EvgenyGenkin',
      'license': 'CC BY 2.5',
      'source':
          'https://commons.wikimedia.org/wiki/File:Lake_Van_(East)_01.jpg',
      'caption_ku': 'Gola Wanê',
      'caption_tr': 'Van Gölü',
    });
    expect(credit.heading(true), 'Gola Wanê');
    expect(credit.heading(false), 'Van Gölü');
    expect(credit.displayTitle, 'Lake Van (East) 01');

    // Alt yazısız eski kayıt temizlenmiş dosya adına düşer, boş kalmaz.
    final bare = ImageCredit.fromJson(const {
      'title': 'Tandoor_(4310722187).jpg',
    });
    expect(bare.heading(true), 'Tandoor (4310722187)');
  });

  test('boş ve hata metinleri tabloda durur', () {
    expect(Tr.keys, contains(K.imageCreditsEmpty));
    expect(Tr.keys, contains(K.imageCreditsFailed));
  });
}
