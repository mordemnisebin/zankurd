// Erişilebilirlik matrisi: ana ekranlar × {gündüz, gece} × {Türkçe, Kurmancî}.
//
// Kusur (2026-10-02 denetimi): `accessibility_guideline_test.dart` ekranların
// yalnız GECE + TÜRKÇE hâlini ölçüyordu. Şahnê'nin gündüz teması ayrı bir
// renk takımı, Kurmancî ayrı (çoğu zaman daha uzun) metindir; ikisinde de
// kontrast, dokunma hedefi ve etiket sonucu değişebilir. Sessiz kalıyordu
// çünkü kılavuzlar yalnız çizilen kareyi ölçer ve test çizilmeyen kareyi hiç
// görmez: gündüzde bozulan bir kontrast, Kurmancî'de taşan bir satır hiçbir
// bekçiye takılmıyordu.
//
// Bu dosya dört kılavuzu (Android/iOS dokunma hedefi, etiketli dokunma
// hedefi, metin kontrastı) her ekran ve her tema/dil bileşimi için koşar ve
// başarısızlıkları TEK mesajda toplar (ilk kusurda durmaz; hangi ekran ve
// bileşimin bozulduğu bir bakışta görülür).
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/placement_store.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/learner_lexicon_screen.dart';
import 'package:zankurd_mobile/src/screens/level_placement_screen.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/screens/paywall_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/review_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_in_screen.dart';
import 'package:zankurd_mobile/src/screens/subcategory_screen.dart';

import 'support/widget_test_helpers.dart';

const _records = [
  AnswerRecord(
    id: 'r1',
    category: 'Ziman',
    prompt: 'Peyva «av» bi Tirkî çi tê gotin?',
    answers: ['su', 'ekmek', 'yol', 'dağ'],
    correctAnswer: 'su',
    selectedAnswer: 'su',
    explanation: '«av» Türkçede «su» demektir.',
    explanationKu: '«av» bi Tirkî dibe «su».',
    explanationTr: '«av» Türkçede «su» demektir.',
  ),
  AnswerRecord(
    id: 'r2',
    category: 'Çand',
    prompt: 'Çay li kîjan firaxê tê vexwarin?',
    answers: ['bardak', 'kase', 'sênî', 'beroş'],
    correctAnswer: 'bardak',
    selectedAnswer: 'kase',
    explanation: 'Çay genellikle «bardak» ile içilir.',
    explanationKu: 'Çay bi gelemperî di «bardak»ê de tê vexwarin.',
    explanationTr: 'Çay genellikle «bardak» ile içilir.',
  ),
];

typedef _Build = Widget Function(MockZanKurdRepository repository);

/// Ekranı çizdikten sonra çalışan, durumu ilerleten adım (ör. şık seçmek).
typedef _Then = Future<void> Function(WidgetTester tester);

/// İlk şıkka dokunur ve geri bildirim/açıklama animasyonlarının bitmesini
/// bekler: doğru/yanlış/seçili şıkların kontrastı yalnız cevaptan SONRA
/// çizilir ve ilk kareyi ölçen bekçi onu hiç görmezdi.
Future<void> _answerFirstOption(WidgetTester tester) async {
  final repository = freshMockRepository();
  await tester.tap(find.text(repository.questions.first.answers.first));
  await tester.pump();
  for (var i = 0; i < 12; i++) {
    await tester.pump(const Duration(milliseconds: 300));
  }
}

final Map<String, _Then> _thens = {
  'soru (cevaplandı)': _answerFirstOption,
  'ders sorusu (cevaplandı)': _answerFirstOption,
};

final Map<String, _Build> _screens = {
  'soru (cevaplandı)': (r) => QuizScreen(
    repository: r,
    room: r.createRoom().copyWith(questionCount: 1),
    questions: r.questions.take(1).toList(),
    enableTimer: false,
  ),
  'ders sorusu (cevaplandı)': (r) => QuizScreen(
    repository: r,
    room: r.createRoom().copyWith(questionCount: 1),
    questions: r.questions.take(1).toList(),
    experience: QuizExperience.learning,
    enableTimer: false,
  ),
  'seviye sınavı': (r) => LevelPlacementScreen(repository: r),
  'ana ekran': (r) => Scaffold(body: HomeScreen(repository: r)),
  'alt kategoriler': (r) => SubcategoryScreen(repository: r, category: 'Ziman'),
  'seviyeler': (r) => LevelScreen(repository: r, category: 'Ziman'),
  'soru': (r) => QuizScreen(
    repository: r,
    room: r.createRoom().copyWith(questionCount: 1),
    questions: r.questions.take(1).toList(),
    enableTimer: false,
  ),
  'ders sorusu': (r) => QuizScreen(
    repository: r,
    room: r.createRoom().copyWith(questionCount: 1),
    questions: r.questions.take(1).toList(),
    experience: QuizExperience.learning,
    enableTimer: false,
  ),
  'sonuç': (r) => QuizResultScreen(
    repository: r,
    room: r.createRoom(),
    score: 240,
    correctCount: 1,
    wrongCount: 1,
    totalQuestions: 2,
    bestStreak: 1,
    coinsAwarded: 30,
    answerRecords: _records,
  ),
  'tur özeti': (r) => ReviewScreen(room: r.createRoom(), records: _records),
  'öğrenme': (r) => LearningScreen(repository: r),
  'sözlük': (r) => const LearnerLexiconScreen(),
  'mağaza': (r) => ShopScreen(repository: r),
  'premium': (r) => PaywallScreen(repository: r),
  'sıralama': (r) => LeaderboardScreen(repository: r),
  'oyun merkezi': (r) => PlayHubScreen(repository: r),
  'oda lobisi': (r) => RoomScreen(repository: r, initialRoom: r.createRoom()),
  'ayarlar': (r) => SettingsScreen(repository: r),
  'karşılama': (r) => OnboardingScreen(onComplete: () {}),
  'giriş': (r) => const SignInScreen(),
};

/// Bir ekranı verilen bileşimde çizer ve dört kılavuzu koşar; kusurları
/// `ekran/tema/dil: kılavuz: sebep` satırları olarak döndürür.
Future<List<String>> _audit(
  WidgetTester tester,
  String name,
  _Build build, {
  required bool dark,
  required bool ku,
  double height = 844,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = Size(390, height);
  addTearDown(tester.view.reset);
  final handle = tester.ensureSemantics();
  await tester.pumpWidget(
    testShell(
      child: build(freshMockRepository()),
      themeProvider: ThemeProvider(
        initialMode: dark ? ThemeMode.dark : ThemeMode.light,
      ),
      languageProvider: ku ? kurmanciLang() : turkishLang(),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1600));
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  await tester.pump(const Duration(milliseconds: 1600));
  final then = _thens[name];
  if (then != null) await then(tester);

  // Olumsuz denetim: ekran gerçekten istenen bileşimde çizildi mi? Boş ya da
  // yanlış temada çizilmiş bir kare her kılavuzdan "geçer" ve bekçiyi
  // anlamsızlaştırır.
  final context = tester.element(find.byType(Navigator).first);
  final failures0 = <String>[];
  // Soru ve sonuç ekranları kasıtlı sabit gece sahnesidir (temadan bağımsız).
  const stageScreens = {'soru', 'ders sorusu', 'sonuç'};
  if (!stageScreens.contains(name) &&
      (Theme.of(context).brightness == Brightness.dark) != dark) {
    failures0.add('$name: tema istenen bileşimde değil');
  }
  if (find.byType(Text).evaluate().length < 3) {
    failures0.add('$name: ekran boş çizildi');
  }

  final tag =
      '$name${height > 900 ? ' (uzun)' : ''} / ${dark ? 'gece' : 'gündüz'} / ${ku ? 'KU' : 'TR'}';
  final guidelines = <String, AccessibilityGuideline>{
    'android dokunma': androidTapTargetGuideline,
    'iOS dokunma': iOSTapTargetGuideline,
    'etiketli dokunma': labeledTapTargetGuideline,
    'kontrast': textContrastGuideline,
  };
  final failures = <String>[...failures0];
  for (final entry in guidelines.entries) {
    final result = await entry.value.evaluate(tester);
    if (!result.passed) {
      failures.add('$tag: ${entry.key}: ${result.reason}');
    }
  }
  final overflow = tester.takeException();
  if (overflow != null) failures.add('$tag: istisna: $overflow');
  handle.dispose();
  return failures;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    PlacementStore.resetInstance();
  });

  for (final entry in _screens.entries) {
    for (final dark in [false, true]) {
      for (final ku in [false, true]) {
        testWidgets(
          'a11y: ${entry.key} / ${dark ? 'gece' : 'gündüz'} / ${ku ? 'KU' : 'TR'}',
          (tester) async {
            final failures = await _audit(
              tester,
              entry.key,
              entry.value,
              dark: dark,
              ku: ku,
            );
            expect(failures, isEmpty, reason: failures.join('\n'));
          },
        );
        testWidgets(
          'a11y (uzun görünüm): ${entry.key} / ${dark ? 'gece' : 'gündüz'} / ${ku ? 'KU' : 'TR'}',
          (tester) async {
            final failures = await _audit(
              tester,
              entry.key,
              entry.value,
              dark: dark,
              ku: ku,
              height: 2600,
            );
            expect(failures, isEmpty, reason: failures.join('\n'));
          },
        );
      }
    }
  }

  // En sıkışık gerçek koşul: 320 px genişlik, %200 yazı. Taşma Flutter'da
  // bir istisna olarak raporlanır; kılavuzlar taşmayı ölçmez (kırpılan metin
  // ya da dışarı çıkan düğme "dokunulur" ve "etiketli" kalır), bu yüzden
  // ayrı sorulur. Kurmancî metin Türkçeden uzundur, ikisi de koşulur.
  for (final entry in _screens.entries) {
    for (final ku in [false, true]) {
      testWidgets('taşma 320px/%200: ${entry.key} / ${ku ? 'KU' : 'TR'}', (
        tester,
      ) async {
        tester.view.devicePixelRatio = 1;
        tester.view.physicalSize = const Size(320, 640);
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          testShell(
            child: MediaQuery(
              data: const MediaQueryData(
                size: Size(320, 640),
                textScaler: TextScaler.linear(2),
              ),
              child: entry.value(freshMockRepository()),
            ),
            languageProvider: ku ? kurmanciLang() : turkishLang(),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1600));
        final then = _thens[entry.key];
        if (then != null) await then(tester);
        expect(tester.takeException(), isNull);
      });
    }
  }
}
