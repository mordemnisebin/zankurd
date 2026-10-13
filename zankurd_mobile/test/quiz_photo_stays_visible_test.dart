/// Görselli soruda cevap verilince fotoğraf, başlık altında ince bir şeride
/// çökmemeli.
///
/// ## Kusur
///
/// Mağaza ekran görüntüsü turunda (2026-10-13, iPhone 17 Pro Max, gerçek
/// uygulama) Newroz fotoğraflı soruda cevap verilince fotoğraf, ilerleme
/// elmaslarının altında ince bir şeride düştü. Fotoğrafın yüksekliği
/// değişmiyordu; kayan gövde kayıyordu: cevaptan sonra `_revealExplanation`
/// "Açıklamayı gör" satırını görünür alanın ALT kenarına yaslayarak
/// `Scrollable.ensureVisible` çağırır ve fotoğraf gövdenin ilk öğesi
/// olduğundan, açıklama ne kadar aşağıdaysa o kadar yukarı kayıp üst
/// kenarın arkasında kaybolur.
///
/// ## Niçin sessiz kaldı
///
/// Varsayılan test yüzeyi 800×600'dür: içerik zaten kaydırılacak kadar
/// uzundur ya da hiç kaymaz, ve hiçbir test cevaptan SONRAKİ kaydırma
/// konumunda fotoğrafın görünür payını ölçmüyordu (var olan görselli test
/// yalnız cevaptan ÖNCE D şıkkının sığmasına bakıyordu). Kaydırma kodu
/// yalnız "hedef görünsün" der; başka neyin görünür kalacağına dair bir
/// sözleşmesi yoktu.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

const _question = QuizQuestion(
  id: 'photo-stays-visible',
  category: 'Çand',
  prompt:
      'Görselde Newroz ateşi görünüyor. Kültürde ve toplumsal bellekte ateş '
      'hangi kavramla daha çok ilişkilendirilir?',
  answers: [
    'Sessizlik ve unutuş',
    'Pazar ve ticaret',
    'Kış ve soğuk',
    'Umut ve yeniden doğuş',
  ],
  correctAnswer: 'Umut ve yeniden doğuş',
  explanation:
      'Newroz ateşi kışın bitişini ve baharın gelişini simgeler. Kürtler '
      'için ateş, zulme karşı direnişin ve yeniden doğuşun da simgesidir; '
      'bayram her yıl yaklaşık 21 Mart günü büyük şenliklerle kutlanır. '
      'Efsanede Kawa demirci, zalim Dehak’a karşı dağlarda ateş yakarak '
      'halkı ayaklanmaya çağırmıştır.',
  type: QuestionType.visual,
  imageUrl: 'asset://assets/zankurd.webp',
);

Finder get _photo =>
    find.byWidgetPredicate((w) => w.runtimeType.toString() == '_QuestionImage');

/// Fotoğrafın kayan alanın içinde görünen yüksekliği.
double _visiblePhotoHeight(WidgetTester tester) {
  final scroll = tester.getRect(
    find.byKey(const ValueKey('quiz-portrait-scroll')),
  );
  final photo = tester.getRect(_photo);
  final top = photo.top < scroll.top ? scroll.top : photo.top;
  final bottom = photo.bottom > scroll.bottom ? scroll.bottom : photo.bottom;
  return bottom > top ? bottom - top : 0;
}

void main() {
  setUpAll(loadAppFonts);

  // `answerMustShow`: yalnız normal yazıda hem fotoğraf hem doğru şık aynı
  // ekrana sığar; büyük yazıda ikisi sığmaz ve fotoğraf payı korunur, doğru
  // şık bir kaydırma ötede kalır (kullanıcı kaydırabilir; fotoğrafı geri
  // getirmek ise bağlamı yeniden aramaktır).
  for (final (name, size, textScale, answerMustShow) in [
    ('440×956 Pro Max', const Size(440, 956), 1.0, true),
    ('402×874', kPhoneSize, 1.0, true),
    ('440×956 Pro Max, yazı 1.5×', const Size(440, 956), 1.5, true),
    ('402×874, yazı 1.5×', kPhoneSize, 1.5, false),
    ('402×874, yazı 2×', kPhoneSize, 2.0, false),
  ]) {
    testWidgets(
      '$name: cevaptan sonra fotoğrafın en az 64pt\'si görünür kalır',
      (tester) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        revealCorrectAnswerInTests = true;
        addTearDown(() => revealCorrectAnswerInTests = false);

        final repository = freshMockRepository();
        await tester.pumpWidget(
          testShell(
            child: MediaQuery(
              data: MediaQueryData(
                size: size,
                padding: kPhoneInsets,
                viewPadding: kPhoneInsets,
                textScaler: TextScaler.linear(textScale),
              ),
              child: QuizScreen(
                repository: repository,
                room: repository.createRoom(),
                questions: const [_question],
                enableTimer: false,
                experience: QuizExperience.learning,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final photoHeight = tester.getSize(_photo).height;
        final before = _visiblePhotoHeight(tester);

        await tester.tap(find.byType(QuizOptionTile).first);
        // Açıklama denetleyicisi (800 ms) + kaydırma (320 ms).
        await tester.pump(const Duration(milliseconds: 900));
        await tester.pumpAndSettle();

        expect(
          tester.getSize(_photo).height,
          photoHeight,
          reason: 'Fotoğrafın kendi yüksekliği cevapla değişmemeli.',
        );
        final floor = photoHeight < 64 ? photoHeight : 64.0;
        expect(
          _visiblePhotoHeight(tester),
          greaterThanOrEqualTo(floor),
          reason:
              'Cevaptan sonra fotoğraf ince bir şeride düştü (önce: $before, '
              'sonra: ${_visiblePhotoHeight(tester)}).',
        );

        // Fotoğrafı korumak doğru şıkkı gömmemeli: doğru şık görünür alanda.
        final scroll = tester.getRect(
          find.byKey(const ValueKey('quiz-portrait-scroll')),
        );
        final correct = tester.getRect(
          find.widgetWithText(QuizOptionTile, 'Umut ve yeniden doğuş'),
        );
        if (answerMustShow) {
          expect(
            correct.top,
            lessThan(scroll.bottom),
            reason: 'Doğru şık görünür alanın altında kaldı ($correct).',
          );
        }
        expect(tester.takeException(), isNull);
      },
    );
  }
}
