import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/xp_store.dart';
import 'package:zankurd_mobile/src/l10n/strings.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/match_history.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_in_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_up_screen.dart';
import 'package:zankurd_mobile/src/widgets/sahne/sahne.dart';
import 'package:zankurd_mobile/src/widgets/lesson_scroll_edge_fade.dart';
import 'package:zankurd_mobile/src/utils/profile_tab_request.dart';

import 'support/t15_capture.dart';
import 'support/widget_test_helpers.dart';

class _StatsRepo extends MockZanKurdRepository {
  int requests = 0;
  Completer<({int correct, int wrong})?>? pending;
  bool fail = true;
  ({int correct, int wrong})? totals = (correct: 8, wrong: 7);

  @override
  Future<({int correct, int wrong})?> loadOnlineAnswerStats() async {
    requests++;
    if (pending != null) return pending!.future;
    if (fail) throw StateError('offline');
    return totals;
  }

  @override
  Future<LeaderboardEntry?> getPlayerStats() async => const LeaderboardEntry(
    rank: 9,
    playerId: 'guest',
    displayName: 'Azad',
    totalScore: 3400,
    bestStreak: 4,
    roomsPlayed: 4,
  );
}

const _capture = bool.fromEnvironment('T15_CAPTURE');
const _before = bool.fromEnvironment('T15_BEFORE');
final _frame = GlobalKey();

Future<void> _shot(WidgetTester tester, String name) async {
  if (!_capture) return;
  await tester.pump();
  final boundary =
      _frame.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 2);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    final parts = RegExp(r'^(S\d+(?:_S\d+)*)_(.*)$').firstMatch(name)!;
    for (final id in parts.group(1)!.split('_')) {
      await File(
        '/Users/kocer/Projects/zankurd_kapisma/t15/kanit/${id}_${_before ? 'once' : 'sonra'}_${parts.group(2)}.png',
      ).writeAsBytes(bytes!.buffer.asUint8List());
    }
    image.dispose();
  });
}

Future<void> _open(
  WidgetTester tester,
  Widget screen, {
  bool ku = false,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  tester.view.padding = const FakeViewPadding(top: 47, bottom: 34);
  debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
  addTearDown(() {
    tester.view.reset();
    debugDefaultTargetPlatformOverride = null;
  });
  await tester.pumpWidget(
    testShell(
      reducedMotion: true,
      languageProvider: ku ? kurmanciLang() : turkishLang(),
      child: RepaintBoundary(key: _frame, child: screen),
    ),
  );
  for (var i = 0; i < 45; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  setUpAll(loadT15Fonts);
  setUp(freshMockRepository);

  for (final ku in [false, true]) {
    testWidgets(
      'S18 S19 ${ku ? 'KU' : 'TR'} retry loading failure success empty',
      (tester) async {
        final repo = _StatsRepo()
          ..serverRecordsForTesting = const ServerRecords(bestQuizStreak: 7);
        await _open(
          tester,
          Scaffold(body: ProfileScreen(repository: repo)),
          ku: ku,
        );
        final error = find.byKey(
          const ValueKey('profile-answer-stats-unavailable'),
        );
        await tester.ensureVisible(error);
        await tester.pumpAndSettle();
        await _shot(tester, 'S18_S19_${ku ? 'KU' : 'TR'}_hata');
        if (_before) {
          debugDefaultTargetPlatformOverride = null;
          return;
        }
        expect(
          find.text(ku ? 'Statîstîkên bersivan' : 'Yanıt istatistikleri'),
          findsOneWidget,
        );
        final retry = find.byKey(const ValueKey('profile-answer-stats-retry'));
        expect(tester.widget<SahneButton>(retry).isPrimary, isFalse);
        expect(
          find.byKey(const ValueKey('profile-record-quiz-streak')),
          findsOneWidget,
        );
        expect(
          find.text(ku ? 'Dîsa biceribîne' : 'Yeniden dene'),
          findsOneWidget,
        );
        repo.pending = Completer();
        await tester.ensureVisible(retry);
        await tester.tap(retry);
        await tester.pump();
        expect(
          find.byKey(const ValueKey('profile-answer-stats-loading')),
          findsOneWidget,
        );
        await tester.tap(retry);
        await tester.pump();
        expect(repo.requests, 2, reason: 'yüklemede ikinci istek gönderilmez');
        expect(
          find.byKey(const ValueKey('profile-record-quiz-streak')),
          findsOneWidget,
        );
        await _shot(tester, 'S18_${ku ? 'KU' : 'TR'}_yukleniyor');
        repo.pending!.completeError(StateError('offline'));
        await tester.pumpAndSettle();
        expect(tester.widget<SahneButton>(retry).onPressed, isNotNull);
        repo.pending = Completer();
        await tester.tap(retry);
        await tester.pump();
        repo.pending!.complete((correct: 8, wrong: 7));
        await tester.pumpAndSettle();
        expect(error, findsNothing);
        expect(find.text('15'), findsOneWidget);
        await _shot(tester, 'S18_${ku ? 'KU' : 'TR'}_basari');
        await tester.pumpWidget(const SizedBox());
        repo.pending = null;
        repo.fail = false;
        repo.totals = (correct: 0, wrong: 0);
        await _open(
          tester,
          Scaffold(body: ProfileScreen(repository: repo)),
          ku: ku,
        );
        final empty = find.byKey(const ValueKey('profile-answer-stats-empty'));
        await tester.ensureVisible(empty);
        await tester.pumpAndSettle();
        expect(empty, findsOneWidget);
        expect(error, findsNothing);
        expect(retry, findsNothing);
        await _shot(tester, 'S18_${ku ? 'KU' : 'TR'}_bos');
        debugDefaultTargetPlatformOverride = null;
      },
    );
  }

  testWidgets('S22 S24 S25 kayıt ilk görünüm ve doğrulama', (tester) async {
    await _open(tester, const SignUpScreen());
    await _shot(tester, 'S22_S24_S25_kayit_ilk');
    if (_before) {
      debugDefaultTargetPlatformOverride = null;
      return;
    }
    final email = find.byType(EditableText).first;
    final dock = find.byKey(const ValueKey('entry-dock'));
    expect(tester.getRect(email).bottom, lessThan(tester.getRect(dock).top));
    expect(find.text('Apple ile kaydol').hitTestable(), findsOneWidget);
    expect(find.text('Google ile kaydol').hitTestable(), findsOneWidget);
    expect(
      find.text('Devam etmek için e-posta adresini gir').hitTestable(),
      findsOneWidget,
    );
    expect(
      find
          .text(
            '1. E-posta ve parola → 2. Kullanıcı adı → 3. Kontrol et ve hesabı oluştur',
          )
          .hitTestable(),
      findsOneWidget,
    );
    final next = find.byKey(const ValueKey('signup-next'));
    expect(tester.widget<SahneButton>(next).onPressed, isNull);
    await tester.enterText(email, 'yanlis@');
    await tester.pump();
    expect(find.text('Geçerli bir e-posta gir'), findsOneWidget);
    expect(tester.widget<SahneButton>(next).onPressed, isNull);
    await _shot(tester, 'S25_eposta_hata');
    await tester.enterText(email, 'rojda@example.com');
    await tester.pump();
    expect(tester.widget<SahneButton>(next).onPressed, isNotNull);
    await tester.tap(next);
    await tester.pump();
    expect(
      find.text('1/3'),
      findsOneWidget,
      reason: 'geçerli e-posta parola doğrulamasını atlatmaz',
    );
    expect(find.text('Parola gerekli'), findsOneWidget);
    await tester.enterText(find.byType(EditableText).at(1), 'sifre123');
    await tester.enterText(find.byType(EditableText).at(2), 'sifre123');
    await tester.pump();
    expect(tester.widget<SahneButton>(next).onPressed, isNotNull);
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byType(EditableText).at(2));
    await tester.pumpAndSettle();
    expect(
      tester.getRect(find.byType(EditableText).at(2)).bottom,
      lessThanOrEqualTo(544),
    );
    await _shot(tester, 'S22_kayit_klavye');
    await tester.ensureVisible(next);
    await tester.pumpAndSettle();
    expect(next.hitTestable(), findsOneWidget);
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('S23 misafir anlamı cihaz açıklaması ve tek birincil', (
    tester,
  ) async {
    await _open(tester, const SignInScreen());
    await _shot(tester, 'S23_giris');
    if (_before) {
      debugDefaultTargetPlatformOverride = null;
      return;
    }
    for (final label in [
      'Misafir olarak oyna',
      'Apple ile devam et',
      'Google ile devam et',
    ]) {
      expect(find.text(label).hitTestable(), findsOneWidget);
    }
    expect(
      find.byKey(const ValueKey('sign-in-guest-storage')).hitTestable(),
      findsOneWidget,
    );
    final primary = tester
        .widgetList<SahneButton>(find.byType(SahneButton))
        .where((b) => b.isPrimary);
    expect(primary, hasLength(1));
    expect(primary.single.label, 'Misafir olarak oyna');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('S20 gerçek profil dock üstünde son maç bütünüyle okunur', (
    tester,
  ) async {
    final repo = _StatsRepo()..fail = false;
    repo.recentMatchesForTesting = List.generate(
      10,
      (i) => RecentMatch(
        kind: RecentMatchKind.async,
        id: 's20-$i',
        result: RecentMatchResult.win,
        playedAt: DateTime(2026, 10, 30 - i),
        opponentName: 'Heval $i',
        myScore: 320,
        opponentScore: 250,
      ),
    );
    await _open(tester, AppShell(repository: repo));
    ProfileTabRequest.request();
    await tester.pumpAndSettle();
    final profile = find.byType(ProfileScreen);
    expect(profile, findsOneWidget);
    expect(
      find.ancestor(of: profile, matching: find.byType(LessonScrollEdgeFade)),
      findsNothing,
    );
    final last = find.byKey(const ValueKey('profile-match-s20-9'));
    await Scrollable.ensureVisible(tester.element(last), alignment: .65);
    await tester.pumpAndSettle();
    final row = tester.getRect(last);
    final dock = tester.getRect(find.byKey(const ValueKey('nav-profile')));
    expect(row.bottom, lessThanOrEqualTo(dock.top));
    expect(find.text('Heval 9').hitTestable(), findsOneWidget);
    expect(
      find.descendant(of: last, matching: find.byType(Text)).hitTestable(),
      findsAtLeastNWidgets(3),
    );
    await _shot(tester, 'S20_son_mac');
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('S22 S23 KU kayıt ilk görünüm ve giriş klavye hata', (
    tester,
  ) async {
    await _open(tester, const SignUpScreen(), ku: true);
    final email = find.byType(EditableText).first;
    final dock = find.byKey(const ValueKey('entry-dock'));
    expect(tester.getRect(email).bottom, lessThan(tester.getRect(dock).top));
    expect(find.text('Wek mêvan bilîze').hitTestable(), findsOneWidget);
    await _shot(tester, 'S22_S24_S25_KU_kayit_ilk');
    await tester.pumpWidget(const SizedBox());
    await _open(tester, const SignInScreen());
    await tester.tap(find.byKey(const ValueKey('sign-in-have-account')));
    await tester.pumpAndSettle();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    await tester.enterText(find.byType(EditableText).first, 'yanlis');
    await tester.pumpAndSettle();
    final error = find.text('Geçerli bir e-posta gir');
    await tester.ensureVisible(error);
    await tester.pumpAndSettle();
    expect(error.hitTestable(), findsOneWidget);
    expect(tester.getRect(error).bottom, lessThanOrEqualTo(544));
    await _shot(tester, 'S23_giris_klavye_hata');
    expect(tester.takeException(), isNull);
    debugDefaultTargetPlatformOverride = null;
  });

  for (final ku in [false, true]) {
    testWidgets('S26 ${ku ? 'KU' : 'TR'} XP sayı oran kalan ve semantics', (
      tester,
    ) async {
      await XPStore.loadForTest(809);
      await _open(
        tester,
        Scaffold(body: ProfileScreen(repository: _StatsRepo())),
        ku: ku,
      );
      await _shot(tester, 'S26_${ku ? 'KU' : 'TR'}_xp');
      if (_before) {
        debugDefaultTargetPlatformOverride = null;
        return;
      }
      final label = ku
          ? 'Di vê astê de: 809 / 1.000 XP'
          : 'Bu seviyede: 809 / 1.000 XP';
      expect(find.text(label), findsOneWidget);
      final bar = tester.widget<SahneProgressBar>(
        find.byKey(const ValueKey('profile-level-xp-progress')),
      );
      expect(bar.value, closeTo(.809, .00001));
      expect(bar.semanticLabel, contains(label));
      final semantics = tester.ensureSemantics();
      await tester.pump();
      expect(
        tester
            .getSemantics(
              find.byKey(const ValueKey('profile-level-xp-progress')),
            )
            .label,
        contains(label),
      );
      semantics.dispose();
      expect(
        bar.semanticLabel,
        contains(Tr.forKu(K.profileXpToNext, ku, {'n': '191'})),
      );
      debugDefaultTargetPlatformOverride = null;
    });
  }
}
