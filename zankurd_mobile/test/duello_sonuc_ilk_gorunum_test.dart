import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

/// Canlı düello sonucunun İLK görünümü kaydırmadan eksiksizdir.
///
/// ## Kusur
///
/// 2026-10-29 iPhone 17 Pro turu (402x874): "Kazanıldı" kartı alt perdenin
/// altında yarım kalıyor, XP/jeton çipleri kaydırınca görünüyordu. Sonucun
/// üç bilgisi (kazandın/kaybettin, skor, ödül) ilk bakışta okunmalı.
///
/// ## Niçin sessiz kalabilirdi
///
/// Sonuç sayfası bir `ListView`; içerik perdenin altında kalınca taşma hatası
/// değil, yalnızca kırpılmış bir kart doğar. Bekçi bu yüzden taşmaya değil,
/// ödül kartının alt kenarının perdenin üst kenarından yukarıda olmasına
/// bakar.
QuizResultScreen _duel() {
  final repository = MockZanKurdRepository();
  return QuizResultScreen(
    repository: repository,
    room: repository.createRoom(),
    score: 539,
    correctCount: 3,
    wrongCount: 6,
    totalQuestions: 10,
    bestStreak: 2,
    coinsAwarded: 20,
    answerRecords: const [
      AnswerRecord(
        id: 'q1',
        category: 'Ziman',
        prompt: 'Soru?',
        answers: ['A', 'B', 'C', 'D'],
        correctAnswer: 'A',
        selectedAnswer: 'B',
        explanation: 'Rast bersiv A ye.',
      ),
    ],
    opponents: const [
      Player(id: 'opp', name: 'QaAlı', score: 1082, state: 'Online'),
    ],
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  for (final (size, scale) in [
    (const Size(402, 874), 1.0),
    (const Size(375, 667), 1.0),
    (const Size(375, 667), 1.3),
  ]) {
    testWidgets('düello sonucu ilk görünümde eksiksiz (${size.width}x'
        '${size.height}, x$scale)', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider(
              create: (_) => LanguageProvider()..setLang('tr'),
            ),
            ChangeNotifierProvider<PremiumService>(
              create: (_) => PremiumService.fallback(),
            ),
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(
                context,
              ).copyWith(textScaler: TextScaler.linear(scale)),
              child: child!,
            ),
            home: _duel(),
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 2));
      expect(tester.takeException(), isNull);
      // 375x667'de %130 yazıda alt perde tek başına ekranın ~%34'ü: ilk
      // görünüme sonuç + skor + sayımlar sığar, ödül kartı bir kaydırma
      // ötededir (kaçınılmaz; bkz. rapor). Orada bekçi kaydırınca sayımların
      // ve ödül kartının perdenin üstünde eksiksiz görünmesine bakar.
      final preDockTop = tester.getRect(find.byType(SahneResultDock)).top;
      // Dört sayım çipi de ekranda ve perdenin üstünde (hiçbiri düşmez).
      for (final label in ['Doğru', 'Yanlış', 'Boş', 'En uzun seri']) {
        final chip = find.text(label);
        expect(chip, findsOneWidget, reason: '$label çipi yok');
        expect(
          tester.getRect(chip).bottom,
          lessThanOrEqualTo(preDockTop),
          reason: '$label perdenin altında',
        );
      }
      final scrolled = scale > 1.0 && size.height < 760;
      if (scrolled) {
        await tester.ensureVisible(find.byType(SahneResultRewards));
        await tester.pump(const Duration(milliseconds: 600));
      }

      // Alt perde = "Cevapları gör" düğmesi + eylem satırı.
      final seeAnswers = find.byKey(
        const ValueKey('result-see-answers-button'),
      );
      var dockTop = tester.getRect(find.byType(SahneResultDock)).top;
      if (seeAnswers.evaluate().isNotEmpty) {
        dockTop = tester.getRect(seeAnswers).top;
      }
      final rewards = tester.getRect(find.byType(SahneResultRewards));
      expect(
        rewards.bottom,
        lessThanOrEqualTo(dockTop),
        reason: 'ödül kartı alt perdenin altında kalıyor: $rewards / $dockTop',
      );
      // Sonuç başlığı, büyük skor ve ödül çipi ekranda.
      for (final key
          in scrolled
              ? const <ValueKey<String>>[]
              : const [
                  ValueKey('result-score-count'),
                  ValueKey('result-duel-faceoff'),
                ]) {
        final r = tester.getRect(find.byKey(key));
        expect(r.top, greaterThanOrEqualTo(0), reason: '$key');
        expect(r.bottom, lessThanOrEqualTo(dockTop), reason: '$key');
      }
      if (!scrolled) {
        expect(find.text(Tr.forKu(K.youLost, false)), findsOneWidget);
      }
      expect(find.text('+20'), findsOneWidget, reason: 'jeton çipi');
      expect(
        tester.getRect(find.text('+20')).bottom,
        lessThanOrEqualTo(dockTop),
      );
    });
  }
}
