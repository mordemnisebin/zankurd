// 2.1.2 W2 — rekabetçi modlarda cevap anahtarı ve günlük yarışma akışı
// (ChatGPT Pro denetimi alan 1 #3-#4, alan 2 #2-#6, #13-#14).
//
// ## Kusurlar
//
// * Günün yarışmasında sunucu 10 gerçek soru kimliği verir; istemci kimlikleri
//   yerel bankayla eşleyip `correctAnswer`ı pakette bulur (#3/#4). Yeni akış
//   soruları sunulduğu anda, doğru şıksız sunucudan alır ve hükmü sunucudan
//   bekler; yerel değerlendirme YOKTUR.
// * Doğrulama zinciri: bir cevap RPC'sinin geçici hatası başarısız Future'ı
//   sonraki her cevabın ön koşulu yapıyordu; yeni RPC hiç gitmiyordu (#2).
// * Resmî liste alınamayınca yerel set sessizce `dailyQuiz: true` açılıyordu;
//   sıralamaya yazılmayan tur "yarışma" sanılıyordu (#13).
// * Sonuç gönderimi tek atımlıktı: "Tekrar dene" tamamlanmış Future'ı
//   bekliyor, kayıt hiç yeniden gönderilmiyordu (#5).
//
// ## Niçin sessiz kalırdı
//
// Sahte depolar soru kimliğini, doğru şıkkı ve sonucu hep anında/başarıyla
// döndürüyordu: ne bir RPC hatası ne bir sunucu hükmü beklemesi ne de resmî
// olmayan liste vardı. Bu dosya hatayı, gecikmeyi ve "resmî değil" durumunu
// zorlar. Sunucu tarafının gerçek davranışı: tool/test_rekabet_sunum_local.mjs.
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/server_daily_event_port.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/quiz_question.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';

import 'support/widget_test_helpers.dart';

const _round = '33333333-3333-4333-8333-333333333333';
const _realId = '11111111-1111-4111-8111-111111111111';

QuizQuestion _q(String id, String prompt) => QuizQuestion(
  id: id,
  category: 'Synthetic',
  prompt: prompt,
  answers: const ['A', 'B', 'C', 'D'],
  correctAnswer: 'A',
  explanation: '',
);

// ───────────────────────── HTTP düzeyi: depo davranışı ─────────────────────────

class _Rpc extends http.BaseClient {
  _Rpc(this.handler);
  final http.Response Function(String name, Map<String, dynamic> params)
  handler;
  final calls = <String>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final raw = await (request as http.Request).finalize().bytesToString();
    final decoded = raw.isEmpty ? null : jsonDecode(raw);
    final params = decoded is Map
        ? Map<String, dynamic>.from(decoded)
        : <String, dynamic>{};
    final name = request.url.pathSegments.last;
    calls.add(name);
    final response = handler(name, params);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: {'content-type': 'application/json'},
      request: request,
    );
  }
}

http.Response _json(Object? data, [int status = 200]) =>
    http.Response(jsonEncode(data), status);

http.Response _missing() =>
    _json({'code': 'PGRST202', 'message': 'Missing function'}, 404);

class _Repo extends SupabaseZanKurdRepository {
  _Repo(_Rpc rpc)
    : super(
        SupabaseClient('https://example.supabase.co', 'k', httpClient: rpc),
      );
  @override
  String? get currentUserId => 'synthetic-user';
  @override
  List<QuizQuestion> get playableQuestions => [_q(_realId, 'local')];
  @override
  Future<void> ensureProfile() async {}
  @override
  Future<User> signInAnonymously() async => const User(
    id: 'synthetic-user',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-11-01T00:00:00Z',
  );
}

Map<String, dynamic> _duelPayload() => {
  'duel_id': '70000000-0000-4000-8000-000000000001',
  'role': 'creator',
  'expires_at': '2026-11-20T00:00:00Z',
  'questions': [
    {'id': 'opaque-0', 'index': 0, 'prompt': '', 'content_hidden': true},
  ],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('doğrulama zinciri (#2)', () {
    test(
      'geçici bir cevap hatası sonraki cevapları ve ödülü ENGELLEMEZ; sıra korunur',
      () async {
        var answerCalls = 0;
        final rpc = _Rpc((name, params) {
          switch (name) {
            case 'start_verified_quiz':
              return _json('44444444-4444-4444-8444-444444444444');
            case 'answer_verified_quiz':
              answerCalls++;
              // İlk deneme: geçici sunucu hatası (503).
              return answerCalls == 1
                  ? _json({'message': 'upstream'}, 503)
                  : _json(true);
            case 'claim_verified_solo_reward':
              return _json({'amount': 6});
            default:
              throw StateError('Unexpected RPC: $name');
          }
        });
        final repo = _Repo(rpc);
        final questions = [_q('q-1', 'bir'), _q('q-2', 'iki')];
        await repo.startVerifiedSoloRound(
          clientRoundId: _round,
          questions: questions,
          daily: true,
        );
        await repo.recordVerifiedSoloAnswer(
          clientRoundId: _round,
          questionId: 'q-1',
          choice: 'A',
        );
        await repo.recordVerifiedSoloAnswer(
          clientRoundId: _round,
          questionId: 'q-2',
          choice: 'B',
        );
        final reward = await repo.awardSoloQuizCoins(
          score: 1,
          correctCount: 1,
          bestStreak: 1,
          totalQuestions: 2,
          clientRoundId: _round,
        );
        expect(reward.amount, 6);
        // q-1 yeniden gönderildi, SONRA q-2; ödeme ikisi de teslimden sonra.
        expect(rpc.calls, [
          'start_verified_quiz',
          'answer_verified_quiz', // q-1 (503)
          'answer_verified_quiz', // q-1 yeniden
          'answer_verified_quiz', // q-2
          'claim_verified_solo_reward',
        ]);
      },
    );
  });

  group('günün yarışması: sunucu-yetkili RPC sarmalayıcıları', () {
    test('yeni işlev yoksa (PGRST202) null: çağıran eski yola düşer', () async {
      final rpc = _Rpc((name, params) => _missing());
      final repo = _Repo(rpc);
      expect(await repo.startServerDailyEvent(), isNull);
      // Bir kez "yok" öğrenilince tekrar sorulmaz.
      expect(await repo.startServerDailyEvent(), isNull);
      expect(rpc.calls, ['start_verified_daily_v2']);
    });

    test('oturum ayrıştırılır; soru kimliği/içeriği alanı YOK', () async {
      final rpc = _Rpc(
        (name, params) => _json({
          'available': true,
          'round_id': _round,
          'day': '2026-11-16',
          'total': 10,
          'answered': 4,
          'correct': 3,
          'current_streak': 1,
          'best_streak': 2,
          'completed': false,
          'expired': false,
          'submitted': false,
          'elapsed_ms': 90000,
          'resumed': true,
        }),
      );
      final session = (await _Repo(rpc).startServerDailyEvent())!;
      expect(session.playable, isTrue);
      expect(session.answered, 4);
      expect(session.resumed, isTrue);
      expect(session.roundId, _round);
    });

    test(
      'sunum doğru şıksız içerik verir; cevap hükmü sunucudan gelir',
      () async {
        final rpc = _Rpc((name, params) {
          if (name == 'present_verified_daily_question') {
            return _json({
              'presented_at': '2026-11-16T10:00:00Z',
              'elapsed_ms': 0,
              'limit_ms': 20000,
              'question': {
                'id': 'opaque-token',
                'index': 4,
                'category_name': 'Ziman',
                'prompt': 'Soru?',
                'option_a': 'a',
                'option_b': 'b',
                'option_c': 'c',
                'option_d': 'd',
                'question_type': 'multiple_choice',
                'difficulty': 2,
              },
            });
          }
          expect(name, 'answer_verified_daily_question');
          expect(params, {'p_round': _round, 'p_index': 4, 'p_choice': 'B'});
          return _json({
            'accepted': true,
            'is_correct': true,
            'correct_option': 'B',
            'question_id': _realId,
            'answered': 5,
            'correct': 4,
            'completed': false,
            'explanation_ku': 'Rave',
          });
        });
        final repo = _Repo(rpc);
        final presented = await repo.presentServerDailyQuestion(_round, 4);
        expect(presented.question.hasHiddenAnswer, isTrue);
        expect(presented.question.id, 'opaque-token');
        final answer = await repo.answerServerDailyQuestion(
          roundId: _round,
          index: 4,
          choice: 'B',
        );
        expect(answer.isCorrect, isTrue);
        expect(answer.correctOption, 'B');
        expect(answer.questionId, _realId);
      },
    );

    test(
      'sonuç gönderimi geçici hatada GERÇEKTEN yeniden denenir (#5)',
      () async {
        var calls = 0;
        final rpc = _Rpc((name, params) {
          calls++;
          return calls < 3
              ? _json({'message': 'upstream'}, 503)
              : _json({'submitted': true, 'day': '2026-11-16'});
        });
        expect(await _Repo(rpc).submitServerDailyResult(_round), isTrue);
        expect(calls, 3);
      },
    );

    test('kesin sunucu reddi tekrarlanmaz; false döner', () async {
      final rpc = _Rpc(
        (name, params) => _json({'submitted': false, 'reason': 'late'}),
      );
      expect(await _Repo(rpc).submitServerDailyResult(_round), isFalse);
      expect(rpc.calls, hasLength(1));
    });

    test(
      'resmî liste alınamazsa yerel yedek RESMÎ DEĞİL diye işaretlenir (#13)',
      () async {
        final rpc = _Rpc((name, params) => _json({'message': 'down'}, 500));
        final repo = _Repo(rpc);
        await repo.loadDailyEventQuestions();
        expect(repo.lastDailyEventListWasOfficial, isFalse);
      },
    );
  });

  group('oda ve düello: opak belirteç yolları (alan 1 #4)', () {
    test(
      'oda soruları get_room_questions_v2 ile; yoksa eski işleve düşer',
      () async {
        final rpc = _Rpc((name, params) {
          if (name == 'get_room_questions_v2') return _missing();
          return _json([
            {
              'id': _realId,
              'category_name': 'Ziman',
              'prompt': 'x',
              'option_a': 'a',
              'option_b': 'b',
              'option_c': 'c',
              'option_d': 'd',
              'question_type': 'multiple_choice',
              'difficulty': 2,
            },
          ]);
        });
        final repo = _Repo(rpc);
        final room = repo
            .createRoom(category: 'Ziman')
            .copyWith(id: '00000000-0000-0000-0000-000000000001');
        final loaded = await repo.loadRoomQuestions(room);
        expect(loaded.single.id, _realId);
        await repo.loadRoomQuestions(room);
        expect(rpc.calls, [
          'get_room_questions_v2',
          'get_room_questions',
          'get_room_questions', // v2 yok bilgisi önbellekte: tekrar sorulmaz
        ]);
      },
    );

    test(
      'düello başlangıcı start_async_duel_masked ile; yoksa eskiye düşer',
      () async {
        final rpc = _Rpc((name, params) {
          if (name.endsWith('_masked')) return _missing();
          return _json(_duelPayload());
        });
        final start = await _Repo(rpc).startAsyncDuel(category: 'Ziman');
        expect(start.questions.single.id, 'opaque-0');
        expect(rpc.calls.first, 'start_async_duel_masked');
        expect(rpc.calls, contains('start_async_duel'));
      },
    );

    test('düello maskeli yol varsa eski sarmalayıcı HİÇ çağrılmaz', () async {
      final rpc = _Rpc((name, params) => _json(_duelPayload()));
      await _Repo(rpc).startAsyncDuel(category: 'Ziman');
      expect(rpc.calls, ['start_async_duel_masked']);
    });
  });

  group('SQL sözleşmesi: dosyalar kusuru kapatan parçaları içerir', () {
    test('yeni göç: sunumda doğru şık yok, süre sunucuda, yeni nesneler', () {
      final sql = File(
        'supabase/2026-11-16_rekabet_sunum.sql',
      ).readAsStringSync();
      expect(sql, contains('public.start_verified_daily_v2()'));
      expect(sql, contains('present_verified_daily_question'));
      expect(sql, contains('answer_verified_daily_question'));
      expect(sql, contains('submit_verified_daily_event_result_v2'));
      expect(sql, contains('get_room_questions_v2'));
      expect(sql, contains('start_async_duel_masked'));
      expect(sql, contains('v_limit_ms constant integer := 20000'));
      // Sunum yanıtı (question nesnesi) doğru şık anahtarı taşımaz.
      final present = sql.substring(
        sql.indexOf('create function public.present_verified_daily_question'),
        sql.indexOf('create function public.answer_verified_daily_question'),
      );
      expect(present, isNot(contains('correct_option')));
      expect(present, isNot(contains("'question_id'")));
      // Mevcut işlev gövdelerine dokunulmadığı göç içinde doğrulanır.
      expect(sql, contains('mevcut bir işlevin gövdesi değişti'));
      expect(
        sql,
        isNot(
          contains('create or replace function public.start_verified_quiz'),
        ),
      );
    });

    test('guard göçü: md5 ön koşulu, yedek, geri alma ve kapanan yollar', () {
      final sql = File(
        'supabase/2026-11-17_rekabet_sunum_guard.sql',
      ).readAsStringSync();
      expect(sql, contains("'w2:' || p_imza"));
      expect(sql, contains('olcek_tur3_yedek'));
      expect(sql, contains('Daily rounds start with start_verified_daily_v2'));
      expect(sql, contains('revoke select on public.room_questions'));
      expect(
        sql,
        contains(
          'revoke execute on function public.get_verified_daily_question_ids()',
        ),
      );
      expect(
        File(
          'supabase/geri_al/2026-11-17_rekabet_sunum_guard_geri.sql',
        ).existsSync(),
        isTrue,
      );
    });

    test(
      'istemci kusur önceki RPC adlarına bağlı kalmaz: yeni adlar kullanılır',
      () {
        final source = File(
          'lib/src/data/supabase_zankurd_repository.dart',
        ).readAsStringSync();
        for (final name in [
          "'start_verified_daily_v2'",
          "'present_verified_daily_question'",
          "'answer_verified_daily_question'",
          "'submit_verified_daily_event_result_v2'",
          "'get_room_questions_v2'",
          "'start_async_duel_masked'",
          "'create_async_duel_challenge_masked'",
          "'accept_async_duel_challenge_masked'",
          "'resume_my_async_duel_masked'",
        ]) {
          expect(source, contains(name));
        }
        expect(
          File('supabase/applied.md').readAsStringSync(),
          contains('2026-11-16_rekabet_sunum.sql'),
        );
      },
    );
  });

  // ───────────────────────── Widget düzeyi ─────────────────────────

  group('günün yarışması ekranı', () {
    testWidgets(
      'resmî liste alınamazsa sessizce başlamaz: antrenman diyaloğu; vazgeçince tur açılmaz (#13)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        freshMockRepository();
        final repo = _PortRepo()..official = false;
        await tester.pumpWidget(
          testShell(child: ContestScreen(repository: repo)),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('contest-start')));
        await tester.pumpAndSettle();
        expect(find.text('Antrenman olarak oynansın mı?'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('contest-practice-cancel')));
        await tester.pumpAndSettle();
        expect(find.byType(QuizScreen), findsNothing);

        await tester.tap(find.byKey(const ValueKey('contest-start')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('contest-practice-play')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        final quiz = tester.widget<QuizScreen>(find.byType(QuizScreen));
        expect(
          quiz.dailyQuiz,
          isFalse,
          reason: 'antrenman günlük tur sayılmaz',
        );
        expect(quiz.serverDaily, isNull);
      },
    );

    testWidgets('resmî liste alınabildiyse diyalog yok; dailyQuiz: true', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      freshMockRepository();
      final repo = _PortRepo()..official = true;
      await tester.pumpWidget(
        testShell(child: ContestScreen(repository: repo)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('contest-start')));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(find.text('Antrenman olarak oynansın mı?'), findsNothing);
      expect(
        tester.widget<QuizScreen>(find.byType(QuizScreen)).dailyQuiz,
        isTrue,
      );
    });

    testWidgets(
      'yarım oturum kaldığı soruda devam eder: sunum o indeks için çağrılır, içerik sunucudan (#3)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        SharedPreferences.setMockInitialValues({
          'zankurd.quiz_tutorial.seen': true,
          'zankurd.navTour.seen': true,
        });
        freshMockRepository();
        final repo = _PortRepo()
          ..session = const DailyEventSession(
            available: true,
            roundId: _round,
            answered: 4,
            correct: 3,
            currentStreak: 1,
            bestStreak: 2,
            resumed: true,
          );
        await tester.pumpWidget(
          testShell(child: ContestScreen(repository: repo)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('contest-start')));
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));
        expect(repo.log, ['present:4']);
        final quiz = tester.widget<QuizScreen>(find.byType(QuizScreen));
        expect(quiz.serverDaily, isNotNull);
        expect(quiz.questions.length, 10);
        expect(quiz.questions[4].prompt, 'Sunucu sorusu 4');
        // Başka hiçbir soruda içerik/kimlik yok.
        for (var i = 0; i < 10; i++) {
          if (i != 4) expect(quiz.questions[i].prompt, isEmpty);
        }
        expect(find.text('Sunucu sorusu 4'), findsWidgets);
      },
    );

    testWidgets(
      'bitmiş ama gönderilmemiş tur açılışta tamamlanır; yazılamazsa açık mesaj (#5)',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(390, 900));
        addTearDown(() => tester.binding.setSurfaceSize(null));
        freshMockRepository();
        final repo = _PortRepo()
          ..session = const DailyEventSession(
            available: true,
            roundId: _round,
            answered: 10,
            correct: 8,
            completed: true,
          )
          ..submitResults = [false];
        await tester.pumpWidget(
          testShell(child: ContestScreen(repository: repo)),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('contest-start')));
        await tester.pumpAndSettle();
        expect(repo.log, ['submit']);
        expect(find.text('Sonuç kaydedilemedi. Tekrar dene.'), findsOneWidget);
        expect(find.byType(QuizScreen), findsNothing);
      },
    );
  });

  group('oyun ekranı: sunucu hükmü', () {
    Future<void> pumpQuiz(
      WidgetTester tester,
      _PortRepo repo, {
      int answered = 2,
    }) async {
      await tester.binding.setSurfaceSize(const Size(390, 900));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      SharedPreferences.setMockInitialValues({
        'zankurd.quiz_tutorial.seen': true,
        'zankurd.navTour.seen': true,
      });
      final session = DailyEventSession(
        available: true,
        roundId: _round,
        answered: answered,
        correct: answered,
        resumed: true,
      );
      final first = await repo.presentServerDailyQuestion(_round, answered);
      repo.log.clear();
      await tester.pumpWidget(
        testShell(
          child: QuizScreen(
            repository: repo,
            room: repo
                .createRoom(category: 'Tevlihev')
                .copyWith(
                  questionCount: 10,
                  secondsPerQuestion: kDailyEventSecondsPerQuestion,
                ),
            questions: [
              for (var i = 0; i < 10; i++)
                i == answered
                    ? first.question
                    : _q('pending-$i', '').copyWith(
                        prompt: '',
                        answers: const [],
                        correctAnswer: '',
                      ),
            ],
            enableTimer: false,
            dailyQuiz: true,
            serverDaily: ServerDailyRound(
              port: repo,
              session: session,
              firstElapsedMs: 0,
            ),
            suspenseHold: Duration.zero,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'cevap sunucuya gider, hüküm sunucudan gelir, sonraki soru sunumla açılır',
      (tester) async {
        freshMockRepository();
        final repo = _PortRepo()..answerCorrect = true;
        await pumpQuiz(tester, repo);
        expect(find.text('Sunucu sorusu 2'), findsWidgets);

        // Cevap beklemede: hüküm henüz yok.
        final gate = Completer<void>();
        repo.answerGate = gate;
        await tester.tap(find.text('ans-b').first);
        await tester.pump();
        expect(repo.log, ['answer:2:B']);
        expect(find.byKey(const ValueKey('quiz-next-button')), findsOneWidget);

        gate.complete();
        await tester.pumpAndSettle();
        // Sunucu doğru şıkkı cevaptan SONRA açtı; gerçek kimlik soruya yazıldı.
        final state = tester.state<State<QuizScreen>>(find.byType(QuizScreen));
        expect(state, isNotNull);

        await tester.tap(find.byKey(const ValueKey('quiz-next-button')));
        await tester.pumpAndSettle();
        expect(repo.log, ['answer:2:B', 'present:3']);
        expect(find.text('Sunucu sorusu 3'), findsWidgets);
      },
    );

    testWidgets(
      'cevap ağ hatasıyla düşerse YEREL değerlendirme yok; seçim açılır, yeniden denenebilir',
      (tester) async {
        freshMockRepository();
        final repo = _PortRepo()..answerFailuresLeft = 1;
        await pumpQuiz(tester, repo);
        await tester.tap(find.text('ans-a').first);
        await tester.pumpAndSettle();
        expect(repo.log, ['answer:2:A']);
        expect(find.text('Cevap gönderilemedi. Tekrar dene.'), findsOneWidget);
        // Hüküm bilinmiyor: ilerleme/sonraki yok, seçim yeniden açık.
        await tester.tap(find.text('ans-a').first);
        await tester.pumpAndSettle();
        expect(repo.log, ['answer:2:A', 'answer:2:A']);
      },
    );
  });

  group('sonuç ekranı: gerçek yeniden deneme (#5)', () {
    testWidgets('sonuç yazılamadı satırı + Tekrar dene sonucu YENİDEN gönderir', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(const Size(390, 1600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      freshMockRepository();
      final repo = _PortRepo()..submitResults = [false, true];
      await tester.pumpWidget(
        testShell(
          child: QuizResultScreen(
            repository: repo,
            room: repo.createRoom(),
            score: 70,
            correctCount: 7,
            wrongCount: 3,
            totalQuestions: 10,
            bestStreak: 3,
            coinsAwarded: 0,
            dailyQuiz: true,
            serverDaily: true,
            roundId: _round,
            answerRecords: const [
              AnswerRecord(
                id: 'a',
                category: 'Ziman',
                prompt: 'p',
                answers: ['x', 'y'],
                correctAnswer: 'x',
                selectedAnswer: 'x',
                explanation: '',
                responseMs: 12000,
              ),
            ],
          ),
        ),
      );
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
      expect(repo.log, ['submit']);
      expect(
        find.byKey(const ValueKey('daily-event-save-failed')),
        findsOneWidget,
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('daily-event-save-retry')),
      );
      await tester.tap(find.byKey(const ValueKey('daily-event-save-retry')));
      await tester.pumpAndSettle();
      expect(repo.log, [
        'submit',
        'submit',
      ], reason: 'aynı tamamlanmış Future değil, yeni gönderim');
      expect(
        find.byKey(const ValueKey('daily-event-save-failed')),
        findsNothing,
      );
      // Eski kusur: eski akış kendi yazımını yapmaz (yalnız sunucu-yetkili tur).
      expect(repo.dailyEventSubmissions, isEmpty);
    });
  });

  test('yeni l10n anahtarları iki dilde dolu', () {
    for (final key in [
      K.contestPracticeTitle,
      K.contestPracticeBody,
      K.contestPracticePlay,
      K.contestAlreadyDone,
      K.contestExpired,
      K.contestResumed,
      K.contestResultNotSaved,
    ]) {
      expect(Tr.of(key, AppLanguage.tr).trim(), isNotEmpty);
      expect(Tr.of(key, AppLanguage.ku).trim(), isNotEmpty);
    }
  });
}

/// Günlük port + yerel Mock: sunucu davranışı denetlenebilir.
class _PortRepo extends MockZanKurdRepository implements ServerDailyEventPort {
  final log = <String>[];
  bool official = true;
  DailyEventSession? session;
  List<bool> submitResults = [true];
  Completer<void>? answerGate;
  bool answerCorrect = true;
  int answerFailuresLeft = 0;

  @override
  bool get lastDailyEventListWasOfficial => official;

  @override
  Future<DailyEventSession?> startServerDailyEvent() async => session;

  @override
  Future<DailyEventPresent> presentServerDailyQuestion(
    String roundId,
    int index,
  ) async {
    log.add('present:$index');
    return DailyEventPresent(
      question:
          const QuizQuestion(
            id: 'opaque',
            category: 'Tevlihev',
            prompt: '',
            answers: [],
            correctAnswer: '',
            explanation: '',
          ).copyWith(
            prompt: 'Sunucu sorusu $index',
            answers: const ['ans-a', 'ans-b', 'ans-c', 'ans-d'],
          ),
      elapsedMs: 0,
    );
  }

  @override
  Future<DailyEventAnswer> answerServerDailyQuestion({
    required String roundId,
    required int index,
    required String choice,
  }) async {
    log.add('answer:$index:$choice');
    await answerGate?.future;
    if (answerFailuresLeft > 0) {
      answerFailuresLeft--;
      throw const SocketException('offline');
    }
    return DailyEventAnswer(
      isCorrect: answerCorrect,
      correctOption: 'B',
      questionId: _realId,
      answered: index + 1,
      correct: index + 1,
      completed: false,
    );
  }

  @override
  Future<bool> submitServerDailyResult(String roundId) async {
    log.add('submit');
    return submitResults.length > 1
        ? submitResults.removeAt(0)
        : submitResults.first;
  }
}
