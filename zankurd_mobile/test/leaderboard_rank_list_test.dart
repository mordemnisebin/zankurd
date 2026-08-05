import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/widgets/arena_kit.dart';

import 'support/widget_test_helpers.dart';

/// Sıralama listesinin ve oyuncu bağlamının sözleşmeleri.
///
/// Liste on ayrı beyaz kart olarak çiziliyordu: her satırın kendi kenarlığı,
/// kendi dolgusu, kendi dış boşluğu. Sırayla okunması gereken bir listede bu
/// on ayrı "bu bir kart" sinyali demekti — göz ritmi yakalayamıyordu. Ayrıca
/// oyuncunun kendi satırı yalnız listenin DIŞINA sabitlendiğinde
/// vurgulanıyordu; görünür listenin içindeyken hiçbir ayrımı yoktu, yani
/// tablonun en çok aranan bilgisi ("ben neredeyim") kayboluyordu.

/// Verilen kadar oyuncu döndüren depo; `selfIndex` verilirse o sıradaki
/// oyuncu mevcut kullanıcıdır (`MockZanKurdRepository.currentUserId`).
class _Repo extends MockZanKurdRepository {
  _Repo({this.count = 12, this.selfIndex, this.name = 'Oyuncu', this.score});

  final int count;
  final int? selfIndex;
  final String name;
  final int? score;

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 20,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async => List.generate(
    count,
    (i) => LeaderboardEntry(
      playerId: i == selfIndex ? 'user' : 'other-$i',
      displayName: i == selfIndex ? name : '$name ${i + 1}',
      totalScore: score ?? (5000 - i * 100),
      bestStreak: 5,
      roomsPlayed: 10,
      rank: i + 1,
    ),
  );

  @override
  Future<LeaderboardEntry?> getPlayerStats() async => null;
}

/// Oyuncu görünür listenin dışında (47. sırada).
class _OutsideRepo extends _Repo {
  _OutsideRepo() : super(count: 10);

  @override
  Future<LeaderboardEntry?> getPlayerStats() async => const LeaderboardEntry(
    playerId: 'user',
    displayName: 'Rojhat',
    totalScore: 210,
    bestStreak: 1,
    roomsPlayed: 3,
    rank: 47,
  );
}

Future<void> _pump(
  WidgetTester tester,
  MockZanKurdRepository repo, {
  Size? size,
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.light,
}) async {
  if (size != null) {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
  }
  await tester.pumpWidget(
    testShell(
      themeProvider: ThemeProvider(initialMode: mode),
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: Scaffold(body: LeaderboardScreen(repository: repo)),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 600));
  await tester.pump(const Duration(milliseconds: 600));
}

/// Telefon görünümü. Varsayılan test yüzeyi 800x600'dür; bu, geniş düzen
/// eşiğinin (720) ÜSTÜNDEDİR. Dar düzeni sınayan her test boyutu açıkça
/// vermelidir, yoksa farkında olmadan tablet dalını sınar.
const _phone = Size(390, 844);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── Liste yüzeyi ────────────────────────────────────────────────────────

  test('satırlar ayrı kart anatomisine geri dönmüyor', () {
    final source = File(
      'lib/src/screens/leaderboard_screen.dart',
    ).readAsStringSync();
    // Gruplu satır kendi dış boşluğunu ve kabuğunu taşımaz.
    expect(source, contains('_RankListSurface'));
    expect(source, contains('grouped: true'));
    expect(
      source,
      contains('margin: grouped'),
      reason: 'gruplu satır kendi dış margin’ini almamalı',
    );
    expect(
      source,
      contains('border: grouped'),
      reason: 'gruplu satır kendi kenarlığını almamalı',
    );
  });

  testWidgets('sıralama satırları tek yüzeyde toplanır', (tester) async {
    await _pump(tester, _Repo(count: 12));
    // 12 oyuncunun 3'ü podyumda; kalan 9 satır TEK yüzeyde.
    final rows = find.byKey(const ValueKey('leaderboard-rank-row-4'));
    expect(rows, findsOneWidget);
    // Ayraçlar satırları böler — kartlar değil.
    expect(find.byType(Divider), findsWidgets);
  });

  testWidgets('liste sıralarında RankMedal kullanılır', (tester) async {
    await _pump(tester, _Repo(count: 12));
    expect(
      find.byType(RankMedal),
      findsWidgets,
      reason: 'sıra işareti ortak arena bileşeninden gelmeli',
    );
  });

  // ── Mevcut kullanıcı bağlamı ────────────────────────────────────────────

  testWidgets('görünür listedeki kendi satırı ayrışır', (tester) async {
    // 6. sıradaki oyuncu mevcut kullanıcı: podyumda değil, listede.
    // Boyut AÇIKÇA telefon: varsayılan test yüzeyi 800x600'dür ve geniş
    // düzen eşiğinin (720) üstünde kalır — o dalda sol sütun ayrıca bir
    // özet çizer, yani "Sen" iki kez görünür ve bu test yanlış yerde
    // kırılırdı.
    await _pump(tester, _Repo(count: 12, selfIndex: 5), size: _phone);
    expect(
      find.text('Sen'),
      findsOneWidget,
      reason: 'kendi satırı yalnız renkle değil, metinle de işaretlenmeli',
    );
  });

  testWidgets('kendi satırında bildir düğmesi yok', (tester) async {
    await _pump(tester, _Repo(count: 12, selfIndex: 5));
    expect(
      find.byKey(const ValueKey('leaderboard-report-user')),
      findsNothing,
      reason: 'kişi kendini bildiremez',
    );
    // Başkalarınınki durur.
    expect(find.byKey(const ValueKey('leaderboard-report-other-6')), findsOne);
  });

  testWidgets('kendi satırı vurgu için turuncuya boyanmaz', (tester) async {
    // Turuncu birincil eylem rengi; sıralamadaki konum bir eylem değil.
    final source = File(
      'lib/src/screens/leaderboard_screen.dart',
    ).readAsStringSync();
    // Yalnız `_RankRow` gövdesi; sonraki sınıflar kendi renklerini taşır.
    final start = source.indexOf('class _RankRow');
    final end = source.indexOf('\nclass ', start + 1);
    final rowBlock = source.substring(start, end);
    expect(
      rowBlock,
      isNot(contains('AppTheme.brand')),
      reason: 'kendi satırı CTA rengine boyanınca düğme gibi görünüyordu',
    );
  });

  testWidgets('liste dışındaki oyuncu sabit satırla görünür', (tester) async {
    await _pump(tester, _OutsideRepo());
    expect(
      find.byKey(const ValueKey('leaderboard-my-rank-row')),
      findsOneWidget,
    );
  });

  testWidgets('sıralanmamış oyuncuya sahte sıra gösterilmez', (tester) async {
    // `getPlayerStats` null: sahte "#0" veya "—" satırı çizilmemeli.
    await _pump(tester, _Repo(count: 10));
    expect(find.byKey(const ValueKey('leaderboard-my-rank-row')), findsNothing);
    expect(find.text('#0'), findsNothing);
  });

  // ── Kullanıcı sayısı durumları ──────────────────────────────────────────

  for (final count in const [1, 2, 3, 4]) {
    testWidgets('$count oyuncuyla çizim hatasız', (tester) async {
      await _pump(tester, _Repo(count: count));
      expect(tester.takeException(), isNull);
      // Sahte dolgu yok: 4. sıra ancak gerçekten varsa çizilir.
      expect(
        find.byKey(const ValueKey('leaderboard-rank-row-4')),
        count >= 4 ? findsOneWidget : findsNothing,
      );
    });
  }

  // ── Dayanıklılık ────────────────────────────────────────────────────────

  testWidgets('uzun ad, büyük skor ve %200 yazı taşmaz', (tester) async {
    await _pump(
      tester,
      _Repo(
        count: 12,
        selfIndex: 5,
        name: 'Şehmûs Alîyê Zînarê Kurmancî',
        score: 987654321,
      ),
      size: const Size(320, 900),
      textScale: 2.0,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('karanlık temada çizim hatasız', (tester) async {
    await _pump(
      tester,
      _Repo(count: 12, selfIndex: 5),
      size: _phone,
      mode: ThemeMode.dark,
    );
    expect(tester.takeException(), isNull);
    expect(find.text('Sen'), findsOneWidget);
  });

  // ── iPad iki sütun ──────────────────────────────────────────────────────

  testWidgets('iPad dikeyde iki sütun kullanılır', (tester) async {
    // iPad mini dikey: 744 pt.
    await _pump(tester, _Repo(count: 12), size: const Size(744, 1133));
    expect(
      find.byKey(const ValueKey('leaderboard-wide-list')),
      findsOneWidget,
      reason: 'tablet telefon düzenini gerdirmemeli',
    );
  });

  testWidgets('iPad yatayda iki sütun kullanılır', (tester) async {
    await _pump(tester, _Repo(count: 12), size: const Size(1194, 834));
    expect(find.byKey(const ValueKey('leaderboard-wide-list')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('geniş ekranda kendi sıra özeti bağlam sütununda', (
    tester,
  ) async {
    // Sağdaki uzun listenin ortasındaki kendi satırın sola da özetlenir;
    // sol sütun podyumdan sonra bomboş kalıyordu.
    await _pump(
      tester,
      _Repo(count: 12, selfIndex: 5),
      size: const Size(744, 1133),
    );
    expect(find.text('Sen'), findsNWidgets(2));
  });

  testWidgets('podyumdaki oyuncuya ikinci özet çizilmez', (tester) async {
    // Kimliği zaten en büyük öğede duruyor; ikinci bir özet aynı şeyi iki
    // kez söylerdi.
    await _pump(
      tester,
      _Repo(count: 12, selfIndex: 0),
      size: const Size(744, 1133),
    );
    expect(find.text('Sen'), findsNothing);
  });

  testWidgets('telefonda tek sütun korunur', (tester) async {
    // En geniş telefon 440 pt; eşik 720.
    await _pump(tester, _Repo(count: 12), size: const Size(440, 956));
    expect(
      find.byKey(const ValueKey('leaderboard-wide-list')),
      findsNothing,
      reason: 'dar düzen bozulmamalı',
    );
  });

  // ── Erişilebilirlik ─────────────────────────────────────────────────────

  testWidgets('bildir düğmesi 44pt dokunma hedefini korur', (tester) async {
    await _pump(tester, _Repo(count: 12));
    final button = find.byKey(const ValueKey('leaderboard-report-other-4'));
    expect(button, findsOneWidget);
    final size = tester.getSize(button);
    expect(size.height, greaterThanOrEqualTo(44));
    expect(size.width, greaterThanOrEqualTo(44));
  });

  testWidgets('satır tek semantik düğümde okunur', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester, _Repo(count: 12, selfIndex: 5), size: _phone);
    // Kendi satırı "senin sıran" olarak duyurulur.
    expect(
      find.bySemanticsLabel(RegExp('[Ss]enin sıran')),
      findsOneWidget,
      reason: 'renk tek kanal olamaz; ekran okuyucu da söylemeli',
    );
    handle.dispose();
  });
}
