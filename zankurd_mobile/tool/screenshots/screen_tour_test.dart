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
import 'package:zankurd_mobile/src/models/friend.dart';
import 'package:zankurd_mobile/src/models/leaderboard_entry.dart';
import 'package:zankurd_mobile/src/models/leaderboard_period.dart';
import 'package:zankurd_mobile/src/models/contest.dart';
import 'package:zankurd_mobile/src/providers/theme_provider.dart';
import 'package:zankurd_mobile/src/screens/contest_screen.dart';
import 'package:zankurd_mobile/src/screens/home_screen.dart';
import 'package:zankurd_mobile/src/screens/friends_screen.dart';
import 'package:zankurd_mobile/src/screens/leaderboard_screen.dart';
import 'package:zankurd_mobile/src/screens/matchmaking_screen.dart';
import 'package:zankurd_mobile/src/screens/paywall_screen.dart';
import 'package:zankurd_mobile/src/screens/play_hub_screen.dart';
import 'package:zankurd_mobile/src/screens/profile_screen.dart';
import 'package:zankurd_mobile/src/screens/quiz_screen.dart';
import 'package:zankurd_mobile/src/screens/review_screen.dart';
import 'package:zankurd_mobile/src/screens/room_screen.dart';
import 'package:zankurd_mobile/src/screens/avatar_editor_screen.dart';
import 'package:zankurd_mobile/src/screens/categories_tab.dart';
import 'package:zankurd_mobile/src/screens/level_placement_screen.dart';
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
Widget _framed(Widget child) => RepaintBoundary(
  key: _boundaryKey,
  child: Material(type: MaterialType.transparency, child: child),
);

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
    if (Directory('${dir.path}/bin/cache/artifacts/material_fonts').existsSync()) {
      return dir.path;
    }
    dir = dir.parent;
  }
  return '';
}

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool dark = false,
  bool ku = false,
}) async {
  _applyViewport(tester, _size);
  await tester.pumpWidget(
    testShell(
      child: _framed(child),
      themeProvider: dark
          ? (ThemeProvider(initialMode: ThemeMode.dark))
          : null,
      languageProvider: ku ? kurmanciLang() : null,
    ),
  );
  // pumpAndSettle KULLANILMAZ: yükleme göstergeleri sonsuz animasyondur ve
  // tur boyunca kilitlenmeye yol açar. Sabit süreli pump yeterlidir.
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 900));
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
      final iconLoader =
          FontLoader('packages/font_awesome_flutter/$family')..addFont(
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

  // Ara ekranlar: bekleme ve para biriminin geçtiği yerler. Yeni
  // kullanıcının en çok "şimdi ne olacak?" diye durakladığı noktalar
  // burasıdır, bu yüzden turda ana ekranlar kadar yer tutarlar.
  testWidgets('17 oda', (t) async {
    await _pump(
      t,
      RoomScreen(
        repository: repository,
        initialRoom: repository.createRoom(),
      ),
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
    await _pump(t, Scaffold(body: HomeScreen(repository: repository)),
        dark: true);
    await _shoot(t, '20_home_dark');
  }, tags: ['preview']);

  testWidgets('21 oyun merkezi (karanlık)', (t) async {
    await _pump(t, PlayHubScreen(repository: repository), dark: true);
    await _shoot(t, '21_play_hub_dark');
  }, tags: ['preview']);

  testWidgets('22 profil (karanlık)', (t) async {
    await _pump(t, Scaffold(body: ProfileScreen(repository: repository)),
        dark: true);
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
    await _pump(t, Scaffold(body: HomeScreen(repository: repository)),
        ku: true);
    await _shoot(t, '26_home_ku');
  }, tags: ['preview']);

  testWidgets('27 oyun merkezi (Kurmancî)', (t) async {
    await _pump(t, PlayHubScreen(repository: repository), ku: true);
    await _shoot(t, '27_play_hub_ku');
  }, tags: ['preview']);

  testWidgets('28 profil (Kurmancî)', (t) async {
    await _pump(t, Scaffold(body: ProfileScreen(repository: repository)),
        ku: true);
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
          ),
          AnswerRecord(
            id: 'r2',
            category: 'Dîrok',
            prompt: 'Şerefname kê nivîsandiye?',
            answers: ['Şerefxan', 'Ehmedê Xanî', 'Melayê Cizîrî', 'Feqiyê Teyran'],
            correctAnswer: 'Şerefxan',
            selectedAnswer: 'Ehmedê Xanî',
            explanation: 'Şerefname, Şerefxanê Bidlîsî tarafından yazıldı.',
          ),
        ],
      ),
    );
    await _shoot(t, '44_review');
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
}
