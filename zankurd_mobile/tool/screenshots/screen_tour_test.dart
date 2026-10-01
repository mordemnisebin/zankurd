// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:zankurd_mobile/src/data/mock_zankurd_repository.dart';
import 'package:zankurd_mobile/src/data/sync_manager.dart';
import 'package:zankurd_mobile/src/models/async_duel.dart';
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/models/contest.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/services/premium_service.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_play_screen.dart';
import 'package:zankurd_mobile/src/screens/async_duel/async_duel_result_screen.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/learn_home_screen.dart';
import 'package:zankurd_mobile/src/screens/password_recovery_screen.dart';
import 'package:zankurd_mobile/src/screens/room_result_recovery_screen.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/screens/matchmaking_screen.dart';
import 'package:zankurd_mobile/src/screens/paywall_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/favorite_questions_screen.dart';
import 'package:zankurd_mobile/src/screens/image_credits_screen.dart';
import 'package:zankurd_mobile/src/screens/onboarding_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_name_gate_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz/quiz_option_tile.dart';
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/review_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_in_screen.dart';
import 'package:zankurd_mobile/src/screens/splash_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_up_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/screens/avatar_editor_screen.dart';
import 'package:zankurd_mobile/src/screens/level_placement_screen.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
import 'package:zankurd_mobile/src/screens/learner_lexicon_screen.dart';
import 'package:zankurd_mobile/src/screens/level_screen.dart';
import 'package:zankurd_mobile/src/screens/settings_screen.dart';
import 'package:zankurd_mobile/src/models/answer_record.dart';
import 'package:zankurd_mobile/src/models/mini_guide.dart';
import 'package:zankurd_mobile/src/models/story.dart';
import 'package:zankurd_mobile/src/screens/story_screen.dart';
import 'package:zankurd_mobile/src/screens/subcategory_screen.dart';
import 'package:zankurd_mobile/src/screens/suggest_question_screen.dart';
import 'package:zankurd_mobile/src/screens/shop_screen.dart';
import 'package:zankurd_mobile/src/screens/spin_wheel_screen.dart';
import 'package:zankurd_mobile/src/screens/tournament_screen.dart';

import '../../test/support/paywall_fixtures.dart';
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
///
/// ## Görüntülerin sınırı
///
/// Test koşucusunda yalnız burada yüklenen yazı tipleri çizilir. Özellikle
/// `CustomPainter` içinde `TextPainter` ile çizilen metin (ör. çark
/// dilimlerinin etiketleri), widget'lardaki gibi temadan Rubik alamayabilir.
/// Bu yüzden font/glif doğruluğu widget turundan değil, gerçek iOS Simulator
/// üzerinde `integration_test/native_visual_qa_test.dart` ile kanıtlanır.
/// Aynı native kapı sıralama podyumundaki kupa/madalya ikonlarını da gerçek
/// platform render'ında yakalar.
/// Tur görüntü boyutu. Yükseklik `ZANKURD_SCREEN_TOUR_HEIGHT` ile
/// büyütülebilir: kaydırılan bir ekranın tamamını tek karede görmek için
/// (ör. `ZANKURD_SCREEN_TOUR_HEIGHT=1800`). Genişlik
/// `ZANKURD_SCREEN_TOUR_WIDTH` ile (ör. `320`, en dar telefon). Varsayılan,
/// iPhone boyu.
final _size = Size(
  double.tryParse(Platform.environment['ZANKURD_SCREEN_TOUR_WIDTH'] ?? '') ??
      390,
  double.tryParse(Platform.environment['ZANKURD_SCREEN_TOUR_HEIGHT'] ?? '') ??
      844,
);
final _baseOutDir =
    Platform.environment['ZANKURD_SCREEN_TOUR_OUT_DIR'] ??
    'docs/screenshots/tour';

/// Turun teması. `ZANKURD_SCREEN_TOUR_THEME=light|dark` bütün kareleri o
/// temada basar ve çıktıyı `<çıktı>/<tema>/` altına yazar (kare adları
/// değişmez; `_dark` adlı bir kare `light/` altında gündüz çizilmiştir).
/// Değişken yoksa her kare kendi tanımındaki temadadır: `_dark` kareleri
/// gece, ötekiler GÜNDÜZ.
///
/// 2026-09-29: Şahnê'de varsayılan tema gecedir (`ThemeProvider`). Tur
/// eskiden gündüz karelerinde sağlayıcıyı boş bırakıyordu; kareler adı
/// "gündüz" olduğu hâlde gece çiziliyordu. Gündüz kareleri artık açıkça
/// gündüz kurulur.
final ThemeMode? _forcedTheme =
    switch (Platform.environment['ZANKURD_SCREEN_TOUR_THEME']) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => null,
    };

final _outDir = switch (_forcedTheme) {
  ThemeMode.light => '$_baseOutDir/light',
  ThemeMode.dark => '$_baseOutDir/dark',
  _ => _baseOutDir,
};

/// Yakalama sınırı. Kök render katmanı yerine açık bir RepaintBoundary
/// kullanılır; kök `debugLayer.toImage()` test koşucusunda kilitlenebiliyor.
final GlobalKey _boundaryKey = GlobalKey();

/// Ekranı yakalama sınırına ve bir `Material` katmanına sarar.
///
/// `Material` katmanı süs değil: `Text`, ailesi yazılmamış bir biçim
/// aldığında ailesini en yakın `DefaultTextStyle`dan alır ve onu temadan
/// **`Material` kurar**. Uygulamada her sekme `Scaffold` içinde açıldığı
/// için bu katman hep vardır; tur ise bazı ekranları çıplak basıyordu.
/// Sonuç: o ekranlarda başlıklar `DefaultTextStyle.fallback()`e düşüyor,
/// koşucuda ölçü fontuyla — yani siyah kutu olarak — çiziliyordu
/// (2026-07-26: oyun merkezi ve sıralama turda böyle görünüyordu).
/// Uygulamada bir kusur değil, turun kendi kusuruydu.

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
  // `ZANKURD_SCREEN_TOUR_TEXT_SCALE=2` büyük yazıyı (sistem yazı ölçeği)
  // bütün karelere uygular; 320 px + 2.0 en sıkışık gerçek koşuldur.
  final scale = double.tryParse(
    Platform.environment['ZANKURD_SCREEN_TOUR_TEXT_SCALE'] ?? '',
  );
  if (scale != null) {
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }
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

/// Flutter SDK kökü — `which flutter` yerine `dart` çalıştırılabilirinden
/// türetilir; koşucu her zaman SDK'nın içindeki dart'ı kullanır.
String _flutterSdkRoot() {
  var dir = File(Platform.resolvedExecutable).parent;
  while (dir.path != dir.parent.path) {
    if (Directory(
      '${dir.path}/bin/cache/artifacts/material_fonts',
    ).existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  return '';
}

/// Tur sonucu ekranı için gerçekçi bir örnek: iki doğru bir yanlış, seri,
/// coin ödülü ve tam açıklama listesi.
/// Çevrimiçi 1v1 maç sonu galibiyet ekranı — kupa, 1v1 sıralaması ve "Yeni Oda" butonu.
Widget _result1v1VictoryScreen() {
  final repository = MockZanKurdRepository();
  const room = GameRoom(
    id: 'room-1v1-online',
    name: '1vs1',
    code: 'ZK-WINNER01',
    category: 'Ziman',
    players: [
      Player(id: 'user', name: 'Ez', score: 320, state: Player.readyState),
      Player(id: 'opp', name: 'Rojda', score: 180, state: Player.readyState),
    ],
    status: RoomStatus.finished,
    questionCount: 5,
    entryFee: 25,
  );
  return QuizResultScreen(
    repository: repository,
    room: room,
    score: 320,
    correctCount: 4,
    wrongCount: 1,
    totalQuestions: 5,
    bestStreak: 3,
    coinsAwarded: 50,
    opponents: const [
      Player(id: 'opp', name: 'Rojda', score: 180, state: Player.readyState),
    ],
    answerRecords: const [
      AnswerRecord(
        id: 'r1',
        category: 'Ziman',
        prompt: 'Peyva «av» bi Tirkî çi tê gotin?',
        answers: ['su', 'ekmek', 'yol', 'dağ'],
        correctAnswer: 'su',
        selectedAnswer: 'su',
        explanation: '«av» Türkçede «su» demektir.',
        explanationKu: '«av» bi Tirkî dibe «su».',
        explanationTr: '«av» Türkçede «su» demektir.',
      ),
      AnswerRecord(
        id: 'r2',
        category: 'Ziman',
        prompt: 'Peyva «agir» bi Tirkî çi tê gotin?',
        answers: ['ateş', 'su', 'hava', 'toprak'],
        correctAnswer: 'ateş',
        selectedAnswer: 'ateş',
        explanation: '«agir» Türkçede «ateş» demektir.',
        explanationKu: '«agir» bi Tirkî dibe «ateş».',
        explanationTr: '«agir» Türkçede «ateş» demektir.',
      ),
    ],
  );
}

Widget _resultScreen() {
  final repository = _TourRepository();
  final room = repository.createRoom();
  return QuizResultScreen(
    repository: repository,
    room: room,
    score: 240,
    correctCount: 2,
    wrongCount: 1,
    totalQuestions: 3,
    bestStreak: 2,
    coinsAwarded: 30,
    answerRecords: const [
      AnswerRecord(
        id: 'r1',
        category: 'Ziman',
        prompt: 'Peyva «av» bi Tirkî çi tê gotin?',
        answers: ['su', 'ekmek', 'yol', 'dağ'],
        correctAnswer: 'su',
        selectedAnswer: 'su',
        explanation: '«av» Türkçede «su» demektir.',
        explanationKu: '«av» bi Tirkî dibe «su».',
        explanationTr: '«av» Türkçede «su» demektir.',
      ),
      AnswerRecord(
        id: 'r2',
        category: 'Dîrok',
        prompt: 'Şerefname kê nivîsandiye?',
        answers: ['Şerefxan', 'Ehmedê Xanî', 'Melayê Cizîrî', 'Feqiyê Teyran'],
        correctAnswer: 'Şerefxan',
        selectedAnswer: 'Ehmedê Xanî',
        explanation: 'Şerefname, Şerefxanê Bidlîsî tarafından yazıldı.',
        explanationKu:
            'Şerefname ji aliyê Şerefxanê Bidlîsî ve hatiye '
            'nivîsandin.',
        explanationTr: 'Şerefname, Şerefxanê Bidlîsî tarafından yazıldı.',
      ),
      AnswerRecord(
        id: 'r3',
        category: 'Çand',
        prompt: 'Newroz di kîjan rojê de tê pîrozkirin?',
        answers: ['21ê Adarê', '1ê Gulanê', '15ê Sibatê', '9ê Nîsanê'],
        correctAnswer: '21ê Adarê',
        selectedAnswer: '21ê Adarê',
        explanation: 'Newroz 21 Mart\'ta kutlanır.',
        explanationKu: 'Newroz di 21ê Adarê de tê pîrozkirin.',
        explanationTr: 'Newroz 21 Mart\'ta kutlanır.',
      ),
    ],
  );
}

/// Turun TEK HİKÂYESİ (2026-09-29 doğallık).
///
/// Tur eskiden her karede başka bir dünya çiziyordu: oyun merkezinde
/// Rojda'ya "Kaybettin 2–3" derken aynı düellonun sonuç ekranı "Sen 2 – 0
/// Rojda, Kazandın!" diyordu; oda lobisinde "Sen" ile "Heval" otururken
/// tepkiler odada olmayan Rojda ve Baran'dan geliyordu; oda kodu her karede
/// başka rastgele bir koddu; sıralamada oyuncunun kendi satırı hiç yoktu;
/// davet kodu düğmesinde "DEMO" yazıyordu. Kareler tek tek doğruydu ama
/// yan yana konunca uydurma olduğu belli oluyordu.
///
/// Hikâye: oyuncu yeni ve adsız (ad kapısı ve boş durumlar öyle görünsün
/// diye), davet kodu [_tourPlayerTag]. Odası "Hevalên Zanînê", kodu
/// [_tourRoomCode], odada Berfin var. Rakibi Rojda: sırayla düelloyu 5–3
/// kazandı ([_seedRojdaDuel]), 1v1 odada da onu yendi. Oda yarışından
/// [_tourRaceScore] puan aldı; haftalık sıralamada o puanla kendi satırını
/// görür. Arkadaşları Diyar ve Berfin, isteği bekleyen Rojîn. Sıralamanın
/// başı Rojda, Baran, Dilan.
const _tourPlayerTag = '4F7K';
const _tourRoomCode = 'ZK-7A41C29E0B';

/// Oda yarışının puanı: `68_result` karesi ve sıralamadaki kendi satır.
const _tourRaceScore = 240;

enum _LobbyView { hostAlone, hostGuestNotReady, guest }

/// Oda lobisinin ev sahibi / konuk durumları için tur deposu. Oyuncu
/// kimliği `user`; ev sahibi olan odalarda `hostId` oyuncunun kendisidir,
/// konuk odasında Berfin.
class _LobbyTourRepository extends _TourRepository {
  _LobbyTourRepository(this.view);

  final _LobbyView view;

  static GameRoom room(_LobbyView view) {
    const me = Player(
      id: 'user',
      name: 'Sen',
      score: 0,
      state: Player.readyState,
    );
    const berfin = Player(
      id: 'tour-berfin',
      name: 'Berfin',
      score: 0,
      state: Player.readyState,
    );
    const berfinWaiting = Player(
      id: 'tour-berfin',
      name: 'Berfin',
      score: 0,
      state: 'Bekliyor',
    );
    return GameRoom(
      id: 'tour-room-lobby',
      name: 'Hevalên Zanînê',
      code: _tourRoomCode,
      category: 'Ziman',
      players: switch (view) {
        _LobbyView.hostAlone => const [me],
        _LobbyView.hostGuestNotReady => const [me, berfinWaiting],
        _LobbyView.guest => const [berfin, me],
      },
      status: RoomStatus.lobby,
      questionCount: 10,
      hostId: view == _LobbyView.guest ? 'tour-berfin' : 'user',
    );
  }

  @override
  Future<List<Player>> loadRoomPlayers(GameRoom room) async => room.players;

  @override
  Stream<List<Player>> subscribeRoomPlayers(GameRoom room) =>
      Stream.value(room.players);
}

class _TourRepository extends TestMockZanKurdRepository {
  @override
  Future<String?> getPlayerTag() async => _tourPlayerTag;

  @override
  GameRoom createRoom({String category = 'Ziman'}) {
    final room = super.createRoom(category: category);
    return room.copyWith(
      code: _tourRoomCode,
      players: [
        room.players.first,
        const Player(
          id: 'tour-berfin',
          name: 'Berfin',
          score: 0,
          state: Player.readyState,
        ),
      ],
    );
  }

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 10,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async {
    final top = await super.loadLeaderboard(limit: limit, period: period);
    return [
      ...top,
      const LeaderboardEntry(
        rank: 4,
        playerId: 'tour-diyar',
        displayName: 'Diyar',
        totalScore: 2450,
        bestStreak: 6,
        roomsPlayed: 9,
      ),
      const LeaderboardEntry(
        rank: 5,
        playerId: 'tour-berfin',
        displayName: 'Berfin',
        totalScore: 1820,
        bestStreak: 5,
        roomsPlayed: 7,
      ),
      const LeaderboardEntry(
        rank: 6,
        playerId: 'tour-rojin',
        displayName: 'Rojîn',
        totalScore: 610,
        bestStreak: 3,
        roomsPlayed: 3,
      ),
      const LeaderboardEntry(
        rank: 7,
        playerId: 'user',
        displayName: 'ZanKurd Oyuncusu',
        totalScore: _tourRaceScore,
        bestStreak: 2,
        roomsPlayed: 1,
      ),
    ];
  }
}

/// Belirli bir jeton bakiyesiyle açılan tur deposu: "jeton yetmiyor"
/// karelerinin (mağaza, oda kurma, paywall değil) bakiyesi.
class _BalanceTourRepository extends _TourRepository {
  _BalanceTourRepository(this.coins);
  final int coins;

  @override
  Future<int> loadCoinBalance() async => coins;
}

/// Rojda ile oynanan sırayla düello: Rojda 3 doğruyla bitirmiş, oyuncu
/// ilk beş soruyu doğru, son ikisini yanlış cevaplar — 5–3 galibiyet.
/// Seçim sabit bir harf ("A") değil, bankadaki doğru cevaptan hesaplanır:
/// düellonun soruları her koşuda başka olsa da skor aynı kalır.
Future<void> _seedRojdaDuel(MockZanKurdRepository repo) async {
  repo.addPendingAsyncDuelForTesting(
    opponentName: 'Rojda',
    opponentCorrect: 3,
    opponentMs: 90000,
  );
  await _playAsyncDuel(repo, correctCount: 5);
}

/// Açılan (ya da bekleyen rakiple eşleşen) düelloyu oynar: ilk
/// [correctCount] soru doğru, kalanlar yanlış.
Future<void> _playAsyncDuel(
  MockZanKurdRepository repo, {
  required int correctCount,
}) async {
  const letters = ['A', 'B', 'C', 'D'];
  final start = await repo.startAsyncDuel();
  final bank = {for (final q in repo.playableQuestions) q.id: q};
  for (var i = 0; i < start.questions.length; i++) {
    final shown = start.questions[i];
    final correct = shown.answers.indexOf(bank[shown.id]!.correctAnswer);
    final index = i < correctCount ? correct : (correct + 1) % 4;
    await repo.answerAsyncDuel(
      duelId: start.duelId,
      questionIndex: i,
      choice: letters[index],
      responseMs: 6000,
    );
  }
}

/// Turun kabuğu: `testShell` + görüntü sınırı.
///
/// Sınır (`RepaintBoundary`) MaterialApp'in DIŞINDA olmak zorunda. Eskiden
/// `_framed` ile `home`un çevresine konuyordu; o kadraj modal sayfaları
/// KAÇIRIYOR, çünkü `showModalBottomSheet` çocuğu Navigator overlay'ine
/// çizer ve overlay `home`un üstünde durur. Oda kurma sheet'i tam olarak
/// böyle bir sayfa — eski kabuğa boş bir oyun merkezi düşerdi.
///
/// Sağlayıcı listesi BURADA TEKRARLANMAZ: `testShell` neyi kuruyorsa tur da
/// onu görmeli. İlk uygulama listeyi elle kopyalamıştı; kopya, testlerin
/// gördüğü uygulamayla turun gösterdiği uygulamayı sessizce ayırır — turun
/// tek işi "uygulama gerçekte neye benziyor" sorusuna cevap vermekken.
Widget _tourShell({
  required Widget child,
  bool dark = false,
  bool ku = false,
  PremiumService? premiumService,
}) {
  return RepaintBoundary(
    key: _boundaryKey,
    child: testShell(
      child: Material(type: MaterialType.transparency, child: child),
      themeProvider: ThemeProvider(
        initialMode: _forcedTheme ?? (dark ? ThemeMode.dark : ThemeMode.light),
      ),
      languageProvider: ku ? kurmanciLang() : null,
      premiumService: premiumService,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  bool ku = false,
  PremiumService? premiumService,
  Size? size,
}) async {
  _applyViewport(tester, size ?? _size);
  await tester.pumpWidget(
    _tourShell(
      child: child,
      dark: dark,
      ku: ku,
      premiumService: premiumService,
    ),
  );
  // pumpAndSettle KULLANILMAZ: yükleme göstergeleri sonsuz animasyondur ve
  // tur boyunca kilitlenmeye yol açar. Sabit süreli pump yeterlidir.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 1600));
  // İlk kez çözülen asset görselleri (özellikle açılış logosu) test
  // bağlayıcısının sahte saatinden bağımsız tamamlanır. Gerçek I/O'ya kısa
  // bir tur vermeden ilk ekran boş, hemen arkasındaki koyu ekran ise aynı
  // görsel önbelleğe girdiği için dolu yakalanıyordu.
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 50)),
  );
  // Tema/dil sağlayıcıları gerçek I/O turundan sonra son bir bildirim
  // yapıp bazı ekran animasyonlarını yeniden başlatabilir. Sıfır süreli
  // pump bu kareyi başlangıçta bırakıyor ve koyu ekranlarda metin/ikonlar
  // yarım görünüyordu. İkinci sabit süre tüm sonlu animasyonları bitirir.
  await tester.pump(const Duration(milliseconds: 1600));
}

/// Ekran turuna özel, deterministik dolu sosyal durum.
///
/// `MockZanKurdRepository` üretim fallback'inde hayalet kullanıcı üretmemek
/// için arkadaş ve yarışma liderliğini bilinçli olarak boş döndürür. Tur da
/// aynı depoyu kullanınca `13_friends` == `33_friends_empty` ve
/// `11_contest` == `34_contest_empty` birebir aynı PNG oluyordu: iki ayrı
/// test adı, tek bir görsel durum. Dolu fixture yalnız burada yaşar; ürün
/// fallback davranışını değiştirmez.
class _PopulatedStateRepository extends _TourRepository {
  @override
  Future<List<Friend>> loadFriends() async => [
    Friend(
      id: 'tour-friend-1',
      userId: 'user',
      friendId: 'tour-diyar',
      friendName: 'Diyar',
      friendAvatarColor: '#2AA6A1',
      createdAt: DateTime.utc(2026, 8, 1),
      totalScore: 2450,
      level: 12,
      gamesPlayed: 48,
      lastActiveAt: DateTime.utc(2026, 9, 9, 4),
    ),
    Friend(
      id: 'tour-friend-2',
      userId: 'user',
      friendId: 'tour-berfin',
      friendName: 'Berfin',
      friendAvatarColor: '#6F61C0',
      createdAt: DateTime.utc(2026, 8, 2),
      totalScore: 1820,
      level: 9,
      gamesPlayed: 31,
      lastActiveAt: DateTime.utc(2026, 9, 9, 3, 50),
    ),
  ];

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async => [
    FriendRequest(
      id: 'tour-request-1',
      fromUserId: 'tour-rojin',
      fromUserName: 'Rojîn',
      toUserId: 'user',
      createdAt: DateTime.utc(2026, 9, 8),
      status: 'pending',
    ),
  ];
}

/// Yeni kullanıcının gerçekten gördüğü boş sosyal durum.
class _ReactionStateRepository extends _TourRepository {
  final StreamController<Map<String, dynamic>> _broadcasts =
      StreamController<Map<String, dynamic>>.broadcast(sync: true);

  @override
  Stream<Map<String, dynamic>> subscribeRoomBroadcast(String roomId) {
    return _broadcasts.stream;
  }

  void emitReaction(
    String text, {
    required String senderName,
    required String senderId,
  }) {
    _broadcasts.add({
      'type': 'reaction',
      'text': text,
      'sender_name': senderName,
      'sender_id': senderId,
    });
  }

  Future<void> close() => _broadcasts.close();
}

class _EmptyStateRepository extends MockZanKurdRepository {
  @override
  Future<Contest?> loadTodayContest() async => null;

  @override
  Future<List<Friend>> loadFriends() async => const [];

  @override
  Future<List<FriendRequest>> loadPendingFriendRequests() async => const [];

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
    int limit = 20,
  }) async => const [];

  @override
  Future<List<ContestLeaderboardRow>> getContestLeaderboard({
    required String contestId,
    int limit = 10,
  }) async => const [];
}

void main() {
  late MockZanKurdRepository repository;

  setUpAll(() async {
    // Yazı tipleri elle yüklenmezse test koşucusu her metni siyah bir kutu
    // olarak çizer: `flutter test` pubspec'teki font ailelerini kendiliğinden
    // yüklemez, bilinmeyen aileyi ölçü fontuna düşürür. Turun tek işi
    // ekranların *görünüşünü* değerlendirmek olduğu için bu, aracı işe
    // yaramaz kılıyordu — 13 ekran görüntüsünün hepsi okunmuyordu
    // (2026-07-26 denetimi).
    // Şahnê: metin ailesi Onest, başlık ailesi Bricolage Grotesque.
    const families = {
      'Onest': [
        'assets/fonts/Onest-Regular.ttf',
        'assets/fonts/Onest-Medium.ttf',
        'assets/fonts/Onest-SemiBold.ttf',
        'assets/fonts/Onest-Bold.ttf',
      ],
      'BricolageGrotesque': [
        'assets/fonts/BricolageGrotesque-Bold.ttf',
        'assets/fonts/BricolageGrotesque-ExtraBold.ttf',
      ],
    };
    for (final family in families.entries) {
      final loader = FontLoader(family.key);
      for (final path in family.value) {
        loader.addFont(
          File(path).readAsBytes().then((b) => ByteData.view(b.buffer)),
        );
      }
      await loader.load();
    }

    // Material'in kendi ikonları (ör. `ExpansionTile`in ok işareti) ayrı
    // bir aileden gelir ve o da yüklenmezse kare çizilir; turda profil
    // ekranındaki "Detaylı İstatistik" satırı böyle görünüyordu. Yazı tipi
    // Flutter SDK'sının önbelleğinde durur; yol `flutter` çalıştırılabilirinden
    // çözülür, sabit yazılmaz.
    final materialIcons = File(
      '${_flutterSdkRoot()}/bin/cache/artifacts/material_fonts/'
      'MaterialIcons-Regular.otf',
    );
    if (materialIcons.existsSync()) {
      final materialLoader = FontLoader('MaterialIcons')
        ..addFont(
          materialIcons.readAsBytes().then((b) => ByteData.view(b.buffer)),
        );
      await materialLoader.load();
    } else {
      print('UYARI: MaterialIcons bulunamadı — o ikonlar kare çizilecek');
    }

    // İkon yazı tipi paket içinden gelir; o da yüklenmezse her ikon küçük
    // bir kare olarak çizilir ve ekranın yarısı okunmaz kalır. Yol
    // `package_config.json`dan çözülür, sabit yazılmaz — pub önbelleği
    // makineden makineye değişir.
    final packageConfig =
        jsonDecode(File('.dart_tool/package_config.json').readAsStringSync())
            as Map<String, dynamic>;
    String packageRoot(String name) {
      final entry = (packageConfig['packages'] as List)
          .cast<Map<String, dynamic>>()
          .firstWhere((p) => p['name'] == name);
      // `rootUri` sonunda eğik çizgi yok; doğrudan birleştirmek
      // ".../font_awesome_flutter-11.0.0lib/fonts/..." gibi var olmayan bir
      // yol üretiyordu ve uyarı sessizce geçilip ikonlar kare kalıyordu.
      final root = Uri.parse(entry['rootUri'] as String).toFilePath();
      return root.endsWith(Platform.pathSeparator)
          ? root
          : '$root${Platform.pathSeparator}';
    }

    // paket -> {aile -> paket içi yazı tipi dosyası}
    //
    // Lucide: `AppIcons` ikonlarının neredeyse hepsi (Şahnê çizgi ailesi).
    // Font Awesome: yalnız dolu puan yıldızı (`AppIcons.starSolid`, Lucide'da
    // dolgu yok) ve Google markası. Solid VE Regular birlikte yüklenir;
    // yalnız Solid yüklenirken Regular ailesindeki ikonlar kare çiziliyordu
    // (2026-07-26).
    const iconFonts = {
      'lucide_icons_flutter': {'Lucide': 'assets/lucide.ttf'},
      'font_awesome_flutter': {
        'FontAwesomeSolid': 'lib/fonts/Font-Awesome-7-Free-Solid-900.otf',
        'FontAwesomeRegular': 'lib/fonts/Font-Awesome-7-Free-Regular-400.otf',
        'FontAwesomeBrands': 'lib/fonts/Font-Awesome-7-Brands-Regular-400.otf',
      },
    };
    for (final package in iconFonts.keys) {
      final base = packageRoot(package);
      final families = iconFonts[package]!;
      for (final family in families.keys) {
        final iconFont = File('$base${families[family]}');
        if (!iconFont.existsSync()) {
          print(
            'UYARI: $package/$family bulunamadı — o ikonlar kare çizilecek',
          );
          continue;
        }
        // Aile adı paket önekiyle kaydedilmeli: `IconData` içindeki
        // `fontPackage` alanı, Flutter'ın çözdüğü aileyi
        // `packages/<paket>/<aile>` biçimine çevirir. Öneksiz kayıt sessizce
        // eşleşmez ve ikonlar yine kare çizilir.
        final iconLoader = FontLoader(
          'packages/$package/$family',
        )..addFont(iconFont.readAsBytes().then((b) => ByteData.view(b.buffer)));
        await iconLoader.load();
      }
    }
  });

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

    // `freshMockRepository` depoları sıfırlar; tur kendi hikâyesinin
    // deposunu kullanır (bkz. [_TourRepository]).
    freshMockRepository();
    repository = _TourRepository();
    SharedPreferences.setMockInitialValues({
      'zankurd.onboarding.seen': true,
      // Eski GLOBAL anahtar. `AppShell` 2026-08-03'te ad kapısını kullanıcıya
      // bağladı (`...completed.<userId>`) ve global anahtarı bilerek
      // okumuyor; tur ise eskisini kurmaya devam ediyordu. Kabuk turda hiç
      // açılmadığı için fark edilmemişti — `80_app_shell` eklenince kabuk
      // sekme çubuğu yerine ad kapısını çizdi (2026-08-16). İkisi de
      // bırakıldı: eskisi kapıyı okuyan başka bir yüzey kalmışsa diye,
      // yenisi kabuğun gerçekten okuduğu anahtar olduğu için.
      'zankurd.profileName.completed': true,
      'zankurd.profileName.completed.user': true,
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
    await _pump(t, FriendsScreen(repository: _PopulatedStateRepository()));
    await _shoot(t, '13_friends');
  }, tags: ['preview']);

  // Ara ekranlar: bekleme ve para biriminin geçtiği yerler. Yeni
  // kullanıcının en çok "şimdi ne olacak?" diye durakladığı noktalar
  // burasıdır, bu yüzden turda ana ekranlar kadar yer tutarlar.
  testWidgets('17 oda', (t) async {
    await _pump(
      t,
      RoomScreen(repository: repository, initialRoom: repository.createRoom()),
    );
    await _shoot(t, '17_room');
  }, tags: ['preview']);

  testWidgets('18 rakip arama', (t) async {
    await _pump(t, MatchmakingScreen(repository: repository));
    await _shoot(t, '18_matchmaking');
  }, tags: ['preview']);

  testWidgets('19 mağaza', (t) async {
    await _pump(t, ShopScreen(repository: repository));
    await _shoot(t, '19_shop');
  }, tags: ['preview']);

  // ── Henüz turda olmayan ekranlar ──
  //
  // Denetim ancak gördüğü ekranı kapsar; bu altısı hiç basılmamıştı.
  testWidgets('35 avatar düzenleme', (t) async {
    await _pump(t, AvatarEditorScreen(repository: repository));
    await _shoot(t, '35_avatar_editor');
  }, tags: ['preview']);

  testWidgets('37 alt kategoriler', (t) async {
    await _pump(
      t,
      SubcategoryScreen(repository: repository, category: 'Ziman'),
    );
    await _shoot(t, '37_subcategories');
  }, tags: ['preview']);

  testWidgets('38 seviyeler', (t) async {
    await _pump(t, LevelScreen(repository: repository, category: 'Ziman'));
    await _shoot(t, '38_levels');
  }, tags: ['preview']);

  testWidgets('39 soru öner', (t) async {
    await _pump(t, SuggestQuestionScreen(repository: repository));
    await _shoot(t, '39_suggest_question');
  }, tags: ['preview']);

  testWidgets('40 seviye sınavı', (t) async {
    await _pump(t, LevelPlacementScreen(repository: repository));
    await _shoot(t, '40_placement');
  }, tags: ['preview']);

  // ── Karanlık tema ──
  //
  // Tur bugüne dek yalnız açık temayı basıyordu; karanlık temada sabit
  // kalmış renkler (`Colors.white`, sabit siyah gölge) hiç ölçülmüyordu.
  // Aynı ekranlar ikinci kez, tema karanlıkken basılır.
  testWidgets('20 ana ekran (karanlık)', (t) async {
    await _pump(
      t,
      Scaffold(body: HomeScreen(repository: repository)),
      dark: true,
    );
    await _shoot(t, '20_home_dark');
  }, tags: ['preview']);

  testWidgets('21 oyun merkezi (karanlık)', (t) async {
    await _pump(t, PlayHubScreen(repository: repository), dark: true);
    await _shoot(t, '21_play_hub_dark');
  }, tags: ['preview']);

  testWidgets('22 profil (karanlık)', (t) async {
    await _pump(
      t,
      Scaffold(body: ProfileScreen(repository: repository)),
      dark: true,
    );
    await _shoot(t, '22_profile_dark');
  }, tags: ['preview']);

  testWidgets('23 mağaza (karanlık)', (t) async {
    await _pump(t, ShopScreen(repository: repository), dark: true);
    await _shoot(t, '23_shop_dark');
  }, tags: ['preview']);

  testWidgets('24 yarışma (karanlık)', (t) async {
    await _pump(t, ContestScreen(repository: repository), dark: true);
    await _shoot(t, '24_contest_dark');
  }, tags: ['preview']);

  testWidgets('25 sıralama (karanlık)', (t) async {
    await _pump(t, LeaderboardScreen(repository: repository), dark: true);
    await _shoot(t, '25_leaderboard_dark');
  }, tags: ['preview']);

  // ── Kurmancî arayüz ──
  //
  // Ürünün asıl dili Kurmancî; tur ise bugüne dek yalnız Türkçe basıyordu.
  // Çevrilmemiş kalmış bir metin ya da uzun Kurmancî sözcüklerin taşırdığı
  // bir düzen bu yüzden hiç görünmüyordu.
  testWidgets('26 ana ekran (Kurmancî)', (t) async {
    await _pump(
      t,
      Scaffold(body: HomeScreen(repository: repository)),
      ku: true,
    );
    await _shoot(t, '26_home_ku');
  }, tags: ['preview']);

  testWidgets('27 oyun merkezi (Kurmancî)', (t) async {
    await _pump(t, PlayHubScreen(repository: repository), ku: true);
    await _shoot(t, '27_play_hub_ku');
  }, tags: ['preview']);

  testWidgets('28 profil (Kurmancî)', (t) async {
    await _pump(
      t,
      Scaffold(body: ProfileScreen(repository: repository)),
      ku: true,
    );
    await _shoot(t, '28_profile_ku');
  }, tags: ['preview']);

  testWidgets('29 mağaza (Kurmancî)', (t) async {
    await _pump(t, ShopScreen(repository: repository), ku: true);
    await _shoot(t, '29_shop_ku');
  }, tags: ['preview']);

  testWidgets('30 ayarlar (Kurmancî)', (t) async {
    await _pump(t, SettingsScreen(repository: repository), ku: true);
    await _shoot(t, '30_settings_ku');
  }, tags: ['preview']);

  testWidgets('31 yarışma (Kurmancî)', (t) async {
    await _pump(t, ContestScreen(repository: repository), ku: true);
    await _shoot(t, '31_contest_ku');
  }, tags: ['preview']);

  // ── Boş durumlar ──
  //
  // İlk açılışta arkadaş yok, sıralama boş, yarışmaya kimse katılmamış.
  // Bu ekranlar turda hiç görünmüyordu.
  testWidgets('32 sıralama (boş)', (t) async {
    await _pump(t, LeaderboardScreen(repository: _EmptyStateRepository()));
    await _shoot(t, '32_leaderboard_empty');
  }, tags: ['preview']);

  testWidgets('33 arkadaşlar (boş)', (t) async {
    await _pump(t, FriendsScreen(repository: _EmptyStateRepository()));
    await _shoot(t, '33_friends_empty');
  }, tags: ['preview']);

  testWidgets('34 yarışma (boş)', (t) async {
    await _pump(t, ContestScreen(repository: _EmptyStateRepository()));
    await _shoot(t, '34_contest_empty');
  }, tags: ['preview']);

  testWidgets('41 seviye sınavı (karanlık)', (t) async {
    await _pump(t, LevelPlacementScreen(repository: repository), dark: true);
    await _shoot(t, '41_placement_dark');
  }, tags: ['preview']);

  testWidgets('42 hikâye (karanlık)', (t) async {
    await _pump(
      t,
      StoryScreen(story: cayxaneStory, guide: cayxaneGuide),
      dark: true,
    );
    await _shoot(t, '42_story_dark');
  }, tags: ['preview']);

  testWidgets('43 hikâye', (t) async {
    await _pump(t, StoryScreen(story: cayxaneStory, guide: cayxaneGuide));
    await _shoot(t, '43_story');
  }, tags: ['preview']);

  testWidgets('44 tur özeti (yanlışlar)', (t) async {
    await _pump(
      t,
      ReviewScreen(
        room: repository.createRoom(),
        records: const [
          AnswerRecord(
            id: 'r1',
            category: 'Ziman',
            prompt: 'Peyva «av» bi Tirkî çi tê gotin?',
            answers: ['su', 'ekmek', 'yol', 'dağ'],
            correctAnswer: 'su',
            selectedAnswer: 'su',
            explanation: '«av» Türkçede «su» demektir.',
            explanationKu: '«av» bi Tirkî dibe «su».',
            explanationTr: '«av» Türkçede «su» demektir.',
          ),
          AnswerRecord(
            id: 'r2',
            category: 'Dîrok',
            prompt: 'Şerefname kê nivîsandiye?',
            answers: [
              'Şerefxan',
              'Ehmedê Xanî',
              'Melayê Cizîrî',
              'Feqiyê Teyran',
            ],
            correctAnswer: 'Şerefxan',
            selectedAnswer: 'Ehmedê Xanî',
            explanation: 'Şerefname, Şerefxanê Bidlîsî tarafından yazıldı.',
            explanationKu:
                'Şerefname ji aliyê Şerefxanê Bidlîsî ve hatiye '
                'nivîsandin.',
            explanationTr: 'Şerefname, Şerefxanê Bidlîsî tarafından yazıldı.',
          ),
        ],
      ),
    );
    await _shoot(t, '44_review');
  }, tags: ['preview']);

  // Sonuç ekranı tura hiç girmemişti: turun bittiği, puanın, rozetlerin
  // ve bütün açıklamaların görüldüğü ekran ölçüm dışı kalıyordu
  // (2026-07-27). Ölçülmeyen yerde kusur görünmez.
  testWidgets('68 tur sonucu', (t) async {
    await _pump(t, _resultScreen());
    await _shoot(t, '68_result');
  }, tags: ['preview']);

  testWidgets('69 tur sonucu (karanlık)', (t) async {
    await _pump(t, _resultScreen(), dark: true);
    await _shoot(t, '69_result_dark');
  }, tags: ['preview']);

  testWidgets('70 tur sonucu (Kurmancî)', (t) async {
    await _pump(t, _resultScreen(), ku: true);
    await _shoot(t, '70_result_ku');
  }, tags: ['preview']);

  // Bu iki ekran da tura hiç girmemişti: ikisi de menüden açılıyor ve
  // ikisi de içerik listeliyor — yani boş durumu, uzun metni ve dili
  // ölçülmemişti (2026-07-27).
  testWidgets('71 kayıtlı sorular', (t) async {
    await _pump(t, FavoriteQuestionsScreen(repository: repository));
    await _shoot(t, '71_favorites');
  }, tags: ['preview']);

  testWidgets('72 görsel künyesi', (t) async {
    await _pump(t, const ImageCreditsScreen());
    await _shoot(t, '72_image_credits');
  }, tags: ['preview']);

  // Açılış ekranı turda yoktu: 1,8 saniye yaşadığı için ekran görüntüsü
  // almak zor, o yüzden hiç ölçülmemiş. Oysa uygulamayı açan herkesin
  // gördüğü ilk kare orası (2026-07-28).
  //
  // Numaralar 78/79: eklendiğinde 71/72 verilmişti ve o ikisi kayıtlı
  // sorular ile görsel künyesinde zaten kullanılıyordu. Aynı öneke sahip
  // iki test aynı dosyaya yazmıyor ama klasörde `71_favorites.png` ile
  // `71_splash.png` yan yana duruyor, sıralama bozuluyordu — turu okuyan
  // kişi hangisinin 71 olduğunu bilemiyordu (2026-08-16).
  testWidgets('78 açılış', (t) async {
    await _pump(
      t,
      const SplashScreen(next: SizedBox.shrink(), duration: Duration(hours: 1)),
    );
    await t.pump(const Duration(milliseconds: 900));
    await _shoot(t, '78_splash');
  }, tags: ['preview']);

  testWidgets('79 açılış (karanlık)', (t) async {
    await _pump(
      t,
      const SplashScreen(next: SizedBox.shrink(), duration: Duration(hours: 1)),
      dark: true,
    );
    await t.pump(const Duration(milliseconds: 900));
    await _shoot(t, '79_splash_dark');
  }, tags: ['preview']);

  // Yeni kullanıcının gördüğü ilk üç ekran da turda yoktu: karşılama,
  // giriş ve ad sorma. İlk izlenimin ölçülmemesi tuhaf bir boşluktu
  // (2026-07-27). Bunlar simülatörde tek tek gözden geçirilmişti; tura
  // girmeleri, bir dahakine gözle bakmadan ölçülebilmeleri için.
  testWidgets('73 karşılama', (t) async {
    await _pump(t, OnboardingScreen(onComplete: () {}));
    await _shoot(t, '73_onboarding');
  }, tags: ['preview']);

  testWidgets('73b karşılama (Kurmancî)', (t) async {
    await _pump(t, OnboardingScreen(onComplete: () {}), ku: true);
    await _shoot(t, '73b_onboarding_ku');
  }, tags: ['preview']);

  // İkinci tanıtım sayfası (yarış) 2026-09-27'de sahne fonu kazandı; tur
  // yalnız ilk sayfayı basıyordu, ikinci sayfa hiç görülmeden gidiyordu.
  testWidgets('73c karşılama, yarış sayfası', (t) async {
    await _pump(t, OnboardingScreen(onComplete: () {}));
    await t.tap(find.text('Sonraki'));
    // Sayfa geçişi bitince sayfa göstergesi kendi 240 ms'lik animasyonunu
    // ANCAK bir sonraki karede başlatır; üçüncü kare olmadan görüntü eski
    // göstergeyi basıyordu.
    for (var i = 0; i < 3; i++) {
      await t.pump(const Duration(milliseconds: 600));
    }
    await _shoot(t, '73c_onboarding_compete');
  }, tags: ['preview']);

  testWidgets('74 giriş', (t) async {
    await _pump(t, const SignInScreen());
    await _shoot(t, '74_sign_in');
  }, tags: ['preview']);

  testWidgets('75 giriş (karanlık)', (t) async {
    await _pump(t, const SignInScreen(), dark: true);
    await _shoot(t, '75_sign_in_dark');
  }, tags: ['preview']);

  testWidgets('76 kayıt', (t) async {
    await _pump(t, const SignUpScreen());
    await _shoot(t, '76_sign_up');
  }, tags: ['preview']);

  // Kayıt sihirbazının 2. adımı: alt perdede "Geri" metin düğmesi görünür
  // (1. adımda "Giriş yap" bağlantısı vardır). Önceki tur yalnız ilk adımı
  // basıyordu; ikincil eylemin yeri ve ilerleme çubuğunun dolgusu görünmezdi.
  testWidgets('118 kayıt, 2. adım', (t) async {
    await _pump(t, const SignUpScreen());
    final fields = find.byType(EditableText);
    await t.enterText(fields.at(0), 'rojda@example.com');
    await t.enterText(fields.at(1), 'sifre123');
    await t.enterText(fields.at(2), 'sifre123');
    await t.tap(find.text('İleri'));
    for (var i = 0; i < 3; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    await _shoot(t, '118_sign_up_step2');
  }, tags: ['preview']);

  testWidgets('77 ad sorma', (t) async {
    await _pump(
      t,
      ProfileNameGateScreen(repository: repository, onCompleted: () {}),
    );
    await _shoot(t, '77_name_gate');
  }, tags: ['preview']);

  // ── Kalan ekranların karanlık tema taraması ──
  //
  // Karanlık tema yalnız altı ekranda ölçülmüştü ve orada gerçek bir
  // kontrast kusuru çıkmıştı (öğrenme kartı). Kalan ekranlar da basılır:
  // ölçülmeyen yerde kusur görünmez.
  testWidgets('45 ayarlar (karanlık)', (t) async {
    await _pump(t, SettingsScreen(repository: repository), dark: true);
    await _shoot(t, '45_settings_dark');
  }, tags: ['preview']);

  testWidgets('46 arkadaşlar (karanlık)', (t) async {
    await _pump(
      t,
      FriendsScreen(repository: _PopulatedStateRepository()),
      dark: true,
    );
    await _shoot(t, '46_friends_dark');
  }, tags: ['preview']);

  testWidgets('47 çark (karanlık)', (t) async {
    await _pump(t, SpinWheelScreen(repository: repository), dark: true);
    await _shoot(t, '47_spin_dark');
  }, tags: ['preview']);

  testWidgets('48 turnuva (karanlık)', (t) async {
    await _pump(t, TournamentScreen(repository: repository), dark: true);
    await _shoot(t, '48_tournament_dark');
  }, tags: ['preview']);

  testWidgets('49 oda (karanlık)', (t) async {
    await _pump(
      t,
      RoomScreen(repository: repository, initialRoom: repository.createRoom()),
      dark: true,
    );
    await _shoot(t, '49_room_dark');
  }, tags: ['preview']);

  testWidgets('50 rakip arama (karanlık)', (t) async {
    await _pump(t, MatchmakingScreen(repository: repository), dark: true);
    await _shoot(t, '50_matchmaking_dark');
  }, tags: ['preview']);

  // Quiz sahnesi dış uygulama temasından bilinçli olarak bağımsız ve her
  // zaman koyudur (`QuizScreen` -> `Theme(data: AppTheme.stage)`). Bu kare
  // uygulama teması koyuyken de sahnenin değişmemesini korur; 14 ile aynı
  // PNG çıkması burada bir tur körlüğü değil, ürün sözleşmesidir.
  testWidgets('51 ders akışı (koyu uygulama temasında sabit sahne)', (t) async {
    await _pump(
      t,
      QuizScreen(
        repository: repository,
        room: repository.createRoom(),
        questions: repository.questions.take(5).toList(),
        experience: QuizExperience.learning,
        enableTimer: false,
      ),
      dark: true,
    );
    await _shoot(t, '51_lesson_dark');
  }, tags: ['preview']);

  testWidgets('53 seviyeler (karanlık)', (t) async {
    await _pump(
      t,
      LevelScreen(repository: repository, category: 'Ziman'),
      dark: true,
    );
    await _shoot(t, '53_levels_dark');
  }, tags: ['preview']);

  testWidgets('54 soru öner (karanlık)', (t) async {
    await _pump(t, SuggestQuestionScreen(repository: repository), dark: true);
    await _shoot(t, '54_suggest_dark');
  }, tags: ['preview']);

  testWidgets('55 öğrenme (karanlık)', (t) async {
    await _pump(t, LearningScreen(repository: repository), dark: true);
    await _shoot(t, '55_learning_dark');
  }, tags: ['preview']);

  testWidgets('56 öğrenme', (t) async {
    await _pump(t, LearningScreen(repository: repository));
    await _shoot(t, '56_learning');
  }, tags: ['preview']);

  // ── Kalan ekranların Kurmancî taraması ──
  //
  // Karanlık tema taraması bir yerelleştirme kusuru çıkardı (ders adları).
  // Aynı mantık dil için de geçerli: Kurmancî yalnız altı ekranda
  // ölçülmüştü.
  testWidgets('57 öğrenme (Kurmancî)', (t) async {
    await _pump(t, LearningScreen(repository: repository), ku: true);
    await _shoot(t, '57_learning_ku');
  }, tags: ['preview']);

  testWidgets('58 seviye sınavı (Kurmancî)', (t) async {
    await _pump(t, LevelPlacementScreen(repository: repository), ku: true);
    await _shoot(t, '58_placement_ku');
  }, tags: ['preview']);

  testWidgets('59 soru öner (Kurmancî)', (t) async {
    await _pump(t, SuggestQuestionScreen(repository: repository), ku: true);
    await _shoot(t, '59_suggest_ku');
  }, tags: ['preview']);

  testWidgets('60 seviyeler (Kurmancî)', (t) async {
    await _pump(
      t,
      LevelScreen(repository: repository, category: 'Ziman'),
      ku: true,
    );
    await _shoot(t, '60_levels_ku');
  }, tags: ['preview']);

  // 2026-09-30 izgara: konu akışının ortak başlığı (alt kategori → seviye)
  // yalnız kategoriyle açılan seviye ekranında değil, alt kategoriyle açılan
  // gerçek akışta ve uzun adlı konuda (Zanist û Raman) da görülmeli.
  testWidgets('38b seviyeler (alt kategori)', (t) async {
    await _pump(
      t,
      LevelScreen(
        repository: repository,
        category: 'Ziman',
        subCategory: 'reziman',
      ),
    );
    await _shoot(t, '38b_levels_sub');
  }, tags: ['preview']);

  testWidgets('37b alt kategoriler (Bilim ve Düşünce, Kurmancî)', (t) async {
    await _pump(
      t,
      SubcategoryScreen(repository: repository, category: 'Paradigma'),
      ku: true,
    );
    await _shoot(t, '37b_subcategories_bilim_ku');
  }, tags: ['preview']);

  testWidgets('60b seviyeler (Bilim ve Düşünce, Kurmancî)', (t) async {
    await _pump(
      t,
      LevelScreen(
        repository: repository,
        category: 'Paradigma',
        subCategory: 'civak_maf',
      ),
      ku: true,
    );
    await _shoot(t, '60b_levels_bilim_ku');
  }, tags: ['preview']);

  // Oda lobisinin üç durumu: ev sahibi yalnız (rakip bekliyor), ev sahibi
  // + hazır olmayan konuk, konuk. Önceki kareler yalnız "iki hazır oyunculu
  // ev sahibi"ni basıyordu; asıl kalabalık ve asıl boş durumlar görünmezdi.
  testWidgets('115 oda — ev sahibi yalnız', (t) async {
    await _pump(
      t,
      RoomScreen(
        repository: _LobbyTourRepository(_LobbyView.hostAlone),
        initialRoom: _LobbyTourRepository.room(_LobbyView.hostAlone),
      ),
    );
    await _shoot(t, '115_room_host_alone');
  }, tags: ['preview']);

  testWidgets('116 oda — ev sahibi, konuk hazır değil', (t) async {
    await _pump(
      t,
      RoomScreen(
        repository: _LobbyTourRepository(_LobbyView.hostGuestNotReady),
        initialRoom: _LobbyTourRepository.room(_LobbyView.hostGuestNotReady),
      ),
    );
    await _shoot(t, '116_room_host_guest_not_ready');
  }, tags: ['preview']);

  testWidgets('117 oda — konuk', (t) async {
    await _pump(
      t,
      RoomScreen(
        repository: _LobbyTourRepository(_LobbyView.guest),
        initialRoom: _LobbyTourRepository.room(_LobbyView.guest),
      ),
    );
    await _shoot(t, '117_room_guest');
  }, tags: ['preview']);

  testWidgets('62 oda (Kurmancî)', (t) async {
    await _pump(
      t,
      RoomScreen(repository: repository, initialRoom: repository.createRoom()),
      ku: true,
    );
    await _shoot(t, '62_room_ku');
  }, tags: ['preview']);

  testWidgets('63 turnuva (Kurmancî)', (t) async {
    await _pump(t, TournamentScreen(repository: repository), ku: true);
    await _shoot(t, '63_tournament_ku');
  }, tags: ['preview']);

  testWidgets('64 çark (Kurmancî)', (t) async {
    await _pump(t, SpinWheelScreen(repository: repository), ku: true);
    await _shoot(t, '64_spin_ku');
  }, tags: ['preview']);

  testWidgets('65 arkadaşlar (Kurmancî)', (t) async {
    await _pump(
      t,
      FriendsScreen(repository: _PopulatedStateRepository()),
      ku: true,
    );
    await _shoot(t, '65_friends_ku');
  }, tags: ['preview']);

  testWidgets('66 rakip arama (Kurmancî)', (t) async {
    await _pump(t, MatchmakingScreen(repository: repository), ku: true);
    await _shoot(t, '66_matchmaking_ku');
  }, tags: ['preview']);

  testWidgets('67 tur özeti (Kurmancî)', (t) async {
    await _pump(
      t,
      ReviewScreen(
        room: repository.createRoom(),
        records: const [
          AnswerRecord(
            id: 'r1',
            category: 'Ziman',
            prompt: 'Peyva «av» bi Tirkî çi tê gotin?',
            answers: ['su', 'ekmek'],
            correctAnswer: 'su',
            selectedAnswer: 'ekmek',
            explanation: '«av» Türkçede «su» demektir.',
            explanationKu: '«av» bi Tirkî dibe «su».',
            explanationTr: '«av» Türkçede «su» demektir.',
          ),
        ],
      ),
      ku: true,
    );
    await _shoot(t, '67_review_ku');
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
    //
    // Açıklama 800 ms'lik bir denetleyicinin bitişinde açılır, üstüne
    // 350+400 ms'lik boyut/opaklık geçişleri biner. Önceki 1600 ms'lik tek
    // pump yetmiyordu ve ekran görüntüsü paneli hiç göstermiyordu — panel
    // çalışmıyor sanılmasına yol açan bir tur kusuru
    // (bkz. `test/lesson_explanation_test.dart`).
    await t.tap(find.text(repository.questions.first.answers.first));
    await t.pump();
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
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

  // ── Turun kendi kör noktaları (2026-08-16 taraması) ──
  //
  // Turda 76 kare vardı ama dört ekran hiç açılmıyordu ve soru anının en
  // önemli iki hâli — yanlış cevap ve Kurmancî — hiç basılmıyordu. Yani
  // "bütün ana ekranlar basılıyor" cümlesi doğru değildi.

  // Sekmeli kabuk: alt gezinme çubuğunu gösteren tek kare. Her ekran tek
  // tek basılıyordu ama kullanıcının uygulamada sürekli gördüğü çubuk
  // hiçbirinde yoktu.
  testWidgets('80 sekmeli kabuk', (t) async {
    // Sabit monitör şart: gerçek `ConnectivityMonitor` connectivity_plus
    // eklentisine gider, koşucuda platform tarafı yoktur ve `_pump`un
    // `runAsync` turunda hiç tamamlanmayan bir Future bırakır — kare
    // yazıldıktan sonra test 10 dakika asılı kalıp zaman aşımına düşüyordu.
    // `app_shell_*_test.dart` dosyalarının hepsi aynı monitörü verir.
    await _pump(
      t,
      AppShell(
        repository: repository,
        connectivityMonitor: const AlwaysOnlineConnectivityMonitor(),
      ),
    );
    await _shoot(t, '80_app_shell');
  }, tags: ['preview']);

  // Öğrenme sekmesinin kökü. `HomeScreen`i sarar ve gezinme argümanlarını
  // bağlar; kendi başına hiç ölçülmemişti.
  testWidgets('81 öğrenme kökü', (t) async {
    await _pump(t, LearnHomeScreen(repository: repository));
    await _shoot(t, '81_learn_home');
  }, tags: ['preview']);

  // Parola sıfırlama: e-posta bağlantısıyla açılır, yani tur sırasında
  // kimsenin uğramadığı bir ekran. Bir kusuru olsa kullanıcı hesabına
  // giremezken fark edilirdi.
  testWidgets('82 parola yenileme', (t) async {
    await _pump(t, const PasswordRecoveryScreen());
    await _shoot(t, '82_password_recovery');
  }, tags: ['preview']);

  // Maç bitti ama sonuç teslim edilemedi hâli. Widget testleri bu ekranın
  // davranışını sıkı ölçüyor (`room_result_recovery_screen_test.dart`),
  // görünüşünü hiç ölçmüyordu.
  testWidgets('83 sonuç kurtarma', (t) async {
    await _pump(
      t,
      RoomResultRecoveryScreen(
        repository: repository,
        snapshot: _recoverySnapshot(),
        expectedUserId: 'user',
      ),
    );
    await _shoot(t, '83_room_result_recovery');
  }, tags: ['preview']);

  // Yanlış cevap anı. Tur yalnız doğru cevabı basıyordu (`15_lesson_answered`
  // ilk şıkkı seçer ve mock bankada ilk şık doğrudur), yani kırmızı geri
  // bildirim, seçilen yanlış şıkkın hâli ve açıklama panelinin yanlış
  // varyantı hiç görülmüyordu.
  testWidgets('84 ders akışı — yanlış cevap', (t) async {
    final questions = repository.questions.take(5).toList();
    await _pump(
      t,
      QuizScreen(
        repository: repository,
        room: repository.createRoom(),
        questions: questions,
        experience: QuizExperience.learning,
        enableTimer: false,
      ),
    );
    // Doğru şıkkın dışındaki ilk şık: mock bankada `answers.first` doğru
    // olduğu için `15_lesson_answered` hep yeşil hâli basıyordu.
    final wrong = questions.first.answers.firstWhere(
      (a) => a != questions.first.correctAnswer,
    );
    await t.tap(find.text(wrong));
    await t.pump();
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    await _shoot(t, '84_lesson_wrong_answer');
  }, tags: ['preview']);

  // ── Kurmancî ikizleri ──────────────────────────────────────────────
  //
  // Ürünün ASIL dili Kurmancî: temiz kurulumda uygulama Kurmancî açılıyor.
  // Buna karşın tur neredeyse tamamen Türkçe basıyordu ve eklenen İLK
  // Kurmancî karesi (85) anında bir kırpma kusuru buldu — joker etiketleri
  // "Alîkariya Be…" diye kesiliyordu. Kurmancî metinler Türkçeden düzenli
  // olarak uzun; yani kırpma ve taşma önce burada görünür.
  //
  // Aşağıdakiler, düzeni en çok zorlayan karelerin Kurmancî ikizleridir.
  testWidgets('85 yarışma akışı (Kurmancî)', (t) async {
    await _pump(
      t,
      QuizScreen(
        repository: repository,
        room: repository.createRoom(),
        questions: repository.questions.take(5).toList(),
      ),
      ku: true,
    );
    await _shoot(t, '85_competition_question_ku');
  }, tags: ['preview']);

  testWidgets('86 ders akışı — cevaplanmış (Kurmancî)', (t) async {
    final questions = repository.questions.take(5).toList();
    await _pump(
      t,
      QuizScreen(
        repository: repository,
        room: repository.createRoom(),
        questions: questions,
        experience: QuizExperience.learning,
        enableTimer: false,
      ),
      ku: true,
    );
    await t.tap(find.text(questions.first.correctAnswer));
    await t.pump();
    for (var i = 0; i < 12; i++) {
      await t.pump(const Duration(milliseconds: 300));
    }
    await _shoot(t, '86_lesson_answered_ku');
  }, tags: ['preview']);

  testWidgets('87 giriş (Kurmancî)', (t) async {
    await _pump(t, const SignInScreen(), ku: true);
    await _shoot(t, '87_sign_in_ku');
  }, tags: ['preview']);

  testWidgets('88 ad sorma (Kurmancî)', (t) async {
    await _pump(
      t,
      ProfileNameGateScreen(repository: repository, onCompleted: () {}),
      ku: true,
    );
    await _shoot(t, '88_name_gate_ku');
  }, tags: ['preview']);

  testWidgets('89 ayarlar (Kurmancî, karanlık)', (t) async {
    await _pump(
      t,
      SettingsScreen(repository: repository),
      ku: true,
      dark: true,
    );
    await _shoot(t, '89_settings_ku_dark');
  }, tags: ['preview']);

  // ── 2026-08-19 Eklenen Yüzeyler ──────────────────────────────────
  //
  // 1. Oda kurma sheet'i (_CustomRoomBottomSheet) — kategori, soru sayısı,
  //    süre ve jeton bahsi seçimleri. Açık/TR, karanlık ve Kurmancî.
  testWidgets("90 oda kurma sheet'i", (t) async {
    await _pump(t, PlayHubScreen(repository: repository));
    // Dar ekranda / büyük yazıda düğme kıvrımın altında kalır (tur
    // `ZANKURD_SCREEN_TOUR_WIDTH/TEXT_SCALE` ile bu koşulu basabilir).
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('play-hub-create-room')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.byKey(const ValueKey('play-hub-create-room')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 800));
    await _shoot(t, '90_custom_room_sheet');
  }, tags: ['preview']);

  testWidgets("91 oda kurma sheet'i (karanlık)", (t) async {
    await _pump(t, PlayHubScreen(repository: repository), dark: true);
    // Dar ekranda / büyük yazıda düğme kıvrımın altında kalır (tur
    // `ZANKURD_SCREEN_TOUR_WIDTH/TEXT_SCALE` ile bu koşulu basabilir).
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('play-hub-create-room')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.byKey(const ValueKey('play-hub-create-room')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 800));
    await _shoot(t, '91_custom_room_sheet_dark');
  }, tags: ['preview']);

  testWidgets("92 oda kurma sheet'i (Kurmancî)", (t) async {
    await _pump(t, PlayHubScreen(repository: repository), ku: true);
    // Dar ekranda / büyük yazıda düğme kıvrımın altında kalır (tur
    // `ZANKURD_SCREEN_TOUR_WIDTH/TEXT_SCALE` ile bu koşulu basabilir).
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('play-hub-create-room')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.tap(find.byKey(const ValueKey('play-hub-create-room')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 800));
    await _shoot(t, '92_custom_room_sheet_ku');
  }, tags: ['preview']);

  // 2. Uçuşan reaksiyon baloncukları — animasyon hâlinde yakalanır.
  // RoomScreen zaten kendi FloatingReactionOverlay'ini taşır. Dışarıdan
  // ikinci bir overlay sarmak uygulamada olmayan bir geometri üretip oyuncu
  // satırlarını örten sahte bir QA bulgusuna yol açıyordu. Fixture artık
  // gerçek broadcast → RoomScreen → iç controller yolunu kullanır.
  testWidgets('93 uçuşan reaksiyonlar', (t) async {
    final reactionRepository = _ReactionStateRepository();
    addTearDown(reactionRepository.close);
    final reactionRoom = reactionRepository.createRoom().copyWith(
      id: 'tour-reactions',
    );
    await _pump(
      t,
      RoomScreen(repository: reactionRepository, initialRoom: reactionRoom),
    );
    reactionRepository.emitReaction(
      '👏 Destxweş!',
      senderName: 'Berfin',
      senderId: 'tour-berfin',
    );
    // Tepkiyi yalnız odadaki oyuncu gönderir (bkz. [_TourRepository]):
    // eskiden odada olmayan Rojda ve Baran da tepki atıyordu.
    reactionRepository.emitReaction(
      '🔥 Agir!',
      senderName: 'Berfin',
      senderId: 'tour-berfin',
    );
    await t.pump();
    await t.pump(const Duration(milliseconds: 500));
    await _shoot(t, '93_floating_reactions');
  }, tags: ['preview']);

  // 3. Çevrimiçi 1v1 maç sonu — galibiyet görünümü ve "Yeni Oda" düğmesi.
  testWidgets('94 1v1 maç sonu (galibiyet)', (t) async {
    await _pump(t, _result1v1VictoryScreen());
    // Vakanın DERDİ "Yeni Oda" düğmesi; o düğme sayfanın altında ve ilk
    // kadrajda görünmüyordu. Ekran görüntüsü, göstermek için var olduğu
    // şeyi göstermezse tur o vakayı boşuna koşturur.
    // `ensureVisible` YETMEZ: sonuç ekranı tembel kuran bir listedir ve
    // eylem satırı henüz İNŞA EDİLMEMİŞTİR — bulucu hiçbir öğe bulamaz.
    // Önce kaydırıp inşa ettirmek gerekir.
    final action = find.byKey(const ValueKey('result-new-room-button'));
    await t.scrollUntilVisible(
      action,
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pump(const Duration(milliseconds: 400));
    await _shoot(t, '94_result_1v1_win');
  }, tags: ['preview']);

  testWidgets('95 öğrenen sözlüğü', (t) async {
    await _pump(t, const LearnerLexiconScreen());
    await _shoot(t, '95_learner_lexicon');
  }, tags: ['preview']);

  testWidgets('96 ders hızlı hatırlama', (t) async {
    final lesson = (await repository.loadLessonsByCategory('everyday')).first;
    await _pump(t, LessonDetailScreen(lesson: lesson, repository: repository));
    await t.tap(find.text('İleri'));
    await t.pumpAndSettle();
    final reveal = find.byKey(const ValueKey('lesson-recall-reveal'));
    await t.ensureVisible(reveal);
    await t.tap(reveal);
    await t.pump();
    await _shoot(t, '96_lesson_recall');
  }, tags: ['preview']);

  // ── Sırayla düello ekranları ────────────────────────────────────────
  testWidgets('97 oyun merkezi — sırayla düello', (t) async {
    final repo = MockZanKurdRepository();
    await t.runAsync(() async {
      // "Rakip bekleniyor" satırı: oyuncunun açtığı, 5/7 bitirdiği düello.
      await _playAsyncDuel(repo, correctCount: 5);
      // "Sonuç hazır" satırı (tamamlanmış, görülmemiş): Rojda'ya karşı 5–3,
      // `101`/`103` karelerindeki düellonun ta kendisi.
      await _seedRojdaDuel(repo);
    });
    await _pump(t, PlayHubScreen(repository: repo, asyncDuelEnabled: true));
    // Kutu tembel kurulan listenin altında: kurulmamış olabilir, bu yüzden
    // koşulsuz kaydırılır (scrollUntilVisible kurulmayı da bekler).
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('play-hub-async-duel-inbox')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pump(const Duration(milliseconds: 300));
    await _shoot(t, '97_play_hub_async_duel');
  }, tags: ['preview']);

  testWidgets('98 oyun merkezi — sırayla düello (karanlık, Kurmancî)', (
    t,
  ) async {
    final repo = MockZanKurdRepository();
    await t.runAsync(() async {
      await _playAsyncDuel(repo, correctCount: 5);
      await _seedRojdaDuel(repo);
    });
    await _pump(
      t,
      PlayHubScreen(repository: repo, asyncDuelEnabled: true),
      dark: true,
      ku: true,
    );
    // Kutu tembel kurulan listenin altında: kurulmamış olabilir, bu yüzden
    // koşulsuz kaydırılır (scrollUntilVisible kurulmayı da bekler).
    await t.scrollUntilVisible(
      find.byKey(const ValueKey('play-hub-async-duel-inbox')),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await t.pump(const Duration(milliseconds: 300));
    await _shoot(t, '98_play_hub_async_duel_dark_ku');
  }, tags: ['preview']);

  testWidgets('99 sırayla düello — soru', (t) async {
    final repo = MockZanKurdRepository();
    await t.runAsync(() async {
      await repo.startAsyncDuel();
    });
    await _pump(t, AsyncDuelPlayScreen(repository: repo));
    await _shoot(t, '99_async_duel_question');
  }, tags: ['preview']);

  testWidgets('100 sırayla düello — açıklandı', (t) async {
    final repo = MockZanKurdRepository();
    await t.runAsync(() async {
      await repo.startAsyncDuel();
    });
    await _pump(t, AsyncDuelPlayScreen(repository: repo));
    await t.tap(find.byKey(const ValueKey('async-duel-option-0')));
    await t.pump();
    // Açıklama duraklaması 1200 ms; kare onun İÇİNDE çekilir, yoksa ekran
    // ikinci soruya geçmiş olur ve renkler görünmez.
    await t.pump(const Duration(milliseconds: 300));
    await _shoot(t, '100_async_duel_revealed');
    // Açıklama duraklamasının zamanlayıcısı kapanmadan test bitmesin.
    await t.pump(const Duration(seconds: 2));
  }, tags: ['preview']);

  testWidgets('101 sırayla düello — sonuç (galibiyet)', (t) async {
    final repo = MockZanKurdRepository();
    late AsyncDuelSummary completedSummary;
    await t.runAsync(() async {
      // Oyun merkezindeki "Sonuç hazır" satırıyla aynı düello: 5–3.
      await _seedRojdaDuel(repo);
      final summaries = await repo.loadMyAsyncDuels();
      completedSummary = summaries.firstWhere((s) => s.outcome != null);
    });
    await _pump(
      t,
      AsyncDuelResultScreen(
        repository: repo,
        view: AsyncDuelResultView.fromSummary(completedSummary),
      ),
    );
    await _shoot(t, '101_async_duel_result_win');
  }, tags: ['preview']);

  testWidgets('102 sırayla düello — sonuç (rakip bekleniyor)', (t) async {
    final repo = MockZanKurdRepository();
    late AsyncDuelSummary waitingSummary;
    await t.runAsync(() async {
      // Oyun merkezindeki "Rakip bekleniyor" satırıyla aynı düello: 5/7.
      await _playAsyncDuel(repo, correctCount: 5);
      final summaries = await repo.loadMyAsyncDuels();
      waitingSummary = summaries.first;
    });
    await _pump(
      t,
      AsyncDuelResultScreen(
        repository: repo,
        view: AsyncDuelResultView.fromSummary(waitingSummary),
      ),
    );
    await _shoot(t, '102_async_duel_result_waiting');
  }, tags: ['preview']);

  testWidgets('103 sırayla düello — sonuç (karanlık, Kurmancî)', (t) async {
    final repo = MockZanKurdRepository();
    late AsyncDuelSummary completedSummary;
    await t.runAsync(() async {
      // Oyun merkezindeki "Sonuç hazır" satırıyla aynı düello: 5–3.
      await _seedRojdaDuel(repo);
      final summaries = await repo.loadMyAsyncDuels();
      completedSummary = summaries.firstWhere((s) => s.outcome != null);
    });
    await _pump(
      t,
      AsyncDuelResultScreen(
        repository: repo,
        view: AsyncDuelResultView.fromSummary(completedSummary),
      ),
      dark: true,
      ku: true,
    );
    await _shoot(t, '103_async_duel_result_win_dark_ku');
  }, tags: ['preview']);

  // ── 2026-10-01 "Jeton yetmiyor" ve paywall dürüstlüğü (A5, A10) ──────
  //
  // Mağaza yarı yarıya yeten bakiyeyle: 120'lik ürün alınabilir (düğme),
  // ötekiler eksik miktarlı durum çipi taşır.
  testWidgets('104 mağaza — kısmen yeten bakiye', (t) async {
    await _pump(t, ShopScreen(repository: _BalanceTourRepository(200)));
    await _shoot(t, '104_shop_partial');
  }, tags: ['preview']);

  testWidgets('105 mağaza — kısmen yeten bakiye (karanlık)', (t) async {
    await _pump(
      t,
      ShopScreen(repository: _BalanceTourRepository(200)),
      dark: true,
    );
    await _shoot(t, '105_shop_partial_dark');
  }, tags: ['preview']);

  testWidgets('106 mağaza — kısmen yeten bakiye (Kurmancî)', (t) async {
    await _pump(
      t,
      ShopScreen(repository: _BalanceTourRepository(200)),
      ku: true,
    );
    await _shoot(t, '106_shop_partial_ku');
  }, tags: ['preview']);

  testWidgets('107 mağaza — yetmeyen ürünün penceresi', (t) async {
    await _pump(t, ShopScreen(repository: _BalanceTourRepository(200)));
    await t.tap(find.byKey(const ValueKey('shop-hero-surface')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 600));
    await _shoot(t, '107_shop_short_dialog');
  }, tags: ['preview']);

  testWidgets(
    '108 mağaza — yetmeyen ürünün penceresi (karanlık, Kurmancî)',
    (t) async {
      await _pump(
        t,
        ShopScreen(repository: _BalanceTourRepository(200)),
        dark: true,
        ku: true,
      );
      await t.tap(find.byKey(const ValueKey('shop-hero-surface')));
      await t.pump();
      await t.pump(const Duration(milliseconds: 600));
      await _shoot(t, '108_shop_short_dialog_dark_ku');
    },
    tags: ['preview'],
  );

  testWidgets('109 oda kurma — ücrete yetmiyor', (t) async {
    await _pump(t, PlayHubScreen(repository: _BalanceTourRepository(10)));
    await t.tap(find.byKey(const ValueKey('play-hub-create-room')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 800));
    final fee = find.byKey(const ValueKey('custom-room-fee-50'));
    await t.ensureVisible(fee);
    await t.tap(fee);
    await t.pump(const Duration(milliseconds: 400));
    await _shoot(t, '109_custom_room_short');
  }, tags: ['preview']);

  testWidgets('110 oda kurma — ücrete yetmiyor (karanlık, Kurmancî)', (
    t,
  ) async {
    await _pump(
      t,
      PlayHubScreen(repository: _BalanceTourRepository(10)),
      dark: true,
      ku: true,
    );
    await t.tap(find.byKey(const ValueKey('play-hub-create-room')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 800));
    final fee = find.byKey(const ValueKey('custom-room-fee-50'));
    await t.ensureVisible(fee);
    await t.tap(fee);
    await t.pump(const Duration(milliseconds: 400));
    await _shoot(t, '110_custom_room_short_dark_ku');
  }, tags: ['preview']);

  // Paywall PAKETLİ durumda: şimdiye dek turda yalnız "paketler yakında"
  // boş hâli vardı; fiyat, dönem, iptal sözü, yenileme koşulu, geri yükle
  // ve hukuk bağlantıları hiç görülmemişti.
  testWidgets('111 paywall — paketli', (t) async {
    await _pump(
      t,
      PaywallScreen(repository: repository),
      premiumService: fakePaywallService(),
    );
    await _shoot(t, '111_paywall_packages');
  }, tags: ['preview']);

  testWidgets('112 paywall — paketli (karanlık)', (t) async {
    await _pump(
      t,
      PaywallScreen(repository: repository),
      dark: true,
      premiumService: fakePaywallService(),
    );
    await _shoot(t, '112_paywall_packages_dark');
  }, tags: ['preview']);

  testWidgets('113 paywall — paketli (Kurmancî)', (t) async {
    await _pump(
      t,
      PaywallScreen(repository: repository),
      ku: true,
      premiumService: fakePaywallService(),
    );
    await _shoot(t, '113_paywall_packages_ku');
  }, tags: ['preview']);

  testWidgets('114 paywall — paketler yok (geri yükle görünür)', (t) async {
    await _pump(t, PaywallScreen(repository: repository));
    await _shoot(t, '114_paywall_empty_restore');
  }, tags: ['preview']);
  // ── Sonuç şablonu (A6): her bitiş ekranı kendi çeşidiyle ──────────────
  testWidgets('200 sonuç — öğrenme (ödülsüz)', (t) async {
    await _pump(
      t,
      _resultVariant(isLearningExperience: true, coins: 0, wrong: 1),
    );
    await _shoot(t, '200_result_learning');
  }, tags: ['preview']);

  testWidgets('201 sonuç — öğrenme (Kurmancî, karanlık)', (t) async {
    await _pump(
      t,
      _resultVariant(isLearningExperience: true, coins: 0, wrong: 1),
      dark: true,
      ku: true,
    );
    await _shoot(t, '201_result_learning_dark_ku');
  }, tags: ['preview']);

  testWidgets('202 sonuç — günün dersi', (t) async {
    await _pump(t, _resultVariant(dailyQuiz: true, coins: 20, wrong: 1));
    await _shoot(t, '202_result_daily');
  }, tags: ['preview']);

  testWidgets('203 sonuç — alıştırma (hepsi doğru, ödül yok)', (t) async {
    await _pump(
      t,
      _resultVariant(practice: true, coins: 0, wrong: 0, streak: 0),
    );
    await _shoot(t, '203_result_practice_perfect');
  }, tags: ['preview']);

  testWidgets('204 sonuç — 1v1 kayıp (karanlık)', (t) async {
    await _pump(
      t,
      _resultVariant(duelOpponentScore: 400, coins: 0, wrong: 2),
      dark: true,
    );
    await _shoot(t, '204_result_1v1_loss_dark');
  }, tags: ['preview']);

  testWidgets('205 sonuç — günlük tavan', (t) async {
    await _pump(t, _resultVariant(coins: 0, wrong: 1, dailyCapReached: true));
    await _shoot(t, '205_result_daily_cap');
  }, tags: ['preview']);

  AsyncDuelSummary duelSummary({int? mine, AsyncDuelStatus? status}) {
    return AsyncDuelSummary(
      duelId: 'tour-duel',
      status: status ?? AsyncDuelStatus.expired,
      role: AsyncDuelRole.creator,
      opponentName: 'Rojda',
      myCorrect: mine,
      createdAt: DateTime.utc(2026, 9, 28),
      seen: false,
    );
  }

  testWidgets('206 sırayla düello — süresi doldu', (t) async {
    await _pump(
      t,
      AsyncDuelResultScreen(
        repository: MockZanKurdRepository(),
        view: AsyncDuelResultView.fromSummary(duelSummary(mine: 4)),
      ),
    );
    await _shoot(t, '206_async_duel_result_expired');
  }, tags: ['preview']);

  testWidgets('207 sırayla düello — yarım kaldı (Kurmancî)', (t) async {
    await _pump(
      t,
      AsyncDuelResultScreen(
        repository: MockZanKurdRepository(),
        view: AsyncDuelResultView.fromSummary(duelSummary()),
      ),
      ku: true,
    );
    await _shoot(t, '207_async_duel_result_unfinished_ku');
  }, tags: ['preview']);

  Future<void> finishPlacement(WidgetTester t) async {
    await t.tap(find.byType(QuizOptionTile).first);
    // Sonuç `PlacementStore` yazımından sonra çıkar (gerçek I/O).
    await t.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 100)),
    );
    await t.pump(const Duration(milliseconds: 1600));
  }

  testWidgets('208 seviye belirleme sonucu', (t) async {
    await _pump(
      t,
      LevelPlacementScreen(repository: repository, questionCount: 1),
    );
    await finishPlacement(t);
    await _shoot(t, '208_placement_result');
  }, tags: ['preview']);

  testWidgets('209 seviye belirleme sonucu (Kurmancî, karanlık)', (t) async {
    await _pump(
      t,
      LevelPlacementScreen(repository: repository, questionCount: 1),
      dark: true,
      ku: true,
    );
    await finishPlacement(t);
    await _shoot(t, '209_placement_result_dark_ku');
  }, tags: ['preview']);

  testWidgets('210 tur özeti — hepsi doğru (sıfır karo yok)', (t) async {
    await _pump(
      t,
      ReviewScreen(
        room: repository.createRoom(),
        records: _tourRecords(wrong: 0).take(2).toList(),
      ),
    );
    await _shoot(t, '210_review_all_correct');
  }, tags: ['preview']);

  // ── Sıralama (A8): podyum, sabit kendi satırı ─────────────────────────
  testWidgets('220 sıralama — podyum', (t) async {
    await _pump(
      t,
      LeaderboardScreen(repository: _BoardRepository(players: 10)),
    );
    await _shoot(t, '220_leaderboard_podium');
  }, tags: ['preview']);

  testWidgets('221 sıralama — podyum (Kurmancî, karanlık)', (t) async {
    await _pump(
      t,
      LeaderboardScreen(repository: _BoardRepository(players: 10)),
      dark: true,
      ku: true,
    );
    await _shoot(t, '221_leaderboard_podium_dark_ku');
  }, tags: ['preview']);

  testWidgets('222 sıralama — iki oyuncu', (t) async {
    await _pump(t, LeaderboardScreen(repository: _BoardRepository(players: 2)));
    await _shoot(t, '222_leaderboard_two');
  }, tags: ['preview']);

  testWidgets('223 sıralama — sen listede değilsin (sabit satır)', (t) async {
    await _pump(
      t,
      LeaderboardScreen(repository: _BoardRepository(players: 10, myRank: 14)),
    );
    await _shoot(t, '223_leaderboard_self_pinned');
  }, tags: ['preview']);

  testWidgets('224 sıralama — sabit satır (karanlık, Kurmancî)', (t) async {
    await _pump(
      t,
      LeaderboardScreen(repository: _BoardRepository(players: 10, myRank: 14)),
      dark: true,
      ku: true,
    );
    await _shoot(t, '224_leaderboard_self_pinned_dark_ku');
  }, tags: ['preview']);

  testWidgets('225 sıralama — henüz sıralamada değilsin', (t) async {
    await _pump(t, LeaderboardScreen(repository: _BoardRepository(players: 5)));
    await _shoot(t, '225_leaderboard_not_ranked');
  }, tags: ['preview']);

  testWidgets('226 sıralama — dar ekran, uzun adlar', (t) async {
    await _pump(
      t,
      LeaderboardScreen(
        repository: _BoardRepository(players: 6, longNames: true, myRank: 9),
      ),
      size: const Size(320, 760),
    );
    await _shoot(t, '226_leaderboard_narrow_long_names');
  }, tags: ['preview']);
}

/// Sonuç ekranı çeşitleri (A6 kareleri): aynı üç soruluk tur, ödül/mod
/// bayraklarıyla farklı bitişler.
///
/// Kayıtlar [wrong] sayısından ÜRETİLİR (son [wrong] soru yanlış). Eskiden
/// sabit iki doğru kayıt vardı ve `_resultVariant` sayıları (2/3 doğru,
/// 1 yanlış) ayrıca elle veriyordu: kahraman "3 sorudan 2 doğru" derken
/// "Konulara göre" kartı kayıtlardan hesaplandığı için "Dil 2/2" ve
/// "2 sorudan 2 doğru" yazıyordu — üçüncü soru kayıtta hiç yoktu. Gerçek
/// ekranda bu ayrışma olmaz (her soru, zaman aşımı dahil, bir kayıt
/// bırakır); kusur yalnız turun örnek verisindeydi ve turun kareleri
/// tasarım kararlarına kaynak olduğu için tutarsız bir örnek yanıltıcıydı.
/// Sayılar artık kayıtlardan türer, ayrışmaları yapısal olarak imkânsızdır.
List<AnswerRecord> _tourRecords({int wrong = 1}) {
  assert(wrong >= 0 && wrong <= 3);
  const specs = [
    (
      id: 'r1',
      category: 'Ziman',
      prompt: 'Peyva «av» bi Tirkî çi tê gotin?',
      answers: ['su', 'ekmek', 'yol', 'dağ'],
      correct: 'su',
      wrongPick: 'yol',
      ku: '«av» bi Tirkî dibe «su».',
      tr: '«av» Türkçede «su» demektir.',
    ),
    (
      id: 'r2',
      category: 'Ziman',
      prompt: 'Peyva «agir» bi Tirkî çi tê gotin?',
      answers: ['ateş', 'su', 'hava', 'toprak'],
      correct: 'ateş',
      wrongPick: 'hava',
      ku: '«agir» bi Tirkî dibe «ateş».',
      tr: '«agir» Türkçede «ateş» demektir.',
    ),
    (
      id: 'r3',
      category: 'Çand',
      prompt: 'Çay li kîjan firaxê tê vexwarin?',
      answers: ['bardak', 'kase', 'sênî', 'beroş'],
      correct: 'bardak',
      wrongPick: 'kase',
      ku: 'Çay bi gelemperî di «bardak»ê de tê vexwarin.',
      tr: 'Çay genellikle «bardak» ile içilir.',
    ),
  ];
  return [
    for (var i = 0; i < specs.length; i++)
      AnswerRecord(
        id: specs[i].id,
        category: specs[i].category,
        prompt: specs[i].prompt,
        answers: specs[i].answers,
        correctAnswer: specs[i].correct,
        selectedAnswer: i >= specs.length - wrong
            ? specs[i].wrongPick
            : specs[i].correct,
        explanation: specs[i].tr,
        explanationKu: specs[i].ku,
        explanationTr: specs[i].tr,
      ),
  ];
}

Widget _resultVariant({
  bool isLearningExperience = false,
  bool dailyQuiz = false,
  bool practice = false,
  bool dailyCapReached = false,
  int? duelOpponentScore,
  int coins = 30,
  int wrong = 1,
  int streak = 2,
}) {
  final repository = _TourRepository();
  final room = repository.createRoom();
  final records = _tourRecords(wrong: wrong);
  final total = records.length;
  final correct = records.where((r) => r.isCorrect).length;
  assert(correct + wrong == total, 'kahraman sayıları kayıtlarla uyuşmalı');
  return QuizResultScreen(
    repository: repository,
    room: room,
    score: isLearningExperience ? 0 : 240,
    correctCount: correct,
    wrongCount: wrong,
    totalQuestions: total,
    bestStreak: streak,
    coinsAwarded: coins,
    isLearningExperience: isLearningExperience,
    dailyQuiz: dailyQuiz,
    practice: practice,
    dailyCapReached: dailyCapReached,
    opponents: duelOpponentScore == null
        ? const []
        : [
            Player(
              id: 'opp',
              name: 'Rojda',
              score: duelOpponentScore,
              state: Player.readyState,
            ),
          ],
    answerRecords: records,
  );
}

/// Sıralama kareleri için ayarlanabilir tahta: [players] satır (en üst 10'a
/// kadar), isteğe bağlı olarak oyuncunun listenin DIŞINDAKİ dönem sırası.
class _BoardRepository extends MockZanKurdRepository {
  _BoardRepository({
    required this.players,
    this.myRank,
    this.longNames = false,
  });

  final int players;
  final int? myRank;
  final bool longNames;

  static const _names = [
    'Rojda',
    'Baran',
    'Dilan',
    'Diyar',
    'Berfin',
    'Rojîn',
    'Zelal',
    'Hêvîdar',
    'Azad',
    'Narîn',
  ];
  static const _longNames = [
    'Mihemed Emînê Şerefxan',
    'Ayşegül Hêvîdar Bayram',
    'Abdurrahman Cizîrî',
    'Zeynep Narîn Kaya',
    'Muhammed Resul Demir',
    'Rojhat Kendal',
  ];

  @override
  Future<List<LeaderboardEntry>> loadLeaderboard({
    int limit = 10,
    LeaderboardPeriod period = LeaderboardPeriod.weekly,
  }) async {
    return [
      for (var i = 0; i < players; i++)
        LeaderboardEntry(
          rank: i + 1,
          playerId: 'board-$i',
          displayName: longNames
              ? _longNames[i % _longNames.length]
              : _names[i % _names.length],
          totalScore: 8420 - i * 700,
          bestStreak: 11 - i,
          roomsPlayed: 14 - i,
        ),
    ];
  }

  @override
  Future<LeaderboardEntry?> getMyLeaderboardRank(
    LeaderboardPeriod period,
  ) async {
    final rank = myRank;
    if (rank == null) return null;
    return LeaderboardEntry(
      rank: rank,
      playerId: 'user',
      displayName: 'ZanKurd Oyuncusu',
      totalScore: 240,
      bestStreak: 2,
      roomsPlayed: 1,
    );
  }
}

/// Teslim edilememiş bir 1v1 sonucu — kurtarma ekranının beslendiği veri.
RoomResultSnapshot _recoverySnapshot() => RoomResultSnapshot(
  room: const GameRoom(
    id: 'room-1',
    name: '1vs1',
    code: 'ZK-TOUR',
    category: 'Ziman',
    players: [
      Player(id: 'user', name: 'Ez', score: 30, state: Player.readyState),
      Player(
        id: 'opponent',
        name: 'Rojda',
        score: 20,
        state: Player.readyState,
      ),
    ],
    status: RoomStatus.finished,
    questionCount: 2,
  ),
  ownPlayerId: 'user',
  questionIds: const ['q1', 'q2'],
  answers: const [
    ResumedAnswer(
      questionId: 'q1',
      questionIndex: 0,
      selectedOptionKey: 'A',
      correctOptionKey: 'A',
      isCorrect: true,
      pointsAwarded: 30,
      responseMs: 900,
    ),
    ResumedAnswer(
      questionId: 'q2',
      questionIndex: 1,
      selectedOptionKey: 'A',
      correctOptionKey: 'B',
      isCorrect: false,
      pointsAwarded: 0,
      responseMs: 1200,
    ),
  ],
  winnerId: 'user',
  endedReason: 'completed',
  forfeitedBy: null,
  finishedAt: DateTime.utc(2026, 8, 16),
);
