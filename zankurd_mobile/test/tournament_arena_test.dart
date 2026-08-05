import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';
import 'package:zankurd_mobile/src/widgets/arena_kit.dart';

import 'support/widget_test_helpers.dart';

/// Turnuva lobisinin oyuncuya verdiği sözleşmeler.
///
/// Lobi ikon + çip + paragraf + hap + paragraf + düğmeden oluşuyordu ve
/// ekranın yarısından fazlası boştu. Daha kötüsü: kupanın ÖDÜLÜ
/// (`coinRewardPerMatch`, `coinBonusChampion`) ve YAPISI (16 oyuncu,
/// 4 tur) `TournamentConfig`te sabit dururken ekranda hiç görünmüyordu —
/// oyuncu neye katıldığını okumadan karar veriyordu (2026-08-04).
///
/// Bekçilerin işi, o değerlerin ekrana geri düşmesini engellemek ve
/// hiçbirinin uydurulmadığını sabitlemek.
Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
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
        child: Scaffold(
          body: TournamentScreen(repository: MockZanKurdRepository()),
        ),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── Ödül ────────────────────────────────────────────────────────────────

  testWidgets('kupanın ödülü lobide görünür', (tester) async {
    await _pump(tester);
    // Değerler `TournamentConfig`ten gelir; ekrana sabit yazılmaz.
    expect(
      find.text('${TournamentConfig.coinRewardPerMatch}'),
      findsOneWidget,
      reason: 'maç başı ödül görünmüyor',
    );
    expect(
      find.text('${TournamentConfig.coinBonusChampion}'),
      findsOneWidget,
      reason: 'şampiyonluk ödülü görünmüyor',
    );
  });

  testWidgets('ödül ortak jeton bileşeniyle çizilir', (tester) async {
    await _pump(tester);
    expect(find.byType(RewardToken), findsWidgets);
  });

  // ── Biçim ───────────────────────────────────────────────────────────────

  testWidgets('kupanın yapısı gerçek yapılandırmadan gelir', (tester) async {
    await _pump(tester);
    expect(find.text('${TournamentConfig.totalPlayers}'), findsWidgets);
    expect(find.text('${TournamentConfig.roundCount}'), findsWidgets);
  });

  testWidgets('kupa yolu 16→8→4→2→1 basamaklarını gösterir', (tester) async {
    await _pump(tester);
    // Merdiven `generateBracket` ile aynı bölme mantığından türer; sabit
    // dizi yazılsaydı ikisi sessizce ayrışabilirdi.
    for (final step in const ['16', '8', '4', '2', '1']) {
      expect(find.text(step), findsWidgets, reason: '$step basamağı yok');
    }
  });

  // ── Dürüstlük ───────────────────────────────────────────────────────────

  testWidgets('katılmadan ilerleme veya kutlama gösterilmez', (tester) async {
    await _pump(tester);
    // Oyuncu henüz katılmadı: hiçbir ilerleme çubuğu çizilmemeli.
    expect(
      find.byType(LinearProgressIndicator),
      findsNothing,
      reason: 'katılmayan oyuncuya sahte ilerleme gösterildi',
    );
    // Durum "başlamadı"; katıldı/tamamlandı denmemeli.
    expect(find.text('Başlamadı'), findsOneWidget);
  });

  testWidgets('durum çipi ortak bileşenden gelir', (tester) async {
    await _pump(tester);
    expect(find.byType(ArenaStatusChip), findsWidgets);
  });

  testWidgets('ekran adı iki kez yazılmaz', (tester) async {
    // `ScreenIdentityHeader` + `ArenaHero` birlikte çizilince "ZanKurd
    // Kupası" ilk 300 pikselde iki kez yazıyordu — 2026-07-30'da
    // kapatılmış bir kusur, hero'ya geçerken geri geldi (2026-08-04).
    await _pump(tester);
    expect(find.text('ZanKurd Kupası'), findsOneWidget);
  });

  // ── Dayanıklılık ────────────────────────────────────────────────────────

  testWidgets('%200 yazıda dar telefonda taşma yok', (tester) async {
    await _pump(tester, size: const Size(320, 950), textScale: 2.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kurmancî arayüzde taşma yok', (tester) async {
    await _pump(tester, ku: true, size: const Size(320, 950), textScale: 2.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('karanlık temada çizim hatasız', (tester) async {
    await _pump(tester, mode: ThemeMode.dark);
    expect(tester.takeException(), isNull);
    expect(find.byType(ArenaHero), findsOneWidget);
  });

  // ── Geniş ekran ─────────────────────────────────────────────────────────

  testWidgets('iPad dikeyde iki sütun kullanılır', (tester) async {
    await _pump(tester, size: const Size(834, 1194));
    expect(
      find.byKey(const ValueKey('tournament-wide-column')),
      findsOneWidget,
      reason: 'tablet telefon düzenini gerdirmemeli',
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('iPad yatayda iki sütun kullanılır', (tester) async {
    await _pump(tester, size: const Size(1194, 834));
    expect(
      find.byKey(const ValueKey('tournament-wide-column')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('telefonda tek sütun korunur', (tester) async {
    await _pump(tester, size: const Size(440, 956));
    expect(find.byKey(const ValueKey('tournament-wide-column')), findsNothing);
  });

  // ── Erişilebilirlik ─────────────────────────────────────────────────────

  testWidgets('ana eylem 44pt dokunma hedefini korur', (tester) async {
    await _pump(tester);
    final cta = find.byKey(const ValueKey('tournament-primary-cta'));
    expect(cta, findsOneWidget);
    expect(tester.getSize(cta).height, greaterThanOrEqualTo(44));
  });

  testWidgets('ana eylem ekran okuyucuya düğme olarak duyurulur', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(find.bySemanticsLabel('Turnuvaya Katıl'), findsOneWidget);
    handle.dispose();
  });
}
