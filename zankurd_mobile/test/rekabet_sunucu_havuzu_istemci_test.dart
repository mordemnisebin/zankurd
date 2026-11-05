// 2.1.2 W10 — rekabetçi modlar için sunucu-yalnız soru havuzu (istemci tarafı).
//
// ## Kusur
//
// Rekabetçi modlarda (günün yarışması, oda, düello, turnuva) soru sunum anında
// sunucudan gelir ama metni yerel pakette de bulunduğundan değiştirilmiş bir
// istemci metni yerel bankada bulup cevabı okuyabilir. Kapanış: bu modların
// soruları pakette OLMAYAN `questions.server_only = true` satırlarından gelir
// (supabase/2026-11-17_rekabet_sunucu_havuzu.sql). İstemci bu satırları yerel
// bankada ARAMADAN, yalnız sunucu içeriğiyle göstermelidir.
//
// ## Niçin sessiz kalırdı
//
// Mevcut testlerin sahte depoları yerel bankadaki kimlikleri de içeriyordu ya da
// Türkçe karşılık alanı hiç yoktu: Türkçe seçen oyuncu sunucu sorusunu Kurmancî
// görüyordu ve yeni sütunlar (`prompt_tr`, `options_tr`) hiçbir yerde okunmuyordu.
// Bu dosya yerelde BULUNMAYAN kimliklerle akışı ve Türkçe karşılık sözleşmesini
// sabitler. Sunucu seçiminin kendisi: tool/test_rekabet_sunucu_havuzu_local.mjs.
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/server_daily_event_port.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

/// Yerel bankada OLMAYAN bir sunucu-yalnız soru satırı.
Map<String, dynamic> _row({
  String id = 'aaaaaaaa-0000-4000-8000-000000000001',
  String prompt = 'Paytexta Kurdistana Başûr kîjan e?',
  Object? promptTr = 'Güney Kürdistan\'ın başkenti hangisidir?',
  Object? optionsTr = const ['Hewlêr', 'Dihok', 'Silêmanî', 'Kerkûk'],
  String? correct,
  bool hidden = false,
}) => {
  'id': id,
  'index': 0,
  'category_name': 'Cografya',
  'prompt': hidden ? '' : prompt,
  if (hidden) 'content_hidden': true,
  'option_a': 'Hewlêr',
  'option_b': 'Dihok',
  'option_c': 'Silêmanî',
  'option_d': 'Kerkûk',
  'question_type': 'multiple_choice',
  'difficulty': 2,
  if (promptTr != null) 'prompt_tr': promptTr,
  if (optionsTr != null) 'options_tr': optionsTr,
  if (correct != null) 'correct_option': correct,
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('sunucu satırının Türkçe karşılığı (prompt_tr / options_tr)', () {
    test('alanlar ayrıştırılır; cevap gizliyken Türkçe küme tutarlıdır', () {
      final q = QuizQuestion.fromServerRow(_row());
      expect(q.hasHiddenAnswer, isTrue);
      expect(q.promptTr, startsWith('Güney'));
      expect(q.answersTr, ['Hewlêr', 'Dihok', 'Silêmanî', 'Kerkûk']);
      expect(q.promptFallsBackToKurmanci, isFalse);
      expect(q.promptFor(isKu: false), startsWith('Güney'));
      expect(q.promptFor(isKu: true), startsWith('Paytexta'));
    });

    test('Türkçe arayüzde soru + şıklar Türkçe, Kurmancîde Kurmancî', () {
      final row = _row()
        ..['option_a'] = 'Yek'
        ..['option_b'] = 'Du'
        ..['option_c'] = 'Sê'
        ..['option_d'] = 'Çar'
        ..['options_tr'] = ['Bir', 'İki', 'Üç', 'Dört'];
      final q = QuizQuestion.fromServerRow(row);
      final tr = q.localized(isKu: false);
      expect(tr.prompt, startsWith('Güney'));
      expect(tr.answers, ['Bir', 'İki', 'Üç', 'Dört']);
      expect(tr.answerLanguage, AnswerLanguage.turkish);
      // Şık anahtarı konumdan gelir: Türkçe 'İki' = B (sunucuya giden harf).
      expect(tr.optionKeyForAnswer('İki'), 'B');
      expect(q.localized(isKu: true).answers, ['Yek', 'Du', 'Sê', 'Çar']);
    });

    test(
      'cevap açılınca Türkçe doğru şık da dolar; Kurmancî doğru şık aynı',
      () {
        final row = _row()
          ..['option_a'] = 'Yek'
          ..['option_b'] = 'Du'
          ..['option_c'] = 'Sê'
          ..['option_d'] = 'Çar'
          ..['options_tr'] = ['Bir', 'İki', 'Üç', 'Dört'];
        final base = QuizQuestion.fromServerRow(row);
        final revealedKu = base.withRevealedAnswer(
          correctAnswer: base.answerForOptionKey('C')!,
        );
        expect(revealedKu.correctAnswer, 'Sê');
        expect(revealedKu.correctAnswerTr, 'Üç');
        expect(revealedKu.correctAnswerFor(isKu: false), 'Üç');
        expect(revealedKu.localized(isKu: false).correctAnswer, 'Üç');
        // Türkçe yansıtılmış model üzerinde açılış (oyun ekranı bunu yapar).
        final tr = base.localized(isKu: false);
        final revealedTr = tr.withRevealedAnswer(
          correctAnswer: tr.answerForOptionKey('C')!,
        );
        expect(revealedTr.correctAnswer, 'Üç');
        expect(revealedTr.hasHiddenAnswer, isFalse);
      },
    );

    test('Türkçe karşılık yoksa Kurmancî\'ye düşer ve etiket çıkar', () {
      final q = QuizQuestion.fromServerRow(
        _row(promptTr: null, optionsTr: null),
      );
      expect(q.promptTr, isNull);
      expect(q.answersTr, isNull);
      expect(q.promptFallsBackToKurmanci, isTrue);
      final tr = q.localized(isKu: false);
      expect(tr.prompt, startsWith('Paytexta'));
      expect(tr.answers, ['Hewlêr', 'Dihok', 'Silêmanî', 'Kerkûk']);
    });

    test('yarım ya da hizasız şık çevirisi bütünüyle yok sayılır', () {
      for (final bad in <Object?>[
        ['Bir', 'İki'], // eksik
        ['Bir', '', 'Üç', 'Dört'], // boş eleman
        'metin', // dizi değil
        [1, 2, 3, 4], // metin değil
      ]) {
        final q = QuizQuestion.fromServerRow(_row(optionsTr: bad));
        expect(q.answersTr, isNull, reason: '$bad');
        expect(q.localized(isKu: false).answers, q.answers);
      }
    });

    test('doğru-yanlış sorusunda kullanılmayan şık konumları atlanır', () {
      final row = {
        'id': 'bbbbbbbb-0000-4000-8000-000000000002',
        'prompt': 'Erbil bir şehirdir.',
        'option_a': 'Rast',
        'option_b': 'Şaş',
        'option_c': '-',
        'option_d': '',
        'question_type': 'true_false',
        'prompt_tr': 'Erbil bir şehirdir.',
        'options_tr': ['Doğru', 'Yanlış', null, null],
      };
      final q = QuizQuestion.fromServerRow(row);
      expect(q.answers, ['Rast', 'Şaş']);
      expect(q.answersTr, ['Doğru', 'Yanlış']);
    });

    test('içeriği gizli satır Türkçe metin taşımaz (sunumda gelir)', () {
      final q = QuizQuestion.fromServerRow(_row(hidden: true));
      expect(q.prompt, isEmpty);
      expect(q.promptTr, isNull);
    });

    test('yerel (cevabı bilinen) sorular eski tutarlılık kuralını korur', () {
      const local = QuizQuestion(
        id: 'local-1',
        category: 'Ziman',
        prompt: 'Kurmancî',
        answers: ['Yek', 'Du'],
        correctAnswer: 'Yek',
        explanation: '',
        promptTr: 'Türkçe',
        answersTr: ['Bir', 'İki'],
      );
      // correctAnswerTr yok -> kısmi çeviri: şıklar Kurmancî kalır.
      expect(local.localized(isKu: false).answers, ['Yek', 'Du']);
    });
  });

  group('yerelde bulunmayan sunucu-yalnız soru: akış çökmez', () {
    const unknownId = 'cccccccc-0000-4000-8000-000000000003';

    testWidgets(
      'oda: yerelde olmayan soru gösterilir, cevap açılır, sonuç çalışır',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        SharedPreferences.setMockInitialValues({
          'zankurd.quiz_tutorial.seen': true,
          'zankurd.navTour.seen': true,
        });
        freshMockRepository();
        final repo = MockZanKurdRepository();
        expect(
          repo.playableQuestions.any((q) => q.id == unknownId),
          isFalse,
          reason: 'kimlik yerel bankada YOK',
        );
        final question = QuizQuestion.fromServerRow(
          _row(id: unknownId, correct: 'A'),
        );
        await tester.pumpWidget(
          testShell(
            child: QuizScreen(
              repository: repo,
              room: repo
                  .createRoom(category: 'Cografya')
                  .copyWith(questionCount: 1, status: RoomStatus.active),
              questions: [question],
              enableTimer: false,
              suspenseHold: Duration.zero,
            ),
          ),
        );
        await tester.pumpAndSettle();
        // Test kabuğu Türkçe arayüzdür: sunucunun `prompt_tr` karşılığı gösterilir.
        expect(
          find.text("Güney Kürdistan'ın başkenti hangisidir?"),
          findsWidgets,
        );
        expect(find.text('Hewlêr'), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets('sonuç ekranı: sunucu kimlikli kayıtlar çökmeden çizilir', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      freshMockRepository();
      final repo = MockZanKurdRepository();
      final source = QuizQuestion.fromServerRow(
        _row(id: unknownId, correct: 'B'),
      ).withRevealedAnswer(correctAnswer: 'Dihok');
      await tester.pumpWidget(
        testShell(
          child: QuizResultScreen(
            repository: repo,
            room: repo.createRoom(category: 'Cografya'),
            score: 0,
            correctCount: 0,
            wrongCount: 1,
            totalQuestions: 1,
            bestStreak: 0,
            coinsAwarded: 0,
            sourceQuestions: [source],
            answerRecords: const [
              AnswerRecord(
                id: unknownId,
                category: 'Cografya',
                prompt: 'Paytexta Kurdistana Başûr kîjan e?',
                answers: ['Hewlêr', 'Dihok', 'Silêmanî', 'Kerkûk'],
                correctAnswer: 'Dihok',
                selectedAnswer: 'Hewlêr',
                explanation: '',
                responseMs: 4000,
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(find.byType(QuizResultScreen), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    test(
      'düello / turnuva yükü: Türkçe alanlar AsyncDuelStart ve sunumda okunur',
      () {
        final start = AsyncDuelStart.fromJson({
          'duel_id': '70000000-0000-4000-8000-000000000001',
          'role': 'creator',
          'expires_at': '2026-11-20T00:00:00Z',
          'questions': [_row(id: unknownId)],
        });
        expect(start.questions.single.promptTr, startsWith('Güney'));
        final present = TournamentPresent.fromJson({
          'elapsed_ms': 0,
          'question': _row(id: unknownId),
        });
        expect(present.question!.answersTr, hasLength(4));
        expect(present.question!.hasHiddenAnswer, isTrue);
      },
    );

    test('günlük sunum: Türkçe alanlar okunur, doğru şık YOK', () {
      final present = DailyEventPresent.fromJson({
        'elapsed_ms': 0,
        'limit_ms': 20000,
        'question': _row(id: unknownId),
      });
      expect(present.question.promptTr, startsWith('Güney'));
      expect(present.question.hasHiddenAnswer, isTrue);
    });
  });

  group('SQL sözleşmesi: göç kusuru kapatan parçaları içerir', () {
    final sql = File(
      'supabase/2026-11-17_rekabet_sunucu_havuzu.sql',
    ).readAsStringSync();

    test('bayrak varsayılanı KAPALI; sütunlar ve indeks eklemeli', () {
      expect(
        sql,
        contains(
          'add column if not exists competitive_server_only_pool boolean not null default false',
        ),
      );
      expect(
        sql,
        contains(
          'add column if not exists server_only boolean not null default false',
        ),
      );
      expect(sql, contains('add column if not exists prompt_tr text'));
      expect(sql, contains('add column if not exists options_tr jsonb'));
      expect(sql, contains('questions_server_only_pool_idx'));
      expect(sql, contains('(category_id, server_only, is_approved)'));
    });

    test('seçim tek ortak kapıdan yamalanır; solo seçimine dokunulmaz', () {
      expect(
        sql,
        contains("'public.weighted_question_pick(uuid[],uuid[],integer)'"),
      );
      expect(sql, contains("'public._w2_daily_set(date)'"));
      expect(sql, isNot(contains('prepare_verified_solo_questions')));
      expect(sql, isNot(contains('start_verified_quiz')));
      expect(sql, contains("'w10:' || p_imza"));
      expect(sql, contains('olcek_tur3_yedek'));
      expect(
        File(
          'supabase/geri_al/2026-11-17_rekabet_sunucu_havuzu_geri.sql',
        ).existsSync(),
        isTrue,
      );
    });

    test('eşik: tur başına gereken x 3; düşüş yorumla açıklanır', () {
      expect(sql, contains('v_need * 3'));
      expect(sql, contains('EŞİK VE DÜŞÜŞ'));
      expect(sql, contains('>= 30'));
    });

    test('applied.md bayrağın min build 46 ön koşulunu yazar', () {
      final applied = File('supabase/applied.md').readAsStringSync();
      final row = applied
          .split('\n')
          .firstWhere(
            (l) => l.contains('2026-11-17_rekabet_sunucu_havuzu.sql'),
          );
      expect(row, contains('⏳'));
      expect(row, contains('min'));
      expect(row, contains('46'));
      expect(row, contains('competitive_server_only_pool'));
    });
  });
}
