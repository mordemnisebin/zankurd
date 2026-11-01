/// Tur 11 bekçisi: görselli soruda hiçbir şey yerinden oynamaz; üst künye
/// "·" ile satır başlamaz; büyük yazıda joker düğmeleri adsız kalmaz.
///
/// ## Kusurlar
///
/// 1. Görsel yüklenemeyince (ya da yüklenirken) yedek metin görselin sabit
///    kutusunun DIŞINDA çiziliyordu: 120-260 pt'lik kutu iki satırlık metne
///    çöküyor, soru ve şıklar yerinden oynuyordu; simülatörde sabit
///    koordinattaki dokunuş şık yerine "Çift cevap" jokerine düştü. Ayrıca
///    şık bütçesi görsel için sabit 144 pt düşüyordu (gerçek kutu başka).
/// 2. Künye "Soru 1/10 · Dil" iki satıra sarınca "·" yeni satırın başına
///    düşüyordu.
/// 3. Büyük yazıda joker adı düşüyor, düğmede yalnız ikon + fiyat kalıyordu.
///
/// ## Niçin sessiz kaldı
///
/// Testler görseli hep başarıyla yüklenen varlıkla ve tek kareyle ölçüyordu;
/// "yüklendikten/başarısız olduktan SONRA şıkların yeri aynı mı" diye kimse
/// iki kareyi karşılaştırmıyordu. Künye testleri metni bütün okuyordu, satır
/// kırılımını değil.
library;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/realistic_device.dart';
import 'support/widget_test_helpers.dart';

class _RichRepository extends MockZanKurdRepository {
  @override
  Future<int> loadCoinBalance() async => 500;
}

const _question = QuizQuestion(
  id: 'tur11-bozuk-gorsel',
  category: 'Çand',
  prompt: 'Görselde görünen çalgı hangisidir?',
  answers: ['Tembûr', 'Def', 'Zirne', 'Bilûr'],
  correctAnswer: 'Tembûr',
  explanation: 'Tembûr telli bir çalgıdır.',
  type: QuestionType.visual,
  imageUrl: 'asset://assets/__yok_tur11__.webp',
);

Future<void> _pump(
  WidgetTester tester,
  Size size,
  double scale, {
  QuizExperience experience = QuizExperience.learning,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  freshMockRepository();
  final repository = _RichRepository();
  await tester.pumpWidget(
    testShell(
      child: MediaQuery(
        data: MediaQueryData(
          size: size,
          padding: kPhoneInsets,
          viewPadding: kPhoneInsets,
          textScaler: TextScaler.linear(scale),
        ),
        child: QuizScreen(
          repository: repository,
          room: repository.createRoom(),
          questions: const [_question],
          enableTimer: false,
          experience: experience,
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(loadAppFonts);

  testWidgets('görsel yüklenemeyince şıklar ve görsel kutusu yerinde kalır', (
    tester,
  ) async {
    await _pump(tester, const Size(375, 667), 1.0);
    await tester.pump(); // ilk kare: görsel henüz hata vermedi
    final photo = find.byWidgetPredicate(
      (w) => w.runtimeType.toString() == '_QuestionImage',
    );
    final firstOption = find.byType(QuizOptionTile).first;
    final photoBefore = tester.getRect(photo);
    final optionBefore = tester.getRect(firstOption);
    await tester.pumpAndSettle(); // hata bildirildi, yedek çizildi
    expect(find.byKey(const ValueKey('quiz-image-load-failed')), findsOne);
    expect(tester.getRect(photo), photoBefore, reason: 'görsel kutusu sabit');
    expect(tester.getRect(firstOption), optionBefore, reason: 'şık oynamaz');
  });

  testWidgets('künye 320 px ve büyük yazıda "·" ile satır başlamaz', (
    tester,
  ) async {
    for (final scale in [1.0, 2.0]) {
      await _pump(tester, const Size(320, 640), scale);
      await tester.pumpAndSettle();
      final finder = find.byKey(const ValueKey('quiz-stage-kicker'));
      final paragraph = tester.renderObject<RenderParagraph>(finder);
      final text = tester.widget<Text>(finder).data!;
      final dot = text.indexOf('·');
      final painter = TextPainter(
        text: TextSpan(text: text, style: paragraph.text.style),
        textDirection: TextDirection.ltr,
        textScaler: paragraph.textScaler,
      )..layout(maxWidth: paragraph.size.width);
      final line = painter.getLineBoundary(TextPosition(offset: dot));
      expect(
        line.start,
        isNot(dot),
        reason: '"·" satır başında ($scale): $text',
      );
    }
  });

  testWidgets('yazı 2× joker düğmeleri görünür ad taşır', (tester) async {
    await _pump(
      tester,
      const Size(402, 874),
      2.0,
      experience: QuizExperience.competition,
    );
    await tester.pumpAndSettle();
    final names = find.byKey(const ValueKey('joker-name'));
    expect(names, findsWidgets, reason: 'büyük yazıda joker adı düşmemeli');
  });
}
