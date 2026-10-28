/// Düello sonucu: soru soru karşılaştırma + rövanş (istemci) bekçisi.
///
/// ## Kusur
///
/// Sonuç ekranı yalnız "5–3" diyordu: oyuncu hangi soruyu bildiğini, rakibin
/// neyi yanlış yaptığını ve doğru cevabı göremiyordu (QuizClash / Trivia
/// Crack'in en çok açılan ekranı). Kaybettikten sonra aynı rakiple tek
/// dokunuşla yeniden oynamak da yoktu.
///
/// ## Niçin sessiz kalırdı
///
/// Bölüm yeni bir RPC'ye (`get_async_duel_review`) bağlıdır. Göç uygulanmamış
/// sunucuda RPC yoktur; ekran bunu "hata" diye çizerse (ya da rövanş
/// düğmesini uygunluğu bilmeden gösterirse) her sonuç ekranı kırık görünür.
/// Engelli çiftte rakibin adı/cevapları ekrana sızarsa hiçbir derleme testi
/// görmez.
///
/// ## Kural
///
/// * Model: sunucu JSON'u ayrıştırılır; boş/'-' şık atılır; `my`/`opp` null =
///   cevapsız (yanlış DEĞİL).
/// * RPC yok (`PGRST202`) → `null`: ne bölüm ne rövanş düğmesi.
/// * Satırlar: soru (en çok 2 satır), doğru cevap, benim ve rakibin cevabı
///   ✓/✗ + süre; süre dolan cevap "Süre doldu" der.
/// * Engelli çift: rakip adı yerine "Rakip", rakip satırı yok, not görünür,
///   rövanş kapalı.
/// * Rövanş: yalnız `can_rematch` iken açık; basınca aynı rakibe arkadaş
///   meydan okuması (`createAsyncDuelChallenge(friendId)`) açılır.
/// * 320 px ve %200 yazıda taşma yok.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/offline_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_play_screen.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_result_screen.dart';

import 'support/widget_test_helpers.dart';

const _longPrompt =
    'Kîjan ji van bajaran di dîroka Kurdistanê de wekî paytexta '
    'mîrnişîna Botan dihat nasîn û li ser çemê Dîcleyê hatiye avakirin?';

Map<String, dynamic> _questionJson(
  int index, {
  Object? mine = 'dogru',
  Object? opp = 'yanlis',
  String? prompt,
  String correct = 'B',
  String optionD = 'Çaralî',
}) {
  Map<String, dynamic>? answer(Object? kind, int ms) => switch (kind) {
    'dogru' => {'choice': correct, 'correct': true, 'ms': ms},
    'yanlis' => {'choice': 'A', 'correct': false, 'ms': ms},
    'sure' => {'choice': 'TIMEOUT', 'correct': false, 'ms': 20000},
    _ => null,
  };
  return {
    'index': index,
    'prompt': prompt ?? 'Pirsa $index',
    'option_a': 'Yekem',
    'option_b': 'Duyem',
    'option_c': 'Sêyem',
    'option_d': optionD,
    'question_type': 'multiple_choice',
    'correct_option': correct,
    'my': answer(mine, 3200),
    'opp': answer(opp, 5400),
  };
}

Map<String, dynamic> _reviewJson({
  bool blocked = false,
  bool canRematch = true,
  bool friend = true,
  bool forfeit = false,
  String? opponentId = 'opp-1',
  String? opponentName = 'Rojda',
  List<Map<String, dynamic>>? questions,
}) => {
  'duel_id': 'duel-1',
  'status': 'completed',
  'forfeit': forfeit,
  'opponent_id': blocked ? null : opponentId,
  'opponent_name': blocked ? null : opponentName,
  'opponent_blocked': blocked,
  'opponent_is_friend': friend,
  'can_rematch': canRematch,
  'questions':
      questions ??
      [
        for (var i = 0; i < 7; i++)
          _questionJson(
            i,
            mine: i == 1 ? 'yanlis' : (i == 2 ? 'sure' : 'dogru'),
            opp: blocked ? null : (i == 3 ? 'sure' : 'yanlis'),
          ),
      ],
};

class _ReviewHttpClient extends http.BaseClient {
  _ReviewHttpClient(this.status, this.body);

  final int status;
  final Object? body;
  final requestedPaths = <String>[];
  final requestBodies = <Map<String, dynamic>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    requestedPaths.add(request.url.path);
    if (request is http.Request && request.body.isNotEmpty) {
      requestBodies.add(
        Map<String, dynamic>.from(jsonDecode(request.body) as Map),
      );
    }
    final bytes = utf8.encode(jsonEncode(body));
    return http.StreamedResponse(
      Stream.value(bytes),
      status,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

class _SignedInRepository extends SupabaseZanKurdRepository {
  _SignedInRepository(super.client);

  @override
  Future<User> signInAnonymously() async => const User(
    id: 'test-user',
    appMetadata: {},
    userMetadata: {},
    aud: 'authenticated',
    createdAt: '2026-09-01T00:00:00.000Z',
    isAnonymous: true,
  );

  @override
  Future<void> ensureProfile() async {}
}

/// İncelemeyi sabitleyen ve rövanş çağrısını kaydeden depo.
class _ReviewRepository extends MockZanKurdRepository {
  _ReviewRepository({this.review, this.error});

  AsyncDuelReview? review;
  Object? error;
  int loads = 0;
  final rematchFriendIds = <String?>[];

  @override
  Future<AsyncDuelReview?> loadAsyncDuelReview(String duelId) async {
    loads++;
    if (error != null) throw error!;
    return review;
  }

  @override
  Future<AsyncDuelStart> createAsyncDuelChallenge({
    String? category,
    String? friendId,
  }) {
    rematchFriendIds.add(friendId);
    return super.createAsyncDuelChallenge(
      category: category,
      friendId: friendId,
    );
  }

  @override
  Future<List<Friend>> loadFriends() async => [
    Friend(
      id: 'f-1',
      userId: 'me',
      friendId: 'opp-1',
      friendName: 'Rojda',
      createdAt: DateTime.utc(2026, 10, 1),
    ),
  ];
}

AsyncDuelSummary _completedSummary({String id = 'duel-1'}) => AsyncDuelSummary(
  duelId: id,
  status: AsyncDuelStatus.completed,
  role: AsyncDuelRole.opponent,
  opponentName: 'Rojda',
  opponentId: 'opp-1',
  myCorrect: 5,
  opponentCorrect: 3,
  outcome: AsyncDuelOutcome.win,
  createdAt: DateTime.utc(2026, 10, 24),
  seen: true,
);

/// Oyun ekranını sökmeden bitirmek bekleyen sayaçlara takılır: ağacı boşaltıp
/// süreyi ileri sarar.
Future<void> _leave(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 25));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'zankurd.onboarding.seen': true});
  });

  group('AsyncDuelReview.fromJson', () {
    test('7 soru, şıklar, doğru şık, iki tarafın cevabı', () {
      final review = AsyncDuelReview.fromJson(_reviewJson());
      expect(review.questions, hasLength(7));
      expect(review.opponentName, 'Rojda');
      expect(review.canRematch, isTrue);
      expect(review.hasOpponentAnswers, isTrue);

      final q0 = review.questions[0];
      expect(q0.options.keys, ['A', 'B', 'C', 'D']);
      expect(q0.correctOption, 'B');
      expect(q0.correctText, 'Duyem');
      expect(q0.mine!.correct, isTrue);
      expect(q0.mine!.ms, 3200);
      expect(q0.choiceText(q0.mine!), 'Duyem');
      expect(q0.opponent!.correct, isFalse);
      expect(q0.choiceText(q0.opponent!), 'Yekem');

      // Süre dolan cevap: şık yok.
      final q2 = review.questions[2];
      expect(q2.mine!.timedOut, isTrue);
      expect(q2.choiceText(q2.mine!), isNull);
    });

    test('boş ve "-" şıklar atılır (doğru/yanlış sorusu)', () {
      final q = AsyncDuelReviewQuestion.fromJson({
        ..._questionJson(0, correct: 'A'),
        'option_c': '-',
        'option_d': '  ',
        'question_type': 'true_false',
      });
      expect(q.options.keys, ['A', 'B']);
    });

    test('cevapsız soru null kalır (yanlış sayılmaz)', () {
      final review = AsyncDuelReview.fromJson(
        _reviewJson(
          forfeit: true,
          questions: [_questionJson(0, mine: null, opp: 'dogru')],
        ),
      );
      expect(review.isForfeit, isTrue);
      expect(review.questions.single.mine, isNull);
      expect(review.questions.single.opponent, isNotNull);
    });

    test('engelli çift: kimlik/ad yok, rakip cevabı yok', () {
      final review = AsyncDuelReview.fromJson(_reviewJson(blocked: true));
      expect(review.opponentBlocked, isTrue);
      expect(review.opponentId, isNull);
      expect(review.opponentName, isNull);
      expect(review.hasOpponentAnswers, isFalse);
    });

    test('eksik bayraklar eski/boş yanıtta güvenli varsayılan', () {
      final review = AsyncDuelReview.fromJson({
        'duel_id': 'x',
        'questions': <Object?>[],
      });
      expect(review.canRematch, isFalse);
      expect(review.opponentBlocked, isFalse);
      expect(review.isForfeit, isFalse);
    });

    test('hata sınıfı: bitmedi / katılımcı değil beklenen, gerisi geçici', () {
      expect(
        classifyAsyncDuelReviewError(Exception('Duel not finished')),
        AsyncDuelReviewError.notAvailable,
      );
      expect(
        classifyAsyncDuelReviewError(Exception('Not a duel player')),
        AsyncDuelReviewError.notAvailable,
      );
      expect(
        classifyAsyncDuelReviewError(Exception('Duel not found')),
        AsyncDuelReviewError.notAvailable,
      );
      expect(
        classifyAsyncDuelReviewError(Exception('socket closed')),
        AsyncDuelReviewError.other,
      );
    });
  });

  group('depo', () {
    test('Supabase: doğru RPC adı ve parametre, yanıt ayrıştırılır', () async {
      final http_ = _ReviewHttpClient(200, _reviewJson());
      final repo = _SignedInRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: http_,
        ),
      );
      final review = await repo.loadAsyncDuelReview('duel-1');
      expect(http_.requestedPaths, ['/rest/v1/rpc/get_async_duel_review']);
      expect(http_.requestBodies.single, {'p_duel_id': 'duel-1'});
      expect(review!.questions, hasLength(7));
    });

    test('Supabase: RPC yoksa (PGRST202) null — hata değil', () async {
      final http_ = _ReviewHttpClient(404, {
        'code': 'PGRST202',
        'message': 'Could not find the function public.get_async_duel_review',
        'details': null,
        'hint': null,
      });
      final repo = _SignedInRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: http_,
        ),
      );
      expect(await repo.loadAsyncDuelReview('duel-1'), isNull);
    });

    test('Supabase: süren düello reddi fırlatılır (sınıflanabilir)', () async {
      final http_ = _ReviewHttpClient(400, {
        'code': 'P0001',
        'message': 'Duel not finished',
        'details': null,
        'hint': null,
      });
      final repo = _SignedInRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: http_,
        ),
      );
      Object? caught;
      try {
        await repo.loadAsyncDuelReview('duel-1');
      } catch (error) {
        caught = error;
      }
      expect(caught, isNotNull);
      expect(
        classifyAsyncDuelReviewError(caught!),
        AsyncDuelReviewError.notAvailable,
      );
    });

    test('çevrimdışı depo fırlatır', () async {
      expect(
        () => OfflineZanKurdRepository().loadAsyncDuelReview('x'),
        throwsA(isA<StateError>()),
      );
    });

    test('mock: biten düello kendi cevaplarımla incelenir, süren düello '
        'reddedilir', () async {
      final repo = MockZanKurdRepository();
      final start = await repo.startAsyncDuel();
      // Süren düello: ikinci taraf yok, ben de bitirmedim.
      await expectLater(
        repo.loadAsyncDuelReview(start.duelId),
        throwsA(
          predicate(
            (e) =>
                e != null &&
                classifyAsyncDuelReviewError(e) ==
                    AsyncDuelReviewError.notAvailable,
          ),
        ),
      );
      repo.asyncDuelReviewSupportedForTesting = false;
      expect(await repo.loadAsyncDuelReview(start.duelId), isNull);
    });
  });

  group('hükmen kazanma etiketi (null yazmaz)', () {
    // Eski sunucu `forfeit` bayrağını göndermez; kazanılmış ama rakibin
    // skoru olmayan düello "Kazandın · 5–null" diye okunuyordu.
    AsyncDuelSummary win({bool forfeit = false}) => AsyncDuelSummary(
      duelId: 'd',
      status: AsyncDuelStatus.expired,
      role: AsyncDuelRole.creator,
      opponentName: 'Rojda',
      myCorrect: 5,
      opponentCorrect: null,
      outcome: AsyncDuelOutcome.win,
      isForfeit: forfeit,
      createdAt: DateTime.utc(2026, 10, 24),
      seen: true,
    );

    testWidgets('rakip skoru yoksa durum etiketi hükmen metni', (tester) async {
      late String label;
      await tester.pumpWidget(
        testShell(
          child: Builder(
            builder: (context) {
              label = asyncDuelStatusLabel(
                context,
                AsyncDuelResultView.fromSummary(win()),
              );
              return const SizedBox.shrink();
            },
          ),
        ),
      );
      expect(label, 'Kazandın · hükmen');
      expect(label, isNot(contains('null')));
    });

    testWidgets('sonuç ekranı da "null" yazmaz', (tester) async {
      await tester.pumpWidget(
        testShell(
          child: AsyncDuelResultScreen(
            repository: _ReviewRepository(),
            view: AsyncDuelResultView.fromSummary(win()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.textContaining('null'), findsNothing);
      expect(find.text('Kazandın · hükmen'), findsOneWidget);
    });

    test('bayraklı hükmen de aynı', () {
      expect(
        AsyncDuelResultView.fromSummary(win(forfeit: true)).isForfeit,
        isTrue,
      );
    });
  });

  group('ekran', () {
    Future<void> open(
      WidgetTester tester,
      MockZanKurdRepository repo, {
      Size size = const Size(390, 2600),
      double textScale = 1.0,
      bool ku = false,
    }) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = size;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          languageProvider: ku ? kurmanciLang() : null,
          child: MediaQuery(
            data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
            child: AsyncDuelResultScreen(
              repository: repo,
              view: AsyncDuelResultView.fromSummary(_completedSummary()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      // K7 (2026-10-28): karşılaştırma varsayılan KAPALI; bu yardımcı
      // "Cevapları gör" ile açar (kapalı olduğunu `sonuç: karşılaştırma
      // varsayılan kapalı` sınar).
      final toggle = find.byKey(const ValueKey('async-duel-review-toggle'));
      if (toggle.evaluate().isNotEmpty) {
        await tester.ensureVisible(toggle);
        await tester.pumpAndSettle();
        await tester.tap(toggle);
        await tester.pumpAndSettle();
      }
    }

    testWidgets('K7: karşılaştırma varsayılan kapalı', (tester) async {
      final repo = _ReviewRepository(
        review: AsyncDuelReview.fromJson(_reviewJson()),
      );
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 2600);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          child: AsyncDuelResultScreen(
            repository: repo,
            view: AsyncDuelResultView.fromSummary(_completedSummary()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('async-duel-review')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('async-duel-review-row-0')),
        findsNothing,
      );
    });

    testWidgets('7 satır; soru, doğru cevap, ✓/✗ ve süre okunur', (
      tester,
    ) async {
      final repo = _ReviewRepository(
        review: AsyncDuelReview.fromJson(_reviewJson()),
      );
      await open(tester, repo);

      expect(find.byKey(const ValueKey('async-duel-review')), findsOneWidget);
      for (var i = 0; i < 7; i++) {
        expect(
          find.byKey(ValueKey('async-duel-review-row-$i')),
          findsOneWidget,
          reason: 'satır $i',
        );
      }
      // Soru 1: doğru cevap + benim doğrum 3,2 sn + rakibin yanlışı 5,4 sn.
      expect(find.text('1. Pirsa 0'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('async-duel-review-correct-0')),
        findsOneWidget,
      );
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('async-duel-review-correct-0')),
            )
            .data,
        'Doğru cevap: Duyem',
      );
      String line(String key) => tester
          .widget<Text>(
            find.descendant(
              of: find.byKey(ValueKey(key)),
              matching: find.byType(Text),
            ),
          )
          .textSpan!
          .toPlainText();
      expect(line('async-duel-review-mine-0'), 'Sen · Duyem · 3,2 sn');
      expect(line('async-duel-review-opp-0'), 'Rojda · Yekem · 5,4 sn');
      // Yanlış ben (soru 2), süre dolan ben (soru 3), süre dolan rakip (4).
      expect(line('async-duel-review-mine-1'), 'Sen · Yekem · 3,2 sn');
      expect(line('async-duel-review-mine-2'), 'Sen · Süre doldu');
      expect(line('async-duel-review-opp-3'), 'Rojda · Süre doldu');
      // ✓ ve ✗ şekil olarak da var (renge bağımlı değil).
      final mine0 = find.byKey(const ValueKey('async-duel-review-mine-0'));
      expect(
        find.descendant(of: mine0, matching: find.byType(Icon)),
        findsOneWidget,
      );
    });

    testWidgets('soru tek satır (K7)', (tester) async {
      final repo = _ReviewRepository(
        review: AsyncDuelReview.fromJson(
          _reviewJson(questions: [_questionJson(0, prompt: _longPrompt * 3)]),
        ),
      );
      await open(tester, repo, size: const Size(320, 1400));
      final prompt = tester.widget<Text>(
        find.byKey(const ValueKey('async-duel-review-prompt-0')),
      );
      expect(prompt.maxLines, 1);
      expect(prompt.overflow, TextOverflow.ellipsis);
    });

    testWidgets('Kurmancî etiketler', (tester) async {
      final repo = _ReviewRepository(
        review: AsyncDuelReview.fromJson(_reviewJson()),
      );
      await open(tester, repo, ku: true);
      expect(find.text('Berhevdana pirsan'), findsOneWidget);
      expect(
        tester
            .widget<Text>(
              find.byKey(const ValueKey('async-duel-review-correct-0')),
            )
            .data,
        'Bersiva rast: Duyem',
      );
      expect(find.text('Pêşbirka vegerê'), findsOneWidget);
    });

    testWidgets('RPC yok (null): ne bölüm ne rövanş; sonuç yerinde', (
      tester,
    ) async {
      final repo = _ReviewRepository(review: null);
      await open(tester, repo);
      expect(find.byKey(const ValueKey('async-duel-review')), findsNothing);
      expect(
        find.byKey(const ValueKey('async-duel-result-rematch')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('async-duel-review-failed')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('async-duel-result-new')),
        findsOneWidget,
      );
    });

    testWidgets('beklenen ret (Duel not finished) sessizce gizler', (
      tester,
    ) async {
      final repo = _ReviewRepository(error: Exception('Duel not finished'));
      await open(tester, repo);
      expect(find.byKey(const ValueKey('async-duel-review')), findsNothing);
      expect(
        find.byKey(const ValueKey('async-duel-review-failed')),
        findsNothing,
      );
    });

    testWidgets('geçici hata: not + Yeniden dene, sonra yüklenir', (
      tester,
    ) async {
      final repo = _ReviewRepository(error: Exception('socket closed'));
      await open(tester, repo);
      expect(
        find.byKey(const ValueKey('async-duel-review-failed')),
        findsOneWidget,
      );
      repo
        ..error = null
        ..review = AsyncDuelReview.fromJson(_reviewJson());
      await tester.tap(find.byKey(const ValueKey('async-duel-review-retry')));
      await tester.pumpAndSettle();
      expect(repo.loads, 2);
      expect(find.byKey(const ValueKey('async-duel-review')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('async-duel-review-failed')),
        findsNothing,
      );
    });

    testWidgets('engelli çift: rakip adı yok, rakip satırı yok, not var, '
        'rövanş kapalı', (tester) async {
      final repo = _ReviewRepository(
        review: AsyncDuelReview.fromJson(
          _reviewJson(blocked: true, canRematch: false, friend: false),
        ),
      );
      await open(tester, repo);
      // Skor kartı da genel "Rakip" der: gerçek ad ekranda hiç yok.
      expect(find.text('Rojda'), findsNothing);
      expect(
        find.byKey(const ValueKey('async-duel-review-blocked')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('async-duel-review-opp-0')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('async-duel-review-mine-0')),
        findsOneWidget,
      );
      final rematch = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('async-duel-result-rematch')),
      );
      expect(rematch.onPressed, isNull);
      expect(
        find.byKey(const ValueKey('async-duel-result-rematch-why')),
        findsOneWidget,
      );
      expect(find.text('Bu rakiple düello açılamaz.'), findsOneWidget);
    });

    testWidgets('arkadaş olmayan rakip: rövanş kapalı, nedeni yazar', (
      tester,
    ) async {
      final repo = _ReviewRepository(
        review: AsyncDuelReview.fromJson(
          _reviewJson(canRematch: false, friend: false),
        ),
      );
      await open(tester, repo);
      final rematch = tester.widget<ButtonStyleButton>(
        find.byKey(const ValueKey('async-duel-result-rematch')),
      );
      expect(rematch.onPressed, isNull);
      expect(
        find.text(
          'Rövanş yalnız arkadaşlarla ve son 7 günde birlikte oynadığın rakiplerle açılır.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('günlük 3 davet doldu: rövanş kapalı, nedeni yazar', (
      tester,
    ) async {
      final json = _reviewJson(canRematch: false, friend: false)
        ..['rematch_limit_reached'] = true;
      final repo = _ReviewRepository(review: AsyncDuelReview.fromJson(json));
      await open(tester, repo);
      expect(
        tester
            .widget<ButtonStyleButton>(
              find.byKey(const ValueKey('async-duel-result-rematch')),
            )
            .onPressed,
        isNull,
      );
      expect(
        find.text('Bugün en fazla 3 rövanş daveti gider; yarın tekrar dene.'),
        findsOneWidget,
      );
    });

    testWidgets('rakip kimliği yok (silinmiş profil): rövanş kapalı', (
      tester,
    ) async {
      final repo = _ReviewRepository(
        review: AsyncDuelReview.fromJson(
          _reviewJson(opponentId: null, canRematch: false),
        ),
      );
      await open(tester, repo);
      expect(find.text('Bu rakiple düello açılamaz.'), findsOneWidget);
    });

    testWidgets('rövanş açık: aynı rakibe arkadaş meydan okuması açar, '
        '"Yeni düello" da durur', (tester) async {
      final repo = _ReviewRepository(
        review: AsyncDuelReview.fromJson(_reviewJson()),
      );
      await open(tester, repo);
      expect(
        find.byKey(const ValueKey('async-duel-result-rematch-why')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('async-duel-result-new')),
        findsOneWidget,
      );

      final button = find.byKey(const ValueKey('async-duel-result-rematch'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(find.byType(AsyncDuelPlayScreen), findsOneWidget);
      expect(repo.rematchFriendIds, ['opp-1']);
      await _leave(tester);
    });

    testWidgets('rövanşa çift dokunuş tek düello açar', (tester) async {
      final repo = _ReviewRepository(
        review: AsyncDuelReview.fromJson(_reviewJson()),
      );
      await open(tester, repo);
      final button = find.byKey(const ValueKey('async-duel-result-rematch'));
      await tester.ensureVisible(button);
      await tester.tap(button);
      await tester.tap(button, warnIfMissed: false);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 600));
      expect(repo.rematchFriendIds, hasLength(1));
      await _leave(tester);
    });

    testWidgets('hükmen: rakip cevapsız satırı yok, benim satırım var', (
      tester,
    ) async {
      final repo = _ReviewRepository(
        review: AsyncDuelReview.fromJson(
          _reviewJson(
            forfeit: true,
            questions: [
              for (var i = 0; i < 7; i++) _questionJson(i, opp: null),
            ],
          ),
        ),
      );
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 2600);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          child: AsyncDuelResultScreen(
            repository: repo,
            view: AsyncDuelResultView.fromSummary(
              AsyncDuelSummary(
                duelId: 'duel-1',
                status: AsyncDuelStatus.expired,
                role: AsyncDuelRole.creator,
                opponentName: 'Rojda',
                myCorrect: 6,
                outcome: AsyncDuelOutcome.win,
                isForfeit: true,
                createdAt: DateTime.utc(2026, 10, 24),
                seen: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('async-duel-review-toggle')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('async-duel-review')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('async-duel-review-opp-0')),
        findsNothing,
      );
      expect(
        find.byKey(const ValueKey('async-duel-review-mine-0')),
        findsOneWidget,
      );
    });

    testWidgets('bitmemiş sonuçlarda (bekleniyor) inceleme hiç istenmez', (
      tester,
    ) async {
      final repo = _ReviewRepository(
        review: AsyncDuelReview.fromJson(_reviewJson()),
      );
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 1200);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        testShell(
          child: AsyncDuelResultScreen(
            repository: repo,
            view: AsyncDuelResultView.fromSummary(
              AsyncDuelSummary(
                duelId: 'duel-1',
                status: AsyncDuelStatus.matched,
                role: AsyncDuelRole.creator,
                myCorrect: 4,
                createdAt: DateTime.utc(2026, 10, 24),
                seen: true,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(repo.loads, 0);
      expect(find.byKey(const ValueKey('async-duel-review')), findsNothing);
    });

    for (final (name, size, scale) in [
      ('320 px', const Size(320, 700), 1.0),
      ('%200 yazı', const Size(390, 844), 2.0),
      ('320 px + %200 yazı', const Size(320, 700), 2.0),
    ]) {
      testWidgets('taşma yok — $name', (tester) async {
        final repo = _ReviewRepository(
          review: AsyncDuelReview.fromJson(
            _reviewJson(
              opponentName: 'Pir Dirêj Navekî Hevrikê Rojdaxanım',
              questions: [
                for (var i = 0; i < 7; i++)
                  _questionJson(
                    i,
                    prompt: _longPrompt,
                    optionD: 'Cihê ku tê de çend peyvên pir dirêj hene',
                    correct: 'D',
                    mine: i.isEven ? 'dogru' : 'sure',
                    opp: i == 4 ? null : 'yanlis',
                  ),
              ],
            ),
          ),
        );
        await open(tester, repo, size: size, textScale: scale);
        expect(tester.takeException(), isNull);
        // Altın satırlara kadar kaydır: hepsi taşmasız kurulur.
        await tester.dragUntilVisible(
          find.byKey(const ValueKey('async-duel-review-row-6')),
          find.byType(SingleChildScrollView).first,
          const Offset(0, -300),
        );
        await tester.pump();
        expect(tester.takeException(), isNull);
      });
    }
  });
}
