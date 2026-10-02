import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/streak_store.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';

/// Seri kırılırken bakiye korumaya yetmiyorsa oyuncuya söylenir.
///
/// ## Kusur
///
/// Sonuç ekranında seri bu turda kırılacakken `_askForStreakFreeze`
/// bakiyeyi okuyor, `balance < 50` ise HİÇBİR ŞEY göstermeden `false`
/// dönüyordu. Bakiyesi 50'den az olan oyuncu serisinin (ör. 30 günlük)
/// sıfırlandığını sonuç ekranında görmüyor; korumanın var olduğunu, ona
/// kaç jeton eksik kaldığını ve jetonu nereden kazanacağını öğrenmiyordu.
/// Yeten bakiyede "Serin kırılıyor" diyen aynı ekran, yetmeyende sessizdi:
/// aynı olayın iki hâlinden biri anlatılmıyordu.
///
/// ## Niçin sessiz kaldı
///
/// Mevcut testler yalnız "bakiye yeter" yolunu ölçüyordu (teklif görünür,
/// kabul/ret seriyi doğru yazar). Yetmeme yolu "teklif yok" diye
/// doğruydu ve onu ölçen test yoktu; kırılma da bir hata değil, bilgi
/// eksikliğiydi, bu yüzden hiçbir şey kırmadı.
///
/// ## Kural
///
/// Yalnız bilgi: dialog eksik miktarı (`SahneShortfallNote`) ve çark
/// eylemini sunar; oyun akışı ve makbuz aşamaları DEĞİŞMEZ — seri aynen
/// sıfırlanır, soru her zaman "koruma yok" döner.
class _PoorRepository extends MockZanKurdRepository {
  _PoorRepository(this.coins);
  final int coins;

  @override
  Future<int> loadCoinBalance() async => coins;

  @override
  Future<bool> canSpinToday() async => true;
}

Widget _wrap(Widget child) => MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => LanguageProvider()..setLang('tr')),
    ChangeNotifierProvider<PremiumService>(
      create: (_) => PremiumService.fallback(),
    ),
  ],
  child: MaterialApp(theme: AppTheme.light(), home: child),
);

QuizResultScreen _screen(MockZanKurdRepository repository) => QuizResultScreen(
  repository: repository,
  room: repository.createRoom(),
  score: 1000,
  correctCount: 8,
  wrongCount: 2,
  totalQuestions: 10,
  bestStreak: 5,
  coinsAwarded: 0,
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

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'zankurd.streak.current': 3,
      'zankurd.streak.best': 3,
      'zankurd.streak.lastDay': '2020-01-01',
    });
    StreakStore.resetInstance();
  });

  testWidgets('bakiye yetmiyorsa eksik miktar söylenir, seri yine sıfırlanır', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_screen(_PoorRepository(10))));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Serin kırılıyor.'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('result-streak-shortfall')),
      findsOneWidget,
    );
    expect(find.text('40 jeton eksik'), findsOneWidget);
    // Teklif DEĞİL: koruma satın alma düğmesi yok.
    expect(find.text('Koru (50)'), findsNothing);

    await tester.tap(find.text('Anladım'));
    await tester.pumpAndSettle();

    // Akış değişmedi: seri normal recordPlay ile 1'e düştü.
    StreakStore.resetInstance();
    final store = await StreakStore.load();
    expect(store.effectiveStreak(), 1);
  });

  testWidgets('"Jeton kazan" çarkı açar', (tester) async {
    await tester.pumpWidget(_wrap(_screen(_PoorRepository(0))));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('50 jeton eksik'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('result-streak-earn-coins')));
    await tester.pumpAndSettle();
    expect(find.byType(SpinWheelScreen), findsOneWidget);
  });

  testWidgets('bakiye yeterse eskisi gibi teklif görünür, uyarı yok', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(_screen(_PoorRepository(50))));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('Koru (50)'), findsOneWidget);
    expect(find.byKey(const ValueKey('result-streak-shortfall')), findsNothing);
  });

  testWidgets('seri kırılmıyorsa uyarı da yok', (tester) async {
    SharedPreferences.setMockInitialValues({
      'zankurd.streak.current': 2,
      'zankurd.streak.best': 2,
      'zankurd.streak.lastDay':
          '${DateTime.now().year.toString().padLeft(4, '0')}-'
          '${DateTime.now().month.toString().padLeft(2, '0')}-'
          '${DateTime.now().day.toString().padLeft(2, '0')}',
    });
    StreakStore.resetInstance();
    await tester.pumpWidget(_wrap(_screen(_PoorRepository(0))));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('Serin kırılıyor.'), findsNothing);
  });
}
