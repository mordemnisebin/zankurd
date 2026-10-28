// 2026-09-29 doğallık: arayüz metni sabitleyen beklentiler yeni metne göre güncellendi.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/tournament.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';
import 'package:zankurd_mobile/src/widgets/arena_kit.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';

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

  // 2026-10-28, kurul K16: ödül artık ayrı bir `RewardToken` ("200" +
  // "jeton · şampiyona" etiketi) değil, açıkça yazılmış tek satır:
  // "Ödül: 200 jeton" (Kurmancî "Xelat: 200 zêr"). Neden: "200" tek başına
  // ne olduğunu söylemiyordu. Beklenti aynı kalır — değer
  // `TournamentConfig`ten gelir, ekrana sabit yazılmaz.
  testWidgets('kupanın şampiyonluk ödülü lobide görünür', (tester) async {
    await _pump(tester);
    // Sunucu (`claim_tournament_reward`) sabit 200 ödüyor — 2026-08-14'e
    // kadar burada 500 yazıyordu.
    final reward = find.byKey(const ValueKey('tournament-reward'));
    expect(reward, findsOneWidget, reason: 'şampiyonluk ödülü görünmüyor');
    expect(
      tester.widget<Semantics>(reward).properties.label,
      'Ödül: ${TournamentConfig.coinBonusChampion} jeton',
    );
    expect(
      find.text('Ödül: ${TournamentConfig.coinBonusChampion} jeton'),
      findsOneWidget,
    );
  });

  testWidgets('Kurmancî kupada ödülün birimi zêr olarak okunur', (
    tester,
  ) async {
    await _pump(tester, ku: true);
    expect(
      find.text('Xelat: ${TournamentConfig.coinBonusChampion} zêr'),
      findsOneWidget,
    );
  });

  testWidgets('maç başı sahte bir ödül vaat edilmiyor', (tester) async {
    // `submit_tournament_match` maç başına hiçbir coin ödemiyor
    // (2026-08-14 denetimi). Lobi eskiden `TournamentConfig.
    // coinRewardPerMatch` (50) değerini "maç başı" etiketiyle
    // gösteriyordu — sunucu hiç ödemediği bir ödülü vaat ediyordu.
    await _pump(tester);
    expect(find.text('maç başı'), findsNothing);
  });

  testWidgets('ödül ortak jeton ikonuyla çizilir', (tester) async {
    await _pump(tester);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('tournament-reward')),
        matching: find.byType(SahneGlyph),
      ),
      findsOneWidget,
    );
  });

  // ── Biçim ───────────────────────────────────────────────────────────────

  testWidgets('kupanın yapısı gerçek yapılandırmadan gelir', (tester) async {
    await _pump(tester);
    expect(find.text('${TournamentConfig.totalPlayers}'), findsWidgets);
    expect(find.text('${TournamentConfig.roundCount}'), findsWidgets);
  });

  // 2026-10-27: canlı kupa 4 kişilik (tournaments.size); lobi eskiden
  // 16→8→4→2→1 diyordu.
  testWidgets('kupa yolu 4→2→1 basamaklarını gösterir', (tester) async {
    await _pump(tester);
    // Merdiven `generateBracket` ile aynı bölme mantığından türer; sabit
    // dizi yazılsaydı ikisi sessizce ayrışabilirdi.
    //
    // 2026-10-28 tur 5 W4: çipler ADLI ("Yarı Final 4 › Final 2 › Şampiyon");
    // çıplak sayılar neyin sayısı olduğunu söylemiyordu.
    //
    // 2026-10-29 tur 6 Y7: çıplak sayı birimli oldu — "Yarı Final · 4 oyuncu".
    for (final step in const [
      'Yarı Final · 4 oyuncu',
      'Final · 2 oyuncu',
      'Şampiyon',
    ]) {
      expect(find.text(step), findsOneWidget, reason: '$step basamağı yok');
    }
    expect(find.text('16'), findsNothing);
    expect(find.text('8'), findsNothing);
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
    // Katıldı/tamamlandı denmemeli. 2026-10-28, K16: "Başlamadı" durum çipi
    // kalktı — hemen altındaki "Turnuvaya katıl" düğmesiyle çelişiyordu.
    expect(find.text('Başlamadı'), findsNothing);
  });

  testWidgets('katılmamış oyuncuya durum çipi ile katıl düğmesi çelişmez', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byType(ArenaStatusChip), findsNothing);
    expect(
      find.byKey(const ValueKey('tournament-primary-cta')),
      findsOneWidget,
    );
  });

  testWidgets('ekran adı iki kez yazılmaz', (tester) async {
    // `ScreenIdentityHeader` + `ArenaHero` birlikte çizilince "ZanKurd
    // Kupası" ilk 300 pikselde iki kez yazıyordu — 2026-07-30'da
    // kapatılmış bir kusur, hero'ya geçerken geri geldi (2026-08-04).
    await _pump(tester);
    expect(find.text('ZanKurd Turnuvası'), findsOneWidget);
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

  testWidgets('ana eylem 48dp dokunma hedefini korur', (tester) async {
    await _pump(tester);
    final cta = find.byKey(const ValueKey('tournament-primary-cta'));
    expect(cta, findsOneWidget);
    expect(tester.getSize(cta).height, greaterThanOrEqualTo(48));
  });

  testWidgets('ana eylem ekran okuyucuya düğme olarak duyurulur', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(find.bySemanticsLabel('Turnuvaya katıl'), findsOneWidget);
    handle.dispose();
  });
}
