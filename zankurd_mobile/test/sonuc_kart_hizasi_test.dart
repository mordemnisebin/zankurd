// 7. tasarım kurulu (2026-10-20), sonuç ekranı: (a) Doğru/Yanlış/Üst üste
// satırında ikon ve sayı kart kenarına yapışıktı (Gemini); (b) "Nerelerde
// zorlandın?" kartında çıplak ampul başlıkla hizasız yüzüyordu (Opus, Grok).
//
// ## Niçin sessiz kalırdı
//
// İkisi de taşma ya da hata değil, yalnızca boşluk/hizalama: `Row` her
// düzenle geçerli, overflow testleri ve metin testleri yeşil kalır. Bekçi
// geometriyi ölçer: sayım kartının iç boşluğu ≥ 16, ampul 36 px kutuda ve
// başlıkla üst kenarı aynı hizada, başlık 15/600.
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/widgets/learning_outcome_card.dart';

Widget _wrap(Widget child) => ChangeNotifierProvider<LanguageProvider>(
  create: (_) => LanguageProvider()..setLang('tr'),
  child: MaterialApp(
    theme: AppTheme.light(),
    home: Scaffold(body: Center(child: child)),
  ),
);

void main() {
  testWidgets('sayım satırı kart kenarından en az 16 px içeride durur', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        const ResultStatTiles(correct: 2, wrong: 1, unanswered: 0, streak: 2),
      ),
    );
    final card = tester.getRect(find.byType(ResultStatTiles));
    final icon = tester.getRect(find.byIcon(AppIcons.check));
    expect(icon.left - card.left, greaterThanOrEqualTo(16));
  });

  // 2026-10-27 (iki cihazlı düello, iPhone Air ≈ 388 pt içerik): dört kutu
  // tek sıraya girince "Doğru" "Doğr/u" diye ortadan kırılıyordu. Dört kutu
  // bu genişlikte ikişerli dizilir; hiçbir etiket ikinci satıra taşmaz.
  testWidgets('dar telefonda dört kutu ikişerli, etiket kırılmaz', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420, 900));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16),
          child: ResultStatTiles(
            correct: 2,
            wrong: 1,
            unanswered: 8,
            streak: 1,
          ),
        ),
      ),
    );
    final correct = tester.getRect(find.text('Doğru'));
    final blank = tester.getRect(find.text('Boş'));
    expect(
      blank.top,
      greaterThan(correct.bottom),
      reason: 'ikişerli dizilmeli',
    );
    // 'En uzun seri' çok sözcüklüdür: ikişerli kutuda SÖZCÜK sınırında
    // sarabilir (harf harf kırılmaz); tek satır şartı kısa etiketlere.
    for (final label in ['Doğru', 'Yanlış', 'Boş']) {
      final para = tester.renderObject<RenderParagraph>(find.text(label));
      expect(para.didExceedMaxLines, isFalse, reason: label);
      expect(
        tester.getSize(find.text(label)).height,
        lessThan(30),
        reason: '$label tek satır olmalı',
      );
    }
  });

  testWidgets('zorlandın kartı: ampul 36 px kutuda, başlıkla üstten hizalı, '
      'başlık 15/600', (tester) async {
    final outcome = LearningOutcome.fromRecords(const [
      AnswerRecord(
        id: '1',
        category: 'Tarih',
        prompt: 'Pirs',
        answers: ['A', 'B'],
        correctAnswer: 'A',
        selectedAnswer: 'B',
        explanation: 'x',
      ),
    ]);
    await tester.pumpWidget(
      _wrap(
        LearningOutcomeCard(
          outcome: outcome,
          onReview: () {},
          showCounts: false,
        ),
      ),
    );
    final box = tester.getRect(
      find
          .ancestor(
            of: find.byIcon(AppIcons.lightbulb),
            matching: find.byType(SizedBox),
          )
          .first,
    );
    expect(box.size, const Size(36, 36));
    final titleFinder = find.text('Nerelerde zorlandın?');
    final title = tester.widget<Text>(titleFinder);
    expect(title.style?.fontSize, 15);
    expect(title.style?.fontWeight, FontWeight.w600);
    // Başlığın satır kutusu 36'lık kutunun üst kenarında başlar.
    expect(tester.getRect(titleFinder).top - box.top, lessThan(8));
  });
}
