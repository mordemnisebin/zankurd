import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/learner_lexicon.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/match_history.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/wildcard.dart';
import 'package:zankurd_mobile/src/screens/profile/profile_matches_section.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_wildcard_bar.dart';
import 'package:zankurd_mobile/src/screens/quiz/word_ordering_widget.dart';
import 'package:zankurd_mobile/src/widgets/rolling_count.dart';

import 'support/widget_test_helpers.dart';

/// Kurul 3 (2026-10-30, Astra + Terra + Sol; tam çözünürlüklü tur-3 kareleri,
/// Opus gözle doğruladı) uzlaşı listesinin bekçileri.
///
/// Bu kusurlar testte sessizdi çünkü eski bekçiler "metin/öğe var mı" diye
/// bakıyordu; oyuncunun durumu NASIL okuduğunu (kilitlenmiş mi, hangi renk
/// kime ait, "5/5" neyi sayıyor, "1–1" niçin galibiyet) ölçmüyordu.
void main() {
  Widget tile({required bool suspense, required bool selected}) => testShell(
    child: Material(
      child: QuizOptionTile(
        index: 0,
        answer: 'Jîn',
        selected: selected,
        correct: false,
        disabled: true,
        suspense: suspense,
        onTap: () {},
      ),
    ),
  );

  // D1 (3/3): hüküm beklenirken seçili şık yalnız beyaz çerçeveliydi; cevabın
  // kilitlendiği okunmuyordu. Seçili şıkta kilit; hüküm rengi/işareti yok.
  testWidgets('D1: beklemede seçili şıkta kilit, ✓/✕ yok', (tester) async {
    await tester.pumpWidget(tile(suspense: true, selected: true));
    expect(find.byKey(const ValueKey('locked_icon')), findsOneWidget);
    expect(find.byKey(const ValueKey('wrong_icon')), findsNothing);
    expect(find.byKey(const ValueKey('correct_icon')), findsNothing);
  });

  testWidgets('D1: hüküm açıkken kilit görünmez', (tester) async {
    await tester.pumpWidget(tile(suspense: false, selected: true));
    expect(find.byKey(const ValueKey('locked_icon')), findsNothing);
    expect(find.byKey(const ValueKey('wrong_icon')), findsOneWidget);
  });

  // D15 (3/3): sırayla düelloda eşit skorda galibiyet gerekçesizdi.
  testWidgets('D15: eşit skorlu sırayla düello galibiyeti hızla açıklanır', (
    tester,
  ) async {
    late String tie;
    late String plain;
    late String roomTie;
    await tester.pumpWidget(
      testShell(
        child: Builder(
          builder: (context) {
            RecentMatch m(RecentMatchKind kind, int a, int b) => RecentMatch(
              kind: kind,
              id: 'm',
              result: RecentMatchResult.win,
              playedAt: DateTime(2026, 10, 30),
              myScore: a,
              opponentScore: b,
            );
            tie = profileMatchSubtitle(context, m(RecentMatchKind.async, 1, 1));
            plain = profileMatchSubtitle(
              context,
              m(RecentMatchKind.async, 3, 1),
            );
            roomTie = profileMatchSubtitle(
              context,
              m(RecentMatchKind.room1v1, 2, 2),
            );
            return const SizedBox();
          },
        ),
      ),
    );
    expect(tie, contains(Tr.of(K.matchDecidedFaster, AppLanguage.tr)));
    expect(plain, isNot(contains('(')));
    expect(
      roomTie,
      isNot(contains('(')),
      reason: 'hız kuralı yalnız sırayla düelloda bilinir',
    );
  });

  // D19 (3/3): yazılı/sıralama sorusunda "Çift cevap" ne yaptığını
  // söylemiyordu; bu türlerde "İkinci deneme".
  testWidgets('D19: sıralama/yazılı soruda joker adı İkinci deneme', (
    tester,
  ) async {
    await tester.pumpWidget(
      testShell(
        child: Material(
          child: WildcardButton(
            type: WildcardType.doubleAnswer,
            isKu: false,
            isEnabled: true,
            isUsed: false,
            isAnswered: false,
            isActive: false,
            secondTry: true,
            onTap: () {},
          ),
        ),
      ),
    );
    expect(
      find.byTooltip(Tr.of(K.wildcardSecondTry, AppLanguage.tr)),
      findsOneWidget,
    );
  });

  // D21 (Astra + Sol): havuz ile cümle alanı tek kutu gibi okunuyordu.
  testWidgets('D21: cümle alanı ve kelime havuzu etiketli', (tester) async {
    const q = QuizQuestion(
      id: 'd21',
      category: 'Ziman',
      prompt: 'Hevokê rêz bike',
      answers: ['Ez', 'diçim', 'malê'],
      correctAnswer: 'Ez diçim malê',
      explanation: '',
      type: QuestionType.wordOrdering,
    );
    await tester.pumpWidget(
      testShell(
        child: Material(
          child: SingleChildScrollView(
            child: WordOrderingWidget(
              question: q,
              disabled: false,
              onAnswerSubmitted: (_) {},
            ),
          ),
        ),
      ),
    );
    expect(
      find.byKey(const ValueKey('word-ordering-sentence-label')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('word-ordering-pool-label')),
      findsOneWidget,
    );
  });

  // D22 (Sol, nesnel): oyunda "1.001", sonuçta "1432" — tek biçim.
  testWidgets('D22: sayım binlik ayırıcıyla yazar', (tester) async {
    await tester.pumpWidget(
      testShell(
        child: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: RollingCount(value: 1432, style: TextStyle()),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('1.432'), findsOneWidget);
  });

  // D11 (Astra + Sol): Kurmancî arayüzde Alfabe dersinin başlığı Türkçeydi.
  test('D11: Alfabe dersinin Kurmancî başlığı Kurmancî', () async {
    final lessons = await MockZanKurdRepository().loadLessonsByCategory(
      'everyday',
    );
    final alphabet = lessons.firstWhere((l) => l.id == 'alphabet_1');
    expect(alphabet.titleKu, 'Elîfbê');
    expect(alphabet.titleTr, 'Alfabe');
    expect(LearnerLexicon.sources['alphabet_1']?.titleKu, 'Elîfbê');
  });

  // D6 (3/3): slogan sorusu "Bilim" (Paradigma) turunda geliyordu.
  test(
    'D6: Jin, jiyan, azadî soruları Paradigma (Bilim) kategorisinde değil',
    () {
      final bank = MockZanKurdRepository().questions;
      final slogan = bank.where(
        (q) => q.prompt.toLowerCase().contains('jin, jiyan'),
      );
      expect(slogan, isNotEmpty);
      for (final q in slogan) {
        expect(q.category, isNot('Paradigma'), reason: q.id);
      }
    },
  );

  // D12/D14/D24/D25/D28/D29 metinleri: neyi saydığı/beklendiği yazar.
  test('D12/D14/D24/D25/D28/D29 metinleri', () {
    String tr(String k, [Map<String, String> p = const {}]) =>
        Tr.of(k, AppLanguage.tr, p);
    expect(tr(K.contestEndsInMin, {'m': '5'}), 'Bu tur 5 dk sonra biter');
    expect(tr(K.contestEndsInMin, {'m': '5'}), isNot(contains('0 sa')));
    expect(tr(K.challengeFriendWaitBody, {'name': 'Bero'}), contains('Yarış'));
    expect(tr(K.randomFindOpponent), 'Tüm konulardan rakip bul');
    expect(tr(K.roomCapacityLabel), 'En çok oyuncu');
    expect(tr(K.allLessonsMore, {'n': '15'}), contains('15 ders daha'));
    expect(tr(K.lessonSlideCounter, {'n': '5', 'total': '5'}), 'Slayt 5/5');
    expect(tr(K.xpEqualsScoreChip, {'n': '443'}), '+443 XP (puan kadar)');
  });
}
