import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/providers/child_safety_provider.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Günlük jeton tavanının SEBEBİYLE gösterildiğinin bekçisi.
///
/// ## Kusur
///
/// `claim_solo_reward` tavana varıldığında
/// `{'amount': 0, 'daily_cap': 45, 'cap_reached': true}` döndürüyordu.
/// İstemci yalnız `amount`ı okuyup gerisini atıyordu.
///
/// Sonuç ekranındaki jeton rozeti `coinsAwarded > 0` koşuluna bağlı olduğu
/// için tavana varan tur ekranda HİÇBİR iz bırakmıyordu: oyuncu "+0" bile
/// görmüyordu, yalnız hiçbir şey görmüyordu. Sıfır tek başına belirsizdir —
/// tavan da sıfır verir, arıza da, göçün uygulanmamış olması da. Oyuncu
/// jeton kazanmayı bıraktığında sebebini öğrenemiyordu.
///
/// Sessizdi çünkü ödül yolunun dönüş tipi `int`ti: bilgi sunucudan çıkıp
/// istemcinin ilk satırında kayboluyordu, hiçbir test onu aramıyordu.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Widget wrap(Widget child, {String lang = 'tr'}) => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang(lang)),
      ChangeNotifierProvider<PremiumService>(
        create: (_) => PremiumService.fallback(),
      ),
      ChangeNotifierProvider<ChildSafetyProvider>(
        create: (_) => ChildSafetyProvider(),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );

  QuizResultScreen screen({required bool capReached, int coinsAwarded = 0}) {
    final repository = MockZanKurdRepository();
    return QuizResultScreen(
      repository: repository,
      room: repository.createRoom(),
      score: 400,
      correctCount: 4,
      wrongCount: 1,
      totalQuestions: 5,
      bestStreak: 3,
      coinsAwarded: coinsAwarded,
      dailyCapReached: capReached,
      answerRecords: const [
        AnswerRecord(
          id: 'q1',
          category: 'Ziman',
          prompt: 'Ev gotin çi wateyê dide?',
          answers: ['A', 'B', 'C', 'D'],
          correctAnswer: 'A',
          selectedAnswer: 'A',
          explanation: 'Rast bersiv A ye.',
        ),
      ],
    );
  }

  const noticeKey = ValueKey('result-daily-cap-notice');

  testWidgets('tavana varılınca sebep gösteriliyor', (tester) async {
    await tester.pumpWidget(wrap(screen(capReached: true)));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(
      find.byKey(noticeKey),
      findsOneWidget,
      reason:
          'Tavana varan tur ekranda hiçbir iz bırakmıyor. Oyuncu jeton '
          'kazanmayı bıraktığında sebebini öğrenemez.',
    );
    expect(find.text(Tr.forKu(K.soloDailyCapReached, false)), findsOneWidget);
  });

  testWidgets('tavana varılmadıysa satır çıkmıyor', (tester) async {
    // Korumanın öteki yarısı: sebep YOKKEN sebep uydurmak, sessizlikten
    // kötüdür. Sıfır jetonun başka nedenleri de var (arıza, göçün
    // uygulanmamış olması) ve onları "tavan" diye göstermek yanlış olurdu.
    await tester.pumpWidget(wrap(screen(capReached: false)));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byKey(noticeKey), findsNothing);
  });

  testWidgets('jeton kazanıldıysa tavan satırı çıkmıyor', (tester) async {
    // Tavan bayrağı gelse bile miktar sıfırdan büyükse mesaj yersizdir:
    // oyuncu bu turda jeton KAZANDI, sınıra bir sonrakinde çarpacak.
    await tester.pumpWidget(wrap(screen(capReached: true, coinsAwarded: 4)));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.byKey(noticeKey), findsNothing);
  });

  testWidgets('mesaj Kurmancî turda da var', (tester) async {
    await tester.pumpWidget(wrap(screen(capReached: true), lang: 'ku'));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text(Tr.forKu(K.soloDailyCapReached, true)), findsOneWidget);
  });
}
