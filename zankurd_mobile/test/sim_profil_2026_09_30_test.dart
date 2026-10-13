// 2026-09-30 simülatör: profil denetiminin üç kusurunun bekçisi.
//
// 1. Avatar düzenleyicideki önizleme turuncu, Profil'deki aynı avatar mordu.
//    İkisi de kayıtlı bir renk yokken ad tohumundan renk türetiyordu ama
//    düzenleyici ham adı, profil dilden bağımsız tohumu veriyordu. Sessizdi:
//    iki ekran ayrı ayrı doğru görünüyordu, çelişki yalnız yan yana bakınca
//    çıkıyordu. Seçili simge/renk de yalnız görsel işaretliydi; ekran
//    okuyucu "seçili" demeli.
// 2. Profil istatistiğinde 390 XP ve 16 cevaplanmış soru varken "Sıralama" ve
//    "Toplam puan" karoları "Henüz yok" diyordu. Bu iki değer sunucu yarış
//    puanından gelir; veri yokken karo çelişki üretmek yerine gizlenir.
// 3. Alt konu satır ikonları: tanımsız alt konular hep yer imine düşüyordu;
//    Sînema'da iki satır aynı ikonu taşıyordu.
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/config/subcategory_config.dart';
import 'package:zankurd_mobile/src/data/achievement_store.dart';
import 'package:zankurd_mobile/src/data/mastery_store.dart';
import 'package:zankurd_mobile/src/data/mistake_store.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/l10n/lang.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/screens/avatar_editor_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/subcategory_screen.dart';
import 'package:zankurd_mobile/src/theme/app_icons.dart';
import 'package:zankurd_mobile/src/theme/app_theme.dart';
import 'package:zankurd_mobile/src/widgets/player_avatar.dart';

import 'support/widget_test_helpers.dart';

class _ZeroScoreRepository extends MockZanKurdRepository {
  @override
  Future<LeaderboardEntry?> getPlayerStats() async => const LeaderboardEntry(
    rank: 85,
    playerId: 'me',
    displayName: 'Lîstikvan',
    totalScore: 0,
    bestStreak: 0,
    roomsPlayed: 0,
  );
}

class _ScoredRepository extends MockZanKurdRepository {
  @override
  Future<LeaderboardEntry?> getPlayerStats() async => const LeaderboardEntry(
    rank: 7,
    playerId: 'me',
    displayName: 'Lîstikvan',
    totalScore: 1250,
    bestStreak: 3,
    roomsPlayed: 4,
  );
}

Color _avatarFill(WidgetTester tester, Finder avatar) {
  final box = tester.widget<ColoredBox>(
    find.descendant(of: avatar, matching: find.byType(ColoredBox)).first,
  );
  return box.color;
}

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    MasteryStore.resetInstance();
    AchievementStore.resetInstance();
    MistakeStore.resetInstance();
  });

  testWidgets('düzenleyici önizlemesi ve profil aynı avatar rengini çizer', (
    tester,
  ) async {
    final repo = MockZanKurdRepository();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider()..setLang('ku'),
          child: AvatarEditorScreen(repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final previewColor = _avatarFill(
      tester,
      find.byKey(const ValueKey('avatar-preview')),
    );

    await tester.pumpWidget(
      testShell(
        child: Scaffold(body: ProfileScreen(repository: repo)),
      ),
    );
    for (
      var i = 0;
      i < 40 &&
          find.byKey(const ValueKey('profile-avatar-edit')).evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    final profileColor = _avatarFill(
      tester,
      find.descendant(
        of: find.byKey(const ValueKey('profile-avatar-edit')),
        matching: find.byType(PlayerAvatar),
      ),
    );

    expect(previewColor, profileColor);
  });

  testWidgets('seçili simge ve renk ekran okuyucuda seçili bildirilir', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    tester.view.physicalSize = const Size(400, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark(),
        home: ChangeNotifierProvider<LanguageProvider>(
          create: (_) => LanguageProvider()..setLang('tr'),
          child: AvatarEditorScreen(repository: MockZanKurdRepository()),
        ),
      ),
    );
    await tester.pumpAndSettle();

    Future<ui.Tristate> selectedOf(ValueKey<String> key) async {
      await tester.scrollUntilVisible(
        find.byKey(key),
        120,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      return tester
          .getSemantics(find.byKey(key))
          .getSemanticsData()
          .flagsCollection
          .isSelected;
    }

    const iconKey = ValueKey('avatar-icon-newroz');
    const colorKey = ValueKey('avatar-color-#3DA968');
    expect(await selectedOf(iconKey), ui.Tristate.isFalse);
    expect(await selectedOf(colorKey), ui.Tristate.isFalse);

    await tester.tap(find.byKey(colorKey));
    await tester.pumpAndSettle();
    expect(await selectedOf(colorKey), ui.Tristate.isTrue);

    await tester.tap(find.byKey(iconKey));
    await tester.pumpAndSettle();
    expect(await selectedOf(iconKey), ui.Tristate.isTrue);
    handle.dispose();
  });

  testWidgets(
    'oynamış oyuncuda sunucu puanı yokken "Henüz yok" çelişkisi yok',
    (tester) async {
      final store = await MistakeStore.load();
      await store.markMistake('sim-q1', category: 'Ziman');
      await store.markResolved('sim-q1');

      await tester.pumpWidget(
        testShell(
          child: Scaffold(
            body: ProfileScreen(repository: _ZeroScoreRepository()),
          ),
        ),
      );
      await tester.pump();
      for (
        var i = 0;
        i < 40 && find.text('Cevaplanan soru').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 50));
      }

      expect(find.text('Cevaplanan soru'), findsOneWidget);
      expect(find.text('Henüz yok'), findsNothing);
      expect(find.text('Sıralama'), findsNothing);
      expect(find.text('Toplam puan'), findsNothing);
    },
  );

  testWidgets('sunucu puanı varsa sıralama ve toplam puan karoları görünür', (
    tester,
  ) async {
    final store = await MistakeStore.load();
    await store.markMistake('sim-q2', category: 'Ziman');
    await store.markResolved('sim-q2');

    await tester.pumpWidget(
      testShell(
        child: Scaffold(body: ProfileScreen(repository: _ScoredRepository())),
      ),
    );
    await tester.pump();
    for (
      var i = 0;
      i < 40 && find.text('Cevaplanan soru').evaluate().isEmpty;
      i++
    ) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.pump(const Duration(milliseconds: 1200));

    expect(find.text('Sıralama'), findsOneWidget);
    expect(find.text('Toplam puan'), findsOneWidget);
    expect(find.text('Henüz yok'), findsNothing);
  });

  test(
    'her alt konunun kendi ikonu var; aynı konu altında ikon tekrarlanmaz',
    () {
      for (final entry in SubcategoryConfig.subcategories.entries) {
        final seen = <IconData, String>{};
        for (final sub in entry.value) {
          final icon = subcategoryIconForTest(sub.id);
          expect(
            icon,
            isNot(AppIcons.bookmark),
            reason: '${entry.key}/${sub.id} yer imi yedeğine düşüyor',
          );
          expect(
            seen.containsKey(icon),
            isFalse,
            reason:
                '${entry.key}: ${sub.id} ile ${seen[icon]} aynı ikonu alıyor',
          );
          seen[icon] = sub.id;
        }
      }
    },
  );
}
