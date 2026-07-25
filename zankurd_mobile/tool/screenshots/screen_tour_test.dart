// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/screens/paywall_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';

import '../../test/support/widget_test_helpers.dart';

/// Uygulamanın her ekranını gerçek widget ağacıyla açıp PNG'ye basar.
///
/// Neden test koşucusunda? Tarayıcı önizleme paneli gizlendiğinde Flutter
/// web kare üretmeyi durduruyor (`document.visibilityState == 'hidden'`) ve
/// panel üzerinden uzun bir gezinti turu sürdürülemiyor. Bu script aynı
/// widget ağacını deterministik biçimde sürer; `.screenshots/` altındaki
/// bozuk el ile alınmış görüntülerin yerini alır.
///
/// ```bash
/// flutter test tool/screenshots/screen_tour_test.dart
/// ```
const _size = Size(390, 844);
const _outDir = 'docs/screenshots/tour';

/// Yakalama sınırı. Kök render katmanı yerine açık bir RepaintBoundary
/// kullanılır; kök `debugLayer.toImage()` test koşucusunda kilitlenebiliyor.
final GlobalKey _boundaryKey = GlobalKey();

Widget _framed(Widget child) =>
    RepaintBoundary(key: _boundaryKey, child: child);

/// Görünüm boyutunu ayarlar.
///
/// `setSurfaceSize` YALNIZCA render yüzeyini değiştirir; `MediaQuery.sizeOf`
/// hâlâ varsayılan 800x600'ü döner. Bu yüzden `MediaQuery` genişliğine göre
/// dallanan ekranlar (ör. profil `width > 720` ile iki sütuna geçer) test
/// görüntülerinde yanlış düzeni çizip taşma şeridi gösteriyordu. Doğrusu
/// `tester.view` üzerinden fiziksel boyutu vermek.
void _applyViewport(WidgetTester tester, Size size, {double dpr = 3.0}) {
  tester.view.devicePixelRatio = dpr;
  tester.view.physicalSize = size * dpr;
  addTearDown(tester.view.reset);
}

Future<void> _shoot(WidgetTester tester, String name) async {
  // Yakalama VE dosya yazımı `runAsync` içinde kalmalı: test bağlayıcısının
  // sahte zaman dilimi içinde gerçek bir I/O Future'ı asla tamamlanmaz ve
  // koşucu çıktı vermeden sessizce kilitlenir.
  await tester.runAsync(() async {
    final boundary =
        _boundaryKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 2.0);
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('$_outDir/$name.png');
    await file.create(recursive: true);
    await file.writeAsBytes(byteData!.buffer.asUint8List());
  });
  print('✓ $name');
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  _applyViewport(tester, _size);
  await tester.pumpWidget(testShell(child: _framed(child)));
  // pumpAndSettle KULLANILMAZ: yükleme göstergeleri sonsuz animasyondur ve
  // tur boyunca kilitlenmeye yol açar. Sabit süreli pump yeterlidir.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
}

void main() {
  late MockZanKurdRepository repository;

  setUp(() {
    // connectivity_plus test ortamında kayıtlı değil; MissingPluginException
    // ekran görüntülerini etkilemiyor ama koşuyu kırmızıya boyuyordu.
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('dev.fluttercommunity.plus/connectivity'),
          (call) async => 'wifi',
        );
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockStreamHandler(
          const EventChannel('dev.fluttercommunity.plus/connectivity_status'),
          MockStreamHandler.inline(
            onListen: (args, sink) => sink.endOfStream(),
          ),
        );

    repository = freshMockRepository();
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      'zankurd.profileName.completed': true,
      'zankurd.navTour.seen': true,
      'zankurd.quiz_tutorial.seen': true,
    });
  });

  // Not: tüm uygulama kabuğu (ZanKurdApp) üzerinden sekme sekme gezen bir
  // varyant denendi; görüntüleri üretiyor ama koşucu test gövdesi bittikten
  // sonra çözülmeyen bir future yüzünden zaman aşımına düşüyor. Ekranlar
  // zaten aşağıda doğrudan açıldığı için kabuk turu kaldırıldı.
  testWidgets('01 ana ekran', (t) async {
    await _pump(t, Scaffold(body: HomeScreen(repository: repository)));
    await _shoot(t, '01_home');
  }, tags: ['preview']);

  testWidgets('05 oyun merkezi', (t) async {
    await _pump(t, PlayHubScreen(repository: repository));
    await _shoot(t, '05_play_hub');
  }, tags: ['preview']);

  testWidgets('06 sıralama', (t) async {
    await _pump(t, LeaderboardScreen(repository: repository));
    await _shoot(t, '06_leaderboard');
  }, tags: ['preview']);

  testWidgets('07 profil', (t) async {
    await _pump(t, Scaffold(body: ProfileScreen(repository: repository)));
    await _shoot(t, '07_profile');
  }, tags: ['preview']);

  testWidgets('08 ayarlar', (t) async {
    await _pump(t, SettingsScreen(repository: repository));
    await _shoot(t, '08_settings');
  }, tags: ['preview']);

  testWidgets('09 paywall', (t) async {
    await _pump(t, PaywallScreen(repository: repository));
    await _shoot(t, '09_paywall');
  }, tags: ['preview']);

  testWidgets('10 turnuva', (t) async {
    await _pump(t, TournamentScreen(repository: repository));
    await _shoot(t, '10_tournament');
  }, tags: ['preview']);

  testWidgets('11 günün etkinliği', (t) async {
    await _pump(t, ContestScreen(repository: repository));
    await _shoot(t, '11_contest');
  }, tags: ['preview']);

  testWidgets('12 çark', (t) async {
    await _pump(t, SpinWheelScreen(repository: repository));
    await _shoot(t, '12_spin');
  }, tags: ['preview']);

  testWidgets('13 arkadaşlar', (t) async {
    await _pump(t, FriendsScreen(repository: repository));
    await _shoot(t, '13_friends');
  }, tags: ['preview']);

  testWidgets('14 ders akışı', (t) async {
    await _pump(
      t,
      QuizScreen(
        repository: repository,
        room: repository.createRoom(),
        questions: repository.questions.take(5).toList(),
        experience: QuizExperience.learning,
        enableTimer: false,
      ),
    );
    await _shoot(t, '14_lesson_question');

    // Bir şık işaretle: geri bildirim + açıklama paneli.
    await t.tap(find.text(repository.questions.first.answers.first));
    await t.pump();
    await t.pump(const Duration(milliseconds: 1600));
    await _shoot(t, '15_lesson_answered');
  }, tags: ['preview']);

  testWidgets('16 yarışma akışı', (t) async {
    await _pump(
      t,
      QuizScreen(
        repository: repository,
        room: repository.createRoom(),
        questions: repository.questions.take(5).toList(),
      ),
    );
    await _shoot(t, '16_competition_question');
  }, tags: ['preview']);
}
