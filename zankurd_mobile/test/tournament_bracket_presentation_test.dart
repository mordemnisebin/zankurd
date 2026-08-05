import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';
import 'package:zankurd_mobile/src/widgets/tournament_bracket_widget.dart';

import 'support/widget_test_helpers.dart';

/// Turnuva şemasının oyuncuya verdiği sözleşmeler.
///
/// Şema iki kez çiziliyordu: üstte bağlantı çizgili gerçek şema, altında
/// aynı eşleşmelerin düz listesi. Liste DAHA AZ bilgi taşıyordu (skor yok,
/// kazanan işareti yok, kullanıcı vurgusu yok) ve kodda "legacy" diye
/// işaretliydi. İki kez anlatılan bir yapı bir kez anlatılandan daha
/// anlaşılır olmuyor.
///
/// Daha ciddisi: maçın SKORU uygulamanın hiçbir yerinde görünmüyordu.
/// Oyuncu satırındaki skor dalı `else if (score > 0)` koşuluyla yalnız maç
/// TAMAMLANMAMIŞKEN çalışıyordu — ama skor ancak tamamlandıktan sonra
/// oluşur. Turnuvanın tek somut çıktısı yazılmıyordu (2026-08-04).

/// Belirtilen tur indeksinde aktif, öncesi tamamlanmış şema.
TournamentBracket _bracket({
  int currentRound = 1,
  String status = 'active',
  int rounds = 4,
  String userName = 'Rojhat',
  int userScore = 340,
  int rivalScore = 280,
}) {
  final list = <TournamentRound>[];
  var per = 8;
  var n = 0;
  for (var i = 0; i < rounds; i++) {
    final done = i < currentRound;
    final matches = <TournamentMatch>[
      for (var m = 0; m < per; m++)
        TournamentMatch(
          id: 'r${i}m$m',
          playerOneId: m == 0 ? 'user' : 'bot${n + m}',
          playerOneName: m == 0 ? userName : 'Bot ${n + m}',
          playerTwoId: 'rival${n + m}',
          playerTwoName: 'Rakip ${n + m}',
          playerOneScore: done ? userScore : 0,
          playerTwoScore: done ? rivalScore : 0,
          status: done
              ? 'completed'
              : (i == currentRound ? 'active' : 'pending'),
          winnerId: done ? (m == 0 ? 'user' : 'bot${n + m}') : '',
        ),
    ];
    n += per;
    list.add(
      TournamentRound(
        roundNumber: i + 1,
        matches: matches,
        status: done ? 'completed' : (i == currentRound ? 'active' : 'pending'),
      ),
    );
    per = per > 1 ? per ~/ 2 : 1;
  }
  return TournamentBracket(
    tournamentId: 'daily',
    userId: 'user',
    rounds: list,
    currentRound: currentRound,
    status: status,
    totalScore: userScore,
    createdAt: DateTime.utc(2026, 8, 4),
  );
}

class _Repo extends MockZanKurdRepository {
  _Repo(this.bracket);

  final TournamentBracket? bracket;

  @override
  Future<TournamentBracket?> loadRealTournamentBracket() async => null;

  @override
  Future<TournamentBracket?> loadTournamentBracket() async => bracket;

  @override
  Future<List<TournamentStandings>> loadTournamentStandings({
    int limit = 16,
  }) async => const [];
}

Future<void> _pump(
  WidgetTester tester,
  TournamentBracket? bracket, {
  Size size = const Size(390, 1400),
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.light,
  bool ku = false,
}) async {
  tester.view.devicePixelRatio = 1.0;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    testShell(
      themeProvider: ThemeProvider(initialMode: mode),
      languageProvider: ku ? kurmanciLang() : turkishLang(),
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: TournamentScreen(repository: _Repo(bracket))),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── Tekrar yok ──────────────────────────────────────────────────────────

  test('şemanın altındaki düz tur listesi geri gelmiyor', () {
    final source = File(
      'lib/src/screens/tournament_screen.dart',
    ).readAsStringSync();
    expect(
      source,
      isNot(contains('_RoundSection(')),
      reason: 'aynı eşleşmeler daha az bilgiyle ikinci kez listeleniyor',
    );
    expect(source, isNot(contains('Legacy round list')));
  });

  testWidgets('bir eşleşme ekranda yalnız bir kez çizilir', (tester) async {
    await _pump(tester, _bracket(currentRound: 1, rounds: 2));
    // Kullanıcının 1. tur rakibi tek yerde görünmeli.
    expect(find.text('Rakip 0'), findsOneWidget);
  });

  // ── Skor ────────────────────────────────────────────────────────────────

  testWidgets('tamamlanan maçın skoru görünür', (tester) async {
    await _pump(tester, _bracket(currentRound: 1, rounds: 2));
    expect(
      find.text('340 – 280'),
      findsWidgets,
      reason: 'maçın kaç-kaç bittiği hiçbir yerde yazmıyordu',
    );
  });

  testWidgets('oynanmamış maçta skor uydurulmaz', (tester) async {
    // Henüz oynanmamış tur "0 – 0" dememeli.
    await _pump(tester, _bracket(currentRound: 0, rounds: 2));
    expect(find.text('0 – 0'), findsNothing);
    expect(find.text('VS'), findsWidgets);
  });

  // ── Kazanan / kaybeden ──────────────────────────────────────────────────

  testWidgets('kazanan yalnız renkle anlatılmaz', (tester) async {
    await _pump(tester, _bracket(currentRound: 1, rounds: 2));
    // Kupa ikonu ikinci kanal; kaybedende üstü çizili ad üçüncü kanal.
    final slots = tester.widgetList<Text>(find.byType(Text));
    final struck = slots.where(
      (t) => t.style?.decoration == TextDecoration.lineThrough,
    );
    expect(
      struck,
      isNotEmpty,
      reason: 'kaybeden yalnız soluk renkle işaretlenmiş',
    );
  });

  // ── Tur yapısı ──────────────────────────────────────────────────────────

  testWidgets('tur şeridi hangi turda olunduğunu söyler', (tester) async {
    await _pump(tester, _bracket(currentRound: 1));
    for (final name in const [
      'Son 16',
      'Çeyrek Final',
      'Yarı Final',
      'Final',
    ]) {
      expect(find.text(name), findsWidgets, reason: '$name turu yok');
    }
  });

  testWidgets('turnuva bittiğinde hiçbir tur "oynanıyor" demez', (
    tester,
  ) async {
    // Elenen oyuncuya aktif tur işareti göstermek, sürmekte olan bir maç
    // varmış izlenimi verirdi.
    await _pump(tester, _bracket(currentRound: 2, status: 'eliminated'));
    final source = File(
      'lib/src/screens/tournament_screen.dart',
    ).readAsStringSync();
    expect(source, contains("bracketStatus == 'active' && i == currentRound"));
    expect(tester.takeException(), isNull);
  });

  // ── Kullanıcının kendi eşleşmesi ────────────────────────────────────────

  testWidgets('kullanıcı kendi eşleşmesini görür', (tester) async {
    await _pump(tester, _bracket(currentRound: 1, rounds: 2));
    expect(find.text('Rojhat'), findsWidgets);
  });

  testWidgets('uzun oyuncu adı kırpılsa da kimlik kaybolmaz', (tester) async {
    // Ad, skor uğruna tek harfe indirilmemeli: skor ortadaki çipte durur.
    await _pump(
      tester,
      _bracket(currentRound: 1, rounds: 2, userName: 'Şehmûs Alîyê Zînarê'),
    );
    expect(tester.takeException(), isNull);
    final source = File(
      'lib/src/widgets/tournament_bracket_widget.dart',
    ).readAsStringSync();
    expect(
      source,
      contains('playerOneScore} – \${match.playerTwoScore'),
      reason: 'skor oyuncu satırına dönerse ad yeniden kırpılır',
    );
  });

  // ── Kompozisyon durumları ───────────────────────────────────────────────

  testWidgets('tohumlanmamış şema lobi olarak gösterilir', (tester) async {
    // Boş şema turnuva başlamış gibi gösterilmemeli.
    await _pump(tester, null);
    expect(
      find.byKey(const ValueKey('tournament-primary-cta')),
      findsOneWidget,
    );
  });

  for (final rounds in const [1, 2, 4]) {
    testWidgets('$rounds turlu şema çizilir', (tester) async {
      await _pump(tester, _bracket(currentRound: 0, rounds: rounds));
      expect(tester.takeException(), isNull);
      expect(find.byType(TournamentBracketWidget), findsOneWidget);
    });
  }

  // ── Dayanıklılık ────────────────────────────────────────────────────────

  testWidgets('%200 yazıda dar telefonda taşma yok', (tester) async {
    await _pump(
      tester,
      _bracket(currentRound: 1),
      size: const Size(320, 1600),
      textScale: 2.0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('büyük skorlar taşmaz', (tester) async {
    await _pump(
      tester,
      _bracket(currentRound: 1, userScore: 98765, rivalScore: 87654),
      size: const Size(320, 1600),
      textScale: 2.0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kurmancî arayüzde taşma yok', (tester) async {
    await _pump(tester, _bracket(currentRound: 1), ku: true);
    expect(tester.takeException(), isNull);
  });

  testWidgets('karanlık temada kazanan adı okunur kalır', (tester) async {
    // Ham altın, kartın altın tonlu zemininde karanlık temada kayboluyordu.
    await _pump(tester, _bracket(currentRound: 1), mode: ThemeMode.dark);
    expect(tester.takeException(), isNull);
    final source = File(
      'lib/src/widgets/tournament_bracket_widget.dart',
    ).readAsStringSync();
    expect(
      source,
      isNot(contains('? AppTheme.gold\n                    : isDimmed')),
      reason: 'kazanan adı yeniden ham altına döndü',
    );
  });

  testWidgets('iPad tüm turları gösterir', (tester) async {
    await _pump(
      tester,
      _bracket(currentRound: 1),
      size: const Size(1194, 1400),
    );
    expect(find.text('Final'), findsWidgets);
    expect(tester.takeException(), isNull);
  });
}
