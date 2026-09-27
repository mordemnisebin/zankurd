import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/daily_mission.dart';
import 'package:zankurd_mobile/src/screens/home/daily_missions_card.dart';
import 'package:zankurd_mobile/src/screens/home/home_rows.dart';
import 'package:zankurd_mobile/src/screens/home/home_sections.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/app_panel.dart';
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
      expect(
        find.descendant(
          of: find.byType(DailyMissionsCard),
          matching: find.byType(AppPanel),
        ),
        findsNothing,
        reason: 'Home compact görev özeti dış kart kabuğu taşımamalı.',
      );
      expect(
        find.byKey(const ValueKey('home-missions-compact-section')),
        findsOneWidget,
      );
      final firstFlatMission = find.byKey(
        const ValueKey('home-mission-row-answerCorrect'),
      );
      expect(firstFlatMission, findsOneWidget);
      expect(
        tester.widget(firstFlatMission),
        isA<Padding>(),
        reason: 'Kompakt görev satırları mini kart kabuğu taşımamalı.',
      );
    });

    testWidgets(
      'görev özeti halka ve altın hero yerine sakin ilerleme kullanır',
      (tester) async {
        final missions = <DailyMission>[
          DailyMission(
            type: MissionType.answerCorrect,
            target: 10,
            coinReward: 50,
            progress: 4,
          ),
          DailyMission(
            type: MissionType.completeQuiz,
            target: 3,
            coinReward: 60,
          ),
        ];

        await tester.pumpWidget(
          _shell(
            Scaffold(
              body: DailyMissionsCard(
                isKu: false,
                missions: missions,
                compact: false,
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(CircularProgressIndicator), findsNothing);
        expect(
          find.byKey(const ValueKey('daily-missions-overall-progress')),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: find.byType(DailyMissionsCard),
            matching: find.byType(AppPanel),
          ),
          findsOneWidget,
          reason: 'Tam görev görünümü diğer ekranlarda panel olarak kalmalı.',
        );

        final headerIcon = tester.widget<Icon>(
          find.byIcon(AppIcons.circleCheck).first,
        );
        expect(
          headerIcon.color,
          AppColors.readableAccent(
            tester.element(find.byIcon(AppIcons.circleCheck).first),
            AppTheme.culturalBrandBg,
          ),
        );
      },
    );

    testWidgets('tamamlanan görev nötr yüzeyi ve marka durumunu korur', (
      tester,
    ) async {
      final mission = DailyMission(
        type: MissionType.answerCorrect,
        target: 10,
        coinReward: 50,
        progress: 10,
        completed: true,
      );

      await tester.pumpWidget(
        _shell(
          Scaffold(
            body: DailyMissionsCard(
              isKu: false,
              missions: [mission],
              compact: false,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final labelFinder = find.text('10 doğru cevap ver');
      final label = tester.widget<Text>(labelFinder);
      expect(
        label.style?.color,
        AppTheme.textMutedColor(tester.element(labelFinder)),
      );

      final headerIcon = tester.widget<Icon>(
        find.byIcon(AppIcons.circleCheck).first,
      );
      expect(
        headerIcon.color,
        AppColors.readableAccent(
          tester.element(find.byIcon(AppIcons.circleCheck).first),
          AppTheme.culturalBrandBg,
        ),
      );

      final doneIconFinder = find.byIcon(AppIcons.check);
      final doneIcon = tester.widget<Icon>(doneIconFinder);
      expect(
        doneIcon.color,
        AppColors.readableAccent(
          tester.element(doneIconFinder),
          AppTheme.culturalBrandBg,
        ),
      );
    });
  });

  group('Ana ekran konu ızgarası', () {
    // "Kaldığın yer" listesi 2026-09-27'de konu ızgarasına katıldı: aynı
    // konu ana ekranda hem yolda hem listede görünebiliyordu. Bekçinin
    // korduğu iki davranış ızgaraya taşındı — sahte ilerleme çizilmez ve
    // ilerleme yalnız gerçekten başlanmış konuda görünür.
    testWidgets(
      'başlanmamış konu sahte ilerleme çizmez, soru sayısını gösterir',
      (tester) async {
        await tester.pumpWidget(
          _shell(
            const Scaffold(
              body: SizedBox(
                width: 390,
                child: HomeTopicGrid(
                  isKu: false,
                  categories: ['Dîrok', 'Cografya'],
                  progress: {
                    'Dîrok': CategoryProgress(
                      category: 'Dîrok',
                      correct: 4,
                      threshold: 10,
                    ),
                    'Cografya': CategoryProgress(
                      category: 'Cografya',
                      correct: 0,
                      threshold: 10,
                    ),
                  },
                  questionCounts: {'Dîrok': 174, 'Cografya': 245},
                  onOpen: null,
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        final started = find.byKey(const ValueKey('home-topic-Dîrok'));
        final fresh = find.byKey(const ValueKey('home-topic-Cografya'));
        expect(
          find.descendant(
            of: started,
            matching: find.byType(LinearProgressIndicator),
          ),
          findsOneWidget,
        );
        expect(
          find.descendant(
            of: fresh,
            matching: find.byType(LinearProgressIndicator),
          ),
          findsNothing,
          reason: 'Başlanmamış konuda boş bir ilerleme çubuğu çizilmemeli.',
        );
        expect(
          find.descendant(of: fresh, matching: find.text('245 soru')),
          findsOneWidget,
        );
      },
    );

    testWidgets('karoya dokunmak o konuyu açar', (tester) async {
      String? opened;
      await tester.pumpWidget(
        _shell(
          Scaffold(
            body: SizedBox(
              width: 390,
              child: HomeTopicGrid(
                isKu: false,
                categories: const ['Ziman', 'Muzîk'],
                progress: const {},
                questionCounts: const {},
                onOpen: (category) => opened = category,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const ValueKey('home-topic-Muzîk')));
      expect(opened, 'Muzîk');
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
      // 2026-09-27: Paradigma ve Siyaset gizlendi (10 -> 8 görünür).
      expect(visible.length, greaterThanOrEqualTo(8));
    });
  });
}
