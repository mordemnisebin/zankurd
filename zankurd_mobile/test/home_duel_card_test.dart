// Ana ekran düello kartı (`HomeDuelCard`) bekçisi.
//
// ## Kusur
//
// 2026-10-13 sunucu verisi: kurulumdan sonraki hafta neredeyse kimse geri
// gelmiyordu (436 hesabın 413'ü misafir) ve ürünün rakipsiz yüzü olan
// sırayla düello yalnız Yarış sekmesindeydi; Ana ekran yalnız öğrenmeyi
// gösteriyordu. Sonucu hazır bir düello tek dönüş sebebidir.
//
// ## Niçin sessiz kalırdı
//
// Eksik bir kart hiçbir derleme ya da çalışma hatası üretmez. Bu dosya
// kartın üç durumunu (varsayılan, "Sonuç hazır", gizli), hedefinin Yarış
// sekmesindeki "Sırayla düello" ile aynı olduğunu, sayının yoklama
// döngüsüyle değil tek çekimle geldiğini ve kartın ikinci bir Agir (turuncu)
// dolgulu birincil düğme taşımadığını sabitler.
//
// 2026-10-19 SADELEŞME (bu dosya güncellendi): büyük bordo "Sırayla düello"
// kartı kompakt tek satırlık yüzey kartı oldu: solda başlık + kısa açıklama,
// sağda TEK ikincil düğme. Varsayılan durumda düğme ("Oyna") bir menü açar
// (Yeni düello / Arkadaşına meydan oku / Hızlı düello: eski kartın üç yolu,
// aynı hedefler); "Sıra sende" ve "Sonuç hazır" durumlarında düğme o eylemi
// yapar ve menü yanındaki ⋯ düğmesindedir (`home-duel-more`). Yani eskiden
// kartta doğrudan görünen "Yeni düello" ve "Hızlı düello" metin düğmeleri
// artık menüdedir; testler önce menüyü açar. İşlev kaybı yok, ağırlık azaldı.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/providers/remote_availability.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_inbox.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_play_screen.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_result_screen.dart';
import 'package:zankurd_mobile/src/screens/home/home_duel_card.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/matchmaking_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

import 'support/widget_test_helpers.dart';

/// `loadMyAsyncDuels` çağrılarını sayan depo.
class _CountingRepository extends MockZanKurdRepository {
  int loads = 0;

  @override
  Future<List<AsyncDuelSummary>> loadMyAsyncDuels() {
    loads++;
    return super.loadMyAsyncDuels();
  }
}

/// Rakibi bitirmiş, oyuncunun henüz görmediği (`seen == false`) düello
/// kurar: Rojda'ya karşı biten düello.
Future<void> _seedReadyDuel(
  MockZanKurdRepository repo, {
  String opponent = 'Rojda',
}) async {
  repo.addPendingAsyncDuelForTesting(
    opponentName: opponent,
    opponentCorrect: 0,
    opponentMs: 1,
  );
  final start = await repo.startAsyncDuel();
  for (var i = 0; i < start.questions.length; i++) {
    await repo.answerAsyncDuel(
      duelId: start.duelId,
      questionIndex: i,
      choice: 'A',
      responseMs: 1000,
    );
  }
}

Widget _card(
  MockZanKurdRepository repo, {
  bool enabled = true,
  RemoteAvailability? remote,
}) => testShell(
  remoteAvailability: remote,
  child: Scaffold(
    body: SingleChildScrollView(
      child: HomeDuelCard(repository: repo, asyncDuelEnabled: enabled),
    ),
  ),
);

/// Düello menüsünü açar: varsayılan durumda ana düğme, bekleyen durumda ⋯.
Future<void> _openMenu(WidgetTester tester, {bool pending = false}) async {
  await tester.tap(
    find.byKey(ValueKey(pending ? 'home-duel-more' : 'home-duel-primary')),
  );
  await tester.pumpAndSettle();
  expect(find.byKey(const ValueKey('home-duel-menu')), findsOneWidget);
}

Future<void> _useSurface(WidgetTester tester) async {
  await tester.binding.setSurfaceSize(const Size(390, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({'zankurd.onboarding.seen': true});
  });

  testWidgets('varsayılan: sırayla düello vaadi, yeni düello ve hızlı düello', (
    tester,
  ) async {
    await _useSurface(tester);
    await tester.pumpWidget(_card(freshMockRepository()));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-duel-card')), findsOneWidget);
    expect(find.text('Sırayla düello'), findsOneWidget);
    expect(find.text('Sen şimdi oyna, rakibin sonra'), findsOneWidget);
    // Kompakt kart: tek ikincil düğme; üç yol menüde.
    expect(find.text('Oyna'), findsOneWidget);
    expect(find.text('Yeni düello'), findsNothing);
    expect(find.text('Hızlı düello'), findsNothing);
    await _openMenu(tester);
    expect(find.text('Yeni düello'), findsOneWidget);
    expect(find.text('Hızlı düello'), findsOneWidget);
    expect(find.textContaining('Sonuç hazır'), findsNothing);
  });

  testWidgets('Sonuç hazır: tek düelloda rakip adı, sayı yok', (tester) async {
    await _useSurface(tester);
    final repo = freshMockRepository();
    await _seedReadyDuel(repo);
    await tester.pumpWidget(_card(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-duel-card-ready')), findsOneWidget);
    expect(find.text('Sonuç hazır'), findsOneWidget);
    expect(find.text('Rojda'), findsOneWidget);
    expect(find.text('Sen şimdi oyna, rakibin sonra'), findsNothing);
    // Yeni düello yine ulaşılabilir (⋯ menüsü).
    await _openMenu(tester, pending: true);
    expect(find.text('Yeni düello'), findsOneWidget);
  });

  testWidgets(
    'Sonuç hazır: birden çok düelloda sayıyı söyler ve listeyi açar',
    (tester) async {
      await _useSurface(tester);
      final repo = freshMockRepository();
      await _seedReadyDuel(repo, opponent: 'Rojda');
      await _seedReadyDuel(repo, opponent: 'Berfin');
      await tester.pumpWidget(_card(repo));
      await tester.pumpAndSettle();

      expect(find.text('Sonuç hazır · 2'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('home-duel-primary')));
      await tester.pumpAndSettle();
      expect(find.byType(AsyncDuelListScreen), findsOneWidget);
    },
  );

  testWidgets('Sonuç hazır: tek düelloda birincil doğrudan sonucu açar', (
    tester,
  ) async {
    await _useSurface(tester);
    final repo = freshMockRepository();
    await _seedReadyDuel(repo);
    await tester.pumpWidget(_card(repo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('home-duel-primary')));
    await tester.pumpAndSettle();
    expect(find.byType(AsyncDuelResultScreen), findsOneWidget);
  });

  testWidgets('görülmüş sonuç sayılmaz', (tester) async {
    await _useSurface(tester);
    final repo = freshMockRepository();
    await _seedReadyDuel(repo);
    final duels = await repo.loadMyAsyncDuels();
    await repo.markAsyncDuelSeen(duels.single.duelId);
    await tester.pumpWidget(_card(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-duel-card')), findsOneWidget);
    expect(find.textContaining('Sonuç hazır'), findsNothing);
  });

  testWidgets('bayrak kapalıyken kart çizilmez ve sayı çekilmez', (
    tester,
  ) async {
    await _useSurface(tester);
    final repo = _CountingRepository();
    await tester.pumpWidget(_card(repo, enabled: false));
    await tester.pumpAndSettle();

    expect(find.byType(SahneSurfaceCard), findsNothing);
    expect(find.byKey(const ValueKey('home-duel-primary')), findsNothing);
    expect(repo.loads, 0);
  });

  testWidgets('sunucuya ulaşılamıyorken kart çizilmez ve sayı çekilmez', (
    tester,
  ) async {
    await _useSurface(tester);
    final repo = _CountingRepository();
    await tester.pumpWidget(
      _card(repo, remote: RemoteAvailability(reachable: false)),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SahneSurfaceCard), findsNothing);
    expect(find.byKey(const ValueKey('home-duel-primary')), findsNothing);
    expect(find.byKey(const ValueKey('home-duel-secondary')), findsNothing);
    expect(repo.loads, 0);
  });

  testWidgets('sayı yoklanmaz: uzun beklemede tek çekim', (tester) async {
    await _useSurface(tester);
    final repo = _CountingRepository();
    await tester.pumpWidget(_card(repo));
    await tester.pumpAndSettle();
    await tester.pump(const Duration(minutes: 10));

    expect(repo.loads, 1);
  });

  testWidgets('sayı yüklenemezse varsayılan durum kalır', (tester) async {
    await _useSurface(tester);
    final repo = _FailingRepository();
    await tester.pumpWidget(_card(repo));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-duel-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('home-duel-primary')), findsOneWidget);
  });

  testWidgets('menüdeki "Yeni düello" sırayla düello oyun ekranını açar', (
    tester,
  ) async {
    await _useSurface(tester);
    await tester.pumpWidget(_card(freshMockRepository()));
    await tester.pumpAndSettle();
    await _openMenu(tester);
    await tester.tap(find.byKey(const ValueKey('home-duel-new')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AsyncDuelPlayScreen), findsOneWidget);
  });

  testWidgets('Yarış sekmesindeki "Sırayla düello" satırı AYNI ekranı açar '
      '(kart ile hedef ortaktır)', (tester) async {
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
    await tester.tap(find.byKey(const ValueKey('play-hub-async-duel')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(AsyncDuelPlayScreen), findsOneWidget);
  });

  testWidgets('menüdeki "Hızlı düello" eşleşme ekranını açar', (tester) async {
    await _useSurface(tester);
    await tester.pumpWidget(_card(freshMockRepository()));
    await tester.pumpAndSettle();
    await _openMenu(tester);
    await tester.tap(find.byKey(const ValueKey('home-duel-secondary')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(MatchmakingScreen), findsOneWidget);
  });

  testWidgets('düğmeler ikinci bir Agir dolgu değil: Kulis tonu / metin', (
    tester,
  ) async {
    await _useSurface(tester);
    final repo = freshMockRepository();
    await tester.pumpWidget(_card(repo));
    await tester.pumpAndSettle();

    final primary = find.byKey(const ValueKey('home-duel-primary'));
    final button = tester.widget<FilledButton>(
      find.descendant(of: primary, matching: find.byType(FilledButton)),
    );
    expect(
      button.style?.backgroundColor?.resolve(<WidgetState>{}),
      Colors.transparent,
      reason: 'Agir yalnız "Günün dersi" düğmesindedir; kart ikincil kalır.',
    );
    // Karttaki hiçbir düğme birincil (Agir) değil.
    final card = find.byKey(const ValueKey('home-duel-card'));
    final fills = tester
        .widgetList<FilledButton>(
          find.descendant(of: card, matching: find.byType(FilledButton)),
        )
        .map((b) => b.style?.backgroundColor?.resolve(<WidgetState>{}));
    expect(fills, everyElement(Colors.transparent));
  });

  testWidgets('Ana ekranda kart "Günün dersi" kartının hemen altındadır', (
    tester,
  ) async {
    await _useSurface(tester);
    await tester.pumpWidget(
      testShell(child: HomeScreen(repository: freshMockRepository())),
    );
    await tester.pump(const Duration(seconds: 1));

    final lesson = tester.getRect(
      find.byKey(const ValueKey('home-daily-task')),
    );
    final duel = tester.getRect(find.byKey(const ValueKey('home-duel-card')));
    final topics = tester.getRect(
      find.byKey(const ValueKey('home-topic-grid')),
    );
    expect(duel.top, greaterThanOrEqualTo(lesson.bottom));
    expect(duel.top - lesson.bottom, lessThan(32), reason: 'hemen altında');
    expect(topics.top, greaterThan(duel.bottom));
    // Turuncu yine yalnız günün dersinde.
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('home-daily-task')),
        matching: find.byType(FilledButton),
      ),
      findsOneWidget,
    );
  });

  testWidgets('Ana ekran, çevrimdışıyken kartı çizmez (boşluk da kalmaz)', (
    tester,
  ) async {
    await _useSurface(tester);
    await tester.pumpWidget(
      testShell(
        child: HomeScreen(repository: freshMockRepository()),
        remoteAvailability: RemoteAvailability(reachable: false),
      ),
    );
    await tester.pump(const Duration(seconds: 1));

    expect(find.byKey(const ValueKey('home-duel-card')), findsNothing);
    expect(find.byKey(const ValueKey('home-daily-task')), findsOneWidget);
  });
}

class _FailingRepository extends MockZanKurdRepository {
  @override
  Future<List<AsyncDuelSummary>> loadMyAsyncDuels() async {
    throw StateError('offline');
  }
}
