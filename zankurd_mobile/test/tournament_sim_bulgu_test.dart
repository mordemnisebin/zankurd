import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';
import 'package:zankurd_mobile/src/widgets/tournament_bracket_widget.dart';

import 'support/widget_test_helpers.dart';

/// Turnuva ekranı, 2026-10-29 iPhone 17 Pro turu bulguları.
///
/// ## Kusur A: şema kırpılıyordu
///
/// Şema turları YATAY dizip 264 px'lik sabit yükseklikli bir kutuya koyuyordu.
/// İkinci yarı final maçı kutunun altında yarım kalıyor, Final sütunu sağdaki
/// solma gradyanının arkasında kayboluyordu. Dört kişilik şema dar telefonda
/// yatay sığmaz; şema artık DİKEY ve kendi yüksekliğini taşır.
///
/// ## Niçin sessiz kalabilirdi
///
/// Kutunun içindeki kaydırma görünümü taşmayı "yutuyordu": `RenderFlex`
/// taşma hatası hiç çıkmıyor, hiçbir test kırılmıyordu. Yalnız gerçek
/// cihazda gözle görülüyordu. Bekçi bu yüzden taşma hatasına değil, her
/// oyuncu adının ve her turun ekran sınırları İÇİNDE olmasına bakar.
///
/// ## Kusur B: bekleme "ne kadar" ve "ne olur"u söylemiyordu
///
/// Sunucu (`resolve_expired_tournament_matches`) süre dolunca yalnız skor
/// göndereni hükmen geçirir; ekran bunu hiç söylemiyordu.
///
/// ## Kusur C: yeni kupa açıklamasızdı
///
/// Önceki kupa doluyken katılan oyuncu boş bir "1/4" ekranına düşüyor, yeni
/// bir kupa açıldığını göremiyordu.
class _Repo extends MockZanKurdRepository {
  _Repo({this.current, this.joined});

  TournamentBracket? current;
  TournamentBracket? joined;

  @override
  String? get currentUserId => 'me';

  @override
  Future<TournamentBracket?> loadRealTournamentBracket() async => current;

  @override
  Future<TournamentBracket?> joinRealTournament() async => joined;
}

TournamentMatch _match(
  String id,
  String a,
  String b, {
  int sa = 0,
  int sb = 0,
  String status = 'pending',
  String winner = '',
  DateTime? deadline,
}) => TournamentMatch(
  id: id,
  playerOneId: a,
  playerOneName: a == 'me' ? 'Ben' : a.toUpperCase(),
  playerTwoId: b,
  playerTwoName: b.toUpperCase(),
  playerOneScore: sa,
  playerTwoScore: sb,
  status: status,
  winnerId: winner,
  deadline: deadline,
);

TournamentBracket _semis({DateTime? deadline, int sa = 0}) => TournamentBracket(
  tournamentId: 't1',
  userId: 'me',
  size: 4,
  entryCount: 4,
  rounds: [
    TournamentRound(
      roundNumber: 1,
      status: 'active',
      matches: [
        _match('m1', 'me', 'qali', sa: sa, deadline: deadline),
        _match(
          'm2',
          'qabero',
          'qacano',
          sa: 265,
          sb: 122,
          status: 'completed',
          winner: 'qabero',
        ),
      ],
    ),
  ],
  createdAt: DateTime(2026, 10, 29),
);

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'zankurd.navTour.seen': true});
  });

  // (genişlik, yazı ölçeği, kaydırma gerekir mi): 320/x2'de kaydırma serbest.
  for (final (width, scale) in [
    (402.0, 1.0),
    (402.0, 1.3),
    (375.0, 1.0),
    (375.0, 1.3),
    (320.0, 2.0),
  ]) {
    testWidgets('A: şema tamamen görünür ($width, x$scale)', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 3000);
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 3000),
              textScaler: TextScaler.linear(scale),
            ),
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: TournamentBracketWidget(
                  bracket: _semis(),
                  userId: 'me',
                  ku: false,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 400));
      expect(tester.takeException(), isNull, reason: 'taşma/hata var');

      // Dört oyuncu, iki yarı final maçı, boş Final kartı.
      for (final name in ['Ben', 'QALI', 'QABERO', 'QACANO']) {
        final rect = tester.getRect(find.text(name));
        expect(rect.left, greaterThanOrEqualTo(0), reason: name);
        expect(rect.right, lessThanOrEqualTo(width), reason: name);
        expect(rect.bottom, lessThan(3000), reason: name);
      }
      expect(find.text('Yarı Final'), findsOneWidget);
      expect(
        find.text('Final'),
        findsOneWidget,
        reason: 'henüz kurulmamış Final de şemada görünmeli',
      );
      // Her maç kartı ekran genişliği içinde.
      final bracket = tester.getRect(
        find.byKey(const ValueKey('tournament-bracket-vertical')),
      );
      expect(bracket.left, greaterThanOrEqualTo(0));
      expect(bracket.right, lessThanOrEqualTo(width));
      // İkinci yarı finalin skoru ve kupası da çizilmiş (satır yarım değil).
      expect(find.text('265 – 122'), findsOneWidget);
    });
  }

  testWidgets('A: tam ekranda şema iç kaydırma ve kırpma taşımaz', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    tester.view.physicalSize = const Size(402 * 3, 874 * 3);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(
        child: TournamentScreen(repository: _Repo(current: _semis())),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(tester.takeException(), isNull);
    // Şemanın kendisi kaydırılabilir kutu DEĞİL (eski yatay kutu kalktı).
    expect(
      find.descendant(
        of: find.byType(TournamentBracketWidget),
        matching: find.byType(SingleChildScrollView),
      ),
      findsNothing,
    );
  });

  testWidgets('B: rakip beklenirken son tarih ve hükmen sonucu yazılır', (
    tester,
  ) async {
    final deadline = DateTime.now().add(const Duration(hours: 20));
    final repo = _Repo(current: _semis(deadline: deadline, sa: 640));
    await tester.pumpWidget(
      testShell(child: TournamentScreen(repository: repo)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.byKey(const ValueKey('tournament-awaiting-opponent')),
      findsOneWidget,
    );
    final line = find.byKey(const ValueKey('tournament-awaiting-deadline'));
    expect(line, findsOneWidget);
    final text = tester.widget<Text>(line).data!;
    expect(text, contains(formatMatchDeadline(deadline)));
    expect(text, contains('hükmen kazanırsın'));
  });

  testWidgets('B: süresi geçmiş bekleme "sonuç güncellenecek" der', (
    tester,
  ) async {
    final repo = _Repo(
      current: _semis(
        deadline: DateTime.now().subtract(const Duration(minutes: 5)),
        sa: 640,
      ),
    );
    await tester.pumpWidget(
      testShell(child: TournamentScreen(repository: repo)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final text = tester
        .widget<Text>(
          find.byKey(const ValueKey('tournament-awaiting-deadline')),
        )
        .data!;
    expect(text, contains('Süre doldu'));
    expect(text, isNot(contains('hükmen')));
  });

  testWidgets('C: katılınca açılan yeni kupa açıkça söylenir', (tester) async {
    final repo = _Repo(
      current: null,
      joined: TournamentBracket(
        tournamentId: 't2',
        userId: 'me',
        size: 4,
        entryCount: 1,
        rounds: const [],
        createdAt: DateTime.now(),
      ),
    );
    await tester.pumpWidget(
      testShell(child: TournamentScreen(repository: repo)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    final join = find.text('Turnuvaya katıl');
    expect(join, findsWidgets);
    await tester.tap(join.first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.byKey(const ValueKey('tournament-waiting')), findsOneWidget);
    expect(find.textContaining('Yeni bir turnuva açıldı'), findsOneWidget);
    expect(find.textContaining('3 oyuncu daha'), findsOneWidget);
    expect(find.textContaining('1/4 oyuncu katıldı'), findsOneWidget);
  });
}
