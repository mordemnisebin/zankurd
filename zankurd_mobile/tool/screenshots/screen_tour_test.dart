// ignore_for_file: avoid_print, invalid_use_of_visible_for_testing_member
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
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/models/player.dart';
import 'package:zankurd_mobile/src/models/room.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/models/contest.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/app_shell.dart';
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
import 'package:zankurd_mobile/src/screens/quiz_result_screen.dart';
import 'package:zankurd_mobile/src/screens/review_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_in_screen.dart';
import 'package:zankurd_mobile/src/screens/splash_screen.dart';
import 'package:zankurd_mobile/src/screens/sign_up_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/screens/avatar_editor_screen.dart';
import 'package:zankurd_mobile/src/screens/categories_tab.dart';
import 'package:zankurd_mobile/src/screens/level_placement_screen.dart';
import 'package:zankurd_mobile/src/screens/learning_screen.dart';
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

import 'package:zankurd_mobile/src/widgets/floating_reaction_overlay.dart';
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
/// Test koşucusunda yalnız burada yüklenen yazı tipleri çizilir. İkisi
/// kaçınılmaz olarak kutu görünür ve **uygulama hatası değildir**:
///
/// * emoji (ör. sıralama madalyaları 🥇🥈🥉) — sistem emoji fontu yok;
/// * `CustomPainter` içinde `TextPainter` ile çizilen metin (ör. çark
///   dilimlerinin etiketleri) — aile belirtilmediği için varsayılan ölçü
///   fontuna düşer, widget'lardaki gibi temadan Rubik almaz.
///
/// Bu ikisini doğrulamak için simülatör gerekir.
const _size = Size(390, 844);
const _outDir = 'docs/screenshots/tour';

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
      Player(id: 'opp', name: 'Hevrik', score: 180, state: Player.readyState),
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
      Player(id: 'opp', name: 'Hevrik', score: 180, state: Player.readyState),
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
  final repository = MockZanKurdRepository();
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
}) {
  return RepaintBoundary(
    key: _boundaryKey,
    child: testShell(
      child: Material(type: MaterialType.transparency, child: child),
      themeProvider: dark ? ThemeProvider(initialMode: ThemeMode.dark) : null,
      languageProvider: ku ? kurmanciLang() : null,
    ),
  );
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  bool ku = false,
}) async {
  _applyViewport(tester, _size);
  await tester.pumpWidget(
    _tourShell(
      child: child,
      dark: dark,
      ku: ku,
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

/// Yeni kullanıcının gerçekten gördüğü depo.
///
/// `MockZanKurdRepository` arkadaş, sıralama ve yarışma satırlarıyla dolu
/// gelir; tur bu yüzden hep "kalabalık" bir uygulamayı gösteriyordu. Oysa
/// ilk açılışta hiçbiri yok. Ürünün en önemli ölçütü ilk kullanımda
/// şaşırmamak olduğu için o hâl de basılmalı (2026-07-26).
class _EmptyStateRepository extends MockZanKurdRepository {
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
    const faces = {
      'assets/fonts/Rubik-Regular.ttf': FontWeight.normal,
      'assets/fonts/Rubik-Medium.ttf': FontWeight.w500,
      'assets/fonts/Rubik-Bold.ttf': FontWeight.w700,
      'assets/fonts/Rubik-Black.ttf': FontWeight.w900,
    };
    final loader = FontLoader('Rubik');
    for (final path in faces.keys) {
      loader.addFont(
        File(path).readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
      );
    }
    await loader.load();

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
    final entry = (packageConfig['packages'] as List)
        .cast<Map<String, dynamic>>()
        .firstWhere((p) => p['name'] == 'font_awesome_flutter');
    // `rootUri` sonunda eğik çizgi yok; doğrudan birleştirmek
    // ".../font_awesome_flutter-11.0.0lib/fonts/..." gibi var olmayan bir
    // yol üretiyordu ve uyarı sessizce geçilip ikonlar kare kalıyordu.
    final root = Uri.parse(entry['rootUri'] as String).toFilePath();
    final base = root.endsWith(Platform.pathSeparator)
        ? root
        : '$root${Platform.pathSeparator}';
    // Solid VE Regular birlikte yüklenir. Yalnız Solid yüklenirken Regular
    // ailesindeki ikonlar (ör. çark ekranındaki "hakkın hazır" onay
    // işareti) kare çiziliyordu ve turda uygulama hatası gibi görünüyordu
    // (2026-07-26).
    const iconFamilies = {
      'FontAwesomeSolid': 'lib/fonts/Font-Awesome-7-Free-Solid-900.otf',
      'FontAwesomeRegular': 'lib/fonts/Font-Awesome-7-Free-Regular-400.otf',
    };
    for (final family in iconFamilies.keys) {
      final iconFont = File('$base${iconFamilies[family]}');
      if (!iconFont.existsSync()) {
        print('UYARI: $family bulunamadı — o ikonlar kare çizilecek');
        continue;
      }
      // Aile adı paket önekiyle kaydedilmeli: `IconData` içindeki
      // `fontPackage` alanı, Flutter'ın çözdüğü aileyi
      // `packages/<paket>/<aile>` biçimine çevirir. Öneksiz kayıt sessizce
      // eşleşmez ve ikonlar yine kare çizilir.
      final iconLoader = FontLoader('packages/font_awesome_flutter/$family')
        ..addFont(
          iconFont.readAsBytes().then((bytes) => ByteData.view(bytes.buffer)),
        );
      await iconLoader.load();
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

    repository = freshMockRepository();
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
    await _pump(t, FriendsScreen(repository: repository));
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

  testWidgets('36 kategoriler', (t) async {
    await _pump(t, Scaffold(body: CategoriesTab(repository: repository)));
    await _shoot(t, '36_categories');
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
    await _pump(t, FriendsScreen(repository: repository), dark: true);
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

  testWidgets('51 ders akışı (karanlık)', (t) async {
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

  testWidgets('52 kategoriler (karanlık)', (t) async {
    await _pump(
      t,
      Scaffold(body: CategoriesTab(repository: repository)),
      dark: true,
    );
    await _shoot(t, '52_categories_dark');
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

  testWidgets('61 kategoriler (Kurmancî)', (t) async {
    await _pump(
      t,
      Scaffold(body: CategoriesTab(repository: repository)),
      ku: true,
    );
    await _shoot(t, '61_categories_ku');
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
    await _pump(t, FriendsScreen(repository: repository), ku: true);
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
    await t.tap(find.byKey(const ValueKey('play-hub-create-room')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 800));
    await _shoot(t, '90_custom_room_sheet');
  }, tags: ['preview']);

  testWidgets("91 oda kurma sheet'i (karanlık)", (t) async {
    await _pump(t, PlayHubScreen(repository: repository), dark: true);
    await t.tap(find.byKey(const ValueKey('play-hub-create-room')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 800));
    await _shoot(t, '91_custom_room_sheet_dark');
  }, tags: ['preview']);

  testWidgets("92 oda kurma sheet'i (Kurmancî)", (t) async {
    await _pump(t, PlayHubScreen(repository: repository), ku: true);
    await t.tap(find.byKey(const ValueKey('play-hub-create-room')));
    await t.pump();
    await t.pump(const Duration(milliseconds: 800));
    await _shoot(t, '92_custom_room_sheet_ku');
  }, tags: ['preview']);

  // 2. Uçuşan reaksiyon baloncukları — animasyon hâlinde yakalanır.
  testWidgets('93 uçuşan reaksiyonlar', (t) async {
    final controller = FloatingReactionController();
    await _pump(
      t,
      FloatingReactionOverlay(
        controller: controller,
        child: RoomScreen(
          repository: repository,
          initialRoom: repository.createRoom(),
        ),
      ),
    );
    controller.triggerReaction('👏 Destxweş!', senderName: 'Berfin');
    controller.triggerReaction('🔥 Agir!', senderName: 'Rojda');
    controller.triggerReaction('⚡ Lez be!', senderName: 'Baran');
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
        name: 'Hevrik',
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
