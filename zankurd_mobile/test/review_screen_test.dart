// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/review_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

Widget _wrap(Widget child) {
  return ChangeNotifierProvider<LanguageProvider>(
    create: (_) => LanguageProvider()..setLang('tr'),
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );
}

const _room = GameRoom(
  name: 'Oda',
  code: 'ZK-TEST',
  category: 'Ziman',
  players: [],
  status: RoomStatus.finished,
  questionCount: 3,
);

void main() {
  testWidgets('boş kayıt listesinde boş durum mesajı gösterir', (tester) async {
    await tester.pumpWidget(
      _wrap(const ReviewScreen(records: [], room: _room)),
    );

    expect(find.text('Hiç cevap kaydı yok.'), findsOneWidget);
  });

  testWidgets('doğru, yanlış ve boş cevap sayılarını özetler', (tester) async {
    const records = [
      AnswerRecord(
        id: 'q1',
        category: 'Ziman',
        prompt: 'Soru 1',
        answers: ['A', 'B'],
        correctAnswer: 'A',
        selectedAnswer: 'A',
        explanation: '',
      ),
      AnswerRecord(
        id: 'q2',
        category: 'Ziman',
        prompt: 'Soru 2',
        answers: ['A', 'B'],
        correctAnswer: 'A',
        selectedAnswer: 'B',
        explanation: '',
      ),
      AnswerRecord(
        id: 'q3',
        category: 'Ziman',
        prompt: 'Soru 3',
        answers: ['A', 'B'],
        correctAnswer: 'A',
        selectedAnswer: null,
        explanation: '',
      ),
    ];

    await tester.binding.setSurfaceSize(const Size(390, 1400));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      _wrap(const ReviewScreen(records: records, room: _room)),
    );

    expect(find.text('1 doğru · 1 yanlış · 1 boş'), findsOneWidget);
    expect(find.text('DOĞRU'), findsOneWidget);
    expect(find.text('YANLIŞ'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('BOŞ BIRAKILDI'), 300);
    expect(find.text('BOŞ BIRAKILDI'), findsOneWidget);
  });

  testWidgets('şıkta doğru/yanlış işaretleme ve açıklama panelini gösterir', (
    tester,
  ) async {
    const records = [
      AnswerRecord(
        id: 'q1',
        category: 'Ziman',
        prompt: 'Hilbijêre',
        answers: ['Rast', 'Şaş'],
        correctAnswer: 'Rast',
        selectedAnswer: 'Şaş',
        explanation: 'Açıklama metni burada.',
      ),
    ];

    await tester.pumpWidget(
      _wrap(const ReviewScreen(records: records, room: _room)),
    );

    expect(find.text('Hilbijêre'), findsOneWidget);
    // Doğru şık ✓ taşır. ✗ iki yerdedir: seçilen yanlış şıkta ve
    // 2026-09-29 Şahnê'den beri kartın durum rozetinde ("YANLIŞ" — durum
    // hiçbir zaman yalnız renkle verilmez, `SahneStatusBadge`).
    expect(find.byIcon(AppIcons.check), findsOneWidget);
    expect(find.byIcon(AppIcons.xmark), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byType(SahneStatusBadge),
        matching: find.byIcon(AppIcons.xmark),
      ),
      findsOneWidget,
    );
    expect(find.text('Açıklama metni burada.'), findsOneWidget);
  });

  testWidgets(
    'flashcard kategori çipi Türkçe turda çevrilmiş görünür (2026-08-14)',
    (tester) async {
      // Kategori kimliği veri katmanında Kurmancî sabittir (`CategoryNames`
      // deftere göre "Ziman" → "Dil"). Kart eskiden `record.category`yi
      // ham basıyordu; Türkçe turda kart hâlâ "Ziman" yazıyordu.
      const records = [
        AnswerRecord(
          id: 'q1',
          category: 'Ziman',
          prompt: 'Hilbijêre',
          answers: ['Rast', 'Şaş'],
          correctAnswer: 'Rast',
          selectedAnswer: 'Şaş',
          explanation: '',
        ),
      ];

      await tester.pumpWidget(
        _wrap(const ReviewScreen(records: records, room: _room)),
      );

      await tester.tap(find.text('Kelime kartları'));
      await tester.pumpAndSettle();

      // 2026-09-29 Şahnê: kategori rozeti (`SahneBadge`) Etiket
      // biçemindedir — yerele duyarlı büyük harf ("Dil" → "DİL").
      expect(find.text('DİL'), findsOneWidget);
      expect(find.text('Ziman'), findsNothing);
      expect(find.text('ZIMAN'), findsNothing);
    },
  );

  // 2026-09-29 Şahnê: arka yüz gece sahne kartıdır; "Doğru cevap:" durum
  // rengi Rast metni (✓ ikonuyla), "Açıklama:" öğrenme rolünün metni.
  // Eskiden eski yeşilin / morun "okunur" tonları ölçülüyordu; mor palet
  // dışıdır ve kalktı.
  testWidgets('flashcard arka yüz etiketleri gece sahnesinde okunur tonda', (
    tester,
  ) async {
    const records = [
      AnswerRecord(
        id: 'q1',
        category: 'Ziman',
        prompt: 'Hilbijêre',
        answers: ['Rast', 'Şaş'],
        correctAnswer: 'Rast',
        selectedAnswer: 'Şaş',
        explanation: 'Açıklama metni burada.',
      ),
    ];

    await tester.pumpWidget(
      _wrap(const ReviewScreen(records: records, room: _room)),
    );
    await tester.tap(find.text('Kelime kartları'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('review-flashcard')));
    await tester.pumpAndSettle();

    final correct = tester.widget<Text>(find.text('Doğru cevap:'));
    expect(correct.style?.color, SahneTokens.night.okTx);

    final explanation = tester.widget<Text>(find.text('Açıklama:'));
    expect(explanation.style?.color, SahneTokens.night.learnTx);
  });

  testWidgets('flashcard ön ve arka yüzü tek actionable semantics nodeudur', (
    tester,
  ) async {
    const records = [
      AnswerRecord(
        id: 'q1',
        category: 'Ziman',
        prompt: 'Hilbijêre',
        answers: ['Rast', 'Şaş'],
        correctAnswer: 'Rast',
        selectedAnswer: 'Şaş',
        explanation: 'Açıklama metni burada.',
      ),
    ];
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      _wrap(const ReviewScreen(records: records, room: _room)),
    );
    await tester.tap(find.text('Kelime kartları'));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('review-flashcard'));
    var data = tester.getSemantics(card).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
    expect(data.label, contains('Soru (ön yüz)'));
    expect(data.label, contains('Hilbijêre'));
    expect(data.label, contains('Cevabı görmek için dokun'));
    expect(data.label, isNot(contains('Doğru Cevap')));
    expect(find.bySemanticsLabel('Soru (ön yüz)'), findsNothing);

    await tester.tap(card);
    await tester.pumpAndSettle();

    data = tester.getSemantics(card).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
    expect(data.label, contains('Cevap (arka yüz)'));
    expect(data.label, contains('Doğru cevap:'));
    expect(data.label, contains('Rast'));
    expect(data.label, contains('Açıklama:'));
    expect(data.label, contains('Açıklama metni burada.'));
    expect(data.label, isNot(contains('Cevabı görmek için dokun')));
    expect(find.bySemanticsLabel('Cevap (arka yüz)'), findsNothing);
    semantics.dispose();
  });

  testWidgets('flashcard Kurmancî ön ve arka semantics güncellenir', (
    tester,
  ) async {
    const records = [
      AnswerRecord(
        id: 'q1',
        category: 'Ziman',
        prompt: 'Hilbijêre',
        answers: ['Rast', 'Şaş'],
        correctAnswer: 'Rast',
        selectedAnswer: 'Şaş',
        explanation: 'Ravekirina testê.',
      ),
    ];
    final semantics = tester.ensureSemantics();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(
            create: (_) => LanguageProvider()..setLang('ku'),
          ),
        ],
        child: const MaterialApp(
          home: ReviewScreen(records: records, room: _room),
        ),
      ),
    );
    await tester.tap(find.text('Kartên peyvan'));
    await tester.pumpAndSettle();

    final card = find.byKey(const ValueKey('review-flashcard'));
    var data = tester.getSemantics(card).getSemanticsData();
    expect(data.label, contains('Pirs (rû)'));
    expect(data.label, contains('Ji bo dîtina bersivê bitikîne'));

    await tester.tap(card);
    await tester.pumpAndSettle();

    data = tester.getSemantics(card).getSemanticsData();
    expect(data.flagsCollection.isButton, isTrue);
    expect(data.hasAction(ui.SemanticsAction.tap), isTrue);
    expect(data.label, contains('Bersiv (pişt)'));
    expect(data.label, contains('Bersiva rast:'));
    expect(data.label, contains('Şîrove:'));
    expect(data.label, contains('Ravekirina testê.'));
    semantics.dispose();
  });

  testWidgets('şık listesinde olmayan yazılı kullanıcı yanıtını gösterir', (
    tester,
  ) async {
    const records = [
      AnswerRecord(
        id: 'fill-1',
        category: 'Ziman',
        prompt: 'Ez ___ dixwînim.',
        answers: ['pirtûk'],
        correctAnswer: 'pirtûk',
        selectedAnswer: 'PIRTIK',
        explanation: '',
        adjudicatedCorrect: false,
      ),
    ];

    await tester.pumpWidget(
      _wrap(const ReviewScreen(records: records, room: _room)),
    );

    expect(find.text('Senin cevabın: PIRTIK'), findsOneWidget);
    expect(find.text('pirtûk'), findsOneWidget);
  });

  testWidgets('süre aşımı teknik yanıt metni olarak gösterilmez', (
    tester,
  ) async {
    const records = [
      AnswerRecord(
        id: 'timeout-1',
        category: 'Ziman',
        prompt: 'Hilbijêre',
        answers: ['Rast', 'Şaş'],
        correctAnswer: 'Rast',
        selectedAnswer: 'TIMEOUT',
        explanation: '',
        adjudicatedCorrect: false,
      ),
    ];

    await tester.pumpWidget(
      _wrap(const ReviewScreen(records: records, room: _room)),
    );

    expect(find.byKey(const ValueKey('review-typed-answer')), findsNothing);
    expect(find.textContaining('TIMEOUT'), findsNothing);
  });

  testWidgets('yanlış cevap varsa tekrar eylemi görünür', (tester) async {
    const records = [
      AnswerRecord(
        id: 'practice-1',
        category: 'Ziman',
        prompt: 'Hilbijêre',
        answers: ['Rast', 'Şaş'],
        correctAnswer: 'Rast',
        selectedAnswer: 'Şaş',
        explanation: '',
      ),
    ];

    await tester.pumpWidget(
      _wrap(const ReviewScreen(records: records, room: _room)),
    );

    final action = find.byKey(const ValueKey('review-practice-cta'));
    expect(action, findsOneWidget);
    expect(
      find.descendant(of: action, matching: find.text('Tekrara başla')),
      findsOneWidget,
    );
  });
}
