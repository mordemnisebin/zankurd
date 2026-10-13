/// "Günün soruları" yüklenirken sayfa zıplamamalı.
///
/// ## Kusur
///
/// Mağaza ekran görüntüsü turunda "Günün soruları" açılınca kartın üstünde
/// geniş boş bir alan göründü. Yükleniyor hâli ekranın ortasında dönen bir
/// gösterge çiziyordu; yüklenen kart ise kalan alanın üst üçte birine
/// (`Alignment(0, -0.6)`) oturuyordu. Yani gösterge ile kart farklı yerdeydi:
/// kart geldiğinde gösterge kayboluyor, kart yukarıda beliriyor ve ekran
/// bir an boş kalıyordu. Uygulamanın öteki ekranları yer tutucuyu gerçek
/// düzenin yerinde çizen iskelet kullanır (`SkeletonLine`).
///
/// ## Niçin sessiz kaldı
///
/// Testler yüklemeyi `pump(700 ms)` ile atlayıp yalnız yüklenmiş kartı
/// ölçüyordu; yükleniyor karesinde ne çizildiğine ve yüklenmiş kareyle aynı
/// yerde olup olmadığına bakan test yoktu. Sahte depo anında döndüğü için
/// geliştirmede bekleme hiç görünmez; gerçek ağda 1-2 sn sürer.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/models/contest.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/widgets/arena_kit.dart';
import 'package:zankurd_mobile/src/widgets/skeleton_loader.dart';

import 'support/widget_test_helpers.dart';

class _SlowRepo extends MockZanKurdRepository {
  final gate = Completer<Contest?>();

  @override
  Future<Contest?> loadTodayContest() => gate.future;
}

Contest _contest() => Contest(
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

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets(
    'yüklenirken iskelet çizilir ve kart geldiğinde aynı yerde belirir',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(390, 844);
      addTearDown(tester.view.reset);

      final repo = _SlowRepo();
      await tester.pumpWidget(
        testShell(child: ContestScreen(repository: repo)),
      );
      await tester.pump(const Duration(milliseconds: 700));

      // Yükleniyor: dönen gösterge değil, kartın yerinde iskelet.
      expect(find.byKey(const ValueKey('contest-skeleton')), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.byType(ArenaHero), findsNothing);
      final skeletonTop = tester
          .getTopLeft(find.byKey(const ValueKey('contest-skeleton')))
          .dy;
      final skeletonHeight = tester
          .getSize(find.byKey(const ValueKey('contest-skeleton')))
          .height;
      expect(find.byType(SkeletonLine), findsWidgets);

      repo.gate.complete(_contest());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.byKey(const ValueKey('contest-skeleton')), findsNothing);
      final heroRect = tester.getRect(find.byType(ArenaHero));
      // Kart, iskeletin bulunduğu yerden en çok birkaç punto oynar.
      expect(
        (heroRect.top - skeletonTop).abs(),
        lessThanOrEqualTo(8),
        reason:
            'Kart iskeletin ${heroRect.top - skeletonTop}pt altında/üstünde '
            'belirdi; sayfa zıpladı.',
      );
      final loaded = tester.getSize(
        find.byWidgetPredicate(
          (w) => w.runtimeType.toString() == '_ContestContent',
        ),
      );
      expect(
        loaded.height,
        closeTo(skeletonHeight, 24),
        reason:
            'İskeletin boyu ($skeletonHeight) yüklenen içeriğin boyundan '
            '(${loaded.height}) ayrıştı.',
      );
      expect(tester.takeException(), isNull);
    },
  );
}
