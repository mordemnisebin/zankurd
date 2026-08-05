import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/contest.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/widgets/arena_kit.dart';

import 'support/widget_test_helpers.dart';

/// Günlük etkinlik ekranının görsel sistemi ve DÜRÜSTLÜK sınırı.
///
/// Ekran ikon + başlık + paragraf + tek hap + düğmeden oluşan bir beyaz
/// karttı; bu turda arena diline geçti. Ama geçişte kolay bir hata var ve
/// bu turda bir kez yapıldı:
///
/// `Contest` modeli tema adı, zorluk aralığı ve dört ödül basamağı
/// (`rank1/2/3Reward`, `participationReward`) taşır. "Modelde var, öyleyse
/// gösterelim" demek YANLIŞTIR — bu akışta hiçbiri gerçekleşmez:
/// `_startQuiz` soruları ortak günlük havuzdan (`Tevlihev`) çeker, oda
/// temanın kategorisini almaz ve quiz `contestId: null` ile açılır. Yani
/// yarışma kaydı oluşmaz, sıralama hesaplanmaz, sıralama ödülü ödenmez.
/// Onları ekrana yazmak, ürünün veremeyeceği bir söz vermek olurdu.
///
/// `daily_event_security_ui_test.dart` bu sınırı AKIŞ tarafından korur;
/// buradaki bekçiler GÖRSEL SİSTEM tarafından korur — yani yeni bir
/// bileşen eklenirken sözün geri sızmasını engeller.
class _Repo extends MockZanKurdRepository {
  _Repo({this.contest});

  final Contest? contest;

  @override
  Future<Contest?> loadTodayContest() async =>
      contest ??
      Contest(
        id: 'c1',
        dayKey: DateTime.utc(2026, 8, 4),
        themeNameKu: 'Pisporê Ziman',
        themeDescriptionKu: 'Bibe hostayê ziman!',
        themeNameTr: 'Dil Uzmanı',
        themeDescriptionTr: 'Dilin ustası ol!',
        category: 'Ziman',
        difficultyMin: 1,
        difficultyMax: 3,
        participationReward: 10,
        rank1Reward: 500,
        rank2Reward: 300,
        rank3Reward: 100,
        questionCount: 10,
      );
}

/// Bugün etkinlik olmayan depo.
class _EmptyRepo extends MockZanKurdRepository {
  @override
  Future<Contest?> loadTodayContest() async => null;
}

Future<void> _pump(
  WidgetTester tester, {
  Size size = const Size(390, 844),
  double textScale = 1.0,
  ThemeMode mode = ThemeMode.light,
  bool ku = false,
  Contest? contest,
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
        child: ContestScreen(repository: _Repo(contest: contest)),
      ),
    ),
  );
  await tester.pump(const Duration(milliseconds: 700));
  await tester.pump(const Duration(milliseconds: 700));
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  // ── Dürüstlük sınırı ────────────────────────────────────────────────────

  testWidgets('gerçekleşmeyen sıralama ödülü gösterilmez', (tester) async {
    // Depo 500/300/100 döndürüyor; ekran hiçbirini yazmamalı çünkü bu
    // akışta sıralama hiç hesaplanmıyor.
    await _pump(tester);
    for (final reward in const ['500', '300', '100']) {
      expect(
        find.text(reward),
        findsNothing,
        reason: '$reward ödülü vaat edildi ama bu akışta hiç ödenmiyor',
      );
    }
    expect(find.byType(RankMedal), findsNothing);
  });

  testWidgets('sorular temadan gelmiyorsa tema adı vaat edilmez', (
    tester,
  ) async {
    // Sorular `Tevlihev` havuzundan geliyor; "Dil Uzmanı" demek oyuncuya
    // dil soruları geleceğini söylemek olurdu.
    await _pump(tester);
    expect(find.text('Dil Uzmanı'), findsNothing);
    expect(find.text('Dilin ustası ol!'), findsNothing);
  });

  testWidgets('uygulanmayan zorluk aralığı gösterilmez', (tester) async {
    await _pump(tester);
    expect(find.text('1–3'), findsNothing);
    expect(find.text('1-3'), findsNothing);
  });

  testWidgets('başlamadan sahte ilerleme gösterilmez', (tester) async {
    await _pump(tester);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  // ── Gerçekleşen değerler ────────────────────────────────────────────────

  testWidgets('soru sayısı ve süre gerçek akıştan gelir', (tester) async {
    await _pump(tester);
    // Soru sayısı modelden, süre `kDailyEventSecondsPerQuestion`dan —
    // ikisi de gerçekten uygulanan değerler.
    expect(find.text('10 soru'), findsOneWidget);
    expect(
      find.text('$kDailyEventSecondsPerQuestion sn/soru'),
      findsOneWidget,
      reason: 'süre şeridi quiz odasının kullandığı sabitten okunmalı',
    );
  });

  testWidgets('sayı ve birimi tek metin düğümünde okunur', (tester) async {
    // Sayıyı etiketinden ayırmak ekran okuyucuya bağlamsız iki parça
    // okutuyordu.
    await _pump(tester);
    expect(find.text('10'), findsNothing);
    expect(find.text('10 soru'), findsOneWidget);
  });

  // ── Görsel sistem ───────────────────────────────────────────────────────

  testWidgets('ekran arena hero kullanır', (tester) async {
    await _pump(tester);
    expect(find.byType(ArenaHero), findsOneWidget);
    expect(find.byType(ArenaStatusChip), findsWidgets);
  });

  testWidgets('yarışma turnuvanın kopyası değil', (tester) async {
    await _pump(tester);
    // Turnuvanın kimlik öğeleri burada YOK.
    expect(find.text('Kupa yolu'), findsNothing);
    expect(find.textContaining('Eleme kupası'), findsNothing);
    // Kendi kimliği var: bugüne ait, doğrudan bir etkinlik.
    expect(find.text('Bugün'), findsOneWidget);
  });

  testWidgets('ekranın adı oyun merkezindeki girişle eşleşir', (tester) async {
    // Kimlik bandı kalır: hero "Günün 10 Sorusu" der, bant ekranın adını.
    await _pump(tester);
    expect(find.text('Günün Etkinliği'), findsWidgets);
  });

  // ── Durumlar ────────────────────────────────────────────────────────────

  testWidgets('etkinlik yoksa dürüst boş durum gösterilir', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      testShell(child: ContestScreen(repository: _EmptyRepo())),
    );
    await tester.pump(const Duration(milliseconds: 700));
    await tester.pump(const Duration(milliseconds: 700));
    expect(find.byType(ArenaHero), findsNothing);
    expect(find.text('Günün Etkinliği'), findsOneWidget);
  });

  // ── Dayanıklılık ────────────────────────────────────────────────────────

  testWidgets('%200 yazıda dar telefonda taşma yok', (tester) async {
    await _pump(tester, size: const Size(320, 950), textScale: 2.0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('Kurmancî arayüzde %200 yazıda taşma yok', (tester) async {
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
    expect(find.byKey(const ValueKey('contest-wide-column')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('iPad yatayda iki sütun kullanılır', (tester) async {
    await _pump(tester, size: const Size(1194, 834));
    expect(find.byKey(const ValueKey('contest-wide-column')), findsOneWidget);
  });

  testWidgets('telefonda tek sütun korunur', (tester) async {
    await _pump(tester, size: const Size(440, 956));
    expect(find.byKey(const ValueKey('contest-wide-column')), findsNothing);
  });

  // ── Erişilebilirlik ─────────────────────────────────────────────────────

  testWidgets('ana eylem görünür ve çizim hatasız', (tester) async {
    await _pump(tester);
    expect(find.text('Etkinliğe başla'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('durum çipi ekran okuyucuya okunur', (tester) async {
    final handle = tester.ensureSemantics();
    await _pump(tester);
    expect(find.bySemanticsLabel(RegExp('Bugün')), findsWidgets);
    handle.dispose();
  });
}
