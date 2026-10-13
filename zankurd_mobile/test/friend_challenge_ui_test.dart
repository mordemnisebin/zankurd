/// Arkadaşa meydan okuma — istemci bekçisi.
///
/// ## Kusur
///
/// Sırayla düello yalnız rastgele rakiple eşleşiyordu; birbirini tanıyan
/// insanlar arasındaki yarış (ürünün rakipsiz yüzü ve tek büyüme/dönüş
/// döngüsü) yoktu: ne bir giriş noktası, ne paylaşılacak bir bağlantı, ne de
/// `/join/…` bağlantısını meydan okumaya çeviren bir kapı.
///
/// ## Niçin sessiz kalırdı
///
/// Bu zincirin her halkası ayrı ayrı "çalışır" görünür; kopukluk yalnız iki
/// insan arasında, WhatsApp'ta yaşanır: oda kodu ile meydan okuma kodu
/// karışırsa bağlantı yanlış RPC'ye gider, süresi dolmuş bağlantıda ekran
/// boş kalırsa arkadaş uygulamayı siler, göç uygulanmadan yayınlanan
/// sürümde ölü bir düğme görünür. Bu dosya: kod biçimlerinin çakışmazlığını,
/// seçim sayfasını (boş arkadaş durumu dahil), sonuç ekranındaki Paylaş'ı,
/// gelen kutusu ve ana ekran kartındaki "Sıra sende"yi, hata metinlerini ve
/// RPC yokken giriş noktalarının gizlenmesini sabitler.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/supabase_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_inbox.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_play_screen.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_result_screen.dart';
import 'package:zankurd_mobile/src/screens/home/home_duel_card.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/utils/join_deep_link.dart';

import 'support/widget_test_helpers.dart';

const _shareChannel = MethodChannel('dev.fluttercommunity.plus/share');

/// Paylaşım sayfası yerine çağrıyı yakalar.
List<Map<Object?, Object?>> _captureShares() {
  final shared = <Map<Object?, Object?>>[];
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(_shareChannel, (call) async {
        if (call.method == 'share') {
          shared.add(call.arguments as Map<Object?, Object?>);
        }
        return 'dev.fluttercommunity.plus/share/unavailable';
      });
  return shared;
}

/// Bir arkadaşı olan sahte depo.
class _FriendsRepository extends MockZanKurdRepository {
  @override
  Future<List<Friend>> loadFriends() async => [
    Friend(
      id: 'f1',
      userId: 'me',
      friendId: 'friend-rojda',
      friendName: 'Rojda',
      createdAt: DateTime(2026, 10, 1),
    ),
  ];
}

/// Kabul çağrısını verilen sunucu hata metniyle reddeden depo.
class _RejectingAcceptRepository extends MockZanKurdRepository {
  _RejectingAcceptRepository(this.message);

  final String message;

  @override
  Future<AsyncDuelStart> acceptAsyncDuelChallenge(String code) async {
    throw StateError(message);
  }
}

Future<void> _useSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

Future<void> _answerCurrentQuestion(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('async-duel-option-0')));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1300));
  await tester.pump();
}

Future<void> _playAllSeven(WidgetTester tester) async {
  for (var i = 0; i < 7; i++) {
    await _answerCurrentQuestion(tester);
  }
  await tester.pumpAndSettle();
}

Future<void> _openChallengeSheetFromHub(WidgetTester tester) async {
  final row = find.byKey(const ValueKey('play-hub-async-duel-challenge'));
  await tester.ensureVisible(row);
  await tester.tap(row);
  await tester.pumpAndSettle();
}

void main() {
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_shareChannel, null);
  });

  group('kod biçimleri çakışmaz', () {
    test('meydan okuma kodu: D + 8, belirsiz karakter yok', () {
      expect(JoinDeepLink.isChallengeCode('DK7M2Q9XA'), isTrue);
      expect(JoinDeepLink.isChallengeCode('dk7m2q9xa'), isTrue);
      expect(JoinDeepLink.isChallengeCode('  DK7M2Q9XA \n'), isTrue);
      // 0, 1, O, I, L alfabede yok.
      for (final bad in ['DK7M2Q9X0', 'DK7M2Q9X1', 'DK7M2Q9XO', 'DK7M2Q9XI']) {
        expect(JoinDeepLink.isChallengeCode(bad), isFalse, reason: bad);
      }
      expect(JoinDeepLink.isChallengeCode('DK7M2Q9X'), isFalse); // kısa
      expect(JoinDeepLink.isChallengeCode('DK7M2Q9XAB'), isFalse); // uzun
      expect(JoinDeepLink.isChallengeCode('XK7M2Q9XA'), isFalse); // D değil
      expect(JoinDeepLink.isChallengeCode(null), isFalse);
      expect(JoinDeepLink.isChallengeCode(''), isFalse);
    });

    test('hiçbir oda kodu meydan okuma kodu sayılmaz', () {
      const roomCodes = [
        'ZK-ABCDEF0123', // güncel: ZK- + 10 onaltılık
        'ZK-DEADBEEF01',
        'ZK-D2345678',
        'ZK-4F7K', // eski 4 karakterli
        'ZKD2345678',
        'D2345678', // çıplak sonek biçimleri de tutmaz: ZK öneki yok
      ];
      for (final room in roomCodes.take(5)) {
        expect(JoinDeepLink.isChallengeCode(room), isFalse, reason: room);
      }
      // Sunucu üreticisinin alfabesiyle üretilen her kod tanınır; onaltılık
      // oda sonekleri (0-9A-F) 0/1 ya da uzunluk yüzünden asla tanınmaz.
      const alphabet = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
      for (var i = 0; i < alphabet.length; i++) {
        final code = 'D${alphabet.substring(i, i + 1) * 8}';
        expect(JoinDeepLink.isChallengeCode(code), isTrue, reason: code);
      }
    });

    test('parse: bağlantıdan kod çıkar, büyük harfe çevirir, boşluğu atar', () {
      expect(
        JoinDeepLink.parse('https://www.zankurd.com/join/DK7M2Q9XA'),
        'DK7M2Q9XA',
      );
      expect(JoinDeepLink.parse('/join/dk7m2q9xa'), 'DK7M2Q9XA');
      expect(JoinDeepLink.parse('/join/%20dk7m2q9xa%20'), 'DK7M2Q9XA');
      expect(
        JoinDeepLink.parse('https://www.zankurd.com/join/ZK-ABCDEF0123'),
        'ZK-ABCDEF0123',
      );
      expect(JoinDeepLink.parse('/join/'), isNull);
      expect(JoinDeepLink.parse('/'), isNull);
      // Ayrım parse'tan sonra kod üzerinden yapılır.
      expect(
        JoinDeepLink.isChallengeCode(JoinDeepLink.parse('/join/dk7m2q9xa')),
        isTrue,
      );
      expect(
        JoinDeepLink.isChallengeCode(JoinDeepLink.parse('/join/zk-abcdef0123')),
        isFalse,
      );
    });

    test('paylaşılan bağlantı parse ile geri çözülür', () {
      expect(
        JoinDeepLink.shareUrl('dk7m2q9xa'),
        'https://www.zankurd.com/join/DK7M2Q9XA',
      );
      expect(
        JoinDeepLink.parse(JoinDeepLink.shareUrl('DK7M2Q9XA')),
        'DK7M2Q9XA',
      );
    });

    test('sıcak açılış: meydan okuma bağlantısı kanala düşer', () {
      JoinDeepLink.resetForTest();
      addTearDown(JoinDeepLink.resetForTest);
      expect(JoinDeepLink.offer('/join/DK7M2Q9XA'), isTrue);
      expect(JoinDeepLink.takeIncoming(), 'DK7M2Q9XA');
      expect(JoinDeepLink.takeIncoming(), isNull);
    });
  });

  group('hata sınıflaması', () {
    test('her sunucu hata metni ayrı bir sınıfa düşer', () {
      AsyncDuelChallengeError c(String m) =>
          classifyAsyncDuelChallengeError(StateError(m));
      expect(c('Challenge not found'), AsyncDuelChallengeError.notFound);
      expect(c('Own challenge'), AsyncDuelChallengeError.own);
      expect(c('Challenge already taken'), AsyncDuelChallengeError.taken);
      expect(c('Challenge expired'), AsyncDuelChallengeError.expired);
      expect(c('Challenge not for you'), AsyncDuelChallengeError.notForYou);
      expect(c('Challenge not ready'), AsyncDuelChallengeError.notReady);
      expect(c('Not a friend'), AsyncDuelChallengeError.notAFriend);
      expect(c('Too many open duels'), AsyncDuelChallengeError.tooMany);
      expect(c('SocketException'), AsyncDuelChallengeError.other);
    });

    test('kalıcı hatalar yeniden denenmez, geçici olanlar denenir', () {
      for (final e in [
        AsyncDuelChallengeError.notFound,
        AsyncDuelChallengeError.own,
        AsyncDuelChallengeError.taken,
        AsyncDuelChallengeError.expired,
        AsyncDuelChallengeError.notForYou,
      ]) {
        expect(asyncDuelChallengeErrorIsTerminal(e), isTrue, reason: '$e');
      }
      for (final e in [
        AsyncDuelChallengeError.notReady,
        AsyncDuelChallengeError.other,
        AsyncDuelChallengeError.tooMany,
      ]) {
        expect(asyncDuelChallengeErrorIsTerminal(e), isFalse, reason: '$e');
      }
    });

    test('eksik RPC sinyali: PGRST202 ve 42883', () {
      expect(isMissingRpcError(StateError('code: PGRST202')), isTrue);
      expect(isMissingRpcError(StateError('code: 42883')), isTrue);
      expect(isMissingRpcError(StateError('Challenge expired')), isFalse);
    });
  });

  group('seçim sayfası', () {
    testWidgets('Yarış sekmesi satırı iki seçenek sunar; bağlantı birincil', (
      tester,
    ) async {
      await _useSurface(tester);
      await tester.pumpWidget(
        testShell(
          child: PlayHubScreen(
            repository: freshMockRepository(),
            asyncDuelEnabled: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Arkadaşına meydan oku'), findsOneWidget);

      await _openChallengeSheetFromHub(tester);

      expect(find.byKey(const ValueKey('challenge-sheet')), findsOneWidget);
      expect(find.text('Bağlantıyla meydan oku'), findsOneWidget);
      expect(find.text('Arkadaş seç'), findsOneWidget);
    });

    testWidgets('arkadaşı yoksa boş durum nedenini söyler ve bağlantı yolunu '
        'önerir', (tester) async {
      await _useSurface(tester);
      await tester.pumpWidget(
        testShell(
          child: PlayHubScreen(
            repository: freshMockRepository(),
            asyncDuelEnabled: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await _openChallengeSheetFromHub(tester);

      await tester.tap(find.byKey(const ValueKey('challenge-sheet-friend')));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('challenge-friends-empty')),
        findsOneWidget,
      );
      expect(find.textContaining('Henüz arkadaşın yok'), findsOneWidget);
      // Çıkmaz sokak yok: bağlantı yolu hâlâ burada ve oyun ekranını açar.
      await tester.tap(
        find.byKey(const ValueKey('challenge-friends-empty-link')),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('async-duel-play')), findsOneWidget);
    });

    testWidgets('arkadaş listesi kabul edilmiş arkadaşları sıralar; seçilen '
        'arkadaş için düello açılır', (tester) async {
      await _useSurface(tester);
      final repo = _FriendsRepository();
      await tester.pumpWidget(
        testShell(
          child: PlayHubScreen(repository: repo, asyncDuelEnabled: true),
        ),
      );
      await tester.pumpAndSettle();
      await _openChallengeSheetFromHub(tester);
      await tester.tap(find.byKey(const ValueKey('challenge-sheet-friend')));
      await tester.pumpAndSettle();

      expect(find.text('Rojda'), findsOneWidget);
      await tester.tap(
        find.byKey(const ValueKey('challenge-friend-friend-rojda')),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('async-duel-play')), findsOneWidget);

      final duels = await repo.loadMyAsyncDuels();
      expect(duels.single.invitedName, 'Rojda');
      expect(duels.single.challengeCode, isNotNull);
      expect(JoinDeepLink.isChallengeCode(duels.single.challengeCode), isTrue);
    });
  });

  group('sonuç ekranında Paylaş', () {
    testWidgets('bağlantı meydan okuması: 7 soru sonra Paylaş bağlantıyı ve '
        'doğru sayısını paylaşır', (tester) async {
      await _useSurface(tester);
      final shared = _captureShares();
      final repo = freshMockRepository();
      await tester.pumpWidget(
        testShell(
          child: AsyncDuelPlayScreen(
            repository: repo,
            entry: const AsyncDuelEntry.createChallenge(),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _playAllSeven(tester);

      final share = find.byKey(const ValueKey('async-duel-result-share'));
      expect(share, findsOneWidget);
      expect(find.text('Paylaş'), findsOneWidget);
      expect(
        find.text(
          'Bağlantıyı arkadaşına gönder. O oynayınca sonuç burada görünecek.',
        ),
        findsOneWidget,
      );

      await tester.tap(share);
      await tester.pump();

      expect(shared, hasLength(1));
      final text = shared.single['text'] as String;
      final code = (await repo.loadMyAsyncDuels()).single.challengeCode!;
      expect(text, contains('https://www.zankurd.com/join/$code'));
      expect(text, contains("ZanKurd'da sana meydan okudum: 7 soruda"));
      expect(text, contains('Beni geçebilir misin?'));
      expect(JoinDeepLink.parse(JoinDeepLink.shareUrl(code)), code);
    });

    testWidgets('arkadaş meydan okuması: Paylaş yok, bildirim güvencesi var', (
      tester,
    ) async {
      await _useSurface(tester);
      final repo = _FriendsRepository();
      await tester.pumpWidget(
        testShell(
          child: AsyncDuelPlayScreen(
            repository: repo,
            entry: const AsyncDuelEntry.createChallenge(
              friendId: 'friend-rojda',
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await _playAllSeven(tester);

      expect(
        find.text('Rojda sırası gelince bildirim alacak.'),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('async-duel-result-share')),
        findsNothing,
      );
    });

    testWidgets('rastgele düello sonucunda Paylaş çıkmaz', (tester) async {
      await _useSurface(tester);
      await tester.pumpWidget(
        testShell(
          child: AsyncDuelResultScreen(
            repository: freshMockRepository(),
            view: AsyncDuelResultView.fromAnswer(
              AsyncDuelStart(
                duelId: 'd',
                role: AsyncDuelRole.creator,
                expiresAt: DateTime(2030),
                questions: const [],
              ),
              const AsyncDuelResult(waiting: true, myCorrect: 4, myMs: 1000),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('async-duel-result-share')),
        findsNothing,
      );
    });

    testWidgets('Kurmancî: paylaşım metni Kurmancî', (tester) async {
      await _useSurface(tester);
      final shared = _captureShares();
      await tester.pumpWidget(
        testShell(
          languageProvider: kurmanciLang(),
          child: AsyncDuelResultScreen(
            repository: freshMockRepository(),
            view: AsyncDuelResultView.fromAnswer(
              AsyncDuelStart(
                duelId: 'd',
                role: AsyncDuelRole.creator,
                expiresAt: DateTime(2030),
                questions: const [],
                challengeCode: 'DK7M2Q9XA',
              ),
              const AsyncDuelResult(waiting: true, myCorrect: 5, myMs: 1000),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('async-duel-result-share')));
      await tester.pump();
      final text = shared.single['text'] as String;
      expect(text, contains('ez te vedixwînim pêşbirkê'));
      expect(text, contains('ji 7 pirsan 5 rast'));
      expect(text, contains('https://www.zankurd.com/join/DK7M2Q9XA'));
    });
  });

  group('bağlantıyı kabul etme', () {
    testWidgets('geçerli bağlantı oyun ekranını açar (rol: rakip)', (
      tester,
    ) async {
      await _useSurface(tester);
      final repo = freshMockRepository()
        ..addIncomingChallengeForTesting(friendChallenge: false);
      await tester.pumpWidget(
        testShell(
          child: AsyncDuelPlayScreen(
            repository: repo,
            entry: const AsyncDuelEntry.acceptChallenge('DK7M2Q9XA'),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byKey(const ValueKey('async-duel-play')), findsOneWidget);
      expect(find.textContaining('Rojda'), findsOneWidget);
      await _playAllSeven(tester);
      // Yaratıcı bitirmişti: karşılaştırma hemen çıkar.
      expect(find.byKey(const ValueKey('async-duel-result')), findsOneWidget);
    });

    for (final (message, expected) in [
      ('Challenge expired', 'Bu meydan okumanın süresi doldu.'),
      (
        'Challenge already taken',
        'Bu meydan okumayı başka biri çoktan kabul etti.',
      ),
      (
        'Own challenge',
        'Bu senin kendi meydan okuman. Bağlantıyı arkadaşına gönder.',
      ),
      (
        'Challenge not found',
        'Bu meydan okuma bulunamadı ya da artık geçerli değil.',
      ),
      ('Challenge not for you', 'Bu meydan okuma başka biri için gönderilmiş.'),
    ]) {
      testWidgets('hata "$message" dürüst metin gösterir ve Kapat çıkış olur', (
        tester,
      ) async {
        await _useSurface(tester);
        await tester.pumpWidget(
          testShell(
            child: Builder(
              builder: (context) => Scaffold(
                body: TextButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => AsyncDuelPlayScreen(
                        repository: _RejectingAcceptRepository(message),
                        entry: const AsyncDuelEntry.acceptChallenge(
                          'DK7M2Q9XA',
                        ),
                      ),
                    ),
                  ),
                  child: const Text('aç'),
                ),
              ),
            ),
          ),
        );
        await tester.tap(find.text('aç'));
        await tester.pumpAndSettle();

        expect(find.text(expected), findsOneWidget);
        // Yeniden denemek anlamsız: yalnız Kapat.
        expect(find.text('Tekrar dene'), findsNothing);
        await tester.tap(
          find.byKey(const ValueKey('async-duel-start-error-close')),
        );
        await tester.pumpAndSettle();
        expect(find.text('aç'), findsOneWidget);
      });
    }

    testWidgets('geçici hata yeniden denemeyi sunar', (tester) async {
      await _useSurface(tester);
      await tester.pumpWidget(
        testShell(
          child: AsyncDuelPlayScreen(
            repository: _RejectingAcceptRepository('SocketException'),
            entry: const AsyncDuelEntry.acceptChallenge('DK7M2Q9XA'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Tekrar dene'), findsOneWidget);
    });
  });

  group('Düellolarım: gelen kutusu', () {
    testWidgets('gelen arkadaş meydan okuması "Sıra sende" satırıdır ve '
        'listenin başındadır', (tester) async {
      await _useSurface(tester);
      final repo = freshMockRepository()
        ..addPendingAsyncDuelForTesting(
          opponentName: 'Berfin',
          opponentCorrect: 3,
          opponentMs: 10,
        );
      // Önce bitmiş bir düello, sonra gelen meydan okuma (daha yeni).
      final start = await repo.startAsyncDuel();
      for (var i = 0; i < start.questions.length; i++) {
        await repo.answerAsyncDuel(
          duelId: start.duelId,
          questionIndex: i,
          choice: 'A',
          responseMs: 1000,
        );
      }
      repo.addIncomingChallengeForTesting();

      await tester.pumpWidget(
        testShell(
          child: PlayHubScreen(repository: repo, asyncDuelEnabled: true),
        ),
      );
      await tester.pumpAndSettle();
      await tester.ensureVisible(
        find.byKey(const ValueKey('play-hub-async-duel-inbox')),
      );

      expect(find.text('Sıra sende'), findsOneWidget);
      expect(find.text('Rojda seni düelloya çağırdı'), findsOneWidget);
      expect(find.text('Oyna'), findsOneWidget);
    });

    testWidgets('gelen satıra dokunmak kabul edip oyunu açar', (tester) async {
      await _useSurface(tester);
      final repo = freshMockRepository()..addIncomingChallengeForTesting();
      await tester.pumpWidget(
        testShell(
          child: PlayHubScreen(repository: repo, asyncDuelEnabled: true),
        ),
      );
      await tester.pumpAndSettle();
      final row = find.byWidgetPredicate(
        (w) =>
            w.key is ValueKey &&
            (w.key! as ValueKey).value.toString().startsWith('async-duel-row-'),
      );
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('async-duel-play')), findsOneWidget);
    });

    testWidgets('bekleyen bağlantım: başlık "Meydan okuma bağlantısı", '
        'dokununca Paylaş', (tester) async {
      await _useSurface(tester);
      final shared = _captureShares();
      final repo = freshMockRepository();
      final start = await repo.createAsyncDuelChallenge();
      for (var i = 0; i < start.questions.length; i++) {
        await repo.answerAsyncDuel(
          duelId: start.duelId,
          questionIndex: i,
          choice: 'A',
          responseMs: 1000,
        );
      }
      await tester.pumpWidget(
        testShell(
          child: PlayHubScreen(repository: repo, asyncDuelEnabled: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Meydan okuma bağlantısı'), findsOneWidget);

      final row = find.byKey(ValueKey('async-duel-row-${start.duelId}'));
      await tester.ensureVisible(row);
      await tester.tap(row);
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('async-duel-result-share')));
      await tester.pump();
      expect(
        shared.single['text'] as String,
        contains('/join/${start.challengeCode}'),
      );
    });
  });

  group('ana ekran düello kartı', () {
    Widget card(MockZanKurdRepository repo) => testShell(
      child: Scaffold(
        body: SingleChildScrollView(
          child: HomeDuelCard(repository: repo, asyncDuelEnabled: true),
        ),
      ),
    );

    testWidgets('Sıra sende: tek gelen meydan okuma davet eden adı ve Oyna', (
      tester,
    ) async {
      await _useSurface(tester);
      final repo = freshMockRepository()..addIncomingChallengeForTesting();
      await tester.pumpWidget(card(repo));
      await tester.pumpAndSettle();

      expect(
        find.byKey(const ValueKey('home-duel-card-your-turn')),
        findsOneWidget,
      );
      expect(find.text('Sıra sende'), findsOneWidget);
      expect(find.text('Rojda seni düelloya çağırdı'), findsOneWidget);
      expect(find.text('Oyna'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('home-duel-primary')));
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(const ValueKey('async-duel-play')), findsOneWidget);
    });

    testWidgets(
      'Sıra sende · N: birden çok gelen meydan okumada sayı ve liste',
      (tester) async {
        await _useSurface(tester);
        final repo = freshMockRepository()
          ..addIncomingChallengeForTesting(code: 'DK7M2Q9XA')
          ..addIncomingChallengeForTesting(
            code: 'DK7M2Q9XB',
            creatorName: 'Azad',
          );
        await tester.pumpWidget(card(repo));
        await tester.pumpAndSettle();

        expect(find.text('Sıra sende · 2'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('home-duel-primary')));
        await tester.pumpAndSettle();
        expect(find.byType(AsyncDuelListScreen), findsOneWidget);
      },
    );

    testWidgets('varsayılan kartta "Arkadaşına meydan oku" sakin metin '
        'düğmesidir ve seçim sayfasını açar', (tester) async {
      await _useSurface(tester);
      await tester.pumpWidget(card(freshMockRepository()));
      await tester.pumpAndSettle();

      final challenge = find.byKey(const ValueKey('home-duel-challenge'));
      expect(challenge, findsOneWidget);
      await tester.tap(challenge);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('challenge-sheet')), findsOneWidget);
    });
  });

  group('sunucuda RPC yoksa giriş noktaları gizlenir', () {
    testWidgets('Yarış sekmesi satırı çizilmez', (tester) async {
      await _useSurface(tester);
      final repo = freshMockRepository()..challengeSupportedForTesting = false;
      await tester.pumpWidget(
        testShell(
          child: PlayHubScreen(repository: repo, asyncDuelEnabled: true),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('play-hub-async-duel-challenge')),
        findsNothing,
      );
      expect(find.text('Arkadaşına meydan oku'), findsNothing);
      // Mevcut düello akışı bozulmaz.
      expect(find.byKey(const ValueKey('play-hub-async-duel')), findsOneWidget);
    });

    testWidgets('ana ekran kartında düğme çizilmez', (tester) async {
      await _useSurface(tester);
      final repo = freshMockRepository()..challengeSupportedForTesting = false;
      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: SingleChildScrollView(
              child: HomeDuelCard(repository: repo, asyncDuelEnabled: true),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('home-duel-challenge')), findsNothing);
      expect(find.text('Hızlı düello'), findsOneWidget);
    });

    test('Supabase deposu: create PGRST202 alırsa destek "yok" olur', () async {
      final repo = _SignedInRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: _MissingRpcHttpClient(),
        ),
      );
      await expectLater(
        repo.createAsyncDuelChallenge(),
        throwsA(isA<PostgrestException>()),
      );
      expect(await repo.supportsAsyncDuelChallenge(), isFalse);
    });
  });

  group('Supabase deposu RPC çağrıları', () {
    test('create doğru RPC adı ve parametreler; kod ayrıştırılır', () async {
      final http = _JsonRpcHttpClient({
        'create_async_duel_challenge': {
          'duel_id': 'd-1',
          'role': 'creator',
          'opponent_name': null,
          'expires_at': '2026-10-15T12:00:00.000Z',
          'questions': <Object>[],
          'challenge_code': 'DK7M2Q9XA',
          'invited_name': 'Rojda',
        },
      });
      final repo = _SignedInRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: http,
        ),
      );
      final start = await repo.createAsyncDuelChallenge(
        category: 'Ziman',
        friendId: 'u-9',
      );
      expect(http.paths, ['/rest/v1/rpc/create_async_duel_challenge']);
      expect(http.bodies.single, {'p_category': 'Ziman', 'p_friend_id': 'u-9'});
      expect(start.challengeCode, 'DK7M2Q9XA');
      expect(start.invitedName, 'Rojda');
    });

    test('accept doğru RPC adı; yeniden açılış alanları okunur', () async {
      final http = _JsonRpcHttpClient({
        'accept_async_duel_challenge': {
          'duel_id': 'd-2',
          'role': 'opponent',
          'opponent_name': 'Rojda',
          'expires_at': '2026-10-15T12:00:00.000Z',
          'questions': <Object>[],
          'answered': 3,
          'finished': false,
        },
      });
      final repo = _SignedInRepository(
        SupabaseClient(
          'https://example.supabase.co',
          'sb_publishable_test_key',
          httpClient: http,
        ),
      );
      final start = await repo.acceptAsyncDuelChallenge('DK7M2Q9XA');
      expect(http.paths, ['/rest/v1/rpc/accept_async_duel_challenge']);
      expect(http.bodies.single, {'p_code': 'DK7M2Q9XA'});
      expect(start.role, AsyncDuelRole.opponent);
      expect(start.answeredCount, 3);
      expect(start.alreadyFinished, isFalse);
    });

    test(
      'list: yeni alanlar ayrıştırılır, eski satır varsayılanlara düşer',
      () {
        final row = AsyncDuelSummary.fromJson({
          'duel_id': 'd-3',
          'status': 'open',
          'role': 'opponent',
          'opponent_name': 'Rojda',
          'category_name': null,
          'my_correct': null,
          'opponent_correct': null,
          'outcome': null,
          'created_at': '2026-10-13T10:00:00.000Z',
          'completed_at': null,
          'seen': true,
          'challenge_code': 'DK7M2Q9XA',
          'incoming_challenge': true,
          'invited_name': null,
        });
        expect(row.incomingChallenge, isTrue);
        expect(row.challengeCode, 'DK7M2Q9XA');

        final old = AsyncDuelSummary.fromJson({
          'duel_id': 'd-4',
          'status': 'open',
          'role': 'creator',
          'opponent_name': null,
          'category_name': null,
          'my_correct': 3,
          'opponent_correct': null,
          'outcome': null,
          'created_at': '2026-10-13T10:00:00.000Z',
          'completed_at': null,
          'seen': true,
        });
        expect(old.incomingChallenge, isFalse);
        expect(old.challengeCode, isNull);
        expect(old.isWaitingLinkChallenge, isFalse);
      },
    );
  });
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

class _JsonRpcHttpClient extends http.BaseClient {
  _JsonRpcHttpClient(this.responses);

  final Map<String, Object?> responses;
  final paths = <String>[];
  final bodies = <Map<String, dynamic>>[];

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    paths.add(request.url.path);
    if (request is http.Request && request.body.isNotEmpty) {
      bodies.add(Map<String, dynamic>.from(jsonDecode(request.body) as Map));
    }
    final name = request.url.path.split('/').last;
    final bytes = utf8.encode(jsonEncode(responses[name]));
    return http.StreamedResponse(
      Stream.value(bytes),
      200,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}

/// PostgREST'in fonksiyonu bulamadığındaki 404 yanıtı (göç uygulanmamış).
class _MissingRpcHttpClient extends http.BaseClient {
  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final bytes = utf8.encode(
      jsonEncode({
        'code': 'PGRST202',
        'details': null,
        'hint': null,
        'message':
            'Could not find the function public.create_async_duel_challenge '
            'in the schema cache',
      }),
    );
    return http.StreamedResponse(
      Stream.value(bytes),
      404,
      request: request,
      contentLength: bytes.length,
      headers: const {'content-type': 'application/json; charset=utf-8'},
    );
  }
}
