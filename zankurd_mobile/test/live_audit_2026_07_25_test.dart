import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/daily_mission.dart';
import 'package:zankurd_mobile/src/screens/home/daily_missions_card.dart';
import 'package:zankurd_mobile/src/screens/home/home_rows.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/config/category_visibility.dart';
import 'package:zankurd_mobile/src/config/category_visuals.dart';
import 'package:zankurd_mobile/src/utils/app_route.dart';

/// 2026-07-25 canlı iOS denetiminde bulunan davranışların regresyon testleri.
/// Her test, denetimde gerçekten görülen bir belirtiyi sabitler.

Widget _shell(Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<LanguageProvider>(
        create: (_) => LanguageProvider()..setLang('tr'),
      ),
    ],
    child: MaterialApp(theme: AppTheme.light(), home: child),
  );
}

void main() {
  group('AppRoute geçiş animasyonu', () {
    testWidgets('en üstteki sayfa dinlenme hâlinde kaymaz', (tester) async {
      // Belirti: push edilen her ekran kalıcı olarak ~%3 sola kayık
      // çiziliyor ve ekranın sağında siyah bir şerit kalıyordu. Neden:
      // giden sayfanın tween'i `begin: Offset(-0.03, 0)` idi ve
      // secondaryAnimation en üstteki rota için daima 0 olduğundan değer
      // `begin`de takılı kalıyordu.
      await tester.pumpWidget(
        _shell(
          Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                AppRoute.to(
                  const Scaffold(body: Center(child: Text('itilen'))),
                ),
              ),
              child: const Text('aç'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('aç'));
      await tester.pumpAndSettle();

      expect(find.text('itilen'), findsOneWidget);

      // Geçiş bittikten sonra sayfa tam olarak viewport'un sol kenarında
      // başlamalı — bir piksel bile kayma olmamalı.
      final pushed = tester.getTopLeft(find.text('itilen'));
      final centerX = tester.getCenter(find.text('itilen')).dx;
      expect(centerX, closeTo(400, 0.5)); // 800px test yüzeyinin ortası
      expect(pushed.dy.isFinite, isTrue);
    });
  });

  group('Günlük görev kartı', () {
    testWidgets('kırpılan açık görevler sayaçla tutarlı biçimde belirtilir', (
      tester,
    ) async {
      // Belirti: başlık "0/3 tamamlandı" diyordu ama kartta yalnız 2 görev
      // vardı; üçüncü satır kayıp gibi görünüyordu.
      final missions = <DailyMission>[
        DailyMission(
          type: MissionType.answerCorrect,
          target: 10,
          coinReward: 50,
        ),
        DailyMission(type: MissionType.completeQuiz, target: 3, coinReward: 60),
        DailyMission(type: MissionType.useWildcard, target: 2, coinReward: 40),
      ];

      await tester.pumpWidget(
        _shell(
          Scaffold(
            body: SingleChildScrollView(
              child: DailyMissionsCard(isKu: false, missions: missions),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('0/3 tamamlandı'), findsOneWidget);
      // Görünmeyen üçüncü görev artık açıkça sayılır.
      expect(find.textContaining('1 görev daha'), findsOneWidget);
    });
  });

  group('Ana ekran "kaldığın yer" bölümü', () {
    testWidgets('hiç ilerleme yokken sahte "kaldığın yer" listesi çizilmez', (
      tester,
    ) async {
      // Keşif ders yolunun içinden açılır; bu bölüm ikinci kapı olmaz.
      await tester.pumpWidget(
        _shell(
          Scaffold(
            body: ContinueSection(
              isKu: false,
              entries: const [
                CategoryProgress(category: 'Tarih', correct: 0, threshold: 10),
                CategoryProgress(
                  category: 'Coğrafya',
                  correct: 0,
                  threshold: 10,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kaldığın yer'), findsNothing);
      expect(find.text('Tüm kategoriler'), findsNothing);
      expect(find.byKey(const ValueKey('home-continue-section')), findsNothing);
    });

    testWidgets('ilerleme varsa yalnız başlanmış kategoriler listelenir', (
      tester,
    ) async {
      await tester.pumpWidget(
        _shell(
          Scaffold(
            body: ContinueSection(
              isKu: false,
              entries: const [
                CategoryProgress(category: 'Tarih', correct: 4, threshold: 10),
                CategoryProgress(
                  category: 'Coğrafya',
                  correct: 0,
                  threshold: 10,
                ),
              ],
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Kaldığın yer'), findsOneWidget);
      expect(find.text('Tarih'), findsOneWidget);
      // Başlanmamış kategori "kaldığın yer" listesine girmez.
      expect(find.text('Coğrafya'), findsNothing);
    });
  });

  group('Onboarding kategori sayısı', () {
    test('sabit değil, görünür kategori listesinden türer', () {
      // Sayı metne sabit yazılıydı ("8 kategori") ve Sînema eklenince
      // yanlışa düştü (2026-07-25). Kaynak, gizleme listesinden geçirilmiş
      // kategori listesi olmalı — sayı oradan türer.
      //
      // Teknolojî 2026-07-26'da, Sînema 2026-07-30'da açıldı (içerik
      // hazırlandı), bu yüzden artık ikisi de sayıma girer; test kategori
      // adı değil *mekanizma* üzerinden kurulur ki bir sonraki
      // açılış/kapanışta yine kırılmasın.
      final all = CategoryVisuals.colorDefinedCategories;
      final visible = visibleCategories(all);
      expect(
        visible.length,
        all.where((c) => !hiddenCategoryIds.contains(c)).length,
        reason: 'Görünür sayı, gizleme listesiyle tutarlı olmalı',
      );
      expect(visible.length, greaterThanOrEqualTo(9));
    });
  });
}
